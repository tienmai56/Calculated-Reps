import SwiftUI

struct GoalDetailView: View {
    @ObservedObject var store: NotebookStore
    var goalId: String
    var onBack: () -> Void

    @State private var adding = false
    @State private var name = ""
    @State private var confirmTaskId: String?

    var body: some View {
        let goal = store.goal(id: goalId)
        VStack(spacing: 0) {
            HeaderView(title: goal?.name ?? "Goal", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WeekStripView(dayStates: store.dayStateMap(goalId: goalId))
                    Text("Tasks").fieldLabel()

                    let tasks = store.tasks(forGoal: goalId)
                    if tasks.isEmpty && !adding {
                        EmptyDashedState(title: "No tasks yet.", subtitle: "Tasks help break a goal into specific drills.")
                    }

                    ForEach(tasks) { task in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.label)
                                Text("\(store.taskWeekDoneDayCount(taskId: task.id, goalId: goalId, anchor: Date())) days completed this week")
                                    .font(.caption)
                                    .foregroundColor(AppColors.label)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            if #available(iOS 14.0, *) {
                                Menu {
                                    Button(action: { confirmTaskId = task.id }) {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("Delete task")
                                        }
                                        .foregroundColor(AppColors.coral)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(AppColors.label)
                                        .frame(width: 36, height: 44)
                                }
                                .padding(.trailing, 4)
                            } else {
                                Button(action: { confirmTaskId = task.id }) {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(AppColors.label)
                                        .frame(width: 36, height: 44)
                                }
                                .padding(.trailing, 4)
                            }
                        }
                        .cardBackground()
                    }

