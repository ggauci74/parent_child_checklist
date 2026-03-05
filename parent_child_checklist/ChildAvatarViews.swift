//
// ChildAvatarCircleView.swift
// parent_child_checklist
//
// Circular avatar image with a child-colour ring.
// Falls back to a neutral placeholder when no avatarId is set.
//

import SwiftUI

struct ChildAvatarCircleView: View {
    let colorHex: String
    let avatarId: String?
    var size: CGFloat = 40
    /// Ring thickness (pt)
    private let ringThickness: CGFloat = 1.5

    private var catalogAvatar: AvatarCatalog.Avatar {
        AvatarCatalog.avatar(for: avatarId)
    }

    var body: some View {
        ZStack {
            if let avatarId, !avatarId.isEmpty, !catalogAvatar.assetName.isEmpty {
                // Bundled image → circular center-crop
                Image(catalogAvatar.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Placeholder: subtle neutral background + person glyph
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.52, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(Color(hex: colorHex), lineWidth: ringThickness)
        )
        .accessibilityLabel(
            avatarId == nil || avatarId?.isEmpty == true
            ? "Avatar not chosen yet"
            : "Avatar \(catalogAvatar.displayName)"
        )
    }
}

