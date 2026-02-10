//
//  CloudKitSchema.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
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
        static let familyMeta = "FamilyMeta"
        static let emojiLibrary = "EmojiLibrary"

        static let childProfile = "ChildProfile"
        static let taskTemplate = "TaskTemplate"
        static let taskAssignment = "TaskAssignment"
        static let taskCompletion = "TaskCompletionRecord"

        static let locationItem = "LocationItem"
        static let eventTemplate = "EventTemplate"
        static let eventAssignment = "EventAssignment"
    }

    // MARK: - Common Fields
    enum Common {
        static let id = "id"                 // String UUID
        static let createdAt = "createdAt"   // Date
        static let updatedAt = "updatedAt"   // Date
        static let schemaVersion = "schemaVersion" // Int
    }

    // MARK: - FamilyMeta Fields
    enum FamilyMeta {
        static let title = "title"           // String
        static let createdAt = "createdAt"   // Date
        static let schemaVersion = "schemaVersion" // Int
    }

    // MARK: - EmojiLibrary Fields
    enum EmojiLibrary {
        static let emojis = "emojis"         // [String]
        static let updatedAt = "updatedAt"   // Date
    }

    // MARK: - ChildProfile Fields
    enum ChildProfile {
        static let id = Common.id
        static let name = "name"
        static let colorHex = "colorHex"
        static let avatarId = "avatarId"     // String? (store as String, omit if nil)
        static let updatedAt = Common.updatedAt
    }

    // MARK: - TaskTemplate Fields
    enum TaskTemplate {
        static let id = Common.id
        static let title = "title"
        static let iconSymbol = "iconSymbol"
        static let rewardPoints = "rewardPoints"
        static let createdAt = "createdAt"
    }

    // MARK: - TaskAssignment Fields
    enum TaskAssignment {
        static let id = Common.id
        static let childId = "childId"
        static let templateId = "templateId" // String? UUID

        // Snapshot
        static let taskTitle = "taskTitle"
        static let taskIcon = "taskIcon"
        static let rewardPoints = "rewardPoints"
        static let helper = "helper" // String?

        // Options
        static let subtractIfNotCompleted = "subtractIfNotCompleted"
        static let alertMe = "alertMe"
        static let photoEvidenceRequired = "photoEvidenceRequired"
        static let isActive = "isActive"

        // Dates
        static let startDate = "startDate"
        static let endDate = "endDate" // Date?

        // Schedule
        static let occurrence = "occurrence" // String rawValue
        static let weekdays = "weekdays"     // [Int] as [NSNumber]

        // Time windows
        static let startTime = "startTime"   // Date?
        static let finishTime = "finishTime" // Date?

        // Duration
        static let durationMinutes = "durationMinutes" // Int?

        // Linked event
        static let linkedEventAssignmentId = "linkedEventAssignmentId" // String? UUID

        // Audit
        static let createdAt = Common.createdAt
        static let updatedAt = Common.updatedAt
    }

    // MARK: - TaskCompletionRecord Fields
    enum TaskCompletionRecord {
        static let id = Common.id
        static let assignmentId = "assignmentId"
        static let day = "day"                 // Date (start-of-day)
        static let completedAt = "completedAt" // Date?
    }

    // MARK: - LocationItem Fields
    enum LocationItem {
        static let id = Common.id
        static let name = "name"
        static let createdAt = Common.createdAt
        static let updatedAt = Common.updatedAt
    }

    // MARK: - EventTemplate Fields
    enum EventTemplate {
        static let id = Common.id
        static let title = "title"
        static let iconSymbol = "iconSymbol"
        static let createdAt = Common.createdAt
        static let updatedAt = Common.updatedAt
    }

    // MARK: - EventAssignment Fields
    enum EventAssignment {
        static let id = Common.id
        static let childId = "childId"
        static let templateId = "templateId" // String? UUID

        // Snapshot
        static let eventTitle = "eventTitle"
        static let eventIcon = "eventIcon"
        static let helper = "helper" // String?

        static let isActive = "isActive"

        // Schedule
        static let startDate = "startDate"
        static let endDate = "endDate"       // Date?
        static let occurrence = "occurrence" // String rawValue
        static let weekdays = "weekdays"     // [Int] as [NSNumber]

        // Time
        static let startTime = "startTime"     // Date?
        static let finishTime = "finishTime"   // Date?
        static let durationMinutes = "durationMinutes" // Int?

        // Location
        static let locationId = "locationId" // String? UUID
        static let locationNameSnapshot = "locationNameSnapshot"

        // Alerts
        static let alertMe = "alertMe"
        static let alertOffsetMinutes = "alertOffsetMinutes" // Int?

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
