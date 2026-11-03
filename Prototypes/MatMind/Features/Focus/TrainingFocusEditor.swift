import SwiftUI

/// The same editor is used while planning and by the organizer on session details.
struct TrainingFocusEditor: View {
    @Binding var items: [TrainingFocus]
    var allowsEmptyRoots = false
    var focusOnAppear = true
    /// Your goals, offered as one-tap focuses while planning. A picked goal carries
    /// over its name only; its notes stay on the goal, viewable from the card.
    /// `nil` hides the picker (session details).
    var goals: [MatGoal]? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedID: UUID?
    @State private var removalID: UUID?
    @State private var showRemoval = false
    /// Focus item → the goal it was picked from. Session-local; not saved with the outline.
    @State private var goalLinks: [UUID: String] = [:]
    @State private var openNotes: Set<UUID> = []

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
                if row.depth == 0, let goal = linkedGoal(row.id), !goal.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    goalNotes(goal, for: row.id)
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

    /// The goal's own notes, read-only and collapsed by default, so the session's
    /// details can be written fresh with the goal in view.
    private func goalNotes(_ goal: MatGoal, for id: UUID) -> some View {
        let open = openNotes.contains(id)
        return VStack(alignment: .leading, spacing: MMSpace.s3) {
            Button {
                withAnimation(reduceMotion ? nil : MMMotion.easeOut()) {
                    if open { openNotes.remove(id) } else { openNotes.insert(id) }
                }
            } label: {
                HStack(spacing: MMSpace.s2) {
                    Text("Goal notes").mmFont(.body, 13, .semibold)
                    MMIcon("chevron-down", size: 14, weight: .bold)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .foregroundStyle(MMColor.textTertiary)
                .frame(minHeight: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? "Shown" : "Hidden")
            if open {
                Text(goal.notes.trimmingCharacters(in: .whitespacesAndNewlines))
                    .mmFont(.body, 13, lineHeight: 1.45)
                    .foregroundStyle(MMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, MMSpace.s5)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous).fill(MMColor.surfaceSunken))
                    .transition(.opacity)
            }
        }
        .padding(.bottom, MMSpace.s2)
    }

    private func linkedGoal(_ id: UUID) -> MatGoal? {
        guard let goalID = goalLinks[id] else { return nil }
        return goals?.first { $0.id == goalID }
    }

    /// The root focus picked from this goal, if it is still in the outline.
    private func pickedFocusID(for goal: MatGoal) -> UUID? {
        items.first { goalLinks[$0.id] == goal.id }?.id
    }

    private func toggleGoal(_ goal: MatGoal) {
        if let id = pickedFocusID(for: goal) {
            if let node = TrainingFocusTree.find(id, in: items) { requestRemoval(node) }
            return
        }
        let item = TrainingFocus(title: goal.title)
        goalLinks[item.id] = goal.id
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

/// Read-only, without editing controls or empty placeholders. Used by sessions
/// and completed posts so the training content survives publication.
struct TrainingFocusOutline: View {
    var items: [TrainingFocus]

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
                        if row.depth >= 3 {
                            Text("Detail · level \(row.depth + 1)")
                                .mmFont(.body, 12)
                                .foregroundStyle(MMColor.textTertiary)
                        }
                    }
                }
                .padding(.leading, CGFloat(min(row.depth, 3)) * MMSpace.s6)
                .accessibilityElement(children: .combine)
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
    /// Wrap onto several lines (post detail) instead of one scrolling row (feed card).
    var wraps = false

    private var titles: [String] {
        TrainingFocusTree.normalized(items).map(\.title).filter { !$0.isEmpty }
    }

    var body: some View {
        Group {
            if wraps {
                MMFlowLayout(spacing: MMSpace.s4, lineSpacing: MMSpace.s4) { tags }
            } else {
                HStack(spacing: MMSpace.s4) {
                    MMIcon("notebook-pen", size: 16, color: MMColor.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(MMColor.surfaceSunken))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: MMSpace.s4) { tags }
                            .padding(.vertical, MMSpace.s1)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("What we worked on: \(titles.joined(separator: ", "))")
    }

    private var tags: some View {
        ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
            MMTag(title, size: .sm)
        }
    }
}
