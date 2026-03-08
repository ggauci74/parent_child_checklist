//
// Models.swift
// parent_child_checklist
//

import Foundation
import SwiftUI

// MARK: - Shared Notify Recipient (for Tasks & Events notifications)
enum NotifyRecipient: String, Codable, Hashable, CaseIterable, Identifiable {
    case both
    case parent
    case child
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .both: return "Both"
        case .parent: return "Parent"
        case .child: return "Child"
        }
    }
}

// MARK: - Child Profile (now includes pairingEpoch for QR pairing invalidation)
struct ChildProfile: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var colorHex: String
    /// Child-chosen avatar preset ID.
    /// - nil means "Not chosen yet" (show placeholder in parent UI).
    var avatarId: String?

    /// Used to invalidate previously issued pairing tokens (QR codes).
    /// If the parent taps "Reset Pairing" for this child, we bump this number.
    /// Devices must present a token signed for the current epoch to (re)bind.
    var pairingEpoch: Int

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        avatarId: String? = nil,
        pairingEpoch: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.avatarId = avatarId
        self.pairingEpoch = pairingEpoch
    }

    // Defensive decoding for older local JSON that doesn't have pairingEpoch yet.
    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, avatarId, pairingEpoch
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.name = (try? c.decode(String.self, forKey: .name)) ?? ""
        self.colorHex = (try? c.decode(String.self, forKey: .colorHex)) ?? "#4A7DFF"
        self.avatarId = try? c.decode(String?.self, forKey: .avatarId)
        self.pairingEpoch = (try? c.decode(Int.self, forKey: .pairingEpoch)) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encodeIfPresent(avatarId, forKey: .avatarId)
        try c.encode(pairingEpoch, forKey: .pairingEpoch)
    }
}

// MARK: - QR Pairing Token (model only; signing/verification lives in service file)
struct PairingToken: Codable, Hashable {
    let childId: UUID
    let issuedAt: Date
    let expiresAt: Date
    let nonce: String
    let pairingEpoch: Int
    /// Optional family scoping if needed later.
    var familyId: UUID?
    /// App version that generated the token (useful for troubleshooting).
    var appVersion: String?
}

// Parent-created reusable tasks (Task Library / Templates)
struct TaskTemplate: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    /// Emoji string stored here
    var iconSymbol: String
    /// Reward points for completing this task (min 0)
    var rewardPoints: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        iconSymbol: String,
        rewardPoints: Int = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.iconSymbol = iconSymbol
        self.rewardPoints = max(0, rewardPoints)
        self.createdAt = createdAt
    }

    // Defensive decoding for older local JSON
    enum CodingKeys: String, CodingKey {
        case id, title, iconSymbol, rewardPoints, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        iconSymbol = (try? container.decode(String.self, forKey: .iconSymbol)) ?? "✅"
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        // If rewardPoints is missing (old saved data), default to 1
        let decodedPoints = (try? container.decode(Int.self, forKey: .rewardPoints)) ?? 1
        rewardPoints = max(0, decodedPoints)
    }
}

