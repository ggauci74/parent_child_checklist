//
//  AddTaskTemplateView.swift
//  parent_child_checklist
//
//  Futurist theme: frosted cards, neon filament separators,
//  pill header (Cancel / Save), and dark inputs.
//

import SwiftUI
import UIKit

// MARK: - Futurist theme tokens (aligned with your other screens)
private enum FuturistTheme {
    static let neonAqua     = Color(red: 0.20, green: 0.95, blue: 1.00)   // bright cyan
    static let textPrimary  = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)
    static let cardStroke   = Color.white.opacity(0.08)
    static let divider      = Color.white.opacity(0.10)
    static let cardShadow   = Color.black.opacity(0.10)

    // Surfaces
    static let surfaceSolid = Color(red: 0.05, green: 0.10, blue: 0.22)
    static let surfaceFrost = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)

    // Pastel action pill colours
    static let softRedBase    = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase  = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight   = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
}

// MARK: - Layout metrics (parity with Select screens)
private enum AddTaskMetrics {
    static let pageHPad: CGFloat     = 12
    static let cornerRadius: CGFloat = 14
    static let innerHPad: CGFloat    = 16
    static let cardShadowRadius: CGFloat = 4
    static let cardShadowYOffset: CGFloat = 1
}

// MARK: - Frosted card container
private struct FrostedCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        let fill = reduceTransparency ? FuturistTheme.surfaceSolid : FuturistTheme.surfaceFrost
        return VStack(alignment: .leading, spacing: 10) { content() }
            .padding(.vertical, 12)
            .padding(.horizontal, AddTaskMetrics.innerHPad)
            .background(
                RoundedRectangle(cornerRadius: AddTaskMetrics.cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AddTaskMetrics.cornerRadius, style: .continuous)
                    .stroke(FuturistTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: FuturistTheme.cardShadow, radius: AddTaskMetrics.cardShadowRadius, x: 0, y: AddTaskMetrics.cardShadowYOffset)
    }
}

// MARK: - Bright cyan filament (separator between cards)
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
        .padding(.horizontal, AddTaskMetrics.pageHPad) // align with page padding
        .accessibilityHidden(true)
    }
}

// MARK: - Toolbar pill button (Cancel / Save)
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
            .shadow(color: glow ? background.opacity(0.28) : FuturistTheme.cardShadow, radius: glow ? 3 : 3)
            .opacity(disabled ? 0.75 : 1)
            .contentShape(Capsule())
            .onTapGesture { if !disabled { action() } }
    }
}

// MARK: - Compact frosted field (for Title)
private struct FrostedField: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var placeholder: String
    @Binding var text: String
    @FocusState var isFocused: Bool

    var body: some View {
        let fill = reduceTransparency ? FuturistTheme.surfaceSolid : Color.white.opacity(0.06)
        HStack {
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(FuturistTheme.textSecondary))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .foregroundStyle(FuturistTheme.textPrimary)
                .tint(FuturistTheme.neonAqua)
                .focused($isFocused)
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

// MARK: - Round glyph button (for +/- points)
private struct RoundGlyphButton: View {
    var systemName: String
    var roleTint: Color = FuturistTheme.neonAqua
    var disabled: Bool = false
    var action: () -> Void
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.90))
            .frame(width: 30, height: 30)
            .background(Circle().fill(roleTint))
            .overlay(Circle().stroke(Color.white.opacity(0.60), lineWidth: 1))
            .opacity(disabled ? 0.5 : 1.0)
            .contentShape(Circle())
            .onTapGesture { if !disabled { action() } }
            .accessibilityHidden(false)
    }
}

