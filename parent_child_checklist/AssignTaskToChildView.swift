import SwiftUI

struct AssignTaskToChildView: View {
    let childId: UUID
    let defaultStartDate: Date
    let onShowWeeklyToast: ((String) -> Void)?

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // ✅ Multi-child selection
    @State private var selectedChildIds: Set<UUID>

    // Template selection
    @State private var selectedTemplate: TaskTemplate? = nil
    @State private var showSelectTask = false

    // ✅ Linked Event (adaptive)
    // - Single child: store selected EventAssignment id
    @State private var linkedEventAssignmentId: UUID? = nil
    // - Multi child: store selected EventTemplate id
    @State private var linkedEventTemplateId: UUID? = nil
    @State private var showSelectLinkedEvent = false

    // Fields
    @State private var helperText: String = ""
    @State private var rewardPoints: Int = 0
    @State private var subtractIfNotCompleted: Bool = false
    @State private var isActive: Bool = true

    // Dates
    @State private var startDate: Date
    @State private var finishDateEnabled: Bool = false
    @State private var finishDate: Date

    // Occurrence
    @State private var occurrence: TaskAssignment.Occurrence = .specifiedDays
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

    // Options
    @State private var alertMe: Bool = false
    @State private var photoEvidence: Bool = false

    // ✅ Local toast (sheet)
    @State private var localToastMessage: String? = nil

    // ✅ Rate-limit clamp toasts to avoid spam while spinning pickers
    @State private var lastClampToastAt: Date = .distantPast

