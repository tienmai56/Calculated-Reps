import SwiftUI

struct PlanTrainingView: View {
    @ObservedObject var store: NotebookStore
    var onCancel: () -> Void
    var onSaved: ([PlannedSession]) -> Void
    var initialGoalId: String?

    private let totalSteps = 2
    private let calendar = Calendar.current

    @State private var step = 1
    @State private var displayedMonth: Date = Date()
    @State private var selectedDays: Set<Date> = []
    @State private var selectedGoalIds: Set<String> = []
    @State private var selectedTasksByDay: [Date: Set<String>] = [:]
    @State private var didApplyInitial = false
    @State private var newGoalSheet: GoalEditToken?
    @State private var pendingNewGoalId: String?

    private var sortedDays: [Date] { selectedDays.sorted() }
    private var selectedGoals: [TrainingGoal] { store.activeGoals.filter { selectedGoalIds.contains($0.id) } }

    // Every selected day must have at least one task chosen — no taskless sessions allowed.
    private var planIsValid: Bool {
        !sortedDays.isEmpty && sortedDays.allSatisfy { !(selectedTasksByDay[$0]?.isEmpty ?? true) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PlanStepHeader(
                step: step,
                totalSteps: totalSteps,
                progress: CGFloat(step) / CGFloat(totalSteps),
                onBack: {
                    if step <= 1 { onCancel() }
                    else { withAnimation(.easeOut(duration: 0.2)) { step -= 1 } }
                },
                onClose: onCancel
            )
            if step == 1 { stepDaysGoals } else { stepTasks }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            if !didApplyInitial {
                didApplyInitial = true
                if let g = initialGoalId { _ = selectedGoalIds.insert(g) }
            }
        }
        .sheet(item: $newGoalSheet, onDismiss: finalizeNewGoalDraft) { token in
            EditGoalView(store: store, goalId: token.id, isNewGoal: true) { newGoalSheet = nil }
        }
    }

    /// Mirrors `GoalListView.discardDraftIfUnsaved`: if the user saved the draft (it has a name now),
    /// auto-select it for this plan; otherwise discard the empty draft.
    private func finalizeNewGoalDraft() {
        guard let id = pendingNewGoalId else { return }
        pendingNewGoalId = nil
        if let g = store.goal(id: id), g.name.nilIfBlank != nil {
            _ = selectedGoalIds.insert(id)
        } else {
            store.deleteGoalCascade(goalId: id)
        }
    }

    // MARK: - Step 1: days + goals

