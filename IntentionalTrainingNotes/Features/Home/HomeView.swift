import SwiftUI

enum PatternKind: String, CaseIterable {
    case all = "All"
    case wins = "Wins"
    case stuck = "Stuck"
    case upNext = "Up next"
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

    private var cal: Calendar { Calendar.current }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                streakHeader
                bountyCard
                nextSessionSection
                latestEntrySection
                patternsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
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

    // MARK: - Streak header

    private var streakHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Text("🔥 \(trainingStreak == 1 ? "1 week streak" : "\(trainingStreak) week streak")")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { sheet = .settings }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider().background(Color.white.opacity(0.25))

            weekTimeline

            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.25), lineWidth: 6).frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: ringFraction)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 80, height: 80)
                    Text("\(completedAllTime)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completedAllTime) / \(totalSessionsAllTime)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("mat sessions")
                        .font(.matMindBody(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(totalReflections)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.mint)
                    }
                    Text("reflections")
                        .font(.matMindBody(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }

            if bountyCount > 0 {
                Button(action: { sheet = .collection }) {
                    HStack(spacing: 6) {
                        Text("🏆 \(bountyCount) \(bountyCount == 1 ? "bounty" : "bounties") collected")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [AppColors.headerGradientTop, AppColors.headerGradientBottom]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
    }

    private var weekTimeline: some View {
        HStack(spacing: 6) {
            ForEach(Array(timelineWeeks.enumerated()), id: \.offset) { _, wk in
                let trained = doneWeeks.contains(wk)
                VStack(spacing: 6) {
                    Text(weekLabel(wk))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .fixedSize()
                    Capsule()
                        .fill(trained ? AppColors.mint : Color.white.opacity(0.22))
                        .frame(height: 6)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Bounty

    /// The single Home slot for bounties. Renders nothing until a goal qualifies,
    /// then the "set a challenge" card, then the full coral hero while a hunt is live.
    @ViewBuilder
    private var bountyCard: some View {
        if let bounty = store.activeBounty {
            activeBountyHero(bounty)
        } else if store.isBountyUnlocked {
            bountyUnlockedCard
        }
    }

    private var bountyUnlockedCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(AppColors.coral).frame(width: 5).padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("🎯 Bounty unlocked")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Text("You've put in the reps — set a challenge.")
                    .font(.matMindBody(size: 14))
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

    // MARK: - Next Session

    private var nextSessionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Next Session")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                if !nextSessions.isEmpty {
                    Text(nextSessionLabel)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            if nextSessions.isEmpty {
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
            } else {
                ForEach(nextSessions) { session in
                    SessionCardView(
                        store: store,
                        session: session,
                        onReflect: { onReflect(session.id) },
                        onEdit: { sheet = .editSession(session) },
                        onDelete: { store.deleteSession(id: session.id) }
                    )
                }
            }
        }
    }

    // MARK: - Latest Entry

    @ViewBuilder
    private var latestEntrySection: some View {
        if let latest = latestReflection {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Latest Entry")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Spacer()
                    Text(weekdayLabel(latest.date))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                ReflectionCardView(
                    store: store,
                    reflection: latest,
                    onReflect: { onReflect(latest.sessionId) },
                    onDelete: { store.deleteReflection(id: latest.id) },
                    onShareFeedback: { sheet = .feedback(latest) }
                )
            }
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
                Text(title).font(.matMindBody(size: 15)).foregroundColor(AppColors.label)
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

    private var nextSessionDay: Date? {
        let today = cal.startOfDay(for: Date())
        return store.notebook.sessions
            .map { cal.startOfDay(for: $0.date) }
            .filter { $0 >= today }
            .sorted()
            .first
    }
    private var nextSessions: [PlannedSession] {
        guard let day = nextSessionDay else { return [] }
        return store.notebook.sessions
            .filter { cal.isDate($0.date, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }
    }
    private var nextSessionLabel: String {
        guard let day = nextSessionDay else { return "" }
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f.string(from: day)
    }

    // MARK: - Reflection helpers

    private var latestReflection: Reflection? {
        store.notebook.reflections.sorted { $0.date > $1.date }.first
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

    private func weekLabel(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d) }
    private func weekdayLabel(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: d) }
    private func shortDateLabel(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d) }
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