// MARK: - Task Assignment (Child-specific, fully captured snapshot)
struct TaskAssignment: Identifiable, Hashable, Codable {
    enum Occurrence: String, Codable, CaseIterable, Identifiable {
        case onceOnly
        case specifiedDays
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .onceOnly: return "Once Only"
            case .specifiedDays: return "Specified Days"
            }
        }
    }

    let id: UUID
    // Ownership
    var childId: UUID
    /// Optional reference to the template used at assignment time.
    /// We keep the snapshot fields below as the source of truth.
    var templateId: UUID?
    // Snapshot
    var taskTitle: String
    var taskIcon: String
    var rewardPoints: Int
    // Optional guidance
    var helper: String?
    // Options
    var subtractIfNotCompleted: Bool
    var alertMe: Bool
    var photoEvidenceRequired: Bool
    var isActive: Bool
    // Dates
    var startDate: Date
    var endDate: Date?
    // Schedule
    var occurrence: Occurrence
    /// Monday-first weekday selection: 0=Mon ... 6=Sun
    var weekdays: [Int]
    // Time windows (optional)
    var startTime: Date?
    var finishTime: Date?
    // Duration (optional)
    var durationMinutes: Int?
    // NEW: Link to an event assignment (optional)
    /// If set, this task is dependent on that event assignment.
    /// If the event assignment is deleted, this task should also be deleted (Option A).
    var linkedEventAssignmentId: UUID?
    // NEW: Notify (Start)
    var startNotifyEnabled: Bool
    var startNotifyRecipient: NotifyRecipient
    /// Minutes before start (0 = at start time). Nil when disabled.
    var startNotifyOffsetMinutes: Int?
    // NEW: Notify (Finish)
    var finishNotifyEnabled: Bool
    var finishNotifyRecipient: NotifyRecipient
    /// Minutes before finish (0 = at finish time). Nil when disabled.
    var finishNotifyOffsetMinutes: Int?
    // Audit
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        childId: UUID,
        templateId: UUID? = nil,
        taskTitle: String,
        taskIcon: String,
        rewardPoints: Int,
        helper: String? = nil,
        subtractIfNotCompleted: Bool = false,
        alertMe: Bool = false,
        photoEvidenceRequired: Bool = false,
        isActive: Bool = true,
        startDate: Date,
        endDate: Date? = nil,
        occurrence: Occurrence = .specifiedDays,
        weekdays: [Int] = [0,1,2,3,4,5,6],
        startTime: Date? = nil,
        finishTime: Date? = nil,
        durationMinutes: Int? = nil,
        linkedEventAssignmentId: UUID? = nil,
        // NEW notify defaults (UI-only until wired)
        startNotifyEnabled: Bool = false,
        startNotifyRecipient: NotifyRecipient = .both,
        startNotifyOffsetMinutes: Int? = nil,
        finishNotifyEnabled: Bool = false,
        finishNotifyRecipient: NotifyRecipient = .both,
        finishNotifyOffsetMinutes: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.childId = childId
        self.templateId = templateId
        self.taskTitle = taskTitle
        self.taskIcon = taskIcon
        self.rewardPoints = max(0, rewardPoints)
        self.helper = helper
        self.subtractIfNotCompleted = subtractIfNotCompleted
        self.alertMe = alertMe
        self.photoEvidenceRequired = photoEvidenceRequired
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
        self.occurrence = occurrence
        self.weekdays = weekdays.sorted()
        self.startTime = startTime
        self.finishTime = finishTime
        self.durationMinutes = durationMinutes
        self.linkedEventAssignmentId = linkedEventAssignmentId
        self.startNotifyEnabled = startNotifyEnabled
        self.startNotifyRecipient = startNotifyRecipient
        self.startNotifyOffsetMinutes = startNotifyOffsetMinutes
        self.finishNotifyEnabled = finishNotifyEnabled
        self.finishNotifyRecipient = finishNotifyRecipient
        self.finishNotifyOffsetMinutes = finishNotifyOffsetMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, childId, templateId
        case taskTitle, taskIcon, rewardPoints, helper
        case subtractIfNotCompleted, alertMe, photoEvidenceRequired, isActive
        case startDate, endDate, occurrence, weekdays
        case startTime, finishTime, durationMinutes
        case linkedEventAssignmentId
        case startNotifyEnabled, startNotifyRecipient, startNotifyOffsetMinutes
        case finishNotifyEnabled, finishNotifyRecipient, finishNotifyOffsetMinutes
        case createdAt, updatedAt
    }
}

// MARK: - Task Completion Record (per assignment per day) + Photo Evidence
struct TaskCompletionRecord: Identifiable, Hashable, Codable {
    let id: UUID
    var assignmentId: UUID
    /// Stored as the start-of-day date (local calendar)
    var day: Date
    /// Optional timestamp
    var completedAt: Date?

