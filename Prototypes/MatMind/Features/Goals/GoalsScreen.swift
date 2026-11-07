import AVKit
import CoreTransferable
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
                MMHeaderActions()
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
            .disabled(!hasChanges(goal) || draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftParts.contains { $0.isLoadingMedia })
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
        let people = sharedWith
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
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
                if !people.isEmpty {
                    Rectangle().fill(MMColor.borderSubtle).frame(height: 1)
                    MMAvatarStack(people: people.map(\.avatar), size: 30, max: 8, ring: MMColor.surfaceCard,
                                  label: Self.sharedLabel(people.map(\.firstName)))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Self.sharedLabel(people.map(\.firstName)))
                }
            }
            .mmCardSurface(radius: 22)
        }
        .buttonStyle(MMPressStyle())
    }

    /// Training partners this goal went to, invited or accepted. Declined ones drop off.
    private var sharedWith: [Person] {
        mm.recipients(ofGoal: goal.id)
            .filter { $0.value != "declined" }
            .map { mm.person($0.key) }
            .sorted { $0.name < $1.name }
    }

    /// "Shared with Sarah", "Sarah and Alex", then "Sarah, Alex and 3 others".
    static func sharedLabel(_ firstNames: [String]) -> String {
        switch firstNames.count {
        case 0: return ""
        case 1: return "Shared with \(firstNames[0])"
        case 2: return "Shared with \(firstNames[0]) and \(firstNames[1])"
        default:
            let rest = firstNames.count - 2
            return "Shared with \(firstNames[0]), \(firstNames[1]) and \(rest) \(rest == 1 ? "other" : "others")"
        }
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
/// contains numbered notes with their own references; nothing is saved until Add goal.
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

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !parts.contains { $0.isLoadingMedia }
    }

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

/// A photo on a note while it's being edited: one already saved (`stored`),
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

/// A picked movie owns its temporary file until the draft is saved or dismissed.
final class GoalVideoFile: Sendable {
    let url: URL
    init(url: URL) { self.url = url }
    deinit { try? FileManager.default.removeItem(at: url) }
}

struct GoalPickedVideo: Transferable {
    let file: GoalVideoFile

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.lowercased()
            let suffix = ["mp4", "mov", "m4v"].contains(ext) ? ext : "mov"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("goal-video-\(UUID().uuidString).\(suffix)")
            try FileManager.default.copyItem(at: received.file, to: url)
            return GoalPickedVideo(file: GoalVideoFile(url: url))
        }
    }
}

struct GoalVideoDraft: Identifiable, Equatable {
    let id = UUID()
    var stored: String?
    var file: GoalVideoFile?
    var url: URL? {
        if let file { return file.url }
        return stored.map { source in
            if let url = URL(string: source), url.scheme == "https" { return url }
            return URL(fileURLWithPath: MatGoal.photoSource(source))
        }
    }
    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
}

struct GoalNoteDraft: Identifiable, Equatable {
    var id: String = UUID().uuidString.lowercased()
    var text = ""
    var links: [String] = []
    var photos: [GoalPhotoDraft] = []
    var videos: [GoalVideoDraft] = []
    var isLoadingMedia = false

    init() {}
    init(_ note: GoalNote) {
        id = note.id
        text = note.text
        links = note.links
        photos = note.photos.map { GoalPhotoDraft(stored: $0) }
        videos = note.videos.map { GoalVideoDraft(stored: $0) }
    }
    var isBlank: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && links.isEmpty && photos.isEmpty && videos.isEmpty
    }
}

struct GoalPartDraft: Identifiable, Equatable {
    var id: String
    var title = ""
    var noteItems: [GoalNoteDraft] = [GoalNoteDraft()]

    init(id: String = GoalPart.newID()) { self.id = id }
    init(_ part: GoalPart) {
        id = part.id
        title = part.title
        noteItems = part.resolvedNotes.map(GoalNoteDraft.init)
        if noteItems.isEmpty { noteItems = [GoalNoteDraft()] }
    }
    var displayName: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unnamed part" : name
    }
    var isBlank: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && noteItems.allSatisfy(\.isBlank) }
    var isLoadingMedia: Bool { noteItems.contains { $0.isLoadingMedia } }
    var contentsSummary: String {
        GoalPart.summary(noteCount: noteItems.filter { !$0.isBlank }.count,
                         linkCount: noteItems.flatMap(\.links).count,
                         photoCount: noteItems.flatMap(\.photos).count,
                         videoCount: noteItems.flatMap(\.videos).count)
    }
}

