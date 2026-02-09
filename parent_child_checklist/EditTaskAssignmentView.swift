import SwiftUI

struct EditTaskAssignmentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let original: TaskAssignment

    // Template selection
    @State private var selectedTemplate: TaskTemplate? = nil
    @State private var showSelectTask = false

    // Fields
    @State private var helperText: String
    @State private var rewardPoints: Int
    @State private var subtractIfNotCompleted: Bool
    @State private var isActive: Bool

    // Dates
    @State private var startDate: Date
    @State private var finishDateEnabled: Bool
    @State private var finishDate: Date

    // Occurrence
    @State private var occurrence: TaskAssignment.Occurrence
    @State private var selectedWeekdays: Set<Int>

    // Times
    @State private var startTimeEnabled: Bool
    @State private var startTime: Date
    @State private var finishTimeEnabled: Bool
    @State private var finishTime: Date

    // Duration
    @State private var durationEnabled: Bool
    @State private var durationHours: Int
    @State private var durationMinutes: Int

    // Options
    @State private var alertMe: Bool
    @State private var photoEvidence: Bool

    // ✅ Linked Event
    @State private var linkedEventAssignmentId: UUID?
    @State private var showSelectLinkedEvent = false

    // Delete confirmation
    @State private var showDeleteConfirm = false

    // ✅ Toast (for clamp messages)
    @State private var localToastMessage: String? = nil
    @State private var lastClampToastAt: Date = .distantPast

    // UI labels
    private let weekdayLabels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    init(assignment: TaskAssignment) {
        self.original = assignment

        _helperText = State(initialValue: assignment.helper ?? "")
        _rewardPoints = State(initialValue: max(0, assignment.rewardPoints))
        _subtractIfNotCompleted = State(initialValue: assignment.subtractIfNotCompleted)
        _isActive = State(initialValue: assignment.isActive)

        _startDate = State(initialValue: assignment.startDate)
        _finishDateEnabled = State(initialValue: assignment.endDate != nil)
        _finishDate = State(initialValue: assignment.endDate ?? assignment.startDate)

        _occurrence = State(initialValue: assignment.occurrence)
        _selectedWeekdays = State(initialValue: Set(assignment.weekdays))

        let now = Date()
        _startTimeEnabled = State(initialValue: assignment.startTime != nil)
        _startTime = State(initialValue: assignment.startTime ?? now)
        _finishTimeEnabled = State(initialValue: assignment.finishTime != nil)
        _finishTime = State(initialValue: assignment.finishTime ?? now)

        let dur = assignment.durationMinutes ?? 0
        _durationEnabled = State(initialValue: assignment.durationMinutes != nil)
        _durationHours = State(initialValue: dur / 60)
        _durationMinutes = State(initialValue: dur % 60)

        _alertMe = State(initialValue: assignment.alertMe)
        _photoEvidence = State(initialValue: assignment.photoEvidenceRequired)
        _linkedEventAssignmentId = State(initialValue: assignment.linkedEventAssignmentId)
    }

    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private func dayOnly(_ date: Date) -> Date { isoCalendar.startOfDay(for: date) }

    private func timeKey(_ time: Date) -> Int {
        let comps = isoCalendar.dateComponents([.hour, .minute], from: time)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    private var linkedEvent: EventAssignment? {
        guard let id = linkedEventAssignmentId else { return nil }
        return appState.eventAssignments.first(where: { $0.id == id })
    }

    private var linkedEventDisplayText: String {
        guard let e = linkedEvent else { return "None" }
        let title = e.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled Event" : title
    }

    // ✅ STRICT MODE: schedule is locked while linked
    private var isScheduleLockedByEvent: Bool { linkedEventAssignmentId != nil }

    // MARK: - Toast helpers
    private func showLocalToast(_ message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            localToastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                localToastMessage = nil
            }
        }
    }

    private func clampToast(_ message: String) {
        let now = Date()
        guard now.timeIntervalSince(lastClampToastAt) > 1.0 else { return }
        lastClampToastAt = now
        showLocalToast(message)
    }

    // MARK: - ✅ Legacy-safe date bounds (keep existing past selectable)
    private var todayDay: Date { dayOnly(Date()) }

    private var startDatePickerLowerBound: Date {
        // Must include any existing selection (original or linked event) to avoid out-of-range DatePicker issues
        let originalDay = dayOnly(original.startDate)
        let linkedDay = linkedEvent.map { dayOnly($0.startDate) } ?? todayDay
        return min(todayDay, originalDay, linkedDay)
    }

    private func isLegacyPastStartUnchanged() -> Bool {
        let originalDay = dayOnly(original.startDate)
        return originalDay < todayDay && dayOnly(startDate) == originalDay
    }

    // MARK: - ✅ No-past scheduling rules (Edit Task) + legacy safe
    private func enforceNoPastScheduling_EditTask() {
        let now = Date()
        let today = todayDay

        // If schedule locked by event, do NOT override dates (event controls them)
        if !isScheduleLockedByEvent {
            if dayOnly(startDate) < today && !isLegacyPastStartUnchanged() {
                startDate = today
                if finishDateEnabled && dayOnly(finishDate) < dayOnly(startDate) {
                    finishDate = startDate
                }
                clampToast("Start date adjusted to today.")
            }

            if finishDateEnabled && dayOnly(finishDate) < dayOnly(startDate) {
                finishDate = startDate
                clampToast("Finish date adjusted to match start date.")
            }
        }

        // Time rules
        let isToday = (dayOnly(startDate) == today)
        if isToday {
            let nowKey = timeKey(now)

            if startTimeEnabled && timeKey(startTime) < nowKey {
                startTime = now
                clampToast("Start time adjusted to now.")
            }

            if finishTimeEnabled && timeKey(finishTime) < nowKey {
                finishTime = now
                clampToast("Finish time adjusted to now.")
            }
        }

        if startTimeEnabled && finishTimeEnabled {
            if timeKey(finishTime) < timeKey(startTime) {
                finishTime = startTime
                clampToast("Finish time adjusted to be after start time.")
            }
        }

        if durationEnabled {
            syncFinishTimeFromDuration()
            if startTimeEnabled && finishTimeEnabled, timeKey(finishTime) < timeKey(startTime) {
                finishTime = startTime
                clampToast("Finish time adjusted to be after start time.")
            }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    // MARK: Task
                    Section("Task") {
                        Button { showSelectTask = true } label: {
                            HStack(spacing: 12) {
                                let icon = selectedTemplate?.iconSymbol ?? original.taskIcon
                                let title = selectedTemplate?.title ?? original.taskTitle
                                TaskEmojiIconView(icon: icon, size: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title).font(.headline)
                                    Text("Tap to change").font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        TextField("Helper (optional)", text: $helperText, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)

                        Toggle("Active", isOn: $isActive)
                    }

                    // MARK: Linked Event
                    Section("Linked Event (Optional)") {
                        Button { showSelectLinkedEvent = true } label: {
                            HStack {
                                Text("Linked Event")
                                Spacer()
                                Text(linkedEventDisplayText).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if linkedEventAssignmentId != nil {
                            Button(role: .destructive) { linkedEventAssignmentId = nil } label: {
                                Text("Remove Link")
                            }
                            Text("This task’s schedule and date range are controlled by the linked event.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Only active events that occur on or after the selected Start Date can be linked.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // MARK: Reward Points
                    Section("Reward Points") {
                        HStack {
                            Text("💎 Points")
                            Spacer()
                            Button { rewardPoints = max(0, rewardPoints - 1) } label: {
                                Image(systemName: "minus.circle.fill").font(.title3)
                            }
                            .buttonStyle(.plain)
                            .disabled(rewardPoints == 0)

                            Text("\(rewardPoints)").font(.headline).frame(minWidth: 32)

                            Button { rewardPoints += 1 } label: {
                                Image(systemName: "plus.circle.fill").font(.title3)
                            }
                            .buttonStyle(.plain)
                        }

                        Toggle("Subtract points if not completed", isOn: $subtractIfNotCompleted)
                            .font(.subheadline)
                    }

                    // MARK: Dates
                    Section("Dates") {
                        DatePicker(
                            "Start Date",
                            selection: $startDate,
                            in: startDatePickerLowerBound...,
                            displayedComponents: .date
                        )
                        .disabled(isScheduleLockedByEvent)
                        .onChange(of: startDate) { _, _ in enforceNoPastScheduling_EditTask() }

                        if occurrence == .onceOnly {
                            HStack {
                                Text("Finish Date")
                                Spacer()
                                Text("Not applicable").foregroundStyle(.secondary)
                            }
                        } else {
                            Toggle("Finish Date", isOn: $finishDateEnabled)
                                .disabled(isScheduleLockedByEvent)
                                .onChange(of: finishDateEnabled) { _, _ in enforceNoPastScheduling_EditTask() }

                            if finishDateEnabled {
                                DatePicker(
                                    "Finish Date",
                                    selection: $finishDate,
                                    in: startDate...,
                                    displayedComponents: .date
                                )
                                .disabled(isScheduleLockedByEvent)
                                .onChange(of: finishDate) { _, _ in enforceNoPastScheduling_EditTask() }
                            }
                        }

                        if isScheduleLockedByEvent, let ev = linkedEvent {
                            Text(scheduleSummary(for: ev))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // MARK: Occurrence
                    Section("Occurrence") {
                        Picker("Occurrence", selection: $occurrence) {
                            ForEach(TaskAssignment.Occurrence.allCases) { opt in
                                Text(opt.displayName).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(isScheduleLockedByEvent)

                        if occurrence == .specifiedDays {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Specified Days")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    ForEach(0..<7, id: \.self) { idx in
                                        let isSelected = selectedWeekdays.contains(idx)
                                        Button {
                                            if isSelected { selectedWeekdays.remove(idx) }
                                            else { selectedWeekdays.insert(idx) }
                                        } label: {
                                            Text(weekdayLabels[idx])
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .frame(width: 40, height: 32)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                                                lineWidth: isSelected ? 2 : 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isScheduleLockedByEvent)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if isScheduleLockedByEvent {
                            Text("Occurrence and weekdays are controlled by the linked event.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: occurrence) { _, newValue in
                        if newValue == .onceOnly { finishDateEnabled = false }
                        enforceNoPastScheduling_EditTask()
                    }

                    // MARK: Time
                    Section("Time") {
                        Toggle("Start Time", isOn: $startTimeEnabled)
                            .onChange(of: startTimeEnabled) { _, _ in enforceNoPastScheduling_EditTask() }

                        if startTimeEnabled {
                            DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                                .onChange(of: startTime) { _, _ in
                                    if durationEnabled { syncFinishTimeFromDuration() }
                                    enforceNoPastScheduling_EditTask()
                                }
                        }

                        Toggle("Finish Time", isOn: $finishTimeEnabled)
                            .onChange(of: finishTimeEnabled) { _, newValue in
                                if !newValue { alertMe = false }
                                enforceNoPastScheduling_EditTask()
                            }

                        if finishTimeEnabled {
                            DatePicker("Finish Time", selection: $finishTime, displayedComponents: .hourAndMinute)
                                .onChange(of: finishTime) { _, _ in enforceNoPastScheduling_EditTask() }
                        }

                        Toggle("Duration", isOn: $durationEnabled)
                            .onChange(of: durationEnabled) { _, enabled in
                                if enabled {
                                    if !startTimeEnabled { startTimeEnabled = true }
                                    syncFinishTimeFromDuration()
                                }
                                enforceNoPastScheduling_EditTask()
                            }

                        if durationEnabled {
                            Stepper("Hours: \(durationHours)", value: $durationHours, in: 0...23)
                                .onChange(of: durationHours) { _, _ in
                                    if durationEnabled { syncFinishTimeFromDuration() }
                                    enforceNoPastScheduling_EditTask()
                                }

                            Stepper("Minutes: \(durationMinutes)", value: $durationMinutes, in: 0...55, step: 5)
                                .onChange(of: durationMinutes) { _, _ in
                                    if durationEnabled { syncFinishTimeFromDuration() }
                                    enforceNoPastScheduling_EditTask()
                                }

                            Text("If duration is set, Finish Time will be adjusted to Start Time + Duration.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // MARK: Options
                    Section("Options") {
                        Toggle("Alert Me", isOn: $alertMe)
                            .disabled(!finishTimeEnabled)

                        if !finishTimeEnabled {
                            Text("Finish Time is required for alerts.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Toggle("Photo Evidence", isOn: $photoEvidence)
                    }

                    // MARK: Delete
                    Section {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Text("Delete Assignment")
                        }
                    }
                }

                if let localToastMessage {
                    ToastBannerView(message: localToastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            // STRICT MODE: when link changes, force schedule & date range to match event
            .onChange(of: linkedEventAssignmentId) { _, _ in
                applyStrictLinkedEventToLocalState()
                enforceNoPastScheduling_EditTask()
            }
            .onAppear {
                if linkedEventAssignmentId != nil {
                    applyStrictLinkedEventToLocalState()
                }
                enforceNoPastScheduling_EditTask()
            }
            .navigationTitle("Edit Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEdits() }
                }
            }
            .navigationDestination(isPresented: $showSelectTask) {
                SelectTaskTemplateView(
                    selectedTemplateId: selectedTemplate?.id ?? original.templateId,
                    onPick: { picked in
                        selectedTemplate = picked
                        rewardPoints = max(0, picked.rewardPoints)
                    }
                )
                .environmentObject(appState)
            }
            .navigationDestination(isPresented: $showSelectLinkedEvent) {
                SelectLinkedEventAssignmentView(
                    childId: original.childId,
                    minimumStartDate: startDate,
                    selectedEventAssignmentId: $linkedEventAssignmentId
                )
                .environmentObject(appState)
            }
            .alert("Delete this assignment?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    appState.deleteTaskAssignment(id: original.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the assignment (and its completion ticks).")
            }
        }
    }

    // MARK: - Strict alignment helpers
    private func applyStrictLinkedEventToLocalState() {
        guard let ev = linkedEvent else { return }
        if !ev.isActive {
            linkedEventAssignmentId = nil
            return
        }
        switch ev.occurrence {
        case .onceOnly:
            occurrence = .onceOnly
            selectedWeekdays = []
            startDate = ev.startDate
            finishDateEnabled = false
        case .specifiedDays:
            occurrence = .specifiedDays
            selectedWeekdays = Set(ev.weekdays)
            startDate = ev.startDate
            if let evEnd = ev.endDate {
                finishDateEnabled = true
                finishDate = evEnd
            } else {
                finishDateEnabled = false
            }
        }
    }

    private func scheduleSummary(for ev: EventAssignment) -> String {
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        let start = df.string(from: ev.startDate)
        let endText = ev.endDate.map { df.string(from: $0) } ?? "No end date"

        let daysText: String
        switch ev.occurrence {
        case .onceOnly:
            daysText = "Once"
        case .specifiedDays:
            let labels: [String] = ev.weekdays
                .sorted()
                .compactMap { (idx: Int) -> String? in
                    guard idx >= 0 && idx < weekdayLabels.count else { return nil }
                    return weekdayLabels[idx]
                }
            daysText = labels.isEmpty ? "Specified days" : labels.joined(separator: ", ")
        }

        let titleTrimmed = ev.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = titleTrimmed.isEmpty ? "Untitled Event" : titleTrimmed
        return "Follows “\(title)”: \(daysText) • \(start) → \(endText)"
    }

    // MARK: - Save
    private func saveEdits() {
        if linkedEventAssignmentId != nil {
            applyStrictLinkedEventToLocalState()
        }

        enforceNoPastScheduling_EditTask()

        let taskTitle = selectedTemplate?.title ?? original.taskTitle
        let taskIcon = selectedTemplate?.iconSymbol ?? original.taskIcon
        let templateId = selectedTemplate?.id ?? original.templateId

        let helper = helperText.trimmingCharacters(in: .whitespacesAndNewlines)
        let helperOrNil = helper.isEmpty ? nil : helper

        let end: Date? = (occurrence == .onceOnly) ? nil : (finishDateEnabled ? finishDate : nil)
        let startTimeValue: Date? = startTimeEnabled ? startTime : nil
        let finishTimeValue: Date? = finishTimeEnabled ? finishTime : nil
        let durationValue: Int? = durationEnabled ? max(0, durationHours * 60 + durationMinutes) : nil

        var updated = original
        updated.templateId = templateId
        updated.taskTitle = taskTitle
        updated.taskIcon = taskIcon
        updated.rewardPoints = max(0, rewardPoints)
        updated.helper = helperOrNil
        updated.subtractIfNotCompleted = subtractIfNotCompleted
        updated.alertMe = alertMe
        updated.photoEvidenceRequired = photoEvidence
        updated.isActive = isActive
        updated.startDate = startDate
        updated.endDate = end
        updated.occurrence = occurrence
        updated.weekdays = Array(selectedWeekdays).sorted()
        updated.startTime = startTimeValue
        updated.finishTime = finishTimeValue
        updated.durationMinutes = durationValue
        updated.linkedEventAssignmentId = linkedEventAssignmentId
        updated.updatedAt = Date()

        _ = appState.updateTaskAssignment(updated)
        dismiss()
    }

    // MARK: - Duration rule
    private func syncFinishTimeFromDuration() {
        guard startTimeEnabled else { return }
        if !finishTimeEnabled { finishTimeEnabled = true }
        let totalMinutes = max(0, durationHours * 60 + durationMinutes)
        finishTime = Calendar.current.date(byAdding: .minute, value: totalMinutes, to: startTime) ?? startTime
    }
}
