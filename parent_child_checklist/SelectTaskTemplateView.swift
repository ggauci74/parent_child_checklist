//
//  SelectTaskTemplateView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 6/2/2026.
//

import SwiftUI

struct SelectTaskTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let selectedTemplateId: UUID?
    let onPick: (TaskTemplate) -> Void

    @State private var searchText: String = ""

    private var templates: [TaskTemplate] {
        let sorted = appState.taskTemplates.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            if templates.isEmpty {
                Text("No tasks yet. Create tasks in the Task Library first.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(templates) { tpl in
                    Button {
                        onPick(tpl)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            TaskEmojiIconView(icon: tpl.iconSymbol, size: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tpl.title)
                                    .font(.headline)
                                if tpl.rewardPoints > 0 {
                                    HStack(spacing: 4) {
                                        Text("💎")
                                        Text("\(tpl.rewardPoints)")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                } else {
                                    Text("💎 0")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
        .navigationTitle("Select Task")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
    }
}
