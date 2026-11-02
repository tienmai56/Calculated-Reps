import SwiftUI

// MARK: - Card

enum MMCardVariant {
    case standard, sunken, outline
}

/// White, radius 22, `--shadow-card`, no border.
struct MMCard<Content: View>: View {
    var variant: MMCardVariant = .standard
    var padding: CGFloat = 16
    var radius: CGFloat = MMRadius.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                switch variant {
                case .standard: shape.fill(MMColor.surfaceCard).mmShadowCard()
                case .sunken: shape.fill(MMColor.paper2)
                case .outline: shape.strokeBorder(MMColor.borderDefault, lineWidth: 1.5)
                }
            }
    }
}

// MARK: - Badge

enum MMBadgeVariant {
    case neutral, accent, soft, success, warning, danger, info, flame

    var colors: (bg: Color, fg: Color) {
        switch self {
        case .neutral: (MMColor.paper2, MMColor.textSecondary)
        case .accent: (MMColor.accent, .white)
        case .soft: (MMColor.accentTint, MMColor.coral700)
        case .success: (MMColor.successTint, MMColor.mint700)
        case .warning: (MMColor.warningTint, MMColor.warningInk)
        case .danger: (MMColor.dangerTint, MMColor.danger500)
        case .info: (MMColor.infoTint, MMColor.sky700)
        case .flame: (MMColor.flame100, MMColor.flameInk)
        }
    }
}

/// 24pt pill, sentence case.
struct MMBadge: View {
    let text: String
    var variant: MMBadgeVariant = .neutral
    var dot = false
    var icon: String?
    var height: CGFloat = 24
    var fontSize: CGFloat = 12
    var paddingX: CGFloat = 10

    init(_ text: String, variant: MMBadgeVariant = .neutral, dot: Bool = false, icon: String? = nil,
         height: CGFloat = 24, fontSize: CGFloat = 12, paddingX: CGFloat = 10) {
        self.text = text
        self.variant = variant
        self.dot = dot
        self.icon = icon
        self.height = height
        self.fontSize = fontSize
        self.paddingX = paddingX
    }

    var body: some View {
        let c = variant.colors
        HStack(spacing: 5) {
            if dot { Circle().fill(c.fg).frame(width: 6, height: 6) }
            if let icon { MMIcon(icon, size: fontSize + 2, weight: .bold) }
            Text(text).mmFont(.body, fontSize, .bold, lineHeight: 1)
        }
        .lineLimit(1)
        .foregroundStyle(c.fg)
        .padding(.horizontal, paddingX)
        .frame(height: height)
        .background(Capsule().fill(c.bg))
    }
}

// MARK: - Tag

/// Selectable chip: 32 (sm) or 40 (md). Selected = ink-900 fill, paper text.
struct MMTag: View {
    enum Size { case sm, md }

    let text: String
    var icon: String?
    var selected = false
    var size: Size = .md
    var action: (() -> Void)?
    var onRemove: (() -> Void)?

    /// A trailing closure is the tap `action`; pass `onRemove:` by label.
    init(_ text: String, icon: String? = nil, selected: Bool = false, size: Size = .md,
         action: (() -> Void)? = nil, onRemove: (() -> Void)? = nil) {
        self.text = text
        self.icon = icon
        self.selected = selected
        self.size = size
        self.onRemove = onRemove
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) { chip }.buttonStyle(MMPressStyle(scale: 0.96))
        } else {
            chip
        }
    }

    private var chip: some View {
        HStack(spacing: 6) {
            if let icon { MMIcon(icon, size: size == .sm ? 14 : 16, weight: .bold) }
            Text(text).mmFont(.body, size == .sm ? 13 : 15, .semibold, lineHeight: 1)
            if let onRemove {
                Button(action: onRemove) { MMIcon("x", size: 14, weight: .bold) }
                    .buttonStyle(.plain)
                    .opacity(0.6)
                    .padding(.trailing, -4)
                    .accessibilityLabel("Remove \(text)")
            }
        }
        .lineLimit(1)
        .foregroundStyle(selected ? MMColor.paper : MMColor.textPrimary)
        .padding(.horizontal, size == .sm ? 12 : 16)
        .frame(height: size == .sm ? 32 : 40)
        .background {
            if selected {
                Capsule().fill(MMColor.ink900)
            } else {
                Capsule().fill(MMColor.white).overlay(Capsule().strokeBorder(MMColor.borderDefault, lineWidth: 1.5))
            }
        }
        .animation(MMMotion.easeOut(MMMotion.fast), value: selected)
    }
}

