import SwiftUI

// Monkey avatars: the steps that end profile setup (meet → build → reveal), the
// one-time invitation for members who joined before monkeys, and the editor that
// Account opens. The monkey itself (`MMMonkey`, `MMMonkeyLook`) lives in Display.swift.

// MARK: - Shared pieces

/// Profile-setup progress: step 1 is the details form, 2–4 are the monkey.
struct MonkeyStepDots: View {
    var step: Int
    var total = 4

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                Capsule().fill(i == step ? MMColor.ink900 : MMColor.ink200)
                    .frame(width: i == step ? 26 : 8, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of \(total)")
    }
}

/// Back chevron, progress dots and an optional trailing action, as on the details step.
private struct MonkeyStepHeader: View {
    var step: Int
    var onBack: () -> Void
    var skip: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            MMIconButton("chevron-left", label: "Back", action: onBack)
                .padding(.leading, -10)
            MonkeyStepDots(step: step)
            Spacer()
            if let skip {
                Button("Skip", action: skip)
                    .mmFont(.body, 15, .semibold)
                    .foregroundStyle(MMColor.textTertiary)
                    .frame(minHeight: MMLayout.tapTarget)
            }
        }
        .padding(.horizontal, MMLayout.gutter)
        .frame(height: MMLayout.headerHeight)
    }
}

// MARK: - Meet

/// Step 2 of profile setup: a random monkey is already waiting, so skipping still leaves one.
struct MonkeyMeetView: View {
    @Binding var look: MMMonkeyLook
    var onBack: () -> Void
    var onBuild: () -> Void
    var onKeep: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private static let crew: [MMMonkeyLook] = [
        MMMonkeyLook(mood: .side, fur: .midnight, haircut: .curls),
        MMMonkeyLook(mood: .grin, fur: .ginger, haircut: .mohawk),
        MMMonkeyLook(mood: .focused, fur: .smoke, haircut: .clean),
        MMMonkeyLook(mood: .happy, fur: .smoke, haircut: .topknot),
        MMMonkeyLook(mood: .tired, fur: .midnight, haircut: .fringe),
    ]

    var body: some View {
        MMScreen {
            MonkeyStepHeader(step: 2, onBack: onBack, skip: onKeep)
        } content: {
            VStack(spacing: 28) {
                MMMonkey(look: look, size: 188, label: "Your monkey")
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                    .opacity(appeared || reduceMotion ? 1 : 0)
                VStack(spacing: 10) {
                    Text("Meet your monkey.")
                        .mmFont(.display, 36, tracking: -0.03, lineHeight: 1)
                        .foregroundStyle(MMColor.ink900)
                    Text("It sits next to your name on posts, sessions and streaks. Make it look like you.")
                        .mmFont(.body, 17, lineHeight: 1.45)
                        .foregroundStyle(MMColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    ForEach(Array(Self.crew.enumerated()), id: \.offset) { index, other in
                        MMMonkey(look: other, size: 44)
                            .offset(y: appeared || reduceMotion ? 0 : 24)
                            .opacity(appeared || reduceMotion ? 1 : 0)
                            .animation(MMMotion.bounce().delay(0.12 + Double(index) * 0.08), value: appeared)
                    }
                }
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, MMLayout.gutter)
            .padding(.top, 40)
        } footer: {
            VStack(spacing: 6) {
                MMButton("Build my monkey", size: .lg, fullWidth: true, action: onBuild)
                MMButton("Keep this one", variant: .ghost, fullWidth: true, action: onKeep)
            }
        }
        .onAppear { withAnimation(MMMotion.bounce(MMMotion.slow)) { appeared = true } }
    }
}

// MARK: - Build

/// Mood, fur and haircut. Every tile shows *your* monkey with that option applied.
struct MonkeyBuilderView: View {
    enum Mode { case setup, edit }
    private enum Part: String, CaseIterable { case mood = "Mood", fur = "Fur", haircut = "Haircut" }

    @Binding var look: MMMonkeyLook
    var name: String
    var mode: Mode
    var busy = false
    var onBack: () -> Void
    var onSkip: (() -> Void)?
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var part: Part = .mood
    @State private var pop = false

    private var hint: String {
        switch part {
        case .mood: return "How do you show up to class?"
        case .fur: return "Pick your fur."
        case .haircut: return "Fresh cut or post-roll chaos?"
        }
    }

