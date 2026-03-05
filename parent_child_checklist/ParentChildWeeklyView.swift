//
// ParentChildWeeklyView.swift
// parent_child_checklist
//

import SwiftUI
import UIKit

// MARK: - Local theme tokens (match child screens)
private enum FuturistTheme {
    static let skyTop = Color(red: 0.02, green: 0.06, blue: 0.16)
    static let skyBottom = Color(red: 0.01, green: 0.03, blue: 0.10)
    static let neonAqua = Color(red: 0.20, green: 0.95, blue: 1.00)

    // Text
    static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)

    // Accents (radios)
    static let magenta = Color(hue: 0.83, saturation: 0.85, brightness: 0.95) // unchecked ring
    static let green   = Color(hue: 0.33, saturation: 0.78, brightness: 0.92) // checked ring
}

// MARK: - Reusable card background (glass + thin stroke)
private struct CardBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let surface      = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    private let surfaceSolid = Color(red: 0.05, green: 0.10, blue: 0.22)
    var cornerRadius: CGFloat = 12
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(reduceTransparency ? surfaceSolid : surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Subtle lower sweep behind content (like child)
private struct LowerContentSweep: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.00),
                .init(color: FuturistTheme.skyTop.opacity(0.05), location: 0.50),
                .init(color: FuturistTheme.skyTop.opacity(0.08), location: 1.00)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Neon divider (dark → neon → dark)
