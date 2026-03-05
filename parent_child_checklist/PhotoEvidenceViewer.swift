//
//  PhotoEvidenceViewer.swift
//  parent_child_checklist
//
//  Created by George Gauci on 24/2/2026.
//


//
// PhotoEvidenceViewer.swift
// parent_child_checklist
//
// Full‑screen viewer for a completion’s photo evidence.
// Shows a simple, reliable preview using the locally cached CKAsset file URL.
// If the URL is not yet available but the record indicates a photo exists,
// we show a friendly “downloading” message so the parent can retry shortly.
//

import SwiftUI
import UIKit

struct PhotoEvidenceViewer: View, Identifiable {
    // Use completion id for .sheet(item:) presentation
    var id: UUID { completion.id }

    let completion: TaskCompletionRecord
    /// Optional, purely for a nice inline title (e.g., task name).
    let taskTitle: String

    @Environment(\.dismiss) private var dismiss
    @State private var uiImage: UIImage? = nil
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                Group {
                    if let image = uiImage {
                        GeometryReader { geo in
                            // Simple, performant full-screen preview
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                    } else if let err = loadError {
                        // Friendly, readable message for the parent
                        Text(err)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding()
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .padding()
            }
            .navigationTitle(taskTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { loadImageIfAvailable() }
        }
    }

    // MARK: - Loader
    private func loadImageIfAvailable() {
        // If CloudKit has already cached the asset, the local file URL will be present.
        // Otherwise, CloudKit will fetch it on-demand soon and AppState/mapper will yield a URL later.
        guard let url = completion.photoEvidenceLocalURL else {
            if completion.hasPhotoEvidence {
                loadError = "Photo is downloading from iCloud… try again in a moment."
            } else {
                loadError = "No photo attached to this completion."
            }
            return
        }

        do {
            let data = try Data(contentsOf: url)
            if let img = UIImage(data: data) {
                uiImage = img
            } else {
                loadError = "Couldn’t read image data."
            }
        } catch {
            loadError = "Couldn’t load image file."
        }
    }
}