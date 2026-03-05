//
// ParentEventsTabView.swift
// parent_child_checklist
//
// Created by George Gauci on 10/2/2026.
//

import SwiftUI

struct ParentEventsTabView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showAddEvent = false
    @State private var eventPendingEdit: EventTemplate?
    @State private var eventPendingDelete: EventTemplate?

    // 🔍 Search (title-only, clears on appear)
    @State private var searchText: String = ""

    // Sorted → then filtered (case-insensitive; title only)
    private var sortedTemplates: [EventTemplate] {
        appState.eventTemplates.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private var filteredTemplates: [EventTemplate] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sortedTemplates }
        return sortedTemplates.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    private var libraryIsEmpty: Bool {
        appState.eventTemplates.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Event Library") {
                    if libraryIsEmpty {
                        Text("No events yet. Tap + to create one.")
                            .foregroundStyle(.secondary)
                    } else if filteredTemplates.isEmpty {
                        Text("No events match “\(searchText)”. Try a different word.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredTemplates) { event in
                            HStack(spacing: 12) {
                                TaskEmojiIconView(icon: event.iconSymbol, size: 22)
                                Text(event.title)
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            // 👇 Double‑tap anywhere on the row to edit
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                triggerSelectionHaptic()
                                eventPendingEdit = event
                            }
                            // Keep existing swipe actions
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    eventPendingDelete = event
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)

                                Button {
                                    eventPendingEdit = event
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline) // Keep inline (title & + share one line)
            .toolbar {
                // 🔹 Custom, larger inline title
                ToolbarItem(placement: .principal) {
                    Text("Events")
                        .font(.system(size: 32, weight: .bold, design: .default)) // ⬅️ adjust size/weight as you like
                        .accessibilityAddTraits(.isHeader)
                }
                // 🔹 Trailing + button
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .accessibilityLabel("Add Event")
                }
            }
            // 🔍 Native nav-bar search; title-only filtering (consistent with Tasks)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .sheet(isPresented: $showAddEvent) {
                AddEventTemplateView()
                    .environmentObject(appState)
            }
            .sheet(item: $eventPendingEdit) { tpl in
                EditEventTemplateView(template: tpl)
                    .environmentObject(appState)
            }
            .alert(
                "Delete event?",
                isPresented: Binding(
                    get: { eventPendingDelete != nil },
                    set: { if !$0 { eventPendingDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let tpl = eventPendingDelete {
                        appState.deleteEventTemplate(id: tpl.id)
                    }
                    eventPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    eventPendingDelete = nil
                }
            } message: {
                Text("This will delete the event from the library.")
            }
            // 🔄 Clear search when returning to the tab
            .onAppear {
                searchText = ""
            }
        }
    }

    // MARK: - Haptics
    /// A subtle, platform-safe selection tick.
    private func triggerSelectionHaptic() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
}
