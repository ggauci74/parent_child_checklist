//
//  SelectTaskTemplateView.swift
//  parent_child_checklist
//
//  Matches Select Location row height & spacing (92pt) and duplicates its swipe rail behavior.
//  - Foreground content anchored to the left (HStack + Spacer) and only width shrinks,
//    so the visible content appears to stay put while the card edge slides left.
//  - Non-breathing layout (ScrollView + LazyVStack)
//  - Horizontal swipe rail (Edit + Delete), with warn-on-use delete (mirrors Location)
//

import SwiftUI
import UIKit

// MARK: - Futurist theme tokens (parity with Select Location)
private enum FuturistTheme {
    static let neonAqua = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let textPrimary = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)
    static let cardStroke = Color.white.opacity(0.08)
    static let cardShadow = Color.black.opacity(0.10)

    static let softRedBase   = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight  = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)

    // Action icon colors (round Edit/Delete) – match Location
    static let actionBlue     = Color(red: 0.11, green: 0.49, blue: 1.00)
    static let actionRed      = Color(red: 1.00, green: 0.29, blue: 0.34)
}

// MARK: - Row metrics (match Location)
private enum TaskRowMetrics {
    static let pageHPad: CGFloat     = 12
    static let cornerRadius: CGFloat = 14
    static let innerHPad: CGFloat    = 16

    // MATCH Select Location tall tile
    static let rowHeight: CGFloat    = 92

    // Chevron
    static let chevronSize: CGFloat  = 16
    static let chevronTint           = Color.white.opacity(0.85)

    // Card inner trailing inset (align rail & chevron with text)
    static let innerTrailing: CGFloat = 12

    // Tight vertical rhythm — separator is the only visible gap
    static let firstRowTopPad: CGFloat       = 2
    static let betweenRowsTopPad: CGFloat    = 0
    static let separatorVerticalPad: CGFloat = 0
}

// MARK: - Frosted “glass” card surface (same feel as Location)
private struct TaskFrostedSurface<ShapeContent: InsettableShape>: View {
    let shape: ShapeContent
    /// Softer shadow so the filament sits “flush”
    var shadowRadius: CGFloat = 4
    var shadowYOffset: CGFloat = 1

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var surface: some ShapeStyle {
        reduceTransparency
        ? Color(red: 0.05, green: 0.10, blue: 0.22)
        : Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
    }

    var body: some View {
        shape.fill(surface)
            .overlay(shape.stroke(FuturistTheme.cardStroke, lineWidth: 1))
            .shadow(color: FuturistTheme.cardShadow, radius: shadowRadius, x: 0, y: shadowYOffset)
    }
}

// MARK: - Bright cyan filament (same geometry as Location)
private struct TaskBrightLineSeparator: View {
    var leadingInset: CGFloat = 16
    var trailingInset: CGFloat = 14
    var thickness: CGFloat = 2

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 0.00),
                .init(color: FuturistTheme.neonAqua,                                     location: 0.50),
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95),    location: 1.00),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: thickness)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.horizontal, TaskRowMetrics.pageHPad) // aligns with card outer padding
        .accessibilityHidden(true)
    }
}

// MARK: - Tiles

/// Compact tile (Search row)
private struct TaskCompactTile<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        HStack(spacing: 10) { content() }
            .frame(height: 56) // compact search tile height
            .padding(.horizontal, TaskRowMetrics.innerHPad)
            .background(
                TaskFrostedSurface(
                    shape: RoundedRectangle(cornerRadius: TaskRowMetrics.cornerRadius, style: .continuous)
                )
            )
    }
}

/// Tall tile (each Task row), MATCH Location tile height
private struct TaskTile<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        HStack(spacing: 12) { content() }
            .frame(height: TaskRowMetrics.rowHeight)
            .padding(.horizontal, TaskRowMetrics.innerHPad)
            .background(
                TaskFrostedSurface(
                    shape: RoundedRectangle(cornerRadius: TaskRowMetrics.cornerRadius, style: .continuous),
                    shadowRadius: 4, shadowYOffset: 1
                )
            )
    }
}

