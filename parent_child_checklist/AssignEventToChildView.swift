import SwiftUI
import UIKit

// MARK: - Futurist theme tokens (shared with Assign Task)
private enum FuturistTheme {
    static let skyTop = Color(red: 0.02, green: 0.06, blue: 0.16) // deep navy
    static let skyBottom = Color(red: 0.01, green: 0.03, blue: 0.10)
    static let neonAqua = Color(red: 0.20, green: 0.95, blue: 1.00) // bright cyan
    static let textPrimary = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)
    static let chipBorder = Color.white.opacity(0.25)
    static let chipDisabled = Color.white.opacity(0.55)
    static let cardStroke = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.10)
    static let cardShadow = Color.black.opacity(0.10)

    // Pastel action pill colours
    static let softRedBase = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
}

// MARK: - Frosted “glass” card container (parity with Task)
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
            .padding(.vertical, 10) // tightened rhythm to match Task
            .padding(.horizontal, 16)
            .background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FuturistTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: FuturistTheme.cardShadow, radius: 6, x: 0, y: 2)
    }
}

// MARK: - Stand-alone bright cyan separator (same as Task)
private struct BrightLineSeparator: View {
    var leadingInset: CGFloat = 16
    var trailingInset: CGFloat = 14
    var thickness: CGFloat = 2

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: FuturistTheme.skyTop.opacity(0.95), location: 0.00),
                .init(color: FuturistTheme.neonAqua, location: 0.50),
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
        .padding(.horizontal, 12) // align with card outer padding
        .zIndex(2)
        .accessibilityHidden(true)
    }
}

// MARK: - Toolbar pill (equal‑width Cancel/Save)
private struct ToolbarPillButton: View {
    let label: String
    var foreground: Color
    var background: Color
    var stroke: Color
    var disabled: Bool = false
    var glow: Bool = false
    var fixedWidth: CGFloat? = nil
    var fixedHeight: CGFloat? = nil
    var action: () -> Void

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .foregroundStyle(foreground)
            .frame(width: fixedWidth, height: fixedHeight, alignment: .center)
            .background(Capsule().fill(background))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
            .shadow(color: glow ? background.opacity(0.28) : .clear, radius: glow ? 3 : 0)
            .opacity(disabled ? 0.75 : 1.0)
            .contentShape(Capsule())
            .onTapGesture { if !disabled { action() } }
            .accessibilityAddTraits(.isButton)
    }
}

private struct AssignTopBar: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    private let pillWidth: CGFloat = 76
    private let pillHeight: CGFloat = 32

    var body: some View {
        ZStack {
            Text("Assign Event")
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
                    fixedWidth: pillWidth,
                    fixedHeight: pillHeight,
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
                    fixedWidth: pillWidth,
                    fixedHeight: pillHeight,
                    action: onSave
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(Color.clear)
    }
}

// MARK: - ToggleRow (neon outline style)
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

// MARK: - ValueChip (for date/time values on rows)
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

// MARK: - Picker chrome (dark scheme + neon tint) for inline Date/Time
private struct PickerChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, .dark)
            .tint(FuturistTheme.neonAqua)
    }
}
private extension View { func pickerChrome() -> some View { modifier(PickerChrome()) } }

// Inline graphical DatePicker panel
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

// Inline wheel TimePicker panel
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

