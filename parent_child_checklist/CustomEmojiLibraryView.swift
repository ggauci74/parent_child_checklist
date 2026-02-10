//
//  CustomEmojiLibraryView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
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

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 8)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
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
                                appState.deleteAllCustomEmojis()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Text("Tip: Save emojis you want to reuse across tasks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                Divider()

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
                                        appState.deleteCustomEmoji(emoji)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("My Emojis")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

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
}
