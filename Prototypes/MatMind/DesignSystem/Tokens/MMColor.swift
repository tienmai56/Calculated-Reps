import SwiftUI

// Grip Gorillas color tokens. Values mirror `.claude/design-system-spec.json` and
// `design-system/tokens/colors.css`. UI code should use the semantic aliases;
// the base ramps exist to build them.

extension Color {
    init(mmHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum MMColor {
    // MARK: Paper & ink
    static let paper = Color(mmHex: 0xFAF6EF)
    static let paper2 = Color(mmHex: 0xF3ECE0)
    static let paper3 = Color(mmHex: 0xE9E0D1)
    static let white = Color(mmHex: 0xFFFFFF)

    static let ink900 = Color(mmHex: 0x1D1B18)
    static let ink800 = Color(mmHex: 0x2E2A25)
    static let ink700 = Color(mmHex: 0x4A453D)
    static let ink500 = Color(mmHex: 0x756E62)
    static let ink400 = Color(mmHex: 0x9A9284)
    static let ink300 = Color(mmHex: 0xBDB5A7)
    static let ink200 = Color(mmHex: 0xDDD5C7)
    static let ink100 = Color(mmHex: 0xEDE6DA)

    // MARK: Coral (the one primary)
    static let coral100 = Color(mmHex: 0xFFE4DB)
    static let coral300 = Color(mmHex: 0xFF9C80)
    static let coral500 = Color(mmHex: 0xFF5C39)
    static let coral600 = Color(mmHex: 0xEB4521)
    static let coral700 = Color(mmHex: 0xC2350F)

    // MARK: Friend palette
    static let sun100 = Color(mmHex: 0xFFF1C7)
    static let sun400 = Color(mmHex: 0xFFC93C)
    static let sun600 = Color(mmHex: 0xE0A100)
    static let mint100 = Color(mmHex: 0xD6F5E8)
    static let mint500 = Color(mmHex: 0x1FB27E)
    static let mint700 = Color(mmHex: 0x0E7A55)
    static let sky100 = Color(mmHex: 0xDCE6FF)
    static let sky500 = Color(mmHex: 0x3E6BFF)
    static let sky700 = Color(mmHex: 0x2347C4)
    static let plum100 = Color(mmHex: 0xEDE3FF)
    static let plum500 = Color(mmHex: 0x8D63F0)
    static let plum700 = Color(mmHex: 0x5E3BB5)

    // MARK: Flame (streaks only)
    static let flame500 = Color(mmHex: 0xFF7A1A)
    static let flame100 = Color(mmHex: 0xFFE8D4)
    /// Text on flame-100 (Badge "flame", streak counts on avatars).
    static let flameInk = Color(mmHex: 0xB5520A)

    // MARK: Status
    static let success500 = Color(mmHex: 0x1FB27E)
    static let successTint = Color(mmHex: 0xD6F5E8)
    static let warning500 = Color(mmHex: 0xE0A100)
    static let warningTint = Color(mmHex: 0xFFF1C7)
    static let warningInk = Color(mmHex: 0x8A6200)
    static let danger500 = Color(mmHex: 0xE5383B)
    static let dangerTint = Color(mmHex: 0xFDE1E1)
    static let info500 = Color(mmHex: 0x3E6BFF)
    static let infoTint = Color(mmHex: 0xDCE6FF)

    // MARK: Semantic aliases
    static let bgApp = paper
    static let surfaceBase = paper
    static let surfaceCard = white
    static let surfaceRaised = white
    static let surfaceSunken = paper2
    static let surfaceInput = white
    static let surfaceHover = Color(mmHex: 0x1D1B18, opacity: 0.04)
    static let surfacePress = Color(mmHex: 0x1D1B18, opacity: 0.08)
    static let surfaceOverlay = Color(mmHex: 0x1D1B18, opacity: 0.48)
    static let surfaceInverse = ink900

    static let textPrimary = ink900
    static let textSecondary = ink700
    static let textTertiary = ink500
    static let textDisabled = ink300
    static let textInverse = paper
    static let textOnAccent = white
    static let textAccent = coral600
    static let textLink = coral600

    static let borderSubtle = Color(mmHex: 0x1D1B18, opacity: 0.06)
    static let borderDefault = Color(mmHex: 0x1D1B18, opacity: 0.12)
    static let borderStrong = Color(mmHex: 0x1D1B18, opacity: 0.22)
    static let borderFocus = coral500

    static let controlOff = ink200
    static let controlBorder = ink300

    static let accent = coral500
    static let accentHover = Color(mmHex: 0xFF6F4F)
    static let accentPress = coral600
    static let accentShade = coral700
    static let accentTint = coral100

    /// Off-white used by athletic tape labels and polaroid frames.
    static let tape = Color(mmHex: 0xFFFDF8)
}

/// Each friendship gets one hue and keeps it everywhere
/// (streak belt, pair card, session ticket).
enum FriendHue: String, CaseIterable {
    case coral, sun, mint, sky, plum

    /// Strong color: streak segments, knots.
    var base: Color {
        switch self {
        case .coral: MMColor.coral500
        case .sun: MMColor.sun400
        case .mint: MMColor.mint500
        case .sky: MMColor.sky500
        case .plum: MMColor.plum500
        }
    }

    /// 100 tint: card and stub backgrounds.
    var tint: Color {
        switch self {
        case .coral: MMColor.coral100
        case .sun: MMColor.sun100
        case .mint: MMColor.mint100
        case .sky: MMColor.sky100
        case .plum: MMColor.plum100
        }
    }

    /// Text on the tint.
    var ink: Color {
        switch self {
        case .coral: MMColor.coral700
        case .sun: MMColor.warningInk
        case .mint: MMColor.mint700
        case .sky: MMColor.sky700
        case .plum: MMColor.plum700
        }
    }
}

/// Belt colors appear only to represent rank.
enum BeltRank: String, CaseIterable {
    case white, blue, purple, brown, black, coral, red, grey, yellow, orange, green

    var color: Color {
        switch self {
        case .white: Color(mmHex: 0xFFFFFF)
        case .blue: Color(mmHex: 0x1F5BD6)
        case .purple: Color(mmHex: 0x7A3FC4)
        case .brown: Color(mmHex: 0x7A4E2D)
        case .black: Color(mmHex: 0x16140F)
        case .coral: Color(mmHex: 0xE2563F)
        case .red: Color(mmHex: 0xC8232C)
        case .grey: Color(mmHex: 0x9AA0A6)
        case .yellow: Color(mmHex: 0xF2C230)
        case .orange: Color(mmHex: 0xF28C28)
        case .green: Color(mmHex: 0x2E9E4F)
        }
    }

    /// Black bar, or red for black / coral / red belts.
    var barColor: Color {
        switch self {
        case .black, .coral, .red: Color(mmHex: 0xC8232C)
        default: Color(mmHex: 0x16140F)
        }
    }

    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// The ranks a member can pick for themselves in the account sheet.
    static let adultRanks: [BeltRank] = [.white, .blue, .purple, .brown, .black]
}
