import SwiftUI

private struct QuickLogSheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Two modes. With `logID`, Activity's "Log techniques" counts hits on a quick log that
/// already exists, saving each tap. Without it (Stats' first log), counts stay a draft
/// until Save log creates the log. List edits always save immediately.
struct QuickLogSheet: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let date: Date
    var logID: String? = nil
    var onClose: () -> Void

    @State private var counts: [String: Int] = [:]
    @State private var editing = false
    @State private var adding = false
    @State private var name = ""
    @State private var nameError: String?
    @State private var saveFailed = false
    @State private var removed: RemovedTechnique?
    @State private var contentHeight: CGFloat = 320

    private struct RemovedTechnique {
        var technique: QuickLogTechnique
        var index: Int
        var count: Int
    }

    private var canSave: Bool { !mm.quickLogHits(counts: counts).isEmpty && !adding && !mm.busy }
    private var title: String {
        logID == nil ? "What did you hit today?" : "What landed on \(date.formatted(.dateTime.weekday(.wide)))?"
    }

    var body: some View {
        ScrollView {
            MMDialogBody(title: title,
                         description: logID == nil ? nil : "Subs, sweeps, passes. Optional, and it saves as you tap.",
                         onClose: onClose) {
                VStack(alignment: .leading, spacing: MMSpace.s6) {
                    HStack {
                        Spacer(minLength: 0)
                        MMButton(editing ? (logID == nil ? "Done" : "Done editing") : "Edit", variant: .ghost) {
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
                                if let logID { mm.setQuickLogHits(logID, counts: counts) }
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
            } actions: {
                if logID != nil {
                    HStack(spacing: MMSpace.s5) {
                        if !mm.quickLogHits(counts: counts).isEmpty {
                            HStack(spacing: MMSpace.s2) {
                                MMIcon("circle-check", size: 14, color: MMColor.mint500)
                                Text("Saved to Stats").mmFont(.body, 12).foregroundStyle(MMColor.textTertiary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Spacer(minLength: 0)
                        MMButton("Done", variant: .inverse, action: onClose)
                            .accessibilityIdentifier("quick-log-done")
                    }
                } else {
                    MMButton(mm.savingTraining ? "Saving…" : "Save log", fullWidth: true) { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("quick-log-save")
                }
            }
            .padding(.horizontal, MMLayout.gutter)
            .padding(.top, MMSpace.s8)
            .padding(.bottom, MMSpace.s6)
            .background {
                // Match the shared sheet pattern: measure the full content so short
                // lists keep Save log close and longer lists scroll at the system cap.
                GeometryReader { geometry in
                    Color.clear.preference(key: QuickLogSheetHeightKey.self, value: geometry.size.height)
                }
            }
            .disabled(mm.busy)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .onPreferenceChange(QuickLogSheetHeightKey.self) { height in
            if height > 0 { contentHeight = height }
        }
        .background(MMColor.surfaceCard)
        .presentationBackground(MMColor.surfaceCard)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MMRadius.xl)
        .interactiveDismissDisabled(mm.savingTraining)
        .onChange(of: mm.quickLogAccount) { _, _ in onClose() }
        // Undo or removal deletes the log being edited, so there is nothing left to count on.
        .onChange(of: mm.quickLogs.map(\.id)) { _, ids in
            if let logID, !ids.contains(logID) { onClose() }
        }
        .onAppear {
            guard let logID else { return }
            counts = Dictionary((mm.quickLogHitsByID[logID] ?? []).map { ($0.id, $0.count) }, uniquingKeysWith: +)
        }
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
                    HStack(spacing: MMSpace.s5) {
                        cancelAdd
                        Spacer(minLength: MMSpace.s5)
                        confirmAdd
                    }
                    VStack(alignment: .leading, spacing: MMSpace.s5) {
                        cancelAdd
                        confirmAdd
                    }
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

    private var cancelAdd: some View {
        Button { adding = false; name = "" } label: {
            Text("Cancel")
                .mmFont(.display, MMButtonSize.md.fontSize, .bold, tracking: -0.01, lineHeight: 1)
                .foregroundStyle(MMColor.textPrimary)
                .frame(minWidth: MMLayout.tapTarget, minHeight: MMButtonSize.md.height, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(MMPressStyle())
    }

    // Secondary, so the sheet's own action (Done or Save log) stays the clear main button.
    private var confirmAdd: some View {
        MMButton("Add technique", variant: .secondary, action: add)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func changeCount(_ id: String, by delta: Int) {
        withAnimation(reduceMotion ? nil : MMMotion.easeOut(MMMotion.fast)) {
            counts[id] = max(0, counts[id, default: 0] + delta)
        }
        if let logID { mm.setQuickLogHits(logID, counts: counts) }
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
