import SwiftUI
import UIKit

// MARK: - Futurist theme (shared with Edit/Assign Task)
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

// MARK: - Frosted card + filament
private struct FrostedCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var surface: some ShapeStyle {
        reduceTransparency ? Color(red: 0.05, green: 0.10, blue: 0.22)
                           : Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(FuturistTheme.cardStroke, lineWidth: 1))
            .shadow(color: FuturistTheme.cardShadow, radius: 6, x: 0, y: 2)
    }
}

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
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: thickness)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.horizontal, 12)
        .accessibilityHidden(true)
    }
}

// MARK: - Top bar (“Edit Event”) + pills
private struct ToolbarPillButton: View {
    let label: String
    var foreground: Color
    var background: Color
    var stroke: Color
    var disabled: Bool = false
    var glow: Bool = false
    var width: CGFloat = 76
    var height: CGFloat = 32
    var action: () -> Void
    var body: some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .foregroundStyle(foreground)
            .frame(width: width, height: height)
            .background(Capsule().fill(background))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
            .shadow(color: glow ? background.opacity(0.28) : .clear, radius: glow ? 3 : 0)
            .opacity(disabled ? 0.75 : 1)
            .contentShape(Capsule())
            .onTapGesture { if !disabled { action() } }
            .accessibilityAddTraits(.isButton)
    }
}

private struct EditEventTopBar: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    var body: some View {
        ZStack {
            Text("Edit Event")
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

// MARK: - Controls (toggle, chips, chips/tint)
private struct NeonOutlineToggleStyle: ToggleStyle {
    var onTint: Color = FuturistTheme.neonAqua
    var offStroke: Color = FuturistTheme.neonAqua.opacity(0.70)
    var offFill: Color = Color.white.opacity(0.10)
    var knobColor: Color = .white
    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) { configuration.isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isOn ? onTint : offFill)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isOn ? Color.clear : offStroke, lineWidth: 1.6))
                    .frame(width: 50, height: 30)
                Circle()
                    .fill(knobColor)
                    .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
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

// MARK: - Picker chrome (dark scheme + neon tint)
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
            .transition(.opacity .combined(with: .move(edge: .top)))
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
        .transition(.opacity .combined(with: .move(edge: .top)))
    }
}

// MARK: - Edit Event (drop‑in)
struct EditEventAssignmentView: View {
    // Environment
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Input
    let original: EventAssignment

    // Event template selection
    @State private var selectedTemplate: EventTemplate? = nil
    @State private var showSelectEvent = false

    // Fields
    @State private var helperText: String
    @State private var isActive: Bool

    // Location (optional)
    @State private var selectedLocationId: UUID?
    @State private var selectedLocationNameSnapshot: String
    @State private var showLocationPicker = false

    // Dates
    @State private var startDate: Date
    @State private var finishDateEnabled: Bool
    @State private var finishDate: Date

    // Occurrence
    @State private var occurrence: EventAssignment.Occurrence
    @State private var selectedWeekdays: Set<Int>
    private let weekdayLabels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    // Inline picker toggles
    @State private var showStartDateInline: Bool = false
    @State private var showFinishDateInline: Bool = false
    @State private var showStartTimeInline: Bool = false
    @State private var showFinishTimeInline: Bool = false

    // Times (no Duration in UI)
    @State private var startTimeEnabled: Bool
    @State private var startTime: Date
    @State private var finishTimeEnabled: Bool
    @State private var finishTime: Date

    // Legacy alert (persisted; no UI)
    @State private var alertMe: Bool
    @State private var alertOffsetMinutes: Int

    // Delete + toast
    @State private var showDeleteConfirm = false
    @State private var localToastMessage: String? = nil

    // Notify Me (persisted)
    @State private var startNotifyEnabled: Bool
    @State private var startNotifyRecipient: NotifyRecipient
    @State private var startNotifyOffsetMinutes: Int
    @State private var finishNotifyEnabled: Bool
    @State private var finishNotifyRecipient: NotifyRecipient
    @State private var finishNotifyOffsetMinutes: Int

