import SwiftUI

struct GoalListView: View {
    @ObservedObject var store: NotebookStore

    @State private var sheet: GoalSheet?
    @State private var expandedGoalIds: Set<String> = []
    @State private var pendingNewGoalId: String?
    @State private var didInit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active goals")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                        Text("What are you working on right now?")
                            .font(.matMindBody(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    Spacer()
                    Button(action: {
                        let draft = store.createDraftGoal()
                        pendingNewGoalId = draft.id
                        sheet = .edit(draft.id)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.indigo)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.top, 12)

                if store.activeGoals.isEmpty {
                    EmptyDashedState(title: "No goals yet.", subtitle: "Add one to begin.")
                }

                ForEach(store.activeGoals) { goal in
                    GoalCard(
                        store: store,
                        goal: goal,
                        isExpanded: expandedGoalIds.contains(goal.id),
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                if expandedGoalIds.contains(goal.id) {
                                    expandedGoalIds.remove(goal.id)
                                } else {
                                    _ = expandedGoalIds.insert(goal.id)
                                }
                            }
                        },
                        onEdit: { sheet = .edit(goal.id) },
                        onShowReflections: { taskId in sheet = .reflections(taskId) }
                    )
                    .zIndex(expandedGoalIds.contains(goal.id) ? 1 : 0)
                }

                if store.activeGoals.count > 1 {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                        Text("tap a goal to expand its tasks").font(.matMindBody(size: 14))
                    }
                    .foregroundColor(AppColors.tertiaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .padding(.bottom, 110)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            if !didInit {
                didInit = true
                if let first = store.activeGoals.first { expandedGoalIds = [first.id] }
            }
        }
        .sheet(item: $sheet, onDismiss: discardDraftIfUnsaved) { which in
            switch which {
            case .edit(let goalId):
                EditGoalView(store: store, goalId: goalId, isNewGoal: goalId == pendingNewGoalId) { sheet = nil }
            case .reflections(let taskId):
                TaskReflectionsView(store: store, taskId: taskId, onClose: { sheet = nil })
            }
        }
    }

    /// When the add-goal flow closes, drop the draft goal if it was never named (i.e. discarded
    /// via Cancel or swipe-to-dismiss). Saving a goal sets a non-blank name, so it's kept.
    private func discardDraftIfUnsaved() {
        guard let id = pendingNewGoalId else { return }
        pendingNewGoalId = nil
        if let g = store.goal(id: id), g.name.nilIfBlank == nil {
            store.deleteGoalCascade(goalId: id)
        }
    }
}

struct GoalCard: View {
    @ObservedObject var store: NotebookStore
    let goal: TrainingGoal
    let isExpanded: Bool
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onShowReflections: (String) -> Void

    @State private var expandedTaskIds: Set<String> = []
    @State private var menuOpen = false
    @State private var confirmDelete = false

    private var cal: Calendar { Calendar.current }

