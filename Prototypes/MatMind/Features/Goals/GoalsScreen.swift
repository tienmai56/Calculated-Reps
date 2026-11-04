import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Tab 3: what you're working on. Each goal has its details and references,
/// and can be brought to a session. Shared holds goals training partners shared with you.
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
            let invites = mm.goalInvites.count
            MMTabs(items: [MMTabItem(GoalsSection.mine.rawValue, "Mine"),
                           MMTabItem(GoalsSection.shared.rawValue, "Shared", count: invites > 0 ? invites : nil)],
                   selection: Binding(get: { mm.goalsSection.rawValue },
                                      set: { mm.goalsSection = GoalsSection(rawValue: $0) ?? .mine }))
                .padding(.horizontal, 16)
                .padding(.top, 2)
            if mm.goalsSection == .shared {
                SharedGoalsSection()
            } else if goals.isEmpty {
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
        .animation(MMMotion.easeOut(), value: mm.sharedGoals.map(\.id))
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

/// One goal, edited in place: its name and its parts. Save goal keeps the changes,
/// parts' photos included. Goals from earlier builds keep their own notes and references;
/// those references still save as soon as they're added.
struct GoalDetailScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String

    @State private var draftTitle = ""
    @State private var draftNotes = ""
    @State private var draftParts: [GoalPartDraft] = []
    /// The parts as loaded, to tell whether anything changed.
    @State private var loadedParts: [GoalPartDraft] = []
    /// Goals from earlier builds can have notes and references of their own; those stay editable.
    @State private var showsGoalNotes = false
    /// The goal the drafts were filled from, so returning to the page keeps unsaved edits.
    @State private var loadedID: String?
    @State private var confirmDiscard = false
    @State private var confirmDelete = false
    @State private var sharing = false
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
            || draftParts != loadedParts
    }

    private func detail(_ goal: MatGoal) -> some View {
        MMScreen {
            MMHeader(title: "Goal", leading: {
                MMIconButton("chevron-left", label: "Back") {
                    if hasChanges(goal) { confirmDiscard = true } else { mm.back() }
                }
            }, trailing: {
                MMIconButton("share-2", label: "Share goal") {
                    // Recipients get the saved goal, so unsaved edits come first.
                    if hasChanges(goal) { mm.showToast("Save your changes first, then share") } else { sharing = true }
                }
                Menu {
                    Button { mm.planSession(forGoal: goal.id) } label: { Label("Plan a training for this", image: "calendar-plus") }
                    Button { if hasChanges(goal) { mm.showToast("Save your changes first, then share") } else { sharing = true } } label: { Label("Share goal", image: "share-2") }
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

            if showsGoalNotes {
                MMEyebrow("Details", topPadding: 20)
                MMTextField(placeholder: "Notes", text: $draftNotes, multiline: true, rows: 5)
                    .padding(.horizontal, 16)
            }

            GoalPartsEditor(parts: $draftParts)
                .padding(.horizontal, 16)
                .padding(.top, 20)

            if !goal.links.isEmpty || !goal.photos.isEmpty {
                MMEyebrow(title: "References", topPadding: 20, trailing: {
                    GoalTextAction(title: "Add a link", icon: "plus") { addingLink = true }
                })
                references(goal)
            }
            Color.clear.frame(height: 16)
        } footer: {
            MMButton("Save goal", size: .lg, fullWidth: true) {
                var updated = goal
                updated.title = draftTitle
                updated.notes = draftNotes
                if mm.saveGoal(updated, parts: draftParts) { mm.back() }
            }
            .disabled(!hasChanges(goal) || draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onAppear {
            guard loadedID != goal.id else { return }
            loadedID = goal.id
            draftTitle = goal.title
            draftNotes = goal.notes
            showsGoalNotes = !goal.notes.isEmpty
            loadedParts = goal.parts.map { GoalPartDraft($0) }
            draftParts = loadedParts
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
            Text(mm.recipients(ofGoal: goal.id).isEmpty
                 ? "Its details and references go with it."
                 : "Its details and references go with it. Anyone you shared it with loses it too.")
        }
        .sheet(isPresented: $sharing) {
            GoalShareSheet(goalID: goal.id)
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
                    if !goal.cardPreview.isEmpty {
                        Text(goal.cardPreview).mmFont(.body, 13, lineHeight: 1.4).foregroundStyle(MMColor.textSecondary)
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
        let photos = goal.allPhotos.count
        return HStack(spacing: 12) {
            if !goal.parts.isEmpty {
                metaItem("notebook-pen", goal.parts.count == 1 ? "1 part" : "\(goal.parts.count) parts")
            }
            if !goal.links.isEmpty {
                metaItem("link", goal.links.count == 1 ? "1 link" : "\(goal.links.count) links")
            }
            if photos > 0 {
                metaItem("image", photos == 1 ? "1 photo" : "\(photos) photos")
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

/// Add or edit a goal: what you're working on, broken down into parts. Each part
/// carries its own notes, video link and photos; nothing is saved until Add goal.
struct MatGoalEditorSheet: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MatGoal
    @State private var parts: [GoalPartDraft]
    let isNew: Bool
    var onSaved: (MatGoal) -> Void

    /// Goals from earlier builds can have notes of their own; keep showing them so they can be edited.
    private let showsGoalNotes: Bool
    @State private var confirmDelete = false

    init(draft: MatGoal, isNew: Bool, onSaved: @escaping (MatGoal) -> Void = { _ in }) {
        _draft = State(initialValue: draft)
        _parts = State(initialValue: draft.parts.map { GoalPartDraft($0) })
        self.isNew = isNew
        self.onSaved = onSaved
        showsGoalNotes = !draft.notes.isEmpty
    }

    private var canSave: Bool { !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ScrollView {
            MMDialogBody(title: isNew ? "Add a goal" : "Edit goal",
                         description: "Name it the way you'd say it on the mat. Be as specific as you like.",
                         onClose: { dismiss() }) {
                VStack(alignment: .leading, spacing: MMLayout.sectionGap) {
                    MMTextField(label: "What are you working on?", placeholder: "Single leg from standing",
                                text: $draft.title, autoFocus: isNew)
                    if showsGoalNotes {
                        MMTextField(label: "Notes", placeholder: "Notes", text: $draft.notes, multiline: true, rows: 4)
                    }
                    GoalPartsEditor(parts: $parts)
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
                if mm.saveGoal(draft, parts: parts) {
                    onSaved(mm.goal(draft.id) ?? draft)
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
        .confirmationDialog("Delete this goal? Its parts go with it.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete goal", role: .destructive) {
                mm.deleteGoal(draft.id)
                dismiss()
            }
        }
    }
}

// MARK: - Parts

/// A photo on a part while it's being edited: one already saved (`stored`),
/// or one just picked from the library (`data`, written to disk on save).
struct GoalPhotoDraft: Identifiable, Equatable {
    let id: UUID
    var stored: String?
    var data: Data?
    var preview: UIImage?

    init(stored: String) {
        id = UUID()
        self.stored = stored
    }

    init(data: Data, preview: UIImage) {
        id = UUID()
        self.data = data
        self.preview = preview
    }

    static func == (a: GoalPhotoDraft, b: GoalPhotoDraft) -> Bool { a.id == b.id }
}

/// A part of a goal as edited on screen. `AppModel.saveGoal(_:parts:)` turns it into a `GoalPart`.
struct GoalPartDraft: Identifiable, Equatable {
    var id: String
    var title = ""
    var notes = ""
    var link = ""
    var photos: [GoalPhotoDraft] = []

    init(id: String = GoalPart.newID()) {
        self.id = id
    }

    init(_ part: GoalPart) {
        id = part.id
        title = part.title
        notes = part.notes
        link = part.link
        photos = part.photos.map { GoalPhotoDraft(stored: $0) }
    }

    var displayName: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unnamed part" : name
    }
}

/// "Break it down": the parts of a goal as cards. One card is open at a time;
/// the rest show a one-line summary. Parts have no order to follow.
struct GoalPartsEditor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var parts: [GoalPartDraft]
    @State private var openID: String?
    @State private var viewing: ViewerTarget?

    private struct ViewerTarget: Identifiable {
        let id = UUID()
        let partID: String
        let index: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Break it down")
                    .mmFont(.display, 16, lineHeight: 1.25)
                    .foregroundStyle(MMColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !parts.isEmpty {
                    Text(parts.count == 1 ? "1 part" : "\(parts.count) parts")
                        .mmFont(.body, 13)
                        .foregroundStyle(MMColor.textTertiary)
                }
            }
            if parts.isEmpty {
                emptyState
            } else {
                ForEach($parts) { $part in
                    let id = part.id
                    GoalPartCard(part: $part,
                                 isOpen: openID == id,
                                 canMoveUp: parts.first?.id != id,
                                 canMoveDown: parts.last?.id != id,
                                 onToggle: { toggle(id) },
                                 onRemove: { remove(id) },
                                 onMove: { move(id, by: $0) },
                                 onViewPhoto: { viewing = ViewerTarget(partID: id, index: $0) })
                }
                Button(action: addPart) {
                    HStack(spacing: 8) {
                        MMIcon("plus", size: 18, weight: .bold)
                        Text("Add another part").mmFont(.display, 15, lineHeight: 1)
                    }
                    .foregroundStyle(MMColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(MMColor.paper2))
                    .contentShape(Capsule())
                }
                .buttonStyle(MMPressStyle())
            }
        }
        .fullScreenCover(item: $viewing) { target in
            if let i = parts.firstIndex(where: { $0.id == target.partID }) {
                GoalPhotoViewer(part: $parts[i], startIndex: target.index)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Big moves are a few small ones")
                    .mmFont(.display, 16, lineHeight: 1.25)
                    .foregroundStyle(MMColor.textPrimary)
                Text("Split it into the parts you want to sharpen. Each part gets its own notes, video and photos.")
                    .mmFont(.body, 13, lineHeight: 1.4)
                    .foregroundStyle(MMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MMButton("Break it down", variant: .secondary, size: .sm, iconLeft: "plus", action: addPart)
        }
        .padding(MMSpace.s7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous).fill(MMColor.surfaceSunken))
    }

    private func animate(_ change: () -> Void) {
        withAnimation(reduceMotion ? nil : MMMotion.easeOut(), change)
    }

    private func addPart() {
        let part = GoalPartDraft()
        animate {
            parts.append(part)
            openID = part.id
        }
    }

    private func toggle(_ id: String) {
        animate { openID = openID == id ? nil : id }
    }

    private func remove(_ id: String) {
        animate {
            parts.removeAll { $0.id == id }
            if openID == id { openID = nil }
        }
    }

    private func move(_ id: String, by offset: Int) {
        guard let from = parts.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard parts.indices.contains(to) else { return }
        animate { parts.swapAt(from, to) }
    }
}

/// One part: closed, it's a summary row; open, it edits the name, notes, video link and photos.
private struct GoalPartCard: View {
    @Environment(AppModel.self) private var mm
    @Binding var part: GoalPartDraft
    let isOpen: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    let onMove: (Int) -> Void
    let onViewPhoto: (Int) -> Void

    /// Photos per part; keeps the picker and memory in check.
    static let photoLimit = 20

    @FocusState private var nameFocused: Bool
    @FocusState private var linkFocused: Bool
    @State private var editingLink = false
    @State private var linkDraft = ""
    @State private var linkError: String?
    @State private var picked: [PhotosPickerItem] = []
    @State private var justAdded: String?
    @State private var confirmRemove = false

    private var isBlank: Bool {
        part.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && part.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && part.link.isEmpty && part.photos.isEmpty
    }

    var body: some View {
        Group {
            if isOpen { open } else { closed }
        }
        .confirmationDialog("Remove \(part.displayName)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove part", role: .destructive, action: onRemove)
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Its notes, video and photos go with it.")
        }
        .onChange(of: picked) { _, items in load(items) }
    }

    // MARK: Closed

    private var closed: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.displayName)
                        .mmFont(.display, 16, lineHeight: 1.25)
                        .foregroundStyle(MMColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(GoalPart.summary(notes: part.notes, hasLink: !part.link.isEmpty, photoCount: part.photos.count))
                        .mmFont(.body, 13, lineHeight: 1.3)
                        .foregroundStyle(MMColor.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MMIcon("chevron-down", size: 20, color: MMColor.ink500)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 56)
            .mmCardSurface(radius: MMRadius.lg)
            .contentShape(RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous))
        }
        .buttonStyle(MMPressStyle())
        .accessibilityHint("Opens its notes, video and photos")
        .contextMenu {
            if canMoveUp {
                Button("Move up") { onMove(-1) }
            }
            if canMoveDown {
                Button("Move down") { onMove(1) }
            }
            Button(role: .destructive) { requestRemove() } label: { Label("Remove part", image: "trash-2") }
        }
    }

    // MARK: Open

    private var open: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                TextField("Name this part", text: $part.title)
                    .focused($nameFocused)
                    .mmFont(.display, 17, lineHeight: 1.2)
                    .foregroundStyle(MMColor.textPrimary)
                    .tint(MMColor.accent)
                    .submitLabel(.done)
                    .accessibilityLabel("Part name")
                smallIconButton("trash-2", label: "Remove part", action: requestRemove)
                smallIconButton("chevron-down", label: "Close part", rotated: true, action: onToggle)
            }
            .padding(.trailing, -10)
            .padding(.vertical, -6)

            TextField("Notes", text: $part.notes, axis: .vertical)
                .lineLimit(3...12)
                .mmFont(.body, 15, lineHeight: 1.45)
                .foregroundStyle(MMColor.textPrimary)
                .tint(MMColor.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous).fill(MMColor.surfaceSunken))
                .accessibilityLabel("Notes for \(part.displayName)")

            references
        }
        .padding(14)
        .mmCardSurface(radius: MMRadius.lg)
        .overlay {
            RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous)
                .strokeBorder(MMColor.borderFocus, lineWidth: 1.5)
        }
        .task {
            guard part.title.isEmpty else { return }
            try? await Task.sleep(for: .seconds(0.3))
            nameFocused = true
        }
    }

    private func smallIconButton(_ icon: String, label: String, rotated: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MMIcon(icon, size: 18, color: MMColor.textTertiary)
                .rotationEffect(.degrees(rotated ? 180 : 0))
                .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func requestRemove() {
        if isBlank { onRemove() } else { confirmRemove = true }
    }

    // MARK: References

    private var references: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("References")
                .mmFont(.body, 12, .semibold, lineHeight: 1.2)
                .foregroundStyle(MMColor.textSecondary)
            if !part.link.isEmpty {
                linkPreview(part.link)
            } else if editingLink {
                linkField
            }
            let needsLink = part.link.isEmpty && !editingLink
            if needsLink || part.photos.isEmpty {
                HStack(spacing: 8) {
                    if needsLink {
                        Button {
                            editingLink = true
                            Task { @MainActor in
                                // Focus once the field is on screen.
                                try? await Task.sleep(for: .milliseconds(150))
                                linkFocused = true
                            }
                        } label: {
                            dashedLabel("video", "YouTube link")
                        }
                        .buttonStyle(MMPressStyle(scale: 0.97))
                    }
                    if part.photos.isEmpty {
                        photosPicker { dashedLabel("image-plus", "Add photos") }
                    }
                }
            }
            if !part.photos.isEmpty { photoStrip }
        }
    }

    private func dashedLabel(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            MMIcon(icon, size: 18)
            Text(title).mmFont(.body, 14, .semibold, lineHeight: 1)
        }
        .foregroundStyle(MMColor.textSecondary)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous)
                .strokeBorder(MMColor.ink300, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
        .contentShape(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous))
    }

    // MARK: Link

    private var linkField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                MMIcon("link", size: 18, color: MMColor.textTertiary)
                TextField("Paste a YouTube link", text: $linkDraft)
                    .focused($linkFocused)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(commitLink)
                    .mmFont(.body, 15)
                    .foregroundStyle(MMColor.textPrimary)
                    .tint(MMColor.accent)
                    .accessibilityLabel("YouTube link")
                PasteButton(payloadType: String.self) { strings in
                    guard let text = strings.first else { return }
                    Task { @MainActor in
                        linkDraft = text
                        commitLink()
                    }
                }
                .labelStyle(.titleOnly)
                .buttonBorderShape(.capsule)
                .tint(MMColor.ink900)
                smallIconButton("x", label: "Cancel") {
                    editingLink = false
                    linkDraft = ""
                    linkError = nil
                }
            }
            .padding(.leading, 14)
            .frame(minHeight: 50)
            .background {
                let shape = RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous)
                ZStack {
                    shape.fill(MMColor.surfaceInput)
                    shape.strokeBorder(linkError == nil ? MMColor.borderFocus : MMColor.danger500, lineWidth: 1.5)
                }
            }
            Text(linkError ?? "Links with a timestamp start the clip right there.")
                .mmFont(.body, 12, .medium, lineHeight: 1.3)
                .foregroundStyle(linkError == nil ? MMColor.textTertiary : MMColor.danger500)
        }
    }

    private func commitLink() {
        guard let link = AppModel.normalizedLink(linkDraft) else {
            linkError = "That doesn't look like a link"
            return
        }
        part.link = link
        editingLink = false
        linkDraft = ""
        linkError = nil
    }

    @ViewBuilder
    private func linkPreview(_ link: String) -> some View {
        let start = GoalPart.linkStart(link)
        let host = URL(string: link)?.host ?? link
        let content = HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: MMRadius.sm, style: .continuous).fill(MMColor.ink800)
                MMIcon("play", size: 18, weight: .bold, color: MMColor.paper)
            }
            .frame(width: 88, height: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(GoalPart.linkTitle(link))
                    .mmFont(.body, 13, .semibold, lineHeight: 1.3)
                    .foregroundStyle(MMColor.textPrimary)
                Text(start.map { "\(host) · from \($0)" } ?? host)
                    .mmFont(.mono, 11)
                    .foregroundStyle(MMColor.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        HStack(spacing: 0) {
            if let url = URL(string: link) {
                Link(destination: url) { content }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the video")
            } else {
                content
            }
            smallIconButton("x", label: "Remove video") { part.link = "" }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous).fill(MMColor.surfaceBase))
    }

    // MARK: Photos

    private func photosPicker<PickerLabel: View>(@ViewBuilder label: () -> PickerLabel) -> some View {
        PhotosPicker(selection: $picked,
                     maxSelectionCount: max(1, Self.photoLimit - part.photos.count),
                     selectionBehavior: .ordered,
                     matching: .images,
                     photoLibrary: .shared(),
                     label: label)
            .buttonStyle(MMPressStyle(scale: 0.97))
            .accessibilityLabel("Add photos")
            .accessibilityHint("You can pick several at once")
    }

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(part.photos.count == 1 ? "1 photo" : "\(part.photos.count) photos")
                    .mmFont(.body, 13, lineHeight: 1.3)
                    .foregroundStyle(MMColor.textSecondary)
                Spacer()
                if let justAdded {
                    HStack(spacing: 4) {
                        MMIcon("check", size: 14, weight: .bold, color: MMColor.mint700)
                        Text(justAdded).mmFont(.body, 12, .semibold, lineHeight: 1.3).foregroundStyle(MMColor.mint700)
                    }
                    .transition(.opacity)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if part.photos.count < Self.photoLimit {
                        photosPicker {
                            VStack(spacing: 2) {
                                MMIcon("image-plus", size: 20)
                                Text("Add").mmFont(.body, 11, .semibold, lineHeight: 1.2)
                            }
                            .foregroundStyle(MMColor.textSecondary)
                            .frame(width: 72, height: 72)
                            .background {
                                RoundedRectangle(cornerRadius: MMRadius.sm, style: .continuous)
                                    .strokeBorder(MMColor.ink300, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            }
                            .contentShape(RoundedRectangle(cornerRadius: MMRadius.sm, style: .continuous))
                        }
                    }
                    ForEach(Array(part.photos.enumerated()), id: \.element.id) { i, photo in
                        Button { onViewPhoto(i) } label: {
                            MMColor.paper3
                                .frame(width: 72, height: 72)
                                .overlay { GoalPhotoImage(photo: photo) }
                                .clipShape(RoundedRectangle(cornerRadius: MMRadius.sm, style: .continuous))
                                .contentShape(RoundedRectangle(cornerRadius: MMRadius.sm, style: .continuous))
                        }
                        .buttonStyle(MMPressStyle(scale: 0.96))
                        .accessibilityLabel("Photo \(i + 1) of \(part.photos.count)")
                        .accessibilityHint("Opens it full screen")
                    }
                }
            }
        }
    }

    /// Loads every picked photo in the order picked, scaled down right away to keep memory low.
    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task { @MainActor in
            var added: [GoalPhotoDraft] = []
            var failed = 0
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let jpeg = AppModel.goalPhotoJPEG(image),
                   let preview = UIImage(data: jpeg) {
                    added.append(GoalPhotoDraft(data: jpeg, preview: preview))
                } else {
                    failed += 1
                }
            }
            picked = []
            if !added.isEmpty {
                let message = added.count == 1 ? "1 photo added" : "\(added.count) photos added"
                part.photos.append(contentsOf: added)
                withAnimation(MMMotion.easeOut()) { justAdded = message }
                AccessibilityNotification.Announcement(message).post()
                try? await Task.sleep(for: .seconds(2.6))
                if justAdded == message { withAnimation(MMMotion.easeOut()) { justAdded = nil } }
            }
            if failed > 0 {
                mm.showToast(failed == 1 ? "A photo couldn't be read" : "\(failed) photos couldn't be read")
            }
        }
    }
}

