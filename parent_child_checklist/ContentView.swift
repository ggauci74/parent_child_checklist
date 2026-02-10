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

// MARK: - Emoji Icon Catalog (kid-friendly + colourful)
enum EmojiCatalog {

    enum Category: String, CaseIterable, Identifiable {
        case all = "All"
        case myEmojis = "My Emojis"   // ✅ NEW
        case morning = "Morning"
        case hygiene = "Hygiene"
        case school = "School"
        case chores = "Chores"
        case food = "Food"
        case pets = "Pets"
        case sports = "Sports"
        case time = "Time"
        case rewards = "Fun"
        case health = "Health"
        case outdoors = "Outdoors"

        var id: String { rawValue }
    }

    static func emojis(for category: Category) -> [String] {
        if category == .all { return allEmojis }
        return categoryMap[category] ?? allEmojis
    }

    static let allEmojis: [String] = Array(Set(categoryMap.values.flatMap { $0 }))
        .sorted()

    // Curated categories (adjust anytime)
    private static let categoryMap: [Category: [String]] = [

        .morning: ["☀️","🌤️","🌙","⭐️","⏰","🛏️","🧸","🧦","👕","🪥"],

        .hygiene: ["🪥","🧴","🧼","🧻","🧽","🪒","🚿","🛁","💧","🧹","🪮"],

        .school: ["🎒","📚","📖","✏️","🖊️","🖍️","📐","📏","🧠","🧪","🔬","🧾","📅"],

        .chores: ["✅","☑️","🧹","🧺","🧼","🧽","🗑️","♻️","🔧","🪛","🪣","🧤","🪠"],

        .food: ["🍎","🍌","🍇","🍓","🥕","🥪","🍳","🥣","🍽️","🥛","🥃","🍞","🍕","🍪"],

        .pets: ["🐶","🐱","🐰","🐹","🐦","🐠","🐢","🐴","🐾","🦄","🧶"],

        .sports: ["⚽️","🏀","🏈","🎾","🏐","🏓","🥋","🏊‍♂️","🚴‍♂️","🛹","🏆","🥇"],

        .time: ["⏱️","⏳","🕒","🗓️","📅","🔔","📌"],

        .rewards: ["🎮","🎧","🎨","🎭","🎲","🎁","🍿","🍦","🎂","🎉","🥳","🚙","👑","🌈","✨","💎"],

        .health: ["💊","🩹","🩺","❤️","🧘‍♂️","🥗","💧"],

        .outdoors: ["🌳","🌿","🍃","🌸","🏞️","⛰️","🌊","☔️","❄️","🔥","🚶‍♂️","🚲","📸"],

        .all: []
    ]
}

// MARK: - Emoji Detection + Sanitising Helpers
extension String {

    /// Simple heuristic to detect emojis (including composed sequences).
    var containsEmoji: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation || scalar.properties.isEmoji
        }
    }

    /// Trims whitespace/newlines and normalises.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Emoji-only task icon view.
/// If icon isn't an emoji (e.g., old saved SF symbol name), show a safe default ✅.
struct TaskEmojiIconView: View {
    let icon: String
    var size: CGFloat = 24

    private var displayEmoji: String {
        let t = icon.trimmed
        return t.containsEmoji ? t : "✅"
    }

    var body: some View {
        Text(displayEmoji)
            .font(.system(size: size))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: 40, height: 40)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityLabel("Task icon")
    }
}

