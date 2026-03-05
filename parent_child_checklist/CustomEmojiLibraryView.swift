//
// CustomEmojiLibraryView.swift
// parent_child_checklist
//
// Created by George Gauci on 10/2/2026.
//

import SwiftUI

// MARK: - Manage My Emojis (Sheet)
struct CustomEmojiLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// When an emoji is tapped, return it to Add/Edit screens.
    let onPick: (String) -> Void

    @State private var inputEmoji: String = ""
    @State private var message: String? = nil

    // Destructive confirmations
    @State private var showClearAllConfirm: Bool = false
    @State private var emojiPendingDelete: String? = nil
    @State private var singleDeleteUsageMessage: String? = nil
    @State private var showSingleDeleteConfirm: Bool = false

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 8)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                // Input + actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste any emoji")
                        .font(.headline)

                    TextField("Paste emoji here (e.g. 🪥, 🎻, 👨‍👩‍👧‍👦)", text: $inputEmoji)
                        .font(.system(size: 24))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(.vertical, 12)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onChange(of: inputEmoji) { _, _ in
                            message = nil
                        }

                    HStack(spacing: 10) {
                        Button("Add") { addEmoji() }
                            .buttonStyle(.borderedProminent)

                        Spacer()

                        if !appState.customEmojis.isEmpty {
                            Button("Clear All", role: .destructive) {
                                showClearAllConfirm = true
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Clear all saved emojis")
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    // Tip + helper link (optional)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tip: Save emojis you want to reuse across tasks.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        // Subtle helper link for parents to browse emojis
                        if let url = URL(string: "https://www.emojicopy.com") {
                            Link("Need emojis? Browse at EmojiCopy.com →", destination: url)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityHint("Opens EmojiCopy dot com in Safari")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)

                Divider()

                // Emoji grid (saved)
                if appState.customEmojis.isEmpty {
                    Spacer()
                    Text("No custom emojis yet.\nTap Add after pasting an emoji.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(appState.customEmojis, id: \.self) { emoji in
                                Button {
                                    onPick(emoji)
                                    dismiss()
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 24))
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.blue.opacity(0.10))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        prepareSingleDelete(emoji)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Small discoverability hint beneath the grid
                        Text("Tip: Long‑press an emoji to delete it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle("My Emojis")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            // MARK: - Clear All confirmation
            .alert("Delete all saved emojis?", isPresented: $showClearAllConfirm) {
                Button("Delete All", role: .destructive) {
                    appState.deleteAllCustomEmojis()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                let inUse = appState.countCustomEmojisInUse()
                let total = appState.customEmojis.count
                if inUse > 0 {
                    Text("This will remove \(total) saved emojis.\n\(inUse) of them are used by templates. Deleting won’t change any existing tasks or events.")
                } else {
                    Text("This will remove \(total) saved emojis. Deleting won’t change any existing tasks or events.")
                }
            }
            // MARK: - Single delete confirmation (when in use)
            .alert("Delete this emoji?", isPresented: $showSingleDeleteConfirm, presenting: emojiPendingDelete) { emoji in
                Button("Delete", role: .destructive) {
                    if let e = emojiPendingDelete {
                        appState.deleteCustomEmoji(e)
                        emojiPendingDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    emojiPendingDelete = nil
                }
            } message: { _ in
                if let msg = singleDeleteUsageMessage {
                    Text(msg)
                } else {
                    Text("This will remove the emoji from your saved list. Deleting won’t change any existing tasks or events.")
                }
            }
        }
    }

    // MARK: - Actions
    private func addEmoji() {
        message = nil
        let t = inputEmoji.trimmed
        guard !t.isEmpty else {
            message = "Please paste an emoji."
            return
        }
        guard t.containsEmoji else {
            message = "That doesn’t look like an emoji."
            return
        }
        guard !appState.isCustomEmojiTaken(t) else {
            message = "That emoji is already saved."
            return
        }
        let ok = appState.addCustomEmoji(t)
        if ok {
            inputEmoji = ""
            message = "Added ✅ Tap an emoji below to use it."
        } else {
            message = "Couldn’t add that emoji. Try again."
        }
    }

    /// Initiates single-emoji deletion. If the emoji is used in templates, ask for confirmation.
    private func prepareSingleDelete(_ emoji: String) {
        let usage = appState.emojiUsage(emoji)
        if usage.tasks > 0 || usage.events > 0 {
            // Build a friendly usage message
            var parts: [String] = []
            if usage.tasks > 0 { parts.append("\(usage.tasks) task template\(usage.tasks == 1 ? "" : "s")") }
            if usage.events > 0 { parts.append("\(usage.events) event template\(usage.events == 1 ? "" : "s")") }
            let joined = parts.joined(separator: " and ")
            singleDeleteUsageMessage =
            """
            This emoji is used in \(joined).
            Deleting won’t change any existing tasks or events, but you won’t be able to select it again in those templates unless you save it here again.
            """
            emojiPendingDelete = emoji
            showSingleDeleteConfirm = true
        } else {
            // Not used anywhere — delete immediately
            appState.deleteCustomEmoji(emoji)
        }
    }
}

