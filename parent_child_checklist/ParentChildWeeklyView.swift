import SwiftUI

struct ParentChildWeeklyView: View {
    let childId: UUID

    @EnvironmentObject private var appState: AppState

    // Selected day
    @State private var selectedDate: Date = Date()

    // Chooser + sheets
    @State private var showAssignChooser = false
    @State private var showAssignTaskSheet = false
    @State private var showAssignEventSheet = false

    // Edit sheets
    @State private var assignmentToEdit: TaskAssignment? = nil
    @State private var eventToEdit: EventAssignment? = nil

    // ✅ Toast (weekly view owns it)
    @State private var toastMessage: String? = nil

    // ISO-like calendar with Monday as first weekday
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private var child: ChildProfile? {
        appState.children.first { $0.id == childId }
    }

    private var today: Date { Date() }

    // MARK: - Header text (reflects selectedDate)
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

    private var todayLineText: String {
        let df = DateFormatter()
        df.calendar = isoCalendar
        df.locale = .current
        df.dateStyle = .long
        let todayLong = df.string(from: today)

        let df2 = DateFormatter()
        df2.calendar = isoCalendar
        df2.locale = .current
        df2.dateFormat = "EEEE"
        let todayWeekday = df2.string(from: today)

        return "Today: \(todayWeekday), \(todayLong)"
    }

    // Placeholder for points
    private var pointsText: String { "0" }

    // Tasks for selected day
    private var tasksForSelectedDay: [TaskAssignment] {
        appState.assignments(for: childId, on: selectedDate)
    }

    // Events for selected day
    private var eventsForSelectedDay: [EventAssignment] {
        appState.events(for: childId, on: selectedDate)
    }

    // Set of event IDs occurring on the selected day
    private var eventIdsForSelectedDay: Set<UUID> {
        Set(eventsForSelectedDay.map(\.id))
    }

    // Tasks linked to events occurring today
    private var linkedTasksForSelectedDay: [TaskAssignment] {
        tasksForSelectedDay.filter { task in
            if let evId = task.linkedEventAssignmentId {
                return eventIdsForSelectedDay.contains(evId)
            }
            return false
        }
    }

    // Tasks not linked (or linked to an event that isn't occurring today)
    private var unlinkedTasksForSelectedDay: [TaskAssignment] {
        tasksForSelectedDay.filter { task in
            guard let evId = task.linkedEventAssignmentId else { return true }
            return !eventIdsForSelectedDay.contains(evId)
        }
    }

    // MARK: - Effective time (startTime preferred, else finishTime)
    private func effectiveTime(for task: TaskAssignment) -> Date? {
        task.startTime ?? task.finishTime
    }

    private func effectiveTime(for event: EventAssignment) -> Date? {
        event.startTime ?? event.finishTime
    }

    // MARK: - Time-of-day key (minutes since midnight)
    private func timeOfDayKey(_ time: Date?) -> Int? {
        guard let time else { return nil }
        let comps = isoCalendar.dateComponents([.hour, .minute], from: time)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return h * 60 + m
    }

    private func taskTimeKey(_ task: TaskAssignment) -> Int? {
        timeOfDayKey(effectiveTime(for: task))
    }

    private func eventTimeKey(_ event: EventAssignment) -> Int? {
        timeOfDayKey(effectiveTime(for: event))
    }

    // MARK: - Sorting helpers (active first, then time, then title)
    private var eventsSortedForDisplay: [EventAssignment] {
        eventsForSelectedDay.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive && !b.isActive }

            let ta = eventTimeKey(a)
            let tb = eventTimeKey(b)
            switch (ta, tb) {
            case (nil, nil):
                break
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (let x?, let y?):
                if x != y { return x < y }
            }

