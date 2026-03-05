//
// PointsEntry.swift
// parent_child_checklist
//
// Append-only points ledger entries.
// Reason = .completed used for task toggles.
// Reason = .redeemed used when a child claims an approved reward request.
//

import Foundation

enum PointsReason: String, Codable, Hashable {
    case completed       // +rewardPoints when a task is marked completed, -rewardPoints when un-ticked
    case missedPenalty   // (future) -rewardPoints at end of day if subtractIfNotCompleted == true
    case manualAdjust    // (future) admin/manual corrections
    case redeemed        // NEW: child redeemed an approved reward request (spend gems)
}

struct PointsEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let childId: UUID
    let assignmentId: UUID?
    /// Start-of-day date in the user's current calendar/time zone.
    let day: Date
    /// Positive for awards, negative for reversals/penalties/spend.
    let delta: Int
    let reason: PointsReason
    let createdAt: Date

    init(
        id: UUID = UUID(),
        childId: UUID,
        assignmentId: UUID?,
        day: Date,
        delta: Int,
        reason: PointsReason,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.childId = childId
        self.assignmentId = assignmentId
        self.day = day
        self.delta = delta
        self.reason = reason
        self.createdAt = createdAt
    }
}
