//
// ParentChildrenTabView.swift
// parent_child_checklist
//
// Created by George Gauci on 10/2/2026.
//

import SwiftUI

struct ParentChildrenTabView: View {
  @AppStorage("userRole") private var userRoleRawValue: String?
  @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
  // 🔹 Optional: write last viewed child as soon as parent taps a child
  @AppStorage("lastParentChildId") private var lastParentChildIdRaw: String?

  @EnvironmentObject private var appState: AppState
  @State private var showAddChild = false
  @State private var childPendingDelete: ChildProfile?
  @State private var childPendingEdit: ChildProfile?

  var body: some View {
    NavigationStack {
      List {
        Section("Children") {
          ForEach(appState.children) { child in
            NavigationLink {
              ParentChildWeeklyView(childId: child.id)
                .environmentObject(appState)
            } label: {
              HStack(spacing: 12) {
                ChildAvatarCircleView(
                  colorHex: child.colorHex,
                  avatarId: child.avatarId,
                  size: 36
                )
                VStack(alignment: .leading, spacing: 2) {
                  Text(child.name)
                    .font(.headline)
                  Text(child.avatarId == nil
                       ? "Not chosen yet"
                       : AvatarCatalog.avatar(for: child.avatarId).displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 6)
            }
            // Eagerly capture the chosen child so Assign tabs default correctly
            .simultaneousGesture(TapGesture().onEnded {
              lastParentChildIdRaw = child.id.uuidString
            })
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button {
                childPendingDelete = child
              } label: {
                Label("Delete", systemImage: "trash")
              }
              .tint(.red)

              Button {
                childPendingEdit = child
              } label: {
                Label("Edit", systemImage: "pencil")
              }
              .tint(.blue)
            }
          }
        }

        Section {
          Button("Switch Role (Temporary)") {
            userRoleRawValue = nil
            selectedChildIdRaw = nil
          }
          .foregroundStyle(.red)
        }
      }
      // ── Title & + share the same line; we provide a custom, larger title
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        // Larger inline title (adjust size as you like; you mentioned 32 works well)
        ToolbarItem(placement: .principal) {
          Text("Parent")
            .font(.system(size: 32, weight: .bold, design: .default))
            .accessibilityAddTraits(.isHeader)
        }
        // Add (+) button on the right
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showAddChild = true
          } label: {
            Image(systemName: "plus")
              .font(.headline)
          }
          .accessibilityLabel("Add Child")
        }
      }
      .sheet(isPresented: $showAddChild) {
        AddChildView()
          .environmentObject(appState)
      }
      .sheet(item: $childPendingEdit) { child in
        EditChildView(child: child)
          .environmentObject(appState)
      }
      .alert(
        "Delete child?",
        isPresented: Binding(
          get: { childPendingDelete != nil },
          set: { if !$0 { childPendingDelete = nil } }
        )
      ) {
        Button("Delete", role: .destructive) {
          if let child = childPendingDelete {
            appState.deleteChild(id: child.id)
          }
          childPendingDelete = nil
        }
        Button("Cancel", role: .cancel) {
          childPendingDelete = nil
        }
      } message: {
        Text("This will remove the child and all their assignments and completion history.")
      }
    }
  }
}
