import SwiftUI
import UIKit

// MARK: - Theme tokens (aligned with Assign Event)
private enum FuturistTheme {
    static let skyTop = Color(red: 0.02, green: 0.06, blue: 0.16)
    static let skyBottom = Color(red: 0.01, green: 0.03, blue: 0.10)
    static let neonAqua = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let textPrimary = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)
    static let chipBorder = Color.white.opacity(0.25)
    static let chipDisabled = Color.white.opacity(0.55)
    static let cardStroke = Color.white.opacity(0.08)
    static let divider = Color.white.opacity(0.10)
    static let cardShadow = Color.black.opacity(0.10)

    static let softRedBase   = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight  = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
}

// MARK: - Frosted card
private struct FrostedCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var surface: some ShapeStyle {
        reduceTransparency
        ? Color(red: 0.05, green: 0.10, blue: 0.22)
        : Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    }
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FuturistTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: FuturistTheme.cardShadow, radius: 6, x: 0, y: 2)
    }
}

// MARK: - Bright separator
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
        .padding(.horizontal, 12)
        .zIndex(2)
        .accessibilityHidden(true)
    }
}

// MARK: - Toolbar pill buttons
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

private struct AssignTopBar: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    private let pillWidth: CGFloat = 76
    private let pillHeight: CGFloat = 32

    var body: some View {
        ZStack {
            Text("Assign Task")
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

// MARK: - Neon Toggle
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

// MARK: - Inline pickers
private struct PickerChrome: ViewModifier {
    func body(content: Content) -> some View {
        content.environment(\.colorScheme, .dark).tint(FuturistTheme.neonAqua)
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

private struct ValueChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(FuturistTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(FuturistTheme.cardStroke, lineWidth: 1))
    }
}

// MARK: - Assign-To (PUSH) destination — Futurist restyle (multi-select)
private struct AssignToPickerScreen: View {
    let allChildren: [ChildProfile]
    let preselected: Set<UUID>
    var onApply: (Set<UUID>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var working: Set<UUID> = []
    @State private var query: String = ""

    private var filteredChildren: [ChildProfile] {
        let base = allChildren.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var canApply: Bool { !working.isEmpty }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            CurvyAquaBlueBackground(animate: true)
                .ignoresSafeArea()

            // Content
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
                        .foregroundStyle(FuturistTheme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                    BrightLineSeparator()

                    // Children list (as a single frosted card with rows)
                    FrostedCard {
                        VStack(spacing: 0) {
                            ForEach(filteredChildren) { child in
                                Button {
                                    toggle(child.id)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    HStack(spacing: 12) {
                                        ChildAvatarCircleView(
                                            colorHex: child.colorHex,
                                            avatarId: child.avatarId,
                                            size: 32
                                        )

                                        Text(child.name)
                                            .foregroundStyle(FuturistTheme.textPrimary)
                                            .lineLimit(1)

                                        Spacer()

                                        // Selection indicator
                                        Image(systemName: working.contains(child.id) ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(
                                                working.contains(child.id) ? FuturistTheme.neonAqua : Color.white.opacity(0.45)
                                            )
                                            .accessibilityHidden(true)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(working.contains(child.id) ? Color.white.opacity(0.06) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(child.name), \(working.contains(child.id) ? "selected" : "not selected")")

                                // Row divider (subtle)
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
        // Hide system nav; themed top bar below
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)

        // Top bar with Cancel / Apply pills
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

// MARK: - Assign Task View
struct AssignTaskToChildView: View {
    // Inputs
    let childId: UUID
    let defaultStartDate: Date
    let onShowWeeklyToast: ((String) -> Void)?

    // Environment
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("parentSelectedTab") private var parentSelectedTab: String = "children"

    // Local state (draft retained until Cancel/Save)
    @State private var selectedChildIds: Set<UUID>
    @State private var selectedTemplate: TaskTemplate? = nil
    @State private var showSelectTask = false

    @State private var helperText: String = ""
    @State private var showHelperEditor: Bool = false
    @State private var isActive: Bool = true
    @State private var photoEvidenceRequired: Bool = false

    // Dates
    @State private var startDate: Date
    @State private var finishDateEnabled: Bool = false
    @State private var finishDate: Date

    // Occurrence
    @State private var occurrence: TaskAssignment.Occurrence = .specifiedDays
    @State private var selectedWeekdays: Set<Int> = [0,1,2,3,4,5,6]
    private let weekdayLabels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    // Times
    @State private var startTimeEnabled: Bool = false
    @State private var startTime: Date
    @State private var finishTimeEnabled: Bool = false
    @State private var finishTime: Date

    // Notify (kept for parity; not scheduling here)
    @State private var startNotifyEnabled: Bool = false
    @State private var startNotifyRecipient: NotifyRecipient = .both
    @State private var startNotifyOffsetMinutes: Int = 0
    @State private var finishNotifyEnabled: Bool = false
    @State private var finishNotifyRecipient: NotifyRecipient = .both
    @State private var finishNotifyOffsetMinutes: Int = 0
    private let notifyOffsetOptions: [(label: String, minutes: Int)] = [
        ("At time", 0), ("5 min before", 5), ("10 min before", 10),
        ("15 min before", 15), ("30 min before", 30),
        ("1 hour before", 60), ("2 hours before", 120)
    ]

    // Inline picker visibility
    @State private var showStartDateInline: Bool = false
    @State private var showFinishDateInline: Bool = false
    @State private var showStartTimeInline: Bool = false
    @State private var showFinishTimeInline: Bool = false

    // Navigation push to Choose Children (replaces sheet)
    @State private var goToChooseChildren: Bool = false

    // Toast
    @State private var localToastMessage: String? = nil

    // ⬇️ NEW: Backups for segmented control appearance (scoped to this screen)
    @State private var prevSegTitleAttrsNormal: [NSAttributedString.Key: Any]?
    @State private var prevSegTitleAttrsSelected: [NSAttributedString.Key: Any]?
    @State private var prevSelectedTintColor: UIColor?

    // Init
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

    // Derived
    private var canSave: Bool { selectedTemplate != nil && !selectedChildIds.isEmpty }
    private var isoCalendar: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        return c
    }
    private func dayOnly(_ d: Date) -> Date { isoCalendar.startOfDay(for: d) }
    private func timeKey(_ time: Date?) -> Int? {
        guard let t = time else { return nil }
        let c = isoCalendar.dateComponents([.hour, .minute], from: t)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    private var todayDay: Date { dayOnly(Date()) }

    // Assign-To summary
    private var assignToSummaryText: String {
        let allIds = Set(appState.children.map(\.id))
        if selectedChildIds == allIds && !allIds.isEmpty { return "All children" }
        let names = appState.children.filter { selectedChildIds.contains($0.id) }.map(\.name)
        if names.isEmpty { return "None" }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names[0]), \(names[1]), +\(names.count - 2) more"
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // 1) TASK CARD — Select Task → Active → Add helper note
                        FrostedCard {
                            Button {
                                showSelectTask = true
                            } label: {
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
                                            Text("Select Task")
                                                .font(.headline)
                                                .foregroundStyle(FuturistTheme.textPrimary)
                                            Text("Tap to choose a task")
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

                            if selectedTemplate != nil {
                                ToggleRow(title: "Active", isOn: $isActive, titleColor: FuturistTheme.textSecondary)
                            }

                            // Helper collapsible
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

                        // 2) ASSIGN TO — now PUSHES the chooser
                        FrostedCard {
                            Button {
                                goToChooseChildren = true
                            } label: {
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
                                    InlineGraphicalCalendar(label: "Start Date", date: $startDate, range: todayDay...)
                                }

                                ToggleRow(title: "Finish Date", isOn: $finishDateEnabled)
                                    .onChange(of: finishDateEnabled) { _, enabled in
                                        if !enabled {
                                            withAnimation(.easeInOut(duration: 0.18)) { showFinishDateInline = false }
                                        }
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
                                    ForEach(TaskAssignment.Occurrence.allCases) { o in
                                        Text(o.displayName).tag(o)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if occurrence == .specifiedDays {
                                    HStack(spacing: 6) {
                                        ForEach(0..<7, id: \.self) { idx in
                                            weekdayChipCompact(index: idx, label: weekdayLabels[idx], isSelected: selectedWeekdays.contains(idx))
                                        }
                                    }
                                    Text("Applies on selected weekdays.")
                                        .font(.footnote)
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 5) TIMES
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                ToggleRow(title: "Start Time", isOn: $startTimeEnabled)
                                    .onChange(of: startTimeEnabled) { _, enabled in
                                        if !enabled {
                                            withAnimation(.easeInOut(duration: 0.18)) { showStartTimeInline = false }
                                            startNotifyEnabled = false
                                        } else {
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                showStartDateInline = false
                                                showFinishDateInline = false
                                                showFinishTimeInline = false
                                            }
                                        }
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
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)

                        BrightLineSeparator()

                        // 6) PHOTO EVIDENCE
                        FrostedCard {
                            ToggleRow(title: "Photo Evidence", isOn: $photoEvidenceRequired)
                        }
                        .padding(.horizontal, 12)

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
            // Hide the system nav bar; draw own header
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

            // PUSH destinations
            .navigationDestination(isPresented: $showSelectTask) {
                SelectTaskTemplateView(
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

            // ⬇️ NEW: Scoped UISegmentedControl styling for higher-contrast unselected labels
            .onAppear {
                // Backup current appearance so other screens remain unaffected
                prevSegTitleAttrsNormal = UISegmentedControl.appearance().titleTextAttributes(for: .normal)
                prevSegTitleAttrsSelected = UISegmentedControl.appearance().titleTextAttributes(for: .selected)
                prevSelectedTintColor = UISegmentedControl.appearance().selectedSegmentTintColor

                // Selected segment: dark text on white pill (semibold for readability)
                let selectedTitleAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(Color(red: 0.08, green: 0.14, blue: 0.24)),
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
                ]

                // Unselected segment: brighten to ~96% white, semibold for legibility on dark glass
                let normalTitleAttrs: [NSAttributedString.Key: Any] = [
                    .foregroundColor: UIColor(FuturistTheme.textPrimary.opacity(0.96)),
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
                ]

                UISegmentedControl.appearance().setTitleTextAttributes(normalTitleAttrs, for: .normal)
                UISegmentedControl.appearance().setTitleTextAttributes(selectedTitleAttrs, for: .selected)
                UISegmentedControl.appearance().selectedSegmentTintColor = .white
            }
            .onDisappear {
                // Restore prior appearance to avoid impacting other screens
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
        }
    }

    // MARK: - UI helpers
    private func weekdayChipCompact(index: Int, label: String, isSelected: Bool) -> some View {
        let borderColor: Color = isSelected ? FuturistTheme.neonAqua : FuturistTheme.chipBorder
        let fill: Color = isSelected ? FuturistTheme.neonAqua.opacity(0.18) : .clear
        return Text(label)
            .font(.caption2).fontWeight(.semibold)
            .foregroundStyle(FuturistTheme.textPrimary)
            .frame(minWidth: 34, minHeight: 24)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(borderColor, lineWidth: isSelected ? 2 : 1))
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelected { selectedWeekdays.remove(index) } else { selectedWeekdays.insert(index) }
            }
    }

    private func dateString(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = isoCalendar
        df.locale = .current
        df.dateFormat = "EEE, d MMM yyyy"
        return df.string(from: date)
    }

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.calendar = isoCalendar
        df.locale = .current
        df.dateStyle = .none
        df.timeStyle = .short
        return df.string(from: date)
    }

    // MARK: - Save
    private func saveAssignment() {
        guard let tpl = selectedTemplate else { return }
        guard !selectedChildIds.isEmpty else { return }

        // Build the TaskAssignment(s) (durationMinutes is nil here)
        let helper = helperText.trimmingCharacters(in: .whitespacesAndNewlines)
        let helperOrNil = helper.isEmpty ? nil : helper

        let endDateValue: Date? = (occurrence == .onceOnly) ? nil : (finishDateEnabled ? finishDate : nil)
        let weekdaysValue = Array(selectedWeekdays).sorted()
        let startTimeValue: Date? = startTimeEnabled ? startTime : nil
        let finishTimeValue: Date? = finishTimeEnabled ? finishTime : nil

        var created: [TaskAssignment] = []
        for cid in selectedChildIds {
            let assignment = TaskAssignment(
                childId: cid,
                templateId: tpl.id,
                taskTitle: tpl.title,
                taskIcon: tpl.iconSymbol,
                rewardPoints: tpl.rewardPoints,
                helper: helperOrNil,
                subtractIfNotCompleted: false,
                alertMe: false,
                photoEvidenceRequired: photoEvidenceRequired,
                isActive: isActive,
                startDate: startDate,
                endDate: endDateValue,
                occurrence: occurrence,
                weekdays: weekdaysValue,
                startTime: startTimeValue,
                finishTime: finishTimeValue,
                durationMinutes: nil,
                linkedEventAssignmentId: nil,
                startNotifyEnabled: false,
                startNotifyRecipient: .both,
                startNotifyOffsetMinutes: nil,
                finishNotifyEnabled: false,
                finishNotifyRecipient: .both,
                finishNotifyOffsetMinutes: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = appState.createTaskAssignment(assignment)
            created.append(assignment)
        }

        // Toast + close
        if !created.isEmpty {
            onShowWeeklyToast?("Task assigned.")
            parentSelectedTab = "children"
            dismiss()
        }
    }
}