    // ---- Photo Evidence (CloudKit CKAsset) ----
    /// True when a photo evidence asset exists on this record in CloudKit.
    /// Persisted in local JSON for lightweight UI decisions (e.g., an indicator),
    /// while the actual local file URLs (below) remain transient/unencoded.
    var hasPhotoEvidence: Bool
    /// Local temporary URL of the downloaded full-resolution CKAsset (transient; not encoded).
    var photoEvidenceLocalURL: URL?
    /// Local temporary URL of the downloaded thumbnail CKAsset (transient; not encoded).
    var photoThumbnailLocalURL: URL?

    init(
        id: UUID = UUID(),
        assignmentId: UUID,
        day: Date,
        completedAt: Date? = nil,
        hasPhotoEvidence: Bool = false,
        photoEvidenceLocalURL: URL? = nil,
        photoThumbnailLocalURL: URL? = nil
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.day = day
        self.completedAt = completedAt
        self.hasPhotoEvidence = hasPhotoEvidence
        self.photoEvidenceLocalURL = photoEvidenceLocalURL
        self.photoThumbnailLocalURL = photoThumbnailLocalURL
    }

    // Encode only stable metadata; do not persist transient file URLs
    enum CodingKeys: String, CodingKey {
        case id, assignmentId, day, completedAt, hasPhotoEvidence
        // NOTE: photoEvidenceLocalURL, photoThumbnailLocalURL intentionally omitted
    }
}

// Represents a single task assigned to a child (legacy placeholder; will be replaced later)
struct TaskItem: Identifiable, Hashable, Codable {
    let id: UUID
    var childId: UUID
    var title: String
    var iconSymbol: String
    var isCompleteToday: Bool
    var lastCompletedAt: Date?

    init(
        id: UUID = UUID(),
        childId: UUID,
        title: String,
        iconSymbol: String,
        isCompleteToday: Bool = false,
        lastCompletedAt: Date? = nil
    ) {
        self.id = id
        self.childId = childId
        self.title = title
        self.iconSymbol = iconSymbol
        self.isCompleteToday = isCompleteToday
        self.lastCompletedAt = lastCompletedAt
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8:
            (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - EVENTS + LOCATIONS
/// Parent-defined locations list (reused by event assignments)
struct LocationItem: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Event template = what the event is (no location here)
struct EventTemplate: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var iconSymbol: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        iconSymbol: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.iconSymbol = iconSymbol
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// EventAssignment = scheduled instance for a child (includes optional location + alert offset)
struct EventAssignment: Identifiable, Hashable, Codable {
    enum Occurrence: String, Codable, CaseIterable, Identifiable {
        case onceOnly
        case specifiedDays
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .onceOnly: return "Once Only"
            case .specifiedDays: return "Specified Days"
            }
        }
    }

    let id: UUID
    // Ownership
    var childId: UUID
    var templateId: UUID?
    // Snapshot
    var eventTitle: String
    var eventIcon: String
    // Optional helper
    var helper: String?
    // Active toggle
    var isActive: Bool
    // Dates / schedule
    var startDate: Date
    var endDate: Date?
    var occurrence: Occurrence
    /// Monday-first weekday selection: 0=Mon ... 6=Sun
    var weekdays: [Int]
    // Time
    var startTime: Date?
    var finishTime: Date?
    var durationMinutes: Int?
    // Location (per assignment)
    var locationId: UUID?
    var locationNameSnapshot: String
    // Alerts (legacy single-field alerts; kept)
    var alertMe: Bool
    /// Minutes before start time (0 = at start time). Nil when alertMe == false.
    var alertOffsetMinutes: Int?
    // NEW: Notify (Start)
    var startNotifyEnabled: Bool
    var startNotifyRecipient: NotifyRecipient
    var startNotifyOffsetMinutes: Int?
    // NEW: Notify (Finish)
    var finishNotifyEnabled: Bool
    var finishNotifyRecipient: NotifyRecipient
    var finishNotifyOffsetMinutes: Int?
    // Audit
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        childId: UUID,
        templateId: UUID? = nil,
        eventTitle: String,
        eventIcon: String,
        helper: String? = nil,
        isActive: Bool = true,
        startDate: Date,
        endDate: Date? = nil,
        occurrence: Occurrence = .specifiedDays,
        weekdays: [Int] = [0,1,2,3,4,5,6],
        startTime: Date? = nil,
        finishTime: Date? = nil,
        durationMinutes: Int? = nil,
        locationId: UUID? = nil,
        locationNameSnapshot: String = "",
        alertMe: Bool = false,
        alertOffsetMinutes: Int? = nil,
        // NEW notify defaults
        startNotifyEnabled: Bool = false,
        startNotifyRecipient: NotifyRecipient = .both,
        startNotifyOffsetMinutes: Int? = nil,
        finishNotifyEnabled: Bool = false,
        finishNotifyRecipient: NotifyRecipient = .both,
        finishNotifyOffsetMinutes: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.childId = childId
        self.templateId = templateId
        self.eventTitle = eventTitle
        self.eventIcon = eventIcon
        self.helper = helper
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
        self.occurrence = occurrence
        self.weekdays = weekdays.sorted()
        self.startTime = startTime
        self.finishTime = finishTime
        self.durationMinutes = durationMinutes
        self.locationId = locationId
        self.locationNameSnapshot = locationNameSnapshot
        self.alertMe = alertMe
        self.alertOffsetMinutes = alertOffsetMinutes
        self.startNotifyEnabled = startNotifyEnabled
        self.startNotifyRecipient = startNotifyRecipient
        self.startNotifyOffsetMinutes = startNotifyOffsetMinutes
        self.finishNotifyEnabled = finishNotifyEnabled
        self.finishNotifyRecipient = finishNotifyRecipient
        self.finishNotifyOffsetMinutes = finishNotifyOffsetMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, childId, templateId
        case eventTitle, eventIcon, helper, isActive
        case startDate, endDate, occurrence, weekdays
        case startTime, finishTime, durationMinutes
        case locationId, locationNameSnapshot
        case alertMe, alertOffsetMinutes
        case startNotifyEnabled, startNotifyRecipient, startNotifyOffsetMinutes
        case finishNotifyEnabled, finishNotifyRecipient, finishNotifyOffsetMinutes
        case createdAt, updatedAt
    }
}