private struct TaskRowGradientRule: View {
    var leadingInset: CGFloat
    var trailingInset: CGFloat
    var thickness: CGFloat = 2

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: FuturistTheme.skyTop.opacity(0.95), location: 0.00),
                .init(color: FuturistTheme.neonAqua,             location: 0.50),
                .init(color: FuturistTheme.skyTop.opacity(0.95), location: 1.00),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: thickness)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ParentChildWeeklyView: View {
    let childId: UUID
    @EnvironmentObject private var appState: AppState

    // Selected day
    @State private var selectedDate: Date = Date()

    // Sheets (Assign entry points)
    @State private var showAssignTaskSheet = false
    @State private var showAssignEventSheet = false

    // Edit sheets
    @State private var assignmentToEdit: TaskAssignment? = nil
    @State private var eventToEdit: EventAssignment? = nil

    // Toast
    @State private var toastMessage: String? = nil

    // Photo viewer sheet
    @State private var completionToPreview: TaskCompletionRecord? = nil
    @State private var viewerTaskTitle: String = ""

    // MARK: - Tunables to match child screens
    private static let ruleLeadingInset: CGFloat = 16
    private static let ruleTrailingInset: CGFloat = 14
    private static let ruleExtraBottomPadding: CGFloat = 6
    private static let ruleVerticalOffset: CGFloat = 6  // same as child Requests
    private static let headerTopPadding: CGFloat = 6
    private static let headerBottomPadding: CGFloat = 4

    // Monday-first calendar
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private var child: ChildProfile? {
        appState.children.first { $0.id == childId }
    }

    private var today: Date { Date() }

    // MARK: - Header texts
    private var headerSelectedDayText: String {
        let df = DateFormatter()
        df.calendar = isoCalendar
        df.locale = .current
        df.dateFormat = "EEEE"
        return df.string(from: selectedDate)
    }

    private var headerSelectedDateText: String {
        let df = DateFormatter()
        df.calendar = isoCalendar
        df.locale = .current
        df.dateStyle = .long
        return df.string(from: selectedDate)
    }

    private var pointsText: String {
        String(appState.childPointsTotal(childId: childId))
    }

    // MARK: - Data helpers
    private var tasksForSelectedDay: [TaskAssignment] {
        appState.assignments(for: childId, on: selectedDate)
    }
    private var eventsForSelectedDay: [EventAssignment] {
        appState.events(for: childId, on: selectedDate)
    }
    private var eventIdsForSelectedDay: Set<UUID> { Set(eventsForSelectedDay.map(\.id)) }

    private var linkedTasksForSelectedDay: [TaskAssignment] {
        tasksForSelectedDay.filter { $0.linkedEventAssignmentId.flatMap(eventIdsForSelectedDay.contains) ?? false }
    }
    private var unlinkedTasksForSelectedDay: [TaskAssignment] {
        tasksForSelectedDay.filter { assignment in
            guard let evId = assignment.linkedEventAssignmentId else { return true }
            return !eventIdsForSelectedDay.contains(evId)
        }
    }

    private func effectiveTime(for task: TaskAssignment) -> Date? { task.startTime ?? task.finishTime }
    private func effectiveTime(for event: EventAssignment) -> Date? { event.startTime ?? event.finishTime }
    private func timeOfDayKey(_ time: Date?) -> Int? {
        guard let time else { return nil }
        let comps = isoCalendar.dateComponents([.hour, .minute], from: time)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
    private func taskTimeKey(_ task: TaskAssignment) -> Int? { timeOfDayKey(effectiveTime(for: task)) }
    private func eventTimeKey(_ event: EventAssignment) -> Int? { timeOfDayKey(effectiveTime(for: event)) }

    private var eventsSortedForDisplay: [EventAssignment] {
        eventsForSelectedDay.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive && !b.isActive }
            let ta = eventTimeKey(a); let tb = eventTimeKey(b)
            switch (ta, tb) {
            case (nil, nil): break
            case (nil, _?): return false
            case (_?, nil): return true
            case (let x?, let y?): if x != y { return x < y }
            }
            return a.eventTitle.localizedCaseInsensitiveCompare(b.eventTitle) == .orderedAscending
        }
    }

    private func linkedTasks(for eventId: UUID) -> [TaskAssignment] {
        linkedTasksForSelectedDay
            .filter { $0.linkedEventAssignmentId == eventId }
            .sorted { a, b in
                if a.isActive != b.isActive { return a.isActive && !b.isActive }
                let ta = taskTimeKey(a); let tb = taskTimeKey(b)
                switch (ta, tb) {
                case (nil, nil): break
                case (nil, _?): return false
                case (_?, nil): return true
                case (let x?, let y?): if x != y { return x < y }
                }
                return a.taskTitle.localizedCaseInsensitiveCompare(b.taskTitle) == .orderedAscending
            }
    }

    private var unlinkedTasksSortedForDisplay: [TaskAssignment] {
        unlinkedTasksForSelectedDay.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive && !b.isActive }
            let ta = taskTimeKey(a); let tb = taskTimeKey(b)
            switch (ta, tb) {
            case (nil, nil): break
            case (nil, _?): return false
            case (_?, nil): return true
            case (let x?, let y?): if x != y { return x < y }
            }
            return a.taskTitle.localizedCaseInsensitiveCompare(b.taskTitle) == .orderedAscending
        }
    }

    private enum AgendaSection: Hashable { case tasks, events }

    private var earliestStandaloneTaskKey: Int? {
        unlinkedTasksForSelectedDay.compactMap { taskTimeKey($0) }.min()
    }
    private var earliestEventBlockKey: Int? {
        let perEventEarliest: [Int] = eventsForSelectedDay.compactMap { ev in
            var keys: [Int] = []
            if let k = eventTimeKey(ev) { keys.append(k) }
            keys.append(contentsOf: linkedTasks(for: ev.id).compactMap { taskTimeKey($0) })
            return keys.min()
        }
        return perEventEarliest.min()
    }

    private var agendaSectionOrder: [AgendaSection] {
        let t = earliestStandaloneTaskKey
        let e = earliestEventBlockKey
        if t == nil && e == nil { return [.tasks, .events] }
        if let t, let e { return (t <= e) ? [.tasks, .events] : [.events, .tasks] }
        if t != nil { return [.tasks, .events] }
        return [.events, .tasks]
    }

    private var standaloneTasksSectionTitle: String {
        guard !eventsForSelectedDay.isEmpty else { return "Tasks" }
        return (agendaSectionOrder.first == .events) ? "Other Tasks" : "Tasks"
    }

    // MARK: - Toast helper
    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) {
                toastMessage = nil
            }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)

                VStack(spacing: 0) {
                    headerCluster
                        .padding(.horizontal)

                    ZStack {
                        LowerContentSweep()
                        VStack(spacing: 6) {  // Option-B spacing
                            dayStripPager
                            agendaArea
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(.horizontal)
                    }
                }

                // Sheets (unchanged)
                .sheet(isPresented: $showAssignTaskSheet) {
                    AssignTaskToChildView(
                        childId: childId,
                        defaultStartDate: selectedDate,
                        onShowWeeklyToast: { showToast($0) }
                    )
                    .environmentObject(appState)
                }
                .sheet(isPresented: $showAssignEventSheet) {
                    AssignEventToChildView(
                        childId: childId,
                        defaultStartDate: selectedDate,
                        onShowWeeklyToast: { showToast($0) }
                    )
                    .environmentObject(appState)
                }
                .sheet(item: $assignmentToEdit) { assignment in
                    EditTaskAssignmentView(assignment: assignment).environmentObject(appState)
                }
                .sheet(item: $eventToEdit) { event in
                    EditEventAssignmentView(assignment: event).environmentObject(appState)
                }
                .sheet(item: $completionToPreview) { comp in
                    PhotoEvidenceViewer(completion: comp, taskTitle: viewerTaskTitle)
                }

                if let toastMessage {
                    ToastBannerView(message: toastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .onAppear { selectedDate = isoCalendar.startOfDay(for: today) }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header cluster
    private var headerCluster: some View {
        VStack(spacing: 6) {
            if let child {
                ChildHeaderView(
                    child: child,
                    points: appState.childPointsTotal(childId: childId)
                )
            }

            Text(headerSelectedDayText)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(FuturistTheme.textPrimary)
                .padding(.top, 2)

            HStack(spacing: 8) {
                Text(headerSelectedDateText)
                    .font(.subheadline)
                    .foregroundStyle(FuturistTheme.textSecondary)

                Spacer(minLength: 8)

                Button("Today") {
                    jumpToToday()
                }
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(Color.white)
                .background(Color.white.opacity(0.25), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                .accessibilityLabel("Jump to today")
            }
        }
    }

    // MARK: - 🔹 Sliding calendar with brighter weekday colours (only change)
    private var dayStripPager: some View {
        ScrollableDayStrip(
            selectedDate: $selectedDate,
            calendar: isoCalendar
        )
        // Bright, cool white/blue so weekday names and dates stand out clearly
        .tint(Color(red: 0.88, green: 0.96, blue: 1.00))
        .brightness(0.14)    // luminance lift
        .contrast(1.24)      // edge clarity
        .saturation(1.12)    // slight colour intensity
        .frame(height: 70)
        .padding(.bottom, -10)
    }

    // MARK: - Agenda area (Lists themed like child)
    private var agendaArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            if tasksForSelectedDay.isEmpty && eventsForSelectedDay.isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 16)
                    Text("No tasks or events assigned for this day.")
                        .foregroundStyle(FuturistTheme.textSecondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(agendaSectionOrder, id: \.self) { section in
                        switch section {
                        case .tasks:
                            if !unlinkedTasksSortedForDisplay.isEmpty {
                                Section {
                                    let items = unlinkedTasksSortedForDisplay
                                    ForEach(Array(items.enumerated()), id: \.element.id) { index, assignment in
                                        let completion = appState.completionRecord(for: assignment.id, on: selectedDate)

                                        VStack(spacing: 0) {
                                            TaskAssignmentRow(
                                                assignment: assignment,
                                                selectedDate: selectedDate,
                                                isCompleted: completion != nil,
                                                completionForSelectedDay: completion,
                                                onToggleComplete: {
                                                    appState.toggleCompletion(assignmentId: assignment.id, on: selectedDate)
                                                },
                                                onTap: { assignmentToEdit = assignment },
                                                onViewPhoto: {
                                                    guard let comp = completion, comp.hasPhotoEvidence else { return }
                                                    viewerTaskTitle = assignment.taskTitle
                                                    completionToPreview = comp
                                                },
                                                headlineColor: FuturistTheme.textPrimary,
                                                metaColor: FuturistTheme.textSecondary
                                            )
                                        }
                                        .padding(.bottom, Self.ruleExtraBottomPadding)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(CardBackground())
                                        .overlay(alignment: .bottomLeading) {
                                            if index < items.count - 1 {
                                                TaskRowGradientRule(
                                                    leadingInset: Self.ruleLeadingInset,
                                                    trailingInset: Self.ruleTrailingInset,
                                                    thickness: 2
                                                )
                                                .offset(y: Self.ruleVerticalOffset)
                                            }
                                        }
                                    }
                                    .onDelete { indexSet in
                                        for idx in indexSet {
                                            let a = unlinkedTasksSortedForDisplay[idx]
                                            appState.deleteTaskAssignment(id: a.id)
                                        }
                                    }
                                } header: {
                                    Text(standaloneTasksSectionTitle)
                                        .foregroundStyle(FuturistTheme.textPrimary)
                                        .textCase(nil)
                                        .padding(.top, Self.headerTopPadding)
                                        .padding(.bottom, Self.headerBottomPadding)
                                }
                            }

                        case .events:
                            if !eventsSortedForDisplay.isEmpty {
                                Section {
                                    let items = eventsSortedForDisplay
                                    ForEach(Array(items.enumerated()), id: \.element.id) { index, event in
                                        VStack(spacing: 0) {
                                            EventAssignmentRow(
                                                event: event,
                                                onTap: { eventToEdit = event },
                                                headlineColor: FuturistTheme.textPrimary,
                                                metaColor: FuturistTheme.textSecondary
                                            )
                                        }
                                        .padding(.bottom, Self.ruleExtraBottomPadding)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(CardBackground())
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                appState.deleteEventAssignment(id: event.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .overlay(alignment: .bottomLeading) {
                                            if index < items.count - 1 {
                                                TaskRowGradientRule(
                                                    leadingInset: Self.ruleLeadingInset,
                                                    trailingInset: Self.ruleTrailingInset,
                                                    thickness: 2
                                                )
                                                .offset(y: Self.ruleVerticalOffset)
                                            }
                                        }

                                        // Linked tasks under event
                                        let tasks = linkedTasks(for: event.id)
                                        if !tasks.isEmpty {
                                            ForEach(tasks) { assignment in
                                                let completion = appState.completionRecord(for: assignment.id, on: selectedDate)
                                                VStack(spacing: 0) {
                                                    TaskAssignmentRow(
                                                        assignment: assignment,
                                                        selectedDate: selectedDate,
                                                        isCompleted: completion != nil,
                                                        completionForSelectedDay: completion,
                                                        onToggleComplete: {
                                                            appState.toggleCompletion(assignmentId: assignment.id, on: selectedDate)
                                                        },
                                                        onTap: { assignmentToEdit = assignment },
                                                        onViewPhoto: {
                                                            guard let comp = completion, comp.hasPhotoEvidence else { return }
                                                            viewerTaskTitle = assignment.taskTitle
                                                            completionToPreview = comp
                                                        },
                                                        headlineColor: FuturistTheme.textPrimary,
                                                        metaColor: FuturistTheme.textSecondary
                                                    )
                                                }
                                                .padding(.leading, 18)
                                                .padding(.bottom, Self.ruleExtraBottomPadding)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                                                .listRowSeparator(.hidden)
                                                .listRowBackground(CardBackground())
                                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                    Button(role: .destructive) {
                                                        appState.deleteTaskAssignment(id: assignment.id)
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } header: {
                                    Text("Events")
                                        .foregroundStyle(FuturistTheme.textPrimary)
                                        .textCase(nil)
                                        .padding(.top, Self.headerTopPadding)
                                        .padding(.bottom, Self.headerBottomPadding)
                                }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .environment(\.defaultMinListHeaderHeight, 0)
            }
        }
    }

    private func jumpToToday() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            selectedDate = isoCalendar.startOfDay(for: today)
        }
    }
}

// MARK: - Task row (PARENT) — radios match child: magenta ring / green + dark fill + white check
private struct TaskAssignmentRow: View {
    let assignment: TaskAssignment
    let selectedDate: Date
    let isCompleted: Bool
    let completionForSelectedDay: TaskCompletionRecord?
    let onToggleComplete: () -> Void
    let onTap: () -> Void
    let onViewPhoto: (() -> Void)?

    var headlineColor: Color = FuturistTheme.textPrimary
    var metaColor: Color = FuturistTheme.textSecondary

    private var dimmed: Bool { !assignment.isActive }

    private var inactiveBadge: some View {
        Text("Inactive")
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(metaColor)
            .background(Color.white.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
    }

    // Custom radio: matches the child-side visuals
    private var radio: some View {
        ZStack {
            if isCompleted {
                Circle()
                    .stroke(FuturistTheme.green, lineWidth: 2.5)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .stroke(FuturistTheme.magenta, lineWidth: 2.5)
                    .frame(width: 22, height: 22)
            }
        }
        .accessibilityHidden(true)
    }

    private var timeSummary: String? {
        let df = DateFormatter(); df.dateFormat = "h:mm a"
        var parts: [String] = []
        if let s = assignment.startTime { parts.append("⏰ \(df.string(from: s))") }
        if let f = assignment.finishTime { parts.append("→ \(df.string(from: f))") }
        if let dur = assignment.durationMinutes, dur > 0 {
            let h = dur / 60, m = dur % 60
            if h > 0 && m > 0 { parts.append("⏳ \(h)h \(m)m") }
            else if h > 0 { parts.append("⏳ \(h)h") }
            else { parts.append("⏳ \(m)m") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var body: some View {
        Button { onTap() } label: {
            HStack(alignment: .top, spacing: 12) {

                Button { onToggleComplete() } label: { radio }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {

                    HStack(spacing: 10) {
                        Text(assignment.taskIcon)
                            .font(.system(size: 22))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text(assignment.taskTitle)
                            .font(.headline)
                            .foregroundStyle(headlineColor)

                        Spacer()

                        if !assignment.isActive { inactiveBadge }

                        if assignment.rewardPoints > 0 {
                            HStack(spacing: 4) {
                                Text("💎")
                                Text("\(assignment.rewardPoints)").fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundStyle(metaColor)
                        }
                    }

                    if let helper = assignment.helper, !helper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(helper)
                            .font(.subheadline)
                            .foregroundStyle(metaColor)
                            .lineLimit(2)
                    }

                    if assignment.photoEvidenceRequired || timeSummary != nil || (completionForSelectedDay?.hasPhotoEvidence ?? false) {
                        HStack(spacing: 10) {
                            if let timeSummary { Text(timeSummary).font(.footnote).foregroundStyle(metaColor) }
                            if assignment.photoEvidenceRequired {
                                Image(systemName: "camera.fill").font(.footnote).foregroundStyle(metaColor)
                            }
                            if let comp = completionForSelectedDay, comp.hasPhotoEvidence {
                                Button {
                                    onViewPhoto?()
                                } label: {
                                    HStack(spacing: 4) { Image(systemName: "photo"); Text("View") }
                                        .font(.footnote)
                                }
                                .buttonStyle(.bordered)
                                .tint(.accentColor)
                                .accessibilityLabel("View photo evidence")
                            }
                            Spacer()
                        }
                    }
                }
            }
            .opacity(dimmed ? 0.60 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Event row — themed colours supported
private struct EventAssignmentRow: View {
    let event: EventAssignment
    let onTap: () -> Void

    var headlineColor: Color = FuturistTheme.textPrimary
    var metaColor: Color = FuturistTheme.textSecondary

    private var dimmed: Bool { !event.isActive }

    private var inactiveBadge: some View {
        Text("Inactive")
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(metaColor)
            .background(Color.white.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
    }

    private var timeSummary: String? {
        let df = DateFormatter(); df.dateFormat = "h:mm a"
        var parts: [String] = []
        if let s = event.startTime { parts.append("⏰ \(df.string(from: s))") }
        if let f = event.finishTime { parts.append("→ \(df.string(from: f))") }
        if let dur = event.durationMinutes, dur > 0 {
            let h = dur / 60, m = dur % 60
            if h > 0 && m > 0 { parts.append("⏳ \(h)h \(m)m") }
            else if h > 0 { parts.append("⏳ \(h)h") }
            else { parts.append("⏳ \(m)m") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private var locationLine: String? {
        let t = event.locationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : "📍 \(t)"
    }

    private var alertLine: String? {
        guard event.alertMe else { return nil }
        let mins = event.alertOffsetMinutes ?? 0
        return mins == 0 ? "🔔 Alert at start time" : "🔔 Alert \(mins) min before"
    }

    var body: some View {
        Button { onTap() } label: {
            VStack(alignment: .leading, spacing: 6) {

                HStack(spacing: 10) {
                    Text(event.eventIcon)
                        .font(.system(size: 22))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(event.eventTitle)
                        .font(.headline)
                        .foregroundStyle(headlineColor)

                    Spacer()

                    if !event.isActive { inactiveBadge }
                }

                if let helper = event.helper, !helper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(helper)
                        .font(.subheadline)
                        .foregroundStyle(metaColor)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    if let timeSummary { Text(timeSummary).font(.footnote).foregroundStyle(metaColor) }
                    if let locationLine { Text(locationLine).font(.footnote).foregroundStyle(metaColor) }
                    if let alertLine { Text(alertLine).font(.footnote).foregroundStyle(metaColor) }
                    Spacer()
                }
            }
            .opacity(dimmed ? 0.65 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
