import SwiftUI
import UIKit

struct AppColors {
    static let indigo = Color(red: 63/255, green: 61/255, blue: 158/255)
    static let mint = Color(red: 94/255, green: 196/255, blue: 182/255)
    static let coral = Color(red: 242/255, green: 139/255, blue: 130/255)
    static let coralDeep = Color(red: 232/255, green: 106/255, blue: 95/255)
    static let gold = Color(red: 233/255, green: 180/255, blue: 76/255)
    static let goldSoft = Color(red: 245/255, green: 201/255, blue: 122/255)
    static let offWhite = Color(red: 240/255, green: 237/255, blue: 235/255)

    // Warm background: faint warm off-white in light mode, system default in dark
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemBackground : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
    })
    static let secondaryBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondarySystemBackground : UIColor(red: 242/255, green: 241/255, blue: 247/255, alpha: 1)
    })
    static let groupedBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1)
    })
    // Soft lavender card surface that reads as a card against the near-white app background.
    static let cardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondarySystemBackground : UIColor(red: 246/255, green: 245/255, blue: 250/255, alpha: 1)
    })

    // Warm grays for text
    static let label = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .label : UIColor(red: 44/255, green: 42/255, blue: 41/255, alpha: 1)
    })
    static let secondaryLabel = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondaryLabel : UIColor(red: 120/255, green: 117/255, blue: 113/255, alpha: 1)
    })
    static let tertiaryLabel = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .tertiaryLabel : UIColor(red: 165/255, green: 161/255, blue: 155/255, alpha: 1)
    })
    static let separator = Color(.separator)

    // Streak header gradient (Home)
    static let headerGradientTop = Color(red: 124/255, green: 112/255, blue: 214/255)
    static let headerGradientBottom = Color(red: 91/255, green: 82/255, blue: 176/255)

    // Reflection section accents: What worked / Where I got stuck / What I'll try next.
    // Keep UIColor variants so we can derive adaptive tints without iOS 14's UIColor(Color).
    static let indigoUI = UIColor(red: 63/255, green: 61/255, blue: 158/255, alpha: 1)
    static let winGreenUI = UIColor(red: 56/255, green: 178/255, blue: 144/255, alpha: 1)
    static let stuckCoralUI = UIColor(red: 235/255, green: 110/255, blue: 100/255, alpha: 1)
    static let winGreen = Color(winGreenUI)
    static let stuckCoral = Color(stuckCoralUI)
    static let nextIndigo = indigo

    /// Adaptive low-opacity tint (dark mode needs higher opacity to stay visible).
    /// Takes a UIColor to avoid the iOS 14-only `UIColor(Color)` initializer.
    static func tint(_ ui: UIColor, light: Double = 0.10, dark: Double = 0.24) -> Color {
        Color(UIColor { traits in
            ui.withAlphaComponent(CGFloat(traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}
