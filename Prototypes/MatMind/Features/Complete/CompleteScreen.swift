import SwiftUI
import PhotosUI
import UIKit

/// What a shared session needs before it can be published: a photo, a note, or both.
/// The session focus is copied from the plan and never counts on its own, and a note
/// made only of whitespace or @tags counts as empty. See DESIGN.md, "Share the session".
enum ShareRule {
    static func hasWords(_ caption: String) -> Bool {
        caption.split(whereSeparator: \.isWhitespace).contains { !$0.hasPrefix("@") }
    }

    static func canPublish(hasPhoto: Bool, caption: String) -> Bool {
        hasPhoto || hasWords(caption)
    }
}

/// The composer: posts only come from completed sessions.
/// Saved session details → photo and/or note → who trained → publish.
struct CompleteScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String

    @State private var library = false
    @State private var camera = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var loadingMedia = false
    @State private var media: [String] = []
    @State private var selectedMedia = 0
    @State private var initializedMedia = false
    @State private var publishing = false
    @State private var savingPhoto = false
    @State private var photoSaveFailed = false
    @State private var removed: Set<String> = []
    @State private var showRoll = false
    @State private var caption = ""
    @State private var result: PublishResult? = nil
    /// Set when Publish is tapped with nothing to share; cleared once there is.
    @State private var nudged = false
    @State private var noteFocus = 0

    private var hasWords: Bool { ShareRule.hasWords(caption) }
    private var canPublish: Bool { ShareRule.canPublish(hasPhoto: !media.isEmpty, caption: caption) }

    var body: some View {
        if let result {
            CelebrateView(result: result)
                .transition(.opacity)
        } else if let s = mm.findSession(id), s.organizer == "me" {
            compose(s)
        } else {
            MMColor.bgApp.ignoresSafeArea().toolbar(.hidden, for: .navigationBar)
        }
    }

    private func compose(_ s: Session) -> some View {
        let attendees = s.going
        let people = attendees.filter { !removed.contains($0) }
        return MMScreen {
            MMHeader(title: "Share the session", leading: {
                MMIconButton("x", label: "Close") { mm.back() }
            })
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                sessionDetails(s)
                if !s.focusItems.isEmpty {
                    Text("What we worked on")
                        .mmFont(.display, 16)
                        .padding(.top, MMLayout.sectionGap)
                        .padding(.bottom, MMSpace.s5)
                    TrainingSessionFocusChecklist(session: s)
                        .disabled(publishing || savingPhoto)
                }
                if media.isEmpty {
                    emptyPhoto.padding(.top, MMLayout.sectionGap)
                } else {
                    mediaEditor.padding(.top, MMLayout.sectionGap)
                }
                if savingPhoto || loadingMedia {
                    Text(loadingMedia ? "Loading media…" : "Saving media to session…")
                        .mmFont(.body, 13).foregroundStyle(MMColor.textSecondary)
                        .padding(.top, MMSpace.s4)
                } else if photoSaveFailed {
                    MMButton("Retry saving media", variant: .secondary, size: .sm, iconLeft: "repeat-2") { saveMedia() }
                        .padding(.top, MMSpace.s4)
                }
                MMTextField(label: "Caption", placeholder: media.isEmpty ? "What happened on the mat? @tag a partner" : "Add a few words? @tag a partner",
                            text: $caption, multiline: true, rows: 2, focusRequest: noteFocus)
                    .padding(.top, 16)
                MentionSuggestions(text: $caption, people: mm.mentionCandidates(including: people))
                HStack {
                    Text("Who trained").mmFont(.display, 16).foregroundStyle(MMColor.ink900)
                    Spacer()
                    MMMeta(people.count == 1 ? "1 person" : "\(people.count) people")
                }
                .padding(.horizontal, 2)
                .padding(.top, 22)
                .padding(.bottom, 10)
                MMFlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(attendees, id: \.self) { pid in personChip(pid) }
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        } footer: {
            VStack(spacing: 12) {
                shareHint
                publishButton(s, people: people)
            }
            .animation(MMMotion.easeOut(MMMotion.fast), value: canPublish)
            .animation(MMMotion.easeOut(MMMotion.fast), value: nudged)
        }
        .onChange(of: canPublish) { _, ready in if ready { nudged = false } }
        .onAppear {
            if !initializedMedia { media = Array(s.photos.prefix(SessionMedia.limit)); initializedMedia = true }
        }
        .photosPicker(isPresented: $library, selection: $pickerItems,
                      maxSelectionCount: max(1, mediaLimit - media.count), selectionBehavior: .ordered,
                      matching: supportsGallery ? .any(of: [.images, .videos]) : .images)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            loadingMedia = true
            Task { await loadMedia(items) }
        }
        .sheet(isPresented: $camera) {
            MMTrainingCamera { image in if let image { storePhoto(image) }; camera = false }
        }
        .mmSheet(isPresented: $showRoll, title: "Recent photos") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(mm.cameraRoll, id: \.self) { name in
                    Button {
                        guard media.count < mediaLimit, !media.contains(name) else { return }
                        withAnimation(MMMotion.bounce(MMMotion.slow)) { media.append(name); selectedMedia = media.count - 1 }
                        saveMedia()
                        showRoll = false
                    } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { Image(name).resizable().scaledToFill() }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(MMColor.accent, lineWidth: 3)
                                    .opacity(media.contains(name) ? 1 : 0)
                            }
                    }
                    .buttonStyle(MMPressStyle(scale: 0.96))
                }
            }
        }
    }

    /// Keep the original plan visible while composing, separate from the new post's caption.
    private func sessionDetails(_ s: Session) -> some View {
        VStack(alignment: .leading, spacing: MMSpace.s5) {
            Text("How was \(s.title)?")
                .mmFont(.display, 22, tracking: -0.03, lineHeight: 1.15)
                .foregroundStyle(MMColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            sessionDetailRow(icon: "map-pin", text: s.gym)
            sessionDetailRow(icon: "user", text: s.organizer == "me" ? "Hosted by you" : "Hosted by \(mm.person(s.organizer).name)")
            sessionDetailRow(icon: s.privacy == .link ? "globe" : "lock",
                             text: s.privacy == .link ? "Session access: anyone with the link (Mat Monkey account required)" : "Session access: friends only")
            if let note = s.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                VStack(alignment: .leading, spacing: MMSpace.s2) {
                    Text("Session note")
                        .mmFont(.body, 13, .semibold)
                        .foregroundStyle(MMColor.textTertiary)
                    Text(note)
                        .mmFont(.body, 15, lineHeight: 1.45)
                        .foregroundStyle(MMColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MMSpace.s6)
        .mmCardSurface(radius: MMRadius.lg)
    }

    private func sessionDetailRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: MMSpace.s4) {
            MMIcon(icon, size: 16, color: MMColor.textTertiary)
                .padding(.top, MMSpace.s1)
                .accessibilityHidden(true)
            Text(text)
                .mmFont(.body, 15, lineHeight: 1.45)
                .foregroundStyle(MMColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// Locked until there's a photo or a note. A tap while locked doesn't error loudly:
    /// the hint turns coral and the note field takes focus, since typing is the fastest fix.
    private func publishButton(_ s: Session, people: [String]) -> some View {
        MMButton(mm.trainingCompletionStatus(s) == nil ? "Complete & Share" : "Share a memory", size: .lg, iconLeft: "send", fullWidth: true) {
            guard canPublish else { nudge(); return }
            if let runtime = mm.runtime {
                publishing = true
                Task {
                    let published = await runtime.publish(s.id, media: media, caption: caption, people: people)
                    publishing = false
                    if let published { withAnimation(MMMotion.easeOut(0.3)) { result = published } }
                }
            } else if let r = mm.publish(s.id, media: media, caption: caption, people: people) {
                withAnimation(MMMotion.easeOut(0.3)) { result = r }
            }
        }
        .disabled(!canPublish || publishing || savingPhoto || loadingMedia || photoSaveFailed || mm.busy)
        .overlay {
            // A disabled button swallows taps, so catch them here to point at what's missing.
            if !canPublish && !publishing && !mm.busy {
                Color.clear
                    .contentShape(Capsule())
                    .onTapGesture { nudge() }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint(canPublish ? "" : "Add a photo, video or a few words first")
    }

    private func nudge() {
        nudged = true
        noteFocus += 1
        AccessibilityNotification.Announcement("Add a photo, video or a few words first").post()
    }

    /// One line above Publish that states the rule up front, then confirms what's in.
    private var hintContent: (icon: String, text: String, color: Color) {
        if nudged && !canPublish { return ("circle-alert", "Add a photo, video or a few words first", MMColor.coral700) }
        if !canPublish { return ("info", "Add a photo, video or a few words to share", MMColor.textSecondary) }
        if !media.isEmpty && hasWords { return ("circle-check", "Media and words. Ready to share.", MMColor.mint700) }
        if !media.isEmpty { return ("circle-check", "Media is in. Words are a bonus.", MMColor.mint700) }
        return ("circle-check", "Words are in. A photo's a bonus.", MMColor.mint700)
    }

    private var shareHint: some View {
        let hint = hintContent
        return HStack(spacing: 6) {
            MMIcon(hint.icon, size: 16, color: hint.color)
            Text(hint.text)
                .mmFont(.body, 13, nudged && !canPublish ? MMWeight.semibold : MMWeight.regular, lineHeight: 1.3)
                .foregroundStyle(hint.color)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hint.text)
    }

    private func choosePhoto() {
        guard media.count < mediaLimit, !savingPhoto, !loadingMedia else { return }
        if mm.isLive { library = true } else { showRoll = true }
    }

    private func storePhoto(_ image: UIImage) {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = normalized.jpegData(compressionQuality: 0.8) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("training-\(UUID().uuidString).jpg")
        do {
            guard media.count < mediaLimit else { return }
            try data.write(to: url, options: .atomic)
            media.append(url.path); selectedMedia = media.count - 1
            if !loadingMedia { saveMedia() }
        }
        catch { mm.showToast("Could not save that photo. Please try again.") }
    }

    private var supportsGallery: Bool { !mm.isLive || mm.sessionMediaAvailable }
    private var mediaLimit: Int { supportsGallery ? SessionMedia.limit : 1 }

    private func saveMedia() {
        savingPhoto = true
        photoSaveFailed = false
        let selection = media
        Task {
            let saved = await mm.saveSessionMedia(id, media: selection)
            savingPhoto = false
            photoSaveFailed = !saved
        }
    }

    @MainActor
    private func loadMedia(_ items: [PhotosPickerItem]) async {
        for item in items.prefix(max(0, mediaLimit - media.count)) {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                if let movie = try? await item.loadTransferable(type: GoalPickedVideo.self),
                   let size = try? movie.file.url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                   size <= SessionMedia.maxVideoBytes {
                    let destination = FileManager.default.temporaryDirectory
                        .appendingPathComponent("session-\(UUID().uuidString).\(movie.file.url.pathExtension)")
                    do {
                        try FileManager.default.copyItem(at: movie.file.url, to: destination)
                        media.append(destination.path); selectedMedia = media.count - 1
                    } catch { mm.showToast("That video couldn't be read") }
                } else { mm.showToast("Choose an MP4, MOV or M4V video under 50 MB") }
            } else if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                storePhoto(image)
            } else { mm.showToast("That photo couldn't be read") }
        }
        pickerItems = []
        loadingMedia = false
        saveMedia()
    }

    private var mediaEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos & videos").mmFont(.display, 18)
                Spacer()
                MMMeta("\(media.count)/\(mediaLimit)")
            }
            MMSessionMediaTile(source: media[min(selectedMedia, media.count - 1)], height: 280, radius: 26)
                .overlay(alignment: .topTrailing) {
                    Text("\(min(selectedMedia + 1, media.count))/\(media.count)")
                        .mmFont(.body, 13, .semibold).foregroundStyle(.white)
                        .padding(8).background(.black.opacity(0.55), in: Capsule()).padding(12)
                }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(media.enumerated()), id: \.offset) { index, source in
                        MMColor.paper3.frame(width: 76, height: 76)
                            .overlay { MMSessionMediaTile(source: source, height: 76, radius: 12).allowsHitTesting(false) }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(index == selectedMedia ? MMColor.accent : .clear, lineWidth: 2) }
                            .contentShape(Rectangle()).onTapGesture { selectedMedia = index }
                            .accessibilityLabel("Preview media \(index + 1)")
                            .overlay(alignment: .topTrailing) {
                                MMIconButton("x", variant: .overlay, size: 32, label: "Remove media \(index + 1)") {
                                    media.remove(at: index); selectedMedia = min(selectedMedia, max(0, media.count - 1)); saveMedia()
                                }
                            }
                    }
                    if media.count < mediaLimit {
                        Button { choosePhoto() } label: {
                            VStack(spacing: 4) { MMIcon("plus", size: 22); Text("Add").mmFont(.body, 13) }
                                .frame(width: 76, height: 76)
                                .background(MMColor.paper2, in: RoundedRectangle(cornerRadius: 12))
                                .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(MMColor.ink200, style: StrokeStyle(lineWidth: 1.5, dash: [5])) }
                        }.buttonStyle(.plain).accessibilityLabel("Add photos or videos")
                    }
                }
            }
            Text(media.count == mediaLimit ? "Limit reached · Remove an item to add another" : "Up to 5 photos and videos total")
                .mmFont(.body, 13).foregroundStyle(MMColor.textSecondary)
        }
        .disabled(savingPhoto || publishing || loadingMedia)
    }

    private var emptyPhoto: some View {
        VStack(spacing: 14) {
            Text("Save the post-training moments").mmFont(.display, 22, tracking: -0.03, lineHeight: 1.15).foregroundStyle(MMColor.ink900)
            Text("Add up to 5 photos and videos from the mat.").mmFont(.body, 14).foregroundStyle(MMColor.textSecondary)
            HStack(spacing: 8) {
                // Once there are words, Publish is the screen's one primary button.
                MMButton("Take photo", variant: hasWords ? .secondary : .primary, iconLeft: "camera") {
                    if mm.isLive && UIImagePickerController.isSourceTypeAvailable(.camera) { camera = true }
                    else { choosePhoto() }
                }
                MMButton("Upload", variant: .secondary, iconLeft: "image-plus") { choosePhoto() }
            }
            .padding(.top, 4)
        }
        .disabled(savingPhoto || publishing || loadingMedia)
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background {
            let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
            ZStack {
                shape.fill(MMColor.paper2)
                MMHatch(color: MMColor.ink900.opacity(0.025), spacing: 28, lineWidth: 10).clipShape(shape)
                shape.strokeBorder(MMColor.ink200, lineWidth: 2)
            }
        }
    }

    private func personChip(_ pid: String) -> some View {
        let p = mm.person(pid)
        let out = removed.contains(pid)
        return HStack(spacing: 8) {
            MMAvatar(name: p.name, photo: p.photo, size: 34)
            Text(pid == "me" ? "You" : p.firstName)
                .mmFont(.body, 14, .semibold, lineHeight: 1)
                .foregroundStyle(MMColor.textPrimary)
                .strikethrough(out)
            if pid != "me" {
                MMIconButton(out ? "plus" : "x", size: 28, label: out ? "Add back" : "Remove") {
                    withAnimation(MMMotion.easeOut()) {
                        if out { removed.remove(pid) } else { removed.insert(pid) }
                    }
                }
            } else {
                Color.clear.frame(width: 6, height: 1)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .frame(height: 42)
        .background {
            if out {
                Capsule().strokeBorder(MMColor.ink200, lineWidth: 1.5)
            } else {
                Capsule().fill(MMColor.white).mmShadowCard()
            }
        }
        .opacity(out ? 0.5 : 1)
    }
}

// MARK: - Celebration

/// Coral full-screen moment: the polaroid drops in, streaks tick up.
struct CelebrateView: View {
    @Environment(AppModel.self) private var mm
    let result: PublishResult

    @State private var dropped = false
    @State private var listShown = false

    var body: some View {
        let post = result.post
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Shared with the crew").mmFont(.display, 34, tracking: -0.04, lineHeight: 1)
                    Text("Now on \(post.participants.count) profiles and in your friends' feeds.")
                        .mmFont(.body, 15, .medium).opacity(0.9)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                VStack(spacing: 0) {
                    MMColor.paper3
                        .frame(height: 200)
                        .overlay {
                            if let photo = post.photo { MMPhoto(source: photo).scaledToFill() }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    HStack {
                        Text(post.title).mmFont(.display, 15, lineHeight: 1.1).foregroundStyle(MMColor.ink900)
                        Spacer(minLength: 6)
                        MMAvatarStack(people: post.participants.map { mm.person($0).avatar }, size: 22, max: 3, ring: MMColor.tape)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .frame(width: 250)
                .background(RoundedRectangle(cornerRadius: 8).fill(MMColor.tape))
                .shadow(color: Color(mmHex: 0x5A1400).opacity(0.35), radius: 20, x: 0, y: 18)
                .rotationEffect(.degrees(dropped ? -3 : -14))
                .offset(y: dropped ? 0 : -60)
                .opacity(dropped ? 1 : 0)
                .padding(.top, 22)

                if !result.streaks.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Streaks this week").mmFont(.display, 16).foregroundStyle(MMColor.ink900).padding(.bottom, 6)
                        ForEach(Array(result.streaks.enumerated()), id: \.element.id) { i, tick in
                            StreakTickRow(tick: tick, delay: 1.1 + Double(i) * 0.3, divider: i < result.streaks.count - 1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.white))
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .opacity(listShown ? 1 : 0)
                    .offset(y: listShown ? 0 : 10)
                }

                MMButton("See it in Activity", variant: .inverse, size: .lg, fullWidth: true) { mm.showPost(post.id) }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .background(MMColor.coral500.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) { dropped = true }
            withAnimation(MMMotion.easeOut(0.5).delay(0.5)) { listShown = true }
        }
    }
}

private struct StreakTickRow: View {
    @Environment(AppModel.self) private var mm
    let tick: StreakTick
    let delay: Double
    let divider: Bool

    @State private var value: Int
    @State private var weekDone = false

    init(tick: StreakTick, delay: Double, divider: Bool) {
        self.tick = tick
        self.delay = delay
        self.divider = divider
        _value = State(initialValue: tick.from)
    }

    var body: some View {
        let p = mm.person(tick.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                MMPairAvatars(a: mm.me.avatar, b: p.avatar, size: 30, hue: p.hue)
                Text(p.firstName).mmFont(.body, 15, .bold).foregroundStyle(MMColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(value)")
                    .mmFont(.display, 22, tracking: -0.03, lineHeight: 1)
                    .foregroundStyle(MMColor.flame500)
                    .contentTransition(.numericText(value: Double(value)))
                Text(tick.to == 1 ? "week" : "weeks").mmFont(.body, 13, .semibold).foregroundStyle(MMColor.textTertiary)
            }
            MMStreakBelt(weeks: tick.friendship.weeks, thisWeek: weekDone ? .done : .pending, hue: p.hue, size: .sm)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(MMColor.borderSubtle).frame(height: 1) }
        }
        .task {
            try? await Task.sleep(for: .seconds(delay))
            withAnimation(MMMotion.bounce(0.5)) {
                value = tick.to
                weekDone = true
            }
        }
    }
}

private struct MMTrainingCamera: UIViewControllerRepresentable {
    let completed: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completed: completed) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let camera = UIImagePickerController(); camera.sourceType = .camera; camera.delegate = context.coordinator; return camera
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completed: (UIImage?) -> Void
        init(completed: @escaping (UIImage?) -> Void) { self.completed = completed }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completed(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            completed(info[.originalImage] as? UIImage)
        }
    }
}
