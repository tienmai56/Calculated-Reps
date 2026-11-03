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
/// Photo and/or note → who trained → publish.
struct CompleteScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String

    @State private var library = false
    @State private var camera = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var publishing = false
    @State private var removed: Set<String> = []
    @State private var photo: String? = nil
    @State private var showRoll = false
    @State private var caption = ""
    @State private var result: PublishResult? = nil
    /// Set when Publish is tapped with nothing to share; cleared once there is.
    @State private var nudged = false
    @State private var noteFocus = 0

    private var hasWords: Bool { ShareRule.hasWords(caption) }
    private var canPublish: Bool { ShareRule.canPublish(hasPhoto: photo != nil, caption: caption) }

    var body: some View {
        if let result {
            CelebrateView(result: result)
                .transition(.opacity)
        } else if let s = mm.findSession(id) {
            compose(s)
        } else {
            MMColor.bgApp.ignoresSafeArea().toolbar(.hidden, for: .navigationBar)
        }
    }

    private func compose(_ s: Session) -> some View {
        let attendees = s.going
        let people = attendees.filter { !removed.contains($0) }
        return MMScreen {
            MMHeader(title: "Share the session", sub: "\(s.title) · \(s.day) \(s.month) \(s.date)", leading: {
                MMIconButton("x", label: "Close") { mm.back() }
            })
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if let photo {
                    MMPhotoTile(photo: photo, height: 330, radius: 26) {
                        ZStack {
                            MMTapeLabel(text: s.gym)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                .padding(.leading, 12)
                                .padding(.bottom, 14)
                            MMIconButton("repeat-2", variant: .overlay, size: 40, label: "Change photo") { choosePhoto() }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(12)
                        }
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else {
                    emptyPhoto
                }
                if !s.focusItems.isEmpty {
                    Text("What we worked on")
                        .mmFont(.display, 16)
                        .padding(.top, MMSpace.s8)
                        .padding(.bottom, MMSpace.s5)
                    TrainingFocusOutline(items: s.focusItems)
                }
                MMTextField(placeholder: photo == nil ? "What happened on the mat? @tag a partner" : "Add a few words? @tag a partner",
                            text: $caption, multiline: true, rows: 2, focusRequest: noteFocus)
                    .padding(.top, 16)
                MentionSuggestions(text: $caption, people: mm.mentionCandidates(including: people))
                HStack {
                    Text("Who trained").mmFont(.display, 16).foregroundStyle(MMColor.ink900)
                    Spacer()
                    MMMeta("\(people.count) people")
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
        .photosPicker(isPresented: $library, selection: $pickerItem, matching: .images)
        .task(id: pickerItem) {
            guard let pickerItem, let data = try? await pickerItem.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
            storePhoto(image)
        }
        .sheet(isPresented: $camera) {
            MMTrainingCamera { image in if let image { storePhoto(image) }; camera = false }
        }
        .mmSheet(isPresented: $showRoll, title: "Recent photos") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(mm.cameraRoll, id: \.self) { name in
                    Button {
                        withAnimation(MMMotion.bounce(MMMotion.slow)) { photo = name }
                        showRoll = false
                    } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay { Image(name).resizable().scaledToFill() }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(MMColor.accent, lineWidth: 3)
                                    .opacity(photo == name ? 1 : 0)
                            }
                    }
                    .buttonStyle(MMPressStyle(scale: 0.96))
                }
            }
        }
    }

    /// Locked until there's a photo or a note. A tap while locked doesn't error loudly:
    /// the hint turns coral and the note field takes focus, since typing is the fastest fix.
    private func publishButton(_ s: Session, people: [String]) -> some View {
        MMButton("Publish to Activity", size: .lg, iconLeft: "send", fullWidth: true) {
            guard canPublish else { nudge(); return }
            if let runtime = mm.runtime {
                publishing = true
                Task {
                    let published = await runtime.publish(s.id, photo: photo, caption: caption, people: people)
                    publishing = false
                    if let published { withAnimation(MMMotion.easeOut(0.3)) { result = published } }
                }
            } else if let r = mm.publish(s.id, photo: photo, caption: caption, people: people) {
                withAnimation(MMMotion.easeOut(0.3)) { result = r }
            }
        }
        .disabled(!canPublish || publishing || mm.busy)
        .overlay {
            // A disabled button swallows taps, so catch them here to point at what's missing.
            if !canPublish && !publishing && !mm.busy {
                Color.clear
                    .contentShape(Capsule())
                    .onTapGesture { nudge() }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint(canPublish ? "" : "Add a photo or a few words first")
    }

    private func nudge() {
        nudged = true
        noteFocus += 1
        AccessibilityNotification.Announcement("Add a photo or a few words first").post()
    }

    /// One line above Publish that states the rule up front, then confirms what's in.
    private var hintContent: (icon: String, text: String, color: Color) {
        if nudged && !canPublish { return ("circle-alert", "Add a photo or a few words first", MMColor.coral700) }
        if !canPublish { return ("info", "Add a photo, a few words, or both to share", MMColor.textSecondary) }
        if photo != nil && hasWords { return ("circle-check", "Photo and words. The crew's going to love it.", MMColor.mint700) }
        if photo != nil { return ("circle-check", "Photo's in. Words are a bonus.", MMColor.mint700) }
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
        if mm.isLive { library = true } else { showRoll = true }
    }

    private func storePhoto(_ image: UIImage) {
        let scale = min(1, 1600 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = normalized.jpegData(compressionQuality: 0.8) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("training-\(UUID().uuidString).jpg")
        do { try data.write(to: url, options: .atomic); photo = url.path }
        catch { mm.showToast("Could not save that photo. Please try again.") }
    }

    private var emptyPhoto: some View {
        VStack(spacing: 14) {
            Text("Grab the post-training photo").mmFont(.display, 22, tracking: -0.03, lineHeight: 1.15).foregroundStyle(MMColor.ink900)
            Text("Sweaty, smiling, slightly crooked. That's the one.").mmFont(.body, 14).foregroundStyle(MMColor.textSecondary)
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