// MARK: - Avatar

/// Photo, or initials on a friend-hue tint; optional belt-color ring.
struct MMAvatar: View {
    var name: String
    var photo: String?
    var size: CGFloat = 40
    var belt: BeltRank?
    var ring: Color = MMColor.bgApp
    var online = false

    private static let tints = [MMColor.sun100, MMColor.mint100, MMColor.sky100, MMColor.plum100, MMColor.coral100]
    private static let inks = [MMColor.sun600, MMColor.mint700, MMColor.sky700, MMColor.plum700, MMColor.coral700]

    private var initials: String {
        let words = name.split(separator: " ").prefix(size < 30 ? 1 : 2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var hueIndex: Int {
        Int(name.unicodeScalars.reduce(0) { $0 + $1.value } % UInt32(Self.tints.count))
    }

    var body: some View {
        let beltWidth: CGFloat = belt == nil ? 0 : max(2, (size / 18).rounded())
        ZStack {
            if let belt {
                Circle().fill(ring)
                if belt == .white {
                    Circle().strokeBorder(MMColor.ink900.opacity(0.2), lineWidth: beltWidth + 1)
                }
                Circle().strokeBorder(belt.color, lineWidth: beltWidth)
            }
            face.padding(belt == nil ? 0 : beltWidth + 2)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if online {
                let d = max(9, size * 0.26)
                Circle().fill(MMColor.mint500).frame(width: d, height: d)
                    .background(Circle().fill(MMColor.bgApp).padding(-2))
            }
        }
        .accessibilityLabel(name)
    }

    private var face: some View {
        ZStack {
            Self.tints[hueIndex]
            if let photo {
                MMPhoto(source: photo).scaledToFill()
            } else {
                Text(initials)
                    .font(MMFont.display((size * 0.38).rounded()))
                    .foregroundStyle(Self.inks[hueIndex])
            }
        }
        .clipShape(Circle())
    }
}

struct MMAvatarPerson: Hashable {
    var name: String
    var photo: String?
}

/// Overlapping avatars (32% overlap, 2.5pt ring) with an optional label.
struct MMAvatarStack: View {
    var people: [MMAvatarPerson]
    var size: CGFloat = 32
    var max = 4
    var ring: Color = MMColor.surfaceCard
    var label: String?

    var body: some View {
        let shown = Array(people.prefix(max))
        let extra = people.count - shown.count
        HStack(spacing: 8) {
            HStack(spacing: -size * 0.32) {
                ForEach(Array(shown.enumerated()), id: \.offset) { index, person in
                    MMAvatar(name: person.name, photo: person.photo, size: size)
                        .background(Circle().fill(ring).padding(-2.5))
                        .zIndex(Double(shown.count - index))
                }
                if extra > 0 {
                    Text("+\(extra)")
                        .mmFont(.body, (size * 0.34).rounded(), .bold, lineHeight: 1)
                        .foregroundStyle(MMColor.textSecondary)
                        .frame(width: size, height: size)
                        .background(Circle().fill(MMColor.paper2))
                        .background(Circle().fill(ring).padding(-2.5))
                }
            }
            if let label {
                Text(label).mmFont(.body, 13, .medium, lineHeight: 1.3).foregroundStyle(MMColor.textSecondary)
            }
        }
    }
}

// MARK: - Belt

/// A rank strip: belt color, black (or red) bar with 0–4 white stripes.
struct MMBelt: View {
    enum Size {
        case xs, sm, md, lg
        var height: CGFloat { switch self { case .xs: 8; case .sm: 12; case .md: 16; case .lg: 24 } }
    }

    var rank: BeltRank
    var stripes = 0
    var size: Size = .md
    var width: CGFloat?
    var showLabel = false

    var label: String {
        let n = Swift.max(0, Swift.min(4, stripes))
        return rank.title + " belt" + (n > 0 ? " · \(n) stripe\(n > 1 ? "s" : "")" : "")
    }

    var body: some View {
        if showLabel {
            VStack(alignment: .leading, spacing: 6) {
                strip
                Text(label).mmFont(.body, 13, .semibold, lineHeight: 1.2).foregroundStyle(MMColor.textSecondary)
            }
        } else {
            strip
        }
    }

    private var strip: some View {
        let h = size.height
        let barWidth: CGFloat = size == .xs ? 14 : Swift.max(h * 3.2, 26)
        let stripeWidth = Swift.max(2, (h * 0.24).rounded())
        let n = Swift.max(0, Swift.min(4, stripes))
        let radius = Swift.max(3, h * 0.25)
        return HStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: Swift.max(2, stripeWidth * 0.8)) {
                ForEach(0..<n, id: \.self) { _ in
                    Rectangle().fill(Color.white).frame(width: stripeWidth)
                }
            }
            .padding(.horizontal, size == .xs ? 2 : (h * 0.35).rounded())
            .frame(width: barWidth, height: h, alignment: .trailing)
            .background(rank.barColor)
            Color.clear.frame(width: (h * 0.8).rounded())
        }
        .frame(height: h)
        .frame(minWidth: barWidth * 2.5)
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(rank.color)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(MMColor.ink900.opacity(0.16), lineWidth: 1.5))
        .accessibilityElement()
        .accessibilityLabel(label)
    }
}

