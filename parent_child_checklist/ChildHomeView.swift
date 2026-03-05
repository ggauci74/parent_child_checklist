//
// ChildHomeView.swift
//
import SwiftUI
import UIKit

// MARK: - Theme (colors used across the scene)
private enum FuturistTheme {
    static let skyTop = Color(red: 0.02, green: 0.06, blue: 0.16) // #05102A (deep/navy blue)
    static let skyBottom = Color(red: 0.01, green: 0.03, blue: 0.10) // #02081A
    static let neonAqua = Color(red: 0.20, green: 0.95, blue: 1.00) // #33F0FF (bright blue/cyan)
    static let neonAquaDim = Color(red: 0.20, green: 0.95, blue: 1.00).opacity(0.32)
    static let gridLine = Color(red: 0.20, green: 0.95, blue: 1.00).opacity(0.30)
    static let pillar = Color(red: 0.20, green: 0.95, blue: 1.00).opacity(0.10)

    // Cards
    static let surface = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    static let surfaceSolid = Color(red: 0.05, green: 0.10, blue: 0.22)

    // Text
    static let textPrimary = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color(red: 0.63, green: 0.73, blue: 0.82)

    // Section title (Option C frost)
    static let sectionTitleFrost = Color(red: 0.92, green: 0.97, blue: 1.00)
}

