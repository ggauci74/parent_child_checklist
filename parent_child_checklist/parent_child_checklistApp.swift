//
// parent_child_checklistApp.swift
// parent_child_checklist
//

import SwiftUI

@main
struct parent_child_checklistApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // 1) Request notification permission (one-time is fine)
                    NotificationManager.shared.requestAuthorizationIfNeeded()

                    // 2) As soon as AppState has finished loading CloudKit snapshot,
                    //    run a reconciliation pass to schedule the NEXT upcoming
                    //    notifications for this device (parent OR child).
                    //
                    //    We call it twice:
                    //    - Immediately (in case of local cached JSON)
                    //    - Again after a small delay to ensure CloudKit
                    //      pulled any remote changes.
                    reconcileAllNotifications()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        reconcileAllNotifications()
                    }
                }
        }
    }

    // MARK: - Device audience routing
    private func currentAudience() -> NotificationAudience {
        // TODO: If you already track role:
        // return appState.isChildMode ? .child : .parent
        return .parent
    }

    // MARK: - Reconciliation helper
    private func reconcileAllNotifications() {
        let audience = currentAudience()
        let mgr = NotificationManager.shared

        mgr.reconcileTasks(appState.taskAssignments, audience: audience)
        mgr.reconcileEvents(appState.eventAssignments, audience: audience)
    }
}
