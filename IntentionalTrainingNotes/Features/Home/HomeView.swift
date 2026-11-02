import SwiftUI

enum PatternKind: String, CaseIterable {
    case all = "All"
    case wins = "Wins"
    case stuck = "Stuck"
    case upNext = "Up next"
}

enum HomeSubTab {
    case upcoming
    case stat
}

struct HomeView: View {
    @ObservedObject var store: NotebookStore
    var onOpenGoalTasks: (String) -> Void
    var onReflect: (String) -> Void
    var onPlanTraining: () -> Void
    var onAddGoal: () -> Void

    @State private var patternKind: PatternKind = .all
    @State private var patternGoalId: String?
    @State private var goalFilterOpen = false
    @State private var showFavoritesOnly = false
    @State private var sheet: HomeSheet?
    @State private var homeTab: HomeSubTab = .upcoming
    @State private var bountyLockedExpanded = false
    @State private var sessionToDelete: PlannedSession?

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                ScreenHeader(
                    titleLead: "Your",
                    titleAccent: "progress",
                    accent: AppColors.indigo,
                    titleSize: 26
                )
                Spacer()
                streakBadge
                Button(action: { sheet = .settings }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            subTabBar
                .padding(.horizontal, 16)
                .padding(.top, 10)

            if homeTab == .upcoming {
                upcomingTrainingContent
            } else {
                StatView(store: store)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .overlay(deleteSessionDialog)
        .sheet(item: $sheet) { which in
            switch which {
            case .settings:
                SettingsSheet()
            case .editSession(let session):
                EditSessionView(store: store, session: session) { sheet = nil }
            case .feedback(let reflection):
                FeedbackPreviewView(store: store, reflection: reflection, onClose: { sheet = nil })
            case .newBounty:
                BountyFlowView(store: store, onClose: { sheet = nil })
            case .collection:
                BountyCollectionView(store: store, onClose: { sheet = nil })
            }
        }
    }

    // MARK: - Sub-tabs (Upcoming training / Stat)

    private var subTabBar: some View {
        HStack(spacing: 26) {
            subTab("Upcoming training", .upcoming)
            subTab("Stat", .stat)
            Spacer(minLength: 0)
        }
        .overlay(
            Rectangle()
                .fill(AppColors.separator.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func subTab(_ title: String, _ tab: HomeSubTab) -> some View {
        let isActive = homeTab == tab
        return Button(action: { withAnimation(.easeInOut(duration: 0.2)) { homeTab = tab } }) {
            VStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 17, weight: isActive ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isActive ? AppColors.label : AppColors.secondaryLabel)
                Rectangle()
                    .fill(isActive ? AppColors.indigo : Color.clear)
                    .frame(height: 3)
                    .cornerRadius(1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var deleteSessionDialog: some View {
        if sessionToDelete != nil {
            ConfirmDialog(
                title: "Delete Session",
                message: "This training session will be permanently deleted.",
                onConfirm: {
                    if let s = sessionToDelete {
                        store.deleteSession(id: s.id)
                    }
                    sessionToDelete = nil
                },
                onCancel: {
                    sessionToDelete = nil
                }
            )
        }
    }

    private var upcomingTrainingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                weekTimelineBar
                heroNextSession
                    .zIndex(3)
                bountyCard
                patternsSection
                    .zIndex(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
    }

    // MARK: - Streak badge

    private var streakBadge: some View {
        let weeks = trainingStreak
        return HStack(spacing: 3) {
            Text("🔥")
                .font(.system(size: 13))
            Text("\(weeks)wk")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(AppColors.cardBackground)
                .overlay(Capsule().stroke(AppColors.cardBorder, lineWidth: 1))
        )
    }

    // MARK: - Week timeline bar

    private var weekTimelineBar: some View {
        let weeks = timelineWeeks
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { idx, wk in
                    let trained = doneWeeks.contains(wk)
                    let isFuture = wk > cal.mondayStartOfWeek(containing: Date())
                    Capsule()
                        .fill(trained ? AppColors.mint : AppColors.label.opacity(0.10))
                        .opacity(isFuture ? 0.55 : 1)
                        .frame(height: 5)
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 6) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { idx, wk in
                    Text(timelineBlockLabel(wk))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.secondaryBackground))
    }

    private func timelineMonthLabel(_ date: Date) -> String {
        let month = MonthStatsFormat.monthAbbrev.string(from: date)
        let yr = cal.component(.year, from: date) % 100
        return "\(month) '\(String(format: "%02d", yr))"
    }

    private func timelineBlockLabel(_ date: Date) -> String {
        let month = MonthStatsFormat.monthAbbrev.string(from: date)
        let day = cal.component(.day, from: date)
        return "\(month) \(day)"
    }

    // MARK: - Hero Next Session

    @ViewBuilder
    private var heroNextSession: some View {
        if nextSessions.isEmpty {
            // Empty state
            VStack(spacing: 12) {
                Text("Nothing planned yet.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onPlanTraining) {
                    Text("Plan Training")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.indigo))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
        } else {
            ForEach(nextSessions) { session in
                heroSessionWithReflection(session)
            }
        }
    }

    private func heroSessionCard(_ session: PlannedSession) -> some View {
        let goal = store.goal(id: session.goalId)
        let tasks = session.taskIds.compactMap { store.task(id: $0) }
        let reflected = store.reflection(forSessionId: session.id) != nil

        return VStack(alignment: .leading, spacing: 0) {
            // Eyebrow + date
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(AppColors.mint).frame(width: 8, height: 8)
                    Text("NEXT SESSION")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Text(nextSessionLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Goal name
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.18)).frame(width: 34, height: 34)
                    GoalIconImage(name: goal?.iconName ?? "target", color: .white, size: 18)
                }
                Text(goal?.name ?? "No goal")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if #available(iOS 14.0, *) {
                    Menu {
                        Button(action: { sheet = .editSession(session) }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(action: { sessionToDelete = session }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                } else {
                    Button(action: { sheet = .editSession(session) }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Tasks
            ForEach(tasks) { task in
                Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                heroTaskRow(task)
            }

            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)

            // Reflect button
            Button(action: { onReflect(session.id) }) {
                HStack(spacing: 6) {
                    Text(reflected ? "Reflected" : "Reflect after class")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.indigo)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.indigo)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(Color.white))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [AppColors.headerGradientTop, AppColors.headerGradientBottom]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Hero card + attached last reflection

    private func heroSessionWithReflection(_ session: PlannedSession) -> some View {
        let goalReflection = latestReflectionForGoal(session.goalId)

        return VStack(spacing: 0) {
            heroSessionCard(session)

            if let reflection = goalReflection {
                attachedReflectionSnippet(reflection)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func attachedReflectionSnippet(_ reflection: Reflection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(AppColors.separator).frame(height: 1)

            HStack {
                Text("LAST REFLECTION ON THIS GOAL")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                Text(shortDateLabel(reflection.date))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.tertiaryLabel)
            }

            if let text = reflection.workedText.nilIfBlank {
                reflectionSnippetBlock(label: "What worked", text: text, accent: AppColors.winGreen, tintUI: AppColors.winGreenUI)
            }
            if let text = reflection.stuckText.nilIfBlank {
                reflectionSnippetBlock(label: "Where I got stuck", text: text, accent: AppColors.stuckCoral, tintUI: AppColors.stuckCoralUI)
            }
            if let text = reflection.tryNextText.nilIfBlank {
                reflectionSnippetBlock(label: "What I'll try next", text: text, accent: AppColors.indigo, tintUI: AppColors.indigoUI)
            }

            if let mood = reflection.mood {
                HStack(spacing: 6) {
                    Text(mood.glyph).font(.system(size: 18))
                    Text(mood.label)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
    }

    private func reflectionSnippetBlock(label: String, text: String, accent: Color, tintUI: UIColor) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                Text(text)
                    .font(.matMonkeysBody(size: 13))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.tint(tintUI, light: 0.10, dark: 0.22)))
    }

    @ViewBuilder
    private func heroTaskRow(_ task: TrainingTask) -> some View {
        let images = task.imageFileNames.compactMap { fn -> UIImage? in
            store.taskImageData(taskId: task.id, fileName: fn).flatMap(UIImage.init(data:))
        }

        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.55), lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .padding(.top, 2)
                Text(task.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let notes = task.notes.nilIfBlank {
                Text(notes)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 26)
            }

            if let link = task.link.nilIfBlank, let url = URL(string: link) {
                Button(action: { UIApplication.shared.open(url) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                        Text(link)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(.leading, 26)
                    .padding(.top, 2)
                }
                .buttonStyle(PlainButtonStyle())
            }

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
                .padding(.leading, 26)
                .padding(.top, 7)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Bounty

    /// The single Home slot for bounties. Renders nothing until the user starts training,
    /// then the "locked" progress card, then "set a challenge", then the live hunt hero.
    @ViewBuilder
    private var bountyCard: some View {
        if let bounty = store.activeBounty {
            activeBountyHero(bounty)
        } else if store.isBountyUnlocked {
            bountyUnlockedCard
        } else if store.isBountyLocked {
            bountyLockedCard
        }
    }

    // MARK: Bounty · locked (building toward eligibility)

    private var bountyLockedCard: some View {
        let goals = store.bountyProgressGoals
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.coral.opacity(0.16))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "lock.fill")
                            .font(.system(size: 17))
                            .foregroundColor(AppColors.coralDeep)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("BOUNTY LOCKED")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(AppColors.coralDeep)
                    Text("Make training progress to unlock the hunt")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { bountyLockedExpanded.toggle() } }) {
                    Image(systemName: bountyLockedExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            if bountyLockedExpanded {
                HStack {
                    Text("GOALS IN PROGRESS")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundColor(AppColors.secondaryLabel)
                    Spacer()
                    Text("\(goals.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppColors.secondaryBackground))
                }

                VStack(spacing: 10) {
                    ForEach(goals, id: \.goal.id) { item in
                        bountyProgressRow(goal: item.goal, sessionsReflected: item.sessionsReflected)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(AppColors.cardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(AppColors.coral.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }

    private func bountyProgressRow(goal: TrainingGoal, sessionsReflected: Int) -> some View {
        let target = NotebookStore.bountyUnlockSessions
        let fraction = min(1, CGFloat(sessionsReflected) / CGFloat(target))
        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(goal.goalColor).frame(width: 3)
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Circle().fill(goal.goalColor).frame(width: 8, height: 8)
                    Text(goal.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Spacer(minLength: 0)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.separator.opacity(0.6))
                        Capsule().fill(AppColors.coral)
                            .frame(width: fraction <= 0 ? 0 : max(6, geo.size.width * fraction))
                    }
                }
                .frame(height: 6)
                Text("\(sessionsReflected) / \(target) sessions reflected")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            .padding(.leading, 12)
            .padding(.vertical, 12)
        }
        .padding(.trailing, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.secondaryBackground.opacity(0.55)))
    }

    private var bountyUnlockedCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(AppColors.coral).frame(width: 5).padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("🎯 Bounty unlocked")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Text("You've put in the reps — set a challenge.")
                    .font(.matMonkeysBody(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            Spacer()
            Button(action: { sheet = .newBounty }) {
                Text("Set")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(AppColors.coralDeep))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.cardBorder, lineWidth: 1))
    }

    private func activeBountyHero(_ bounty: Bounty) -> some View {
        let stats = store.bountyStats(bounty)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "target").font(.system(size: 12, weight: .bold))
                Text("BOUNTY ACTIVE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.6)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.22)))

            Text(store.bountyTitle(bounty) + ".")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("PROGRESS")
                Spacer()
                Text("\(bounty.hitCount) / \(bounty.requiredHits)")
            }
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundColor(.white.opacity(0.9))

            bountyProgress(bounty)

            Button(action: {
                let updated = store.recordBountyHit(id: bounty.id)
                if updated?.status == .collected {
                    sheet = .collection
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                    Text("I hit it")
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.coralDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            }
            .buttonStyle(PlainButtonStyle())

            Text("Tap the moment you land it · Day \(stats.days) of the hunt")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [AppColors.coral, AppColors.coralDeep]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }

    /// Progress dots for small targets; a filling bar once the target grows past 6.
    @ViewBuilder
    private func bountyProgress(_ bounty: Bounty) -> some View {
        if bounty.requiredHits <= 6 {
            HStack(spacing: 8) {
                ForEach(0..<bounty.requiredHits, id: \.self) { i in
                    let landed = i < bounty.hitCount
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(landed ? Color.white.opacity(0.95) : Color.clear)
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(landed ? 0 : 0.4), style: StrokeStyle(lineWidth: 1.5, dash: landed ? [] : [4, 3]))
                        if landed, i < bounty.hitDates.count {
                            Text(DateFormatter.monthDay.string(from: bounty.hitDates[i]))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.coralDeep)
                        }
                    }
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            let fraction = CGFloat(bounty.hitCount) / CGFloat(bounty.requiredHits)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule().fill(Color.white).frame(width: max(10, geo.size.width * fraction))
                }
            }
            .frame(height: 10)
        }
    }

    // MARK: - Patterns

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Patterns — \(filteredReflections.count) \(filteredReflections.count == 1 ? "entry" : "entries")")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showFavoritesOnly.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(showFavoritesOnly ? AppColors.coral : AppColors.secondaryLabel)
                        Text("\(favoritesCount) favorites")
                            .font(.system(size: 14, weight: showFavoritesOnly ? .semibold : .regular, design: .rounded))
                            .foregroundColor(showFavoritesOnly ? AppColors.coral : AppColors.secondaryLabel)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(showFavoritesOnly ? AppColors.coral.opacity(0.12) : Color.clear))
                }
                .buttonStyle(PlainButtonStyle())
            }

            HStack(alignment: .center, spacing: 8) {
                goalFilterControl
                Spacer(minLength: 8)
                kindFilterControl
            }

            if groupedReflections.isEmpty {
                EmptyDashedState(title: "No entries yet.", subtitle: "Reflect after a session to spot patterns.")
            } else {
                ForEach(groupedReflections, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle().fill(AppColors.tertiaryLabel).frame(width: 7, height: 7)
                            Text(shortDateLabel(group.date))
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.label)
                        }
                        ForEach(group.items) { reflection in
                            ReflectionCardView(
                                store: store,
                                reflection: reflection,
                                onReflect: { onReflect(reflection.sessionId) },
                                onDelete: { store.deleteReflection(id: reflection.id) },
                                onShareFeedback: { sheet = .feedback(reflection) },
                                filter: patternKind
                            )
                        }
                    }
                }
            }
        }
        .overlay(
            ZStack(alignment: .topLeading) {
                if goalFilterOpen {
                    // Soft-dismiss backdrop — uses .overlay so it doesn't affect parent layout
                    Color.black.opacity(0.001)
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        .fixedSize()
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { goalFilterOpen = false } }

                    VStack(alignment: .leading, spacing: 0) {
                        goalFilterRow(title: "All", id: nil)
                        ForEach(store.activeGoals) { goal in
                            Divider()
                            goalFilterRow(title: goal.name, id: goal.id)
                        }
                    }
                    .background(AppColors.background)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray4), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 6)
                    .frame(width: 200)
                    .fixedSize()
                    .offset(x: 0, y: 80)
                }
            }
            .allowsHitTesting(goalFilterOpen),
            alignment: .topLeading
        )
    }

    private var goalFilterControl: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { goalFilterOpen.toggle() } }) {
            HStack(spacing: 4) {
                Text(patternGoalId.flatMap { store.goal(id: $0)?.name } ?? "All")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.secondaryLabel)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(AppColors.cardBackground))
        }
        .buttonStyle(PlainButtonStyle())
        .fixedSize()
    }

    private func goalFilterRow(title: String, id: String?) -> some View {
        Button(action: {
            patternGoalId = id
            withAnimation(.easeInOut(duration: 0.15)) { goalFilterOpen = false }
        }) {
            HStack {
                Text(title).font(.matMonkeysBody(size: 15)).foregroundColor(AppColors.label)
                Spacer()
                if patternGoalId == id {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.indigo)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var kindFilterControl: some View {
        HStack(spacing: 2) {
            ForEach(PatternKind.allCases, id: \.self) { kind in
                Button(action: { patternKind = kind }) {
                    Text(kind.rawValue)
                        .font(.system(size: 13, weight: patternKind == kind ? .semibold : .regular, design: .rounded))
                        .foregroundColor(patternKind == kind ? AppColors.indigo : AppColors.secondaryLabel)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(patternKind == kind ? AppColors.indigo.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .fixedSize()
            }
        }
        .fixedSize()
    }

    // MARK: - Stats

    private var completedAllTime: Int {
        store.notebook.sessions.filter { $0.status == .done }.count
    }
    private var totalSessionsAllTime: Int {
        max(store.notebook.sessions.count, completedAllTime)
    }
    private var ringFraction: CGFloat {
        totalSessionsAllTime == 0 ? 0 : CGFloat(completedAllTime) / CGFloat(totalSessionsAllTime)
    }
    private var totalReflections: Int { store.notebook.reflections.count }
    private var favoritesCount: Int { store.notebook.reflections.filter { $0.isFavorite }.count }
    private var bountyCount: Int { store.collectedBountyCount }

    /// Consecutive weeks with at least one completed session, counting back from the current week.
    private var trainingStreak: Int {
        let doneWeeks = self.doneWeeks
        var streak = 0
        var weekStart = cal.mondayStartOfWeek(containing: Date())
        if !doneWeeks.contains(weekStart) {
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { return 0 }
            weekStart = prev
        }
        while doneWeeks.contains(weekStart) {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { break }
            weekStart = prev
        }
        return streak
    }

    private var doneWeeks: Set<Date> {
        Set(store.notebook.sessions.filter { $0.status == .done }.map { cal.mondayStartOfWeek(containing: $0.date) })
    }

    private var timelineWeeks: [Date] {
        let current = cal.mondayStartOfWeek(containing: Date())
        return (-5...2).compactMap { cal.date(byAdding: .weekOfYear, value: $0, to: current) }
    }

    // MARK: - Next session helpers

    /// A planned session belongs in "Next session" only until it has been
    /// reflected on. Once a reflection exists, it drops off the list.
    private func isReflected(_ session: PlannedSession) -> Bool {
        store.reflection(forSessionId: session.id) != nil
    }

    private var nextSessionDay: Date? {
        let today = cal.startOfDay(for: Date())
        return store.notebook.sessions
            .filter { !isReflected($0) }
            .map { cal.startOfDay(for: $0.date) }
            .filter { $0 >= today }
            .sorted()
            .first
    }
    private var nextSessions: [PlannedSession] {
        guard let day = nextSessionDay else { return [] }
        return store.notebook.sessions
            .filter { cal.isDate($0.date, inSameDayAs: day) && !isReflected($0) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    private var nextSessionLabel: String {
        guard let day = nextSessionDay else { return "" }
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return DateFormatter.weekdayShortDate.string(from: day)
    }

    // MARK: - Reflection helpers

    private func latestReflectionForGoal(_ goalId: String) -> Reflection? {
        let goalSessionIds = Set(store.notebook.sessions.filter { $0.goalId == goalId }.map { $0.id })
        return store.notebook.reflections
            .filter { goalSessionIds.contains($0.sessionId) }
            .sorted { $0.date > $1.date }
            .first
    }

    private func goal(for reflection: Reflection) -> TrainingGoal? {
        guard let s = store.notebook.sessions.first(where: { $0.id == reflection.sessionId }) else { return nil }
        return store.goal(id: s.goalId)
    }

    private var filteredReflections: [Reflection] {
        store.notebook.reflections
            .filter { r in
                (patternGoalId == nil || goal(for: r)?.id == patternGoalId)
                    && kindMatches(r)
                    && (!showFavoritesOnly || r.isFavorite)
            }
            .sorted { $0.date > $1.date }
    }

    private func kindMatches(_ r: Reflection) -> Bool {
        switch patternKind {
        case .all: return true
        case .wins: return r.workedText.nilIfBlank != nil
        case .stuck: return r.stuckText.nilIfBlank != nil
        case .upNext: return r.tryNextText.nilIfBlank != nil
        }
    }

    private var groupedReflections: [(date: Date, items: [Reflection])] {
        let groups = Dictionary(grouping: filteredReflections) { cal.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { key in
            (date: key, items: groups[key]!.sorted { $0.updatedAt > $1.updatedAt })
        }
    }

    // MARK: - Labels

    private func weekLabel(_ d: Date) -> String { DateFormatter.monthDay.string(from: d) }
    private func shortDateLabel(_ d: Date) -> String { DateFormatter.monthDay.string(from: d) }
}

// MARK: - Bounty Flow

/// New Bounty flow: pick shape → pick technique → set the target. Presented as a
/// sheet from Home. Creates the bounty and dismisses on "Start Bounty".
enum HomeSheet: Identifiable {
    case settings
    case editSession(PlannedSession)
    case feedback(Reflection)
    case newBounty
    case collection
    var id: String {
        switch self {
        case .settings: return "settings"
        case .editSession(let s): return "edit-\(s.id)"
        case .feedback(let r): return "feedback-\(r.id)"
        case .newBounty: return "new-bounty"
        case .collection: return "collection"
        }
    }
}
