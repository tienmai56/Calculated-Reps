import SwiftUI
import AVKit

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
    var showMark = true
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
            // Top-level headers can opt out of the default Silverback mark.
            if large && showMark && !hasLeading { MMHeaderMark() }
            VStack(alignment: centered ? .center : .leading, spacing: 3) {
                Text(title)
                    .mmFont(.display, large ? 32 : 18, tracking: large ? -0.035 : -0.015, lineHeight: 1)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let sub {
                    Text(sub).mmFont(.body, 13, .medium, lineHeight: 1).foregroundStyle(MMColor.textTertiary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .padding(.trailing, centered && !hasTrailing ? 44 : 0)
            HStack(spacing: 4) { trailing }
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.leading, large ? 20 : 10)
        .padding(.trailing, 10)
        .padding(.top, large ? 6 : 4)
        .padding(.bottom, large ? 10 : 8)
        .frame(minHeight: MMLayout.headerHeight)
    }
}

/// Shared navigation actions for tab and Friends headers, backed by the unread count.
struct MMHeaderActions: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        MMIconButton("search", variant: .filled, label: "Search people") { mm.go(.people) }
        MMIconButton("bell", badge: mm.unreadCount > 0 ? .count(mm.unreadCount) : nil, label: "Notifications") {
            mm.go(.notifications())
        }
        MMIconButton("qr-code", variant: .filled, label: "My code") { mm.go(.qr()) }
    }
}

extension MMHeader where Leading == EmptyView {
    init(title: String, large: Bool = false, showMark: Bool = true, sub: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, large: large, showMark: showMark, sub: sub, leading: { EmptyView() }, trailing: trailing)
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

/// The ragged-edge athletic tape outline (tape labels, goal tapes).
struct MMTapeShape: Shape {
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

/// Official Silverback artwork with the lowercase Mat Monkey wordmark.
/// `markOnly` drops the name for tight spots like tab headers; the full
/// lockup stays on the Welcome screen.
struct MMWordmark: View {
    var size: CGFloat = 32
    var markOnly = false

    var body: some View {
        HStack(spacing: MMSpace.s4) {
            Image("SilverbackMark")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
            if !markOnly {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("mat monkey").lineLimit(1).minimumScaleFactor(0.75)
                    Text(".").foregroundStyle(MMColor.accent)
                }
            }
        }
        .mmFont(.display, size, tracking: -0.04, lineHeight: 1)
        .foregroundStyle(MMColor.ink900)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mat Monkey")
    }
}

/// The Silverback mark as it sits left of a large tab-screen title.
struct MMHeaderMark: View {
    var body: some View {
        MMWordmark(size: 32, markOnly: true)
            .padding(.trailing, 4)
    }
}

/// "Sarah & Alex", or "Sarah, Alex +2" past `max`.
func mmNames(_ list: [String], max: Int = 2) -> String {
    let firsts = list.map { $0.split(separator: " ").first.map(String.init) ?? $0 }
    if firsts.count <= max { return firsts.joined(separator: " & ") }
    return firsts.prefix(max).joined(separator: ", ") + " +\(firsts.count - max)"
}

private struct AllowsSamplePhotosKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var allowsSamplePhotos: Bool {
        get { self[AllowsSamplePhotosKey.self] }
        set { self[AllowsSamplePhotosKey.self] = newValue }
    }
}

/// Live photos must be private local files. Bundled photos require explicit preview mode.
struct MMPhoto: View {
    let source: String
    @State private var videoPoster: UIImage?
    @Environment(\.allowsSamplePhotos) private var allowsSamplePhotos

    static func image(source: String, allowsSamplePhotos: Bool) -> UIImage? {
        if source.hasPrefix("/") {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: source), options: .mappedIfSafe) else { return nil }
            return UIImage(data: data)
        }
        return allowsSamplePhotos ? UIImage(named: source) : nil
    }

    var body: some View {
        Group {
            if SessionMedia.isVideo(source) {
                if let videoPoster { Image(uiImage: videoPoster).resizable() }
                else { MMColor.paper3 }
            } else if let image = Self.image(source: source, allowsSamplePhotos: allowsSamplePhotos) {
                Image(uiImage: image).resizable()
            } else {
                Color.clear
            }
        }
        .task(id: source) {
            guard SessionMedia.isVideo(source) else { return }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: source)))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 600, height: 600)
            if let frame = try? await generator.image(at: .zero) { videoPoster = UIImage(cgImage: frame.image) }
        }
    }
}

