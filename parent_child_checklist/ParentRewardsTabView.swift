//
//  ParentRewardsTabView.swift
//  parent_child_checklist
//
//  Futurist theme: Curvy background, safe-area header, frosted cards,
//  neon filament separators, and non-breathing ScrollView layout.
//  UPDATES:
//   • Custom StatusSegmentedControl for clear unselected tabs
//   • Themed “Not this time” sheet to match the new design
//

import SwiftUI
import UIKit

// MARK: - Futurist theme tokens (aligned with your other screens)
private enum FuturistTheme {
    static let neonAqua      = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)
    static let cardStroke    = Color.white.opacity(0.08)
    static let divider       = Color.white.opacity(0.10)
    static let cardShadow    = Color.black.opacity(0.10)

    // Surfaces
    static let surfaceSolid = Color(red: 0.05, green: 0.10, blue: 0.22)
    static let surfaceFrost = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)

    // Pastel pills
    static let softRedBase    = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase  = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight   = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
}

// MARK: - Layout metrics
private enum PageMetrics {
    static let pageHPad: CGFloat     = 12
    static let cornerRadius: CGFloat = 14
    static let innerHPad: CGFloat    = 16
    static let cardShadowRadius: CGFloat = 4
    static let cardShadowYOffset: CGFloat = 1
}

// MARK: - Frosted card container
private struct FrostedCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        let fill = reduceTransparency ? FuturistTheme.surfaceSolid : FuturistTheme.surfaceFrost
        return VStack(alignment: .leading, spacing: 10) { content() }
            .padding(.vertical, 12)
            .padding(.horizontal, PageMetrics.innerHPad)
            .background(
                RoundedRectangle(cornerRadius: PageMetrics.cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PageMetrics.cornerRadius, style: .continuous)
                    .stroke(FuturistTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: FuturistTheme.cardShadow, radius: PageMetrics.cardShadowRadius, x: 0, y: PageMetrics.cardShadowYOffset)
    }
}

// MARK: - Bright cyan filament separator
private struct BrightLineSeparator: View {
    var leadingInset: CGFloat = 16
    var trailingInset: CGFloat = 14
    var thickness: CGFloat = 2
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 0.00),
                .init(color: FuturistTheme.neonAqua, location: 0.50),
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 1.00)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: thickness)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.horizontal, PageMetrics.pageHPad)
        .accessibilityHidden(true)
    }
}

// MARK: - Compact frosted Search tile
private struct SearchTile: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Binding var text: String

    var body: some View {
        let fill = reduceTransparency ? FuturistTheme.surfaceSolid : Color.white.opacity(0.06)
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FuturistTheme.textPrimary.opacity(0.92))
            TextField("", text: $text,
                      prompt: Text("Search")
                        .foregroundStyle(FuturistTheme.textSecondary))
                .textInputAutocapitalization(.none)
                .foregroundStyle(FuturistTheme.textPrimary)
                .tint(FuturistTheme.neonAqua)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FuturistTheme.cardStroke, lineWidth: 1)
        )
    }
}