/// A part photo, saved or just picked.
private struct GoalPhotoImage: View {
    let photo: GoalPhotoDraft
    var fit = false

    var body: some View {
        if let preview = photo.preview {
            Image(uiImage: preview)
                .resizable()
                .aspectRatio(contentMode: fit ? .fit : .fill)
        } else if let stored = photo.stored {
            MMPhoto(source: MatGoal.photoSource(stored))
                .aspectRatio(contentMode: fit ? .fit : .fill)
        } else {
            Color.clear
        }
    }
}

// MARK: - Photo viewer

/// A part's photos full screen: swipe between them, jump with the filmstrip,
/// remove one with a few seconds to undo. Changes apply to the draft, so they're
/// only kept when the goal is saved.
private struct GoalPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var part: GoalPartDraft
    @State private var index: Int
    @State private var removed: (photo: GoalPhotoDraft, index: Int)?
    @State private var undoToken = UUID()

    init(part: Binding<GoalPartDraft>, startIndex: Int) {
        _part = part
        _index = State(initialValue: startIndex)
    }

    private var count: Int { part.photos.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            MMColor.ink900.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                TabView(selection: $index) {
                    ForEach(Array(part.photos.enumerated()), id: \.element.id) { i, photo in
                        GoalPhotoImage(photo: photo, fit: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(i)
                            .accessibilityElement()
                            .accessibilityLabel("Photo \(i + 1) of \(count)")
                            .accessibilityAddTraits(.isImage)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.horizontal, -16)
                .padding(.vertical, 20)
                filmstrip
                removeButton.padding(.top, 20)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if removed != nil {
                undoBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 150)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                MMIcon("x", size: 20, weight: .bold, color: MMColor.paper)
                    .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                    .background(Circle().fill(MMColor.paper.opacity(0.12)))
            }
            .buttonStyle(MMPressStyle(scale: 0.9))
            .accessibilityLabel("Close")
            Spacer()
            VStack(spacing: 2) {
                Text("\(min(index, max(count - 1, 0)) + 1) of \(count)")
                    .mmFont(.display, 16, lineHeight: 1.2)
                    .foregroundStyle(MMColor.paper)
                Text(part.displayName)
                    .mmFont(.body, 12, lineHeight: 1.3)
                    .foregroundStyle(MMColor.ink300)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            Color.clear.frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
        }
    }

    private var filmstrip: some View {
        let strip = HStack(spacing: 6) {
            ForEach(Array(part.photos.enumerated()), id: \.element.id) { i, photo in
                let current = i == index
                Button {
                    withAnimation(reduceMotion ? nil : MMMotion.easeOut()) { index = i }
                } label: {
                    MMColor.ink700
                        .frame(width: 44, height: 44)
                        .overlay { GoalPhotoImage(photo: photo) }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .opacity(current ? 1 : 0.55)
                        .padding(3)
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(current ? MMColor.paper : Color.clear, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Photo \(i + 1)")
                .accessibilityAddTraits(current ? .isSelected : [])
            }
        }
        return ViewThatFits(in: .horizontal) {
            strip
            ScrollView(.horizontal, showsIndicators: false) { strip }
        }
    }

    private var removeButton: some View {
        Button(action: removeCurrent) {
            HStack(spacing: 8) {
                MMIcon("trash-2", size: 18, weight: .bold)
                Text("Remove photo").mmFont(.display, 16, lineHeight: 1)
            }
            .foregroundStyle(MMColor.paper)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(MMColor.paper.opacity(0.12)))
            .contentShape(Capsule())
        }
        .buttonStyle(MMPressStyle())
    }

    private var undoBar: some View {
        HStack {
            Text("Photo removed")
                .mmFont(.body, 15, .semibold, lineHeight: 1.3)
                .foregroundStyle(MMColor.ink900)
            Spacer()
            Button(action: undoRemove) {
                Text("Undo")
                    .mmFont(.display, 15, lineHeight: 1)
                    .foregroundStyle(MMColor.coral700)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(Capsule().fill(MMColor.paper2))
            }
            .buttonStyle(MMPressStyle(scale: 0.95))
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .frame(height: 52)
        .background(Capsule().fill(MMColor.paper).mmShadowFloat())
    }

    private func removeCurrent() {
        guard part.photos.indices.contains(index) else { return }
        let at = index
        let photo = part.photos.remove(at: at)
        // Removing the last one closes the viewer; the part card is all that's left to show.
        guard !part.photos.isEmpty else {
            dismiss()
            return
        }
        index = min(at, part.photos.count - 1)
        let token = UUID()
        undoToken = token
        withAnimation(reduceMotion ? nil : MMMotion.easeOut()) { removed = (photo, at) }
        AccessibilityNotification.Announcement("Photo removed").post()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard undoToken == token else { return }
            withAnimation(reduceMotion ? nil : MMMotion.easeOut()) { removed = nil }
        }
    }

    private func undoRemove() {
        guard let removed else { return }
        let at = min(removed.index, part.photos.count)
        part.photos.insert(removed.photo, at: at)
        index = at
        undoToken = UUID()
        withAnimation(reduceMotion ? nil : MMMotion.easeOut()) { self.removed = nil }
    }
}