    private let notifyOffsetOptions: [(label: String, minutes: Int)] = [
        ("At time", 0), ("5 min before", 5), ("10 min before", 10),
        ("15 min before", 15), ("30 min before", 30),
        ("1 hour before", 60), ("2 hours before", 120)
    ]

    // Inline hint for Option‑B (bump to tomorrow)
    @State private var skipTodayInfo: String? = nil

    // Segmented control appearance backups (readability parity with Task screens)
    @State private var prevSegTitleAttrsNormal: [NSAttributedString.Key: Any]?
    @State private var prevSegTitleAttrsSelected: [NSAttributedString.Key: Any]?
    @State private var prevSelectedTintColor: UIColor?

    // MARK: - Init
    init(assignment: EventAssignment) {
        self.original = assignment

        _helperText = State(initialValue: assignment.helper ?? "")
        _isActive    = State(initialValue: assignment.isActive)

        _selectedLocationId           = State(initialValue: assignment.locationId)
        _selectedLocationNameSnapshot = State(initialValue: assignment.locationNameSnapshot)

        _startDate        = State(initialValue: assignment.startDate)
        _finishDateEnabled = State(initialValue: assignment.endDate != nil)
        _finishDate       = State(initialValue: assignment.endDate ?? assignment.startDate)

        _occurrence       = State(initialValue: assignment.occurrence)
        _selectedWeekdays = State(initialValue: Set(assignment.weekdays))

        let now = Date()
        _startTimeEnabled = State(initialValue: assignment.startTime != nil)
        _startTime        = State(initialValue: assignment.startTime ?? now)
        _finishTimeEnabled = State(initialValue: assignment.finishTime != nil)
        _finishTime        = State(initialValue: assignment.finishTime ?? now)

        // Duration removed from UI (we will persist nil on save)

        _alertMe            = State(initialValue: assignment.alertMe)
        _alertOffsetMinutes = State(initialValue: assignment.alertOffsetMinutes ?? 10)

        _startNotifyEnabled        = State(initialValue: assignment.startNotifyEnabled)
        _startNotifyRecipient      = State(initialValue: assignment.startNotifyRecipient)
        _startNotifyOffsetMinutes  = State(initialValue: assignment.startNotifyOffsetMinutes ?? 5)
        _finishNotifyEnabled       = State(initialValue: assignment.finishNotifyEnabled)
        _finishNotifyRecipient     = State(initialValue: assignment.finishNotifyRecipient)
        _finishNotifyOffsetMinutes = State(initialValue: assignment.finishNotifyOffsetMinutes ?? 0)
    }

