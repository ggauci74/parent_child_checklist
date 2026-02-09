//
// SelectLinkedEventAssignmentView.swift
// parent_child_checklist
//
// Select an active EventAssignment for a given child, filtered to those occurring
// on or after a minimum start date.
//
// IMPORTANT:
// - For once-only events: use startDate >= minimumStartDate
// - For recurring events (.specifiedDays): allow events that started earlier,
//   as long as they still have an occurrence on/after minimumStartDate.
//

import SwiftUI

struct SelectLinkedEventAssignmentView: View {
    let childId: UUID
    let minimumStartDate: Date

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedEventAssignmentId: UUID?
    @State private var searchText: String = ""

    // ISO-like calendar (Monday-first) for consistent day-only comparisons
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private func dayOnly(_ date: Date) -> Date {
        isoCalendar.startOfDay(for: date)
    }

    // Monday-first weekday index: 0=Mon ... 6=Sun
    private func weekdayIndexMondayFirst(for date: Date) -> Int {
        let weekday = isoCalendar.component(.weekday, from: date)
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

    /// Returns the next day (start-of-day) on or after `fromDay` that this recurring event occurs.
    /// If the event doesn't occur anymore (e.g., endDate before match), returns nil.
    private func nextOccurrenceDay(for ev: EventAssignment, onOrAfter fromDay: Date) -> Date? {
        guard ev.occurrence == .specifiedDays else {
            return dayOnly(ev.startDate)
        }

        let startWindow = max(dayOnly(ev.startDate), fromDay)
        let endWindow = ev.endDate.map(dayOnly)

        // If recurring but already ended before our window
        if let endWindow, endWindow < startWindow { return nil }

        // Need at least one weekday selected
        if ev.weekdays.isEmpty { return nil }

        // Find the next matching day within the next 14 days (2 weeks is safe for weekly patterns)
        // This keeps the logic simple and robust.
        for offset in 0..<14 {
            guard let candidate = isoCalendar.date(byAdding: .day, value: offset, to: startWindow) else { continue }
            let candDay = dayOnly(candidate)

            if let endWindow, candDay > endWindow { return nil }

            let w = weekdayIndexMondayFirst(for: candDay)
            if ev.weekdays.contains(w) {
                return candDay
            }
        }

        // If nothing matched within 2 weeks, treat it as non-occurring (very unlikely unless weekdays empty)
        return nil
    }

    /// Whether an event is linkable given the rules:
    /// - must be the same child
    /// - must be active
    /// - must have an occurrence on/after minimumStartDate
    private func isLinkable(_ ev: EventAssignment) -> Bool {
        guard ev.childId == childId else { return false }
        guard ev.isActive else { return false }

        let minDay = dayOnly(minimumStartDate)

        switch ev.occurrence {
        case .onceOnly:
            return dayOnly(ev.startDate) >= minDay

        case .specifiedDays:
            // Recurring events are linkable if they have a next occurrence day on/after minDay
            return nextOccurrenceDay(for: ev, onOrAfter: minDay) != nil
        }
    }

    /// Date used for sorting & display (next occurrence for recurring, start date for once-only)
    private func displayDay(for ev: EventAssignment) -> Date {
        let minDay = dayOnly(minimumStartDate)
        if ev.occurrence == .specifiedDays {
            return nextOccurrenceDay(for: ev, onOrAfter: minDay) ?? dayOnly(ev.startDate)
        }
        return dayOnly(ev.startDate)
    }

    private var childEvents: [EventAssignment] {
        let base = appState.eventAssignments
            .filter { isLinkable($0) }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [EventAssignment]
        if q.isEmpty {
            filtered = base
        } else {
            filtered = base.filter {
                $0.eventTitle.localizedCaseInsensitiveContains(q) ||
                $0.locationNameSnapshot.localizedCaseInsensitiveContains(q)
            }
        }

        // Sort by next occurrence day (or start day for once-only), then by start time (nil last), then title
        return filtered.sorted { a, b in
            let da = displayDay(for: a)
            let db = displayDay(for: b)
            if da != db { return da < db }

            switch (a.startTime, b.startTime) {
            case (nil, nil):
                break
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (let ta?, let tb?):
                if ta != tb { return ta < tb }
            }

            return a.eventTitle.localizedCaseInsensitiveCompare(b.eventTitle) == .orderedAscending
        }
    }

    var body: some View {
        List {
            // None option
            Button {
                selectedEventAssignmentId = nil
                dismiss()
            } label: {
                HStack {
                    Text("None")
                    Spacer()
                    if selectedEventAssignmentId == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Section("Events") {
                if childEvents.isEmpty {
                    Text("No active events occur on or after the selected Start Date.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(childEvents) { ev in
                        Button {
                            selectedEventAssignmentId = ev.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                TaskEmojiIconView(icon: ev.eventIcon, size: 22)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ev.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Event" : ev.eventTitle)
                                        .font(.headline)

                                    Text(detailLine(for: ev))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                if selectedEventAssignmentId == ev.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Select Event")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }

    private func detailLine(for ev: EventAssignment) -> String {
        var parts: [String] = []

        let d = displayDay(for: ev)

        let df = DateFormatter()
        df.dateFormat = "EEE, d MMM"
        parts.append(df.string(from: d))

        if let st = ev.startTime {
            let tf = DateFormatter()
            tf.dateFormat = "h:mm a"
            parts.append("⏰ \(tf.string(from: st))")
        }

        let loc = ev.locationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        if !loc.isEmpty {
            parts.append("📍 \(loc)")
        }

        return parts.joined(separator: " • ")
    }
}
