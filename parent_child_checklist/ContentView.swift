//
// ContentView.swift
// parent_child_checklist
//

import SwiftUI
import UIKit // for subtle haptics on tap

// MARK: - Role Model
enum UserRole: String {
    case parent
    case child
}

// MARK: - Day-only utilities (ISO yyyy-MM-dd in @AppStorage)
// We persist just the day (no time). These helpers keep all logic consistent.
fileprivate extension Calendar {
    static var appCal: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }
}
fileprivate func dayOnly(_ date: Date) -> Date {
    Calendar.appCal.startOfDay(for: date)
}
fileprivate func parseStoredDay(_ isoYYYYMMDD: String?) -> Date? {
    guard let s = isoYYYYMMDD, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let df = DateFormatter()
    df.calendar = Calendar.appCal
    df.locale = .current
    df.timeZone = .current
    df.dateFormat = "yyyy-MM-dd"
    return df.date(from: s).map { dayOnly($0) }
}
fileprivate func effectiveDefaultStartDate(from storedDayISO: String?) -> Date {
    let today = dayOnly(Date())
    guard let picked = parseStoredDay(storedDayISO) else { return today }
    // If the picked day is in the future or today, use it; if it's in the past, clamp to today.
    return max(today, picked)
}

// MARK: - App Root
struct ContentView: View {
    @AppStorage("userRole") private var userRoleRawValue: String?
    @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
    @EnvironmentObject private var appState: AppState
    var body: some View {
        Group {
            if let raw = userRoleRawValue, let role = UserRole(rawValue: raw) {
                switch role {
                case .parent:
                    ParentHomeView()
                case .child:
                    if let idString = selectedChildIdRaw, let uuid = UUID(uuidString: idString) {
                        if let child = appState.children.first(where: { $0.id == uuid }) {
                            let hasAvatar = !(child.avatarId ?? "")
                                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            if hasAvatar {
                                // Avatar already chosen -> show child tabs (Today is default)
                                ChildRootTabView(childId: uuid)
                            } else {
                                // First-time only: avatar setup flow
                                ChildAvatarSetupView(childId: uuid) { }
                                    .environmentObject(appState)
                            }
                        } else {
                            // If not yet loaded, still show tabs; guards inside handle state
                            ChildRootTabView(childId: uuid)
                        }
                    } else {
                        ChildChooseProfileView() // “Who are you?” (restyled + now with pairing gate)
                    }
                }
            } else {
                RoleSelectionView()
            }
        }
    }
}

// MARK: - Parent Home (Tabs: Children · Tasks · Events · Requests · Settings)
struct ParentHomeView: View {
    @EnvironmentObject private var appState: AppState
    // ✅ Share the selected parent tab across the app
    @AppStorage("parentSelectedTab") private var parentSelectedTab: String = "children"
    private var pendingBadge: Int { appState.pendingRewardRequestsCount }
    /// Title that includes the pending count when > 0, e.g. "Requests (3)"
    private var requestsTabTitle: String {
        pendingBadge > 0 ? "Requests (\(pendingBadge))" : "Requests"
    }
    var body: some View {
        TabView(selection: $parentSelectedTab) {
            // Children
            ParentChildrenTabView()
                .tabItem { Label("Children", systemImage: "person.2.fill") }
                .tag("children")
            // Tasks -> DIRECT host of AssignTaskToChildView
            ParentAssignTaskScreen()
                .tabItem { Label("Tasks", systemImage: "checklist") }
                .tag("tasks")
            // Events -> DIRECT host of AssignEventToChildView
            ParentAssignEventScreen()
                .tabItem { Label("Events", systemImage: "calendar") }
                .tag("events")
            // Requests
            ParentRewardsTabView()
                .tabItem { Label(requestsTabTitle, systemImage: "diamond.fill") }
                .tag("requests")
            // Settings
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag("settings")
        }
    }
}

// MARK: - Child resolution helper (shared by Task/Event tabs)
fileprivate func resolvePreferredChildId(
    children: [ChildProfile],
    lastParentChildIdRaw: String?,
    selectedChildIdRaw: String?
) -> UUID? {
    // 1) last child the parent viewed in weekly screen (ParentChildWeeklyView writes this)
    if let raw = lastParentChildIdRaw, let uuid = UUID(uuidString: raw),
       children.contains(where: { $0.id == uuid }) {
        return uuid
    }
    // 2) child-side selection (if you want to honor it on parent)
    if let raw = selectedChildIdRaw, let uuid = UUID(uuidString: raw),
       children.contains(where: { $0.id == uuid }) {
        return uuid
    }
    // 3) exactly one child
    if children.count == 1, let only = children.first {
        return only.id
    }
    // 4) otherwise default to the first (one-tap behavior as requested)
    return children.first?.id
}