    private var stepDaysGoals: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Plan your training")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                        Text("Tap the days you want to train, then pick your goals.")
                            .font(.matMindBody(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    monthCalendar
                    Text(daysSelectedLabel)
                        .font(.matMindBody(size: 15))
                        .foregroundColor(AppColors.label)
                    if !selectedDays.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goals")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.secondaryLabel)
                            WrappingHStack(items: store.activeGoals) { goal in
                                goalChip(goal)
                            }
                            Button(action: {
                                let draft = store.createDraftGoal()
                                pendingNewGoalId = draft.id
                                newGoalSheet = GoalEditToken(id: draft.id)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("New Goal")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(AppColors.indigo)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(AppColors.indigo.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(16)
            }
            bottomBar(title: "Continue", enabled: !selectedDays.isEmpty && !selectedGoalIds.isEmpty) {
                withAnimation(.easeOut(duration: 0.2)) { step = 2 }
            }
        }
    }

    private func goalChip(_ goal: TrainingGoal) -> some View {
        let selected = selectedGoalIds.contains(goal.id)
        return Button(action: {
            if selected { _ = selectedGoalIds.remove(goal.id) } else { _ = selectedGoalIds.insert(goal.id) }
        }) {
            Text(goal.name)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(selected ? .white : AppColors.label)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(chipBackground(selected: selected, color: goal.goalColor))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Step 2: tasks per day

    private var stepTasks: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What will you drill?")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                        Text(drillSubtitle)
                            .font(.matMindBody(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    ForEach(sortedDays, id: \.self) { day in
                        dayTaskCard(day)
                    }
                    Text("Planning creates an unchecked entry for each day. Check it off after training to reflect.")
                        .font(.matMindBody(size: 15))
                        .foregroundColor(AppColors.label)
                }
                .padding(16)
            }
            if !planIsValid {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Select at least one task to continue")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(Color(.systemRed))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            bottomBar(title: "Save plan (\(sortedDays.count) \(sortedDays.count == 1 ? "day" : "days"))", enabled: planIsValid) {
                handleSave()
            }
        }
    }

    private func dayTaskCard(_ day: Date) -> some View {
        let taskCount = selectedTasksByDay[day]?.count ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(dowString(day))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                Text(mdString(day))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Text("· \(taskCount) \(taskCount == 1 ? "task" : "tasks")")
                    .font(.matMindBody(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                if sortedDays.count > 1 {
                    Button(action: { applyToAll(from: day) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc").font(.system(size: 12))
                            Text("APPLY TO ALL")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .kerning(0.5)
                        }
                        .foregroundColor(AppColors.secondaryLabel)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            ForEach(selectedGoals) { goal in
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(goal.goalColor)
                    let tasks = store.tasks(forGoal: goal.id)
                    if tasks.isEmpty {
                        Text("Add a task to this goal to plan it")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppColors.tertiaryLabel)
                    } else {
                        WrappingHStack(items: tasks) { task in
                            taskChip(day: day, task: task, color: goal.goalColor)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.secondaryBackground))
    }

    private func taskChip(day: Date, task: TrainingTask, color: Color) -> some View {
        let selected = selectedTasksByDay[day]?.contains(task.id) ?? false
        return Button(action: { toggleTask(day: day, taskId: task.id) }) {
            Text(task.name)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(selected ? .white : AppColors.label)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(chipBackground(selected: selected, color: color))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func chipBackground(selected: Bool, color: Color) -> some View {
        ZStack {
            if selected {
                Capsule().fill(color)
            } else {
                Capsule().fill(Color(.systemBackground))
                Capsule().stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
    }

    // MARK: - Month calendar (multi-select)

    private var monthCalendar: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { shiftMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { shiftMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity)
                }
            }
            let days = gridDays
            let rows = (days.count + 6) / 7
            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < days.count, let date = days[idx] {
                                daySelectCell(date)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.secondaryBackground))
    }

    private func daySelectCell(_ date: Date) -> some View {
        let norm = calendar.normalizedTrainingDay(date)
        let selected = selectedDays.contains(norm)
        let isToday = calendar.isDateInToday(date)
        return Button(action: { toggleDay(date) }) {
            ZStack {
                if selected {
                    Circle().fill(AppColors.indigo).frame(width: 36, height: 36)
                } else if isToday {
                    Circle().stroke(AppColors.indigo, lineWidth: 1.5).frame(width: 36, height: 36)
                }
                Text("\(calendar.component(.day, from: date))")
                    .font(.matMindBody(size: 16))
                    .foregroundColor(selected ? .white : AppColors.label)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Bottom bar

    private func bottomBar(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: action) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 28).fill(enabled ? AppColors.indigo : AppColors.indigo.opacity(0.4)))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!enabled)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Actions

    private func toggleDay(_ date: Date) {
        let norm = calendar.normalizedTrainingDay(date)
        if selectedDays.contains(norm) {
            _ = selectedDays.remove(norm)
            selectedTasksByDay.removeValue(forKey: norm)
        } else {
            _ = selectedDays.insert(norm)
        }
    }

    private func toggleTask(day: Date, taskId: String) {
        var set = selectedTasksByDay[day] ?? []
        if set.contains(taskId) { set.remove(taskId) } else { set.insert(taskId) }
        selectedTasksByDay[day] = set
    }

    private func applyToAll(from source: Date) {
        let src = selectedTasksByDay[source] ?? []
        for d in selectedDays { selectedTasksByDay[d] = src }
    }

    private func handleSave() {
        guard planIsValid else { return }
        var proposals: [ProposedSession] = []
        for day in sortedDays {
            let dayTasks = selectedTasksByDay[day] ?? []
            for goal in selectedGoals {
                let goalTaskIds = Set(store.tasks(forGoal: goal.id).map { $0.id })
                let tasksForGoal = Array(dayTasks.intersection(goalTaskIds))
                if tasksForGoal.isEmpty { continue }
                proposals.append(ProposedSession(goalId: goal.id, date: day, taskIds: tasksForGoal))
            }
        }
        let created = store.planSessions(proposals, overrideConflicts: true)
        onSaved(created)
    }

    // MARK: - Calendar helpers

    private var monthFirst: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthTitle: String {
        DateFormatter.monthYear.string(from: monthFirst)
    }

    private var gridDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthFirst) else { return [] }
        let weekdayOfFirst = calendar.component(.weekday, from: monthFirst)
        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst - 1)
        for d in range {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: monthFirst))
        }
        return days
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: monthFirst) {
            displayedMonth = d
        }
    }

    private var daysSelectedLabel: String {
        selectedDays.isEmpty ? "No days picked yet." : "\(selectedDays.count) day\(selectedDays.count == 1 ? "" : "s") selected."
    }

    private var drillSubtitle: String {
        let names = selectedGoals.map { $0.name }.joined(separator: ", ")
        return "Pick at least one task under \(names) for each day."
    }

    private func dowString(_ d: Date) -> String {
        DateFormatter.weekdayAbbrev.string(from: d).uppercased()
    }

    private func mdString(_ d: Date) -> String {
        DateFormatter.monthDay.string(from: d)
    }
}

// MARK: - Plan Step Header

private struct PlanStepHeader: View {
    var step: Int
    var totalSteps: Int
    var progress: CGFloat
    var onBack: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                        .dashedCircle()
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Back"))

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule()
                            .fill(AppColors.indigo)
                            .frame(width: geometry.size.width * progress)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                    }
                }
                .frame(height: 6)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                        .dashedCircle()
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Close"))
            }
            .padding(.horizontal, 4)

            Text("STEP \(step) OF \(totalSteps) · PLAN TRAINING")
                .font(.system(size: 10, design: .rounded))
                .tracking(0.8)
                .foregroundColor(AppColors.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Step 1: Focus

private struct PlanStepFocus: View {
    var goals: [TrainingGoal]
    var goalId: String?
    var onPickGoal: (String) -> Void
    var weekStart: Date
    var weekEnd: Date
    var onShiftWeek: (Int) -> Void
    var canAdvance: Bool
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's your focus?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                        Text("Pick one goal to anchor this week's training.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Week").fieldLabel()
                        HStack {
                            Button(action: { onShiftWeek(-1) }) {
                                Image(systemName: "chevron.left")
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            Spacer()
                            Text(weekRangeLabel)
                                .font(.subheadline.monospacedDigit())
                            Spacer()
                            Button(action: { onShiftWeek(1) }) {
                                Image(systemName: "chevron.right")
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundColor(Color(.systemGray4))
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal").fieldLabel()
                        if goals.isEmpty {
                            EmptyDashedState(title: "No goals yet.", subtitle: "Create one from the Goals tab first.")
                        } else {
                            FlowWrap(goals) { goal in
                                ChipButton(
                                    title: goal.name,
                                    isSelected: goalId == goal.id,
                                    action: { onPickGoal(goal.id) }
                                )
                            }
                        }
                    }

                    Text("Next you'll pick which days you'll train, then which tasks to drill on each day.")
                        .font(.caption)
                        .foregroundColor(AppColors.label)
                }
                .padding(16)
            }

            Divider()
            Button("Continue") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canAdvance)
                .padding()
        }
    }

    private var weekRangeLabel: String {
        let fmt = DateFormatter.monthDay
        return "\(fmt.string(from: weekStart)) – \(fmt.string(from: weekEnd))"
    }
}

