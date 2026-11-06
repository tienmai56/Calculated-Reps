import SwiftUI
import WidgetKit

// Your rhythm: "How much have I trained lately?", and log it in one tap.
// Small shows the last 5 weeks, medium 12, in the same Mon–Sun grammar as Stats › Your rhythm.

struct RhythmEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    var placeholder = false
}

struct RhythmProvider: TimelineProvider {
    func placeholder(in context: Context) -> RhythmEntry {
        RhythmEntry(date: Date(), snapshot: WidgetSamples.snapshot(now: Date()), placeholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (RhythmEntry) -> Void) {
        let stored = WidgetStore.read()
        // The gallery previews the person's own data when there is some.
        let snapshot = stored?.signedIn == true || !context.isPreview ? stored : WidgetSamples.snapshot(now: Date())
        completion(RhythmEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RhythmEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetStore.read()
        let calendar = Calendar.current
        var dates: Set<Date> = [now]
        var midnight = calendar.startOfDay(for: now)
        for _ in 0..<2 {
            midnight = calendar.date(byAdding: .day, value: 1, to: midnight)!
            dates.insert(midnight)
        }
        if let snapshot, snapshot.signedIn {
            let stale = snapshot.updatedAt.addingTimeInterval(WidgetStale.threshold)
            if stale > now { dates.insert(stale) }
        }
        let entries = dates.sorted().map { RhythmEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct RhythmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetStore.rhythmKind, provider: RhythmProvider()) { entry in
            RhythmWidgetView(entry: entry)
        }
        .configurationDisplayName("Your rhythm")
        .description("How much you’ve trained lately, and a one-tap way to log it.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct RhythmWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: RhythmEntry

    private var small: Bool { family == .systemSmall }
    private var large: Bool { typeSize >= .accessibility1 }
    private var signedIn: Bool { entry.snapshot?.signedIn == true }

    var body: some View {
        PaletteReader(ground: MMColor.paper) { palette in
            Group {
                if signedIn, let snapshot = entry.snapshot {
                    content(snapshot, palette)
                } else {
                    SignedOutPrompt(title: "Sign in to see your rhythm", detail: "Your log stays private to you.", palette: palette)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .redacted(reason: entry.placeholder ? .placeholder : [])
            .containerBackground(for: .widget) { palette.ground }
            .widgetURL((signedIn ? WidgetDestination.rhythm : .home).url)
        }
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot, _ palette: WidgetPalette) -> some View {
        let rhythm = snapshot.rhythm ?? WidgetSnapshot.Rhythm(quickLogAvailable: true, entries: [:])
        let summary = RhythmSummary(entries: rhythm.entries, now: entry.date)
        let fresh = rhythm.entries.values.allSatisfy { $0 == 0 }
        let stale = WidgetStale.caption(updatedAt: snapshot.updatedAt, now: entry.date)
        let label = Self.accessibilityLabel(summary: summary, fresh: fresh, entries: rhythm.entries, now: entry.date, weeks: small ? 5 : 12)

        if small {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    smallCount(summary, fresh: fresh, stale: stale, palette: palette)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(label)
                    if !large {
                        RhythmHeatmap(entries: rhythm.entries, now: entry.date, weeks: 5, cell: 9, gap: 2, labels: false, palette: palette)
                    }
                }
                Spacer(minLength: 0)
                action(rhythm, palette: palette, compact: true)
            }
        } else {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    mediumCount(summary, fresh: fresh, stale: stale, entries: rhythm.entries, palette: palette)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(label)
                    Spacer(minLength: 6)
                    action(rhythm, palette: palette, compact: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RhythmHeatmap(entries: rhythm.entries, now: entry.date, weeks: 12, cell: 10, gap: 3, labels: true, palette: palette)
            }
        }
    }

    // MARK: Count blocks

    private func smallCount(_ s: RhythmSummary, fresh: Bool, stale: String?, palette: WidgetPalette) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if fresh {
                Text("Your rhythm starts with one log.")
                    .font(WidgetFont.display(large ? 17 : 14)).tracking(-0.2)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(s.sessionsThisMonth)")
                    .font(WidgetFont.display(large ? 44 : 34)).tracking(-1.3)
                    .foregroundStyle(palette.ink)
                    .contentTransition(.numericText())
                    .widgetAccentable()
                Text(WidgetWording.sessions(s.sessionsThisMonth))
                    .font(WidgetFont.display(large ? 17 : 13)).tracking(-0.2)
                    .foregroundStyle(palette.ink)
                Text("this month")
                    .font(WidgetFont.body(large ? 15 : 12, .semibold))
                    .foregroundStyle(palette.ink2)
            }
            if let stale {
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    WidgetIcon(name: "cloud-off", size: 12, color: palette.ink3)
                    Text(stale.replacingOccurrences(of: "As of", with: "as of"))
                        .font(WidgetFont.body(11)).foregroundStyle(palette.ink3).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
    }

    private func mediumCount(_ s: RhythmSummary, fresh: Bool, stale: String?, entries: [String: Int], palette: WidgetPalette) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if fresh {
                Text("Your rhythm starts with one log.")
                    .font(WidgetFont.display(large ? 19 : 16)).tracking(-0.24)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(s.sessionsThisMonth)")
                        .font(WidgetFont.display(large ? 44 : 38)).tracking(-1.5)
                        .contentTransition(.numericText())
                        .widgetAccentable()
                    Text(WidgetWording.sessions(s.sessionsThisMonth))
                        .font(WidgetFont.display(large ? 19 : 16)).tracking(-0.24)
                }
                .foregroundStyle(palette.ink)
                Text("this month")
                    .font(WidgetFont.body(large ? 15 : 12, .semibold))
                    .foregroundStyle(palette.ink2)
                if !large, let line = Self.daysLine(s, stale: stale, hasHistory: !entries.isEmpty) {
                    HStack(spacing: 4) {
                        if s.today > 0 && stale == nil { WidgetIcon(name: "check-bold", size: 12, color: palette.check).widgetAccentable() }
                        if stale != nil { WidgetIcon(name: "cloud-off", size: 12, color: palette.ink3) }
                        Text(line).font(WidgetFont.body(12)).foregroundStyle(palette.ink3).lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .padding(.top, 1)
                }
            }
        }
    }

    /// Sessions vs days, in words: "on 4 days", "5 days, today included", "5 days · twice today".
    static func daysLine(_ s: RhythmSummary, stale: String?, hasHistory: Bool) -> String? {
        if s.sessionsThisMonth == 0 { return hasHistory ? "Rest is part of training." : nil }
        let days = "\(s.daysThisMonth) \(WidgetWording.days(s.daysThisMonth))"
        if let stale { return "\(days) · \(stale.replacingOccurrences(of: "As of", with: "as of"))" }
        switch s.today {
        case 0: return "on \(days)"
        case 1: return "\(days), today included"
        case 2: return "\(days) · twice today"
        default: return "\(days) · \(s.today) times today"
        }
    }

    // MARK: Action

    @ViewBuilder
    private func action(_ rhythm: WidgetSnapshot.Rhythm, palette: WidgetPalette, compact: Bool) -> some View {
        if rhythm.quickLogAvailable {
            // Opens the app on today's Quick Log. Nothing is saved from the widget.
            Button(intent: LogTrainingIntent()) {
                WidgetPillLabel(title: "Log training", palette: palette, height: 40, fontSize: large ? 16 : 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log training")
            .accessibilityHint("Opens Mat Monkey")
        } else {
            Text(compact ? "Quick log isn’t on your account yet." : "Quick log isn’t on your account yet. Tap to see your history.")
                .font(WidgetFont.body(compact ? 11 : 12))
                .foregroundStyle(palette.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func accessibilityLabel(summary s: RhythmSummary, fresh: Bool, entries: [String: Int], now: Date, weeks: Int) -> String {
        if fresh { return "Your rhythm. No training logged yet." }
        let calendar = WidgetCalendar.calendar()
        let trained = WidgetCalendar.weeks(weeks, endingAt: now, calendar: calendar).joined()
            .filter { calendar.startOfDay(for: $0) <= calendar.startOfDay(for: now) && (entries[WidgetCalendar.key($0, calendar: calendar)] ?? 0) > 0 }.count
        let today = s.today == 0 ? "Nothing logged today yet." : s.today == 1 ? "Trained today." : "Trained \(s.today) times today."
        return "Your rhythm. \(s.sessionsThisMonth) \(WidgetWording.sessions(s.sessionsThisMonth)) this month, on \(s.daysThisMonth) \(WidgetWording.days(s.daysThisMonth)). \(trained) trained days in the last \(weeks) weeks. \(today)"
    }
}

/// Mon–Sun columns, oldest on the left. Coral = trained (one fill however many sessions),
/// paper-3 = no entry, outline = future, ring = today.
struct RhythmHeatmap: View {
    let entries: [String: Int]
    let now: Date
    let weeks: Int
    let cell: CGFloat
    let gap: CGFloat
    let labels: Bool
    let palette: WidgetPalette

    private static let weekdays = ["M", "", "W", "", "F", "", "S"]

    var body: some View {
        let calendar = WidgetCalendar.calendar()
        let grid = WidgetCalendar.weeks(weeks, endingAt: now, calendar: calendar)
        HStack(alignment: .top, spacing: 4) {
            if labels {
                VStack(alignment: .leading, spacing: gap) {
                    Color.clear.frame(width: 9, height: 13)
                    ForEach(0..<7, id: \.self) { i in
                        Text(Self.weekdays[i]).font(WidgetFont.body(8.5, .semibold)).foregroundStyle(palette.ink3)
                            .frame(width: 9, height: cell, alignment: .leading)
                    }
                }
            }
            HStack(alignment: .top, spacing: gap) {
                ForEach(grid.indices, id: \.self) { w in
                    VStack(alignment: .leading, spacing: gap) {
                        if labels {
                            Text(monthLabel(grid, w, calendar: calendar)).font(WidgetFont.body(9, .semibold)).foregroundStyle(palette.ink3)
                                .fixedSize().frame(width: cell, height: 13, alignment: .leading)
                        }
                        ForEach(grid[w], id: \.self) { day in dayCell(day, calendar: calendar) }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func monthLabel(_ grid: [[Date]], _ w: Int, calendar: Calendar) -> String {
        let month = calendar.component(.month, from: grid[w][0])
        guard w == 0 || month != calendar.component(.month, from: grid[w - 1][0]) else { return "" }
        let f = DateFormatter(); f.calendar = calendar; f.setLocalizedDateFormatFromTemplate("MMM")
        return f.string(from: grid[w][0])
    }

    private func dayCell(_ day: Date, calendar: Calendar) -> some View {
        let radius = cell * 0.28
        let future = calendar.startOfDay(for: day) > calendar.startOfDay(for: now)
        let trained = !future && (entries[WidgetCalendar.key(day, calendar: calendar)] ?? 0) > 0
        let today = calendar.isDate(day, inSameDayAs: now)
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(future ? Color.clear : trained ? palette.trained : palette.empty)
            .overlay {
                if future { RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(palette.future, lineWidth: 1) }
            }
            .frame(width: cell, height: cell)
            .overlay {
                if today {
                    RoundedRectangle(cornerRadius: radius + 1.5, style: .continuous)
                        .strokeBorder(palette.ring, lineWidth: 1.5).padding(-2.5)
                }
            }
            .widgetAccentable(trained)
    }
}

/// Shared by both widgets when nobody is signed in: the Silverback and a way in.
struct SignedOutPrompt: View {
    @Environment(\.widgetFamily) private var family
    let title: String
    let detail: String
    let palette: WidgetPalette

    var body: some View {
        let small = family == .systemSmall
        let layout = small ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        layout {
            WidgetLogo(size: small ? 32 : 56, palette: palette)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(WidgetFont.display(small ? 15 : 18)).tracking(-0.25).foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !small { Text(detail).font(WidgetFont.body(13)).foregroundStyle(palette.ink2) }
                Spacer(minLength: 4)
                WidgetPillLabel(title: "Sign in", icon: nil, palette: palette, height: 36, fontSize: 14, fullWidth: false)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). Opens Mat Monkey.")
    }
}
