//
// CloudKitMapper.swift
// parent_child_checklist
//
// Updated for Photo Evidence (Option A: single CKAsset)
// + Updated ChildProfile mapping to include pairingEpoch
//

import Foundation
import CloudKit

// MARK: - CKRecord field helpers
enum CKField {
    static func uuidString(_ uuid: UUID) -> String { uuid.uuidString }
    static func uuid(from string: String) -> UUID? { UUID(uuidString: string) }
}

extension CKRecord {
    // MARK: - Read helpers
    func string(_ key: String) -> String? {
        self[key] as? String
    }
    func int(_ key: String) -> Int? {
        if let n = self[key] as? Int { return n }
        if let n = self[key] as? NSNumber { return n.intValue }
        return nil
    }
    func bool(_ key: String) -> Bool? {
        if let b = self[key] as? Bool { return b }
        if let n = self[key] as? NSNumber { return n.boolValue }
        return nil
    }
    func date(_ key: String) -> Date? {
        self[key] as? Date
    }
    func uuid(_ key: String) -> UUID? {
        guard let s = string(key) else { return nil }
        return UUID(uuidString: s)
    }
    func intArray(_ key: String) -> [Int]? {
        if let ints = self[key] as? [Int] { return ints }
        if let nums = self[key] as? [NSNumber] { return nums.map { $0.intValue } }
        return nil
    }
    func stringArray(_ key: String) -> [String]? {
        self[key] as? [String]
    }
    func asset(_ key: String) -> CKAsset? {
        self[key] as? CKAsset
    }

    // MARK: - Write helpers
    func set(_ key: String, _ value: String?) {
        self[key] = value as CKRecordValue?
    }
    func set(_ key: String, _ value: Int?) {
        self[key] = value as CKRecordValue?
    }
    func set(_ key: String, _ value: Bool?) {
        self[key] = value as CKRecordValue?
    }
    func set(_ key: String, _ value: Date?) {
        self[key] = value as CKRecordValue?
    }
    func setUUID(_ key: String, _ value: UUID?) {
        self[key] = value?.uuidString as CKRecordValue?
    }
    func setIntArray(_ key: String, _ value: [Int]?) {
        if let value {
            self[key] = value.map { NSNumber(value: $0) } as CKRecordValue
        } else {
            self[key] = nil
        }
    }
    func setStringArray(_ key: String, _ value: [String]?) {
        self[key] = value as CKRecordValue?
    }
    func setAsset(_ key: String, _ asset: CKAsset?) {
        self[key] = asset
    }
}

// MARK: - Record builders (stable IDs)
enum CKRecordFactory {
    static func makeRecord(type: String, uuid: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKID.recordID(type: type, uuid: uuid, zoneID: zoneID)
        return CKRecord(recordType: type, recordID: recordID)
    }
    /// Singletons (FamilyMeta, EmojiLibrary) — fixed recordName in-zone.
    static func makeSingleton(type: String, recordName: String, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        return CKRecord(recordType: type, recordID: recordID)
    }
}

// MARK: - CHILD PROFILE
enum ChildProfileMapper {
    static func toRecord(_ model: ChildProfile, zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecordFactory.makeRecord(type: CKSchema.RecordType.childProfile, uuid: model.id, zoneID: zoneID)
        r.set(CKSchema.ChildProfile.id, model.id.uuidString)
        r.set(CKSchema.ChildProfile.name, model.name)
        r.set(CKSchema.ChildProfile.colorHex, model.colorHex)
        r.set(CKSchema.ChildProfile.avatarId, model.avatarId)
        // NEW: pairingEpoch
        r.set(CKSchema.ChildProfile.pairingEpoch, model.pairingEpoch)
        r.set(CKSchema.ChildProfile.updatedAt, Date())
        return r
    }

