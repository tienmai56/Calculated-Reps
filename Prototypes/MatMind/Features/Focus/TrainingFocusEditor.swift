import SwiftUI

/// The same editor is used while planning and by the organizer on session details.
struct TrainingFocusEditor: View {
    @Binding var items: [TrainingFocus]
    var allowsEmptyRoots = false
    var focusOnAppear = true
    /// Your goals, offered as one-tap focuses while planning and when editing a
    /// session's focus. Notes and parts remain read-only references on the goal.
    /// `nil` hides the picker.
    var goals: [MatGoal]? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedID: UUID?
    @State private var removalID: UUID?
    @State private var showRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s5) {
            if let goals, !goals.isEmpty {
                MMFlowLayout(spacing: MMSpace.s4, lineSpacing: MMSpace.s4) {
                    ForEach(goals) { goal in
                        let picked = pickedFocusID(for: goal) != nil
                        MMTag(goal.title, icon: picked ? "check" : "plus", selected: picked, size: .sm) { toggleGoal(goal) }
                            .accessibilityAddTraits(picked ? .isSelected : [])
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Your goals")
            }
            ForEach(items) { root in
                VStack(spacing: 0) {
                    ForEach(TrainingFocusTree.rows([root])) { row in
                        editorRow(row)
                    }
                    cardActions(root)
                }
                .padding(MMSpace.s5)
                .mmCardSurface()
            }
            if items.isEmpty, goals?.isEmpty ?? true {
                MMFlowLayout(spacing: MMSpace.s4, lineSpacing: MMSpace.s4) {
                    ForEach(["Guard passing", "Escapes", "Sweeps"], id: \.self) { title in
                        MMTag(title, icon: "plus", size: .sm) { addRoot(title) }
                    }
                }
                .accessibilityLabel("Focus suggestions")
            }
            MMButton("Add a focus", variant: .secondary, iconLeft: "plus", fullWidth: true) { addRoot() }
            if let goals, goals.isEmpty {
                HStack(spacing: MMSpace.s3) {
                    MMIcon("notebook-pen", size: 14, color: MMColor.textTertiary)
                    Text("Goals you set will show up here as one-tap picks.")
                        .mmFont(.body, 13)
                        .foregroundStyle(MMColor.textTertiary)
                }
            }
            if !TrainingFocusTree.isValid(allowsEmptyRoots ? TrainingFocusTree.optionalOutline(items) : items) {
                Text("Name each focus, or remove the blank one.")
                    .mmFont(.body, 13)
                    .foregroundStyle(MMColor.textTertiary)
            }
        }
        .onAppear {
            // With goals to pick from, start on the picker instead of a blank card.
            if let goals, !goals.isEmpty, items.count == 1, items[0].title.isEmpty, items[0].children.isEmpty {
                items = []
            }
            if focusOnAppear, items.count == 1, items[0].title.isEmpty, items[0].children.isEmpty {
                focusedID = items[0].id
            }
        }
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

    private func editorRow(_ row: TrainingFocusTree.Row) -> some View {
        HStack(alignment: .top, spacing: MMSpace.s4) {
            MMIcon(row.depth == 0 ? "notebook-pen" : "chevron-right", size: 16, color: MMColor.textTertiary)
                .padding(.top, MMSpace.s5)
            VStack(alignment: .leading, spacing: 0) {
                TextField(row.depth == 0 ? "What would you like to work on?" : "Break it down a little…",
                          text: titleBinding(row.id), axis: .vertical)
                    .font(MMFont.body(16, row.depth == 0 ? .bold : .regular))
                    .foregroundStyle(MMColor.textPrimary)
                    .tint(MMColor.accent)
                    .lineLimit(1...4)
                    .frame(minHeight: MMLayout.tapTarget)
                    .focused($focusedID, equals: row.id)
                    .accessibilityLabel(row.depth == 0 ? "Training focus" : (row.depth == 1 ? "Detail" : "Detail, level \(row.depth + 1)"))
                    .accessibilityIdentifier("focus-title-\(row.id)")
                if row.depth == 0, let goal = row.node.linkedGoal(in: goals ?? []), goal.hasReferenceContent {
                    TrainingGoalNotes(goal: goal)
                }
                if row.depth >= 3 {
                    Text("Detail · level \(row.depth + 1)")
                        .mmFont(.body, 12)
                        .foregroundStyle(MMColor.textTertiary)
                }
            }
            if row.depth > 0 {
                MMIconButton("x", label: "Remove \(row.node.title.isEmpty ? "detail" : row.node.title)") {
                    requestRemoval(row.node)
                }
            }
        }
        .padding(.leading, CGFloat(min(row.depth, 3)) * MMSpace.s6)
        .id(row.id)
    }

    /// One level of details: a single Add a detail per focus, plus the focus's remove button.
    private func cardActions(_ root: TrainingFocus) -> some View {
        HStack(spacing: MMSpace.s4) {
            Button { addChild(to: root.id) } label: {
                HStack(spacing: MMSpace.s2) {
                    MMIcon("plus", size: 14)
                    Text("Add a detail").mmFont(.body, 13, .semibold)
                }
                .foregroundStyle(MMColor.textLink)
                .frame(minHeight: MMLayout.tapTarget)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            MMIconButton("trash-2", label: "Remove \(root.title.isEmpty ? "focus" : root.title)") {
                requestRemoval(root)
            }
        }
        .padding(.leading, 16 + MMSpace.s4)
    }

    private func requestRemoval(_ node: TrainingFocus) {
        if node.children.isEmpty {
            remove(node.id)
        } else {
            removalID = node.id
            showRemoval = true
        }
    }

    private func pickedFocusID(for goal: MatGoal) -> UUID? {
        items.first { $0.linkedGoal(in: goals ?? [])?.id == goal.id }?.id
    }

    private func toggleGoal(_ goal: MatGoal) {
        if let id = pickedFocusID(for: goal) {
            if let node = TrainingFocusTree.find(id, in: items) { requestRemoval(node) }
            return
        }
        let item = TrainingFocus(title: goal.title, goalID: goal.id)
        withAnimation(reduceMotion ? nil : MMMotion.bounce()) { items.append(item) }
    }

    private func titleBinding(_ id: UUID) -> Binding<String> {
        Binding(get: { TrainingFocusTree.find(id, in: items)?.title ?? "" },
                set: { value in
                    TrainingFocusTree.update(id, in: &items) { $0.title = value }
                })
    }

    private func addRoot(_ title: String = "") {
        let item = TrainingFocus(title: title)
        withAnimation(reduceMotion ? nil : MMMotion.bounce()) { items.append(item) }
        focusedID = item.id
    }

    private func addChild(to parent: UUID) {
        let item = TrainingFocus()
        withAnimation(reduceMotion ? nil : MMMotion.bounce()) {
            TrainingFocusTree.update(parent, in: &items) { $0.children.append(item) }
        }
        focusedID = item.id
    }

    private func remove(_ id: UUID) {
        if let subtree = TrainingFocusTree.find(id, in: items), let focusedID,
           TrainingFocusTree.rows([subtree]).contains(where: { $0.id == focusedID }) {
            self.focusedID = nil
        }
        withAnimation(reduceMotion ? nil : MMMotion.easeOut()) {
            TrainingFocusTree.remove(id, from: &items)
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

/// Session outline with read-only references to the viewer's own goals.
/// Shared posts use TrainingFocusNames and never show these private references.
struct TrainingFocusOutline: View {
    var items: [TrainingFocus]
    @Environment(AppModel.self) private var mm

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s5) {
            ForEach(TrainingFocusTree.rows(items)) { row in
                HStack(alignment: .top, spacing: MMSpace.s4) {
                    MMIcon(row.depth == 0 ? "notebook-pen" : "chevron-right", size: 16, color: MMColor.textTertiary)
                        .padding(.top, MMSpace.s1)
                    VStack(alignment: .leading, spacing: MMSpace.s2) {
                        Text(row.node.title)
                            .mmFont(.body, 15, row.depth == 0 ? .bold : .regular, lineHeight: 1.45)
                            .foregroundStyle(MMColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if row.depth == 0, let goal = row.node.linkedGoal(in: mm.goals), goal.hasReferenceContent {
                            TrainingGoalNotes(goal: goal, initiallyExpanded: false)
                        }
                        if row.depth >= 3 {
                            Text("Detail · level \(row.depth + 1)")
                                .mmFont(.body, 12)
                                .foregroundStyle(MMColor.textTertiary)
                        }
                    }
                }
                .padding(.leading, CGFloat(min(row.depth, 3)) * MMSpace.s6)
                .accessibilityElement(children: .contain)
                .accessibilityValue("Level \(row.depth + 1)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MMSpace.s6)
        .mmCardSurface()
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
