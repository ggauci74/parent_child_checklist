//
//  FamilyCoordinator.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//


import Foundation
import CloudKit

/// Implements your "Approach B":
/// - Data lives in a single zone named FamilyZone
/// - If a shared family exists, use SHARED DB
/// - Else if private family exists, use PRIVATE DB
/// - Else create FamilyZone + FamilyMeta in PRIVATE DB (this user becomes owner by creation)
final class FamilyCoordinator {

    enum FamilyState {
        case shared(context: FamilyContext)
        case privateOwner(context: FamilyContext)
    }

    struct FamilyContext: Equatable {
        let database: CloudKitService.DatabaseKind
        let zoneID: CKRecordZone.ID
        let familyMetaRecordID: CKRecord.ID
    }

    private let ck: CloudKitService

    init(ck: CloudKitService) {
        self.ck = ck
    }

    /// Main bootstrap entry.
    func bootstrapFamily() async throws -> FamilyState {

        // 1) Shared DB: find any shared zone named "FamilyZone" and see if it contains FamilyMeta.
        if let sharedContext = try await findSharedFamilyContext() {
            return .shared(context: sharedContext)
        }

        // 2) Private DB: ensure zone exists, then find/create FamilyMeta
        let privateZoneID = try await ck.ensureFamilyZoneInPrivate()

        if let meta = try await ck.fetchFirst(recordType: CKSchema.RecordType.familyMeta, zoneID: privateZoneID, from: .private) {
            return .privateOwner(context: FamilyContext(
                database: .private,
                zoneID: privateZoneID,
                familyMetaRecordID: meta.recordID
            ))
        }

        // 3) Create FamilyMeta in private (owner by creation)
        let meta = try await createFamilyMeta(in: privateZoneID, to: .private)
        return .privateOwner(context: FamilyContext(
            database: .private,
            zoneID: privateZoneID,
            familyMetaRecordID: meta.recordID
        ))
    }

    // MARK: - Shared detection

    /// Shared DB can contain zones owned by another iCloud user.
    /// We detect a family by scanning shared zones whose zoneName == FamilyZoneName,
    /// then checking for a FamilyMeta record inside that zone.
    private func findSharedFamilyContext() async throws -> FamilyContext? {
        let zones = try await ck.fetchAllZones(in: .shared)
        let familyZones = zones.filter { $0.zoneID.zoneName == CKSchema.familyZoneName }

        for zone in familyZones {
            if let meta = try await ck.fetchFirst(recordType: CKSchema.RecordType.familyMeta, zoneID: zone.zoneID, from: .shared) {
                return FamilyContext(
                    database: .shared,
                    zoneID: zone.zoneID,
                    familyMetaRecordID: meta.recordID
                )
            }
        }
        return nil
    }

    // MARK: - FamilyMeta creation

    private func createFamilyMeta(in zoneID: CKRecordZone.ID, to db: CloudKitService.DatabaseKind) async throws -> CKRecord {

        // Use a stable ID so repeated bootstrap doesn't create duplicates.
        let recordID = CKRecord.ID(recordName: "\(CKSchema.RecordType.familyMeta)_ROOT", zoneID: zoneID)
        let record = CKRecord(recordType: CKSchema.RecordType.familyMeta, recordID: recordID)

        // Populate minimal metadata
        record[CKSchema.Common.id] = UUID().uuidString as CKRecordValue
        record[CKSchema.FamilyMeta.title] = "Family" as CKRecordValue
        record[CKSchema.FamilyMeta.createdAt] = Date() as CKRecordValue
        record[CKSchema.FamilyMeta.schemaVersion] = 1 as CKRecordValue

        return try await ck.save(record, to: db)
    }
}
