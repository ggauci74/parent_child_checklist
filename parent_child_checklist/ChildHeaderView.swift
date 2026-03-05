//
//  ChildHeaderView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 20/2/2026.
//


//
// ChildHeaderView.swift
// parent_child_checklist
//
// Reusable child header used across the Child screens:
// - Left-aligned gems (💎 36pt + 36pt bold number)
// - Centered avatar (default 88pt, with optional override avatarId for live preview)
// - Child name (36pt heavy) below the avatar
//

import SwiftUI

struct ChildHeaderView: View {
    // Required
    let child: ChildProfile
    let points: Int

    // Optional: lets Avatar screen show the in-progress selection
    var avatarIdOverride: String? = nil

    // Styling (kept here so future tuning is centralized)
    var nameFontSize: CGFloat = 36
    var avatarSize: CGFloat = 88

    // Tiny spacing tweak for shorter devices (same behaviour as other screens)
    private var isSmallHeight: Bool {
        UIScreen.main.bounds.height <= 700
    }

    private var pointsText: String {
        String(points)
    }

    var body: some View {
        VStack(spacing: isSmallHeight ? 10 : 8) {
            ZStack {
                // Left-aligned gems — 36pt diamond + 36pt bold number
                HStack(spacing: 6) {
                    Text("💎")
                        .font(.system(size: 36))
                    Text(pointsText)
                        .font(.system(size: 36, weight: .bold))
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Reward points \(pointsText)")

                // Centered avatar — 88pt by default.
                // If avatarIdOverride is provided, show that (used by Avatar screen live preview).
                ChildAvatarCircleView(
                    colorHex: child.colorHex,
                    avatarId: avatarIdOverride ?? child.avatarId,
                    size: avatarSize
                )
            }
            .padding(.top, 8)
            .padding(.bottom, isSmallHeight ? 6 : 0)

            // Child name — 36pt heavy
            Text(child.name)
                .font(.system(size: nameFontSize, weight: .heavy))
                .lineLimit(1)
        }
    }
}
