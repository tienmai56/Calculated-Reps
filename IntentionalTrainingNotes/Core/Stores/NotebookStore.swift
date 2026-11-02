import Foundation
import SwiftUI
import UIKit

final class NotebookStore: ObservableObject {
    @Published private(set) var notebook: TrainingNotebook
    @Published var errorMessage: String?

    let persistence: NotebookPersistence
    private let calendar: Calendar
    private var loadFailed = false

    init(
        accountId: String = "local",
        persistence: NotebookPersistence = JSONNotebookPersistence(),
        calendar: Calendar = .current
    ) {
        self.persistence = persistence
        self.calendar = calendar
        do {
            self.notebook = try persistence.load(accountId: accountId)
        } catch {
            self.notebook = TrainingNotebook(accountId: accountId)
            self.errorMessage = "Could not read saved training data. Original files have been preserved. Changes are disabled."
            self.loadFailed = true
        }
    }

    var profile: UserProfile? { notebook.profile }
    var activeGoals: [TrainingGoal] { notebook.goals.filter { !$0.isArchived && $0.name.nilIfBlank != nil }.sorted { $0.createdAt < $1.createdAt } }

    func saveProfile(_ profile: UserProfile) {
        mutate {
            notebook.profile = profile
        }
    }

    @discardableResult
    func addGoal(name: String, iconName: String = "target", colorName: String = "indigo") -> TrainingGoal? {
        guard let trimmed = name.nilIfBlank else { return nil }
        let goal = TrainingGoal(accountId: notebook.accountId, name: trimmed, iconName: iconName, colorName: colorName)
        mutate { notebook.goals.append(goal) }
        return goal
    }

    /// Creates an unnamed draft goal so the rich `EditGoalView` (live task notes/links/photos)
    /// can be reused for goal creation. Drafts are hidden from `activeGoals` until named, and
    /// discarded on dismiss if left unnamed.
    @discardableResult
    func createDraftGoal() -> TrainingGoal {
        let goal = TrainingGoal(accountId: notebook.accountId, name: "", iconName: "target", colorName: "indigo")
        mutate { notebook.goals.append(goal) }
        return goal
    }

    func updateGoal(id: String, name: String, iconName: String, colorName: String) {
        mutate {
            guard let index = notebook.goals.firstIndex(where: { $0.id == id }) else { return }
            notebook.goals[index].name = name
            notebook.goals[index].iconName = iconName
            notebook.goals[index].colorName = colorName
            notebook.goals[index].updatedAt = Date()
        }
    }

    @discardableResult
    func addTask(goalId: String, name: String) -> TrainingTask? {
        guard let trimmed = name.nilIfBlank, goal(id: goalId) != nil else { return nil }
        let task = TrainingTask(goalId: goalId, name: trimmed)
        mutate { notebook.tasks.append(task) }
        return task
    }

    func updateTask(id: String, name: String? = nil, notes: String? = nil, link: String? = nil, imageFileNames: [String]? = nil) {
        guard let idx = notebook.tasks.firstIndex(where: { $0.id == id }) else { return }
        mutate {
            if let name = name?.nilIfBlank { notebook.tasks[idx].name = name }
            if let notes = notes { notebook.tasks[idx].notes = notes }
            if let link = link { notebook.tasks[idx].link = link }
            if let imgs = imageFileNames { notebook.tasks[idx].imageFileNames = imgs }
            notebook.tasks[idx].updatedAt = Date()
        }
    }

    @discardableResult
    func addTaskImage(taskId: String, imageData: Data) -> String? {
        guard let idx = notebook.tasks.firstIndex(where: { $0.id == taskId }),
              let jsonPersistence = persistence as? JSONNotebookPersistence else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        do {
            _ = try jsonPersistence.saveTaskImage(accountId: notebook.accountId, taskId: taskId, imageData: imageData, fileName: fileName)
        } catch {
            errorMessage = "Could not save image."
            return nil
        }
        mutate {
            notebook.tasks[idx].imageFileNames.append(fileName)
            notebook.tasks[idx].updatedAt = Date()
        }
        return fileName
    }

