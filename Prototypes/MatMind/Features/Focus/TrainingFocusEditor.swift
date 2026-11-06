import SwiftUI

/// A focus is a session checklist item; its outline and private goal references
/// stay intact underneath. The shared checkbox supplies the app's coral state.
struct TrainingFocusChecklist: View {
    var items: [TrainingFocus]
    var onToggle: ((UUID, Bool) -> Void)? = nil
    @Environment(AppModel.self) private var mm

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s5) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider() }
                HStack(alignment: .top, spacing: MMSpace.s4) {
                    VStack(alignment: .leading, spacing: MMSpace.s3) {
                        MMCheckbox(isOn: Binding(
                            get: { item.isCompleted },
                            set: { onToggle?(item.id, $0) }
                        ), label: item.title)
                        .frame(maxWidth: .infinity, minHeight: MMLayout.tapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                        .disabled(onToggle == nil)
                        .accessibilityValue(item.isCompleted ? "Completed" : "Not completed")
                        .accessibilityHint(onToggle == nil ? "Mark complete after training" : "Mark what you worked on")

                        if !item.children.isEmpty {
                            VStack(alignment: .leading, spacing: MMSpace.s2) {
                                ForEach(TrainingFocusTree.rows(item.children)) { row in
                                    Text(row.node.title)
                                        .mmText(.bodyS)
                                        .foregroundStyle(MMColor.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.leading, CGFloat(min(row.depth, 3)) * MMSpace.s5)
                                }
                            }
                            .padding(.leading, MMSpace.s8 + MMSpace.s5)
                        }
                        if let goal = item.linkedGoal(in: mm.goals), goal.hasReferenceContent {
                            TrainingGoalNotes(goal: goal, initiallyExpanded: false)
                                .padding(.leading, MMSpace.s8 + MMSpace.s5)
                        }
                    }
                }
            }
        }
        .padding(MMSpace.s6)
        .mmCardSurface()
    }
}

/// Inline checklist editing uses the same row shape as the saved checklist.
/// A blank first row makes the interaction visible before any focus is entered.
struct TrainingFocusComposer: View {
    @Binding var items: [TrainingFocus]
    var allowsCompletion = false
    var goals: [MatGoal] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedField: Field?
    @State private var removalID: UUID?
    @State private var showRemoval = false

