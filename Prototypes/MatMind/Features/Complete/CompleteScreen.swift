import SwiftUI

/// The composer: posts only come from completed sessions.
/// Photo → caption → who trained → mark completed → publish.
struct CompleteScreen: View {
    @Environment(AppModel.self) private var mm
    let id: String

    @State private var removed: Set<String> = []
    @State private var photo: String? = nil
    @State private var showRoll = false
    @State private var caption = ""
    @State private var done = false
    @State private var result: PublishResult? = nil

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
                            MMIconButton("repeat-2", variant: .overlay, size: 40, label: "Change photo") { showRoll = true }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(12)
                        }
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else {
                    emptyPhoto
                }
                MMTextField(placeholder: "What happened on the mat?", text: $caption, multiline: true, rows: 2)
                    .padding(.top, 16)
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
                MMSwitch(isOn: $done, label: "Training completed", description: "Counts toward weekly streaks for everyone here.")
                    .padding(16)
                    .background {
                        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
                        shape.fill(done ? MMColor.mint100 : MMColor.white).mmShadowCard(!done)
                    }
                    .animation(MMMotion.easeOut(), value: done)
                    .padding(.top, 22)
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        } footer: {
            MMButton(done ? "Publish to Activity" : "Mark as completed to publish", size: .lg, iconLeft: "send", fullWidth: true) {
                if let r = mm.publish(s.id, photo: photo, caption: caption, people: people) {
                    withAnimation(MMMotion.easeOut(0.3)) { result = r }
                }
            }
            .disabled(!done)
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

    private var emptyPhoto: some View {
        VStack(spacing: 14) {
            Text("Grab the post-training photo").mmFont(.display, 22, tracking: -0.03, lineHeight: 1.15).foregroundStyle(MMColor.ink900)
            Text("Sweaty, smiling, slightly crooked. That's the one.").mmFont(.body, 14).foregroundStyle(MMColor.textSecondary)
            HStack(spacing: 8) {
                MMButton("Take photo", iconLeft: "camera") { showRoll = true }
                MMButton("Upload", variant: .secondary, iconLeft: "image-plus") { showRoll = true }
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
                            if let photo = post.photo { Image(photo).resizable().scaledToFill() }
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
