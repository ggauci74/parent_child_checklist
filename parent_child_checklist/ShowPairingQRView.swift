//
//  ShowPairingQRView.swift
//  parent_child_checklist
//
//  Parent-facing sheet that displays a short-lived pairing QR for a specific child.
//  Uses PairingTokenService to generate a signed token and renders it as a QR image.
//
//  DEBUG conveniences:
//   - Copy token
//   - Expand to view raw token string (for pasting into child dev sheet)
//
//  Presented from ParentChildrenTabView's per-child action cluster.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Combine          // needed for Timer.publish(...).autoconnect()
import UIKit            // used for UIPasteboard in DEBUG tools

struct ShowPairingQRView: View {
    // Input
    let child: ChildProfile
    /// Pass in the current epoch for this child (usually child.pairingEpoch).
    let pairingEpoch: Int
    /// Optional family scope if you decide to gate tokens to a single family.
    var familyId: UUID? = nil
    /// Token lifetime (seconds). Keep short (e.g., 10–15 minutes).
    var validity: TimeInterval = 10 * 60
    /// Optional close callback (when dismissing from a manual button).
    var onClose: (() -> Void)? = nil

    // Theme
    private enum Theme {
        static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00)
        static let textSecondary = Color.white.opacity(0.78)
        static let cardStroke    = Color.white.opacity(0.08)
        static let cardShadow    = Color.black.opacity(0.10)
        static let surfaceFrost  = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
        static let surfaceSolid  = Color(red: 0.05, green: 0.10, blue: 0.22)
    }

    // Service — initialize with defaults; reconfigure in onAppear.
    @State private var tokenService = PairingTokenService()

    // Token state
    @State private var tokenString: String = ""
    @State private var issuedAt: Date = .distantPast
    @State private var expiresAt: Date = .distantPast
    @State private var remaining: Int = 0
    @State private var errorMessage: String?

    // QR image state
    @State private var qrImage: Image? = nil

    // Timer
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Futurist background
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header
                        contentCard
                        hintCard
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            // ⬇️ Add a top buffer above the header bar (pills + title)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 12)   // breathing room from the notch/status area
                    topBar
                }
                .background(Color.clear)
            }
            .onAppear {
                // Configure service with desired validity & family scope at runtime
                tokenService = PairingTokenService(
                    config: PairingTokenService.Config(
                        allowedClockSkew: 90,
                        defaultValidity: validity,
                        familyId: familyId,
                        // DEV ONLY — rotate/change for your environment.
                        devHMACSecret: Data("DEV_SECRET_CHANGE_ME_ROTATE_ME".utf8)
                    )
                )
                regenerateToken()
            }
            .onReceive(tick) { _ in
                guard tokenString.isEmpty == false else { return }
                let secs = Int(max(0, expiresAt.timeIntervalSinceNow.rounded(.down)))
                remaining = secs
                if secs <= 0 {
                    regenerateToken()
                }
            }
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        ZStack {
            Text("Pair \(child.name)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            HStack {
                PillButton(
                    label: "Close",
                    foreground: .white,
                    background: Color(red: 1.00, green: 0.58, blue: 0.63),
                    stroke: Color(red: 1.00, green: 0.36, blue: 0.43).opacity(0.75)
                ) {
                    onClose?()
                }
                Spacer(minLength: 12)
                PillButton(
                    label: "Regenerate",
                    foreground: Color.black.opacity(0.9),
                    background: Color(red: 0.62, green: 0.95, blue: 0.73),
                    stroke: Color(red: 0.27, green: 0.89, blue: 0.54).opacity(0.75)
                ) {
                    regenerateToken()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color.clear)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Show this QR to your child’s device")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Valid for a short time. The child scans once to pair this device with \(child.name).")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var contentCard: some View {
        VStack(spacing: 12) {
            if let err = errorMessage {
                Text(err)
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let img = qrImage {
                img
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 280)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 1)
                    .accessibilityLabel("Pairing QR code")
            } else {
                ProgressView().progressViewStyle(.circular)
                    .tint(.white)
            }

            countdown
            #if DEBUG
            debugTools
            #endif
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surfaceFrost)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.cardStroke, lineWidth: 1)
        )
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 1)
    }

    private var countdown: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .foregroundStyle(Theme.textSecondary)
            Text(remainingText())
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tips")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("• The QR expires automatically. If it runs out, tap Regenerate.\n• If a device was paired to the wrong child, reset pairing for that child and re‑scan.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surfaceFrost)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.cardStroke, lineWidth: 1)
        )
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 1)
    }

    #if DEBUG
    private var debugTools: some View {
        VStack(spacing: 8) {
            DisclosureGroup {
                ScrollView(.vertical) {
                    Text(tokenString)
                        .font(.footnote.monospaced())
                        .foregroundStyle(Theme.textSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxHeight: 120)
            } label: {
                Text("Show raw token (DEBUG)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = tokenString
                } label: {
                    Label("Copy token", systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    regenerateToken()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
    #endif

    // MARK: - Actions

    private func regenerateToken() {
        do {
            errorMessage = nil
            let s = try tokenService.makeSignedToken(
                for: child.id,
                pairingEpoch: pairingEpoch,
                validFor: validity,
                appVersion: nil
            )
            tokenString = s
            issuedAt = Date()
            expiresAt = issuedAt.addingTimeInterval(validity)
            remaining = Int(validity)
            qrImage = makeQRImage(from: s)
        } catch {
            errorMessage = error.localizedDescription
            tokenString = ""
            qrImage = nil
        }
    }

    private func remainingText() -> String {
        guard remaining > 0 else { return "Expired — tap Regenerate" }
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "Expires in %d:%02d", m, s)
    }

    // MARK: - QR generation

    private func makeQRImage(from string: String) -> Image? {
        let data = Data(string.utf8)
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.correctionLevel = "M" // medium error correction

        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 8, y: 8))

        let context = CIContext()
        if let cgimg = context.createCGImage(transformed, from: transformed.extent) {
            #if os(iOS)
            return Image(uiImage: UIImage(cgImage: cgimg))
            #else
            return Image(decorative: cgimg, scale: 1.0, orientation: .up)
            #endif
        }
        return nil
    }
}

// MARK: - Helpers

private struct PillButton: View {
    let label: String
    var foreground: Color
    var background: Color
    var stroke: Color
    var action: () -> Void
    var body: some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: 112, height: 32)
            .background(Capsule().fill(background))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.10), radius: 3)
            .contentShape(Capsule())
            .onTapGesture { action() }
    }
}
