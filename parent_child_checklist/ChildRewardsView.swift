//
// ChildRewardsView.swift
// parent_child_checklist
//
// Child screen to submit/view requests with segmented layout, medium‑tight spacing,
// top-aligned (right) character counter aligned to the TextField trailing,
// "Request Again" from Claimed, and an inline hint on Pending rows.
//

import SwiftUI
import UIKit

// MARK: - Theme tokens (mirrors ChildHomeView for this screen)
private enum FuturistTheme {
    static let skyTop = Color(red: 0.02, green: 0.06, blue: 0.16)
    static let skyBottom = Color(red: 0.01, green: 0.03, blue: 0.10)
    static let neonAqua = Color(red: 0.20, green: 0.95, blue: 1.00)

    // Cards
    static let surface = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    static let surfaceSolid = Color(red: 0.05, green: 0.10, blue: 0.22)

    // Text
    static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color(red: 0.63, green: 0.73, blue: 0.82)
}

// Micro-elevation card background (matches Today’s screen)
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

// Gentle dark sweep behind lower content (matches Today’s screen)
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

// Custom neon divider capsule (dark → neon → dark), same as Today’s screen
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, ChildRewardsView.ruleLeadingInset)
        .padding(.trailing, ChildRewardsView.ruleTrailingInset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// Simple empty-state card for lists
private struct EmptyCard: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(FuturistTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(CardBackground())
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Custom Segmented Pills (higher contrast on dark cards)
private struct SegmentedPills: View {
    enum Segment: Hashable { case pending, approved, claimed }
    @Binding var selected: Segment

    private let selectedBG   = Color.white.opacity(0.15)
    private let selectedText = Color.white
    private let unselectedBG = Color.white.opacity(0.06)
    private let unselectedText = Color.white.opacity(0.80)

    var pendingCount: Int
    var approvedCount: Int
    var claimedCount: Int

    var body: some View {
        HStack(spacing: 8) {
            pill(title: "Pending (\(pendingCount))", tag: .pending)
            pill(title: "Approved (\(approvedCount))", tag: .approved)
            pill(title: "Claimed (\(claimedCount))", tag: .claimed)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)   // Option B pills card height
        .background(CardBackground())
    }

    private func pill(title: String, tag: Segment) -> some View {
        let isSel = (selected == tag)
        return Button {
            selected = tag
        } label: {
            Text(title)
                .font(.subheadline).fontWeight(isSel ? .semibold : .regular)
                .foregroundStyle(isSel ? selectedText : unselectedText)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)   // Option B: pill height
                .background((isSel ? selectedBG : unselectedBG), in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// PreferenceKey to capture the Request button width (for aligning the counter to the TextField trailing)
private struct RequestButtonWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - View
struct ChildRewardsView: View {
    let childId: UUID
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // Input
    @State private var newRequestTitle: String = ""
    @FocusState private var composerFocused: Bool

    // Toast
    @State private var toastMessage: String? = nil

    // Title styling (to match "Today's List")
    private let nameFontSize: CGFloat = 36

    // Divider & header tunables (identical to Today’s screen)
    static let ruleLeadingInset: CGFloat = 16
    static let ruleTrailingInset: CGFloat = 14
    static let ruleExtraBottomPadding: CGFloat = 6
    static let ruleVerticalOffset: CGFloat = 6

    // Local colors for meta text on dark cards
    private let metaColor = Color.white.opacity(0.78)

    // Segments
    private enum Segment: Hashable { case pending, approved, claimed }
    @State private var selectedSegment: Segment = .pending

    // Derived child + points
    private var child: ChildProfile? {
        appState.children.first { $0.id == childId }
    }
    private var pointsValue: Int { appState.childPointsTotal(childId: childId) }

    // All requests for this child (newest first)
    private var requests: [RewardRequest] {
        appState.rewardRequests
            .filter { $0.childId == childId }
            .sorted { $0.requestedAt > $1.requestedAt }
    }

    // Segment filters
    private var pendingRequests: [RewardRequest] {
        requests.filter { $0.status == .pending }
    }
    private var notApprovedRequests: [RewardRequest] {
        requests.filter { $0.status == .notApproved }
    }
    private var approvedRequests: [RewardRequest] {
        requests.filter { $0.status == .approved }
    }
    private var claimedRequests: [RewardRequest] {
        requests.filter { $0.status == .claimed }
    }

    // Composer preview & limit logic
    private let previewTriggerCount: Int = 22
    private let maxCharacters: Int = 160
    @State private var showPreview: Bool = false
    private var shouldShowPreview: Bool { composerFocused && newRequestTitle.count >= previewTriggerCount }
    private var atLimit: Bool { newRequestTitle.count >= maxCharacters }

    // For aligning the counter with TextField trailing
    @State private var requestButtonWidth: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)

                VStack(spacing: 0) {
                    if let child {
                        ChildHeaderView(child: child, points: pointsValue)
                            .padding(.horizontal)
                        Text("Requests")
                            .font(.system(size: nameFontSize, weight: .regular))
                            .foregroundStyle(FuturistTheme.textPrimary)
                            .padding(.top, 2)

                        ZStack {
                            LowerContentSweep()
                            screenContent
                        }
                    } else {
                        VStack {
                            Spacer()
                            Text("That child profile can’t be found.")
                                .foregroundStyle(FuturistTheme.textSecondary)
                            Spacer()
                        }
                    }
                }

                if let toastMessage {
                    ToastBannerView(message: toastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Screen content (composer card + custom segmented pills + segmented lists)
    private var screenContent: some View {
        // Option B: medium-tight vertical rhythm
        VStack(spacing: 6) {
            composerCard
                .padding(.horizontal)

            SegmentedPills(
                selected: Binding(
                    get: {
                        switch selectedSegment {
                        case .pending:  return .pending
                        case .approved: return .approved
                        case .claimed:  return .claimed
                        }
                    },
                    set: { seg in
                        switch seg {
                        case .pending:  selectedSegment = .pending
                        case .approved: selectedSegment = .approved
                        case .claimed:  selectedSegment = .claimed
                        }
                    }
                ),
                pendingCount: pendingRequests.count,
                approvedCount: approvedRequests.count,
                claimedCount: claimedRequests.count
            )
            .padding(.horizontal)
            .padding(.bottom, 1) // tiny gap before the first section header

            segmentedLists
        }
        .padding(.top, 6) // slightly tighter under the big title
    }

    // Composer Card (input + preview + counter (moved to header))
    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Header row: Make a Request (left) + counter (right, aligned to TextField trailing)
            HStack(alignment: .firstTextBaseline) {
                Text("Make a Request")
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .font(.headline)

                Spacer(minLength: 8)

                // The trailing padding equals the Request button width + HStack spacing (8),
                // so this counter aligns with the TextField's trailing edge.
                Text("\(newRequestTitle.count)/\(maxCharacters)")
                    .font(.caption)
                    .foregroundStyle(atLimit ? Color.red : metaColor)
                    .padding(.trailing, requestButtonWidth + 8)
                    .accessibilityLabel("Characters used \(newRequestTitle.count) of \(maxCharacters)")
            }
            .padding(.top, 2)

            // Input row: single-line field + Request button
            HStack(spacing: 8) {
                TextField("What would you like to earn? (e.g. Go to the movies)", text: $newRequestTitle)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(reduceTransparency ? FuturistTheme.surfaceSolid : Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .focused($composerFocused)
                    .onChange(of: newRequestTitle) { _, _ in
                        if newRequestTitle.count > maxCharacters {
                            newRequestTitle = String(newRequestTitle.prefix(maxCharacters))
                        }
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showPreview = shouldShowPreview
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        showPreview = false
                    }
                    createRequest()
                } label: {
                    Text("Request")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(.white)
                        // Measure the button so we can align the counter to the TextField trailing above
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: RequestButtonWidthKey.self, value: geo.size.width)
                            }
                        )
                }
                .onPreferenceChange(RequestButtonWidthKey.self) { requestButtonWidth = $0 }
                .disabled(newRequestTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Your parent will review your request and set how many gems it costs.")
                .accessibilityLabel("Send request")
            }
            .onChange(of: composerFocused) { _, _ in
                withAnimation(.easeInOut(duration: 0.15)) {
                    showPreview = shouldShowPreview
                }
            }

            // Multi-line Preview (optional)
            if showPreview {
                VStack(alignment: .leading, spacing: 6) {
                    Text(newRequestTitle)
                        .font(.body)
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Preview")
                        .font(.caption2)
                        .foregroundStyle(FuturistTheme.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(reduceTransparency ? FuturistTheme.surfaceSolid : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityLabel("Preview of your request")
                .accessibilityHint("Shows the full text while typing")
            }
        }
        .padding(12)
        .background(CardBackground())
    }

    // Segmented lists below the pills
    private var segmentedLists: some View {
        Group {
            switch selectedSegment {
            case .pending:
                pendingList
            case .approved:
                approvedList
            case .claimed:
                claimedList
            }
        }
    }

    // MARK: - Lists

    private var pendingList: some View {
        List {
            // Pending items (editable)
            Section {
                if pendingRequests.isEmpty {
                    EmptyCard(text: "No pending requests to display.")
                } else {
                    ForEach(Array(pendingRequests.enumerated()), id: \.element.id) { index, req in
                        VStack(spacing: 0) {
                            RewardRequestRowView(
                                request: req,
                                childBalance: appState.childPointsTotal(childId: childId),
                                onEdit: { newTitle in
                                    _ = appState.updateRewardRequestTitle(id: req.id, newTitle: newTitle)
                                },
                                onDelete: {
                                    _ = appState.deleteRewardRequest(id: req.id)
                                },
                                onClaim: {},
                                onRequestAgain: { _ in },
                                headlineColor: FuturistTheme.textPrimary,
                                metaColor: metaColor
                            )
                        }
                        .padding(.bottom, Self.ruleExtraBottomPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(CardBackground())
                        .overlay(alignment: .bottomLeading) {
                            if index < pendingRequests.count - 1 {
                                TaskRowGradientRule(
                                    leadingInset: Self.ruleLeadingInset,
                                    trailingInset: Self.ruleTrailingInset,
                                    thickness: 2
                                )
                                .offset(y: Self.ruleVerticalOffset)
                            }
                        }
                    }
                }
            } header: {
                Text("Pending")
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .textCase(nil)
                    .padding(.top, 1)
                    .padding(.bottom, 1)
            }

            // Earlier Decisions (Not approved) — read-only, neutral
            if !notApprovedRequests.isEmpty {
                Section {
                    ForEach(Array(notApprovedRequests.enumerated()), id: \.element.id) { index, req in
                        VStack(spacing: 0) {
                            RewardRequestRowView(
                                request: req,
                                childBalance: appState.childPointsTotal(childId: childId),
                                onEdit: { _ in },
                                onDelete: { _ = appState.deleteRewardRequest(id: req.id) },
                                onClaim: {},
                                onRequestAgain: { _ in }, // could enable later
                                headlineColor: FuturistTheme.textPrimary,
                                metaColor: metaColor
                            )
                        }
                        .padding(.bottom, Self.ruleExtraBottomPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(CardBackground())
                        .overlay(alignment: .bottomLeading) {
                            if index < notApprovedRequests.count - 1 {
                                TaskRowGradientRule(
                                    leadingInset: Self.ruleLeadingInset,
                                    trailingInset: Self.ruleTrailingInset,
                                    thickness: 2
                                )
                                .offset(y: Self.ruleVerticalOffset)
                            }
                        }
                    }
                } header: {
                    Text("Earlier Decisions")
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .textCase(nil)
                        .padding(.top, 1)
                        .padding(.bottom, 1)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }

    private var approvedList: some View {
        List {
            Section {
                if approvedRequests.isEmpty {
                    EmptyCard(text: "No approved requests available to claim.")
                } else {
                    ForEach(Array(approvedRequests.enumerated()), id: \.element.id) { index, req in
                        VStack(spacing: 0) {
                            RewardRequestRowView(
                                request: req,
                                childBalance: appState.childPointsTotal(childId: childId),
                                onEdit: { _ in },
                                onDelete: { _ = appState.deleteRewardRequest(id: req.id) },
                                onClaim: {
                                    if appState.claimRewardRequest(id: req.id) {
                                        showToast("Enjoy! Gems spent.")
                                    } else {
                                        showToast("Not enough gems yet.")
                                    }
                                },
                                onRequestAgain: { _ in },
                                headlineColor: FuturistTheme.textPrimary,
                                metaColor: metaColor
                            )
                        }
                        .padding(.bottom, Self.ruleExtraBottomPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(CardBackground())
                        .overlay(alignment: .bottomLeading) {
                            if index < approvedRequests.count - 1 {
                                TaskRowGradientRule(
                                    leadingInset: Self.ruleLeadingInset,
                                    trailingInset: Self.ruleTrailingInset,
                                    thickness: 2
                                )
                                .offset(y: Self.ruleVerticalOffset)
                            }
                        }
                    }
                }
            } header: {
                Text("Approved")
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .textCase(nil)
                    .padding(.top, 1)
                    .padding(.bottom, 1)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }

    private var claimedList: some View {
        List {
            Section {
                if claimedRequests.isEmpty {
                    EmptyCard(text: "No claimed rewards yet.")
                } else {
                    ForEach(Array(claimedRequests.enumerated()), id: \.element.id) { index, req in
                        VStack(spacing: 0) {
                            RewardRequestRowView(
                                request: req,
                                childBalance: appState.childPointsTotal(childId: childId),
                                onEdit: { _ in },
                                onDelete: { _ = appState.deleteRewardRequest(id: req.id) },
                                onClaim: {},
                                onRequestAgain: { title in
                                    if appState.createRewardRequest(childId: childId, title: title) != nil {
                                        selectedSegment = .pending
                                        showToast("Request sent to parent.")
                                    } else {
                                        showToast("Couldn’t create request. Try again.")
                                    }
                                },
                                headlineColor: FuturistTheme.textPrimary,
                                metaColor: metaColor
                            )
                        }
                        .padding(.bottom, Self.ruleExtraBottomPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(CardBackground())
                        .overlay(alignment: .bottomLeading) {
                            if index < claimedRequests.count - 1 {
                                TaskRowGradientRule(
                                    leadingInset: Self.ruleLeadingInset,
                                    trailingInset: Self.ruleTrailingInset,
                                    thickness: 2
                                )
                                .offset(y: Self.ruleVerticalOffset)
                            }
                        }
                    }
                }
            } header: {
                Text("Claimed")
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .textCase(nil)
                    .padding(.top, 1)
                    .padding(.bottom, 1)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions
    private func createRequest() {
        let t = newRequestTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        if appState.createRewardRequest(childId: childId, title: t) != nil {
            newRequestTitle = ""
            composerFocused = false
            selectedSegment = .pending
            showToast("Request sent to parent.")
        } else {
            composerFocused = false
            showToast("Couldn’t create request. Try again.")
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Request row (child) — themed to match dark cards
private struct RewardRequestRowView: View {
    let request: RewardRequest
    let childBalance: Int
    let onEdit: (String) -> Void
    let onDelete: () -> Void
    let onClaim: () -> Void
    let onRequestAgain: (String) -> Void

    var headlineColor: Color = FuturistTheme.textPrimary
    var metaColor: Color = Color.white.opacity(0.78)

    @State private var editing: Bool = false
    @State private var editText: String = ""

    private var canEdit: Bool { request.status == .pending }
    private var canClaim: Bool {
        request.status == .approved && (request.approvedCost ?? .max) <= childBalance && (request.approvedCost ?? 0) > 0
    }

    private func statusDateLine() -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        switch request.status {
        case .claimed:
            if let d = request.claimedAt { return "Claimed on \(df.string(from: d))" }
            if let d = request.approvedAt { return "Approved on \(df.string(from: d))" }
            if let d = request.notApprovedAt { return "Not this time on \(df.string(from: d))" }
            return "Requested on \(df.string(from: request.requestedAt))"
        case .approved:
            if let d = request.approvedAt { return "Approved on \(df.string(from: d))" }
            return "Requested on \(df.string(from: request.requestedAt))"
        case .notApproved:
            if let d = request.notApprovedAt { return "Not this time on \(df.string(from: d))" }
            return "Requested on \(df.string(from: request.requestedAt))"
        case .pending:
            return "Requested on \(df.string(from: request.requestedAt))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + status badge OR editor
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if editing && canEdit {
                    TextField("Edit request", text: $editText)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .onAppear { editText = request.title }
                        .foregroundStyle(headlineColor)
                } else {
                    Text(request.title)
                        .font(.headline)
                        .foregroundStyle(headlineColor)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
                statusChip
            }

            // Status-specific date line
            Text(statusDateLine())
                .font(.footnote)
                .foregroundStyle(metaColor)

            // Actions row (now includes a small hint for Pending)
            HStack(spacing: 10) {
                if request.status == .pending {
                    Text("Parent will set the gem cost")
                        .font(.caption)
                        .foregroundStyle(metaColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if canEdit {
                    if editing {
                        Button("Save") {
                            let t = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty { onEdit(t) }
                            editing = false
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Cancel") { editing = false }
                            .buttonStyle(.bordered)
                    } else {
                        Button("Edit") { editing = true }
                            .buttonStyle(.bordered)
                    }
                }

                if request.status == .approved {
                    Button("Claim") { onClaim() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canClaim)
                        .accessibilityHint(canClaim ? "" : "Not enough gems yet")
                }

                Menu {
                    if request.status == .claimed {
                        Button {
                            onRequestAgain(request.title)
                        } label: {
                            Label("Request Again", systemImage: "arrow.uturn.left.circle")
                        }
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(metaColor)
                }
                .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 6)
    }

    private var statusChip: some View {
        let text = request.status.childDisplay
        let (bg, fg): (Color, Color) = {
            switch request.status {
            case .pending:
                return (Color.yellow.opacity(0.22), Color.orange)
            case .approved:
                return (Color.green.opacity(0.22), Color.green)
            case .notApproved:
                return (Color.white.opacity(0.14), Color.white.opacity(0.90))
            case .claimed:
                return (Color.blue.opacity(0.22), Color.blue)
            }
        }()
        return Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
    }
}
