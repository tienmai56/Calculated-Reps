import SwiftUI

/// Tab 2: upcoming sessions, invites, the "how was it?" prompt, and past sessions.
struct TrainingScreen: View {
    @Environment(AppModel.self) private var mm
    @State private var tab = "Upcoming"

    var body: some View {
        let list = mm.plannedSessions
        let invites = list.filter { $0.status(of: "me") == .invited }
        let rest = list.filter { $0.status(of: "me") != .invited && $0.status(of: "me") != .declined }
        MMScreen(tabPadding: true) {
            VStack(spacing: 0) {
                MMHeader(title: "Training", large: true, trailing: {
                    if !list.isEmpty {
                        MMIconButton("calendar-plus", variant: .filled, label: "Plan a session") { mm.go(.create()) }
                    }
                })
                MMTabs(["Upcoming", "Past"], selection: $tab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
        } content: {
            if tab == "Past" {
                pastList
            } else {
                if let s = mm.toComplete {
                    ReadyToShare(session: s).padding(.top, 12)
                }
                if !invites.isEmpty {
                    MMEyebrow("Invites")
                    VStack(spacing: 12) {
                        ForEach(invites) { s in
                            VStack(spacing: 8) {
                                SessionTicket(session: s) { mm.go(.session(id: s.id)) }
                                HStack(spacing: 8) {
                                    MMButton("Decline", variant: .secondary, size: .sm, fullWidth: true) { mm.rsvp(s.id, .declined) }
                                    MMButton("Join", size: .sm, iconLeft: "check", fullWidth: true) { mm.rsvp(s.id, .going) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                if !rest.isEmpty {
                    MMEyebrow("Coming up")
                    VStack(spacing: 12) {
                        ForEach(rest) { s in
                            SessionTicket(session: s) { mm.go(.session(id: s.id)) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                if list.isEmpty && mm.toComplete == nil {
                    EmptyTraining()
                } else if !list.isEmpty {
                    MMButton("Plan a training session", size: .lg, iconLeft: "plus", fullWidth: true) { mm.go(.create()) }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                }
            }
        }
        .animation(MMMotion.easeOut(), value: list.map(\.id))
    }

    @ViewBuilder
    private var pastList: some View {
        if mm.posts.filter({ $0.participants.contains("me") }).isEmpty {
            MMEmptyState(artwork: .memory, title: "Your mat memories\nstart here.",
                         message: "Already got some rounds in?\nLog the session and share a photo.",
                         actionTitle: "Log a past session", actionIcon: "history") {
                mm.go(.create(past: true))
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Missed a session? Log it after the fact and it still counts for your streaks.")
                    .mmFont(.body, 14).foregroundStyle(MMColor.textTertiary)
                    .padding(.horizontal, 4)
                MMButton("Log a past session", variant: .secondary, iconLeft: "history", fullWidth: true) { mm.go(.create(past: true)) }
                ForEach(mm.posts.filter { $0.participants.contains("me") }) { p in
                    Button { mm.go(.post(id: p.id)) } label: {
                        HStack(spacing: 12) {
                            MMPhotoTile(photo: p.photo, height: 56, radius: 14).frame(width: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.title).mmFont(.display, 15).foregroundStyle(MMColor.ink900)
                                Text("\(p.date) · \(p.participants.count) people").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            MMBadge("Shared", variant: .success)
                        }
                        .padding(10)
                        .mmCardSurface(radius: 20)
                    }
                    .buttonStyle(MMPressStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

/// Ink prompt card: "How was … ?" → Complete & share.
private struct ReadyToShare: View {
    @Environment(AppModel.self) private var mm
    let session: Session

    var body: some View {
        let shortTitle = session.title.lowercased().replacingOccurrences(of: "no-gi ", with: "")
        HStack(spacing: 14) {
            Image("floor-drill").resizable().scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(.white).padding(-3))
                .rotationEffect(.degrees(-4))
            VStack(alignment: .leading, spacing: 0) {
                Text("How was \(shortTitle)?").mmFont(.display, 17, lineHeight: 1.2).foregroundStyle(MMColor.paper)
                Text("Add a photo and share it with the \(session.people.count) of you.")
                    .mmFont(.body, 13, .medium, lineHeight: 1.35).foregroundStyle(MMColor.ink200)
                    .padding(.top, 4)
                MMButton("Complete & share", size: .sm, iconLeft: "camera") { mm.go(.complete(id: session.id)) }
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(MMColor.ink900))
        .padding(.horizontal, 16)
        .padding(.top, 4)
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
                            text: s.privacy == .link ? "Anyone with the link (Mat Mind account required)" : "Friends only",
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