// MARK: - StreakBelt

enum MMWeekState: String {
    case done, pending
}

/// The signature motif: each calendar week is a belt segment with a white
/// tape stripe; consecutive weeks join into one belt; missed weeks are bare
/// mat; the current week is a hatched slot until you train.
struct MMStreakBelt: View {
    enum Size { case sm, md }

    var weeks: [Bool]
    var thisWeek: MMWeekState
    var hue: FriendHue = .coral
    var size: Size = .md
    var showFlame = true

    private var height: CGFloat { size == .sm ? 14 : 22 }

    private var alive: Bool {
        thisWeek == .done || (thisWeek == .pending && weeks.last == true)
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0...weeks.count, id: \.self) { i in cell(i) }
            }
            .frame(height: height)
            if showFlame {
                MMIcon("flame", size: (height * 0.72).rounded(), filled: alive, color: alive ? MMColor.flame500 : MMColor.ink300)
                    .frame(width: height + 6, height: height + 6)
                    .background(Circle().fill(alive ? MMColor.flame100 : MMColor.paper2))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(alive ? "Streak alive" : "Streak on pause")
    }

    @ViewBuilder
    private func cell(_ i: Int) -> some View {
        let lastIndex = weeks.count
        let isNow = i == lastIndex
        let done = isNow ? thisWeek == .done : weeks[i]
        let first = i == 0 || !weeks[i - 1]
        let last = isNow || (i + 1 < lastIndex ? !weeks[i + 1] : thisWeek != .done)
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: first ? 6 : 2,
            bottomLeadingRadius: first ? 6 : 2,
            bottomTrailingRadius: last ? 6 : 2,
            topTrailingRadius: last ? 6 : 2,
            style: .continuous
        )
        ZStack(alignment: .trailing) {
            if done {
                shape.fill(hue.base)
                if size != .sm {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 3)
                        .padding(.vertical, 4)
                        .padding(.trailing, 4)
                }
            } else if isNow {
                MMHatch(color: hue.tint, spacing: 8, lineWidth: 3).clipShape(shape)
                shape.stroke(hue.base, lineWidth: 2).padding(1)
            } else {
                shape.fill(MMColor.paper3)
            }
        }
        .opacity(isNow && !done ? 0.7 : 1)
        .frame(maxWidth: .infinity)
    }
}
