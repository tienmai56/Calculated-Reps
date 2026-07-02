import Foundation
import SwiftUI
import UIKit

final class NotebookStore: ObservableObject {
    @Published private(set) var notebook: TrainingNotebook
    @Published var errorMessage: String?

    let persistence: NotebookPersistence
    private let calendar: Calendar

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
            self.errorMessage = "Could not load saved notebook."
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
    static let bountyUnlockSessions = 8

    /// Number of training sessions logged for this goal, up to today. Reflection is NOT
    /// required — any planned/logged session counts.
    func sessionsTrainedForGoal(_ goalId: String) -> Int {
        let today = calendar.startOfDay(for: Date())
        return notebook.sessions
            .filter { $0.goalId == goalId && calendar.startOfDay(for: $0.date) <= today }
            .count
    }

    /// A goal qualifies for a bounty once it's been trained for `bountyUnlockSessions` sessions.
    /// Reflection is not required. `MATMIND_FORCE_BOUNTY` force-unlocks eligibility for QA.
    func isGoalBountyEligible(_ goalId: String) -> Bool {
        guard let goal = goal(id: goalId), !goal.isArchived, goal.name.nilIfBlank != nil else { return false }
        #if DEBUG
        if ProcessInfo.processInfo.environment["MATMIND_FORCE_BOUNTY"] == "1" {
            return notebook.sessions.contains { $0.goalId == goalId }
        }
        #endif
        return sessionsTrainedForGoal(goalId) >= Self.bountyUnlockSessions
    }

    var hasBountyEligibleGoal: Bool {
        activeGoals.contains { isGoalBountyEligible($0.id) }
    }

    /// Goals the user is actively building toward bounty eligibility: at least one session
    /// trained but not yet at the unlock threshold. Drives the "Bounty locked" progress card.
    var bountyProgressGoals: [(goal: TrainingGoal, sessionsTrained: Int)] {
        activeGoals
            .compactMap { g -> (goal: TrainingGoal, sessionsTrained: Int)? in
                let n = sessionsTrainedForGoal(g.id)
                guard n >= 1, n < Self.bountyUnlockSessions else { return nil }
                return (goal: g, sessionsTrained: n)
            }
            .sorted { $0.sessionsTrained > $1.sessionsTrained }
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
                && $0.taskIds.contains(bounty.taskId)
                && $0.date >= calendar.startOfDay(for: bounty.createdAt)
        }.count
        let days = max(1, (calendar.dateComponents([.day], from: bounty.createdAt, to: end).day ?? 0) + 1)
        return (sessions: sessionCount, days: days, hits: bounty.hitCount)
    }

    /// Human-readable title, e.g. "Hit over under on Marcus, 5×".
    func bountyTitle(_ bounty: Bounty) -> String {
        let name = task(id: bounty.taskId)?.name ?? "your technique"
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
            notebook.profile = nil
        }
    }
#endif
}
