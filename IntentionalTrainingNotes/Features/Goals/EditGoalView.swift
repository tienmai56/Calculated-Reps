import SwiftUI
import UIKit

private enum EditGoalAlert: Identifiable {
    case deleteTask(String)
    case deleteGoal
    var id: String {
        switch self {
        case .deleteTask(let id): return "task-\(id)"
        case .deleteGoal: return "goal"
        }
    }
}

struct EditGoalView: View {
    @ObservedObject var store: NotebookStore
    let goalId: String
    var onDismiss: () -> Void
    let isNewGoal: Bool

    @State private var goalName: String
    @State private var iconName: String
    @State private var colorName: String
    @State private var addingTask = false
    @State private var newTaskName = ""
    @State private var expandedTaskIds: Set<String>
    @State private var activeAlert: EditGoalAlert?

    private var goalColor: Color { GoalIconLibrary.color(for: colorName) }

    init(store: NotebookStore, goalId: String, isNewGoal: Bool = false, onDismiss: @escaping () -> Void) {
        self.store = store
        self.goalId = goalId
        self.isNewGoal = isNewGoal
        self.onDismiss = onDismiss
        let goal = store.goal(id: goalId)
        _goalName = State(initialValue: goal?.name ?? "")
        _iconName = State(initialValue: goal?.iconName ?? "target")
        _colorName = State(initialValue: goal?.colorName ?? "indigo")
        // Auto-expand any task that has details OR is missing a description, so the user can
        // immediately see what needs to be filled in (descriptions are required to save).
        let tasks = store.tasks(forGoal: goalId)
        let needsAttention = tasks
            .filter { $0.hasDetails || $0.notes.nilIfBlank == nil }
            .map { $0.id }
        _expandedTaskIds = State(initialValue: Set(needsAttention))
    }

    var body: some View {
        let tasks = store.tasks(forGoal: goalId)
        let missingDescription = tasks.contains(where: { $0.notes.nilIfBlank == nil })
        let saveDisabled = goalName.nilIfBlank == nil || missingDescription

        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { onDismiss() }
                    .font(.system(size: 17, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: saveAndDismiss) {
                    Text("Save")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(saveDisabled ? AppColors.indigo.opacity(0.4) : AppColors.indigo))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(saveDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if missingDescription {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                    Text("Add a description to each task before saving.")
                        .font(.system(size: 13, design: .rounded))
                }
                .foregroundColor(AppColors.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    previewHeader
                    appearanceSection
                    tasksSection
                    if !isNewGoal { deleteGoalButton }
                }
                .padding(16)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .alert(item: $activeAlert, content: alert(for:))
    }

    private var previewHeader: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18)
                .fill(goalColor.opacity(0.14))
                .frame(width: 76, height: 76)
                .overlay(GoalIconImage(name: iconName, color: goalColor, size: 36))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    TextField("Goal name", text: $goalName)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Image(systemName: "pencil").font(.system(size: 15)).foregroundColor(AppColors.secondaryLabel)
                }
                let n = store.tasks(forGoal: goalId).count
                Text("\(n) \(n == 1 ? "task" : "tasks")")
                    .font(.matMindBody(size: 16))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("APPEARANCE")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .kerning(0.5)
                .foregroundColor(AppColors.tertiaryLabel)
            GoalIconColorPicker(iconName: $iconName, colorName: $colorName)
            Divider().padding(.top, 6)
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("TASKS")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .kerning(0.5)
                    .foregroundColor(AppColors.tertiaryLabel)
                Spacer()
                Button(action: { addingTask = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                        Text("Add").font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(AppColors.indigo)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 4)

            let tasks = store.tasks(forGoal: goalId)
            if tasks.isEmpty && !addingTask {
                Text("No tasks yet.")
                    .font(.matMindBody(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
                    .padding(.top, 6)
            }
            ForEach(tasks) { task in
                TaskEditRow(
                    store: store,
                    task: task,
                    accentColor: goalColor,
                    expanded: Binding(
                        get: { expandedTaskIds.contains(task.id) },
                        set: { isOn in
                            if isOn { _ = expandedTaskIds.insert(task.id) }
                            else { _ = expandedTaskIds.remove(task.id) }
                        }
                    ),
                    onDelete: { activeAlert = .deleteTask(task.id) }
                )
                Divider()
            }
            if addingTask { addTaskField }
        }
    }

    private var addTaskField: some View {
        HStack(spacing: 8) {
            TextField("Task name", text: $newTaskName, onCommit: commitNewTask)
                .font(.matMindBody(size: 16))
                .textFieldStyle(TrainingTextFieldStyle())
            Button(action: commitNewTask) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(goalColor)
            }
            .disabled(newTaskName.nilIfBlank == nil)
            Button(action: { addingTask = false; newTaskName = "" }) {
                Image(systemName: "xmark.circle").foregroundColor(AppColors.secondaryLabel)
            }
        }
        .padding(.vertical, 8)
    }

