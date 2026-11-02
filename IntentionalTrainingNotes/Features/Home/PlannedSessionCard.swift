import SwiftUI

/// Planned-session card — **3A Flat rows**. Used by Home "Next session" and the Plan tab.
///
/// One flat white card. Tasks are full-width rows separated by hairlines (no
/// nested tiles). A task with photo(s) shows the image(s) below its description;
/// a task without a photo stretches its title and copy edge to edge.
struct PlannedSessionCard: View {
    @ObservedObject var store: NotebookStore
    let session: PlannedSession
    var onReflect: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var menuOpen = false
    @State private var showDeleteConfirm = false

    var body: some View {
        let goal = store.goal(id: session.goalId)
        // Next-session cards always use the app's indigo accent; the goal's
        // user-selected color is reserved for goal cards under the Goals tab.
        let color = AppColors.indigo
        let tasks = session.taskIds.compactMap { store.task(id: $0) }
        let reflected = store.reflection(forSessionId: session.id) != nil

        VStack(spacing: 0) {
            header(goal, color)

            ForEach(tasks) { task in
                hairline(color)
                taskRow(task, color)
            }

            hairline(color)
            reflectFooter(color, reflected: reflected)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(color.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.20), radius: 15, x: 0, y: 10)
        .overlay(menuOverlay, alignment: .topTrailing)
        .overlay(deleteConfirmOverlay)
    }

    @ViewBuilder
    private var deleteConfirmOverlay: some View {
        if showDeleteConfirm {
            ConfirmDialog(
                title: "Delete Session",
                message: "This training session will be permanently deleted.",
                onConfirm: {
                    showDeleteConfirm = false
                    onDelete()
                },
                onCancel: {
                    showDeleteConfirm = false
                }
            )
        }
    }

    // MARK: - Hairline divider

    private func hairline(_ color: Color) -> some View {
        Rectangle()
            .fill(color.opacity(0.10))
            .frame(height: 1)
    }

    // MARK: - Header (goal + overflow)

    private func header(_ goal: TrainingGoal?, _ color: Color) -> some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 24, height: 24)
                GoalIconImage(name: goal?.iconName ?? "target", color: color, size: 14)
            }
            Text(goal?.name ?? "No goal")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { menuOpen.toggle() } }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.tertiaryLabel)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Reflect footer (text link, like "View Spending ›")

    private func reflectFooter(_ color: Color, reflected: Bool) -> some View {
        let isFuture = Calendar.current.startOfDay(for: session.date) > Calendar.current.startOfDay(for: Date())
        let disabled = isFuture && !reflected

        return Button(action: onReflect) {
            HStack(spacing: 6) {
                Text(reflected ? "Reflected" : "Reflect after class")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(disabled ? AppColors.tertiaryLabel : color)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(disabled ? AppColors.tertiaryLabel : color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
    }

    // MARK: - Task row (flat, hairline-separated)

    @ViewBuilder
    private func taskRow(_ task: TrainingTask, _ color: Color) -> some View {
        let images = task.imageFileNames.compactMap { fn -> UIImage? in
            store.taskImageData(taskId: task.id, fileName: fn).flatMap(UIImage.init(data:))
        }

        VStack(alignment: .leading, spacing: 5) {
            Text(task.name)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(AppColors.label)
                .fixedSize(horizontal: false, vertical: true)

            if let notes = task.notes.nilIfBlank {
                Text(notes)
                    .font(.gripGorillasBody(size: 13))
                    .foregroundColor(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            linkRow(task, color)

            if !images.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, ui in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .overlay(
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.top, 7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func linkRow(_ task: TrainingTask, _ color: Color) -> some View {
        if let link = task.link.nilIfBlank {
            HStack(spacing: 6) {
                Image(systemName: "link").font(.system(size: 12)).foregroundColor(color)
                Text(link)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Overflow menu

    @ViewBuilder
    private var menuOverlay: some View {
        if menuOpen {
            ZStack(alignment: .topTrailing) {
                GeometryReader { geo in
                    let f = geo.frame(in: .global)
                    Color.black.opacity(0.001)
                        .frame(width: UIScreen.main.bounds.width,
                               height: UIScreen.main.bounds.height)
                        .contentShape(Rectangle())
                        .position(x: UIScreen.main.bounds.midX - f.minX,
                                  y: UIScreen.main.bounds.midY - f.minY)
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { menuOpen = false } }
                }
                .edgesIgnoringSafeArea(.all)

                VStack(alignment: .leading, spacing: 0) {
                    menuRow(icon: "pencil", label: "Edit", color: AppColors.label) {
                        menuOpen = false
                        onEdit()
                    }
                    Divider().padding(.horizontal, 10)
                    menuRow(icon: "trash", label: "Delete", color: AppColors.coral) {
                        menuOpen = false
                        showDeleteConfirm = true
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
                Image(systemName: icon).font(.gripGorillasBody(size: 14)).foregroundColor(color)
                Text(label).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