// MARK: - Status chip (for custom segmented control)
private struct StatusChip: View {
    var title: String
    var count: Int
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text("(\(count))")
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? Color.black.opacity(0.9) : FuturistTheme.textSecondary.opacity(0.95))
            .background(
                Group {
                    if selected {
                        Capsule().fill(Color.white) // high-contrast when selected
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.06))                 // subtle fill
                            .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1)) // readable outline
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel("\(title) \(count)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Custom segmented control (Pending / Approved / Claimed)
private struct StatusSegmentedControl<Scope: Hashable>: View {
    @Binding var selected: Scope
    let pendingCount: Int
    let approvedCount: Int
    let claimedCount: Int
    let pendingValue: Scope
    let approvedValue: Scope
    let claimedValue: Scope

    init(selected: Binding<Scope>,
         pendingCount: Int, approvedCount: Int, claimedCount: Int,
         pendingValue: Scope, approvedValue: Scope, claimedValue: Scope)
    {
        self._selected = selected
        self.pendingCount = pendingCount
        self.approvedCount = approvedCount
        self.claimedCount = claimedCount
        self.pendingValue = pendingValue
        self.approvedValue = approvedValue
        self.claimedValue = claimedValue
    }

    var body: some View {
        HStack(spacing: 8) {
            StatusChip(title: "Pending",  count: pendingCount,  selected: selected == pendingValue)  { selected = pendingValue  }
            StatusChip(title: "Approved", count: approvedCount, selected: selected == approvedValue) { selected = approvedValue }
            StatusChip(title: "Claimed",  count: claimedCount,  selected: selected == claimedValue)  { selected = claimedValue  }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Status pill (for request cards)
private struct StatusPill: View {
    let text: String
    let fg: Color
    let bg: Color
    var body: some View {
        Text(text)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
    }
}

// MARK: - Main
struct ParentRewardsTabView: View {
    @EnvironmentObject private var appState: AppState

    // Review sheet
    @State private var selected: RewardRequest? = nil

    // Toast (errors only)
    @State private var localToastMessage: String? = nil
    @State private var lastToastAt: Date = .distantPast

    // History sheet
    @State private var historyChild: ChildProfile? = nil

    // “Not this time” sheet
    @State private var showNotApprovedSheet = false

    // MARK: - Filters
    private enum StatusScope: String, CaseIterable, Identifiable {
        case pending = "Pending"
        case approved = "Approved"
        case claimed = "Claimed"
        var id: String { rawValue }
    }
    @State private var selectedStatus: StatusScope = .pending
    @State private var selectedChildId: UUID? = nil // nil = All Children

    // MARK: - Search
    @State private var searchText: String = ""

    // MARK: - Counts for segmented labels
    private var pendingCount: Int { appState.rewardRequests.filter { $0.status == .pending }.count }
    private var approvedCount: Int { appState.rewardRequests.filter { $0.status == .approved }.count }
    private var claimedCount: Int { appState.rewardRequests.filter { $0.status == .claimed }.count }
    private var notApprovedCount: Int { appState.rewardRequests.filter { $0.status == .notApproved }.count }

    // MARK: - Status-scoped requests
    private var statusScopedRequests: [RewardRequest] {
        appState.rewardRequests.filter { req in
            switch selectedStatus {
            case .pending:  return req.status == .pending
            case .approved: return req.status == .approved
            case .claimed:  return req.status == .claimed
            }
        }
    }

    // MARK: - Child filter
    private var childScopedRequests: [RewardRequest] {
        guard let childId = selectedChildId else { return statusScopedRequests }
        return statusScopedRequests.filter { $0.childId == childId }
    }

    // MARK: - Search (title + child name), AFTER status + child filters
    private var searchScopedRequests: [RewardRequest] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return childScopedRequests }
        return childScopedRequests.filter { req in
            req.title.localizedCaseInsensitiveContains(q)
            || childName(req.childId).localizedCaseInsensitiveContains(q)
        }
    }

    // MARK: - Sort within status
    private var sortedRequests: [RewardRequest] {
        switch selectedStatus {
        case .pending:
            return searchScopedRequests.sorted { $0.requestedAt > $1.requestedAt }
        case .approved:
            return searchScopedRequests.sorted {
                let a = $0.approvedAt ?? $0.updatedAt
                let b = $1.approvedAt ?? $1.updatedAt
                return a > b
            }
        case .claimed:
            return searchScopedRequests.sorted {
                let a = $0.claimedAt ?? $0.updatedAt
                let b = $1.claimedAt ?? $1.updatedAt
                return a > b
            }
        }
    }

    // Group by child for display
    private var groupedByChild: [(child: ChildProfile?, requests: [RewardRequest])] {
        let dict = Dictionary(grouping: sortedRequests, by: { $0.childId })
        let sortedKeys = dict.keys.sorted {
            childName($0).localizedCaseInsensitiveCompare(childName($1)) == .orderedAscending
        }
        return sortedKeys.map { key in
            let child = appState.children.first(where: { $0.id == key })
            return (child, dict[key] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ===== Search =====
                        FrostedCard {
                            SearchTile(text: $searchText)
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)
                        .padding(.top, 12)

                        BrightLineSeparator()

                        // ===== Balances =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Balances")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)

                                if appState.children.isEmpty {
                                    Text("No children yet.")
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                } else {
                                    VStack(spacing: 0) {
                                        let childrenSorted = appState.children.sorted {
                                            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                                        }
                                        ForEach(Array(childrenSorted.enumerated()), id: \.element.id) { idx, child in
                                            balanceRow(for: child)
                                                .padding(.vertical, 6)
                                            if idx < childrenSorted.count - 1 {
                                                Rectangle()
                                                    .fill(FuturistTheme.divider)
                                                    .frame(height: 1)
                                                    .padding(.leading, 0)
                                                    .accessibilityHidden(true)
                                            }
                                        }
                                    }
                                }
                            }
                            .foregroundStyle(FuturistTheme.textPrimary)
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)

                        BrightLineSeparator()

                        // ===== Filters =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 12) {
                                // Custom segmented control (clearer unselected tabs)
                                StatusSegmentedControl(
                                    selected: $selectedStatus,
                                    pendingCount: pendingCount,
                                    approvedCount: approvedCount,
                                    claimedCount: claimedCount,
                                    pendingValue: .pending,
                                    approvedValue: .approved,
                                    claimedValue: .claimed
                                )

                                // Child filter row
                                HStack(spacing: 10) {
                                    Text("Child")
                                        .font(.subheadline)
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                    Spacer()
                                    Picker("Child", selection: Binding(
                                        get: { selectedChildId ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID() },
                                        set: { newValue in
                                            if newValue.uuidString == "00000000-0000-0000-0000-000000000000" {
                                                selectedChildId = nil
                                            } else {
                                                selectedChildId = newValue
                                            }
                                        })) {
                                            Text("All Children").tag(UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID())
                                            ForEach(appState.children) { child in
                                                Text(child.name).tag(child.id)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .labelsHidden()
                                        .tint(FuturistTheme.neonAqua)
                                }
                            }
                            .foregroundStyle(FuturistTheme.textPrimary)
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)

                        BrightLineSeparator()

                        // ===== Results (grouped by child) =====
                        if groupedByChild.isEmpty {
                            FrostedCard {
                                Text(emptyStateText)
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                            }
                            .padding(.horizontal, PageMetrics.pageHPad)
                        } else {
                            ForEach(groupedByChild, id: \.child?.id) { group in
                                // Child header
                                Text(childHeaderText(group.child))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 12)
                                    .padding(.horizontal, PageMetrics.pageHPad)

                                // Request cards
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(group.requests.enumerated()), id: \.element.id) { idx, req in
                                        FrostedCard {
                                            requestCardContent(req)
                                        }
                                        .padding(.horizontal, PageMetrics.pageHPad)
                                        if idx < group.requests.count - 1 {
                                            BrightLineSeparator()
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 12)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.bottom, 24)
                }

                // Toast
                if let localToastMessage {
                    ToastBannerView(message: localToastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            // Hide system nav; themed header below
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // Header (center title + trailing menu)
            .safeAreaInset(edge: .top, spacing: 0) {
                let topSpacer: CGFloat = 8
                ZStack {
                    Text("Requests")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    VStack(spacing: 0) {
                        Color.clear.frame(height: topSpacer)
                        HStack {
                            Spacer(minLength: 12)
                            Menu {
                                if notApprovedCount > 0 {
                                    Button {
                                        showNotApprovedSheet.toggle()
                                    } label: {
                                        Label("View “Not this time” (\(notApprovedCount))", systemImage: "eye")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(FuturistTheme.textPrimary)
                                    .padding(8)
                                    .background(
                                        Circle().fill(Color.white.opacity(0.08))
                                    )
                                    .overlay(
                                        Circle().stroke(FuturistTheme.cardStroke, lineWidth: 1)
                                    )
                            }
                            .accessibilityLabel("More")
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .background(Color.clear)
            }

            // Sheets
            .sheet(item: $selected) { req in
                ReviewRewardRequestView(request: req)
                    .environmentObject(appState)
            }
            .sheet(item: $historyChild) { child in
                PointsHistoryView(childId: child.id)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showNotApprovedSheet) {
                NotApprovedListView(
                    requests: appState.rewardRequests
                        .filter { $0.status == .notApproved }
                        .sorted { ($0.notApprovedAt ?? $0.updatedAt) > ($1.notApprovedAt ?? $1.updatedAt) },
                    childName: { id in childName(id) },
                    onOpen: { selected = $0 },
                    onDelete: { _ = appState.deleteRewardRequest(id: $0.id) }
                )
                .environmentObject(appState)
            }
            .onAppear {
                appState.compactLedgerRollingWindow()
            }
        }
    }

    // MARK: - Subviews / helpers

    private var emptyStateText: String {
        let base = "\(selectedStatus.rawValue) requests"
        if let cid = selectedChildId, !childName(cid).isEmpty {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "No \(base.lowercased()) for \(childName(cid))."
            } else {
                return "No \(base.lowercased()) for \(childName(cid)) matching “\(searchText)”."
            }
        } else {
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "No \(base.lowercased()) to display."
            } else {
                return "No \(base.lowercased()) matching “\(searchText)”."
            }
        }
    }

    private func childHeaderText(_ child: ChildProfile?) -> String {
        child?.name ?? "Child"
    }

    private func childName(_ id: UUID) -> String {
        appState.children.first(where: { $0.id == id })?.name ?? "Child"
    }

    // Balances row
    @ViewBuilder
    private func balanceRow(for child: ChildProfile) -> some View {
        let total = appState.childPointsTotal(childId: child.id)
        HStack(spacing: 12) {
            Text(child.name)
                .font(.headline)
                .foregroundStyle(FuturistTheme.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                Text("💎")
                Text("\(total)")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(FuturistTheme.textSecondary)

            // Minus
            Button {
                let ok = appState.adjustChildPoints(childId: child.id, delta: -1)
                if !ok { showToast("Balance can’t go below 0.") }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.red)

            // Plus
            Button {
                _ = appState.adjustChildPoints(childId: child.id, delta: +1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            // History
            Button {
                historyChild = child
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(FuturistTheme.textSecondary)
            .accessibilityLabel("History for \(child.name)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(child.name), \(total) gems")
    }

    // Request card content (frosted)
    @ViewBuilder
    private func requestCardContent(_ req: RewardRequest) -> some View {
        Button { selected = req } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(childName(req.childId))
                        .font(.subheadline)
                        .foregroundStyle(FuturistTheme.textSecondary)
                    Spacer()

                    // Status pill colors
                    let pill: (String, Color, Color) = {
                        switch req.status {
                        case .pending:    return (req.status.childDisplay, .orange, Color.yellow.opacity(0.18))
                        case .approved:   return (req.status.childDisplay, .green,  Color.green.opacity(0.18))
                        case .notApproved:return (req.status.childDisplay, .secondary, Color.gray.opacity(0.20))
                        case .claimed:    return (req.status.childDisplay, .blue,   Color.blue.opacity(0.18))
                        }
                    }()
                    StatusPill(text: pill.0, fg: pill.1, bg: pill.2)
                }

                Text(req.title)
                    .font(.headline)
                    .foregroundStyle(FuturistTheme.textPrimary)

                Text(statusDateLine(for: req))
                    .font(.footnote)
                    .foregroundStyle(FuturistTheme.textSecondary)

                if let cost = req.approvedCost, cost > 0,
                   (req.status == .approved || req.status == .claimed) {
                    HStack(spacing: 6) {
                        Text("💎")
                        Text("\(cost)").fontWeight(.semibold)
                    }
                    .font(.footnote)
                    .foregroundStyle(FuturistTheme.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                _ = appState.deleteRewardRequest(id: req.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func statusDateLine(for req: RewardRequest) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        switch req.status {
        case .claimed:
            if let d = req.claimedAt { return "Claimed on \(df.string(from: d))" }
            if let d = req.approvedAt { return "Approved on \(df.string(from: d))" }
            if let d = req.notApprovedAt { return "Not this time on \(df.string(from: d))" }
            return "Requested on \(df.string(from: req.requestedAt))"
        case .approved:
            if let d = req.approvedAt { return "Approved on \(df.string(from: d))" }
            return "Requested on \(df.string(from: req.requestedAt))"
        case .notApproved:
            if let d = req.notApprovedAt { return "Not this time on \(df.string(from: d))" }
            return "Requested on \(df.string(from: req.requestedAt))"
        case .pending:
            return "Requested on \(df.string(from: req.requestedAt))"
        }
    }

    private func showToast(_ message: String) {
        let now = Date()
        guard now.timeIntervalSince(lastToastAt) > 0.8 else { return }
        lastToastAt = now
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            localToastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                localToastMessage = nil
            }
        }
    }
}

// MARK: - “Not this time” (themed to match Futurist screens)
private struct NotApprovedListView: View {
    let requests: [RewardRequest]
    let childName: (UUID) -> String
    let onOpen: (RewardRequest) -> Void
    let onDelete: (RewardRequest) -> Void

    // Group by child (A→Z)
    private var groupedByChild: [(childId: UUID, items: [RewardRequest])] {
        let dict = Dictionary(grouping: requests, by: { $0.childId })
        let keys = dict.keys.sorted {
            childName($0).localizedCaseInsensitiveCompare(childName($1)) == .orderedAscending
        }
        return keys.map { cid in (cid, dict[cid] ?? []) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        if requests.isEmpty {
                            // Empty state card
                            FrostedCard {
                                Text("No items.")
                                    .font(.subheadline)
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                            }
                            .padding(.horizontal, PageMetrics.pageHPad)
                            .padding(.top, 12)
                        } else {
                            // Groups by child
                            ForEach(groupedByChild, id: \.childId) { group in
                                // Child header
                                Text(childName(group.childId))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 12)
                                    .padding(.horizontal, PageMetrics.pageHPad)

                                // Requests for this child
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { idx, req in
                                        FrostedCard {
                                            Button {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                onOpen(req)
                                            } label: {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text(req.title)
                                                        .font(.headline)
                                                        .foregroundStyle(FuturistTheme.textPrimary)

                                                    Text(dateLine(req))
                                                        .font(.footnote)
                                                        .foregroundStyle(FuturistTheme.textSecondary)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    onDelete(req)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                        .padding(.horizontal, PageMetrics.pageHPad)

                                        // Filament between cards (not after the last)
                                        if idx < group.items.count - 1 {
                                            BrightLineSeparator()
                                        }
                                    }
                                }
                            }

                            Spacer(minLength: 24)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            // Hide system nav; themed header below
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // Header (centered title)
            .safeAreaInset(edge: .top, spacing: 0) {
                let topSpacer: CGFloat = 8
                ZStack {
                    Text("Not this time")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    VStack(spacing: 0) {
                        Color.clear.frame(height: topSpacer)
                        // Add trailing/leading header actions here if ever needed.
                        HStack { Spacer() }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }
                }
                .background(Color.clear)
            }
        }
    }

    // MARK: - Local helpers
    private func dateLine(_ req: RewardRequest) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        if let d = req.notApprovedAt { return "Marked on \(df.string(from: d))" }
        return "Requested on \(df.string(from: req.requestedAt))"
    }
}