    private var deleteGoalButton: some View {
        Button(action: { activeAlert = .deleteGoal }) {
            Text("Delete goal")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.coral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.coral.opacity(0.1)))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 8)
    }

    private func alert(for alert: EditGoalAlert) -> Alert {
        switch alert {
        case .deleteTask(let taskId):
            return Alert(
                title: Text("Delete Task"),
                message: Text("Are you sure you want to delete this task?"),
                primaryButton: .destructive(Text("Delete")) {
                    store.deleteTaskCascade(taskId: taskId)
                },
                secondaryButton: .cancel()
            )
        case .deleteGoal:
            let summary = store.goalCascadeSummary(goalId: goalId)
            return Alert(
                title: Text("Delete \"\(goalName)\"?"),
                message: Text("\(summary.taskCount) tasks, \(summary.sessionCount) sessions, and \(summary.reflectionCount) reflections will be deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    store.deleteGoalCascade(goalId: goalId)
                    onDismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func saveAndDismiss() {
        if goalName.nilIfBlank != nil {
            store.updateGoal(id: goalId, name: goalName, iconName: iconName, colorName: colorName)
        }
        onDismiss()
    }

    private func commitNewTask() {
        if let task = store.addTask(goalId: goalId, name: newTaskName) {
            newTaskName = ""
            addingTask = false
            _ = expandedTaskIds.insert(task.id)
        }
    }
}

struct TaskEditRow: View {
    @ObservedObject var store: NotebookStore
    let task: TrainingTask
    let accentColor: Color
    @Binding var expanded: Bool
    var onDelete: () -> Void

    @State private var name: String
    @State private var notes: String
    @State private var link: String
    @State private var showLinkField = false

    init(store: NotebookStore, task: TrainingTask, accentColor: Color, expanded: Binding<Bool>, onDelete: @escaping () -> Void) {
        self.store = store
        self.task = task
        self.accentColor = accentColor
        self._expanded = expanded
        self.onDelete = onDelete
        _name = State(initialValue: task.name)
        _notes = State(initialValue: task.notes)
        _link = State(initialValue: task.link)
    }

    private var imageFileNames: [String] {
        store.task(id: task.id)?.imageFileNames ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .buttonStyle(PlainButtonStyle())

                if expanded {
                    TextField("Task name", text: nameBinding)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                } else {
                    Text(name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded = true } }
                    Spacer()
                }
            }

            if expanded {
                TrainingTextView(text: notesBinding, placeholder: "Add a description (required)…")
                    .frame(height: 76)

                if !imageFileNames.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(imageFileNames, id: \.self) { fileName in
                            taskThumbnail(fileName)
                        }
                    }
                }

                if showLinkField || link.nilIfBlank != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "link").font(.system(size: 13)).foregroundColor(AppColors.secondaryLabel)
                        TextField("Paste link...", text: linkBinding).font(.matMindBody(size: 14))
                    }
                    .padding(11)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray3), lineWidth: 1))
                }

                HStack(spacing: 10) {
                    chipButton(icon: "link", label: "Add link") { showLinkField = true }
                    chipButton(icon: "photo", label: "Photo") {
                        UIKitImagePicker.present { data in
                            store.addTaskImage(taskId: task.id, imageData: data)
                        }
                    }
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 16)).foregroundColor(AppColors.coral)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func chipButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundColor(AppColors.secondaryLabel)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(.systemGray6)))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func taskThumbnail(_ fileName: String) -> some View {
        ZStack(alignment: .topTrailing) {
            if let data = store.taskImageData(taskId: task.id, fileName: fileName), let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)).frame(maxWidth: .infinity).frame(height: 160)
            }
            Button(action: { store.removeTaskImage(taskId: task.id, fileName: fileName) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.45)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(8)
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { name }, set: { name = $0; store.updateTask(id: task.id, name: $0) })
    }
    private var notesBinding: Binding<String> {
        Binding(get: { notes }, set: { notes = $0; store.updateTask(id: task.id, notes: $0) })
    }
    private var linkBinding: Binding<String> {
        Binding(get: { link }, set: { link = $0; store.updateTask(id: task.id, link: $0) })
    }
}
