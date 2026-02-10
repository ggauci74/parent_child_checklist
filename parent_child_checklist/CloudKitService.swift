import Foundation
import CloudKit

final class CloudKitService {

    struct Configuration {
        let containerIdentifier: String?
        init(containerIdentifier: String? = nil) {
            self.containerIdentifier = containerIdentifier
        }
    }

    enum DatabaseKind {
        case `private`
        case shared
    }

    enum QueryFailurePolicy {
        /// Ignore per-record failures (keep successes); optionally log failures.
        case lenient
        /// If any record in a page fails, throw the first error found.
        case strict
    }

    private let container: CKContainer

    init(config: Configuration = .init()) {
        if let id = config.containerIdentifier {
            self.container = CKContainer(identifier: id)
        } else {
            self.container = CKContainer.default()
        }
    }

    func database(_ kind: DatabaseKind) -> CKDatabase {
        switch kind {
        case .private: return container.privateCloudDatabase
        case .shared:  return container.sharedCloudDatabase
        }
    }

    // MARK: - Zones

    func ensureFamilyZoneInPrivate() async throws -> CKRecordZone.ID {
        let zoneID = CKID.familyZoneID()
        let zone = CKRecordZone(zoneID: zoneID)

        _ = try await database(.private).modifyRecordZones(saving: [zone], deleting: [])
        return zoneID
    }

    func fetchAllZones(in kind: DatabaseKind) async throws -> [CKRecordZone] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecordZone], Error>) in
            database(kind).fetchAllRecordZones { zones, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: zones ?? [])
                }
            }
        }
    }

    // MARK: - Records (single)

    func fetch(recordID: CKRecord.ID, from kind: DatabaseKind) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            database(kind).fetch(withRecordID: recordID) { record, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let record else {
                    continuation.resume(throwing: NSError(
                        domain: "CloudKitService",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Record not found"]
                    ))
                    return
                }
                continuation.resume(returning: record)
            }
        }
    }

    func save(_ record: CKRecord, to kind: DatabaseKind) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            database(kind).save(record) { saved, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let saved else {
                    continuation.resume(throwing: NSError(
                        domain: "CloudKitService",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Save returned nil record"]
                    ))
                    return
                }
                continuation.resume(returning: saved)
            }
        }
    }

    func delete(recordID: CKRecord.ID, from kind: DatabaseKind) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database(kind).delete(withRecordID: recordID) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // MARK: - Batch Modify

    func modifyRecords(
        saving: [CKRecord],
        deleting: [CKRecord.ID],
        in kind: DatabaseKind,
        savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .changedKeys,
        atomically: Bool = true
    ) async throws -> (
        saveResults: [CKRecord.ID: Result<CKRecord, Error>],
        deleteResults: [CKRecord.ID: Result<Void, Error>]
    ) {
        let result = try await database(kind).modifyRecords(
            saving: saving,
            deleting: deleting,
            savePolicy: savePolicy,
            atomically: atomically
        )

        let saves = result.saveResults.mapValues { $0.mapError { $0 as Error } }
        let deletes = result.deleteResults.mapValues { $0.mapError { $0 as Error } }
        return (saves, deletes)
    }

    // MARK: - Queries (paged)

    func fetchAll(
        recordType: String,
        zoneID: CKRecordZone.ID?,
        from kind: DatabaseKind,
        desiredKeys: [CKRecord.FieldKey]? = nil,
        resultsLimit: Int = 200,
        sort: [NSSortDescriptor] = [],
        failurePolicy: QueryFailurePolicy = .lenient
    ) async throws -> [CKRecord] {

        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = sort

        var all: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let response: (matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)], queryCursor: CKQueryOperation.Cursor?)

            if let cursor {
                response = try await database(kind).records(
                    continuingMatchFrom: cursor,
                    desiredKeys: desiredKeys,
                    resultsLimit: resultsLimit
                )
            } else {
                response = try await database(kind).records(
                    matching: query,
                    inZoneWith: zoneID,
                    desiredKeys: desiredKeys,
                    resultsLimit: resultsLimit
                )
            }

            var firstError: Error?

            for (_, recordResult) in response.matchResults {
                switch recordResult {
                case .success(let record):
                    all.append(record)
                case .failure(let err):
                    // capture error but continue depending on policy
                    if firstError == nil { firstError = err }
                }
            }

            if failurePolicy == .strict, let firstError {
                throw firstError
            }

            cursor = response.queryCursor
        } while cursor != nil

        return all
    }

    func fetchFirst(
        recordType: String,
        zoneID: CKRecordZone.ID?,
        from kind: DatabaseKind
    ) async throws -> CKRecord? {
        let records = try await fetchAll(
            recordType: recordType,
            zoneID: zoneID,
            from: kind,
            resultsLimit: 1
        )
        return records.first
    }
}
