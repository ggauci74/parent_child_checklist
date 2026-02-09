//
//  SelectEventTemplateView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 8/2/2026.
//
//
// SelectEventTemplateView.swift
// parent_child_checklist
//

import SwiftUI

struct SelectEventTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let selectedTemplateId: UUID?
    let onPick: (EventTemplate) -> Void

    @State private var searchText: String = ""

    private var templates: [EventTemplate] {
        let sorted = appState.eventTemplates.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            if templates.isEmpty {
                Text("No events yet. Create events in the Events tab first.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(templates) { tpl in
                    Button {
                        onPick(tpl)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            TaskEmojiIconView(icon: tpl.iconSymbol, size: 22)
                            Text(tpl.title)
                                .font(.headline)
                            Spacer()
                            if selectedTemplateId == tpl.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Select Event")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }
}
