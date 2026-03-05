//
// SettingsView.swift
// parent_child_checklist
//

import SwiftUI
import CloudKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    // Invite Partner presentation state
    @State private var isPresentingShareSheet = false
    @State private var sharingController: UICloudSharingController?
    @State private var isPreparingShare = false
    @State private var shareErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Family
                Section("Family") {
                    Button {
                        Task { await invitePartnerTapped() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.wave.2.fill")
                                .font(.headline)
                                .foregroundStyle(.tint)
                            Text("Invite Partner")
                            Spacer()
                            if isPreparingShare {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .disabled(inviteDisabled)
                    .accessibilityHint(inviteDisabled
                        ? "Cloud data not ready yet."
                        : "Share your family to invite another parent.")
                    if let msg = inviteDisabledReason {
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - App (placeholders)
                Section("App") {
                    HStack {
                        Text("Notifications (coming soon)")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())

                    HStack {
                        Text("Appearance (coming soon)")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }

                // MARK: - About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 (1)")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Custom principal title (matches your prior design)
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .sheet(isPresented: $isPresentingShareSheet) {
                if let sharingController {
                    ShareSheet(sharingController: sharingController)
                }
            }
            .alert("Sharing Error", isPresented: Binding<Bool>(
                get: { shareErrorMessage != nil },
                set: { if !$0 { shareErrorMessage = nil } }
            ), actions: {
                Button("OK", role: .cancel) { shareErrorMessage = nil }
            }, message: {
                Text(shareErrorMessage ?? "An unknown error occurred.")
            })
        }
    }

    // MARK: - Invite availability

    private var inviteDisabled: Bool {
        isPreparingShare || appState.familyContext == nil || !cloudKitReady
    }

    private var inviteDisabledReason: String? {
        if isPreparingShare { return "Preparing sharing options…" }
        guard cloudKitReady else { return "iCloud is not ready. Try again in a moment." }
        if appState.familyContext == nil { return "Family context not loaded yet." }
        return nil
    }

    private var cloudKitReady: Bool {
        // appState publishes these read-only flags already
        // (true when FamilyDataStore snapshot has been applied)
        // - cloudKitLoaded == true means we detected remote user data
        //   but we still allow sharing even if it's false (first run),
        //   as long as familyContext is available (we own private zone).
        // For safety, just require that there is a context.
        appState.familyContext != nil
    }

    // MARK: - Actions

    private func invitePartnerTapped() async {
        guard !isPreparingShare else { return }
        guard let ctx = appState.familyContext else {
            shareErrorMessage = "Family context not available yet. Please try again shortly."
            return
        }

        isPreparingShare = true
        defer { isPreparingShare = false }

        do {
            // Choose the correct database the family currently lives in.
            // FamilyContext already tells us whether it is private or shared. [2](https://ausgrid-my.sharepoint.com/personal/ggauci_ausgrid_com_au/Documents/Microsoft%20Copilot%20Chat%20Files/swift_parts_7.txt)
            let database: CKDatabase = appState.cloudDatabaseForCurrentFamily() // convenience helper [2](https://ausgrid-my.sharepoint.com/personal/ggauci_ausgrid_com_au/Documents/Microsoft%20Copilot%20Chat%20Files/swift_parts_7.txt)

            // Build a share UI around the FamilyMeta root record using your helper. [3](https://ausgrid-my.sharepoint.com/personal/ggauci_ausgrid_com_au/Documents/Microsoft%20Copilot%20Chat%20Files/swift_parts_8.txt)
            let controller = try await CloudKitSharingController(
                container: .default(),
                database: database,
                familyMetaRecordID: ctx.familyMetaRecordID
            ).makeSharingController() // returns UICloudSharingController configured for the FamilyMeta root

            // Present the system share UI
            sharingController = controller
            isPresentingShareSheet = true
        } catch {
            shareErrorMessage = "Could not prepare sharing: \(error.localizedDescription)"
        }
    }
}
