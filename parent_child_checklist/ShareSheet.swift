//
//  ShareSheet.swift
//  parent_child_checklist
//
//  Created by George Gauci on 10/2/2026.
//
import SwiftUI
import CloudKit

struct ShareSheet: UIViewControllerRepresentable {
    let sharingController: UICloudSharingController
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        return sharingController
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
        // no-op
    }
}
