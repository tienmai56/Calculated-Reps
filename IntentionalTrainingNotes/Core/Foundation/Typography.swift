import SwiftUI

// MARK: - Mat Mind Typography
//
// Mat Mind pairs Apple's SF Pro Rounded with Fraunces (variable serif):
//   • TITLES & HEADERS — SF Pro Rounded via Font.system(..., design: .rounded)
//   • DESCRIPTIONS / BODY PROSE — Fraunces, via Font.matMindBody(size:)
//
// Use Fraunces only for prose: reflection notes, task notes, subtitles,
// helper text. Keep buttons, chips, labels, and titles in rounded.
extension Font {
    /// Fraunces for descriptive prose — reflection notes, helper text, subtitles.
    /// Variable font; defaults to regular weight (best for body).
    static func matMindBody(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Fraunces", size: size).weight(weight)
    }

    /// Fraunces italic for emphasis within body prose.
    static func matMindItalic(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Fraunces-Italic", size: size).weight(weight)
    }
}
