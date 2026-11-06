import SwiftUI

/// Tab 1: open upcoming plans and completed memories from your crew.
struct ActivityScreen: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            feed(at: context.date)
        }
    }

    private func feed(at now: Date) -> some View {
        let prompt = mm.quickTrainingLogEnabled
            ? mm.quickLogActivityPrompt(keeping: mm.activityQuickLogPromptID, now: now)
            : mm.activityPrompt(at: now)
        let plans = mm.activityPlans(at: now)
        return MMScreen(tabPadding: true) {
            MMHeader(title: "Activity", large: true, leading: {
                MMHeaderMark()
                    .onLongPressGesture { if !mm.isLive { mm.showDemoPanel = true } }
                    .accessibilityHint(mm.isLive ? "" : "Long press for prototype tools")
            }, trailing: {
                MMHeaderActions()
            })
        } content: {
            if mm.quickTrainingLogEnabled {
                TrainingWeekCard(anchor: now, isActivity: true)
                    .padding(.horizontal, MMSpace.s6)
                    .padding(.top, MMSpace.s2)
                    .padding(.bottom, MMSpace.s6)
            }
            if let session = prompt {
                ReadyToShare(session: session, now: now, keepsUpcomingStyle: mm.quickTrainingLogEnabled)
                    .padding(.top, mm.quickTrainingLogEnabled ? MMSpace.s0 : MMSpace.s5)
                    .padding(.bottom, MMSpace.s5)
            }
            if mm.feedPosts.isEmpty && plans.isEmpty {
                EmptyActivity(prompt: prompt, now: now)
            } else {
                if !plans.isEmpty {
                    MMEyebrow("Coming up", topPadding: MMSpace.s4)
                    VStack(spacing: MMSpace.s6) {
                        ForEach(plans) { session in
                            ActivityPlanCard(session: session)
                        }
                    }
                    .padding(.horizontal, MMSpace.s6)
                    .padding(.bottom, MMSpace.s6)
                }
                ForEach(mm.feedPosts) { post in
                    PostCard(post: post, highlight: post.id == mm.highlight)
                }
                if mm.isLive && !mm.feedPosts.isEmpty {
                    MMButton("Load older memories", variant: .ghost) {
                        Task { _ = await mm.runtime?.perform("load_more_feed", [:]) }
                    }.padding(.horizontal, 16)
                }
                Text("You're all caught up with your crew.\nGo make a new memory.")
                    .mmFont(.body, 13, .medium, lineHeight: 1.45)
                    .foregroundStyle(MMColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
        }
        .onChange(of: prompt?.id, initial: true) { _, id in
            if mm.quickTrainingLogEnabled { mm.activityQuickLogPromptID = id }
        }
    }
}

/// An invitation to train, using the same ticket as Training and session details.
private struct ActivityPlanCard: View {
    @Environment(AppModel.self) private var mm
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s4) {
            HStack(spacing: MMSpace.s3) {
                MMIcon(session.privacy == .link ? "link" : "lock", size: 14, color: MMColor.textTertiary)
                Text(session.privacy == .link ? "Anyone with the link" : "Friends only")
                    .mmFont(.body, 13, .medium).foregroundStyle(MMColor.textSecondary)
                Spacer()
                if session.status(of: "me") == .going {
                    MMBadge(session.organizer == "me" ? "You host" : "Going", variant: .success)
                }
            }
            SessionTicket(session: session) { mm.go(.session(id: session.id)) }
            if session.organizer != "me" && session.status(of: "me") != .going {
                MMButton("Join session", size: .sm, iconLeft: "check", fullWidth: true) {
                    mm.rsvp(session.id, .going)
                }
                .disabled(mm.busy)
            }
        }
    }
}

/// The nearest session: share a past roll, or open an upcoming plan.
private struct ReadyToShare: View {
    @Environment(AppModel.self) private var mm
    let session: Session
    let now: Date
    var keepsUpcomingStyle = false
    @State private var confirmingSkip = false

    private var hasStarted: Bool { mm.startDate(of: session) <= now }
    private var showsPastPrompt: Bool { hasStarted && !keepsUpcomingStyle }
    private var canShare: Bool { showsPastPrompt && session.organizer == "me" }

