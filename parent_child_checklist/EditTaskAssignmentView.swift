import SwiftUI
import UIKit

// MARK: - Futurist theme (shared with Assign)
private enum FuturistTheme {
    static let skyTop     = Color(red: 0.02, green: 0.06, blue: 0.16)   // deep navy
    static let skyBottom  = Color(red: 0.01, green: 0.03, blue: 0.10)
    static let neonAqua   = Color(red: 0.20, green: 0.95, blue: 1.00)   // bright cyan

    static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)
    static let chipBorder    = Color.white.opacity(0.25)
    static let chipDisabled  = Color.white.opacity(0.55)
    static let cardStroke    = Color.white.opacity(0.08)
    static let divider       = Color.white.opacity(0.10)
    static let cardShadow    = Color.black.opacity(0.10)

    static let softRedBase    = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase  = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight   = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
}

// MARK: - Frosted “glass” card (parity with Assign)
private struct FrostedCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var surface: some ShapeStyle {
        reduceTransparency
        ? Color(red: 0.05, green: 0.10, blue: 0.22)
        : Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FuturistTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: FuturistTheme.cardShadow, radius: 6, x: 0, y: 2)
    }
}

// MARK: - Bright cyan separator (stand-alone line, same insets)
private struct BrightLineSeparator: View {
    var leadingInset: CGFloat = 16
    var trailingInset: CGFloat = 14
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
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.horizontal, 12)
        .zIndex(2)
        .accessibilityHidden(true)
    }
}

// MARK: - Top bar pills + “Edit Task” title (same sizing as Assign)
private struct ToolbarPillButton: View {
    let label: String
    var foreground: Color
    var background: Color
    var stroke: Color
    var disabled: Bool = false
    var glow: Bool = false
    var fixedWidth: CGFloat? = 76
    var fixedHeight: CGFloat? = 32
    var action: () -> Void

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .foregroundStyle(foreground)
            .frame(width: fixedWidth, height: fixedHeight)
            .background(Capsule().fill(background))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
            .shadow(color: glow ? background.opacity(0.28) : .clear, radius: glow ? 3 : 0)
            .opacity(disabled ? 0.75 : 1.0)
            .contentShape(Capsule())
            .onTapGesture { if !disabled { action() } }
            .accessibilityAddTraits(.isButton)
    }
}

private struct EditTopBar: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Text("Edit Task")
                .font(.title2.weight(.semibold))
                .foregroundStyle(FuturistTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)

            HStack {
                ToolbarPillButton(
                    label: "Cancel",
                    foreground: .white,
                    background: FuturistTheme.softRedLight,
                    stroke: FuturistTheme.softRedBase.opacity(0.75),
                    action: onCancel
                )
                Spacer(minLength: 12)
                ToolbarPillButton(
                    label: "Save",
                    foreground: canSave ? Color.black.opacity(0.9) : FuturistTheme.textSecondary,
                    background: canSave ? FuturistTheme.softGreenLight : Color.clear,
                    stroke: canSave ? FuturistTheme.softGreenBase.opacity(0.75)
                                    : FuturistTheme.textSecondary.opacity(0.35),
                    disabled: !canSave,
                    glow: canSave,
                    action: onSave
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(Color.clear)
    }
}

// MARK: - Neon toggle + rows + chips
private struct NeonOutlineToggleStyle: ToggleStyle {
    var onTint: Color = FuturistTheme.neonAqua
    var offStroke: Color = FuturistTheme.neonAqua.opacity(0.70)
    var offFill: Color = Color.white.opacity(0.10)
    var knobColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isOn ? onTint : offFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isOn ? Color.clear : offStroke, lineWidth: 1.6)
                    )
                    .frame(width: 50, height: 30)
                Circle()
                    .fill(knobColor)
                    .shadow(color: Color.black.opacity(0.25), radius: 1, x: 0, y: 1)
                    .frame(width: 24, height: 24)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Toggle"))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var titleColor: Color = FuturistTheme.textPrimary

    var body: some View {
        HStack(spacing: 12) {
            Text(title).foregroundStyle(titleColor)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(NeonOutlineToggleStyle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
    }
}

private struct ValueChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(FuturistTheme.textPrimary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.white.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(FuturistTheme.cardStroke, lineWidth: 1))
    }
}

