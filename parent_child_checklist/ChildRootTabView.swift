//
// ChildRootTabView.swift
//

import SwiftUI

struct ChildRootTabView: View {
    let childId: UUID

    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: ChildTab = .today

    enum ChildTab: Hashable {
        case today, requests, avatar
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChildHomeView(childId: childId)
                .tabItem { Label("Today", systemImage: "calendar") }
                .tag(ChildTab.today)

            ChildRewardsView(childId: childId)
                .tabItem { Label("Requests", systemImage: "diamond.fill") }
                .tag(ChildTab.requests)

            // The Avatar tab remains available for *changing* avatars later.
            ChildAvatarSetupView(childId: childId, onContinue: { selectedTab = .today })
                .tabItem { Label("Avatar", systemImage: "person.crop.circle") }
                .tag(ChildTab.avatar)
        }
    }
}