                    if adding {
                        DashedPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Task name (e.g. Finishing mechanics)", text: $name)
                                    .textFieldStyle(TrainingTextFieldStyle())
                                if name.count > 19 {
                                    Text("Keep it under 20 letters")
                                        .font(.caption)
                                        .foregroundColor(AppColors.coral)
                                }
                                HStack(spacing: 8) {
                                    Button("Add") {
                                        if store.addTask(goalId: goalId, name: name) != nil {
                                            name = ""
                                            adding = false
                                        }
                                    }
                                    .buttonStyle(SmallPrimaryButtonStyle())
                                    .disabled(name.nilIfBlank == nil || name.count > 19)
                                    Button("Cancel") {
                                        name = ""
                                        adding = false
                                    }
                                    .buttonStyle(SmallSecondaryButtonStyle())
                                    Spacer()
                                }
                            }
                        }
                    } else {
                        Button(action: { adding = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add task")
                                Spacer()
                            }
                            .foregroundColor(AppColors.indigo)
                            .padding(12)
                            .cardBackground(stronger: true)
                        }
                    }
                }
                .padding(16)
            }
        }
        .alert(item: Binding(
            get: { confirmTaskId.map(TaskDeleteAlertToken.init(id:)) },
            set: { confirmTaskId = $0?.id }
        )) { token in
            let task = store.task(id: token.id)
            let summary = store.cascadeSummary(forTask: token.id)
            return Alert(
                title: Text("Delete \"\(task?.name ?? "task")\"?"),
                message: Text("\(summary.sessionCount) planned sessions and \(summary.reflectionCount) reflections will be deleted."),
                primaryButton: .destructive(Text("Delete task")) {
                    store.deleteTaskCascade(taskId: token.id)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

private struct TaskDeleteAlertToken: Identifiable {
    var id: String
}

struct GoalEditToken: Identifiable {
    var id: String
}

struct TaskTimelineView: View {
    @ObservedObject var store: NotebookStore
    var goalId: String
    var taskId: String
    var onBack: () -> Void
    var onReflect: (String) -> Void
    var onPlanTraining: (String, String) -> Void

    @State private var expandedId: String?

    var body: some View {
        let task = store.task(id: taskId)
        let goal = store.goal(id: goalId)
        let sessions = store.sessions(forTask: taskId, goalId: goalId)
        let sorted = sessions.sorted { $0.date > $1.date }
        let latest = sorted.first
        let rest = sorted.dropFirst()

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let thisWeekMonday = cal.mondayStartOfWeek(containing: today)
        let lastWeekMonday = cal.date(byAdding: .day, value: -7, to: thisWeekMonday)!

        let weekGroups: [(key: Date, value: [PlannedSession])] = {
            var dict: [Date: [PlannedSession]] = [:]
            for s in rest {
                let monday = cal.mondayStartOfWeek(containing: s.date)
                dict[monday, default: []].append(s)
            }
            return dict.sorted { $0.key > $1.key }
        }()

        func weekLabel(for monday: Date) -> String {
            if monday == thisWeekMonday { return "This Week" }
            if monday == lastWeekMonday { return "Last Week" }
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return "Week of \(fmt.string(from: monday))"
        }

        return VStack(spacing: 0) {
            HeaderView(title: task?.name ?? "Task", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(goal?.name ?? "Goal") · \(sessions.count) \(sessions.count == 1 ? "session" : "sessions")")
                        .font(.caption)
                        .foregroundColor(AppColors.label)

                    Button(action: { onPlanTraining(goalId, taskId) }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Plan Training")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(AppColors.label)
                    }

                    if sessions.isEmpty {
                        EmptyDashedState(title: "No sessions planned for this task yet.", subtitle: "Plan training from the center button.")
                    }

                    if let latestSession = latest {
                        TimelineSection(title: "Latest", count: 1) {
                            timelineRow(for: latestSession)
                        }
                    }

                    ForEach(weekGroups, id: \.key) { group in
                        TimelineSection(title: weekLabel(for: group.key), count: group.value.count) {
                            ForEach(group.value.sorted(by: { $0.date > $1.date })) { session in
                                timelineRow(for: session)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func timelineRow(for session: PlannedSession) -> some View {
        TimelineRow(
            session: session,
            reflection: store.reflection(forSessionId: session.id),
            tasks: store.notebook.tasks,
            expanded: expandedId == session.id,
            onTapCircle: {
                if session.status == .planned {
                    onReflect(session.id)
                }
            },
            onToggleExpand: {
                if session.status == .done {
                    if store.reflection(forSessionId: session.id) != nil {
                        expandedId = expandedId == session.id ? nil : session.id
                    } else {
                        onReflect(session.id)
                    }
                } else {
                    onReflect(session.id)
                }
            },
            onDeleteReflection: { id in store.deleteReflection(id: id) }
        )
    }
}

struct TimelineSection<Content: View>: View {
    var title: String
    var count: Int
    var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).fieldLabel()
                Text("· \(count)")
                    .font(.caption)
                    .foregroundColor(AppColors.label)
            }
            content()
        }
    }
}

struct TimelineRow: View {
    var session: PlannedSession
    var reflection: Reflection?
    var tasks: [TrainingTask]
    var expanded: Bool
    var onTapCircle: () -> Void
    var onToggleExpand: () -> Void
    var onDeleteReflection: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onTapCircle) {
                    ZStack {
                        Circle()
                            .fill(session.status == .done ? AppColors.mint : AppColors.background)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(session.status == .done ? AppColors.mint : AppColors.indigo, lineWidth: 1))
                        Image(systemName: session.status == .done ? "checkmark" : "circle")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(session.status == .done ? .white : AppColors.indigo)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .disabled(session.status == .done)
                .accessibility(label: Text(session.status == .done ? "Completed session" : "Reflect on session"))

                Button(action: onToggleExpand) {
                    HStack {
                        Text(shortDate(session.date))
                            .font(.subheadline)
                            .foregroundColor(AppColors.label)
                        Spacer()
                        if reflection == nil {
                            ReflectPencilIcon(size: 16, color: .primary)
                        } else {
                            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(AppColors.label)
                        }
                    }
                }
            }
            .padding(12)

            if expanded, let reflection = reflection {
                VStack(alignment: .leading, spacing: 14) {
                    if !reflection.workedText.isEmpty {
                        ZStack(alignment: .topLeading) {
                            Text(reflection.workedText)
                                .font(.subheadline)
                                .foregroundColor(AppColors.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 20)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            Text("What worked")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(8)
                                .offset(x: 12, y: -10)
                        }
                    }
                    if !reflection.stuckText.isEmpty {
                        ZStack(alignment: .topLeading) {
                            Text(reflection.stuckText)
                                .font(.subheadline)
                                .foregroundColor(AppColors.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 20)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            Text("Where I got stuck")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppColors.coral)
                                .cornerRadius(8)
                                .offset(x: 12, y: -10)
                        }
                    }
                    if let mood = reflection.mood {
                        Text("\(mood.glyph) \(mood.label)")
                            .font(.caption)
                            .foregroundColor(AppColors.label)
                    }
                    Button("Delete reflection") {
                        onDeleteReflection(reflection.id)
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.label)
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
            }
        }
        .cardBackground()
    }

    private func shortDate(_ date: Date) -> String {
        DateFormatter.timelineShortDate.string(from: date)
    }
}

// MARK: - Plan Training
