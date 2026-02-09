//
// ParentEventsTabView.swift
// parent_child_checklist
//

import SwiftUI

struct ParentEventsTabView_OLD: View {
    @EnvironmentObject private var appState: AppState

    @State private var showAddEvent = false
    @State private var templatePendingEdit: EventTemplate? = nil
    @State private var templatePendingDelete: EventTemplate? = nil

    private var sortedTemplates: [EventTemplate] {
        appState.eventTemplates.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Event Library") {
                    if sortedTemplates.isEmpty {
                        Text("No events yet. Tap + to create one.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedTemplates) { tpl in
                            HStack(spacing: 12) {
                                TaskEmojiIconView(icon: tpl.iconSymbol)
                                Text(tpl.title)
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .onTapGesture { templatePendingEdit = tpl }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    templatePendingDelete = tpl
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    templatePendingEdit = tpl
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddEvent = true } label: {
                        Image(systemName: "plus").font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventTemplateView()
                    .environmentObject(appState)
            }
            .sheet(item: $templatePendingEdit) { tpl in
                EditEventTemplateView(template: tpl)
                    .environmentObject(appState)
            }
            .alert(item: $templatePendingDelete) { tpl in
                Alert(
                    title: Text("Delete Event?"),
                    message: Text("Delete “\(tpl.title)”?"),
                    primaryButton: .destructive(Text("Delete")) {
                        appState.deleteEventTemplate(id: tpl.id)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}
