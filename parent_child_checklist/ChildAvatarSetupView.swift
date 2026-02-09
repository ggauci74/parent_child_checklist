//
// ChildAvatarSetupView.swift
// parent_child_checklist
//
// Child chooses an avatar (preset). Avatar is unique across children.
//

import SwiftUI

struct ChildAvatarSetupView: View {
    let childId: UUID

    @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAvatarId: String? = nil
    @State private var errorMessage: String? = nil

    private var child: ChildProfile? {
        appState.children.first { $0.id == childId }
    }

    /// Avatars currently used by other children in the family.
    private var takenAvatarIds: Set<String> {
        let current = child?.avatarId
        let allTaken = appState.children.compactMap { $0.avatarId }
        return Set(allTaken.filter { $0 != current })
    }

    private var canContinue: Bool {
        selectedAvatarId != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let child {
                    Text("Hello, \(child.name)!")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .padding(.top, 16)

                    Text("Choose your avatar ✅")
                        .foregroundStyle(.secondary)

                    Text("Each avatar can only be used by one child at a time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ScrollView {
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(AvatarCatalog.all) { avatar in
                                let isTaken = takenAvatarIds.contains(avatar.id)
                                let isSelected = selectedAvatarId == avatar.id

                                Button {
                                    if isTaken { return }
                                    selectedAvatarId = avatar.id
                                    errorMessage = nil
                                } label: {
                                    VStack(spacing: 8) {
                                        ChildAvatarCircleView(
                                            colorHex: child.colorHex,
                                            avatarId: avatar.id,
                                            size: 64
                                        )

                                        Text(avatar.displayName)
                                            .font(.footnote)
                                            .foregroundStyle(isTaken ? .secondary : .primary)
                                            .lineLimit(1)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(isSelected ? Color.blue.opacity(0.14) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                isSelected ? Color.blue : Color.secondary.opacity(0.20),
                                                lineWidth: isSelected ? 2 : 1
                                            )
                                    )
                                    .opacity(isTaken ? 0.45 : 1.0)
                                }
                                .buttonStyle(.plain)
                                .disabled(isTaken)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    Button {
                        continueTapped()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .disabled(!canContinue)

                    Spacer()
                } else {
                    Text("That child profile can’t be found.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Avatar")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            selectedAvatarId = child?.avatarId
        }
    }

    private func continueTapped() {
        guard let child else { return }
        guard let selectedAvatarId else { return }

        // Data-layer validation (handles race conditions)
        let ok = appState.updateChildAvatar(childId: child.id, newAvatarId: selectedAvatarId)
        if ok {
            selectedChildIdRaw = child.id.uuidString
            dismiss()
        } else {
            errorMessage = "That avatar was just taken. Please choose another."
        }
    }
}
