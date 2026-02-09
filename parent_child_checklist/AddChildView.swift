//
// AddChildView.swift
// parent_child_checklist
//
// Swatch-grid colour selection (no hex picker), pinned bottom button
//

import SwiftUI

struct AddChildView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var colorHex: String = "#4A7DFF"

    @State private var createdChild: ChildProfile?
    @State private var validationMessage: String?
    @FocusState private var nameFieldFocused: Bool

    // Kid-friendly preset palette (fast + consistent)
    private let swatchHexes: [String] = [
        "#4A7DFF", "#00A3FF", "#3CCB7F", "#22C55E", "#A3E635", "#FFB020",
        "#F97316", "#FF4D4D", "#F43F5E", "#FF6FAE", "#8B5CFF", "#2DD4BF",
        "#0EA5E9", "#64748B", "#111827", "#FFFFFF"
    ]

    // Layout
    private let colorGridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    // MARK: - Derived validation state
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateName: Bool {
        !trimmedName.isEmpty && appState.isNameTaken(trimmedName)
    }

    private var canCreate: Bool {
        createdChild == nil && !trimmedName.isEmpty && !isDuplicateName
    }

    var body: some View {
        NavigationStack {
            Form {

                Section("Child") {
                    TextField("Name", text: $name)
                        .focused($nameFieldFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                        .disabled(createdChild != nil)

                    if createdChild == nil {
                        if isDuplicateName {
                            Text("That name already exists. Please choose a different name.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else if let validationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Colour swatch picker (no hex-value dropdown)
                Section("Colour") {
                    HStack {
                        Text("Selected")
                        Spacer()
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: colorHex))
                            .frame(width: 36, height: 18)
                    }

                    Text("Tap a colour")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: colorGridColumns, spacing: 10) {
                        ForEach(swatchHexes, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle().strokeBorder(
                                            colorHex == hex ? Color.primary : Color.secondary.opacity(0.25),
                                            lineWidth: colorHex == hex ? 3 : 1
                                        )
                                    )
                                    .shadow(color: .black.opacity(hex == "#FFFFFF" ? 0.10 : 0.0), radius: 2)
                            }
                            .buttonStyle(.plain)
                            .disabled(createdChild != nil)
                            .accessibilityLabel("Colour swatch \(hex)")
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Avatar status is child-controlled
                Section("Avatar") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text("Not chosen yet")
                            .foregroundStyle(.secondary)
                    }

                    Text("Your child will choose their avatar on their device. It will appear here automatically once selected.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let createdChild {
                    Section("Created") {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(createdChild.name)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Colour")
                            Spacer()
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: createdChild.colorHex))
                                .frame(width: 36, height: 18)
                        }

                        HStack {
                            Text("Avatar")
                            Spacer()
                            Text("Not chosen yet")
                                .foregroundStyle(.secondary)
                        }

                        Text("On the child’s phone: choose “I’m a Child”, select their name, then choose an avatar.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Child")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    nameFieldFocused = true
                }
            }
            .onChange(of: name) { _, _ in
                validationMessage = nil
            }
            // pinned bottom button (no scrolling needed)
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
        }
    }

    // MARK: - Pinned Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            if createdChild == nil, let validationMessage {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                if createdChild == nil {
                    create()
                } else {
                    dismiss()
                }
            } label: {
                Text(createdChild == nil ? "Create Child" : "Done")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(createdChild == nil ? !canCreate : false)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    // MARK: - Create
    private func create() {
        validationMessage = nil

        guard !trimmedName.isEmpty else {
            validationMessage = "Please enter a name."
            return
        }
        guard !isDuplicateName else {
            validationMessage = "That name already exists. Please choose a different name."
            return
        }

        if let child = appState.createChild(name: trimmedName, colorHex: colorHex) {
            createdChild = child
            nameFieldFocused = false
        } else {
            validationMessage = "Couldn’t create child. Please check the details and try again."
        }
    }
}
