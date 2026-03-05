//
// SelectLocationView.swift
// parent_child_checklist
//

import SwiftUI
import UIKit

// MARK: - Futurist theme tokens (aligned with Assign Event)
private enum FuturistTheme {
    static let skyTop     = Color(red: 0.02, green: 0.06, blue: 0.16)   // deep navy
    static let skyBottom  = Color(red: 0.01, green: 0.03, blue: 0.10)
    static let neonAqua   = Color(red: 0.20, green: 0.95, blue: 1.00)   // bright cyan

    static let textPrimary   = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)
    static let chipBorder    = Color.white.opacity(0.25)
    static let chipDisabled  = Color.white.opacity(0.55)
    static let cardStroke    = Color.white.opacity(0.08)
    static let divider       = Color.white.opacity(0.10)
    static let cardShadow    = Color.black.opacity(0.10)

    // Pastel action pill colours
    static let softRedBase    = Color(red: 1.00, green: 0.36, blue: 0.43)
    static let softGreenBase  = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softRedLight   = Color(red: 1.00, green: 0.58, blue: 0.63)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)

    // Action icon colors (round Edit/Delete)
    static let actionBlue     = Color(red: 0.11, green: 0.49, blue: 1.00)
    static let actionRed      = Color(red: 1.00, green: 0.29, blue: 0.34)
}

// MARK: - Row metrics (compact vs tall + tight filament rhythm)
private enum LocationRowMetrics {
    static let pageHPad: CGFloat     = 12
    static let cornerRadius: CGFloat = 14  // List card radius
    static let innerHPad: CGFloat    = 16  // List card inner horizontal padding

    // Tall rows (Locations) – fits 48-pt circles + captions
    static let locationRowHeight: CGFloat = 92

    // Compact rows (Search, None)
    static let compactRowHeight: CGFloat = 56

    // Trailing chevron (bright neutral, not neon)
    static let chevronSize: CGFloat  = 16
    static let chevronTint           = Color.white.opacity(0.85)

    // Card inner trailing inset (align rail & chevron with text)
    static let innerTrailing: CGFloat = 12

    // Tight vertical rhythm — separator is the only visible gap
    static let firstRowTopPad: CGFloat       = 2   // small nudge below "Locations"
    static let betweenRowsTopPad: CGFloat    = 0   // no extra space between cards
    static let separatorVerticalPad: CGFloat = 0   // no extra space around the filament
}

// MARK: - Frosted “glass” surface (list cards)
private struct FrostedSurface<ShapeContent: InsettableShape>: View {
    let shape: ShapeContent
    /// Allow minor adjustments per-usage; defaults match Assign Event.
    var shadowRadius: CGFloat = 6
    var shadowYOffset: CGFloat = 2

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

// MARK: - Bright cyan separator (exactly like Assign Event)
private struct BrightLineSeparator: View {
    var leadingInset: CGFloat = 16
    var trailingInset: CGFloat = 14
    var thickness: CGFloat = 2

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: FuturistTheme.skyTop.opacity(0.95), location: 0.00),
                .init(color: FuturistTheme.neonAqua,             location: 0.50),
                .init(color: FuturistTheme.skyTop.opacity(0.95), location: 1.00),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: thickness)
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.horizontal, 12)  // aligns with card outer padding on page
        .zIndex(2)
        .accessibilityHidden(true)
    }
}

// MARK: - Full-width card tiles (Frosted surface + fixed heights)

/// Tall tile (for Location rows)
private struct LocationTile<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        HStack(spacing: 10) {
            content()
        }
        .frame(height: LocationRowMetrics.locationRowHeight)
        .padding(.horizontal, LocationRowMetrics.innerHPad)
        .background(
            // Slightly softer shadow on Location rows so the filament sits "flush"
            FrostedSurface(
                shape: RoundedRectangle(cornerRadius: LocationRowMetrics.cornerRadius, style: .continuous),
                shadowRadius: 4,
                shadowYOffset: 1
            )
        )
    }
}

/// Compact tile (for Search & None)
private struct CompactTile<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        HStack(spacing: 10) {
            content()
        }
        .frame(height: LocationRowMetrics.compactRowHeight)
        .padding(.horizontal, LocationRowMetrics.innerHPad)
        .background(
            FrostedSurface(
                shape: RoundedRectangle(cornerRadius: LocationRowMetrics.cornerRadius, style: .continuous)
            )
        )
    }
}

// MARK: - Swipe-to-reveal row (right-justified Edit/Delete; reliable taps)
private struct SwipeRevealRow<RowContent: View>: View {
    private let rowHeight: CGFloat     = LocationRowMetrics.locationRowHeight
    private let circleSize: CGFloat    = 48
    private let glyphSize: CGFloat     = 20
    private let actionSpacing: CGFloat = 20
    /// Row slides left by this amount—enough to reveal both circles comfortably.
    private let revealWidth: CGFloat   = 160

