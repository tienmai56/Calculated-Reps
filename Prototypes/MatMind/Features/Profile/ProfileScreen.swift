import SwiftUI

/// Tab 4: me, my belt, live streaks, and the sessions I'm in.
struct ProfileScreen: View {
    @Environment(AppModel.self) private var mm
    @State private var showSettings = false
    @State private var name = ""
    @State private var email = ""
    @State private var belt = BeltRank.purple.rawValue
    @State private var stripes = "2"

    var body: some View {
        let me = mm.me
        let mine = mm.posts.filter { $0.participants.contains("me") }
        let active = mm.friends.filter { $0.streak > 0 }.sorted { $0.streak > $1.streak }
        MMScreen(tabPadding: true) {
            HStack {
                Spacer()
                MMIconButton("settings", variant: .filled, label: "Settings") { openSettings() }
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
        } content: {
            VStack(spacing: 0) {
                MMAvatar(name: me.name, photo: me.photo, size: 108, belt: me.belt)
                Text(me.name).mmFont(.display, 30, tracking: -0.035, lineHeight: 1.05).foregroundStyle(MMColor.ink900).padding(.top, 14)
                Text(me.gym).mmFont(.body, 14).foregroundStyle(MMColor.textTertiary).padding(.top, 4)
                MMBelt(rank: me.belt, stripes: me.stripes, size: .sm, width: 190, showLabel: true).padding(.top, 14)
                HStack(spacing: 10) {
                    MMButton("\(mm.friends.count) friends", variant: .secondary, size: .sm, iconLeft: "users") { mm.setTab(.friends) }
                    MMButton("My code", variant: .secondary, size: .sm, iconLeft: "qr-code") { mm.go(.qr()) }
                }
                .padding(.top, 18)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            MMEyebrow("Weekly streaks")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(active) { f in
                        let p = mm.person(f.id)
                        Button { mm.go(.friend(id: f.id)) } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                MMPairAvatars(a: me.avatar, b: p.avatar, size: 30, hue: p.hue, ring: p.hue.tint)
                                Text("\(f.streak) wk\(f.streak > 1 ? "s" : "")").mmFont(.display, 22, tracking: -0.03, lineHeight: 1)
                                    .foregroundStyle(p.hue.ink)
                                    .padding(.top, 12)
                                Text("with \(p.firstName)").mmFont(.body, 13, .semibold).foregroundStyle(MMColor.ink700)
                                MMStreakBelt(weeks: Array(f.weeks.suffix(5)), thisWeek: f.thisWeek, hue: p.hue, size: .sm, showFlame: false)
                                    .padding(.top, 10)
                            }
                            .padding(14)
                            .frame(width: 150, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(p.hue.tint))
                        }
                        .buttonStyle(MMPressStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            MMEyebrow(title: "Activity", trailing: { MMMeta("\(mine.count) sessions") })
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(Array(mine.enumerated()), id: \.element.id) { i, post in
                    Button { mm.go(.post(id: post.id)) } label: {
                        MMPhotoTile(photo: post.photo, height: 118, corners: gridCorners(i))
                    }
                    .buttonStyle(MMPressStyle(scale: 0.97))
                }
            }
            .padding(.horizontal, 16)
        }
        .mmSheet(isPresented: $showSettings, title: "Account") {
            VStack(alignment: .leading, spacing: 16) {
                MMTextField(label: "Name", text: $name)
                VStack(alignment: .leading, spacing: 8) {
                    MMTextField(label: "Email", text: $email, iconLeft: "mail")
                    HStack(spacing: 6) {
                        MMIcon("lock", size: 14, color: MMColor.textTertiary)
                        Text("Private. Only you can see this.").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                    }
                }
                HStack(alignment: .bottom, spacing: 10) {
                    MMSelect(label: "Belt", options: BeltRank.adultRanks.map(\.rawValue), selection: $belt)
                    MMSelect(label: "Stripes", options: ["0", "1", "2", "3", "4"], selection: $stripes)
                        .frame(width: 110)
                }
                MMButton("Sign out", variant: .ghost, iconLeft: "log-out") { showSettings = false }
                    .padding(.leading, -10)
            }
        }
        .onChange(of: showSettings) { _, open in
            guard !open else { return }
            mm.updateMe(name: name.isEmpty ? mm.me.name : name, email: email,
                        belt: BeltRank(rawValue: belt) ?? mm.me.belt, stripes: Int(stripes) ?? mm.me.stripes)
        }
    }

    private func openSettings() {
        name = mm.me.name
        email = mm.me.email ?? ""
        belt = mm.me.belt.rawValue
        stripes = String(mm.me.stripes)
        showSettings = true
    }

    /// Rounded outer corners on the first row of the grid only.
    private func gridCorners(_ i: Int) -> RectangleCornerRadii {
        RectangleCornerRadii(topLeading: i == 0 ? 18 : 4, bottomLeading: 4, bottomTrailing: 4, topTrailing: i == 2 ? 18 : 4)
    }
}

// MARK: - Notifications

struct NotificationsScreen: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        let fresh = mm.notifications.filter(\.unread)
        let old = mm.notifications.filter { !$0.unread }
        MMScreen {
            MMHeader(title: "Notifications", leading: {
                MMIconButton("chevron-left", label: "Back") { mm.back() }
            })
        } content: {
            if !fresh.isEmpty {
                MMEyebrow("New", topPadding: 6)
                ForEach(fresh) { n in NotificationRow(note: n) }
            }
            MMEyebrow("Earlier")
            ForEach(old) { n in NotificationRow(note: n) }
            Color.clear.frame(height: 30)
        }
        .onDisappear { mm.readAll() }
    }
}

