import SwiftUI

// Sharing goals: the share sheet on your own goal, the Shared tab in Goals, and
// the read-only page for a goal someone shared with you, where you accept or decline.

// MARK: - Goals › Shared

/// Invitations waiting for an answer, then the goals you accepted.
struct SharedGoalsSection: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        let invites = mm.goalInvites
        let accepted = mm.acceptedSharedGoals
        if invites.isEmpty && accepted.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Nothing shared yet")
                    .mmFont(.display, 18, lineHeight: 1.2)
                    .foregroundStyle(MMColor.textPrimary)
                Text("When a training partner shares a goal with you, it shows up here.")
                    .mmFont(.body, 14, lineHeight: 1.45)
                    .foregroundStyle(MMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(MMSpace.s7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous).fill(MMColor.surfaceSunken))
            .padding(.horizontal, 16)
            .padding(.top, MMLayout.sectionGap)
        } else {
            if !invites.isEmpty {
                MMEyebrow("Invites", topPadding: 18)
                VStack(spacing: 10) {
                    ForEach(invites) { GoalInviteCard(shared: $0) }
                }
                .padding(.horizontal, 16)
            }
            if !accepted.isEmpty {
                MMEyebrow(title: "Shared with you", topPadding: invites.isEmpty ? 18 : MMLayout.sectionGap, trailing: {
                    MMMeta("Read-only")
                })
                VStack(spacing: 10) {
                    ForEach(accepted) { shared in
                        SharedGoalCard(shared: shared) { mm.go(.sharedGoal(id: shared.id)) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// "Kenji shared Berimbolo entries": the same Decline / Look / Accept pattern as session invites.
struct GoalInviteCard: View {
    @Environment(AppModel.self) private var mm
    let shared: SharedGoal

    var body: some View {
        let owner = mm.person(shared.owner)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MMAvatar(name: owner.name, photo: owner.photo, size: 40, belt: owner.belt, ring: MMColor.surfaceCard)
                VStack(alignment: .leading, spacing: 2) {
                    mmRich([.body(owner.firstName, 15, .bold), .body(" shared ", 15), .body(shared.title, 15, .bold)])
                        .fixedSize(horizontal: false, vertical: true)
                    if !meta.isEmpty {
                        Text(meta).mmFont(.body, 12, .medium, lineHeight: 1.3).foregroundStyle(MMColor.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                MMButton("Decline", variant: .ghost, size: .sm, fullWidth: true) {
                    Task { await mm.respondToSharedGoal(shared.id, accept: false) }
                }
                MMButton("Look", variant: .secondary, size: .sm, fullWidth: true) {
                    mm.go(.sharedGoal(id: shared.id))
                }
                MMButton("Accept", variant: .inverse, size: .sm, fullWidth: true) {
                    Task { await mm.respondToSharedGoal(shared.id, accept: true) }
                }
            }
        }
        .padding(14)
        .mmCardSurface(radius: 22)
        .accessibilityElement(children: .contain)
    }

    private var meta: String {
        let ago = shared.sharedAt.map { RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date()) }
        return [shared.contentsSummary, ago].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// An accepted shared goal: its name, who it's from (in their hue) and a peek at the notes.
struct SharedGoalCard: View {
    @Environment(AppModel.self) private var mm
    let shared: SharedGoal
    let onTap: () -> Void

    var body: some View {
        let owner = mm.person(shared.owner)
        let preview = shared.content.cardPreview
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(shared.title).mmFont(.display, 18, lineHeight: 1.2).foregroundStyle(MMColor.ink900)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SharedFromChip(person: owner)
                    }
                    if !preview.isEmpty {
                        Text(preview).mmFont(.body, 13, lineHeight: 1.4).foregroundStyle(MMColor.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    if !shared.contentsSummary.isEmpty {
                        Text(shared.contentsSummary).mmFont(.body, 12, .medium, lineHeight: 1.3).foregroundStyle(MMColor.textTertiary)
                    }
                }
                MMIcon("chevron-right", size: 18, color: MMColor.ink400)
            }
            .padding(16)
            .mmCardSurface(radius: 22)
        }
        .buttonStyle(MMPressStyle())
        .accessibilityHint("From \(owner.name)")
    }
}

/// "From Sarah" on the sharer's friend-hue tint.
struct SharedFromChip: View {
    let person: Person

    var body: some View {
        HStack(spacing: 6) {
            MMAvatar(name: person.name, photo: person.photo, size: 18)
            Text("From \(person.firstName)").mmFont(.body, 12, .semibold, lineHeight: 1).lineLimit(1)
        }
        .foregroundStyle(person.hue.ink)
        .padding(.leading, 3)
        .padding(.trailing, 10)
        .frame(height: 24)
        .background(Capsule().fill(person.hue.tint))
        .fixedSize()
    }
}

// MARK: - Share sheet

/// Share one of your goals: pick training partners, or copy a link for anyone else.
/// Everything goes along, and later saves come through for everyone it's shared with.
struct GoalShareSheet: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.dismiss) private var dismiss
    let goalID: String
    @State private var picked: [String] = []
    @State private var working = false
    /// Result of the last copy, shown in the sheet (the app's toast sits under it).
    @State private var linkCopied: Bool?

    var body: some View {
        if let goal = mm.goal(goalID) {
            content(goal)
        }
    }

    private func content(_ goal: MatGoal) -> some View {
        let answers = mm.recipients(ofGoal: goal.id)
        let partners = mm.friends.map { mm.person($0.id) }
        return ScrollView {
            MMDialogBody(title: "Share \(goal.title)", description: Self.summary(goal), onClose: { dismiss() }) {
                VStack(alignment: .leading, spacing: MMLayout.sectionGap) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Training partners").mmFont(.display, 16, lineHeight: 1.25).foregroundStyle(MMColor.textPrimary)
                            Spacer()
                            if !picked.isEmpty { MMMeta("\(picked.count) picked") }
                        }
                        if partners.isEmpty {
                            Text("Add a training partner to share with them here. A link works for anyone.")
                                .mmFont(.body, 14, lineHeight: 1.45).foregroundStyle(MMColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 14) {
                                    ForEach(partners) { person in
                                        partnerButton(person, answer: answers[person.id])
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                            }
                            .padding(.horizontal, -4)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Or send a link").mmFont(.display, 16, lineHeight: 1.25).foregroundStyle(MMColor.textPrimary)
                        Button {
                            Task {
                                working = true
                                linkCopied = nil
                                linkCopied = await mm.copyGoalLink(goal.id)
                                working = false
                            }
                        } label: {
                            HStack(spacing: 10) {
                                MMIcon("link", size: 18, color: MMColor.textTertiary)
                                Text(linkTitle).mmFont(.body, 15, .semibold, lineHeight: 1.2)
                                    .foregroundStyle(MMColor.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if working {
                                    ProgressView().tint(MMColor.ink900)
                                } else {
                                    MMIcon(linkCopied == true ? "check" : "copy", size: 18, weight: .bold,
                                           color: linkCopied == true ? MMColor.mint700 : MMColor.ink900)
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 52)
                            .mmCardSurface(radius: 22)
                        }
                        .buttonStyle(MMPressStyle())
                        .disabled(working)
                        if linkCopied == false {
                            HStack(alignment: .top, spacing: 6) {
                                MMIcon("circle-alert", size: 14, color: MMColor.coral700).padding(.top, 1)
                                Text("Couldn't make a link. Check your connection and try again.")
                                    .mmFont(.body, 12, lineHeight: 1.3).foregroundStyle(MMColor.coral700)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        HStack(alignment: .top, spacing: 6) {
                            MMIcon("lock", size: 14, color: MMColor.textTertiary).padding(.top, 1)
                            Text("Anyone with the link can ask to add it. They need a Mat Monkey account to see what's inside.")
                                .mmFont(.body, 12, lineHeight: 1.3).foregroundStyle(MMColor.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, MMSpace.s4)
            } actions: {
                EmptyView()
            }
            .padding(MMSpace.s7)
        }
        .safeAreaInset(edge: .bottom) {
            MMButton(shareTitle, size: .lg, iconLeft: "send", fullWidth: true) {
                // Close now: the toast says it's sharing and then that it's shared, and a
                // failure shows the app's alert, which this sheet would otherwise cover.
                let people = picked
                let id = goal.id
                dismiss()
                Task { await mm.shareGoal(id, with: people) }
            }
            .disabled(picked.isEmpty || working)
            .padding(MMSpace.s6)
            .background(MMColor.bgApp)
        }
        .background(MMColor.bgApp)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MMRadius.xl)
        .presentationBackground(MMColor.bgApp)
    }

    private var linkTitle: String {
        if working { return "Making a link…" }
        return linkCopied == true ? "Link copied. Paste it anywhere." : "Copy a link to this goal"
    }

    private var shareTitle: String {
        switch picked.count {
        case 0: "Share"
        case 1: "Share with \(mm.person(picked[0]).firstName)"
        default: "Share with \(picked.count) partners"
        }
    }

    /// What goes along, so nobody is surprised by what the other person sees.
    static func summary(_ goal: MatGoal) -> String {
        let parts = goal.parts.count
        let videos = goal.parts.filter { !$0.link.isEmpty }.count
        let photos = goal.allPhotos.count
        var bits: [String] = []
        if !goal.notes.isEmpty { bits.append("your notes") }
        if parts > 0 { bits.append(parts == 1 ? "1 part" : "\(parts) parts") }
        if videos > 0 { bits.append(videos == 1 ? "a video" : "\(videos) videos") }
        if photos > 0 { bits.append(photos == 1 ? "a photo" : "\(photos) photos") }
        if !goal.links.isEmpty { bits.append(goal.links.count == 1 ? "a link" : "\(goal.links.count) links") }
        let list: String
        switch bits.count {
        case 0: list = "Everything in it goes along"
        case 1: list = "Everything goes along: \(bits[0])"
        default: list = "Everything goes along: " + bits.dropLast().joined(separator: ", ") + " and " + bits.last!
        }
        return list + ". They see it read-only, and your saved edits come through."
    }

    @ViewBuilder
    private func partnerButton(_ person: Person, answer: String?) -> some View {
        let on = picked.contains(person.id)
        // Already has it (or hasn't answered yet): nothing to send again.
        let has = answer == "accepted" || answer == "pending"
        Button {
            withAnimation(MMMotion.bounce(MMMotion.base)) {
                if on { picked.removeAll { $0 == person.id } } else { picked.append(person.id) }
            }
        } label: {
            VStack(spacing: 6) {
                MMAvatar(name: person.name, photo: person.photo, size: 56, belt: person.belt, ring: MMColor.bgApp)
                    .overlay {
                        if on { Circle().strokeBorder(MMColor.accent, lineWidth: 3).padding(-4) }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if on {
                            MMIcon("check", size: 13, weight: .bold, color: .white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(MMColor.accent))
                                .background(Circle().fill(MMColor.bgApp).padding(-2.5))
                                .offset(x: 4, y: 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(person.firstName).mmFont(.body, 12, on ? .semibold : .medium, lineHeight: 1.2)
                    .foregroundStyle(on ? MMColor.textPrimary : MMColor.textSecondary)
                    .lineLimit(1)
                Text(has ? (answer == "accepted" ? "Has it" : "Invited") : " ")
                    .mmFont(.body, 11, .medium, lineHeight: 1.2)
                    .foregroundStyle(MMColor.textTertiary)
            }
            .frame(width: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMPressStyle(scale: 0.95, bounce: true))
        .disabled(has)
        .opacity(has ? 0.55 : 1)
        .accessibilityLabel(has ? "\(person.name), already shared" : person.name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - A shared goal

/// A goal someone shared with you, read-only. Pending: Decline or Add to my goals.
/// Accepted: it lives in Goals › Shared until you remove it.
struct SharedGoalScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String
    @State private var confirmRemove = false
    @State private var working = false

    var body: some View {
        screen
            // Opening it shows the owner's latest saved version.
            .task(id: id) { await mm.runtime?.refreshSharedGoalsIfChanged() }
    }

    @ViewBuilder private var screen: some View {
        if let shared = mm.sharedGoal(id) {
            detail(shared)
        } else {
            MMScreen {
                MMHeader(title: "Shared goal", leading: {
                    MMIconButton("chevron-left", label: "Back") { mm.back() }
                })
            } content: {
                Text("This goal isn't shared with you anymore.")
                    .mmFont(.body, 15, lineHeight: 1.45)
                    .foregroundStyle(MMColor.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
            }
        }
    }

    private func detail(_ shared: SharedGoal) -> some View {
        let owner = mm.person(shared.owner)
        let pending = shared.status == .pending
        return MMScreen {
            MMHeader(title: "Shared goal", leading: {
                MMIconButton(pending ? "x" : "chevron-left", variant: pending ? .filled : .ghost, label: pending ? "Close" : "Back") { mm.back() }
            }, trailing: {
                if pending {
                    Color.clear.frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                } else {
                    Menu {
                        Button(role: .destructive) { confirmRemove = true } label: { Label("Remove from Shared", image: "trash-2") }
                    } label: {
                        MMIcon("ellipsis", size: 22, color: MMColor.ink900)
                            .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Shared goal options")
                }
            })
        } content: {
            VStack(alignment: .leading, spacing: MMLayout.sectionGap) {
                sender(owner, shared: shared)
                VStack(alignment: .leading, spacing: 6) {
                    Text(shared.title)
                        .mmFont(.display, 28, tracking: -0.03, lineHeight: 1.05)
                        .foregroundStyle(MMColor.ink900)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(owner.firstName)'s notes · read-only")
                        .mmFont(.body, 13, .medium).foregroundStyle(MMColor.textTertiary)
                }
                if !shared.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details").mmFont(.display, 16, lineHeight: 1.25).foregroundStyle(MMColor.textPrimary)
                        Text(shared.notes)
                            .mmFont(.body, 15, lineHeight: 1.45)
                            .foregroundStyle(MMColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mmCardSurface(radius: 22)
                }
                if !shared.parts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Broken down").mmFont(.display, 18, tracking: -0.02, lineHeight: 1.2).foregroundStyle(MMColor.ink900)
                            Spacer()
                            MMMeta(shared.parts.count == 1 ? "1 part" : "\(shared.parts.count) parts")
                        }
                        ForEach(shared.parts) { SharedGoalPartCard(part: $0) }
                    }
                }
                if !shared.photos.isEmpty || !shared.links.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("References").mmFont(.display, 18, tracking: -0.02, lineHeight: 1.2).foregroundStyle(MMColor.ink900)
                        if !shared.photos.isEmpty { SharedPhotoStrip(photos: shared.photos, size: 96) }
                        if !shared.links.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(Array(shared.links.enumerated()), id: \.element) { i, link in
                                    SharedLinkRow(link: link, divider: i < shared.links.count - 1)
                                }
                            }
                            .padding(.horizontal, 14)
                            .mmCardSurface(radius: 22)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if pending {
                VStack(spacing: 10) {
                    Text("Lands in Goals under Shared. \(owner.firstName)'s edits come through.")
                        .mmFont(.body, 13, lineHeight: 1.4)
                        .foregroundStyle(MMColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    HStack(spacing: 10) {
                        MMButton("Decline", variant: .secondary, size: .lg, fullWidth: true) {
                            Task {
                                working = true
                                if await mm.respondToSharedGoal(shared.id, accept: false) { mm.back() }
                                working = false
                            }
                        }
                        .frame(maxWidth: 140)
                        MMButton("Add to my goals", size: .lg, fullWidth: true) {
                            Task {
                                working = true
                                if await mm.respondToSharedGoal(shared.id, accept: true) {
                                    mm.goalsSection = .shared
                                    mm.setTab(.goals)
                                }
                                working = false
                            }
                        }
                    }
                    .disabled(working)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(MMColor.bgApp.ignoresSafeArea(edges: .bottom))
            }
        }
        .confirmationDialog("Remove \(shared.title)?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove from Shared", role: .destructive) {
                Task {
                    if await mm.respondToSharedGoal(shared.id, accept: false) { mm.back() }
                }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("It leaves your Goals. \(owner.firstName) can share it with you again.")
        }
    }

    /// Who shared it, front and center, on their friend hue.
    private func sender(_ owner: Person, shared: SharedGoal) -> some View {
        let ago = shared.sharedAt.map { RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date()) }
        let meta = ["\(owner.belt.title) belt", owner.gym, ago].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return HStack(spacing: 14) {
            MMPairAvatars(a: owner.avatar, b: mm.me.avatar, size: 44, hue: owner.hue, ring: owner.hue.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(owner.name) shared a goal with you")
                    .mmFont(.display, 16, lineHeight: 1.25)
                    .foregroundStyle(MMColor.ink900)
                    .fixedSize(horizontal: false, vertical: true)
                Text(meta).mmFont(.body, 13, lineHeight: 1.4).foregroundStyle(owner.hue.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous).fill(owner.hue.tint))
        .accessibilityElement(children: .combine)
    }
}

/// One part of a shared goal: name, notes, the video and photos. Nothing to edit.
private struct SharedGoalPartCard: View {
    let part: GoalPart

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(part.title.isEmpty ? "Unnamed part" : part.title)
                .mmFont(.display, 16, lineHeight: 1.25)
                .foregroundStyle(MMColor.textPrimary)
            if !part.notes.isEmpty {
                Text(part.notes)
                    .mmFont(.body, 14, lineHeight: 1.45)
                    .foregroundStyle(MMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            if !part.link.isEmpty { SharedVideoRow(link: part.link) }
            if !part.photos.isEmpty { SharedPhotoStrip(photos: part.photos, size: 72) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mmCardSurface(radius: 22)
    }
}

/// The part's video: opens in the browser or the YouTube app, at its start time.
private struct SharedVideoRow: View {
    let link: String

    var body: some View {
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
        .padding(8)
        .background(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous).fill(MMColor.surfaceBase))
        if let url = URL(string: link) {
            Link(destination: url) { content }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the video")
        } else {
            content
        }
    }
}

/// Photos in a row; tap one to see it full screen.
private struct SharedPhotoStrip: View {
    let photos: [String]
    let size: CGFloat
    @State private var viewing: SharedPhotoTarget?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.offset) { i, photo in
                    Button { viewing = SharedPhotoTarget(photo: photo) } label: {
                        MMPhotoTile(photo: photo, height: size, radius: size > 80 ? 18 : MMRadius.sm)
                            .frame(width: size)
                    }
                    .buttonStyle(MMPressStyle(scale: 0.96))
                    .accessibilityLabel("Photo \(i + 1) of \(photos.count)")
                    .accessibilityHint("Opens it full screen")
                }
            }
        }
        .fullScreenCover(item: $viewing) { target in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                MMPhoto(source: target.photo)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                MMIconButton("x", variant: .overlay, label: "Close") { viewing = nil }
                    .padding(16)
            }
        }
    }
}

private struct SharedPhotoTarget: Identifiable {
    let id = UUID()
    let photo: String
}

private struct SharedLinkRow: View {
    let link: String
    let divider: Bool

    var body: some View {
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
}
