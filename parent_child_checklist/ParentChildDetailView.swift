//
//  ParentChildDetailView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 3/2/2026.
//
import SwiftUI

struct ParentChildDetailView: View {
    let child: ChildProfile
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Text("Details for \(child.name)")
            .navigationTitle(child.name)
    }
}

