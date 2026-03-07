//
//  ReviewRewardRequestView.swift
//  parent_child_checklist
//

import SwiftUI
import UIKit

// MARK: - Futurist theme tokens (parity with your other screens)
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

// MARK: - Toolbar pill buttons
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
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }
}

// MARK: - Dark frosted text field
private struct FrostedField: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        let fill = reduceTransparency ? FuturistTheme.surfaceSolid : Color.white.opacity(0.06)
        TextField("",
                  text: $text,
                  prompt: Text(placeholder).foregroundStyle(FuturistTheme.textSecondary),
                  axis: axis)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .foregroundStyle(FuturistTheme.textPrimary)
            .tint(FuturistTheme.neonAqua)
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

// MARK: - Round glyph button (for +/- cost)
private struct RoundGlyphButton: View {
    var systemName: String
    var roleTint: Color
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
    }
}

// MARK: - Main view
struct ReviewRewardRequestView: View, Identifiable {
    var id: UUID { request.id }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let request: RewardRequest

    @State private var titleText: String
    @State private var gemCost: Int
    @State private var showDeleteConfirm = false

    init(request: RewardRequest) {
        self.request = request
        _titleText = State(initialValue: request.title)
        _gemCost = State(initialValue: max(0, request.approvedCost ?? 0))
    }

    private var childName: String {
        appState.children.first(where: { $0.id == request.childId })?.name ?? "Child"
    }

    private var isPending: Bool { request.status == .pending }
    private var isApprovedOrClaimed: Bool { request.status == .approved || request.status == .claimed }

    private func fmt(_ d: Date?) -> String? {
        guard let d else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: d)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ===== Card 1: Request (child + title) =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Request")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)

                                HStack {
                                    Text("Child")
                                        .foregroundStyle(FuturistTheme.textPrimary)
                                    Spacer()
                                    Text(childName)
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                }