    static func fromRecord(_ r: CKRecord) -> ChildProfile? {
        let id = (r.uuid(CKSchema.ChildProfile.id))
            ?? UUID(uuidString: r.recordID.recordName.replacingOccurrences(of: "\(CKSchema.RecordType.childProfile)_", with: ""))
        guard let id,
              let name = r.string(CKSchema.ChildProfile.name),
              let colorHex = r.string(CKSchema.ChildProfile.colorHex)
        else { return nil }

        let avatarId = r.string(CKSchema.ChildProfile.avatarId)
        // NEW: pairingEpoch (defaults to 0 if absent)
        let pairingEpoch = r.int(CKSchema.ChildProfile.pairingEpoch) ?? 0

        return ChildProfile(id: id,
                            name: name,
                            colorHex: colorHex,
                            avatarId: avatarId,
                            pairingEpoch: pairingEpoch)
    }
}

// MARK: - TASK TEMPLATE
enum TaskTemplateMapper {
    static func toRecord(_ model: TaskTemplate, zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecordFactory.makeRecord(type: CKSchema.RecordType.taskTemplate, uuid: model.id, zoneID: zoneID)
        r.set(CKSchema.TaskTemplate.id, model.id.uuidString)
        r.set(CKSchema.TaskTemplate.title, model.title)
        r.set(CKSchema.TaskTemplate.iconSymbol, model.iconSymbol)
        r.set(CKSchema.TaskTemplate.rewardPoints, max(0, model.rewardPoints))
        r.set(CKSchema.TaskTemplate.createdAt, model.createdAt)
        return r
    }
    static func fromRecord(_ r: CKRecord) -> TaskTemplate? {
        guard let id = r.uuid(CKSchema.TaskTemplate.id),
              let title = r.string(CKSchema.TaskTemplate.title),
              let icon = r.string(CKSchema.TaskTemplate.iconSymbol),
              let createdAt = r.date(CKSchema.TaskTemplate.createdAt)
        else { return nil }
        let points = max(0, r.int(CKSchema.TaskTemplate.rewardPoints) ?? 1)
        return TaskTemplate(id: id, title: title, iconSymbol: icon, rewardPoints: points, createdAt: createdAt)
    }
}

// MARK: - TASK ASSIGNMENT
enum TaskAssignmentMapper {
    static func toRecord(_ model: TaskAssignment, zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecordFactory.makeRecord(type: CKSchema.RecordType.taskAssignment, uuid: model.id, zoneID: zoneID)
        r.set(CKSchema.TaskAssignment.id, model.id.uuidString)
        r.setUUID(CKSchema.TaskAssignment.childId, model.childId)
        r.setUUID(CKSchema.TaskAssignment.templateId, model.templateId)
        r.set(CKSchema.TaskAssignment.taskTitle, model.taskTitle)
        r.set(CKSchema.TaskAssignment.taskIcon, model.taskIcon)
        r.set(CKSchema.TaskAssignment.rewardPoints, max(0, model.rewardPoints))
        r.set(CKSchema.TaskAssignment.helper, model.helper)
        r.set(CKSchema.TaskAssignment.subtractIfNotCompleted, model.subtractIfNotCompleted)
        r.set(CKSchema.TaskAssignment.alertMe, model.alertMe)
        r.set(CKSchema.TaskAssignment.photoEvidenceRequired, model.photoEvidenceRequired)
        r.set(CKSchema.TaskAssignment.isActive, model.isActive)
        r.set(CKSchema.TaskAssignment.startDate, model.startDate)
        r.set(CKSchema.TaskAssignment.endDate, model.endDate)
        r.set(CKSchema.TaskAssignment.occurrence, model.occurrence.rawValue)
        r.setIntArray(CKSchema.TaskAssignment.weekdays, model.weekdays.sorted())
        r.set(CKSchema.TaskAssignment.startTime, model.startTime)
        r.set(CKSchema.TaskAssignment.finishTime, model.finishTime)
        r.set(CKSchema.TaskAssignment.durationMinutes, model.durationMinutes)
        r.setUUID(CKSchema.TaskAssignment.linkedEventAssignmentId, model.linkedEventAssignmentId)
        r.set(CKSchema.TaskAssignment.startNotifyEnabled, model.startNotifyEnabled)
        r.set(CKSchema.TaskAssignment.startNotifyRecipient, model.startNotifyRecipient.rawValue)
        r.set(CKSchema.TaskAssignment.startNotifyOffsetMinutes, model.startNotifyOffsetMinutes)
        r.set(CKSchema.TaskAssignment.finishNotifyEnabled, model.finishNotifyEnabled)
        r.set(CKSchema.TaskAssignment.finishNotifyRecipient, model.finishNotifyRecipient.rawValue)
        r.set(CKSchema.TaskAssignment.finishNotifyOffsetMinutes, model.finishNotifyOffsetMinutes)
        r.set(CKSchema.TaskAssignment.createdAt, model.createdAt)
        r.set(CKSchema.TaskAssignment.updatedAt, model.updatedAt)
        return r
    }

