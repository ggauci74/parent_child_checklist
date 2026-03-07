//
//  CustomEmojiLibraryView.swift
//  parent_child_checklist
//
//  Futurist theme: Curvy background, frosted cards, neon filament,
//  pill header, dark inputs, and frosted emoji tiles (via TaskEmojiIconView).
//

import SwiftUI
import UIKit

// MARK: - Futurist theme tokens (aligned with your other screens)
private enum FuturistTheme {
    static let neonAqua      = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)
    static let cardStroke    = Color.white.opacity(0.08)
    static let divider       = Color.white.opacity(0.10)
    static let cardShadow    = Color.black.opacity(0.10)

    // Surfaces
    static let surfaceSolid = Color(red: 0.05, green: 0.10, blue: 0.22)
    static let surfaceFrost = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)

    // Pastel action pills
    static let softRedBase    = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase  = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight   = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
}

// MARK: - Layout metrics
private enum PageMetrics {
    static let pageHPad: CGFloat     = 12
    static let cornerRadius: CGFloat = 14
    static let innerHPad: CGFloat    = 16
    static let cardShadowRadius: CGFloat = 4
    static let cardShadowYOffset: CGFloat = 1
}

// MARK: - Frosted card
private struct FrostedCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        let fill = reduceTransparency ? FuturistTheme.surfaceSolid : FuturistTheme.surfaceFrost
        return VStack(alignment: .leading, spacing: 10) { content() }
            .padding(.vertical, 12)
            .padding(.horizontal, PageMetrics.innerHPad)
            .background(
                RoundedRectangle(cornerRadius: PageMetrics.cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PageMetrics.cornerRadius, style: .continuous)
                    .stroke(FuturistTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: FuturistTheme.cardShadow, radius: PageMetrics.cardShadowRadius, x: 0, y: PageMetrics.cardShadowYOffset)
    }
}

// MARK: - Bright cyan filament
private struct BrightLineSeparator: View {
    var leadingInset: CGFloat = 16
    var trailingInset: CGFloat = 14
    var thickness: CGFloat = 2
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 0.00),
                .init(color: FuturistTheme.neonAqua, location: 0.50),
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 1.00)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: thickness)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.horizontal, PageMetrics.pageHPad)
        .accessibilityHidden(true)
    }
}

// MARK: - Toolbar pill button
private struct ToolbarPillButton: View {
    let label: String
    var foreground: Color
    var background: Color
    var stroke: Color
    var disabled: Bool = false
    var glow: Bool = false
    var fixedWidth: CGFloat? = 76
    var fixedHeight: CGFloat? = 32
    var action: () -> Void

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: fixedWidth, height: fixedHeight)
            .background(Capsule().fill(background))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
            .shadow(color: glow ? background.opacity(0.28) : FuturistTheme.cardShadow, radius: 3)
            .opacity(disabled ? 0.75 : 1)
            .contentShape(Capsule())
            .onTapGesture { if !disabled { action() } }
    }
}

// MARK: - Dark frosted text field
private struct FrostedField: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var placeholder: String
    @Binding var text: String

    var body: some View {
        let fill = reduceTransparency ? FuturistTheme.surfaceSolid : Color.white.opacity(0.06)
        HStack {
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(FuturistTheme.textSecondary))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .multilineTextAlignment(.center)
                .foregroundStyle(FuturistTheme.textPrimary)
                .tint(FuturistTheme.neonAqua)
                .font(.system(size: 22))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(FuturistTheme.cardStroke, lineWidth: 1)
        )
    }
}

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
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ===== Card 1: Paste any emoji + actions =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Paste any emoji")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)

                                FrostedField(
                                    placeholder: "Paste emoji here (e.g. 🪥, 🎻, 👨‍👩‍👧‍👦)",
                                    text: $inputEmoji
                                )
                                .onChange(of: inputEmoji) { _, _ in message = nil }

                                HStack(spacing: 10) {
                                    ToolbarPillButton(
                                        label: "Add",
                                        foreground: Color.black.opacity(0.9),
                                        background: FuturistTheme.softGreenLight,
                                        stroke: FuturistTheme.softGreenBase.opacity(0.75),
                                        action: { addEmoji() }
                                    )

                                    Spacer()

                                    if !appState.customEmojis.isEmpty {
                                        ToolbarPillButton(
                                            label: "Clear All",
                                            foreground: .white,
                                            background: FuturistTheme.softRedLight,
                                            stroke: FuturistTheme.softRedBase.opacity(0.75),
                                            action: { showClearAllConfirm = true }
                                        )
                                        .accessibilityLabel("Clear all saved emojis")
                                    }
                                }

                                if let message {
                                    Text(message)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                }

                                // Tip + helper link
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Tip: Save emojis you want to reuse across tasks.")
                                        .font(.footnote)
                                        .foregroundStyle(FuturistTheme.textSecondary)

                                    if let url = URL(string: "https://www.emojicopy.com") {
                                        Link("Need emojis? Browse at EmojiCopy.com →", destination: url)
                                            .font(.footnote)
                                            .foregroundStyle(FuturistTheme.textSecondary)
                                            .accessibilityHint("Opens EmojiCopy dot com in Safari")
                                    }
                                }
                            }
                            .foregroundStyle(FuturistTheme.textPrimary)
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)
                        .padding(.top, 12)

                        BrightLineSeparator()

                        // ===== Card 2: Saved emoji grid =====
                        if appState.customEmojis.isEmpty {
                            FrostedCard {
                                Text("No custom emojis yet.\nPaste an emoji above and tap Add.")
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 8)
                            }
                            .padding(.horizontal, PageMetrics.pageHPad)
                        } else {
                            FrostedCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Saved")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(FuturistTheme.textSecondary)

                                    LazyVGrid(columns: gridColumns, spacing: 10) {
                                        ForEach(appState.customEmojis, id: \.self) { emoji in
                                            Button {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                onPick(emoji)
                                                dismiss()
                                            } label: {
                                                // Use your frosted tile component to match everywhere
                                                TaskEmojiIconView(icon: emoji, size: 24)
                                                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .center)
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
                                    .padding(.top, 2)

                                    Text("Tip: Long‑press an emoji to delete it.")
                                        .font(.footnote)
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                        .padding(.top, 2)
                                }
                                .foregroundStyle(FuturistTheme.textPrimary)
                            }
                            .padding(.horizontal, PageMetrics.pageHPad)
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.bottom, 24)
                }
            }
            // Hide system nav; themed header below
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // Themed header (Done pill)
            .safeAreaInset(edge: .top, spacing: 0) {
                let topSpacer: CGFloat = 8
                ZStack {
                    Text("My Emojis")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    VStack(spacing: 0) {
                        Color.clear.frame(height: topSpacer)
                        HStack {
                            ToolbarPillButton(
                                label: "Done",
                                foreground: .white,
                                background: FuturistTheme.softRedLight,
                                stroke: FuturistTheme.softRedBase.opacity(0.75),
                                action: { dismiss() }
                            )
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .background(Color.clear)
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            appState.deleteCustomEmoji(emoji)
        }
    }
}