// MARK: - Assign-To (PUSH) destination — Futurist multi‑select with Apply
private struct AssignToPickerScreen: View {
    let allChildren: [ChildProfile]
    let preselected: Set<UUID>
    var onApply: (Set<UUID>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var working: Set<UUID> = []
    @State private var query: String = ""

    private var filteredChildren: [ChildProfile] {
        let sorted = allChildren.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    private var canApply: Bool { !working.isEmpty }

    var body: some View {
        ZStack(alignment: .top) {
            CurvyAquaBlueBackground(animate: true).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Search
                    FrostedCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Search")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FuturistTheme.textSecondary)
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                TextField("Find a child…", text: $query)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled(true)
                                    .foregroundStyle(FuturistTheme.textPrimary)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                    BrightLineSeparator()

                    // Children list
                    FrostedCard {
                        VStack(spacing: 0) {
                            ForEach(filteredChildren) { child in
                                let checked = working.contains(child.id)
                                Button {
                                    toggle(child.id)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    HStack(spacing: 12) {
                                        ChildAvatarCircleView(colorHex: child.colorHex, avatarId: child.avatarId, size: 32)
                                        Text(child.name)
                                            .foregroundStyle(FuturistTheme.textPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(checked ? FuturistTheme.neonAqua : Color.white.opacity(0.45))
                                            .accessibilityHidden(true)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(checked ? Color.white.opacity(0.06) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(child.name), \(checked ? "selected" : "not selected")")

                                if child.id != filteredChildren.last?.id {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 1)
                                        .padding(.leading, 46) // align under avatar
                                        .accessibilityHidden(true)
                                }
                            }

                            if filteredChildren.isEmpty {
                                Text("No matches")
                                    .font(.footnote)
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 12)

                    BrightLineSeparator()

                    // Select All / Clear All
                    FrostedCard {
                        HStack(spacing: 12) {
                            Button {
                                working = Set(allChildren.map(\.id))
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text("Select All")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.12), in: Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            Button {
                                working.removeAll()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text("Clear All")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.12), in: Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer(minLength: 24)
                }
                .padding(.bottom, 24)
            }
        }
        // Hide system nav; themed top bar with Cancel/Apply
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            let pillWidth: CGFloat = 76
            let pillHeight: CGFloat = 32

            ZStack {
                Text("Assign To")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack {
                    ToolbarPillButton(
                        label: "Cancel",
                        foreground: .white,
                        background: FuturistTheme.softRedLight,
                        stroke: FuturistTheme.softRedBase.opacity(0.75),
                        fixedWidth: pillWidth,
                        fixedHeight: pillHeight,
                        action: { dismiss() }
                    )

                    Spacer(minLength: 12)

                    ToolbarPillButton(
                        label: "Apply",
                        foreground: canApply ? Color.black.opacity(0.9) : FuturistTheme.textSecondary,
                        background: canApply ? FuturistTheme.softGreenLight : Color.clear,
                        stroke: canApply ? FuturistTheme.softGreenBase.opacity(0.75)
                                         : FuturistTheme.textSecondary.opacity(0.35),
                        disabled: !canApply,
                        glow: canApply,
                        fixedWidth: pillWidth,
                        fixedHeight: pillHeight,
                        action: {
                            guard canApply else { return }
                            onApply(working)
                            dismiss()
                        }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .background(Color.clear)
        }
        .onAppear { working = preselected }
    }

    private func toggle(_ id: UUID) {
        if working.contains(id) { working.remove(id) } else { working.insert(id) }
    }
}

// MARK: - Assign Event View (updated: Location uses PUSH navigation)
struct AssignEventToChildView: View {
    // Inputs
    let childId: UUID
    let defaultStartDate: Date
    let onShowWeeklyToast: ((String) -> Void)?

    // Environment
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("parentSelectedTab") private var parentSelectedTab: String = "children"

    // State
    @State private var selectedChildIds: Set<UUID>
    @State private var selectedTemplate: EventTemplate? = nil
    @State private var showSelectEvent = false

    // Helper (collapsible)
    @State private var helperText: String = ""
    @State private var showHelperEditor: Bool = false

    // Active toggle (shown only after selection)
    @State private var isActive: Bool = true

    // Location
    @State private var selectedLocationId: UUID? = nil
    @State private var selectedLocationNameSnapshot: String = ""

    // DATES / OCCURRENCE / TIMES state
    @State private var startDate: Date
    @State private var finishDateEnabled: Bool = false
    @State private var finishDate: Date

    @State private var occurrence: EventAssignment.Occurrence = .specifiedDays
    @State private var selectedWeekdays: Set<Int> = [0,1,2,3,4,5,6]
    private let weekdayLabels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    @State private var showStartDateInline: Bool = false
    @State private var showFinishDateInline: Bool = false
    @State private var showStartTimeInline: Bool = false
    @State private var showFinishTimeInline: Bool = false

    @State private var startTimeEnabled: Bool = false
    @State private var startTime: Date
    @State private var finishTimeEnabled: Bool = false
    @State private var finishTime: Date

    // Legacy alerts (kept off; using Notify instead)
    @State private var alertMe: Bool = false
    @State private var alertOffsetMinutes: Int? = nil

    // Notify (persisted)
    @State private var startNotifyEnabled: Bool = false
    @State private var startNotifyRecipient: NotifyRecipient = .both
    @State private var startNotifyOffsetMinutes: Int = 5
    @State private var finishNotifyEnabled: Bool = false
    @State private var finishNotifyRecipient: NotifyRecipient = .both
    @State private var finishNotifyOffsetMinutes: Int = 0
    private let notifyOffsetOptions: [(label: String, minutes: Int)] = [
        ("At time", 0), ("5 min before", 5), ("10 min before", 10),
        ("15 min before", 15), ("30 min before", 30),
        ("1 hour before", 60), ("2 hours before", 120)
    ]

    // Toast / info
    @State private var localToastMessage: String? = nil
    @State private var lastClampToastAt: Date = .distantPast
    @State private var skipTodayInfo: String? = nil

    // PUSH navigation flags
    @State private var goToChooseChildren: Bool = false
    @State private var goToChooseLocation: Bool = false

    // ⬇️ NEW: Backups for segmented control appearance (scoped to this screen)
    @State private var prevSegTitleAttrsNormal: [NSAttributedString.Key: Any]?
    @State private var prevSegTitleAttrsSelected: [NSAttributedString.Key: Any]?
    @State private var prevSelectedTintColor: UIColor?

    // MARK: - Init
    init(childId: UUID, defaultStartDate: Date, onShowWeeklyToast: ((String) -> Void)? = nil) {
        self.childId = childId
        self.defaultStartDate = defaultStartDate
        self.onShowWeeklyToast = onShowWeeklyToast
        _selectedChildIds = State(initialValue: [childId])
        _startDate = State(initialValue: defaultStartDate)
        _finishDate = State(initialValue: defaultStartDate)
        let now = Date()
        _startTime = State(initialValue: now)
        _finishTime = State(initialValue: now)
    }

    // MARK: - Derived helpers
    private var canSave: Bool { selectedTemplate != nil && !selectedChildIds.isEmpty }
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }
    private func dayOnly(_ date: Date) -> Date { isoCalendar.startOfDay(for: date) }
    private func timeKey(_ time: Date?) -> Int? {
        guard let t = time else { return nil }
        let comps = isoCalendar.dateComponents([.hour, .minute], from: t)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
    private func normalizedOptionalString(_ s: String?) -> String? {
        let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
    private func weekdayIndexMondayFirst(for date: Date) -> Int {
        let wd = isoCalendar.component(.weekday, from: date) // 1=Sun ... 7=Sat
        switch wd { case 2: return 0; case 3: return 1; case 4: return 2; case 5: return 3; case 6: return 4; case 7: return 5; default: return 6 }
    }
    private func isTodaySelectedWeekday() -> Bool {
        selectedWeekdays.contains(weekdayIndexMondayFirst(for: startDate))
    }
    private var todayDay: Date { dayOnly(Date()) }

    // MARK: - Toast helpers
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

    // MARK: - Option‑B handling (recurring; past start time today → bump)
    private func handlePastTimeOnTodayIfNeeded() {
        guard occurrence == .specifiedDays else { skipTodayInfo = nil; return }
        let today = todayDay
        guard dayOnly(startDate) == today else { skipTodayInfo = nil; return }
        guard isTodaySelectedWeekday() else { skipTodayInfo = nil; return }
        guard startTimeEnabled else { skipTodayInfo = nil; return }

        let nowKey = timeKey(Date()) ?? 0
        let sKey = timeKey(startTime) ?? Int.max
        guard sKey < nowKey else { skipTodayInfo = nil; return }

        if let next = isoCalendar.date(byAdding: .day, value: 1, to: startDate) {
            startDate = dayOnly(next)
            if finishDateEnabled && dayOnly(finishDate) < dayOnly(startDate) {
                finishDate = startDate
            }
            let df = DateFormatter()
            df.calendar = isoCalendar
            df.locale = .current
            df.dateStyle = .medium
            df.timeStyle = .none
            skipTodayInfo = "Start time has already passed today. First occurrence will be \(df.string(from: startDate))."
        }
    }

    // MARK: - Enforcement / clamping (parity with Task)
    private func enforceNoPastScheduling() {
        let now = Date()
        let today = todayDay

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
            let nowKey = timeKey(now) ?? 0
            if startTimeEnabled, let sKey = timeKey(startTime), sKey < nowKey {
                startTime = now
                clampToast("Start time adjusted to now.")
            }
            if finishTimeEnabled, let fKey = timeKey(finishTime), fKey < nowKey {
                finishTime = now
                clampToast("Finish time adjusted to now.")
            }
        }

        if startTimeEnabled && finishTimeEnabled,
           let sKey = timeKey(startTime),
           let fKey = timeKey(finishTime),
           fKey < sKey {
            finishTime = startTime
            clampToast("Finish time adjusted to be after start time.")
        }

        // Apply Option‑B last + keep weekdays in allowed range
        handlePastTimeOnTodayIfNeeded()
        reconcileSelectedWeekdaysWithAllowed()
    }

    // MARK: - Allowed weekdays in Start..Finish range
    private var allowedWeekdays: Set<Int> {
        guard finishDateEnabled else { return Set(0..<7) }
        let start = dayOnly(startDate)
        let end = dayOnly(finishDate)
        if end < start { return [] }
        if let diff = isoCalendar.dateComponents([.day], from: start, to: end).day, diff >= 6 {
            return Set(0..<7)
        }
        var set = Set<Int>()
        var d = start
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

    // Keep selected weekdays within allowed range
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

    // Duplicate detection (ignore duration)
    private func isExactDuplicateEvent(_ proposed: EventAssignment) -> Bool {
        appState.eventAssignments.contains { existing in
            guard existing.childId == proposed.childId else { return false }
            guard existing.templateId == proposed.templateId else { return false }
            // Snapshot identity
            guard existing.eventTitle == proposed.eventTitle else { return false }
            guard existing.eventIcon == proposed.eventIcon else { return false }
            guard normalizedOptionalString(existing.helper) == normalizedOptionalString(proposed.helper) else { return false }
            guard existing.isActive == proposed.isActive else { return false }
            // Schedule identity
            guard dayOnly(existing.startDate) == dayOnly(proposed.startDate) else { return false }
            guard existing.endDate.map(dayOnly) == proposed.endDate.map(dayOnly) else { return false }
            guard existing.occurrence == proposed.occurrence else { return false }
            guard existing.weekdays.sorted() == proposed.weekdays.sorted() else { return false }
            // Time identity
            guard timeKey(existing.startTime) == timeKey(proposed.startTime) else { return false }
            guard timeKey(existing.finishTime) == timeKey(proposed.finishTime) else { return false }
            // Location + alerts + notify identity
            guard existing.locationId == proposed.locationId else { return false }
            guard existing.locationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                    == proposed.locationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            guard existing.alertMe == proposed.alertMe else { return false }
            guard existing.alertOffsetMinutes == proposed.alertOffsetMinutes else { return false }
            guard existing.startNotifyEnabled == proposed.startNotifyEnabled else { return false }
            guard existing.startNotifyRecipient == proposed.startNotifyRecipient else { return false }
            guard existing.startNotifyOffsetMinutes == proposed.startNotifyOffsetMinutes else { return false }
            guard existing.finishNotifyEnabled == proposed.finishNotifyEnabled else { return false }
            guard existing.finishNotifyRecipient == proposed.finishNotifyRecipient else { return false }
            guard existing.finishNotifyOffsetMinutes == proposed.finishNotifyOffsetMinutes else { return false }
            return true
        }
    }

    private func childName(_ id: UUID) -> String {
        appState.children.first(where: { $0.id == id })?.name ?? "Child"
    }

    // MARK: - Formatters
    private func dateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = isoCalendar
        df.locale = .current
        df.dateFormat = "EEE, d MMM yyyy"
        return df.string(from: date)
    }
    private func timeString(_ date: Date) -> String {
        let df = DateFormatter(); df.calendar = isoCalendar; df.locale = .current
        df.dateStyle = .none; df.timeStyle = .short
        return df.string(from: date)
    }

    // Assign-To summary (same as Task)
    private var assignToSummaryText: String {
        let allIds = Set(appState.children.map(\.id))
        if selectedChildIds == allIds && !allIds.isEmpty { return "All children" }
        let names = appState.children
            .filter { selectedChildIds.contains($0.id) }
            .map(\.name)
        if names.isEmpty { return "None" }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names[0]), \(names[1]), +\(names.count - 2) more"
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZZZBody
        }
    }

    // Extracted for readability
    private var ZZZBody: some View {
        ZStack(alignment: .top) {
            CurvyAquaBlueBackground(animate: true)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 1) EVENT CARD — order: Select Event → Active → Add helper note
                    FrostedCard {
                        Button {
                            showSelectEvent = true
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let tpl = selectedTemplate {
                                        // Selected state (emoji + title + helper line)
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
                                        // Empty state — “Select Event” to match Assign Task
                                        Text("Select Event")
                                            .font(.headline)
                                            .foregroundStyle(FuturistTheme.textPrimary)
                                        Text("Tap to choose an event")
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

                        // ✅ Active toggle — ONLY visible once an event is chosen
                        if selectedTemplate != nil {
                            ToggleRow(title: "Active", isOn: $isActive, titleColor: FuturistTheme.textSecondary)
                        }

                        // Helper collapsible — AFTER Active (parity with Assign Task)
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { showHelperEditor.toggle() }
                            } label: {
                                HStack {
                                    if helperText.isEmpty {
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
                    }
                    .padding(.horizontal, 12)

                    BrightLineSeparator()

                    // 2) ASSIGN TO — PUSH (left→right)
                    FrostedCard {
                        Button { goToChooseChildren = true } label: {
                            HStack {
                                Text("Assign To").foregroundStyle(FuturistTheme.textPrimary)
                                Spacer()
                                Text(assignToSummaryText).foregroundStyle(FuturistTheme.textSecondary)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(FuturistTheme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)

                    BrightLineSeparator()

                    // 3) LOCATION (Optional) — PUSH (left→right)
                    FrostedCard {
                        Button { goToChooseLocation = true } label: {
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

                    // 4) DATES (inline graphical)
                    FrostedCard {
                        VStack(alignment: .leading, spacing: 10) {
                            // START DATE row
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
                                InlineGraphicalCalendar(label: "Start Date", date: $startDate, range: todayDay...)
                                    .onChange(of: startDate) { _, _ in enforceNoPastScheduling() }
                            }

                            // FINISH DATE toggle + row
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

                    // 5) OCCURRENCE (segmented + chips)
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

                    // 6) TIME (inline wheels + notify)
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

                            // Divider
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

                    Spacer(minLength: 12)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            if let localToastMessage {
                ToastBannerView(message: localToastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        // Hide system nav bar; draw own header
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)

        // Custom top bar
        .safeAreaInset(edge: .top, spacing: 0) {
            AssignTopBar(
                canSave: canSave,
                onCancel: {
                    parentSelectedTab = "children"
                    dismiss()
                },
                onSave: {
                    if canSave { saveAssignment() }
                }
            )
            .background(Color.clear)
        }
        .onAppear {
            enforceNoPastScheduling()
            handlePastTimeOnTodayIfNeeded()

            // ⬇️ Scoped UISegmentedControl styling (parity with Task)
            prevSegTitleAttrsNormal  = UISegmentedControl.appearance().titleTextAttributes(for: .normal)
            prevSegTitleAttrsSelected = UISegmentedControl.appearance().titleTextAttributes(for: .selected)
            prevSelectedTintColor     = UISegmentedControl.appearance().selectedSegmentTintColor

            let selectedTitleAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor(Color(red: 0.08, green: 0.14, blue: 0.24)),
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ]
            let normalTitleAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor(FuturistTheme.textPrimary.opacity(0.96)),
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ]
            UISegmentedControl.appearance().setTitleTextAttributes(normalTitleAttrs, for: .normal)
            UISegmentedControl.appearance().setTitleTextAttributes(selectedTitleAttrs, for: .selected)
            UISegmentedControl.appearance().selectedSegmentTintColor = .white
        }
        .onDisappear {
            // Restore prior segmented control appearance
            if let prev = prevSegTitleAttrsNormal {
                UISegmentedControl.appearance().setTitleTextAttributes(prev, for: .normal)
            }
            if let prev = prevSegTitleAttrsSelected {
                UISegmentedControl.appearance().setTitleTextAttributes(prev, for: .selected)
            }
            if let prev = prevSelectedTintColor {
                UISegmentedControl.appearance().selectedSegmentTintColor = prev
            }
        }

        // Destinations / PUSH routes
        .navigationDestination(isPresented: $showSelectEvent) {
            SelectEventTemplateView(
                selectedTemplateId: selectedTemplate?.id,
                onPick: { picked in selectedTemplate = picked }
            )
            .environmentObject(appState)
        }
        .navigationDestination(isPresented: $goToChooseChildren) {
            AssignToPickerScreen(
                allChildren: appState.children,
                preselected: selectedChildIds,
                onApply: { newSelection in selectedChildIds = newSelection }
            )
        }
        .navigationDestination(isPresented: $goToChooseLocation) {
            // SelectLocationView already contains its own NavigationStack internally.
            // We can present it directly; its internal dismiss() will pop this push.
            SelectLocationView(
                selectedLocationId: $selectedLocationId,
                selectedLocationNameSnapshot: $selectedLocationNameSnapshot
            )
            .environmentObject(appState)
        }
    }

    // MARK: - Weekday chip (neon)
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

    // MARK: - Save (durationMinutes = nil; notify persisted; schedule notifications)
    private func saveAssignment() {
        enforceNoPastScheduling()
        guard let tpl = selectedTemplate else { return }
        guard !selectedChildIds.isEmpty else { return }

        let helper = helperText.trimmingCharacters(in: .whitespacesAndNewlines)
        let helperOrNil = helper.isEmpty ? nil : helper

        let start = startDate
        let end: Date? = (occurrence == .onceOnly) ? nil : (finishDateEnabled ? finishDate : nil)
        let weekdays = Array(selectedWeekdays).sorted()

        let startTimeValue: Date? = startTimeEnabled ? startTime : nil
        let finishTimeValue: Date? = finishTimeEnabled ? finishTime : nil

        // Duration removed
        let durationValue: Int? = nil

        // Notify (persist only if enabled)
        let persistedStartOffset: Int? = startNotifyEnabled ? max(0, startNotifyOffsetMinutes) : nil
        let persistedFinishOffset: Int? = finishNotifyEnabled ? max(0, finishNotifyOffsetMinutes) : nil

        var skippedNames: [String] = []
        var createdAssignments: [EventAssignment] = []

        for cid in selectedChildIds {
            let proposed = EventAssignment(
                childId: cid,
                templateId: tpl.id,
                eventTitle: tpl.title,
                eventIcon: tpl.iconSymbol,
                helper: helperOrNil,
                isActive: isActive,
                startDate: start,
                endDate: end,
                occurrence: occurrence,
                weekdays: weekdays,
                startTime: startTimeValue,
                finishTime: finishTimeValue,
                durationMinutes: durationValue,
                locationId: selectedLocationId,
                locationNameSnapshot: selectedLocationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines),
                alertMe: false,
                alertOffsetMinutes: nil,
                startNotifyEnabled: startNotifyEnabled,
                startNotifyRecipient: startNotifyRecipient,
                startNotifyOffsetMinutes: persistedStartOffset,
                finishNotifyEnabled: finishNotifyEnabled,
                finishNotifyRecipient: finishNotifyRecipient,
                finishNotifyOffsetMinutes: persistedFinishOffset,
                createdAt: Date(),
                updatedAt: Date()
            )

            if isExactDuplicateEvent(proposed) {
                skippedNames.append(childName(cid))
                continue
            }

            _ = appState.createEventAssignment(proposed)
            createdAssignments.append(proposed)
        }

        if !createdAssignments.isEmpty {
            let audience = currentAudience()
            for ev in createdAssignments where ev.isActive {
                NotificationManager.shared.scheduleNext(for: ev, audience: audience)
            }
            if !skippedNames.isEmpty {
                onShowWeeklyToast?("Already assigned to \(skippedNames.joined(separator: ", "))")
            }
            parentSelectedTab = "children"
            dismiss()
        } else {
            if !skippedNames.isEmpty {
                showLocalToast("Already assigned to \(skippedNames.joined(separator: ", "))")
            }
        }
    }

    private func currentAudience() -> NotificationAudience { .parent }
}