    private enum Field: Hashable {
        case title(UUID), description(UUID), detail(UUID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s5) {
            if !goals.isEmpty {
                MMFlowLayout(spacing: MMSpace.s4, lineSpacing: MMSpace.s4) {
                    ForEach(goals) { goal in
                        let picked = items.first { $0.linkedGoal(in: goals)?.id == goal.id }
                        MMTag(goal.title, icon: picked == nil ? "plus" : "check", selected: picked != nil, size: .sm) {
                            if let picked { requestRemoval(picked) }
                            else {
                                items = TrainingFocusTree.optionalOutline(items)
                                items.append(TrainingFocus(title: goal.title, goalID: goal.id))
                            }
                        }
                    }
                }
                .accessibilityLabel("Your goals")
            }
            VStack(alignment: .leading, spacing: MMSpace.s5) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, root in
                    if index > 0 { Divider() }
                    checklistRow(root)
                }
                Divider()
                MMButton("Add a focus", variant: .ghost, iconLeft: "plus", fullWidth: true) { addFocus() }
            }
            .padding(MMSpace.s6)
            .mmCardSurface()
            if !TrainingFocusTree.isValid(TrainingFocusTree.optionalOutline(items)) {
                Text("Name each focus, or remove the blank one.")
                    .mmText(.bodyS)
                    .foregroundStyle(MMColor.textTertiary)
            }
        }
        .onAppear { ensureFirstRow() }
        .alert("Remove this focus?", isPresented: $showRemoval) {
            Button("Keep it", role: .cancel) { removalID = nil }
            Button("Remove", role: .destructive) {
                if let removalID { remove(removalID) }
                removalID = nil
            }
        } message: {
            Text("Its details will be removed too.")
        }
    }

    private func checklistRow(_ root: TrainingFocus) -> some View {
        HStack(alignment: .top, spacing: MMSpace.s5) {
            MMCheckbox(isOn: Binding(
                get: { root.isCompleted },
                set: { completed in
                    TrainingFocusTree.update(root.id, in: &items) { $0.isCompleted = completed }
                }
            ))
            .padding(.top, (MMLayout.tapTarget - MMSpace.s8) / 2)
            .disabled(!allowsCompletion || root.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(root.title.isEmpty ? "Training focus" : root.title)
            .accessibilityValue(root.isCompleted ? "Completed" : "Not completed")
            .accessibilityHint(allowsCompletion ? "Mark what you worked on" : "Mark complete after training")

            VStack(alignment: .leading, spacing: MMSpace.s1) {
                TextField("Focus title", text: titleBinding(root.id), axis: .vertical)
                    .font(MMFont.body(16, .bold))
                    .lineLimit(1...3)
                    .frame(minHeight: MMLayout.tapTarget)
                    .focused($focusedField, equals: .title(root.id))
                    .accessibilityLabel("Focus title")
                    .accessibilityIdentifier("focus-title-\(root.id)")
                HStack(alignment: .top, spacing: MMSpace.s2) {
                    TextField("Add a description", text: descriptionBinding(root.id), axis: .vertical)
                        .font(MMFont.body(13))
                        .foregroundStyle(MMColor.textSecondary)
                        .lineLimit(1...4)
                        .frame(minHeight: MMLayout.tapTarget, alignment: .topLeading)
                        .focused($focusedField, equals: .description(root.id))
                        .accessibilityLabel("Focus description")
                    if let first = root.children.first, root.children.count > 1 || !first.children.isEmpty {
                        MMIconButton("x", label: "Remove description") { requestRemoval(first) }
                    }
                }

                ForEach(TrainingFocusTree.rows(root.children).dropFirst()) { row in
                    HStack(alignment: .top, spacing: MMSpace.s2) {
                        TextField("Detail", text: titleBinding(row.id), axis: .vertical)
                            .font(MMFont.body(13))
                            .foregroundStyle(MMColor.textSecondary)
                            .lineLimit(1...4)
                            .frame(minHeight: MMLayout.tapTarget)
                            .focused($focusedField, equals: .detail(row.id))
                            .accessibilityLabel("Focus detail, level \(row.depth + 2)")
                        MMIconButton("x", label: "Remove detail") { requestRemoval(row.node) }
                    }
                    .padding(.leading, CGFloat(min(row.depth, 3)) * MMSpace.s5)
                }
                if let goal = root.linkedGoal(in: goals), goal.hasReferenceContent {
                    TrainingGoalNotes(goal: goal, initiallyExpanded: false)
                }
            }
            .foregroundStyle(MMColor.textPrimary)
            .tint(MMColor.accent)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }

            Menu {
                Button("Add a detail") {
                    let detail = TrainingFocus()
                    TrainingFocusTree.update(root.id, in: &items) { $0.children.append(detail) }
                    focusedField = root.children.isEmpty ? .description(root.id) : .detail(detail.id)
                }
                Button("Remove focus", role: .destructive) { requestRemoval(root) }
            } label: {
                MMIcon("ellipsis", size: 18, color: MMColor.textTertiary)
                    .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(root.title.isEmpty ? "focus" : root.title)")
        }
    }

    private func titleBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { TrainingFocusTree.find(id, in: items)?.title ?? "" },
                set: { value in TrainingFocusTree.update(id, in: &items) { $0.title = value } })
    }

    private func descriptionBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { TrainingFocusTree.find(id, in: items)?.children.first?.title ?? "" },
                set: { value in
                    TrainingFocusTree.update(id, in: &items) { root in
                        root.detailDescription = value
                    }
                })
    }

    private func ensureFirstRow() {
        if items.isEmpty { items = [TrainingFocus()] }
    }

    private func addFocus() {
        if let blank = items.first(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.children.isEmpty }) {
            focusedField = .title(blank.id)
            return
        }
        let item = TrainingFocus()
        withAnimation(reduceMotion ? nil : MMMotion.easeOut()) { items.append(item) }
        focusedField = .title(item.id)
    }

    private func requestRemoval(_ node: TrainingFocus) {
        if node.children.isEmpty { remove(node.id) }
        else { removalID = node.id; showRemoval = true }
    }

    private func remove(_ id: UUID) {
        focusedField = nil
        withAnimation(reduceMotion ? nil : MMMotion.easeOut()) {
            TrainingFocusTree.remove(id, from: &items)
            ensureFirstRow()
        }
    }
}

