//
// ParentChildWeeklyView.swift
// parent_child_checklist
//

import SwiftUI
import UIKit

// MARK: - Local theme tokens (match child screens)
private enum FuturistTheme {
  static let skyTop = Color(red: 0.02, green: 0.06, blue: 0.16)
  static let skyBottom = Color(red: 0.01, green: 0.03, blue: 0.10)
  static let neonAqua = Color(red: 0.20, green: 0.95, blue: 1.00)
  // Text
  static let textPrimary = Color(red: 0.92, green: 0.97, blue: 1.00)
  static let textSecondary = Color.white.opacity(0.78)
  // Accents (radios)
  static let magenta = Color(hue: 0.83, saturation: 0.85, brightness: 0.95) // unchecked ring
  static let green = Color(hue: 0.33, saturation: 0.78, brightness: 0.92)   // checked ring
}

// MARK: - Reusable card background (glass + thin stroke)
private struct CardBackground: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  private let surface = Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
  private let surfaceSolid = Color(red: 0.05, green: 0.10, blue: 0.22)
  var cornerRadius: CGFloat = 12

  var body: some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .fill(reduceTransparency ? surfaceSolid : surface)
      .overlay(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .stroke(Color.white.opacity(0.07), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.10), radius: 6, x: 0, y: 2)
  }
}

