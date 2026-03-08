//
//  SelectEventTemplateView.swift
//  parent_child_checklist
//
//  UPDATED: Extra‑compact tiles (height 64), visible trailing actions (Edit + …)
//  - Non-breathing layout (ScrollView + LazyVStack)
//  - Same frosted cards, neon filament separators, and header as before
//

import SwiftUI
import UIKit

// MARK: - Futurist theme tokens (parity with your other screens)
private enum FuturistTheme {
    static let neonAqua       = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let textPrimary    = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary  = Color.white.opacity(0.78)
    static let cardStroke     = Color.white.opacity(0.08)
    static let cardShadow     = Color.black.opacity(0.10)

    static let softRedBase    = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase  = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight   = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
}

// MARK: - Row metrics (compact, aligned with Select Task)
private enum EventRowMetrics {
    static let pageHPad: CGFloat     = 12
    static let cornerRadius: CGFloat = 14
    static let innerHPad: CGFloat    = 16

    // EXTRA‑COMPACT tile height (was 92 → now 64)
    static let rowHeight: CGFloat    = 64

    // Chevron (kept if you want a disclosure feel; currently not shown)
    static let chevronSize: CGFloat  = 16
    static let chevronTint           = Color.white.opacity(0.85)

    // Right inset so trailing actions align with content
    static let innerTrailing: CGFloat = 12

    // Separator-only spacing
    static let firstRowTopPad: CGFloat       = 2
    static let betweenRowsTopPad: CGFloat    = 0
    static let separatorVerticalPad: CGFloat = 0
}

// MARK: - Frosted card surface (same as Task/Location)
private struct EventFrostedSurface<ShapeContent: InsettableShape>: View {
    let shape: ShapeContent
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

// MARK: - Cyan filament separator
private struct EventBrightLineSeparator: View {
    var leadingInset: CGFloat = 16
    var trailingInset: CGFloat = 14
    var thickness: CGFloat = 2

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95), location: 0.00),
                .init(color: FuturistTheme.neonAqua,                                      location: 0.50),
                .init(color: Color(red: 0.02, green: 0.06, blue: 0.16).opacity(0.95),     location: 1.00),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: thickness)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.horizontal, EventRowMetrics.pageHPad)
        .accessibilityHidden(true)
    }
}

// MARK: - Tiles

/// Compact tile (Search)
private struct EventCompactTile<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        HStack(spacing: 10) { content() }
            .frame(height: 56)
            .padding(.horizontal, EventRowMetrics.innerHPad)
            .background(
                EventFrostedSurface(
                    shape: RoundedRectangle(cornerRadius: EventRowMetrics.cornerRadius, style: .continuous)
                )
            )
    }
}

/// Event row tile — extra‑compact height
private struct EventTile<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        HStack(spacing: 12) { content() }
            .frame(height: EventRowMetrics.rowHeight)
            .padding(.horizontal, EventRowMetrics.innerHPad)
            .background(
                EventFrostedSurface(
                    shape: RoundedRectangle(cornerRadius: EventRowMetrics.cornerRadius, style: .continuous),
                    shadowRadius: 4, shadowYOffset: 1
                )
            )
    }
}

// MARK: - Delete confirmation (mirrors Location copy & style)
private struct EventDeleteConfirmSheet: View {
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
struct SelectEventTemplateView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let selectedTemplateId: UUID?
    let onPick: (EventTemplate) -> Void

    @State private var searchText: String = ""

    // Add/Edit
    @State private var showAddTemplate = false
    @State private var editingTemplate: EventTemplate? = nil

    // Delete confirm
    @State private var showDeletePrompt: Bool = false
    @State private var pendingDelete: EventTemplate? = nil
    @State private var pendingDeleteUsageCount: Int = 0