// MARK: - Reward Requests
enum RewardRequestStatus: String, Codable, Hashable, CaseIterable, Identifiable {
    case pending
    case approved
    case notApproved
    case claimed
    var id: String { rawValue }
    /// Child-facing friendly label for status
    var childDisplay: String {
        switch self {
        case .pending: return "Sent to parent"
        case .approved: return "Approved"
        case .notApproved: return "Not this time"
        case .claimed: return "Claimed"
        }
    }
}

/// Child asks for something in exchange for gems; parent may approve with a gem cost.
/// Claiming is only allowed when approved and the child has enough gems.
struct RewardRequest: Identifiable, Hashable, Codable {
    let id: UUID
    var childId: UUID
    var title: String
    var status: RewardRequestStatus
    var approvedCost: Int? // gems, set by parent upon approval

    // Lifecycle timestamps
    var requestedAt: Date // when first submitted
    var approvedAt: Date? // when approved
    var notApprovedAt: Date? // when marked "Not this time"
    var claimedAt: Date? // when claimed

    // General bookkeeping
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        childId: UUID,
        title: String,
        status: RewardRequestStatus = .pending,
        approvedCost: Int? = nil,
        requestedAt: Date = Date(),
        approvedAt: Date? = nil,
        notApprovedAt: Date? = nil,
        claimedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.childId = childId
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.status = status
        self.approvedCost = approvedCost
        self.requestedAt = requestedAt
        self.approvedAt = approvedAt
        self.notApprovedAt = notApprovedAt
        self.claimedAt = claimedAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, childId, title, status, approvedCost, requestedAt, approvedAt, notApprovedAt, claimedAt, updatedAt
    }
}
