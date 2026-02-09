//
// AddEventTemplateView.swift
// parent_child_checklist
//

import SwiftUI

struct AddEventTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var searchText: String = ""
    @State private var selectedEmoji: String? = nil
    @State private var selectedCategory: EmojiCatalog.Category = .all
    @State private var validationMessage: String? = nil
    @FocusState private var titleFocused: Bool

    @State private var showMyEmojisSheet = false

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 8)

    private var trimmedTitle: String { title.trimmed }

    private var isDuplicate: Bool {
        !trimmedTitle.isEmpty && appState.isEventTitleTaken(trimmedTitle)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !isDuplicate && (selectedEmoji != nil)
    }

    private var baseEmojis: [String] {
        switch selectedCategory {
        case .myEmojis:
            return appState.customEmojis
        default:
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
                Section("Event") {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)

                    if isDuplicate {
                        Text("That event already exists. Please choose a different name.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Icon (Emoji)") {
                    HStack {
                        Text("Selected")
                        Spacer()
                        if let selectedEmoji {
                            Text(selectedEmoji).font(.system(size: 32))
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
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
            .navigationTitle("Add Event")
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
            .onChange(of: selectedCategory) { _, _ in searchText = "" }
        }
    }

    private func save() {
        validationMessage = nil

        guard !trimmedTitle.isEmpty else {
            validationMessage = "Please enter an event title."
            return
        }
        guard !isDuplicate else {
            validationMessage = "That event already exists. Please choose a different name."
            return
        }
        guard let emoji = selectedEmoji, !emoji.trimmed.isEmpty else {
            validationMessage = "Please select an emoji."
            return
        }

        _ = appState.createEventTemplate(title: trimmedTitle, iconSymbol: emoji)
        dismiss()
    }
}