    /// Solo sessions share with the crew; never "the 1 of you".
    private var shareLine: String {
        if !showsPastPrompt { return "\(session.day) \(session.month) \(session.date) · \(session.time) · \(session.gym)" }
        if !canShare { return "Your crew's post-roll memory starts here." }
        switch session.people.count {
        case ...1: return "Add a photo and share it with your crew."
        case 2: return "Add a photo and share it with the two of you."
        case let n: return "Add a photo and share it with the \(n) of you."
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            MMIcon(showsPastPrompt ? "camera" : "calendar", size: 28, color: MMColor.ink500)
                .frame(width: 64, height: 64)
                .background(keepsUpcomingStyle ? MMColor.white : MMColor.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(.white).padding(-3))
                .rotationEffect(.degrees(-4))
            VStack(alignment: .leading, spacing: 0) {
                Text(showsPastPrompt ? "How was \(session.title)?" : "Coming up: \(session.title)")
                    .mmFont(.display, 17, lineHeight: 1.2)
                    .foregroundStyle(keepsUpcomingStyle ? MMColor.ink900 : MMColor.paper)
                Text(shareLine)
                    .mmFont(.body, 13, .medium, lineHeight: 1.35)
                    .foregroundStyle(keepsUpcomingStyle ? MMColor.ink700 : MMColor.ink200)
                    .padding(.top, 4)
                HStack(spacing: 14) {
                    MMButton(canShare ? "Complete & share" : "View session", variant: keepsUpcomingStyle ? .secondary : .primary,
                             size: .sm, iconLeft: canShare ? "camera" : "calendar") {
                        mm.go(canShare ? .complete(id: session.id) : .session(id: session.id))
                    }
                    if canShare {
                        Button("Didn't train") { confirmingSkip = true }
                            .mmFont(.body, 13, .semibold, lineHeight: 1.2)
                            .foregroundStyle(MMColor.ink200)
                            .frame(minHeight: 36)
                    }
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(keepsUpcomingStyle ? MMColor.paper2 : MMColor.ink900))
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .confirmationDialog("Didn't train at \(session.title)?", isPresented: $confirmingSkip, titleVisibility: .visible) {
            Button("Delete session", role: .destructive) { mm.deleteSession(session.id) }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text(session.people.count > 1 ? "It comes off everyone's schedule and won't be shared." : "It comes off your schedule and won't be shared.")
        }
    }
}

/// No open Activity plans or completed memories yet.
private struct EmptyActivity: View {
    @Environment(AppModel.self) private var mm
    let prompt: Session?
    let now: Date

    var body: some View {
        if let prompt {
            // The session card above already holds the primary action.
            let hasStarted = mm.startDate(of: prompt) <= now
            MMEmptyState(artwork: .memory, title: hasStarted ? "Proof you showed up." : "Your first photo\nis on its way.",
                         message: hasStarted ? "Share a post-roll photo\nand your crew sees it here." : "Train together, then share the post-roll photo.")
        } else if let session = mm.plannedSessions.first(where: { $0.status(of: "me") == .going }) ?? mm.plannedSessions.first {
            MMEmptyState(artwork: .memory, title: "Your first photo\nis on its way.",
                         message: "Train together, then share the post-roll photo.",
                         actionTitle: session.status(of: "me") == .invited ? "View invitation" : "View your plan",
                         actionIcon: "calendar") {
                mm.go(.session(id: session.id))
            }
        } else {
            MMEmptyState(artwork: .memory, title: "Good memories\nstart on the mat.",
                         message: "Plan a training with your people.\nShare the photo after the rolls.",
                         actionTitle: "Plan a training session", actionIcon: "plus",
                         secondaryTitle: mm.friends.isEmpty ? "Add your mat people" : "Already trained? Log it",
                         secondaryIcon: mm.friends.isEmpty ? "qr-code" : "history",
                         secondaryAction: { mm.go(mm.friends.isEmpty ? .qr() : .create(past: true)) }) {
                mm.go(.create())
            }
        }
    }
}

struct PostCard: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let post: Post
    var highlight = false

    @State private var showMenu = false
    @State private var burst = false
    @State private var commentsExpanded = false
    @State private var commentPreviewVisible = true
    @State private var commentText = ""

    var body: some View {
        let org = mm.person(post.organizer)
        let liked = post.likes.contains("me")
        let others = post.participants.filter { $0 != post.organizer }.map { mm.person($0) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                PersonProfileButton(person: org) {
                    MMAvatar(name: org.name, photo: org.photo, size: 42, belt: org.belt, ring: MMColor.white)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    PersonText([
                        .person(org, 15, .bold, color: MMColor.ink900),
                        .body(others.isEmpty ? " trained" : " trained with ", 14, color: MMColor.textSecondary),
                    ] + PersonText.names(others, size: 14, color: MMColor.textSecondary))
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
                if !post.caption.isEmpty {
                    PostCaption(text: post.caption, postID: post.id)
                }
                if !TrainingFocusTree.optionalOutline(post.focusItems).isEmpty {
                    TrainingFocusNames(items: post.focusItems)
                        .padding(.top, MMSpace.s5)
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

            ZStack(alignment: .topLeading) {
                commentPreview
                    .opacity(commentPreviewVisible ? 1 : 0)
                    .animation(nil, value: commentPreviewVisible)
                    .allowsHitTesting(!commentsExpanded && commentPreviewVisible)
                    .accessibilityHidden(commentsExpanded || !commentPreviewVisible)

                // Keep rows at their natural height and reveal them from the top.
                // Animating the viewport avoids reflowing/fading two comment layouts.
                inlineComments
                    .padding(.horizontal, 4)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: commentsExpanded ? nil : 0, alignment: .top)
                    .clipped()
                    .allowsHitTesting(commentsExpanded)
                    .disabled(!commentsExpanded)
                    .accessibilityHidden(!commentsExpanded)
                    .accessibilityIdentifier("inline-comments-\(post.id)")
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

    @ViewBuilder
    private var commentPreview: some View {
        if let first = post.comments.first {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    PersonProfileButton(person: mm.person(first.who)) {
                        Text(first.who == "me" ? "You" : mm.person(first.who).firstName)
                            .mmFont(.body, 14, .bold).foregroundStyle(MMColor.textPrimary)
                            .mmMonkey(mm.person(first.who).monkey, size: 16)
                    }
                    Button { toggleComments() } label: {
                        Text(" \(first.text)").mmFont(.body, 14).foregroundStyle(MMColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: MMLayout.tapTarget, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Expand comments in the feed")
                }
                if post.comments.count > 1 {
                    Button { toggleComments() } label: {
                        Text("View all \(post.comments.count) comments").mmFont(.body, 13, .medium, lineHeight: 1).foregroundStyle(MMColor.textTertiary)
                            .frame(minHeight: MMLayout.tapTarget)
                    }
                    .buttonStyle(.plain)
                }
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .padding(.bottom, 4)
        }
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
            CommentComposer(post: post, text: $commentText, onSend: sendComment)
            Button("Hide comments") { toggleComments() }
                .mmFont(.body, 13, .medium, lineHeight: 1)
                .foregroundStyle(MMColor.textTertiary)
                .frame(minHeight: MMLayout.tapTarget)
                .buttonStyle(.plain)
        }
    }

    private func toggleComments() {
        commentPreviewVisible = false
        if commentsExpanded {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        withAnimation(reduceMotion ? nil : MMMotion.easeOut(MMMotion.base)) {
            commentsExpanded.toggle()
        } completion: {
            // Wait until the rows have retracted before restoring the compact preview.
            // Checking the current state also handles a second tap mid-animation.
            if !commentsExpanded { commentPreviewVisible = true }
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

/// Measure both layouts at the card's actual width, including mention styling.
/// Keeping the measurements independent of expansion keeps the toggle visible.
private struct PostCaption: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let text: String
    let postID: String
    private let previewLineLimit = 3
    @State private var expanded = false
    @State private var heights: [Int: CGFloat] = [:]

    private var isTruncated: Bool {
        guard let full = heights[0], let collapsed = heights[previewLineLimit] else { return false }
        return full > collapsed + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption(lineLimit: expanded ? nil : previewLineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        measuredCaption(lineLimit: previewLineLimit)
                        measuredCaption(lineLimit: nil)
                    }
                    .hidden()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }

            if isTruncated {
                Button {
                    withAnimation(reduceMotion ? nil : MMMotion.easeOut()) {
                        expanded.toggle()
                    }
                } label: {
                    Text(expanded ? "See less" : "See more")
                        .mmFont(.body, 13, .semibold)
                        .foregroundStyle(MMColor.textSecondary)
                        .frame(minWidth: MMLayout.tapTarget, minHeight: MMLayout.tapTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                .accessibilityIdentifier("caption-toggle-\(postID)")
            }
        }
        .onPreferenceChange(PostCaptionHeightKey.self) { heights = $0 }
        .onChange(of: text) { _, _ in expanded = false }
    }

    private func caption(lineLimit: Int?) -> some View {
        MentionText(text: text)
            .mmFont(.body, 15, lineHeight: 1.45)
            .foregroundStyle(MMColor.ink800)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func measuredCaption(lineLimit: Int?) -> some View {
        caption(lineLimit: lineLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: PostCaptionHeightKey.self,
                                           value: [lineLimit ?? 0: geometry.size.height])
                }
            }
    }
}

private struct PostCaptionHeightKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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
                    PersonText([
                        .body("\(post.date)\(post.timeText.map { " · \($0)" } ?? "") · organized by ", 13, .semibold, color: MMColor.textTertiary),
                        .body(isOrganizer ? "you" : organizer.name, 13, .semibold, color: MMColor.textTertiary,
                              link: PersonProfileLink.url(for: post.organizer)),
                    ])
                    .mmFont(.body, 13, .semibold, lineHeight: 1.4)
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
                                PersonProfileButton(person: p) {
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
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }
                    HStack(spacing: 4) {
                        MMIconButton("heart", active: post.likes.contains("me"), filledWhenActive: true, label: "Like") { mm.like(post.id) }
                        if post.likes.isEmpty && post.extraLikes == 0 {
                            Text("Be the first to like this").mmFont(.body, 14).foregroundStyle(MMColor.textSecondary)
                        } else {
                        PersonText([
                            .body("Liked by ", 14, .semibold, color: MMColor.textSecondary),
                        ] + PersonText.names(post.likes.map { mm.person($0) }, size: 14, weight: .bold, color: MMColor.ink900) + [
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
            CommentComposer(post: post, text: $text, autoFocus: focusComment) { send(post) }
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

/// Compact shared composer for feed comments and post detail.
private struct CommentComposer: View {
    @Environment(AppModel.self) private var mm
    let post: Post
    @Binding var text: String
    var autoFocus = false
    var onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s4) {
            MentionSuggestions(text: $text, people: mm.mentionCandidates(for: post))
            HStack(spacing: MMSpace.s4) {
                MMAvatar(name: mm.me.name, photo: mm.me.photo, size: 34)
                MMTextField(placeholder: "Say something nice…", text: $text,
                            autoFocus: autoFocus, onSubmit: onSend)
                    .submitLabel(.send)
                    .accessibilityLabel("Add a comment")
                    .accessibilityHint("Use @ to tag a partner.")
                MMIconButton("send", variant: .accent, label: "Send comment", action: onSend)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func authorLine(for person: Person) -> [MMRun] {
        var name = MMRun.person(person, 13, .bold)
        name.monkeySize = 16
        var runs = [name]
        if let createdAt = comment.createdAt {
            let time = createdAt.formatted(.relative(presentation: .numeric, unitsStyle: .narrow))
            runs.append(.body(" · \(time)", 12, color: MMColor.textTertiary))
        }
        return runs
    }

    var body: some View {
        let p = mm.person(comment.who)
        HStack(alignment: .top, spacing: MMSpace.s4) {
            PersonProfileButton(person: p) {
                MMAvatar(name: p.name, photo: p.photo, size: 34)
                    .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
            }
            // Inline profile links keep the author at text height. The avatar
            // retains a separate 44pt target without stretching the header.
            VStack(alignment: .leading, spacing: MMSpace.s1) {
                PersonText(authorLine(for: p))
                    .mmFont(.body, 13, .bold, lineHeight: 1.3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityValue(comment.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                MentionText(text: comment.text).mmFont(.body, 15, lineHeight: 1.4).foregroundStyle(MMColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, MMSpace.s2)
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
                                .mmMonkey(person.monkey, size: 16)
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
                mm.openPerson(id)
                return .handled
            })
    }
}

// MARK: - Private training calendar
private struct TrainingDaySheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct TrainingWeekCard: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let anchor: Date
    var isActivity = false
    @State private var selected: Date?
    @State private var choice = false
    @State private var loggingTechniques = false
    @State private var removing: QuickLog?
    @State private var trainingSaveFailed = false
    @State private var daySheetHeight: CGFloat = 280
    private var days: [Date] { TrainingCalendar.week(anchor) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isActivity {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(days, id: \.self) { day in tile(day) }
                }
                if days.contains(where: { !mm.openPlans($0).isEmpty }) {
                    HStack(spacing: MMSpace.s2) {
                        MMIcon("calendar", size: 12, color: MMColor.ink300)
                        Text("=")
                        Text("You have a planned session")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .mmFont(.body, 12)
                    .foregroundStyle(MMColor.ink300)
                    .padding(.horizontal, MMSpace.s2)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("The calendar icon means you have a planned session")
                }
            } else {
                HStack(spacing: 4) { ForEach(days, id: \.self) { day in tile(day) } }
            }
            if !isActivity {
                HStack(spacing: MMSpace.s2) {
                    MMIcon("calendar", size: 12, color: MMColor.textTertiary)
                    Text("Planned session").mmFont(.body, 12).foregroundStyle(MMColor.textTertiary)
                }
            }
        }
        .padding(EdgeInsets(top: isActivity ? 16 : 12, leading: isActivity ? 14 : 12, bottom: 12, trailing: isActivity ? 14 : 12))
        .mmCardSurface(radius: isActivity ? 24 : MMRadius.lg, fill: isActivity ? MMColor.ink900 : MMColor.surfaceCard, shadow: !isActivity)
        .animation(reduceMotion ? nil : .timingCurve(0.34, 1.56, 0.64, 1, duration: MMMotion.slow), value: days.map { mm.entryCount($0) })
        .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            if let date = selected {
                if loggingTechniques {
                    QuickLogSheet(date: date) { selected = nil }
                } else {
                    daySheet(date)
                }
            }
        }
        .overlay(alignment: .top) {
            // A system sheet covers the shell toast; older-week logging needs its own presentation.
            if !isActivity, let toast = mm.toast, mm.canUndoTrainingToast(toast.id) {
                MMToast(message: toast.message, actionLabel: "Undo") {
                    Task { await mm.undoTrainingToast(toast.id) }
                }.offset(y: -12)
            }
        }
        .onChange(of: selected) { _, _ in trainingSaveFailed = false }
    }

    @ViewBuilder
    private var header: some View {
        if isActivity {
            VStack(alignment: .leading, spacing: MMSpace.s2) {
                Text("This week")
                    .mmFont(.display, 18)
                    .foregroundStyle(MMColor.paper)
                Text("Tap a day to quickly log your training.")
                    .mmFont(.body, 13)
                    .foregroundStyle(MMColor.ink200)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MMSpace.s2)
        } else {
            headerContent
        }
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: MMSpace.s2) {
            HStack(spacing: MMSpace.s4) {
                Text(days[0].formatted(.dateTime.month(.abbreviated).day()))
                    .mmFont(.display, 16)
                    .foregroundStyle(MMColor.textPrimary)
                Spacer(minLength: MMSpace.s2)
                Text("\(mm.trainedDays(days)) \(mm.trainedDays(days) == 1 ? "day" : "days") this week")
                    .mmFont(.body, 12, .semibold)
                    .foregroundStyle(MMColor.textPrimary)
                    .padding(.horizontal, MMSpace.s5)
                    .padding(.vertical, MMSpace.s3)
                    .background(MMColor.paper2, in: Capsule()).contentTransition(.numericText())
                    .modifier(TrainingPop(trigger: mm.trainedDays(days)))
            }
            Text("Tap a day to quickly log your training.")
                .mmFont(.body, 13)
                .foregroundStyle(MMColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func tile(_ date: Date) -> some View {
        let count = mm.entryCount(date), planTitles = mm.openPlans(date).map(\.title)
        let planned = !planTitles.isEmpty
        let today = TrainingCalendar.calendar.isDateInToday(date)
        let future = TrainingCalendar.calendar.startOfDay(for: date) > TrainingCalendar.calendar.startOfDay(for: Date())
        if isActivity {
            activityTile(date, count: count, planned: planned, today: today, future: future)
        } else {
            Button { tap(date) } label: {
                VStack(spacing: MMSpace.s2) {
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .mmFont(.body, 11, .semibold)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(date.formatted(.dateTime.day()))
                        .mmFont(.display, 16)
                        .fixedSize(horizontal: false, vertical: true)
                    Group {
                        if count > 1 { Text("×\(count)").mmFont(.body, 10, .bold).padding(.horizontal, 4).background(.white, in: Capsule()).foregroundStyle(MMColor.accent) }
                        else if count == 1 { MMIcon("check", size: 12, color: .white) }
                        else if planned { MMIcon("calendar", size: 12, color: MMColor.textTertiary) }
                        else { Circle().fill(today ? MMColor.accent : .clear).frame(width: 4, height: 4) }
                    }.frame(minHeight: 14)
                }
                    .padding(.vertical, MMSpace.s4)
                    .frame(maxWidth: .infinity, minHeight: MMSpace.s11 + MMSpace.s6)
                    .foregroundStyle(count > 0 ? .white : future ? MMColor.textDisabled : MMColor.textPrimary)
                    .background(count > 0 ? MMColor.accent : future ? .clear : MMColor.paper2, in: RoundedRectangle(cornerRadius: MMRadius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: MMRadius.md).strokeBorder(today && count == 0 ? MMColor.accent : future ? MMColor.borderDefault : .clear,
                            style: StrokeStyle(lineWidth: today ? 2 : 1, dash: future && planned ? [3, 3] : []))
                    }.modifier(TrainingPop(trigger: count))
            }.buttonStyle(.plain).disabled(future || mm.busy)
            .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(count > 0 ? "trained, \(count) entries" : "no entry")\(planned ? ", " + planTitles.joined(separator: ", ") + " planned" : ""), \(future ? "future day" : "tap to log training")")
        }
    }

    private func activityTile(_ date: Date, count: Int, planned: Bool, today: Bool, future: Bool) -> some View {
        let weekday = Text(date.formatted(.dateTime.weekday(.narrow)))
            .mmFont(.body, 11, .semibold, lineHeight: 1)
            .foregroundStyle(today ? MMColor.coral300 : future ? MMColor.ink400 : MMColor.ink300)
        let hasQuickLog = !mm.dayLogs(date).isEmpty
        let showsCount = count > 1 || hasQuickLog
        let removable = mm.canRemoveQuickLog(on: date)
        return ZStack {
            Button { tap(date) } label: {
                VStack(spacing: 7) {
                    weekday
                    Text(date.formatted(.dateTime.day()))
                        .mmFont(.display, 16, lineHeight: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(count > 0 ? MMColor.white : future ? MMColor.ink400 : MMColor.paper)
                        .frame(width: 40, height: 40)
                        .background(count > 0 ? MMColor.coral500 : future ? .clear : MMColor.paper.opacity(0.10), in: Circle())
                        .overlay {
                            Circle().strokeBorder(today ? MMColor.coral500 : future ? MMColor.paper.opacity(planned ? 0.50 : 0.14) : .clear,
                                                  style: StrokeStyle(lineWidth: today ? 2 : 1.5, dash: future && planned ? [3, 3] : []))
                        }
                }
                .frame(maxWidth: .infinity, minHeight: 66)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(date.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(count) training entries\(planned ? ", planned session" : "")")
            .accessibilityHint(planned ? "Choose a planned session or a quick log" : future ? "Future day" : "Add a quick log")
            .accessibilityActions {
                if removable {
                    Button("Remove one quick log") { Task { await mm.removeLatestQuickLog(on: date) } }
                }
            }
            // Sibling controls keep badge taps from also triggering the date button.
            // The hidden weekday keeps their circle aligned at larger text sizes.
            VStack(spacing: 7) {
                weekday.hidden().accessibilityHidden(true).allowsHitTesting(false)
                Color.clear.frame(width: 40, height: 40).allowsHitTesting(false)
                    .overlay(alignment: .topTrailing) {
                        if showsCount {
                            if removable {
                                Button { Task { await mm.removeLatestQuickLog(on: date) } } label: {
                                    quickLogCountBadge(count)
                                        .frame(width: 24, height: 24).contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove one quick log from \(date.formatted(.dateTime.month(.wide).day()))")
                                .accessibilityValue("\(count) training entries")
                                .offset(x: 6, y: -6)
                            } else {
                                // A planned date always opens the chooser; confirmed-only counts stay read-only.
                                Button { if planned { tap(date) } } label: {
                                    quickLogCountBadge(count)
                                        .frame(width: 24, height: 24).contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .offset(x: 6, y: -6)
                                .accessibilityHidden(true)
                            }
                        }
                    }
                    .overlay(alignment: showsCount ? .bottomTrailing : .topTrailing) {
                        if planned {
                            Button { tap(date) } label: {
                                MMIcon("calendar", size: 11, color: MMColor.paper)
                                    .frame(width: 18, height: 18)
                                    .background(MMColor.ink700, in: Circle())
                                    .background { Circle().fill(MMColor.ink900).padding(-2) }
                                    .frame(width: 24, height: 24).contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Planned session on \(date.formatted(.dateTime.month(.wide).day()))")
                            .accessibilityHint("Choose a planned session or a quick log")
                            .offset(x: 6, y: showsCount ? 6 : -6)
                        }
                    }
            }
            .frame(maxWidth: .infinity, minHeight: 66)
        }
        .disabled(mm.busy || mm.trainingTap(date, isActivity: true) == .disabled)
        .modifier(TrainingPop(trigger: count))
    }

    private func quickLogCountBadge(_ count: Int) -> some View {
        Text("×\(count)")
            .mmFont(.body, 9, .bold, lineHeight: 1)
            .foregroundStyle(MMColor.ink900)
            .lineLimit(1).minimumScaleFactor(0.5)
            .contentTransition(.numericText())
            .frame(width: 18, height: 18)
            .background(MMColor.paper, in: Circle())
            .background { Circle().fill(MMColor.ink900).padding(-2) }
    }

    private func tap(_ date: Date) {
        loggingTechniques = false
        switch mm.trainingTap(date, isActivity: isActivity) {
        case .disabled: break
        case .choose: choice = true; selected = date
        case .entries: choice = false; selected = date
        case .quickLog: loggingTechniques = true; selected = date
        }
    }
    private func daySheet(_ date: Date) -> some View {
        ScrollView {
            Group {
                if choice {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Text("What are you logging?")
                                .mmFont(.display, 22)
                                .foregroundStyle(MMColor.ink900)
                            Spacer(minLength: 0)
                            MMIconButton("x", variant: .filled, size: 40, label: "Close") { selected = nil }
                        }
                        loggingOptions(date)
                    }
                    .padding(.horizontal, MMSpace.s6)
                    .padding(.top, 26)
                    .padding(.bottom, MMSpace.s5)
                } else {
                    MMDialogBody(title: date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
                                 onClose: { selected = nil }) {
                        dayEntries(date)
                    } actions: { EmptyView() }
                    .padding(20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: TrainingDaySheetHeightKey.self, value: geometry.size.height)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(TrainingDaySheetHeightKey.self) { height in
            if height > 0 { daySheetHeight = height }
        }
        .background(MMColor.surfaceCard)
        .presentationBackground(MMColor.surfaceCard)
        .presentationDetents(choice ? [.height(daySheetHeight)] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MMRadius.xl)
        .confirmationDialog("Remove this quick log?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            if let log = removing {
                Button("Remove quick log", role: .destructive) {
                    Task {
                        if await mm.deleteQuickLog(log.id) { removing = nil }
                        else { trainingSaveFailed = true }
                    }
                }
            }
            Button("Keep it", role: .cancel) { removing = nil }
        }
    }

    private func loggingOptions(_ date: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let canQuickLog = mm.trainingTap(date, now: context.date) != .disabled
            VStack(alignment: .leading, spacing: 10) {
                ForEach(mm.openPlans(date)) { session in
                    Button {
                        trainingSaveFailed = false
                        Task {
                            if await mm.markTrainingDone(session) {
                                selected = nil
                                mm.go(.session(id: session.id))
                            } else if !mm.savingTraining { trainingSaveFailed = true }
                        }
                    } label: { planOption(session, now: context.date) }
                    .buttonStyle(.plain)
                    .disabled(mm.busy || !mm.canMarkTrainingDone(session, now: context.date))
                }
                Button {
                    trainingSaveFailed = false
                    loggingTechniques = true
                } label: {
                    HStack(spacing: 12) {
                        MMIcon("check", size: 24, weight: .bold, color: MMColor.white)
                            .frame(width: 48, height: 52)
                            .background(MMColor.coral500, in: RoundedRectangle(cornerRadius: MMRadius.md))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("A quick log").mmFont(.display, 17, tracking: -0.015, lineHeight: 1.2)
                            Text("Log the techniques you hit. Nothing is posted.")
                                .mmFont(.body, 13, .medium, lineHeight: 1.3)
                                .foregroundStyle(MMColor.ink700)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        MMIcon("chevron-right", size: 16, color: MMColor.ink500)
                    }
                    .foregroundStyle(MMColor.ink900)
                    .padding(14)
                    .background(MMColor.paper2, in: RoundedRectangle(cornerRadius: MMRadius.lg))
                    .contentShape(RoundedRectangle(cornerRadius: MMRadius.lg))
                }
                .buttonStyle(.plain)
                .disabled(mm.busy || !canQuickLog)
                .opacity(canQuickLog ? 1 : 0.5)
                if trainingSaveFailed {
                    Text("Couldn't save. Nothing changed. Try again.")
                        .mmFont(.body, 13).foregroundStyle(MMColor.danger500)
                }
                if let log = mm.dayLogs(date).first {
                    Text("Already logged today: a quick log at \(clock(log.loggedAt))")
                        .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                }
            }
        }
    }

    private func dayEntries(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(mm.dayLogs(date)) { log in
                HStack {
                    VStack(alignment: .leading, spacing: MMSpace.s2) {
                        Text("Quick log · Logged \(clock(log.loggedAt))").mmFont(.body, 15)
                        if let hits = mm.quickLogHitsByID[log.id], !hits.isEmpty {
                            Text(hits.map { "\($0.name) ×\($0.count)" }.joined(separator: " · "))
                                .mmFont(.body, 13).foregroundStyle(MMColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(); MMIconButton("trash-2", label: "Remove quick log") { removing = log }
                }
            }
            ForEach(mm.daySessions(date)) { session in
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title).mmFont(.display, 18)
                    Text("With \(names(session)) · \(mm.sharedSessionIDs.contains(session.id) ? "shared" : "not shared yet")")
                        .mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
                }
            }
            if trainingSaveFailed {
                Text("Couldn't save. Nothing changed. Try again.")
                    .mmFont(.body, 13).foregroundStyle(MMColor.danger500)
            }
            MMButton("Log another session", variant: .secondary, fullWidth: true) {
                trainingSaveFailed = false
                loggingTechniques = true
            }
            .disabled(mm.busy)
        }
    }
    private func clock(_ date: Date) -> String { date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()) }
    private func names(_ s: Session) -> String { s.going.filter { $0 != "me" }.map { mm.person($0).firstName }.joined(separator: " and ") }
    private func planOption(_ s: Session, now: Date) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(s.day.uppercased()).mmFont(.display, 10, tracking: 0.04, lineHeight: 1)
                Text("\(s.date)").mmFont(.display, 22, tracking: -0.03, lineHeight: 1)
            }
            .foregroundStyle(MMColor.sky700)
            .frame(width: 48, height: 52)
            .background(MMColor.sky100, in: RoundedRectangle(cornerRadius: MMRadius.md))
            VStack(alignment: .leading, spacing: 3) {
                Text(s.title).mmFont(.display, 17, tracking: -0.015, lineHeight: 1.2)
                Text(s.organizer == "me" ? "You host · \(s.time)" + (names(s).isEmpty ? "" : " with \(names(s))") : "\(mm.person(s.organizer).firstName) hosts · \(s.time)")
                    .mmFont(.body, 13, .medium, lineHeight: 1.3)
                    .foregroundStyle(MMColor.ink700)
                    .fixedSize(horizontal: false, vertical: true)
                if mm.startDate(of: s) > now {
                    Text("Starts at \(s.time)")
                        .mmFont(.body, 12, .medium).foregroundStyle(MMColor.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MMIcon("chevron-right", size: 16, color: MMColor.ink500)
        }
        .opacity(mm.startDate(of: s) > now ? 0.5 : 1)
        .foregroundStyle(MMColor.ink900)
        .padding(14)
        .mmCardSurface(shadow: false)
        .mmOutline(radius: MMRadius.lg, width: 1)
        .shadow(color: MMColor.ink900.opacity(0.06), radius: 0, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: MMRadius.lg))
    }

}
struct TrainingRhythm: View {
    @Environment(AppModel.self) private var mm
    @State private var selectedWeek: Int?
    private var weeks: [[Date]] {
        let c = TrainingCalendar.calendar
        return (-16...0).map { TrainingCalendar.week(c.date(byAdding: .weekOfYear, value: $0, to: Date())!) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your rhythm").mmFont(.display, 18); Spacer()
                Text("Since \(weeks[0][0].formatted(.dateTime.month(.abbreviated).day()))").mmFont(.body, 12).foregroundStyle(MMColor.textTertiary)
            }
            Text("Quick taps and planned sessions both fill a day. Rest is part of training.").mmFont(.body, 13).foregroundStyle(MMColor.textSecondary)
            HStack(alignment: .top, spacing: 4) {
                VStack(spacing: 4) {
                    Color.clear.frame(width: 12, height: 16)
                    ForEach(0..<7) { i in Text(["M", "", "W", "", "F", "", "S"][i]).mmFont(.body, 10).frame(width: 12, height: 14) }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(0..<17) { i in weekColumn(i) }
                    }
                }
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(MMColor.accent).frame(width: 14, height: 14)
                Text("Trained").mmFont(.body, 12)
                RoundedRectangle(cornerRadius: 4).fill(MMColor.paper3).frame(width: 14, height: 14)
                Text("No entry").mmFont(.body, 12)
            }
            Text("Tap a week to open its days").mmFont(.body, 12).foregroundStyle(MMColor.textTertiary)
        }.padding(16).mmCardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your rhythm, last 17 weeks, \(weeks.reduce(0) { $0 + mm.trainedDays($1) }) trained days. Monday to Sunday, oldest week first.")
        .sheet(isPresented: Binding(get: { selectedWeek != nil }, set: { if !$0 { selectedWeek = nil } })) {
            if let i = selectedWeek {
                TrainingWeekCard(anchor: weeks[i][0]).padding(16).presentationDetents([.medium, .large]).presentationDragIndicator(.visible).presentationBackground(MMColor.bgApp)
            }
        }
    }
    private func weekColumn(_ i: Int) -> some View {
        let week = weeks[i]
        let month = i == 0 || TrainingCalendar.calendar.component(.month, from: week[0]) != TrainingCalendar.calendar.component(.month, from: weeks[i-1][0])
        return VStack(alignment: .leading, spacing: 4) {
            Text(month ? week[0].formatted(.dateTime.month(.abbreviated)) : "").mmFont(.body, 10)
                .fixedSize().frame(width: 14, height: 16, alignment: .leading)
            Button { selectedWeek = i } label: {
                VStack(spacing: 4) {
                    ForEach(week, id: \.self) { date in
                        let future = TrainingCalendar.calendar.startOfDay(for: date) > TrainingCalendar.calendar.startOfDay(for: Date())
                        RoundedRectangle(cornerRadius: 4).fill(future ? .clear : mm.entryCount(date) > 0 ? MMColor.accent : MMColor.paper3)
                            .frame(width: 14, height: 14).overlay { if future { RoundedRectangle(cornerRadius: 4).stroke(MMColor.borderDefault, lineWidth: 1) } }
                    }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Week of \(week[0].formatted(date: .abbreviated, time: .omitted)), \(mm.trainedDays(week)) trained days. Open days")
        }
    }
}

private struct TrainingPop: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: Int
    func body(content: Content) -> some View {
        content.phaseAnimator([false, true, false], trigger: trigger) { view, expanded in
            view.scaleEffect(reduceMotion ? 1 : expanded ? 1.08 : 1)
        } animation: { _ in
            reduceMotion ? nil : .timingCurve(0.34, 1.56, 0.64, 1, duration: MMMotion.slow / 2)
        }
    }
}
