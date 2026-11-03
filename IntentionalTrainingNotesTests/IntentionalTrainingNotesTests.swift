import XCTest
import UIKit
@testable import IntentionalTrainingNotes

final class IntentionalTrainingNotesTests: XCTestCase {
    func testLegacyLocalSessionRemainsAvailableWithoutCloudSignIn() {
        let oldFlag = UserDefaults.standard.object(forKey: AppSessionStore.onboardingCompletedKey)
        defer { UserDefaults.standard.set(oldFlag, forKey: AppSessionStore.onboardingCompletedKey) }
        UserDefaults.standard.set(true, forKey: AppSessionStore.onboardingCompletedKey)
        let accountStore = TestAccountStore()
        let session = AppSessionStore(accountStore: accountStore, authService: TestAuthService()) { _ in
            TestNotebookPersistence()
        }

        XCTAssertEqual(session.route, .ready)

        let account = UserAccount(provider: .google, providerSubjectId: "subject-1")
        session.completeSignIn(account: account)

        XCTAssertEqual(session.route, .ready)

        session.saveProfile(firstName: " Alex ", lastName: " Rivera ")

        XCTAssertEqual(session.route, .ready)
        XCTAssertEqual(session.notebookStore?.profile?.firstName, "Alex")
        XCTAssertNil(session.notebookStore?.profile?.belt)
    }

