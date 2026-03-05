//
// SharedTaskAssignmentRow.swift
// parent_child_checklist
//
// Reusable task row for both parent and child lists.
// Child screens do NOT attach any swipe actions to this row.
//

import SwiftUI

struct SharedTaskAssignmentRow: View {
    let assignment: TaskAssignment
    let selectedDate: Date
    let isCompleted: Bool
    let onToggleComplete: () -> Void

    /// Optional: completion (for the *selected day*) if it exists.
    /// When present and `hasPhotoEvidence == true`, we show a small "View" button
    /// alongside the camera icon on the time row.
    var completionForSelectedDay: TaskCompletionRecord? = nil

    /// Optional: handler invoked when the user taps "View" (photo evidence).
    var onViewPhoto: (() -> Void)? = nil

    /// When false, the checkmark button is disabled (read-only view).
    var isInteractive: Bool = true

    // MARK: - Layout & visual tokens
    private let leftColumnWidth: CGFloat = 56      // radio + spacing + emoji; keeps titles aligned
    private let radioSize: CGFloat = 24
    private let emojiSize: CGFloat = 22
    private let spacingAfterRadio: CGFloat = 8
    private let rowVerticalPadding: CGFloat = 8    // inner content padding (list adds extra padding for divider)

    // Secondary/meta styling tuned for readability on dark cards
    private let metaColor = Color.white.opacity(0.78)
    private let gemColor = Color.accentColor.opacity(0.96) // clear but not louder than the title

    // MARK: - Accents
    private let magenta = Color(red: 1.0, green: 0.0, blue: 1.0) // used for the ring when NOT selected
    private let selectedGreen = Color.green                       // used when selected

    // Subtle press feedback (row-level)
    @GestureState private var isPressing: Bool = false

    private var dimmed: Bool { !assignment.isActive }

    // MARK: - Time summary (unchanged logic)
    private var timeSummary: String? {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        var parts: [String] = []
        if let start = assignment.startTime {
            parts.append("⏰ \(timeFormatter.string(from: start))")
        }
        if let finish = assignment.finishTime {
            parts.append("→ \(timeFormatter.string(from: finish))")
        }
        if let dur = assignment.durationMinutes, dur > 0 {
            let h = dur / 60
            let m = dur % 60
            if h > 0 && m > 0 { parts.append("⏳ \(h)h \(m)m") }
            else if h > 0 { parts.append("⏳ \(h)h") }
            else { parts.append("⏳ \(m)m") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private var hasPhotoForThisDay: Bool {
        (completionForSelectedDay?.hasPhotoEvidence ?? false)
    }

    var body: some View {
        // Extra breathing room between left column and title
        HStack(alignment: .top, spacing: 16) {

            // LEFT COLUMN (fixed width): radio + emoji
            ZStack(alignment: .leading) {
                HStack(spacing: spacingAfterRadio) {
                    radioButton
                        .onTapGesture {
                            guard isInteractive else { return }
                            onToggleComplete()
                        }
                        .padding(.top, 2) // slight optical nudge to center with emoji

                    Text(assignment.taskIcon)
                        .font(.system(size: emojiSize))
                        .frame(width: 30, height: 30)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: leftColumnWidth, alignment: .leading)
            .padding(.trailing, 4) // extra breathing room before the title

            // MIDDLE: title + helper + meta
            VStack(alignment: .leading, spacing: 6) {

                // Title row
                HStack(spacing: 10) {
                    Text(assignment.taskTitle)
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.92, green: 0.97, blue: 1.00)) // frosted white for strong contrast
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Spacer(minLength: 8)

                    if assignment.rewardPoints > 0 {
                        HStack(spacing: 4) {
                            Text("💎")
                                .font(.subheadline)
                            Text("\(assignment.rewardPoints)")
                                .font(.subheadline).fontWeight(.semibold)
                        }
                        .foregroundStyle(gemColor)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(assignment.rewardPoints) gems")
                    }
                }

                // Helper (optional)
                if let helper = assignment.helper,
                   !helper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(helper)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Time row / camera / "View"
                if assignment.photoEvidenceRequired || timeSummary != nil || hasPhotoForThisDay {
                    HStack(spacing: 10) {

                        if let timeSummary {
                            Text(timeSummary)
                                .font(.footnote)
                                .foregroundStyle(metaColor)
                        }

                        if assignment.photoEvidenceRequired {
                            Image(systemName: "camera.fill")
                                .font(.footnote)
                                .foregroundStyle(metaColor)
                                .accessibilityLabel("Photo required")
                        }

                        if hasPhotoForThisDay {
                            Button {
                                onViewPhoto?()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo")
                                    Text("View")
                                }
                                .font(.footnote).fontWeight(.semibold)
                            }
                            .buttonStyle(.bordered)
                            .tint(.accentColor)
                            .accessibilityLabel("View photo evidence")
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.vertical, rowVerticalPadding)
        // Subtle press feedback
        .scaleEffect(isPressing ? 0.99 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.95), value: isPressing)
        .gesture(
            LongPressGesture(minimumDuration: 0.01)
                .updating($isPressing) { value, state, _ in
                    state = value
                }
        )
        .opacity(dimmed ? 0.55 : (isInteractive ? 1.0 : 0.80))
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }

    // MARK: - Radio glyph (magenta when not selected; green + white tick when selected)
    private var radioButton: some View {
        // Colors depend on state
        let ringColor = isCompleted ? selectedGreen : magenta
        // Keep the fill subtle; switch to green when selected so the control reads "on"
        let fillColor: Color = isCompleted ? selectedGreen.opacity(0.25) : .clear

        return Circle()
            .strokeBorder(ringColor, lineWidth: 2)
            .background(Circle().fill(fillColor))
            .frame(width: radioSize, height: radioSize)
            .overlay {
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)        // white tick (as requested)
                }
            }
            .accessibilityLabel(isCompleted ? "Completed" : "Not completed")
            .accessibilityAddTraits(.isButton)
    }
}