/// Parts are the only cards. Numbered notes and their references use plain rows.
struct GoalPartsEditor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var parts: [GoalPartDraft]
    @State private var openID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Break it down")
                    .mmFont(.display, 18, lineHeight: 1.2)
                    .foregroundStyle(MMColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !parts.isEmpty {
                    Text(parts.count == 1 ? "1 part" : "\(parts.count) parts")
                        .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                }
            }
            Text("Add a note for each detail. Attach links, photos, and videos that explain it.")
                .mmFont(.body, 13, lineHeight: 1.4)
                .foregroundStyle(MMColor.textTertiary)
            ForEach($parts) { $part in
                let id = part.id
                GoalPartCard(part: $part, isOpen: openID == id,
                             canMoveUp: parts.first?.id != id, canMoveDown: parts.last?.id != id,
                             onToggle: { animate { openID = openID == id ? nil : id } },
                             onRemove: { animate { parts.removeAll { $0.id == id } } },
                             onMove: { offset in move(id, by: offset) })
            }
            Button(action: addPart) {
                HStack(spacing: 8) {
                    MMIcon("plus", size: 18, weight: .bold)
                    Text(parts.isEmpty ? "Add a part" : "Add another part").mmFont(.display, 15, lineHeight: 1)
                }
                .foregroundStyle(MMColor.textPrimary)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(Capsule().fill(MMColor.paper2))
                .contentShape(Capsule())
            }
            .buttonStyle(MMPressStyle())
        }
        .onChange(of: parts.map(\.id), initial: true) { _, ids in
            if !ids.contains(openID ?? "") { openID = ids.first }
        }
    }

    private func animate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : MMMotion.easeOut(), action)
    }
    private func addPart() {
        let part = GoalPartDraft()
        animate { parts.append(part); openID = part.id }
    }
    private func move(_ id: String, by offset: Int) {
        guard let index = parts.firstIndex(where: { $0.id == id }), parts.indices.contains(index + offset) else { return }
        animate { parts.swapAt(index, index + offset) }
    }
}

private struct GoalPartCard: View {
    @Binding var part: GoalPartDraft
    let isOpen: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void
    let onMove: (Int) -> Void
    @FocusState private var nameFocused: Bool
    @State private var confirmRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isOpen {
                HStack(spacing: 0) {
                    TextField("Name this part", text: $part.title)
                        .focused($nameFocused)
                        .mmFont(.display, 17, lineHeight: 1.2)
                        .foregroundStyle(MMColor.textPrimary).tint(MMColor.accent)
                        .accessibilityLabel("Part name")
                    MMIconButton("trash-2", label: "Remove part") { requestRemove() }
                        .disabled(part.isLoadingMedia)
                    MMIconButton("chevron-up", label: "Close part", action: onToggle)
                }
                ForEach($part.noteItems) { $note in
                    let noteID = note.id
                    let number = (part.noteItems.firstIndex { $0.id == note.id } ?? 0) + 1
                    GoalNoteRow(note: $note, number: number) {
                        part.noteItems.removeAll { $0.id == noteID }
                    }
                    Rectangle().fill(MMColor.borderDefault).frame(height: 1)
                }
                GoalTextAction(title: "Add a note", icon: "plus", color: MMColor.textTertiary) {
                    part.noteItems.append(GoalNoteDraft())
                }
                .padding(.leading, 28).frame(minHeight: MMLayout.tapTarget)
            } else {
                Button(action: onToggle) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(part.displayName).mmFont(.display, 16, lineHeight: 1.25)
                                .foregroundStyle(MMColor.textPrimary)
                            Text(part.contentsSummary).mmFont(.body, 13)
                                .foregroundStyle(MMColor.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        MMIcon("chevron-down", size: 20, color: MMColor.ink500)
                    }
                    .frame(minHeight: MMLayout.tapTarget).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16).mmCardSurface(radius: MMRadius.lg)
        .contextMenu {
            if canMoveUp { Button("Move up") { onMove(-1) } }
            if canMoveDown { Button("Move down") { onMove(1) } }
            Button(role: .destructive, action: requestRemove) { Label("Remove part", image: "trash-2") }
                .disabled(part.isLoadingMedia)
        }
        .confirmationDialog("Remove \(part.displayName)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove part", role: .destructive, action: onRemove)
            Button("Keep it", role: .cancel) {}
        } message: { Text("Its notes and references go with it.") }
        .onAppear { if isOpen && part.isBlank { nameFocused = true } }
    }
    private func requestRemove() {
        if part.isBlank { onRemove() } else { confirmRemove = true }
    }
}

