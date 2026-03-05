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

    /// Currently selected template id (to show a ✔︎)
    let selectedTemplateId: UUID?

    /// Called when the user picks (or creates/edits and then picks) a template
    let onPick: (TaskTemplate) -> Void

    @State private var searchText: String = ""

    // New: add/create + edit states
    @State private var showAddTemplate = false
    @State private var editingTemplate: TaskTemplate? = nil

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
                VStack(alignment: .leading, spacing: 8) {
                    Text("No tasks yet.")
                        .font(.headline)
                    Text("Tap the + in the top‑right to create your first task template.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
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

                                HStack(spacing: 4) {
                                    Text("💎")
                                    Text("\(max(0, tpl.rewardPoints))")
                                        .fontWeight(.semibold)
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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
                    .contextMenu {
                        Button {
                            editingTemplate = tpl
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            editingTemplate = tpl
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTemplate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .accessibilityLabel("New Task Template")
                }
            }
        }

        // NEW: Create flow
        .sheet(isPresented: $showAddTemplate) {
            // Expecting editor to call onSaved with the created TaskTemplate
            AddTaskTemplateView(
                onSaved: { created in
                    // Ensure the store is up-to-date (editor typically updates AppState)
                    onPick(created)
                    dismiss()
                },
                onCancel: {
                    // No-op; just close the sheet
                }
            )
            .environmentObject(appState)
        }

        // NEW: Edit flow
        .sheet(item: $editingTemplate) { tpl in
            EditTaskTemplateView(
                template: tpl,
                onSaved: { updated in
                    onPick(updated)
                    dismiss()
                },
                onCancel: {
                    // No-op; just close the sheet
                }
            )
            .environmentObject(appState)
        }
    }
}
