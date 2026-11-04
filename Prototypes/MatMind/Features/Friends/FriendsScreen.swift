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

// MARK: - Search & discover people

/// Opened from the Activity header. Before typing: people who train with your training partners,
/// most shared partners first. Typing searches your partners and those people by name.
/// There is no public directory: strangers outside your circle never appear.
struct PeopleSearchScreen: View {
    @Environment(AppModel.self) private var mm
    @State private var query = ""

    var body: some View {
        let searching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        MMScreen {
            HStack(spacing: 6) {
                MMIconButton("chevron-left", label: "Back") { mm.back() }
                MMTextField(placeholder: "Search people by name", text: $query, iconLeft: "search")
            }
            .padding(.leading, 6)
            .padding(.trailing, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
        } content: {
            if searching {
                results
            } else {
                suggestions
            }
        }
    }

    @ViewBuilder
    private var suggestions: some View {
        let people = mm.suggestedPeople
        VStack(alignment: .leading, spacing: 4) {
            Text("Suggested for you").mmFont(.display, 18, tracking: -0.02, lineHeight: 1.2).foregroundStyle(MMColor.ink900)
            Text("People who train with your training partners").mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 6)
        if people.isEmpty {
            VStack(spacing: 14) {
                Text("Suggestions show up once your training partners have rolled with people you haven't met yet.")
                    .mmFont(.body, 15, lineHeight: 1.45).foregroundStyle(MMColor.textSecondary)
                    .multilineTextAlignment(.center)
                MMButton("Share my code", variant: .secondary, iconLeft: "qr-code") { mm.go(.qr()) }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 32)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(people) { PersonSearchRow(person: $0, showsBelt: false) }
            }
            Text("That's everyone your partners train with. Rolled with someone new? Scan each other's code.")
                .mmFont(.body, 13, lineHeight: 1.45).foregroundStyle(MMColor.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.vertical, 22)
        }
    }

    @ViewBuilder
    private var results: some View {
        let found = mm.searchPeople(query)
        if found.isEmpty {
            VStack(spacing: 6) {
                Text("No one by that name in your circle").mmFont(.display, 18, tracking: -0.02, lineHeight: 1.2).foregroundStyle(MMColor.ink900)
                Text("Search covers your training partners and the people they train with.")
                    .mmFont(.body, 15, lineHeight: 1.45).foregroundStyle(MMColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 48)
        } else {
            Text(found.count == 1 ? "1 PERSON" : "\(found.count) PEOPLE")
                .mmFont(.body, 11, .semibold, tracking: 0.1, lineHeight: 1.2).foregroundStyle(MMColor.textTertiary)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 4)
                .accessibilityLabel(found.count == 1 ? "1 person found" : "\(found.count) people found")
            LazyVStack(spacing: 0) {
                ForEach(found) { PersonSearchRow(person: $0, query: query) }
            }
        }
    }
}

