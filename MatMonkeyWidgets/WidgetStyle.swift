import CoreText
import SwiftUI
import WidgetKit

// Shared look for both widgets. Colors come from MMColor (Prototypes/MatMind/DesignSystem),
// compiled into this extension so the widgets use the app's exact tokens.

enum WidgetFont {
    /// The extension bundles the same TTFs as the app.
    static let registered: Bool = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        return !urls.isEmpty
    }()

    /// Bricolage Grotesque 800 for counts, times, titles and buttons.
    static func display(_ size: CGFloat) -> Font {
        _ = registered
        return .custom("BricolageGrotesque-ExtraBold", size: size)
    }

    /// Archivo for labels and meta.
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        _ = registered
        let name: String
        switch weight {
        case .medium: name = "Archivo-Medium"
        case .semibold: name = "Archivo-SemiBold"
        case .bold, .heavy, .black: name = "Archivo-Bold"
        default: name = "Archivo-Regular"
        }
        return .custom(name, size: size)
    }
}

/// One palette per appearance: light (default), dark (proposed mapping onto existing
/// tokens), increased contrast, and the system's tinted/clear rendering.
struct WidgetPalette {
    var ground: Color
    var ink: Color
    var ink2: Color
    var ink3: Color
    var trained: Color
    var empty: Color
    var future: Color
    var ring: Color
    var button: Color
    var buttonInk: Color
    var buttonEdge: Color
    var skeleton: Color
    var check: Color
    var dash: Color
    var live: Color
    var danger: Color
    var hairline: Color
    var accented: Bool
    var dark: Bool

    static func resolve(scheme: ColorScheme, contrast: ColorSchemeContrast, mode: WidgetRenderingMode, ground: Color) -> WidgetPalette {
        if mode == .accented || mode == .vibrant {
            let white = Color.white
            return WidgetPalette(ground: .clear, ink: white, ink2: white.opacity(0.8), ink3: white.opacity(0.7),
                                 trained: white, empty: white.opacity(0.18), future: white.opacity(0.4), ring: white,
                                 button: white.opacity(0.24), buttonInk: white, buttonEdge: .clear, skeleton: white.opacity(0.18),
                                 check: white, dash: white.opacity(0.3), live: white, danger: white, hairline: .clear,
                                 accented: true, dark: true)
        }
        if scheme == .dark {
            return WidgetPalette(ground: MMColor.ink900, ink: MMColor.paper, ink2: MMColor.ink200, ink3: MMColor.ink300,
                                 trained: MMColor.coral500, empty: MMColor.ink700, future: MMColor.paper.opacity(0.3), ring: MMColor.paper,
                                 button: contrast == .increased ? MMColor.coral700 : MMColor.coral500, buttonInk: MMColor.white,
                                 buttonEdge: MMColor.coral700, skeleton: MMColor.ink800, check: MMColor.coral300,
                                 dash: MMColor.ink700, live: MMColor.coral500, danger: MMColor.coral300, hairline: .clear,
                                 accented: false, dark: true)
        }
        let high = contrast == .increased
        return WidgetPalette(ground: ground, ink: MMColor.ink900, ink2: high ? MMColor.ink900 : MMColor.ink700,
                             ink3: high ? MMColor.ink700 : MMColor.ink500,
                             trained: high ? MMColor.coral700 : MMColor.coral500, empty: high ? MMColor.ink200 : MMColor.paper3,
                             future: high ? MMColor.ink900.opacity(0.6) : MMColor.borderStrong, ring: MMColor.ink900,
                             button: high ? MMColor.coral700 : MMColor.coral500, buttonInk: MMColor.white,
                             buttonEdge: high ? MMColor.ink900 : MMColor.coral700, skeleton: MMColor.ink100,
                             check: high ? MMColor.coral700 : MMColor.coral600, dash: high ? MMColor.ink400 : MMColor.ink200,
                             live: high ? MMColor.coral700 : MMColor.coral500, danger: high ? MMColor.coral700 : MMColor.danger500,
                             hairline: high ? MMColor.borderStrong : .clear, accented: false, dark: false)
    }
}