// MARK: - Tasks tab: DIRECT AssignTaskToChildView (retain drafts across tab hops)
private struct ParentAssignTaskScreen: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("lastParentChildId") private var lastParentChildIdRaw: String?
    @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
    // ⬇️ Day persisted by the Parent weekly view (as "yyyy-MM-dd")
    @AppStorage("lastParentSelectedDay") private var lastParentSelectedDayISO: String?
    var body: some View {
        Group {
            if let cid = resolvePreferredChildId(
                children: appState.children,
                lastParentChildIdRaw: lastParentChildIdRaw,
                selectedChildIdRaw: selectedChildIdRaw
            ) {
                let effective = effectiveDefaultStartDate(from: lastParentSelectedDayISO)
                AssignTaskToChildView(
                    childId: cid,
                    defaultStartDate: effective,
                    onShowWeeklyToast: { _ in }
                )
                // ⬇️ Force a fresh instance when the effective default day changes
                .id(effective)
                .environmentObject(appState)
                // ✅ No `.id(openToken)` and no refresh-on-appear: drafts persist until Cancel/Save,
                // except when the day changes (intentional for this feature).
            } else {
                NoChildrenHintView(title: "Assign Task")
            }
        }
    }
}

// MARK: - Events tab: DIRECT AssignEventToChildView (already retains drafts)
private struct ParentAssignEventScreen: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("lastParentChildId") private var lastParentChildIdRaw: String?
    @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
    // ⬇️ Day persisted by the Parent weekly view (as "yyyy-MM-dd")
    @AppStorage("lastParentSelectedDay") private var lastParentSelectedDayISO: String?
    var body: some View {
        Group {
            if let cid = resolvePreferredChildId(
                children: appState.children,
                lastParentChildIdRaw: lastParentChildIdRaw,
                selectedChildIdRaw: selectedChildIdRaw
            ) {
                let effective = effectiveDefaultStartDate(from: lastParentSelectedDayISO)
                AssignEventToChildView(
                    childId: cid,
                    defaultStartDate: effective,
                    onShowWeeklyToast: { _ in }
                )
                // ⬇️ Force a fresh instance when the effective default day changes
                .id(effective)
                .environmentObject(appState)
            } else {
                NoChildrenHintView(title: "Assign Event")
            }
        }
    }
}

