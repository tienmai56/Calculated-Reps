import SwiftUI

struct EditSessionView: View {
    @ObservedObject var store: NotebookStore
    let session: PlannedSession
    var onDismiss: () -> Void

    @State private var selectedGoalIds: Set<String>
    @State private var selectedTaskIds: Set<String>
    @State private var selectedDate: Date
    @State private var showDatePicker = false

    init(store: NotebookStore, session: PlannedSession, onDismiss: @escaping () -> Void) {
        self.store = store
        self.session = session
        self.onDismiss = onDismiss
        // Pre-select goals that own any of the session's tasks
        let taskGoalIds = Set(session.taskIds.compactMap { tid in
            store.notebook.tasks.first(where: { $0.id == tid })?.goalId
        })
        let initialGoalIds = taskGoalIds.union([session.goalId])
        _selectedGoalIds = State(initialValue: initialGoalIds)
        _selectedTaskIds = State(initialValue: Set(session.taskIds))
        _selectedDate = State(initialValue: session.date)
    }

    private var selectedGoalsSorted: [TrainingGoal] {
        store.activeGoals.filter { selectedGoalIds.contains($0.id) }
    }

    private var cal: Calendar { Calendar.current }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date (editable)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATE")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showDatePicker.toggle() } }) {
                            HStack {
                                Text(DateFormatter.weekdayShortDate.string(from: selectedDate))
                                    .font(.body)
                                    .foregroundColor(AppColors.label)
                                Spacer()
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.indigo)
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if showDatePicker {
                            editSessionCalendar
                                .transition(.opacity)
                        }
                    }

                    // Goal picker (multi-select)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GOAL")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        ForEach(store.activeGoals) { goal in
                            Button(action: {
                                if selectedGoalIds.contains(goal.id) {
                                    if selectedGoalIds.count > 1 {
                                        selectedGoalIds.remove(goal.id)
                                        // Remove tasks belonging to this goal
                                        let goalTaskIds = Set(store.tasks(forGoal: goal.id).map(\.id))
                                        selectedTaskIds.subtract(goalTaskIds)
                                    }
                                } else {
                                    selectedGoalIds.insert(goal.id)
                                }
                            }) {
                                HStack {
                                    Text(goal.name)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.label)
                                    Spacer()
                                    if selectedGoalIds.contains(goal.id) {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(AppColors.label)
                                    }
                                }
                                .padding(12)
                                .background(selectedGoalIds.contains(goal.id) ? Color(.systemGray5) : Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // Task picker (grouped by goal)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TASKS")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)

                        ForEach(selectedGoalsSorted) { goal in
                            let tasks = store.tasks(forGoal: goal.id)
                            if !tasks.isEmpty {
                                Text(goal.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(goal.goalColor)
                                    .padding(.top, 4)

                                ForEach(tasks) { task in
                                    Button(action: {
                                        if selectedTaskIds.contains(task.id) {
                                            selectedTaskIds.remove(task.id)
                                        } else {
                                            selectedTaskIds.insert(task.id)
                                        }
                                    }) {
                                        HStack {
                                            Text(task.name)
                                                .font(.subheadline)
                                                .foregroundColor(AppColors.label)
                                            Spacer()
                                            if selectedTaskIds.contains(task.id) {
                                                Image(systemName: "checkmark")
                                                    .font(.caption)
                                                    .foregroundColor(AppColors.label)
                                            }
                                        }
                                        .padding(12)
                                        .background(selectedTaskIds.contains(task.id) ? goal.goalColor.opacity(0.12) : Color(.systemGray6))
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }

                        if selectedGoalsSorted.allSatisfy({ store.tasks(forGoal: $0.id).isEmpty }) {
                            Text("No tasks for selected goals.")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.groupedBackground)
            .navigationBarTitle("Edit Session", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { onDismiss() },
                trailing: Button(action: {
                    let primaryGoalId = selectedGoalIds.first ?? session.goalId
                    store.updateSession(id: session.id, goalId: primaryGoalId, taskIds: Array(selectedTaskIds), date: selectedDate)
                    onDismiss()
                }) {
                    Text("Save").font(.system(size: 17, weight: .medium, design: .rounded))
                }
            )
        }
    }

    // MARK: - Inline Calendar

    @ViewBuilder
    private var editSessionCalendar: some View {
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: selectedDate)) ?? selectedDate
        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let offset = (firstWeekday + 5) % 7 // Monday-start offset

        VStack(spacing: 12) {
            // Month nav
            HStack {
                Button(action: { shiftMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                }
                Spacer()
                Text(monthYearLabel(monthStart))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { shiftMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                }
            }

            // Day-of-week headers
            let days = ["M", "T", "W", "T", "F", "S", "S"]
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(days[i])
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let totalCells = offset + daysInMonth
            let rows = (totalCells + 6) / 7
            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let cellIndex = row * 7 + col
                            let dayNum = cellIndex - offset + 1
                            if dayNum >= 1 && dayNum <= daysInMonth {
                                let cellDate = cal.date(byAdding: .day, value: dayNum - 1, to: monthStart) ?? monthStart
                                let isSelected = cal.isDate(cellDate, inSameDayAs: selectedDate)
                                Button(action: { selectedDate = cellDate }) {
                                    Text("\(dayNum)")
                                        .font(.system(size: 15, weight: isSelected ? .bold : .regular, design: .rounded))
                                        .foregroundColor(isSelected ? .white : AppColors.label)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle().fill(isSelected ? AppColors.indigo : Color.clear)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(maxWidth: .infinity)
                            } else {
                                Color.clear.frame(width: 36, height: 36).frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray4), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func shiftMonth(_ direction: Int) {
        if let newDate = cal.date(byAdding: .month, value: direction, to: selectedDate) {
            selectedDate = cal.date(from: cal.dateComponents([.year, .month], from: newDate))
                .flatMap { cal.date(byAdding: .day, value: 0, to: $0) } ?? newDate
        }
    }

    private func monthYearLabel(_ date: Date) -> String {
        return DateFormatter.monthYear.string(from: date)
    }
}

// MARK: - Edit Goal
