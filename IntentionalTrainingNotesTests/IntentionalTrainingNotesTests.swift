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
    func testGripGorillasBrandingIsBundledInTheInstalledApp() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Grip Gorillas")
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
        let ui = AppModel(live: true)
        XCTAssertFalse(ui.isSignedIn)
        XCTAssertTrue(ui.people.isEmpty)
        XCTAssertTrue(ui.friends.isEmpty)
        XCTAssertTrue(ui.posts.isEmpty)
        XCTAssertTrue(ui.upcoming.isEmpty)
        XCTAssertNil(ui.toComplete)
        XCTAssertTrue(ui.cameraRoll.isEmpty)
        ui.run(.active)
        ui.reset()
        XCTAssertTrue(ui.people.isEmpty, "Prototype tools must never inject seed data into the installed app")
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

    init(failureStatus: Int, failureBody: Data, rejectFreshToken: Bool = false, refreshStatus: Int = 200) {
        self.failureStatus = failureStatus
        self.failureBody = failureBody
        self.rejectFreshToken = rejectFreshToken
        self.refreshStatus = refreshStatus
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
        return (200, Data("{}".utf8))
    }
}

private final class BackendURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var fixtures: [String: BackendHTTPFixture] = [:]
    private var task: Task<Void, Never>?

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
        task = Task {
            do {
                let (status, data) = try await fixture.respond(to: request)
                let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() { task?.cancel() }
}
