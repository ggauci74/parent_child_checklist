//
//  DeepAquaElectricBlueBackground.swift
//  parent_child_checklist
//
//  Created by George Gauci on 26/2/2026.
//


import SwiftUI

struct DeepAquaElectricBlueBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.00, green: 0.55, blue: 0.75),   // deep aqua
                Color(red: 0.00, green: 0.70, blue: 1.00),   // vivid aqua-blue
                Color(red: 0.00, green: 0.40, blue: 1.00)    // electric blue
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