    func removeTaskImage(taskId: String, fileName: String) {
        guard let idx = notebook.tasks.firstIndex(where: { $0.id == taskId }) else { return }
        if let jsonPersistence = persistence as? JSONNotebookPersistence {
            let url = jsonPersistence.taskImagesDirectory(accountId: notebook.accountId, taskId: taskId).appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
        mutate {
            notebook.tasks[idx].imageFileNames.removeAll { $0 == fileName }
            notebook.tasks[idx].updatedAt = Date()
        }
    }

    func taskImageData(taskId: String, fileName: String) -> Data? {
        guard let jsonPersistence = persistence as? JSONNotebookPersistence else { return nil }
        return jsonPersistence.loadTaskImage(accountId: notebook.accountId, taskId: taskId, fileName: fileName)
    }

    func archiveGoal(id: String) {
        mutate {
            guard let index = notebook.goals.firstIndex(where: { $0.id == id }) else { return }
            notebook.goals[index].isArchived = true
            notebook.goals[index].updatedAt = Date()
        }
    }

    func deleteTaskCascade(taskId: String) {
        mutate {
            notebook.tasks.removeAll { $0.id == taskId }
            // Remove taskId from all sessions
            for i in notebook.sessions.indices {
                notebook.sessions[i].taskIds.removeAll { $0 == taskId }
            }
            // Delete sessions that have no tasks left
            let emptySessions = Set(notebook.sessions.filter { $0.taskIds.isEmpty }.map(\.id))
            notebook.sessions.removeAll { emptySessions.contains($0.id) }
            notebook.reflections.removeAll { emptySessions.contains($0.sessionId) }
        }
    }

    func cascadeSummary(forTask taskId: String) -> TaskCascadeSummary {
        // Count sessions that would become empty (only have this one task)
        let emptySessionIds = Set(notebook.sessions.filter { $0.taskIds == [taskId] }.map(\.id))
        return TaskCascadeSummary(
            sessionCount: emptySessionIds.count,
            reflectionCount: notebook.reflections.filter { emptySessionIds.contains($0.sessionId) }.count
        )
    }

    func deleteGoalCascade(goalId: String) {
        let taskIds = Set(notebook.tasks.filter { $0.goalId == goalId }.map(\.id))
        let sessionIds = Set(notebook.sessions.filter { $0.goalId == goalId }.map(\.id))
        mutate {
            notebook.goals.removeAll { $0.id == goalId }
            notebook.tasks.removeAll { taskIds.contains($0.id) }
            notebook.sessions.removeAll { sessionIds.contains($0.id) }
            notebook.reflections.removeAll { sessionIds.contains($0.sessionId) }
        }
    }

    func goalCascadeSummary(goalId: String) -> GoalCascadeSummary {
        let taskCount = notebook.tasks.filter { $0.goalId == goalId }.count
        let sessionIds = Set(notebook.sessions.filter { $0.goalId == goalId }.map(\.id))
        return GoalCascadeSummary(
            taskCount: taskCount,
            sessionCount: sessionIds.count,
            reflectionCount: notebook.reflections.filter { sessionIds.contains($0.sessionId) }.count
        )
    }

    func goal(id: String) -> TrainingGoal? {
        notebook.goals.first { $0.id == id }
    }

    func task(id: String) -> TrainingTask? {
        notebook.tasks.first { $0.id == id }
    }

    func tasks(forGoal goalId: String) -> [TrainingTask] {
        notebook.tasks.filter { $0.goalId == goalId }.sorted { $0.createdAt < $1.createdAt }
    }

    func sessions(forGoal goalId: String) -> [PlannedSession] {
        notebook.sessions
            .filter { $0.goalId == goalId }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.createdAt > rhs.createdAt }
                return lhs.date > rhs.date
            }
    }

    func sessions(forTask taskId: String, goalId: String) -> [PlannedSession] {
        notebook.sessions
            .filter { $0.goalId == goalId && $0.taskIds.contains(taskId) }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.createdAt > rhs.createdAt }
                return lhs.date > rhs.date
            }
    }

    func reflection(forSessionId sessionId: String) -> Reflection? {
        notebook.reflections.first { $0.sessionId == sessionId }
    }

    func reflections(on date: Date) -> [Reflection] {
        notebook.reflections.filter { calendar.sameTrainingDay($0.date, date) }
    }

    /// All reflections whose session contains the given task, newest first.
    func reflections(forTaskId taskId: String) -> [Reflection] {
        let sessionIds = Set(notebook.sessions.filter { $0.taskIds.contains(taskId) }.map { $0.id })
        return notebook.reflections
            .filter { sessionIds.contains($0.sessionId) }
            .sorted { $0.date > $1.date }
    }

    func proposeBatchSessions(goalId: String, dayDates: [Date], tasksByDay: [Date: [String]]) -> [ProposedSession] {
        dayDates.map { date in
            let normalized = calendar.normalizedTrainingDay(date)
            let taskIds = tasksByDay[normalized] ?? tasksByDay[date] ?? []
            return ProposedSession(goalId: goalId, date: normalized, taskIds: taskIds)
        }
    }

    func proposeSessions(date: Date, selectedGoalIds: [String], selectedTaskIds: [String]) -> [ProposedSession] {
        let normalized = calendar.normalizedTrainingDay(date)
        return selectedGoalIds.map { goalId in
            let goalTaskIds = Set(tasks(forGoal: goalId).map(\.id))
            return ProposedSession(
                goalId: goalId,
                date: normalized,
                taskIds: selectedTaskIds.filter { goalTaskIds.contains($0) }
            )
        }
    }

    func duplicateConflicts(for proposed: [ProposedSession]) -> [DuplicatePlanConflict] {
        var conflicts: [DuplicatePlanConflict] = []
        for proposal in proposed {
            let matches = conflictingSessions(for: proposal)
            guard !matches.isEmpty, let goal = goal(id: proposal.goalId) else { continue }

            let sharedIds = Set(matches.flatMap(\.taskIds)).intersection(Set(proposal.taskIds))
            let names = Array(sharedIds)
                .compactMap { task(id: $0)?.name }
                .sorted()
            conflicts.append(
                DuplicatePlanConflict(
                    goal: goal,
                    date: proposal.date,
                    sharedTaskNames: names
                )
            )
        }
        return conflicts
    }

    @discardableResult
    func planSessions(_ proposed: [ProposedSession], overrideConflicts: Bool) -> [PlannedSession] {
        var created: [PlannedSession] = []
        mutate {
            for proposal in proposed {
                let conflicts = overrideConflicts ? conflictingSessions(for: proposal) : []
                let session = PlannedSession(goalId: proposal.goalId, date: proposal.date, taskIds: proposal.taskIds)
                let conflictIds = Set(conflicts.map(\.id))
                if !conflictIds.isEmpty {
                    notebook.reflections = notebook.reflections.map { reflection in
                        guard conflictIds.contains(reflection.sessionId) else { return reflection }
                        var moved = reflection
                        moved.sessionId = session.id
                        moved.date = session.date
                        moved.updatedAt = Date()
                        return moved
                    }
                    notebook.sessions.removeAll { conflictIds.contains($0.id) }
                }
                notebook.sessions.append(session)
                created.append(session)
            }
        }
        return created
    }

    @discardableResult
    func saveReflection(sessionId: String, mood: Mood?, workedText: String, stuckText: String, tryNextText: String, link: String = "", imageFileNames: [String] = []) -> Reflection? {
        guard let sessionIndex = notebook.sessions.firstIndex(where: { $0.id == sessionId }) else { return nil }
        let session = notebook.sessions[sessionIndex]
        let existing = notebook.reflections.first { $0.sessionId == sessionId }
        let reflection = Reflection(
            id: existing?.id ?? "r_\(UUID().uuidString)",
            sessionId: session.id,
            date: session.date,
            workedText: workedText.trimmingCharacters(in: .whitespacesAndNewlines),
            stuckText: stuckText.trimmingCharacters(in: .whitespacesAndNewlines),
            tryNextText: tryNextText.trimmingCharacters(in: .whitespacesAndNewlines),
            mood: mood,
            isFavorite: existing?.isFavorite ?? false,
            link: link.trimmingCharacters(in: .whitespacesAndNewlines),
            imageFileNames: imageFileNames,
            createdAt: existing?.createdAt ?? Date()
        )
        mutate {
            notebook.reflections.removeAll { $0.sessionId == sessionId }
            notebook.reflections.append(reflection)
            notebook.sessions[sessionIndex].status = .done
            notebook.sessions[sessionIndex].updatedAt = Date()
        }
        return reflection
    }

    /// Reflection rules:
    /// - Editing an existing reflection is always allowed.
    /// - If the session's day is already in the past, it has happened → reflect right away.
    /// - Otherwise (today or future) require at least one hour since it was planned
    ///   (a proxy for "the session has actually happened" when we only store a day, not a time).
    func canReflect(sessionId: String) -> Bool {
        guard let session = notebook.sessions.first(where: { $0.id == sessionId }) else { return false }
        if reflection(forSessionId: sessionId) != nil { return true }
        if session.date < calendar.startOfDay(for: Date()) { return true }
        return Date() >= session.createdAt.addingTimeInterval(3600)
    }

    @discardableResult
    func addReflectionImage(sessionId: String, imageData: Data) -> String? {
        guard let jsonPersistence = persistence as? JSONNotebookPersistence else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        do {
            _ = try jsonPersistence.saveReflectionImage(accountId: notebook.accountId, reflectionId: sessionId, imageData: imageData, fileName: fileName)
        } catch {
            errorMessage = "Could not save image."
            return nil
        }
        return fileName
    }

    func reflectionImageData(sessionId: String, fileName: String) -> Data? {
        guard let jsonPersistence = persistence as? JSONNotebookPersistence else { return nil }
        return jsonPersistence.loadReflectionImage(accountId: notebook.accountId, reflectionId: sessionId, fileName: fileName)
    }

    func toggleFavorite(reflectionId: String) {
        guard let idx = notebook.reflections.firstIndex(where: { $0.id == reflectionId }) else { return }
        mutate {
            notebook.reflections[idx].isFavorite.toggle()
            notebook.reflections[idx].updatedAt = Date()
        }
    }

    func deleteReflection(id: String) {
        mutate {
            if let reflection = notebook.reflections.first(where: { $0.id == id }),
               let sessionIdx = notebook.sessions.firstIndex(where: { $0.id == reflection.sessionId }) {
                notebook.sessions[sessionIdx].status = .planned
                notebook.sessions[sessionIdx].updatedAt = Date()
            }
            notebook.reflections.removeAll { $0.id == id }
        }
    }

    func updateSession(id: String, goalId: String, taskIds: [String], date: Date? = nil) {
        guard let idx = notebook.sessions.firstIndex(where: { $0.id == id }) else { return }
        mutate {
            notebook.sessions[idx].goalId = goalId
            notebook.sessions[idx].taskIds = taskIds
            if let newDate = date {
                notebook.sessions[idx].date = Calendar.current.normalizedTrainingDay(newDate)
            }
            notebook.sessions[idx].updatedAt = Date()
        }
    }

    /// Saves an edited session so that each goal becomes its own session (card) on
    /// the given date. The existing session id is reused for one goal (preferring
    /// its current goal) so any reflection stays linked; remaining goals get new
    /// sessions. Tasks are grouped by their owning goal.
    func updateSessionSplittingByGoal(id: String, taskIds: [String], date: Date) {
        guard let idx = notebook.sessions.firstIndex(where: { $0.id == id }) else { return }
        let day = Calendar.current.normalizedTrainingDay(date)

        // Group selected tasks by their owning goal.
        var tasksByGoal: [String: [String]] = [:]
        for tid in taskIds {
            guard let gid = notebook.tasks.first(where: { $0.id == tid })?.goalId else { continue }
            tasksByGoal[gid, default: []].append(tid)
        }

        mutate {
            // No tasks selected: keep the session on its current goal, cleared.
            guard !tasksByGoal.isEmpty else {
                notebook.sessions[idx].taskIds = []
                notebook.sessions[idx].date = day
                notebook.sessions[idx].updatedAt = Date()
                return
            }

            // Reuse the existing session for one goal (its current one if it still
            // has tasks, otherwise any of the selected goals).
            let currentGoal = notebook.sessions[idx].goalId
            let reuseGoal = tasksByGoal[currentGoal] != nil ? currentGoal : tasksByGoal.keys.sorted().first!

            notebook.sessions[idx].goalId = reuseGoal
            notebook.sessions[idx].taskIds = tasksByGoal[reuseGoal] ?? []
            notebook.sessions[idx].date = day
            notebook.sessions[idx].updatedAt = Date()

            // Remaining goals each become a new session on the same day.
            for gid in tasksByGoal.keys.sorted() where gid != reuseGoal {
                let session = PlannedSession(goalId: gid, date: day, taskIds: tasksByGoal[gid] ?? [])
                notebook.sessions.append(session)
            }
        }
    }

    func deleteSession(id: String) {
        mutate {
            notebook.sessions.removeAll { $0.id == id }
            notebook.reflections.removeAll { $0.sessionId == id }
        }
    }

    // MARK: - Notes

    var sortedNotes: [Note] {
        notebook.notes.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func addNote(title: String = "", body: String = "") -> Note {
        let note = Note(title: title, body: body)
        mutate {
            notebook.notes.append(note)
        }
        return note
    }

    func updateNote(id: String, title: String, body: String, imageFileNames: [String]? = nil) {
        guard let idx = notebook.notes.firstIndex(where: { $0.id == id }) else { return }
        mutate {
            notebook.notes[idx].title = title
            notebook.notes[idx].body = body
            if let imgs = imageFileNames {
                notebook.notes[idx].imageFileNames = imgs
            }
            notebook.notes[idx].updatedAt = Date()
        }
    }

    func deleteNote(id: String) {
        guard let note = notebook.notes.first(where: { $0.id == id }) else { return }
        // Clean up image files
        if !note.imageFileNames.isEmpty, let persistence = persistence as? JSONNotebookPersistence {
            let imagesDir = persistence.noteImagesDirectory(accountId: notebook.accountId, noteId: id)
            try? FileManager.default.removeItem(at: imagesDir)
        }
        mutate {
            notebook.notes.removeAll { $0.id == id }
        }
    }

    // MARK: - Bounties

    /// Number of training sessions required on a single goal before its bounty unlocks.
    static let bountyUnlockSessions = 4

    /// Number of *reflected* sessions for this goal. A session only counts toward the bounty
    /// once the user has reflected on it (i.e. it's marked done with a saved reflection).
    func reflectedSessionsForGoal(_ goalId: String) -> Int {
        let reflectedSessionIds = Set(notebook.reflections.map { $0.sessionId })
        return notebook.sessions
            .filter { $0.goalId == goalId && reflectedSessionIds.contains($0.id) }
            .count
    }

    /// A goal qualifies for a bounty once `bountyUnlockSessions` of its sessions have been
    /// reflected on. `GRIPGORILLAS_FORCE_BOUNTY` force-unlocks eligibility for QA.
    func isGoalBountyEligible(_ goalId: String) -> Bool {
        guard let goal = goal(id: goalId), !goal.isArchived, goal.name.nilIfBlank != nil else { return false }
        #if DEBUG
        if ProcessInfo.processInfo.environment["GRIPGORILLAS_FORCE_BOUNTY"] == "1" {
            return notebook.sessions.contains { $0.goalId == goalId }
        }
        #endif
        return reflectedSessionsForGoal(goalId) >= Self.bountyUnlockSessions
    }

    var hasBountyEligibleGoal: Bool {
        activeGoals.contains { isGoalBountyEligible($0.id) }
    }

    /// Goals to show in the "Bounty locked" progress card: any goal that has at least one
    /// planned/logged session and hasn't hit the unlock threshold yet. Progress counts
    /// reflected sessions (may be 0) toward `bountyUnlockSessions`.
    var bountyProgressGoals: [(goal: TrainingGoal, sessionsReflected: Int)] {
        activeGoals
            .compactMap { g -> (goal: TrainingGoal, sessionsReflected: Int)? in
                guard notebook.sessions.contains(where: { $0.goalId == g.id }) else { return nil }
                let n = reflectedSessionsForGoal(g.id)
                guard n < Self.bountyUnlockSessions else { return nil }
                return (goal: g, sessionsReflected: n)
            }
            .sorted { $0.sessionsReflected > $1.sessionsReflected }
    }

    /// Tasks the user can turn into a bounty: any task under a goal that qualifies,
    /// paired with its goal and how many sessions have drilled it.
    func bountyEligibleTasks() -> [(task: TrainingTask, goal: TrainingGoal, sessionCount: Int)] {
        activeGoals
            .filter { isGoalBountyEligible($0.id) }
            .flatMap { goal in
                tasks(forGoal: goal.id).map { task in
                    (task: task, goal: goal, sessionCount: sessions(forTask: task.id, goalId: goal.id).count)
                }
            }
    }

    var activeBounty: Bounty? {
        notebook.bounties.first { $0.status == .active }
    }

    /// The unlocked "Set a challenge" card shows only when a goal qualifies and there
    /// is no bounty already in flight.
    var isBountyUnlocked: Bool {
        activeBounty == nil && hasBountyEligibleGoal
    }

    /// Show the "Bounty locked" progress card when nothing qualifies yet but the user is
    /// building toward it (at least one goal in progress).
    var isBountyLocked: Bool {
        activeBounty == nil && !hasBountyEligibleGoal && !bountyProgressGoals.isEmpty
    }

    var collectedBounties: [Bounty] {
        notebook.bounties
            .filter { $0.status == .collected }
            .sorted { ($0.collectedAt ?? $0.createdAt) > ($1.collectedAt ?? $1.createdAt) }
    }

    var collectedBountyCount: Int { collectedBounties.count }

    @discardableResult
    func createBounty(taskId: String, kind: BountyKind, targetCount: Int?, targetPartner: String?) -> Bounty? {
        guard let task = task(id: taskId) else { return nil }
        let bounty = Bounty(
            accountId: notebook.accountId,
            goalId: task.goalId,
            taskId: taskId,
            kind: kind,
            targetCount: targetCount,
            targetPartner: targetPartner?.nilIfBlank
        )
        mutate { notebook.bounties.append(bounty) }
        return bounty
    }

    @discardableResult
    func createBountyForGoal(goalId: String, kind: BountyKind, targetCount: Int?, targetPartner: String?) -> Bounty? {
        guard goal(id: goalId) != nil else { return nil }
        let bounty = Bounty(
            accountId: notebook.accountId,
            goalId: goalId,
            taskId: "",
            kind: kind,
            targetCount: targetCount,
            targetPartner: targetPartner?.nilIfBlank
        )
        mutate { notebook.bounties.append(bounty) }
        return bounty
    }

    /// Records one landing. Auto-collects the bounty when the required hits are reached.
    @discardableResult
    func recordBountyHit(id: String) -> Bounty? {
        guard let idx = notebook.bounties.firstIndex(where: { $0.id == id }) else { return nil }
        mutate {
            notebook.bounties[idx].hitDates.append(Date())
            if notebook.bounties[idx].isComplete {
                notebook.bounties[idx].status = .collected
                notebook.bounties[idx].collectedAt = Date()
            }
        }
        return notebook.bounties[idx]
    }

    func cancelBounty(id: String) {
        mutate { notebook.bounties.removeAll { $0.id == id } }
    }

    /// Trophy stats for a collected (or in-flight) bounty: sessions drilling the
    /// technique during the hunt, elapsed days, and total hits landed.
    func bountyStats(_ bounty: Bounty) -> (sessions: Int, days: Int, hits: Int) {
        let end = bounty.collectedAt ?? Date()
        let sessionCount = notebook.sessions.filter {
            $0.goalId == bounty.goalId
                && (bounty.taskId.isEmpty || $0.taskIds.contains(bounty.taskId))
                && $0.date >= calendar.startOfDay(for: bounty.createdAt)
        }.count
        let days = max(1, (calendar.dateComponents([.day], from: bounty.createdAt, to: end).day ?? 0) + 1)
        return (sessions: sessionCount, days: days, hits: bounty.hitCount)
    }

    /// Human-readable title, e.g. "Hit over under on Marcus, 5×".
    func bountyTitle(_ bounty: Bounty) -> String {
        let name = bounty.taskId.isEmpty
            ? (goal(id: bounty.goalId)?.name ?? "your technique")
            : (task(id: bounty.taskId)?.name ?? "your technique")
        var parts = "Hit \(name)"
        if let partner = bounty.targetPartner?.nilIfBlank {
            parts += " on \(partner)"
        }
        if bounty.requiredHits > 1 {
            parts += ", \(bounty.requiredHits)×"
        }
        return parts
    }

    func trainingDatesThisWeek(goalId: String, anchor: Date) -> Set<Date> {
        let start = calendar.mondayStartOfWeek(containing: anchor)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return Set(
            notebook.sessions
                .filter { $0.goalId == goalId && $0.date >= start && $0.date < end }
                .map { calendar.normalizedTrainingDay($0.date) }
        )
    }

    func taskWeekDoneDayCount(taskId: String, goalId: String, anchor: Date) -> Int {
        let start = calendar.mondayStartOfWeek(containing: anchor)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return Set(
            notebook.sessions
                .filter { $0.goalId == goalId && $0.taskIds.contains(taskId) && $0.status == .done && $0.date >= start && $0.date < end }
                .map { calendar.normalizedTrainingDay($0.date) }
        ).count
    }

    func dayStateMap(goalId: String) -> [String: SessionStatus] {
        var result: [String: SessionStatus] = [:]
        for session in notebook.sessions where session.goalId == goalId {
            let key = session.date.trainingDayString
            if session.status == .done {
                result[key] = .done
            } else if result[key] != .done {
                result[key] = .planned
            }
        }
        return result
    }

    private func conflictingSessions(for proposal: ProposedSession) -> [PlannedSession] {
        notebook.sessions.filter { session in
            guard session.goalId == proposal.goalId,
                  calendar.sameTrainingDay(session.date, proposal.date) else { return false }
            if session.taskIds.isEmpty && proposal.taskIds.isEmpty { return true }
            return !Set(session.taskIds).intersection(Set(proposal.taskIds)).isEmpty
        }
    }

    private func mutate(_ changes: () -> Void) {
        guard !loadFailed else { return }
        changes()
        do {
            try persistence.save(notebook)
        } catch {
            errorMessage = "Could not save notebook."
        }
    }

#if DEBUG
    /// DEBUG/QA: wipes all notebook data so first-run onboarding can be re-tested without
    /// deleting the app. Triggered by the `RESET_ONBOARDING` launch environment variable.
    func resetForOnboardingTestingDEBUG() {
        mutate {
            notebook.goals = []
            notebook.tasks = []
            notebook.sessions = []
            notebook.reflections = []
            notebook.notes = []
            notebook.bounties = []
            notebook.competitions = []
            notebook.profile = nil
        }
    }

    /// DEBUG/QA: populates the notebook with realistic BJJ training data so every
    /// section of the Home screen renders with content. Triggered by
    /// `SEED_DEMO_DATA` launch environment variable.
    func seedDemoDataDEBUG() {
        guard notebook.goals.isEmpty else { return }

        let cal = Calendar.current
        let acct = notebook.accountId

        func daysAgo(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: -n, to: Date()) ?? Date()
        }
        func daysFromNow(_ n: Int) -> Date {
            cal.date(byAdding: .day, value: n, to: Date()) ?? Date()
        }

        // — Goals —

        let g1 = TrainingGoal(id: "seed-g1", accountId: acct, name: "Closed Guard", iconName: "shield.fill", colorName: "indigo",
                              createdAt: daysAgo(42))
        let g2 = TrainingGoal(id: "seed-g2", accountId: acct, name: "Passing", iconName: "arrow.up.right", colorName: "mint",
                              createdAt: daysAgo(35))
        let g3 = TrainingGoal(id: "seed-g3", accountId: acct, name: "Takedowns", iconName: "custom.leg", colorName: "coral",
                              createdAt: daysAgo(21))

        // — Tasks —

        let t1a = TrainingTask(id: "seed-t1a", goalId: g1.id, name: "Break their posture",
                               notes: "Two-on-one collar grip, pull elbows to mat. Keep hips close.", createdAt: daysAgo(42))
        let t1b = TrainingTask(id: "seed-t1b", goalId: g1.id, name: "Hip escape to angle",
                               notes: "Shrimp to the side before attacking. Creates space for sweeps and subs.", createdAt: daysAgo(40))
        let t1c = TrainingTask(id: "seed-t1c", goalId: g1.id, name: "Sweep off the hook",
                               notes: "Scissor sweep when they post. Flower sweep as follow-up if they resist.", createdAt: daysAgo(38))

        let t2a = TrainingTask(id: "seed-t2a", goalId: g2.id, name: "Knee slice pass",
                               notes: "Lead knee across thigh, cross-face pressure, underhook the far arm.", createdAt: daysAgo(35))
        let t2b = TrainingTask(id: "seed-t2b", goalId: g2.id, name: "Torreando footwork",
                               notes: "Grip both pant legs, push to one side, step around. Speed over strength.", createdAt: daysAgo(33))
        let t2c = TrainingTask(id: "seed-t2c", goalId: g2.id, name: "Leg drag finish",
                               notes: "Pin their leg across your hip line with your forearm. Settle into side control.", createdAt: daysAgo(30))

        let t3a = TrainingTask(id: "seed-t3a", goalId: g3.id, name: "Snap-down to front headlock",
                               notes: "Quick level change, collar tie, snap them down. Transition to guillotine or go-behind.", createdAt: daysAgo(21))
        let t3b = TrainingTask(id: "seed-t3b", goalId: g3.id, name: "Arm drag to back take",
                               notes: "Two-on-one, pull past your hip, circle to the back. Works gi and no-gi.", createdAt: daysAgo(18))

        // — Past sessions (reflected) —

        let s1 = PlannedSession(id: "seed-s1", goalId: g1.id, date: daysAgo(28),
                                taskIds: [t1a.id, t1b.id], status: .done, createdAt: daysAgo(29))
        let r1 = Reflection(id: "seed-r1", sessionId: s1.id, date: daysAgo(28),
                            workedText: "Posture breaks felt solid from collar grip\nHip escape timing improved a lot",
                            stuckText: "Still getting stacked when I go for the armbar",
                            tryNextText: "Try the pendulum sweep instead of forcing the armbar",
                            mood: .good, createdAt: daysAgo(28))

        let s2 = PlannedSession(id: "seed-s2", goalId: g2.id, date: daysAgo(21),
                                taskIds: [t2a.id, t2b.id], status: .done, createdAt: daysAgo(22))
        let r2 = Reflection(id: "seed-r2", sessionId: s2.id, date: daysAgo(21),
                            workedText: "Knee slice is becoming my A-game pass\nTorreando worked great against seated guard",
                            stuckText: "Kept getting caught in half guard during knee slice",
                            tryNextText: "Focus on cross-face before sliding the knee through",
                            mood: .great, createdAt: daysAgo(21))

        let s3 = PlannedSession(id: "seed-s3", goalId: g1.id, date: daysAgo(14),
                                taskIds: [t1b.id, t1c.id], status: .done, createdAt: daysAgo(15))
        let r3 = Reflection(id: "seed-r3", sessionId: s3.id, date: daysAgo(14),
                            workedText: "Scissor sweep landed 3 times in rolling",
                            stuckText: "Flower sweep timing is off — they keep posting",
                            tryNextText: "Drill the flower sweep entry 20 reps before rolling",
                            mood: .good, isFavorite: true, createdAt: daysAgo(14))

        let s4 = PlannedSession(id: "seed-s4", goalId: g3.id, date: daysAgo(7),
                                taskIds: [t3a.id, t3b.id], status: .done, createdAt: daysAgo(8))
        let r4 = Reflection(id: "seed-r4", sessionId: s4.id, date: daysAgo(7),
                            workedText: "Snap-down is becoming reflexive\nArm drag worked twice on a bigger partner",
                            stuckText: "Getting sprawled on when I commit too early",
                            tryNextText: "Set up the snap with a push-pull sequence first",
                            mood: .neutral, createdAt: daysAgo(7))

        let s5 = PlannedSession(id: "seed-s5", goalId: g2.id, date: daysAgo(3),
                                taskIds: [t2a.id, t2c.id], status: .done, createdAt: daysAgo(4))
        let r5 = Reflection(id: "seed-r5", sessionId: s5.id, date: daysAgo(3),
                            workedText: "Leg drag felt really smooth today\nChained knee slice → leg drag when they re-guarded",
                            stuckText: "Lost position when I rushed the pass",
                            mood: .great, createdAt: daysAgo(3))

        // — Extra Closed Guard sessions to unlock bounty (need 8 total) —

        let s6 = PlannedSession(id: "seed-s6", goalId: g1.id, date: daysAgo(56),
                                taskIds: [t1a.id], status: .done, createdAt: daysAgo(57))
        let r6 = Reflection(id: "seed-r6", sessionId: s6.id, date: daysAgo(56),
                            workedText: "First day drilling posture breaks — got the grip concept",
                            stuckText: "Kept reaching too high on the collar",
                            mood: .neutral, createdAt: daysAgo(56))

        let s7 = PlannedSession(id: "seed-s7", goalId: g1.id, date: daysAgo(49),
                                taskIds: [t1a.id, t1b.id], status: .done, createdAt: daysAgo(50))
        let r7 = Reflection(id: "seed-r7", sessionId: s7.id, date: daysAgo(49),
                            workedText: "Hip escape feels more natural now",
                            stuckText: "Still bridging instead of shrimping under pressure",
                            tryNextText: "Focus on elbow-knee connection during the shrimp",
                            mood: .good, createdAt: daysAgo(49))

        let s8 = PlannedSession(id: "seed-s8", goalId: g1.id, date: daysAgo(42),
                                taskIds: [t1b.id, t1c.id], status: .done, createdAt: daysAgo(43))
        let r8 = Reflection(id: "seed-r8", sessionId: s8.id, date: daysAgo(42),
                            workedText: "Scissor sweep is clicking — landed it twice on a blue belt",
                            stuckText: "Timing the sweep when they stand is tricky",
                            mood: .great, createdAt: daysAgo(42))

        let s9 = PlannedSession(id: "seed-s9", goalId: g1.id, date: daysAgo(35),
                                taskIds: [t1a.id, t1c.id], status: .done, createdAt: daysAgo(36))
        let r9 = Reflection(id: "seed-r9", sessionId: s9.id, date: daysAgo(35),
                            workedText: "Posture break → sweep combo is becoming a real sequence",
                            stuckText: "Bigger guys just posture up through my grips",
                            tryNextText: "Try overhook guard against bigger opponents",
                            mood: .good, createdAt: daysAgo(35))

        let s10 = PlannedSession(id: "seed-s10", goalId: g1.id, date: daysAgo(24),
                                 taskIds: [t1b.id], status: .done, createdAt: daysAgo(25))
        let r10 = Reflection(id: "seed-r10", sessionId: s10.id, date: daysAgo(24),
                             workedText: "Hip escape to angle created back-take opportunities",
                             stuckText: "Got flattened out a couple times before I could angle",
                             mood: .good, createdAt: daysAgo(24))

        let s11 = PlannedSession(id: "seed-s11", goalId: g1.id, date: daysAgo(17),
                                 taskIds: [t1a.id, t1b.id, t1c.id], status: .done, createdAt: daysAgo(18))
        let r11 = Reflection(id: "seed-r11", sessionId: s11.id, date: daysAgo(17),
                             workedText: "Full chain worked: break posture → hip escape → sweep\nBest closed guard day yet",
                             stuckText: "Still giving up the guard when they stack hard",
                             tryNextText: "Drill the shoulder walk escape from stacking",
                             mood: .great, isFavorite: true, createdAt: daysAgo(17))

        // — Upcoming session (the hero card) —

        let sNext = PlannedSession(id: "seed-sNext", goalId: g1.id, date: daysFromNow(0),
                                   taskIds: [t1a.id, t1b.id, t1c.id], createdAt: daysAgo(1))

        // — Competitions —

        var compPast = Competition(
            id: "seed-c1", accountId: acct,
            name: "City Open", date: daysAgo(45),
            venue: "Downtown Rec Center", division: "White Belt Adult", rank: "Light",
            strategy: [
                StrategyFocus(id: "sf1", text: "Pull guard early — don't waste energy wrestling"),
                StrategyFocus(id: "sf2", text: "Work the scissor sweep from closed guard"),
                StrategyFocus(id: "sf3", text: "Stay calm if I end up on bottom side control")
            ],
            createdAt: daysAgo(52))
        compPast.result = .win
        compPast.wins = 3
        compPast.losses = 1
        compPast.draws = 0
        compPast.placement = "Silver"
        compPast.loggedAt = daysAgo(45)
        compPast.mood = .great
        compPast.workedText = "Scissor sweep worked in two of three wins — game plan paid off"
        compPast.stuckText = "Lost the final by points, couldn't escape mount in the last minute"
        compPast.tryNextText = "Drill mount escapes under fatigue before next comp"
        compPast.reflectedAt = daysAgo(44)
        compPast.strategy[0].worked = true
        compPast.strategy[1].worked = true
        compPast.strategy[2].worked = false

        var compPast2 = Competition(
            id: "seed-c2", accountId: acct,
            name: "Sub Only Invitational", date: daysAgo(14),
            venue: "Gracie Academy", division: "Beginner No-Gi", rank: "",
            strategy: [
                StrategyFocus(id: "sf4", text: "Arm drag to back take every chance"),
                StrategyFocus(id: "sf5", text: "Don't stall — always be attacking")
            ],
            createdAt: daysAgo(21))
        compPast2.result = .loss
        compPast2.wins = 1
        compPast2.losses = 2
        compPast2.draws = 0
        compPast2.placement = ""
        compPast2.loggedAt = daysAgo(14)
        compPast2.strategy[0].worked = true
        compPast2.strategy[1].worked = false

        let compUpcoming = Competition(
            id: "seed-c3", accountId: acct,
            name: "Summer Classic", date: daysFromNow(12),
            venue: "Convention Center", division: "White Belt Adult", rank: "Light",
            strategy: [
                StrategyFocus(id: "sf6", text: "Open with collar tie snap-down"),
                StrategyFocus(id: "sf7", text: "Chain knee slice → leg drag if they re-guard"),
                StrategyFocus(id: "sf8", text: "Mount escapes under pressure — don't panic")
            ],
            createdAt: daysAgo(5))

        mutate {
            notebook.goals = [g1, g2, g3]
            notebook.tasks = [t1a, t1b, t1c, t2a, t2b, t2c, t3a, t3b]
            notebook.sessions = [s6, s7, s8, s9, s10, s11, s1, s2, s3, s4, s5, sNext]
            notebook.reflections = [r6, r7, r8, r9, r10, r11, r1, r2, r3, r4, r5]
            notebook.competitions = [compPast, compPast2, compUpcoming]
        }
    }
