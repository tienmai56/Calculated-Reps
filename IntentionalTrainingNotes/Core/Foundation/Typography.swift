import SwiftUI

// MARK: - Mat Monkeys Typography
//
// Mat Monkeys uses two typefaces:
//   • MAIN SECTION HEADERS — Fraunces (serif), via Font.matMonkeysSerif(size:) and
//     Font.matMonkeysSerifItalic(size:). Reserved for the ScreenHeader titles only.
//   • EVERYTHING ELSE — SF Pro. Titles/labels/buttons/chips use the rounded
//     design (Font.system(..., design: .rounded)); body prose and descriptions
//     use plain SF Pro (not rounded) via Font.matMonkeysBody(size:).
extension Font {
    /// Body / descriptive prose — reflection text, task notes, subtitles, helper
    /// text. Plain SF Pro (system default design — intentionally NOT rounded).
    static func matMonkeysBody(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight)
    }

    /// Fraunces serif — reserved for the main section headers (ScreenHeader).
    /// Maps the requested weight to a bundled static Fraunces face by PostScript
    /// name so it renders reliably on all supported iOS versions.
    static func matMonkeysSerif(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(frauncesName(weight: weight, italic: false), size: size)
    }

    /// Fraunces italic — the accent word in a section header title.
    static func matMonkeysSerifItalic(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(frauncesName(weight: weight, italic: true), size: size)
    }

    private static func frauncesName(weight: Font.Weight, italic: Bool) -> String {
        let bold = weight == .semibold || weight == .bold || weight == .heavy || weight == .black
        if italic {
            return bold ? "Fraunces-MediumItalic"
                 : (weight == .medium ? "Fraunces-MediumItalic" : "Fraunces-Italic")
        } else {
            return bold ? "Fraunces-SemiBold" : "Fraunces-Regular"
        }
    }
}
