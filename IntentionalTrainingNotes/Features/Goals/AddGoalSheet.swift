import SwiftUI

struct AddGoalSheet: View {
    @ObservedObject var store: NotebookStore
    var onDone: () -> Void

    @State private var name = ""
    @State private var goalIconName = "target"
    @State private var goalColorName = "indigo"
    @State private var taskNames: [String] = []
    @State private var newTaskName = ""
    @State private var showTaskWarning = false

    @State private var taskFieldId = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                }
                Spacer()
                Button(action: {
                    if taskNames.isEmpty {
                        showTaskWarning = true
                        return
                    }
                    if let goal = store.addGoal(name: name, iconName: goalIconName, colorName: goalColorName) {
                        for taskName in taskNames {
                            store.addTask(goalId: goal.id, name: taskName)
                        }
                        name = ""
                        goalIconName = "target"
                        goalColorName = "indigo"
                        taskNames = []
                        onDone()
                    }
                }) {
                    Text("Create")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(name.nilIfBlank == nil ? Color.gray : AppColors.indigo)
                }
                .disabled(name.nilIfBlank == nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 0) {
                    // Icon preview
                    VStack(spacing: 8) {
                        let color = GoalIconLibrary.color(for: goalColorName)
                        GoalIconImage(name: goalIconName, color: color, size: 56)
                    }
                    .padding(.bottom, 12)

                    // Goal name input
                    VStack(spacing: 4) {
                        TextField("Goal name (e.g. Leg Locks)", text: $name)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("Tap to rename")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // Icon & color picker
                    GoalIconColorPicker(iconName: $goalIconName, colorName: $goalColorName)
                        .padding(.horizontal, 20)

                    // Tasks section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tasks")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.label)

                        ForEach(Array(taskNames.enumerated()), id: \.offset) { index, taskName in
                            HStack {
                                Text(taskName)
                                    .font(.subheadline)
                                Spacer()
                                Button(action: { taskNames.remove(at: index) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppColors.secondaryLabel)
                                }
                            }
                            .padding(10)
                            .background(AppColors.background)
                            .cardBackground()
                        }

                        HStack(spacing: 8) {
                            AutoFocusTextField(text: $newTaskName, placeholder: "Add a task", id: taskFieldId)
                                .font(.subheadline)
                            Button(action: {
                                if let trimmed = newTaskName.nilIfBlank, trimmed.count <= 15 {
                                    taskNames.append(trimmed)
                                    newTaskName = ""
                                    showTaskWarning = false
                                    taskFieldId = UUID()
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24, weight: .regular, design: .rounded))
                                    .foregroundColor(newTaskName.nilIfBlank == nil || newTaskName.count > 19 ? Color.gray : AppColors.indigo)
                            }
                            .disabled(newTaskName.nilIfBlank == nil || newTaskName.count > 19)
                        }

                        if newTaskName.count > 19 {
                            Text("Keep it under 20 letters")
                                .font(.caption)
                                .foregroundColor(AppColors.coral)
                        }

                        if showTaskWarning && taskNames.isEmpty {
                            Text("You must create at least one task")
                                .font(.caption)
                                .foregroundColor(AppColors.coral)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }
}

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @ObservedObject var store: NotebookStore
    let goalId: String
    var onDone: () -> Void

    @State private var taskName = ""

    private var goal: TrainingGoal? {
        store.notebook.goals.first(where: { $0.id == goalId })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                }
                Spacer()
                Button(action: {
                    if store.addTask(goalId: goalId, name: taskName) != nil {
                        taskName = ""
                        onDone()
                    }
                }) {
                    Text("Create")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(taskName.nilIfBlank == nil || taskName.count > 19 ? Color.gray : AppColors.indigo)
                }
                .disabled(taskName.nilIfBlank == nil || taskName.count > 19)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Goal icon + name
            VStack(spacing: 8) {
                if let goal = goal {
                    GoalIconImage(name: goal.iconName, color: goal.goalColor, size: 56)
                }
                Text(goal?.name ?? "Goal")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            .padding(.bottom, 20)

            // Task name input
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "checklist")
                        .font(.matMindBody(size: 16))
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    TextField("Enter task name", text: $taskName)
                        .font(.matMindBody(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColors.groupedBackground)
                .cornerRadius(12)
                if taskName.count > 19 {
                    Text("Keep it under 20 letters")
                        .font(.caption)
                        .foregroundColor(AppColors.coral)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }
}

enum GoalSheet: Identifiable {
    case edit(String)
    case reflections(String)  // taskId
    var id: String {
        switch self {
        case .edit(let goalId): return "edit-\(goalId)"
        case .reflections(let taskId): return "refl-\(taskId)"
        }
    }
}

// MARK: - Task Reflections (per-task list of all linked reflections)

struct TaskReflectionsView: View {
    @ObservedObject var store: NotebookStore
    let taskId: String
    var onClose: () -> Void

    @State private var filter: PatternKind = .all
    @State private var favoritesOnly = false

    var body: some View {
        let task = store.task(id: taskId)
        let goal = task.flatMap { store.goal(id: $0.goalId) }
        let allReflections = store.reflections(forTaskId: taskId)
        let favCount = allReflections.filter { $0.isFavorite }.count
        let filtered = allReflections.filter { r in
            (!favoritesOnly || r.isFavorite) && matchesKind(r, filter)
        }

        VStack(spacing: 0) {
            header(task: task, goal: goal, total: allReflections.count)
            filterBar(allCount: allReflections.count, favCount: favCount)

            ScrollView {
                VStack(spacing: 12) {
                    if filtered.isEmpty {
                        EmptyDashedState(
                            title: "Nothing here yet.",
                            subtitle: allReflections.isEmpty
                                ? "Reflect after a session to capture what worked and where you got stuck."
                                : "Try a different filter."
                        )
                        .padding(.top, 32)
                    }
                    ForEach(filtered) { r in
                        ReflectionCardView(
                            store: store,
                            reflection: r,
                            onReflect: {},
                            onDelete: { store.deleteReflection(id: r.id) },
                            onShareFeedback: {},
                            filter: filter,
                            dateMode: true,
                            showShareButton: false,
                            showMenu: false
                        )
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    // MARK: Header

    private func header(task: TrainingTask?, goal: TrainingGoal?, total: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.label)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.cardBackground))
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(task?.name ?? "Task")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Text("\(goal?.name ?? "Goal") · \(total) \(total == 1 ? "reflection" : "reflections")")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Filter bar

    private func filterBar(allCount: Int, favCount: Int) -> some View {
        HStack(spacing: 8) {
            filterChip(label: "All \(allCount)", isOn: filter == .all && !favoritesOnly) {
                filter = .all
                favoritesOnly = false
            }
            filterChip(label: "Wins", isOn: filter == .wins) {
                filter = (filter == .wins) ? .all : .wins
                favoritesOnly = false
            }
            filterChip(label: "Stuck", isOn: filter == .stuck) {
                filter = (filter == .stuck) ? .all : .stuck
                favoritesOnly = false
            }
            filterChip(label: "Up next", isOn: filter == .upNext) {
                filter = (filter == .upNext) ? .all : .upNext
                favoritesOnly = false
            }
            Spacer(minLength: 0)
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { favoritesOnly.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                    if favCount > 0 {
                        Text("\(favCount)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundColor(favoritesOnly ? AppColors.coral : AppColors.secondaryLabel)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(favoritesOnly ? AppColors.coral.opacity(0.14) : Color.clear))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func filterChip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { action() } }) {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isOn ? .white : AppColors.label)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(isOn ? AppColors.indigo : AppColors.cardBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func matchesKind(_ r: Reflection, _ kind: PatternKind) -> Bool {
        switch kind {
        case .all: return true
        case .wins: return r.workedText.nilIfBlank != nil
        case .stuck: return r.stuckText.nilIfBlank != nil
        case .upNext: return r.tryNextText.nilIfBlank != nil
        }
    }
}
