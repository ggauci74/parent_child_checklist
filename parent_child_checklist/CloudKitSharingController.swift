//
//  CloudKitSharingController.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//


import CloudKit
import UIKit
import SwiftUI

final class CloudKitSharingController: NSObject, UICloudSharingControllerDelegate {
    
    private let container: CKContainer
    private let database: CKDatabase
    private let familyMetaRecordID: CKRecord.ID
    
    init(container: CKContainer = .default(),
         database: CKDatabase,
         familyMetaRecordID: CKRecord.ID) {
        self.container = container
        self.database = database
        self.familyMetaRecordID = familyMetaRecordID
    }
    
    func makeSharingController() async throws -> UICloudSharingController {
        
        // Fetch the FamilyMeta record
        let record = try await database.record(for: familyMetaRecordID)
        
        // Attempt to grab an existing share
        if let shareRef = record.share {
            if let existingShare = try? await database.record(for: shareRef.recordID) as? CKShare {
                let controller = UICloudSharingController(share: existingShare, container: container)
                controller.delegate = self
                return controller
            }
        }
        
        // No existing share → create one
        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "Family Checklist" as CKRecordValue
        
        // Save both together
        _ = try await database.modifyRecords(saving: [record, share], deleting: [])
        
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = self
        return controller
    }
    
    // MARK: UICloudSharingControllerDelegate
    func cloudSharingController(_ c: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("❌ Failed to save share: \(error)")
    }
    
    func itemTitle(for c: UICloudSharingController) -> String? {
        return "Family Checklist"
    }
}