    func testAvatarJPEGIsSquareAndCapped() throws {
        let wide = UIGraphicsImageRenderer(size: CGSize(width: 1600, height: 900)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1600, height: 900))
        }
        let data = try XCTUnwrap(AppModel.avatarJPEG(wide))
        let out = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(out.size.width * out.scale, 640)
        XCTAssertEqual(out.size.height * out.scale, 640)
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

    func testCorruptedJSONPreservesSourceAndDisablesWrites() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = JSONNotebookPersistence(rootDirectory: root)
        let url = persistence.fileURL(accountId: "recover")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: url)

        let store = NotebookStore(accountId: "recover", persistence: persistence)

        XCTAssertEqual(store.notebook.accountId, "recover")
        XCTAssertTrue(store.activeGoals.isEmpty)
        XCTAssertTrue(store.notebook.sessions.isEmpty)
        XCTAssertNotNil(store.errorMessage)
        _ = store.addGoal(name: "Must not overwrite")
        XCTAssertEqual(try Data(contentsOf: url), Data("not-json".utf8))
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

    func testLegacyDeletingReflectionReturnsSessionToPlanned() {
        let store = NotebookStore(accountId: "a_1", persistence: TestNotebookPersistence())
        let goal = store.addGoal(name: "Passing")!
        let session = store.planSessions(
            store.proposeSessions(date: day("2026-05-09"), selectedGoalIds: [goal.id], selectedTaskIds: []),
            overrideConflicts: false
        ).first!
        let reflection = store.saveReflection(sessionId: session.id, mood: .great, workedText: "Good pressure", stuckText: "", tryNextText: "")!

        store.deleteReflection(id: reflection.id)

        XCTAssertEqual(store.notebook.sessions.first?.status, .planned)
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

@MainActor
final class MatMindLiveUITests: XCTestCase {
    func testMatMonkeysBrandingIsBundledInTheInstalledApp() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Mat Monkeys")
        XCTAssertNotNil(UIImage(named: "SilverbackMark"))
        XCTAssertNotNil(UIImage(named: "SilverbackMono"))
    }

#if DEBUG
    func testUIReviewUsesAnIsolatedModelWithoutLiveServices() {
        let live = AppModel(live: true)
        let preview = AppModel.uiReviewPreview()

        XCTAssertTrue(preview.isSignedIn)
        XCTAssertFalse(preview.isLive)
        XCTAssertNil(preview.runtime)
        XCTAssertFalse(preview.posts.isEmpty)
        preview.addFriend("preview-only-friend")

        XCTAssertFalse(live.isSignedIn)
        XCTAssertTrue(live.friends.isEmpty)
        XCTAssertTrue(live.posts.isEmpty)
    }
#endif

    func testInstalledUIStartsWithoutSamplePeopleSessionsOrPosts() {
        let ui = AppModel()
        XCTAssertTrue(ui.isLive, "A model must require an explicit opt-in to load preview data")
        XCTAssertFalse(ui.isSignedIn)
        XCTAssertTrue(ui.people.isEmpty)
        XCTAssertTrue(ui.friends.isEmpty)
        XCTAssertTrue(ui.posts.isEmpty)
        XCTAssertTrue(ui.upcoming.isEmpty)
        XCTAssertNil(ui.toComplete)
        XCTAssertTrue(ui.cameraRoll.isEmpty)
        XCTAssertTrue(ui.gyms.isEmpty)
        XCTAssertTrue(ui.notifications.isEmpty)
        XCTAssertTrue(ui.me.name.isEmpty)
        XCTAssertNil(ui.me.photo)
        ui.run(.active)
        ui.reset()
        XCTAssertTrue(ui.people.isEmpty, "Prototype tools must never inject seed data into the installed app")
    }

    func testPlanningFromAGoalAttachesItToTheNewSession() {
        let ui = AppModel(live: false)
        ui.setTab(.goals)
        ui.go(.goal(id: "g2"))
        ui.planSession(forGoal: "g2")
        XCTAssertEqual(ui.path.last, .create())
        let draft = SessionDraft(title: "Back takes", day: "Wed", date: 11, month: "Nov", time: "6:00 PM", gym: "Tidewater BJJ",
                                 note: "", invited: [], privacy: .friends, past: false)
        ui.createSession(draft)
        let created = ui.upcoming.last
        XCTAssertEqual(created?.title, "Back takes")
        XCTAssertEqual(created.flatMap { ui.goal(forSession: $0.id)?.id }, "g2")
        XCTAssertNil(ui.pendingPlanGoal)

        // Backing out of the plan form forgets the goal.
        ui.planSession(forGoal: "g3")
        ui.back()
        XCTAssertNil(ui.pendingPlanGoal)
    }

    func testGoalPhotosAreSavedPrivatelyAndRemovable() throws {
        let ui = AppModel(live: false)
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1500)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 3000, height: 1500))
        }
        let data = try XCTUnwrap(big.pngData())
        XCTAssertTrue(ui.addPhoto(data, toGoal: "g4"))
        let photo = try XCTUnwrap(ui.goal("g4")?.photos.last)
        let file = MatGoal.photoRoot.appendingPathComponent(photo)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(MatGoal.photoSource(photo), file.path)
        let saved = try XCTUnwrap(UIImage(contentsOfFile: file.path))
        XCTAssertLessThanOrEqual(max(saved.size.width, saved.size.height), 2048, "Large photos are scaled down")
        XCTAssertFalse(ui.addPhoto(Data("not an image".utf8), toGoal: "g4"))

        ui.removePhoto(photo, fromGoal: "g4")
        XCTAssertFalse(ui.goal("g4")?.photos.contains(photo) ?? true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path), "Removing a photo deletes its file")
    }

    func testReferenceLinksAreNormalizedAndValidated() {
        let ui = AppModel(live: false)
        XCTAssertTrue(ui.addLink("  youtube.com/watch?v=abc ", toGoal: "g4"))
        XCTAssertEqual(ui.goal("g4")?.links, ["https://youtube.com/watch?v=abc"])
        XCTAssertTrue(ui.addLink("https://youtube.com/watch?v=abc", toGoal: "g4"))
        XCTAssertEqual(ui.goal("g4")?.links.count, 1, "The same link is kept once")
        XCTAssertFalse(ui.addLink("not a link", toGoal: "g4"))
        XCTAssertFalse(ui.addLink("ftp://files.example.com", toGoal: "g4"))
    }

    func testHostCanEditAndDeleteOnlyTheirOwnSessions() async {
        let ui = AppModel(live: false)
        let start = ISO8601DateFormatter().date(from: "2026-11-08T18:30:00Z")!

        let edited = await ui.editSession("s1", title: "  Sunday open mat ", startsAt: start, gym: "Harbor Jiu-Jitsu", note: "")
        XCTAssertTrue(edited)
        let session = ui.findSession("s1")
        XCTAssertEqual(session?.title, "Sunday open mat")
        XCTAssertEqual(session?.gym, "Harbor Jiu-Jitsu")
        XCTAssertEqual(session?.startsAt, start)
        XCTAssertNil(session?.note)
        XCTAssertEqual(ui.startDate(of: session!), start)

        let blank = await ui.editSession("s1", title: "  ", startsAt: start, gym: "Harbor Jiu-Jitsu", note: "")
        XCTAssertFalse(blank, "A session needs a name")
        let notMine = await ui.editSession("s2", title: "Mine now", startsAt: start, gym: "Anywhere", note: "")
        XCTAssertFalse(notMine, "Only the host can edit")

        XCTAssertNotNil(ui.goal(forSession: "s1"))
        ui.deleteSession("s1")
        XCTAssertNil(ui.findSession("s1"))
        XCTAssertNil(ui.goal(forSession: "s1"), "A deleted session drops its goal")
        ui.deleteSession("s2")
        XCTAssertNotNil(ui.findSession("s2"), "Only the host can delete")
    }

    func testGoalsAttachToSessionsAndPersistPerAccountInTheInstalledApp() {
        let ui = AppModel(live: true)
        XCTAssertTrue(ui.goals.isEmpty, "The installed app never shows sample goals")
        let account = "goal-test-\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: "matmonkeys.goals.\(account)") }
        ui.loadGoals(account: account)

        var goal = MatGoal.new()
        goal.title = "  Single leg from standing  "
        goal.notes = "Head inside\n- Run the pipe"
        XCTAssertTrue(ui.saveGoal(goal))
        XCTAssertEqual(ui.goals.first?.title, "Single leg from standing")
        XCTAssertEqual(ui.goals.first?.notesPreview, "Head inside Run the pipe")
        XCTAssertFalse(ui.saveGoal(MatGoal(id: "blank", title: "   ")), "A goal needs a name")
        ui.setGoal(goal.id, forSession: "session-1")
        XCTAssertEqual(ui.goal(forSession: "session-1")?.id, goal.id)

        let reopened = AppModel(live: true)
        reopened.loadGoals(account: account)
        XCTAssertEqual(reopened.goals.map(\.id), [goal.id])
        XCTAssertEqual(reopened.sessionGoals["session-1"], goal.id)

        let otherAccount = AppModel(live: true)
        otherAccount.loadGoals(account: account + "-other")
        XCTAssertTrue(otherAccount.goals.isEmpty, "Goals are kept per account")

        reopened.deleteGoal(goal.id)
        XCTAssertTrue(reopened.goals.isEmpty)
        XCTAssertNil(reopened.goal(forSession: "session-1"))
    }

    func testLivePhotoRenderingRejectsBundledSampleImages() throws {
#if DEBUG
        XCTAssertNotNil(MMPhoto.image(source: "floor-drill", allowsSamplePhotos: true))
#endif
        for name in ["floor-drill", "roll-gi", "portrait-gi", "team-lineup"] {
            XCTAssertNil(MMPhoto.image(source: name, allowsSamplePhotos: false))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }.jpegData(compressionQuality: 0.8))
        try data.write(to: url)
        XCTAssertNotNil(MMPhoto.image(source: url.path, allowsSamplePhotos: false))
        XCTAssertNil(MMPhoto.image(source: url.path + ".missing", allowsSamplePhotos: false))
    }

    func testLiveSnapshotMapsCurrentUserAndPreservesTagVisibility() throws {
        let data = Data(#"""
        {
          "profiles":[{"id":"owner","name":"Alex","belt":"blue","stripes":2,"gym":"Home gym"},{"id":"friend","name":"Lena","belt":"white","stripes":0,"gym":"Home gym"}],
          "sessions":[{"id":"session","organizer":"owner","title":"Open mat","starts_at":"2026-10-01T10:00:00Z","venue":"Home gym","status":"planned","join_mode":"friends","note":"Work on passing"}],
          "participants":[{"session_id":"session","user_id":"owner","rsvp":"going"},{"session_id":"session","user_id":"friend","rsvp":"invited"}],
          "posts":[{"id":"post","author":"owner","title":"Rounds","venue":"Home gym","occurred_at":"2026-10-01T10:00:00Z","caption":"Good rounds"}],
          "tags":[{"post_id":"post","user_id":"owner","visible":true},{"post_id":"post","user_id":"friend","visible":false}],
          "friendships":[],"likes":[],"comments":[],"credits":[],"media":[],"notifications":[]
        }
        """#.utf8)
        let model = SocialAppModel()
        model.userID = "owner"
        model.snapshot = try JSONDecoder().decode(SocialSnapshot.self, from: data)
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        runtime.sync()
        XCTAssertTrue(ui.isSignedIn)
        XCTAssertEqual(ui.me.id, "me")
        XCTAssertEqual(ui.me.name, "Alex")
        XCTAssertEqual(ui.people["friend"]?.name, "Lena")
        XCTAssertEqual(ui.upcoming.first?.organizer, "me")
        XCTAssertEqual(ui.upcoming.first?.status(of: "me"), .going)
        XCTAssertEqual(ui.upcoming.first?.status(of: "friend"), .invited)
        XCTAssertEqual(ui.posts.first?.participants, ["me"])
        XCTAssertEqual(ui.toComplete?.id, "session")
        model.userID = nil
        runtime.sync()
        XCTAssertFalse(ui.isSignedIn)
        XCTAssertTrue(ui.posts.isEmpty)
        XCTAssertTrue(ui.people.isEmpty)
        model.userID = "new-owner"
        model.snapshot = SocialSnapshot()
        runtime.sync()
        XCTAssertTrue(ui.isSignedIn)
        XCTAssertTrue(ui.me.name.isEmpty)
        XCTAssertTrue(ui.posts.isEmpty)
        XCTAssertTrue(ui.upcoming.isEmpty)
        XCTAssertTrue(ui.friends.isEmpty)
        XCTAssertNil(ui.toComplete)
        XCTAssertTrue(ui.cameraRoll.isEmpty)
    }

    func testFocusOutlineRoundTripsWithoutLosingPlainNotes() {
        let focus = [TrainingFocus(title: "Guard passing", children: [TrainingFocus(title: "Control the hips")])]
        let encoded = SessionNoteCodec.encode(note: "Bring a gi", focus: focus)
        let decoded = SessionNoteCodec.decode(encoded)
        XCTAssertEqual(decoded.note, "Bring a gi")
        XCTAssertEqual(decoded.focus, focus)
        XCTAssertEqual(SessionNoteCodec.decode("Existing plain note").note, "Existing plain note")
        XCTAssertTrue(SessionNoteCodec.decode("Existing plain note").focus.isEmpty)
        XCTAssertEqual(SessionNoteCodec.decode("matmind-focus-v1:broken").note, "matmind-focus-v1:broken")
    }

    func testLiveProfilePhotosLoadPrivatelyAndClearOnSignOut() async throws {
        let model = SocialAppModel()
        model.userID = "owner"
        model.snapshot.profiles = try JSONDecoder().decode([SocialRow].self, from: Data(#"[{"id":"owner","name":"Alex","avatar_key":"owner/one.jpg"},{"id":"friend","name":"Lena","avatar_key":"friend/two.jpg"}]"#.utf8))
        let data = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }.jpegData(compressionQuality: 0.8))
        var requested: [String] = []
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui) { key, bucket in
            requested.append(bucket + ":" + key)
            return data
        }

        await runtime.loadPhotos()
        XCTAssertEqual(Set(requested), ["avatars:owner/one.jpg", "avatars:friend/two.jpg"])
        let ownPhoto = try XCTUnwrap(ui.me.photo)
        let friendPhoto = try XCTUnwrap(ui.people["friend"]?.photo)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: ownPhoto)), data)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: friendPhoto)), data)
        XCTAssertNotNil(UIImage(contentsOfFile: ownPhoto))
        XCTAssertNotNil(UIImage(contentsOfFile: friendPhoto))
        await runtime.loadPhotos()
        XCTAssertEqual(requested.count, 2)

        model.userID = nil
        runtime.sync()
        XCTAssertNil(ui.me.photo)
        XCTAssertTrue(ui.people.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ownPhoto))
        XCTAssertFalse(FileManager.default.fileExists(atPath: friendPhoto))
    }

    func testProfilePhotoUpdatesAndRevokedAccessRemoveCachedImages() async throws {
        let model = SocialAppModel()
        model.userID = "owner"
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui) { key, _ in
            if key == "unreadable/photo.jpg" { throw CloudError(message: "Unavailable") }
            return Data(key.utf8)
        }
        model.snapshot.profiles = try JSONDecoder().decode([SocialRow].self, from: Data(#"[{"id":"owner","avatar_key":"owner/first.jpg"},{"id":"friend","avatar_key":"unreadable/photo.jpg"}]"#.utf8))
        await runtime.loadPhotos()
        let first = try XCTUnwrap(ui.me.photo)
        XCTAssertNil(ui.people["friend"]?.photo)

        model.snapshot.profiles = try JSONDecoder().decode([SocialRow].self, from: Data(#"[{"id":"owner","avatar_key":"owner/second.jpg"}]"#.utf8))
        await runtime.loadPhotos()
        let second = try XCTUnwrap(ui.me.photo)
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: second)), Data("owner/second.jpg".utf8))

        model.snapshot.profiles = []
        await runtime.loadPhotos()
        XCTAssertNil(ui.me.photo)
        XCTAssertFalse(FileManager.default.fileExists(atPath: second))
    }

    func testUntouchedOptionalFocusDoesNotBlockPlanningOrCreateSavedContent() {
        let outline = TrainingFocusTree.optionalOutline([TrainingFocus(), TrainingFocus(title: "  ")])
        XCTAssertTrue(TrainingFocusTree.isValid(outline))
        XCTAssertEqual(SessionNoteCodec.encode(note: "Bring a gi", focus: outline), "Bring a gi")
    }

    func testOptionalFocusKeepsEnteredDetailsForValidation() {
        let detail = TrainingFocus(title: "Win the underhook")
        let incomplete = TrainingFocus(title: "", children: [detail])
        let outline = TrainingFocusTree.optionalOutline([TrainingFocus(), incomplete])
        XCTAssertEqual(outline, [incomplete])
        XCTAssertFalse(TrainingFocusTree.isValid(outline))

        let named = TrainingFocus(title: " Guard passing ", children: [detail])
        let saved = TrainingFocusTree.optionalOutline([TrainingFocus(), named])
        XCTAssertTrue(TrainingFocusTree.isValid(saved))
        XCTAssertEqual(saved.first?.title, "Guard passing")
        XCTAssertEqual(saved.first?.children, [detail])
    }
}

final class MultiDayScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func draft(title: String = "", time: String = "7:30 PM") -> SessionDraft {
        SessionDraft(title: title, day: "", date: 0, month: "", time: time, gym: "Home gym",
                     note: "Bring a gi", invited: ["friend"], privacy: .link, past: false,
                     focusItems: [TrainingFocus(title: "Passing")])
    }

    func testNonconsecutiveDaysAreDistinctSortedAndShareTheEnteredDetailsAcrossYearBoundary() throws {
        let original = draft(title: "Partner drills")
        let scheduled = original.scheduled(on: [date("2027-01-02T20:00:00Z"), date("2026-12-31T20:00:00Z"), date("2027-01-02T22:00:00Z")], calendar: calendar)
        XCTAssertEqual(scheduled.map(\.date), [31, 2])
        XCTAssertEqual(scheduled.map(\.month), ["Dec", "Jan"])
        XCTAssertEqual(scheduled.map(\.title), ["Partner drills", "Partner drills"])
        for session in scheduled {
            XCTAssertEqual(session.gym, original.gym)
            XCTAssertEqual(session.note, original.note)
            XCTAssertEqual(session.invited, original.invited)
            XCTAssertEqual(session.privacy, original.privacy)
            XCTAssertEqual(session.focusItems, original.focusItems)
            XCTAssertEqual(session.timezone, calendar.timeZone.identifier)
            let start = try XCTUnwrap(session.startsAt)
            XCTAssertEqual(calendar.component(.hour, from: start), 19)
            XCTAssertEqual(calendar.component(.minute, from: start), 30)
        }
    }

    func testSuggestedTitlesFollowEachSelectedDay() {
        let scheduled = draft(time: "10:00 AM").scheduled(on: [date("2026-11-06T20:00:00Z"), date("2026-11-07T20:00:00Z"), date("2026-11-08T20:00:00Z")], calendar: calendar)
        XCTAssertEqual(scheduled.map(\.title), ["Morning rolls", "Saturday open mat", "Sunday open mat"])
    }

    func testTimeStaysLocalAcrossDaylightSavingChange() throws {
        let scheduled = draft().scheduled(on: [date("2026-10-31T20:00:00Z"), date("2026-11-01T20:00:00Z")], calendar: calendar)
        let first = try XCTUnwrap(scheduled.first?.startsAt)
        let second = try XCTUnwrap(scheduled.last?.startsAt)
        XCTAssertEqual(calendar.component(.hour, from: first), 19)
        XCTAssertEqual(calendar.component(.hour, from: second), 19)
        XCTAssertEqual(second.timeIntervalSince(first), 25 * 60 * 60)
    }

    func testNoSelectionOrInvalidTimeDoesNotProduceSessions() {
        XCTAssertTrue(draft().scheduled(on: [], calendar: calendar).isEmpty)
        XCTAssertTrue(draft(time: "invalid").scheduled(on: [Date()], calendar: calendar).isEmpty)
    }

    @MainActor
    func testPreviewBatchCreatesUniqueSessionsAndAttachesGoalToEveryDay() async {
        let ui = AppModel(live: false)
        ui.planSession(forGoal: "g2")
        let scheduled = draft(title: "Partner drills").scheduled(on: [date("2026-11-03T20:00:00Z"), date("2026-11-05T20:00:00Z"), date("2026-11-07T20:00:00Z")], calendar: calendar)
        let requests = scheduled.map { SessionCreationRequest(draft: $0) }
        let before = ui.upcoming.count
        let result = await ui.createSessions(requests)
        XCTAssertTrue(result)
        let added = Array(ui.upcoming.suffix(3))
        XCTAssertEqual(ui.upcoming.count, before + 3)
        XCTAssertEqual(Set(added.map(\.id)).count, 3)
        XCTAssertTrue(added.allSatisfy { ui.goal(forSession: $0.id)?.id == "g2" })
        XCTAssertEqual(ui.tab, .training)
        XCTAssertTrue(ui.path.isEmpty)
        XCTAssertFalse(ui.busy)
        XCTAssertNil(ui.pendingPlanGoal)
    }

    @MainActor
    func testPastSessionsRemainSingleAndContinueToPhotoCompletion() async {
        let ui = AppModel(live: false)
        var past = draft(title: "Yesterday's rolls")
        past.past = true
        let request = SessionCreationRequest(draft: past)
        let rejected = await ui.createSessions([request, SessionCreationRequest(draft: past)])
        XCTAssertFalse(rejected)
        let result = await ui.createSessions([request])
        XCTAssertTrue(result)
        XCTAssertEqual(ui.path.last, ui.drafts.last.map { .complete(id: $0.id) })
    }
}

final class GoogleCloudSignInTests: XCTestCase {
    func testGoogleSignInRequiresAnEnabledServerProvider() throws {
        let enabled = try JSONDecoder().decode(CloudAuthSettings.self, from: Data(#"{"external":{"google":true,"apple":false}}"#.utf8))
        XCTAssertNoThrow(try enabled.requireGoogle())
        for fixture in [#"{"external":{"google":false}}"#, #"{"external":{}}"#] {
            let disabled = try JSONDecoder().decode(CloudAuthSettings.self, from: Data(fixture.utf8))
            XCTAssertThrowsError(try disabled.requireGoogle()) { error in
                XCTAssertEqual(error as? CloudSignInError, .googleUnavailable)
            }
        }
    }

    func testGoogleCallbackAcceptsOnlyTheAppAuthRouteWithOneCode() throws {
        let callback = try XCTUnwrap(URL(string: "matmind://auth?code=test-authorization-code"))
        XCTAssertEqual(try GoogleOAuthCallback.authorizationCode(from: callback), "test-authorization-code")
        for value in ["https://example.com/auth?code=test", "matmind://friend?code=test", "matmind://auth", "matmind://auth?code=", "matmind://auth?code=one&code=two"] {
            let url = try XCTUnwrap(URL(string: value))
            XCTAssertThrowsError(try GoogleOAuthCallback.authorizationCode(from: url)) { error in
                XCTAssertEqual(error as? CloudSignInError, .invalidCallback)
            }
        }
    }

    func testGoogleCallbackCancellationAndErrorsCannotBecomeSuccessfulSignIn() throws {
        let cancelled = try XCTUnwrap(URL(string: "matmind://auth?error=access_denied&code=ignored"))
        XCTAssertThrowsError(try GoogleOAuthCallback.authorizationCode(from: cancelled)) { error in
            XCTAssertEqual(error as? CloudSignInError, .cancelled)
        }
        let rejected = try XCTUnwrap(URL(string: "matmind://auth?error=server_error&error_description=internal-details&code=ignored"))
        XCTAssertThrowsError(try GoogleOAuthCallback.authorizationCode(from: rejected)) { error in
            XCTAssertEqual(error as? CloudSignInError, .providerRejected)
            XCTAssertFalse(error.localizedDescription.contains("internal-details"))
        }
        let emptyError = try XCTUnwrap(URL(string: "matmind://auth?error&code=ignored"))
        XCTAssertThrowsError(try GoogleOAuthCallback.authorizationCode(from: emptyError)) { error in
            XCTAssertEqual(error as? CloudSignInError, .providerRejected)
        }
    }
}

final class BackendSessionTests: XCTestCase {
    private let photo = Data([0xff, 0xd8, 0xff, 0xd9])
    private let expiryError = Data(#"{"statusCode":"400","error":"Unauthorized","message":"\"exp\" claim timestamp check failed"}"#.utf8)

    func testOldKeychainSessionRefreshesBeforeSendingPhoto() async throws {
        // Existing installations stored no expires_at; the JWT exp still works.
        let payload = Data(#"{"exp":1}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let old = CloudCredential(access_token: "header.\(payload).signature", refresh_token: "old-refresh", user: CloudUser(id: "owner"))
        let fixture = BackendHTTPFixture(failureStatus: 400, failureBody: expiryError)
        let (client, store) = try makeClient(credential: old, fixture: fixture)

        try await client.upload(photo, objectKey: "owner/avatar.jpg", bucket: "avatars")

        let requests = await fixture.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.url?.path, "/auth/v1/token")
        XCTAssertEqual(requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
        let saved = try JSONDecoder().decode(CloudCredential.self, from: XCTUnwrap(store.read()))
        XCTAssertEqual(saved.refresh_token, "rotated-refresh")
        XCTAssertEqual(saved.access_token, "fresh-token")
    }

    func testLegacyStorageExpiryRefreshesAndRetriesIdenticalPhoto() async throws {
        let fixture = BackendHTTPFixture(failureStatus: 400, failureBody: expiryError)
        let (client, _) = try makeClient(fixture: fixture)

        try await client.upload(photo, objectKey: "owner/avatar.jpg", bucket: "avatars")

        let requests = await fixture.requests
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests[0].url, requests[2].url)
        XCTAssertEqual(requests[0].httpBody, photo)
        XCTAssertEqual(requests[2].httpBody, photo)
        XCTAssertEqual(requests[2].httpMethod, "POST")
        XCTAssertEqual(requests[2].value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
        XCTAssertEqual(requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
        XCTAssertNil(requests[1].value(forHTTPHeaderField: "Authorization"))
        let refreshBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[1].httpBody)) as? [String: String])
        XCTAssertEqual(refreshBody["refresh_token"], "old-refresh")
    }

    func testConcurrentStorageFailuresShareOneRefresh() async throws {
        let fixture = BackendHTTPFixture(failureStatus: 400, failureBody: expiryError)
        let (client, _) = try makeClient(fixture: fixture)

        async let first: Void = client.upload(photo, objectKey: "owner/one.jpg", bucket: "avatars")
        async let second: Void = client.upload(photo, objectKey: "owner/two.jpg", bucket: "avatars")
        _ = try await (first, second)

        let requests = await fixture.requests
        XCTAssertEqual(requests.filter { $0.url?.path == "/auth/v1/token" }.count, 1)
        XCTAssertEqual(requests.filter { $0.value(forHTTPHeaderField: "Authorization") == "Bearer fresh-token" }.count, 2)
    }

    func testUploadValidationAndPermissionErrorsDoNotRefresh() async throws {
        for (status, body) in [(400, #"{"code":"InvalidMimeType","message":"Invalid MIME type"}"#),
                               (403, #"{"code":"AccessDenied","message":"new row violates row-level security policy"}"#)] {
            let fixture = BackendHTTPFixture(failureStatus: status, failureBody: Data(body.utf8))
            let (client, _) = try makeClient(fixture: fixture)
            do {
                try await client.upload(photo, objectKey: "owner/avatar.jpg", bucket: "avatars")
                XCTFail("Upload should fail")
            } catch { XCTAssertTrue(error is CloudError) }
            let requests = await fixture.requests
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testStorageJWTCodeRetriesOnlyOnce() async throws {
        for (status, field) in [(400, "error"), (403, "code")] {
            let body = try JSONSerialization.data(withJSONObject: [field: "InvalidJWT", "message": "Invalid token"])
            let fixture = BackendHTTPFixture(failureStatus: status, failureBody: body, rejectFreshToken: true)
            let (client, _) = try makeClient(fixture: fixture)
            do {
                try await client.upload(photo, objectKey: "owner/avatar.jpg", bucket: "avatars")
                XCTFail("Repeated token rejection should fail")
            } catch { XCTAssertEqual(error.localizedDescription, "Invalid token") }
            let requests = await fixture.requests
            XCTAssertEqual(requests.count, 3)
        }
    }

    func testFailedRefreshDoesNotSendPhotoOrOverwriteSavedSession() async throws {
        let expired = CloudCredential(access_token: "old-token", refresh_token: "old-refresh", user: CloudUser(id: "owner"), expires_at: 1)
        let fixture = BackendHTTPFixture(failureStatus: 400, failureBody: expiryError, refreshStatus: 400)
        let (client, store) = try makeClient(credential: expired, fixture: fixture)
        do {
            try await client.upload(photo, objectKey: "owner/avatar.jpg", bucket: "avatars")
            XCTFail("Failed refresh should stop upload")
        } catch { XCTAssertEqual(error.localizedDescription, "Refresh token rejected") }
        let requests = await fixture.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.path, "/auth/v1/token")
        let saved = try JSONDecoder().decode(CloudCredential.self, from: XCTUnwrap(store.read()))
        XCTAssertEqual(saved, expired)
    }

    func testRPCUnauthorizedRetryPreservesIdempotencyKeyAndPayload() async throws {
        let fixture = BackendHTTPFixture(failureStatus: 401, failureBody: Data(#"{"message":"JWT expired"}"#.utf8))
        let (client, _) = try makeClient(fixture: fixture)
        let key = UUID()
        _ = try await client.command("save_profile", payload: ["name": "Alex"], key: key)
        let requests = await fixture.requests
        XCTAssertEqual(requests.count, 3)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[0].httpBody)) as? NSDictionary)
        let retried = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[2].httpBody)) as? NSDictionary)
        XCTAssertEqual(original, retried)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(requests[2].httpBody)) as? [String: Any])
        XCTAssertEqual(body["idempotency_key"] as? String, key.uuidString)
        XCTAssertEqual((body["payload"] as? [String: String])?["name"], "Alex")
    }

    func testExpiryMarginAndMissingExpiry() {
        let now = Date(timeIntervalSince1970: 100)
        var credential = CloudCredential(access_token: "opaque", refresh_token: "refresh", user: CloudUser(id: "owner"))
        XCTAssertFalse(credential.needsRefresh(at: now))
        credential.expires_at = 160
        XCTAssertTrue(credential.needsRefresh(at: now))
        credential.expires_at = 161
        XCTAssertFalse(credential.needsRefresh(at: now))
    }

    @MainActor
    func testCancelledBackgroundRefreshDoesNotShowAlertOrClearSession() async throws {
        let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data(), snapshotError: .cancelled)
        let (client, _) = try makeClient(fixture: fixture)
        let model = SocialAppModel(backend: client)
        model.userID = "owner"
        model.snapshot = SocialSnapshot(server_time: "previous-snapshot")

        await model.refresh()
        await model.refresh()

        XCTAssertNil(model.error)
        XCTAssertEqual(model.userID, "owner")
        XCTAssertEqual(model.snapshot.server_time, "previous-snapshot")
        let requests = await fixture.requests
        XCTAssertEqual(requests.count, 2, "Cancellation must release the refresh so a later attempt can run")
    }

    @MainActor
    func testBackgroundRefreshStillReportsNetworkAndServerFailures() async throws {
        // A server message containing "cancelled" is a real failure, not an
        // NSURLErrorCancelled. Do not filter errors by their display text.
        for code: URLError.Code? in [.timedOut, nil] {
            let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data(#"{"message":"cancelled"}"#.utf8), snapshotError: code)
            let (client, _) = try makeClient(fixture: fixture)
            let model = SocialAppModel(backend: client)
            model.userID = "owner"

            await model.refresh()

            XCTAssertEqual(model.error, code.map { URLError($0).localizedDescription } ?? "cancelled")
            XCTAssertEqual(model.userID, "owner")
        }
    }

    @MainActor
    func testCancelledViewTaskStillLoadsProfileThroughSharedRefresh() async throws {
        let started = expectation(description: "Snapshot request started")
        let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data(), snapshotStarted: started, holdSnapshots: true)
        let fresh = CloudCredential(access_token: "fresh-token", refresh_token: "refresh", user: CloudUser(id: "owner"))
        let (client, _) = try makeClient(credential: fresh, fixture: fixture)
        let model = SocialAppModel(backend: client)
        model.userID = "owner"
        let originalView = Task { await model.refresh() }
        await fulfillment(of: [started], timeout: 5)

        originalView.cancel()
        let joined = expectation(description: "Replacement view requested refresh")
        let nextView = Task { joined.fulfill(); await model.refresh() }
        await fulfillment(of: [joined], timeout: 5)
        await fixture.releaseSnapshots()
        await originalView.value
        await nextView.value

        XCTAssertNil(model.error)
        XCTAssertEqual(model.userID, "owner")
        XCTAssertEqual(model.snapshot.server_time, "snapshot-loaded")
        let requests = await fixture.requests
        XCTAssertEqual(requests.count, 1, "Overlapping view and foreground refreshes should share a request")
    }

    @MainActor
    func testSavingProfileReplacesAnOlderRefresh() async throws {
        let started = expectation(description: "Pre-save snapshot started")
        let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data(), snapshotStarted: started, holdSnapshots: true)
        let fresh = CloudCredential(access_token: "fresh-token", refresh_token: "refresh", user: CloudUser(id: "owner"))
        let (client, _) = try makeClient(credential: fresh, fixture: fixture)
        let model = SocialAppModel(backend: client)
        model.userID = "owner"
        let previousRefresh = Task { await model.refresh() }
        await fulfillment(of: [started], timeout: 5)

        let finished = expectation(description: "Save fetched the new profile without waiting for the old snapshot")
        let save = Task {
            let result = await model.perform("save_profile", ["name": "Alex"])
            finished.fulfill()
            return result
        }
        await fulfillment(of: [finished], timeout: 5)
        await fixture.releaseSnapshots()
        let result = await save.value
        await previousRefresh.value

        XCTAssertNotNil(result)
        XCTAssertNil(model.error)
        XCTAssertEqual(model.me?.text("name"), "Alex")
        XCTAssertEqual(model.snapshot.server_time, "profile-saved")
    }

    @MainActor
    func testMultiDayRetrySkipsCompletedDaysAndReusesReceiptAfterLostResponse() async throws {
        let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data(), loseCreateResponseAt: 2)
        let fresh = CloudCredential(access_token: "fresh-token", refresh_token: "refresh", user: CloudUser(id: "owner"))
        let (client, _) = try makeClient(credential: fresh, fixture: fixture)
        let model = SocialAppModel(backend: client)
        model.userID = "owner"
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        ui.runtime = runtime
        runtime.sync()
        ui.go(.create())
        let requests = creationRequests()

        let first = await ui.createSessions(requests)
        XCTAssertFalse(first)
        XCTAssertEqual(ui.createdCount(for: requests), 1)
        XCTAssertEqual(ui.path.last, .create())
        XCTAssertFalse(ui.busy)
        let savedBeforeRetry = await fixture.createdSessionCount
        XCTAssertEqual(savedBeforeRetry, 2, "The interrupted request committed before its response was lost")

        let retry = await ui.createSessions(requests)
        XCTAssertTrue(retry)
        XCTAssertNil(model.error)
        XCTAssertEqual(ui.createdCount(for: requests), 3)
        XCTAssertEqual(ui.tab, .training)
        XCTAssertTrue(ui.path.isEmpty)
        let savedAfterRetry = await fixture.createdSessionCount
        XCTAssertEqual(savedAfterRetry, 3, "Retry must not duplicate the day whose response was lost")
        let wireRequests = await fixture.requests
        let commands = try wireRequests.filter { $0.url?.path == "/rest/v1/rpc/command" }.map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap($0.httpBody)) as? [String: Any])
        }
        XCTAssertEqual(commands.compactMap { $0["idempotency_key"] as? String }, [requests[0].id, requests[1].id, requests[1].id, requests[2].id].map(\.uuidString))
        let retriedPayload = try XCTUnwrap(commands[2]["payload"] as? [String: Any])
        XCTAssertEqual(retriedPayload["timezone"] as? String, "America/Los_Angeles")
        XCTAssertEqual(retriedPayload["invited"] as? [String], ["friend"])
        let note = SessionNoteCodec.decode(try XCTUnwrap(retriedPayload["note"] as? String))
        XCTAssertEqual(note.note, "Bring a gi")
        XCTAssertEqual(note.focus.map(\.title), ["Guard passing"])
    }

    @MainActor
    func testMultiDayCreationStaysBusyBetweenWritesAndRejectsDuplicateSubmission() async throws {
        let started = expectation(description: "First session saved, refresh pending")
        let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data(), snapshotStarted: started, holdSnapshots: true)
        let fresh = CloudCredential(access_token: "fresh-token", refresh_token: "refresh", user: CloudUser(id: "owner"))
        let (client, _) = try makeClient(credential: fresh, fixture: fixture)
        let model = SocialAppModel(backend: client)
        model.userID = "owner"
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        ui.runtime = runtime
        runtime.sync()
        let requests = creationRequests()
        let batch = Task { await ui.createSessions(requests) }
        await fulfillment(of: [started], timeout: 5)
        XCTAssertTrue(ui.busy)
        let duplicate = await ui.createSessions(requests)
        XCTAssertFalse(duplicate)
        await fixture.releaseSnapshots()
        let result = await batch.value
        XCTAssertTrue(result)
        let saved = await fixture.createdSessionCount
        XCTAssertEqual(saved, 3)
        XCTAssertFalse(ui.busy)
    }

    @MainActor
    func testSigningOutStopsRemainingSessionCreationsAndClearsRetryState() async throws {
        let started = expectation(description: "First session refresh pending")
        let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data(), snapshotStarted: started, holdSnapshots: true)
        let fresh = CloudCredential(access_token: "fresh-token", refresh_token: "refresh", user: CloudUser(id: "owner"))
        let (client, _) = try makeClient(credential: fresh, fixture: fixture)
        let model = SocialAppModel(backend: client)
        model.userID = "owner"
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        ui.runtime = runtime
        runtime.sync()
        let requests = creationRequests()
        let batch = Task { await ui.createSessions(requests) }
        await fulfillment(of: [started], timeout: 5)
        model.userID = nil
        runtime.sync()
        await fixture.releaseSnapshots()
        let result = await batch.value
        XCTAssertFalse(result)
        XCTAssertEqual(ui.createdCount(for: requests), 0)
        let saved = await fixture.createdSessionCount
        XCTAssertEqual(saved, 1)
        XCTAssertFalse(ui.busy)
        XCTAssertTrue(ui.path.isEmpty)
    }

    private func creationRequests() -> [SessionCreationRequest] {
        let draft = SessionDraft(title: "Partner drills", day: "", date: 0, month: "", time: "6:00 PM", gym: "Home gym",
                                 note: "Bring a gi", invited: ["friend"], privacy: .friends, past: false,
                                 focusItems: [TrainingFocus(title: "Guard passing")])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let dates = ["2026-11-03T20:00:00Z", "2026-11-05T20:00:00Z", "2026-11-07T20:00:00Z"].map { ISO8601DateFormatter().date(from: $0)! }
        return draft.scheduled(on: dates, calendar: calendar).map { SessionCreationRequest(draft: $0) }
    }

    private func makeClient(credential: CloudCredential = CloudCredential(access_token: "old-token", refresh_token: "old-refresh", user: CloudUser(id: "owner")), fixture: BackendHTTPFixture) throws -> (BackendClient, BackendCredentialStore) {
        let host = UUID().uuidString.lowercased() + ".example.com"
        BackendURLProtocol.register(host: host, fixture: fixture)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BackendURLProtocol.self]
        let session = URLSession(configuration: configuration)
        addTeardownBlock {
            session.invalidateAndCancel()
            BackendURLProtocol.unregister(host: host)
        }
        let store = BackendCredentialStore(try JSONEncoder().encode(credential))
        let backend = BackendClient(configuration: BackendConfiguration(url: URL(string: "https://" + host)!, key: "test-publishable-key"),
                                    session: session, loadCredential: store.read, saveCredential: store.write)
        return (backend, store)
    }
}

private final class BackendCredentialStore {
    private let lock = NSLock()
    private var data: Data
    init(_ data: Data) { self.data = data }
    func read() -> Data? { lock.lock(); defer { lock.unlock() }; return data }
    func write(_ data: Data) { lock.lock(); defer { lock.unlock() }; self.data = data }
}

private actor BackendHTTPFixture {
    private(set) var requests: [URLRequest] = []
    let failureStatus: Int
    let failureBody: Data
    let rejectFreshToken: Bool
    let refreshStatus: Int
    let snapshotError: URLError.Code?
    let snapshotStarted: XCTestExpectation?
    private var holdSnapshots: Bool
    private var snapshotWaiters: [CheckedContinuation<Void, Never>] = []
    private var profileSaved = false
    private let loseCreateResponseAt: Int?
    private var createAttempts = 0
    private var createReceipts: [String: (payload: Data, id: String)] = [:]
    var createdSessionCount: Int { createReceipts.count }

    init(failureStatus: Int, failureBody: Data, rejectFreshToken: Bool = false, refreshStatus: Int = 200,
         snapshotError: URLError.Code? = nil, snapshotStarted: XCTestExpectation? = nil, holdSnapshots: Bool = false, loseCreateResponseAt: Int? = nil) {
        self.failureStatus = failureStatus
        self.failureBody = failureBody
        self.rejectFreshToken = rejectFreshToken
        self.refreshStatus = refreshStatus
        self.snapshotError = snapshotError
        self.snapshotStarted = snapshotStarted
        self.holdSnapshots = holdSnapshots
        self.loseCreateResponseAt = loseCreateResponseAt
    }

    func releaseSnapshots() {
        holdSnapshots = false
        let waiters = snapshotWaiters
        snapshotWaiters = []
        for waiter in waiters { waiter.resume() }
    }

    func respond(to original: URLRequest) async throws -> (Int, Data) {
        var request = original
        // URLSession may move a POST body into a stream for URLProtocol.
        if request.httpBody == nil, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var bytes = Data()
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                bytes.append(contentsOf: buffer.prefix(count))
            }
            request.httpBody = bytes
        }
        requests.append(request)
        if request.url?.path == "/rest/v1/rpc/snapshot", let snapshotError { throw URLError(snapshotError) }
        if request.url?.path == "/auth/v1/token" {
            // Keep refresh in flight while another upload receives its rejection.
            try await Task.sleep(nanoseconds: 50_000_000)
            if refreshStatus != 200 { return (refreshStatus, Data(#"{"message":"Refresh token rejected"}"#.utf8)) }
            let refreshed = CloudCredential(access_token: "fresh-token", refresh_token: "rotated-refresh", user: CloudUser(id: "owner"), expires_at: Date().timeIntervalSince1970 + 3600)
            return (200, try JSONEncoder().encode(refreshed))
        }
        if request.value(forHTTPHeaderField: "Authorization") != "Bearer fresh-token" || rejectFreshToken {
            return (failureStatus, failureBody)
        }
        if request.url?.path == "/rest/v1/rpc/command",
           let body = request.httpBody,
           let command = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           command["operation"] as? String == "save_profile" { profileSaved = true }
        if request.url?.path == "/rest/v1/rpc/command", let body = request.httpBody,
           let command = try JSONSerialization.jsonObject(with: body) as? [String: Any],
           command["operation"] as? String == "create_session",
           let key = command["idempotency_key"] as? String, let payload = command["payload"] as? [String: Any] {
            createAttempts += 1
            let encoded = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            let receipt = createReceipts[key] ?? (payload: encoded, id: UUID().uuidString)
            guard receipt.payload == encoded else { return (409, Data(#"{"message":"Idempotency key reused with different payload"}"#.utf8)) }
            createReceipts[key] = receipt
            if createAttempts == loseCreateResponseAt { throw URLError(.networkConnectionLost) }
            return (200, try JSONSerialization.data(withJSONObject: ["id": receipt.id]))
        }
        if request.url?.path == "/rest/v1/rpc/snapshot" {
            var snapshot = SocialSnapshot(server_time: profileSaved ? "profile-saved" : "snapshot-loaded")
            if profileSaved {
                snapshot.profiles = try JSONDecoder().decode([SocialRow].self, from: Data(#"[{"id":"owner","name":"Alex"}]"#.utf8))
            }
            if holdSnapshots {
                holdSnapshots = false
                snapshotStarted?.fulfill()
                await withCheckedContinuation { snapshotWaiters.append($0) }
            }
            return (200, try JSONEncoder().encode(snapshot))
        }
        return (200, Data("{}".utf8))
    }
}

private final class BackendURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var fixtures: [String: BackendHTTPFixture] = [:]
    private var responseTask: Task<Void, Never>?

    static func register(host: String, fixture: BackendHTTPFixture) {
        lock.lock(); defer { lock.unlock() }; fixtures[host] = fixture
    }
    static func unregister(host: String) {
        lock.lock(); defer { lock.unlock() }; fixtures[host] = nil
    }
    private static func fixture(for request: URLRequest) -> BackendHTTPFixture? {
        lock.lock(); defer { lock.unlock() }; return fixtures[request.url?.host ?? ""]
    }
    override class func canInit(with request: URLRequest) -> Bool { fixture(for: request) != nil }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let fixture = Self.fixture(for: request), let url = request.url else { return }
        responseTask = Task {
            do {
                let (status, data) = try await fixture.respond(to: request)
                let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() { responseTask?.cancel() }
}

@MainActor
final class PlaceSearchTests: XCTestCase {
    func testShortQueriesDoNotSearchAndClearingCancelsPendingResults() {
        var clients: [PlaceSearchTestClient] = []
        let search = PlaceSearch { let client = PlaceSearchTestClient(); clients.append(client); return client }
        search.updateQuery(" R ")
        XCTAssertTrue(clients.isEmpty)
        XCTAssertEqual(search.state, .idle)
        search.updateQuery("  Ralph Gracie  ")
        XCTAssertEqual(clients.first?.queries, ["Ralph Gracie"])
        XCTAssertEqual(search.state, .searching)
        search.updateQuery("Ralph Gracie ")
        XCTAssertEqual(clients.count, 1, "Whitespace changes do not send another lookup")
        search.updateQuery("")
        XCTAssertTrue(clients[0].cancelled)
        clients[0].complete(.success([PlaceSuggestion(title: "Late gym", subtitle: "Old address")]))
        XCTAssertEqual(search.state, .idle)
        XCTAssertTrue(search.suggestions.isEmpty, "A dismissed dropdown cannot reopen from a late result")
    }

    func testNewQueryRejectsOlderSuccessAndFailureCallbacks() {
        var clients: [PlaceSearchTestClient] = []
        let search = PlaceSearch { let client = PlaceSearchTestClient(); clients.append(client); return client }
        search.updateQuery("Ralph")
        search.updateQuery("Gracie")
        XCTAssertTrue(clients[0].cancelled)
        let current = PlaceSuggestion(title: "Gracie Academy", subtitle: "123 Main Street")
        clients[1].complete(.success([current]))
        clients[0].complete(.success([PlaceSuggestion(title: "Other gym", subtitle: "Old address")]))
        clients[0].complete(.failure(URLError(.cancelled)))
        XCTAssertEqual(search.suggestions, [current])
        XCTAssertEqual(search.state, .ready)
    }

    func testAddressesDistinguishSameNameVenuesAndResultsAreLimited() {
        let client = PlaceSearchTestClient()
        let search = PlaceSearch { client }
        search.updateQuery("Academy")
        let first = PlaceSuggestion(title: "Academy", subtitle: "First Street")
        let second = PlaceSuggestion(title: "Academy", subtitle: "Second Street")
        let extra = (1...8).map { PlaceSuggestion(title: "Gym \($0)", subtitle: "Street \($0)") }
        client.complete(.success([first, first, second, PlaceSuggestion(title: "", subtitle: "")] + extra))
        XCTAssertEqual(Array(search.suggestions.prefix(2)), [first, second])
        XCTAssertEqual(search.suggestions.count, 5)
        XCTAssertEqual(Set(search.suggestions).count, 5)
    }

    func testFailedAndEmptySearchesKeepManualVenueEntryAvailable() {
        var clients: [PlaceSearchTestClient] = []
        let search = PlaceSearch { let client = PlaceSearchTestClient(); clients.append(client); return client }
        search.updateQuery("Private training space")
        clients[0].complete(.failure(URLError(.notConnectedToInternet)))
        XCTAssertEqual(search.query, "Private training space")
        XCTAssertEqual(search.state, .unavailable)
        XCTAssertTrue(search.suggestions.isEmpty)
        search.updateQuery("Different venue")
        clients[1].complete(.success([]))
        XCTAssertEqual(search.query, "Different venue")
        XCTAssertEqual(search.state, .ready)
        XCTAssertTrue(search.suggestions.isEmpty)
    }
}

@MainActor
private final class PlaceSearchTestClient: PlaceSearchClient {
    var queries: [String] = []
    var cancelled = false
    private var completion: ((Result<[PlaceSuggestion], Error>) -> Void)?
    func search(_ query: String, completion: @escaping (Result<[PlaceSuggestion], Error>) -> Void) {
        queries.append(query)
        self.completion = completion
    }
    func cancel() { cancelled = true }
    // Keep the callback to exercise responses that were already in flight at cancellation.
    func complete(_ result: Result<[PlaceSuggestion], Error>) { completion?(result) }
}
