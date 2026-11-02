import SwiftUI

// Prototype-level patterns from `ui_kits/app/Shell.jsx`
// (candidates for promotion into the design system).

// MARK: - Screen

/// Fixed header, scrolling body, optional sticky footer CTA.
struct MMScreen<Header: View, Content: View, Footer: View>: View {
    var background: Color = MMColor.bgApp
    /// Leaves room under the content for the 86pt tab bar.
    var tabPadding = false
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, tabPadding ? 104 : 0)
            }
            .scrollDismissesKeyboard(.interactively)
            if Footer.self != EmptyView.self {
                footer
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background {
                        // The one allowed gradient: a faint fade under sticky footers.
                        LinearGradient(
                            stops: [.init(color: background.opacity(0), location: 0), .init(color: background, location: 0.3)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .ignoresSafeArea(edges: .bottom)
                    }
            }
        }
        .background(background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension MMScreen where Footer == EmptyView {
    init(background: Color = MMColor.bgApp, tabPadding: Bool = false,
         @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.init(background: background, tabPadding: tabPadding, header: header, content: content, footer: { EmptyView() })
    }
}

// MARK: - Header

/// Large 32pt Bricolage title on tabs, centered 18pt on pushed screens.
struct MMHeader<Leading: View, Trailing: View>: View {
    var title: String
    var large = false
    var sub: String?
    var titleColor: Color = MMColor.ink900
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let hasLeading = Leading.self != EmptyView.self
        let hasTrailing = Trailing.self != EmptyView.self
        let centered = !large && hasLeading
        HStack(spacing: 6) {
            leading
            VStack(alignment: centered ? .center : .leading, spacing: 3) {
                Text(title)
                    .mmFont(.display, large ? 32 : 18, tracking: large ? -0.035 : -0.015, lineHeight: 1)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                if let sub {
                    Text(sub).mmFont(.body, 13, .medium, lineHeight: 1).foregroundStyle(MMColor.textTertiary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .padding(.trailing, centered && !hasTrailing ? 44 : 0)
            HStack(spacing: 4) { trailing }
        }
        .padding(.leading, large ? 20 : 10)
        .padding(.trailing, 10)
        .padding(.top, large ? 6 : 4)
        .padding(.bottom, large ? 10 : 8)
        .frame(minHeight: MMLayout.headerHeight)
    }
}

extension MMHeader where Leading == EmptyView {
    init(title: String, large: Bool = false, sub: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, large: large, sub: sub, leading: { EmptyView() }, trailing: trailing)
    }
}

extension MMHeader where Trailing == EmptyView {
    init(title: String, large: Bool = false, sub: String? = nil, titleColor: Color = MMColor.ink900, @ViewBuilder leading: () -> Leading) {
        self.init(title: title, large: large, sub: sub, titleColor: titleColor, leading: leading, trailing: { EmptyView() })
    }
}

extension MMHeader where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, large: Bool = false, sub: String? = nil) {
        self.init(title: title, large: large, sub: sub, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

// MARK: - Eyebrow (section title)

/// 18pt Bricolage section title, 22pt above, 10pt below, 20pt gutter.
struct MMEyebrow<Trailing: View>: View {
    var title: String
    var topPadding: CGFloat = MMLayout.sectionGap
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).mmFont(.display, 18, tracking: -0.02, lineHeight: 1.2).foregroundStyle(MMColor.ink900)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, 10)
    }
}

extension MMEyebrow where Trailing == EmptyView {
    init(_ title: String, topPadding: CGFloat = MMLayout.sectionGap) {
        self.init(title: title, topPadding: topPadding, trailing: { EmptyView() })
    }
}

/// Small grey meta text used at the end of eyebrows ("4 sessions").
struct MMMeta: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).mmFont(.body, 13, .semibold, lineHeight: 1).foregroundStyle(MMColor.textTertiary)
    }
}

// MARK: - Athletic tape label