    // MARK: - Helpers
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601); cal.timeZone = .current; return cal
    }
    private func dayOnly(_ date: Date) -> Date { isoCalendar.startOfDay(for: date) }

    private var startDatePickerLowerBound: Date {
        // allow choosing the original past date as lower bound
        min(dayOnly(Date()), dayOnly(original.startDate))
    }

    // Monday‑first weekday index helper: 0=Mon ... 6=Sun
    private func weekdayIndexMondayFirst(for date: Date) -> Int {
        switch isoCalendar.component(.weekday, from: date) {
        case 2: return 0; case 3: return 1; case 4: return 2; case 5: return 3; case 6: return 4; case 7: return 5
        default: return 6
        }
    }
    private func isTodaySelectedWeekday() -> Bool {
        selectedWeekdays.contains(weekdayIndexMondayFirst(for: startDate))
    }

    private func showLocalToast(_ message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { localToastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) { localToastMessage = nil }
        }
    }

    /// Keep finish time ≥ start time when both enabled.
    private func clampFinishNotBeforeStart() {
        guard startTimeEnabled, finishTimeEnabled else { return }
        if finishTime < startTime { finishTime = startTime }
    }

    // Option‑B: Specified Days + past start time today → bump Start Date +1 day with hint
    private func handlePastTimeOnTodayIfNeeded() {
        guard occurrence == .specifiedDays else { skipTodayInfo = nil; return }
        let today = dayOnly(Date())
        guard dayOnly(startDate) == today else { skipTodayInfo = nil; return }
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

    // Allowed weekdays in Start..Finish range
    private var allowedWeekdays: Set<Int> {
        guard finishDateEnabled else { return Set(0..<7) }
        let start = dayOnly(startDate), end = dayOnly(finishDate)
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
        let after = before.intersection(allowed)
        if after != before {
            selectedWeekdays = after
            let removed = before.subtracting(after).sorted()
            if !removed.isEmpty {
                let removedLabels = removed.map { weekdayLabels[$0] }.joined(separator: ", ")
                showLocalToast("Removed: \(removedLabels) (not in date range)")
            }
        }
    }

    // MARK: - Enforcement (Edit-mode friendly)
    private func enforceNoPastScheduling() {
        let now = Date()
        let today = dayOnly(Date())

        // ❌ Removed: automatic clamping of past Start Date to today (and its toast).

        // Keep finish date ≥ start date
        if finishDateEnabled && dayOnly(finishDate) < dayOnly(startDate) {
            finishDate = startDate
            showLocalToast("Finish date adjusted to match start date.")
        }

        // Same-day time sanity checks (only if not Specified Days)
        let isToday = (dayOnly(startDate) == today)
        if isToday && occurrence != .specifiedDays {
            let nowComps = isoCalendar.dateComponents([.hour, .minute], from: now)
            let nowKey = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
            let sKey = (isoCalendar.component(.hour, from: startTime) * 60) + isoCalendar.component(.minute, from: startTime)
            let fKey = (isoCalendar.component(.hour, from: finishTime) * 60) + isoCalendar.component(.minute, from: finishTime)
            if startTimeEnabled && sKey < nowKey { startTime = now; showLocalToast("Start time adjusted to now.") }
            if finishTimeEnabled && fKey < nowKey { finishTime = now; showLocalToast("Finish time adjusted to now.") }
        }

        clampFinishNotBeforeStart()
        handlePastTimeOnTodayIfNeeded()
        reconcileSelectedWeekdaysWithAllowed()
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

    // MARK: - Save (persist Notify + schedule)
    private func saveEdits() {
        enforceNoPastScheduling()

        let eventTitle  = selectedTemplate?.title ?? original.eventTitle
        let eventIcon   = selectedTemplate?.iconSymbol ?? original.eventIcon
        let templateId  = selectedTemplate?.id ?? original.templateId

        let helper = helperText.trimmingCharacters(in: .whitespacesAndNewlines)
        let helperOrNil = helper.isEmpty ? nil : helper

        let end: Date? = (occurrence == .onceOnly) ? nil : (finishDateEnabled ? finishDate : nil)
        let weekdays = Array(selectedWeekdays).sorted()

        let startTimeValue: Date?  = startTimeEnabled  ? startTime  : nil
        let finishTimeValue: Date? = finishTimeEnabled ? finishTime : nil

        // Notify persistence
        let persistedStartOffset: Int?  = startNotifyEnabled  ? max(0, startNotifyOffsetMinutes)  : nil
        let persistedFinishOffset: Int? = finishNotifyEnabled ? max(0, finishNotifyOffsetMinutes) : nil

        var updated = original
        updated.templateId = templateId
        updated.eventTitle = eventTitle
        updated.eventIcon  = eventIcon
        updated.helper = helperOrNil
        updated.isActive = isActive
        updated.startDate = startDate
        updated.endDate   = end
        updated.occurrence = occurrence
        updated.weekdays   = weekdays
        updated.startTime  = startTimeValue
        updated.finishTime = finishTimeValue

        // ❌ Duration removed
        updated.durationMinutes = nil

        updated.locationId = selectedLocationId
        updated.locationNameSnapshot = selectedLocationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)

        // Legacy alert values persisted as-is (no UI here)
        updated.alertMe = alertMe
        updated.alertOffsetMinutes = alertMe ? max(0, alertOffsetMinutes) : nil

        // Notify
        updated.startNotifyEnabled = startNotifyEnabled
        updated.startNotifyRecipient = startNotifyRecipient
        updated.startNotifyOffsetMinutes = persistedStartOffset
        updated.finishNotifyEnabled = finishNotifyEnabled
        updated.finishNotifyRecipient = finishNotifyRecipient
        updated.finishNotifyOffsetMinutes = persistedFinishOffset

        updated.updatedAt = Date()

        _ = appState.updateEventAssignment(updated)

        if updated.isActive {
            NotificationManager.shared.scheduleNext(for: updated, audience: currentAudience())
        } else {
            NotificationManager.shared.cancelAllForEvent(id: updated.id)
        }

        dismiss()
    }

    private func currentAudience() -> NotificationAudience { .parent }

    // MARK: - Weekday chip
    @ViewBuilder
    private func weekdayChipCompact(index: Int, label: String, isSelected: Bool, isAllowed: Bool) -> some View {
        let borderColor: Color = { if !isAllowed { return FuturistTheme.cardStroke }
                                   return isSelected ? FuturistTheme.neonAqua : FuturistTheme.chipBorder }()

        let textColor: Color = { if !isAllowed { return FuturistTheme.chipDisabled }
                                 return FuturistTheme.textPrimary }()

        let fill: Color = isSelected ? FuturistTheme.neonAqua.opacity(0.18) : .clear

        Text(label)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(textColor)
            .frame(minWidth: 34, minHeight: 24)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(borderColor, lineWidth: isSelected ? 2 : 1))
            .contentShape(Rectangle())
            .onTapGesture {
                guard isAllowed else { return }
                if isSelected { selectedWeekdays.remove(index) } else { selectedWeekdays.insert(index) }
            }
    }

    // MARK: - Body
    private var canSave: Bool { (selectedTemplate != nil) || !original.eventTitle.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // 1) EVENT (template, helper, active)
                        FrostedCard {
                            Button { showSelectEvent = true } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let tpl = selectedTemplate {
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
                                                TaskEmojiIconView(icon: original.eventIcon, size: 22)
                                                Text(original.eventTitle)
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
                            .accessibilityHint("Opens event templates")

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
                                            Text(helperText).lineLimit(1).foregroundStyle(FuturistTheme.textSecondary)
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

                        // 2) LOCATION (Optional)
                        FrostedCard {
                            Button { showLocationPicker = true } label: {
                                HStack {
                                    Text("Location (Optional)").foregroundStyle(FuturistTheme.textPrimary)
                                    Spacer()
                                    let displayName = selectedLocationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                                    Text(displayName.isEmpty ? "None" : displayName)
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 3) DATES
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

                        // 4) OCCURRENCE
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Picker("Occurrence", selection: $occurrence) {
                                    ForEach(EventAssignment.Occurrence.allCases) { opt in
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

                        // 5) TIME + NOTIFY
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                // START TIME
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

                                    // Notify (Start)
                                    VStack(alignment: .leading, spacing: 8) {
                                        ToggleRow(title: "Notify Me", isOn: $startNotifyEnabled)
                                        if startNotifyEnabled {
                                            Picker("Who", selection: $startNotifyRecipient) {
                                                ForEach(NotifyRecipient.allCases) { Text($0.displayName).tag($0) }
                                            }
                                            .pickerStyle(.segmented)

                                            Picker("When", selection: $startNotifyOffsetMinutes) {
                                                ForEach(notifyOffsetOptions, id: \.minutes) { Text($0.label).tag($0.minutes) }
                                            }

                                            if let msg = skipTodayInfo {
                                                Text(msg).font(.footnote).foregroundStyle(FuturistTheme.textSecondary)
                                            }
                                        }
                                    }
                                }

                                Rectangle().fill(FuturistTheme.divider).frame(height: 1).accessibilityHidden(true)

                                // FINISH TIME
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

                                    // Notify (Finish)
                                    VStack(alignment: .leading, spacing: 8) {
                                        ToggleRow(title: "Notify Me", isOn: $finishNotifyEnabled)
                                        if finishNotifyEnabled {
                                            Picker("Who", selection: $finishNotifyRecipient) {
                                                ForEach(NotifyRecipient.allCases) { Text($0.displayName).tag($0) }
                                            }
                                            .pickerStyle(.segmented)

                                            Picker("When", selection: $finishNotifyOffsetMinutes) {
                                                ForEach(notifyOffsetOptions, id: \.minutes) { Text($0.label).tag($0.minutes) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 6) DELETE (High-contrast pill)
                        FrostedCard {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash.fill")
                                        .font(.body.weight(.semibold))
                                    Text("Delete Event Assignment")
                                        .font(.body.weight(.semibold))
                                }
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.vertical, 2) // slight cushion inside the pill
                                .background(Capsule().fill(FuturistTheme.softRedBase))
                                .overlay(
                                    Capsule()
                                        .stroke(FuturistTheme.softRedLight.opacity(0.95), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                                .contentShape(Rectangle())
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
            // Hide system nav bar; we draw our own header
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // ✅ Custom top bar with a 12‑pt cushion so pills don’t hug the sheet’s top radius
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 12) // ← cushion
                    EditEventTopBar(
                        canSave: canSave,
                        onCancel: { dismiss() },
                        onSave: { if canSave { saveEdits() } }
                    )
                }
                .background(Color.clear)
            }

            // Destinations / Sheets
            .navigationDestination(isPresented: $showSelectEvent) {
                SelectEventTemplateView(
                    selectedTemplateId: selectedTemplate?.id ?? original.templateId,
                    onPick: { picked in selectedTemplate = picked }
                )
                .environmentObject(appState)
            }
            .sheet(isPresented: $showLocationPicker) {
                NavigationStack {
                    SelectLocationView(
                        selectedLocationId: $selectedLocationId,
                        selectedLocationNameSnapshot: $selectedLocationNameSnapshot
                    )
                    .environmentObject(appState)
                }
            }

            // Segmented control readability (parity with Task screens)
            .onAppear {
                // ⛔️ Removed automatic enforcement on appear to avoid altering stored past dates
                // enforceNoPastScheduling()
                // handlePastTimeOnTodayIfNeeded()

                prevSegTitleAttrsNormal   = UISegmentedControl.appearance().titleTextAttributes(for: .normal)
                prevSegTitleAttrsSelected = UISegmentedControl.appearance().titleTextAttributes(for: .selected)
                prevSelectedTintColor     = UISegmentedControl.appearance().selectedSegmentTintColor

                // Selected: dark text on white pill
                let selectedTitleAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(Color(red: 0.08, green: 0.14, blue: 0.24)),
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
                ]
                // Unselected: bright, readable light text
                let normalTitleAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(FuturistTheme.textPrimary.opacity(0.92)),
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
                ]
                UISegmentedControl.appearance().setTitleTextAttributes(normalTitleAttrs, for: .normal)
                UISegmentedControl.appearance().setTitleTextAttributes(selectedTitleAttrs, for: .selected)
                UISegmentedControl.appearance().selectedSegmentTintColor = .white
            }
            .onDisappear {
                if let prev = prevSegTitleAttrsNormal   { UISegmentedControl.appearance().setTitleTextAttributes(prev, for: .normal) }
                if let prev = prevSegTitleAttrsSelected { UISegmentedControl.appearance().setTitleTextAttributes(prev, for: .selected) }
                if let prev = prevSelectedTintColor     { UISegmentedControl.appearance().selectedSegmentTintColor = prev }
            }

            .alert("Delete this event assignment?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    NotificationManager.shared.cancelAllForEvent(id: original.id)
                    appState.deleteEventAssignment(id: original.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the event assignment.")
            }
        }
    }

    // Collapsible helper flag (local to this view)
    @State private var showHelperEditor: Bool = false
}