// MARK: - Picker chrome for inline Date/Time (dark + neon)
private struct PickerChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, .dark)
            .tint(FuturistTheme.neonAqua)
    }
}
private extension View { func pickerChrome() -> some View { modifier(PickerChrome()) } }

private struct InlineGraphicalCalendar: View {
    let label: String
    @Binding var date: Date
    let range: PartialRangeFrom<Date>
    var body: some View {
        DatePicker(label, selection: $date, in: range, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .labelsHidden()
            .pickerChrome()
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(FuturistTheme.cardStroke, lineWidth: 1))
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

private struct InlineWheelTimePicker: View {
    let label: String
    @Binding var time: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DatePicker(label, selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .pickerChrome()
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .clipped()
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(FuturistTheme.cardStroke, lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Edit Task
struct EditTaskAssignmentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let original: TaskAssignment

    // Convenience so existing call sites using `assignment:` keep working
    init(assignment: TaskAssignment) { self.original = assignment
        _helperText = State(initialValue: assignment.helper ?? "")
        _rewardPoints = State(initialValue: max(0, assignment.rewardPoints))
        _subtractIfNotCompleted = State(initialValue: assignment.subtractIfNotCompleted)
        _isActive = State(initialValue: assignment.isActive)

        _startDate = State(initialValue: assignment.startDate)
        _finishDateEnabled = State(initialValue: assignment.endDate != nil)
        _finishDate = State(initialValue: assignment.endDate ?? assignment.startDate)

        _occurrence = State(initialValue: assignment.occurrence)
        _selectedWeekdays = State(initialValue: Set(assignment.weekdays))

        let now = Date()
        _startTimeEnabled = State(initialValue: assignment.startTime != nil)
        _startTime = State(initialValue: assignment.startTime ?? now)
        _finishTimeEnabled = State(initialValue: assignment.finishTime != nil)
        _finishTime = State(initialValue: assignment.finishTime ?? now)

        _alertMe = State(initialValue: assignment.alertMe) // persisted; no UI
        _photoEvidence = State(initialValue: assignment.photoEvidenceRequired)

        _startNotifyEnabled = State(initialValue: assignment.startNotifyEnabled)
        _startNotifyRecipient = State(initialValue: assignment.startNotifyRecipient)
        _startNotifyOffsetMinutes = State(initialValue: assignment.startNotifyOffsetMinutes ?? 5)
        _finishNotifyEnabled = State(initialValue: assignment.finishNotifyEnabled)
        _finishNotifyRecipient = State(initialValue: assignment.finishNotifyRecipient)
        _finishNotifyOffsetMinutes = State(initialValue: assignment.finishNotifyOffsetMinutes ?? 0)
    }

    // MARK: - Template & Fields
    @State private var selectedTemplate: TaskTemplate? = nil
    @State private var showSelectTask = false

    @State private var helperText: String
    @State private var rewardPoints: Int
    @State private var subtractIfNotCompleted: Bool
    @State private var isActive: Bool

    // Dates / Occurrence
    @State private var startDate: Date
    @State private var finishDateEnabled: Bool
    @State private var finishDate: Date
    @State private var occurrence: TaskAssignment.Occurrence
    @State private var selectedWeekdays: Set<Int>
    private let weekdayLabels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    // Inline picker toggles
    @State private var showStartDateInline: Bool = false
    @State private var showFinishDateInline: Bool = false
    @State private var showStartTimeInline: Bool = false
    @State private var showFinishTimeInline: Bool = false

    // Time (no Duration)
    @State private var startTimeEnabled: Bool
    @State private var startTime: Date
    @State private var finishTimeEnabled: Bool
    @State private var finishTime: Date

    // Options (alert persisted; no UI)
    @State private var alertMe: Bool
    @State private var photoEvidence: Bool

    // Toast / hint
    @State private var localToastMessage: String? = nil
    @State private var lastClampToastAt: Date = .distantPast
    @State private var skipTodayInfo: String? = nil

    // 🔹 Delete confirmation flag
    @State private var showDeleteConfirm: Bool = false

    // Notify Me (persisted)
    @State private var startNotifyEnabled: Bool
    @State private var startNotifyRecipient: NotifyRecipient
    @State private var startNotifyOffsetMinutes: Int
    @State private var finishNotifyEnabled: Bool
    @State private var finishNotifyRecipient: NotifyRecipient
    @State private var finishNotifyOffsetMinutes: Int

    // Collapsible helper
    @State private var showHelperEditor: Bool = false

    // 🔹 UISegmentedControl appearance backups (for parity with Assign Task)
    @State private var prevSegTitleAttrsNormal: [NSAttributedString.Key: Any]?
    @State private var prevSegTitleAttrsSelected: [NSAttributedString.Key: Any]?
    @State private var prevSelectedTintColor: UIColor?

    // MARK: - Helpers (dates, toasts)
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601); cal.timeZone = .current; return cal
    }
    private func dayOnly(_ d: Date) -> Date { isoCalendar.startOfDay(for: d) }
    private var startDatePickerLowerBound: Date {
        min(dayOnly(Date()), dayOnly(original.startDate))
    }
    private func showLocalToast(_ message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { localToastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) { localToastMessage = nil }
        }
    }
    private func clampToast(_ message: String) {
        let now = Date()
        guard now.timeIntervalSince(lastClampToastAt) > 1.0 else { return }
        lastClampToastAt = now
        showLocalToast(message)
    }

    private func weekdayIndexMondayFirst(for date: Date) -> Int {
        let wd = isoCalendar.component(.weekday, from: date) // 1=Sun ... 7=Sat
        switch wd { case 2: return 0; case 3: return 1; case 4: return 2; case 5: return 3; case 6: return 4; case 7: return 5; default: return 6 }
    }
    private func isTodaySelectedWeekday() -> Bool {
        selectedWeekdays.contains(weekdayIndexMondayFirst(for: startDate))
    }
    private func clampFinishNotBeforeStart() {
        guard startTimeEnabled, finishTimeEnabled else { return }
        if finishTime < startTime { finishTime = startTime }
    }

    // Option‑B: Specified Days + past start time today → bump Start Date +1 day with hint
    private func handlePastTimeOnTodayIfNeeded() {
        guard occurrence == .specifiedDays else { skipTodayInfo = nil; return }
        guard dayOnly(startDate) == dayOnly(Date()) else { skipTodayInfo = nil; return }
        guard isTodaySelectedWeekday() else { skipTodayInfo = nil; return }
        guard startTimeEnabled else { skipTodayInfo = nil; return }

        let nowComps = isoCalendar.dateComponents([.hour, .minute], from: Date())
        let nowKey = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
        let stComps = isoCalendar.dateComponents([.hour, .minute], from: startTime)
        let startKey = (stComps.hour ?? 0) * 60 + (stComps.minute ?? 0)
        guard startKey < nowKey else { skipTodayInfo = nil; return }

        if let next = isoCalendar.date(byAdding: .day, value: 1, to: startDate) {
            startDate = dayOnly(next)
            if finishDateEnabled && dayOnly(finishDate) < dayOnly(startDate) {
                finishDate = startDate
            }
            let df = DateFormatter(); df.calendar = isoCalendar; df.locale = .current
            df.dateStyle = .medium; df.timeStyle = .none
            skipTodayInfo = "Start time has already passed today. First occurrence will be \(df.string(from: startDate))."
        }
    }

    private func enforceNoPastScheduling() {
        let now = Date()
        let today = dayOnly(Date())

        if dayOnly(startDate) < today {
            startDate = today
            if finishDateEnabled && dayOnly(finishDate) < dayOnly(startDate) {
                finishDate = startDate
            }
            clampToast("Start date adjusted to today.")
        }

        if finishDateEnabled && dayOnly(finishDate) < dayOnly(startDate) {
            finishDate = startDate
            clampToast("Finish date adjusted to match start date.")
        }

        let isToday = (dayOnly(startDate) == today)
        if isToday && occurrence != .specifiedDays {
            let nowComps = isoCalendar.dateComponents([.hour, .minute], from: now)
            let nowKey = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
            let sKey = (isoCalendar.component(.hour, from: startTime) * 60) + isoCalendar.component(.minute, from: startTime)
            let fKey = (isoCalendar.component(.hour, from: finishTime) * 60) + isoCalendar.component(.minute, from: finishTime)
            if startTimeEnabled && sKey < nowKey {
                startTime = now; clampToast("Start time adjusted to now.")
            }
            if finishTimeEnabled && fKey < nowKey {
                finishTime = now; clampToast("Finish time adjusted to now.")
            }
        }

        clampFinishNotBeforeStart()
        handlePastTimeOnTodayIfNeeded()
        reconcileSelectedWeekdaysWithAllowed()
    }

    // Allowed weekdays for Specified Days within Start..Finish range
    private var allowedWeekdays: Set<Int> {
        guard finishDateEnabled else { return Set(0..<7) }
        let start = dayOnly(startDate)
        let end = dayOnly(finishDate)
        if end < start { return [] }
        if let diff = isoCalendar.dateComponents([.day], from: start, to: end).day, diff >= 6 {
            return Set(0..<7)
        }
        var set = Set<Int>(); var d = start
        while d <= end {
            set.insert(weekdayIndexMondayFirst(for: d))
            guard let next = isoCalendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return set
    }
    private func allowedHintText(for allowed: Set<Int>) -> String {
        guard finishDateEnabled else { return "Applies on selected weekdays." }
        if allowed.count == 1 {
            let df = DateFormatter(); df.calendar = isoCalendar; df.locale = .current
            df.dateStyle = .medium
            let only = weekdayLabels[allowed.first!]
            return "Only \(only) fits \(df.string(from: startDate))"
        } else {
            let labels = allowed.sorted().map { weekdayLabels[$0] }.joined(separator: ", ")
            return "Allowed days in range: \(labels)"
        }
    }
    private func reconcileSelectedWeekdaysWithAllowed() {
        guard occurrence == .specifiedDays else { return }
        let allowed = allowedWeekdays
        guard !allowed.isEmpty else { return }
        let before = selectedWeekdays
        let after  = before.intersection(allowed)
        if after != before {
            selectedWeekdays = after
            let removed = before.subtracting(after).sorted()
            if !removed.isEmpty {
                let removedLabels = removed.map { weekdayLabels[$0] }.joined(separator: ", ")
                showLocalToast("Removed: \(removedLabels) (not in date range)")
            }
        }
    }

    // MARK: - Formatters
    private func dateString(_ date: Date) -> String {
        let df = DateFormatter(); df.calendar = isoCalendar; df.locale = .current
        df.dateFormat = "EEE, d MMM yyyy"; return df.string(from: date)
    }
    private func timeString(_ date: Date) -> String {
        let df = DateFormatter(); df.calendar = isoCalendar; df.locale = .current
        df.dateStyle = .none; df.timeStyle = .short; return df.string(from: date)
    }

    // MARK: - Save
    private func saveEdits() {
        enforceNoPastScheduling()

        let taskTitle  = selectedTemplate?.title ?? original.taskTitle
        let taskIcon   = selectedTemplate?.iconSymbol ?? original.taskIcon
        let templateId = selectedTemplate?.id ?? original.templateId

        let helper = helperText.trimmingCharacters(in: .whitespacesAndNewlines)
        let helperOrNil = helper.isEmpty ? nil : helper

        let end: Date? = (occurrence == .onceOnly) ? nil : (finishDateEnabled ? finishDate : nil)
        let startTimeValue: Date?  = startTimeEnabled  ? startTime  : nil
        let finishTimeValue: Date? = finishTimeEnabled ? finishTime : nil

        // Notify to persisted
        let persistedStartOffset: Int?  = startNotifyEnabled  ? max(0, startNotifyOffsetMinutes)  : nil
        let persistedFinishOffset: Int? = finishNotifyEnabled ? max(0, finishNotifyOffsetMinutes) : nil

        var updated = original
        updated.templateId = templateId
        updated.taskTitle  = taskTitle
        updated.taskIcon   = taskIcon
        updated.rewardPoints = max(0, rewardPoints)
        updated.helper = helperOrNil
        updated.subtractIfNotCompleted = subtractIfNotCompleted
        updated.alertMe = alertMe
        updated.photoEvidenceRequired = photoEvidence
        updated.isActive = isActive
        updated.startDate = startDate
        updated.endDate   = end
        updated.occurrence = occurrence
        updated.weekdays   = Array(selectedWeekdays).sorted()
        updated.startTime  = startTimeValue
        updated.finishTime = finishTimeValue
        updated.durationMinutes = nil // Duration removed

        updated.startNotifyEnabled = startNotifyEnabled
        updated.startNotifyRecipient = startNotifyRecipient
        updated.startNotifyOffsetMinutes = persistedStartOffset
        updated.finishNotifyEnabled = finishNotifyEnabled
        updated.finishNotifyRecipient = finishNotifyRecipient
        updated.finishNotifyOffsetMinutes = persistedFinishOffset
        updated.updatedAt = Date()

        _ = appState.updateTaskAssignment(updated)

        if updated.isActive {
            NotificationManager.shared.scheduleNext(for: updated, audience: currentAudience())
        } else {
            NotificationManager.shared.cancelAllForTask(id: updated.id)
        }

        dismiss()
    }
    private func currentAudience() -> NotificationAudience { .parent }

    // MARK: - Points row
    @ViewBuilder
    private func pointsStepperRow() -> some View {
        HStack(spacing: 12) {
            Text("💎 Points").foregroundStyle(FuturistTheme.textPrimary)
            Spacer(minLength: 8)

            Button { rewardPoints = max(0, rewardPoints - 1) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FuturistTheme.neonAqua)
                    .shadow(color: FuturistTheme.neonAqua.opacity(0.35), radius: 2)
            }
            .buttonStyle(.plain)
            .disabled(rewardPoints == 0)
            .opacity(rewardPoints == 0 ? 0.6 : 1.0)

            Text("\(rewardPoints)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(FuturistTheme.textPrimary)
                .frame(minWidth: 32, alignment: .center)

            Button { rewardPoints += 1 } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(FuturistTheme.neonAqua)
                    .shadow(color: FuturistTheme.neonAqua.opacity(0.35), radius: 2)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    // MARK: - Weekday chip
    @ViewBuilder
    private func weekdayChipCompact(index: Int, label: String, isSelected: Bool, isAllowed: Bool) -> some View {
        let borderColor: Color = {
            if !isAllowed { return FuturistTheme.cardStroke }
            return isSelected ? FuturistTheme.neonAqua : FuturistTheme.chipBorder
        }()
        let textColor: Color = {
            if !isAllowed { return FuturistTheme.chipDisabled }
            return FuturistTheme.textPrimary
        }()
        let fill: Color = isSelected ? FuturistTheme.neonAqua.opacity(0.18) : .clear

        Text(label)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(textColor)
            .frame(minWidth: 34, minHeight: 24)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(fill))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard isAllowed else { return }
                if isSelected { selectedWeekdays.remove(index) } else { selectedWeekdays.insert(index) }
            }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // 1) TASK
                        FrostedCard {
                            Button { showSelectTask = true } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        let tpl = selectedTemplate
                                        if let tpl {
                                            HStack(spacing: 10) {
                                                TaskEmojiIconView(icon: tpl.iconSymbol, size: 22)
                                                Text(tpl.title)
                                                    .font(.headline)
                                                    .foregroundStyle(FuturistTheme.textPrimary)
                                            }
                                            Text("Tap to change")
                                                .font(.footnote)
                                                .foregroundStyle(FuturistTheme.textSecondary)
                                        } else {
                                            HStack(spacing: 10) {
                                                TaskEmojiIconView(icon: original.taskIcon, size: 22)
                                                Text(original.taskTitle)
                                                    .font(.headline)
                                                    .foregroundStyle(FuturistTheme.textPrimary)
                                            }
                                            Text("Tap to change")
                                                .font(.footnote)
                                                .foregroundStyle(FuturistTheme.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                        .padding(.top, 2)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens task templates")

                            // Collapsible helper
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) { showHelperEditor.toggle() }
                                } label: {
                                    HStack {
                                        if helperText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text("Add helper note").foregroundStyle(FuturistTheme.textSecondary)
                                        } else {
                                            Text("Helper note").foregroundStyle(FuturistTheme.textPrimary)
                                            Spacer()
                                            Text(helperText)
                                                .lineLimit(1)
                                                .foregroundStyle(FuturistTheme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: showHelperEditor ? "chevron.up" : "chevron.down")
                                            .foregroundStyle(FuturistTheme.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)

                                if showHelperEditor {
                                    TextField("Type helper text...", text: $helperText, axis: .vertical)
                                        .lineLimit(4, reservesSpace: true)
                                        .textInputAutocapitalization(.sentences)
                                        .submitLabel(.done)
                                        .foregroundStyle(FuturistTheme.textPrimary)
                                    HStack {
                                        Spacer()
                                        if !helperText.isEmpty {
                                            Button("Clear") { helperText.removeAll() }
                                                .font(.footnote)
                                                .foregroundStyle(FuturistTheme.textSecondary)
                                        }
                                    }
                                }
                            }

                            ToggleRow(title: "Active", isOn: $isActive, titleColor: FuturistTheme.textSecondary)
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 2) REWARD POINTS
                        FrostedCard {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .center, spacing: 12) {
                                    pointsStepperRow()
                                    Rectangle().fill(FuturistTheme.divider)
                                        .frame(width: 1, height: 24)
                                        .accessibilityHidden(true)
                                    ToggleRow(title: "Subtract points if not completed", isOn: $subtractIfNotCompleted)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    pointsStepperRow()
                                    ToggleRow(title: "Subtract points if not completed", isOn: $subtractIfNotCompleted)
                                }
                            }
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 3) DATES (inline graphical)
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        showStartDateInline.toggle()
                                        if showStartDateInline {
                                            showFinishDateInline = false
                                            showStartTimeInline = false
                                            showFinishTimeInline = false
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text("Start Date").foregroundStyle(FuturistTheme.textPrimary)
                                        Spacer()
                                        ValueChip(text: dateString(startDate))
                                    }
                                }
                                .buttonStyle(.plain)

                                if showStartDateInline {
                                    InlineGraphicalCalendar(label: "Start Date", date: $startDate, range: startDatePickerLowerBound...)
                                        .onChange(of: startDate) { _, _ in enforceNoPastScheduling() }
                                }

                                ToggleRow(title: "Finish Date", isOn: $finishDateEnabled)
                                    .onChange(of: finishDateEnabled) { _, enabled in
                                        if !enabled {
                                            withAnimation(.easeInOut(duration: 0.18)) { showFinishDateInline = false }
                                        }
                                        enforceNoPastScheduling()
                                    }

                                if finishDateEnabled {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            showFinishDateInline.toggle()
                                            if showFinishDateInline {
                                                showStartDateInline = false
                                                showStartTimeInline = false
                                                showFinishTimeInline = false
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text("Finish Date").foregroundStyle(FuturistTheme.textPrimary)
                                            Spacer()
                                            ValueChip(text: dateString(finishDate))
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if showFinishDateInline {
                                        InlineGraphicalCalendar(label: "Finish Date", date: $finishDate, range: startDate...)
                                            .onChange(of: finishDate) { _, _ in enforceNoPastScheduling() }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 4) OCCURRENCE (segmented + weekday chips)
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Occurrence", selection: $occurrence) {
                                    ForEach(TaskAssignment.Occurrence.allCases) { opt in
                                        Text(opt.displayName).tag(opt)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: occurrence) { _, newValue in
                                    if newValue == .onceOnly {
                                        finishDateEnabled = false
                                        withAnimation(.easeInOut(duration: 0.18)) { showFinishDateInline = false }
                                    }
                                    enforceNoPastScheduling()
                                }

                                if occurrence == .specifiedDays {
                                    let allowed = allowedWeekdays
                                    HStack(spacing: 6) {
                                        ForEach(0..<7, id: \.self) { idx in
                                            weekdayChipCompact(
                                                index: idx,
                                                label: weekdayLabels[idx],
                                                isSelected: selectedWeekdays.contains(idx),
                                                isAllowed: allowed.contains(idx)
                                            )
                                        }
                                    }
                                    .onChange(of: selectedWeekdays) { _, _ in enforceNoPastScheduling() }

                                    Text(allowedHintText(for: allowed))
                                        .font(.footnote)
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                }
                            }
                            .foregroundStyle(FuturistTheme.textPrimary)
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 5) TIME (inline wheels + notify)
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                ToggleRow(title: "Start Time", isOn: $startTimeEnabled)
                                    .onChange(of: startTimeEnabled) { _, enabled in
                                        if !enabled {
                                            withAnimation(.easeInOut(duration: 0.18)) { showStartTimeInline = false }
                                            startNotifyEnabled = false
                                            skipTodayInfo = nil
                                        } else {
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                showStartDateInline = false
                                                showFinishDateInline = false
                                                showFinishTimeInline = false
                                            }
                                        }
                                        enforceNoPastScheduling()
                                    }