// MARK: - Add Task Template (Emoji-only picker + My Emojis sheet)
struct AddTaskTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Callbacks
    var onSaved: ((TaskTemplate) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    // State
    @State private var title: String = ""
    @State private var selectedEmoji: String? = nil
    @State private var selectedCategory: EmojiCatalog.Category = .all
    @State private var validationMessage: String? = nil
    @FocusState private var titleFocused: Bool
    @State private var rewardPoints: Int = 1

    // My Emojis sheet
    @State private var showMyEmojisSheet = false

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 8)
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isDuplicate: Bool {
        !trimmedTitle.isEmpty && appState.isTaskTitleTaken(trimmedTitle)
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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ===== Card 1: Task Title =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Task")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)

                                FrostedField(placeholder: "Title", text: $title, isFocused: _titleFocused)
                                    .onChange(of: title) { _, _ in validationMessage = nil }
                                    .accessibilityLabel("Task title")

                                if isDuplicate {
                                    Text("That task already exists. Please choose a different name.")
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                } else if let msg = validationMessage {
                                    Text(msg)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                }
                            }
                            .foregroundStyle(FuturistTheme.textPrimary)
                        }
                        .padding(.horizontal, AddTaskMetrics.pageHPad)

                        BrightLineSeparator()

                        // ===== Card 2: Reward Points =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reward Points")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)

                                HStack(spacing: 12) {
                                    HStack(spacing: 6) {
                                        Text("💎")
                                        Text("Points")
                                    }
                                    .foregroundStyle(FuturistTheme.textPrimary)

                                    Spacer()

                                    RoundGlyphButton(systemName: "minus", roleTint: FuturistTheme.softRedLight, disabled: rewardPoints == 0) {
                                        rewardPoints = max(0, rewardPoints - 1)
                                    }
                                    Text("\(rewardPoints)")
                                        .font(.headline)
                                        .foregroundStyle(FuturistTheme.textPrimary)
                                        .frame(minWidth: 32)
                                    RoundGlyphButton(systemName: "plus", roleTint: FuturistTheme.softGreenLight) {
                                        rewardPoints += 1
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AddTaskMetrics.pageHPad)

                        BrightLineSeparator()

                        // ===== Card 3: Icon (Emoji) =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Icon (Emoji)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)

                                // Selected row
                                HStack {
                                    Text("Selected")
                                        .foregroundStyle(FuturistTheme.textPrimary)
                                    Spacer()
                                    if let chosen = selectedEmoji {
                                        Text(chosen)
                                            .font(.system(size: 32))
                                    } else {
                                        Text("—")
                                            .foregroundStyle(FuturistTheme.textSecondary)
                                    }
                                }

                                // Category segmented
                                Picker("Category", selection: $selectedCategory) {
                                    ForEach(EmojiCatalog.Category.allCases) { cat in
                                        Text(cat.rawValue).tag(cat)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .tint(FuturistTheme.neonAqua)

                                // Emoji grid container
                                VStack(spacing: 10) {
                                    ScrollView {
                                        LazyVGrid(columns: gridColumns, spacing: 10) {
                                            ForEach(baseEmojis, id: \.self) { emoji in
                                                Button {
                                                    selectedEmoji = emoji
                                                    validationMessage = nil
                                                } label: {
                                                    Text(emoji)
                                                        .font(.system(size: 24))
                                                        .frame(maxWidth: .infinity, minHeight: 36)
                                                        .padding(.vertical, 4)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                .fill(selectedEmoji == emoji ? FuturistTheme.neonAqua.opacity(0.18) : Color.clear)
                                                        )
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                                .stroke(
                                                                    selectedEmoji == emoji ? FuturistTheme.neonAqua : FuturistTheme.cardStroke,
                                                                    lineWidth: selectedEmoji == emoji ? 2 : 1
                                                                )
                                                        )
                                                        .foregroundStyle(FuturistTheme.textPrimary)
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityLabel(emoji)
                                            }
                                        }
                                        .padding(.vertical, 6)
                                    }
                                    .frame(minHeight: 240, maxHeight: 360)
                                    .scrollIndicators(.visible)

                                    if selectedCategory == .myEmojis, appState.customEmojis.isEmpty {
                                        Text("No saved emojis yet. Tap “Manage My Emojis” below to add some.")
                                            .font(.footnote)
                                            .foregroundStyle(FuturistTheme.textSecondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .foregroundStyle(FuturistTheme.textPrimary)
                        }
                        .padding(.horizontal, AddTaskMetrics.pageHPad)

                        BrightLineSeparator()

                        Spacer(minLength: 20)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }

                // Bottom bar: Manage My Emojis (frosted)
                VStack(spacing: 0) {
                    Rectangle().fill(FuturistTheme.divider).frame(height: 1).accessibilityHidden(true)
                    HStack(spacing: 10) {
                        Text("Manage My Emojis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FuturistTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .foregroundStyle(FuturistTheme.textSecondary)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        .ultraThinMaterial
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { showMyEmojisSheet = true }
                }
                .ignoresSafeArea(edges: .bottom)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            // Hide system nav bar; theme uses custom header
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // Themed header: Cancel / title / Save pills
            .safeAreaInset(edge: .top, spacing: 0) {
                // 👇 Option A: add a small top spacer so pills sit a bit lower
                let topSpacer: CGFloat = 8  // tweak to taste (e.g., 6–10)
                ZStack {
                    Text("Add Task")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    VStack(spacing: 0) {
                        Color.clear.frame(height: topSpacer)

                        HStack {
                            ToolbarPillButton(
                                label: "Cancel",
                                foreground: .white,
                                background: FuturistTheme.softRedLight,
                                stroke: FuturistTheme.softRedBase.opacity(0.75),
                                action: {
                                    onCancel?()
                                    dismiss()
                                }
                            )
                            Spacer(minLength: 12)
                            ToolbarPillButton(
                                label: "Save",
                                foreground: canSave ? Color.black.opacity(0.9) : FuturistTheme.textSecondary,
                                background: canSave ? FuturistTheme.softGreenLight : Color.clear,
                                stroke: canSave ? FuturistTheme.softGreenBase.opacity(0.75)
                                                : FuturistTheme.textSecondary.opacity(0.35),
                                disabled: !canSave,
                                glow: canSave,
                                action: { if canSave { save() } }
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .background(Color.clear)
            }
            // My Emojis sheet (unchanged logic; themed screen keeps behaviour)
            .sheet(isPresented: $showMyEmojisSheet) {
                CustomEmojiLibraryView { picked in
                    selectedEmoji = picked
                    selectedCategory = .myEmojis
                }
                .environmentObject(appState)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    titleFocused = true
                }
            }
        }
    }

    // MARK: - Save flow (unchanged logic)
    private func save() {
        validationMessage = nil
        let t = trimmedTitle
        guard !t.isEmpty else {
            validationMessage = "Please enter a task title."
            return
        }
        guard !isDuplicate else {
            validationMessage = "That task already exists. Please choose a different name."
            return
        }
        guard let emoji = selectedEmoji, !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationMessage = "Please select an emoji."
            return
        }
        let points = max(0, rewardPoints)

        if let created = appState.createTaskTemplate(title: t,
                                                     iconSymbol: emoji,
                                                     rewardPoints: points) {
            onSaved?(created)
            dismiss()
        } else {
            validationMessage = "Couldn’t create task. Please try again."
        }
    }
}
