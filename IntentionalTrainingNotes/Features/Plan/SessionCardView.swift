import SwiftUI

struct SessionCardView: View {
    @ObservedObject var store: NotebookStore
    let session: PlannedSession
    var onReflect: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var menuOpen = false

    var body: some View {
        let goal = store.goal(id: session.goalId)
        let color = goal?.goalColor ?? AppColors.indigo
        let tasks = session.taskIds.compactMap { store.task(id: $0) }
        let reflected = store.reflection(forSessionId: session.id) != nil

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    GoalIconImage(name: goal?.iconName ?? "target", color: color, size: 18)
                    Text(goal?.name ?? "No goal")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.label)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(color.opacity(0.14)))

                Spacer()

                Button(action: onReflect) {
                    HStack(spacing: 4) {
                        ReflectPencilIcon(size: 14, color: AppColors.indigo)
                        Text(reflected ? "Reflected" : "Reflect")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.indigo)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { menuOpen.toggle() } }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 28, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(tasks) { task in
                        sessionTaskRow(task, color, isLast: task.id == tasks.last?.id)
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 16)
            }
        }
        .padding(14)
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
        .overlay(
            HStack(spacing: 0) {
                Rectangle().fill(color).frame(width: 4)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        .overlay(menuOverlay, alignment: .topTrailing)
    }

    // MARK: Task row (matches "Next Session" screenshot design)

    @ViewBuilder
    private func sessionTaskRow(_ task: TrainingTask, _ color: Color, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(color)
                    .frame(width: 6, height: 6)
                    .padding(.top, 7)
                Text(task.name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            sessionTaskDetail(task, color)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func sessionTaskDetail(_ task: TrainingTask, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let notes = task.notes.nilIfBlank {
                Text(notes)
                    .font(.matMindBody(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !task.imageFileNames.isEmpty {
                VStack(spacing: 8) {
                    ForEach(task.imageFileNames, id: \.self) { fn in
                        if let data = store.taskImageData(taskId: task.id, fileName: fn), let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            if let link = task.link.nilIfBlank {
                HStack(spacing: 8) {
                    Image(systemName: "link").font(.system(size: 13)).foregroundColor(color)
                    Text(link).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(color).lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var menuOverlay: some View {
        if menuOpen {
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.001)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .fixedSize()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { menuOpen = false } }

                VStack(alignment: .leading, spacing: 0) {
                    menuRow(icon: "pencil", label: "Edit", color: AppColors.label) {
                        menuOpen = false
                        onEdit()
                    }
                    Divider().padding(.horizontal, 10)
                    menuRow(icon: "trash", label: "Delete", color: AppColors.coral) {
                        menuOpen = false
                        onDelete()
                    }
                }
                .background(AppColors.background)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 2)
                .frame(width: 150)
                .padding(.top, 44)
                .padding(.trailing, 8)
            }
        }
    }

    private func menuRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.matMindBody(size: 14)).foregroundColor(color)
                Text(label).font(.matMindBody(size: 15)).foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Plan (month calendar)