/// Save a check through the same versioned focus update used by the editor.
/// Render saved state, so failed requests never leave an unsaved check on screen.
struct TrainingSessionFocusChecklist: View {
    let session: Session
    @Environment(AppModel.self) private var mm
    @State private var saving = false

    private var canComplete: Bool {
        session.organizer == "me" && mm.trainingSessions(past: true).contains { $0.id == session.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s4) {
            HStack {
                if canComplete {
                    Text("Mark what you worked on.").mmText(.bodyS)
                        .foregroundStyle(MMColor.textTertiary)
                }
                Spacer(minLength: 0)
                MMMeta("\(session.focusItems.filter(\.isCompleted).count)/\(session.focusItems.count)")
                    .accessibilityLabel("\(session.focusItems.filter(\.isCompleted).count) of \(session.focusItems.count) focuses completed")
            }
            TrainingFocusChecklist(items: session.focusItems, onToggle: canComplete ? toggle : nil)
                .disabled(saving || mm.busy)
        }
    }

    private func toggle(_ id: UUID, _ completed: Bool) {
        guard !saving, !mm.busy, canComplete,
              var items = mm.findSession(session.id)?.focusItems else { return }
        TrainingFocusTree.update(id, in: &items) { $0.isCompleted = completed }
        saving = true
        Task {
            if let runtime = mm.runtime {
                _ = await runtime.saveFocus(session.id, items)
            } else {
                mm.updateSessionFocus(session.id, items)
            }
            saving = false
        }
    }
}

/// References stay on your goal and reflect its latest saved parts and notes.
private struct TrainingGoalNotes: View {
    let goal: MatGoal
    @State private var expanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(goal: MatGoal, initiallyExpanded: Bool = true) {
        self.goal = goal
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s3) {
            Button {
                withAnimation(reduceMotion ? nil : MMMotion.easeOut()) { expanded.toggle() }
            } label: {
                HStack(spacing: MMSpace.s2) {
                    Text("Goal notes").mmFont(.body, 13, .semibold)
                    MMIcon("chevron-down", size: 14, weight: .bold)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .foregroundStyle(MMColor.textTertiary)
                .frame(minHeight: MMLayout.tapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expanded ? "Shown" : "Hidden")
            if expanded { GoalReferenceContent(goal: goal) }
        }
    }
}

/// Focus names only, for posts. A session's details stay with the people who
/// planned it, so the feed and post detail never show them.
struct TrainingFocusNames: View {
    var items: [TrainingFocus]
    /// Post detail shows names immediately; feed cards keep them behind a disclosure.
    var wraps = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private var titles: [String] {
        TrainingFocusTree.normalized(items).map(\.title).filter { !$0.isEmpty }
    }

    var body: some View {
        Group {
            if titles.isEmpty {
                EmptyView()
            } else if wraps {
                MMFlowLayout(spacing: MMSpace.s4, lineSpacing: MMSpace.s4) { tags }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("What we worked on: \(titles.joined(separator: ", "))")
            } else {
                disclosure
            }
        }
    }

    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : MMMotion.easeOut()) { expanded.toggle() }
            } label: {
                HStack(spacing: MMSpace.s4) {
                    MMIcon("notebook-pen", size: 16, color: MMColor.coral700)
                    Text("Worked on")
                        .mmText(.bodyS, .semibold)
                        .foregroundStyle(MMColor.textPrimary)
                    Text("\(titles.count)")
                        .mmText(.caption, .bold)
                        .foregroundStyle(MMColor.textPrimary)
                        .padding(.horizontal, MMSpace.s4)
                        .padding(.vertical, MMSpace.s2)
                        .background(MMColor.white, in: Capsule())
                    Spacer(minLength: MMSpace.s4)
                    MMIcon("chevron-down", size: 14, color: MMColor.ink700)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, minHeight: MMLayout.tapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("What we worked on, \(titles.count) \(titles.count == 1 ? "technique" : "techniques")")
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityHint(expanded ? "Hide technique names" : "Show technique names")

            if expanded {
                VStack(alignment: .leading, spacing: MMSpace.s4) {
                    ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
                        Text(title)
                            .mmText(.bodyS, .medium)
                            .foregroundStyle(MMColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.bottom, MMSpace.s5)
            }
        }
        .padding(.horizontal, MMSpace.s5)
        .background(MMColor.paper2, in: RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var tags: some View {
        ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
            MMTag(title, size: .sm)
        }
    }
}