// MARK: - Step 2: Days

private struct PlanStepDays: View {
    var weekDays: [Date]
    var selectedDays: Set<Date>
    var onToggleDay: (Date) -> Void
    var focusName: String
    var canAdvance: Bool
    var onContinue: () -> Void

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Which days?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                        (Text("Pick the days you'll train ") + Text(focusName).bold() + Text(". Tap to toggle."))
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    HStack(spacing: 6) {
                        ForEach(Array(weekDays.enumerated()), id: \.offset) { index, date in
                            PlanDayCell(
                                label: dayLabels[index],
                                dayNumber: calendar.component(.day, from: date),
                                isSelected: selectedDays.contains(calendar.normalizedTrainingDay(date)),
                                isToday: calendar.isDateInToday(date),
                                onTap: { onToggleDay(date) }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Text(selectedDays.isEmpty ? "No days picked yet." : "\(selectedDays.count) \(selectedDays.count == 1 ? "day" : "days") selected.")
                        .font(.caption)
                        .foregroundColor(AppColors.label)
                }
                .padding(16)
            }

            Divider()
            Button("Continue") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canAdvance)
                .padding()
        }
    }
}

private struct PlanDayCell: View {
    var label: String
    var dayNumber: Int
    var isSelected: Bool
    var isToday: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                Text("\(dayNumber)")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AppColors.indigo : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? AppColors.indigo : (isToday ? AppColors.indigo : Color(.systemGray4)),
                        style: isSelected || isToday ? StrokeStyle(lineWidth: 1) : StrokeStyle(lineWidth: 1, dash: [5])
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Step 3: Tasks per day

private struct PlanStepTasks: View {
    var selectedDays: [Date]
    var tasksByDay: [Date: [String]]
    var goalTasks: [TrainingTask]
    var onToggleTask: (Date, String) -> Void
    var onApplyToAll: (Date) -> Void
    var totalDays: Int
    var focusName: String
    var onSave: () -> Void