private struct GoalNoteRow: View {
    @Environment(AppModel.self) private var mm
    @Binding var note: GoalNoteDraft
    let number: Int
    let onRemove: () -> Void
    @State private var editingLink = false
    @State private var linkDraft = ""
    @State private var linkError: String?
    @State private var picked: [PhotosPickerItem] = []
    @State private var viewingPhoto: PhotoTarget?
    @State private var viewingVideo: GoalVideoDraft?
    @State private var confirmRemove = false
    @FocusState private var linkFocused: Bool
    @FocusState private var textFocused: Bool

    private struct PhotoTarget: Identifiable { let id = UUID(); let index: Int }
    private let mediaLimit = 20

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)").mmFont(.body, 11, .bold)
                .foregroundStyle(MMColor.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(linkFocused ? MMColor.accent : MMColor.ink900))
                .padding(.top, 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    TextField("What detail do you want to remember?", text: $note.text, axis: .vertical)
                        .focused($textFocused).lineLimit(2...12)
                        .mmFont(.body, 15, lineHeight: 1.45)
                        .foregroundStyle(MMColor.textPrimary).tint(MMColor.accent)
                        .accessibilityLabel("Note \(number)")
                        .padding(.top, 14)
                    Menu {
                        Button(role: .destructive) {
                            if note.isBlank { onRemove() } else { confirmRemove = true }
                        } label: { Label("Delete note", image: "trash-2") }
                        .disabled(note.isLoadingMedia)
                    } label: {
                        MMIcon("ellipsis", size: 18, color: MMColor.textTertiary)
                            .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                    }
                    .accessibilityLabel("Options for note \(number)")
                }
                ForEach(Array(note.links.enumerated()), id: \.offset) { index, link in
                    HStack(spacing: 0) {
                        if let url = URL(string: link) {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    MMIcon("link", size: 14)
                                    Text(GoalPart.linkTitle(link)).mmFont(.mono, 12).lineLimit(1)
                                    MMIcon("arrow-up-right", size: 12)
                                }
                                .foregroundStyle(MMColor.textTertiary)
                                .frame(maxWidth: .infinity, minHeight: MMLayout.tapTarget, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .accessibilityLabel(link)
                        }
                        MMIconButton("x", label: "Remove link") { note.links.remove(at: index) }
                    }
                }
                if !note.photos.isEmpty || !note.videos.isEmpty { mediaStrip }
                HStack(spacing: 16) {
                    GoalTextAction(title: "Add a link", icon: "link", color: editingLink ? MMColor.textAccent : MMColor.textTertiary) {
                        editingLink.toggle()
                        if editingLink { linkFocused = true }
                    }
                    PhotosPicker(selection: $picked,
                                 maxSelectionCount: max(1, mediaLimit - note.photos.count - note.videos.count),
                                 selectionBehavior: .ordered, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                        HStack(spacing: 6) {
                            MMIcon("image-plus", size: 16)
                            Text("Photo/video").mmFont(.body, 13, .semibold)
                        }
                        .foregroundStyle(MMColor.textTertiary).frame(minHeight: MMLayout.tapTarget)
                    }
                    .disabled(note.isLoadingMedia || note.photos.count + note.videos.count >= mediaLimit)
                    .accessibilityLabel("Add photo or video to note \(number)")
                }
                if note.isLoadingMedia {
                    ProgressView("Adding media…").mmFont(.body, 12).padding(.vertical, 8)
                }
                if editingLink { linkField }
            }
        }
        .padding(.bottom, 12)
        .onAppear { if number > 1 && note.isBlank { textFocused = true } }
        .onChange(of: picked) { _, items in load(items) }
        .confirmationDialog("Delete note \(number)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Delete note", role: .destructive, action: onRemove)
            Button("Keep it", role: .cancel) {}
        } message: { Text("Its references go with it.") }
        .fullScreenCover(item: $viewingPhoto) { target in
            GoalPhotoViewer(note: $note, startIndex: target.index)
        }
        .sheet(item: $viewingVideo) { video in
            if let url = video.url {
                GoalVideoPlayer(url: url) {
                    note.videos.removeAll { $0.id == video.id }
                    viewingVideo = nil
                }
            }
        }
    }

    private var linkField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                TextField("Paste a link", text: $linkDraft)
                    .focused($linkFocused).keyboardType(.URL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.done).onSubmit(commitLink)
                    .mmFont(.body, 14).tint(MMColor.accent)
                    .accessibilityLabel("Link for note \(number)")
                Button("Add", action: commitLink)
                    .mmFont(.body, 14, .semibold).foregroundStyle(MMColor.textAccent)
                    .frame(minWidth: MMLayout.tapTarget, minHeight: MMLayout.tapTarget)
                MMIconButton("x", label: "Cancel adding link") {
                    editingLink = false; linkDraft = ""; linkError = nil
                }
            }
            Rectangle().fill(linkError == nil ? MMColor.borderStrong : MMColor.danger500).frame(height: 1)
            if let linkError {
                Text(linkError).mmFont(.body, 12).foregroundStyle(MMColor.danger500)
            }
        }
    }

    private var mediaStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(note.photos.enumerated()), id: \.element.id) { index, photo in
                    Button { viewingPhoto = PhotoTarget(index: index) } label: {
                        GoalPhotoImage(photo: photo)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: MMRadius.sm))
                    }
                    .accessibilityLabel("Photo \(index + 1) for note \(number)")
                }
                ForEach(note.videos) { video in
                    Button { viewingVideo = video } label: {
                        MMIcon("play", size: 20, color: MMColor.textSecondary)
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: MMRadius.sm).fill(MMColor.paper2))
                    }
                    .accessibilityLabel("Play video for note \(number)")
                }
            }
            .buttonStyle(.plain).padding(.vertical, 4)
        }
    }

    private func commitLink() {
        guard let link = AppModel.normalizedLink(linkDraft) else {
            linkError = "That doesn't look like a link"; return
        }
        if !note.links.contains(link) { note.links.append(link) }
        linkDraft = ""; linkError = nil; editingLink = false; linkFocused = false
    }

    private func load(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        note.isLoadingMedia = true
        Task { @MainActor in
            defer { note.isLoadingMedia = false; picked = [] }
            for item in items {
                if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    if let movie = try? await item.loadTransferable(type: GoalPickedVideo.self) {
                        let size = (try? movie.file.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                        if size > 0 && size <= AppModel.goalVideoSizeLimit {
                            note.videos.append(GoalVideoDraft(file: movie.file))
                        } else { mm.showToast("Choose a video under 50 MB") }
                    } else { mm.showToast("That video couldn't be read") }
                } else if let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data), let jpeg = AppModel.goalPhotoJPEG(image),
                          let preview = UIImage(data: jpeg) {
                    note.photos.append(GoalPhotoDraft(data: jpeg, preview: preview))
                } else { mm.showToast("That photo couldn't be read") }
            }
        }
    }
}

