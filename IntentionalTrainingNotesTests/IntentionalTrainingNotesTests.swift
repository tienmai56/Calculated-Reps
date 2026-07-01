import XCTest
@testable import IntentionalTrainingNotes

final class IntentionalTrainingNotesTests: XCTestCase {
    func testSessionRoutingSignedOutMissingProfileAndReady() {
        let accountStore = TestAccountStore()
        let session = AppSessionStore(accountStore: accountStore, authService: TestAuthService()) { _ in
            TestNotebookPersistence()
        }

        XCTAssertEqual(session.route, .signedOut)

        let account = UserAccount(provider: .google, providerSubjectId: "subject-1")
        session.completeSignIn(account: account)

        XCTAssertEqual(session.route, .signedInMissingProfile)

        session.saveProfile(firstName: " Alex ", lastName: " Rivera ")

        XCTAssertEqual(session.route, .ready)
        XCTAssertEqual(session.notebookStore?.profile?.firstName, "Alex")
        XCTAssertNil(session.notebookStore?.profile?.belt)
    }

    func testProfileValidationRulesMirrorRequiredFieldsWithoutBelt() {
        let profile = UserProfile(
            accountId: "a_1",
            firstName: "Alex",
            lastName: "Rivera",
            createdAt: day("2026-05-08"),
            updatedAt: day("2026-05-08")
        )

        XCTAssertFalse(profile.firstName.isEmpty)
        XCTAssertFalse(profile.lastName.isEmpty)
        XCTAssertNil(profile.belt)
    }

    func testAccountScopedJSONRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = JSONNotebookPersistence(rootDirectory: root)
        let accountId = "google_subject_1"
        let goal = TrainingGoal(id: "g_1", accountId: accountId, name: "Guard Retention", createdAt: day("2026-05-08"), updatedAt: day("2026-05-08"))
        let task = TrainingTask(id: "t_1", goalId: goal.id, name: "Framing", createdAt: day("2026-05-08"), updatedAt: day("2026-05-08"))
        let session = PlannedSession(id: "p_1", goalId: goal.id, date: day("2026-05-09"), taskIds: [task.id], status: .done, createdAt: day("2026-05-08"), updatedAt: day("2026-05-09"))
        let reflection = Reflection(id: "r_1", sessionId: session.id, date: session.date, workedText: "Frames landed", stuckText: "Late hips", mood: .good, createdAt: day("2026-05-09"), updatedAt: day("2026-05-09"))
        let notebook = TrainingNotebook(accountId: accountId, goals: [goal], tasks: [task], sessions: [session], reflections: [reflection])

        try persistence.save(notebook)

