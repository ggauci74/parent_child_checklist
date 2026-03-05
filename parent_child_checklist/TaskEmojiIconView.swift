//
//  TaskEmojiIconView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//


//
//  TaskEmojiIconView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//

import SwiftUI

/// Emoji-only task icon view.
/// If `icon` isn't an emoji (e.g., legacy SF Symbol string), shows a safe default ✅.
struct TaskEmojiIconView: View {
    let icon: String
    var size: CGFloat = 24

    private var displayEmoji: String {
        let t = icon.trimmed
        return t.containsEmoji ? t : "✅"
    }

    var body: some View {
        Text(displayEmoji)
            .font(.system(size: size))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: 40, height: 40)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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