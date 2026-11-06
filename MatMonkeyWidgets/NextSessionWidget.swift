import SwiftUI
import WidgetKit

// Next session: "When am I training next, where, and with whom?"
// The Training ticket stub at widget size: day + time, title, gym, then partners.

struct NextEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    var placeholder = false
}

struct NextSessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextEntry {
        NextEntry(date: Date(), snapshot: WidgetSamples.snapshot(now: Date()), placeholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextEntry) -> Void) {
        let stored = WidgetStore.read()
        let snapshot = stored?.signedIn == true || !context.isPreview ? stored : WidgetSamples.snapshot(now: Date())
        completion(NextEntry(date: Date(), snapshot: snapshot))
    }

    /// One entry now and one at every start, end, cancellation expiry and midnight, so the
    /// widget reads "Now", moves on and flips Tomorrow → Today without the app.
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetStore.read()
        var dates = [now] + NextSessionPicker.boundaries(snapshot?.sessions ?? [], after: now).prefix(24)
        if let snapshot, snapshot.signedIn {
            let stale = snapshot.updatedAt.addingTimeInterval(WidgetStale.threshold)
            if stale > now { dates.append(stale) }
        }
        let entries = Array(Set(dates)).sorted().map { NextEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct NextSessionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetStore.nextSessionKind, provider: NextSessionProvider()) { entry in
            NextSessionWidgetView(entry: entry)
        }
        .configurationDisplayName("Next session")
        .description("When and where you’re training next, and who’s coming.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct NextSessionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: NextEntry

    private var small: Bool { family == .systemSmall }
    private var large: Bool { typeSize >= .accessibility1 }

    var body: some View {
        PaletteReader(ground: MMColor.white) { palette in
            let state = Self.state(entry)
            Group {
                switch state {
                case .signedOut:
                    SignedOutPrompt(title: "Sign in to see what’s next", detail: "Your sessions and partners live here.", palette: palette)
                        .padding(16)
                case .empty(let host):
                    EmptyNextSession(invitationHost: host, palette: palette).padding(16)
                case .session(let session, let following, let stale):
                    ticketView(TicketModel(session: session, following: following, stale: stale, now: entry.date), palette)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .redacted(reason: entry.placeholder ? .placeholder : [])
            .containerBackground(for: .widget) { palette.ground }
            .widgetURL(state.destination.url)
        }
    }

    // MARK: State

    enum ViewState {
        case signedOut
        case empty(invitationHost: String?)
        case session(WidgetSnapshot.Session, following: WidgetSnapshot.Session?, stale: String?)

        var destination: WidgetDestination {
            switch self {
            case .signedOut: .home
            case .empty: .plan
            case .session(let s, _, _): .session(s.id)
            }
        }
    }

    static func state(_ entry: NextEntry) -> ViewState {
        guard let snapshot = entry.snapshot, snapshot.signedIn else { return .signedOut }
        guard let session = NextSessionPicker.current(snapshot.sessions, at: entry.date) else {
            return .empty(invitationHost: snapshot.invitationHost)
        }
        let following = session.cancelled ? NextSessionPicker.following(session, in: snapshot.sessions, at: entry.date) : nil
        return .session(session, following: following, stale: WidgetStale.caption(updatedAt: snapshot.updatedAt, now: entry.date))
    }

    /// One tap target, one VoiceOver sentence.
    @ViewBuilder
    private func ticketView(_ ticket: TicketModel, _ palette: WidgetPalette) -> some View {
        Group {
            if small { smallTicket(ticket, palette) } else { mediumTicket(ticket, palette) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ticket.accessibilityLabel)
    }

    // MARK: Medium

    private func mediumTicket(_ t: TicketModel, _ palette: WidgetPalette) -> some View {
        let stub = Self.stubColors(t.session, palette)
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(t.stub.day).font(WidgetFont.display(13)).tracking(0.5)
                Text(t.stub.date).font(WidgetFont.display(40)).tracking(-1.6).padding(.top, 4).padding(.bottom, 2)
                Text(t.stub.month).font(WidgetFont.body(12, .bold))
            }
            .foregroundStyle(stub.ink)
            .frame(width: 84)
            .frame(maxHeight: .infinity)
            .background(stub.fill)
            .widgetAccentable()

            DashLine(vertical: true)
                .stroke(palette.dash, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: 2)
                .padding(.vertical, 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if t.live { Circle().fill(palette.live).frame(width: 8, height: 8).widgetAccentable() }
                    if t.session.cancelled { WidgetIcon(name: "circle-x", size: 16, color: palette.danger) }
                    Text(t.whenMedium).lineLimit(1).minimumScaleFactor(0.8)
                }
                .font(WidgetFont.display(large ? 21 : 19)).tracking(-0.38)
                .foregroundStyle(palette.ink)

                Text(t.session.title)
                    .font(WidgetFont.display(large ? 18 : 16)).tracking(-0.24)
                    .foregroundStyle(t.session.cancelled ? palette.ink3 : palette.ink)
                    .strikethrough(t.session.cancelled)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !t.session.venue.isEmpty {
                    HStack(spacing: 5) {
                        WidgetIcon(name: "map-pin", size: 13, color: palette.ink3)
                        Text(t.session.venue).font(WidgetFont.body(13, .medium)).foregroundStyle(palette.ink2).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                footer(t, palette, avatarSize: 26, text: t.footerMedium, fontSize: 12)
            }
            .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 16))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Small

    private func smallTicket(_ t: TicketModel, _ palette: WidgetPalette) -> some View {
        let stub = Self.stubColors(t.session, palette)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if t.live { Circle().fill(palette.live).frame(width: 7, height: 7) }
                    Text(t.labelSmall).font(WidgetFont.display(13)).lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(t.timeSmall).font(WidgetFont.display(large ? 28 : 26)).tracking(-0.8).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(stub.ink)
            .padding(EdgeInsets(top: 13, leading: 14, bottom: 8, trailing: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(stub.fill)
            .widgetAccentable()

            DashLine(vertical: false)
                .stroke(palette.dash, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(height: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(t.session.title)
                    .font(WidgetFont.display(large ? 16 : 14)).tracking(-0.2)
                    .foregroundStyle(t.session.cancelled ? palette.ink3 : palette.ink)
                    .strikethrough(t.session.cancelled)
                    .lineLimit(large ? 1 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                if !large && !t.session.venue.isEmpty {
                    HStack(spacing: 4) {
                        WidgetIcon(name: "map-pin", size: 12, color: palette.ink3)
                        Text(t.session.venue).font(WidgetFont.body(12, .medium)).foregroundStyle(palette.ink2).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                footer(t, palette, avatarSize: 20, text: t.footerSmall, fontSize: 11)
            }
            .padding(EdgeInsets(top: 8, leading: 14, bottom: 12, trailing: 14))
        }
    }

    @ViewBuilder
    private func footer(_ t: TicketModel, _ palette: WidgetPalette, avatarSize: CGFloat, text: String, fontSize: CGFloat) -> some View {
        HStack(spacing: 8) {
            if t.showsAvatars {
                WidgetAvatarStack(partners: t.session.partners, size: avatarSize, palette: palette)
            }
            if t.stale != nil { WidgetIcon(name: "cloud-off", size: fontSize + 1, color: palette.ink3) }
            if !text.isEmpty {
                Text(text).font(WidgetFont.body(fontSize, .medium))
                    .foregroundStyle(t.session.cancelled ? palette.ink2 : palette.ink3)
                    .lineLimit(1)
            }
        }
    }

    /// The organizer's friend hue (coral when you host); neutral once cancelled.
    static func stubColors(_ s: WidgetSnapshot.Session, _ palette: WidgetPalette) -> (fill: Color, ink: Color) {
        if palette.accented { return (Color.white.opacity(s.cancelled ? 0.08 : 0.2), Color.white.opacity(s.cancelled ? 0.7 : 1)) }
        if s.cancelled { return palette.dark ? (MMColor.ink800, MMColor.ink300) : (MMColor.paper2, palette.ink3) }
        let hue = FriendHue(rawValue: s.hostHue) ?? .coral
        guard palette.dark else { return (hue.tint, hue.ink) }
        switch hue {
        case .sun: return (MMColor.sun600, MMColor.ink900)
        case .coral: return (MMColor.coral700, MMColor.coral100)
        case .mint: return (MMColor.mint700, MMColor.mint100)
        case .sky: return (MMColor.sky700, MMColor.sky100)
        case .plum: return (MMColor.plum700, MMColor.plum100)
        }
    }
}

/// Everything the ticket says, worked out once per entry.
struct TicketModel {
    let session: WidgetSnapshot.Session
    let following: WidgetSnapshot.Session?
    let stale: String?
    let now: Date

    var live: Bool { !session.cancelled && session.start <= now && now < session.end }
    var stub: (day: String, date: String, month: String) { WidgetWording.stub(session.start) }
    private var relative: String { WidgetWording.relativeDay(session.start, now: now) }

    var whenMedium: String {
        if session.cancelled { return session.hostedByMe ? "Cancelled" : "Cancelled by \(session.hostName)" }
        if live { return "Now · until \(WidgetWording.time(session.end))" }
        return "\(relative) · \(WidgetWording.time(session.start))"
    }

    var labelSmall: String {
        if session.cancelled { return "Cancelled · \(Self.shortDay(session.start, now: now))" }
        if live { return "Now · ends" }
        return relative
    }

    var timeSmall: String { WidgetWording.time(live ? session.end : session.start) }

    var showsAvatars: Bool { !session.partners.isEmpty && !session.cancelled && stale == nil }

    var footerMedium: String {
        if let stale { return stale }
        if session.cancelled {
            guard let next = following else { return "Nothing else planned yet" }
            return "Next up: \(Self.shortDay(next.start, now: now)) \(WidgetWording.time(next.start)) · \(next.title)"
        }
        return WidgetWording.partners(session.partners.map(\.firstName))
    }

    var footerSmall: String {
        if let stale { return stale }
        if session.cancelled { return following.map { "Next: \(Self.shortDay($0.start, now: now)) \(WidgetWording.time($0.start))" } ?? "" }
        return session.partners.isEmpty ? "Just you" : ""
    }

    var accessibilityLabel: String {
        let names = session.partners.map(\.firstName)
        let who = names.isEmpty ? "Solo session." : "With \(names.joined(separator: ", "))."
        if session.cancelled {
            let next = following.map { " Next up \(WidgetWording.relativeDay($0.start, now: now)) at \(WidgetWording.time($0.start)), \($0.title)." } ?? ""
            return "Next session cancelled\(session.hostedByMe ? "" : " by \(session.hostName)"): \(session.title), \(relative) at \(WidgetWording.time(session.start)).\(next)"
        }
        let when = live ? "Happening now, until \(WidgetWording.time(session.end))." : "\(relative), \(WidgetWording.time(session.start))."
        let place = session.venue.isEmpty ? "" : " at \(session.venue)"
        return "Next session. \(when) \(session.title)\(place). \(who) Opens session details."
    }

    static func shortDay(_ date: Date, now: Date) -> String {
        let relative = WidgetWording.relativeDay(date, now: now)
        if relative == "Today" || relative == "Tomorrow" { return relative == "Today" ? "Today" : "Tmrw" }
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEE"); return f.string(from: date)
    }
}

/// Nothing booked: the Silverback, a warm line and one coral action.
struct EmptyNextSession: View {
    @Environment(\.widgetFamily) private var family
    let invitationHost: String?
    let palette: WidgetPalette

    var body: some View {
        let small = family == .systemSmall
        let layout = small ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        layout {
            if !(small && invitationHost != nil) { WidgetLogo(size: small ? 30 : 60, palette: palette) }
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing planned yet").font(WidgetFont.display(small ? 16 : 20)).tracking(-0.4)
                    .foregroundStyle(palette.ink).fixedSize(horizontal: false, vertical: true)
                if let invitationHost {
                    // The host's name is all a pending invitation reveals.
                    HStack(spacing: 6) {
                        WidgetIcon(name: "mail", size: 14, color: palette.ink3)
                        Text("\(invitationHost) invited you to train").font(WidgetFont.body(small ? 12 : 13, .medium))
                            .foregroundStyle(palette.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                } else if !small {
                    Text("Rolls are better with friends.").font(WidgetFont.body(13)).foregroundStyle(palette.ink2)
                }
                Spacer(minLength: 4)
                WidgetPillLabel(title: "Plan a training", icon: small ? nil : "calendar-plus-bold", palette: palette,
                                height: small ? 36 : 40, fontSize: small ? 13 : 14, fullWidth: false)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next session. Nothing planned yet.\(invitationHost.map { " \($0) invited you to train." } ?? "") Plan a training opens Mat Monkey.")
    }
}

/// The ticket's dashed tear line.
struct DashLine: Shape {
    var vertical: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        if vertical {
            p.move(to: CGPoint(x: rect.midX, y: rect.minY)); p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
        return p
    }
}
