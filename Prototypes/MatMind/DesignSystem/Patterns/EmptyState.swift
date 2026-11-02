import SwiftUI

/// An invitation on the paper canvas, never a placeholder post or a loading skeleton.
struct MMEmptyState: View {
    enum Artwork { case memory, plan }

    var artwork: Artwork
    var title: String
    var message: String
    var actionTitle: String
    var actionIcon: String
    var secondaryTitle: String? = nil
    var secondaryIcon: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            illustration
                .frame(height: 200)
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
            MMButton(actionTitle, size: .lg, iconLeft: actionIcon, fullWidth: true, action: action)
                .padding(.top, MMSpace.s8)
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
            VStack(spacing: MMSpace.s5) {
                RoundedRectangle(cornerRadius: MMRadius.md, style: .continuous)
                    .fill(MMColor.surfaceSunken)
                    .frame(height: 120)
                    .overlay { MMIcon("camera", size: 36, color: MMColor.textTertiary) }
                Text("Post-roll, with your people.")
                    .mmFont(.display, 13, .bold, lineHeight: 1)
                    .foregroundStyle(MMColor.textSecondary)
                    .padding(.bottom, MMSpace.s2)
            }
            .padding(MMSpace.s4)
            .frame(width: 200)
            .background(RoundedRectangle(cornerRadius: MMRadius.lg, style: .continuous).fill(MMColor.surfaceCard))
            .mmShadowCard()
            .rotationEffect(.degrees(-6))
        case .plan:
            HStack(spacing: 0) {
                MMIcon("calendar-plus", size: 32, color: MMColor.textTertiary)
                    .frame(width: 76, height: 124)
                    .background(MMColor.surfaceSunken)
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
            .rotationEffect(.degrees(5))
        }
    }
}
