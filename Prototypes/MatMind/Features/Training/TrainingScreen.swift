import SwiftUI
import UniformTypeIdentifiers

/// Tab 2: what's coming up and what you're working on.
/// Past sessions live in Profile → Activity, so they are not repeated here.
struct TrainingScreen: View {
    @Environment(AppModel.self) private var mm
    @State private var showAllSessions = false
    @State private var showAllGoals = false
    /// The goal being added or edited.
    @State private var editingGoal: MatGoal?
    /// The session whose goal is being picked.
    @State private var pickingFor: String?
    /// A session waiting for the goal that's being created from its picker.
    @State private var attachNewGoalTo: String?
    /// Picking an old-notebook export to bring goals over from.
    @State private var importingGoals = false
    /// The hosted session being edited, or waiting for delete confirmation.
    @State private var editingSession: Session?
    @State private var deletingSession: Session?

    private let cardWidth: CGFloat = 300
    private let goalPreviewCount = 3

    var body: some View {
        let list = mm.plannedSessions
        // Invites first so they never get buried behind your own plans.
        let ordered = list.filter { $0.status(of: "me") == .invited } + list.filter { $0.status(of: "me") != .invited }
        MMScreen(tabPadding: true) {
            MMHeader(title: "Training", large: true, trailing: {
                if !list.isEmpty {
                    MMIconButton("calendar-plus", variant: .filled, label: "Plan a session") { mm.go(.create()) }
                }
            })
        } content: {
            MMEyebrow(title: "Coming up", topPadding: 8, trailing: {
                if ordered.count > 1 {
                    textAction(showAllSessions ? "Show less" : "See all \(ordered.count)") {
                        withAnimation(MMMotion.easeOut()) { showAllSessions.toggle() }
                    }
                }
            })
            if ordered.isEmpty {
                EmptyTraining()
            } else if ordered.count == 1 || showAllSessions {
                VStack(spacing: 16) {
                    ForEach(ordered) { s in sessionCard(s) }
                }
                .padding(.horizontal, 16)
            } else {
                // One row tall however many sessions are planned, so Working on stays in view.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(ordered) { s in sessionCard(s).frame(width: cardWidth) }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 4)
                }
                // Margins (not padding) so tickets snap to the 16pt gutter.
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .padding(.vertical, -4)
            }
            goalsSection
        }
        .animation(MMMotion.easeOut(), value: list.map(\.id))
        .animation(MMMotion.easeOut(), value: mm.goals.map(\.id))
        .sheet(item: $editingGoal, onDismiss: { attachNewGoalTo = nil }) { goal in
            MatGoalEditorSheet(draft: goal, isNew: mm.goal(goal.id) == nil) { saved in
                if let sessionID = attachNewGoalTo { mm.setGoal(saved.id, forSession: sessionID) }
            }
        }
        .mmSheet(isPresented: Binding(get: { pickingFor != nil }, set: { if !$0 { pickingFor = nil } }),
                 title: "Pick a goal", description: "What do you want reps on this time?") {
            goalPicker
        }
        .fileImporter(isPresented: $importingGoals, allowedContentTypes: [.zip, .json]) { result in
            importGoals(result)
        }
        .sheet(item: $editingSession) { s in
            MatSessionEditorSheet(session: s, startsAt: mm.startDate(of: s))
        }
        .confirmationDialog("Delete \(deletingSession?.title ?? "this session")?",
                            isPresented: Binding(get: { deletingSession != nil }, set: { if !$0 { deletingSession = nil } }),
                            titleVisibility: .visible, presenting: deletingSession) { s in
            Button("Delete session", role: .destructive) { mm.deleteSession(s.id) }
            Button("Keep it", role: .cancel) {}
        } message: { s in
            Text(s.people.count > 1 ? "It comes off everyone's schedule." : "It comes off your schedule.")
        }
    }

    /// Host-only options on a ticket.
    private func sessionMenu(_ s: Session) -> some View {
        Menu {
            Button { editingSession = s } label: { Label("Edit session", image: "pencil") }
            Button(role: .destructive) { deletingSession = s } label: { Label("Delete session", image: "trash-2") }
        } label: {
            MMIcon("ellipsis", size: 20, color: MMColor.ink700)
                .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Options for \(s.title)")
        .padding(.top, 2)
        .padding(.trailing, 2)
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

    // MARK: Coming up

    private func sessionCard(_ s: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SessionTicket(session: s, reservesMenuSpace: s.organizer == "me") { mm.go(.session(id: s.id)) }
                .overlay(alignment: .topTrailing) {
                    if s.organizer == "me" { sessionMenu(s) }
                }
            goalRow(s)
            if s.status(of: "me") == .invited {
                HStack(spacing: 8) {
                    MMButton("Decline", variant: .secondary, size: .sm, fullWidth: true) { mm.rsvp(s.id, .declined) }
                    MMButton("Join", size: .sm, iconLeft: "check", fullWidth: true) { mm.rsvp(s.id, .going) }
                }
            }
        }
    }

    /// The goal attached to a session, or a quiet way to pick one.
    @ViewBuilder
    private func goalRow(_ s: Session) -> some View {
        if let goal = mm.goal(forSession: s.id) {
            Button { pickingFor = s.id } label: {
                HStack(spacing: 6) {
                    MMIcon("notebook-pen", size: 14, color: MMColor.ink700)
                    Text(goal.title).mmFont(.body, 13, .semibold, lineHeight: 1).foregroundStyle(MMColor.ink900)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(MMColor.paper2))
                .frame(minHeight: MMLayout.tapTarget)
            }
            .buttonStyle(MMPressStyle(scale: 0.96))
            .accessibilityLabel("Working on \(goal.title). Change goal")
        } else {
            Button { pickingFor = s.id } label: {
                HStack(spacing: 4) {
                    MMIcon("plus", size: 14, weight: .bold)
                    Text("Pick a goal").mmFont(.body, 13, .bold, lineHeight: 1)
                }
                .foregroundStyle(MMColor.coral700)
                .padding(.horizontal, 4)
                .frame(minHeight: MMLayout.tapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(MMPressStyle(scale: 0.96))
        }
    }

    @ViewBuilder
    private var goalPicker: some View {
        if let sessionID = pickingFor {
            let current = mm.sessionGoals[sessionID]
            VStack(alignment: .leading, spacing: 10) {
                ForEach(mm.goals) { g in
                    MMTag(g.title, icon: current == g.id ? "check" : nil, selected: current == g.id, action: {
                        mm.setGoal(current == g.id ? nil : g.id, forSession: sessionID)
                        pickingFor = nil
                    })
                }
                HStack(spacing: 8) {
                    MMButton("New goal", variant: .secondary, size: .sm, iconLeft: "plus") {
                        pickingFor = nil
                        attachNewGoalTo = sessionID
                        // Let the picker finish dismissing before the editor presents.
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(0.35))
                            editingGoal = .new()
                        }
                    }
                    if current != nil {
                        MMButton("No goal this time", variant: .ghost, size: .sm) {
                            mm.setGoal(nil, forSession: sessionID)
                            pickingFor = nil
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: Working on

    @ViewBuilder
    private var goalsSection: some View {
        let goals = mm.goals
        let shown = showAllGoals ? goals : Array(goals.prefix(goalPreviewCount))
        MMEyebrow(title: "Working on", trailing: {
            if !goals.isEmpty {
                textAction("Add a goal", icon: "plus") { editingGoal = .new() }
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
                ForEach(shown) { g in
                    WorkingOnGoalCard(goal: g) { editingGoal = g }
                }
                if goals.count > goalPreviewCount {
                    textAction(showAllGoals ? "Show less" : "See all \(goals.count) goals", color: MMColor.textSecondary) {
                        withAnimation(MMMotion.easeOut()) { showAllGoals.toggle() }
                    }
                }
                if mm.canImportGoals {
                    textAction("Import goals from your old notebook", icon: "upload", color: MMColor.textTertiary) {
                        importingGoals = true
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    /// Quiet coral text action used in section headers.
    private func textAction(_ title: String, icon: String? = nil, color: Color = MMColor.coral700,
                            action: @escaping () -> Void) -> some View {
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
private struct WorkingOnGoalCard: View {
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
private struct MatGoalEditorSheet: View {
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

/// Host-only edit: name, when, gym and note. People and the focus plan stay as they are.
private struct MatSessionEditorSheet: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.dismiss) private var dismiss
    let session: Session
    @State private var title: String
    @State private var startsAt: Date
    @State private var gym: String
    @State private var note: String
    @State private var saving = false

    init(session: Session, startsAt: Date) {
        self.session = session
        _title = State(initialValue: session.title)
        _startsAt = State(initialValue: startsAt)
        _gym = State(initialValue: session.gym)
        _note = State(initialValue: session.note ?? "")
    }

    private var canSave: Bool {
        !saving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !gym.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            MMDialogBody(title: "Edit session", description: "Everyone in it sees the change.", onClose: { dismiss() }) {
                VStack(alignment: .leading, spacing: 18) {
                    MMTextField(label: "Session name", placeholder: "Saturday open mat", text: $title)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("When").mmFont(.display, 14, .bold, tracking: 0, lineHeight: 1.2).foregroundStyle(MMColor.textPrimary)
                        DatePicker("When", selection: $startsAt, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(MMColor.accent)
                    }
                    MMTextField(label: "Gym", placeholder: "Where you're rolling", text: $gym, iconLeft: "map-pin")
                    MMTextField(label: "Note", placeholder: "Anything people should know", text: $note, multiline: true, rows: 4)
                }
                .padding(.top, MMSpace.s4)
            } actions: {
                EmptyView()
            }
            .padding(MMSpace.s7)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            MMButton("Save changes", fullWidth: true) {
                saving = true
                Task {
                    let saved = await mm.editSession(session.id, title: title, startsAt: startsAt, gym: gym, note: note)
                    saving = false
                    if saved { dismiss() }
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
    }
}

/// The next session is an invitation, not a missing-data error.
private struct EmptyTraining: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        MMEmptyState(artwork: .plan, title: "Make it a\nmat date.",
                     message: "Pick a day. Bring your people.\nThe rounds will follow.",
                     actionTitle: "Plan a training session", actionIcon: "plus",
                     secondaryTitle: "Already trained? Log it", secondaryIcon: "history",
                     secondaryAction: { mm.go(.create(past: true)) }) {
            mm.go(.create())
        }
    }
}

// MARK: - Session detail

struct SessionDetailScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String

    @State private var showAdd = false
    @State private var picked: Set<String> = []
    @State private var showFocusEditor = false
    @State private var focusDraft: [TrainingFocus] = []

    var body: some View {
        if let s = mm.upcoming.first(where: { $0.id == id }) ?? (mm.toComplete?.id == id ? mm.toComplete : nil) {
            detail(s)
        } else {
            MMColor.bgApp.ignoresSafeArea().toolbar(.hidden, for: .navigationBar)
        }
    }

    private func detail(_ s: Session) -> some View {
        let isOrganizer = s.organizer == "me"
        let mine = s.status(of: "me")
        // Organizer first, everyone else in invite order.
        let rows = s.people.filter { $0.id == s.organizer } + s.people.filter { $0.id != s.organizer }
        let addable = mm.friends.map(\.id).filter { fid in s.status(of: fid) == nil }
        return MMScreen {
            MMHeader(title: "", leading: {
                MMIconButton("chevron-left", label: "Back") { mm.back() }
            }, trailing: {
                if isOrganizer {
                    MMIconButton("share-2", label: "Share") { mm.copySessionLink(s.id) }
                }
            })
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                SessionTicket(session: s, big: true)
                VStack(spacing: 0) {
                    infoRow(icon: "map-pin", text: s.gym, divider: true)
                    infoRow(icon: "clock", text: "\(s.day), \(s.month) \(s.date) · \(s.time)", divider: true)
                    infoRow(icon: s.privacy == .link ? "globe" : "lock",
                            text: s.privacy == .link ? "Anyone with the link (Mat Monkeys account required)" : "Friends only",
                            divider: false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .mmCardSurface(radius: 22)
                .padding(.top, 14)
                if let note = s.note {
                    Text("“\(note)”").mmFont(.body, 15, lineHeight: 1.45).foregroundStyle(MMColor.ink700)
                        .padding(.horizontal, 4)
                        .padding(.top, 14)
                }
                if !s.focusItems.isEmpty || isOrganizer {
                    HStack {
                        Text("What we're working on").mmFont(.display, 18)
                        Spacer()
                        if isOrganizer {
                            MMIconButton("pencil", label: "Edit session focus") {
                                focusDraft = s.focusItems
                                showFocusEditor = true
                            }
                        }
                    }
                    .padding(.top, MMSpace.s6)
                    if !s.focusItems.isEmpty {
                        TrainingFocusOutline(items: s.focusItems)
                            .padding(.top, MMSpace.s4)
                    } else {
                        MMButton("Add a focus", variant: .secondary, iconLeft: "plus", fullWidth: true) {
                            focusDraft = []
                            showFocusEditor = true
                        }
                        .padding(.top, MMSpace.s4)
                    }
                }
                Text("Who's coming").mmFont(.display, 18)
                    .padding(.horizontal, 4)
                    .padding(.top, 22)
                    .padding(.bottom, 10)
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        AttendeeRow(session: s, attendee: row, canRemove: isOrganizer && row.id != "me", divider: i < rows.count - 1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .mmCardSurface(radius: 22)
                .animation(MMMotion.bounce(), value: rows.map(\.id))
                Color.clear.frame(height: 16)
            }
            .padding(.horizontal, 16)
        } footer: {
            if isOrganizer {
                VStack(spacing: 10) {
                    let photoReady = mm.toComplete?.id == s.id
                    MMButton("Take a photo", variant: .secondary, size: .lg, iconLeft: "camera", fullWidth: true) {
                        mm.go(.complete(id: s.id))
                    }
                    .disabled(!photoReady)
                    .accessibilityHint(photoReady ? "Opens the session photo composer" : "Available after your session")
                    if !photoReady {
                        Text("Available after your session")
                            .mmFont(.body, 12)
                            .foregroundStyle(MMColor.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    HStack(spacing: 8) {
                        MMButton("Add people", variant: .secondary, iconLeft: "user-plus", fullWidth: true) {
                            picked = []
                            showAdd = true
                        }
                        MMButton("Copy link", variant: .soft, iconLeft: "link", fullWidth: true) { mm.copySessionLink(s.id) }
                    }
                }
            } else if mine == .invited {
                HStack(spacing: 8) {
                    MMButton("Decline", variant: .secondary, fullWidth: true) {
                        mm.rsvp(s.id, .declined)
                        mm.back()
                    }
                    MMButton("Join", iconLeft: "check", fullWidth: true) { mm.rsvp(s.id, .going) }
                }
            } else {
                HStack(spacing: 8) {
                    MMBadge("You're going", variant: .success, dot: true, height: 34, fontSize: 14, paddingX: 14)
                    MMButton("Can't make it", variant: .ghost, size: .sm) {
                        mm.rsvp(s.id, .declined)
                        mm.back()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showFocusEditor) {
            ScrollView {
                MMDialogBody(title: "What are we working on?", description: "Big idea first. Details underneath.",
                             onClose: { showFocusEditor = false }) {
                    TrainingFocusEditor(items: $focusDraft)
                } actions: {
                    EmptyView()
                }
                .padding(MMSpace.s7)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                MMButton("Save focus plan", fullWidth: true) {
                    if let runtime = mm.runtime {
                        Task { if await runtime.saveFocus(s.id, focusDraft) { showFocusEditor = false } }
                    } else if mm.updateSessionFocus(s.id, focusDraft) { showFocusEditor = false }
                }
                .disabled(!TrainingFocusTree.isValid(focusDraft))
                .padding(MMSpace.s6)
                .background(MMColor.bgApp)
            }
            .background(MMColor.bgApp)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(MMRadius.xl)
            .presentationBackground(MMColor.bgApp)
        }
        .mmSheet(isPresented: $showAdd, title: "Add people", description: "They're added straight to the session.") {
            VStack(alignment: .leading, spacing: 14) {
                if addable.isEmpty {
                    Text("All your friends are already in.").mmFont(.body, 15).foregroundStyle(MMColor.textTertiary)
                }
                ForEach(addable, id: \.self) { fid in
                    let p = mm.person(fid)
                    HStack(spacing: 12) {
                        MMAvatar(name: p.name, size: 36)
                        Text(p.name).mmFont(.body, 15, .semibold).foregroundStyle(MMColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        MMCheckbox(isOn: Binding(
                            get: { picked.contains(fid) },
                            set: { on in if on { picked.insert(fid) } else { picked.remove(fid) } }
                        ))
                    }
                }
            }
        } actions: {
            MMButton(picked.isEmpty ? "Add" : "Add \(picked.count)", fullWidth: true) {
                let ids = addable.filter { picked.contains($0) }
                showAdd = false
                mm.addParticipants(s.id, ids)
            }
            .disabled(picked.isEmpty)
        }
    }

    private func infoRow(icon: String, text: String, divider: Bool) -> some View {
        HStack(spacing: 12) {
            MMIcon(icon, size: 18, color: MMColor.textTertiary)
            Text(text).mmFont(.body, 15, .medium).foregroundStyle(MMColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(MMColor.borderSubtle).frame(height: 1) }
        }
    }
}

private struct AttendeeRow: View {
    @Environment(AppModel.self) private var mm
    let session: Session
    let attendee: Attendee
    let canRemove: Bool
    let divider: Bool

    @State private var joined = false

    var body: some View {
        let p = mm.person(attendee.id)
        let badge = attendee.status.badge
        let isFresh = mm.fresh == session.id + attendee.id
        HStack(spacing: 12) {
            MMAvatar(name: p.name, photo: p.photo, size: 40, belt: p.belt, ring: .white)
            VStack(alignment: .leading, spacing: 2) {
                Text(attendee.id == "me" ? "You" : p.name).mmFont(.body, 15, .bold).foregroundStyle(MMColor.textPrimary)
                Text(attendee.id == session.organizer ? "Organizer" : p.gym).mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MMBadge(badge.label, variant: badge.variant)
                .contentTransition(.opacity)
            if canRemove {
                MMIconButton("x", size: 32, label: "Remove \(p.name)") { mm.removeParticipant(session.id, attendee.id) }
            }
        }
        .padding(.vertical, 10)
        .background(isFresh && !joined ? MMColor.mint100 : Color.clear)
        .scaleEffect(isFresh && !joined ? 0.96 : 1)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(MMColor.borderSubtle).frame(height: 1) }
        }
        .onChange(of: isFresh, initial: true) { _, nowFresh in
            guard nowFresh else { return }
            joined = false
            withAnimation(MMMotion.bounce(0.6).delay(0.05)) { joined = true }
        }
    }
}
