import SwiftUI

struct DayTrendPoint {
    let date: Date
    let sessionCount: Int
    let mood: Mood?
}

// MARK: - Section Header

struct SectionHeader: View {
    var icon: String
    var title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.clear)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [AppColors.indigo, AppColors.indigo.opacity(0.55)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .mask(
                        Image(systemName: icon)
                            .font(.caption)
                    )
                )
            Text(title.uppercased())
                .font(.system(size: 11, design: .rounded))
                .tracking(0.8)
                .fontWeight(.medium)
                .foregroundColor(AppColors.label)
        }
    }
}

// MARK: - Period Tab Bar

struct HomePeriodTabBar: View {
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 0) {
            segmentButton("Week", value: "week")
            segmentButton("Month", value: "month")
        }
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }

    private func segmentButton(_ label: String, value: String) -> some View {
        Button(action: { selected = value }) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(selected == value ? AppColors.label : AppColors.tertiaryLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected == value ? AppColors.background : Color.clear)
                .cornerRadius(7)
                .padding(2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat Row

struct HomeStatRow: View {
    let value: Int
    let description: String
    let systemName: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemName)
                .font(.matMindBody(size: 16))
                .foregroundColor(iconColor)
            Text("\(value)")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.label)
            Text(description)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Next Session Section

struct HomeNextSessionSection: View {
    @ObservedObject var store: NotebookStore
    let sessions: [PlannedSession]
    var onOpenGoalTasks: (String) -> Void
    var onReflect: (String) -> Void
    var onPlanTraining: () -> Void
    @State private var expandedGoalIds: Set<String> = []

    private var cal: Calendar { Calendar.current }

    private var dateLabel: String {
        guard let session = sessions.first else { return "" }
        if cal.isDateInToday(session.date) { return "Today" }
        if cal.isDateInTomorrow(session.date) { return "Tomorrow" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: session.date)
    }

    /// Groups sessions by goalId, preserving order of first appearance.
    private var groupedByGoal: [(goalId: String, sessions: [PlannedSession])] {
        var order: [String] = []
        var map: [String: [PlannedSession]] = [:]
        for s in sessions {
            if map[s.goalId] == nil { order.append(s.goalId) }
            map[s.goalId, default: []].append(s)
        }
        return order.map { (goalId: $0, sessions: map[$0]!) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row outside cards
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.indigo, AppColors.indigo.opacity(0.55)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .mask(
                                Image(systemName: "calendar")
                                    .font(.caption)
                            )
                        )
                    Text("NEXT SESSION")
                        .font(.system(size: 11, design: .rounded))
                        .tracking(0.8)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.label)
                }
                Spacer()
                if !sessions.isEmpty {
                    Text(dateLabel)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }

            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Text("Nothing planned yet.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: onPlanTraining) {
                        Text("Plan Training")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.indigo)
                            .cornerRadius(8)
                    }
                }
                .padding(12)
                .cardBackground()
            } else {
                ForEach(groupedByGoal, id: \.goalId) { group in
                    let goal = store.goal(id: group.goalId)
                    let goalColor = goal?.goalColor ?? AppColors.indigo
                    let isExpanded = expandedGoalIds.contains(group.goalId)

                    let taskIds = group.sessions.flatMap { $0.taskIds }
                    let tasks: [TrainingTask] = {
                        var seen = Set<String>()
                        var result = [TrainingTask]()
                        for id in taskIds {
                            if seen.insert(id).inserted, let t = store.task(id: id) {
                                result.append(t)
                            }
                        }
                        return result
                    }()

                    VStack(alignment: .leading, spacing: 0) {
                        // Header row — matches Goal card design
                        HStack(spacing: 10) {
                            // Expand/collapse chevron
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedGoalIds.contains(group.goalId) {
                                        expandedGoalIds.remove(group.goalId)
                                    } else {
                                        expandedGoalIds.insert(group.goalId)
                                    }
                                }
                            }) {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.label)
                                    .frame(width: 20, height: 20)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Goal icon
                            GoalIconImage(name: goal?.iconName ?? "figure.martial.arts", color: goalColor, size: 38)

                            // Title + subtitle
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal?.name ?? "No goal")
                                    .font(.headline)
                                    .foregroundColor(AppColors.label)
                                let count = tasks.count
                                Text("\(count) \(count == 1 ? "task" : "tasks")")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.secondaryLabel)
                            }
                            Spacer()

                            // Reflect pencil icon
                            Button(action: {
                                if let first = group.sessions.first {
                                    onReflect(first.id)
                                }
                            }) {
                                ReflectPencilIcon(size: 22, color: .primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedGoalIds.contains(group.goalId) {
                                    expandedGoalIds.remove(group.goalId)
                                } else {
                                    expandedGoalIds.insert(group.goalId)
                                }
                            }
                        }

                        // Expanded task pills
                        if isExpanded && !tasks.isEmpty {
                            WrappingHStack(items: tasks) { task in
                                PlanTaskTagView(task: task, goalColor: goalColor)
                            }
                            .padding(.leading, 80)
                            .padding(.trailing, 16)
                            .padding(.bottom, 12)
                        }
                    }
                    .cardBackground()
                }
            }
        }
    }
}

// MARK: - Working On Section

