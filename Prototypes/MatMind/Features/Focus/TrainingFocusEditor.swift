import SwiftUI

/// The same editor is used while planning and by the organizer on session details.
struct TrainingFocusEditor: View {
    @Binding var items: [TrainingFocus]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedID: UUID?
    @State private var removalID: UUID?
    @State private var showRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s5) {
            ForEach(items) { root in
                VStack(spacing: 0) {
                    ForEach(TrainingFocusTree.rows([root])) { row in
                        editorRow(row)
                    }
                }
                .padding(MMSpace.s5)
                .mmCardSurface()
            }
            if items.isEmpty {
                MMFlowLayout(spacing: MMSpace.s4, lineSpacing: MMSpace.s4) {
                    ForEach(["Guard passing", "Escapes", "Sweeps"], id: \.self) { title in
                        MMTag(title, icon: "plus", size: .sm) { addRoot(title) }
                    }
                }
                .accessibilityLabel("Focus suggestions")
            }
            MMButton("Add a focus", variant: .secondary, iconLeft: "plus", fullWidth: true) { addRoot() }
            if !TrainingFocusTree.isValid(items) {
                Text("Name each focus, or remove the blank one.")
                    .mmFont(.body, 13)
                    .foregroundStyle(MMColor.textTertiary)
            }
        }
        .alert("Remove this focus?", isPresented: $showRemoval) {
            Button("Keep it", role: .cancel) { removalID = nil }
            Button("Remove", role: .destructive) {
                if let removalID { remove(removalID) }
                removalID = nil
            }
        } message: {
            Text("Its nested details will be removed too.")
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
                    .accessibilityLabel(row.depth == 0 ? "Training focus" : "Detail, level \(row.depth + 1)")
                    .accessibilityIdentifier("focus-title-\(row.id)")
                HStack(spacing: MMSpace.s4) {
                    Button { addChild(to: row.id) } label: {
                        HStack(spacing: MMSpace.s2) {
                            MMIcon("plus", size: 14)
                            Text("Add a detail").mmFont(.body, 13, .semibold)
                        }
                        .foregroundStyle(MMColor.textLink)
                        .frame(minHeight: MMLayout.tapTarget)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    MMIconButton("trash-2", label: "Remove \(row.node.title.isEmpty ? "focus" : row.node.title)") {
                        if row.node.children.isEmpty {
                            remove(row.id)
                        } else {
                            removalID = row.id
                            showRemoval = true
                        }
                    }
                }
                if row.depth >= 3 {
                    Text("Detail · level \(row.depth + 1)")
                        .mmFont(.body, 12)
                        .foregroundStyle(MMColor.textTertiary)
                }
            }
        }
        .padding(.leading, CGFloat(min(row.depth, 3)) * MMSpace.s6)
        .id(row.id)
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
