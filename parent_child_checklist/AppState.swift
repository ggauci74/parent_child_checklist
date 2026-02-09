//
// AppState.swift
// parent_child_checklist
//

import SwiftUI
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State
    @Published var children: [ChildProfile] = []
    @Published var tasks: [TaskItem] = [] // legacy / placeholder

    /// Parent-created task library
    @Published var taskTemplates: [TaskTemplate] = []

    /// Task assignments + completions
    @Published var taskAssignments: [TaskAssignment] = []
    @Published var taskCompletions: [TaskCompletionRecord] = []

    /// Shared emoji library
    @Published var customEmojis: [String] = []

    /// Event library (templates)
    @Published var eventTemplates: [EventTemplate] = []

    /// Event assignments (per child)
    @Published var eventAssignments: [EventAssignment] = []

    /// Locations (used by event assignments)
    @Published var locations: [LocationItem] = []

    private var cancellables = Set<AnyCancellable>()

    // MARK: - File names
    private let childrenFileName = "children.json"
    private let taskTemplatesFileName = "taskTemplates.json"
    private let customEmojisFileName = "customEmojis.json"
    private let taskAssignmentsFileName = "taskAssignments.json"
    private let taskCompletionsFileName = "taskCompletions.json"
    private let eventTemplatesFileName = "eventTemplates.json"
    private let eventAssignmentsFileName = "eventAssignments.json"
    private let locationsFileName = "locations.json"

    // MARK: - Init
    init() {
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
        setupAutoSave()
    }

    func seedSampleData() { }

    // ISO-like calendar (Monday-first)
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    // MARK: - Name normalization
    private func normalizedName(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsedSpaces = trimmed
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
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

    // MARK: - Avatar (preset) uniqueness + update
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
        customEmojis = Array(NSOrderedSet(array: customEmojis)) as? [String] ?? customEmojis
        return true
    }

    func deleteCustomEmoji(_ emoji: String) {
        let t = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        customEmojis.removeAll { $0 == t }
    }

    func deleteAllCustomEmojis() {
        customEmojis = []
    }

    // MARK: - Locations CRUD (rename propagation to event ASSIGNMENTS)
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

    // MARK: - Auto Save
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

    // MARK: - Persistence helpers
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

    // MARK: - Persistence URLs
    private func childrenFileURL() -> URL { appFolderURL().appendingPathComponent(childrenFileName) }
    private func taskTemplatesFileURL() -> URL { appFolderURL().appendingPathComponent(taskTemplatesFileName) }
    private func customEmojisFileURL() -> URL { appFolderURL().appendingPathComponent(customEmojisFileName) }
    private func taskAssignmentsFileURL() -> URL { appFolderURL().appendingPathComponent(taskAssignmentsFileName) }
    private func taskCompletionsFileURL() -> URL { appFolderURL().appendingPathComponent(taskCompletionsFileName) }
    private func eventTemplatesFileURL() -> URL { appFolderURL().appendingPathComponent(eventTemplatesFileName) }
    private func eventAssignmentsFileURL() -> URL { appFolderURL().appendingPathComponent(eventAssignmentsFileName) }
    private func locationsFileURL() -> URL { appFolderURL().appendingPathComponent(locationsFileName) }

    // MARK: - Persistence (Children)
    private func saveChildren() { write(children, to: childrenFileURL(), label: "children") }
    private func loadChildren() { children = read([ChildProfile].self, from: childrenFileURL(), label: "children") ?? [] }

    // MARK: - Persistence (Task Templates)
    private func saveTaskTemplates() { write(taskTemplates, to: taskTemplatesFileURL(), label: "task templates") }
    private func loadTaskTemplates() { taskTemplates = read([TaskTemplate].self, from: taskTemplatesFileURL(), label: "task templates") ?? [] }

    // MARK: - Persistence (Custom Emojis)
    private func saveCustomEmojis() { write(customEmojis, to: customEmojisFileURL(), label: "custom emojis") }
    private func loadCustomEmojis() { customEmojis = read([String].self, from: customEmojisFileURL(), label: "custom emojis") ?? [] }

    // MARK: - Persistence (Task Assignments)
    private func saveTaskAssignments() { write(taskAssignments, to: taskAssignmentsFileURL(), label: "task assignments") }
    private func loadTaskAssignments() { taskAssignments = read([TaskAssignment].self, from: taskAssignmentsFileURL(), label: "task assignments") ?? [] }

    // MARK: - Persistence (Task Completions)
    private func saveTaskCompletions() { write(taskCompletions, to: taskCompletionsFileURL(), label: "task completions") }
    private func loadTaskCompletions() { taskCompletions = read([TaskCompletionRecord].self, from: taskCompletionsFileURL(), label: "task completions") ?? [] }

    // MARK: - Persistence (Event Templates)
    private func saveEventTemplates() { write(eventTemplates, to: eventTemplatesFileURL(), label: "event templates") }
    private func loadEventTemplates() { eventTemplates = read([EventTemplate].self, from: eventTemplatesFileURL(), label: "event templates") ?? [] }

    // MARK: - Persistence (Event Assignments)
    private func saveEventAssignments() { write(eventAssignments, to: eventAssignmentsFileURL(), label: "event assignments") }
    private func loadEventAssignments() { eventAssignments = read([EventAssignment].self, from: eventAssignmentsFileURL(), label: "event assignments") ?? [] }

    // MARK: - Persistence (Locations)
    private func saveLocations() { write(locations, to: locationsFileURL(), label: "locations") }
    private func loadLocations() { locations = read([LocationItem].self, from: locationsFileURL(), label: "locations") ?? [] }
}
// MARK: - Add Task Template (Emoji-only picker + My Emojis sheet)
// MARK: - Add Task Template (Emoji-only picker + My Emojis sheet)
struct AddTaskTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var searchText: String = ""
    @State private var selectedEmoji: String? = nil
    @State private var selectedCategory: EmojiCatalog.Category = .all
    @State private var validationMessage: String? = nil
    @FocusState private var titleFocused: Bool

    // ✅ NEW: Reward points (default 1)
    @State private var rewardPoints: Int = 1

    // Sheet
    @State private var showMyEmojisSheet = false

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 8)

    private var trimmedTitle: String { title.trimmed }

    private var isDuplicate: Bool {
        !trimmedTitle.isEmpty && appState.isTaskTitleTaken(trimmedTitle)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !isDuplicate && (selectedEmoji != nil)
    }

    private var baseEmojis: [String] {
        switch selectedCategory {
        case .myEmojis:
            return appState.customEmojis
        case .all, .morning, .hygiene, .school, .chores, .food, .pets, .sports, .time, .rewards, .health, .outdoors:
            return EmojiCatalog.emojis(for: selectedCategory)
        }
    }

    private var filteredEmojis: [String] {
        let q = searchText.trimmed
        if q.isEmpty { return baseEmojis }
        return baseEmojis.filter { $0.contains(q) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)

                    if isDuplicate {
                        Text("That task already exists. Please choose a different name.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                // ✅ NEW: Reward Points UI
                Section("Reward Points") {
                    HStack {
                        Text("💎 Points")
                        Spacer()

                        Button {
                            rewardPoints = max(0, rewardPoints - 1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(rewardPoints == 0)
                        .accessibilityLabel("Decrease reward points")

                        Text("\(rewardPoints)")
                            .font(.headline)
                            .frame(minWidth: 32)

                        Button {
                            rewardPoints += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Increase reward points")
                    }
                }

                Section("Icon (Emoji)") {
                    HStack {
                        Text("Selected")
                        Spacer()
                        if let selectedEmoji {
                            Text(selectedEmoji).font(.system(size: 32))
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(EmojiCatalog.Category.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }

                    TextField("Search", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    // ✅ Stable layout inside Form
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(filteredEmojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                    validationMessage = nil
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 24))
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(selectedEmoji == emoji ? Color.blue.opacity(0.18) : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(
                                                    selectedEmoji == emoji ? Color.blue : Color.secondary.opacity(0.25),
                                                    lineWidth: selectedEmoji == emoji ? 2 : 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(emoji)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(minHeight: 240, maxHeight: 360)
                    .scrollIndicators(.visible)

                    if selectedCategory == .myEmojis, appState.customEmojis.isEmpty {
                        Text("No saved emojis yet. Tap “Manage My Emojis” below to add some.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Bottom button (keeps main UI clean)
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        showMyEmojisSheet = true
                    } label: {
                        HStack {
                            Text("Manage My Emojis")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.up")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showMyEmojisSheet) {
                CustomEmojiLibraryView { picked in
                    selectedEmoji = picked
                    // Convenience: switch category to My Emojis after picking
                    selectedCategory = .myEmojis
                    searchText = ""
                }
                .environmentObject(appState)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    titleFocused = true
                }
            }
            .onChange(of: title) { _, _ in validationMessage = nil }
            .onChange(of: selectedCategory) { _, _ in
                searchText = ""
            }
        }
    }

    private func save() {
        validationMessage = nil

        guard !trimmedTitle.isEmpty else {
            validationMessage = "Please enter a task title."
            return
        }

        guard !isDuplicate else {
            validationMessage = "That task already exists. Please choose a different name."
            return
        }

        guard let emoji = selectedEmoji, !emoji.trimmed.isEmpty else {
            validationMessage = "Please select an emoji."
            return
        }

        let points = max(0, rewardPoints)

        if appState.createTaskTemplate(title: trimmedTitle, iconSymbol: emoji, rewardPoints: points) != nil {
            dismiss()
        } else {
            validationMessage = "Couldn’t create task. Please try again."
        }
    }
}

// MARK: - Edit Task Template (Emoji-only picker + My Emojis sheet)
struct EditTaskTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let template: TaskTemplate

    @State private var title: String
    @State private var searchText: String = ""
    @State private var selectedEmoji: String
    @State private var selectedCategory: EmojiCatalog.Category = .all
    @State private var validationMessage: String? = nil
    @FocusState private var titleFocused: Bool
    @State private var showMyEmojisSheet = false

    // ✅ NEW: Reward points
    @State private var rewardPoints: Int

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 8)

    init(template: TaskTemplate) {
        self.template = template
        _title = State(initialValue: template.title)
        _selectedEmoji = State(initialValue: template.iconSymbol)
        _rewardPoints = State(initialValue: max(0, template.rewardPoints))
    }

    private var trimmedTitle: String { title.trimmed }

    private var isDuplicate: Bool {
        !trimmedTitle.isEmpty && appState.isTaskTitleTaken(trimmedTitle, excluding: template.id)
    }

    private var hasChanges: Bool {
        trimmedTitle != template.title.trimmed ||
        selectedEmoji != template.iconSymbol ||
        rewardPoints != max(0, template.rewardPoints)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !isDuplicate && selectedEmoji.trimmed.containsEmoji && hasChanges
    }

    private var baseEmojis: [String] {
        switch selectedCategory {
        case .myEmojis:
            return appState.customEmojis
        case .all, .morning, .hygiene, .school, .chores, .food, .pets, .sports, .time, .rewards, .health, .outdoors:
            return EmojiCatalog.emojis(for: selectedCategory)
        }
    }

    private var filteredEmojis: [String] {
        let q = searchText.trimmed
        if q.isEmpty { return baseEmojis }
        return baseEmojis.filter { $0.contains(q) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)

                    if isDuplicate {
                        Text("That task already exists. Please choose a different name.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let validationMessage {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                // ✅ NEW: Reward Points UI
                Section("Reward Points") {
                    HStack {
                        Text("💎 Points")
                        Spacer()

                        Button {
                            rewardPoints = max(0, rewardPoints - 1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(rewardPoints == 0)
                        .accessibilityLabel("Decrease reward points")

                        Text("\(rewardPoints)")
                            .font(.headline)
                            .frame(minWidth: 32)

                        Button {
                            rewardPoints += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Increase reward points")
                    }
                }
                
                Section("Icon (Emoji)") {
                    HStack {
                        Text("Selected")
                        Spacer()
                        Text(selectedEmoji.trimmed.containsEmoji ? selectedEmoji : "✅")
                            .font(.system(size: 32))
                    }

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(EmojiCatalog.Category.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }

                    TextField("Search", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(filteredEmojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                    validationMessage = nil
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 24))
                                        .frame(maxWidth: .infinity, minHeight: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(selectedEmoji == emoji ? Color.blue.opacity(0.18) : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(
                                                    selectedEmoji == emoji ? Color.blue : Color.secondary.opacity(0.25),
                                                    lineWidth: selectedEmoji == emoji ? 2 : 1
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(emoji)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(minHeight: 240, maxHeight: 360)
                    .scrollIndicators(.visible)

                    if selectedCategory == .myEmojis, appState.customEmojis.isEmpty {
                        Text("No saved emojis yet. Tap “Manage My Emojis” below to add some.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        showMyEmojisSheet = true
                    } label: {
                        HStack {
                            Text("Manage My Emojis")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.up")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showMyEmojisSheet) {
                CustomEmojiLibraryView { picked in
                    selectedEmoji = picked
                    selectedCategory = .myEmojis
                    searchText = ""
                }
                .environmentObject(appState)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    titleFocused = true
                }
            }
            .onChange(of: title) { _, _ in validationMessage = nil }
            .onChange(of: selectedCategory) { _, _ in
                searchText = ""
            }
        }
    }

    private func save() {
        validationMessage = nil

        guard !trimmedTitle.isEmpty else {
            validationMessage = "Task title cannot be empty."
            return
        }

        guard !isDuplicate else {
            validationMessage = "That task already exists. Please choose a different name."
            return
        }

        guard selectedEmoji.trimmed.containsEmoji else {
            validationMessage = "Please select an emoji."
            return
        }

        let points = max(0, rewardPoints)

        let ok = appState.updateTaskTemplate(
            id: template.id,
            newTitle: trimmedTitle,
            newIconSymbol: selectedEmoji.trimmed,
            newRewardPoints: points
        )

        if ok {
            dismiss()
        } else {
            validationMessage = "Couldn’t save changes. Try again."
        }
    }
}
