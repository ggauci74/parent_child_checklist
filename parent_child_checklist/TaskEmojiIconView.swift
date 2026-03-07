//
//  TaskEmojiIconView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//

import SwiftUI

/// Emoji-only task icon view using the app's frosted tile style.
/// If `icon` isn't an emoji (e.g., legacy SF Symbol string), shows a safe default ✅.
struct TaskEmojiIconView: View {
    let icon: String
    /// Visual glyph size (the emoji itself).
    var size: CGFloat = 24

    // Tile metrics to match the Add Task emoji grid feel
    private let cornerRadius: CGFloat = 12
    private let innerPad: CGFloat = 6  // space around the emoji inside the tile

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var displayEmoji: String {
        let t = icon.trimmed
        return t.containsEmoji ? t : "✅"
    }

    var body: some View {
        // Frosted tile fill – same vibe as Add Task cards/grid
        let fill: Color = reduceTransparency
            ? Color(red: 0.05, green: 0.10, blue: 0.22)                 // solid surface when transparency reduced
            : Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)   // frosted surface

        Text(displayEmoji)
            .font(.system(size: size))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            // Tile dimensions: emoji size + inner padding on both sides
            .frame(width: size + innerPad * 2, height: size + innerPad * 2)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1) // subtle keyline like other cards
            )
            .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 1) // soft elevation
            .accessibilityLabel("Task icon")
    }
}

// MARK: - Emoji Detection + Sanitising Helpers

extension String {
    /// Simple heuristic to detect emojis (including composed sequences).
    var containsEmoji: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || scalar.properties.isEmoji
        }
    }

    /// Trims whitespace/newlines and normalises.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Preview

#if DEBUG
struct TaskEmojiIconView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TaskEmojiIconView(icon: "🧹")
            TaskEmojiIconView(icon: "not-an-emoji")
            TaskEmojiIconView(icon: "  🍎  ", size: 32)
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}
#endif
