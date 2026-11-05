import SwiftUI

/// Shared by Activity's day strip, planned-day chooser and older-week history.
/// List edits save immediately. Counts remain a draft until Save log succeeds.
struct QuickLogSheet: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let date: Date
    var onClose: () -> Void

    @State private var counts: [String: Int] = [:]
    @State private var editing = false
    @State private var adding = false
    @State private var name = ""
    @State private var nameError: String?
    @State private var saveFailed = false
    @State private var removed: RemovedTechnique?

    private struct RemovedTechnique {
        var technique: QuickLogTechnique
        var index: Int
        var count: Int
    }

    private var canSave: Bool { !mm.quickLogHits(counts: counts).isEmpty && !adding && !mm.busy }

    var body: some View {
        ScrollView {
            MMDialogBody(title: "What did you hit today?", onClose: onClose) {
                VStack(alignment: .leading, spacing: MMSpace.s6) {
                    HStack {
                        Spacer(minLength: 0)
                        MMButton(editing ? "Done" : "Edit", variant: .ghost) {
                            withAnimation(reduceMotion ? nil : MMMotion.easeOut()) { editing.toggle() }
                        }
                        .accessibilityLabel(editing ? "Finish editing techniques" : "Edit techniques")
                    }
                    .padding(.bottom, -MMSpace.s6)

                    techniqueList
                    addTechnique

                    if let removed {
                        MMToast(message: "\(removed.technique.name) removed", actionLabel: "Undo") {
                            withAnimation(reduceMotion ? nil : MMMotion.easeOut()) {
                                mm.restoreQuickLogTechnique(removed.technique, at: removed.index)
                                counts[removed.technique.id] = removed.count
                                self.removed = nil
                            }
                        }
                    }
                    if saveFailed {
                        Text("Couldn't save your log. Try again.")
                            .mmFont(.body, 13).foregroundStyle(MMColor.danger500)
                            .accessibilityIdentifier("quick-log-save-error")
                    }
                }
            } actions: { EmptyView() }
            .padding(.horizontal, MMLayout.gutter)
            .padding(.top, MMSpace.s8)
            .padding(.bottom, MMSpace.s6)
            .disabled(mm.busy)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: MMSpace.s6) {
                HStack(spacing: MMSpace.s2) {
                    MMIcon("lock", size: 14, color: MMColor.textTertiary)
                    Text("Only you can see this.").mmFont(.body, 13).foregroundStyle(MMColor.textSecondary)
                }
                MMButton(mm.savingTraining ? "Saving…" : "Save log", fullWidth: true) { save() }
                    .disabled(!canSave)
                    .accessibilityIdentifier("quick-log-save")
            }
            .padding(MMLayout.gutter)
            .background(MMColor.surfaceCard)
        }
        .background(MMColor.surfaceCard)
        .presentationBackground(MMColor.surfaceCard)
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MMRadius.xl)
        .interactiveDismissDisabled(mm.savingTraining)
        .onChange(of: mm.quickLogAccount) { _, _ in onClose() }
    }

    private var techniqueList: some View {
        VStack(spacing: 0) {
            ForEach(mm.quickLogTechniques) { technique in
                HStack(alignment: .center, spacing: MMSpace.s4) {
                    Text(technique.name)
                        .mmFont(.display, 16)
                        .foregroundStyle(MMColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if editing {
                        MMIconButton("circle-minus", active: true, activeColor: MMColor.coral700,
                                     label: "Remove \(technique.name)") { remove(technique) }
                    } else {
                        repControls(technique)
                    }
                }
                .padding(.vertical, MMSpace.s4)
                if technique.id != mm.quickLogTechniques.last?.id {
                    Divider().overlay(MMColor.borderSubtle)
                }
            }
        }
    }

    private func repControls(_ technique: QuickLogTechnique) -> some View {
        let count = counts[technique.id, default: 0]
        return HStack(spacing: MMSpace.s2) {
            MMIconButton("minus", variant: .filled, label: "One fewer \(technique.name)") {
                changeCount(technique.id, by: -1)
            }
            .disabled(count == 0)
            .opacity(count == 0 ? 0.45 : 1)
            Text("\(count)")
                .mmFont(.body, 16, .bold)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(count == 0 ? MMColor.textTertiary : MMColor.textPrimary)
                .frame(minWidth: MMSpace.s8)
                .accessibilityLabel("\(technique.name), \(count) reps")
            MMIconButton("plus", variant: .inverse, label: "One more \(technique.name)") {
                changeCount(technique.id, by: 1)
            }
            .disabled(count == Int.max)
        }
    }

    @ViewBuilder private var addTechnique: some View {
        if adding {
            VStack(alignment: .leading, spacing: MMSpace.s5) {
                MMTextField(label: "Technique name", placeholder: "e.g. Triangle", text: $name,
                            error: nameError, autoFocus: true, onSubmit: add)
                    .submitLabel(.done)
                    .onChange(of: name) { _, _ in nameError = nil }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: MMSpace.s5) { addActions }
                    VStack(spacing: MMSpace.s5) { addActions }
                }
            }
        } else {
            MMButton("Add technique", variant: .secondary, iconLeft: "plus", fullWidth: true) {
                adding = true
                name = ""
                nameError = nil
            }
            .accessibilityIdentifier("quick-log-add-technique")
        }
    }

    @ViewBuilder private var addActions: some View {
        MMButton("Cancel", variant: .ghost, fullWidth: true) { adding = false; name = "" }
        MMButton("Add technique", variant: .inverse, fullWidth: true, action: add)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func changeCount(_ id: String, by delta: Int) {
        withAnimation(reduceMotion ? nil : MMMotion.easeOut(MMMotion.fast)) {
            counts[id] = max(0, counts[id, default: 0] + delta)
        }
    }

    private func add() {
        guard let technique = mm.addQuickLogTechnique(name) else {
            nameError = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Enter a technique name." : "That technique is already in your list."
            return
        }
        if removed?.technique.name.caseInsensitiveCompare(technique.name) == .orderedSame { removed = nil }
        adding = false
        name = ""
        nameError = nil
    }

    private func remove(_ technique: QuickLogTechnique) {
        guard let index = mm.quickLogTechniques.firstIndex(where: { $0.id == technique.id }) else { return }
        withAnimation(reduceMotion ? nil : MMMotion.easeOut()) {
            removed = RemovedTechnique(technique: technique, index: index, count: counts[technique.id, default: 0])
            counts.removeValue(forKey: technique.id)
            mm.removeQuickLogTechnique(technique.id)
        }
    }

    private func save() {
        guard canSave else { return }
        saveFailed = false
        Task {
            if await mm.addQuickLog(date, counts: counts) { onClose() }
            else { saveFailed = true }
        }
    }
}
