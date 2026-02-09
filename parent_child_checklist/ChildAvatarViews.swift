import SwiftUI

/// Coloured avatar circle used everywhere a child icon appears.
/// If avatarId is nil, shows a placeholder.
struct ChildAvatarCircleView: View {
    let colorHex: String
    let avatarId: String?
    var size: CGFloat = 40

    private var displayEmoji: String {
        if avatarId == nil { return "👤" }
        return AvatarCatalog.avatar(for: avatarId).emoji
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex))

            Text(displayEmoji)
                .font(.system(size: size * 0.55))
        }
        .frame(width: size, height: size)
        .accessibilityLabel(
            avatarId == nil
            ? "Avatar not chosen yet"
            : "Avatar \(AvatarCatalog.avatar(for: avatarId).displayName)"
        )
    }
}
