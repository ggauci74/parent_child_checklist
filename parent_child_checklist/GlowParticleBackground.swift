//
//  GlowParticleBackground.swift
//  parent_child_checklist
//
//  Created by George Gauci on 26/2/2026.
//


import SwiftUI

struct GlowParticleBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var time: CGFloat = 0
    @State private var shootingStarActive = false
    @State private var shootingStarOffset = CGSize.zero

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let t = reduceMotion ? 0 : CGFloat(now)

            Canvas { context, size in

                // ============ 1) BASE NEBULA GRADIENT ============
                let nebula = Gradient(colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.16),   // deep navy
                    Color(red: 0.10, green: 0.02, blue: 0.20),   // purple tint
                    Color(red: 0.02, green: 0.03, blue: 0.08)    // near-black
                ])

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        nebula,
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // ============ 2) FLOATING GLOW CLOUDS ============
                let glowColors = [
                    Color.cyan.opacity(0.18),
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.10)
                ]

                for i in 0..<3 {
                    let cx = size.width * (0.3 + 0.4 * CGFloat(i))
                    let cy = size.height * (0.3 + 0.2 * CGFloat(sin(t * 0.1 + CGFloat(i))))

                    let rect = CGRect(
                        x: cx - 200,
                        y: cy - 200,
                        width: 400,
                        height: 400
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [glowColors[i], .clear]),
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            startRadius: 10,
                            endRadius: 200
                        )
                    )
                }

                // ============ 3) TWINKLING PARTICLES ============
                let particleCount = 160
                let seed: CGFloat = 9123

                for i in 0..<particleCount {
                    let fx = frac(sin(CGFloat(i) * 12.15 + seed) * 45234.204)
                    let fy = frac(sin(CGFloat(i) * 73.91 + seed) * 91234.112)

                    let x = fx * size.width
                    let y = fy * size.height

                    let twinkle = 0.4 + 0.6 * abs(sin(t * 1.5 + fx * 12 + fy * 9))

                    let r = 0.8 + frac(fx * fy * 93.1) * 1.4

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                        with: .color(.white.opacity(0.15 + twinkle * 0.6))
                    )
                }

                // ============ 4) SHOOTING STAR ============
                if shootingStarActive {
                    let start = CGPoint(
                        x: size.width * 0.1 + shootingStarOffset.width,
                        y: size.height * 0.2 + shootingStarOffset.height
                    )
                    let end = CGPoint(
                        x: start.x + 120,
                        y: start.y + 40
                    )

                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)

                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.9)),
                        lineWidth: 2
                    )
                }
            }
            .onAppear {
                startShootingStarLoop()
            }
            .ignoresSafeArea()
        }
    }

    private func startShootingStarLoop() {
        guard !reduceMotion else { return }

        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            shootingStarActive = true
            shootingStarOffset = .zero

            withAnimation(.linear(duration: 0.8)) {
                shootingStarOffset = CGSize(width: 400, height: 160)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                shootingStarActive = false
            }
        }
    }

    private func frac(_ x: CGFloat) -> CGFloat {
        x - floor(x)
    }
}