// MARK: - Reusable card background with micro-elevation
private struct CardBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = 12
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(reduceTransparency ? FuturistTheme.surfaceSolid : FuturistTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Subtle lower sweep gradient to anchor the content area
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

// MARK: - Custom gradient rule between rows
/// 2pt, rounded, center-bright gradient line (dark → bright → dark).
/// Drawn on a full-width basis with identical paddings so Tasks & Events match exactly.
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
        .frame(maxWidth: .infinity, alignment: .leading) // full-row basis
        .padding(.leading, leadingInset)                 // same paddings in both sections
        .padding(.trailing, trailingInset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - ChildHomeView
struct ChildHomeView: View {
    let childId: UUID

    @AppStorage("userRole") private var userRoleRawValue: String?
    @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let nameFontSize: CGFloat = 36

    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }
    private func dayOnly(_ date: Date) -> Date { isoCalendar.startOfDay(for: date) }

    private var todayDay: Date { dayOnly(Date()) }
    private var yesterdayDay: Date { isoCalendar.date(byAdding: .day, value: -1, to: todayDay) ?? todayDay }
    private var tomorrowDay: Date { isoCalendar.date(byAdding: .day, value: 1, to: todayDay) ?? todayDay }

    @State private var selectedDate: Date = Date()
    private var selectedDay: Date { dayOnly(selectedDate) }

    private enum RelativeDay { case yesterday, today, tomorrow }
    private var relativeSelection: RelativeDay {
        if selectedDay == todayDay { return .today }
        if selectedDay == yesterdayDay { return .yesterday }
        if selectedDay == tomorrowDay { return .tomorrow }
        return .today
    }
    private var isTodayView: Bool { relativeSelection == .today }
    private var canGoBack: Bool { relativeSelection != .yesterday }
    private var canGoForward: Bool { relativeSelection != .tomorrow }

    private func goLeft() {
        switch relativeSelection {
        case .today: selectedDate = yesterdayDay
        case .tomorrow: selectedDate = todayDay
        case .yesterday: break
        }
    }
    private func goRight() {
        switch relativeSelection {
        case .today: selectedDate = tomorrowDay
        case .yesterday: selectedDate = todayDay
        case .tomorrow: break
        }
    }
    private func clampSelectionToAllowed() {
        if !(selectedDay == yesterdayDay || selectedDay == todayDay || selectedDay == tomorrowDay) {
            selectedDate = todayDay
        }
    }

    private var child: ChildProfile? {
        appState.children.first { $0.id == childId }
    }

    private var currentDateText: String {
        let df = DateFormatter()
        df.calendar = isoCalendar
        df.locale = .current
        df.dateFormat = "EEEE, yyyy MMMM d"
        return df.string(from: selectedDay)
    }

    private var listTitleText: String {
        switch relativeSelection {
        case .yesterday: return "Yesterday’s List"
        case .today: return "Today’s List"
        case .tomorrow: return "Tomorrow’s List"
        }
    }

    private var pointsValue: Int {
        appState.childPointsTotal(childId: childId)
    }

    private func effectiveTime(_ task: TaskAssignment) -> Date? { task.startTime ?? task.finishTime }
    private func effectiveTime(_ event: EventAssignment) -> Date? { event.startTime ?? event.finishTime }
    private func timeKey(_ time: Date?) -> Int? {
        guard let time else { return nil }
        let components = isoCalendar.dateComponents([.hour, .minute], from: time)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private var tasksForSelectedDayAll: [TaskAssignment] {
        appState.assignments(for: childId, on: selectedDay)
    }
    private var eventsForSelectedDayAll: [EventAssignment] {
        appState.events(for: childId, on: selectedDay)
    }

    private var standaloneTimedTasks: [TaskAssignment] {
        tasksForSelectedDayAll
            .filter { effectiveTime($0) != nil }
            .sorted { a, b in
                let ta = timeKey(effectiveTime(a)) ?? Int.max
                let tb = timeKey(effectiveTime(b)) ?? Int.max
                if ta != tb { return ta < tb }
                return a.taskTitle.localizedCaseInsensitiveCompare(b.taskTitle) == .orderedAscending
            }
    }
    private var standaloneUntimedTasks: [TaskAssignment] {
        tasksForSelectedDayAll
            .filter { effectiveTime($0) == nil }
            .sorted { a, b in
                a.taskTitle.localizedCaseInsensitiveCompare(b.taskTitle) == .orderedAscending
            }
    }
    private var timedEvents: [EventAssignment] {
        eventsForSelectedDayAll
            .filter { effectiveTime($0) != nil }
            .sorted { a, b in
                let ta = timeKey(effectiveTime(a)) ?? Int.max
                let tb = timeKey(effectiveTime(b)) ?? Int.max
                if ta != tb { return ta < tb }
                return a.eventTitle.localizedCaseInsensitiveCompare(b.eventTitle) == .orderedAscending
            }
    }
    private var untimedEvents: [EventAssignment] {
        eventsForSelectedDayAll
            .filter { effectiveTime($0) == nil }
            .sorted { a, b in
                a.eventTitle.localizedCaseInsensitiveCompare(b.eventTitle) == .orderedAscending
            }
    }

    private var earliestStandaloneTaskKey: Int? {
        standaloneTimedTasks.compactMap { timeKey(effectiveTime($0)) }.min()
    }

    private var earliestEventBlockKey: Int? {
        let perEventEarliest: [Int] = eventsForSelectedDayAll.compactMap { ev in
            var keys: [Int] = []
            if let k = timeKey(effectiveTime(ev)) { keys.append(k) }
            return keys.min()
        }
        return perEventEarliest.min()
    }

    private enum AgendaSection: Hashable { case tasks, events }

    // ✅ Fixed version (no 'const', explicit unwraps)
    private var agendaSectionOrder: [AgendaSection] {
        if timedEvents.isEmpty { return [.tasks, .events] }
        if !timedEvents.isEmpty && standaloneTimedTasks.isEmpty && !standaloneUntimedTasks.isEmpty {
            return [.events, .tasks]
        }

        let t = earliestStandaloneTaskKey   // Int?
        let e = earliestEventBlockKey       // Int?

        if t == nil && e == nil { return [.tasks, .events] }
        if let tUnwrapped = t, let eUnwrapped = e {
            return (tUnwrapped <= eUnwrapped) ? [.tasks, .events] : [.events, .tasks]
        }
        if t != nil { return [.tasks, .events] }
        return [.events, .tasks]
    }

    private let swipeThreshold: CGFloat = 60
    private let verticalTolerance: CGFloat = 40

    @State private var avatarToastMessage: String? = nil
    @State private var showPhotoChoice = false
    @State private var showCameraPicker = false
    @State private var showLibraryPicker = false
    @State private var pendingPhotoAssignment: TaskAssignment? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var completionToPreview: TaskCompletionRecord? = nil
    @State private var viewerTaskTitle: String = ""
    @State private var showUncompleteConfirm: Bool = false
    @State private var pendingUncompleteAssignmentId: UUID? = nil
    @State private var pendingUncompleteTaskTitle: String = ""

    var body: some View {
        NavigationStack {
            ZZZBackgroundAndContent
        }
    }

    // Extracted for readability
    private var ZZZBackgroundAndContent: some View {
        ZStack(alignment: .top) {
            // Background
            CurvyAquaBlueBackground(animate: true)

            // Content
            VStack(spacing: 0) {
                if let child = child {
                    ChildHeaderView(
                        child: child,
                        points: pointsValue
                    )
                    .padding(.horizontal)

                    Text(listTitleText)
                        .font(.system(size: nameFontSize, weight: .regular))
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .padding(.top, 2)

                    HStack(spacing: 12) {
                        ChipArrowButton(
                            systemName: "chevron.backward.circle.fill",
                            action: { goLeft() },
                            disabled: !canGoBack
                        )
                        .accessibilityLabel(relativeSelection == .today ? "Go to Yesterday" : "Go to Previous Day")

                        Text(currentDateText)
                            .font(.subheadline)
                            .foregroundStyle(FuturistTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        ChipArrowButton(
                            systemName: "chevron.forward.circle.fill",
                            action: { goRight() },
                            disabled: !canGoForward
                        )
                        .accessibilityLabel(relativeSelection == .today ? "Go to Tomorrow" : "Go to Next Day")
                    }
                    .padding(.top, 6)

                    selectedDayContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    childNotFoundView
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onEnded { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        if abs(dy) > verticalTolerance && abs(dy) > abs(dx) { return }
                        if dx < -swipeThreshold, canGoForward { goRight() }
                        else if dx > swipeThreshold, canGoBack { goLeft() }
                    }
            )

            if let msg = avatarToastMessage {
                ToastBannerView(message: msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .avatarUpdated)) { _ in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                avatarToastMessage = "Avatar updated"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.2)) {
                    avatarToastMessage = nil
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .onAppear {
            selectedDate = dayOnly(Date())
            clampSelectionToAllowed()
        }
        .sheet(item: $completionToPreview) { comp in
            PhotoEvidenceViewer(
                completion: comp,
                taskTitle: viewerTaskTitle
            )
        }
        .confirmationDialog(
            "Attach Photo",
            isPresented: $showPhotoChoice,
            titleVisibility: .visible
        ) {
            Button("Take Photo") { showCameraPicker = true }
            Button("Choose from Library") { showLibraryPicker = true }
            Button("Cancel", role: .cancel) { pendingPhotoAssignment = nil }
        } message: {
            Text("A photo is required to complete this task.")
        }
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera) { image in
                handlePickedPhoto(image)
            }
        }
        .sheet(isPresented: $showLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                handlePickedPhoto(image)
            }
        }
        .alert("Un‑complete task?", isPresented: $showUncompleteConfirm) {
            Button("Remove Photo & Un‑complete", role: .destructive) {
                if let id = pendingUncompleteAssignmentId {
                    appState.toggleCompletion(assignmentId: id, on: selectedDay)
                }
                pendingUncompleteAssignmentId = nil
            }
            Button("Cancel", role: .cancel) {
                pendingUncompleteAssignmentId = nil
            }
        } message: {
            Text("This will mark “\(pendingUncompleteTaskTitle)” as not done and remove the attached photo.")
        }
    }

    private var selectedDayContent: some View {
        VStack(spacing: 0) {
            ZStack {
                LowerContentSweep()
                agendaList
            }
            Button("Switch Role (Temporary)") {
                userRoleRawValue = nil
                selectedChildIdRaw = nil
            }
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(.bottom, 20)
        }
    }

    // MARK: - TASKS + EVENTS LIST (identical dividers; precise vertical offset)
    @ViewBuilder
    private var agendaList: some View {
        let orderedStandaloneTasks = standaloneTimedTasks + standaloneUntimedTasks
        let orderedEvents = timedEvents + untimedEvents

        if orderedStandaloneTasks.isEmpty && orderedEvents.isEmpty {
            VStack {
                Spacer()
                Text("No tasks or events assigned for this day.")
                    .foregroundStyle(FuturistTheme.textSecondary)
                Spacer()
            }
        } else {
            List {
                ForEach(agendaSectionOrder, id: \.self) { section in
                    switch section {
                    case .tasks:
                        if !orderedStandaloneTasks.isEmpty {
                            Section {
                                ForEach(Array(orderedStandaloneTasks.enumerated()), id: \.element.id) { index, assignment in
                                    let completion = appState.completionRecord(for: assignment.id, on: selectedDay)

                                    // Wrapper gets extra bottom padding (Option A)
                                    VStack(spacing: 0) {
                                        SharedTaskAssignmentRow(
                                            assignment: assignment,
                                            selectedDate: selectedDay,
                                            isCompleted: completion != nil,
                                            onToggleComplete: {
                                                guard isTodayView else { return }
                                                handleToggleComplete(assignment)
                                            },
                                            completionForSelectedDay: completion,
                                            onViewPhoto: {
                                                guard let comp = completion, comp.hasPhotoEvidence else { return }
                                                viewerTaskTitle = assignment.taskTitle
                                                completionToPreview = comp
                                            },
                                            isInteractive: isTodayView
                                        )
                                    }
                                    .padding(.bottom, Self.ruleExtraBottomPadding)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(CardBackground())

                                    // Divider — identical paddings with a precise vertical offset
                                    .overlay(alignment: .bottomLeading) {
                                        if index < orderedStandaloneTasks.count - 1 {
                                            TaskRowGradientRule(
                                                leadingInset: Self.ruleLeadingInset,
                                                trailingInset: Self.ruleTrailingInset,
                                                thickness: 2
                                            )
                                            .offset(y: Self.ruleVerticalOffset) // << control height here
                                        }
                                    }
                                }
                            } header: {
                                Text("Tasks")
                                    .foregroundStyle(FuturistTheme.sectionTitleFrost)
                                    .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)
                                    .textCase(nil)
                                    .padding(.top, Self.headerTopPadding)
                                    .padding(.bottom, Self.headerBottomPadding)
                            }
                        }

                    case .events:
                        if !orderedEvents.isEmpty {
                            Section {
                                ForEach(Array(orderedEvents.enumerated()), id: \.element.id) { index, event in
                                    // Wrapper gets extra bottom padding (Option A)
                                    VStack(spacing: 0) {
                                        SharedEventAssignmentRow(event: event)
                                    }
                                    .padding(.bottom, Self.ruleExtraBottomPadding)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(CardBackground())

                                    // Divider — identical paddings with the same vertical offset
                                    .overlay(alignment: .bottomLeading) {
                                        if index < orderedEvents.count - 1 {
                                            TaskRowGradientRule(
                                                leadingInset: Self.ruleLeadingInset,
                                                trailingInset: Self.ruleTrailingInset,
                                                thickness: 2
                                            )
                                            .offset(y: Self.ruleVerticalOffset) // << control height here
                                        }
                                    }
                                }
                            } header: {
                                Text("Events")
                                    .foregroundStyle(FuturistTheme.sectionTitleFrost)
                                    .shadow(color: Color.black.opacity(0.18), radius: 1, x: 0, y: 1)
                                    .textCase(nil)
                                    .padding(.top, Self.eventsHeaderTopPadding)   // << tighten just Events
                                    .padding(.bottom, Self.headerBottomPadding)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .modifier(CompactSectionSpacingIfAvailable()) // iOS 17+: compact section spacing; no-op on earlier iOS
            .environment(\.defaultMinListHeaderHeight, 0)
        }
    }

    // MARK: - Tunable metrics for the custom rule & headers
    /// Horizontal start: align under the left icon/radio column.
    private static let ruleLeadingInset: CGFloat = 16
    /// Horizontal end: align under the trailing gem/right cluster.
    private static let ruleTrailingInset: CGFloat = 14
    /// Extra internal bottom padding so the divider appears lower (applied to WRAPPER).
    private static let ruleExtraBottomPadding: CGFloat = 6
    /// ✅ Precise vertical offset for the divider capsule (positive = further down)
    private static let ruleVerticalOffset: CGFloat = 6

    /// Section title spacing (above/below)
    private static let headerTopPadding: CGFloat = 6
    private static let headerBottomPadding: CGFloat = 4
    /// Tighter top padding used ONLY for the Events header to pull it closer to Tasks.
    private static let eventsHeaderTopPadding: CGFloat = 2

    private var childNotFoundView: some View {
        VStack {
            Spacer()
            Text("That child profile can’t be found.")
                .foregroundStyle(FuturistTheme.textSecondary)
            Spacer()
            Button("Back") {
                userRoleRawValue = nil
                selectedChildIdRaw = nil
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Photo evidence helpers (unchanged)
private extension ChildHomeView {
    func handleToggleComplete(_ assignment: TaskAssignment) {
        guard isTodayView else { return }
        if let comp = appState.completionRecord(for: assignment.id, on: selectedDay) {
            if comp.hasPhotoEvidence {
                pendingUncompleteAssignmentId = assignment.id
                pendingUncompleteTaskTitle = assignment.taskTitle
                showUncompleteConfirm = true
            } else {
                appState.toggleCompletion(assignmentId: assignment.id, on: selectedDay)
            }
            return
        }
        if assignment.photoEvidenceRequired {
            pendingPhotoAssignment = assignment
            showPhotoChoice = true
        } else {
            appState.toggleCompletion(assignmentId: assignment.id, on: selectedDay)
        }
    }

    func handlePickedPhoto(_ image: UIImage?) {
        defer {
            showCameraPicker = false
            showLibraryPicker = false
        }
        guard let image, let assignment = pendingPhotoAssignment else {
            pendingPhotoAssignment = nil
            return
        }
        appState.completeTaskWithPhoto(assignmentId: assignment.id, on: selectedDay, image: image)
        pendingPhotoAssignment = nil
        pickedImage = nil
    }
}

// MARK: - Blue Chip Arrow Button (present/next-day controls)
private struct ChipArrowButton: View {
    let systemName: String
    let action: () -> Void
    let disabled: Bool

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            Image(systemName: systemName)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.accentColor)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .opacity(disabled ? 0.45 : 1.0)
        .disabled(disabled)
    }
}

// MARK: - UIKit Image Picker
private struct ImagePicker: UIViewControllerRepresentable {
    enum Source { case camera, photoLibrary }

    let sourceType: Source
    var onImagePicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        switch sourceType {
        case .camera:
            picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        case .photoLibrary:
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onPicked: (UIImage?) -> Void
        init(onImagePicked: @escaping (UIImage?) -> Void) { self.onPicked = onImagePicked }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onPicked(nil)
            picker.dismiss(animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            onPicked(image)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Utilities
/// Applies compact section spacing on iOS 17+, does nothing on earlier OS versions.
private struct CompactSectionSpacingIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.listSectionSpacing(.compact)
        } else {
            content
        }
    }
}
