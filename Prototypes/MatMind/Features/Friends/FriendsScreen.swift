import SwiftUI

/// Encouraging, never guilt: copy for one friendship's streak state.
private struct StreakCopy {
    enum State { case pending, done, broken }
    var line: String
    var cta: String?
    var state: State

    init(_ f: Friendship, first: String) {
        let n = f.streak
        if n == 0 && f.best == 0 {
            self.init(line: "New friend. Train together to start a streak", cta: "Invite", state: .broken)
        } else if n == 0 {
            self.init(line: "Ended \(f.brokeAgo ?? "recently") · best \(f.best) weeks", cta: "Start again", state: .broken)
        } else if f.thisWeek == .done {
            self.init(line: n == 1 ? "New streak with \(first). Same time next week?" : "This week's locked in. Longest: \(max(f.best, n)) weeks",
                      cta: nil, state: .done)
        } else {
            self.init(line: "Roll together by Sunday to make it \(n + 1)", cta: "Invite", state: .pending)
        }
    }

    private init(line: String, cta: String?, state: State) {
        self.line = line
        self.cta = cta
        self.state = state
    }
}

/// Weekly streaks, grouped by what each friendship needs. Opened from Profile.
struct FriendsScreen: View {
    @Environment(AppModel.self) private var mm
    /// Pushed from Profile (back button, no tab bar) rather than shown as a tab root.
    var pushed = false

