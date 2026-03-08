//
//  ChildPairingScannerSheet.swift
//  parent_child_checklist
//
//  Created by George Gauci on 8/3/2026.
//


//
//  ChildPairingScannerSheet.swift
//  parent_child_checklist
//
//  Child-facing pairing sheet.
//  - On device: live camera scan (AVFoundation) to read QR -> verify -> (caller binds device)
//  - DEBUG (Simulator): "Import from Photos" or "Paste token" to exercise full flow without camera
//
//  Not yet wired into ContentView; we'll present this sheet from ChildChooseProfileView
//  after we add the device-binding gate.
//

import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import Combine
import UIKit
#if canImport(PhotosUI)
import PhotosUI
#endif

struct ChildPairingScannerSheet: View {
    // Inputs from caller
    let expectedChildId: UUID
    let expectedPairingEpoch: Int
    /// Optional family scope if you enabled it for tokens.
    var familyId: UUID? = nil
    /// Called when a token verifies successfully (the caller should bind the device to this child & dismiss).
    var onVerified: (_ decoded: PairingToken) -> Void
    /// Called when the user cancels.
    var onCancel: () -> Void

    // Theme (local to keep this file self-contained)
    private enum Theme {
        static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00)
        static let textSecondary = Color.white.opacity(0.78)
        static let cardStroke    = Color.white.opacity(0.08)
        static let cardShadow    = Color.black.opacity(0.10)
        static let surfaceFrost  = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
        static let surfaceSolid  = Color(red: 0.05, green: 0.10, blue: 0.22)
        static let softRedBase   = Color(red: 1.00, green: 0.36, blue: 0.43)
        static let softRedLight  = Color(red: 1.00, green: 0.58, blue: 0.63)
        static let softGreenBase = Color(red: 0.27, green: 0.89, blue: 0.54)
        static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
    }

    // Service (configured with same parameters as parent)
    @State private var tokenService: PairingTokenService = {
        let cfg = PairingTokenService.Config(
            allowedClockSkew: 90,
            defaultValidity: 10 * 60,
            familyId: nil,
            devHMACSecret: Data("DEV_SECRET_CHANGE_ME_ROTATE_ME".utf8) // DEV ONLY
        )
        return PairingTokenService(config: cfg)
    }()

    // Camera / session coordinator
    @StateObject private var scanner = QRScannerCoordinator()

    // Error / state
    @State private var errorMessage: String? = nil
    @State private var isProcessingToken: Bool = false

    // DEBUG: image picker & paste token sheet
    #if DEBUG
    @State private var showPhotoPicker = false
    @State private var showPasteToken = false
    @State private var pastedTokenText: String = ""
    #endif

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true).ignoresSafeArea()

                VStack(spacing: 16) {
                    header
                    cameraCard
                    helpCard
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
            .onAppear {
                // Configure service family scoping if required
                tokenService = PairingTokenService(
                    config: PairingTokenService.Config(
                        allowedClockSkew: 90,
                        defaultValidity: 10 * 60,
                        familyId: familyId,
                        devHMACSecret: Data("DEV_SECRET_CHANGE_ME_ROTATE_ME".utf8) // DEV ONLY
                    )
                )
                scanner.start()
                scanner.onFound = { payload in
                    handleScannedPayload(payload)
                }
            }
            .onDisappear {
                scanner.stop()
            }
        }
        #if DEBUG
        // Paste token dialog for Simulator/testing
        .sheet(isPresented: $showPasteToken) {
            NavigationStack {
                ZStack(alignment: .top) {
                    CurvyAquaBlueBackground(animate: true).ignoresSafeArea()
                    VStack(spacing: 12) {
                        Text("Paste token (DEBUG)")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        TextField("Token string", text: $pastedTokenText, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .lineLimit(5, reservesSpace: true)

                        if let err = errorMessage {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(spacing: 10) {
                            pill(label: "Cancel", fg: .white, bg: Theme.softRedLight, stroke: Theme.softRedBase) {
                                showPasteToken = false
                            }
                            pill(label: "Verify", fg: Color.black.opacity(0.9), bg: Theme.softGreenLight, stroke: Theme.softGreenBase) {
                                verifyTokenString(pastedTokenText)
                            }
                        }
                        .padding(.top, 4)

                        Spacer()
                    }
                    .padding(16)
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        #endif
    }

    // MARK: - Subviews

    private var topBar: some View {
        ZStack {
            Text("Scan to pair")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            HStack {
                pill(label: "Close", fg: .white, bg: Theme.softRedLight, stroke: Theme.softRedBase) { onCancel() }
                Spacer(minLength: 12)
                #if DEBUG
                Menu {
                    Button {
                        showPasteToken = true
                    } label: {
                        Label("Paste token (DEBUG)", systemImage: "doc.on.clipboard")
                    }
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Import QR image (DEBUG)", systemImage: "photo")
                    }
                } label: {
                    Text("DEBUG")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.9))
                        .frame(width: 100, height: 32)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1))
                        .shadow(color: Theme.cardShadow, radius: 3)
                }
                .photosPicker(isPresented: $showPhotoPicker, selection: .constant(nil))
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color.clear)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Ask your parent to show the QR")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("Point your camera at the QR code. Once verified, this device will be paired.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var cameraCard: some View {
        VStack(spacing: 10) {
            ZStack {
                CameraView(session: scanner.session)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 1)

                // scanning reticle / hint
                VStack {
                    Spacer()
                    Text("Align the QR inside the frame")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 6)
            }
            .frame(height: 280)

            if let err = errorMessage {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            if isProcessingToken {
                ProgressView("Verifying…")
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
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

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trouble scanning?")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Text("Make sure the QR is clearly visible and in good light. If you still can’t scan, ask your parent to generate a new QR.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

            #if DEBUG
            Divider().overlay(Theme.cardStroke).padding(.vertical, 6)
            Text("Debug options (Simulator)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 10) {
                pill(label: "Paste token", fg: .white, bg: Theme.softRedLight, stroke: Theme.softRedBase) {
                    showPasteToken = true
                }
                pill(label: "Import QR image", fg: Color.black.opacity(0.9), bg: Color.white, stroke: Color.white.opacity(0.85)) {
                    showPhotoPicker = true
                }
            }
            .padding(.top, 2)
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

    // MARK: - Actions

    /// Handle a scanned payload string from the camera
    private func handleScannedPayload(_ payload: String) {
        // Avoid re-entrancy storms
        guard !isProcessingToken else { return }
        isProcessingToken = true
        errorMessage = nil

        verifyTokenString(payload)
    }

    /// Run full verification pipeline on a token string (used by camera, paste, and import)
    private func verifyTokenString(_ tokenString: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tok = try tokenService.verifyAll(
                    tokenString: tokenString,
                    expectedChildId: expectedChildId,
                    expectedEpoch: expectedPairingEpoch
                )
                DispatchQueue.main.async {
                    isProcessingToken = false
                    onVerified(tok)
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessingToken = false
                    errorMessage = error.localizedDescription
                    // resume scanning after brief delay to avoid rapid re-trigger
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        scanner.resumeScanning()
                    }
                }
            }
        }
    }

    // MARK: - UI helpers

    private func pill(label: String, fg: Color, bg: Color, stroke: Color, action: @escaping () -> Void) -> some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(fg)
            .frame(width: 120, height: 32)
            .background(Capsule().fill(bg))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
            .shadow(color: Theme.cardShadow, radius: 3)
            .contentShape(Capsule())
            .onTapGesture { action() }
    }
}

