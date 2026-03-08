//
// ParentChildrenTabView.swift
// parent_child_checklist
//
// Updated: header + button now uses soft–green pill with black plus icon
// + Added “Show Pairing QR” per-child action, presenting ShowPairingQRView
//

import SwiftUI

// MARK: - Futurist theme tokens (aligned with other screens)
private enum FuturistTheme {
    static let skyTop = Color(red: 0.02, green: 0.06, blue: 0.16)
    static let skyBottom = Color(red: 0.01, green: 0.03, blue: 0.10)
    static let neonAqua = Color(red: 0.20, green: 0.95, blue: 1.00)
    static let textPrimary = Color(red: 0.92, green: 0.97, blue: 1.00)
    static let textSecondary = Color.white.opacity(0.78)
    static let cardStroke = Color.white.opacity(0.08)
    static let cardShadow = Color.black.opacity(0.10)
    // Pastel pills (same palette used elsewhere)
    static let softGreenBase = Color(red: 0.27, green: 0.89, blue: 0.54)
    static let softGreenLight = Color(red: 0.62, green: 0.95, blue: 0.73)
}

// MARK: - Frosted card background
private struct CardBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = 14
    var body: some View {
        let surface = reduceTransparency
        ? Color(red: 0.05, green: 0.10, blue: 0.22)
        : Color(red: 0.04, green: 0.08, blue: 0.18).opacity(0.70)
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FuturistTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: FuturistTheme.cardShadow, radius: 6, x: 0, y: 2)
    }
}

// MARK: - Neon divider between rows
private struct NeonRule: View {
    var leadingInset: CGFloat = 16
    var trailingInset: CGFloat = 14
    var thickness: CGFloat = 2
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: FuturistTheme.skyTop.opacity(0.95), location: 0.00),
                .init(color: FuturistTheme.neonAqua, location: 0.50),
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
        .accessibilityHidden(true)
    }
}

// MARK: - Soft–green pill + with black icon (matches Select Task header)
private struct GreenPillPlusButton: View {
    let action: () -> Void
    private let pillWidth: CGFloat = 76
    private let pillHeight: CGFloat = 32
    @State private var pressed = false
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.20, dampingFraction: 0.8)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.9)) { pressed = false }
            }
            action()
        } label: {
            ZStack {
                Capsule()
                    .fill(FuturistTheme.softGreenLight)
                    .overlay(
                        Capsule().stroke(FuturistTheme.softGreenBase.opacity(0.75), lineWidth: 1)
                    )
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.9))
            }
            .frame(width: pillWidth, height: pillHeight)
            .shadow(color: FuturistTheme.softGreenLight.opacity(0.28), radius: 3)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.96 : 1.0)
        .accessibilityLabel("Add Child")
    }
}

