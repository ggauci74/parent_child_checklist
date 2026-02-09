//
//  parent_child_checklistApp.swift
//  parent_child_checklist
//
//  Created by George Gauci on 2/2/2026.
//

import SwiftUI

@main
struct parent_child_checklistApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