// MARK: - Camera layer

/// A simple AVCaptureSession wrapper that looks for QR codes and emits the raw payload string.
final class QRScannerCoordinator: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "QRScannerCoordinator.session")
    private let metadataOutput = AVCaptureMetadataOutput()
    private var isConfigured = false
    private var isRunning = false

    /// Called on the main thread whenever a QR payload is detected.
    var onFound: ((String) -> Void)?

    // control to debounce scans
    private var didEmitRecently = false

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isConfigured else {
                self.startRunning()
                return
            }
            configureSession()
            startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isRunning {
                self.session.stopRunning()
                self.isRunning = false
            }
        }
    }

    func resumeScanning() {
        // allow new emits
        didEmitRecently = false
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()
        isConfigured = true
    }

    private func startRunning() {
        guard !isRunning else { return }
        session.startRunning()
        isRunning = true
    }
}

extension QRScannerCoordinator: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didEmitRecently else { return }
        for obj in metadataObjects {
            guard let readable = obj as? AVMetadataMachineReadableCodeObject,
                  readable.type == .qr,
                  let stringValue = readable.stringValue,
                  !stringValue.isEmpty else { continue }

            didEmitRecently = true
            // brief debounce so multiple frames don’t trigger verify multiple times
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.didEmitRecently = false
            }
            self.onFound?(stringValue)
            break
        }
    }
}

// MARK: - SwiftUI CameraView

struct CameraView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) { }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

// MARK: - DEBUG: decode QR from static image (imported from Photos)

#if DEBUG
extension ChildPairingScannerSheet {
    /// Decode a QR from a still image using Vision; drive the same verification flow.
    func importQRImageAndVerify(_ image: UIImage) {
        guard let cg = image.cgImage else {
            self.errorMessage = "Could not read image."
            return
        }
        let request = VNDetectBarcodesRequest { req, _ in
            if let obs = req.results as? [VNBarcodeObservation],
               let first = obs.first(where: { $0.symbology == .QR }),
               let payload = first.payloadStringValue {
                self.verifyTokenString(payload)
            } else {
                self.errorMessage = "No QR found in image."
            }
        }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([request])
        } catch {
            self.errorMessage = "Failed to process image."
        }
    }
}
#endif
