//
//  SharedEventAssignmentRow.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//

//
// SharedEventAssignmentRow.swift
// parent_child_checklist
//
// Reusable event row for both parent and child lists.
// Child screens do NOT attach any swipe actions to this row.
//

import SwiftUI

struct SharedEventAssignmentRow: View {
    let event: EventAssignment

    // MARK: - Layout & visual tokens (mirrors SharedTaskAssignmentRow)
    private let leftColumnWidth: CGFloat = 56   // placeholder "radio" + spacing + emoji; keeps titles aligned
    private let radioSize: CGFloat = 24
    private let emojiSize: CGFloat = 22
    private let spacingAfterRadio: CGFloat = 8
    private let rowVerticalPadding: CGFloat = 8 // inner content padding (list adds extra padding for divider)

    // Secondary/meta styling tuned for readability on dark cards
    private let metaColor = Color.white.opacity(0.78)

    @GestureState private var isPressing: Bool = false

    private var dimmed: Bool { !event.isActive }

    private var timeSummary: String? {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        var parts: [String] = []
        if let start = event.startTime {
            parts.append("⏰ \(timeFormatter.string(from: start))")
        }
        if let finish = event.finishTime {
            parts.append("→ \(timeFormatter.string(from: finish))")
        }
        if let dur = event.durationMinutes, dur > 0 {
            let h = dur / 60
            let m = dur % 60
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
        if mins == 0 { return "🔔 Alert at start time" }
        return "🔔 Alert \(mins) min before"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // LEFT COLUMN (fixed width): radio placeholder + emoji (aligns with task rows)
            ZStack(alignment: .leading) {
                HStack(spacing: spacingAfterRadio) {
                    // Invisible radio placeholder to align emoji with task emoji position
                    Color.clear
                        .frame(width: radioSize, height: radioSize)
                        .accessibilityHidden(true)

                    Text(event.eventIcon)
                        .font(.system(size: emojiSize))
                        .frame(width: 30, height: 30)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: leftColumnWidth, alignment: .leading)

            // MIDDLE: title + helper + meta
            VStack(alignment: .leading, spacing: 6) {

                // Title
                Text(event.eventTitle)
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.92, green: 0.97, blue: 1.00)) // frosted white for strong contrast
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                // Helper (optional)
                if let helper = event.helper,
                   !helper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(helper)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Meta: time, location, alert
                if timeSummary != nil || locationLine != nil || alertLine != nil {
                    HStack(spacing: 10) {
                        if let timeSummary {
                            Text(timeSummary)
                                .font(.footnote)
                                .foregroundStyle(metaColor)
                        }
                        if let locationLine {
                            Text(locationLine)
                                .font(.footnote)
                                .foregroundStyle(metaColor)
                        }
                        if let alertLine {
                            Text(alertLine)
                                .font(.footnote)
                                .foregroundStyle(metaColor)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.vertical, rowVerticalPadding)
        // Subtle press feedback for tactile polish
        .scaleEffect(isPressing ? 0.99 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.95), value: isPressing)
        .gesture(
            LongPressGesture(minimumDuration: 0.01)
                .updating($isPressing) { value, state, _ in
                    state = value
                }
        )
        .opacity(dimmed ? 0.60 : 1.0)
        .contentShape(Rectangle())
    }
}