// MARK: - Session media

/// One preview shared by the composer, Activity, detail and training photos.
/// Video files are private local downloads; playback is always an explicit tap.
struct MMSessionMediaTile: View {
    let source: String
    var height: CGFloat = 300
    var radius: CGFloat = 20
    @State private var poster: UIImage?
    @State private var duration = ""
    @State private var playing = false

    var body: some View {
        Group {
            if SessionMedia.isVideo(source) {
                Button { playing = true } label: {
                    MMColor.paper3
                        .overlay { if let poster { Image(uiImage: poster).resizable().scaledToFill() } }
                        .frame(height: height).clipped()
                        .overlay {
                            MMIcon("play", size: height < 100 ? 20 : 32, filled: true, color: .white)
                                .padding(height < 100 ? 8 : 16).background(.black.opacity(0.45), in: Circle())
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if !duration.isEmpty {
                                Text(duration).mmFont(.body, 12, .semibold).foregroundStyle(.white)
                                    .padding(5).background(.black.opacity(0.6), in: Capsule()).padding(8)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: radius))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play video" + (duration.isEmpty ? "" : ", " + duration))
                .task(id: source) {
                    let asset = AVURLAsset(url: URL(fileURLWithPath: source))
                    let generator = AVAssetImageGenerator(asset: asset)
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: 1200, height: 1200)
                    if let frame = try? await generator.image(at: .zero) { poster = UIImage(cgImage: frame.image) }
                    if let time = try? await asset.load(.duration), time.seconds.isFinite {
                        let seconds = max(0, Int(time.seconds))
                        duration = String(format: "%d:%02d", seconds / 60, seconds % 60)
                    }
                }
                .sheet(isPresented: $playing) { MMSessionVideoPlayer(source: source) }
            } else {
                MMPhotoTile(photo: source, height: height, radius: radius)
                    .accessibilityLabel("Training photo")
            }
        }
    }
}

private struct MMSessionVideoPlayer: View {
    let source: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .onAppear { player = AVPlayer(url: URL(fileURLWithPath: source)); player?.play() }
                .onDisappear { player?.pause(); player = nil }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct MMSessionGallery: View {
    let sources: [String]
    var height: CGFloat = 300
    var gym: String = ""
    var onPhotoTap: (() -> Void)? = nil
    var onPhotoDoubleTap: (() -> Void)? = nil
    @State private var page = 0

    var body: some View {
        if !sources.isEmpty {
            VStack(spacing: 8) {
                TabView(selection: $page) {
                    ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                        MMSessionMediaTile(source: source, height: height)
                            .overlay {
                                if !SessionMedia.isVideo(source) {
                                    Color.clear.contentShape(Rectangle())
                                        .onTapGesture(count: 2) { onPhotoDoubleTap?() }
                                        .onTapGesture { onPhotoTap?() }
                                }
                            }
                            .overlay(alignment: .bottomLeading) {
                                if !gym.isEmpty { MMTapeLabel(text: gym).padding(12).allowsHitTesting(false) }
                            }
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: height)
                .overlay(alignment: .topTrailing) {
                    if sources.count > 1 {
                        Text("\(min(page + 1, sources.count))/\(sources.count)")
                            .mmFont(.body, 13, .semibold).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule()).padding(12)
                            .allowsHitTesting(false)
                    }
                }
                if sources.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(sources.indices, id: \.self) { index in
                            Button { page = index } label: {
                                Circle().fill(index == page ? MMColor.accent : MMColor.ink200).frame(width: 6, height: 6)
                                    .frame(width: MMLayout.tapTarget, height: MMLayout.tapTarget)
                            }
                            .accessibilityLabel("Media \(index + 1) of \(sources.count)")
                            .accessibilityAddTraits(index == page ? .isSelected : [])
                        }
                    }
                }
            }
            .onChange(of: sources) { _, _ in page = min(page, max(0, sources.count - 1)) }
        }
    }
}