            return a.eventTitle.localizedCaseInsensitiveCompare(b.eventTitle) == .orderedAscending
        }
    }

    private func linkedTasks(for eventId: UUID) -> [TaskAssignment] {
        linkedTasksForSelectedDay
            .filter { $0.linkedEventAssignmentId == eventId }
            .sorted { a, b in
                if a.isActive != b.isActive { return a.isActive && !b.isActive }

                let ta = taskTimeKey(a)
                let tb = taskTimeKey(b)
                switch (ta, tb) {
                case (nil, nil):
                    break
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                case (let x?, let y?):
                    if x != y { return x < y }
                }

                return a.taskTitle.localizedCaseInsensitiveCompare(b.taskTitle) == .orderedAscending
            }
    }

    private var unlinkedTasksSortedForDisplay: [TaskAssignment] {
        unlinkedTasksForSelectedDay.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive && !b.isActive }

            let ta = taskTimeKey(a)
            let tb = taskTimeKey(b)
            switch (ta, tb) {
            case (nil, nil):
                break
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (let x?, let y?):
                if x != y { return x < y }
            }

            return a.taskTitle.localizedCaseInsensitiveCompare(b.taskTitle) == .orderedAscending
        }
    }

    // MARK: - Agenda ordering (Tasks-first vs Events-first)
    private enum AgendaSection: Hashable {
        case tasks
        case events
    }

    private var earliestStandaloneTaskKey: Int? {
        unlinkedTasksForSelectedDay.compactMap { taskTimeKey($0) }.min()
    }

    private var earliestEventBlockKey: Int? {
        let perEventEarliest: [Int] = eventsForSelectedDay.compactMap { ev in
            var keys: [Int] = []
            if let k = eventTimeKey(ev) { keys.append(k) }
            keys.append(contentsOf: linkedTasks(for: ev.id).compactMap { taskTimeKey($0) })
            return keys.min()
        }
        return perEventEarliest.min()
    }

    private var agendaSectionOrder: [AgendaSection] {
        let t = earliestStandaloneTaskKey
        let e = earliestEventBlockKey
        if t == nil && e == nil { return [.tasks, .events] }
        if let t, let e { return (t <= e) ? [.tasks, .events] : [.events, .tasks] }
        if t != nil { return [.tasks, .events] }
        return [.events, .tasks]
    }

    private var standaloneTasksSectionTitle: String {
        guard !eventsForSelectedDay.isEmpty else { return "Tasks" }
        return (agendaSectionOrder.first == .events) ? "Other Tasks" : "Tasks"
    }

    // MARK: - Toast helpers
    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                toastMessage = nil
            }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    headerView
                    dayStripPager
                    agendaArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal)
                .navigationTitle(child?.name ?? "Child")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") { jumpToToday() }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    bottomAddBar
                }
                .sheet(isPresented: $showAssignTaskSheet) {
                    AssignTaskToChildView(
                        childId: childId,
                        defaultStartDate: selectedDate,
                        onShowWeeklyToast: { msg in showToast(msg) }
                    )
                    .environmentObject(appState)
                }
                .sheet(isPresented: $showAssignEventSheet) {
                    AssignEventToChildView(
                        childId: childId,
                        defaultStartDate: selectedDate,
                        onShowWeeklyToast: { msg in showToast(msg) }
                    )
                    .environmentObject(appState)
                }
                .sheet(item: $assignmentToEdit) { assignment in
                    EditTaskAssignmentView(assignment: assignment)
                        .environmentObject(appState)
                }
                .sheet(item: $eventToEdit) { event in
                    EditEventAssignmentView(assignment: event)
                        .environmentObject(appState)
                }
                .confirmationDialog(
                    "Assign",
                    isPresented: $showAssignChooser,
                    titleVisibility: .visible
                ) {
                    Button("Assign Task") { showAssignTaskSheet = true }
                    Button("Assign Event") { showAssignEventSheet = true }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("What would you like to assign?")
                }
                .onAppear {
                    selectedDate = isoCalendar.startOfDay(for: today)
                }

                if let toastMessage {
                    ToastBannerView(message: toastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        let isSelectedToday = isoCalendar.isDate(selectedDate, inSameDayAs: today)

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(headerSelectedDayText)
                    .font(.largeTitle)
                    .fontWeight(.heavy)

                Text(headerSelectedDateText)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                if isSelectedToday {
                    Text("Today")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(todayLineText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Text("💎")
                Text(pointsText)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .accessibilityLabel("Reward points \(pointsText)")
        }
        .padding(.top, 6)
    }

    private var dayStripPager: some View {
        ScrollableDayStrip(
            selectedDate: $selectedDate,
            calendar: isoCalendar
        )
        .frame(height: 70)
        .padding(.bottom, -14)   // safe, small adjustment
    }
    
    private var agendaArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            if tasksForSelectedDay.isEmpty && eventsForSelectedDay.isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 16)
                    Text("No tasks or events assigned for this day.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(agendaSectionOrder, id: \.self) { section in
                        switch section {
                        case .tasks:
                            if !unlinkedTasksSortedForDisplay.isEmpty {
                                Section(standaloneTasksSectionTitle) {
                                    ForEach(unlinkedTasksSortedForDisplay) { assignment in
                                        TaskAssignmentRow(
                                            assignment: assignment,
                                            selectedDate: selectedDate,
                                            isCompleted: appState.isCompleted(assignmentId: assignment.id, on: selectedDate),
                                            onToggleComplete: {
                                                appState.toggleCompletion(assignmentId: assignment.id, on: selectedDate)
                                            },
                                            onTap: {
                                                assignmentToEdit = assignment
                                            }
                                        )
                                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                    }
                                    .onDelete { indexSet in
                                        for idx in indexSet {
                                            let a = unlinkedTasksSortedForDisplay[idx]
                                            appState.deleteTaskAssignment(id: a.id)
                                        }
                                    }
                                }
                            }

                        case .events:
                            if !eventsSortedForDisplay.isEmpty {
                                Section("Events") {
                                    ForEach(eventsSortedForDisplay) { event in
                                        EventAssignmentRow(
                                            event: event,
                                            onTap: { eventToEdit = event }
                                        )
                                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                appState.deleteEventAssignment(id: event.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }

                                        let tasks = linkedTasks(for: event.id)
                                        if !tasks.isEmpty {
                                            ForEach(tasks) { assignment in
                                                TaskAssignmentRow(
                                                    assignment: assignment,
                                                    selectedDate: selectedDate,
                                                    isCompleted: appState.isCompleted(assignmentId: assignment.id, on: selectedDate),
                                                    onToggleComplete: {
                                                        appState.toggleCompletion(assignmentId: assignment.id, on: selectedDate)
                                                    },
                                                    onTap: {
                                                        assignmentToEdit = assignment
                                                    }
                                                )
                                                .padding(.leading, 18)
                                                .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
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
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListHeaderHeight, 0)
            }
        }
    }

    private var bottomAddBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button {
                    showAssignChooser = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 52, height: 52)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Circle())
                        .accessibilityLabel("Assign")
                }
                Spacer()
            }
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private func jumpToToday() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            selectedDate = isoCalendar.startOfDay(for: today)
        }
    }
}