    // Data
    private var templates: [EventTemplate] {
        let sorted = appState.eventTemplates.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(q) }
    }

    // Delete messages (mirror Location tone)
    private var deleteAlertTitle: String {
        guard let tpl = pendingDelete else { return "Delete Event" }
        return "Delete “\(tpl.title)”?"
    }
    private var deleteAlertMessage: String {
        guard pendingDeleteUsageCount > 0 else {
            return "This will remove the event template from your list. This action cannot be undone."
        }
        let n = pendingDeleteUsageCount
        let plural = n == 1 ? "assignment" : "assignments"
        return "This event template is currently used by \(n) \(plural). Deleting it will not remove existing assignments, but you won’t be able to use this template again. This cannot be undone."
    }

    // Count how many assignments use a template
    private func usageCount(for templateId: UUID) -> Int {
        appState.eventAssignments.filter { $0.templateId == templateId }.count
    }

    // Delete confirmed
    private func performDeleteConfirmed() {
        guard let tpl = pendingDelete else { return }
        _ = appState.deleteEventTemplate(id: tpl.id)
        pendingDelete = nil
        pendingDeleteUsageCount = 0
        showDeletePrompt = false
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                // CONTENT (header provided by safeAreaInset below)
                ScrollView {
                    VStack(spacing: 0) {

                        // SEARCH + HEADER
                        VStack(spacing: 8) {
                            EventCompactTile {
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

                            Text("Events")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(FuturistTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, EventRowMetrics.pageHPad)
                        .padding(.top, 12)

                        // EVENTS LIST (separator-only spacing)
                        if templates.isEmpty {
                            Text("No events yet. Tap + to create one.")
                                .font(.subheadline)
                                .foregroundStyle(FuturistTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(templates.enumerated()), id: \.element.id) { idx, tpl in
                                    // ---- Row tile with visible action cluster (Edit + More) ----
                                    EventTile {
                                        HStack(spacing: 12) {
                                            // Icon + title
                                            TaskEmojiIconView(icon: tpl.iconSymbol, size: 20)

                                            Text(tpl.title)
                                                .font(.headline)
                                                .foregroundStyle(FuturistTheme.textPrimary)
                                                .lineLimit(2)

                                            Spacer(minLength: 10)

                                            // Action cluster: Edit + More (Delete inside)
                                            HStack(spacing: 10) {
                                                Button {
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                    editingTemplate = tpl
                                                } label: {
                                                    Text("Edit")
                                                        .font(.footnote.weight(.semibold))
                                                        .foregroundStyle(Color.white)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 5) // compact to fit 64-pt row
                                                        .background(Color.white.opacity(0.12), in: Capsule())
                                                        .overlay(
                                                            Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityLabel("Edit event “\(tpl.title)”")

                                                Menu {
                                                    Button(role: .destructive) {
                                                        pendingDelete = tpl
                                                        pendingDeleteUsageCount = usageCount(for: tpl.id)
                                                        showDeletePrompt = true
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                } label: {
                                                    Image(systemName: "ellipsis.circle")
                                                        .font(.title3)
                                                        .foregroundStyle(FuturistTheme.textSecondary)
                                                        .padding(.horizontal, 2)
                                                }
                                                .accessibilityLabel("More actions for “\(tpl.title)”")
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // Tap anywhere on the tile (except buttons) selects the template
                                            onPick(tpl)
                                            dismiss()
                                        }
                                    }
                                    .padding(.horizontal, EventRowMetrics.pageHPad)
                                    .padding(.top, idx == 0 ? EventRowMetrics.firstRowTopPad
                                                            : EventRowMetrics.betweenRowsTopPad)

                                    if idx < templates.count - 1 {
                                        EventBrightLineSeparator()
                                            .padding(.vertical, EventRowMetrics.separatorVerticalPad)
                                    }
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }

                // Delete confirm sheet
                if showDeletePrompt {
                    EventDeleteConfirmSheet(
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

            // Header (Close / title / ＋) via safeAreaInset — identical to Location/Task
            .safeAreaInset(edge: .top, spacing: 0) {
                ZStack {
                    Text("Select Event")
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
                            .accessibilityLabel(Text("New Event Template"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .background(Color.clear)
            }

            // Create
            .sheet(isPresented: $showAddTemplate) {
                AddEventTemplateView(
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
                EditEventTemplateView(
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
