import PhotosUI
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
    /// Where the export file comes from, shown before the file picker.
    @State private var showImportHelp = false

    var body: some View {
        let goals = mm.goals
        MMScreen(tabPadding: true) {
            MMHeader(title: "Goals", large: true, trailing: {
                MMIconButton("qr-code", variant: .filled, label: "My code") { mm.go(.qr()) }
            })
        } content: {
            if goals.isEmpty {
                MMEmptyState(artwork: .goals, title: "What are you\nchasing?",
                             message: "Name it. Bring it to the mat.",
                             actionTitle: "Add a goal", actionIcon: "plus",
                             secondaryTitle: mm.canImportGoals ? "Import from old notebook" : nil,
                             secondaryIcon: "upload",
                             secondaryAction: mm.canImportGoals ? { showImportHelp = true } : nil) {
                    editingGoal = .new()
                }
            } else {
                MMEyebrow(title: "Working on", topPadding: 8, trailing: {
                    GoalTextAction(title: "Add a goal", icon: "plus") { editingGoal = .new() }
                })
                VStack(spacing: 10) {
                    ForEach(goals) { g in
                        WorkingOnGoalCard(goal: g) { mm.go(.goal(id: g.id)) }
                    }
                    if mm.canImportGoals {
                        GoalTextAction(title: "Import goals from your old notebook", icon: "upload", color: MMColor.textTertiary) {
                            showImportHelp = true
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
        .confirmationDialog("Bring goals from your old notebook", isPresented: $showImportHelp, titleVisibility: .visible) {
            Button("Choose the export file") {
                // Let the dialog finish closing before the file picker opens.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.3))
                    importingGoals = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Export it first from Profile → Settings → Export local sessions, and save it to Files.")
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

/// One goal, edited in place: its name and details, plus references. Save goal keeps
/// the changes; photos and links save as soon as they're added.
struct GoalDetailScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String

    @State private var draftTitle = ""
    @State private var draftNotes = ""
    /// The goal the drafts were filled from, so returning to the page keeps unsaved edits.
    @State private var loadedID: String?
    @State private var confirmDiscard = false
    @State private var confirmDelete = false
    @State private var addingLink = false
    @State private var linkDraft = ""
    @State private var pickedPhoto: PhotosPickerItem?

    var body: some View {
        if let goal = mm.goal(id) {
            detail(goal)
        } else {
            MMColor.bgApp.ignoresSafeArea().toolbar(.hidden, for: .navigationBar)
        }
    }

    private func hasChanges(_ goal: MatGoal) -> Bool {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines) != goal.title
            || draftNotes.trimmingCharacters(in: .whitespacesAndNewlines) != goal.notes
    }

    private func detail(_ goal: MatGoal) -> some View {
        MMScreen {
            MMHeader(title: "Goal", leading: {
                MMIconButton("chevron-left", label: "Back") {
                    if hasChanges(goal) { confirmDiscard = true } else { mm.back() }
                }
            }, trailing: {
                Menu {
                    Button { mm.planSession(forGoal: goal.id) } label: { Label("Plan a session for this", image: "calendar-plus") }
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
                TextField("Name your goal", text: $draftTitle, axis: .vertical)
                    .mmFont(.display, 28, tracking: -0.03, lineHeight: 1.05)
                    .foregroundStyle(MMColor.ink900)
                    .tint(MMColor.accent)
                    .accessibilityLabel("Goal name")
                Text(plan(goal)).mmFont(.body, 13, .medium).foregroundStyle(MMColor.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            MMEyebrow("Details", topPadding: 20)
            MMTextField(placeholder: "Cues, details, what coach said. Start a line with - for a sub-point.",
                        text: $draftNotes, multiline: true, rows: 5)
                .padding(.horizontal, 16)

            MMEyebrow(title: "References", topPadding: 20, trailing: {
                GoalTextAction(title: "Add a link", icon: "plus") { addingLink = true }
            })
            references(goal)
            Color.clear.frame(height: 16)
        } footer: {
            MMButton("Save goal", size: .lg, fullWidth: true) {
                var updated = goal
                updated.title = draftTitle
                updated.notes = draftNotes
                if mm.saveGoal(updated) { mm.back() }
            }
            .disabled(!hasChanges(goal) || draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onAppear {
            guard loadedID != goal.id else { return }
            loadedID = goal.id
            draftTitle = goal.title
            draftNotes = goal.notes
        }
        .confirmationDialog("Discard your changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { mm.back() }
            Button("Keep editing", role: .cancel) {}
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
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    mm.addPhoto(data, toGoal: goal.id)
                } else {
                    mm.showToast("That photo couldn't be read")
                }
                pickedPhoto = nil
            }
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
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(goal.photos, id: \.self) { photo in
                        MMPhotoTile(photo: MatGoal.photoSource(photo), height: 88, radius: 18)
                            .frame(width: 88)
                            .contextMenu {
                                Button(role: .destructive) { mm.removePhoto(photo, fromGoal: goal.id) } label: {
                                    Label("Remove photo", image: "trash-2")
                                }
                            }
                            .accessibilityLabel("Reference photo")
                            .accessibilityHint("Touch and hold to remove")
                    }
                    PhotosPicker(selection: $pickedPhoto, matching: .images, photoLibrary: .shared()) {
                        VStack(spacing: 6) {
                            MMIcon("image-plus", size: 22, color: MMColor.ink700)
                            Text("Add photo").mmFont(.body, 12, .semibold, lineHeight: 1.2).foregroundStyle(MMColor.textSecondary)
                        }
                        .frame(width: 88, height: 88)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(MMColor.paper2))
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(MMPressStyle(scale: 0.96))
                    .accessibilityLabel("Add a reference photo")
                }
                .padding(.horizontal, 16)
            }
            if goal.links.isEmpty && goal.photos.isEmpty {
                Text("Save the instructionals and photos you keep coming back to.")
                    .mmFont(.body, 14, lineHeight: 1.45).foregroundStyle(MMColor.textTertiary)
                    .padding(.horizontal, 20)
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

/// One thing you're working on: name, a peek at the notes, and when it's next on the mat.
struct WorkingOnGoalCard: View {
    @Environment(AppModel.self) private var mm
    let goal: MatGoal
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
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

