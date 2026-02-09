//
// Models.swift
// parent_child_checklist
//

import Foundation
import SwiftUI

// Represents a child profile in the family
struct ChildProfile: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var colorHex: String

    /// Child-chosen avatar preset ID.
    /// - nil means "Not chosen yet" (show placeholder in parent UI).
    var avatarId: String?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        avatarId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.avatarId = avatarId
    }
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

    // MARK: - Codable (Backward compatible decoding)
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

    // ✅ NEW: Link to an event assignment (optional).
    /// If set, this task is dependent on that event assignment.
    /// If the event assignment is deleted, this task should also be deleted (Option A).
    var linkedEventAssignmentId: UUID?

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
        linkedEventAssignmentId: UUID? = nil,   // ✅ NEW
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Codable (Backward compatible decoding)
    enum CodingKeys: String, CodingKey {
        case id, childId, templateId
        case taskTitle, taskIcon, rewardPoints, helper
        case subtractIfNotCompleted, alertMe, photoEvidenceRequired, isActive
        case startDate, endDate, occurrence, weekdays
        case startTime, finishTime, durationMinutes
        case linkedEventAssignmentId               // ✅ NEW
        case createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        childId = try c.decode(UUID.self, forKey: .childId)
        templateId = try? c.decode(UUID.self, forKey: .templateId)

        taskTitle = (try? c.decode(String.self, forKey: .taskTitle)) ?? ""
        taskIcon = (try? c.decode(String.self, forKey: .taskIcon)) ?? "✅"
        rewardPoints = max(0, (try? c.decode(Int.self, forKey: .rewardPoints)) ?? 0)

        helper = try? c.decode(String.self, forKey: .helper)

        subtractIfNotCompleted = (try? c.decode(Bool.self, forKey: .subtractIfNotCompleted)) ?? false
        alertMe = (try? c.decode(Bool.self, forKey: .alertMe)) ?? false
        photoEvidenceRequired = (try? c.decode(Bool.self, forKey: .photoEvidenceRequired)) ?? false
        isActive = (try? c.decode(Bool.self, forKey: .isActive)) ?? true

        startDate = (try? c.decode(Date.self, forKey: .startDate)) ?? Date()
        endDate = try? c.decode(Date.self, forKey: .endDate)

        occurrence = (try? c.decode(Occurrence.self, forKey: .occurrence)) ?? .specifiedDays
        weekdays = (try? c.decode([Int].self, forKey: .weekdays)) ?? [0,1,2,3,4,5,6]

        startTime = try? c.decode(Date.self, forKey: .startTime)
        finishTime = try? c.decode(Date.self, forKey: .finishTime)
        durationMinutes = try? c.decode(Int.self, forKey: .durationMinutes)

        // ✅ NEW: safe default to nil if missing in older saves
        linkedEventAssignmentId = try? c.decode(UUID.self, forKey: .linkedEventAssignmentId)

        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? c.decode(Date.self, forKey: .updatedAt)) ?? createdAt
    }
}

// MARK: - Task Completion Record (per assignment per day)
struct TaskCompletionRecord: Identifiable, Hashable, Codable {
    let id: UUID
    var assignmentId: UUID
    /// Stored as the start-of-day date (local calendar)
    var day: Date
    /// Optional timestamp
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        assignmentId: UUID,
        day: Date,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.assignmentId = assignmentId
        self.day = day
        self.completedAt = completedAt
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

    // Alerts (per assignment)
    var alertMe: Bool
    /// Minutes before start time (0 = at start time). Nil when alertMe == false.
    var alertOffsetMinutes: Int?

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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