struct HomeWorkingOnSection: View {
    @ObservedObject var store: NotebookStore
    let goals: [TrainingGoal]
    var onAddGoal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row outside card
            SectionHeader(icon: "target", title: "WORKING ON")

            if goals.isEmpty {
                VStack(spacing: 12) {
                    Text("No goals yet.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: onAddGoal) {
                        Text("Add Goal")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.indigo)
                            .cornerRadius(8)
                    }
                }
                .padding(12)
                .cardBackground()
            } else {
                ForEach(goals) { goal in
                    let tasks = store.tasks(forGoal: goal.id)
                    HStack(alignment: .top, spacing: 12) {
                        // Left icon
                        GoalIconImage(name: goal.iconName, color: goal.goalColor, size: 56)

                        // Content
                        VStack(alignment: .leading, spacing: 6) {
                            Text(goal.name)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppColors.label)
                                .lineLimit(2)

                            if !tasks.isEmpty {
                                WrappingHStack(items: tasks) { task in
                                    PlanTaskTagView(task: task, goalColor: goal.goalColor)
                                }
                            } else {
                                Text("No tasks yet.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.secondaryLabel)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .cardBackground()
                }
            }
        }
    }
}

// MARK: - Snippet Section

struct HomeSnippetSection: View {
    let title: String
    let icon: String
    let snippets: [String]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row — outside the card, matching Next Session pattern
            SectionHeader(icon: icon, title: title)

            // Card content
            if snippets.isEmpty {
                Text(emptyText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .cardBackground()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(snippets.enumerated()), id: \.offset) { _, snippet in
                        Text("• " + snippet)
                            .font(.matMindBody(size: 15))
                            .foregroundColor(AppColors.label)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .cardBackground()
            }
        }
    }
}

// MARK: - Training Trend Section

struct HomeTrendSection: View {
    let data: [DayTrendPoint]
    let isWeek: Bool
    let periodStart: Date

    private var cal: Calendar { Calendar.current }

    private var maxCount: Int {
        let m = data.map { $0.sessionCount }.max() ?? 0
        return max(m, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "chart.xyaxis.line", title: "TRAINING TREND")

            if data.isEmpty {
                Text("No data yet.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryLabel)
            } else {
                HomeTrendGraph(data: data, maxCount: maxCount, isWeek: isWeek, periodStart: periodStart)
                    .frame(height: 120)
            }
        }
    }
}

struct HomeTrendGraph: View {
    let data: [DayTrendPoint]
    let maxCount: Int
    let isWeek: Bool
    let periodStart: Date

    private var cal: Calendar { Calendar.current }

    var body: some View {
        GeometryReader { geo in
            let graphTop: CGFloat = 20
            let graphBottom: CGFloat = 20
            let graphHeight = geo.size.height - graphTop - graphBottom
            let count = max(data.count, 1)
            let stepX = geo.size.width / CGFloat(count)
            let barWidth = max(stepX * 0.4, 4)

            ZStack(alignment: .topLeading) {
                // Horizontal grid lines
                ForEach(0..<4, id: \.self) { i in
                    let y = graphTop + graphHeight * CGFloat(i) / 3
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color(.systemGray5), lineWidth: 0.5)
                }

                // Y-axis labels
                ForEach(0..<4, id: \.self) { i in
                    let value = maxCount - (maxCount * i / 3)
                    let y = graphTop + graphHeight * CGFloat(i) / 3
                    Text("\(value)")
                        .font(.system(size: 7, design: .rounded))
                        .foregroundColor(Color(.systemGray3))
                        .position(x: 10, y: y)
                }

                // Bars
                ForEach(Array(data.enumerated()), id: \.offset) { i, point in
                    let x = stepX * CGFloat(i) + stepX / 2
                    let yRatio = CGFloat(point.sessionCount) / CGFloat(maxCount)
                    let barH = graphHeight * yRatio
                    let y = graphTop + graphHeight - barH

                    if point.sessionCount > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.darkGray))
                            .frame(width: barWidth, height: barH)
                            .position(x: x, y: y + barH / 2)
                    }

                    // Mood emoji above bar
                    if let mood = point.mood {
                        Text(mood.glyph)
                            .font(.system(size: 12, design: .rounded))
                            .position(x: x, y: y - 10)
                    }
                }

                // Trend line connecting bars
                Path { path in
                    for (i, point) in data.enumerated() {
                        let x = stepX * CGFloat(i) + stepX / 2
                        let yRatio = CGFloat(point.sessionCount) / CGFloat(maxCount)
                        let y = graphTop + graphHeight * (1 - yRatio)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                // Day labels
                ForEach(Array(data.enumerated()), id: \.offset) { i, point in
                    let x = stepX * CGFloat(i) + stepX / 2
                    Text(dayLabel(index: i, date: point.date))
                        .font(.system(size: 8, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .position(x: x, y: geo.size.height - 6)
                }
            }
        }
    }

    private func dayLabel(index: Int, date: Date) -> String {
        if isWeek {
            let labels = ["M", "T", "W", "T", "F", "S", "S"]
            return index < labels.count ? labels[index] : ""
        } else {
            let day = cal.component(.day, from: date)
            return day % 5 == 1 || day == 1 ? "\(day)" : ""
        }
    }
}

// MARK: - Plan List

// MARK: - Reusable Session Card (matches Mat Mind Home / Plan design)