// MARK: - Swipe-to-reveal row (MATCH Location; foreground anchored left and shrinks width only)
private struct TaskSwipeRevealRow<RowContent: View>: View {
    private let rowHeight: CGFloat     = TaskRowMetrics.rowHeight
    private let circleSize: CGFloat    = 48
    private let glyphSize: CGFloat     = 20
    private let actionSpacing: CGFloat = 20
    /// Row "opens" by this amount—enough to reveal both circles comfortably.
    private let revealWidth: CGFloat   = 160

    let id: UUID
    @Binding var openRowId: UUID?
    let rowContent: () -> RowContent
    let onTapRow: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    // Location-style gesture state
    @GestureState private var dragX: CGFloat = 0
    private var isOpen: Bool { openRowId == id }

    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            // Mirror Location: compute revealed distance from drag state or open state.
            let revealed  = min(revealWidth, max(0, isOpen ? revealWidth : -dragX))
            let railActive = revealed > 0

            ZStack(alignment: .trailing) {
                // Trailing action rail (Edit + Delete), right-justified, visible as we "open"
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(spacing: actionSpacing) {
                        VStack(spacing: 6) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onEdit()
                            } label: {
                                Circle()
                                    .fill(FuturistTheme.actionBlue)
                                    .frame(width: circleSize, height: circleSize)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .foregroundStyle(.white)
                                            .font(.system(size: glyphSize, weight: .semibold))
                                    )
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            Text("Edit")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(FuturistTheme.textPrimary.opacity(0.90))
                                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                        }
                        VStack(spacing: 6) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDelete()
                            } label: {
                                Circle()
                                    .fill(FuturistTheme.actionRed)
                                    .frame(width: circleSize, height: circleSize)
                                    .overlay(
                                        Image(systemName: "trash")
                                            .foregroundStyle(.white)
                                            .font(.system(size: glyphSize, weight: .semibold))
                                    )
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            Text("Delete")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(FuturistTheme.textPrimary.opacity(0.90))
                                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                        }
                    }
                    .padding(.trailing, TaskRowMetrics.innerTrailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(height: rowHeight, alignment: .center)
                .opacity(railActive ? 1 : 0)
                .allowsHitTesting(railActive)
                .zIndex(railActive ? 1 : 0)

                // ✅ Foreground content: anchored to leading. Shrink width only; do NOT offset.
                HStack(spacing: 0) {
                    rowContent()
                        .frame(width: fullWidth - revealed, alignment: .leading)
                    Spacer(minLength: 0) // anchors foreground to the leading edge
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .updating($dragX) { value, state, _ in
                            // Horizontal-only state like Location (keeps scroll feeling similar)
                            state = min(0, max(-revealWidth, value.translation.width))
                        }
                        .onEnded { value in
                            let finalReveal = min(revealWidth, max(0, -(value.translation.width)))
                            let threshold = revealWidth * 0.33
                            let shouldOpen = finalReveal > threshold
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                openRowId = shouldOpen ? id : nil
                            }
                            if shouldOpen { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                        }
                )
                .onTapGesture {
                    if isOpen {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            openRowId = nil
                        }
                    } else {
                        onTapRow()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: TaskRowMetrics.cornerRadius, style: .continuous))
        }
        .frame(height: rowHeight)
    }
}

// MARK: - Toolbar pill button (Close / ＋) – same look as Location
private struct ToolbarPillButton: View {
    let label: String
    var foreground: Color
    var background: Color
    var stroke: Color
    var fixedWidth: CGFloat? = nil
    var fixedHeight: CGFloat? = nil
    var action: () -> Void

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: fixedWidth, height: fixedHeight)
            .background(Capsule().fill(background))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
            .shadow(color: FuturistTheme.cardShadow, radius: 3)
            .contentShape(Capsule())
            .onTapGesture { action() }
    }
}