        XCTAssertEqual(try persistence.load(accountId: accountId), notebook)
        XCTAssertTrue(FileManager.default.fileExists(atPath: persistence.fileURL(accountId: accountId).path))
    }

    func testMissingNotebookFileLoadsEmptyNotebookForFirstLaunch() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = JSONNotebookPersistence(rootDirectory: root)

        let notebook = try persistence.load(accountId: "new-user")

        XCTAssertEqual(notebook.accountId, "new-user")
        XCTAssertNil(notebook.profile)
        XCTAssertTrue(notebook.goals.isEmpty)
        XCTAssertTrue(notebook.tasks.isEmpty)
        XCTAssertTrue(notebook.sessions.isEmpty)
        XCTAssertTrue(notebook.reflections.isEmpty)
    }

    func testCorruptedJSONFallsBackToEmptyStoreWithoutCrashing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = JSONNotebookPersistence(rootDirectory: root)
        let url = persistence.fileURL(accountId: "recover")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: url)

        let store = NotebookStore(accountId: "recover", persistence: persistence)

        XCTAssertEqual(store.notebook.accountId, "recover")
        XCTAssertTrue(store.activeGoals.isEmpty)
        XCTAssertTrue(store.notebook.sessions.isEmpty)
        XCTAssertEqual(store.errorMessage, "Could not load saved notebook.")
    }

    func testGoogleSignInIsHiddenWhenProductionConfigurationIsMissing() {
        XCTAssertFalse(GoogleSignInCoordinator.isConfigured)
    }

    func testMigrationFromLegacyNotebookShape() throws {
        let legacy = """
        {
          "focuses": [
            {
              "id": "f_1",
              "name": "Leg Locks",
              "isArchived": false,
              "createdAt": "2026-05-08",
              "updatedAt": "2026-05-08"
            }
          ],
          "tasks": [
            {
              "id": "t_1",
              "focusId": "f_1",
              "name": "Entries",
              "createdAt": "2026-05-08",
              "updatedAt": "2026-05-08"
            }
          ],
          "entries": [
            {
              "id": "e_1",
              "focusId": "f_1",
              "date": "2026-05-09",
              "taskIds": ["t_1"],
              "stuckText": "Lost the knee line",
              "mood": "neutral",
              "createdAt": "2026-05-09",
              "updatedAt": "2026-05-09"
            }
          ]
        }
        """.data(using: .utf8)!

        let migrated = try NotebookMigration.decode(data: legacy, accountId: "apple_123")

        XCTAssertEqual(migrated.schemaVersion, 2)
        XCTAssertEqual(migrated.goals.first?.name, "Leg Locks")
        XCTAssertEqual(migrated.tasks.first?.goalId, "f_1")
        XCTAssertEqual(migrated.sessions.first?.status, .done)
        XCTAssertEqual(migrated.reflections.first?.stuckText, "Lost the knee line")
    }

    func testCreateGoalTaskSessionAndReflection() {
        let store = NotebookStore(accountId: "a_1", persistence: TestNotebookPersistence())
        let goal = store.addGoal(name: " Leg Locks ")!
        let task = store.addTask(goalId: goal.id, name: " Entries ")!
        let proposals = store.proposeSessions(date: day("2026-05-09"), selectedGoalIds: [goal.id], selectedTaskIds: [task.id])
        let session = store.planSessions(proposals, overrideConflicts: false).first!
        let reflection = store.saveReflection(sessionId: session.id, mood: .good, workedText: " Clean entry ", stuckText: " Knee line ", tryNextText: "")!

        XCTAssertEqual(goal.name, "Leg Locks")
        XCTAssertEqual(task.name, "Entries")
        XCTAssertEqual(store.notebook.sessions.first?.status, .done)
        XCTAssertEqual(reflection.workedText, "Clean entry")
    }

    func testDuplicateOverrideTransfersReflectionToReplacementSession() {
        let store = NotebookStore(accountId: "a_1", persistence: TestNotebookPersistence())
        let goal = store.addGoal(name: "Guard")!
        let task = store.addTask(goalId: goal.id, name: "Frames")!
        let proposal = store.proposeSessions(date: day("2026-05-09"), selectedGoalIds: [goal.id], selectedTaskIds: [task.id])
        let first = store.planSessions(proposal, overrideConflicts: false).first!
        _ = store.saveReflection(sessionId: first.id, mood: .neutral, workedText: "Ok", stuckText: "Late", tryNextText: "")

        XCTAssertEqual(store.duplicateConflicts(for: proposal).count, 1)

        let replacement = store.planSessions(proposal, overrideConflicts: true).first!

        XCTAssertEqual(store.notebook.sessions.count, 1)
        XCTAssertEqual(store.notebook.reflections.first?.sessionId, replacement.id)
        XCTAssertNotEqual(first.id, replacement.id)
    }

    func testCheckToReflectCancelLeavesSessionPlanned() {
        let store = NotebookStore(accountId: "a_1", persistence: TestNotebookPersistence())
        let goal = store.addGoal(name: "Takedowns")!
        let task = store.addTask(goalId: goal.id, name: "Single leg")!
        let session = store.planSessions(
            store.proposeSessions(date: day("2026-05-09"), selectedGoalIds: [goal.id], selectedTaskIds: [task.id]),
            overrideConflicts: false
        ).first!

        XCTAssertEqual(store.notebook.sessions.first { $0.id == session.id }?.status, .planned)
        XCTAssertNil(store.reflection(forSessionId: session.id))
    }

    func testDeletingReflectionLeavesSessionDone() {
        let store = NotebookStore(accountId: "a_1", persistence: TestNotebookPersistence())
        let goal = store.addGoal(name: "Passing")!
        let session = store.planSessions(
            store.proposeSessions(date: day("2026-05-09"), selectedGoalIds: [goal.id], selectedTaskIds: []),
            overrideConflicts: false
        ).first!
        let reflection = store.saveReflection(sessionId: session.id, mood: .great, workedText: "Good pressure", stuckText: "", tryNextText: "")!

        store.deleteReflection(id: reflection.id)

        XCTAssertEqual(store.notebook.sessions.first?.status, .done)
        XCTAssertTrue(store.notebook.reflections.isEmpty)
    }

    func testTaskCascadeDeleteRemovesAffectedSessionsAndReflections() {
        let store = NotebookStore(accountId: "a_1", persistence: TestNotebookPersistence())
        let goal = store.addGoal(name: "Guard")!
        let keepTask = store.addTask(goalId: goal.id, name: "Hip escape")!
        let deleteTask = store.addTask(goalId: goal.id, name: "Frames")!
        let removeSession = store.planSessions(
            store.proposeSessions(date: day("2026-05-09"), selectedGoalIds: [goal.id], selectedTaskIds: [deleteTask.id]),
            overrideConflicts: false
        ).first!
        let keepSession = store.planSessions(
            store.proposeSessions(date: day("2026-05-10"), selectedGoalIds: [goal.id], selectedTaskIds: [keepTask.id]),
            overrideConflicts: false
        ).first!
        _ = store.saveReflection(sessionId: removeSession.id, mood: .frustrated, workedText: "", stuckText: "Late frames", tryNextText: "")

        XCTAssertEqual(store.cascadeSummary(forTask: deleteTask.id), TaskCascadeSummary(sessionCount: 1, reflectionCount: 1))

        store.deleteTaskCascade(taskId: deleteTask.id)

        XCTAssertEqual(store.notebook.sessions.map(\.id), [keepSession.id])
        XCTAssertTrue(store.notebook.reflections.isEmpty)
        XCTAssertEqual(store.notebook.tasks.map(\.id), [keepTask.id])
    }

    func testReverseChronologicalTaskTimelineAndWeeklyDoneDayCounts() {
        let store = NotebookStore(accountId: "a_1", persistence: TestNotebookPersistence(), calendar: Calendar(identifier: .gregorian))
        let goal = store.addGoal(name: "Mount")!
        let task = store.addTask(goalId: goal.id, name: "Retention")!
        let monday = day("2026-05-04")
        let tuesday = day("2026-05-05")

        let first = store.planSessions(store.proposeSessions(date: monday, selectedGoalIds: [goal.id], selectedTaskIds: [task.id]), overrideConflicts: false).first!
        _ = store.planSessions(store.proposeSessions(date: monday, selectedGoalIds: [goal.id], selectedTaskIds: [task.id]), overrideConflicts: false)
        let third = store.planSessions(store.proposeSessions(date: tuesday, selectedGoalIds: [goal.id], selectedTaskIds: [task.id]), overrideConflicts: false).first!
        _ = store.saveReflection(sessionId: first.id, mood: .good, workedText: "A", stuckText: "", tryNextText: "")
        _ = store.saveReflection(sessionId: third.id, mood: .good, workedText: "B", stuckText: "", tryNextText: "")

        XCTAssertEqual(store.sessions(forTask: task.id, goalId: goal.id).first?.date, tuesday)
        XCTAssertEqual(store.taskWeekDoneDayCount(taskId: task.id, goalId: goal.id, anchor: monday), 2)
    }

    private func day(_ value: String) -> Date {
        DateFormatter.trainingDay.date(from: value)!
    }
}

private final class TestNotebookPersistence: NotebookPersistence {
    var notebook: TrainingNotebook

    init(notebook: TrainingNotebook = TrainingNotebook(accountId: "a_1")) {
        self.notebook = notebook
    }

    func load(accountId: String) throws -> TrainingNotebook {
        notebook.accountId = accountId
        return notebook
    }

    func save(_ notebook: TrainingNotebook) throws {
        self.notebook = notebook
    }
}

private final class TestAccountStore: AccountStore {
    var account: UserAccount?

    func loadAccount() -> UserAccount? {
        account
    }

    func saveAccount(_ account: UserAccount) throws {
        self.account = account
    }

    func clearAccount() throws {
        account = nil
    }
}

private final class TestAuthService: AuthServicing {
    func signInWithApple(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        completion(.success(UserAccount(provider: .apple, providerSubjectId: "apple-test")))
    }

    func signInWithGoogle(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        completion(.success(UserAccount(provider: .google, providerSubjectId: "google-test")))
    }

    static func handleOpenURL(_ url: URL) -> Bool {
        false
    }
}