    var body: some View {
        let tasks = store.tasks(forGoal: goal.id)
        let color = goal.goalColor
        let trained = tasks.filter { trainedThisWeek($0) }.count

        VStack(alignment: .leading, spacing: 0) {
            header(tasks: tasks, color: color, trained: trained)
            if isExpanded {
                expandedBody(tasks: tasks, color: color, trained: trained)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground))
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.06), color.opacity(0.03)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(gradient: Gradient(colors: [color.opacity(0.22), color.opacity(0.06)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        .overlay(menuOverlay, alignment: .topTrailing)
        // Owned here (not on GoalListView) so it doesn't collide with that view's `.sheet`,
        // which previously stopped the goal-delete confirmation from ever presenting.
        .alert(isPresented: $confirmDelete) {
            let summary = store.goalCascadeSummary(goalId: goal.id)
            return Alert(
                title: Text("Delete \"\(goal.name)\"?"),
                message: Text(goalDeleteMessage(summary)),
                primaryButton: .destructive(Text("Delete")) { store.deleteGoalCascade(goalId: goal.id) },
                secondaryButton: .cancel()
            )
        }
    }

    private func goalDeleteMessage(_ s: GoalCascadeSummary) -> String {
        func plural(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }
        return "This will permanently delete the goal along with its \(plural(s.taskCount, "task")), "
            + "\(plural(s.sessionCount, "training session")), and \(plural(s.reflectionCount, "reflection")). "
            + "This can't be undone."
    }

    // MARK: Header

    @ViewBuilder
    private func header(tasks: [TrainingTask], color: Color, trained: Int) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 13)
                .fill(color.opacity(0.14))
                .frame(width: 46, height: 46)
                .overlay(GoalIconImage(name: goal.iconName, color: color, size: 23))

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                if isExpanded {
                    Text("\(tasks.count) \(tasks.count == 1 ? "task" : "tasks")")
                        .font(.matMindBody(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                } else {
                    HStack(spacing: 10) {
                        progressBar(trained, tasks.count, color).frame(width: 120)
                        Text("\(trained) of \(tasks.count) this week")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
            }

            Spacer()

            if isExpanded {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { menuOpen.toggle() } }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
        .padding(16)
        .padding(.leading, 4)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }

    // MARK: Expanded body

    @ViewBuilder
    private func expandedBody(tasks: [TrainingTask], color: Color, trained: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Trained this week")
                    .font(.matMindBody(size: 15))
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                Text("\(trained) / \(tasks.count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 16)
            .padding(.leading, 4)
            .padding(.top, 4)

            progressBar(trained, tasks.count, color)
                .padding(.horizontal, 16)
                .padding(.leading, 4)
                .padding(.top, 8)
                .padding(.bottom, 14)

            ForEach(tasks) { task in
                taskRow(task, color, isLast: task.id == tasks.last?.id)
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func taskRow(_ task: TrainingTask, _ color: Color, isLast: Bool) -> some View {
        let trained = trainedThisWeek(task)
        let isOpen = expandedTaskIds.contains(task.id)
        let reflCount = store.reflections(forTaskId: task.id).count
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { toggleTask(task.id) } }) {
                HStack(spacing: 12) {
                    checkbox(trained, color)
                    Text(task.name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Spacer()
                    if reflCount > 0 {
                        reflectionBadge(reflCount)
                    }
                    if task.link.nilIfBlank != nil {
                        Image(systemName: "link").font(.system(size: 13)).foregroundColor(AppColors.tertiaryLabel)
                    }
                    if !task.imageFileNames.isEmpty {
                        Image(systemName: "photo").font(.system(size: 13)).foregroundColor(AppColors.tertiaryLabel)
                    }
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isOpen {
                taskDetail(task, color)
            }
            if !isLast { Divider() }
        }
        .padding(.horizontal, 16)
        .padding(.leading, 14)
    }

    @ViewBuilder
    private func taskDetail(_ task: TrainingTask, _ color: Color) -> some View {
        let reflCount = store.reflections(forTaskId: task.id).count
        VStack(alignment: .leading, spacing: 12) {
            if let notes = task.notes.nilIfBlank {
                Text(notes)
                    .font(.matMindBody(size: 16))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No notes yet")
                    .font(.matMindBody(size: 15))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
            if !task.imageFileNames.isEmpty {
                VStack(spacing: 8) {
                    ForEach(task.imageFileNames, id: \.self) { fn in
                        if let data = store.taskImageData(taskId: task.id, fileName: fn), let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            if let link = task.link.nilIfBlank {
                HStack(spacing: 8) {
                    Image(systemName: "link").font(.system(size: 13)).foregroundColor(color)
                    Text(link).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(color).lineLimit(1)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.secondaryBackground))
            }
            if reflCount > 0 {
                viewAllReflectionsCTA(taskId: task.id, count: reflCount)
            }
        }
        .padding(.leading, 38)
        .padding(.bottom, 14)
    }

    private func reflectionBadge(_ count: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "text.bubble").font(.system(size: 10))
            Text("\(count)").font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundColor(AppColors.winGreen)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(AppColors.winGreen.opacity(0.15)))
    }

    private func viewAllReflectionsCTA(taskId: String, count: Int) -> some View {
        Button(action: { onShowReflections(taskId) }) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble").font(.system(size: 12))
                Text("View all reflections")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundColor(AppColors.indigo)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Pieces

    private func checkbox(_ done: Bool, _ color: Color) -> some View {
        ZStack {
            if done {
                Circle().fill(color).frame(width: 26, height: 26)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
            } else {
                Circle().stroke(Color(.systemGray3), lineWidth: 2).frame(width: 26, height: 26)
            }
        }
    }

    private func progressBar(_ value: Int, _ total: Int, _ color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5)).frame(height: 6)
                Capsule().fill(color)
                    .frame(width: total > 0 ? geo.size.width * CGFloat(value) / CGFloat(total) : 0, height: 6)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private var menuOverlay: some View {
        if menuOpen {
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.001)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .fixedSize()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { menuOpen = false } }

                VStack(spacing: 0) {
                    menuRow(icon: "pencil", label: "Edit goal", color: AppColors.label) { menuOpen = false; onEdit() }
                    Divider().padding(.horizontal, 10)
                    menuRow(icon: "trash", label: "Delete goal", color: AppColors.coral) { menuOpen = false; confirmDelete = true }
                }
                .background(AppColors.background)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
                .frame(width: 170)
                .padding(.top, 54)
                .padding(.trailing, 12)
            }
        }
    }

    private func menuRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                Text(label).font(.matMindBody(size: 15)).foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Helpers

    private func trainedThisWeek(_ task: TrainingTask) -> Bool {
        store.taskWeekDoneDayCount(taskId: task.id, goalId: goal.id, anchor: Date()) > 0
    }

    private func toggleTask(_ id: String) {
        if expandedTaskIds.contains(id) { expandedTaskIds.remove(id) } else { _ = expandedTaskIds.insert(id) }
    }
}