// MARK: - Subtle lower sweep behind content (like child)
private struct LowerContentSweep: View {
  var body: some View {
    LinearGradient(
      gradient: Gradient(stops: [
        .init(color: .clear, location: 0.00),
        .init(color: FuturistTheme.skyTop.opacity(0.05), location: 0.50),
        .init(color: FuturistTheme.skyTop.opacity(0.08), location: 1.00)
      ]),
      startPoint: .top,
      endPoint: .bottom
    )
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

// MARK: - Neon divider (dark → neon → dark)
private struct TaskRowGradientRule: View {
  var leadingInset: CGFloat
  var trailingInset: CGFloat
  var thickness: CGFloat = 2

  var body: some View {
    LinearGradient(
      gradient: Gradient(stops: [
        .init(color: FuturistTheme.skyTop.opacity(0.95), location: 0.00),
        .init(color: FuturistTheme.neonAqua, location: 0.50),
        .init(color: FuturistTheme.skyTop.opacity(0.95), location: 1.00),
      ]),
      startPoint: .leading,
      endPoint: .trailing
    )
    .frame(height: thickness)
    .clipShape(Capsule())
    .frame(maxWidth: .infinity, alignment: .leading)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

// MARK: - Header child-switch arrows
private struct ChildSwitchArrow: View {
  let systemName: String
  let action: () -> Void

  var body: some View {
    Button(action: { action() }) {
      Image(systemName: systemName)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(FuturistTheme.textPrimary)
        .frame(width: 36, height: 36)
        .background(Color.white.opacity(0.08))
        .clipShape(Circle())
        .overlay(
          Circle().stroke(FuturistTheme.textPrimary.opacity(0.20), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .contentShape(Circle())
  }
}

struct ParentChildWeeklyView: View {
  let childId: UUID

  @EnvironmentObject private var appState: AppState

  // 🔹 Persist the last parent-viewed child for Assign screens AND for scanning arrows
  @AppStorage("lastParentChildId") private var lastParentChildIdRaw: String?

  // 🔹 Persist the parent’s last selected day ("yyyy-MM-dd")
  @AppStorage("lastParentSelectedDay") private var lastParentSelectedDayISO: String?

  // Selected day
  @State private var selectedDate: Date = Date()

  // One-time init gate so we don't overwrite user's selection on reappear
  @State private var didInitializeSelectedDate = false

  // 🔹 Active child for this screen (initialized from `childId` / lastParentChildIdRaw)
  @State private var activeChildId: UUID

  // Sheets (Assign entry points)
  @State private var showAssignTaskSheet = false
  @State private var showAssignEventSheet = false

  // Edit sheets
  @State private var assignmentToEdit: TaskAssignment? = nil
  @State private var eventToEdit: EventAssignment? = nil

  // Toast
  @State private var toastMessage: String? = nil

  // Photo viewer sheet
  @State private var completionToPreview: TaskCompletionRecord? = nil
  @State private var viewerTaskTitle: String = ""

  // MARK: - Init
  init(childId: UUID) {
    self.childId = childId
    _activeChildId = State(initialValue: childId)
  }

  // MARK: - Tunables to match child screens
  private static let ruleLeadingInset: CGFloat = 16
  private static let ruleTrailingInset: CGFloat = 14
  private static let ruleExtraBottomPadding: CGFloat = 6
  private static let ruleVerticalOffset: CGFloat = 6 // same as child Requests
  private static let headerTopPadding: CGFloat = 6
  private static let headerBottomPadding: CGFloat = 4

  /// Align the arrows with the **name** line inside `ChildHeaderView`.
  /// Positive = push arrows DOWN; tweak by a point or two if your header font changes.
  private let arrowNameBaselineOffset: CGFloat = 10

  // Monday-first calendar
  private var isoCalendar: Calendar {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = .current
    return cal
  }

  // ISO day-only formatter used for persistence
  private static let isoDayFormatter: DateFormatter = {
    let df = DateFormatter()
    var c = Calendar(identifier: .iso8601)
    c.timeZone = .current
    df.calendar = c
    df.locale = .current
    df.timeZone = .current
    df.dateFormat = "yyyy-MM-dd"
    return df
  }()

  // Resolve child by activeChildId
  private var child: ChildProfile? {
    appState.children.first { $0.id == activeChildId }
  }

  // Sorted order for scanning (A→Z by name)
  private var childrenSorted: [ChildProfile] {
    appState.children.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }
  private var hasMultipleChildren: Bool { childrenSorted.count > 1 }
  private var currentChildIndex: Int? {
    childrenSorted.firstIndex(where: { $0.id == activeChildId })
  }

  // Scan actions with wrap-around + haptic + persistence
  private func goPrevChild() {
    guard hasMultipleChildren, let idx = currentChildIndex else { return }
    let newIdx = (idx - 1 + childrenSorted.count) % childrenSorted.count
    let newId = childrenSorted[newIdx].id
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
      activeChildId = newId
    }
    lastParentChildIdRaw = newId.uuidString
  }

  private func goNextChild() {
    guard hasMultipleChildren, let idx = currentChildIndex else { return }
    let newIdx = (idx + 1) % childrenSorted.count
    let newId = childrenSorted[newIdx].id
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
      activeChildId = newId
    }
    lastParentChildIdRaw = newId.uuidString
  }

  private var today: Date { Date() }

  // MARK: - Header texts
  private var headerSelectedDayText: String {
    let df = DateFormatter()
    df.calendar = isoCalendar
    df.locale = .current
    df.dateFormat = "EEEE"
    return df.string(from: selectedDate)
  }

  private var headerSelectedDateText: String {
    let df = DateFormatter()
    df.calendar = isoCalendar
    df.locale = .current
    df.dateStyle = .long
    return df.string(from: selectedDate)
  }

  private var pointsText: String {
    String(appState.childPointsTotal(childId: activeChildId))
  }

  // MARK: - Data helpers (now bound to activeChildId)
  private var tasksForSelectedDay: [TaskAssignment] {
    appState.assignments(for: activeChildId, on: selectedDate)
  }

  private var eventsForSelectedDay: [EventAssignment] {
    appState.events(for: activeChildId, on: selectedDate)
  }

  private var eventIdsForSelectedDay: Set<UUID> { Set(eventsForSelectedDay.map(\.id)) }

  private var linkedTasksForSelectedDay: [TaskAssignment] {
    tasksForSelectedDay.filter { $0.linkedEventAssignmentId.flatMap(eventIdsForSelectedDay.contains) ?? false }
  }

  private var unlinkedTasksForSelectedDay: [TaskAssignment] {
    tasksForSelectedDay.filter { assignment in
      guard let evId = assignment.linkedEventAssignmentId else { return true }
      return !eventIdsForSelectedDay.contains(evId)
    }
  }

  private func effectiveTime(for task: TaskAssignment) -> Date? { task.startTime ?? task.finishTime }
  private func effectiveTime(for event: EventAssignment) -> Date? { event.startTime ?? event.finishTime }

  private func timeOfDayKey(_ time: Date?) -> Int? {
    guard let time else { return nil }
    let comps = isoCalendar.dateComponents([.hour, .minute], from: time)
    return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
  }

  private func taskTimeKey(_ task: TaskAssignment) -> Int? { timeOfDayKey(effectiveTime(for: task)) }
  private func eventTimeKey(_ event: EventAssignment) -> Int? { timeOfDayKey(effectiveTime(for: event)) }

  private var eventsSortedForDisplay: [EventAssignment] {
    eventsForSelectedDay.sorted { a, b in
      if a.isActive != b.isActive { return a.isActive && !b.isActive }
      let ta = eventTimeKey(a); let tb = eventTimeKey(b)
      switch (ta, tb) {
      case (nil, nil): break
      case (nil, _?): return false
      case (_?, nil): return true
      case (let x?, let y?): if x != y { return x < y }
      }
      return a.eventTitle.localizedCaseInsensitiveCompare(b.eventTitle) == .orderedAscending
    }
  }

  private func linkedTasks(for eventId: UUID) -> [TaskAssignment] {
    linkedTasksForSelectedDay
      .filter { $0.linkedEventAssignmentId == eventId }
      .sorted { a, b in
        if a.isActive != b.isActive { return a.isActive && !b.isActive }
        let ta = taskTimeKey(a); let tb = taskTimeKey(b)
        switch (ta, tb) {
        case (nil, nil): break
        case (nil, _?): return false
        case (_?, nil): return true
        case (let x?, let y?): if x != y { return x < y }
        }
        return a.taskTitle.localizedCaseInsensitiveCompare(b.taskTitle) == .orderedAscending
      }
  }

  private var unlinkedTasksSortedForDisplay: [TaskAssignment] {
    unlinkedTasksForSelectedDay.sorted { a, b in
      if a.isActive != b.isActive { return a.isActive && !b.isActive }
      let ta = taskTimeKey(a); let tb = taskTimeKey(b)
      switch (ta, tb) {
      case (nil, nil): break
      case (nil, _?): return false
      case (_?, nil): return true
      case (let x?, let y?): if x != y { return x < y }
      }
      return a.taskTitle.localizedCaseInsensitiveCompare(b.taskTitle) == .orderedAscending
    }
  }

  private enum AgendaSection: Hashable { case tasks, events }

  // ✅ Fixed order: Tasks always first, then Events
  private var agendaSectionOrder: [AgendaSection] { [.tasks, .events] }

  // ✅ Fixed header: always "Tasks"
  private var standaloneTasksSectionTitle: String { "Tasks" }

  // MARK: - Toast helper
  private func showToast(_ message: String) {
    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
      toastMessage = message
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      withAnimation(.easeOut(duration: 0.2)) {
        toastMessage = nil
      }
    }
  }

  // MARK: - Persist last selected day (ISO yyyy-MM-dd)
  private func persistLastSelectedDay(_ date: Date) {
    let day = isoCalendar.startOfDay(for: date)
    lastParentSelectedDayISO = Self.isoDayFormatter.string(from: day)
  }

  // MARK: - Body
  var body: some View {
    NavigationStack {
      ZStack(alignment: .top) {
        CurvyAquaBlueBackground(animate: true)

        VStack(spacing: 0) {
          headerCluster
            .padding(.horizontal)

          ZStack {
            LowerContentSweep()

            VStack(spacing: 6) { // tighter rhythm under the header
              dayStripPager
              agendaArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal)
          }
        }

        // Sheets
        .sheet(isPresented: $showAssignTaskSheet) {
          // Clamp selected day to today if in the past
          let defaultStartDate = max(isoCalendar.startOfDay(for: selectedDate),
                                     isoCalendar.startOfDay(for: today))
          AssignTaskToChildView(
            childId: activeChildId,
            defaultStartDate: defaultStartDate,
            onShowWeeklyToast: { showToast($0) }
          )
          .environmentObject(appState)
        }
        .sheet(isPresented: $showAssignEventSheet) {
          let defaultStartDate = max(isoCalendar.startOfDay(for: selectedDate),
                                     isoCalendar.startOfDay(for: today))
          AssignEventToChildView(
            childId: activeChildId,
            defaultStartDate: defaultStartDate,
            onShowWeeklyToast: { showToast($0) }
          )
          .environmentObject(appState)
        }
        .sheet(item: $assignmentToEdit) { assignment in
          EditTaskAssignmentView(assignment: assignment).environmentObject(appState)
        }
        .sheet(item: $eventToEdit) { event in
          EditEventAssignmentView(assignment: event).environmentObject(appState)
        }
        .sheet(item: $completionToPreview) { comp in
          PhotoEvidenceViewer(completion: comp, taskTitle: viewerTaskTitle)
        }

        if let toastMessage {
          ToastBannerView(message: toastMessage)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(10)
        }
      }
      .onAppear {
        // Initialize active child from stored value (if present/valid), else use inbound childId
        if let raw = lastParentChildIdRaw, let stored = UUID(uuidString: raw),
           appState.children.contains(where: { $0.id == stored }) {
          activeChildId = stored
        } else {
          activeChildId = childId
          lastParentChildIdRaw = childId.uuidString
        }

        // ✅ Initialize the selectedDate once:
        guard !didInitializeSelectedDate else { return }
        if let iso = lastParentSelectedDayISO,
           let stored = Self.isoDayFormatter.date(from: iso) {
          selectedDate = isoCalendar.startOfDay(for: stored)
        } else {
          selectedDate = isoCalendar.startOfDay(for: today)
        }
        didInitializeSelectedDate = true

        // Write it out (keeps storage in sync if it was missing).
        persistLastSelectedDay(selectedDate)
      }
      // 🔹 Persist whenever the parent changes the day (via strip or "Today")
      .onChange(of: selectedDate) { _, newValue in
        persistLastSelectedDay(newValue)
      }
      .navigationTitle("")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarHidden(true)
    }
  }

  // MARK: - Header cluster
  private var headerCluster: some View {
    VStack(spacing: 6) {
      if let child {
        // Keep ChildHeaderView unchanged so gems remain where they were.
        // Add arrows as a BOTTOM-ALIGNED overlay so they line up with the child's name,
        // not with the gems row. Tweak `arrowNameBaselineOffset` if your name font changes.
        ChildHeaderView(
          child: child,
          points: appState.childPointsTotal(childId: activeChildId)
        )
        .overlay(alignment: .bottom) {
          if hasMultipleChildren {
            HStack {
              ChildSwitchArrow(systemName: "chevron.left", action: goPrevChild)
                .accessibilityLabel("Previous child")
              Spacer()
              ChildSwitchArrow(systemName: "chevron.right", action: goNextChild)
                .accessibilityLabel("Next child")
            }
            // Pull the arrows *down* to the name baseline (positive pushes down)
            .padding(.horizontal, 4)
            .offset(y: arrowNameBaselineOffset)
          }
        }
      }

      Text(headerSelectedDayText)
        .font(.system(size: 36, weight: .regular))
        .foregroundStyle(FuturistTheme.textPrimary)
        .padding(.top, 2)

      HStack(spacing: 8) {
        Text(headerSelectedDateText)
          .font(.subheadline)
          .foregroundStyle(FuturistTheme.textSecondary)

        Spacer(minLength: 8)

        Button("Today") { jumpToToday() }
          .font(.footnote.weight(.semibold))
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .foregroundStyle(Color.white)
          .background(Color.white.opacity(0.25), in: Capsule())
          .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
          .accessibilityLabel("Jump to today")
      }
    }
  }

  // MARK: - Sliding calendar strip
  private var dayStripPager: some View {
    ScrollableDayStrip(
      selectedDate: $selectedDate,
      calendar: isoCalendar
    )
    .tint(Color(red: 0.88, green: 0.96, blue: 1.00)) // brighter weekday names
    .brightness(0.14)
    .contrast(1.24)
    .saturation(1.12)
    .frame(height: 70)
    .padding(.bottom, -10)
  }

  // MARK: - Agenda area (List modifiers attached to the LIST, not outer view)
  private var agendaArea: some View {
    VStack(alignment: .leading, spacing: 0) {
      if tasksForSelectedDay.isEmpty && eventsForSelectedDay.isEmpty {
        VStack(spacing: 8) {
          Spacer(minLength: 16)
          Text("No tasks or events assigned for this day.")
            .foregroundStyle(FuturistTheme.textSecondary)
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          ForEach(agendaSectionOrder, id: \.self) { section in
            switch section {
            case .tasks:
              if !unlinkedTasksSortedForDisplay.isEmpty {
                Section {
                  let items = unlinkedTasksSortedForDisplay
                  ForEach(Array(items.enumerated()), id: \.element.id) { index, assignment in
                    let completion = appState.completionRecord(for: assignment.id, on: selectedDate)

                    VStack(spacing: 0) {
                      TaskAssignmentRow(
                        assignment: assignment,
                        selectedDate: selectedDate,
                        isCompleted: completion != nil,
                        completionForSelectedDay: completion,
                        onToggleComplete: {
                          appState.toggleCompletion(assignmentId: assignment.id, on: selectedDate)
                        },
                        onTap: { assignmentToEdit = assignment },
                        onViewPhoto: {
                          guard let comp = completion, comp.hasPhotoEvidence else { return }
                          viewerTaskTitle = assignment.taskTitle
                          completionToPreview = comp
                        },
                        headlineColor: FuturistTheme.textPrimary,
                        metaColor: FuturistTheme.textSecondary
                      )
                    }
                    .padding(.bottom, Self.ruleExtraBottomPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(CardBackground())
                    .overlay(alignment: .bottomLeading) {
                      if index < items.count - 1 {
                        TaskRowGradientRule(
                          leadingInset: Self.ruleLeadingInset,
                          trailingInset: Self.ruleTrailingInset,
                          thickness: 2
                        )
                        .offset(y: Self.ruleVerticalOffset)
                      }
                    }
                  }
                  .onDelete { indexSet in
                    for idx in indexSet {
                      let a = unlinkedTasksSortedForDisplay[idx]
                      appState.deleteTaskAssignment(id: a.id)
                    }
                  }
                } header: {
                  Text(standaloneTasksSectionTitle)
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .textCase(nil)
                    .padding(.top, Self.headerTopPadding)
                    .padding(.bottom, Self.headerBottomPadding)
                }
              }

            case .events:
              if !eventsSortedForDisplay.isEmpty {
                Section {
                  let items = eventsSortedForDisplay
                  ForEach(Array(items.enumerated()), id: \.element.id) { index, event in
                    VStack(spacing: 0) {
                      EventAssignmentRow(
                        event: event,
                        onTap: { eventToEdit = event },
                        headlineColor: FuturistTheme.textPrimary,
                        metaColor: FuturistTheme.textSecondary
                      )
                    }
                    .padding(.bottom, Self.ruleExtraBottomPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(CardBackground())
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                      Button(role: .destructive) {
                        appState.deleteEventAssignment(id: event.id)
                      } label: {
                        Label("Delete", systemImage: "trash")
                      }
                    }
                    .overlay(alignment: .bottomLeading) {
                      if index < items.count - 1 {
                        TaskRowGradientRule(
                          leadingInset: Self.ruleLeadingInset,
                          trailingInset: Self.ruleTrailingInset,
                          thickness: 2
                        )
                        .offset(y: Self.ruleVerticalOffset)
                      }
                    }

                    // Linked tasks under event
                    let tasks = linkedTasks(for: event.id)
                    if !tasks.isEmpty {
                      ForEach(tasks) { assignment in
                        let completion = appState.completionRecord(for: assignment.id, on: selectedDate)

                        VStack(spacing: 0) {
                          TaskAssignmentRow(
                            assignment: assignment,
                            selectedDate: selectedDate,
                            isCompleted: completion != nil,
                            completionForSelectedDay: completion,
                            onToggleComplete: {
                              appState.toggleCompletion(assignmentId: assignment.id, on: selectedDate)
                            },
                            onTap: { assignmentToEdit = assignment },
                            onViewPhoto: {
                              guard let comp = completion, comp.hasPhotoEvidence else { return }
                              viewerTaskTitle = assignment.taskTitle
                              completionToPreview = comp
                            },
                            headlineColor: FuturistTheme.textPrimary,
                            metaColor: FuturistTheme.textSecondary
                          )
                        }
                        .padding(.leading, 18)
                        .padding(.bottom, Self.ruleExtraBottomPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(CardBackground())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                          Button(role: .destructive) {
                            appState.deleteTaskAssignment(id: assignment.id)
                          } label: {
                            Label("Delete", systemImage: "trash")
                          }
                        }
                      }
                    }
                  }
                } header: {
                  Text("Events")
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .textCase(nil)
                    .padding(.top, Self.headerTopPadding)
                    .padding(.bottom, Self.headerBottomPadding)
                }
              }
            }
          }
        }
        // ✅ Attach list-specific modifiers here (not on the outer view)
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListHeaderHeight, 0)
      }
    }
  }

  private func jumpToToday() {
    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
      selectedDate = isoCalendar.startOfDay(for: today)
    }
    // (onChange of selectedDate will persist)
  }
}

// MARK: - Task row (PARENT) — radios match child: magenta ring / green + dark fill + white check
private struct TaskAssignmentRow: View {
  let assignment: TaskAssignment
  let selectedDate: Date
  let isCompleted: Bool
  let completionForSelectedDay: TaskCompletionRecord?
  let onToggleComplete: () -> Void
  let onTap: () -> Void
  let onViewPhoto: (() -> Void)?
  var headlineColor: Color = FuturistTheme.textPrimary
  var metaColor: Color = FuturistTheme.textSecondary

  private var dimmed: Bool { !assignment.isActive }

  private var inactiveBadge: some View {
    Text("Inactive")
      .font(.caption2).fontWeight(.semibold)
      .padding(.horizontal, 8).padding(.vertical, 4)
      .foregroundStyle(metaColor)
      .background(Color.white.opacity(0.10), in: Capsule())
      .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
  }

  // Custom radio: matches the child-side visuals
  private var radio: some View {
    let checked = isCompleted
    return ZStack {
      Circle()
        .stroke(FuturistTheme.magenta, lineWidth: 2.5) // outer ring (unchecked colour)
      if checked {
        Circle()
          .fill(Color.black.opacity(0.60)) // dark inner when checked
          .overlay(
            Image(systemName: "checkmark")
              .font(.system(size: 11, weight: .heavy))
              .foregroundStyle(.white)
          )
          .overlay(
            Circle().stroke(FuturistTheme.green, lineWidth: 2.5) // green ring when checked
          )
      }
    }
    .frame(width: 24, height: 24)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 12) {
        // Radio
        Button(action: onToggleComplete) {
          radio
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(isCompleted ? "Mark as not done" : "Mark as done")

        VStack(alignment: .leading, spacing: 4) {
          // Title row
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            TaskEmojiIconView(icon: assignment.taskIcon, size: 20)
            Text(assignment.taskTitle)
              .font(.headline)
              .foregroundStyle(dimmed ? metaColor.opacity(0.7) : headlineColor)
            if dimmed { inactiveBadge }
          }

          // Meta line (points + time)
          HStack(spacing: 8) {
            if assignment.rewardPoints > 0 {
              HStack(spacing: 3) {
                Text("💎")
                Text("\(assignment.rewardPoints)")
                  .fontWeight(.semibold)
              }
              .foregroundStyle(metaColor)
            }

            if let st = assignment.startTime {
              Text(formatTime(st))
                .foregroundStyle(metaColor)
            } else if let ft = assignment.finishTime {
              Text(formatTime(ft))
                .foregroundStyle(metaColor)
            }
          }
          .font(.footnote)

          // Helper
          if let helper = assignment.helper, !helper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(helper)
              .font(.footnote)
              .foregroundStyle(metaColor)
          }

          // Photo evidence chip
          if completionForSelectedDay?.hasPhotoEvidence == true {
            Button(action: { onViewPhoto?() }) {
              HStack(spacing: 6) {
                Image(systemName: "photo.fill.on.rectangle.fill")
                Text("View Photo")
                  .fontWeight(.semibold)
              }
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 5)
              .background(Color.white.opacity(0.10), in: Capsule())
              .overlay(Capsule().stroke(Color.white.opacity(0.20)))
            }
            .buttonStyle(.plain)
          }
        }

        Spacer(minLength: 8)

        // Edit chevron
        Image(systemName: "chevron.right")
          .foregroundStyle(FuturistTheme.textSecondary)
          .onTapGesture { onTap() }
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
  }

  private func formatTime(_ date: Date) -> String {
    let df = DateFormatter()
    df.dateStyle = .none
    df.timeStyle = .short
    return df.string(from: date)
  }
}

// MARK: - Event row (PARENT)
private struct EventAssignmentRow: View {
  let event: EventAssignment
  let onTap: () -> Void
  var headlineColor: Color = FuturistTheme.textPrimary
  var metaColor: Color = FuturistTheme.textSecondary

