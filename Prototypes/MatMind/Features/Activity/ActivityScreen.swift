import SwiftUI

/// Tab 1: a feed of completed sessions only (the completion flow is the composer).
struct ActivityScreen: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        MMScreen(tabPadding: true) {
            HStack {
                MMWordmark(size: 32)
                    .onLongPressGesture { if !mm.isLive { mm.showDemoPanel = true } }
                    .accessibilityHint(mm.isLive ? "" : "Long press for prototype tools")
                Spacer()
                MMIconButton("bell", badge: mm.unreadCount > 0 ? .count(mm.unreadCount) : nil, label: "Notifications") {
                    mm.go(.notifications)
                }
                MMIconButton("qr-code", variant: .filled, label: "My code") { mm.go(.qr()) }
            }
            .padding(.leading, 20)
            .padding(.trailing, 10)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(minHeight: MMLayout.headerHeight)
        } content: {
            ForEach(mm.readyToShare) { session in
                ReadyToShare(session: session)
                    .padding(.vertical, 12)
            }
            if mm.posts.isEmpty {
                EmptyActivity()
            } else {
                StreakNudges()
                ForEach(mm.posts) { post in
                    PostCard(post: post, highlight: post.id == mm.highlight)
                }
                if mm.isLive {
                    MMButton("Load older memories", variant: .ghost) {
                        Task { _ = await mm.runtime?.perform("load_more_feed", [:]) }
                    }.padding(.horizontal, 16)
                }
                Text("That's everything from your crew this week.\nGo make a new memory.")
                    .mmFont(.body, 13, .medium, lineHeight: 1.45)
                    .foregroundStyle(MMColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
        }
    }
}

/// Ink prompt card: "How was … ?" → Complete & share.
private struct ReadyToShare: View {
    @Environment(AppModel.self) private var mm
    let session: Session

    /// Solo sessions share with the crew; never "the 1 of you".
    private var shareLine: String {
        switch session.people.count {
        case ...1: "Add a photo and share it with your crew."
        case 2: "Add a photo and share it with the two of you."
        case let n: "Add a photo and share it with the \(n) of you."
        }
    }

    var body: some View {
        let shortTitle = session.title.lowercased().replacingOccurrences(of: "no-gi ", with: "")
        HStack(spacing: 14) {
            MMIcon("camera", size: 28, color: MMColor.ink500)
                .frame(width: 64, height: 64)
                .background(MMColor.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(.white).padding(-3))
                .rotationEffect(.degrees(-4))
            VStack(alignment: .leading, spacing: 0) {
                Text("How was \(shortTitle)?").mmFont(.display, 17, lineHeight: 1.2).foregroundStyle(MMColor.paper)
                Text(shareLine)
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

/// No completed sessions yet. A plan stays a plan until the organizer publishes it.
private struct EmptyActivity: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        if !mm.readyToShare.isEmpty {
            // The "How was …?" card above holds Complete & share, so no second primary here.
            MMEmptyState(artwork: .memory, title: "Proof you showed up.",
                         message: "Share a post-roll photo\nand your crew sees it here.")
        } else if let session = mm.plannedSessions.first(where: { $0.status(of: "me") == .going }) ?? mm.plannedSessions.first {
            MMEmptyState(artwork: .memory, title: "Your first photo\nis on its way.",
                         message: "Train together, then share the post-roll photo.",
                         actionTitle: session.status(of: "me") == .invited ? "View invitation" : "View your plan",
                         actionIcon: "calendar") {
                mm.go(.session(id: session.id))
            }
        } else {
            MMEmptyState(artwork: .memory, title: "Good memories\nstart on the mat.",
                         message: "Plan a session with your people.\nShare the photo after the rolls.",
                         actionTitle: "Plan a training session", actionIcon: "plus",
                         secondaryTitle: mm.friends.isEmpty ? "Add your mat people" : "Already trained? Log it",
                         secondaryIcon: mm.friends.isEmpty ? "qr-code" : "history",
                         secondaryAction: { mm.go(mm.friends.isEmpty ? .qr() : .create(past: true)) }) {
                mm.go(.create())
            }
        }
    }
}

/// Tinted cards for live streaks that still need this week's session.
private struct StreakNudges: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        let list = mm.friends.filter { $0.thisWeek == .pending && $0.streak > 0 }
        if !list.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(list) { f in
                        let p = mm.person(f.id)
                        Button { mm.go(.friend(id: f.id)) } label: {
                            HStack(spacing: 12) {
                                MMPairAvatars(a: mm.me.avatar, b: p.avatar, size: 38, hue: p.hue, ring: p.hue.tint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(f.streak) weeks with \(p.firstName)")
                                        .mmFont(.display, 16, lineHeight: 1.15)
                                        .foregroundStyle(p.hue.ink)
                                    Text("Roll together by Sunday to make it \(f.streak + 1)")
                                        .mmFont(.body, 13, .medium, lineHeight: 1.3)
                                        .foregroundStyle(MMColor.ink700)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                MMIcon("flame", size: 22, filled: true, color: MMColor.flame500)
                            }
                            .multilineTextAlignment(.leading)
                            .padding(14)
                            .frame(width: 262)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(p.hue.tint))
                        }
                        .buttonStyle(MMPressStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 16)
            }
        }
    }
}