/// Someone's full training partner list: your own partners first, then everyone else.
struct PartnersListScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String

    var body: some View {
        let owner = mm.person(id)
        let list = mm.partnerLists[id] ?? []
        let yours = list.filter { $0 == "me" || mm.friendship($0) != nil }
        let others = list.filter { !yours.contains($0) }
        MMScreen {
            MMHeader(title: "\(owner.firstName)'s training partners", leading: {
                MMIconButton("chevron-left", label: "Back") { mm.back() }
            })
        } content: {
            if list.isEmpty {
                Text("No training partners yet.")
                    .mmFont(.body, 15, lineHeight: 1.45).foregroundStyle(MMColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
            if !yours.isEmpty {
                MMEyebrow(title: "Your training partners", topPadding: 12) { MMMeta("\(yours.count)") }
                LazyVStack(spacing: 0) { ForEach(yours, id: \.self) { PersonSearchRow(person: mm.person($0), followsPartners: true) } }
            }
            if !others.isEmpty {
                MMEyebrow(title: yours.isEmpty ? "Training partners" : "Others", topPadding: yours.isEmpty ? 12 : MMLayout.sectionGap) {
                    MMMeta("\(others.count)")
                }
                LazyVStack(spacing: 0) { ForEach(others, id: \.self) { PersonSearchRow(person: mm.person($0), followsPartners: true) } }
            }
        }
        .task(id: id) { await mm.loadPartners(of: id) }
    }
}

/// One person in Search: tap the details to open their profile; Follow sits on the right.
private struct PersonSearchRow: View {
    @Environment(AppModel.self) private var mm
    let person: Person
    var query = ""
    /// Suggestions leave the belt to the avatar's ring; search results spell it out.
    var showsBelt = true
    /// Partner lists offer Follow on every row, your own partners included. Search labels them instead.
    var followsPartners = false

    var body: some View {
        let p = person
        let partner = mm.friendship(p.id) != nil
        let mutual = mm.mutualPartners(p.id)
        HStack(spacing: 12) {
            Button { mm.openPerson(p.id) } label: {
                HStack(spacing: 12) {
                    MMAvatar(name: p.name, photo: p.photo, size: 48, belt: p.belt)
                    VStack(alignment: .leading, spacing: 4) {
                        name(p.name)
                        if showsBelt {
                            HStack(spacing: 6) {
                                MMBelt(rank: p.belt, stripes: p.stripes, size: .xs, width: 30)
                                Text([p.belt.title, p.gym].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .mmFont(.body, 12, .medium).foregroundStyle(MMColor.textTertiary).lineLimit(1)
                            }
                        } else if !p.gym.isEmpty {
                            Text(p.gym).mmFont(.body, 12, .medium).foregroundStyle(MMColor.textTertiary).lineLimit(1)
                        }
                        if p.id == "me" {
                            Text("You").mmFont(.body, 12, .semibold).foregroundStyle(MMColor.textSecondary)
                        } else if partner {
                            Text("Your training partner").mmFont(.body, 12, .semibold).foregroundStyle(MMColor.textSecondary)
                        } else if !mutual.isEmpty {
                            HStack(spacing: 6) {
                                MMAvatarStack(people: mutual.prefix(3).map { mm.person($0).avatar }, size: 18, max: 3, ring: MMColor.bgApp)
                                Text(mutualLabel(mutual)).mmFont(.body, 12, .semibold).foregroundStyle(MMColor.textSecondary).lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(MMPressStyle(scale: 0.98))
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens \(p.firstName)'s profile")

            if (!partner || followsPartners) && mm.canFollow(p.id) {
                if mm.isFollowing(p.id) {
                    MMButton("Following", variant: .secondary, size: .sm, iconLeft: "check") { mm.setFollowing(p.id, false) }
                        .accessibilityLabel("Following \(p.name)")
                        .accessibilityHint("Unfollows")
                } else {
                    MMButton("Follow", variant: .inverse, size: .sm, iconLeft: "user-plus") { mm.setFollowing(p.id, true) }
                        .accessibilityLabel("Follow \(p.name)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(MMColor.borderSubtle).frame(height: 1) }
        .animation(MMMotion.bounce(MMMotion.base), value: mm.isFollowing(p.id))
    }

    private func mutualLabel(_ mutual: [String]) -> String {
        mutual.count == 1 ? "1 mutual partner · \(mm.person(mutual[0]).firstName)" : "\(mutual.count) mutual partners"
    }

    /// The name, with the part that matches the search in full weight and the rest lighter.
    private func name(_ full: String) -> some View {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = q.isEmpty ? nil : (full.range(of: q, options: [.caseInsensitive, .anchored])
            ?? full.range(of: " " + q, options: .caseInsensitive).map { full.index(after: $0.lowerBound)..<$0.upperBound })
        let runs: [MMRun]
        if let match {
            let light = MMFont.display(16, .bold), strong = MMFont.display(16, .extraBold)
            runs = [MMRun(text: String(full[..<match.lowerBound]), font: light, color: MMColor.textSecondary),
                    MMRun(text: String(full[match]), font: strong, color: MMColor.ink900),
                    MMRun(text: String(full[match.upperBound...]), font: light, color: MMColor.textSecondary)]
        } else {
            runs = [MMRun(text: full, font: MMFont.display(16, .extraBold), color: MMColor.ink900)]
        }
        return mmRich(runs).tracking(-0.015 * 16).lineLimit(1)
    }
}