// MARK: - One row — left: NavigationLink, right: action cluster (no swipe)
private struct ParentChildRow: View {
    let child: ChildProfile
    let destination: () -> AnyView // ParentChildWeeklyView wrapped into AnyView
    let onTappedInto: () -> Void   // persist lastParentChildId, etc.
    let onEdit: () -> Void
    let onDelete: () -> Void
    // NEW: show pairing QR
    let onShowPairingQR: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // LEFT tappable area navigates
            NavigationLink {
                destination()
            } label: {
                HStack(spacing: 12) {
                    ChildAvatarCircleView(
                        colorHex: child.colorHex,
                        avatarId: child.avatarId,
                        size: 36
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.name)
                            .font(.headline)
                            .foregroundStyle(FuturistTheme.textPrimary)
                        let subtitle = child.avatarId == nil
                        ? "Not chosen yet"
                        : AvatarCatalog.avatar(for: child.avatarId).displayName
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(FuturistTheme.textSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .simultaneousGesture(TapGesture().onEnded { onTappedInto() })
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            // RIGHT trailing action cluster — centered vertically
            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onEdit()
                } label: {
                    Text("Edit")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(child.name)")

                Menu {
                    // NEW: Show Pairing QR
                    Button {
                        onShowPairingQR()
                    } label: {
                        Label("Show Pairing QR", systemImage: "qrcode")
                    }

                    // Existing: Delete
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(FuturistTheme.textSecondary)
                        .padding(.horizontal, 2)
                }
                .accessibilityLabel("More actions for \(child.name)")
            }
            .frame(maxHeight: .infinity) // ensures optical vertical centering
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Screen

struct ParentChildrenTabView: View {
    @AppStorage("userRole") private var userRoleRawValue: String?
    @AppStorage("selectedChildId") private var selectedChildIdRaw: String?
    // 🔹 Optional: write last viewed child as soon as parent taps a child
    @AppStorage("lastParentChildId") private var lastParentChildIdRaw: String?
    @EnvironmentObject private var appState: AppState

    @State private var showAddChild = false
    @State private var childPendingDelete: ChildProfile?
    @State private var childPendingEdit: ChildProfile?

    // NEW: sheet for Show Pairing QR
    @State private var showPairingQRForChild: ChildProfile?

    // Neon rule spacing
    private static let ruleLeadingInset: CGFloat = 16
    private static let ruleTrailingInset: CGFloat = 14
    private static let ruleExtraBottomPadding: CGFloat = 6
    private static let ruleVerticalOffset: CGFloat = 6

    private var childrenSorted: [ChildProfile] {
        appState.children.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                CurvyAquaBlueBackground(animate: true)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // ===== Header (title + green + pill) =====
                    HStack(alignment: .center) {
                        Text("Parent")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(FuturistTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        GreenPillPlusButton {
                            showAddChild = true
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                    // ===== List of children =====
                    if childrenSorted.isEmpty {
                        VStack {
                            Spacer(minLength: 24)
                            Text("No children yet.")
                                .foregroundStyle(FuturistTheme.textSecondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            Section {
                                let items = childrenSorted
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, child in
                                    // Card wrapper to place neon rule per-row
                                    VStack(spacing: 0) {
                                        ParentChildRow(
                                            child: child,
                                            destination: {
                                                AnyView(
                                                    ParentChildWeeklyView(childId: child.id)
                                                        .environmentObject(appState)
                                                )
                                            },
                                            onTappedInto: {
                                                lastParentChildIdRaw = child.id.uuidString
                                            },
                                            onEdit: {
                                                childPendingEdit = child
                                            },
                                            onDelete: {
                                                childPendingDelete = child
                                            },
                                            // NEW
                                            onShowPairingQR: {
                                                showPairingQRForChild = child
                                            }
                                        )
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                    }
                                    .padding(.bottom, Self.ruleExtraBottomPadding)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(CardBackground())
                                    .overlay(alignment: .bottomLeading) {
                                        if index < items.count - 1 {
                                            NeonRule(
                                                leadingInset: Self.ruleLeadingInset,
                                                trailingInset: Self.ruleTrailingInset,
                                                thickness: 2
                                            )
                                            .offset(y: Self.ruleVerticalOffset)
                                        }
                                    }
                                    // 🔒 No swipeActions here (explicit trailing actions).
                                }
                            } header: {
                                Text("Children")
                                    .foregroundStyle(FuturistTheme.textPrimary)
                                    .textCase(nil)
                                    .padding(.top, 6)
                                    .padding(.bottom, 4)
                            }

                            Section {
                                Button("Switch Role (Temporary)") {
                                    userRoleRawValue = nil
                                    selectedChildIdRaw = nil
                                }
                                .foregroundStyle(.red)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.insetGrouped)
                        .environment(\.defaultMinListHeaderHeight, 0)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar) // we render our own header
            .navigationBarTitleDisplayMode(.inline)
            // ===== Sheets =====
            .sheet(isPresented: $showAddChild) {
                AddChildView()
                    .environmentObject(appState)
            }
            .sheet(item: $childPendingEdit) { child in
                EditChildView(child: child)
                    .environmentObject(appState)
            }
            // NEW: Show Pairing QR sheet
            .sheet(item: $showPairingQRForChild) { child in
                ShowPairingQRView(
                    child: child,
                    pairingEpoch: child.pairingEpoch,
                    onClose: { showPairingQRForChild = nil }
                )
            }
            // ===== Delete confirm =====
            .alert(
                "Delete child?",
                isPresented: Binding(
                    get: { childPendingDelete != nil },
                    set: { if !$0 { childPendingDelete = nil } }
                )
            ) {
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