struct PostCard: View {
    @Environment(AppModel.self) private var mm
    let post: Post
    var highlight = false

    @State private var showMenu = false
    @State private var burst = false
    @State private var commentsExpanded = false
    @State private var commentText = ""

    var body: some View {
        let org = mm.person(post.organizer)
        let liked = post.likes.contains("me")
        let others = post.participants.filter { $0 != post.organizer }.map { $0 == "me" ? "You" : mm.person($0).name }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    if post.organizer != "me" { mm.go(.friend(id: post.organizer)) }
                } label: {
                    MMAvatar(name: org.name, photo: org.photo, size: 42, belt: org.belt, ring: MMColor.white)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    mmRich([
                        .body(post.organizer == "me" ? "You" : org.name, 15, .bold, color: MMColor.ink900),
                        .body(others.isEmpty ? " trained" : " trained with \(mmNames(others))", 14, color: MMColor.textSecondary),
                    ])
                    .lineSpacing(1)
                    Text("\(post.date)\(post.timeText.map { " · \($0)" } ?? "") · \(post.ago)").mmFont(.body, 13, .medium, lineHeight: 1).foregroundStyle(MMColor.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MMIconButton("ellipsis", size: 36, label: "Post options") { showMenu = true }
                    .accessibilityIdentifier("post-options-\(post.id)")
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)
            .padding(.bottom, 12)

            MMPhotoTile(photo: post.photo, height: 300, radius: 20) {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { doubleTap() }
                        .onTapGesture { mm.go(.post(id: post.id)) }
                    MMTapeLabel(text: post.gym)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, 12)
                        .padding(.bottom, 14)
                        .allowsHitTesting(false)
                    MMAvatarStack(people: post.participants.map { mm.person($0).avatar }, size: 30, ring: .white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(12)
                        .allowsHitTesting(false)
                    MMIcon("heart", size: 88, filled: true, color: .white)
                        .shadow(color: .black.opacity(0.2), radius: 8)
                        .scaleEffect(burst ? 1 : 0.2)
                        .opacity(burst ? 1 : 0)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel("Photo from \(post.title). Double tap to like.")

            VStack(alignment: .leading, spacing: 6) {
                Text(post.title).mmFont(.display, 21, tracking: -0.025, lineHeight: 1.15).foregroundStyle(MMColor.ink900)
                if !TrainingFocusTree.optionalOutline(post.focusItems).isEmpty {
                    TrainingFocusNames(items: post.focusItems)
                        .padding(.top, MMSpace.s1)
                }
                if !post.caption.isEmpty {
                    MentionText(text: post.caption).mmFont(.body, 15, lineHeight: 1.45).foregroundStyle(MMColor.ink800)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 14)

            HStack(spacing: 2) {
                MMIconButton("heart", size: 40, active: liked, filledWhenActive: true, label: liked ? "Unlike" : "Like") {
                    withAnimation(MMMotion.bounce()) { mm.like(post.id) }
                }
                .scaleEffect(liked ? 1 : 0.98)
                .animation(MMMotion.bounce(), value: liked)
                Text("\(post.likes.count + post.extraLikes)").mmFont(.body, 14, .bold, lineHeight: 1).foregroundStyle(MMColor.textPrimary)
                    .contentTransition(.numericText())
                    .padding(.trailing, 10)
                MMIconButton("message-circle", size: 44, active: commentsExpanded, label: commentsExpanded ? "Hide comments" : "Show comments") {
                    toggleComments()
                }
                .accessibilityValue(commentsExpanded ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("comments-toggle-\(post.id)")
                Text("\(post.comments.count)").mmFont(.body, 14, .bold, lineHeight: 1).foregroundStyle(MMColor.textPrimary)
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    MMIcon("users", size: 15, color: MMColor.textTertiary)
                    Text("On \(post.participants.count) profiles").mmFont(.body, 12, .semibold, lineHeight: 1).foregroundStyle(MMColor.textTertiary)
                }
                .padding(.trailing, 6)
            }
            .padding(.top, 8)
            .padding(.leading, -4)

            if commentsExpanded {
                inlineComments
                    .padding(.horizontal, 4)
                    .padding(.top, 12)
                    .accessibilityIdentifier("inline-comments-\(post.id)")
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if let first = post.comments.first {
                Button { toggleComments() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        mmRich([.body(mm.person(first.who).firstName, 14, .bold), .body(" \(first.text)", 14)])
                        if post.comments.count > 1 {
                            Text("View all \(post.comments.count) comments").mmFont(.body, 13, .medium, lineHeight: 1).foregroundStyle(MMColor.textTertiary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Expand comments in the feed")
            }
        }
        .padding(12)
        .mmCardSurface(radius: 28)
        .overlay {
            RoundedRectangle(cornerRadius: 29.5, style: .continuous)
                .stroke(MMColor.coral300, lineWidth: 3)
                .padding(-1.5)
                .opacity(highlight ? 1 : 0)
        }
        .scaleEffect(highlight ? 1.01 : 1)
        .animation(MMMotion.bounce(MMMotion.slow), value: highlight)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .modifier(PostOptionsModifier(postID: post.id, isPresented: $showMenu))
    }

    private var inlineComments: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(post.comments) { comment in
                CommentRow(comment: comment, postID: post.id)
            }
            if post.comments.isEmpty {
                Text("No comments yet. Be the first.")
                    .mmFont(.body, 14)
                    .foregroundStyle(MMColor.textTertiary)
            }
            MentionSuggestions(text: $commentText, people: mm.mentionCandidates(for: post))
            HStack(spacing: 8) {
                MMAvatar(name: mm.me.name, photo: mm.me.photo, size: 34)
                MMTextField(placeholder: "Say something nice… @tag a partner", text: $commentText) {
                    sendComment()
                }
                MMIconButton("send", variant: .accent, label: "Send comment") {
                    sendComment()
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Button("Hide comments") { toggleComments() }
                .mmFont(.body, 13, .medium, lineHeight: 1)
                .foregroundStyle(MMColor.textTertiary)
                .frame(minHeight: MMLayout.tapTarget)
                .buttonStyle(.plain)
        }
    }

    private func toggleComments() {
        withAnimation(MMMotion.easeOut(MMMotion.base)) {
            commentsExpanded.toggle()
        }
    }

    private func sendComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let runtime = mm.runtime {
            Task { if await runtime.perform("add_comment", ["post_id": post.id, "body": trimmed]) { commentText = "" } }
        } else {
            withAnimation(MMMotion.easeOut(MMMotion.base)) { mm.comment(post.id, trimmed) }
            commentText = ""
        }
    }

    private func doubleTap() {
        if !post.likes.contains("me") { mm.like(post.id) }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { burst = true }
        Task {
            try? await Task.sleep(for: .seconds(0.55))
            withAnimation(.easeOut(duration: 0.25)) { burst = false }
        }
    }
}

// MARK: - Post detail

struct PostDetailScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String
    var openMenu = false
    var focusComment = false

    @State private var text = ""
    @State private var showMenu = false

    var body: some View {
        if let post = mm.post(id) {
            content(post)
                .onAppear {
                    if openMenu { showMenu = true }
                }
        } else {
            MMScreen {
                MMHeader(title: "Memory", leading: { MMIconButton("chevron-left", label: "Back") { mm.back() } })
            } content: {
                Text("Loading memory…").mmFont(.body, 15).padding(24)
            }
            .task { if mm.isLive { _ = await mm.runtime?.perform("hydrate_post", ["post_id": id]) } }
        }
    }

    private func content(_ post: Post) -> some View {
        let isOrganizer = post.organizer == "me"
        let organizer = mm.person(post.organizer)
        return MMScreen {
            MMHeader(title: post.title, leading: {
                MMIconButton("chevron-left", label: "Back") { mm.back() }
            }, trailing: {
                // Always available: anyone who can see a post can report it.
                MMIconButton("ellipsis", label: "Options") { showMenu = true }
            })
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                MMPhotoTile(photo: post.photo, height: 340, radius: 24) {
                    MMTapeLabel(text: post.gym)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, 12)
                        .padding(.bottom, 14)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(post.date)\(post.timeText.map { " · \($0)" } ?? "") · organized by \(isOrganizer ? "you" : organizer.name)")
                        .mmFont(.body, 13, .semibold, lineHeight: 1.4).foregroundStyle(MMColor.textTertiary)
                    MentionText(text: post.caption).mmFont(.body, 16, lineHeight: 1.5).foregroundStyle(MMColor.ink800)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                    if !TrainingFocusTree.optionalOutline(post.focusItems).isEmpty {
                        Text("What we worked on").mmFont(.display, 16).padding(.top, MMSpace.s8)
                        TrainingFocusNames(items: post.focusItems, wraps: true).padding(.top, MMSpace.s5)
                    }
                    Text("On the mat").mmFont(.display, 16).padding(.top, 18)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(post.participants, id: \.self) { pid in
                                let p = mm.person(pid)
                                VStack(spacing: 6) {
                                    MMAvatar(name: p.name, photo: p.photo, size: 52, belt: p.belt)
                                    Text(pid == "me" ? "You" : p.firstName).mmFont(.body, 12, .semibold, lineHeight: 1).foregroundStyle(MMColor.textPrimary)
                                    if pid == post.organizer {
                                        MMBadge("Host", variant: .soft, height: 18, fontSize: 10, paddingX: 6)
                                    }
                                }
                                .frame(width: 60)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }
                    HStack(spacing: 4) {
                        MMIconButton("heart", active: post.likes.contains("me"), filledWhenActive: true, label: "Like") { mm.like(post.id) }
                        if post.likes.isEmpty && post.extraLikes == 0 {
                            Text("Be the first to like this").mmFont(.body, 14).foregroundStyle(MMColor.textSecondary)
                        } else {
                        mmRich([
                            .body("Liked by ", 14, .semibold, color: MMColor.textSecondary),
                            .body(mmNames(post.likes.map { $0 == "me" ? "You" : mm.person($0).name }), 14, .bold, color: MMColor.ink900),
                            .body(post.extraLikes > 0 ? " and \(post.extraLikes) others" : "", 14, .semibold, color: MMColor.textSecondary),
                        ])
                        }
                    }
                    .padding(.top, 14)
                    .padding(.leading, -6)
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(post.comments) { c in
                            CommentRow(comment: c, postID: post.id)
                        }
                        if mm.isLive && !post.comments.isEmpty {
                            MMButton("Load older comments", variant: .ghost, size: .sm) {
                                Task { _ = await mm.runtime?.perform("load_more_comments", ["post_id": post.id]) }
                            }
                        }
                        if post.comments.isEmpty {
                            Text("No comments yet. Be the first.").mmFont(.body, 14).foregroundStyle(MMColor.textTertiary)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .padding(.horizontal, 6)
                .padding(.top, 16)
            }
            .padding(.horizontal, 12)
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                MentionSuggestions(text: $text, people: mm.mentionCandidates(for: post))
                HStack(spacing: 8) {
                    MMAvatar(name: mm.me.name, photo: mm.me.photo, size: 36)
                    MMTextField(placeholder: "Say something nice… @tag a partner", text: $text, autoFocus: focusComment) { send(post) }
                    MMIconButton("send", variant: .accent, label: "Send") { send(post) }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .modifier(PostOptionsModifier(postID: post.id, isPresented: $showMenu))
    }

    private func send(_ post: Post) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let runtime = mm.runtime {
            Task { if await runtime.perform("add_comment", ["post_id": post.id, "body": trimmed]) { text = "" } }
        } else {
            withAnimation(MMMotion.easeOut(MMMotion.slow)) { mm.comment(post.id, trimmed) }
            text = ""
        }
    }
}

/// Shared by feed cards and post details so options never require a navigation push.
private struct PostOptionsModifier: ViewModifier {
    @Environment(AppModel.self) private var mm
    let postID: String
    @Binding var isPresented: Bool

    private enum Panel { case options, edit, delete, report }
    @State private var panel: Panel = .options
    @State private var caption = ""
    @State private var saving = false

    func body(content: Content) -> some View {
        content.mmSheet(isPresented: $isPresented,
                        title: title,
                        description: description) {
            if let post = mm.post(postID) {
                VStack(spacing: 8) {
                    if panel == .report {
                        ReportReasonList { reason in
                            isPresented = false
                            Task { await mm.report(postID: postID, reason: reason) }
                        }
                    } else if post.organizer == "me" {
                        switch panel {
                        case .options:
                            MMButton("Edit caption", variant: .secondary, iconLeft: "pencil", fullWidth: true) {
                                caption = post.caption
                                panel = .edit
                            }
                            MMButton("Delete post", variant: .danger, iconLeft: "trash-2", fullWidth: true) {
                                panel = .delete
                            }
                        case .edit:
                            MMTextField(placeholder: "Caption · @tag a partner", text: $caption, multiline: true, rows: 3)
                                .disabled(saving)
                            MentionSuggestions(text: $caption, people: mm.mentionCandidates(for: post))
                                .disabled(saving)
                            MMButton("Save", fullWidth: true) { saveCaption() }
                                .disabled(saving)
                            MMButton("Cancel", variant: .ghost, fullWidth: true) { isPresented = false }
                                .disabled(saving)
                        case .delete:
                            MMButton("Keep it", variant: .secondary, fullWidth: true) { isPresented = false }
                            MMButton("Delete", variant: .danger, fullWidth: true) {
                                isPresented = false
                                mm.deletePost(postID)
                            }
                        case .report:
                            EmptyView()
                        }
                    } else if post.participants.contains("me") {
                        MMButton("Remove me from this post", variant: .danger, iconLeft: "user-minus", fullWidth: true) {
                            isPresented = false
                            mm.removeMe(from: postID)
                        }
                        reportButton
                    } else {
                        Text("You weren't in this session.").mmFont(.body, 14).foregroundStyle(MMColor.textTertiary)
                        reportButton
                    }
                }
            }
        }
        .onChange(of: isPresented) { _, presented in
            if presented { panel = .options }
        }
    }

    private var reportButton: some View {
        MMButton("Report post", variant: .ghost, iconLeft: "triangle-alert", fullWidth: true) { panel = .report }
    }

    private var title: String {
        switch panel {
        case .options: mm.post(postID)?.organizer == "me" ? "Your post" : "Post options"
        case .edit: "Edit caption"
        case .delete: "Delete this post?"
        case .report: "Report this post?"
        }
    }

    private var description: String? {
        guard let post = mm.post(postID) else { return nil }
        switch panel {
        case .options:
            return post.organizer == "me"
                ? "Only you, the organizer, can edit or delete this post."
                : "\(mm.person(post.organizer).name) organized this session."
        case .edit:
            return nil
        case .delete:
            return "It disappears from all \(post.participants.count) profiles and your friends' feeds."
        case .report:
            return ReportReasonList.note
        }
    }

    private func saveCaption() {
        guard !saving else { return }
        if let runtime = mm.runtime {
            saving = true
            Task {
                let saved = await runtime.perform("edit_post", ["post_id": postID, "caption": caption])
                saving = false
                if saved { isPresented = false }
            }
        } else {
            mm.editCaption(postID, caption)
            isPresented = false
        }
    }
}

/// Reasons for a report, one tap each. Shared by post options and comments.
private struct ReportReasonList: View {
    static let note = "Only the Mat Monkey team sees reports. They won't know it was you."
    let pick: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(AppModel.reportReasons, id: \.self) { reason in
                MMButton(reason, variant: .secondary, fullWidth: true) { pick(reason) }
            }
        }
    }
}

private struct CommentRow: View {
    @Environment(AppModel.self) private var mm
    let comment: Comment
    var postID: String?
    @State private var shown = false
    @State private var reporting = false
    @State private var confirmingDelete = false

    /// Live comments need their cloud ID before they can be reported or deleted.
    private var actionable: Bool { postID != nil && (!mm.isLive || comment.cloudID != nil) }

    /// Someone else's comment that can be reported.
    private var reportable: Bool { actionable && comment.who != "me" }

    /// Your own comment, or any comment on a post you organized.
    private var deletable: Bool {
        guard actionable, let postID else { return false }
        return mm.canDelete(comment, on: postID)
    }

    var body: some View {
        let p = mm.person(comment.who)
        HStack(alignment: .top, spacing: 12) {
            MMAvatar(name: p.name, photo: p.photo, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(comment.who == "me" ? "You" : p.name).mmFont(.body, 13, .bold, lineHeight: 1.3).foregroundStyle(MMColor.textPrimary)
                MentionText(text: comment.text).mmFont(.body, 15, lineHeight: 1.4).foregroundStyle(MMColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background {
                let shape = UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 18, bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous)
                shape.fill(MMColor.white).overlay(shape.stroke(MMColor.borderSubtle, lineWidth: 1))
            }
            Spacer(minLength: 0)
            if reportable || deletable {
                Menu {
                    if deletable {
                        Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete comment", image: "trash-2") }
                    }
                    if reportable {
                        Button(role: .destructive) { reporting = true } label: { Label("Report comment", image: "triangle-alert") }
                    }
                } label: {
                    MMIcon("ellipsis", size: 18, color: MMColor.ink500)
                        .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Comment options")
                .padding(.trailing, -10)
            }
        }
        .opacity(comment.fresh && !shown ? 0 : 1)
        .offset(y: comment.fresh && !shown ? 10 : 0)
        .onAppear {
            withAnimation(MMMotion.easeOut(0.35)) { shown = true }
        }
        .contextMenu {
            if deletable { Button("Delete comment", role: .destructive) { confirmingDelete = true } }
            if reportable { Button("Report comment", role: .destructive) { reporting = true } }
        }
        .accessibilityActions {
            if deletable { Button("Delete comment") { confirmingDelete = true } }
            if reportable { Button("Report comment") { reporting = true } }
        }
        .mmSheet(isPresented: $confirmingDelete, title: "Delete this comment?",
                 description: comment.who == "me" ? "It's gone for everyone on this post." : "It's your post, so you can clear it. \(mm.person(comment.who).name) won't be told.") {
            VStack(spacing: 8) {
                MMButton("Keep it", variant: .secondary, fullWidth: true) { confirmingDelete = false }
                MMButton("Delete", variant: .danger, iconLeft: "trash-2", fullWidth: true) {
                    confirmingDelete = false
                    guard let postID else { return }
                    withAnimation(MMMotion.easeOut(MMMotion.base)) { mm.deleteComment(comment, on: postID) }
                }
            }
        }
        .mmSheet(isPresented: $reporting, title: "Report this comment?", description: ReportReasonList.note) {
            ReportReasonList { reason in
                reporting = false
                guard let postID else { return }
                Task { await mm.report(postID: postID, commentID: comment.cloudID, reason: reason) }
            }
        }
    }
}

/// Inline suggestions keep the composer in place and use the existing partner
/// avatars, typography and tap-target tokens.
struct MentionSuggestions: View {
    @Binding var text: String
    var people: [Person]

    var body: some View {
        if let query = UsernameMention.query(in: text) {
            let matches = people.filter {
                query.isEmpty || $0.username.lowercased().hasPrefix(query) || $0.name.lowercased().contains(query)
            }
            VStack(alignment: .leading, spacing: 4) {
                if matches.isEmpty {
                    Text("No matching partners. Check their username.")
                        .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                }
                ForEach(Array(matches.prefix(5))) { person in
                    Button {
                        text = UsernameMention.inserting(person.username, in: text)
                    } label: {
                        HStack(spacing: 8) {
                            MMAvatar(name: person.name, photo: person.photo, size: 28)
                            Text(person.name).mmFont(.body, 13, .semibold).foregroundStyle(MMColor.textPrimary)
                            Text("@" + person.username).mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: MMLayout.tapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mention \(person.name), @\(person.username)")
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// Highlight known handles without interpreting arbitrary user text as Markdown.
struct MentionText: View {
    @Environment(AppModel.self) private var mm
    let text: String

    private var styled: AttributedString {
        var result = AttributedString(text)
        let people = Array(mm.people.values) + [mm.me]
        for match in UsernameMention.ranges(in: text) {
            guard let range = Range(match, in: text),
                  let person = people.first(where: { $0.username.lowercased() == text[range].dropFirst().lowercased() }),
                  let attributedRange = Range(range, in: result) else { continue }
            result[attributedRange].foregroundColor = MMColor.textAccent
            result[attributedRange].link = URL(string: "matmonkeys-mention://profile/" + person.id)
        }
        return result
    }

    var body: some View {
        Text(styled)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "matmonkeys-mention", let id = url.pathComponents.last else { return .systemAction }
                if id == "me" { mm.setTab(.profile) } else { mm.go(.friend(id: id)) }
                return .handled
            })
    }
}