struct GoalVideoPlayer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    var onRemove: (() -> Void)?
    init(url: URL, onRemove: (() -> Void)? = nil) {
        _player = State(initialValue: AVPlayer(url: url))
        self.onRemove = onRemove
    }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Video").mmFont(.display, 18)
                Spacer()
                MMIconButton("x", label: "Close video") { dismiss() }
            }
            VideoPlayer(player: player)
            if let onRemove {
                MMButton("Remove video", variant: .ghost, iconLeft: "trash-2", action: onRemove)
            }
        }
        .padding(16).background(MMColor.bgApp)
        .onDisappear { player.pause() }
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

/// A note's photos full screen: swipe between them, jump with the filmstrip,
/// remove one with a few seconds to undo. Changes apply to the draft, so they're
/// only kept when the goal is saved.
private struct GoalPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var note: GoalNoteDraft
    @State private var index: Int
    @State private var removed: (photo: GoalPhotoDraft, index: Int)?
    @State private var undoToken = UUID()

    init(note: Binding<GoalNoteDraft>, startIndex: Int) {
        _note = note
        _index = State(initialValue: startIndex)
    }

    private var count: Int { note.photos.count }

    var body: some View {
        ZStack(alignment: .bottom) {
            MMColor.ink900.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                TabView(selection: $index) {
                    ForEach(Array(note.photos.enumerated()), id: \.element.id) { i, photo in
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
                Text("Note references")
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
            ForEach(Array(note.photos.enumerated()), id: \.element.id) { i, photo in
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
        guard note.photos.indices.contains(index) else { return }
        let at = index
        let photo = note.photos.remove(at: at)
        // Removing the last one closes the viewer; the part card is all that's left to show.
        guard !note.photos.isEmpty else {
            dismiss()
            return
        }
        index = min(at, note.photos.count - 1)
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
        let at = min(removed.index, note.photos.count)
        note.photos.insert(removed.photo, at: at)
        index = at
        undoToken = UUID()
        withAnimation(reduceMotion ? nil : MMMotion.easeOut()) { self.removed = nil }
    }
}