private struct MMTapeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let pts: [(CGFloat, CGFloat)] = [(0.02, 0), (0.98, 0.04), (1, 0.5), (0.97, 1), (0.03, 0.96), (0, 0.5)]
        for (i, pt) in pts.enumerated() {
            let point = CGPoint(x: r.minX + r.width * pt.0, y: r.minY + r.height * pt.1)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

/// A slightly rotated, ragged-edge off-white strip on photos showing the gym.
struct MMTapeLabel: View {
    var text: String
    var icon: String? = "map-pin"
    var rotation: Double = -3

    var body: some View {
        HStack(spacing: 6) {
            if let icon { MMIcon(icon, size: 13, weight: .bold) }
            Text(text).mmFont(.display, 13, tracking: -0.01, lineHeight: 1)
        }
        .foregroundStyle(MMColor.ink900)
        .padding(.vertical, 6)
        .padding(.leading, 11)
        .padding(.trailing, 12)
        .background(MMColor.tape)
        .clipShape(MMTapeShape())
        .shadow(color: MMColor.ink900.opacity(0.2), radius: 3, x: 0, y: 2)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Tied avatars (the friendship mark)

struct MMPairAvatars: View {
    var a: MMAvatarPerson
    var b: MMAvatarPerson
    var size: CGFloat = 44
    var hue: FriendHue = .coral
    var knot = true
    var ring: Color = MMColor.surfaceCard

    var body: some View {
        HStack(spacing: -size * 0.3) {
            MMAvatar(name: a.name, photo: a.photo, size: size)
                .background(Circle().fill(ring).padding(-3))
            MMAvatar(name: b.name, photo: b.photo, size: size)
                .background(Circle().fill(ring).padding(-3))
        }
        .overlay(alignment: .bottom) {
            if knot {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(hue.base)
                    .frame(width: size * 0.5, height: size * 0.22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ring).padding(-2))
                    .offset(y: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(a.name) and \(b.name)")
    }
}

// MARK: - Photo tile

/// Full-bleed photo in a rounded tile (paper-3 while empty), with overlay content.
struct MMPhotoTile<Overlay: View>: View {
    var photo: String?
    var height: CGFloat
    var corners: RectangleCornerRadii
    @ViewBuilder var overlay: Overlay

    init(photo: String?, height: CGFloat, radius: CGFloat = 22, corners: RectangleCornerRadii? = nil,
         @ViewBuilder overlay: () -> Overlay) {
        self.photo = photo
        self.height = height
        self.corners = corners ?? RectangleCornerRadii(topLeading: radius, bottomLeading: radius, bottomTrailing: radius, topTrailing: radius)
        self.overlay = overlay()
    }

    var body: some View {
        MMColor.paper3
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let photo {
                    MMPhoto(source: photo).scaledToFill()
                }
            }
            .overlay { overlay }
            .clipShape(UnevenRoundedRectangle(cornerRadii: corners, style: .continuous))
            .contentShape(UnevenRoundedRectangle(cornerRadii: corners, style: .continuous))
    }
}

extension MMPhotoTile where Overlay == EmptyView {
    init(photo: String?, height: CGFloat, radius: CGFloat = 22, corners: RectangleCornerRadii? = nil) {
        self.init(photo: photo, height: height, radius: radius, corners: corners, overlay: { EmptyView() })
    }
}

// MARK: - Wordmark

/// Official Silverback artwork with the lowercase Grip Gorillas wordmark.
struct MMWordmark: View {
    var size: CGFloat = 32

    var body: some View {
        HStack(spacing: MMSpace.s4) {
            Image("SilverbackMark")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("grip gorillas").lineLimit(1).minimumScaleFactor(0.75)
                Text(".").foregroundStyle(MMColor.accent)
            }
        }
        .mmFont(.display, size, tracking: -0.04, lineHeight: 1)
        .foregroundStyle(MMColor.ink900)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grip Gorillas")
    }
}

/// "Sarah & Alex", or "Sarah, Alex +2" past `max`.
func mmNames(_ list: [String], max: Int = 2) -> String {
    let firsts = list.map { $0.split(separator: " ").first.map(String.init) ?? $0 }
    if firsts.count <= max { return firsts.joined(separator: " & ") }
    return firsts.prefix(max).joined(separator: ", ") + " +\(firsts.count - max)"
}

/// Asset names are used in previews; live photos are downloaded to private local files.
struct MMPhoto: View {
    let source: String
    var body: some View {
        Group {
            if source.hasPrefix("/"), let image = UIImage(contentsOfFile: source) {
                Image(uiImage: image).resizable()
            } else {
                Image(source).resizable()
            }
        }
    }
}
