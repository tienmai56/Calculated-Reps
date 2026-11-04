import SwiftUI
import UIKit

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
         onRemove: (() -> Void)? = nil, action: (() -> Void)? = nil) {
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

// MARK: - Monkey

/// A member's monkey: a minimal two-color face (fur + white) shown right after
/// their name. Built from a mood, a fur color and a haircut. Stored on the
/// profile as "mood.fur.haircut" (see migration 20261104170000_monkey_avatars).
struct MMMonkeyLook: Hashable {
    enum Mood: String, CaseIterable, Identifiable {
        case happy, grin, focused, tired, side, tapped
        var id: String { rawValue }
        var title: String {
            switch self {
            case .happy: return "Oss."
            case .grin: return "Good rolls"
            case .focused: return "Game face"
            case .tired: return "Round six"
            case .side: return "Side-eye"
            case .tapped: return "Tapped"
            }
        }
    }

    /// Dark tokens only (3:1 or more on white): the features are drawn in the fur color, so
    /// light furs would wash out. The friend-hue 700s are allowed here and never mean a friendship.
    enum Fur: String, CaseIterable, Identifiable {
        case midnight = "ink-900", charcoal = "ink-700", smoke = "ink-500", ginger = "coral-700"
        case navy = "sky-700", grape = "plum-700", moss = "mint-700"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .midnight: return "Midnight"
            case .charcoal: return "Charcoal"
            case .smoke: return "Smoke"
            case .ginger: return "Ginger"
            case .navy: return "Navy"
            case .grape: return "Grape"
            case .moss: return "Moss"
            }
        }
        var color: Color {
            switch self {
            case .midnight: return MMColor.ink900
            case .charcoal: return MMColor.ink700
            case .smoke: return MMColor.ink500
            case .ginger: return MMColor.coral700
            case .navy: return MMColor.sky700
            case .grape: return MMColor.plum700
            case .moss: return MMColor.mint700
            }
        }
    }

    enum Haircut: String, CaseIterable, Identifiable {
        case clean, tuft, fringe, mohawk, topknot, curls
        var id: String { rawValue }
        var title: String {
            switch self {
            case .clean: return "Clean"
            case .tuft: return "Tuft"
            case .fringe: return "Fringe"
            case .mohawk: return "Mohawk"
            case .topknot: return "Top knot"
            case .curls: return "Curls"
            }
        }
    }

    var mood: Mood = .happy
    var fur: Fur = .midnight
    var haircut: Haircut = .tuft

    init(mood: Mood = .happy, fur: Fur = .midnight, haircut: Haircut = .tuft) {
        self.mood = mood
        self.fur = fur
        self.haircut = haircut
    }

    /// Parses "mood.fur.haircut"; anything else (including empty) means no monkey.
    init?(code: String) {
        let parts = code.split(separator: ".").map(String.init)
        guard parts.count == 3, let mood = Mood(rawValue: parts[0]), let fur = Fur(rawValue: parts[1]),
              let haircut = Haircut(rawValue: parts[2]) else { return nil }
        self.init(mood: mood, fur: fur, haircut: haircut)
    }

    var code: String { "\(mood.rawValue).\(fur.rawValue).\(haircut.rawValue)" }

    static func random() -> MMMonkeyLook {
        MMMonkeyLook(mood: Mood.allCases.randomElement() ?? .happy,
                     fur: Fur.allCases.randomElement() ?? .midnight,
                     haircut: Haircut.allCases.randomElement() ?? .tuft)
    }
}

/// Draws a monkey on a 200×200 grid scaled to `size`. No backdrop: just the face.
struct MMMonkey: View {
    var look: MMMonkeyLook
    var size: CGFloat = 20
    var label: String?
    /// "Not built yet": drawn in `--text-disabled` (ink-300) rather than faded, so it stays on a token.
    var placeholder = false

    var body: some View {
        Canvas { context, canvas in
            context.scaleBy(x: canvas.width / 200, y: canvas.height / 200)
            Self.draw(look, fur: placeholder ? MMColor.textDisabled : look.fur.color, in: &context)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
    }

    private static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
    private static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    private static func line(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b); return p
    }
    private static func curve(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint) -> Path {
        var p = Path(); p.move(to: a); p.addQuadCurve(to: b, control: control); return p
    }

    static func draw(_ look: MMMonkeyLook, fur furColor: Color, in context: inout GraphicsContext) {
        let fur = GraphicsContext.Shading.color(furColor)
        let face = GraphicsContext.Shading.color(MMColor.white)
        let pen = StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)