// MARK: - App Root
struct ContentView: View {
    @AppStorage("userRole") private var userRoleRawValue: String?
    @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let raw = userRoleRawValue,
               let role = UserRole(rawValue: raw) {
                switch role {
                case .parent:
                    ParentHomeView()
                case .child:
                    if let idString = selectedChildIdRaw,
                       let uuid = UUID(uuidString: idString) {
                        ChildHomeView(childId: uuid)
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

// MARK: - Role Selection
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
                            Text("👨‍👩‍👧‍👦")
                                .font(.title2)
                            Text("I'm a Parent")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button {
                        userRoleRawValue = UserRole.child.rawValue
                    } label: {
                        HStack {
                            Text("🧒")
                                .font(.title2)
                            Text("I'm a Child")
                                .fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
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

// MARK: - Parent Home
struct ParentHomeView: View {
    var body: some View {
        TabView {
            ParentChildrenTabView()
                .tabItem { Label("Children", systemImage: "person.2.fill") }
            
            ParentTasksTabView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
            
            ParentEventsTabView()
                .tabItem { Label("Events", systemImage: "calendar") }
            
            ParentFamilyTabView()
                .tabItem { Label("Family", systemImage: "person.crop.circle.badge.plus") }
        }
    }
}
// MARK: - Parent Children Tab
struct ParentChildrenTabView: View {
        @AppStorage("userRole") private var userRoleRawValue: String?
        @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
        @EnvironmentObject private var appState: AppState
        
        @State private var showAddChild = false
        @State private var childPendingDelete: ChildProfile?
        @State private var childPendingEdit: ChildProfile?
        
        var body: some View {
            NavigationStack {
                List {
                    Section("Children") {
                        ForEach(appState.children) { child in
                            NavigationLink {
                                ParentChildWeeklyView(childId: child.id)
                            } label: {
                                HStack(spacing: 12) {
                                    ChildAvatarCircleView(colorHex: child.colorHex, avatarId: child.avatarId, size: 36)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(child.name)
                                            .font(.headline)
                                        
                                        Text(child.avatarId == nil ? "Not chosen yet" : AvatarCatalog.avatar(for: child.avatarId).displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 6)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    childPendingDelete = child
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                                
                                Button {
                                    childPendingEdit = child
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    
                    Section {
                        Button("Switch Role (Temporary)") {
                            userRoleRawValue = nil
                            selectedChildIdRaw = nil
                        }
                        .foregroundStyle(.red)
                    }
                }
                .navigationTitle("Parent")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddChild = true } label: {
                            Image(systemName: "plus").font(.headline)
                        }
                    }
                }
                .sheet(isPresented: $showAddChild) {
                    AddChildView()
                        .environmentObject(appState)
                }
                .sheet(item: $childPendingEdit) { child in
                    EditChildView(child: child)
                        .environmentObject(appState)
                }
                .alert("Delete child?", isPresented: Binding(
                    get: { childPendingDelete != nil },
                    set: { if !$0 { childPendingDelete = nil } }
                )) {
                    Button("Delete", role: .destructive) {
                        if let child = childPendingDelete {
                            appState.deleteChild(id: child.id)
                        }
                        childPendingDelete = nil
                    }
                    Button("Cancel", role: .cancel) {
                        childPendingDelete = nil
                    }
                } message: {
                    Text("This will remove the child and all their assignments and completion history.")
                }
            }
        }
    }

// MARK: - Parent Tasks Tab
    struct ParentTasksTabView: View {
        @EnvironmentObject private var appState: AppState
        
        @State private var showAddTask = false
        @State private var taskPendingEdit: TaskTemplate?
        @State private var taskPendingDelete: TaskTemplate?
        @State private var showDeleteBlockedAlert = false
        
        var body: some View {
            NavigationStack {
                List {
                    Section("Task Library") {
                        if appState.taskTemplates.isEmpty {
                            Text("No tasks yet. Tap + to create one.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appState.taskTemplates.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) { task in
                                HStack(spacing: 12) {
                                    TaskEmojiIconView(icon: task.iconSymbol, size: 22)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(task.title)
                                            .font(.headline)
                                        
                                        if task.rewardPoints > 0 {
                                            Text("💎 \(task.rewardPoints) point\(task.rewardPoints == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        taskPendingDelete = task
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    
                                    Button {
                                        taskPendingEdit = task
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Tasks")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddTask = true } label: {
                            Image(systemName: "plus").font(.headline)
                        }
                    }
                }
                .sheet(isPresented: $showAddTask) {
                    AddTaskTemplateView()
                        .environmentObject(appState)
                }
                .sheet(item: $taskPendingEdit) { tpl in
                    EditTaskTemplateView(template: tpl)
                        .environmentObject(appState)
                }
                .alert("Delete task?", isPresented: Binding(
                    get: { taskPendingDelete != nil },
                    set: { if !$0 { taskPendingDelete = nil } }
                )) {
                    Button("Delete", role: .destructive) {
                        if let tpl = taskPendingDelete {
                            let ok = appState.deleteTaskTemplate(id: tpl.id)
                            if !ok { showDeleteBlockedAlert = true }
                        }
                        taskPendingDelete = nil
                    }
                    Button("Cancel", role: .cancel) {
                        taskPendingDelete = nil
                    }
                } message: {
                    Text("This will delete the task from the library.")
                }
                .alert("Can’t delete", isPresented: $showDeleteBlockedAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("This task is currently assigned to at least one child. Remove the assignments first.")
                }
            }
        }
    }
    
    // MARK: - Parent Events Tab
    struct ParentEventsTabView: View {
        @EnvironmentObject private var appState: AppState
        
        @State private var showAddEvent = false
        @State private var eventPendingEdit: EventTemplate?
        @State private var eventPendingDelete: EventTemplate?
        
        var body: some View {
            NavigationStack {
                List {
                    Section("Event Library") {
                        if appState.eventTemplates.isEmpty {
                            Text("No events yet. Tap + to create one.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appState.eventTemplates.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }) { event in
                                HStack(spacing: 12) {
                                    TaskEmojiIconView(icon: event.iconSymbol, size: 22)
                                    
                                    Text(event.title)
                                        .font(.headline)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        eventPendingDelete = event
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    
                                    Button {
                                        eventPendingEdit = event
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Events")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showAddEvent = true } label: {
                            Image(systemName: "plus").font(.headline)
                        }
                    }
                }
                .sheet(isPresented: $showAddEvent) {
                    AddEventTemplateView()
                        .environmentObject(appState)
                }
                .sheet(item: $eventPendingEdit) { tpl in
                    EditEventTemplateView(template: tpl)
                        .environmentObject(appState)
                }
                .alert("Delete event?", isPresented: Binding(
                    get: { eventPendingDelete != nil },
                    set: { if !$0 { eventPendingDelete = nil } }
                )) {
                    Button("Delete", role: .destructive) {
                        if let tpl = eventPendingDelete {
                            appState.deleteEventTemplate(id: tpl.id)
                        }
                        eventPendingDelete = nil
                    }
                    Button("Cancel", role: .cancel) { eventPendingDelete = nil }
                } message: {
                    Text("This will delete the event from the library.")
                }
            }
        }
    }
    
    // MARK: - Child Home
    struct ChildHomeView: View {
        let childId: UUID
        @AppStorage("userRole") private var userRoleRawValue: String?
        @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
        @EnvironmentObject private var appState: AppState
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Today")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .padding(.top, 16)
                    
                    Text("Your tasks will show here soon ✅")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button("Switch Role (Temporary)") {
                        userRoleRawValue = nil
                        selectedChildIdRaw = nil
                    }
                    .foregroundStyle(.red)
                    .padding(.bottom, 12)
                }
                .padding()
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    // MARK: - Child Choose Profile (Step 1)
    struct ChildChooseProfileView: View {
        @EnvironmentObject private var appState: AppState
        
        // ✅ Needed so we ...
        @AppStorage("userRole") private var userRoleRawValue: String?
        
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
                        NavigationLink {
                            ChildAvatarSetupView(childId: child.id)
                        } label: {
                            HStack(spacing: 12) {
                                ChildAvatarCircleView(colorHex: child.colorHex, avatarId: child.avatarId, size: 42)
                                
                                Text(child.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(.insetGrouped)
                    
                    Spacer()
                    
                    Button("Back") {
                        userRoleRawValue = nil
                    }
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

