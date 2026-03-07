//
// AppState.swift
// parent_child_checklist
//

import SwiftUI
import UIKit
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
    // Append-only points ledger
    @Published var pointsLedger: [PointsEntry] = []
    // Requests
    @Published var rewardRequests: [RewardRequest] = []

    // MARK: - CloudKit status (read-only phase)
    @Published private(set) var cloudKitLoaded: Bool = false
    @Published private(set) var cloudKitErrorMessage: String? = nil
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
    private let pointsLedgerFileName = "pointsLedger.json"
    private let rewardRequestsFileName = "rewardRequests.json"

    // MARK: - CloudKit integration
    private let familyStore = FamilyDataStore(containerIdentifier: nil) // read-only snapshot loader
    private let shareCoordinator = FamilyCoordinator(ck: CloudKitService(config: .init(containerIdentifier: nil)))
    private let ck = CloudKitService(config: .init(containerIdentifier: nil)) // used for immediate writes (photo assets)

    // MARK: - Rolling window config
    /// Keep only the latest N days of detailed ledger, snapshot older entries.
    private let ledgerKeepDays: Int = 90
    /// Expose in case views want to align their cutoffs
    var ledgerWindowDays: Int { ledgerKeepDays }

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
        loadPointsLedger()
        loadRewardRequests()

        if children.isEmpty {
            seedSampleData()
        }

        setupAutoSave()

        // CloudKit bootstrap (read-only): load family if CloudKit already has user data
        Task { await bootstrapFromCloudKit() }

        // 🔹 Apply rolling-window compaction on app start
        compactLedgerRollingWindow()
    }

    func seedSampleData() { }

    // MARK: - Calendar helpers (ISO-like, Monday-first)
    private var isoCalendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }
    private func dayOnly(_ date: Date) -> Date { isoCalendar.startOfDay(for: date) }

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

    // MARK: - Task / Event template uniqueness
    func isTaskTitleTaken(_ title: String, excluding templateId: UUID? = nil) -> Bool {
        let target = normalizedName(title)
        guard !target.isEmpty else { return false }
        return taskTemplates.contains { tpl in
            if let templateId, tpl.id == templateId { return false }
            return normalizedName(tpl.title) == target
        }
    }
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
        eventAssignments.removeAll { $0.childId == id }
        // Keep points ledger for audit (but remove per-child entries for deleted child)
        pointsLedger.removeAll { $0.childId == id }
        rewardRequests.removeAll { $0.childId == id }
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

    func deleteLocation(id: UUID) {
        locations.removeAll { $0.id == id }
        for i in eventAssignments.indices {
            if eventAssignments[i].locationId == id {
                eventAssignments[i].locationId = nil
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
        eventAssignments[idx] = updated

        // STRICT MODE: resync schedule of all tasks linked to this event assignment
        for i in taskAssignments.indices {
            guard taskAssignments[i].linkedEventAssignmentId == updated.id else { continue }
            var t = taskAssignments[i]
            applyStrictLinkedEventSchedule(to: &t, event: updated)
            t.updatedAt = Date()
            taskAssignments[i] = t
        }
        return true
    }

    // ✅ FIXED: non-strict linker (assign back to task.endDate, never to a `let`)
    private func applyLinkedEventSchedule(to task: inout TaskAssignment, event: EventAssignment) {
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

            // Ensure task start is not before the event start
            if task.startDate < event.startDate {
                task.startDate = event.startDate
            }

            if let eventEnd = event.endDate {
                // If task already has an end date, clamp it to eventEnd; otherwise adopt eventEnd
                if let currentTaskEnd = task.endDate {
                    task.endDate = min(currentTaskEnd, eventEnd)
                } else {
                    task.endDate = eventEnd
                }
                // Never let end be before start
                if let currentTaskEnd = task.endDate, currentTaskEnd < task.startDate {
                    task.endDate = task.startDate
                }
            } else {
                // Event has no end; ensure task.endDate (if present) is not before start
                if let currentTaskEnd = task.endDate, currentTaskEnd < task.startDate {
                    task.endDate = task.startDate
                }
            }
        }
    }

    private func applyStrictLinkedEventSchedule(to task: inout TaskAssignment, event: EventAssignment) {
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
        let linkedTaskIds = taskAssignments
            .filter { $0.linkedEventAssignmentId == id }
            .map(\.id)
        taskAssignments.removeAll { $0.linkedEventAssignmentId == id }
        taskCompletions.removeAll { linkedTaskIds.contains($0.assignmentId) }
        eventAssignments.removeAll { $0.id == id }
    }

    // MARK: - Task Assignment CRUD (basic)
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
                if a.isActive != b.isActive { return a.isActive && !b.isActive }
                switch (a.startTime, b.startTime) {
                case (nil, nil): break
                case (nil, _?): return false
                case (_?, nil): return true
                case (let ta?, let tb?): if ta != tb { return ta < tb }
                }
                return a.eventTitle.localizedCaseInsensitiveCompare(b.eventTitle) == .orderedAscending
            }
    }

    // MARK: - Completion Helpers + Points awarding

    func completionRecord(for assignmentId: UUID, on date: Date) -> TaskCompletionRecord? {
        let d = dayOnly(date)
        return taskCompletions.first { $0.assignmentId == assignmentId && dayOnly($0.day) == d }
    }

    func isCompleted(assignmentId: UUID, on date: Date) -> Bool {
        completionRecord(for: assignmentId, on: date) != nil
    }

    /// Standard toggle flow (no photo evidence path). If a completion exists → un-complete; else → complete.
    func toggleCompletion(assignmentId: UUID, on date: Date) {
        let d = dayOnly(date)

        if let idx = taskCompletions.firstIndex(where: { $0.assignmentId == assignmentId && dayOnly($0.day) == d }) {
            // UN-COMPLETE
            let rec = taskCompletions[idx]

            // 1) Remove locally
            taskCompletions.remove(at: idx)

            // 2) Remove in CloudKit (best effort)
            Task { await deleteCompletionFromCloudKit(rec) }

            // 3) Cleanup local photo file
            if let url = rec.photoEvidenceLocalURL {
                try? FileManager.default.removeItem(at: url)
            }

            // 4) Reverse points
            if let assignment = taskAssignments.first(where: { $0.id == assignmentId }) {
                let points = max(0, assignment.rewardPoints)
                guard points > 0 else { return }
                appendPointsEntry(childId: assignment.childId,
                                  assignmentId: assignmentId,
                                  day: d,
                                  delta: -points,
                                  reason: .completed)
            }
        } else {
            // COMPLETE (no photo evident path—this call is used by non-photo tasks)
            let rec = TaskCompletionRecord(assignmentId: assignmentId, day: d, completedAt: Date(), hasPhotoEvidence: false)
            taskCompletions.append(rec)

            // (Optional) Save to CloudKit without asset (pure completion row)
            Task { await uploadCompletionToCloudKit(rec) }

            // Points
            if let assignment = taskAssignments.first(where: { $0.id == assignmentId }) {
                let points = max(0, assignment.rewardPoints)
                guard points > 0 else { return }
                appendPointsEntry(childId: assignment.childId,
                                  assignmentId: assignmentId,
                                  day: d,
                                  delta: points,
                                  reason: .completed)
            }
        }
    }

    /// NEW: Complete a task with required photo evidence (Option A: immediate CloudKit upload).
    func completeTaskWithPhoto(assignmentId: UUID, on date: Date, image: UIImage) {
        let d = dayOnly(date)

        // If already completed for the day, do nothing (or could replace photo in a future iteration)
        guard completionRecord(for: assignmentId, on: d) == nil else { return }

        // 1) Save image to a local Evidence folder (JPEG)
        guard let fileURL = savePhotoEvidenceToDisk(image) else {
            // If saving failed, we can still complete without photo to avoid blocking the child.
            let fallback = TaskCompletionRecord(assignmentId: assignmentId, day: d, completedAt: Date(), hasPhotoEvidence: false)
            taskCompletions.append(fallback)
            Task { await uploadCompletionToCloudKit(fallback) }
            awardPointsForCompletion(assignmentId: assignmentId, on: d)
            return
        }

        // 2) Create completion record marked with photo
        let rec = TaskCompletionRecord(
            assignmentId: assignmentId,
            day: d,
            completedAt: Date(),
            hasPhotoEvidence: true,
            photoEvidenceLocalURL: fileURL
        )
        taskCompletions.append(rec)

        // 3) Upload to CloudKit (record + CKAsset)
        Task { await uploadCompletionToCloudKit(rec) }

        // 4) Award points
        awardPointsForCompletion(assignmentId: assignmentId, on: d)
    }

    private func awardPointsForCompletion(assignmentId: UUID, on day: Date) {
        if let assignment = taskAssignments.first(where: { $0.id == assignmentId }) {
            let points = max(0, assignment.rewardPoints)
            guard points > 0 else { return }
            appendPointsEntry(childId: assignment.childId,
                              assignmentId: assignmentId,
                              day: dayOnly(day),
                              delta: points,
                              reason: .completed)
        }
    }

    // MARK: - CloudKit Upload/Delete for Completion

    private func uploadCompletionToCloudKit(_ rec: TaskCompletionRecord) async {
        guard let ctx = familyContext else { return } // if not available yet, skip (local JSON still holds it)
        let zoneID = ctx.zoneID
        let record = TaskCompletionRecordMapper.toRecord(rec, zoneID: zoneID)
        do {
            _ = try await ck.save(record, to: ctx.database)
        } catch {
            // best-effort: keep local; CloudKit may sync later after next bootstrap in future enhancement
            print("⚠️ uploadCompletionToCloudKit failed: \(error)")
        }
    }

    private func deleteCompletionFromCloudKit(_ rec: TaskCompletionRecord) async {
        guard let ctx = familyContext else { return }
        let recordID = CKID.recordID(type: CKSchema.RecordType.taskCompletion, uuid: rec.id, zoneID: ctx.zoneID)
        do {
            try await ck.delete(recordID: recordID, from: ctx.database)
        } catch {
            // best-effort
            print("⚠️ deleteCompletionFromCloudKit failed: \(error)")
        }
    }

    // MARK: - Photo Evidence Disk Helpers

    private func evidenceFolderURL() -> URL {
        let folder = appFolderURL().appendingPathComponent("Evidence", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    /// Saves `UIImage` to Evidence folder as a JPEG (quality 0.85). Returns file URL if successful.
    private func savePhotoEvidenceToDisk(_ image: UIImage) -> URL? {
        // Prefer JPEG to balance size/quality. Fall back to PNG if JPEG fails.
        let filename = UUID().uuidString + ".jpg"
        let url = evidenceFolderURL().appendingPathComponent(filename)

        let jpegQuality: CGFloat = 0.85
        if let data = image.jpegData(compressionQuality: jpegQuality) {
            do {
                try data.write(to: url, options: [.atomic])
                return url
            } catch {
                print("❌ Failed to write JPEG: \(error)")
            }
        }

        // Fallback PNG
        if let data = image.pngData() {
            do {
                try data.write(to: url, options: [.atomic])
                return url
            } catch {
                print("❌ Failed to write PNG: \(error)")
            }
        }
        return nil
    }

    // MARK: - Points & Ledger

    private func appendPointsEntry(childId: UUID, assignmentId: UUID?, day: Date, delta: Int, reason: PointsReason) {
        let entry = PointsEntry(
            childId: childId,
            assignmentId: assignmentId,
            day: dayOnly(day),
            delta: delta,
            reason: reason,
            createdAt: Date()
        )
        pointsLedger.append(entry)
    }

    func childPointsTotal(childId: UUID) -> Int {
        pointsLedger
            .filter { $0.childId == childId }
            .reduce(0) { $0 + $1.delta }
    }

    // MARK: - Reward Requests

    /// Create a new pending request from child
    @discardableResult
    func createRewardRequest(childId: UUID, title: String) -> RewardRequest? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let now = Date()
        let req = RewardRequest(
            childId: childId,
            title: t,
            status: .pending,
            approvedCost: nil,
            requestedAt: now,
            approvedAt: nil,
            notApprovedAt: nil,
            claimedAt: nil,
            updatedAt: now
        )
        rewardRequests.insert(req, at: 0) // newest first
        return req
    }

    /// Child can edit title only when pending
    @discardableResult
    func updateRewardRequestTitle(id: UUID, newTitle: String) -> Bool {
        let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        guard let idx = rewardRequests.firstIndex(where: { $0.id == id }) else { return false }
        guard rewardRequests[idx].status == .pending else { return false }
        rewardRequests[idx].title = t
        rewardRequests[idx].updatedAt = Date()
        return true
    }

    /// Child or parent can delete any request at any time (no refunds if already claimed)
    @discardableResult
    func deleteRewardRequest(id: UUID) -> Bool {
        if let idx = rewardRequests.firstIndex(where: { $0.id == id }) {
            rewardRequests.remove(at: idx)
            return true
        }
        return false
    }

    /// Parent: approve with a gem cost; can also refine the title before approving
    @discardableResult
    func approveRewardRequest(id: UUID, cost: Int, newTitle: String?) -> Bool {
        guard let idx = rewardRequests.firstIndex(where: { $0.id == id }) else { return false }
        guard rewardRequests[idx].status == .pending else { return false }
        let now = Date()
        let c = max(0, cost)
        rewardRequests[idx].approvedCost = c
        if let t = newTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            rewardRequests[idx].title = t
        }
        rewardRequests[idx].status = .approved
        rewardRequests[idx].approvedAt = now
        rewardRequests[idx].notApprovedAt = nil
        rewardRequests[idx].updatedAt = now
        return true
    }

    /// Parent: not approved ("Not this time")
    @discardableResult
    func notApproveRewardRequest(id: UUID) -> Bool {
        guard let idx = rewardRequests.firstIndex(where: { $0.id == id }) else { return false }
        guard rewardRequests[idx].status == .pending else { return false }
        let now = Date()
        rewardRequests[idx].approvedCost = nil
        rewardRequests[idx].status = .notApproved
        rewardRequests[idx].notApprovedAt = now
        rewardRequests[idx].approvedAt = nil
        rewardRequests[idx].updatedAt = now
        return true
    }

    /// Child: claim an approved request (must have enough gems)
    @discardableResult
    func claimRewardRequest(id: UUID) -> Bool {
        guard let idx = rewardRequests.firstIndex(where: { $0.id == id }) else { return false }
        var req = rewardRequests[idx]
        guard req.status == .approved, let cost = req.approvedCost, cost > 0 else { return false }
        let balance = childPointsTotal(childId: req.childId)
        guard balance >= cost else { return false }

        // Deduct gems now
        appendPointsEntry(
            childId: req.childId,
            assignmentId: nil,
            day: Date(),
            delta: -cost,
            reason: .redeemed
        )

        // Mark as claimed with timestamp
        let now = Date()
        req.status = .claimed
        req.claimedAt = now
        req.updatedAt = now
        rewardRequests[idx] = req

        // 🔹 Rolling window (after ledger change)
        compactLedgerRollingWindow()

        return true
    }

    /// Count for tab title (parent)
    var pendingRewardRequestsCount: Int {
        rewardRequests.filter { $0.status == .pending }.count
    }

    // MARK: - Manual balance adjustment (append-only ledger)

    /// Whether an adjustment would keep the child's balance >= 0
    func canAdjustChildPoints(childId: UUID, delta: Int) -> Bool {
        let newTotal = childPointsTotal(childId: childId) + delta
        return newTotal >= 0
    }

    /// Append a manual adjustment entry. Returns false if it would go below 0 (clamped).
    @discardableResult
    func adjustChildPoints(childId: UUID, delta: Int) -> Bool {
        guard canAdjustChildPoints(childId: childId, delta: delta) else { return false }
        appendPointsEntry(
            childId: childId,
            assignmentId: nil,
            day: Date(),
            delta: delta,
            reason: .manualAdjust
        )
        // 🔹 Rolling window (after ledger change)
        compactLedgerRollingWindow()
        return true
    }

    // MARK: - Rolling Window Compaction (keep last N days; snapshot older)
    /// Keeps per-child points history only for the last `ledgerKeepDays` days.
    /// Before-cutoff entries are reduced to a single snapshot "Balance carried forward".
    func compactLedgerRollingWindow() {
        let days = ledgerKeepDays
        guard days > 0 else { return }
        guard !pointsLedger.isEmpty else { return }

        let now = Date()
        guard let cutoffRaw = Calendar.current.date(byAdding: .day, value: -days, to: now) else { return }
        let cutoff = dayOnly(cutoffRaw)

        let childIds = Set(pointsLedger.map { $0.childId })
        var newLedger: [PointsEntry] = []
        newLedger.reserveCapacity(pointsLedger.count)

        for childId in childIds {
            let childEntries = pointsLedger.filter { $0.childId == childId }
            let oldEntries = childEntries.filter { dayOnly($0.day) < cutoff }
            let recentEntries = childEntries.filter { dayOnly($0.day) >= cutoff }

            let oldTotal = oldEntries.reduce(0) { $0 + $1.delta }

            if !oldEntries.isEmpty {
                if oldTotal != 0 {
                    // Snapshot carries forward exact balance up to cutoff
                    let snapshot = PointsEntry(
                        childId: childId,
                        assignmentId: nil,
                        day: cutoff,                 // start-of-day cutoff
                        delta: oldTotal,
                        reason: .manualAdjust,       // rendered as "Balance carried forward" in UI when detected at cutoff
                        createdAt: cutoff
                    )
                    newLedger.append(snapshot)
                }
                newLedger.append(contentsOf: recentEntries)
            } else {
                newLedger.append(contentsOf: recentEntries)
            }
        }

        // Sort by day then createdAt for stable ordering
        newLedger.sort {
            if dayOnly($0.day) != dayOnly($1.day) { return dayOnly($0.day) < dayOnly($1.day) }
            return $0.createdAt < $1.createdAt
        }

        if newLedger != pointsLedger {
            pointsLedger = newLedger
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

        $pointsLedger.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.savePointsLedger() }
            .store(in: &cancellables)

        $rewardRequests.dropFirst().debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.saveRewardRequests() }
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
    private func childrenFileURL() -> URL { appFolderURL().appendingPathComponent(childrenFileName) }
    private func taskTemplatesFileURL() -> URL { appFolderURL().appendingPathComponent(taskTemplatesFileName) }
    private func customEmojisFileURL() -> URL { appFolderURL().appendingPathComponent(customEmojisFileName) }
    private func taskAssignmentsFileURL() -> URL { appFolderURL().appendingPathComponent(taskAssignmentsFileName) }
    private func taskCompletionsFileURL() -> URL { appFolderURL().appendingPathComponent(taskCompletionsFileName) }
    private func eventTemplatesFileURL() -> URL { appFolderURL().appendingPathComponent(eventTemplatesFileName) }
    private func eventAssignmentsFileURL() -> URL { appFolderURL().appendingPathComponent(eventAssignmentsFileName) }
    private func locationsFileURL() -> URL { appFolderURL().appendingPathComponent(locationsFileName) }
    private func pointsLedgerFileURL() -> URL { appFolderURL().appendingPathComponent(pointsLedgerFileName) }
    private func rewardRequestsFileURL() -> URL { appFolderURL().appendingPathComponent(rewardRequestsFileName) }

    // MARK: - JSON persistence
    private func saveChildren() { write(children, to: childrenFileURL(), label: "children") }
    private func loadChildren() { children = read([ChildProfile].self, from: childrenFileURL(), label: "children") ?? [] }

    private func saveTaskTemplates() { write(taskTemplates, to: taskTemplatesFileURL(), label: "task templates") }
    private func loadTaskTemplates() { taskTemplates = read([TaskTemplate].self, from: taskTemplatesFileURL(), label: "task templates") ?? [] }

    private func saveCustomEmojis() { write(customEmojis, to: customEmojisFileURL(), label: "custom emojis") }
    private func loadCustomEmojis() { customEmojis = read([String].self, from: customEmojisFileURL(), label: "custom emojis") ?? [] }

    private func saveTaskAssignments() { write(taskAssignments, to: taskAssignmentsFileURL(), label: "task assignments") }
    private func loadTaskAssignments() { taskAssignments = read([TaskAssignment].self, from: taskAssignmentsFileURL(), label: "task assignments") ?? [] }

    private func saveTaskCompletions() { write(taskCompletions, to: taskCompletionsFileURL(), label: "task completions") }
    private func loadTaskCompletions() { taskCompletions = read([TaskCompletionRecord].self, from: taskCompletionsFileURL(), label: "task completions") ?? [] }

    private func saveEventTemplates() { write(eventTemplates, to: eventTemplatesFileURL(), label: "event templates") }
    private func loadEventTemplates() { eventTemplates = read([EventTemplate].self, from: eventTemplatesFileURL(), label: "event templates") ?? [] }

    private func saveEventAssignments() { write(eventAssignments, to: eventAssignmentsFileURL(), label: "event assignments") }
    private func loadEventAssignments() { eventAssignments = read([EventAssignment].self, from: eventAssignmentsFileURL(), label: "event assignments") ?? [] }

    private func saveLocations() { write(locations, to: locationsFileURL(), label: "locations") }
    private func loadLocations() { locations = read([LocationItem].self, from: locationsFileURL(), label: "locations") ?? [] }

    private func savePointsLedger() { write(pointsLedger, to: pointsLedgerFileURL(), label: "points ledger") }
    private func loadPointsLedger() { pointsLedger = read([PointsEntry].self, from: pointsLedgerFileURL(), label: "points ledger") ?? [] }

    private func saveRewardRequests() { write(rewardRequests, to: rewardRequestsFileURL(), label: "reward requests") }
    private func loadRewardRequests() { rewardRequests = read([RewardRequest].self, from: rewardRequestsFileURL(), label: "reward requests") ?? [] }

    // MARK: - CloudKit bootstrap (read-only)
    private func bootstrapFromCloudKit() async {
        do {
            let snapshot = try await familyStore.loadSnapshot()
            do {
                let s = try await shareCoordinator.bootstrapFamily()
                switch s {
                case .shared(let ctx), .privateOwner(let ctx): self.familyContext = ctx
                }
            } catch {
                print("⚠️ Failed to resolve FamilyContext: \(error)")
            }
            guard FamilyDataStore.hasUserData(snapshot) else {
                cloudKitLoaded = false
                cloudKitErrorMessage = nil
                print("ℹ️ CloudKit snapshot empty — keeping local JSON as source for now.")
                return
            }
            self.children = snapshot.children
            self.taskTemplates = snapshot.taskTemplates
            self.taskAssignments = snapshot.taskAssignments
            self.taskCompletions = snapshot.taskCompletions
            self.customEmojis = snapshot.customEmojis
            self.eventTemplates = snapshot.eventTemplates
            self.eventAssignments = snapshot.eventAssignments
            self.locations = snapshot.locations
            // pointsLedger & rewardRequests are not yet fetched from CloudKit (read-only)
            cloudKitLoaded = true
            cloudKitErrorMessage = nil
            print("✅ CloudKit loaded family snapshot (\(children.count) children, \(taskTemplates.count) templates, \(eventTemplates.count) events)")
        } catch {
            cloudKitLoaded = false
            cloudKitErrorMessage = String(describing: error)
            print("❌ CloudKit bootstrap failed: \(error)")
        }
    }

    // MARK: - Helpers for Sharing UI
    func cloudDatabaseForCurrentFamily() -> CKDatabase {
        if let ctx = familyContext {
            switch ctx.database {
            case .private: return CKContainer.default().privateCloudDatabase
            case .shared:  return CKContainer.default().sharedCloudDatabase
            }
        }
        return CKContainer.default().privateCloudDatabase
    }
}

