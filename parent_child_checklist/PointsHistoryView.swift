//
//  PointsHistoryView.swift
//  parent_child_checklist
//
//  Read-only ledger history for a child (Futurist theme):
//  - Curvy background, safe-area header (Close pill + centered title + Clean pill)
//  - Frosted cards + neon filament separators (non-breathing ScrollView)
//  - Balance card at the top
//  - Day sections with cardized entries
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
}

// MARK: - Layout metrics
private enum PageMetrics {
    static let pageHPad: CGFloat     = 12
    static let innerHPad: CGFloat    = 16
    static let cornerRadius: CGFloat = 14
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

// MARK: - Bright cyan filament (separator between cards)
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
            startPoint: .leading, endPoint: .trailing
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

// MARK: - Toolbar pill button (Close / Clean)
private struct ToolbarPillButton: View {
    let label: String
    var foreground: Color
    var background: Color
    var stroke: Color
    var fixedWidth: CGFloat? = 76
    var fixedHeight: CGFloat? = 32
    var action: () -> Void

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: fixedWidth, height: fixedHeight)
            .background(Capsule().fill(background))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
            .shadow(color: FuturistTheme.cardShadow, radius: 3)
            .contentShape(Capsule())
            .onTapGesture { action() }
    }
}

// MARK: - Main
struct PointsHistoryView: View {
    let childId: UUID
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // How tightly to group manual +/- taps into one display row
    private let burstWindow: TimeInterval = 60 // seconds

    // How far to look around a .redeemed points entry to match the claimed RewardRequest (title)
    private let rewardMatchWindow: TimeInterval = 5 * 60 // 5 minutes

    private var child: ChildProfile? {
        appState.children.first(where: { $0.id == childId })
    }

    private var cutoffDay: Date {
        let days = appState.ledgerWindowDays
        let now = Date()
        let date = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        return Calendar.current.startOfDay(for: date)
    }

    // Raw recent entries (>= cutoff), newest first by day then createdAt
    private var recentEntriesRaw: [PointsEntry] {
        appState.pointsLedger
            .filter { $0.childId == childId && Calendar.current.startOfDay(for: $0.day) >= cutoffDay }
            .sorted {
                let d0 = Calendar.current.startOfDay(for: $0.day)
                let d1 = Calendar.current.startOfDay(for: $1.day)
                if d0 != d1 { return d0 > d1 }            // newer day first
                return $0.createdAt > $1.createdAt        // newer within day first
            }
    }

    // Whether there was older history (before cutoff).
    private var hadOlderHistory: Bool {
        appState.pointsLedger.contains { $0.childId == childId && Calendar.current.startOfDay(for: $0.day) < cutoffDay }
    }

    // Display model (coalesced)
    private struct DisplayRow: Identifiable, Equatable {
        let id = UUID()
        let day: Date
        let createdAt: Date
        let delta: Int
        let reason: PointsReason
        let assignmentId: UUID?
        let isSnapshot: Bool
        let coalescedCount: Int  // how many raw entries make up this display row
        // Optional resolved titles
        let taskTitle: String?
        let rewardTitle: String?
    }

    private struct DayGroup: Identifiable {
        let id = UUID()
        let day: Date
        let rows: [DisplayRow]
    }

    private var groupedDisplay: [DayGroup] {
        // 1) group raw entries by day (newest day first)
        let dict = Dictionary(grouping: recentEntriesRaw, by: { Calendar.current.startOfDay(for: $0.day) })
        let days = dict.keys.sorted(by: >)

        // 2) for each day, coalesce manual bursts and map to DisplayRow
        return days.map { day in
            let items = dict[day]!.sorted(by: { $0.createdAt > $1.createdAt }) // newest first

            var rows: [DisplayRow] = []
            rows.reserveCapacity(items.count)

            for e in items {
                let snapshotFlag = isSnapshot(e, cutoffDay: cutoffDay)
                // Resolve titles
                let resolvedTaskTitle: String? = e.assignmentId.flatMap { aid in
                    appState.taskAssignments.first(where: { $0.id == aid })?.taskTitle
                }
                let resolvedRewardTitle: String? = (e.reason == .redeemed) ? findClaimedRewardTitle(matching: e) : nil

                if let last = rows.last,
                   last.reason == .manualAdjust,
                   e.reason == .manualAdjust,
                   Calendar.current.isDate(last.day, inSameDayAs: day),
                   abs(last.createdAt.timeIntervalSince(e.createdAt)) <= burstWindow {
                    // Merge into last
                    let merged = DisplayRow(
                        day: last.day,
                        createdAt: last.createdAt,
                        delta: last.delta + e.delta,
                        reason: .manualAdjust,
                        assignmentId: nil,
                        isSnapshot: last.isSnapshot,
                        coalescedCount: last.coalescedCount + 1,
                        taskTitle: nil,
                        rewardTitle: nil
                    )
                    rows[rows.count - 1] = merged
                } else {
                    // New row
                    rows.append(DisplayRow(
                        day: day,
                        createdAt: e.createdAt,
                        delta: e.delta,
                        reason: e.reason,
                        assignmentId: e.assignmentId,
                        isSnapshot: snapshotFlag,
                        coalescedCount: 1,
                        taskTitle: resolvedTaskTitle,
                        rewardTitle: resolvedRewardTitle
                    ))
                }
            }

            return DayGroup(day: day, rows: rows)
        }
    }

