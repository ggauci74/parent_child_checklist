//
//  AppState.swift
//  parent_child_checklist
//

import SwiftUI
import Combine
import Foundation
import CloudKit

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State (UI Source of Truth)
    @Published var children: [ChildProfile] = []
    @Published var tasks: [TaskItem] = [] // legacy / placeholder

    // Parent-created task library
    @Published var taskTemplates: [TaskTemplate] = []

    // Task assignments + completions
    @Published var taskAssignments: [TaskAssignment] = []
    @Published var taskCompletions: [TaskCompletionRecord] = []

    // Shared emoji library
    @Published var customEmojis: [String] = []

    // Event library (templates)
    @Published var eventTemplates: [EventTemplate] = []

    // Event assignments (per child)
    @Published var eventAssignments: [EventAssignment] = []

    // Locations (used by event assignments)
    @Published var locations: [LocationItem] = []

    // MARK: - CloudKit status (read-only phase)
    /// Whether we successfully loaded non-empty user data from CloudKit on this launch.
    @Published private(set) var cloudKitLoaded: Bool = false
    /// If bootstrap failed, any error message here (for logging/diagnostics UI if desired).
    @Published private(set) var cloudKitErrorMessage: String? = nil
    /// The resolved family context (shared vs. private owner, zone & FamilyMeta recordID).
    @Published private(set) var familyContext: FamilyCoordinator.FamilyContext? = nil

    private var cancellables = Set<AnyCancellable>()

    // MARK: - JSON Cache File Names
    private let childrenFileName = "children.json"
    private let taskTemplatesFileName = "taskTemplates.json"
    private let customEmojisFileName = "customEmojis.json"
    private let taskAssignmentsFileName = "taskAssignments.json"
    private let taskCompletionsFileName = "taskCompletions.json"
    private let eventTemplatesFileName = "eventTemplates.json"
    private let eventAssignmentsFileName = "eventAssignments.json"
    private let locationsFileName = "locations.json"

    // MARK: - CloudKit (read-only integration for now)
    /// Family data loader (bootstraps family & loads records); JSON remains as cache.
    private let familyStore = FamilyDataStore(containerIdentifier: nil)

    /// A lightweight coordinator we reuse to fetch the current FamilyContext
    /// (zone, database kind, FamilyMeta recordID) for future sharing UI.
    private let shareCoordinator = FamilyCoordinator(
        ck: CloudKitService(config: .init(containerIdentifier: nil))
    )

    // MARK: - Init
    init() {
        // Load local JSON cache first → immediate UI
        loadChildren()
        loadTaskTemplates()
        loadCustomEmojis()
        loadTaskAssignments()
        loadTaskCompletions()
        loadEventTemplates()
        loadEventAssignments()
        loadLocations()

        if children.isEmpty {
            seedSampleData()
        }

        // Debounced autosave to JSON (we'll add CloudKit writes later)
        setupAutoSave()

        // CloudKit bootstrap (read-only): load family if CloudKit already has user data
        Task {
            await bootstrapFromCloudKit()
        }
    }

    func seedSampleData() { }

    // MARK: - Calendar helpers (ISO-like, Monday-first)
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    // MARK: - Name normalization
    private func normalizedName(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsedSpaces = trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsedSpaces.lowercased()
    }

    // MARK: - Children uniqueness
    func isNameTaken(_ name: String, excluding childId: UUID? = nil) -> Bool {
        let target = normalizedName(name)
        guard !target.isEmpty else { return false }
        return children.contains { child in
            if let childId, child.id == childId { return false }
            return normalizedName(child.name) == target
        }
    }

    // MARK: - Task template uniqueness
    func isTaskTitleTaken(_ title: String, excluding templateId: UUID? = nil) -> Bool {
        let target = normalizedName(title)
        guard !target.isEmpty else { return false }
        return taskTemplates.contains { tpl in
            if let templateId, tpl.id == templateId { return false }
            return normalizedName(tpl.title) == target
        }
    }

    // MARK: - Event template uniqueness
    func isEventTitleTaken(_ title: String, excluding templateId: UUID? = nil) -> Bool {
        let target = normalizedName(title)
        guard !target.isEmpty else { return false }
        return eventTemplates.contains { tpl in
            if let templateId, tpl.id == templateId { return false }
            return normalizedName(tpl.title) == target
        }
    }

    // MARK: - Location uniqueness
    func isLocationNameTaken(_ name: String, excluding locationId: UUID? = nil) -> Bool {
        let target = normalizedName(name)
        guard !target.isEmpty else { return false }
        return locations.contains { loc in
            if let locationId, loc.id == locationId { return false }
            return normalizedName(loc.name) == target
        }
    }

    @discardableResult
    func updateChildColor(childId: UUID, newColorHex: String) -> Bool {
        let trimmed = newColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let idx = children.firstIndex(where: { $0.id == childId }) else { return false }
        children[idx].colorHex = trimmed
        return true
    }

    // MARK: - Child actions
    @discardableResult
    func createChild(name: String, colorHex: String) -> ChildProfile? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !isNameTaken(trimmed) else { return nil }

        let child = ChildProfile(name: trimmed, colorHex: colorHex, avatarId: nil)
        children.append(child)
        return child
    }

    func deleteChild(id: UUID) {
        children.removeAll { $0.id == id }
        tasks.removeAll { $0.childId == id }

        let assignmentIds = taskAssignments.filter { $0.childId == id }.map(\.id)
        taskAssignments.removeAll { $0.childId == id }
        taskCompletions.removeAll { assignmentIds.contains($0.assignmentId) }

        // remove event assignments for that child
        eventAssignments.removeAll { $0.childId == id }
    }

    @discardableResult
    func renameChild(id: UUID, newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !isNameTaken(trimmed, excluding: id) else { return false }
        guard let idx = children.firstIndex(where: { $0.id == id }) else { return false }
        children[idx].name = trimmed
        return true
    }

    // MARK: - Task Template CRUD
    @discardableResult
    func createTaskTemplate(title: String, iconSymbol: String, rewardPoints: Int = 1) -> TaskTemplate? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }
        guard !isTaskTitleTaken(trimmedTitle) else { return nil }

        let trimmedIcon = iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIcon.isEmpty else { return nil }

        let points = max(0, rewardPoints)
        let tpl = TaskTemplate(title: trimmedTitle, iconSymbol: trimmedIcon, rewardPoints: points)
        taskTemplates.append(tpl)
        return tpl
    }

    @discardableResult
    func updateTaskTemplate(id: UUID, newTitle: String, newIconSymbol: String, newRewardPoints: Int) -> Bool {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard !isTaskTitleTaken(trimmedTitle, excluding: id) else { return false }

        let trimmedIcon = newIconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIcon.isEmpty else { return false }

        guard let idx = taskTemplates.firstIndex(where: { $0.id == id }) else { return false }
        taskTemplates[idx].title = trimmedTitle
        taskTemplates[idx].iconSymbol = trimmedIcon
        taskTemplates[idx].rewardPoints = max(0, newRewardPoints)
        return true
    }

    private func isTaskTemplateAssigned(_ templateId: UUID) -> Bool {
        taskAssignments.contains { $0.templateId == templateId }
    }

    @discardableResult
    func deleteTaskTemplate(id: UUID) -> Bool {
        guard !isTaskTemplateAssigned(id) else { return false }
        taskTemplates.removeAll { $0.id == id }
        return true
    }

    // MARK: - Event Template CRUD
    @discardableResult
    func createEventTemplate(title: String, iconSymbol: String) -> EventTemplate? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }
        guard !isEventTitleTaken(trimmedTitle) else { return nil }

        let trimmedIcon = iconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIcon.isEmpty else { return nil }

        let tpl = EventTemplate(title: trimmedTitle, iconSymbol: trimmedIcon, createdAt: Date(), updatedAt: Date())
        eventTemplates.append(tpl)
        return tpl
    }

    @discardableResult
    func updateEventTemplate(id: UUID, newTitle: String, newIconSymbol: String) -> Bool {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        guard !isEventTitleTaken(trimmedTitle, excluding: id) else { return false }

        let trimmedIcon = newIconSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIcon.isEmpty else { return false }

        guard let idx = eventTemplates.firstIndex(where: { $0.id == id }) else { return false }
        eventTemplates[idx].title = trimmedTitle
        eventTemplates[idx].iconSymbol = trimmedIcon
        eventTemplates[idx].updatedAt = Date()
        return true
    }

    func deleteEventTemplate(id: UUID) {
        eventTemplates.removeAll { $0.id == id }
    }

    // MARK: - Avatar uniqueness + update
    func isAvatarTaken(_ avatarId: String, excluding childId: UUID? = nil) -> Bool {
        let t = avatarId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }

        return children.contains { child in
            if let childId, child.id == childId { return false }
            return child.avatarId == t
        }
    }

    @discardableResult
    func updateChildAvatar(childId: UUID, newAvatarId: String?) -> Bool {
        guard let idx = children.firstIndex(where: { $0.id == childId }) else { return false }

        // Allow clearing avatar (nil => "Not chosen yet")
        let trimmed = newAvatarId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            // Enforce uniqueness across other children
            guard !isAvatarTaken(trimmed, excluding: childId) else { return false }
            children[idx].avatarId = trimmed
        } else {
            children[idx].avatarId = nil
        }
        return true
    }

    // MARK: - Custom Emoji Library
    func isCustomEmojiTaken(_ emoji: String) -> Bool {
        let t = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        return customEmojis.contains(t)
    }

    @discardableResult
    func addCustomEmoji(_ emoji: String) -> Bool {
        let t = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard !isCustomEmojiTaken(t) else { return false }

        customEmojis.append(t)
        // De-duplicate while preserving order
        var seen = Set<String>()
        customEmojis = customEmojis.filter { seen.insert($0).inserted }
        return true
    }

    func deleteCustomEmoji(_ emoji: String) {
        let t = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        customEmojis.removeAll { $0 == t }
    }

    func deleteAllCustomEmojis() {
        customEmojis = []
    }

    // MARK: - Locations CRUD (rename propagation to event assignments)
    @discardableResult
    func createLocation(name: String) -> LocationItem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !isLocationNameTaken(trimmed) else { return nil }

        let loc = LocationItem(name: trimmed, createdAt: Date(), updatedAt: Date())
        locations.append(loc)
        return loc
    }

    /// Renaming updates all event assignments that reference this locationId
    @discardableResult
    func renameLocation(id: UUID, newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !isLocationNameTaken(trimmed, excluding: id) else { return false }
        guard let idx = locations.firstIndex(where: { $0.id == id }) else { return false }

        locations[idx].name = trimmed
        locations[idx].updatedAt = Date()

        for i in eventAssignments.indices {
            if eventAssignments[i].locationId == id {
                eventAssignments[i].locationNameSnapshot = trimmed
                eventAssignments[i].updatedAt = Date()
            }
        }
        return true
    }

    /// Delete allowed: unlink id but keep snapshot on existing assignments
    func deleteLocation(id: UUID) {
        locations.removeAll { $0.id == id }
        for i in eventAssignments.indices {
            if eventAssignments[i].locationId == id {
                eventAssignments[i].locationId = nil
                // keep snapshot
                eventAssignments[i].updatedAt = Date()
            }
        }
    }

    // MARK: - Event Assignment CRUD
    @discardableResult
    func createEventAssignment(_ assignment: EventAssignment) -> EventAssignment {
        eventAssignments.append(assignment)
        return assignment
    }

    @discardableResult
    func updateEventAssignment(_ updated: EventAssignment) -> Bool {
        guard let idx = eventAssignments.firstIndex(where: { $0.id == updated.id }) else { return false }

        // 1) Update the event assignment
        eventAssignments[idx] = updated

        // 2) STRICT MODE: resync schedule of all tasks linked to this event assignment
        for i in taskAssignments.indices {
            guard taskAssignments[i].linkedEventAssignmentId == updated.id else { continue }
            var t = taskAssignments[i]
            applyStrictLinkedEventSchedule(to: &t, event: updated)
            t.updatedAt = Date()
            taskAssignments[i] = t
        }
        return true
    }

    /// Applies the "linked schedule" rules to a task based on a linked event.
    /// Defaults:
    /// - occurrence matches event occurrence
    /// - weekdays match for specifiedDays
    /// - startDate cannot be earlier than event.startDate
    /// - if event has endDate, task must have an endDate and cannot exceed it
    private func applyLinkedEventSchedule(to task: inout TaskAssignment, event: EventAssignment) {
        // If event is inactive, we shouldn't keep a link (picker prevents linking, but this covers edits)
        if !event.isActive {
            task.linkedEventAssignmentId = nil
            return
        }

        // Map event occurrence -> task occurrence
        switch event.occurrence {
        case .onceOnly:
            task.occurrence = .onceOnly
            task.weekdays = [] // not used for onceOnly
            // Once-only means it occurs on the event's start date
            task.startDate = event.startDate
            task.endDate = nil

        case .specifiedDays:
            task.occurrence = .specifiedDays
            task.weekdays = event.weekdays.sorted()

            // Clamp task start date >= event start date
            if task.startDate < event.startDate {
                task.startDate = event.startDate
            }

            // Handle end date constraint
            if let eventEnd = event.endDate {
                // Task must have an end date if the event has one, and cannot exceed it
                if let taskEnd = task.endDate {
                    task.endDate = min(taskEnd, eventEnd)
                } else {
                    task.endDate = eventEnd
                }

                // Safety: ensure endDate isn't before startDate
                if let taskEnd = task.endDate, taskEnd < task.startDate {
                    task.endDate = task.startDate
                }
            } else {
                // Event has no end date: task end date can remain as-is (nil allowed)
                if let taskEnd = task.endDate, taskEnd < task.startDate {
                    task.endDate = task.startDate
                }
            }
        }
    }

    /// STRICT MODE:
    /// If a task is linked to an event assignment, the task's schedule must exactly match the event's schedule:
    /// - occurrence matches
    /// - weekdays match (for specifiedDays)
    /// - startDate matches exactly
    /// - endDate matches exactly (including nil)
    private func applyStrictLinkedEventSchedule(to task: inout TaskAssignment, event: EventAssignment) {
        // If event is inactive, unlink defensively (picker prevents linking but event can be edited)
        if !event.isActive {
            task.linkedEventAssignmentId = nil
            return
        }

        switch event.occurrence {
        case .onceOnly:
            task.occurrence = .onceOnly
            task.weekdays = []
            task.startDate = event.startDate
            task.endDate = nil

        case .specifiedDays:
            task.occurrence = .specifiedDays
            task.weekdays = event.weekdays.sorted()
            task.startDate = event.startDate
            task.endDate = event.endDate
        }
    }

    func deleteEventAssignment(id: UUID) {
        // 1) Find all tasks linked to this event assignment (Option A: dependent)
        let linkedTaskIds = taskAssignments
            .filter { $0.linkedEventAssignmentId == id }
            .map(\.id)

        // 2) Remove those task assignments
        taskAssignments.removeAll { $0.linkedEventAssignmentId == id }

        // 3) Remove any task completion records for the removed tasks
        taskCompletions.removeAll { linkedTaskIds.contains($0.assignmentId) }

        // 4) Finally remove the event assignment itself
        eventAssignments.removeAll { $0.id == id }
    }

    // MARK: - Task Assignment CRUD
    @discardableResult
    func createTaskAssignment(_ assignment: TaskAssignment) -> TaskAssignment {
        taskAssignments.append(assignment)
        return assignment
    }

    @discardableResult
    func updateTaskAssignment(_ updated: TaskAssignment) -> Bool {
        guard let idx = taskAssignments.firstIndex(where: { $0.id == updated.id }) else { return false }
        taskAssignments[idx] = updated
        return true
    }

    func deleteTaskAssignment(id: UUID) {
        taskAssignments.removeAll { $0.id == id }
        taskCompletions.removeAll { $0.assignmentId == id }
    }

    // MARK: - Date helpers
    private func dayOnly(_ date: Date) -> Date { isoCalendar.startOfDay(for: date) }

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

    // MARK: - Task assignments for a day
    func assignments(for childId: UUID, on selectedDate: Date) -> [TaskAssignment] {
        let d = dayOnly(selectedDate)
        return taskAssignments
            .filter { $0.childId == childId }
            .filter { assignment in
                let start = dayOnly(assignment.startDate)
                let end = assignment.endDate.map(dayOnly)
                switch assignment.occurrence {
                case .onceOnly:
                    return d == start
                case .specifiedDays:
                    guard d >= start else { return false }
                    if let end, d > end { return false }
                    let w = weekdayIndexMondayFirst(for: d)
                    return assignment.weekdays.contains(w)
                }
            }
            .sorted { a, b in
                if a.isActive != b.isActive { return a.isActive && !b.isActive }
                return a.taskTitle.localizedCaseInsensitiveCompare(b.taskTitle) == .orderedAscending
            }
    }

    // MARK: - Events for a day
    func events(for childId: UUID, on selectedDate: Date) -> [EventAssignment] {
        let d = dayOnly(selectedDate)
        return eventAssignments
            .filter { $0.childId == childId }
            .filter { assignment in
                let start = dayOnly(assignment.startDate)
                let end = assignment.endDate.map(dayOnly)
                switch assignment.occurrence {
                case .onceOnly:
                    return d == start
                case .specifiedDays:
                    guard d >= start else { return false }
                    if let end, d > end { return false }
                    let w = weekdayIndexMondayFirst(for: d)
                    return assignment.weekdays.contains(w)
                }
            }
            .sorted { a, b in
                // Active first
                if a.isActive != b.isActive { return a.isActive && !b.isActive }
                // Then by start time (nil last)
                switch (a.startTime, b.startTime) {
                case (nil, nil):
                    break
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                case (let ta?, let tb?):
                    if ta != tb { return ta < tb }
                }
                // Then title
                return a.eventTitle.localizedCaseInsensitiveCompare(b.eventTitle) == .orderedAscending
            }
    }

    // MARK: - Completion Helpers (tasks only)
    func completionRecord(for assignmentId: UUID, on date: Date) -> TaskCompletionRecord? {
        let d = dayOnly(date)
        return taskCompletions.first(where: { $0.assignmentId == assignmentId && dayOnly($0.day) == d })
    }

    func isCompleted(assignmentId: UUID, on date: Date) -> Bool {
        completionRecord(for: assignmentId, on: date) != nil
    }

    func toggleCompletion(assignmentId: UUID, on date: Date) {
        let d = dayOnly(date)
        if let idx = taskCompletions.firstIndex(where: { $0.assignmentId == assignmentId && dayOnly($0.day) == d }) {
            taskCompletions.remove(at: idx)
        } else {
            let rec = TaskCompletionRecord(assignmentId: assignmentId, day: d, completedAt: nil)
            taskCompletions.append(rec)
        }
    }

    // MARK: - Auto Save (JSON cache)
    private func setupAutoSave() {
        $children.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveChildren() }
            .store(in: &cancellables)

        $taskTemplates.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveTaskTemplates() }
            .store(in: &cancellables)

        $customEmojis.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveCustomEmojis() }
            .store(in: &cancellables)

        $taskAssignments.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveTaskAssignments() }
            .store(in: &cancellables)

        $taskCompletions.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveTaskCompletions() }
            .store(in: &cancellables)

        $eventTemplates.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveEventTemplates() }
            .store(in: &cancellables)

        $eventAssignments.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveEventAssignments() }
            .store(in: &cancellables)

        $locations.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveLocations() }
            .store(in: &cancellables)
    }

    // MARK: - Storage folder
    private func appFolderURL() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let folder = base.appendingPathComponent("parent_child_checklist", isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    // MARK: - JSON persistence helpers
    private func write<T: Encodable>(_ value: T, to url: URL, label: String) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("❌ Failed to save \(label): \(error)")
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL, label: String) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("❌ Failed to load \(label): \(error)")
            return nil
        }
    }

    // MARK: - JSON file URLs
    private func childrenFileURL()        -> URL { appFolderURL().appendingPathComponent(childrenFileName) }
    private func taskTemplatesFileURL()   -> URL { appFolderURL().appendingPathComponent(taskTemplatesFileName) }
    private func customEmojisFileURL()    -> URL { appFolderURL().appendingPathComponent(customEmojisFileName) }
    private func taskAssignmentsFileURL() -> URL { appFolderURL().appendingPathComponent(taskAssignmentsFileName) }
    private func taskCompletionsFileURL() -> URL { appFolderURL().appendingPathComponent(taskCompletionsFileName) }
    private func eventTemplatesFileURL()  -> URL { appFolderURL().appendingPathComponent(eventTemplatesFileName) }
    private func eventAssignmentsFileURL()-> URL { appFolderURL().appendingPathComponent(eventAssignmentsFileName) }
    private func locationsFileURL()       -> URL { appFolderURL().appendingPathComponent(locationsFileName) }

    // MARK: - JSON persistence (Children)
    private func saveChildren() { write(children, to: childrenFileURL(), label: "children") }
    private func loadChildren() { children = read([ChildProfile].self, from: childrenFileURL(), label: "children") ?? [] }

    // MARK: - JSON persistence (Task Templates)
    private func saveTaskTemplates() { write(taskTemplates, to: taskTemplatesFileURL(), label: "task templates") }
    private func loadTaskTemplates() { taskTemplates = read([TaskTemplate].self, from: taskTemplatesFileURL(), label: "task templates") ?? [] }

    // MARK: - JSON persistence (Custom Emojis)
    private func saveCustomEmojis() { write(customEmojis, to: customEmojisFileURL(), label: "custom emojis") }
    private func loadCustomEmojis() { customEmojis = read([String].self, from: customEmojisFileURL(), label: "custom emojis") ?? [] }

    // MARK: - JSON persistence (Task Assignments)
    private func saveTaskAssignments() { write(taskAssignments, to: taskAssignmentsFileURL(), label: "task assignments") }
    private func loadTaskAssignments() { taskAssignments = read([TaskAssignment].self, from: taskAssignmentsFileURL(), label: "task assignments") ?? [] }

    // MARK: - JSON persistence (Task Completions)
    private func saveTaskCompletions() { write(taskCompletions, to: taskCompletionsFileURL(), label: "task completions") }
    private func loadTaskCompletions() { taskCompletions = read([TaskCompletionRecord].self, from: taskCompletionsFileURL(), label: "task completions") ?? [] }

    // MARK: - JSON persistence (Event Templates)
    private func saveEventTemplates() { write(eventTemplates, to: eventTemplatesFileURL(), label: "event templates") }
    private func loadEventTemplates() { eventTemplates = read([EventTemplate].self, from: eventTemplatesFileURL(), label: "event templates") ?? [] }

    // MARK: - JSON persistence (Event Assignments)
    private func saveEventAssignments() { write(eventAssignments, to: eventAssignmentsFileURL(), label: "event assignments") }
    private func loadEventAssignments() { eventAssignments = read([EventAssignment].self, from: eventAssignmentsFileURL(), label: "event assignments") ?? [] }

    // MARK: - JSON persistence (Locations)
    private func saveLocations() { write(locations, to: locationsFileURL(), label: "locations") }
    private func loadLocations() { locations = read([LocationItem].self, from: locationsFileURL(), label: "locations") ?? [] }

    // MARK: - CloudKit bootstrap (read-only)
    private func bootstrapFromCloudKit() async {
        do {
            // 1) Load snapshot of records from CloudKit (if any)
            let snapshot = try await familyStore.loadSnapshot()

            // 2) Also resolve the current family context (for sharing UI later)
            do {
                let s = try await shareCoordinator.bootstrapFamily()
                switch s {
                case .shared(let ctx), .privateOwner(let ctx):
                    self.familyContext = ctx
                }
            } catch {
                // Not fatal for data; just log for sharing UI
                print("⚠️ Failed to resolve FamilyContext: \(error)")
            }

            // 3) Only apply if CloudKit actually has user data
            guard FamilyDataStore.hasUserData(snapshot) else {
                cloudKitLoaded = false
                cloudKitErrorMessage = nil
                print("ℹ️ CloudKit snapshot empty — keeping local JSON as source for now.")
                return
            }

            // Apply snapshot to @Published arrays
            self.children        = snapshot.children
            self.taskTemplates   = snapshot.taskTemplates
            self.taskAssignments = snapshot.taskAssignments
            self.taskCompletions = snapshot.taskCompletions
            self.customEmojis    = snapshot.customEmojis
            self.eventTemplates  = snapshot.eventTemplates
            self.eventAssignments = snapshot.eventAssignments
            self.locations       = snapshot.locations

            cloudKitLoaded = true
            cloudKitErrorMessage = nil
            print("✅ CloudKit loaded family snapshot (\(children.count) children, \(taskTemplates.count) templates, \(eventTemplates.count) events)")

        } catch {
            cloudKitLoaded = false
            cloudKitErrorMessage = String(describing: error)
            print("❌ CloudKit bootstrap failed: \(error)")
        }
    }

    // MARK: - Helpers for Sharing UI (optional convenience)
    /// Return the correct CKDatabase for the current family context (or default private DB if unknown)
    func cloudDatabaseForCurrentFamily() -> CKDatabase {
        if let ctx = familyContext {
            switch ctx.database {
            case .private: return CKContainer.default().privateCloudDatabase
            case .shared:  return CKContainer.default().sharedCloudDatabase
            }
        }
        // Fallback
        return CKContainer.default().privateCloudDatabase
    }
}
