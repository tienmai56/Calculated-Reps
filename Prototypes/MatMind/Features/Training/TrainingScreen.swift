import SwiftUI

/// Tab 2: upcoming and past training, using the same session tickets.
struct TrainingScreen: View {
    @Environment(AppModel.self) private var mm
    /// The hosted session being edited, or waiting for delete confirmation.
    @State private var editingSession: Session?
    @State private var deletingSession: Session?
    @State private var section = "upcoming"

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            training(now: context.date)
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

    private func training(now: Date) -> some View {
        let past = section == "past"
        let list = mm.trainingSessions(past: past, relativeTo: now)
        let invites = past ? [] : list.filter { $0.status(of: "me") == .invited }
        let rest = past ? list : list.filter { $0.status(of: "me") != .invited }
        return MMScreen(tabPadding: true) {
            MMHeader(title: "Training", large: true, trailing: {
                MMIconButton("qr-code", variant: .filled, label: "My code") { mm.go(.qr()) }
            })
            MMTabs(items: [MMTabItem("upcoming", "Upcoming"), MMTabItem("past", "Past")], selection: $section)
                .padding(.horizontal, MMSpace.s6)
                .padding(.bottom, MMSpace.s4)
        } content: {
            if list.isEmpty {
                if past {
                    MMEmptyState(artwork: .plan, title: "Your past training",
                                 message: "Sessions show up here once their start time has passed. No photo needed.",
                                 actionTitle: "Log a past session", actionIcon: "history") {
                        mm.go(.create(past: true))
                    }
                } else {
                    EmptyTraining()
                }
            }
            if !invites.isEmpty {
                MMEyebrow("Invites", topPadding: 8)
                VStack(spacing: 16) {
                    ForEach(invites) { s in sessionCard(s) }
                }
                .padding(.horizontal, 16)
            }
            if !rest.isEmpty {
                MMEyebrow(past ? "Past training" : "Coming up", topPadding: invites.isEmpty ? 8 : MMLayout.sectionGap)
                VStack(spacing: 16) {
                    ForEach(rest) { s in sessionCard(s) }
                }
                .padding(.horizontal, 16)
            }
        }
        .animation(MMMotion.easeOut(), value: list.map(\.id))
    }

    private func sessionCard(_ s: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SessionTicket(session: s, reservesMenuSpace: s.organizer == "me" && !mm.isCompleted(s)) { mm.go(.session(id: s.id)) }
                .overlay(alignment: .topTrailing) {
                    if s.organizer == "me" && !mm.isCompleted(s) { sessionMenu(s) }
                }
            if section == "upcoming" && s.status(of: "me") == .invited {
                HStack(spacing: 8) {
                    MMButton("Decline", variant: .secondary, size: .sm, fullWidth: true) { mm.rsvp(s.id, .declined) }
                    MMButton("Join", size: .sm, iconLeft: "check", fullWidth: true) { mm.rsvp(s.id, .going) }
                }
            }
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
                    MMPlaceSearchField(label: "Gym", placeholder: "Search gyms or addresses", text: $gym)
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
        MMEmptyState(artwork: .plan, title: "Summon\nyour crew",
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
        if let s = mm.findSession(id) {
            detail(s)
        } else {
            MMColor.bgApp.ignoresSafeArea().toolbar(.hidden, for: .navigationBar)
        }
    }

    private func detail(_ s: Session) -> some View {
        let isOrganizer = s.organizer == "me"
        let completed = mm.isCompleted(s)
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
                            text: s.privacy == .link ? "Anyone with the link (Mat Monkey account required)" : "Friends only",
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
                if !s.focusItems.isEmpty || (isOrganizer && !completed) {
                    HStack {
                        Text("What we're working on").mmFont(.display, 18)
                        Spacer()
                        if isOrganizer && !completed {
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
                        AttendeeRow(session: s, attendee: row, canRemove: isOrganizer && !completed && row.id != "me", divider: i < rows.count - 1)
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
            if completed {
                MMBadge("Completed", variant: .success, dot: true)
            } else if isOrganizer {
                VStack(spacing: 10) {
                    let photoReady = s.startsAt.map { $0 <= Date() } ?? (mm.toComplete?.id == s.id)
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
