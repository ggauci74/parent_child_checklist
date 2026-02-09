import SwiftUI

struct EditEventAssignmentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let original: EventAssignment

    // Event selection
    @State private var selectedTemplate: EventTemplate? = nil
    @State private var showSelectEvent = false

    // Fields
    @State private var helperText: String
    @State private var isActive: Bool

    // Location (optional)
    @State private var selectedLocationId: UUID?
    @State private var selectedLocationNameSnapshot: String
    @State private var showLocationPicker = false

    // Dates
    @State private var startDate: Date
    @State private var finishDateEnabled: Bool
    @State private var finishDate: Date

    // Occurrence
    @State private var occurrence: EventAssignment.Occurrence
    @State private var selectedWeekdays: Set<Int>
    private let weekdayLabels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    // Times
    @State private var startTimeEnabled: Bool
    @State private var startTime: Date
    @State private var finishTimeEnabled: Bool
    @State private var finishTime: Date

    // Duration
    @State private var durationEnabled: Bool
    @State private var durationHours: Int
    @State private var durationMinutes: Int

    // Alerts
    @State private var alertMe: Bool
    @State private var alertOffsetMinutes: Int

    // Delete
    @State private var showDeleteConfirm = false

    // ✅ Toast (clamp messages)
    @State private var localToastMessage: String? = nil
    @State private var lastClampToastAt: Date = .distantPast

    init(assignment: EventAssignment) {
        self.original = assignment

        _helperText = State(initialValue: assignment.helper ?? "")
        _isActive = State(initialValue: assignment.isActive)

        _selectedLocationId = State(initialValue: assignment.locationId)
        _selectedLocationNameSnapshot = State(initialValue: assignment.locationNameSnapshot)

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
        _alertOffsetMinutes = State(initialValue: assignment.alertOffsetMinutes ?? 10)
    }

    private var alertOffsetOptions: [(label: String, minutes: Int)] {
        [
            ("At start time", 0),
            ("5 min before", 5),
            ("10 min before", 10),
            ("15 min before", 15),
            ("30 min before", 30),
            ("1 hour before", 60),
            ("2 hours before", 120)
        ]
    }

    // MARK: - Calendar helpers
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

    // MARK: - ✅ Legacy-safe date bounds
    private var todayDay: Date { dayOnly(Date()) }

    private var startDatePickerLowerBound: Date {
        // Must include original selection day so DatePicker doesn't go out-of-range for legacy past items
        min(todayDay, dayOnly(original.startDate))
    }

    private func isLegacyPastStartUnchanged() -> Bool {
        let originalDay = dayOnly(original.startDate)
        return originalDay < todayDay && dayOnly(startDate) == originalDay
    }

    // MARK: - ✅ No-past scheduling rules (Edit Event) + legacy safe
    private func enforceNoPastScheduling_EditEvent() {
        let now = Date()
        let today = todayDay

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
                    Section("Event") {
                        Button {
                            showSelectEvent = true
                        } label: {
                            HStack(spacing: 12) {
                                let icon = selectedTemplate?.iconSymbol ?? original.eventIcon
                                let title = selectedTemplate?.title ?? original.eventTitle
                                TaskEmojiIconView(icon: icon, size: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title).font(.headline)
                                    Text("Tap to change")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
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

                    Section("Location (Optional)") {
                        Button {
                            showLocationPicker = true
                        } label: {
                            HStack {
                                Text("Selected")
                                Spacer()
                                Text(selectedLocationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None" : selectedLocationNameSnapshot)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Section("Dates") {
                        DatePicker(
                            "Start Date",
                            selection: $startDate,
                            in: startDatePickerLowerBound...,
                            displayedComponents: .date
                        )
                        .onChange(of: startDate) { _, _ in enforceNoPastScheduling_EditEvent() }

                        if occurrence == .onceOnly {
                            HStack {
                                Text("Finish Date")
                                Spacer()
                                Text("Not applicable")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Toggle("Finish Date", isOn: $finishDateEnabled)
                                .onChange(of: finishDateEnabled) { _, _ in enforceNoPastScheduling_EditEvent() }

                            if finishDateEnabled {
                                DatePicker(
                                    "Finish Date",
                                    selection: $finishDate,
                                    in: startDate...,
                                    displayedComponents: .date
                                )
                                .onChange(of: finishDate) { _, _ in enforceNoPastScheduling_EditEvent() }
                            }
                        }
                    }

                    Section("Occurrence") {
                        Picker("Occurrence", selection: $occurrence) {
                            ForEach(EventAssignment.Occurrence.allCases) { opt in
                                Text(opt.displayName).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)

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
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onChange(of: occurrence) { _, newValue in
                        if newValue == .onceOnly { finishDateEnabled = false }
                        enforceNoPastScheduling_EditEvent()
                    }

                    Section("Time") {
                        Toggle("Start Time", isOn: $startTimeEnabled)
                            .onChange(of: startTimeEnabled) { _, enabled in
                                if !enabled { alertMe = false }
                                enforceNoPastScheduling_EditEvent()
                            }

                        if startTimeEnabled {
                            DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                                .onChange(of: startTime) { _, _ in
                                    if durationEnabled { syncFinishTimeFromDuration() }
                                    enforceNoPastScheduling_EditEvent()
                                }
                        }

                        Toggle("Finish Time", isOn: $finishTimeEnabled)
                            .onChange(of: finishTimeEnabled) { _, _ in enforceNoPastScheduling_EditEvent() }

                        if finishTimeEnabled {
                            DatePicker("Finish Time", selection: $finishTime, displayedComponents: .hourAndMinute)
                                .onChange(of: finishTime) { _, _ in enforceNoPastScheduling_EditEvent() }
                        }

                        Toggle("Duration", isOn: $durationEnabled)
                            .onChange(of: durationEnabled) { _, enabled in
                                if enabled {
                                    if !startTimeEnabled { startTimeEnabled = true }
                                    syncFinishTimeFromDuration()
                                }
                                enforceNoPastScheduling_EditEvent()
                            }

                        if durationEnabled {
                            Stepper("Hours: \(durationHours)", value: $durationHours, in: 0...23)
                                .onChange(of: durationHours) { _, _ in
                                    if durationEnabled { syncFinishTimeFromDuration() }
                                    enforceNoPastScheduling_EditEvent()
                                }

                            Stepper("Minutes: \(durationMinutes)", value: $durationMinutes, in: 0...55, step: 5)
                                .onChange(of: durationMinutes) { _, _ in
                                    if durationEnabled { syncFinishTimeFromDuration() }
                                    enforceNoPastScheduling_EditEvent()
                                }

                            Text("If duration is set, Finish Time will be adjusted to Start Time + Duration.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Alerts") {
                        Toggle("Alert Me", isOn: $alertMe)
                            .onChange(of: alertMe) { _, enabled in
                                if enabled, !startTimeEnabled { startTimeEnabled = true }
                                enforceNoPastScheduling_EditEvent()
                            }

                        if alertMe {
                            Picker("When", selection: $alertOffsetMinutes) {
                                ForEach(alertOffsetOptions, id: \.minutes) { opt in
                                    Text(opt.label).tag(opt.minutes)
                                }
                            }
                            Text(alertHintText())
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Alerts for events are reminders before the start time.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Text("Delete Event Assignment")
                        }
                    }
                }

                if let localToastMessage {
                    ToastBannerView(message: localToastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .onAppear {
                enforceNoPastScheduling_EditEvent()
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEdits() }
                }
            }
            .navigationDestination(isPresented: $showSelectEvent) {
                SelectEventTemplateView(
                    selectedTemplateId: selectedTemplate?.id ?? original.templateId,
                    onPick: { picked in
                        selectedTemplate = picked
                    }
                )
                .environmentObject(appState)
            }
            .sheet(isPresented: $showLocationPicker) {
                NavigationStack {
                    SelectLocationView(
                        selectedLocationId: $selectedLocationId,
                        selectedLocationNameSnapshot: $selectedLocationNameSnapshot
                    )
                    .environmentObject(appState)
                }
            }
            .alert("Delete this event assignment?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    appState.deleteEventAssignment(id: original.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the event assignment.")
            }
        }
    }

    private func alertHintText() -> String {
        if alertOffsetMinutes == 0 { return "You will be alerted at the event start time." }
        return "You will be alerted \(alertOffsetMinutes) minutes before the event starts."
    }

    private func saveEdits() {
        enforceNoPastScheduling_EditEvent()

        let eventTitle = selectedTemplate?.title ?? original.eventTitle
        let eventIcon = selectedTemplate?.iconSymbol ?? original.eventIcon
        let templateId = selectedTemplate?.id ?? original.templateId

        let helper = helperText.trimmingCharacters(in: .whitespacesAndNewlines)
        let helperOrNil = helper.isEmpty ? nil : helper

        let end: Date? = (occurrence == .onceOnly) ? nil : (finishDateEnabled ? finishDate : nil)
        let weekdays = Array(selectedWeekdays).sorted()

        let startTimeValue: Date? = startTimeEnabled ? startTime : nil
        let finishTimeValue: Date? = finishTimeEnabled ? finishTime : nil
        let durationValue: Int? = durationEnabled ? max(0, durationHours * 60 + durationMinutes) : nil

        let alertOn = alertMe && startTimeValue != nil
        let offset: Int? = alertOn ? max(0, alertOffsetMinutes) : nil

        var updated = original
        updated.templateId = templateId
        updated.eventTitle = eventTitle
        updated.eventIcon = eventIcon
        updated.helper = helperOrNil
        updated.isActive = isActive
        updated.startDate = startDate
        updated.endDate = end
        updated.occurrence = occurrence
        updated.weekdays = weekdays
        updated.startTime = startTimeValue
        updated.finishTime = finishTimeValue
        updated.durationMinutes = durationValue
        updated.locationId = selectedLocationId
        updated.locationNameSnapshot = selectedLocationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.alertMe = alertOn
        updated.alertOffsetMinutes = offset
        updated.updatedAt = Date()

        _ = appState.updateEventAssignment(updated)
        dismiss()
    }

    private func syncFinishTimeFromDuration() {
        guard startTimeEnabled else { return }
        if !finishTimeEnabled { finishTimeEnabled = true }
        let totalMinutes = max(0, durationHours * 60 + durationMinutes)
        finishTime = Calendar.current.date(byAdding: .minute, value: totalMinutes, to: startTime) ?? startTime
    }
}
