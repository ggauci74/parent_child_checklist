//
// AddEventTemplateView.swift
// parent_child_checklist
//

import SwiftUI

// MARK: - Futurist theme tokens (parity with other screens)
private enum FuturistTheme {
    static let neonAqua       = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let textPrimary    = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary  = Color.white.opacity(0.78)
    static let cardStroke     = Color.white.opacity(0.08)
    static let cardShadow     = Color.black.opacity(0.10)

    static let surfaceSolid   = Color(red: 0.05, green: 0.10, blue: 0.22)
    static let surfaceFrost   = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)

    // Header pills
    static let softRedBase    = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase  = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight   = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
}

// MARK: - Layout metrics
private enum PageMetrics {
    static let pageHPad: CGFloat     = 12
    static let innerHPad: CGFloat    = 16
    static let cornerRadius: CGFloat = 14
    static let fieldCorner: CGFloat  = 12
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

// MARK: - Bright cyan filament separator
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

// MARK: - Header pill button
private struct ToolbarPillButton: View {
    let label: String
    var foreground: Color
    var background: Color
    var stroke: Color
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
            .shadow(color: FuturistTheme.cardShadow, radius: 3)
            .contentShape(Capsule())
            .onTapGesture { action() }
    }
}

// MARK: - Main
struct AddEventTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Callbacks
    var onSaved: ((EventTemplate) -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    // State
    @State private var title: String = ""
    @State private var selectedEmoji: String? = nil
    @State private var selectedCategory: EmojiCatalog.Category = .all
    @State private var validationMessage: String? = nil
    @FocusState private var titleFocused: Bool

    @State private var showMyEmojisSheet = false

    // Square emoji tile size (prevents truncation)
    private let cell: CGFloat = 40

    // Adaptive grid so tiles stay square and wrap nicely
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: cell), spacing: 10)]
    }

    // Derived
    private var trimmedTitle: String { title.trimmed }

    private var isDuplicate: Bool {
        !trimmedTitle.isEmpty && appState.isEventTitleTaken(trimmedTitle)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !isDuplicate && (selectedEmoji?.trimmed.containsEmoji == true)
    }

    private var baseEmojis: [String] {
        switch selectedCategory {
        case .myEmojis: return appState.customEmojis
        default:        return EmojiCatalog.emojis(for: selectedCategory)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                // Content
                ScrollView {
                    VStack(spacing: 0) {

                        // ===== Event Title =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Event")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)

                                TextField("Title", text: $title)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled(true)
                                    .focused($titleFocused)
                                    .foregroundStyle(FuturistTheme.textPrimary)
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: PageMetrics.fieldCorner, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PageMetrics.fieldCorner, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )

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
                            .foregroundStyle(FuturistTheme.textPrimary)
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)
                        .padding(.top, 12)

                        BrightLineSeparator()

                        // ===== Icon (Emoji) =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Icon (Emoji)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)

                                // Selected row (right-aligned emoji; no ellipses)
                                HStack {
                                    Text("Selected")
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                    Spacer()
                                    if let selectedEmoji {
                                        Text(selectedEmoji).font(.system(size: 32))
                                    } else {
                                        Text("✅").font(.system(size: 28))
                                    }
                                }

                                // Category row (right-aligned Picker)
                                HStack {
                                    Text("Category")
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                    Spacer()
                                    Picker("Category", selection: $selectedCategory) {
                                        ForEach(EmojiCatalog.Category.allCases) { cat in
                                            Text(cat.rawValue).tag(cat)
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(FuturistTheme.neonAqua)
                                }

                                // Emoji grid — square cells, centered glyph, neon outline on selection
                                ScrollView {
                                    LazyVGrid(columns: gridColumns, spacing: 10) {
                                        ForEach(baseEmojis, id: \.self) { emoji in
                                            Button {
                                                selectedEmoji = emoji
                                                validationMessage = nil
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            } label: {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(selectedEmoji == emoji ? Color.white.opacity(0.06) : Color.clear)

                                                    Text(emoji)
                                                        .font(.system(size: 27))
                                                        .frame(width: cell, height: cell, alignment: .center)
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(1.0)
                                                        .contentShape(Rectangle())
                                                }
                                                .frame(width: cell, height: cell)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .stroke(
                                                            selectedEmoji == emoji ? FuturistTheme.neonAqua
                                                                                    : Color.white.opacity(0.20),
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
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                }
                            }
                            .foregroundStyle(FuturistTheme.textPrimary)
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)

                        BrightLineSeparator()

                        // Manage My Emojis footer card
                        FrostedCard {
                            Button {
                                showMyEmojisSheet = true
                            } label: {
                                HStack {
                                    Text("Manage My Emojis")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.up")
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)

                        Spacer(minLength: 24)
                    }
                    .padding(.bottom, 24)
                }
            }
            // Hide default nav; themed header below
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // Header (Cancel / title / Save) — Save is soft-green with black text
            .safeAreaInset(edge: .top, spacing: 0) {
                let topSpacer: CGFloat = 8
                ZStack {
                    Text("Add Event")
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

                            Spacer()

                            ToolbarPillButton(
                                label: "Save",
                                foreground: Color.black.opacity(0.9),
                                background: FuturistTheme.softGreenLight,
                                stroke: FuturistTheme.softGreenBase.opacity(0.75),
                                action: { save() }
                            )
                            .opacity(canSave ? 1.0 : 0.45)
                            .allowsHitTesting(canSave)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .background(Color.clear)
            }

            // My Emojis sheet
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
            .onChange(of: title) { _, _ in validationMessage = nil }
        }
    }

    // MARK: - Save logic (unchanged)
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

        if let created = appState.createEventTemplate(title: trimmedTitle, iconSymbol: emoji) {
            onSaved?(created)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } else {
            validationMessage = "Couldn’t create event. Please try again."
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}