    var body: some View {
        MMScreen {
            switch mode {
            case .setup:
                MonkeyStepHeader(step: 3, onBack: onBack, skip: onSkip)
            case .edit:
                MMHeader(title: "Your monkey", leading: {
                    MMIconButton("x", label: "Cancel", action: onBack)
                })
            }
        } content: {
            VStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    MMMonkey(look: look, size: 180, label: "Your monkey")
                        .scaleEffect(pop ? 0.9 : 1)
                    MMIconButton("shuffle", variant: .filled, size: 48, label: "Shuffle your monkey") {
                        change(.random())
                    }
                    .background(Circle().fill(MMColor.white).mmShadowFloat())
                    .offset(x: 24, y: -6)
                }
                .padding(.top, 12)
                HStack(spacing: 6) {
                    Text(name.isEmpty ? "You" : name).mmFont(.body, 15, .bold, lineHeight: 1).foregroundStyle(MMColor.ink900)
                    MMMonkey(look: look, size: 22)
                }
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(MMColor.white).mmShadowCard())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Preview: \(name) with your monkey after the name")
                Text(hint)
                    .mmFont(.body, 15, lineHeight: 1.4)
                    .foregroundStyle(MMColor.textSecondary)
                MMTabs(Part.allCases.map(\.rawValue), selection: Binding(
                    get: { part.rawValue },
                    set: { part = Part(rawValue: $0) ?? .mood }
                ))
                .padding(.top, 6)
                options
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, MMLayout.gutter)
            .padding(.bottom, 16)
        } footer: {
            MMButton(mode == .setup ? "Looks like me" : "Save my monkey", size: .lg, fullWidth: true, action: onDone)
                .disabled(busy)
        }
    }

    private var options: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            switch part {
            case .mood:
                ForEach(MMMonkeyLook.Mood.allCases) { mood in
                    tile(mood.title, with: { $0.mood = mood }, selected: look.mood == mood)
                }
            case .fur:
                ForEach(MMMonkeyLook.Fur.allCases) { fur in
                    tile(fur.title, with: { $0.fur = fur }, selected: look.fur == fur)
                }
            case .haircut:
                ForEach(MMMonkeyLook.Haircut.allCases) { haircut in
                    tile(haircut.title, with: { $0.haircut = haircut }, selected: look.haircut == haircut)
                }
            }
        }
    }

    private func tile(_ title: String, with apply: (inout MMMonkeyLook) -> Void, selected: Bool) -> some View {
        var preview = look
        apply(&preview)
        let next = preview
        return Button { change(next) } label: {
            VStack(spacing: 6) {
                MMMonkey(look: next, size: 64)
                Text(title).mmFont(.body, 13, .semibold, lineHeight: 1.2).foregroundStyle(MMColor.ink900)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background {
                RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous).fill(MMColor.white).mmShadowCard(!selected)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous)
                    .strokeBorder(MMColor.ink900, lineWidth: 2)
                    .opacity(selected ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func change(_ next: MMMonkeyLook) {
        guard next != look else { return }
        look = next
        guard !reduceMotion else { return }
        pop = true
        withAnimation(MMMotion.bounce()) { pop = false }
    }
}

// MARK: - Reveal

/// Last step of profile setup. "Complete my profile" saves the details and the monkey together.
struct MonkeyRevealView: View {
    var look: MMMonkeyLook
    var name: String
    var detail: String
    var busy = false
    var onBack: () -> Void
    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var firstName: String { name.split(separator: " ").first.map(String.init) ?? name }

    var body: some View {
        MMScreen {
            MonkeyStepHeader(step: 4, onBack: onBack)
        } content: {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    MMMonkey(look: look, size: 160, label: "Your monkey")
                        .frame(width: 190, height: 190)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MMColor.paper2))
                    Text(detail.isEmpty ? firstName : "\(firstName), \(detail.lowercased())")
                        .mmFont(.display, 18, lineHeight: 1)
                        .foregroundStyle(MMColor.ink900)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 20)
                .background(RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous).fill(MMColor.white).mmShadowFloat())
                .rotationEffect(.degrees(-4))
                .offset(y: appeared || reduceMotion ? 0 : -40)
                .opacity(appeared || reduceMotion ? 1 : 0)

                VStack(spacing: 10) {
                    Text("Looking sharp, \(firstName).")
                        .mmFont(.display, 36, tracking: -0.03, lineHeight: 1)
                        .foregroundStyle(MMColor.ink900)
                    Text("Your monkey goes next to your name. Change it any time in Account.")
                        .mmFont(.body, 17, lineHeight: 1.45)
                        .foregroundStyle(MMColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    MMAvatar(name: name, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).mmFont(.body, 15, .bold, lineHeight: 1.3).foregroundStyle(MMColor.ink900)
                            .mmMonkey(look, size: 22)
                        if !detail.isEmpty {
                            Text(detail).mmFont(.body, 13, lineHeight: 1.3).foregroundStyle(MMColor.textTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .mmCardSurface()
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, MMLayout.gutter)
            .padding(.top, 32)
        } footer: {
            MMButton("Complete my profile", size: .lg, fullWidth: true, action: onComplete)
                .disabled(busy)
        }
        .onAppear { withAnimation(MMMotion.bounce(MMMotion.slow)) { appeared = true } }
    }
}

// MARK: - Existing members

/// The one-time invitation for members who joined before monkeys. "Maybe later" stops
/// the invitation; Account keeps a Build my monkey row until they make one.
struct MonkeyPromptSheet: View {
    @Environment(AppModel.self) private var mm
    var onBuild: () -> Void
    var onLater: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .bottom, spacing: -4) {
                MMMonkey(look: MMMonkeyLook(mood: .side, fur: .midnight, haircut: .fringe), size: 80)
                    .rotationEffect(.degrees(-10))
                MMMonkey(look: MMMonkeyLook(mood: .happy, fur: .smoke, haircut: .clean), size: 112)
                    .opacity(0.3)
                MMMonkey(look: MMMonkeyLook(mood: .grin, fur: .charcoal, haircut: .mohawk), size: 80)
                    .rotationEffect(.degrees(10))
            }
            .accessibilityHidden(true)
            .padding(.top, 18)
            VStack(spacing: 8) {
                Text("Your monkey's waiting, \(mm.me.firstName).")
                    .mmFont(.display, 28, tracking: -0.03, lineHeight: 1.05)
                    .foregroundStyle(MMColor.ink900)
                Text("Your monkey goes next to your name.")
                    .mmFont(.body, 17, lineHeight: 1.45)
                    .foregroundStyle(MMColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            VStack(spacing: 6) {
                MMButton("Build my monkey", size: .lg, fullWidth: true, action: onBuild)
                MMButton("Maybe later", variant: .ghost, fullWidth: true, action: onLater)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, MMLayout.gutter)
        .padding(.bottom, 12)
        .presentationDetents([.height(440)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MMRadius.xl)
        .presentationBackground(MMColor.bgApp)
    }
}

/// The builder over whatever screen was open. Saving closes it, and that screen
/// redraws with the new monkey after the member's name.
struct MonkeyEditScreen: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.dismiss) private var dismiss
    @State private var look = MMMonkeyLook.random()
    @State private var saving = false

    var body: some View {
        MonkeyBuilderView(look: $look, name: mm.me.name, mode: .edit, busy: saving,
                          onBack: { dismiss() },
                          onDone: { Task { await save() } })
            .onAppear { if let current = mm.me.monkey { look = current } }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        guard await mm.saveMonkey(look) else { return }
        dismiss()
        mm.showToast("Fresh monkey on the mat", .success)
    }
}

/// The Account row: build one if you haven't, edit it if you have.
struct MonkeyAccountRow: View {
    @Environment(AppModel.self) private var mm
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let monkey = mm.me.monkey {
                    MMMonkey(look: monkey, size: 52)
                } else {
                    MMMonkey(look: MMMonkeyLook(mood: .happy, fur: .smoke, haircut: .clean), size: 52).opacity(0.35)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(mm.me.monkey == nil ? "Build my monkey" : "Edit my monkey")
                        .mmFont(.display, 16, tracking: -0.015, lineHeight: 1.25)
                        .foregroundStyle(MMColor.ink900)
                    Text("Your monkey goes next to your name.")
                        .mmFont(.body, 13, lineHeight: 1.3)
                        .foregroundStyle(MMColor.textTertiary)
                }
                Spacer(minLength: 0)
                MMIcon("chevron-right", size: 20, color: MMColor.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .mmCardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("account-monkey")
    }
}
