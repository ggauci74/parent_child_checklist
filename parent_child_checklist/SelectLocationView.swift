//
// SelectLocationView.swift
// parent_child_checklist
//

import SwiftUI

struct SelectLocationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedLocationId: UUID?
    @Binding var selectedLocationNameSnapshot: String

    @State private var searchText: String = ""

    // Add
    @State private var showAddPrompt = false
    @State private var newLocationName: String = ""

    // Rename
    @State private var renameTarget: LocationItem? = nil
    @State private var renameText: String = ""

    private var filteredLocations: [LocationItem] {
        let sorted = appState.locations.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            Button {
                selectedLocationId = nil
                selectedLocationNameSnapshot = ""
                dismiss()
            } label: {
                HStack {
                    Text("None")
                    Spacer()
                    if selectedLocationId == nil && selectedLocationNameSnapshot.trimmed.isEmpty {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Section("Locations") {
                if filteredLocations.isEmpty {
                    Text("No locations yet. Tap + to add one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredLocations) { loc in
                        Button {
                            selectedLocationId = loc.id
                            selectedLocationNameSnapshot = loc.name
                            dismiss()
                        } label: {
                            HStack {
                                Text(loc.name)
                                    .font(.headline)
                                Spacer()
                                if selectedLocationId == loc.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                renameTarget = loc
                                renameText = loc.name
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                appState.deleteLocation(id: loc.id)
                                if selectedLocationId == loc.id {
                                    selectedLocationId = nil
                                    // keep snapshot text as-is (historical)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Location")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newLocationName = ""
                    showAddPrompt = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Add Location", isPresented: $showAddPrompt) {
            TextField("Location name", text: $newLocationName)
            Button("Add") { addLocation() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a new location.")
        }
        .alert("Rename Location", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Location name", text: $renameText)
            Button("Save") { renameLocation() }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        } message: {
            Text("Renaming will update all event assignments using this location.")
        }
    }

    private func addLocation() {
        let t = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if let loc = appState.createLocation(name: t) {
            selectedLocationId = loc.id
            selectedLocationNameSnapshot = loc.name
            dismiss()
        }
    }

    private func renameLocation() {
        guard let target = renameTarget else { return }
        let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        let ok = appState.renameLocation(id: target.id, newName: t)
        if ok, selectedLocationId == target.id {
            selectedLocationNameSnapshot = t
        }
        renameTarget = nil
    }
}