// MARK: - Custom Emoji usage lookups (for safe deletion)
extension AppState {
    /// Returns how many Task Templates and Event Templates currently use this emoji.
    func emojiUsage(_ emoji: String) -> (tasks: Int, events: Int) {
        let tasks = taskTemplates.reduce(0) { $0 + ($1.iconSymbol == emoji ? 1 : 0) }
        let events = eventTemplates.reduce(0) { $0 + ($1.iconSymbol == emoji ? 1 : 0) }
        return (tasks, events)
    }

    /// Returns the number of saved custom emojis that are used by templates.
    func countCustomEmojisInUse() -> Int {
        var used = 0
        for e in customEmojis {
            let u = emojiUsage(e)
            if u.tasks > 0 || u.events > 0 {
                used += 1
            }
        }
        return used
    }
}

// MARK: - Points history cleanup (remove rows not needed for current balance; no snapshots)
extension AppState {

    struct HistoryCleanPreview: Equatable {
        let removableIds: Set<UUID>
        let removeCount: Int
        let keepCount: Int
    }

    /// Dry-run: compute which rows for this child can be safely removed without changing the current total.
    /// Strategy: cancel exact +k / -k pairs by magnitude across the entire history (no snapshots).
    func previewCleanChildPointsHistory(childId: UUID) -> HistoryCleanPreview {
        let entries = pointsLedger.filter { $0.childId == childId }
        guard !entries.isEmpty else {
            return .init(removableIds: [], removeCount: 0, keepCount: 0)
        }

        // Group by |delta| and split by sign; operate oldest-first so newer history is favored.
        var byMagPos: [Int: [PointsEntry]] = [:]   // magnitude -> [+k entries], oldest → newest
        var byMagNeg: [Int: [PointsEntry]] = [:]   // magnitude -> [-k entries], oldest → newest

        let sortedOldestFirst = entries.sorted { a, b in
            if dayOnly(a.day) != dayOnly(b.day) { return dayOnly(a.day) < dayOnly(b.day) }
            return a.createdAt < b.createdAt
        }

        for e in sortedOldestFirst {
            let mag = abs(e.delta)
            guard mag > 0 else { continue }
            if e.delta > 0 {
                byMagPos[mag, default: []].append(e)
            } else {
                byMagNeg[mag, default: []].append(e)
            }
        }

        // Pair off as many +mag with -mag as possible; mark both as removable.
        var removable = Set<UUID>()
        for mag in Set(byMagPos.keys).union(byMagNeg.keys) {
            let pos = byMagPos[mag] ?? []
            let neg = byMagNeg[mag] ?? []
            if pos.isEmpty || neg.isEmpty { continue }
            let c = min(pos.count, neg.count)
            if c > 0 {
                for i in 0..<c {
                    removable.insert(pos[i].id)
                    removable.insert(neg[i].id)
                }
            }
        }

        let removeCount = removable.count
        let keepCount = entries.count - removeCount
        return .init(removableIds: removable, removeCount: removeCount, keepCount: keepCount)
    }

    /// Apply the cleanup computed by `previewCleanChildPointsHistory` (no undo, no snapshots).
    /// Returns (removed, kept).
    @discardableResult
    func cleanChildPointsHistory(childId: UUID) -> (removed: Int, kept: Int) {
        let preview = previewCleanChildPointsHistory(childId: childId)
        guard !preview.removableIds.isEmpty else {
            let kept = pointsLedger.filter { $0.childId == childId }.count
            return (0, kept)
        }

        // Sanity: verify total before/after remains the same.
        let beforeTotal = childPointsTotal(childId: childId)

        pointsLedger.removeAll { e in
            e.childId == childId && preview.removableIds.contains(e.id)
        }

        let afterTotal = childPointsTotal(childId: childId)
        if beforeTotal != afterTotal {
            // This should not happen with exact +k/-k pairing. If it does, log and bail.
            print("❌ Clean history sanity check failed: before=\(beforeTotal), after=\(afterTotal)")
        }

        // JSON autosave for pointsLedger is already wired.
        let kept = pointsLedger.filter { $0.childId == childId }.count
        return (preview.removeCount, kept)
    }
}
