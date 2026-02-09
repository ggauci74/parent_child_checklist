import SwiftUI

struct AssignEventToChildView: View {
    let childId: UUID
    let defaultStartDate: Date
    let onShowWeeklyToast: ((String) -> Void)?

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // ✅ Multi-child selection
    @State private var selectedChildIds: Set<UUID>

    // Event selection
    @State private var selectedTemplate: EventTemplate? = nil
    @State private var showSelectEvent = false

    // Fields
    @State private var helperText: String = ""
    @State private var isActive: Bool = true

    // Location (optional)
    @State private var selectedLocationId: UUID? = nil
    @State private var selectedLocationNameSnapshot: String = ""
    @State private var showLocationPicker = false

    // Dates
    @State private var startDate: Date
    @State private var finishDateEnabled: Bool = false
    @State private var finishDate: Date

    // Occurrence
    @State private var occurrence: EventAssignment.Occurrence = .specifiedDays
    @State private var selectedWeekdays: Set<Int> = [0,1,2,3,4,5,6]
    private let weekdayLabels = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]

    // Times
    @State private var startTimeEnabled: Bool = false
    @State private var startTime: Date
    @State private var finishTimeEnabled: Bool = false
    @State private var finishTime: Date

    // Duration
    @State private var durationEnabled: Bool = false
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 30

    // Alerts (event-style)
    @State private var alertMe: Bool = false
    @State private var alertOffsetMinutes: Int = 10

    // ✅ Local toast
    @State private var localToastMessage: String? = nil

    // ✅ Rate-limit clamp toasts
    @State private var lastClampToastAt: Date = .distantPast

    // MARK: - Init
    init(childId: UUID, defaultStartDate: Date, onShowWeeklyToast: ((String) -> Void)? = nil) {
        self.childId = childId
        self.defaultStartDate = defaultStartDate
        self.onShowWeeklyToast = onShowWeeklyToast

        _selectedChildIds = State(initialValue: [childId])
        _startDate = State(initialValue: defaultStartDate)
        _finishDate = State(initialValue: defaultStartDate)

        let now = Date()
        _startTime = State(initialValue: now)
        _finishTime = State(initialValue: now)
    }

    // MARK: - Derived
    private var canSave: Bool {
        selectedTemplate != nil && !selectedChildIds.isEmpty
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

    // MARK: - Date/time keys for duplicate detection
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private func dayOnly(_ date: Date) -> Date {
        isoCalendar.startOfDay(for: date)
    }

    private func timeKey(_ time: Date?) -> Int? {
        guard let time else { return nil }
        let comps = isoCalendar.dateComponents([.hour, .minute], from: time)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    private func normalizedOptionalString(_ s: String?) -> String? {
        let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    // MARK: - ✅ No-past scheduling rules (Assign Event)
    private var todayDay: Date { dayOnly(Date()) }

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

    private func enforceNoPastScheduling() {
        let now = Date()
        let today = todayDay

        if dayOnly(startDate) < today {
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
            let nowKey = timeKey(now) ?? 0

            if startTimeEnabled, let sKey = timeKey(startTime), sKey < nowKey {
                startTime = now
                clampToast("Start time adjusted to now.")
            }

            if finishTimeEnabled, let fKey = timeKey(finishTime), fKey < nowKey {
                finishTime = now
                clampToast("Finish time adjusted to now.")
            }
        }

        if startTimeEnabled && finishTimeEnabled,
           let sKey = timeKey(startTime),
           let fKey = timeKey(finishTime),
           fKey < sKey {
            finishTime = startTime
            clampToast("Finish time adjusted to be after start time.")
        }

        if durationEnabled {
            syncFinishTimeFromDuration()
            if startTimeEnabled && finishTimeEnabled,
               let sKey = timeKey(startTime),
               let fKey = timeKey(finishTime),
               fKey < sKey {
                finishTime = startTime
                clampToast("Finish time adjusted to be after start time.")
            }
        }
    }

    // MARK: - Duplicate detection
    private func isExactDuplicateEvent(_ proposed: EventAssignment) -> Bool {
        appState.eventAssignments.contains { existing in
            guard existing.childId == proposed.childId else { return false }
            guard existing.templateId == proposed.templateId else { return false }

            // Snapshot identity
            guard existing.eventTitle == proposed.eventTitle else { return false }
            guard existing.eventIcon == proposed.eventIcon else { return false }
            guard normalizedOptionalString(existing.helper) == normalizedOptionalString(proposed.helper) else { return false }
            guard existing.isActive == proposed.isActive else { return false }

            // Schedule identity
            guard dayOnly(existing.startDate) == dayOnly(proposed.startDate) else { return false }
            guard existing.endDate.map(dayOnly) == proposed.endDate.map(dayOnly) else { return false }
            guard existing.occurrence == proposed.occurrence else { return false }
            guard existing.weekdays.sorted() == proposed.weekdays.sorted() else { return false }

            // Time identity
            guard timeKey(existing.startTime) == timeKey(proposed.startTime) else { return false }
            guard timeKey(existing.finishTime) == timeKey(proposed.finishTime) else { return false }
            guard existing.durationMinutes == proposed.durationMinutes else { return false }

            // Location + alerts identity
            guard existing.locationId == proposed.locationId else { return false }
            guard existing.locationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                == proposed.locationNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            guard existing.alertMe == proposed.alertMe else { return false }
            guard existing.alertOffsetMinutes == proposed.alertOffsetMinutes else { return false }

            return true
        }
    }

    private func childName(_ id: UUID) -> String {
        appState.children.first(where: { $0.id == id })?.name ?? "Child"
    }

    private func alertOffsetLabel() -> String {
        if alertOffsetMinutes == 0 { return "at start time" }
        return "\(alertOffsetMinutes) minutes"
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    // Assign To
                    Section("Assign To") {
                        HStack {
                            Button("Select All") {
                                selectedChildIds = Set(appState.children.map(\.id))
                            }
                            Spacer()
                            Button("Clear All") {
                                selectedChildIds.removeAll()
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.tint)

                        ForEach(appState.children) { child in
                            HStack {
                                Text(child.name)
                                Spacer()
                                Image(systemName: selectedChildIds.contains(child.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedChildIds.contains(child.id) ? Color.accentColor : Color.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedChildIds.contains(child.id) { selectedChildIds.remove(child.id) }
                                else { selectedChildIds.insert(child.id) }
                            }
                        }

                        if selectedChildIds.isEmpty {
                            Text("Select at least one child.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Section("Event") {
                        Button {
                            showSelectEvent = true
                        } label: {
                            HStack(spacing: 12) {
                                if let tpl = selectedTemplate {
                                    TaskEmojiIconView(icon: tpl.iconSymbol, size: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tpl.title).font(.headline)
                                        Text("Tap to change").font(.footnote).foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Event Name").foregroundStyle(.primary)
                                    Spacer()
                                    Text("Select Event").foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
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
                                Text(selectedLocationNameSnapshot.trimmed.isEmpty ? "None" : selectedLocationNameSnapshot)
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
                            in: todayDay...,
                            displayedComponents: .date
                        )
                        .onChange(of: startDate) { _, _ in enforceNoPastScheduling() }

                        if occurrence == .onceOnly {
                            HStack {
                                Text("Finish Date")
                                Spacer()
                                Text("Not applicable")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Toggle("Finish Date", isOn: $finishDateEnabled)
                                .onChange(of: finishDateEnabled) { _, _ in enforceNoPastScheduling() }

                            if finishDateEnabled {
                                DatePicker(
                                    "Finish Date",
                                    selection: $finishDate,
                                    in: startDate...,
                                    displayedComponents: .date
                                )
                                .onChange(of: finishDate) { _, _ in enforceNoPastScheduling() }
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
                                                        .stroke(
                                                            isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                                            lineWidth: isSelected ? 2 : 1
                                                        )
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
                        enforceNoPastScheduling()
                    }

                    Section("Time") {
                        Toggle("Start Time", isOn: $startTimeEnabled)
                            .onChange(of: startTimeEnabled) { _, enabled in
                                if !enabled { alertMe = false }
                                enforceNoPastScheduling()
                            }

                        if startTimeEnabled {
                            DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                                .onChange(of: startTime) { _, _ in
                                    if durationEnabled { syncFinishTimeFromDuration() }
                                    enforceNoPastScheduling()
                                }
                        }

                        Toggle("Finish Time", isOn: $finishTimeEnabled)
                            .onChange(of: finishTimeEnabled) { _, _ in enforceNoPastScheduling() }

                        if finishTimeEnabled {
                            DatePicker("Finish Time", selection: $finishTime, displayedComponents: .hourAndMinute)
                                .onChange(of: finishTime) { _, _ in enforceNoPastScheduling() }
                        }

                        Toggle("Duration", isOn: $durationEnabled)
                            .onChange(of: durationEnabled) { _, enabled in
                                if enabled {
                                    if !startTimeEnabled { startTimeEnabled = true }
                                    syncFinishTimeFromDuration()
                                }
                                enforceNoPastScheduling()
                            }

                        if durationEnabled {
                            Stepper("Hours: \(durationHours)", value: $durationHours, in: 0...23)
                                .onChange(of: durationHours) { _, _ in
                                    if durationEnabled { syncFinishTimeFromDuration() }
                                    enforceNoPastScheduling()
                                }

                            Stepper("Minutes: \(durationMinutes)", value: $durationMinutes, in: 0...55, step: 5)
                                .onChange(of: durationMinutes) { _, _ in
                                    if durationEnabled { syncFinishTimeFromDuration() }
                                    enforceNoPastScheduling()
                                }

                            Text("If duration is set, Finish Time will be adjusted to Start Time + Duration.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Alerts") {
                        Toggle("Alert Me", isOn: $alertMe)
                            .onChange(of: alertMe) { _, enabled in
                                if enabled {
                                    if !startTimeEnabled { startTimeEnabled = true }
                                    if alertOffsetMinutes < 0 { alertOffsetMinutes = 10 }
                                }
                                enforceNoPastScheduling()
                            }
                            .disabled(!startTimeEnabled && !alertMe)

                        if alertMe {
                            Picker("When", selection: $alertOffsetMinutes) {
                                ForEach(alertOffsetOptions, id: \.minutes) { opt in
                                    Text(opt.label).tag(opt.minutes)
                                }
                            }
                            Text("You will be alerted \(alertOffsetLabel()) before the event starts.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Alerts for events are reminders before the start time.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onAppear { enforceNoPastScheduling() }
                .navigationTitle("Assign Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveAssignment() }
                            .disabled(!canSave)
                    }
                }
                .navigationDestination(isPresented: $showSelectEvent) {
                    SelectEventTemplateView(
                        selectedTemplateId: selectedTemplate?.id,
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

                if let localToastMessage {
                    ToastBannerView(message: localToastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
        }
    }

    private func syncFinishTimeFromDuration() {
        guard startTimeEnabled else { return }
        if !finishTimeEnabled { finishTimeEnabled = true }
        let totalMinutes = max(0, durationHours * 60 + durationMinutes)
        finishTime = Calendar.current.date(byAdding: .minute, value: totalMinutes, to: startTime) ?? startTime
    }

    private func saveAssignment() {
        enforceNoPastScheduling()

        guard let tpl = selectedTemplate else { return }
        guard !selectedChildIds.isEmpty else { return }

        let helper = helperText.trimmingCharacters(in: .whitespacesAndNewlines)
        let helperOrNil = helper.isEmpty ? nil : helper

        let start = startDate
        let end: Date? = (occurrence == .onceOnly) ? nil : (finishDateEnabled ? finishDate : nil)
        let weekdays = Array(selectedWeekdays).sorted()

        let startTimeValue: Date? = startTimeEnabled ? startTime : nil
        let finishTimeValue: Date? = finishTimeEnabled ? finishTime : nil
        let durationValue: Int? = durationEnabled ? max(0, durationHours * 60 + durationMinutes) : nil

        let alertOn = alertMe && startTimeValue != nil
        let offset: Int? = alertOn ? max(0, alertOffsetMinutes) : nil

        var skippedNames: [String] = []
        var createdCount = 0

        for cid in selectedChildIds {
            let proposed = EventAssignment(
                childId: cid,
                templateId: tpl.id,
                eventTitle: tpl.title,
                eventIcon: tpl.iconSymbol,
                helper: helperOrNil,
                isActive: isActive,
                startDate: start,
                endDate: end,
                occurrence: occurrence,
                weekdays: weekdays,
                startTime: startTimeValue,
                finishTime: finishTimeValue,
                durationMinutes: durationValue,
                locationId: selectedLocationId,
                locationNameSnapshot: selectedLocationNameSnapshot.trimmed,
                alertMe: alertOn,
                alertOffsetMinutes: offset,
                createdAt: Date(),
                updatedAt: Date()
            )

            if isExactDuplicateEvent(proposed) {
                skippedNames.append(childName(cid))
                continue
            }

            _ = appState.createEventAssignment(proposed)
            createdCount += 1
        }

        if createdCount > 0 {
            if !skippedNames.isEmpty {
                onShowWeeklyToast?("Already assigned to \(skippedNames.joined(separator: ", "))")
            }
            dismiss()
        } else {
            if !skippedNames.isEmpty {
                showLocalToast("Already assigned to \(skippedNames.joined(separator: ", "))")
            }
        }
    }
}