#endif
}

// MARK: - Competitions

extension NotebookStore {
    /// Competitions still to happen (no result logged yet), soonest first.
    var upcomingCompetitions: [Competition] {
        notebook.competitions
            .filter { $0.isUpcoming }
            .sorted { $0.date < $1.date }
    }

    /// The soonest upcoming competition — the "NEXT UP" hero card.
    var nextCompetition: Competition? { upcomingCompetitions.first }

    /// Competitions with a logged result, most recent first.
    var pastCompetitions: [Competition] {
        notebook.competitions
            .filter { !$0.isUpcoming }
            .sorted { $0.date > $1.date }
    }

    func competition(id: String) -> Competition? {
        notebook.competitions.first { $0.id == id }
    }

    @discardableResult
    func addCompetition(name: String, date: Date, venue: String = "", division: String = "", rank: String = "", strategy: [StrategyFocus] = []) -> Competition {
        let competition = Competition(
            accountId: notebook.accountId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            division: division.trimmingCharacters(in: .whitespacesAndNewlines),
            rank: rank.trimmingCharacters(in: .whitespacesAndNewlines),
            strategy: strategy
        )
        mutate { notebook.competitions.append(competition) }
        return competition
    }

    /// Replaces a competition wholesale (used by the edit sheet). Stamps updatedAt.
    func updateCompetition(_ competition: Competition) {
        guard let idx = notebook.competitions.firstIndex(where: { $0.id == competition.id }) else { return }
        var updated = competition
        updated.updatedAt = Date()
        mutate { notebook.competitions[idx] = updated }
    }

