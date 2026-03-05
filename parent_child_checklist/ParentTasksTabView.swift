//
// ParentTasksTabView.swift
// parent_child_checklist
//
// Created by George Gauci on 10/2/2026.
//

import SwiftUI

struct ParentTasksTabView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showAddTask = false
    @State private var taskPendingEdit: TaskTemplate?
    @State private var taskPendingDelete: TaskTemplate?
    @State private var showDeleteBlockedAlert = false

    // 🔍 Search (title-only)
    @State private var searchText: String = ""

    // Sorted → then filtered (case-insensitive; title only)
    private var sortedTemplates: [TaskTemplate] {
        appState.taskTemplates.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private var filteredTemplates: [TaskTemplate] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sortedTemplates }
        return sortedTemplates.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    // Whether the library has any tasks at all (pre-filter)
    private var libraryIsEmpty: Bool {
        appState.taskTemplates.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Task Library") {
                    if libraryIsEmpty {
                        // Existing empty-library message
                        Text("No tasks yet. Tap + to create one.")
                            .foregroundStyle(.secondary)
                    } else if filteredTemplates.isEmpty {
                        // Empty-search-result state
                        Text("No tasks match “\(searchText)”. Try a different word.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredTemplates) { task in
                            HStack(spacing: 12) {
                                TaskEmojiIconView(icon: task.iconSymbol, size: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                        .font(.headline)
                                    if task.rewardPoints > 0 { // ensure proper >
                                        Text("💎 \(task.rewardPoints) point\(task.rewardPoints == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            // 👇 Double‑tap anywhere on the row to edit
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                triggerSelectionHaptic()
                                taskPendingEdit = task
                            }
                            // Existing swipe actions remain available
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    taskPendingDelete = task
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)

                                Button {
                                    taskPendingEdit = task
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            // We keep inline so title & + share the same horizontal row
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 🔹 Custom, larger inline title (same line as +)
                ToolbarItem(placement: .principal) {
                    // Adjust size/weight to match your “Parent” look (try 22–26)
                    Text("Tasks")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .accessibilityAddTraits(.isHeader)
                }
                // 🔹 Trailing + button
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .accessibilityLabel("Add Task")
                }
            }
            // 🔍 Native nav-bar search; title-only filtering (consistent with your pickers)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .sheet(isPresented: $showAddTask) {
                AddTaskTemplateView()
                    .environmentObject(appState)
            }
            .sheet(item: $taskPendingEdit) { tpl in
                EditTaskTemplateView(template: tpl)
                    .environmentObject(appState)
            }
            .alert(
                "Delete task?",
                isPresented: Binding(
                    get: { taskPendingDelete != nil },
                    set: { if !$0 { taskPendingDelete = nil } }
                )
            ) {
                Button("Delete", role: .destructive) {
                    if let tpl = taskPendingDelete {
                        let ok = appState.deleteTaskTemplate(id: tpl.id)
                        if !ok { showDeleteBlockedAlert = true }
                    }
                    taskPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    taskPendingDelete = nil
                }
            } message: {
                Text("This will delete the task from the library.")
            }
            .alert("Can’t delete", isPresented: $showDeleteBlockedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This task is currently assigned to at least one child. Remove the assignments first.")
            }
            // 🔄 Clear search when the user returns to the tab (as requested)
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