    // Current balance text
    private var balanceText: String { String(appState.childPointsTotal(childId: childId)) }

    // MARK: - Clean confirmation state
    @State private var showCleanConfirm: Bool = false
    @State private var cleanPreview: AppState.HistoryCleanPreview? = nil
    @State private var showingNothingToCleanToast: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ===== Balance card =====
                        FrostedCard {
                            HStack(spacing: 10) {
                                Text("💎")
                                    .font(.system(size: 24))
                                Text(balanceText)
                                    .font(.system(size: 24, weight: .bold))
                                Spacer()
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Current balance")
                            .accessibilityValue(balanceText)
                            .foregroundStyle(FuturistTheme.textPrimary)
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)
                        .padding(.top, 12)

                        // If there was older history but compactor didn’t insert a snapshot, show neutral carried-forward 0.
                        if hadOlderHistory && !groupedDisplay.contains(where: { $0.rows.contains(where: { $0.isSnapshot }) }) {
                            BrightLineSeparator()
                            FrostedCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Balance carried forward")
                                        Spacer()
                                        Text("💎 0")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(FuturistTheme.textSecondary)
                                    }
                                    .font(.subheadline)
                                    Text("Older history summarized at \(formatDate(cutoffDay)).")
                                        .font(.footnote)
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                }
                                .foregroundStyle(FuturistTheme.textPrimary)
                            }
                            .padding(.horizontal, PageMetrics.pageHPad)
                        }

                        // ===== Day sections =====
                        if groupedDisplay.isEmpty && !hadOlderHistory {
                            BrightLineSeparator()
                            FrostedCard {
                                Text("No history yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                            }
                            .padding(.horizontal, PageMetrics.pageHPad)
                        } else {
                            ForEach(groupedDisplay) { group in
                                // Day header
                                Text(sectionHeader(group.day))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 12)
                                    .padding(.horizontal, PageMetrics.pageHPad)

                                // Entries for the day
                                LazyVStack(spacing: 0) {
                                    ForEach(Array(group.rows.enumerated()), id: \.element.id) { idx, row in
                                        FrostedCard {
                                            historyRowContent(row)
                                        }
                                        .padding(.horizontal, PageMetrics.pageHPad)

                                        if idx < group.rows.count - 1 {
                                            BrightLineSeparator()
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.bottom, 24)
                }

                // Tiny toast if there's nothing to clean
                if showingNothingToCleanToast {
                    VStack {
                        Text("Nothing to clean")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.white.opacity(0.12))
                            )
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                            .foregroundStyle(FuturistTheme.textPrimary)
                            .shadow(color: Color.black.opacity(0.25), radius: 3)
                        Spacer()
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                }
            }
            // Hide system nav; themed header below
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // Header (Close pill + centered title + Clean pill)
            .safeAreaInset(edge: .top, spacing: 0) {
                let topSpacer: CGFloat = 8
                ZStack {
                    Text("\(child?.name ?? "Child") — History")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    VStack(spacing: 0) {
                        Color.clear.frame(height: topSpacer)
                        HStack {
                            // Close (left)
                            ToolbarPillButton(
                                label: "Close",
                                foreground: .white,
                                background: Color(red: 1.00, green: 0.58, blue: 0.63), // softRedLight
                                stroke: Color(red: 1.00, green: 0.36, blue: 0.43).opacity(0.75), // softRedBase
                                action: { dismiss() }
                            )
                            Spacer()
                            // Clean (right)
                            ToolbarPillButton(
                                label: "Clean",
                                foreground: Color.black.opacity(0.9),
                                background: Color.white, // high contrast
                                stroke: Color.white.opacity(0.85),
                                action: { onTapClean() }
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .background(Color.clear)
            }

            // Confirm clean dialog
            .alert("Clean history for \(child?.name ?? "this child")?",
                   isPresented: $showCleanConfirm,
                   presenting: cleanPreview) { preview in
                Button("Clean", role: .destructive) {
                    _ = appState.cleanChildPointsHistory(childId: childId)
                }
                Button("Cancel", role: .cancel) { }
            } message: { preview in
                Text("""
                     We’ll remove rows that don’t affect the current total and keep only the entries needed.
                     Will remove \(preview.removeCount) and keep \(preview.keepCount).
                     """)
            }
        }
    }

    // MARK: - Row content (themed)
    @ViewBuilder
    private func historyRowContent(_ row: DisplayRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // LEFT: Primary + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(reasonText(row))                 // <-- UPDATED: includes task title inline for completed rows
                    .font(.subheadline)
                    .foregroundStyle(FuturistTheme.textPrimary)

                if let subtitle = subtitleText(row) { // <-- UPDATED: completed rows now show time only
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(FuturistTheme.textSecondary)
                }
            }

            Spacer()

            // RIGHT: Delta
            Text(deltaText(row.delta))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.delta >= 0 ? Color.green : Color.red)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reasonText(row)), \(deltaText(row.delta))")
    }

    // MARK: - Snapshot detection
    private func isSnapshot(_ e: PointsEntry, cutoffDay: Date) -> Bool {
        // Heuristic: compactor creates `.manualAdjust` at cutoff with assignmentId == nil
        return e.reason == .manualAdjust
            && Calendar.current.isDate(e.day, inSameDayAs: cutoffDay)
            && Calendar.current.isDate(e.createdAt, inSameDayAs: cutoffDay)
            && e.assignmentId == nil
    }

    // MARK: - Reason + subtitle + delta formatting
    /// Primary line (e.g., "Task completed — Brush Teeth")
    private func reasonText(_ row: DisplayRow) -> String {
        if row.isSnapshot { return "Balance carried forward" }

        switch row.reason {
        case .manualAdjust:
            return "Manual adjust"

        case .redeemed:
            // Reward title stays on subtitle (consistent with current design)
            return "Reward claimed"

        case .missedPenalty:
            return "Missed task penalty"

        case .completed:
            // Include task title on primary line when available
            if let t = row.taskTitle, !t.trimmed.isEmpty {
                return (row.delta >= 0) ? "Task completed — \(t)" : "Task un-ticked — \(t)"
            } else {
                return (row.delta >= 0) ? "Task completed" : "Task un-ticked"
            }
        }
    }

    /// Subtitle: time (and for rewards, also reward title)
    private func subtitleText(_ row: DisplayRow) -> String? {
        // Snapshot subtitle shows the cutoff date
        if row.isSnapshot { return "as at \(formatDate(row.day))" }

        let timeStr = formatTime(row.createdAt)

        // Completed rows: we now show the task title on the primary line, so subtitle is just time.
        if row.reason == .completed {
            return timeStr
        }

        // Rewards: keep reward title on subtitle (time • title)
        if row.reason == .redeemed, let r = row.rewardTitle, !r.trimmed.isEmpty {
            return "\(timeStr) • \(r)"
        }

        // Otherwise just time
        return timeStr
    }

    private func deltaText(_ delta: Int) -> String {
        let sign = delta >= 0 ? "+" : "–"
        return "\(sign)\(abs(delta))"
    }

    private func sectionHeader(_ date: Date) -> String { formatDate(date) }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let tf = DateFormatter()
        tf.dateStyle = .none
        tf.timeStyle = .short
        return tf.string(from: date)
    }

    // MARK: - Reward title resolver
    /// Best-effort match of a `.redeemed` ledger entry to a claimed RewardRequest to display its title.
    /// Matches by same child, absolute delta == approvedCost, and claimedAt within ±rewardMatchWindow of createdAt.
    private func findClaimedRewardTitle(matching entry: PointsEntry) -> String? {
        let absCost = abs(entry.delta)
        let created = entry.createdAt

        // Candidate claimed requests for this child with same cost
        let candidates = appState.rewardRequests.filter {
            $0.childId == childId
            && ($0.status == .claimed || $0.claimedAt != nil)
            && ($0.approvedCost ?? 0) == absCost
        }

        // Pick the one with closest claimedAt within the window
        var best: (req: RewardRequest, diff: TimeInterval)? = nil
        for req in candidates {
            guard let ct = req.claimedAt else { continue }
            let diff = abs(ct.timeIntervalSince(created))
            if diff <= rewardMatchWindow {
                if best == nil || diff < best!.diff { best = (req, diff) }
            }
        }
        return best?.req.title
    }

    // MARK: - Clean action (preview → confirm)
    private func onTapClean() {
        let preview = appState.previewCleanChildPointsHistory(childId: childId)
        cleanPreview = preview
        if preview.removeCount == 0 {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) { showingNothingToCleanToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeOut(duration: 0.20)) { showingNothingToCleanToast = false }
            }
        } else {
            showCleanConfirm = true
        }
    }
}
