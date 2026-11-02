import SwiftUI

/// 2px-based spacing steps (`--space-0` … `--space-11`).
enum MMSpace {
    static let s0: CGFloat = 0
    static let s1: CGFloat = 2
    static let s2: CGFloat = 4
    static let s3: CGFloat = 6
    static let s4: CGFloat = 8
    static let s5: CGFloat = 12
    static let s6: CGFloat = 16
    static let s7: CGFloat = 20
    static let s8: CGFloat = 24
    static let s9: CGFloat = 32
    static let s10: CGFloat = 40
    static let s11: CGFloat = 56
}

enum MMLayout {
    static let gutter: CGFloat = 16
    static let tapTarget: CGFloat = 44
    static let tabBarHeight: CGFloat = 86
    static let headerHeight: CGFloat = 54
    static let sectionGap: CGFloat = 22
}

/// Soft everywhere: inputs 14, cards 22–24, photo posts and sheets 28, controls pill.
enum MMRadius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
}

/// Quick, physical, joyful. CSS easings mapped to SwiftUI animations.
enum MMMotion {
    static let fast: Double = 0.14
    static let base: Double = 0.22
    static let slow: Double = 0.42

    /// `--ease-out` cubic-bezier(.2,.8,.2,1): UI changes and screen pushes.
    static func easeOut(_ duration: Double = base) -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1, duration: duration)
    }

    /// `--ease-in-out` cubic-bezier(.65,0,.35,1).
    static func easeInOut(_ duration: Double = base) -> Animation {
        .timingCurve(0.65, 0, 0.35, 1, duration: duration)
    }

    /// `--ease-bounce` overshoot: joins, likes, checkmarks, switches, the QR connect.
    static func bounce(_ duration: Double = base) -> Animation {
        .spring(response: max(0.25, duration * 1.6), dampingFraction: 0.6)
    }
}

extension View {
    /// `--shadow-card`: 0 1px 0 ink/.04, 0 6px 18px ink/.06.
    func mmShadowCard(_ enabled: Bool = true) -> some View {
        self
            .shadow(color: MMColor.ink900.opacity(enabled ? 0.04 : 0), radius: 0, x: 0, y: 1)
            .shadow(color: MMColor.ink900.opacity(enabled ? 0.06 : 0), radius: 9, x: 0, y: 6)
    }

    /// `--shadow-float`: toasts and modals.
    func mmShadowFloat() -> some View {
        shadow(color: MMColor.ink900.opacity(0.16), radius: 16, x: 0, y: 12)
    }

    /// White card surface with the card shadow and no border.
    func mmCardSurface(radius: CGFloat = MMRadius.lg, fill: Color = MMColor.surfaceCard, shadow: Bool = true) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill)
                .mmShadowCard(shadow)
        }
    }

    /// Hairline outline (`--shadow-hairline` / outline variants).
    func mmOutline(radius: CGFloat, color: Color = MMColor.borderDefault, width: CGFloat = 1.5) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(color, lineWidth: width)
        }
    }
}

/// 135° hatch, used only for empty photo slots and the pending streak week.
struct MMHatch: View {
    var color: Color
    var spacing: CGFloat = 8
    var lineWidth: CGFloat = 2.8

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
}

/// Wrapping row layout, for tag and chip groups.
struct MMFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Plain press feedback used by tappable cards (`scale(.985)`).
struct MMPressStyle: ButtonStyle {
    var scale: CGFloat = 0.985
    var bounce = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(bounce ? MMMotion.bounce(MMMotion.fast) : MMMotion.easeOut(MMMotion.fast), value: configuration.isPressed)
    }
}