    // MARK: - Init
    init(
        childId: UUID,
        defaultStartDate: Date,
        onShowWeeklyToast: ((String) -> Void)? = nil
    ) {
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

    private var isMultiChild: Bool { selectedChildIds.count > 1 }
    private var singleSelectedChildId: UUID { selectedChildIds.first ?? childId }

    // MARK: - Linked Event display helpers
    private var linkedEventSingle: EventAssignment? {
        guard let id = linkedEventAssignmentId else { return nil }
        return appState.eventAssignments.first(where: { $0.id == id })
    }

    private var linkedEventTemplate: EventTemplate? {
        guard let tid = linkedEventTemplateId else { return nil }
        return appState.eventTemplates.first(where: { $0.id == tid })
    }

    private var linkedEventDisplayText: String {
        if isMultiChild {
            guard let tpl = linkedEventTemplate else { return "None" }
            let title = tpl.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "Untitled Event" : title
        } else {
            guard let e = linkedEventSingle else { return "None" }
            let title = e.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "Untitled Event" : title
        }
    }

    // ✅ STRICT MODE: schedule fields are locked while linked
    private var isScheduleLockedByEvent: Bool {
        (linkedEventAssignmentId != nil) || (isMultiChild && linkedEventTemplateId != nil)
    }

    // MARK: - Calendar helpers (duplicate detection + event validity)
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private func dayOnly(_ date: Date) -> Date {
        isoCalendar.startOfDay(for: date)
    }

    private func timeKey(_ time: Date) -> Int {
        let comps = isoCalendar.dateComponents([.hour, .minute], from: time)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    private func normalizedOptionalString(_ s: String?) -> String? {
        let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    // Monday-first weekday index: 0=Mon ... 6=Sun
    private func weekdayIndexMondayFirst(for date: Date) -> Int {
        let weekday = isoCalendar.component(.weekday, from: date)
        switch weekday {
        case 2: return 0
        case 3: return 1
        case 4: return 2
        case 5: return 3
        case 6: return 4
        case 7: return 5
        default: return 6
        }
    }

    // MARK: - ✅ No-past scheduling rules (Assign Task)
    private var todayDay: Date { dayOnly(Date()) }

    private func clampToast(_ message: String) {
        let now = Date()
        guard now.timeIntervalSince(lastClampToastAt) > 1.0 else { return }
        lastClampToastAt = now
        showLocalToast(message)
    }

    private func enforceNoPastScheduling() {
        let now = Date()
        let today = todayDay

        // Clamp defaultStartDate if user opened sheet from a past day
        if dayOnly(startDate) < today {
            startDate = today
            if finishDateEnabled && dayOnly(finishDate) < dayOnly(startDate) {
                finishDate = startDate
            }
            clampToast("Start date adjusted to today.")
        }

        // Finish Date >= Start Date
        if finishDateEnabled && dayOnly(finishDate) < dayOnly(startDate) {
            finishDate = startDate
            clampToast("Finish date adjusted to match start date.")
        }

        // If startDate is today: times must be >= now
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

        // finishTime >= startTime if both enabled
        if startTimeEnabled && finishTimeEnabled {
            if timeKey(finishTime) < timeKey(startTime) {
                finishTime = startTime
                clampToast("Finish time adjusted to be after start time.")
            }
        }

        // Duration rule: keep finish in sync and re-check ordering
        if durationEnabled {
            syncFinishTimeFromDuration()
            if startTimeEnabled && finishTimeEnabled, timeKey(finishTime) < timeKey(startTime) {
                finishTime = startTime
                clampToast("Finish time adjusted to be after start time.")
            }
        }
    }

    // MARK: - Linked-event validity (bulk mode)
    private func nextOccurrenceDay(for ev: EventAssignment, onOrAfter fromDay: Date) -> Date? {
        guard ev.occurrence == .specifiedDays else {
            return dayOnly(ev.startDate)
        }
        let startWindow = max(dayOnly(ev.startDate), fromDay)
        let endWindow = ev.endDate.map(dayOnly)
        if let endWindow, endWindow < startWindow { return nil }
        if ev.weekdays.isEmpty { return nil }

        for offset in 0..<14 {
            guard let candidate = isoCalendar.date(byAdding: .day, value: offset, to: startWindow) else { continue }
            let candDay = dayOnly(candidate)
            if let endWindow, candDay > endWindow { return nil }
            let w = weekdayIndexMondayFirst(for: candDay)
            if ev.weekdays.contains(w) { return candDay }
        }
        return nil
    }

    private func isLinkableEventAssignment(_ ev: EventAssignment, minimumStartDate: Date) -> Bool {
        guard ev.isActive else { return false }
        let minDay = dayOnly(minimumStartDate)
        switch ev.occurrence {
        case .onceOnly:
            return dayOnly(ev.startDate) >= minDay
        case .specifiedDays:
            return nextOccurrenceDay(for: ev, onOrAfter: minDay) != nil
        }
    }

    private func matchingAssignments(childId: UUID, templateId: UUID, minimumStartDate: Date) -> [EventAssignment] {
        appState.eventAssignments.filter { ev in
            ev.childId == childId &&
            ev.templateId == templateId &&
            isLinkableEventAssignment(ev, minimumStartDate: minimumStartDate)
        }
    }

    private func uniqueEventAssignment(childId: UUID, templateId: UUID, minimumStartDate: Date) -> EventAssignment? {
        let matches = matchingAssignments(childId: childId, templateId: templateId, minimumStartDate: minimumStartDate)
        return matches.count == 1 ? matches[0] : nil
    }

    private func isTemplateValidForSelectedChildren(templateId: UUID, selectedChildIds: Set<UUID>, minimumStartDate: Date) -> Bool {
        guard !selectedChildIds.isEmpty else { return false }
        for cid in selectedChildIds {
            if uniqueEventAssignment(childId: cid, templateId: templateId, minimumStartDate: minimumStartDate) == nil {
                return false
            }
        }
        return true
    }

    // MARK: - Duplicate detection (exact identical assignment)
    private func isExactDuplicateTask(_ proposed: TaskAssignment) -> Bool {
        appState.taskAssignments.contains { existing in
            guard existing.childId == proposed.childId else { return false }
            guard existing.templateId == proposed.templateId else { return false }

            // Snapshot identity
            guard existing.taskTitle == proposed.taskTitle else { return false }
            guard existing.taskIcon == proposed.taskIcon else { return false }
            guard existing.rewardPoints == proposed.rewardPoints else { return false }
            guard normalizedOptionalString(existing.helper) == normalizedOptionalString(proposed.helper) else { return false }

            // Options identity
            guard existing.subtractIfNotCompleted == proposed.subtractIfNotCompleted else { return false }
            guard existing.alertMe == proposed.alertMe else { return false }
            guard existing.photoEvidenceRequired == proposed.photoEvidenceRequired else { return false }
            guard existing.isActive == proposed.isActive else { return false }

            // Schedule identity
            guard dayOnly(existing.startDate) == dayOnly(proposed.startDate) else { return false }
            guard existing.endDate.map(dayOnly) == proposed.endDate.map(dayOnly) else { return false }
            guard existing.occurrence == proposed.occurrence else { return false }
            guard existing.weekdays.sorted() == proposed.weekdays.sorted() else { return false }

            // Time identity
            func keyOpt(_ d: Date?) -> Int? { d.map(timeKey) }
            guard keyOpt(existing.startTime) == keyOpt(proposed.startTime) else { return false }
            guard keyOpt(existing.finishTime) == keyOpt(proposed.finishTime) else { return false }
            guard existing.durationMinutes == proposed.durationMinutes else { return false }

            // Link identity
            guard existing.linkedEventAssignmentId == proposed.linkedEventAssignmentId else { return false }

            return true
        }
    }

    private func childName(_ id: UUID) -> String {
        appState.children.first(where: { $0.id == id })?.name ?? "Child"
    }

    // MARK: - Toast
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

    // MARK: - Child selection change handling (auto-convert + auto-clear)
    private func handleChildSelectionChange(old: Set<UUID>, new: Set<UUID>) {
        // Empty selection: clear link (no toast)
        if new.isEmpty {
            linkedEventAssignmentId = nil
            linkedEventTemplateId = nil
            return
        }

        let oldCount = old.count
        let newCount = new.count

        // Single -> Multi: convert assignment link into template link if possible
        if oldCount <= 1 && newCount > 1 {
            if let singleId = linkedEventAssignmentId,
               let ev = appState.eventAssignments.first(where: { $0.id == singleId }),
               let tplId = ev.templateId {

                if isTemplateValidForSelectedChildren(templateId: tplId, selectedChildIds: new, minimumStartDate: startDate) {
                    linkedEventTemplateId = tplId
                    linkedEventAssignmentId = nil
                } else {
                    linkedEventAssignmentId = nil
                    linkedEventTemplateId = nil
                    showLocalToast("Linked event cleared (not available for all selected children)")
                }
            } else if linkedEventAssignmentId != nil {
                linkedEventAssignmentId = nil
                showLocalToast("Linked event cleared (not available for all selected children)")
            }
        }

        // Multi -> Single: convert template link into assignment link for that child if possible
        if oldCount > 1 && newCount == 1 {
            if let tplId = linkedEventTemplateId, let onlyChild = new.first {
                if let ev = uniqueEventAssignment(childId: onlyChild, templateId: tplId, minimumStartDate: startDate) {
                    linkedEventAssignmentId = ev.id
                    linkedEventTemplateId = nil
                } else {
                    linkedEventTemplateId = nil
                    showLocalToast("Linked event cleared (not available for all selected children)")
                }
            }
        }

        // Still single: ensure linked assignment belongs to selected child
        if newCount == 1, let onlyChild = new.first, let linkedId = linkedEventAssignmentId {
            if let ev = appState.eventAssignments.first(where: { $0.id == linkedId }),
               ev.childId != onlyChild {
                linkedEventAssignmentId = nil
                showLocalToast("Linked event cleared (not available for all selected children)")
            }
        }

        // Still multi: ensure template remains valid
        if newCount > 1, let tplId = linkedEventTemplateId {
            if !isTemplateValidForSelectedChildren(templateId: tplId, selectedChildIds: new, minimumStartDate: startDate) {
                linkedEventTemplateId = nil
                showLocalToast("Linked event cleared (not available for all selected children)")
            }
        }
    }

    // MARK: - Strict mode (single child) local state alignment
    private func applyStrictLinkedEventToLocalState() {
        guard let ev = linkedEventSingle else { return }
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

    // MARK: - Duration rule
    private func syncFinishTimeFromDuration() {
        guard startTimeEnabled else { return }
        if !finishTimeEnabled { finishTimeEnabled = true }
        let totalMinutes = max(0, durationHours * 60 + durationMinutes)
        finishTime = Calendar.current.date(byAdding: .minute, value: totalMinutes, to: startTime) ?? startTime
    }

    // MARK: - View building blocks
    private var taskPickerRow: some View {
        Button {
            showSelectTask = true
        } label: {
            HStack(spacing: 12) {
                if let tpl = selectedTemplate {
                    TaskEmojiIconView(icon: tpl.iconSymbol, size: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tpl.title).font(.headline)
                        Text("Tap to change").font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Task Name").foregroundStyle(.primary)
                    Spacer()
                    Text("Select Task").foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var assignToSection: some View {
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
        .onChange(of: selectedChildIds) { old, new in
            handleChildSelectionChange(old: old, new: new)
        }
    }

    private var linkedEventSection: some View {
        Section("Linked Event (Optional)") {
            Button {
                showSelectLinkedEvent = true
            } label: {
                HStack {
                    Text("Linked Event")
                    Spacer()
                    Text(linkedEventDisplayText).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if linkedEventAssignmentId != nil || linkedEventTemplateId != nil {
                Button(role: .destructive) {
                    linkedEventAssignmentId = nil
                    linkedEventTemplateId = nil
                } label: { Text("Remove Link") }

                if isMultiChild {
                    Text("This task’s schedule and date range will follow each child’s linked event.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("This task’s schedule and date range are controlled by the linked event.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                if isMultiChild {
                    Text("Only events that exist for all selected children can be linked.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Only active events that occur on or after the selected Start Date can be linked.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var rewardSection: some View {
        Section("Reward Points") {
            HStack {
                Text("💎 Points")
                Spacer()
                Button { rewardPoints = max(0, rewardPoints - 1) } label: {
                    Image(systemName: "minus.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(rewardPoints == 0)

                Text("\(rewardPoints)")
                    .font(.headline)
                    .frame(minWidth: 32)

                Button { rewardPoints += 1 } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
            }

            Toggle("Subtract points if not completed", isOn: $subtractIfNotCompleted)
                .font(.subheadline)

            Text("If enabled, points are deducted at end of day (11:59pm) when not completed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var datesSection: some View {
        Section("Dates") {
            DatePicker(
                "Start Date",
                selection: $startDate,
                in: todayDay...,
                displayedComponents: .date
            )
            .disabled(isScheduleLockedByEvent)

            if occurrence == .onceOnly {
                HStack {
                    Text("Finish Date")
                    Spacer()
                    Text("Not applicable").foregroundStyle(.secondary)
                }
            } else {
                Toggle("Finish Date", isOn: $finishDateEnabled)
                    .disabled(isScheduleLockedByEvent)

                if finishDateEnabled {
                    DatePicker(
                        "Finish Date",
                        selection: $finishDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                    .disabled(isScheduleLockedByEvent)
                } else {
                    Text("Finish Date not set.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: startDate) { _, _ in
            // If bulk linked template becomes invalid due to minimumStartDate change, clear it.
            if isMultiChild, let tplId = linkedEventTemplateId {
                if !isTemplateValidForSelectedChildren(templateId: tplId, selectedChildIds: selectedChildIds, minimumStartDate: startDate) {
                    linkedEventTemplateId = nil
                    showLocalToast("Linked event cleared (not available for all selected children)")
                }
            }
            enforceNoPastScheduling()
        }
        .onChange(of: finishDateEnabled) { _, _ in enforceNoPastScheduling() }
        .onChange(of: finishDate) { _, _ in enforceNoPastScheduling() }
    }

    private var occurrenceSection: some View {
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
                                            .stroke(
                                                isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                                lineWidth: isSelected ? 2 : 1
                                            )
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
            enforceNoPastScheduling()
        }
    }

    private var timeSection: some View {
        Section("Time") {
            Toggle("Start Time", isOn: $startTimeEnabled)
                .onChange(of: startTimeEnabled) { _, _ in
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
                .onChange(of: finishTimeEnabled) { _, newValue in
                    if !newValue { alertMe = false }
                    enforceNoPastScheduling()
                }

            if finishTimeEnabled {
                DatePicker("Finish Time", selection: $finishTime, displayedComponents: .hourAndMinute)
                    .onChange(of: finishTime) { _, _ in
                        enforceNoPastScheduling()
                    }
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
    }

    private var optionsSection: some View {
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
    }

    private var formContent: some View {
        Form {
            Section("Task") {
                taskPickerRow
                TextField("Helper (optional)", text: $helperText, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)

                Toggle("Active", isOn: $isActive)
            }

            assignToSection
            linkedEventSection
            rewardSection
            datesSection
            occurrenceSection
            timeSection
            optionsSection
        }
    }

    private var taskTemplateDestination: some View {
        SelectTaskTemplateView(
            selectedTemplateId: selectedTemplate?.id,
            onPick: { picked in
                selectedTemplate = picked
                rewardPoints = max(0, picked.rewardPoints)
            }
        )
        .environmentObject(appState)
    }

    private var linkedEventDestination: some View {
        Group {
            if isMultiChild {
                SelectLinkedEventTemplateView(
                    selectedChildIds: selectedChildIds,
                    minimumStartDate: startDate,
                    selectedTemplateId: $linkedEventTemplateId
                )
                .environmentObject(appState)
                .onDisappear {
                    if let tplId = linkedEventTemplateId,
                       !isTemplateValidForSelectedChildren(templateId: tplId, selectedChildIds: selectedChildIds, minimumStartDate: startDate) {
                        linkedEventTemplateId = nil
                        showLocalToast("Linked event cleared (not available for all selected children)")
                    }
                }
            } else {
                SelectLinkedEventAssignmentView(
                    childId: singleSelectedChildId,
                    minimumStartDate: startDate,
                    selectedEventAssignmentId: $linkedEventAssignmentId
                )
                .environmentObject(appState)
                .onDisappear {
                    if let linkedId = linkedEventAssignmentId,
                       let ev = appState.eventAssignments.first(where: { $0.id == linkedId }),
                       ev.childId != singleSelectedChildId {
                        linkedEventAssignmentId = nil
                        showLocalToast("Linked event cleared (not available for all selected children)")
                    }
                }
            }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                formContent

                if let localToastMessage {
                    ToastBannerView(message: localToastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .onAppear {
                enforceNoPastScheduling()
            }
            // Strict mode (single child): when link changes, force schedule to match event
            .onChange(of: linkedEventAssignmentId) { _, _ in
                if !isMultiChild {
                    applyStrictLinkedEventToLocalState()
                }
                enforceNoPastScheduling()
            }
            .navigationTitle("Assign Task")
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
            .navigationDestination(isPresented: $showSelectTask) {
                taskTemplateDestination
            }
            .navigationDestination(isPresented: $showSelectLinkedEvent) {
                linkedEventDestination
            }
        }
    }

    // MARK: - Save
    private func saveAssignment() {
        // Final safety: enforce rules just before save
        enforceNoPastScheduling()

        guard let tpl = selectedTemplate else { return }
        guard !selectedChildIds.isEmpty else { return }

        let helper = helperText.trimmingCharacters(in: .whitespacesAndNewlines)
        let helperOrNil = helper.isEmpty ? nil : helper

        // Base schedule from UI
        let baseEnd: Date? = (occurrence == .onceOnly) ? nil : (finishDateEnabled ? finishDate : nil)
        let baseWeekdays = Array(selectedWeekdays).sorted()

        // Times
        let startTimeValue: Date? = startTimeEnabled ? startTime : nil
        let finishTimeValue: Date? = finishTimeEnabled ? finishTime : nil
        let durationValue: Int? = durationEnabled ? max(0, durationHours * 60 + durationMinutes) : nil

        var skippedNames: [String] = []
        var createdCount = 0

        for cid in selectedChildIds {
            var effectiveOccurrence = occurrence
            var effectiveStartDate = startDate
            var effectiveEndDate = baseEnd
            var effectiveWeekdays = baseWeekdays
            var linkedEventIdForChild: UUID? = nil

            // Multi-child + linked event template: resolve to each child’s unique EventAssignment and strictly follow it.
            if isMultiChild, let tplId = linkedEventTemplateId {
                guard let ev = uniqueEventAssignment(childId: cid, templateId: tplId, minimumStartDate: startDate) else {
                    continue
                }
                linkedEventIdForChild = ev.id
                switch ev.occurrence {
                case .onceOnly:
                    effectiveOccurrence = .onceOnly
                    effectiveWeekdays = []
                    effectiveStartDate = ev.startDate
                    effectiveEndDate = nil
                case .specifiedDays:
                    effectiveOccurrence = .specifiedDays
                    effectiveWeekdays = ev.weekdays.sorted()
                    effectiveStartDate = ev.startDate
                    effectiveEndDate = ev.endDate
                }
            } else {
                // Single-child link uses direct assignment id
                linkedEventIdForChild = linkedEventAssignmentId
            }

            let proposed = TaskAssignment(
                childId: cid,
                templateId: tpl.id,
                taskTitle: tpl.title,
                taskIcon: tpl.iconSymbol,
                rewardPoints: max(0, rewardPoints),
                helper: helperOrNil,
                subtractIfNotCompleted: subtractIfNotCompleted,
                alertMe: alertMe,
                photoEvidenceRequired: photoEvidence,
                isActive: isActive,
                startDate: effectiveStartDate,
                endDate: effectiveEndDate,
                occurrence: effectiveOccurrence,
                weekdays: effectiveWeekdays,
                startTime: startTimeValue,
                finishTime: finishTimeValue,
                durationMinutes: durationValue,
                linkedEventAssignmentId: linkedEventIdForChild,
                createdAt: Date(),
                updatedAt: Date()
            )

            if isExactDuplicateTask(proposed) {
                skippedNames.append(childName(cid))
                continue
            }

            _ = appState.createTaskAssignment(proposed)
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
            // Stay open so parent can adjust and try again
        }
    }
}