    static func fromRecord(_ r: CKRecord) -> TaskAssignment? {
        guard let id = r.uuid(CKSchema.TaskAssignment.id),
              let childId = r.uuid(CKSchema.TaskAssignment.childId),
              let taskTitle = r.string(CKSchema.TaskAssignment.taskTitle),
              let taskIcon = r.string(CKSchema.TaskAssignment.taskIcon),
              let startDate = r.date(CKSchema.TaskAssignment.startDate)
        else { return nil }

        let occurrenceRaw = r.string(CKSchema.TaskAssignment.occurrence) ?? TaskAssignment.Occurrence.specifiedDays.rawValue
        let occurrence = TaskAssignment.Occurrence(rawValue: occurrenceRaw) ?? .specifiedDays
        let weekdays = (r.intArray(CKSchema.TaskAssignment.weekdays) ?? [0,1,2,3,4,5,6]).sorted()
        let createdAt = r.date(CKSchema.TaskAssignment.createdAt) ?? Date()
        let updatedAt = r.date(CKSchema.TaskAssignment.updatedAt) ?? createdAt

        let startEnabled = r.bool(CKSchema.TaskAssignment.startNotifyEnabled) ?? false
        let startRecipientRaw = r.string(CKSchema.TaskAssignment.startNotifyRecipient) ?? NotifyRecipient.both.rawValue
        let startRecipient = NotifyRecipient(rawValue: startRecipientRaw) ?? .both
        let startOffset = r.int(CKSchema.TaskAssignment.startNotifyOffsetMinutes)

        let finishEnabled = r.bool(CKSchema.TaskAssignment.finishNotifyEnabled) ?? false
        let finishRecipientRaw = r.string(CKSchema.TaskAssignment.finishNotifyRecipient) ?? NotifyRecipient.both.rawValue
        let finishRecipient = NotifyRecipient(rawValue: finishRecipientRaw) ?? .both
        let finishOffset = r.int(CKSchema.TaskAssignment.finishNotifyOffsetMinutes)

        return TaskAssignment(
            id: id,
            childId: childId,
            templateId: r.uuid(CKSchema.TaskAssignment.templateId),
            taskTitle: taskTitle,
            taskIcon: taskIcon,
            rewardPoints: max(0, r.int(CKSchema.TaskAssignment.rewardPoints) ?? 0),
            helper: r.string(CKSchema.TaskAssignment.helper),
            subtractIfNotCompleted: r.bool(CKSchema.TaskAssignment.subtractIfNotCompleted) ?? false,
            alertMe: r.bool(CKSchema.TaskAssignment.alertMe) ?? false,
            photoEvidenceRequired: r.bool(CKSchema.TaskAssignment.photoEvidenceRequired) ?? false,
            isActive: r.bool(CKSchema.TaskAssignment.isActive) ?? true,
            startDate: startDate,
            endDate: r.date(CKSchema.TaskAssignment.endDate),
            occurrence: occurrence,
            weekdays: weekdays,
            startTime: r.date(CKSchema.TaskAssignment.startTime),
            finishTime: r.date(CKSchema.TaskAssignment.finishTime),
            durationMinutes: r.int(CKSchema.TaskAssignment.durationMinutes),
            linkedEventAssignmentId: r.uuid(CKSchema.TaskAssignment.linkedEventAssignmentId),
            startNotifyEnabled: startEnabled,
            startNotifyRecipient: startRecipient,
            startNotifyOffsetMinutes: startOffset,
            finishNotifyEnabled: finishEnabled,
            finishNotifyRecipient: finishRecipient,
            finishNotifyOffsetMinutes: finishOffset,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - TASK COMPLETION RECORD (with Photo Evidence)
enum TaskCompletionRecordMapper {
    // MARK: Write (Model → CKRecord)
    static func toRecord(_ model: TaskCompletionRecord, zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecordFactory.makeRecord(
            type: CKSchema.RecordType.taskCompletion,
            uuid: model.id,
            zoneID: zoneID
        )
        r.set(CKSchema.TaskCompletionRecord.id, model.id.uuidString)
        r.setUUID(CKSchema.TaskCompletionRecord.assignmentId, model.assignmentId)
        r.set(CKSchema.TaskCompletionRecord.day, model.day)
        r.set(CKSchema.TaskCompletionRecord.completedAt, model.completedAt)

        // Photo evidence CKAsset
        if let url = model.photoEvidenceLocalURL {
            let asset = CKAsset(fileURL: url)
            r.setAsset(CKSchema.TaskCompletionRecord.photoAsset, asset)
        } else {
            r.setAsset(CKSchema.TaskCompletionRecord.photoAsset, nil)
        }
        return r
    }

    // MARK: Read (CKRecord → Model)
    static func fromRecord(_ r: CKRecord) -> TaskCompletionRecord? {
        guard let id = r.uuid(CKSchema.TaskCompletionRecord.id),
              let assignmentId = r.uuid(CKSchema.TaskCompletionRecord.assignmentId),
              let day = r.date(CKSchema.TaskCompletionRecord.day)
        else { return nil }

        let completedAt = r.date(CKSchema.TaskCompletionRecord.completedAt)

        var localURL: URL? = nil
        if let asset = r.asset(CKSchema.TaskCompletionRecord.photoAsset) {
            localURL = asset.fileURL
        }
        let hasPhoto = (localURL != nil)

        return TaskCompletionRecord(
            id: id,
            assignmentId: assignmentId,
            day: day,
            completedAt: completedAt,
            hasPhotoEvidence: hasPhoto,
            photoEvidenceLocalURL: localURL,
            photoThumbnailLocalURL: nil
        )
    }
}

// MARK: - LOCATION ITEM
enum LocationItemMapper {
    static func toRecord(_ model: LocationItem, zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecordFactory.makeRecord(type: CKSchema.RecordType.locationItem, uuid: model.id, zoneID: zoneID)
        r.set(CKSchema.LocationItem.id, model.id.uuidString)
        r.set(CKSchema.LocationItem.name, model.name)
        r.set(CKSchema.LocationItem.createdAt, model.createdAt)
        r.set(CKSchema.LocationItem.updatedAt, model.updatedAt)
        return r
    }
    static func fromRecord(_ r: CKRecord) -> LocationItem? {
        guard let id = r.uuid(CKSchema.LocationItem.id),
              let name = r.string(CKSchema.LocationItem.name)
        else { return nil }
        let createdAt = r.date(CKSchema.LocationItem.createdAt) ?? Date()
        let updatedAt = r.date(CKSchema.LocationItem.updatedAt) ?? createdAt
        return LocationItem(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt)
    }
}

// MARK: - EVENT TEMPLATE
enum EventTemplateMapper {
    static func toRecord(_ model: EventTemplate, zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecordFactory.makeRecord(type: CKSchema.RecordType.eventTemplate, uuid: model.id, zoneID: zoneID)
        r.set(CKSchema.EventTemplate.id, model.id.uuidString)
        r.set(CKSchema.EventTemplate.title, model.title)
        r.set(CKSchema.EventTemplate.iconSymbol, model.iconSymbol)
        r.set(CKSchema.EventTemplate.createdAt, model.createdAt)
        r.set(CKSchema.EventTemplate.updatedAt, model.updatedAt)
        return r
    }
    static func fromRecord(_ r: CKRecord) -> EventTemplate? {
        guard let id = r.uuid(CKSchema.EventTemplate.id),
              let title = r.string(CKSchema.EventTemplate.title),
              let icon = r.string(CKSchema.EventTemplate.iconSymbol)
        else { return nil }
        let createdAt = r.date(CKSchema.EventTemplate.createdAt) ?? Date()
        let updatedAt = r.date(CKSchema.EventTemplate.updatedAt) ?? createdAt
        return EventTemplate(id: id, title: title, iconSymbol: icon, createdAt: createdAt, updatedAt: updatedAt)
    }
}

// MARK: - EVENT ASSIGNMENT
enum EventAssignmentMapper {
    static func toRecord(_ model: EventAssignment, zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecordFactory.makeRecord(type: CKSchema.RecordType.eventAssignment, uuid: model.id, zoneID: zoneID)
        r.set(CKSchema.EventAssignment.id, model.id.uuidString)
        r.setUUID(CKSchema.EventAssignment.childId, model.childId)
        r.setUUID(CKSchema.EventAssignment.templateId, model.templateId)
        r.set(CKSchema.EventAssignment.eventTitle, model.eventTitle)
        r.set(CKSchema.EventAssignment.eventIcon, model.eventIcon)
        r.set(CKSchema.EventAssignment.helper, model.helper)
        r.set(CKSchema.EventAssignment.isActive, model.isActive)
        r.set(CKSchema.EventAssignment.startDate, model.startDate)
        r.set(CKSchema.EventAssignment.endDate, model.endDate)
        r.set(CKSchema.EventAssignment.occurrence, model.occurrence.rawValue)
        r.setIntArray(CKSchema.EventAssignment.weekdays, model.weekdays.sorted())
        r.set(CKSchema.EventAssignment.startTime, model.startTime)
        r.set(CKSchema.EventAssignment.finishTime, model.finishTime)
        r.set(CKSchema.EventAssignment.durationMinutes, model.durationMinutes)
        r.setUUID(CKSchema.EventAssignment.locationId, model.locationId)
        r.set(CKSchema.EventAssignment.locationNameSnapshot, model.locationNameSnapshot)
        r.set(CKSchema.EventAssignment.alertMe, model.alertMe)
        r.set(CKSchema.EventAssignment.alertOffsetMinutes, model.alertOffsetMinutes)
        r.set(CKSchema.EventAssignment.startNotifyEnabled, model.startNotifyEnabled)
        r.set(CKSchema.EventAssignment.startNotifyRecipient, model.startNotifyRecipient.rawValue)
        r.set(CKSchema.EventAssignment.startNotifyOffsetMinutes, model.startNotifyOffsetMinutes)
        r.set(CKSchema.EventAssignment.finishNotifyEnabled, model.finishNotifyEnabled)
        r.set(CKSchema.EventAssignment.finishNotifyRecipient, model.finishNotifyRecipient.rawValue)
        r.set(CKSchema.EventAssignment.finishNotifyOffsetMinutes, model.finishNotifyOffsetMinutes)
        r.set(CKSchema.EventAssignment.createdAt, model.createdAt)
        r.set(CKSchema.EventAssignment.updatedAt, model.updatedAt)
        return r
    }

    static func fromRecord(_ r: CKRecord) -> EventAssignment? {
        guard let id = r.uuid(CKSchema.EventAssignment.id),
              let childId = r.uuid(CKSchema.EventAssignment.childId),
              let title = r.string(CKSchema.EventAssignment.eventTitle),
              let icon = r.string(CKSchema.EventAssignment.eventIcon),
              let startDate = r.date(CKSchema.EventAssignment.startDate)
        else { return nil }

        let occurrenceRaw = r.string(CKSchema.EventAssignment.occurrence)
            ?? EventAssignment.Occurrence.specifiedDays.rawValue
        let occurrence = EventAssignment.Occurrence(rawValue: occurrenceRaw) ?? .specifiedDays
        let weekdays = (r.intArray(CKSchema.EventAssignment.weekdays) ?? [0,1,2,3,4,5,6]).sorted()
        let createdAt = r.date(CKSchema.EventAssignment.createdAt) ?? Date()
        let updatedAt = r.date(CKSchema.EventAssignment.updatedAt) ?? createdAt

        let startEnabled = r.bool(CKSchema.EventAssignment.startNotifyEnabled) ?? false
        let startRecipientRaw = r.string(CKSchema.EventAssignment.startNotifyRecipient)
            ?? NotifyRecipient.both.rawValue
        let startRecipient = NotifyRecipient(rawValue: startRecipientRaw) ?? .both
        let startOffset = r.int(CKSchema.EventAssignment.startNotifyOffsetMinutes)

        let finishEnabled = r.bool(CKSchema.EventAssignment.finishNotifyEnabled) ?? false
        let finishRecipientRaw = r.string(CKSchema.EventAssignment.finishNotifyRecipient)
            ?? NotifyRecipient.both.rawValue
        let finishRecipient = NotifyRecipient(rawValue: finishRecipientRaw) ?? .both
        let finishOffset = r.int(CKSchema.EventAssignment.finishNotifyOffsetMinutes)

        return EventAssignment(
            id: id,
            childId: childId,
            templateId: r.uuid(CKSchema.EventAssignment.templateId),
            eventTitle: title,
            eventIcon: icon,
            helper: r.string(CKSchema.EventAssignment.helper),
            isActive: r.bool(CKSchema.EventAssignment.isActive) ?? true,
            startDate: startDate,
            endDate: r.date(CKSchema.EventAssignment.endDate),
            occurrence: occurrence,
            weekdays: weekdays,
            startTime: r.date(CKSchema.EventAssignment.startTime),
            finishTime: r.date(CKSchema.EventAssignment.finishTime),
            durationMinutes: r.int(CKSchema.EventAssignment.durationMinutes),
            locationId: r.uuid(CKSchema.EventAssignment.locationId),
            locationNameSnapshot: r.string(CKSchema.EventAssignment.locationNameSnapshot) ?? "",
            alertMe: r.bool(CKSchema.EventAssignment.alertMe) ?? false,
            alertOffsetMinutes: r.int(CKSchema.EventAssignment.alertOffsetMinutes),
            startNotifyEnabled: startEnabled,
            startNotifyRecipient: startRecipient,
            startNotifyOffsetMinutes: startOffset,
            finishNotifyEnabled: finishEnabled,
            finishNotifyRecipient: finishRecipient,
            finishNotifyOffsetMinutes: finishOffset,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - EMOJI LIBRARY (singleton)
enum EmojiLibraryMapper {
    static let singletonRecordName = "\(CKSchema.RecordType.emojiLibrary)_ROOT"

    static func toRecord(emojis: [String], zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecordFactory.makeSingleton(
            type: CKSchema.RecordType.emojiLibrary,
            recordName: singletonRecordName,
            zoneID: zoneID
        )
        r.setStringArray(CKSchema.EmojiLibrary.emojis, emojis)
        r.set(CKSchema.EmojiLibrary.updatedAt, Date())
        return r
    }

    static func fromRecord(_ r: CKRecord) -> [String] {
        r.stringArray(CKSchema.EmojiLibrary.emojis) ?? []
    }
}
