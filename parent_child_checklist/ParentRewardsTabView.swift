//
// ParentRewardsTabView.swift
// parent_child_checklist
//
// Parent Requests area with scalable filtering:
// - Balances section
// - Status segmented filter: Pending | Approved | Claimed
// - Child filter picker: All Children or a specific child
// - Search on request title + child name
// - Results grouped by child for easy scanning
//
// Updated: Inline, larger custom title (same line as trailing toolbar item).
//

import SwiftUI

struct ParentRewardsTabView: View {
    @EnvironmentObject private var appState: AppState

    // Review sheet
    @State private var selected: RewardRequest? = nil

    // Toast (errors only)
    @State private var localToastMessage: String? = nil
    @State private var lastToastAt: Date = .distantPast

    // History sheet
    @State private var historyChild: ChildProfile? = nil

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
            // newest requested first
            return searchScopedRequests.sorted { $0.requestedAt > $1.requestedAt }
        case .approved:
            // newest approved first (fallback updatedAt)
            return searchScopedRequests.sorted {
                let a = $0.approvedAt ?? $0.updatedAt
                let b = $1.approvedAt ?? $1.updatedAt
                return a > b
            }
        case .claimed:
            // newest claimed first (fallback updatedAt)
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
        // sort child groups by child name (A→Z)
        let sortedKeys = dict.keys.sorted {
            childName($0).localizedCaseInsensitiveCompare(childName($1)) == .orderedAscending
        }
        return sortedKeys.map { key in
            let child = appState.children.first(where: { $0.id == key })
            return (child, dict[key] ?? [])
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                List {
                    // 🔹 Balances
                    balancesSection

                    // 🔹 Filters row
                    filtersHeader

                    // 🔹 Results area
                    if sortedRequests.isEmpty {
                        Section {
                            Text(emptyStateText)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(groupedByChild, id: \.child?.id) { group in
                            Section(header: Text(childHeaderText(group.child))) {
                                ForEach(group.requests) { req in
                                    buttonRow(for: req)
                                }
                                .onDelete { indexSet in
                                    // enable delete via swipe on filtered list
                                    let subset = group.requests
                                    for idx in indexSet {
                                        _ = appState.deleteRewardRequest(id: subset[idx].id)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

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

                // Title, toolbar, search
                .navigationBarTitleDisplayMode(.inline) // inline so title & menu share one row
                .toolbar {
                    // Larger inline title (adjust size as needed; 32 matches your other screens)
                    ToolbarItem(placement: .principal) {
                        Text("Requests")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .accessibilityAddTraits(.isHeader)
                    }
                    // Trailing menu / actions
                    ToolbarItem(placement: .topBarTrailing) {
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
                                .font(.headline)
                        }
                        .accessibilityLabel("More")
                    }
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
                .navigationTitle("") // hidden because the principal title is shown
                .onAppear {
                    // Keep your rolling window compaction behaviour
                    appState.compactLedgerRollingWindow()
                }

                if let localToastMessage {
                    ToastBannerView(message: localToastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10) // ✅ SwiftUI uses .zIndex(_:)
                }
            }
        }
    }

    // MARK: - Sections / Subviews

    private var balancesSection: some View {
        Section("Balances") {
            if appState.children.isEmpty {
                Text("No children yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.children.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })) { child in
                    balanceRow(for: child)
                }
            }
        }
    }

    private var filtersHeader: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                // Status segmented control with counts
                Picker("Status", selection: $selectedStatus) {
                    Text("Pending (\(pendingCount))").tag(StatusScope.pending)
                    Text("Approved (\(approvedCount))").tag(StatusScope.approved)
                    Text("Claimed (\(claimedCount))").tag(StatusScope.claimed)
                }
                .pickerStyle(.segmented)

                // Child filter (compact)
                HStack(spacing: 10) {
                    Text("Child")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Child", selection: Binding(
                        get: { selectedChildId ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID() },
                        set: { newValue in
                            // special sentinel UUID = All Children
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
                }
            }
            .textCase(nil)
        }
    }

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

    // MARK: - Balances row
    @ViewBuilder
    private func balanceRow(for child: ChildProfile) -> some View {
        let total = appState.childPointsTotal(childId: child.id)
        HStack(spacing: 12) {
            // Child name
            Text(child.name)
                .font(.headline)
            Spacer()
            // Current balance
            HStack(spacing: 6) {
                Text("💎")
                Text("\(total)")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

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
                Label("History", systemImage: "clock.arrow.circlepath")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("History for \(child.name)")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(child.name), \(total) gems")
    }

    // MARK: - Request row
    @ViewBuilder
    private func buttonRow(for req: RewardRequest) -> some View {
        Button { selected = req } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(childName(req.childId))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    statusPill(req.status)
                }
                Text(req.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(statusDateLine(for: req))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let cost = req.approvedCost, cost > 0,
                   (req.status == .approved || req.status == .claimed) {
                    HStack(spacing: 4) {
                        Text("💎")
                        Text("\(cost)").fontWeight(.semibold)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
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

    private func statusPill(_ status: RewardRequestStatus) -> some View {
        let text = status.childDisplay
        let bg: Color
        let fg: Color
        switch status {
        case .pending:
            bg = Color.yellow.opacity(0.18); fg = .orange
        case .approved:
            bg = Color.green.opacity(0.18); fg = .green
        case .notApproved:
            bg = Color.gray.opacity(0.20); fg = .secondary
        case .claimed:
            bg = Color.blue.opacity(0.18); fg = .blue
        }
        return Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
    }

    private func showToast(_ message: String) {
        let now = Date()
        guard now.timeIntervalSince(lastToastAt) > 0.8 else { return } // rate-limit
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

    @State private var showNotApprovedSheet = false
}

// MARK: - “Not this time” quick view (optional sheet for completeness)
private struct NotApprovedListView: View {
    let requests: [RewardRequest]
    let childName: (UUID) -> String
    let onOpen: (RewardRequest) -> Void
    let onDelete: (RewardRequest) -> Void

    var body: some View {
        NavigationStack {
            List {
                if requests.isEmpty {
                    Section {
                        Text("No items.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // group by child
                    let dict = Dictionary(grouping: requests, by: { $0.childId })
                    let keys = dict.keys.sorted { childName($0).localizedCaseInsensitiveCompare(childName($1)) == .orderedAscending }
                    ForEach(keys, id: \.self) { cid in
                        Section(header: Text(childName(cid))) {
                            ForEach(dict[cid] ?? []) { req in
                                Button { onOpen(req) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(req.title).font(.headline)
                                        Text(dateLine(req))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 6)
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
                        }
                    }
                }
            }
            .navigationTitle("Not this time")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func dateLine(_ req: RewardRequest) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        if let d = req.notApprovedAt { return "Marked on \(df.string(from: d))" }
        return "Requested on \(df.string(from: req.requestedAt))"
    }
}
