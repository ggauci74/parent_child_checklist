//
//  FamilyDataStore.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//

import Foundation
import CloudKit

/// Loads the family's data from CloudKit into a single snapshot that AppState can apply.
/// This class does **read-only** work; write/autosave will be added later.
@MainActor
final class FamilyDataStore {

    // MARK: Snapshot

    struct Snapshot {
        var children: [ChildProfile] = []
        var taskTemplates: [TaskTemplate] = []
        var taskAssignments: [TaskAssignment] = []
        var taskCompletions: [TaskCompletionRecord] = []
        var customEmojis: [String] = []
        var eventTemplates: [EventTemplate] = []
        var eventAssignments: [EventAssignment] = []
        var locations: [LocationItem] = []
    }

    // MARK: Dependencies

    private let ck: CloudKitService
    private let coordinator: FamilyCoordinator

    init(containerIdentifier: String? = nil) {
        self.ck = CloudKitService(config: .init(containerIdentifier: containerIdentifier))
        self.coordinator = FamilyCoordinator(ck: ck)
    }

    // MARK: Load

    /// Bootstraps the family (shared → private → create) and loads every record type from the FamilyZone.
    /// If the zone exists but is empty (first run), returns an empty snapshot.
    func loadSnapshot() async throws -> Snapshot {
        // Determine which DB/zone we should read from.
        let state = try await coordinator.bootstrapFamily()

        let context: FamilyCoordinator.FamilyContext
        switch state {
        case .shared(let ctx):        context = ctx
        case .privateOwner(let ctx):  context = ctx
        }

        let db = context.database
        let zoneID = context.zoneID

        // Kick off all fetches in parallel.
        async let childrenR         = ck.fetchAll(recordType: CKSchema.RecordType.childProfile,     zoneID: zoneID, from: db)
        async let templatesR        = ck.fetchAll(recordType: CKSchema.RecordType.taskTemplate,     zoneID: zoneID, from: db)
        async let assignmentsR      = ck.fetchAll(recordType: CKSchema.RecordType.taskAssignment,   zoneID: zoneID, from: db)
        async let completionsR      = ck.fetchAll(recordType: CKSchema.RecordType.taskCompletion,   zoneID: zoneID, from: db)

        async let eventTemplatesR   = ck.fetchAll(recordType: CKSchema.RecordType.eventTemplate,    zoneID: zoneID, from: db)
        async let eventAssignmentsR = ck.fetchAll(recordType: CKSchema.RecordType.eventAssignment,  zoneID: zoneID, from: db)
        async let locationsR        = ck.fetchAll(recordType: CKSchema.RecordType.locationItem,     zoneID: zoneID, from: db)

        // Emoji library is a singleton record
        async let emojiRecord       = ck.fetchFirst(recordType: CKSchema.RecordType.emojiLibrary,   zoneID: zoneID, from: db)

        // Await and map per type.
        let children         = try await childrenR.compactMap(ChildProfileMapper.fromRecord)
        let taskTemplates    = try await templatesR.compactMap(TaskTemplateMapper.fromRecord)
        let taskAssignments  = try await assignmentsR.compactMap(TaskAssignmentMapper.fromRecord)
        let taskCompletions  = try await completionsR.compactMap(TaskCompletionRecordMapper.fromRecord)

        let eventTemplates   = try await eventTemplatesR.compactMap(EventTemplateMapper.fromRecord)
        let eventAssignments = try await eventAssignmentsR.compactMap(EventAssignmentMapper.fromRecord)
        let locations        = try await locationsR.compactMap(LocationItemMapper.fromRecord)

        // Handle the emoji singleton (no closure; unwrap cleanly).
        let emojiRec = try await emojiRecord
        let emojis: [String] = emojiRec.map(EmojiLibraryMapper.fromRecord) ?? []

        return Snapshot(
            children: children,
            taskTemplates: taskTemplates,
            taskAssignments: taskAssignments,
            taskCompletions: taskCompletions,
            customEmojis: emojis,
            eventTemplates: eventTemplates,
            eventAssignments: eventAssignments,
            locations: locations
        )
    }

    // MARK: Utilities

    /// Consider the snapshot to have "user data" if any of the arrays is non-empty.
    /// AppState uses this to **avoid** overwriting local JSON with an empty CloudKit snapshot on first run.
    static func hasUserData(_ s: Snapshot) -> Bool {
        return !s.children.isEmpty
            || !s.taskTemplates.isEmpty
            || !s.taskAssignments.isEmpty
            || !s.taskCompletions.isEmpty
            || !s.eventTemplates.isEmpty
            || !s.eventAssignments.isEmpty
            || !s.locations.isEmpty
            || !s.customEmojis.isEmpty
    }
}