                                if startTimeEnabled {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            showStartTimeInline.toggle()
                                            if showStartTimeInline {
                                                showStartDateInline = false
                                                showFinishDateInline = false
                                                showFinishTimeInline = false
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text("Start Time").foregroundStyle(FuturistTheme.textPrimary)
                                            Spacer()
                                            ValueChip(text: timeString(startTime))
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if showStartTimeInline {
                                        InlineWheelTimePicker(label: "Start Time", time: $startTime)
                                            .onChange(of: startTime) { _, _ in enforceNoPastScheduling() }
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        ToggleRow(title: "Notify Me", isOn: $startNotifyEnabled)
                                        if startNotifyEnabled {
                                            Picker("Who", selection: $startNotifyRecipient) {
                                                ForEach(NotifyRecipient.allCases) { Text($0.displayName).tag($0) }
                                            }
                                            .pickerStyle(.segmented)

                                            Picker("When", selection: $startNotifyOffsetMinutes) {
                                                ForEach([("At time",0),("5 min before",5),("10 min before",10),
                                                         ("15 min before",15),("30 min before",30),
                                                         ("1 hour before",60),("2 hours before",120)], id: \.1) {
                                                    Text($0.0).tag($0.1)
                                                }
                                            }

                                            if let msg = skipTodayInfo {
                                                Text(msg).font(.footnote).foregroundStyle(FuturistTheme.textSecondary)
                                            }
                                        }
                                    }
                                }

                                Rectangle().fill(FuturistTheme.divider).frame(height: 1).accessibilityHidden(true)

                                ToggleRow(title: "Finish Time", isOn: $finishTimeEnabled)
                                    .onChange(of: finishTimeEnabled) { _, enabled in
                                        if !enabled {
                                            withAnimation(.easeInOut(duration: 0.18)) { showFinishTimeInline = false }
                                            finishNotifyEnabled = false
                                        } else {
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                showStartDateInline = false
                                                showFinishDateInline = false
                                                showStartTimeInline = false
                                            }
                                        }
                                        enforceNoPastScheduling()
                                    }

