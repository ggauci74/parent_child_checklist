//
// ReviewRewardRequestView.swift
// parent_child_checklist
//

import SwiftUI

struct ReviewRewardRequestView: View, Identifiable {
    var id: UUID { request.id }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let request: RewardRequest

    @State private var titleText: String
    @State private var gemCost: Int
    @State private var showDeleteConfirm = false

    init(request: RewardRequest) {
        self.request = request
        _titleText = State(initialValue: request.title)
        _gemCost = State(initialValue: max(0, request.approvedCost ?? 0))
    }

    private var childName: String {
        appState.children.first(where: { $0.id == request.childId })?.name ?? "Child"
    }

    private var isPending: Bool { request.status == .pending }
    private var isApprovedOrClaimed: Bool { request.status == .approved || request.status == .claimed }

    private func fmt(_ d: Date?) -> String? {
        guard let d else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: d)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Request") {
                    HStack {
                        Text("Child")
                        Spacer()
                        Text(childName).foregroundStyle(.secondary)
                    }
                    if isPending {
                        TextField("Title", text: $titleText, axis: .vertical)
                            .lineLimit(2, reservesSpace: true)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                    } else {
                        Text(request.title)
                            .font(.headline)
                    }
                }

                if isPending {
                    Section("Gem Cost") {
                        Stepper("Cost: \(gemCost)", value: $gemCost, in: 0...999)
                        TextField("Enter cost", value: $gemCost, format: .number)
                            .keyboardType(.numberPad)
                    }
                } else if isApprovedOrClaimed, let cost = request.approvedCost {
                    Section("Gem Cost") {
                        HStack {
                            Text("Cost")
                            Spacer()
                            Text("💎 \(cost)")
                                .fontWeight(.semibold)
                        }
                    }
                }

                // Timeline
                Section("Timeline") {
                    HStack {
                        Text("Requested")
                        Spacer()
                        Text(fmt(request.requestedAt) ?? "-")
                            .foregroundStyle(.secondary)
                    }
                    if request.status == .approved || request.approvedAt != nil {
                        HStack {
                            Text("Approved")
                            Spacer()
                            Text(fmt(request.approvedAt) ?? "-")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if request.status == .notApproved || request.notApprovedAt != nil {
                        HStack {
                            Text("Not this time")
                            Spacer()
                            Text(fmt(request.notApprovedAt) ?? "-")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if request.status == .claimed || request.claimedAt != nil {
                        HStack {
                            Text("Claimed")
                            Spacer()
                            Text(fmt(request.claimedAt) ?? "-")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    if isPending {
                        Button {
                            let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
                            _ = appState.approveRewardRequest(id: request.id, cost: gemCost, newTitle: trimmed)
                            dismiss()
                        } label: {
                            Label("Approve", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            _ = appState.notApproveRewardRequest(id: request.id)
                            dismiss()
                        } label: {
                            Label("Not this time", systemImage: "hand.raised")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("This request is \(request.status.childDisplay.lowercased()).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Request", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Delete this request?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    _ = appState.deleteRewardRequest(id: request.id)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the request.")
            }
        }
    }
}