    private let calendar = Calendar.current

    private var hasAnyTaskSelected: Bool {
        let cal = Calendar.current
        return selectedDays.allSatisfy { day in
            let normalized = cal.normalizedTrainingDay(day)
            return !(tasksByDay[normalized] ?? []).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What will you drill?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                        (Text("Pick tasks under ") + Text(focusName).bold() + Text(" for each day. Leave empty to plan a whole-goal session."))
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    if goalTasks.isEmpty {
                        DashedPanel {
                            Text("No tasks under this goal yet. You can still save — each day will be a whole-goal session.")
                                .font(.caption)
                                .foregroundColor(AppColors.label)
                        }
                    }

                    ForEach(selectedDays, id: \.self) { day in
                        PlanDayTaskSection(
                            day: day,
                            tasksByDay: tasksByDay,
                            goalTasks: goalTasks,
                            totalDays: totalDays,
                            onToggleTask: onToggleTask,
                            onApplyToAll: onApplyToAll
                        )
                    }

                    Text("Planning creates an unchecked entry for each day. Check it off after training to reflect.")
                        .font(.caption)
                        .foregroundColor(AppColors.label)

                    if !goalTasks.isEmpty && !hasAnyTaskSelected {
                        Text("Select at least one task for every day")
                            .font(.caption)
                            .foregroundColor(AppColors.coral)
                    }
                }
                .padding(16)
            }

            Divider()
            Button("Save plan (\(totalDays) \(totalDays == 1 ? "day" : "days"))") { onSave() }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
                .disabled(!goalTasks.isEmpty && !hasAnyTaskSelected)
                .opacity(!goalTasks.isEmpty && !hasAnyTaskSelected ? 0.4 : 1)
        }
    }
}

private struct PlanDayTaskSection: View {
    var day: Date
    var tasksByDay: [Date: [String]]
    var goalTasks: [TrainingTask]
    var totalDays: Int
    var onToggleTask: (Date, String) -> Void
    var onApplyToAll: (Date) -> Void

    private let calendar = Calendar.current
    private let fullDayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    private var normalized: Date { calendar.normalizedTrainingDay(day) }
    private var dayIdx: Int { (calendar.component(.weekday, from: day) + 5) % 7 }
    private var selectedTaskIds: [String] { tasksByDay[normalized] ?? [] }

    var body: some View {
        DashedPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(fullDayLabels[dayIdx])
                            .font(.system(size: 10, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(AppColors.label)
                        Text(DateFormatter.monthDay.string(from: day))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                        Text("· \(selectedTaskIds.count) \(selectedTaskIds.count == 1 ? "task" : "tasks")")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(AppColors.label)
                    }
                    Spacer()
                    if totalDays > 1 && !selectedTaskIds.isEmpty {
                        Button(action: { onApplyToAll(day) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10, design: .rounded))
                                Text("APPLY TO ALL")
                                    .font(.system(size: 10, design: .rounded))
                                    .tracking(0.5)
                            }
                            .foregroundColor(AppColors.label)
                        }
                    }
                }

                if !goalTasks.isEmpty {
                    FlowWrap(goalTasks) { task in
                        ChipButton(
                            title: task.name,
                            isSelected: selectedTaskIds.contains(task.id),
                            action: { onToggleTask(day, task.id) }
                        )
                    }
                }
            }
        }
    }
}

private struct DuplicateAlertToken: Identifiable {
    var id: String
}

// MARK: - Reflect
