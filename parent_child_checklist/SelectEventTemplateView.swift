//
//  SelectEventTemplateView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 8/2/2026.
//

import SwiftUI

struct SelectEventTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let selectedTemplateId: UUID?
    let onPick: (EventTemplate) -> Void

    @State private var searchText: String = ""

    // NEW: add/create + edit states
    @State private var showAddTemplate = false
    @State private var editingTemplate: EventTemplate? = nil

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
                VStack(alignment: .leading, spacing: 8) {
                    Text("No events yet.")
                        .font(.headline)
                    Text("Tap the + in the top‑right to create your first event template.")
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
        .navigationTitle("Select Event")
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
                        .accessibilityLabel("New Event Template")
                }
            }
        }

        // NEW: Create flow
        .sheet(isPresented: $showAddTemplate) {
            AddEventTemplateView(
                onSaved: { created in
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
            EditEventTemplateView(
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