private struct NotificationRow: View {
    @Environment(AppModel.self) private var mm
    let note: AppNotification

    private var kindIcon: (name: String, color: Color) {
        switch note.kind {
        case .invite: ("calendar", MMColor.accent)
        case .joined: ("user-check", MMColor.mint500)
        case .comment: ("message-circle", MMColor.sky500)
        case .published: ("images", MMColor.plum500)
        }
    }

    var body: some View {
        let p = mm.person(note.who)
        let session = note.session.flatMap { sid in mm.upcoming.first { $0.id == sid } }
        HStack(alignment: .top, spacing: 12) {
            MMAvatar(name: p.name, photo: p.photo, size: 46)
                .overlay(alignment: .bottomTrailing) {
                    MMIcon(kindIcon.name, size: 12, weight: .bold, color: .white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(kindIcon.color))
                        .background(Circle().fill(MMColor.bgApp).padding(-2.5))
                        .offset(x: 3, y: 3)
                }
            VStack(alignment: .leading, spacing: 0) {
                if note.kind == .invite, let s = session {
                    mmRich([.body(p.firstName, 15, .bold), .body(" invited you to ", 15), .body(s.title, 15, .bold)])
                    Text("\(s.day), \(s.month) \(s.date) · \(s.time) · \(s.gym)").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                    if s.status(of: "me") == .invited {
                        HStack(spacing: 8) {
                            MMButton("Decline", variant: .secondary, size: .sm) { mm.rsvp(s.id, .declined) }
                            MMButton("Join", size: .sm, iconLeft: "check") { mm.rsvp(s.id, .going) }
                        }
                        .padding(.top, 10)
                    } else {
                        let going = s.status(of: "me") == .going
                        MMBadge(going ? "You're going" : "Declined", variant: going ? .success : .neutral, dot: true)
                            .padding(.top, 8)
                    }
                } else {
                    mmRich([.body(p.firstName, 15, .bold), .body(" \(note.text)", 15)])
                    if let quote = note.quote {
                        Text("“\(quote)”").mmFont(.body, 14).foregroundStyle(MMColor.textSecondary).padding(.top, 4)
                    }
                }
                Text(note.time).mmFont(.body, 12, .semibold).foregroundStyle(MMColor.textTertiary).padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let photo = note.photo {
                Button { mm.go(.post(id: "p1")) } label: {
                    MMPhotoTile(photo: photo, height: 48, radius: 10).frame(width: 48)
                }
                .buttonStyle(MMPressStyle(scale: 0.95))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(note.unread ? MMColor.coral500.opacity(0.06) : Color.clear)
    }
}