    func deleteCompetition(id: String) {
        mutate { notebook.competitions.removeAll { $0.id == id } }
    }

    @discardableResult
    func addStrategyFocus(competitionId: String, text: String) -> StrategyFocus? {
        guard let idx = notebook.competitions.firstIndex(where: { $0.id == competitionId }) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let focus = StrategyFocus(text: trimmed)
        mutate {
            notebook.competitions[idx].strategy.append(focus)
            notebook.competitions[idx].updatedAt = Date()
        }
        return focus
    }

    func updateStrategyFocus(competitionId: String, focusId: String, text: String) {
        guard let idx = notebook.competitions.firstIndex(where: { $0.id == competitionId }),
              let fIdx = notebook.competitions[idx].strategy.firstIndex(where: { $0.id == focusId }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate {
            notebook.competitions[idx].strategy[fIdx].text = trimmed
            notebook.competitions[idx].updatedAt = Date()
        }
    }

    func deleteStrategyFocus(competitionId: String, focusId: String) {
        guard let idx = notebook.competitions.firstIndex(where: { $0.id == competitionId }) else { return }
        mutate {
            notebook.competitions[idx].strategy.removeAll { $0.id == focusId }
            notebook.competitions[idx].updatedAt = Date()
        }
    }

    /// Logs the outcome and grades each strategy focus ("did the plan work?").
    func logCompetitionResult(id: String, result: CompetitionResult, wins: Int, losses: Int, draws: Int, placement: String, focusWorked: [String: Bool]) {
        guard let idx = notebook.competitions.firstIndex(where: { $0.id == id }) else { return }
        mutate {
            notebook.competitions[idx].result = result
            notebook.competitions[idx].wins = max(0, wins)
            notebook.competitions[idx].losses = max(0, losses)
            notebook.competitions[idx].draws = max(0, draws)
            notebook.competitions[idx].placement = placement.trimmingCharacters(in: .whitespacesAndNewlines)
            notebook.competitions[idx].loggedAt = Date()
            for fIdx in notebook.competitions[idx].strategy.indices {
                let fid = notebook.competitions[idx].strategy[fIdx].id
                notebook.competitions[idx].strategy[fIdx].worked = focusWorked[fid]
            }
            notebook.competitions[idx].updatedAt = Date()
        }
    }

    /// Saves the competition reflection (mirrors training's saveReflection).
    func saveCompetitionReflection(id: String, mood: Mood?, workedText: String, stuckText: String, tryNextText: String) {
        guard let idx = notebook.competitions.firstIndex(where: { $0.id == id }) else { return }
        mutate {
            notebook.competitions[idx].mood = mood
            notebook.competitions[idx].workedText = workedText.trimmingCharacters(in: .whitespacesAndNewlines)
            notebook.competitions[idx].stuckText = stuckText.trimmingCharacters(in: .whitespacesAndNewlines)
            notebook.competitions[idx].tryNextText = tryNextText.trimmingCharacters(in: .whitespacesAndNewlines)
            notebook.competitions[idx].reflectedAt = Date()
            notebook.competitions[idx].updatedAt = Date()
        }
    }

    @discardableResult
    func addCompetitionImage(competitionId: String, imageData: Data) -> String? {
        guard let idx = notebook.competitions.firstIndex(where: { $0.id == competitionId }),
              let jsonPersistence = persistence as? JSONNotebookPersistence else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        do {
            _ = try jsonPersistence.saveCompetitionImage(accountId: notebook.accountId, competitionId: competitionId, imageData: imageData, fileName: fileName)
        } catch {
            errorMessage = "Could not save image."
            return nil
        }
        mutate {
            notebook.competitions[idx].imageFileNames.append(fileName)
            notebook.competitions[idx].updatedAt = Date()
        }
        return fileName
    }

    func removeCompetitionImage(competitionId: String, fileName: String) {
        guard let idx = notebook.competitions.firstIndex(where: { $0.id == competitionId }) else { return }
        if let jsonPersistence = persistence as? JSONNotebookPersistence {
            let url = jsonPersistence.competitionImagesDirectory(accountId: notebook.accountId, competitionId: competitionId).appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
        mutate {
            notebook.competitions[idx].imageFileNames.removeAll { $0 == fileName }
            notebook.competitions[idx].updatedAt = Date()
        }
    }

    func competitionImageData(competitionId: String, fileName: String) -> Data? {
        guard let jsonPersistence = persistence as? JSONNotebookPersistence else { return nil }
        return jsonPersistence.loadCompetitionImage(accountId: notebook.accountId, competitionId: competitionId, fileName: fileName)
    }
}