                                if finishTimeEnabled {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            showFinishTimeInline.toggle()
                                            if showFinishTimeInline {
                                                showStartDateInline = false
                                                showFinishDateInline = false
                                                showStartTimeInline = false
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text("Finish Time").foregroundStyle(FuturistTheme.textPrimary)
                                            Spacer()
                                            ValueChip(text: timeString(finishTime))
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if showFinishTimeInline {
                                        InlineWheelTimePicker(label: "Finish Time", time: $finishTime)
                                            .onChange(of: finishTime) { _, _ in enforceNoPastScheduling() }
                                    }

                                    VStack(alignment: .leading, spacing: 8) {
                                        ToggleRow(title: "Notify Me", isOn: $finishNotifyEnabled)
                                        if finishNotifyEnabled {
                                            Picker("Who", selection: $finishNotifyRecipient) {
                                                ForEach(NotifyRecipient.allCases) { Text($0.displayName).tag($0) }
                                            }
                                            .pickerStyle(.segmented)

                                            Picker("When", selection: $finishNotifyOffsetMinutes) {
                                                ForEach([("At time",0),("5 min before",5),("10 min before",10),
                                                         ("15 min before",15),("30 min before",30),
                                                         ("1 hour before",60),("2 hours before",120)], id: \.1) {
                                                    Text($0.0).tag($0.1)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 6) OPTIONS
                        FrostedCard {
                            ToggleRow(title: "Photo Evidence", isOn: $photoEvidence)
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 7) DELETE
                        FrostedCard {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash").font(.body.weight(.semibold))
                                    Text("Delete Assignment")
                                        .font(.body.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)

                        Spacer(minLength: 12)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                if let msg = localToastMessage {
                    ToastBannerView(message: msg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            // Hide system nav; we draw our own header
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // Custom top bar
            .safeAreaInset(edge: .top, spacing: 0) {
                EditTopBar(
                    canSave: true,  // tighten if desired
                    onCancel: { dismiss() },
                    onSave: { saveEdits() }
                )
                .background(Color.clear)
            }

            // Template picker
            .navigationDestination(isPresented: $showSelectTask) {
                SelectTaskTemplateView(
                    selectedTemplateId: selectedTemplate?.id ?? original.templateId,
                    onPick: { picked in
                        selectedTemplate = picked
                        rewardPoints = max(0, picked.rewardPoints)
                    }
                )
                .environmentObject(appState)
            }

            // ✨ Match Assign Task segmented styling, scoped to this screen
            .onAppear {
                enforceNoPastScheduling()
                handlePastTimeOnTodayIfNeeded()

                // Backup current UISegmentedControl appearance
                prevSegTitleAttrsNormal   = UISegmentedControl.appearance().titleTextAttributes(for: .normal)
                prevSegTitleAttrsSelected = UISegmentedControl.appearance().titleTextAttributes(for: .selected)
                prevSelectedTintColor     = UISegmentedControl.appearance().selectedSegmentTintColor

                // Selected segment: dark text on white pill
                let selectedTitleAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(Color(red: 0.08, green: 0.14, blue: 0.24)),
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
                ]
                // Unselected segment: bright, readable light text
                let normalTitleAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(FuturistTheme.textPrimary.opacity(0.92)),
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
                ]
                UISegmentedControl.appearance().setTitleTextAttributes(normalTitleAttrs, for: .normal)
                UISegmentedControl.appearance().setTitleTextAttributes(selectedTitleAttrs, for: .selected)
                UISegmentedControl.appearance().selectedSegmentTintColor = .white
            }
            .onDisappear {
                // Restore previous appearance so other screens are unaffected
                if let prev = prevSegTitleAttrsNormal   { UISegmentedControl.appearance().setTitleTextAttributes(prev, for: .normal) }
                if let prev = prevSegTitleAttrsSelected { UISegmentedControl.appearance().setTitleTextAttributes(prev, for: .selected) }
                if let prev = prevSelectedTintColor     { UISegmentedControl.appearance().selectedSegmentTintColor = prev }
            }

            .alert("Delete this assignment?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    NotificationManager.shared.cancelAllForTask(id: original.id)
                    appState.deleteTaskAssignment(id: original.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the assignment (and its completion ticks).")
            }
        }
    }
}
