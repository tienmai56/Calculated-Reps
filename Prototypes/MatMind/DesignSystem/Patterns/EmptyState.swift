import SwiftUI

/// An invitation on the paper canvas, never a placeholder post or a loading skeleton.
struct MMEmptyState: View {
    enum Artwork { case memory, plan, goals, techniques }

    var artwork: Artwork
    var title: String
    var message: String
    /// Nil when another card on the screen already holds the primary action.
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var secondaryTitle: String? = nil
    var secondaryIcon: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            illustration
                .frame(height: artwork == .plan ? 250 : 200)
                .accessibilityHidden(true)
            Text(title)
                .mmFont(.display, 28, tracking: -0.03, lineHeight: 1.05)
                .foregroundStyle(MMColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, MMSpace.s6)
            Text(message)
                .mmFont(.body, 15, lineHeight: 1.45)
                .foregroundStyle(MMColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, MMSpace.s5)
            if let actionTitle, let action {
                MMButton(actionTitle, size: .lg, iconLeft: actionIcon, fullWidth: true, action: action)
                    .padding(.top, MMSpace.s8)
            }
            if let secondaryTitle, let secondaryAction {
                MMButton(secondaryTitle, variant: .ghost, iconLeft: secondaryIcon, action: secondaryAction)
                    .padding(.top, MMSpace.s4)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MMSpace.s8)
        .padding(.top, MMSpace.s8)
        .padding(.bottom, MMSpace.s8)
    }

    @ViewBuilder
    private var illustration: some View {
        switch artwork {
        case .memory:
            PeekABooCardArtwork()
        case .plan:
            TiedInPlanArtwork()
        case .goals:
            GoalTapesArtwork()
        case .techniques:
            PeekABooCardArtwork(techniques: true)
        }
    }
}

/// Shared peek-and-nod motion for a memory frame or technique index card.
/// The existing Silverback moves as a whole, never changing its artwork.
/// Reduce Motion holds the still peeking pose.
private struct PeekABooCardArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var techniques = false

    private enum Phase: CaseIterable { case hidden, peek, click, nod, hold }

    var body: some View {
        if reduceMotion {
            scene(.hold)
        } else {
            PhaseAnimator(Phase.allCases) { phase in
                scene(phase)
            } animation: { phase in
                switch phase {
                case .hidden: MMMotion.easeOut(0.4).delay(0.5)
                case .peek: MMMotion.bounce(MMMotion.slow).delay(0.9)
                case .click: MMMotion.easeOut(0.08).delay(0.25)
                case .nod: MMMotion.bounce().delay(0.1)
                case .hold: MMMotion.bounce().delay(0.25)
                }
            }
        }
    }

    private func scene(_ phase: Phase) -> some View {
        let out = phase != .hidden
        return ZStack(alignment: .topTrailing) {
            Image("SilverbackMark")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 72)
                .rotationEffect(.degrees(out ? (phase == .nod ? 6 : 16) : 0), anchor: .bottomLeading)
                .offset(x: out ? 0 : -52, y: out ? -2 : 26)
            if techniques {
                techniqueCard(pulse: phase == .click)
            } else {
                card(click: phase == .click)
            }
        }
        .frame(width: 280)
    }

    private func techniqueCard(pulse: Bool) -> some View {
        VStack(alignment: .leading, spacing: MMSpace.s6) {
            HStack(spacing: MMSpace.s6) {
                ruledLine
                MMIcon("plus", size: 24, color: MMColor.accent)
                    .scaleEffect(pulse ? 0.86 : 1)
            }
            ruledLine
            ruledLine.frame(width: MMSpace.s11 + MMSpace.s10)
        }
        .padding(MMSpace.s6)
        .frame(width: 200, height: 120)
        .mmCardSurface(radius: MMRadius.lg)
        .rotationEffect(.degrees(pulse ? -7 : -6))
        .padding(.top, MMSpace.s5)
        .frame(maxWidth: .infinity)
    }

    private var ruledLine: some View {
        Capsule().fill(MMColor.paper3).frame(height: MMSpace.s1)
    }

    private func card(click: Bool) -> some View {
        VStack(spacing: MMSpace.s5) {
            RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous)
                .fill(MMColor.surfaceSunken)
                .frame(height: 120)
                .overlay {
                    MMIcon("camera", size: 36, color: MMColor.textTertiary)
                        .scaleEffect(click ? 0.86 : 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous)
                        .fill(MMColor.surfaceCard)
                        .opacity(click ? 0.95 : 0)
                }
            Text("Gi wrinkled.\nHair wrecked. Perfect.")
                .mmFont(.display, 13, .bold, lineHeight: 1)
                .multilineTextAlignment(.center)
                .foregroundStyle(MMColor.textSecondary)
                .padding(.bottom, MMSpace.s2)
        }
        .padding(MMSpace.s4)
        .frame(width: 200)
        .background(RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous).fill(MMColor.surfaceCard))
        .mmShadowCard()
        .rotationEffect(.degrees(click ? -7 : -6))
        .padding(.top, MMSpace.s5)
        .frame(maxWidth: .infinity)
    }
}

