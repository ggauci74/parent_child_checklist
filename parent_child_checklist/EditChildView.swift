//
// EditChildView.swift
// parent_child_checklist
//

import SwiftUI

struct EditChildView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let child: ChildProfile

    @State private var name: String
    @State private var colorHex: String
    @State private var validationMessage: String?
    @FocusState private var nameFieldFocused: Bool

    // Kid-friendly preset palette
    private let swatchHexes: [String] = [
        "#4A7DFF", "#00A3FF", "#3CCB7F", "#22C55E", "#A3E635", "#FFB020",
        "#F97316", "#FF4D4D", "#F43F5E", "#FF6FAE", "#8B5CFF", "#2DD4BF",
        "#0EA5E9", "#64748B", "#111827", "#FFFFFF"
    ]

    private let colorGridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    init(child: ChildProfile) {
        self.child = child
        _name = State(initialValue: child.name)
        _colorHex = State(initialValue: child.colorHex)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isDuplicateName: Bool {
        !trimmedName.isEmpty && appState.isNameTaken(trimmedName, excluding: child.id)
    }

    private var hasChanges: Bool {
        trimmedName != child.name.trimmingCharacters(in: .whitespacesAndNewlines) ||
        colorHex != child.colorHex
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicateName && hasChanges
    }

    var body: some View {
        NavigationStack {
            Form {

                Section("Child") {
                    TextField("Name", text: $name)
                        .focused($nameFieldFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)

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
                            .accessibilityLabel("Colour swatch \(hex)")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Avatar") {
                    HStack(spacing: 12) {
                        ChildAvatarCircleView(
                            colorHex: colorHex,
                            avatarId: child.avatarId,
                            size: 44
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(child.avatarId == nil ? "Not chosen yet" : AvatarCatalog.avatar(for: child.avatarId).displayName)
                                .font(.headline)
                            Text("Your child controls this on their device.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Edit Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    nameFieldFocused = true
                }
            }
            .onChange(of: name) { _, _ in validationMessage = nil }
        }
    }

    private func save() {
        validationMessage = nil

        guard !trimmedName.isEmpty else {
            validationMessage = "Name cannot be empty."
            return
        }
        guard !isDuplicateName else {
            validationMessage = "That name already exists. Please choose a different name."
            return
        }

        // Update name + colour
        _ = appState.renameChild(id: child.id, newName: trimmedName)
        _ = appState.updateChildColor(childId: child.id, newColorHex: colorHex)

        dismiss()
    }
}
