//
//  SelectLinkedEventTemplateView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 8/2/2026.
//
import SwiftUI

/// Bulk linked-event picker for multi-child assignment.
/// Shows EventTemplates that are valid for ALL selected children:
/// - match by EventTemplate.id (templateId)
/// - each selected child must have EXACTLY ONE active, linkable EventAssignment for that template
struct SelectLinkedEventTemplateView: View {
    let selectedChildIds: Set<UUID>
    let minimumStartDate: Date

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTemplateId: UUID?
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
    /// If the event doesn't occur anymore (endDate before match), returns nil.
    private func nextOccurrenceDay(for ev: EventAssignment, onOrAfter fromDay: Date) -> Date? {
        guard ev.occurrence == .specifiedDays else {
            return dayOnly(ev.startDate)
        }

        let startWindow = max(dayOnly(ev.startDate), fromDay)
        let endWindow = ev.endDate.map(dayOnly)

        if let endWindow, endWindow < startWindow { return nil }
        if ev.weekdays.isEmpty { return nil }

        // Search up to 14 days for next occurrence
        for offset in 0..<14 {
            guard let candidate = isoCalendar.date(byAdding: .day, value: offset, to: startWindow) else { continue }
            let candDay = dayOnly(candidate)
            if let endWindow, candDay > endWindow { return nil }
            let w = weekdayIndexMondayFirst(for: candDay)
            if ev.weekdays.contains(w) { return candDay }
        }
        return nil
    }

    /// An EventAssignment is linkable iff:
    /// - active
    /// - has an occurrence on/after minimumStartDate
    private func isLinkable(_ ev: EventAssignment) -> Bool {
        guard ev.isActive else { return false }
        let minDay = dayOnly(minimumStartDate)
        switch ev.occurrence {
        case .onceOnly:
            return dayOnly(ev.startDate) >= minDay
        case .specifiedDays:
            return nextOccurrenceDay(for: ev, onOrAfter: minDay) != nil
        }
    }

    /// For a given child + template, return all matching linkable EventAssignments.
    private func matchingAssignments(childId: UUID, templateId: UUID) -> [EventAssignment] {
        appState.eventAssignments.filter { ev in
            ev.childId == childId &&
            ev.templateId == templateId &&
            isLinkable(ev)
        }
    }

    /// A template is valid in bulk mode iff:
    /// - every selected child has exactly ONE matching linkable assignment for this template
    private func isTemplateValidForAllChildren(templateId: UUID) -> Bool {
        guard !selectedChildIds.isEmpty else { return false }
        for cid in selectedChildIds {
            let matches = matchingAssignments(childId: cid, templateId: templateId)
            if matches.count != 1 { return false }
        }
        return true
    }

    private var validTemplates: [EventTemplate] {
        let base = appState.eventTemplates.filter { tpl in
            isTemplateValidForAllChildren(templateId: tpl.id)
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            return base.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }

        return base
            .filter { $0.title.localizedCaseInsensitiveContains(q) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        List {
            Button {
                selectedTemplateId = nil
                dismiss()
            } label: {
                HStack {
                    Text("None")
                    Spacer()
                    if selectedTemplateId == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Section("Events") {
                if validTemplates.isEmpty {
                    Text("No events are available for all selected children.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(validTemplates) { tpl in
                        Button {
                            selectedTemplateId = tpl.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                TaskEmojiIconView(icon: tpl.iconSymbol, size: 22)
                                Text(tpl.title)
                                    .font(.headline)
                                Spacer()
                                if selectedTemplateId == tpl.id {
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
}
