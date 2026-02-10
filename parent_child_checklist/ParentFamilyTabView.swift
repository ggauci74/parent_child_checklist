//
//  ParentFamilyTabView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//

import SwiftUI
import CloudKit

struct ParentFamilyTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showShareSheet = false
    @State private var sharingController: UICloudSharingController?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Invite Partner") {
                        Task { await prepareShare() }
                    }
                    .font(.headline)
                }
            }
            .navigationTitle("Family")
            .sheet(isPresented: $showShareSheet) {
                if let controller = sharingController {
                    ShareSheet(sharingController: controller)
                }
            }
        }
    }

    private func prepareShare() async {
        guard let ctx = appState.familyContext else {
            print("❌ No family context loaded yet")
            return
        }

        // Optional runtime guard: only owners (private DB) can create a new share.
        // If you want participants to open an existing share, remove this guard
        // and rely on the existing-share path in CloudKitSharingController.
        if ctx.database == .shared {
            print("ℹ️ This device is a participant; cannot create a new share.")
            return
        }

        // Use AppState’s helper to resolve the correct CKDatabase.
        let database = appState.cloudDatabaseForCurrentFamily()

        let shareHelper = CloudKitSharingController(
            database: database,
            familyMetaRecordID: ctx.familyMetaRecordID
        )

        do {
            let controller = try await shareHelper.makeSharingController()
            sharingController = controller
            showShareSheet = true
        } catch {
            print("❌ Failed to prepare share sheet: \(error)")
        }
    }
}