/// Three strips of athletic tape, each a goal, that drop onto the mat one after
/// another with a bounce and then sway gently. Still when Reduce Motion is on.
private struct GoalTapesArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var sway = false

    private struct Strip {
        var text: String
        var rotation: Double
        var x: CGFloat
        var y: CGFloat
    }

    private let strips = [
        Strip(text: "Single leg", rotation: -6, x: -34, y: -54),
        Strip(text: "RNC finish", rotation: 4, x: 30, y: 0),
        Strip(text: "Knee cut", rotation: -3, x: -16, y: 54),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(strips.enumerated()), id: \.offset) { i, strip in
                let drift: CGFloat = sway ? (i.isMultiple(of: 2) ? -4 : 4) : 0
                Text(strip.text)
                    .mmFont(.display, 20, tracking: -0.02, lineHeight: 1)
                    .foregroundStyle(MMColor.ink900)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 18)
                    .background(MMColor.tape)
                    .clipShape(MMTapeShape())
                    .shadow(color: MMColor.ink900.opacity(0.2), radius: 3, x: 0, y: 2)
                    .rotationEffect(.degrees(landed ? strip.rotation + (sway ? 1.5 : 0) * (i.isMultiple(of: 2) ? 1 : -1) : strip.rotation * 3))
                    .offset(x: strip.x, y: landed ? strip.y + drift : strip.y - 150)
                    .opacity(landed ? 1 : 0)
                    .animation(reduceMotion ? nil : MMMotion.bounce(MMMotion.slow).delay(Double(i) * 0.14), value: landed)
            }
        }
        .onAppear {
            landed = true
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(1)) { sway = true }
        }
    }
}

/// The plan ticket with two Silverbacks under it. They slide in from either side,
/// bump heads with a bounce, and a sun "knot" ties them together while the stub
/// warms to the sun tint, then they part and go again. Still (tied) when Reduce
/// Motion is on. The mark only moves as a whole; it is never redrawn.
private struct TiedInPlanArtwork: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: CaseIterable { case apart, bump, tied }

    var body: some View {
        if reduceMotion {
            scene(.tied)
        } else {
            PhaseAnimator(Phase.allCases) { phase in
                scene(phase)
            } animation: { phase in
                switch phase {
                case .apart: MMMotion.easeOut(0.5).delay(1.4)
                case .bump: MMMotion.bounce(MMMotion.slow).delay(0.8)
                case .tied: MMMotion.easeOut(0.4).delay(0.12)
                }
            }
        }
    }

    private func scene(_ phase: Phase) -> some View {
        let together = phase != .apart
        return VStack(spacing: 44) {
            PlanTicket(stubTint: together ? MMColor.sun100 : MMColor.surfaceSunken,
                       iconColor: together ? MMColor.textPrimary : MMColor.textTertiary)
                .rotationEffect(.degrees(phase == .bump ? 2 : 4))
                .offset(y: phase == .bump ? -3 : 0)
            ZStack(alignment: .bottom) {
                burst
                    .opacity(phase == .bump ? 1 : 0)
                    .offset(y: phase == .tied ? -86 : -76)
                silverback
                    .rotationEffect(.degrees(together ? 6 : -12), anchor: .bottom)
                    .offset(x: together ? -24 : -98)
                silverback
                    .rotationEffect(.degrees(together ? -6 : 12), anchor: .bottom)
                    .offset(x: together ? 24 : 98)
                Circle()
                    .fill(MMColor.sun400)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(MMColor.bgApp, lineWidth: 3))
                    .scaleEffect(together ? 1 : 0.01)
                    .offset(y: 10)
            }
            .frame(height: 72)
        }
    }

    private var silverback: some View {
        Image("SilverbackMark")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 72)
    }

    /// Three short coral spark lines above the spot where the heads meet.
    private var burst: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Capsule().frame(width: 4, height: 12).rotationEffect(.degrees(-35))
            Capsule().frame(width: 4, height: 14).offset(y: -6)
            Capsule().frame(width: 4, height: 12).rotationEffect(.degrees(35))
        }
        .foregroundStyle(MMColor.accent)
    }
}

/// The ticket-stub card: tinted date stub, dashed tear, punched notches.
private struct PlanTicket: View {
    var stubTint: Color
    var iconColor: Color

    var body: some View {
        HStack(spacing: 0) {
            MMIcon("calendar-plus", size: 32, color: iconColor)
                .frame(width: 76, height: 124)
                .background(stubTint)
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 0, y: 100))
            }
            .stroke(MMColor.controlOff, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            .frame(width: 1, height: 100)
            Text("Next up?\nYou decide.")
                .mmFont(.display, 20, tracking: -0.02, lineHeight: 1.15)
                .foregroundStyle(MMColor.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MMSpace.s6)
        }
        .frame(width: 256)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .mmCardSurface(radius: 24)
        .overlay(alignment: .topLeading) {
            Circle().fill(MMColor.bgApp).frame(width: 16, height: 16).offset(x: 69, y: -8)
        }
        .overlay(alignment: .bottomLeading) {
            Circle().fill(MMColor.bgApp).frame(width: 16, height: 16).offset(x: 69, y: 8)
        }
    }
}