        // Haircuts that sit above the head go first, so the head covers their base.
        switch look.haircut {
        case .tuft:
            var p = Path()
            p.move(to: pt(94, 44))
            p.addCurve(to: pt(132, 23), control1: pt(96, 26), control2: pt(114, 16))
            p.addCurve(to: pt(110, 44), control1: pt(118, 25), control2: pt(110, 32))
            p.closeSubpath()
            context.fill(p, with: fur)
        case .mohawk:
            var p = Path()
            p.addLines([pt(82, 46), pt(88, 24), pt(97, 40), pt(102, 18), pt(109, 40), pt(118, 24), pt(122, 46)])
            p.closeSubpath()
            context.fill(p, with: fur)
            context.stroke(p, with: fur, style: StrokeStyle(lineWidth: 6, lineJoin: .round))
        case .topknot:
            context.fill(circle(100, 30, 15), with: fur)
        case .curls:
            let curls: [(CGFloat, CGFloat, CGFloat)] = [(70, 54, 16), (88, 42, 17), (112, 42, 17), (130, 54, 16)]
            for (x, y, r) in curls {
                context.fill(circle(x, y, r), with: fur)
            }
        case .clean, .fringe:
            break
        }

        // Ears, head and the light face mask.
        context.fill(circle(36, 100, 23), with: fur)
        context.fill(circle(164, 100, 23), with: fur)
        context.fill(circle(31, 100, 10), with: face)
        context.fill(circle(169, 100, 10), with: face)
        context.fill(circle(100, 100, 62), with: fur)
        context.fill(circle(82, 96, 25), with: face)
        context.fill(circle(118, 96, 25), with: face)
        context.fill(Path(ellipseIn: CGRect(x: 64, y: 96, width: 72, height: 56)), with: face)

        if look.haircut == .fringe {
            var p = Path()
            p.move(to: pt(56, 82))
            p.addQuadCurve(to: pt(100, 86), control: pt(80, 68))
            p.addQuadCurve(to: pt(144, 82), control: pt(120, 68))
            p.addLine(to: pt(144, 60))
            p.addLine(to: pt(56, 60))
            p.closeSubpath()
            context.fill(p, with: fur)
        }

        // Mood: eyes and mouth only, in the fur color.
        func eyes(_ dx: CGFloat = 0) {
            context.fill(circle(84 + dx, 98, 7), with: fur)
            context.fill(circle(116 + dx, 98, 7), with: fur)
        }
        func strokes(_ paths: Path...) { for path in paths { context.stroke(path, with: fur, style: pen) } }
        switch look.mood {
        case .happy:
            eyes()
            strokes(curve(pt(86, 128), pt(100, 138), pt(114, 128)))
        case .grin:
            strokes(curve(pt(76, 100), pt(84, 90), pt(92, 100)),
                 curve(pt(108, 100), pt(116, 90), pt(124, 100)),
                 curve(pt(80, 124), pt(100, 146), pt(120, 124)))
        case .focused:
            eyes()
            strokes(line(pt(73, 84), pt(92, 89)), line(pt(127, 84), pt(108, 89)), line(pt(88, 132), pt(112, 132)))
        case .tired:
            strokes(line(pt(76, 99), pt(92, 99)), line(pt(108, 99), pt(124, 99)),
                 curve(pt(88, 135), pt(100, 128), pt(112, 135)))
        case .side:
            eyes(5)
            strokes(line(pt(88, 133), pt(112, 129)))
        case .tapped:
            eyes()
            strokes(Path(ellipseIn: CGRect(x: 93, y: 116, width: 14, height: 16)))
        }
    }
}

/// Rendered monkeys for use inside `Text`, cached per look, size and scale.
@MainActor
enum MMMonkeyImages {
    private static var cache: [String: Image] = [:]

    static func image(_ look: MMMonkeyLook, size: CGFloat, scale: CGFloat) -> Image? {
        let key = "\(look.code)@\(size)x\(scale)"
        if let hit = cache[key] { return hit }
        let renderer = ImageRenderer(content: MMMonkey(look: look, size: size))
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return nil }
        let image = Image(decorative: cgImage, scale: scale)
        cache[key] = image
        return image
    }
}

/// A monkey that flows inside a sentence: `mmRich(...) + mmMonkeyText(person.monkey)`.
/// Empty when the member hasn't built one.
@MainActor
func mmMonkeyText(_ look: MMMonkeyLook?, size: CGFloat = 18) -> Text {
    guard let look, let image = MMMonkeyImages.image(look, size: size, scale: UITraitCollection.current.displayScale) else {
        return Text("")
    }
    return Text(" ") + Text(image).baselineOffset(-size * 0.22)
}

extension View {
    /// Puts a member's monkey right after this name, about the height of the text.
    /// No monkey yet: just the name.
    func mmMonkey(_ look: MMMonkeyLook?, size: CGFloat = 20) -> some View {
        HStack(spacing: max(4, size * 0.25)) {
            self
            if let look { MMMonkey(look: look, size: size) }
        }
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
