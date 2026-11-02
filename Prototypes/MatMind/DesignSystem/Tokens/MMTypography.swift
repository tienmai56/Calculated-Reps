import CoreText
import SwiftUI

// Families: display Bricolage Grotesque, body Archivo, mono JetBrains Mono
// (links and codes only, never stats). The TTFs in Resources/Fonts are static
// instances cut from the design system's variable woff2 files.

enum MMWeight {
    case regular, medium, semibold, bold, extraBold
}

enum MMFamily {
    case display, body, mono
}

enum MMFont {
    /// Registers the bundled TTFs once. Runs on first use, so SwiftUI
    /// previews get the fonts too, not just the running app.
    static let registered: Bool = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return !urls.isEmpty
    }()

    static func display(_ size: CGFloat, _ weight: MMWeight = .extraBold) -> Font {
        _ = registered
        let name: String
        switch weight {
        case .extraBold: name = "BricolageGrotesque-ExtraBold"
        case .bold: name = "BricolageGrotesque-Bold"
        case .semibold, .medium, .regular: name = "BricolageGrotesque-SemiBold"
        }
        return .custom(name, size: size)
    }

    static func body(_ size: CGFloat, _ weight: MMWeight = .regular, italic: Bool = false) -> Font {
        _ = registered
        if italic { return .custom("Archivo-Italic", size: size) }
        let name: String
        switch weight {
        case .regular: name = "Archivo-Regular"
        case .medium: name = "Archivo-Medium"
        case .semibold: name = "Archivo-SemiBold"
        case .bold, .extraBold: name = "Archivo-Bold"
        }
        return .custom(name, size: size)
    }

    static func mono(_ size: CGFloat, _ weight: MMWeight = .regular) -> Font {
        _ = registered
        return .custom(weight == .regular || weight == .medium ? "JetBrainsMono-Regular" : "JetBrainsMono-SemiBold", size: size)
    }
}

/// The type scale from DESIGN.md §3.3.
enum MMTextStyle {
    case displayXL, displayL, displayM, titleL, titleM, titleS, bodyL, body, bodyS, caption, overline

    var size: CGFloat {
        switch self {
        case .displayXL: 48
        case .displayL: 36
        case .displayM: 28
        case .titleL: 22
        case .titleM: 18
        case .titleS: 16
        case .bodyL: 17
        case .body: 15
        case .bodyS: 13
        case .caption: 12
        case .overline: 11
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .displayXL: 0.95
        case .displayL: 1
        case .displayM: 1.05
        case .titleL: 1.15
        case .titleM: 1.2
        case .titleS: 1.25
        case .bodyL, .body: 1.45
        case .bodyS: 1.4
        case .caption: 1.3
        case .overline: 1.2
        }
    }

    var family: MMFamily {
        switch self {
        case .displayXL, .displayL, .displayM, .titleL, .titleM, .titleS: .display
        default: .body
        }
    }

    /// Tracking in em: display −0.03, title −0.015, overline +0.1.
    var trackingEm: CGFloat {
        switch self {
        case .displayXL, .displayL, .displayM: -0.03
        case .titleL, .titleM, .titleS: -0.015
        case .overline: 0.1
        default: 0
        }
    }
}

extension View {
    /// Applies a family, size, weight, tracking (em) and line height in one go.
    func mmFont(
        _ family: MMFamily,
        _ size: CGFloat,
        _ weight: MMWeight? = nil,
        tracking: CGFloat? = nil,
        lineHeight: CGFloat? = nil
    ) -> some View {
        let font: Font
        switch family {
        case .display: font = MMFont.display(size, weight ?? .extraBold)
        case .body: font = MMFont.body(size, weight ?? .regular)
        case .mono: font = MMFont.mono(size, weight ?? .regular)
        }
        let em = tracking ?? (family == .display ? -0.02 : 0)
        let lh = lineHeight ?? (family == .display ? 1.15 : 1.4)
        return self
            .font(font)
            .tracking(em * size)
            .lineSpacing(max(0, size * (lh - 1)))
    }

    func mmText(_ style: MMTextStyle, _ weight: MMWeight? = nil) -> some View {
        mmFont(style.family, style.size, weight, tracking: style.trackingEm, lineHeight: style.lineHeight)
    }
}

/// Builds one `Text` from differently styled runs, e.g. a bold name followed by
/// regular copy, without relying on markdown bolding of a custom font.
struct MMRun {
    var text: String
    var font: Font
    var color: Color

    static func body(_ text: String, _ size: CGFloat, _ weight: MMWeight = .regular, color: Color = MMColor.textPrimary) -> MMRun {
        MMRun(text: text, font: MMFont.body(size, weight), color: color)
    }
}

func mmRich(_ runs: [MMRun]) -> Text {
    var all = AttributedString()
    for run in runs {
        var part = AttributedString(run.text)
        part.font = run.font
        part.foregroundColor = run.color
        all += part
    }
    return Text(all)
}
