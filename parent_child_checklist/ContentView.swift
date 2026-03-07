//
// ContentView.swift
// parent_child_checklist
//

import SwiftUI

// MARK: - Role Model
enum UserRole: String {
  case parent
  case child
}

// MARK: - Day-only utilities (ISO yyyy-MM-dd in @AppStorage)
// We persist just the day (no time). These helpers keep all logic consistent.
fileprivate extension Calendar {
  static var appCal: Calendar {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = .current
    return cal
  }
}
fileprivate func dayOnly(_ date: Date) -> Date {
  Calendar.appCal.startOfDay(for: date)
}
fileprivate func parseStoredDay(_ isoYYYYMMDD: String?) -> Date? {
  guard let s = isoYYYYMMDD, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
  let df = DateFormatter()
  df.calendar = Calendar.appCal
  df.locale = .current
  df.timeZone = .current
  df.dateFormat = "yyyy-MM-dd"
  return df.date(from: s).map { dayOnly($0) }
}
fileprivate func effectiveDefaultStartDate(from storedDayISO: String?) -> Date {
  let today = dayOnly(Date())
  guard let picked = parseStoredDay(storedDayISO) else { return today }
  // If the picked day is in the future or today, use it; if it's in the past, clamp to today.
  return max(today, picked)
}

// MARK: - App Root
struct ContentView: View {
  @AppStorage("userRole") private var userRoleRawValue: String?
  @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
  @EnvironmentObject private var appState: AppState

  var body: some View {
    Group {
      if let raw = userRoleRawValue, let role = UserRole(rawValue: raw) {
        switch role {
        case .parent:
          ParentHomeView()
        case .child:
          if let idString = selectedChildIdRaw, let uuid = UUID(uuidString: idString) {
            if let child = appState.children.first(where: { $0.id == uuid }) {
              let hasAvatar = !(child.avatarId ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              if hasAvatar {
                // Avatar already chosen -> show child tabs (Today is default)
                ChildRootTabView(childId: uuid)
              } else {
                // First-time only: avatar setup flow
                ChildAvatarSetupView(childId: uuid) { }
                  .environmentObject(appState)
              }
            } else {
              // If not yet loaded, still show tabs; guards inside handle state
              ChildRootTabView(childId: uuid)
            }
          } else {
            ChildChooseProfileView()
          }
        }
      } else {
        RoleSelectionView()
      }
    }
  }
}

// MARK: - Parent Home (Tabs: Children · Tasks · Events · Requests · Settings)
struct ParentHomeView: View {
  @EnvironmentObject private var appState: AppState
  // ✅ Share the selected parent tab across the app
  @AppStorage("parentSelectedTab") private var parentSelectedTab: String = "children"

  private var pendingBadge: Int { appState.pendingRewardRequestsCount }
  /// Title that includes the pending count when > 0, e.g. "Requests (3)"
  private var requestsTabTitle: String {
    pendingBadge > 0 ? "Requests (\(pendingBadge))" : "Requests"
  }

  var body: some View {
    TabView(selection: $parentSelectedTab) {
      // Children
      ParentChildrenTabView()
        .tabItem { Label("Children", systemImage: "person.2.fill") }
        .tag("children")

      // Tasks -> DIRECT host of AssignTaskToChildView
      ParentAssignTaskScreen()
        .tabItem { Label("Tasks", systemImage: "checklist") }
        .tag("tasks")

      // Events -> DIRECT host of AssignEventToChildView
      ParentAssignEventScreen()
        .tabItem { Label("Events", systemImage: "calendar") }
        .tag("events")

      // Requests
      ParentRewardsTabView()
        .tabItem { Label(requestsTabTitle, systemImage: "diamond.fill") }
        .tag("requests")

      // Settings
      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        .tag("settings")
    }
  }
}

// MARK: - Child resolution helper (shared by Task/Event tabs)
fileprivate func resolvePreferredChildId(
  children: [ChildProfile],
  lastParentChildIdRaw: String?,
  selectedChildIdRaw: String?
) -> UUID? {
  // 1) last child the parent viewed in weekly screen (ParentChildWeeklyView writes this)
  if let raw = lastParentChildIdRaw, let uuid = UUID(uuidString: raw),
     children.contains(where: { $0.id == uuid }) {
    return uuid
  }

  // 2) child-side selection (if you want to honor it on parent)
  if let raw = selectedChildIdRaw, let uuid = UUID(uuidString: raw),
     children.contains(where: { $0.id == uuid }) {
    return uuid
  }

  // 3) exactly one child
  if children.count == 1, let only = children.first {
    return only.id
  }

  // 4) otherwise default to the first (one-tap behavior as requested)
  return children.first?.id
}

// MARK: - Tasks tab: DIRECT AssignTaskToChildView (retain drafts across tab hops)
private struct ParentAssignTaskScreen: View {
  @EnvironmentObject private var appState: AppState
  @AppStorage("lastParentChildId") private var lastParentChildIdRaw: String?
  @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
  // ⬇️ Day persisted by the Parent weekly view (as "yyyy-MM-dd")
  @AppStorage("lastParentSelectedDay") private var lastParentSelectedDayISO: String?