  private var dimmed: Bool { !event.isActive }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      TaskEmojiIconView(icon: event.eventIcon, size: 20)
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(event.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Event" : event.eventTitle)
            .font(.headline)
            .foregroundStyle(dimmed ? metaColor.opacity(0.7) : headlineColor)
          if dimmed {
            Text("Inactive")
              .font(.caption2).fontWeight(.semibold)
              .padding(.horizontal, 8).padding(.vertical, 4)
              .foregroundStyle(metaColor)
              .background(Color.white.opacity(0.10), in: Capsule())
              .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
          }
        }

        HStack(spacing: 8) {
          Text(dateLine())
            .foregroundStyle(metaColor)

          if let st = event.startTime {
            Text(timeLine(st))
              .foregroundStyle(metaColor)
          } else if let ft = event.finishTime {
            Text(timeLine(ft))
              .foregroundStyle(metaColor)
          }

          let loc = event.locationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
          if !loc.isEmpty {
            Text("📍 \(loc)")
              .foregroundStyle(metaColor)
          }
        }
        .font(.footnote)
      }

      Spacer(minLength: 8)

      Image(systemName: "chevron.right")
        .foregroundStyle(FuturistTheme.textSecondary)
        .onTapGesture { onTap() }
    }
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
  }

  private func dateLine() -> String {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .none
    return df.string(from: event.startDate)
  }

  private func timeLine(_ date: Date) -> String {
    let tf = DateFormatter()
    tf.dateStyle = .none
    tf.timeStyle = .short
    return tf.string(from: date)
  }
}
