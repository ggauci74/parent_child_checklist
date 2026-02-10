//
//  EditTaskTemplateView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//

import SwiftUI

// MARK: - Edit Task Template (Emoji-only picker + My Emojis sheet)
struct EditTaskTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let template: TaskTemplate

    @State private var title: String
    @State private var searchText: String = ""
    @State private var selectedEmoji: String
    @State private var selectedCategory: EmojiCatalog.Category = .all
    @State private var validationMessage: String? = nil
    @FocusState private var titleFocused: Bool
    @State private var showMyEmojisSheet = false

    // ✅ NEW: Reward points
    @State private var rewardPoints: Int

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 8)

    init(template: TaskTemplate) {
        self.template = template
        _title = State(initialValue: template.title)
        _selectedEmoji = State(initialValue: template.iconSymbol)
        _rewardPoints = State(initialValue: max(0, template.rewardPoints))
    }

    private var trimmedTitle: String { title.trimmed }

    private var isDuplicate: Bool {
        !trimmedTitle.isEmpty && appState.isTaskTitleTaken(trimmedTitle, excluding: template.id)
    }

    private var hasChanges: Bool {
        trimmedTitle != template.title.trimmed ||
        selectedEmoji != template.iconSymbol ||
        rewardPoints != max(0, template.rewardPoints)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !isDuplicate && selectedEmoji.trimmed.containsEmoji && hasChanges
    }

    private var baseEmojis: [String] {
        switch selectedCategory {
        case .myEmojis:
            return appState.customEmojis
        case .all, .morning, .hygiene, .school, .chores, .food, .pets, .sports, .time, .rewards, .health, .outdoors:
            return EmojiCatalog.emojis(for: selectedCategory)
        }
    }

    private var filteredEmojis: [String] {
        let q = searchText.trimmed
        if q.isEmpty { return baseEmojis }
        return baseEmojis.filter { $0.contains(q) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)

                    if isDuplicate {
                        Text("That task already exists. Please choose a different name.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                // ✅ NEW: Reward Points UI
                Section("Reward Points") {
                    HStack {
                        Text("💎 Points")
                        Spacer()

                        Button {
                            rewardPoints = max(0, rewardPoints - 1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(rewardPoints == 0)
                        .accessibilityLabel("Decrease reward points")

                        Text("\(rewardPoints)")
                            .font(.headline)
                            .frame(minWidth: 32)

                        Button {
                            rewardPoints += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Increase reward points")
                    }
                }
                
                Section("Icon (Emoji)") {
                    HStack {
                        Text("Selected")
                        Spacer()
                        Text(selectedEmoji.trimmed.containsEmoji ? selectedEmoji : "✅")
                            .font(.system(size: 32))
                    }

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(EmojiCatalog.Category.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }

                    TextField("Search", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(filteredEmojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                    validationMessage = nil
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 24))
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(selectedEmoji == emoji ? Color.blue.opacity(0.18) : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(
                                                    selectedEmoji == emoji ? Color.blue : Color.secondary.opacity(0.25),
                                                    lineWidth: selectedEmoji == emoji ? 2 : 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(emoji)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(minHeight: 240, maxHeight: 360)
                    .scrollIndicators(.visible)

                    if selectedCategory == .myEmojis, appState.customEmojis.isEmpty {
                        Text("No saved emojis yet. Tap “Manage My Emojis” below to add some.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        showMyEmojisSheet = true
                    } label: {
                        HStack {
                            Text("Manage My Emojis")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.up")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showMyEmojisSheet) {
                CustomEmojiLibraryView { picked in
                    selectedEmoji = picked
                    selectedCategory = .myEmojis
                    searchText = ""
                }
                .environmentObject(appState)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    titleFocused = true
                }
            }
            .onChange(of: title) { _, _ in validationMessage = nil }
            .onChange(of: selectedCategory) { _, _ in
                searchText = ""
            }
        }
    }

    private func save() {
        validationMessage = nil

        guard !trimmedTitle.isEmpty else {
            validationMessage = "Task title cannot be empty."
            return
        }

        guard !isDuplicate else {
            validationMessage = "That task already exists. Please choose a different name."
            return
        }

        guard selectedEmoji.trimmed.containsEmoji else {
            validationMessage = "Please select an emoji."
            return
        }

        let points = max(0, rewardPoints)

        let ok = appState.updateTaskTemplate(
            id: template.id,
            newTitle: trimmedTitle,
            newIconSymbol: selectedEmoji.trimmed,
            newRewardPoints: points
        )

        if ok {
            dismiss()
        } else {
            validationMessage = "Couldn’t save changes. Try again."
        }
    }
}
