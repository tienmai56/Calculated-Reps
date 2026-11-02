import SwiftUI

struct StatView: View {
    @ObservedObject var store: NotebookStore

    @State private var selectedMonth: MonthKey = .current
    @State private var didSetInitial = false
    @State private var monthPickerOpen = false
    @State private var quoteContext: ReflectionQuotesContext?

    private var months: [MonthKey] { store.availableStatMonths() }
    private var stats: MonthStats { store.monthStats(for: selectedMonth) }

    // Bounty coral palette
    private let coralDeep = Color(red: 192/255, green: 60/255, blue: 50/255)
    private let coralMid = Color(red: 214/255, green: 105/255, blue: 96/255)
    private let coralLabel = Color(red: 205/255, green: 78/255, blue: 68/255)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                    .zIndex(monthPickerOpen ? 10 : 0)
                if stats.hasAnyData {
                    trainingSection
                    goalsWorkedSection
                    bountiesSection
                    feedbackSection
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            if !didSetInitial {
                selectedMonth = months.first(where: { store.monthStats(for: $0).hasAnyData }) ?? .current
                didSetInitial = true
            }
        }
        .sheet(item: $quoteContext) { ctx in
            ReflectionQuotesSheet(store: store, context: ctx, onClose: { quoteContext = nil })
        }
    }

    // MARK: - Header + month picker

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            (
                Text("Your ")
                    .foregroundColor(AppColors.secondaryLabel)
                + Text("month")
                    .foregroundColor(AppColors.indigo)
                    .italic()
                + Text(" at a glance")
                    .foregroundColor(AppColors.secondaryLabel)
            )
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { monthPickerOpen.toggle() } }) {
                HStack(spacing: 6) {
                    Text(selectedMonth.label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.secondaryLabel)
                        .rotationEffect(.degrees(monthPickerOpen ? 180 : 0))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(AppColors.cardBackground)
                        .overlay(Capsule().stroke(AppColors.cardBorder, lineWidth: 1))
                )
            }
            .buttonStyle(PlainButtonStyle())
            .fixedSize()
            .overlay(
                ZStack(alignment: .topTrailing) {
                    if monthPickerOpen {
                        // Soft-dismiss backdrop — overlay so it doesn't affect layout.
                        Color.black.opacity(0.001)
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                            .fixedSize()
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { monthPickerOpen = false } }

                        monthDropdown
                            .frame(width: 190)
                            .fixedSize()
                            .offset(x: 0, y: 46)
                    }
                }
                .allowsHitTesting(monthPickerOpen),
                alignment: .topTrailing
            )
        }
    }

    private var monthDropdown: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(months) { m in
                    Button(action: {
                        selectedMonth = m
                        withAnimation(.easeInOut(duration: 0.15)) { monthPickerOpen = false }
                    }) {
                        HStack {
                            Text(m.label)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Spacer()
                            if m == selectedMonth {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppColors.indigo)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    if m != months.last { Divider() }
                }
            }
        }
        .frame(maxHeight: 264)
        .background(AppColors.background)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 6)
    }

    // MARK: - Training

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionEyebrow(icon: "chart.bar.fill", text: "Training", color: AppColors.indigo)

            statCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(stats.sessionCount)")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundColor(AppColors.label)
                        Text("sessions")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        deltaChip
                    }
                    dayBars
                }
            }

            HStack(spacing: 10) {
                metric(value: "\(stats.reflectionCount)", suffix: nil, label: "reflections")
                metric(value: "\(stats.streakWeeks)", suffix: "w", label: "streak")
                metric(value: String(format: "%.1f", stats.avgPacePerWeek), suffix: "/wk", label: "avg pace")
            }
        }
    }

    @ViewBuilder
    private var deltaChip: some View {
        let d = stats.delta
        let prevLabel = MonthStatsFormat.monthAbbrev.string(from: selectedMonth.adding(months: -1).startDate())
        if d == 0 {
            Text("even vs \(prevLabel)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(Color(.systemGray5)))
        } else {
            let up = d > 0
            HStack(spacing: 3) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 9, weight: .heavy))
                Text("\(up ? "+" : "")\(d) vs \(prevLabel)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundColor(up ? AppColors.winGreen : AppColors.stuckCoral)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill((up ? AppColors.winGreen : AppColors.stuckCoral).opacity(0.12)))
        }
    }

    private var dayBars: some View {
        let bars = stats.dayBars
        let maxCount = max(bars.max() ?? 0, 1)
        return VStack(spacing: 5) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(bars.indices, id: \.self) { i in
                    let count = bars[i]
                    let ratio = CGFloat(count) / CGFloat(maxCount)
                    let isToday = stats.todayDayIndex == i + 1
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(count: count, isToday: isToday))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(3, ratio * 74))
                }
            }
            .frame(height: 74, alignment: .bottom)

            HStack(spacing: 3) {
                ForEach(bars.indices, id: \.self) { i in
                    Text((i + 1) % 2 == 1 ? "\(i + 1)" : " ")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
    }

    private func barColor(count: Int, isToday: Bool) -> Color {
        if count == 0 { return AppColors.indigo.opacity(0.12) }
        if isToday { return AppColors.mint }
        return AppColors.indigo
    }

    private func metric(value: String, suffix: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.label)
                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
    }

    // MARK: - Goals worked

    private var goalsWorkedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow(icon: "target", text: "Goals worked", color: AppColors.indigo,
                           trailing: "\(stats.activeGoalCount) active")
            if stats.goalsWorked.isEmpty {
                EmptyDashedState(title: "No sessions this month", subtitle: "Complete a session to see goal volume.")
            } else {
                VStack(spacing: 10) {
                    ForEach(stats.goalsWorked) { g in
                        goalRow(g)
                    }
                }
            }
        }
    }

    private func goalRow(_ g: GoalWorkedStat) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(g.color).frame(width: 4, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .lineLimit(1)
                Text(subtitle(for: g))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(g.sessionCount)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(g.color)
                Text(g.sessionCount == 1 ? "session" : "sessions")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
    }

    private func subtitle(for g: GoalWorkedStat) -> String {
        var parts = ["\(g.taskCount) \(g.taskCount == 1 ? "task" : "tasks")"]
        if let latest = g.latestDate {
            parts.append("latest \(DateFormatter.weekdayShortDate.string(from: latest))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Bounties

    private var bountiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow(emoji: "🏆", text: "Bounties", color: coralLabel,
                           trailing: "\(stats.collectedCount) collected · \(stats.activeCount) active")

            VStack(alignment: .leading, spacing: 14) {
                coralHeadline
                ForEach(stats.collectedTrophies) { t in trophyRow(t) }
                ForEach(stats.activeHunts) { h in activeHuntRow(h) }
                if stats.collectedTrophies.isEmpty && stats.activeHunts.isEmpty {
                    Text("No bounties yet this month.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(coralMid)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color(red: 255/255, green: 244/255, blue: 242/255),
                                                  Color(red: 254/255, green: 236/255, blue: 233/255)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.coral.opacity(0.35), lineWidth: 1))
        }
    }

    private var coralHeadline: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(stats.collectedCount)")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundColor(coralDeep)
                    Text("collected")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(coralDeep)
                }
                Text(stats.activeCount == 1 ? "1 hunt still active" : "\(stats.activeCount) hunts still active")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(coralMid)
            }
            Spacer()
            HStack(spacing: -8) {
                ForEach(0..<min(3, max(stats.collectedCount, 0)), id: \.self) { _ in
                    Text("🏆")
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(AppColors.coral.opacity(0.25), lineWidth: 1))
                }
            }
        }
    }

    private func trophyRow(_ t: CollectedTrophyStat) -> some View {
        HStack(spacing: 12) {
            Text("🏆").font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(t.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(coralDeep)
                    .lineLimit(1)
                Text("Collected \(DateFormatter.monthDay.string(from: t.collectedDate)) · \(t.days) \(t.days == 1 ? "day" : "days")")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(coralMid)
            }
            Spacer(minLength: 6)
            Text(t.hitRatio)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(coralDeep)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.7)))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.55)))
    }

    private func activeHuntRow(_ h: ActiveHuntStat) -> some View {
        HStack(spacing: 12) {
            Text("🎯").font(.system(size: 20))
            VStack(alignment: .leading, spacing: 4) {
                Text(h.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(coralDeep)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("Active · started \(DateFormatter.monthDay.string(from: h.startedDate))")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(coralMid)
                    HStack(spacing: 3) {
                        ForEach(0..<max(h.required, 1), id: \.self) { i in
                            Circle()
                                .fill(i < h.hits ? AppColors.coral : AppColors.coral.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            Spacer(minLength: 6)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.coral.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            feedbackList(title: "What's working", subtitle: "in your own words",
                         icon: "checkmark.circle.fill", color: AppColors.winGreen, quotes: stats.workingQuotes, kind: .working)
            feedbackList(title: "Where you're stuck", subtitle: "in your own words",
                         icon: "exclamationmark.circle.fill", color: AppColors.stuckCoral, quotes: stats.stuckQuotes, kind: .stuck)
        }
    }

    private func feedbackList(title: String, subtitle: String, icon: String, color: Color, quotes: [ReflectionQuote], kind: ReflectionQuotesContext.Kind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow(icon: icon, text: title, color: color, trailing: subtitle)
            if quotes.isEmpty {
                EmptyDashedState(title: "Nothing here yet", subtitle: "Reflect after a session to capture this in your own words.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(quotes.enumerated()), id: \.element.id) { idx, quote in
                        Button(action: {
                            quoteContext = ReflectionQuotesContext(kind: kind, reflectionIds: [quote.reflectionId], accent: color)
                        }) {
                            quoteRow(quote, color: color)
                        }
                        .buttonStyle(PlainButtonStyle())
                        if idx < quotes.count - 1 {
                            Divider().padding(.leading, 30)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.cardBorder, lineWidth: 1))
            }
        }
    }

    private func quoteRow(_ quote: ReflectionQuote, color: Color) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle().fill(color).frame(width: 6, height: 6).padding(.top, 7)
            VStack(alignment: .leading, spacing: 3) {
                Text("\u{201C}\(quote.text)\u{201D}")
                    .font(.gripGorillasBody(size: 15))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 5) {
                    if let goalName = quote.goalName {
                        Text(goalName)
                            .foregroundColor(quote.goalColor ?? AppColors.tertiaryLabel)
                        Text("·").foregroundColor(AppColors.tertiaryLabel)
                    }
                    Text(DateFormatter.monthDay.string(from: quote.date))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            }
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    // MARK: - Shared bits

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("📊").font(.system(size: 46)).opacity(0.6)
            Text("No training yet in \(selectedMonth.label)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
                .multilineTextAlignment(.center)
            Text("Complete and reflect on sessions to see your month come together here.")
                .font(.gripGorillasBody(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
    }

    private func sectionEyebrow(icon: String? = nil, emoji: String? = nil, text: String, color: Color, trailing: String? = nil) -> some View {
        HStack(spacing: 8) {
            if let emoji = emoji {
                Text(emoji).font(.system(size: 14))
            } else if let icon = icon {
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundColor(color)
            }
            Text(text.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(color)
            Spacer(minLength: 6)
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
    }

    private func statCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.cardBorder, lineWidth: 1))
    }
}