    let id: UUID
    @Binding var openRowId: UUID?
    let rowContent: () -> RowContent
    let onTapRow: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @GestureState private var dragX: CGFloat = 0
    private var isOpen: Bool { openRowId == id }

    init(
        id: UUID,
        openRowId: Binding<UUID?>,
        @ViewBuilder rowContent: @escaping () -> RowContent,
        onTapRow: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.id = id
        self._openRowId = openRowId
        self.rowContent = rowContent
        self.onTapRow = onTapRow
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let revealed  = min(revealWidth, max(0, isOpen ? revealWidth : -dragX))
            let railActive = revealed > 0

            ZStack(alignment: .trailing) {
                // Trailing action rail fills row width and anchors to trailing edge
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

                            // Legible caption
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

                            // Legible caption
                            Text("Delete")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(FuturistTheme.textPrimary.opacity(0.90))
                                .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 1)
                        }
                    }
                    .padding(.trailing, LocationRowMetrics.innerTrailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(height: rowHeight, alignment: .center)
                .opacity(railActive ? 1 : 0)
                .allowsHitTesting(railActive)
                .zIndex(railActive ? 1 : 0)

                // Foreground card that slides & shrinks so the rail is tappable
                rowContent()
                    .frame(width: fullWidth - revealed, alignment: .leading)
                    .offset(x: -revealed)
                    .contentShape(Rectangle())
                    .zIndex(railActive ? 0 : 1)
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .updating($dragX) { value, state, _ in
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
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { openRowId = nil }
                        } else {
                            onTapRow()
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: LocationRowMetrics.cornerRadius, style: .continuous))
        }
        .frame(height: LocationRowMetrics.locationRowHeight)
    }
}

// MARK: - Themed panels (Add / Edit / Delete) — Popover with neon keyline (Option C)
private struct ThemedPanel: View {
    let title: String
    let message: String
    @Binding var text: String
    let primaryTitle: String
    let isValid: Bool
    let onPrimary: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFieldFocused: Bool
    @State private var appear: Bool = false

    var body: some View {
        ZStack {
            // Backdrop: mild dim (no heavy blur to preserve gradient feel)
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }       // background inert; tap scrim to dismiss

            // Popover card with crisp edge + subtle neon keyline
            VStack(spacing: 14) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(FuturistTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(FuturistTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(FuturistTheme.textSecondary)
                    TextField("Location name", text: $text)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isFieldFocused)
                        .onSubmit { if isValid { onPrimary() } }
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .tint(FuturistTheme.neonAqua)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(FuturistTheme.cardStroke, lineWidth: 1)
                )

                // Subtle divider above buttons
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
                    .accessibilityHidden(true)
                    .padding(.top, 2)

                HStack(spacing: 12) {
                    Button { onCancel() } label: {
                        Text("Cancel")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(FuturistTheme.softRedLight))
                            .overlay(
                                Capsule()
                                    .stroke(FuturistTheme.softRedBase.opacity(0.75), lineWidth: 1)
                            )
                            .shadow(color: FuturistTheme.cardShadow, radius: 3)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onPrimary()
                    } label: {
                        Text(primaryTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(FuturistTheme.softGreenLight))
                            .overlay(
                                Capsule()
                                    .stroke(FuturistTheme.softGreenBase.opacity(0.75), lineWidth: 1)
                            )
                            .shadow(color: FuturistTheme.cardShadow, radius: 3)
                            .opacity(isValid ? 1 : 0.6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValid)
                }
                .padding(.top, 2)
            }
            .padding(16)
            .background(
                // Slightly lighter/opaquer than list cards for separation
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.10, blue: 0.22).opacity(0.78))
            )
            // Double keyline: outer white + inner neon aqua (inset)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .inset(by: 1)
                    .stroke(FuturistTheme.neonAqua.opacity(0.18), lineWidth: 1)
            )
            // Elevation (no outer glow)
            .shadow(color: Color.black.opacity(0.42), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 24)
            // Entrance motion (gentle lift)
            .scaleEffect(appear ? 1.0 : 0.97)
            .offset(y: appear ? 0 : 8)
            .animation(.spring(response: 0.24, dampingFraction: 0.95), value: appear)
            .transition(.scale.combined(with: .opacity))
            .onAppear {
                appear = true
                // autofocus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isFieldFocused = true }
            }
            .onDisappear { appear = false }
        }
        .animation(.easeInOut(duration: 0.18), value: isValid)
    }
}

