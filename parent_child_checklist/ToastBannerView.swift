//
//  ToastBannerView.swift
//  parent_child_checklist
//
//  Created by George Gauci on 8/2/2026.
//
import SwiftUI

struct ToastBannerView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            .padding(.horizontal)
            .padding(.top, 10)
            .accessibilityLabel(message)
    }
}