extension Image {
    /// Keeps the Silverback in its own colors when the system tints the home screen (iOS 18+).
    func brandFullColor() -> Image {
        if #available(iOS 18.0, *) { return widgetAccentedRenderingMode(.fullColor) }
        return self
    }
}

/// Resolves the palette from the widget's environment: color scheme, Increase Contrast
/// and the home screen's rendering mode (full color, or tinted/clear).
struct PaletteReader<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.widgetRenderingMode) private var mode
    let ground: Color
    @ViewBuilder let content: (WidgetPalette) -> Content

    var body: some View {
        content(WidgetPalette.resolve(scheme: scheme, contrast: contrast, mode: mode, ground: ground))
    }
}

/// Lucide glyphs from the app's icon set (template images).
struct WidgetIcon: View {
    let name: String
    var size: CGFloat = 14
    var color: Color

    var body: some View {
        Image(name).renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

/// The primary pill: coral with the 3pt coral-700 edge, as in the app's MMButton.
struct WidgetPillLabel: View {
    let title: String
    var icon: String? = "plus-bold"
    let palette: WidgetPalette
    var height: CGFloat = 40
    var fontSize: CGFloat = 14
    var fullWidth = true

    var body: some View {
        HStack(spacing: 6) {
            if let icon { WidgetIcon(name: icon, size: fontSize + 1, color: palette.buttonInk) }
            Text(title).font(WidgetFont.display(fontSize)).tracking(-0.015 * fontSize).lineLimit(1).minimumScaleFactor(0.85)
        }
        .foregroundStyle(palette.buttonInk)
        .padding(.horizontal, fullWidth ? 8 : 16)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .frame(height: height)
        .background {
            Capsule().fill(palette.buttonEdge).offset(y: 3)
            Capsule().fill(palette.button)
        }
        .padding(.bottom, palette.accented ? 0 : 3)
        .widgetAccentable()
    }

}

/// The Silverback, from the brand files: the plain mark on light grounds, the sun
/// app-icon tile on ink and on tinted home screens.
struct WidgetLogo: View {
    let size: CGFloat
    let palette: WidgetPalette

    var body: some View {
        Group {
            if palette.dark {
                Image("SilverbackTile").brandFullColor().resizable().scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            } else {
                Image("SilverbackMark").brandFullColor().resizable().scaledToFit().frame(height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Initials on the friend's own hue (the app's avatar fallback).
struct WidgetAvatarStack: View {
    let partners: [WidgetSnapshot.Partner]
    let size: CGFloat
    let palette: WidgetPalette

    var body: some View {
        HStack(spacing: -size * 0.32) {
            ForEach(Array(partners.prefix(3).enumerated()), id: \.offset) { index, partner in
                let hue = FriendHue(rawValue: partner.hue) ?? .mint
                circle(Text(partner.initials), fill: palette.accented ? Color.white.opacity(0.22) : hue.tint,
                       ink: palette.accented ? .white : hue.ink)
                    .zIndex(Double(5 - index))
            }
            if partners.count > 3 {
                circle(Text("+\(partners.count - 3)"),
                       fill: palette.accented ? Color.white.opacity(0.14) : palette.dark ? MMColor.ink800 : MMColor.ink100,
                       ink: palette.accented ? .white : palette.dark ? MMColor.ink200 : MMColor.ink700)
            }
        }
        .accessibilityHidden(true)
    }

    private func circle(_ text: Text, fill: Color, ink: Color) -> some View {
        text.font(WidgetFont.body(size * 0.38, .bold))
            .foregroundStyle(ink)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(palette.accented ? .clear : palette.ground, lineWidth: 2).padding(-2))
    }
}

/// Offline / stale caption: "As of 9:40 AM", or the weekday when it's older than today.
enum WidgetStale {
    static let threshold: TimeInterval = 6 * 3600

    static func caption(updatedAt: Date, now: Date, calendar: Calendar = .current) -> String? {
        guard now.timeIntervalSince(updatedAt) > threshold else { return nil }
        if calendar.isDate(updatedAt, inSameDayAs: now) { return "As of \(WidgetWording.time(updatedAt, calendar: calendar))" }
        let f = DateFormatter(); f.calendar = calendar; f.setLocalizedDateFormatFromTemplate("EEE")
        return "As of \(f.string(from: updatedAt))"
    }
}