private struct AddLocationSheet: View {
    @Binding var isPresented: Bool
    @Binding var locationName: String
    var onAdd: (String) -> Void
    private var isValid: Bool { !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ThemedPanel(
            title: "Add Location",
            message: "Enter a new location.",
            text: $locationName,
            primaryTitle: "Add",
            isValid: isValid,
            onPrimary: {
                onAdd(locationName.trimmingCharacters(in: .whitespacesAndNewlines))
                isPresented = false
            },
            onCancel: { isPresented = false }
        )
    }
}

private struct EditLocationSheet: View {
    @Binding var isPresented: Bool
    @Binding var locationName: String
    var onSave: (String) -> Void
    private var isValid: Bool { !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ThemedPanel(
            title: "Edit Location",
            message: "Update the location name.",
            text: $locationName,
            primaryTitle: "Save",
            isValid: isValid,
            onPrimary: {
                onSave(locationName.trimmingCharacters(in: .whitespacesAndNewlines))
                isPresented = false
            },
            onCancel: { isPresented = false }
        )
    }
}

private struct DeleteConfirmSheet: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    var onDelete: () -> Void

    var body: some View {
        // Kept as-is; say the word and I’ll port the same popover/keyline styling here too.
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
struct SelectLocationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedLocationId: UUID?
    @Binding var selectedLocationNameSnapshot: String

    @State private var searchText: String = ""

    // Add
    @State private var showAddPrompt = false
    @State private var newLocationName: String = ""

    // Edit (themed sheet)
    @State private var showEditPrompt = false
    @State private var editTarget: LocationItem? = nil
    @State private var editNameText: String = ""

    // Swipe open tracking
    @State private var openRowId: UUID? = nil

    // Delete confirm (themed sheet)
    @State private var showDeletePrompt: Bool = false
    @State private var pendingDelete: LocationItem? = nil
    @State private var pendingDeleteUsageCount: Int = 0

    // Toast
    @State private var localToastMessage: String? = nil

    private var filteredLocations: [LocationItem] {
        let sorted = appState.locations.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { openRowId = nil } }

                ScrollView {
                    VStack(spacing: 0) {

                        // SEARCH + NONE (compact height)
                        VStack(spacing: 8) {
                            CompactTile {
                                HStack(spacing: 10) {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(FuturistTheme.textPrimary.opacity(0.92))
                                    TextField(
                                        "", text: $searchText,
                                        prompt: Text("Search")
                                            .foregroundStyle(FuturistTheme.textPrimary.opacity(0.92))
                                    )
                                    .textInputAutocapitalization(.none)
                                    .foregroundStyle(FuturistTheme.textPrimary)
                                    .tint(FuturistTheme.neonAqua)
                                }
                            }

                            CompactTile {
                                HStack {
                                    // Typography parity: regular weight
                                    Text("None")
                                        .foregroundStyle(FuturistTheme.textPrimary)
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedLocationId = nil
                                    selectedLocationNameSnapshot = ""
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, LocationRowMetrics.pageHPad)
                        .padding(.top, 12)

                        // LOCATIONS HEADER
                        Text("Locations")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(FuturistTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                            .padding(.horizontal, LocationRowMetrics.pageHPad)

                        // LOCATIONS LIST (separator-only spacing)
                        VStack(spacing: 0) {
                            if filteredLocations.isEmpty {
                                Text("No locations yet. Tap Add to create one.")
                                    .font(.footnote)
                                    .foregroundStyle(FuturistTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(Array(filteredLocations.enumerated()), id: \.element.id) { idx, loc in
                                    // Card
                                    SwipeRevealRow(
                                        id: loc.id,
                                        openRowId: $openRowId,
                                        rowContent: {
                                            LocationTile {
                                                HStack(spacing: 8) {
                                                    // Typography parity: regular weight row title
                                                    Text(loc.name)
                                                        .foregroundStyle(FuturistTheme.textPrimary)
                                                        .font(.subheadline)
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: LocationRowMetrics.chevronSize, weight: .semibold))
                                                        .foregroundStyle(LocationRowMetrics.chevronTint)
                                                        .opacity(openRowId == loc.id ? 0 : 1) // hide while rail open
                                                }
                                            }
                                        },
                                        onTapRow: {
                                            selectedLocationId = loc.id
                                            selectedLocationNameSnapshot = loc.name
                                            dismiss()
                                        },
                                        onEdit: {
                                            withAnimation { openRowId = nil }
                                            editTarget = loc
                                            editNameText = loc.name
                                            showEditPrompt = true
                                        },
                                        onDelete: {
                                            withAnimation { openRowId = nil }
                                            pendingDelete = loc
                                            pendingDeleteUsageCount = appState.eventAssignments.filter { $0.locationId == loc.id }.count
                                            showDeletePrompt = true
                                        }
                                    )
                                    .padding(.horizontal, LocationRowMetrics.pageHPad)
                                    .padding(.top, idx == 0 ? LocationRowMetrics.firstRowTopPad
                                                            : LocationRowMetrics.betweenRowsTopPad)

                                    // Filament between cards (not after last) — no extra vertical padding
                                    if idx < filteredLocations.count - 1 {
                                        BrightLineSeparator()
                                            .padding(.vertical, LocationRowMetrics.separatorVerticalPad)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            if openRowId != nil { withAnimation { openRowId = nil } }
                        }
                    )
                }

                // Toast
                if let msg = localToastMessage {
                    ToastBannerView(message: msg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }

                // Themed panels
                if showAddPrompt {
                    AddLocationSheet(
                        isPresented: $showAddPrompt,
                        locationName: $newLocationName,
                        onAdd: { name in addLocation(named: name) }
                    )
                    .zIndex(20)
                    .transition(.opacity)
                }

                if showEditPrompt, let _ = editTarget {
                    EditLocationSheet(
                        isPresented: $showEditPrompt,
                        locationName: $editNameText,
                        onSave: { newName in
                            performRename(newName: newName)
                        }
                    )
                    .zIndex(20)
                    .transition(.opacity)
                }

                if showDeletePrompt {
                    DeleteConfirmSheet(
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

            // Custom top bar (Close / title / Add)
            .safeAreaInset(edge: .top, spacing: 0) {
                ZStack {
                    Text("Select Location")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(FuturistTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack {
                        let pillWidth: CGFloat = 76
                        let pillHeight: CGFloat = 32

                        Text("Close")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: pillWidth, height: pillHeight)
                            .background(Capsule().fill(FuturistTheme.softRedLight))
                            .overlay(Capsule().stroke(FuturistTheme.softRedBase.opacity(0.75), lineWidth: 1))
                            .shadow(color: FuturistTheme.cardShadow, radius: 3)
                            .contentShape(Capsule())
                            .onTapGesture { dismiss() }

                        Spacer(minLength: 12)

                        Text("Add")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.9))
                            .frame(width: pillWidth, height: pillHeight)
                            .background(Capsule().fill(FuturistTheme.softGreenLight))
                            .overlay(Capsule().stroke(FuturistTheme.softGreenBase.opacity(0.75), lineWidth: 1))
                            .shadow(color: FuturistTheme.cardShadow, radius: 3)
                            .contentShape(Capsule())
                            .onTapGesture {
                                newLocationName = ""
                                withAnimation(.easeInOut(duration: 0.18)) { showAddPrompt = true }
                            }
                            .accessibilityLabel(Text("Add Location"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .background(Color.clear)
            }
        }
    }

    // MARK: - Delete prompt messages
    private var deleteAlertTitle: String {
        guard let loc = pendingDelete else { return "Delete Location" }
        return "Delete “\(loc.name)”?"
    }

    private var deleteAlertMessage: String {
        guard pendingDeleteUsageCount > 0 else {
            return "This will remove the location from your list. This action cannot be undone."
        }
        let n = pendingDeleteUsageCount
        let plural = n == 1 ? "event" : "events"
        return "This location is currently used by \(n) \(plural). Deleting it will clear the Location field on those \(plural). This cannot be undone."
    }

    // MARK: - Actions
    private func addLocation(named name: String) {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if let loc = appState.createLocation(name: t) {
            selectedLocationId = loc.id
            selectedLocationNameSnapshot = loc.name
            dismiss()
        }
    }

    private func performRename(newName: String) {
        guard let target = editTarget else { return }
        let t = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        let ok = appState.renameLocation(id: target.id, newName: t)
        if ok, selectedLocationId == target.id {
            selectedLocationNameSnapshot = t
        }
        editTarget = nil
        showEditPrompt = false

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast("Saved “\(t)”")
    }

    private func performDeleteConfirmed() {
        guard let loc = pendingDelete else { return }
        let usage = pendingDeleteUsageCount

        // Cascade clear: locationId = nil
        if usage > 0 {
            let impacted = appState.eventAssignments.filter { $0.locationId == loc.id }
            for var ev in impacted {
                var updated = ev
                updated.locationId = nil
                _ = appState.updateEventAssignment(updated)
            }
        }

        appState.deleteLocation(id: loc.id)

        if selectedLocationId == loc.id {
            selectedLocationId = nil
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast("Deleted “\(loc.name)”" + (usage > 0 ? " and cleared it from \(usage) event\(usage == 1 ? "" : "s")" : ""))

        pendingDelete = nil
        pendingDeleteUsageCount = 0
        showDeletePrompt = false
    }

    private func showToast(_ msg: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { localToastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.2)) { localToastMessage = nil }
        }
    }
}