  var body: some View {
    Group {
      if let cid = resolvePreferredChildId(
        children: appState.children,
        lastParentChildIdRaw: lastParentChildIdRaw,
        selectedChildIdRaw: selectedChildIdRaw
      ) {
        let effective = effectiveDefaultStartDate(from: lastParentSelectedDayISO)

        AssignTaskToChildView(
          childId: cid,
          defaultStartDate: effective,
          onShowWeeklyToast: { _ in }
        )
        // ⬇️ Force a fresh instance when the effective default day changes
        .id(effective)
        .environmentObject(appState)
        // ✅ No `.id(openToken)` and no refresh-on-appear: drafts persist until Cancel/Save,
        //    except when the day changes (intentional for this feature).
      } else {
        NoChildrenHintView(title: "Assign Task")
      }
    }
  }
}

// MARK: - Events tab: DIRECT AssignEventToChildView (already retains drafts)
private struct ParentAssignEventScreen: View {
  @EnvironmentObject private var appState: AppState
  @AppStorage("lastParentChildId") private var lastParentChildIdRaw: String?
  @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
  // ⬇️ Day persisted by the Parent weekly view (as "yyyy-MM-dd")
  @AppStorage("lastParentSelectedDay") private var lastParentSelectedDayISO: String?

  var body: some View {
    Group {
      if let cid = resolvePreferredChildId(
        children: appState.children,
        lastParentChildIdRaw: lastParentChildIdRaw,
        selectedChildIdRaw: selectedChildIdRaw
      ) {
        let effective = effectiveDefaultStartDate(from: lastParentSelectedDayISO)

        AssignEventToChildView(
          childId: cid,
          defaultStartDate: effective,
          onShowWeeklyToast: { _ in }
        )
        // ⬇️ Force a fresh instance when the effective default day changes
        .id(effective)
        .environmentObject(appState)
      } else {
        NoChildrenHintView(title: "Assign Event")
      }
    }
  }
}

// MARK: - Tiny empty-state for when there are no children
private struct NoChildrenHintView: View {
  let title: String
  var body: some View {
    NavigationStack {
      VStack(spacing: 12) {
        Image(systemName: "person.badge.plus")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(.secondary)
        Text("No children yet")
          .font(.headline)
        Text("Add a child in the Children tab, then return to \(title).")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .padding()
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

// MARK: - Role Selection (onboarding entry)
struct RoleSelectionView: View {
  @AppStorage("userRole") private var userRoleRawValue: String?

  var body: some View {
    NavigationStack {
      VStack(spacing: 18) {
        Spacer()
        Text("Welcome 👋")
          .font(.largeTitle)
          .fontWeight(.heavy)
        Text("Choose who you are to get started")
          .foregroundStyle(.secondary)

        VStack(spacing: 12) {
          Button {
            userRoleRawValue = UserRole.parent.rawValue
          } label: {
            HStack {
              Text("👨‍👩‍👧‍👦").font(.title2)
              Text("I'm a Parent").fontWeight(.semibold)
              Spacer()
              Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }

          Button {
            userRoleRawValue = UserRole.child.rawValue
          } label: {
            HStack {
              Text("🧒").font(.title2)
              Text("I'm a Child").fontWeight(.semibold)
              Spacer()
              Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
        .padding(.horizontal)

        Spacer()

        Text("Tip: parents create tasks and events, kids tick them off ✅")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.bottom, 20)
      }
      .padding()
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

// MARK: - Child Choose Profile (Step 1 for child role)
struct ChildChooseProfileView: View {
  @EnvironmentObject private var appState: AppState
  @AppStorage("userRole") private var userRoleRawValue: String?
  @AppStorage("selectedChildId") private var selectedChildIdRaw: String?

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Spacer(minLength: 10)
        Text("Who are you?")
          .font(.largeTitle)
          .fontWeight(.heavy)
        Text("Pick your name to see your tasks ✅")
          .foregroundStyle(.secondary)

        List(appState.children) { child in
          // Correct "has avatar" logic
          let hasAvatar = !(child.avatarId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
          if hasAvatar {
            // Child already has an avatar → jump straight into tabs
            Button {
              selectedChildIdRaw = child.id.uuidString
              // ContentView will re-render and present ChildRootTabView
            } label: {
              row(for: child)
            }
            .buttonStyle(.plain)
          } else {
            // First-time only → go to avatar setup flow
            NavigationLink {
              ChildAvatarSetupView(childId: child.id)
                .environmentObject(appState)
            } label: {
              row(for: child)
            }
          }
        }
        .listStyle(.insetGrouped)

        Spacer()

        Button("Back") {
          userRoleRawValue = nil
          selectedChildIdRaw = nil
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, 20)
      }
      .padding(.horizontal)
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  // MARK: - Row UI
  @ViewBuilder
  private func row(for child: ChildProfile) -> some View {
    HStack(spacing: 12) {
      ChildAvatarCircleView(colorHex: child.colorHex, avatarId: child.avatarId, size: 42)
      VStack(alignment: .leading, spacing: 2) {
        Text(child.name)
          .font(.title3)
          .fontWeight(.semibold)
        Text(child.avatarId == nil
             ? "Not chosen yet"
             : AvatarCatalog.avatar(for: child.avatarId).displayName)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
  }
}
