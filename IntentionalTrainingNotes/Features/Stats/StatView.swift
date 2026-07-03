import SwiftUI

struct StatView: View {
    @ObservedObject var store: NotebookStore

    @State private var selectedMonth: MonthKey = .current
    @State private var didSetInitial = false
    @State private var showMonthPicker = false
    @State private var themeContext: ThemeReflectionsContext?

    private var months: [MonthKey] { store.availableStatMonths() }
    private var stats: MonthStats { store.monthStats(for: selectedMonth) }

    // Bounty gold palette (matches prototype)
    private let goldDeep = Color(red: 138/255, green: 100/255, blue: 7/255)
    private let goldMid = Color(red: 176/255, green: 138/255, blue: 47/255)
    private let goldLabel = Color(red: 184/255, green: 137/255, blue: 14/255)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                monthRail
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
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerSheet(months: months, selected: selectedMonth) { m in
                selectedMonth = m
                showMonthPicker = false
            } onClose: { showMonthPicker = false }
        }
        .sheet(item: $themeContext) { ctx in
            ThemeReflectionsSheet(store: store, context: ctx, onClose: { themeContext = nil })
        }
    }

    // MARK: - Header + month picker

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stat")
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundColor(AppColors.label)
                Text("Your month at a glance")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            Spacer()
            Button(action: { showMonthPicker = true }) {
                HStack(spacing: 6) {
                    Text(selectedMonth.label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(AppColors.cardBackground)
                        .overlay(Capsule().stroke(AppColors.cardBorder, lineWidth: 1))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var railMonths: [MonthKey] {
        let newest = months.first ?? .current
        return (0..<6).reversed().map { newest.adding(months: -$0) }
    }

    private var monthRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(railMonths) { m in
                    let isSel = m == selectedMonth
                    Button(action: { selectedMonth = m }) {
                        Text(m.shortLabel)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(isSel ? .white : AppColors.secondaryLabel)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSel ? AppColors.indigo : AppColors.cardBackground)
                                    .overlay(Capsule().stroke(isSel ? Color.clear : AppColors.cardBorder, lineWidth: 1))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 1)
        }
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
            sectionEyebrow(emoji: "🏆", text: "Bounties", color: goldLabel,
                           trailing: "\(stats.collectedCount) collected · \(stats.activeCount) active")

            VStack(alignment: .leading, spacing: 14) {
                goldHeadline
                ForEach(stats.collectedTrophies) { t in trophyRow(t) }
                ForEach(stats.activeHunts) { h in activeHuntRow(h) }
                if stats.collectedTrophies.isEmpty && stats.activeHunts.isEmpty {
                    Text("No bounties yet this month.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(goldMid)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [Color(red: 254/255, green: 247/255, blue: 230/255),
                                                  Color(red: 253/255, green: 241/255, blue: 214/255)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.gold.opacity(0.35), lineWidth: 1))
        }
    }

    private var goldHeadline: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(stats.collectedCount)")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundColor(goldDeep)
                    Text("collected")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(goldDeep)
                }
                Text(stats.activeCount == 1 ? "1 hunt still active" : "\(stats.activeCount) hunts still active")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(goldMid)
            }
            Spacer()
            HStack(spacing: -8) {
                ForEach(0..<min(3, max(stats.collectedCount, 0)), id: \.self) { _ in
                    Text("🏆")
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white))
                        .overlay(Circle().stroke(AppColors.gold.opacity(0.25), lineWidth: 1))
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
                    .foregroundColor(goldDeep)
                    .lineLimit(1)
                Text("Collected \(DateFormatter.monthDay.string(from: t.collectedDate)) · \(t.days) \(t.days == 1 ? "day" : "days")")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundColor(goldMid)
            }
            Spacer(minLength: 6)
            Text(t.hitRatio)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(goldDeep)
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
                    .foregroundColor(goldDeep)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("Active · started \(DateFormatter.monthDay.string(from: h.startedDate))")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(goldMid)
                    HStack(spacing: 3) {
                        ForEach(0..<max(h.required, 1), id: \.self) { i in
                            Circle()
                                .fill(i < h.hits ? AppColors.gold : AppColors.gold.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            Spacer(minLength: 6)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.gold.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            feedbackList(title: "What's working", subtitle: "from \(stats.reflectionCount) \(stats.reflectionCount == 1 ? "reflection" : "reflections")",
                         icon: "checkmark.circle.fill", color: AppColors.winGreen, themes: stats.workingThemes, kind: .working)
            feedbackList(title: "Where you're stuck", subtitle: "recurring themes",
                         icon: "exclamationmark.circle.fill", color: AppColors.stuckCoral, themes: stats.stuckThemes, kind: .stuck)
        }
    }

    private func feedbackList(title: String, subtitle: String, icon: String, color: Color, themes: [ThemeStat], kind: ThemeReflectionsContext.Kind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionEyebrow(icon: icon, text: title, color: color, trailing: subtitle)
            if themes.isEmpty {
                EmptyDashedState(title: "Nothing tagged yet", subtitle: "Add themes when you reflect to spot patterns.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(themes.prefix(6).enumerated()), id: \.element.id) { idx, theme in
                        Button(action: {
                            themeContext = ThemeReflectionsContext(kind: kind, theme: theme.label,
                                                                   reflectionIds: theme.reflectionIds, accent: color)
                        }) {
                            themeRow(theme, color: color)
                        }
                        .buttonStyle(PlainButtonStyle())
                        if idx < min(themes.count, 6) - 1 {
                            Divider().padding(.leading, 51)
                        }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.cardBorder, lineWidth: 1))
            }
        }
    }

    private func themeRow(_ theme: ThemeStat, color: Color) -> some View {
        HStack(spacing: 11) {
            Text("\(theme.count)×")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .frame(width: 26, height: 26)
                .background(Circle().fill(color.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                if let goalName = theme.goalName {
                    Text(goalName)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.goalColor ?? AppColors.tertiaryLabel)
                }
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.tertiaryLabel)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
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
                .font(.matMindBody(size: 14))
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

// MARK: - Month picker sheet

private struct MonthPickerSheet: View {
    let months: [MonthKey]
    let selected: MonthKey
    let onSelect: (MonthKey) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(months) { m in
                        Button(action: { onSelect(m) }) {
                            HStack {
                                Text(m.label)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(AppColors.label)
                                Spacer()
                                if m == selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppColors.indigo)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.cardBackground))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
            }
            .background(AppColors.groupedBackground.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Choose month", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done", action: onClose).foregroundColor(AppColors.indigo))
        }
    }
}
