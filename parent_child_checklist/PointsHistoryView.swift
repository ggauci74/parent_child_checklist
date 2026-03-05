//
// PointsHistoryView.swift
// parent_child_checklist
//
// Read-only ledger history for a child:
// - Shows current balance at the top
// - Shows last N days (matches AppState.ledgerWindowDays)
// - Adds a "Balance carried forward" snapshot item at cutoff when older entries existed
// - Coalesces bursty manual adjustments (±1 taps) into a single display row
// - Shows task titles for completed/un-ticked entries
// - Shows reward titles for claimed entries
// - The small subtitle row places the time first, then the item title (if any)
//

import SwiftUI

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
                   // Coalesce only when both are manualAdjust, same day, close in time
                   last.reason == .manualAdjust,
                   e.reason == .manualAdjust,
                   Calendar.current.isDate(last.day, inSameDayAs: day),
                   abs(last.createdAt.timeIntervalSince(e.createdAt)) <= burstWindow {
                    // Merge into the last row: sum delta, keep latest createdAt (last), keep any titles (none for manual)
                    let merged = DisplayRow(
                        day: last.day,
                        createdAt: last.createdAt,
                        delta: last.delta + e.delta,
                        reason: .manualAdjust,
                        assignmentId: nil,
                        isSnapshot: last.isSnapshot, // should be false for manual entries
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
    private var balanceText: String {
        String(appState.childPointsTotal(childId: childId))
    }

    var body: some View {
        NavigationStack {
            List {
                // Balance summary at top
                Section {
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
                }

                // If there was older history but the compactor didn’t insert a snapshot (net 0),
                // show a neutral "carried forward 0" line so the cutoff is obvious.
                if hadOlderHistory && !groupedDisplay.contains(where: { group in
                    group.rows.contains(where: { $0.isSnapshot })
                }) {
                    Section {
                        HStack {
                            Text("Balance carried forward")
                            Spacer()
                            Text("💎 0")
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    } footer: {
                        Text("Older history summarized at \(formatDate(cutoffDay)).")
                    }
                }

                // Render grouped sections
                ForEach(groupedDisplay) { group in
                    Section(header: Text(sectionHeader(group.day))) {
                        ForEach(group.rows) { row in
                            historyRow(row)
                        }
                    }
                }

                if groupedDisplay.isEmpty && !hadOlderHistory {
                    Section {
                        Text("No history yet.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("\(child?.name ?? "Child") — History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Row View

    @ViewBuilder
    private func historyRow(_ row: DisplayRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            // LEFT: Reason + subtitle (time first, then item title)
            VStack(alignment: .leading, spacing: 2) {
                Text(reasonText(row))
                    .font(.subheadline)

                if let subtitle = subtitleText(row) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // RIGHT: Delta
            Text(deltaText(row.delta))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(row.delta >= 0 ? .green : .red)
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

    private func reasonText(_ row: DisplayRow) -> String {
        if row.isSnapshot { return "Balance carried forward" }

        switch row.reason {
        case .manualAdjust:
            return "Manual adjust"

        case .redeemed:
            return "Reward claimed"

        case .missedPenalty:
            return "Missed task penalty"

        case .completed:
            return row.delta >= 0 ? "Task completed" : "Task un-ticked"
        }
    }

    /// Subtitle: "{time}  •  {item title (if any)}"
    private func subtitleText(_ row: DisplayRow) -> String? {
        // No subtitle for snapshot (it is pinned to cutoff)
        if row.isSnapshot { return "as at \(formatDate(row.day))" }

        let timeStr = formatTime(row.createdAt)

        // Decide which item title to show (task or reward)
        if row.reason == .completed, let t = row.taskTitle, !t.trimmed.isEmpty {
            return "\(timeStr) • \(t)"
        }
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

    private func sectionHeader(_ date: Date) -> String {
        formatDate(date)
    }

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
            $0.childId == childId &&
            ($0.status == .claimed || $0.claimedAt != nil) &&
            ($0.approvedCost ?? 0) == absCost
        }

        // Pick the one with closest claimedAt to the ledger entry timestamp within the time window
        var best: (req: RewardRequest, diff: TimeInterval)? = nil
        for req in candidates {
            guard let ct = req.claimedAt else { continue }
            let diff = abs(ct.timeIntervalSince(created))
            if diff <= rewardMatchWindow {
                if best == nil || diff < best!.diff {
                    best = (req, diff)
                }
            }
        }
        return best?.req.title
    }
}
