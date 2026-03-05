//
//  AuroraBluePurpleBackground.swift
//  parent_child_checklist
//
//  Created by George Gauci on 26/2/2026.
//


import SwiftUI

struct AuroraBluePurpleBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.12, blue: 0.30),   // deep navy
                Color(red: 0.12, green: 0.36, blue: 0.98),   // electric blue
                Color(red: 0.42, green: 0.29, blue: 1.00),   // indigo-violet
                Color(red: 0.62, green: 0.35, blue: 1.00),   // lighter violet
                Color(red: 0.93, green: 0.97, blue: 1.00)    // soft white highlight
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
