//
// ChildAvatarSetupView.swift
// parent_child_checklist
//

import SwiftUI

// Local theme tokens (mirrors other child screens in this file only)
private enum FuturistTheme {
    static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00) // frosted white headline
    static let textSecondary = Color(red: 0.63, green: 0.73, blue: 0.82) // secondary on dark
}

// Same CardBackground used on other screens (glass + thin stroke + micro shadow)
private struct CardBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let surface      = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    private let surfaceSolid = Color(red: 0.05, green: 0.10, blue: 0.22)
    var cornerRadius: CGFloat = 12
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(reduceTransparency ? surfaceSolid : surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
    }
}

// Gentle dark sweep behind the content area (like other child screens)
private struct LowerContentSweep: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.00),
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.05), location: 0.50),
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.08), location: 1.00)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ChildAvatarSetupView: View {
    let childId: UUID
    // Parent-provided callback used to switch tabs back to Today
    var onContinue: (() -> Void)? = nil

    @AppStorage("selectedChildId") private var selectedChildIdRaw: String?

    @EnvironmentObject private var appState: AppState

    @State private var selectedAvatarId: String? = nil
    @State private var errorMessage: String? = nil

    // MARK: - Derived
    private var child: ChildProfile? {
        appState.children.first { $0.id == childId }
    }

    /// Avatars currently used by other children in the family (enforce 1‑per‑child)
    private var takenAvatarIds: Set<String> {
        let current = child?.avatarId
        let allTaken = appState.children.compactMap { $0.avatarId }
        return Set(allTaken.filter { $0 != current })
    }

    private var canContinue: Bool { selectedAvatarId != nil }

    // Matches the large page titles used across child screens
    private let largeTitleSize: CGFloat = 36

    // Grid metrics
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background to match the rest of the child experience
                CurvyAquaBlueBackground(animate: true)

                VStack(spacing: 0) {
                    if let child {
                        // Shared header (gems + avatar + child name). We pass the in-progress choice for live preview.
                        ChildHeaderView(
                            child: child,
                            points: appState.childPointsTotal(childId: childId),
                            avatarIdOverride: selectedAvatarId ?? child.avatarId
                        )
                        .padding(.horizontal)

                        // Big page title (frosted white)
                        Text("Select Avatar")
                            .font(.system(size: largeTitleSize, weight: .regular))
                            .foregroundStyle(FuturistTheme.textPrimary)
                            .padding(.top, 2)

                        ZStack {
                            LowerContentSweep()

                            VStack(spacing: 12) {
                                // Avatar grid inside a dark card
                                VStack(alignment: .leading, spacing: 12) {
                                    LazyVGrid(columns: gridColumns, spacing: 12) {
                                        ForEach(AvatarCatalog.all) { avatar in
                                            avatarTile(avatar: avatar,
                                                       isTaken: takenAvatarIds.contains(avatar.id),
                                                       isSelected: selectedAvatarId == avatar.id,
                                                       ringHex: child.colorHex)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(CardBackground())
                                .padding(.horizontal)

                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                        .padding(.horizontal)
                                }

                                // Accent "Continue" button (same look as other screens)
                                Button {
                                    continueTapped()
                                } label: {
                                    Text("Continue")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                                .disabled(!canContinue)
                                .opacity(canContinue ? 1.0 : 0.55)

                                Spacer(minLength: 10)
                            }
                            .padding(.top, 6) // medium-tight rhythm under the title
                        }
                    } else {
                        // Fallback if child profile is not found
                        VStack {
                            Spacer()
                            Text("That child profile can’t be found.")
                                .foregroundStyle(FuturistTheme.textSecondary)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .onAppear {
            // Prefill with current avatar so the header shows it immediately
            selectedAvatarId = child?.avatarId
        }
    }

    // MARK: - Avatar Tile
    @ViewBuilder
    private func avatarTile(avatar: AvatarCatalog.Avatar,
                            isTaken: Bool,
                            isSelected: Bool,
                            ringHex: String) -> some View {
        Button {
            guard !isTaken else { return }
            selectedAvatarId = avatar.id
            errorMessage = nil
        } label: {
            VStack(spacing: 8) {
                // Reuse your circular avatar with the child-colour ring
                ChildAvatarCircleView(
                    colorHex: ringHex,
                    avatarId: avatar.id,
                    size: 56
                )
                .overlay(alignment: .center) {
                    // Subtle selection halo that does not change layout
                    if isSelected {
                        Circle()
                            .stroke(Color.accentColor.opacity(0.85), lineWidth: 2)
                            .frame(width: 56 + 10, height: 56 + 10)
                            .blur(radius: 0.2)
                            .allowsHitTesting(false)
                    }
                }

                Text(avatar.displayName)
                    .font(.footnote)
                    .foregroundStyle(isTaken ? FuturistTheme.textSecondary.opacity(0.65)
                                             : FuturistTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.white.opacity(0.06)     // subtle surface when selected
                        : Color.white.opacity(0.03)     // quiet tile surface on dark card
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected
                        ? Color.accentColor               // selected ring
                        : Color.white.opacity(0.12),      // quiet border
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .opacity(isTaken ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isTaken)
        .contentShape(Rectangle())
        .accessibilityLabel(
            isTaken
            ? "\(avatar.displayName), locked"
            : (isSelected ? "Selected: \(avatar.displayName)" : avatar.displayName)
        )
    }

    // MARK: - Save / Continue
    private func continueTapped() {
        guard let child = appState.children.first(where: { $0.id == childId }) else { return }
        guard let selectedAvatarId else { return }

        // Enforce uniqueness via data layer
        let ok = appState.updateChildAvatar(childId: child.id, newAvatarId: selectedAvatarId)
        if ok {
            // Persist selection for child mode
            selectedChildIdRaw = child.id.uuidString

            // Notify the app that the avatar has been updated (Today screen shows toast)
            NotificationCenter.default.post(name: .avatarUpdated, object: nil)

            // Ask the parent tab view to jump to Today
            onContinue?()
        } else {
            errorMessage = "That avatar was just taken. Please choose another."
        }
    }
}