                                if isPending {
                                    FrostedField(placeholder: "Title", text: $titleText, axis: .vertical)
                                        .lineLimit(2, reservesSpace: true)
                                } else {
                                    Text(request.title)
                                        .font(.headline)
                                        .foregroundStyle(FuturistTheme.textPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)
                        .padding(.top, 12)

                        BrightLineSeparator()

                        // ===== Card 2: Gem Cost =====
                        if isPending {
                            FrostedCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Gem Cost")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(FuturistTheme.textSecondary)

                                    HStack(spacing: 12) {
                                        HStack(spacing: 6) {
                                            Text("💎")
                                            Text("Cost")
                                        }
                                        .foregroundStyle(FuturistTheme.textPrimary)

                                        Spacer()

                                        RoundGlyphButton(
                                            systemName: "minus",
                                            roleTint: FuturistTheme.softRedLight,
                                            disabled: gemCost == 0
                                        ) { gemCost = max(0, gemCost - 1) }

                                        Text("\(gemCost)")
                                            .font(.headline)
                                            .foregroundStyle(FuturistTheme.textPrimary)
                                            .frame(minWidth: 40)

                                        RoundGlyphButton(
                                            systemName: "plus",
                                            roleTint: FuturistTheme.softGreenLight
                                        ) { gemCost += 1 }
                                    }

                                    // Optional numeric entry, themed
                                    HStack(spacing: 8) {
                                        Text("Enter cost")
                                            .font(.footnote)
                                            .foregroundStyle(FuturistTheme.textSecondary)
                                        Spacer()
                                        TextField("0", value: $gemCost, format: .number)
                                            .keyboardType(.numberPad)
                                            .multilineTextAlignment(.trailing)
                                            .foregroundStyle(FuturistTheme.textPrimary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color.white.opacity(0.06))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(FuturistTheme.cardStroke, lineWidth: 1)
                                            )
                                            .frame(width: 96)
                                    }
                                }
                            }
                            .padding(.horizontal, PageMetrics.pageHPad)
                        } else if isApprovedOrClaimed, let cost = request.approvedCost {
                            FrostedCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Gem Cost")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(FuturistTheme.textSecondary)

                                    HStack {
                                        Text("Cost")
                                            .foregroundStyle(FuturistTheme.textPrimary)
                                        Spacer()
                                        Text("💎 \(cost)")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(FuturistTheme.textPrimary)
                                    }
                                }
                            }
                            .padding(.horizontal, PageMetrics.pageHPad)
                        }

                        BrightLineSeparator()

                        // ===== Card 3: Timeline =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Timeline")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FuturistTheme.textSecondary)

                                Row(label: "Requested", value: fmt(request.requestedAt) ?? "-")

                                if request.status == .approved || request.approvedAt != nil {
                                    Row(label: "Approved", value: fmt(request.approvedAt) ?? "-")
                                }
                                if request.status == .notApproved || request.notApprovedAt != nil {
                                    Row(label: "Not this time", value: fmt(request.notApprovedAt) ?? "-")
                                }
                                if request.status == .claimed || request.claimedAt != nil {
                                    Row(label: "Claimed", value: fmt(request.claimedAt) ?? "-")
                                }
                            }
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)

                        BrightLineSeparator()

                        // ===== Card 4: Actions =====
                        FrostedCard {
                            VStack(alignment: .leading, spacing: 12) {
                                if isPending {
                                    // Approve (left) and Not this time (right)
                                    HStack(spacing: 12) {
                                        // Left-aligned Approve
                                        ToolbarPillButton(
                                            label: "Approve",
                                            foreground: Color.black.opacity(0.9),
                                            background: FuturistTheme.softGreenLight,
                                            stroke: FuturistTheme.softGreenBase.opacity(0.75),
                                            glow: true,
                                            action: {
                                                let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                                                _ = appState.approveRewardRequest(id: request.id, cost: gemCost, newTitle: trimmed)
                                                dismiss()
                                            }
                                        )

                                        Spacer(minLength: 12)

                                        // Right-aligned Not this time (wider + no truncation)
                                        ToolbarPillButton(
                                            label: "Not this time",
                                            foreground: .white,
                                            background: FuturistTheme.softRedLight,
                                            stroke: FuturistTheme.softRedBase.opacity(0.75),
                                            fixedWidth: 140, // ensure adequate width for full label
                                            action: {
                                                _ = appState.notApproveRewardRequest(id: request.id)
                                                dismiss()
                                            }
                                        )
                                        .fixedSize(horizontal: true, vertical: false) // never truncate the label
                                    }
                                } else {
                                    Text("This request is \(request.status.childDisplay.lowercased()).")
                                        .font(.footnote)
                                        .foregroundStyle(FuturistTheme.textSecondary)
                                }

                                // Delete (destructive)
                                Button {
                                    showDeleteConfirm = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "trash")
                                        Text("Delete Request")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule().fill(FuturistTheme.softRedLight)
                                    )
                                    .overlay(
                                        Capsule().stroke(FuturistTheme.softRedBase.opacity(0.75), lineWidth: 1)
                                    )
                                    .shadow(color: FuturistTheme.cardShadow, radius: 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, PageMetrics.pageHPad)

                        Spacer(minLength: 24)
                    }
                    .padding(.bottom, 24)
                }
            }
            // Hide system nav bar; themed header below
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // Header (Close pill + centered title)
            .safeAreaInset(edge: .top, spacing: 0) {
                let topSpacer: CGFloat = 8
                ZStack {
                    Text("Review")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    VStack(spacing: 0) {
                        Color.clear.frame(height: topSpacer)
                        HStack {
                            ToolbarPillButton(
                                label: "Close",
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

            // Delete confirmation alert (unchanged logic)
            .alert("Delete this request?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    _ = appState.deleteRewardRequest(id: request.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the request.")
            }
        }
    }

    // MARK: - Simple row helper
    @ViewBuilder
    private func Row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(FuturistTheme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(FuturistTheme.textSecondary)
        }
    }
}