// MARK: - Task row (with Inactive pill)
private struct TaskAssignmentRow: View {
    let assignment: TaskAssignment
    let selectedDate: Date
    let isCompleted: Bool
    let onToggleComplete: () -> Void
    let onTap: () -> Void

    private var dimmed: Bool { !assignment.isActive }

    private var inactiveBadge: some View {
        Text("Inactive")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.secondary)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
            .accessibilityLabel("Inactive")
    }

    private var timeSummary: String? {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        var parts: [String] = []

        if let start = assignment.startTime {
            parts.append("⏰ \(timeFormatter.string(from: start))")
        }
        if let finish = assignment.finishTime {
            parts.append("→ \(timeFormatter.string(from: finish))")
        }
        if let dur = assignment.durationMinutes, dur > 0 {
            let h = dur / 60
            let m = dur % 60
            if h > 0 && m > 0 { parts.append("⏳ \(h)h \(m)m") }
            else if h > 0 { parts.append("⏳ \(h)h") }
            else { parts.append("⏳ \(m)m") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    var body: some View {
        Button { onTap() } label: {
            HStack(alignment: .top, spacing: 12) {
                Button { onToggleComplete() } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isCompleted ? Color.green : Color.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(assignment.taskIcon)
                            .font(.system(size: 22))
                            .frame(width: 30, height: 30)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Text(assignment.taskTitle)
                            .font(.headline)

                        Spacer()

                        if !assignment.isActive {
                            inactiveBadge
                        }

                        if assignment.rewardPoints > 0 {
                            HStack(spacing: 4) {
                                Text("💎")
                                Text("\(assignment.rewardPoints)")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let helper = assignment.helper,
                       !helper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(helper)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 10) {
                        if let timeSummary {
                            Text(timeSummary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if assignment.alertMe {
                            Text("🔔 Alert")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .opacity(dimmed ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Event row (with Inactive pill)
private struct EventAssignmentRow: View {
    let event: EventAssignment
    let onTap: () -> Void

    private var dimmed: Bool { !event.isActive }

    private var inactiveBadge: some View {
        Text("Inactive")
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.secondary)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
            .accessibilityLabel("Inactive")
    }

    private var timeSummary: String? {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        var parts: [String] = []

        if let start = event.startTime {
            parts.append("⏰ \(timeFormatter.string(from: start))")
        }
        if let finish = event.finishTime {
            parts.append("→ \(timeFormatter.string(from: finish))")
        }
        if let dur = event.durationMinutes, dur > 0 {
            let h = dur / 60
            let m = dur % 60
            if h > 0 && m > 0 { parts.append("⏳ \(h)h \(m)m") }
            else if h > 0 { parts.append("⏳ \(h)h") }
            else { parts.append("⏳ \(m)m") }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private var locationLine: String? {
        let t = event.locationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : "📍 \(t)"
    }

    private var alertLine: String? {
        guard event.alertMe else { return nil }
        let mins = event.alertOffsetMinutes ?? 0
        if mins == 0 { return "🔔 Alert at start time" }
        return "🔔 Alert \(mins) min before"
    }

    var body: some View {
        Button { onTap() } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(event.eventIcon)
                        .font(.system(size: 22))
                        .frame(width: 30, height: 30)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text(event.eventTitle)
                        .font(.headline)

                    Spacer()

                    if !event.isActive {
                        inactiveBadge
                    }
                }

                if let helper = event.helper,
                   !helper.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(helper)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    if let timeSummary {
                        Text(timeSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let locationLine {
                        Text(locationLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let alertLine {
                        Text(alertLine)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .opacity(dimmed ? 0.60 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