    var body: some View {
        let all = mm.friends
        MMScreen(tabPadding: !pushed) {
            if pushed {
                MMHeader(title: "Friends", leading: {
                    MMIconButton("chevron-left", label: "Back") { mm.back() }
                }, trailing: {
                    MMIconButton("qr-code", variant: .filled, label: "My code") { mm.go(.qr()) }
                })
            } else {
                MMHeader(title: "Friends", large: true, trailing: {
                    MMIconButton("qr-code", variant: .filled, label: "My code") { mm.go(.qr()) }
                })
            }
        } content: {
            Button { mm.go(.qr(scan: true)) } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("At the gym with someone new?").mmFont(.display, 18, lineHeight: 1.15).foregroundStyle(MMColor.ink900)
                        Text("Scan their code. You're friends instantly.").mmFont(.body, 13).foregroundStyle(MMColor.ink700)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    MMIcon("scan-line", size: 26, weight: .bold, color: MMColor.sun400)
                        .frame(width: 52, height: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(MMColor.ink900))
                        .rotationEffect(.degrees(6))
                }
                .padding(.vertical, 16)
                .padding(.leading, 18)
                .padding(.trailing, 16)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(MMColor.sun100))
            }
            .buttonStyle(MMPressStyle())
            .padding(.horizontal, 16)
            .padding(.top, 4)

            section("New friends", list: all.filter { $0.streak == 0 && $0.best == 0 })
            section("Keep it going", sub: "Weeks run Mon–Sun", list: all.filter { $0.streak > 0 && $0.thisWeek == .pending })
            section("Trained together this week", list: all.filter { $0.thisWeek == .done })
            section("Pick it back up", list: all.filter { $0.streak == 0 && $0.best > 0 })

            Text("A streak grows each week you and a friend finish at least one session together.")
                .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .padding(.top, 24)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func section(_ title: String, sub: String? = nil, list: [Friendship]) -> some View {
        if !list.isEmpty {
            MMEyebrow(title: title, trailing: {
                if let sub { MMMeta(sub) }
            })
            VStack(spacing: 12) {
                ForEach(list) { f in FriendStreakCard(friendship: f) }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct FriendStreakCard: View {
    @Environment(AppModel.self) private var mm
    let friendship: Friendship

    var body: some View {
        let f = friendship
        let p = mm.person(f.id)
        let n = f.streak
        let copy = StreakCopy(f, first: p.firstName)
        let broken = copy.state == .broken
        // A tap gesture rather than a Button, so the inner Invite buttons stay tappable.
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                MMPairAvatars(a: mm.me.avatar, b: p.avatar, size: 40, hue: broken ? .coral : p.hue, knot: !broken)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You + \(p.firstName)").mmFont(.display, 17, lineHeight: 1.15).foregroundStyle(MMColor.ink900)
                        .mmMonkey(p.monkey, size: 20)
                    Text(copy.line).mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                if broken {
                    MMButton(copy.cta ?? "Invite", variant: .secondary, size: .sm) { mm.go(.create(friend: f.id)) }
                } else {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(n)").mmFont(.display, 30, tracking: -0.04, lineHeight: 1).foregroundStyle(p.hue.ink)
                        Text(n == 1 ? "WEEK" : "WEEKS").mmFont(.body, 11, .bold, lineHeight: 1).foregroundStyle(MMColor.textTertiary)
                    }
                }
            }
            MMStreakBelt(weeks: f.weeks, thisWeek: f.thisWeek, hue: p.hue, showFlame: !broken)
                .opacity(broken ? 0.55 : 1)
                .padding(.top, 14)
            if copy.state == .pending {
                HStack {
                    Text(mm.isLive ? "Make a plan with \(p.firstName) this week" : "\(p.firstName) is free most Thursdays").mmFont(.body, 13, .semibold).foregroundStyle(p.hue.ink)
                    Spacer(minLength: 8)
                    MMButton("Invite", size: .sm, iconLeft: "calendar-plus") { mm.go(.create(friend: f.id)) }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(p.hue.tint))
                .padding(.top, 12)
            }
        }
        .padding(16)
        .mmCardSurface(radius: 24)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { mm.go(.friend(id: f.id)) }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Friend profile

struct FriendProfileScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String
    @State private var confirmBlock = false

    var body: some View {
        let p = mm.person(id)
        let f = mm.friendship(id)
        let n = f?.streak ?? 0
        let shared = mm.posts.filter { $0.participants.contains("me") && $0.participants.contains(id) }
        MMScreen {
            MMHeader(title: "", leading: {
                MMIconButton("chevron-left", label: "Back") { mm.back() }
            })
        } content: {
            VStack(spacing: 0) {
                MMAvatar(name: p.name, photo: p.photo, size: 104, belt: p.belt)
                Text(p.name).mmFont(.display, 30, tracking: -0.035, lineHeight: 1.05).foregroundStyle(MMColor.ink900)
                    .mmMonkey(p.monkey, size: 28)
                    .padding(.top, 14)
                Text(p.gym).mmFont(.body, 14).foregroundStyle(MMColor.textTertiary).padding(.top, 4)
                MMBelt(rank: p.belt, stripes: p.stripes, size: .sm, width: 180, showLabel: true).padding(.top, 14)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            if let f {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        MMPairAvatars(a: mm.me.avatar, b: p.avatar, size: 36, hue: p.hue, ring: p.hue.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n > 0 ? "\(n)-week streak" : "Streak on pause").mmFont(.display, 20, tracking: -0.03, lineHeight: 1.1).foregroundStyle(p.hue.ink)
                            Text(n > 0 ? (f.thisWeek == .done ? "This week is covered." : "Train together by Sunday to keep it.")
                                       : "Your best was \(f.best) weeks. Start a new one?")
                                .mmFont(.body, 13).foregroundStyle(MMColor.ink700)
                        }
                    }
                    MMStreakBelt(weeks: f.weeks, thisWeek: f.thisWeek, hue: p.hue).padding(.top, 14)
                    HStack(spacing: 0) {
                        stat("\(max(f.best, n)) wks", "Longest streak")
                        stat("\(f.together)", "Sessions together")
                            .padding(.leading, 14)
                            .overlay(alignment: .leading) { Rectangle().fill(MMColor.ink900.opacity(0.1)).frame(width: 1.5) }
                    }
                    .padding(.top, 14)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(p.hue.tint))
                .padding(.horizontal, 16)
                .padding(.top, 22)
            }

            MMEyebrow("Memories together")
            Group {
                if shared.isEmpty {
                    Text("No shared posts yet. Fix that this week.").mmFont(.body, 14).foregroundStyle(MMColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(shared) { post in
                            Button { mm.go(.post(id: post.id)) } label: {
                                MMPhotoTile(photo: post.photo, height: 150, radius: 18) {
                                    Text(post.title)
                                        .mmFont(.display, 13, lineHeight: 1.1)
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                        .padding(8)
                                }
                            }
                            .buttonStyle(MMPressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        } footer: {
            VStack(spacing: 8) {
            MMButton("Invite \(p.firstName) to train", size: .lg, iconLeft: "calendar-plus", fullWidth: true) {
                mm.go(.create(friend: id))
            }
            if mm.isLive { MMButton("Block user", variant: .ghost) { confirmBlock = true } }
            }
        }
        .confirmationDialog("Block this training partner?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block user", role: .destructive) {
                Task { if await mm.runtime?.perform("block_user", ["user_id": id]) == true { mm.back() } }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).mmFont(.display, 22, tracking: -0.03, lineHeight: 1).foregroundStyle(MMColor.ink900)
            Text(label).mmFont(.body, 12, .semibold).foregroundStyle(MMColor.ink700)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
