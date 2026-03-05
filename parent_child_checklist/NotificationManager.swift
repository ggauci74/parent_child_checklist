//
// NotificationManager.swift
// parent_child_checklist
//
// Part 3: Local notification scheduling & management.
// - Requests authorization
// - Schedules "Notify Me" for Task & Event assignments (Start/Finish)
// - Cancels/reschedules deterministically by assignment ID & phase
// - Device routing is done via `audience:` parameter (parent vs child)
// - Schedules the NEXT upcoming occurrence (non-repeating trigger)
//   — call `reconcile*` on app launch / foreground / after changes
//

import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit   // Required for UIApplication on iOS/tvOS
#endif

// MARK: - Notification audience (who this device should schedule for)
enum NotificationAudience {
    case parent
    case child
}

// MARK: - Internal kinds/phases for stable identifiers
private enum AssignmentKind: String {
    case task
    case event
}

private enum Phase: String {
    case start
    case finish
}

// MARK: - Notification Manager

final class NotificationManager: NSObject {
    static let shared = NotificationManager()
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Public API: Authorization

    /// Asks the system for notification permission (only once is typical).
    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            case .denied:
                completion(false)
            case .authorized, .provisional, .ephemeral:
                completion(true)
            @unknown default:
                completion(false)
            }
        }
    }

    /// Returns current authorization status.
    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    /// Opens system Settings for the app (to enable notifications if denied).
    func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            // Use the simple overload to avoid the 'nil requires a contextual type' warning
            UIApplication.shared.open(url)
        }
        #else
        // Non‑UIKit platforms: no-op (or add platform-specific behavior here)
        #endif
    }

    // MARK: - Public API: Cancel helpers

    func cancelAllForTask(id: UUID) {
        let ids = [
            identifier(kind: .task, id: id, phase: .start),
            identifier(kind: .task, id: id, phase: .finish)
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAllForEvent(id: UUID) {
        let ids = [
            identifier(kind: .event, id: id, phase: .start),
            identifier(kind: .event, id: id, phase: .finish)
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Public API: Schedule NEXT occurrence (Task)

    /// Schedules the NEXT Start/Finish notifications for a TaskAssignment that apply to this device audience.
    /// - Important: This cancels pending requests for this assignment first (to avoid duplicates),
    ///              then schedules new ones if eligible (enabled, time present, future).
    func scheduleNext(for task: TaskAssignment, audience: NotificationAudience) {
        cancelAllForTask(id: task.id)

        // Start
        if shouldScheduleStart(task: task, audience: audience),
           let fireDate = nextStartFireDate(for: task) {
            schedule(
                kind: .task,
                id: task.id,
                phase: .start,
                title: "Reminder: \(task.taskTitle)",
                body: startBodyText(for: task),
                fireDate: fireDate
            )
        }

        // Finish
        if shouldScheduleFinish(task: task, audience: audience),
           let fireDate = nextFinishFireDate(for: task) {
            schedule(
                kind: .task,
                id: task.id,
                phase: .finish,
                title: "Reminder: \(task.taskTitle)",
                body: finishBodyText(for: task),
                fireDate: fireDate
            )
        }
    }

    // MARK: - Public API: Schedule NEXT occurrence (Event)

    /// Schedules the NEXT Start/Finish notifications for an EventAssignment that apply to this device audience.
    func scheduleNext(for event: EventAssignment, audience: NotificationAudience) {
        cancelAllForEvent(id: event.id)

        // Start
        if shouldScheduleStart(event: event, audience: audience),
           let fireDate = nextStartFireDate(for: event) {
            schedule(
                kind: .event,
                id: event.id,
                phase: .start,
                title: "Reminder: \(event.eventTitle)",
                body: startBodyText(for: event),
                fireDate: fireDate
            )
        }

        // Finish
        if shouldScheduleFinish(event: event, audience: audience),
           let fireDate = nextFinishFireDate(for: event) {
            schedule(
                kind: .event,
                id: event.id,
                phase: .finish,
                title: "Reminder: \(event.eventTitle)",
                body: finishBodyText(for: event),
                fireDate: fireDate
            )
        }
    }

    // MARK: - Public API: Reconcile helpers (batch)

    /// Reconciles all tasks for this device audience: ensures pending notifications match current data
    /// by canceling & re-scheduling the next upcoming notifications.
    func reconcileTasks(_ tasks: [TaskAssignment], audience: NotificationAudience) {
        for t in tasks where t.isActive {
            scheduleNext(for: t, audience: audience)
        }
    }

    /// Reconciles all events for this device audience.
    func reconcileEvents(_ events: [EventAssignment], audience: NotificationAudience) {
        for e in events where e.isActive {
            scheduleNext(for: e, audience: audience)
        }
    }

    // MARK: - Recipient routing (Parent vs Child device)

    private func shouldScheduleStart(task: TaskAssignment, audience: NotificationAudience) -> Bool {
        guard task.startNotifyEnabled, task.startTime != nil else { return false }
        return isRecipientMatch(task.startNotifyRecipient, audience: audience)
    }

    private func shouldScheduleFinish(task: TaskAssignment, audience: NotificationAudience) -> Bool {
        guard task.finishNotifyEnabled, task.finishTime != nil else { return false }
        return isRecipientMatch(task.finishNotifyRecipient, audience: audience)
    }

    private func shouldScheduleStart(event: EventAssignment, audience: NotificationAudience) -> Bool {
        guard event.startNotifyEnabled, event.startTime != nil else { return false }
        return isRecipientMatch(event.startNotifyRecipient, audience: audience)
    }

    private func shouldScheduleFinish(event: EventAssignment, audience: NotificationAudience) -> Bool {
        guard event.finishNotifyEnabled, event.finishTime != nil else { return false }
        return isRecipientMatch(event.finishNotifyRecipient, audience: audience)
    }

    private func isRecipientMatch(_ r: NotifyRecipient, audience: NotificationAudience) -> Bool {
        switch (r, audience) {
        case (.both, _): return true
        case (.parent, .parent): return true
        case (.child, .child):   return true
        default: return false
        }
    }

    // MARK: - Next fire date (Task)

    private func nextStartFireDate(for t: TaskAssignment) -> Date? {
        guard let base = nextOccurrenceDay(startDate: t.startDate, endDate: t.endDate, occurrence: t.occurrence, weekdays: t.weekdays) else { return nil }
        guard let time = t.startTime else { return nil }
        let at = merge(day: base, time: time)
        let offset = max(0, t.startNotifyOffsetMinutes ?? 0)
        let fire = Calendar.current.date(byAdding: .minute, value: -offset, to: at) ?? at
        return fire > Date() ? fire : nil
    }

    private func nextFinishFireDate(for t: TaskAssignment) -> Date? {
        guard let base = nextOccurrenceDay(startDate: t.startDate, endDate: t.endDate, occurrence: t.occurrence, weekdays: t.weekdays) else { return nil }
        guard let time = t.finishTime else { return nil }
        let at = merge(day: base, time: time)
        let offset = max(0, t.finishNotifyOffsetMinutes ?? 0)
        let fire = Calendar.current.date(byAdding: .minute, value: -offset, to: at) ?? at
        return fire > Date() ? fire : nil
    }

    // MARK: - Next fire date (Event)

    private func nextStartFireDate(for e: EventAssignment) -> Date? {
        guard let base = nextOccurrenceDay(startDate: e.startDate, endDate: e.endDate, occurrence: e.occurrence, weekdays: e.weekdays) else { return nil }
        guard let time = e.startTime else { return nil }
        let at = merge(day: base, time: time)
        let offset = max(0, e.startNotifyOffsetMinutes ?? 0)
        let fire = Calendar.current.date(byAdding: .minute, value: -offset, to: at) ?? at
        return fire > Date() ? fire : nil
    }

    private func nextFinishFireDate(for e: EventAssignment) -> Date? {
        guard let base = nextOccurrenceDay(startDate: e.startDate, endDate: e.endDate, occurrence: e.occurrence, weekdays: e.weekdays) else { return nil }
        guard let time = e.finishTime else { return nil }
        let at = merge(day: base, time: time)
        let offset = max(0, e.finishNotifyOffsetMinutes ?? 0)
        let fire = Calendar.current.date(byAdding: .minute, value: -offset, to: at) ?? at
        return fire > Date() ? fire : nil
    }

    // MARK: - Build content

    private func startBodyText(for t: TaskAssignment) -> String {
        if let mins = t.startNotifyOffsetMinutes, mins > 0 {
            return "Starts in \(mins) minute\(mins == 1 ? "" : "s")."
        }
        return "Starts now."
    }

    private func finishBodyText(for t: TaskAssignment) -> String {
        if let mins = t.finishNotifyOffsetMinutes, mins > 0 {
            return "Finishes in \(mins) minute\(mins == 1 ? "" : "s")."
        }
        return "Finishes now."
    }

    private func startBodyText(for e: EventAssignment) -> String {
        if let mins = e.startNotifyOffsetMinutes, mins > 0 {
            return "Starts in \(mins) minute\(mins == 1 ? "" : "s")."
        }
        return "Starts now."
    }

    private func finishBodyText(for e: EventAssignment) -> String {
        if let mins = e.finishNotifyOffsetMinutes, mins > 0 {
            return "Finishes in \(mins) minute\(mins == 1 ? "" : "s")."
        }
        return "Finishes now."
    }

    // MARK: - Core scheduling

    private func schedule(kind: AssignmentKind, id: UUID, phase: Phase, title: String, body: String, fireDate: Date) {
        // Build trigger date components in current calendar/timezone
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

        // Content
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Trigger (non-repeating; we'll re-schedule next occurrence via reconciliation)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        // Request
        let request = UNNotificationRequest(identifier: identifier(kind: kind, id: id, phase: phase), content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            #if DEBUG
            if let error { print("[NotificationManager] add error:", error) }
            #endif
        }
    }

    // MARK: - ID builder

    private func identifier(kind: AssignmentKind, id: UUID, phase: Phase) -> String {
        return "\(kind.rawValue)_\(id.uuidString)_\(phase.rawValue)"
    }

    // MARK: - Occurrence helpers

    /// Returns the next day (start-of-day) on/after "today" (or startDate) that this schedule occurs.
    /// - For `.onceOnly`: returns `startDate` if >= today, else nil.
    /// - For `.specifiedDays`: returns next day matching selected weekdays within [startDate, endDate].
    private func nextOccurrenceDay(startDate: Date, endDate: Date?, occurrence: Any, weekdays: [Int]) -> Date? {
        let cal = Calendar(identifier: .iso8601)
        var tzCal = cal
        tzCal.timeZone = .current

        let today = tzCal.startOfDay(for: Date())
        let start = max(tzCal.startOfDay(for: startDate), today)

        // Occurrence discriminator via type name (TaskAssignment.Occurrence / EventAssignment.Occurrence)
        let occRaw: String
        if let o = occurrence as? TaskAssignment.Occurrence { occRaw = o.rawValue }
        else if let o = occurrence as? EventAssignment.Occurrence { occRaw = o.rawValue }
        else { occRaw = "specifiedDays" }

        if occRaw == TaskAssignment.Occurrence.onceOnly.rawValue || occRaw == EventAssignment.Occurrence.onceOnly.rawValue {
            let candidate = tzCal.startOfDay(for: startDate)
            return (candidate >= today) ? candidate : nil
        }

        // specified days
        guard !weekdays.isEmpty else { return nil }
        let endBound = endDate.map { tzCal.startOfDay(for: $0) }

        // Search up to 21 days ahead to be safe (should match within a week normally)
        for i in 0..<21 {
            guard let cand = tzCal.date(byAdding: .day, value: i, to: start) else { continue }
            let candDay = tzCal.startOfDay(for: cand)
            if let endBound, candDay > endBound { return nil }
            if weekdays.contains(mondayFirstIndex(for: candDay, calendar: tzCal)) {
                return candDay
            }
        }
        return nil
    }

    /// Monday-first weekday index: 0=Mon ... 6=Sun
    private func mondayFirstIndex(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        switch weekday {
        case 2: return 0 // Mon
        case 3: return 1 // Tue
        case 4: return 2 // Wed
        case 5: return 3 // Thu
        case 6: return 4 // Fri
        case 7: return 5 // Sat
        default: return 6 // Sun
        }
    }

    /// Combines date-only (day) with time (hour/minute).
    private func merge(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: day)
        let t = cal.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = d.year
        combined.month = d.month
        combined.day = d.day
        combined.hour = t.hour
        combined.minute = t.minute
        combined.second = 0

        return cal.date(from: combined) ?? day
    }
}

// MARK: - UNUserNotificationCenterDelegate (optional behaviors)

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Present notifications while the app is in the foreground (banner + sound).
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // After a notification is delivered, you *may* want to immediately schedule the next occurrence here.
    // For v1, we'll keep it simple and rely on reconcile at app launch/foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