// MARK: - Tiny empty-state for when there are no children
private struct NoChildrenHintView: View {
    let title: String
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("No children yet")
                    .font(.headline)
                Text("Add a child in the Children tab, then return to \(title).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Role Selection (onboarding entry)
struct RoleSelectionView: View {
    @AppStorage("userRole") private var userRoleRawValue: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // MARK: Local Futurist tokens (scoped to this view to avoid collisions)
    private enum WelcomeTheme {
        static let neonAqua = Color(red: 0.20, green: 0.95, blue: 1.00)
        static let textPrimary = Color(red: 0.92, green: 0.97, blue: 1.00)
        static let textSecondary = Color.white.opacity(0.78)
        static let cardStroke = Color.white.opacity(0.08)
        static let cardShadow = Color.black.opacity(0.10)
        static let surfaceSolid = Color(red: 0.05, green: 0.10, blue: 0.22)
        static let surfaceFrost = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    }
    // MARK: Local frosted card (safe reduceTransparency)
    private struct WelcomeFrostedCard<Content: View>: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        let content: () -> Content
        init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
        var body: some View {
            let fill = reduceTransparency ? WelcomeTheme.surfaceSolid : WelcomeTheme.surfaceFrost
            return VStack(alignment: .leading, spacing: 10) { content() }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(WelcomeTheme.cardStroke, lineWidth: 1)
                )
                .shadow(color: WelcomeTheme.cardShadow, radius: 4, x: 0, y: 1)
        }
    }
    // MARK: Neon filament separator
    private struct WelcomeBrightLineSeparator: View {
        var leadingInset: CGFloat = 16
        var trailingInset: CGFloat = 14
        var thickness: CGFloat = 2
        var body: some View {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 0.00),
                    .init(color: WelcomeTheme.neonAqua, location: 0.50),
                    .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 1.00),
                ]),
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: thickness)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, leadingInset)
            .padding(.trailing, trailingInset)
            .accessibilityHidden(true)
        }
    }
    // MARK: Emoji tile (fallback frosted square)
    @ViewBuilder private func emojiTile(_ emoji: String) -> some View {
        Text(emoji)
            .font(.system(size: 22))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
    }
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background
                CurvyAquaBlueBackground(animate: !reduceMotion).ignoresSafeArea()
                // Content (role selection)
                ScrollView {
                    VStack(spacing: 0) {
                        // Prompt
                        Text("Select your role – Parent or Child")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(WelcomeTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                            .padding(.horizontal, 16)
                        // Parent card
                        WelcomeFrostedCard {
                            Button(action: roleParent) {
                                HStack(spacing: 12) {
                                    emojiTile("👨‍👩‍👧‍👦").accessibilityHidden(true)
                                    Text("I'm a Parent")
                                        .font(.headline)
                                        .foregroundStyle(WelcomeTheme.textPrimary)
                                    Spacer(minLength: 8)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("I'm a Parent")
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 20)
                        // Neon line
                        WelcomeBrightLineSeparator()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 0)
                        // Child card
                        WelcomeFrostedCard {
                            Button(action: roleChild) {
                                HStack(spacing: 12) {
                                    emojiTile("🧒").accessibilityHidden(true)
                                    Text("I'm a Child")
                                        .font(.headline)
                                        .foregroundStyle(WelcomeTheme.textPrimary)
                                    Spacer(minLength: 8)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("I'm a Child")
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 0)
                        Spacer(minLength: 120)
                    }
                    .padding(.bottom, 24)
                }
            }
            // Hide default nav; render Futurist title in the safe-area inset
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            // Larger, confident header
            .safeAreaInset(edge: .top, spacing: 0) {
                let topSpacer: CGFloat = 8
                ZStack {
                    Text("Welcome 👋")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(WelcomeTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: topSpacer)
                        HStack { Spacer() }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }
                }
                .background(Color.clear)
            }
            // Bottom tip
            .safeAreaInset(edge: .bottom, spacing: 0) {
                WelcomeFrostedCard {
                    Text("Tip: parents create tasks and events,\n kids tick them off")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(WelcomeTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .background(.clear)
            }
        }
    }
    // MARK: - Actions
    private func roleParent() {
        triggerTapHaptic()
        userRoleRawValue = UserRole.parent.rawValue
    }
    private func roleChild() {
        triggerTapHaptic()
        userRoleRawValue = UserRole.child.rawValue
    }
    private func triggerTapHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
}

// MARK: - “Who are you?” (Futurist restyle + QR pairing gate)
struct ChildChooseProfileView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("userRole") private var userRoleRawValue: String?
    @AppStorage("selectedChildId") private var selectedChildIdRaw: String?

    // For presenting the scanner sheet when a device is not yet bound
    @State private var pendingScanChild: ChildProfile? = nil

    // Derived: A→Z by name for consistent ordering (matches other tabs)
    private var childrenSorted: [ChildProfile] {
        appState.children.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // Neon rule spacing (kept in-sync with other Futurist lists)
    private static let ruleLeadingInset: CGFloat  = 16
    private static let ruleTrailingInset: CGFloat = 14
    private static let ruleExtraBottomPadding: CGFloat = 6
    private static let ruleVerticalOffset: CGFloat = 6

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Futurist background
                CurvyAquaBlueBackground(animate: true).ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    // Title + subtitle
                    VStack(spacing: 6) {
                        Text("Who are you?")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(ChooseTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        Text("Pick your name to see your tasks ✅")
                            .font(.callout)
                            .foregroundStyle(ChooseTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // List of children
                    if childrenSorted.isEmpty {
                        Spacer(minLength: 24)
                        Text("No children yet.")
                            .foregroundStyle(ChooseTheme.textSecondary)
                            .padding(.horizontal, 16)
                        Spacer()
                    } else {
                        List {
                            Section {
                                ForEach(Array(childrenSorted.enumerated()), id: \.element.id) { index, child in
                                    VStack(spacing: 0) {
                                        childRow(for: child)
                                    }
                                    .padding(.bottom, Self.ruleExtraBottomPadding)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(ChooseCardBackground())
                                    .overlay(alignment: .bottomLeading) {
                                        if index < childrenSorted.count - 1 {
                                            ChooseNeonRule(
                                                leadingInset: Self.ruleLeadingInset,
                                                trailingInset: Self.ruleTrailingInset,
                                                thickness: 2
                                            )
                                            .offset(y: Self.ruleVerticalOffset)
                                        }
                                    }
                                }
                            } header: {
                                Text("Children")
                                    .foregroundStyle(ChooseTheme.textPrimary)
                                    .textCase(nil)
                                    .padding(.top, 6)
                                    .padding(.bottom, 4)
                            }

                            // Same “Back” behavior as before (resets role/selection)
                            Section {
                                Button("Back") {
                                    userRoleRawValue = nil
                                    selectedChildIdRaw = nil
                                }
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.insetGrouped)
                        .environment(\.defaultMinListHeaderHeight, 0)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            // Pairing scanner sheet (only when needed)
            .sheet(item: $pendingScanChild) { child in
                ChildPairingScannerSheet(
                    expectedChildId: child.id,
                    expectedPairingEpoch: child.pairingEpoch,
                    familyId: nil,
                    onVerified: { _ in
                        // Bind this device to the verified child & finish selection
                        do {
                            try DeviceBindingStore.shared.bind(to: child.id, epoch: child.pairingEpoch)
                        } catch {
                            // If Keychain write fails, we still proceed, but pairing protection will re-prompt next time.
                            print("Bind error: \(error)")
                        }
                        selectedChildIdRaw = child.id.uuidString
                        pendingScanChild = nil
                    },
                    onCancel: {
                        pendingScanChild = nil
                    }
                )
            }
        }
    }

    // MARK: - Row content (Button or NavigationLink depending on avatar state)
    @ViewBuilder
    private func childRow(for child: ChildProfile) -> some View {
        let hasAvatar = !(child.avatarId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        if hasAvatar {
            Button {
                attemptSelectChild(child)
            } label: {
                rowCardContent(child: child)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(child.name)")
        } else {
            // First-time flow: go to avatar setup
            NavigationLink {
                ChildAvatarSetupView(childId: child.id)
                    .environmentObject(appState)
            } label: {
                rowCardContent(child: child)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(child.name), choose avatar")
        }
    }

    /// Applies the pairing gate: if this device is not yet bound (or epoch changed), present the scanner;
    /// otherwise proceed as before by setting selectedChildIdRaw.
    private func attemptSelectChild(_ child: ChildProfile) {
        let alreadyBound = DeviceBindingStore.shared.isBound(to: child.id, epoch: child.pairingEpoch)
        if alreadyBound {
            selectedChildIdRaw = child.id.uuidString
        } else {
            // Present the scanner; binding occurs on successful verification.
            pendingScanChild = child
        }
    }

    // MARK: - Row visual
    @ViewBuilder
    private func rowCardContent(child: ChildProfile) -> some View {
        HStack(spacing: 12) {
            ChildAvatarCircleView(
                colorHex: child.colorHex,
                avatarId: child.avatarId,
                size: 36
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .font(.headline)
                    .foregroundStyle(ChooseTheme.textPrimary)
                let subtitle = child.avatarId == nil
                    ? "Not chosen yet"
                    : AvatarCatalog.avatar(for: child.avatarId).displayName
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(ChooseTheme.textSecondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(ChooseTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ChooseCardBackground())
    }
}

// MARK: - Local Futurist tokens (scoped to this file to avoid collisions)
private enum ChooseTheme {
    static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00)      // frosted white headline
    static let textSecondary = Color.white.opacity(0.78)                       // secondary on dark
    static let cardStroke    = Color.white.opacity(0.08)
    static let cardShadow    = Color.black.opacity(0.10)
    static let surfaceFrost  = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    static let surfaceSolid  = Color(red: 0.05, green: 0.10, blue: 0.22)
}

// MARK: - Frosted card background (matches other child/parent lists)
private struct ChooseCardBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = 14
    var body: some View {
        let surface = reduceTransparency ? ChooseTheme.surfaceSolid : ChooseTheme.surfaceFrost
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(ChooseTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: ChooseTheme.cardShadow, radius: 6, x: 0, y: 2)
    }
}

// MARK: - Neon cyan filament between rows
private struct ChooseNeonRule: View {
    var leadingInset: CGFloat = 16
    var trailingInset: CGFloat = 14
    var thickness: CGFloat = 2
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 0.00),
                .init(color: Color(red: 0.20, green: 0.95, blue: 1.00),               location: 0.50),
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 1.00),
            ]),
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: thickness)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .accessibilityHidden(true)
    }
}