// MARK: - Delete confirmation (mirrors Location’s structure & tone)
private struct TaskDeleteConfirmSheet: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    var onDelete: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { isPresented = false }

            VStack(spacing: 14) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(FuturistTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Capsule().fill(FuturistTheme.softRedLight))
                            .overlay(Capsule().stroke(FuturistTheme.softRedBase.opacity(0.75), lineWidth: 1))
                            .shadow(color: FuturistTheme.cardShadow, radius: 3)
                    }
                    .buttonStyle(.plain)

                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                        onDelete()
                        isPresented = false
                    } label: {
                        Text("Delete")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.black.opacity(0.9))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(Capsule().fill(Color.white))
                            .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: 1))
                            .shadow(color: FuturistTheme.cardShadow, radius: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(FuturistTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 24)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.18), value: isPresented)
    }
}

// MARK: - Main
struct SelectTaskTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let selectedTemplateId: UUID?
    let onPick: (TaskTemplate) -> Void

    @State private var searchText: String = ""

    // Create/Edit sheets
    @State private var showAddTemplate = false
    @State private var editingTemplate: TaskTemplate? = nil

    // Swipe-open tracking
    @State private var openRowId: UUID? = nil

    // Delete confirm (mirrors Location)
    @State private var showDeletePrompt: Bool = false
    @State private var pendingDelete: TaskTemplate? = nil
    @State private var pendingDeleteUsageCount: Int = 0

    // Data
    private var templates: [TaskTemplate] {
        let sorted = appState.taskTemplates.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    // Delete prompt messages (mirrors Location copy)
    private var deleteAlertTitle: String {
        guard let tpl = pendingDelete else { return "Delete Task" }
        return "Delete “\(tpl.title)”?"
    }
    private var deleteAlertMessage: String {
        guard pendingDeleteUsageCount > 0 else {
            return "This will remove the task template from your list. This action cannot be undone."
        }
        let n = pendingDeleteUsageCount
        let plural = n == 1 ? "assignment" : "assignments"
        return "This task template is currently used by \(n) \(plural). Deleting it will not remove existing assignments, but you won’t be able to use this template again. This cannot be undone."
    }

    // Count how many assignments use a template
    private func usageCount(for templateId: UUID) -> Int {
        return appState.taskAssignments.filter { $0.templateId == templateId }.count
    }

    // Perform deletion (mirror Location: warn → delete)
    private func performDeleteConfirmed() {
        guard let tpl = pendingDelete else { return }
        _ = appState.deleteTaskTemplate(id: tpl.id) // update to your API if named differently
        if openRowId == tpl.id { openRowId = nil }
        pendingDelete = nil
        pendingDeleteUsageCount = 0
        showDeletePrompt = false
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                // CONTENT (header is provided by safeAreaInset below)
                ScrollView {
                    VStack(spacing: 0) {

                        // SEARCH + HEADER (compact tiles) — match Location spacing
                        VStack(spacing: 8) {
                            TaskCompactTile {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(FuturistTheme.textPrimary.opacity(0.92))
                                    TextField(
                                        "",
                                        text: $searchText,
                                        prompt: Text("Search")
                                            .foregroundStyle(FuturistTheme.textPrimary.opacity(0.92))
                                    )
                                    .textInputAutocapitalization(.none)
                                    .foregroundStyle(FuturistTheme.textPrimary)
                                    .tint(FuturistTheme.neonAqua)
                                }
                            }

                            Text("Tasks")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FuturistTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, TaskRowMetrics.pageHPad)
                        .padding(.top, 12)

                        // TASKS (separator-only spacing) — MATCH Location rhythm
                        if templates.isEmpty {
                            Text("No tasks yet. Tap + to create one.")
                                .font(.subheadline)
                                .foregroundStyle(FuturistTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(templates.enumerated()), id: \.element.id) { index, tpl in
                                    let isRailOpen = (openRowId == tpl.id)

                                    TaskSwipeRevealRow(
                                        id: tpl.id,
                                        openRowId: $openRowId,
                                        rowContent: {
                                            TaskTile {
                                                HStack(spacing: 12) {
                                                    // Slightly larger emoji for tall tile
                                                    TaskEmojiIconView(icon: tpl.iconSymbol, size: 24)

                                                    VStack(alignment: .leading, spacing: 6) {
                                                        Text(tpl.title)
                                                            .font(.headline)
                                                            .foregroundStyle(FuturistTheme.textPrimary)

                                                        // points line
                                                        HStack(spacing: 6) {
                                                            Text("💎")
                                                            Text("\(max(0, tpl.rewardPoints))")
                                                                .fontWeight(.semibold)
                                                        }
                                                        .font(.footnote)
                                                        .foregroundStyle(FuturistTheme.textSecondary)
                                                    }

                                                    Spacer(minLength: 10)

                                                    // Chevron hides while rail open (parity with Location)
                                                    if !isRailOpen {
                                                        Image(systemName: "chevron.right")
                                                            .font(.system(size: TaskRowMetrics.chevronSize, weight: .semibold))
                                                            .foregroundStyle(TaskRowMetrics.chevronTint)
                                                    }
                                                }
                                            }
                                        },
                                        onTapRow: {
                                            onPick(tpl)
                                            dismiss()
                                        },
                                        onEdit: {
                                            withAnimation { openRowId = nil }
                                            editingTemplate = tpl
                                        },
                                        onDelete: {
                                            withAnimation { openRowId = nil }
                                            pendingDelete = tpl
                                            pendingDeleteUsageCount = usageCount(for: tpl.id)
                                            showDeletePrompt = true
                                        }
                                    )
                                    .padding(.horizontal, TaskRowMetrics.pageHPad)
                                    .padding(.top, index == 0 ? TaskRowMetrics.firstRowTopPad
                                                              : TaskRowMetrics.betweenRowsTopPad)

                                    // Filament between cards (not after last) — no vertical padding
                                    if index < templates.count - 1 {
                                        TaskBrightLineSeparator()
                                            .padding(.vertical, TaskRowMetrics.separatorVerticalPad)
                                    }
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }

                // Delete confirm (mirrors Location’s confirm)
                if showDeletePrompt {
                    TaskDeleteConfirmSheet(
                        isPresented: $showDeletePrompt,
                        title: deleteAlertTitle,
                        message: deleteAlertMessage,
                        onDelete: { performDeleteConfirmed() }
                    )
                    .zIndex(20)
                    .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)

            // ✅ Header via safeAreaInset — exactly like Select Location
            .safeAreaInset(edge: .top, spacing: 0) {
                ZStack {
                    Text("Select Task")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack {
                        let pillWidth: CGFloat = 76
                        let pillHeight: CGFloat = 32

                        Text("Close")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: pillWidth, height: pillHeight)
                            .background(Capsule().fill(FuturistTheme.softRedLight))
                            .overlay(Capsule().stroke(FuturistTheme.softRedBase.opacity(0.75), lineWidth: 1))
                            .shadow(color: FuturistTheme.cardShadow, radius: 3)
                            .contentShape(Capsule())
                            .onTapGesture { dismiss() }

                        Spacer(minLength: 12)

                        Text("+")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.9))
                            .frame(width: pillWidth, height: pillHeight)
                            .background(Capsule().fill(FuturistTheme.softGreenLight))
                            .overlay(Capsule().stroke(FuturistTheme.softGreenBase.opacity(0.75), lineWidth: 1))
                            .shadow(color: FuturistTheme.cardShadow, radius: 3)
                            .contentShape(Capsule())
                            .onTapGesture { showAddTemplate = true }
                            .accessibilityLabel(Text("New Task Template"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .background(Color.clear)
            }

            // Create
            .sheet(isPresented: $showAddTemplate) {
                AddTaskTemplateView(
                    onSaved: { created in
                        onPick(created)
                        dismiss()
                    },
                    onCancel: { }
                )
                .environmentObject(appState)
            }
            // Edit
            .sheet(item: $editingTemplate) { tpl in
                EditTaskTemplateView(
                    template: tpl,
                    onSaved: { updated in
                        onPick(updated)
                        dismiss()
                    },
                    onCancel: { }
                )
                .environmentObject(appState)
            }
        }
    }
}
