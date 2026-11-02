import SwiftUI

// MARK: - Icon

/// Lucide v0.454.0 (ISC), from `assets/icons/`. Each glyph ships as a template
/// SVG at a 2px stroke, a `-bold` 2.5px variant (active tab, buttons, checks)
/// and, for flame / heart / star / bookmark, a `-filled` variant.
struct MMIcon: View {
    enum Weight { case regular, bold }

    let name: String
    var size: CGFloat = 20
    var weight: Weight = .regular
    var filled = false
    var color: Color?

    init(_ name: String, size: CGFloat = 20, weight: Weight = .regular, filled: Bool = false, color: Color? = nil) {
        self.name = name
        self.size = size
        self.weight = weight
        self.filled = filled
        self.color = color
    }

    private static let fillable: Set<String> = ["flame", "heart", "star", "bookmark"]

    private var assetName: String {
        if filled && Self.fillable.contains(name) { return name + "-filled" }
        return weight == .bold ? name + "-bold" : name
    }

    var body: some View {
        let image = Image(assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        if let color {
            image.foregroundStyle(color)
        } else {
            image
        }
    }
}

// MARK: - Button

enum MMButtonVariant {
    case primary, secondary, soft, ghost, inverse, danger

    fileprivate var spec: (bg: Color, fg: Color, border: Color?, edge: Color?) {
        switch self {
        case .primary: (MMColor.accent, MMColor.textOnAccent, nil, MMColor.accentShade)
        case .secondary: (MMColor.white, MMColor.textPrimary, MMColor.borderDefault, MMColor.ink200)
        case .soft: (MMColor.accentTint, MMColor.coral700, nil, nil)
        case .ghost: (Color.clear, MMColor.textPrimary, nil, nil)
        case .inverse: (MMColor.ink900, MMColor.paper, nil, Color(mmHex: 0x000000))
        case .danger: (MMColor.dangerTint, MMColor.danger500, nil, nil)
        }
    }
}

enum MMButtonSize {
    case sm, md, lg

    var height: CGFloat { switch self { case .sm: 36; case .md: 48; case .lg: 56 } }
    var paddingX: CGFloat { switch self { case .sm: 14; case .md: 20; case .lg: 24 } }
    var fontSize: CGFloat { switch self { case .sm: 14; case .md: 16; case .lg: 17 } }
    var iconSize: CGFloat { switch self { case .sm: 16; case .md: 18; case .lg: 20 } }
}

/// Pill button. Primary (and secondary / inverse) have a 3px darker
/// "pressable" bottom edge that sinks 2px on press.
struct MMButton: View {
    let title: String
    var variant: MMButtonVariant = .primary
    var size: MMButtonSize = .md
    var iconLeft: String?
    var iconRight: String?
    var fullWidth = false
    let action: () -> Void

    init(
        _ title: String,
        variant: MMButtonVariant = .primary,
        size: MMButtonSize = .md,
        iconLeft: String? = nil,
        iconRight: String? = nil,
        fullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.iconLeft = iconLeft
        self.iconRight = iconRight
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let iconLeft { MMIcon(iconLeft, size: size.iconSize, weight: .bold) }
                Text(title)
                if let iconRight { MMIcon(iconRight, size: size.iconSize, weight: .bold) }
            }
        }
        .buttonStyle(MMButtonStyle(variant: variant, size: size, fullWidth: fullWidth))
    }
}

struct MMButtonStyle: ButtonStyle {
    var variant: MMButtonVariant
    var size: MMButtonSize
    var fullWidth: Bool

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let spec = variant.spec
        let edge: Color? = isEnabled ? spec.edge : nil
        let pressed = configuration.isPressed && isEnabled
        return configuration.label
            .mmFont(.display, size.fontSize, .bold, tracking: -0.01, lineHeight: 1)
            .lineLimit(1)
            .foregroundStyle(isEnabled ? spec.fg : MMColor.textDisabled)
            .padding(.horizontal, size.paddingX)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .background {
                ZStack {
                    if let edge {
                        Capsule().fill(edge).offset(y: pressed ? 1 : 3)
                    }
                    Capsule().fill(isEnabled ? (pressed && edge == nil ? spec.bg.opacity(0.85) : spec.bg) : MMColor.ink100)
                    if let border = spec.border {
                        Capsule().strokeBorder(border, lineWidth: 1.5)
                    }
                }
            }
            .contentShape(Capsule())
            .scaleEffect(pressed && edge == nil ? 0.97 : 1)
            .offset(y: pressed && edge != nil ? 2 : 0)
            .animation(MMMotion.easeOut(MMMotion.fast), value: pressed)
    }
}

// MARK: - IconButton

enum MMIconButtonVariant {
    case ghost, filled, accent, overlay, inverse

    fileprivate var colors: (bg: Color, fg: Color) {
        switch self {
        case .ghost: (Color.clear, MMColor.textPrimary)
        case .filled: (MMColor.paper2, MMColor.textPrimary)
        case .accent: (MMColor.accent, MMColor.textOnAccent)
        case .overlay: (Color.white.opacity(0.88), MMColor.ink900)
        case .inverse: (MMColor.ink900, MMColor.paper)
        }
    }
}

enum MMIconBadge: Equatable {
    case dot
    case count(Int)
}

/// Round icon button, 44pt by default. Press scales to .86 with a bounce.
struct MMIconButton: View {
    let icon: String
    var variant: MMIconButtonVariant = .ghost
    var size: CGFloat = 44
    var iconSize: CGFloat?
    var active = false
    var filledWhenActive = false
    var activeColor: Color = MMColor.accent
    var badge: MMIconBadge?
    let label: String
    let action: () -> Void

    init(
        _ icon: String,
        variant: MMIconButtonVariant = .ghost,
        size: CGFloat = 44,
        iconSize: CGFloat? = nil,
        active: Bool = false,
        filledWhenActive: Bool = false,
        activeColor: Color = MMColor.accent,
        badge: MMIconBadge? = nil,
        label: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.variant = variant
        self.size = size
        self.iconSize = iconSize
        self.active = active
        self.filledWhenActive = filledWhenActive
        self.activeColor = activeColor
        self.badge = badge
        self.label = label
        self.action = action
    }

    var body: some View {
        let colors = variant.colors
        let fg = active && variant != .accent ? activeColor : colors.fg
        Button(action: action) {
            ZStack {
                Circle().fill(colors.bg)
                MMIcon(icon, size: iconSize ?? (size * 0.5).rounded(), weight: .bold, filled: active && filledWhenActive, color: fg)
            }
            .frame(width: size, height: size)
            .overlay(alignment: .topTrailing) {
                if let badge {
                    badgeView(badge)
                        .padding(.top, size * 0.12)
                        .padding(.trailing, size * 0.12)
                }
            }
        }
        .buttonStyle(MMPressStyle(scale: 0.86, bounce: true))
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func badgeView(_ badge: MMIconBadge) -> some View {
        switch badge {
        case .dot:
            Circle().fill(MMColor.accent)
                .frame(width: 9, height: 9)
                .background(Circle().fill(MMColor.bgApp).padding(-2))
        case .count(let n):
            Text("\(n)")
                .mmFont(.body, 11, .bold, lineHeight: 1)
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(Capsule().fill(MMColor.accent))
                .background(Capsule().fill(MMColor.bgApp).padding(-2))
        }
    }
}
