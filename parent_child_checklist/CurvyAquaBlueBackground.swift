//
//  CurvyAquaBlueBackground.swift
//  parent_child_checklist
//
//  List‑safe animated background (reversing shimmer; no compositing issues)
//

import SwiftUI

struct CurvyAquaBlueBackground: View {
    var animate: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var t: CGFloat = 0   // wave phase

    var body: some View {
        ZStack {
            // 1) Deep blue base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.02, green: 0.08, blue: 0.25), // deep navy
                    Color(red: 0.00, green: 0.22, blue: 0.50), // sapphire
                    Color(red: 0.00, green: 0.45, blue: 0.85), // electric blue
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()

            // 2) Soft vignette (opacity only; no blendMode)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.22),
                    .clear
                ]),
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()

            // 3) Lower wave (deeper band)
            WaveBandSafe(
                yOffset: animate && !reduceMotion ? sin(t * 0.9) * 18 : 0,
                thickness: 260,
                colors: [
                    Color.blue.opacity(0.23),
                    Color.blue.opacity(0.06),
                    .clear
                ],
                blur: 34,
                rotation: .degrees(-12)
            )
            .offset(y: 180)

            // 4) Upper wave (brighter highlight)
            WaveBandSafe(
                yOffset: animate && !reduceMotion ? cos(t * 1.4 + 1.2) * 22 : 0,
                thickness: 200,
                colors: [
                    Color(red: 0.20, green: 0.80, blue: 1.00).opacity(0.42),
                    Color.blue.opacity(0.16),
                    .clear
                ],
                blur: 26,
                rotation: .degrees(-10)
            )
            .offset(y: 60)

            // 5) Corner glow (top‑right)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.78),
                    Color.white.opacity(0.0)
                ]),
                center: .topTrailing,
                startRadius: 16,
                endRadius: 360
            )
            .ignoresSafeArea()

            // 6) Reversing shimmer (ease in/out; no snap; list‑safe)
            if animate && !reduceMotion {
                ShimmerSweepAutoReverse(duration: 12) // adjust duration for feel (slower/faster)
                    .allowsHitTesting(false)
            }
        }
        // Always behind content; never intercept gestures
        .zIndex(-1)
        .allowsHitTesting(false)
        .onAppear {
            guard animate && !reduceMotion else { return }

            // Wave motion (ease at turnarounds for a natural feel)
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                t = .pi * 2
            }
        }
    }
}

// MARK: - Wave band with no blend modes (safer for List)
private struct WaveBandSafe: View {
    var yOffset: CGFloat
    var thickness: CGFloat
    var colors: [Color]
    var blur: CGFloat
    var rotation: Angle

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 1.6
            Capsule()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: colors),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: w, height: thickness)
                .rotationEffect(rotation)
                .offset(x: -w * 0.2, y: yOffset)
                .blur(radius: blur)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .opacity(0.95)
    }
}

// MARK: - Reversing shimmer (ease‑in‑out; no blend modes)
private struct ShimmerSweepAutoReverse: View {
    var duration: Double = 8   // total time for a forward or backward sweep
    var bandOpacity: CGFloat = 0.14
    var blurRadius: CGFloat = 70
    var angle: Angle = .degrees(35)

    @State private var phase: CGFloat = -0.5  // animates to +0.5 and back (autoreverse)

    var body: some View {
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height) * 1.2
            let travel: CGFloat = side + 200               // how far the shimmer travels
            let offset = phase * travel                    // convert normalized phase → points

            Rectangle()
                .fill(Color.white.opacity(bandOpacity))
                .frame(width: side, height: side)
                .rotationEffect(angle)
                .offset(x: offset, y: offset)
                .blur(radius: blurRadius)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.00),
                            .init(color: .white, location: 0.20),
                            .init(color: .white, location: 0.40),
                            .init(color: .clear, location: 0.70),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        phase = 0.5   // -0.5 → +0.5 → -0.5 … smoothly
                    }
                }
        }
        .ignoresSafeArea()
    }
}
