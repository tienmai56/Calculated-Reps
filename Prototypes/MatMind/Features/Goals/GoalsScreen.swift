import SwiftUI
import UniformTypeIdentifiers

/// Tab 3: what you're working on. Each goal has its details and references,
/// and can be brought to a session.
struct GoalsScreen: View {
    @Environment(AppModel.self) private var mm
    /// The goal being added.
    @State private var editingGoal: MatGoal?
    /// Picking an old-notebook export to bring goals over from.
    @State private var importingGoals = false

    var body: some View {
        let goals = mm.goals
        MMScreen(tabPadding: true) {
            MMHeader(title: "Goals", large: true, trailing: {
                MMIconButton("qr-code", variant: .filled, label: "My code") { mm.go(.qr()) }
            })
        } content: {
            MMEyebrow(title: "Working on", topPadding: 8, trailing: {
                if !goals.isEmpty {
                    GoalTextAction(title: "Add a goal", icon: "plus") { editingGoal = .new() }
                }
            })
            if goals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What are you chasing?").mmFont(.display, 18, lineHeight: 1.2).foregroundStyle(MMColor.ink900)
                    Text("Single legs, RNC finishes, that one sweep. Add it here and bring it to your next session.")
                        .mmFont(.body, 14, lineHeight: 1.45).foregroundStyle(MMColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        MMButton("Add a goal", variant: .secondary, size: .sm, iconLeft: "plus") { editingGoal = .new() }
                        if mm.canImportGoals {
                            MMButton("Import", variant: .ghost, size: .sm, iconLeft: "upload") { importingGoals = true }
                        }
                    }
                    .padding(.top, 4)
                    if mm.canImportGoals {
                        Text("Used the old notebook? Export it from Profile → Settings → Export local sessions, save it to Files, then import it here.")
                            .mmFont(.body, 12, lineHeight: 1.4).foregroundStyle(MMColor.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mmCardSurface(radius: 22)
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(goals) { g in
                        WorkingOnGoalCard(goal: g) { mm.go(.goal(id: g.id)) }
                    }
                    if mm.canImportGoals {
                        GoalTextAction(title: "Import goals from your old notebook", icon: "upload", color: MMColor.textTertiary) {
                            importingGoals = true
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .animation(MMMotion.easeOut(), value: goals.map(\.id))
        .sheet(item: $editingGoal) { goal in
            MatGoalEditorSheet(draft: goal, isNew: mm.goal(goal.id) == nil)
        }
        .fileImporter(isPresented: $importingGoals, allowedContentTypes: [.zip, .json]) { result in
            importGoals(result)
        }
    }

    /// Brings goals over from the file made by Settings → Export local sessions.
    private func importGoals(_ result: Result<URL, Error>) {
        guard case .success(let url) = result, let read = mm.readGoalExport else { return }
        Task {
            let outcome = await Task.detached(priority: .userInitiated) { () -> Result<[MatGoal], Error> in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                return Result { try read(url) }
            }.value
            switch outcome {
            case .success(let imported):
                let added = mm.importGoals(imported)
                if imported.isEmpty {
                    mm.showToast("No goals in that notebook")
                } else if added == 0 {
                    mm.showToast("Those goals are already here")
                } else {
                    mm.showToast(added == 1 ? "Brought over 1 goal" : "Brought over \(added) goals", .success)
                }
            case .failure(let error):
                mm.showToast((error as? LocalizedError)?.errorDescription ?? "That file couldn't be read.")
            }
        }
    }
}

// MARK: - Goal detail

/// One goal: its details (main points with sub-points), references, and a way to plan a session for it.
struct GoalDetailScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String

    @State private var editing: MatGoal?
    @State private var confirmDelete = false
    @State private var addingLink = false
    @State private var linkDraft = ""

    var body: some View {
        if let goal = mm.goal(id) {
            detail(goal)
        } else {
            MMColor.bgApp.ignoresSafeArea().toolbar(.hidden, for: .navigationBar)
        }
    }

    private func detail(_ goal: MatGoal) -> some View {
        MMScreen {
            MMHeader(title: "Goal", leading: {
                MMIconButton("chevron-left", label: "Back") { mm.back() }
            }, trailing: {
                Menu {
                    Button { editing = goal } label: { Label("Edit goal", image: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete goal", image: "trash-2") }
                } label: {
                    MMIcon("ellipsis", size: 22, color: MMColor.ink900)
                        .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Goal options")
            })
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                if !goal.position.isEmpty { MMBadge(goal.position) }
                Text(goal.title).mmFont(.display, 28, tracking: -0.03, lineHeight: 1.05).foregroundStyle(MMColor.ink900)
                Text(plan(goal)).mmFont(.body, 13, .medium).foregroundStyle(MMColor.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            MMEyebrow(title: "Details", topPadding: 20, trailing: {
                GoalTextAction(title: goal.notes.isEmpty ? "Add" : "Edit") { editing = goal }
            })
            GoalNotesView(notes: goal.notes)
                .padding(.horizontal, 16)

            MMEyebrow(title: "References", topPadding: 20, trailing: {
                GoalTextAction(title: "Add a link", icon: "plus") { addingLink = true }
            })
            references(goal)
            Color.clear.frame(height: 16)
        } footer: {
            MMButton("Plan a session for this", size: .lg, iconLeft: "calendar-plus", fullWidth: true) {
                mm.planSession(forGoal: goal.id)
            }
        }
        .sheet(item: $editing) { g in
            MatGoalEditorSheet(draft: g, isNew: false)
        }
        .confirmationDialog("Delete \(goal.title)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete goal", role: .destructive) {
                mm.deleteGoal(goal.id)
                mm.back()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Its details and references go with it.")
        }
        .alert("Add a link", isPresented: $addingLink) {
            TextField("youtube.com/…", text: $linkDraft)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Add") {
                mm.addLink(linkDraft, toGoal: goal.id)
                linkDraft = ""
            }
            Button("Cancel", role: .cancel) { linkDraft = "" }
        } message: {
            Text("An instructional, a video, anything you want to rewatch.")
        }
    }

    @ViewBuilder
    private func references(_ goal: MatGoal) -> some View {
        if goal.links.isEmpty && goal.photos.isEmpty {
            Text("Save the instructionals and photos you keep coming back to.")
                .mmFont(.body, 14, lineHeight: 1.45).foregroundStyle(MMColor.textTertiary)
                .padding(.horizontal, 20)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if !goal.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(goal.photos, id: \.self) { photo in
                                MMPhotoTile(photo: MatGoal.photoSource(photo), height: 88, radius: 18)
                                    .frame(width: 88)
                                    .accessibilityLabel("Reference photo")
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                if !goal.links.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(goal.links.enumerated()), id: \.element) { i, link in
                            linkRow(link, divider: i < goal.links.count - 1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .mmCardSurface(radius: 22)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func linkRow(_ link: String, divider: Bool) -> some View {
        let url = URL(string: link)
        let row = HStack(spacing: 12) {
            MMIcon("link", size: 18, color: MMColor.textTertiary)
            Text(url?.host ?? link).mmFont(.mono, 13).foregroundStyle(MMColor.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            MMIcon("chevron-right", size: 16, color: MMColor.ink400)
        }
        .frame(minHeight: MMLayout.tapTarget)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(MMColor.borderSubtle).frame(height: 1) }
        }
        if let url {
            Link(destination: url) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }

    private func plan(_ goal: MatGoal) -> String {
        guard let s = mm.nextSession(forGoal: goal.id) else { return "Not planned yet" }
        let others = s.going.filter { $0 != "me" }.map { mm.person($0).name }
        return others.isEmpty ? "Next: \(s.title), \(s.day)" : "Next: \(s.day) with \(mmNames(others))"
    }
}

/// Goal notes as an outline: plain lines are main points, "-" lines sit underneath.
private struct GoalNotesView: View {
    let notes: String

    var body: some View {
        let lines = notes.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        VStack(alignment: .leading, spacing: 8) {
            if lines.isEmpty {
                Text("No details yet. Add the cues you want to remember on the mat.")
                    .mmFont(.body, 14, lineHeight: 1.45).foregroundStyle(MMColor.textTertiary)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("-") {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Capsule().fill(MMColor.ink300).frame(width: 8, height: 2).alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 5 }
                        Text(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
                            .mmFont(.body, 14, lineHeight: 1.4).foregroundStyle(MMColor.textSecondary)
                    }
                    .padding(.leading, 18)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle().fill(MMColor.ink900).frame(width: 8, height: 8).alignmentGuide(.firstTextBaseline) { d in d[.bottom] + 1 }
                        Text(line).mmFont(.body, 15, .semibold, lineHeight: 1.35).foregroundStyle(MMColor.textPrimary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .mmCardSurface(radius: 22)
    }
}

/// Quiet coral text action used in section headers.
private struct GoalTextAction: View {
    let title: String
    var icon: String?
    var color: Color = MMColor.coral700
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { MMIcon(icon, size: 16, weight: .bold) }
                Text(title).mmFont(.body, 14, .bold, lineHeight: 1)
            }
            .foregroundStyle(color)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -12)
    }
}

/// One thing you're working on: position, name, a peek at the notes, and when it's next on the mat.
struct WorkingOnGoalCard: View {
    @Environment(AppModel.self) private var mm
    let goal: MatGoal
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    if !goal.position.isEmpty { MMBadge(goal.position) }
                    Text(goal.title).mmFont(.display, 18, lineHeight: 1.2).foregroundStyle(MMColor.ink900)
                        .multilineTextAlignment(.leading)
                    if !goal.notesPreview.isEmpty {
                        Text(goal.notesPreview).mmFont(.body, 13, lineHeight: 1.4).foregroundStyle(MMColor.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    meta
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MMIcon("chevron-right", size: 18, color: MMColor.ink400)
            }
            .padding(16)
            .mmCardSurface(radius: 22)
        }
        .buttonStyle(MMPressStyle())
    }

    private var meta: some View {
        HStack(spacing: 12) {
            if !goal.links.isEmpty {
                metaItem("link", goal.links.count == 1 ? "1 link" : "\(goal.links.count) links")
            }
            if !goal.photos.isEmpty {
                metaItem("image", goal.photos.count == 1 ? "1 photo" : "\(goal.photos.count) photos")
            }
            Text(plan).mmFont(.body, 12, .medium, lineHeight: 1.3).foregroundStyle(MMColor.textTertiary).lineLimit(1)
        }
    }

    private func metaItem(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            MMIcon(icon, size: 14, color: MMColor.textTertiary)
            Text(text).mmFont(.body, 12, .medium, lineHeight: 1.3).foregroundStyle(MMColor.textTertiary)
        }
    }

    /// People first: "On Sat with Sarah", not a count.
    private var plan: String {
        guard let s = mm.nextSession(forGoal: goal.id) else { return "Not planned yet" }
        let others = s.going.filter { $0 != "me" }.map { mm.person($0).name }
        return others.isEmpty ? "On \(s.day)" : "On \(s.day) with \(mmNames(others))"
    }
}

/// Add or edit a goal: a name, where it happens, and free-form notes.
struct MatGoalEditorSheet: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.dismiss) private var dismiss
    @State var draft: MatGoal
    let isNew: Bool
    var onSaved: (MatGoal) -> Void = { _ in }

    @State private var confirmDelete = false

    private var canSave: Bool { !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ScrollView {
            MMDialogBody(title: isNew ? "Add a goal" : "Edit goal",
                         description: "Name it the way you'd say it on the mat. Be as specific as you like.",
                         onClose: { dismiss() }) {
                VStack(alignment: .leading, spacing: 18) {
                    MMTextField(label: "What are you working on?", placeholder: "Single leg from standing",
                                text: $draft.title, autoFocus: isNew)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Where on the mat").mmFont(.display, 14, .bold, tracking: 0, lineHeight: 1.2)
                            .foregroundStyle(MMColor.textPrimary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(MatGoal.positions, id: \.self) { position in
                                    MMTag(position, selected: draft.position == position, size: .sm, action: {
                                        draft.position = draft.position == position ? "" : position
                                    })
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    MMTextField(label: "Notes", placeholder: "Cues, details, what coach said. Start a line with - for a bullet.",
                                text: $draft.notes, multiline: true, rows: 6)
                    if !isNew {
                        MMButton("Delete goal", variant: .ghost, iconLeft: "trash-2") { confirmDelete = true }
                            .padding(.leading, -10)
                    }
                }
                .padding(.top, MMSpace.s4)
            } actions: {
                EmptyView()
            }
            .padding(MMSpace.s7)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            MMButton(isNew ? "Add goal" : "Save goal", fullWidth: true) {
                if mm.saveGoal(draft) {
                    onSaved(draft)
                    dismiss()
                }
            }
            .disabled(!canSave)
            .padding(MMSpace.s6)
            .background(MMColor.bgApp)
        }
        .background(MMColor.bgApp)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MMRadius.xl)
        .presentationBackground(MMColor.bgApp)
        .confirmationDialog("Delete this goal? Its notes go with it.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete goal", role: .destructive) {
                mm.deleteGoal(draft.id)
                dismiss()
            }
        }
    }
}

