//
// CloudKitSchema.swift
// parent_child_checklist
//
// Created by George Gauci on 10/2/2026.
//

import Foundation
import CloudKit

/// Central place for all record types + field keys.
/// Keep this in sync with Models.swift.
enum CKSchema {
    // MARK: - Zone
    static let familyZoneName = "FamilyZone"

    // MARK: - Record Types
    enum RecordType {
        static let familyMeta      = "FamilyMeta"
        static let emojiLibrary    = "EmojiLibrary"
        static let childProfile    = "ChildProfile"
        static let taskTemplate    = "TaskTemplate"
        static let taskAssignment  = "TaskAssignment"
        static let taskCompletion  = "TaskCompletionRecord"
        static let locationItem    = "LocationItem"
        static let eventTemplate   = "EventTemplate"
        static let eventAssignment = "EventAssignment"
    }

    // MARK: - Common Fields
    enum Common {
        static let id            = "id"            // String UUID
        static let createdAt     = "createdAt"     // Date
        static let updatedAt     = "updatedAt"     // Date
        static let schemaVersion = "schemaVersion" // Int
    }

    // MARK: - FamilyMeta Fields
    enum FamilyMeta {
        static let title         = "title"         // String
        static let createdAt     = "createdAt"     // Date
        static let schemaVersion = "schemaVersion" // Int
    }

    // MARK: - EmojiLibrary Fields
    enum EmojiLibrary {
        static let emojis    = "emojis"    // [String]
        static let updatedAt = "updatedAt" // Date
    }

    // MARK: - ChildProfile Fields
    enum ChildProfile {
        static let id       = Common.id
        static let name     = "name"       // String
        static let colorHex = "colorHex"   // String
        static let avatarId = "avatarId"   // String? (store as String, omit if nil)

        /// NEW: Used to invalidate previously issued pairing tokens (QR codes) for this child.
        /// Parent can bump this to force re‑pairing on devices.
        static let pairingEpoch = "pairingEpoch" // Int

        static let updatedAt = Common.updatedAt
    }

    // MARK: - TaskTemplate Fields
    enum TaskTemplate {
        static let id           = Common.id
        static let title        = "title"        // String
        static let iconSymbol   = "iconSymbol"   // String
        static let rewardPoints = "rewardPoints" // Int
        static let createdAt    = "createdAt"    // Date
    }

    // MARK: - TaskAssignment Fields
    enum TaskAssignment {
        static let id        = Common.id
        static let childId   = "childId"    // String UUID
        static let templateId = "templateId" // String? UUID
        // Snapshot
        static let taskTitle   = "taskTitle"   // String
        static let taskIcon    = "taskIcon"    // String
        static let rewardPoints = "rewardPoints" // Int
        static let helper      = "helper"      // String?
        // Options
        static let subtractIfNotCompleted = "subtractIfNotCompleted" // Bool
        static let alertMe     = "alertMe"    // Bool
        static let photoEvidenceRequired = "photoEvidenceRequired" // Bool
        static let isActive    = "isActive"   // Bool
        // Dates
        static let startDate   = "startDate"  // Date
        static let endDate     = "endDate"    // Date?
        // Schedule
        static let occurrence  = "occurrence" // String rawValue
        static let weekdays    = "weekdays"   // [Int] as [NSNumber]
        // Time windows
        static let startTime   = "startTime"  // Date?
        static let finishTime  = "finishTime" // Date?
        // Duration
        static let durationMinutes = "durationMinutes" // Int?
        // Linked event
        static let linkedEventAssignmentId = "linkedEventAssignmentId" // String? UUID
        // NEW: Notify (Start)
        static let startNotifyEnabled        = "startNotifyEnabled"        // Bool
        static let startNotifyRecipient      = "startNotifyRecipient"      // String (NotifyRecipient.rawValue)
        static let startNotifyOffsetMinutes  = "startNotifyOffsetMinutes"  // Int?
        // NEW: Notify (Finish)
        static let finishNotifyEnabled       = "finishNotifyEnabled"       // Bool
        static let finishNotifyRecipient     = "finishNotifyRecipient"     // String (NotifyRecipient.rawValue)
        static let finishNotifyOffsetMinutes = "finishNotifyOffsetMinutes" // Int?
        // Audit
        static let createdAt = Common.createdAt
        static let updatedAt = Common.updatedAt
    }

    // MARK: - TaskCompletionRecord Fields
    enum TaskCompletionRecord {
        static let id          = Common.id
        static let assignmentId = "assignmentId" // String UUID
        static let day         = "day"           // Date (start-of-day)
        static let completedAt = "completedAt"   // Date?
        // NEW (Option A): single CKAsset for full-size photo evidence
        static let photoAsset  = "photoAsset"    // CKAsset?
    }

    // MARK: - LocationItem Fields
    enum LocationItem {
        static let id        = Common.id
        static let name      = "name"      // String
        static let createdAt = Common.createdAt
        static let updatedAt = Common.updatedAt
    }

    // MARK: - EventTemplate Fields
    enum EventTemplate {
        static let id         = Common.id
        static let title      = "title"      // String
        static let iconSymbol = "iconSymbol" // String
        static let createdAt  = Common.createdAt
        static let updatedAt  = Common.updatedAt
    }

    // MARK: - EventAssignment Fields
    enum EventAssignment {
        static let id        = Common.id
        static let childId   = "childId"   // String UUID
        static let templateId = "templateId" // String? UUID
        // Snapshot
        static let eventTitle = "eventTitle" // String
        static let eventIcon  = "eventIcon"  // String
        static let helper     = "helper"     // String?
        static let isActive   = "isActive"   // Bool
        // Schedule
        static let startDate  = "startDate"  // Date
        static let endDate    = "endDate"    // Date?
        static let occurrence = "occurrence" // String rawValue
        static let weekdays   = "weekdays"   // [Int] as [NSNumber]
        // Time
        static let startTime  = "startTime"  // Date?
        static let finishTime = "finishTime" // Date?
        static let durationMinutes = "durationMinutes" // Int?
        // Location
        static let locationId            = "locationId"            // String? UUID
        static let locationNameSnapshot  = "locationNameSnapshot"  // String
        // Legacy single “alert before start” (kept)
        static let alertMe           = "alertMe"           // Bool
        static let alertOffsetMinutes = "alertOffsetMinutes" // Int?
        // NEW: Notify (Start)
        static let startNotifyEnabled        = "startNotifyEnabled"        // Bool
        static let startNotifyRecipient      = "startNotifyRecipient"      // String (NotifyRecipient.rawValue)
        static let startNotifyOffsetMinutes  = "startNotifyOffsetMinutes"  // Int?
        // NEW: Notify (Finish)
        static let finishNotifyEnabled       = "finishNotifyEnabled"       // Bool
        static let finishNotifyRecipient     = "finishNotifyRecipient"     // String (NotifyRecipient.rawValue)
        static let finishNotifyOffsetMinutes = "finishNotifyOffsetMinutes" // Int?
        // Audit
        static let createdAt = Common.createdAt
        static let updatedAt = Common.updatedAt
    }
}

/// Utilities for consistent zone + record IDs.
enum CKID {
    static func familyZoneID(ownerName: String = CKCurrentUserDefaultName) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: CKSchema.familyZoneName, ownerName: ownerName)
    }

    static func recordID(type: String, uuid: UUID, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "\(type)_\(uuid.uuidString)", zoneID: zoneID)
    }
}
