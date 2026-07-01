import SwiftUI

struct AppTypography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.medium)
    static let title = Font.system(size: 22, weight: .medium, design: .rounded)
    static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
    static let subhead = Font.system(.subheadline, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let micro = Font.system(size: 10, weight: .medium, design: .rounded)

    // Convenience for custom sizes with rounded design
    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }
}

struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
