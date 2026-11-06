import XCTest
import UIKit
import SwiftUI
@testable import IntentionalTrainingNotes

final class IntentionalTrainingNotesTests: XCTestCase {
    func testNotificationDestinationsUseTheirOwnEntityIDs() {
        let cases: [(AppNotification.Kind, Route)] = [
            (.invite, .session(id: "target")), (.joined, .session(id: "target")),
            (.comment, .post(id: "target")), (.published, .post(id: "target")),
            (.like, .post(id: "target")), (.mention, .post(id: "target")),
            (.friend, .friend(id: "actor")), (.goalShare, .sharedGoal(id: "target")),
            (.goalUpdate, .sharedGoal(id: "target"))
        ]
        for (kind, expected) in cases {
            let note = AppNotification(id: "notification", kind: kind, who: "actor", session: "target", time: "now")
            XCTAssertEqual(note.destination, expected, "Incorrect destination for \(kind)")
            XCTAssertEqual(AppNotification.destination(kind: kind, entityID: kind == .friend ? "actor" : "target"), expected,
                           "Push and in-app destinations must agree")
        }
        let first = AppNotification(id: "first", kind: .like, who: "actor", session: "first-post", time: "now")
        let second = AppNotification(id: "second", kind: .like, who: "actor", session: "second-post", time: "now")
        XCTAssertEqual(first.destination, .post(id: "first-post"))
        XCTAssertEqual(second.destination, .post(id: "second-post"))
    }

    func testNotificationsWithoutTargetsNeverFallBackToAnotherActivity() {
        for kind: AppNotification.Kind in [.invite, .joined, .comment, .published, .like, .mention, .friend, .goalShare, .goalUpdate] {
            for entityID: String? in [nil, "", "  "] {
                XCTAssertNil(AppNotification.destination(kind: kind, entityID: entityID))
            }
        }
        XCTAssertNil(AppNotification(id: "missing", kind: .like, who: "actor", time: "now").destination)
        XCTAssertEqual(AppNotification(id: "friend", kind: .friend, who: "actor", time: "now").destination, .friend(id: "actor"))
    }

    @MainActor
    func testPreviewNotificationsReferToTheActivityTheyDescribe() {
        let ui = AppModel(live: false)
        for note in ui.notifications {
            XCTAssertNotNil(note.destination)
            switch note.destination {
            case .post(let id, _, _):
                let post = ui.post(id)
                XCTAssertNotNil(post)
                if let photo = note.photo { XCTAssertEqual(photo, post?.photo) }
            case .session(let id): XCTAssertNotNil(ui.findSession(id))
            case .sharedGoal(let id): XCTAssertNotNil(ui.sharedGoal(id))
            default: break
            }
        }
    }

    @MainActor
    func testActivityPlansKeepPersonalPlansUntilAttendanceWithoutChangingMemories() {
        let ui = AppModel(live: true)
        ui.quickTrainingLogBackendAvailable = true
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func plan(_ id: String, privacy: Privacy = .link, rsvp: RSVP = .going, offset: TimeInterval = 60) -> Session {
            Session(id: id, title: id, day: "Fri", date: 15, month: "Jan", time: "6:00 PM", gym: "Gym",
                    organizer: "me", privacy: privacy, people: [Attendee(id: "me", status: rsvp)],
                    startsAt: now.addingTimeInterval(offset))
        }
        ui.upcoming = [plan("private", privacy: .friends), plan("later", offset: 120), plan("started", offset: 0),
                       plan("declined", rsvp: .declined), plan("earlier")]
        XCTAssertEqual(ui.activityPlans(at: now).map(\.id), ["started", "earlier", "private", "later"])
        XCTAssertEqual(ui.activityPlans(at: now.addingTimeInterval(120)).count, 4, "Open plans stay visible after their start")
        XCTAssertTrue(ui.posts.isEmpty, "An upcoming entry never creates a completed memory")
        ui.upcoming.removeAll { $0.id == "earlier" }
        XCTAssertEqual(ui.activityPlans(at: now).map(\.id), ["started", "private", "later"], "Cancelling removes the plan from Activity")
    }

    @MainActor
    func testOldDiscoveryCacheStaysHiddenUntilAcceptedAndLeavesAfterCompletion() throws {
        let model = SocialAppModel()
        model.userID = "owner"
        model.snapshot.activity_sessions = try JSONDecoder().decode([SocialRow].self, from: Data(#"""
        [{"id":"open","organizer":"friend","title":"Open rolls","starts_at":"2099-01-01T18:00:00Z","venue":"Gym","status":"planned","join_mode":"link"}]
        """#.utf8))
        model.snapshot.participants = try JSONDecoder().decode([SocialRow].self, from: Data(#"""
        [{"session_id":"open","user_id":"friend","rsvp":"going"}]
        """#.utf8))
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        runtime.sync()
        XCTAssertTrue(ui.activityPlans().isEmpty)
        XCTAssertTrue(ui.plannedSessions.isEmpty)
        XCTAssertNil(ui.findSession("open"), "Old discovery caches cannot reveal unaccepted session details")
        model.snapshot.participants += try JSONDecoder().decode([SocialRow].self, from: Data(#"""
        [{"session_id":"open","user_id":"owner","rsvp":"going"}]
        """#.utf8))
        model.snapshot.sessions = model.snapshot.activity_sessions ?? []
        model.snapshot.activity_sessions = []
        runtime.sync()
        XCTAssertEqual(ui.plannedSessions.map(\.id), ["open"])
        XCTAssertEqual(ui.activityPlans().map(\.id), ["open"], "Joining keeps just one Activity entry")
        XCTAssertTrue(ui.discoverableSessions.isEmpty)
        model.snapshot.sessions[0].values["status"] = .string("completed")
        runtime.sync()
        XCTAssertTrue(ui.activityPlans().isEmpty)
        XCTAssertTrue(ui.plannedSessions.isEmpty)
        model.userID = nil
        runtime.sync()
        XCTAssertTrue(ui.discoverableSessions.isEmpty)
    }

    @MainActor
    func testCreatingPersonalPreviewPlansAddsActivityImmediately() {
        let ui = AppModel(live: false)
        ui.upcoming = []
        ui.toComplete = nil
        let memories = ui.posts
        var draft = SessionDraft(title: "Open rolls", day: "Fri", date: 15, month: "Jan", time: "6:00 PM", gym: "Gym",
                                 note: "", invited: [], privacy: .link, past: false,
                                 startsAt: Date().addingTimeInterval(3600))
        ui.createSession(draft)
        XCTAssertEqual(ui.activityPlans().map(\.title), ["Open rolls"])
        draft.title = "Private rolls"
        draft.privacy = .friends
        ui.createSession(draft)
        XCTAssertEqual(Set(ui.activityPlans().map(\.title)), Set(["Open rolls", "Private rolls"]))
        XCTAssertEqual(ui.posts, memories)
    }

    @MainActor
    func testPreviewInvitationShowsNoDetailsUntilAccepted() throws {
        let ui = AppModel(live: false)
        let invitation = try XCTUnwrap(ui.pendingTrainingInvitations.first)
        XCTAssertFalse(ui.activityPlans().contains { $0.id == invitation.id })
        ui.rsvp(invitation.id, .going)
        XCTAssertFalse(ui.pendingTrainingInvitations.contains { $0.id == invitation.id })
        XCTAssertEqual(ui.findSession(invitation.id)?.status(of: "me"), .going)
        ui.rsvp(invitation.id, .declined)
        XCTAssertFalse(ui.plannedSessions.contains { $0.id == invitation.id })
    }

    @MainActor
    func testScanningAndFollowingBothGrantInvitePermission() {
        let ui = AppModel(live: false)
        XCTAssertFalse(ui.canInvite("lena"))
        ui.addFriend("lena")
        XCTAssertTrue(ui.isFollowing("lena"))
        XCTAssertTrue(ui.canInvite("lena"))
        ui.setFollowing("lena", false)
        XCTAssertFalse(ui.canInvite("lena"), "Unfollowing removes the mutual connection")
        ui.setFollowing("rafa", true)
        XCTAssertTrue(ui.invitees.contains { $0.id == "rafa" })
        XCTAssertTrue(ui.canInvite("rafa"))
        XCTAssertNotNil(ui.friendship("rafa"), "Following creates a training partnership")
        ui.setFollowing("rafa", false)
        XCTAssertNil(ui.friendship("rafa"))
        XCTAssertFalse(ui.isFollowing("rafa"))
    }

    @MainActor
    func testFollowAndScanCreateTheSameActivityAndSharingConnection() throws {
        let followed = AppModel(live: false)
        let scanned = AppModel(live: false)
        var memory = try XCTUnwrap(followed.posts.first)
        memory.organizer = "rafa"
        memory.participants = ["rafa"]
        followed.posts = [memory]
        scanned.posts = [memory]
        XCTAssertTrue(followed.feedPosts.isEmpty)
        followed.setFollowing("rafa", true)
        scanned.addFriend("rafa")
        XCTAssertEqual(followed.feedPosts, scanned.feedPosts)
        XCTAssertEqual(followed.feedPosts, [memory])
        XCTAssertEqual(followed.friendship("rafa"), scanned.friendship("rafa"))
        XCTAssertTrue(followed.friends.contains { $0.id == "rafa" }, "Note sharing offers training partners")
        followed.setFollowing("rafa", false)
        XCTAssertTrue(followed.feedPosts.isEmpty)
        XCTAssertNil(followed.friendship("rafa"))
        followed.setFollowing("stranger", true)
        XCTAssertFalse(followed.isFollowing("stranger"))
    }

    @MainActor
    func testLivePendingInvitationContainsOnlyHostAndIdentity() throws {
        let model = SocialAppModel()
        model.userID = "owner"
        model.snapshot = try JSONDecoder().decode(SocialSnapshot.self, from: Data(#"""
        {"profiles":[],"friendships":[],"sessions":[],"participants":[],"posts":[],"tags":[],"likes":[],"comments":[],"credits":[],"media":[],"notifications":[],
         "training_invitations":[{"id":"invitation","organizer":"host","organizer_name":"Sarah"}]}
        """#.utf8))
        let ui = AppModel(live: true)
        LiveMatMindRuntime(model: model, ui: ui).sync()
        XCTAssertEqual(ui.pendingTrainingInvitations, [TrainingInvitation(id: "invitation", organizer: "host")])
        XCTAssertEqual(ui.person("host").name, "Sarah")
        XCTAssertNil(ui.findSession("invitation"))
        XCTAssertTrue(ui.activityPlans().isEmpty)
        // A cache written by the previous client may still have full invited rows.
        model.snapshot.training_invitations = nil
        model.snapshot.sessions = try JSONDecoder().decode([SocialRow].self, from: Data(#"""
        [{"id":"invitation","organizer":"host","title":"Private title","venue":"Private venue","note":"Private note","starts_at":"2099-01-01T18:00:00Z","status":"planned","join_mode":"link"}]
        """#.utf8))
        model.snapshot.participants = try JSONDecoder().decode([SocialRow].self, from: Data(#"""
        [{"session_id":"invitation","user_id":"owner","rsvp":"invited"}]
        """#.utf8))
        LiveMatMindRuntime(model: model, ui: ui).sync()
        XCTAssertEqual(ui.pendingTrainingInvitations.map(\.id), ["invitation"])
        XCTAssertTrue(ui.upcoming.isEmpty)
        XCTAssertNil(ui.findSession("invitation"))
    }

    func testMentionTypingAndInsertionAfterEmoji() {
        XCTAssertEqual(UsernameMention.query(in: "Great rolls 😀 @Hi"), "hi")
        XCTAssertEqual(UsernameMention.inserting("hippo", in: "Great rolls 😀 @Hi"), "Great rolls 😀 @hippo ")
        XCTAssertEqual(UsernameMention.query(in: "(@"), "")
        XCTAssertNil(UsernameMention.query(in: "email@hippo"))
        XCTAssertNil(UsernameMention.query(in: "@@hippo"))
        XCTAssertNil(UsernameMention.query(in: "@hippo "))
        XCTAssertNil(UsernameMention.query(in: "@" + String(repeating: "a", count: 41)))
    }

    func testMentionGrammarMatchesOnlyWholeUsernames() {
        let text = "😀 (@HiPpO), @training_partner! a@hippo.com @ab @" + String(repeating: "a", count: 41)
        let handles = UsernameMention.ranges(in: text).compactMap { Range($0, in: text).map { String(text[$0]) } }
        XCTAssertEqual(handles, ["@HiPpO", "@training_partner"])
        XCTAssertEqual(AppNotification.Kind(rawValue: "mention"), .mention)
    }

    func testSharingNeedsAPhotoOrANote() {
        XCTAssertFalse(ShareRule.canPublish(hasPhoto: false, caption: ""))
        XCTAssertFalse(ShareRule.canPublish(hasPhoto: false, caption: "  \n\t "))
        XCTAssertFalse(ShareRule.canPublish(hasPhoto: false, caption: "@sarah @lena "))
        XCTAssertTrue(ShareRule.canPublish(hasPhoto: true, caption: ""))
        XCTAssertTrue(ShareRule.canPublish(hasPhoto: false, caption: "Standups with @sarah"))
        XCTAssertTrue(ShareRule.canPublish(hasPhoto: false, caption: "😀"))
        XCTAssertTrue(ShareRule.canPublish(hasPhoto: true, caption: "Leg drags all day"))
    }

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
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "Mat Monkey")
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

    func testCommentsCanBeDeletedByTheirAuthorOrThePostOrganizer() {
        let ui = AppModel(live: false)
        // p1 is Sarah's post: you can delete your own comment there, not Alex's.
        ui.comment("p1", "Wrong post, sorry")
        let mine = ui.post("p1")!.comments.last!
        let alexs = ui.post("p1")!.comments.first!
        XCTAssertTrue(ui.canDelete(mine, on: "p1"))
        XCTAssertFalse(ui.canDelete(alexs, on: "p1"))
        ui.deleteComment(mine, on: "p1")
        XCTAssertFalse(ui.post("p1")!.comments.contains { $0.id == mine.id })
        XCTAssertEqual(ui.post("p1")!.comments.count, 2)

        // p3 is your post: you can clear anyone's comment on it.
        let lenas = ui.post("p3")!.comments.first!
        XCTAssertTrue(ui.canDelete(lenas, on: "p3"))
        ui.deleteComment(lenas, on: "p3")
        XCTAssertTrue(ui.post("p3")!.comments.isEmpty)
    }

    func testTrainingScheduleAndGoalNextSessionUseStartTimeRatherThanSnapshotOrder() {
        let ui = AppModel(live: true)
        func session(_ id: String, _ start: String, status: RSVP = .going) -> Session {
            // Labels deliberately match: ordering must use the full date, including time and year.
            Session(id: id, title: id, day: "Thu", date: 31, month: "Dec", time: "6:00 PM", gym: "Home gym",
                    organizer: "me", people: [Attendee(id: "me", status: status)],
                    startsAt: ISO8601DateFormatter().date(from: start)!)
        }
        ui.upcoming = [
            session("next-year", "2031-01-01T18:00:00Z"),
            session("evening", "2030-12-31T18:00:00Z"),
            session("morning-b", "2030-12-31T10:00:00Z", status: .invited),
            session("morning-a", "2030-12-31T10:00:00Z"),
            session("declined", "2030-12-30T10:00:00Z", status: .declined),
            session("awaiting-photo", "2020-12-29T10:00:00Z"),
        ]
        ui.toComplete = ui.upcoming.last
        ui.sessionGoals = ["next-year": "goal", "evening": "goal", "morning-a": "goal"]

        XCTAssertEqual(ui.plannedSessions.map(\.id), ["morning-a", "morning-b", "evening", "next-year"])
        XCTAssertEqual(ui.plannedSessions.filter { $0.status(of: "me") == .going }.map(\.id), ["morning-a", "evening", "next-year"])
        XCTAssertEqual(ui.nextSession(forGoal: "goal")?.id, "morning-a")
        ui.upcoming.reverse()
        XCTAssertEqual(ui.plannedSessions.map(\.id), ["morning-a", "morning-b", "evening", "next-year"], "A refresh with a different row order must not reorder equal-time sessions")
    }

    func testEveryPastSessionYouLoggedCanBeShared() {
        let ui = AppModel(live: true)
        func session(_ id: String, _ start: Date, organizer: String = "me") -> Session {
            Session(id: id, title: id, day: "Mon", date: 1, month: "Jan", time: "6:00 PM", gym: "Home gym",
                    organizer: organizer, people: [Attendee(id: "me", status: .going)], startsAt: start)
        }
        let now = Date()
        ui.upcoming = [
            session("tomorrow", now.addingTimeInterval(86_400)),
            session("this-morning", now.addingTimeInterval(-3_600 * 6)),
            session("logged-three-days-ago", now.addingTimeInterval(-86_400 * 3)),
            session("friend-hosted", now.addingTimeInterval(-86_400), organizer: "friend"),
        ]
        ui.toComplete = ui.upcoming[1]

        // An older logged session is shareable too, not only the most recent one.
        XCTAssertEqual(ui.readyToShare.map(\.id), ["this-morning", "logged-three-days-ago"])
        XCTAssertTrue(ui.isReadyToShare("logged-three-days-ago"))
        XCTAssertFalse(ui.isReadyToShare("tomorrow"))
        // Sessions waiting to be shared have already happened, so they aren't "coming up".
        XCTAssertFalse(ui.plannedSessions.contains { $0.id == "logged-three-days-ago" })
        XCTAssertTrue(ui.plannedSessions.contains { $0.id == "tomorrow" })
    }

    func testActivityPromptFollowsTheNearestCommittedSessionAsTimePasses() {
        let ui = AppModel(live: true)
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        func session(_ id: String, offset: TimeInterval, organizer: String = "me", status: RSVP = .going) -> Session {
            Session(id: id, title: id, day: "Tue", date: 3, month: "Nov", time: "10:00 AM", gym: "Home gym",
                    organizer: organizer, people: [Attendee(id: "me", status: status)], startsAt: now.addingTimeInterval(offset))
        }
        let recent = session("recent", offset: -3600)
        let next = session("next", offset: 7200)
        ui.upcoming = [
            session("old", offset: -86400), next, recent,
            session("invited", offset: 1, organizer: "friend", status: .invited),
            session("declined", offset: -1, organizer: "friend", status: .declined),
        ]
        // A stale completion pointer must not decide which session Activity shows.
        ui.toComplete = ui.upcoming.first
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "recent")
        ui.upcoming.reverse()
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "recent")
        XCTAssertEqual(ui.activityPrompt(at: now.addingTimeInterval(7200))?.id, "next")

        ui.upcoming = [session("near-future", offset: 60), recent]
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "near-future", "An upcoming session can be closer than a past one")
        ui.toComplete = nil
        ui.upcoming = [next]
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "next", "The prompt must exist before any session is ready to share")
        ui.upcoming = [session("joined", offset: 60, organizer: "friend"), next]
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "joined")

        ui.upcoming = []
        XCTAssertNil(ui.activityPrompt(at: now))
        ui.toComplete = recent
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "recent", "Preview completion sessions can live outside the schedule")
    }

    func testActivityPromptBreaksEqualDistanceAndEqualTimeTiesConsistently() {
        let ui = AppModel(live: true)
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        func session(_ id: String, offset: TimeInterval) -> Session {
            Session(id: id, title: id, day: "Tue", date: 3, month: "Nov", time: "10:00 AM", gym: "Home gym",
                    organizer: "me", people: [Attendee(id: "me", status: .going)], startsAt: now.addingTimeInterval(offset))
        }
        ui.upcoming = [session("future", offset: 60), session("past-b", offset: -60), session("past-a", offset: -60)]
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "past-a")
        ui.upcoming.reverse()
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "past-a")
    }

    func testLiveCompletionUsesMostRecentUnsharedHostedSession() throws {
        let data = Data(#"""
        {
          "profiles":[],"friendships":[],
          "sessions":[
            {"id":"old","organizer":"owner","starts_at":"2030-11-01T10:00:00Z","status":"planned"},
            {"id":"completed","organizer":"owner","starts_at":"2030-11-03T11:59:00Z","status":"completed"},
            {"id":"cancelled","organizer":"owner","starts_at":"2030-11-03T11:58:00Z","status":"cancelled"},
            {"id":"friend","organizer":"friend","starts_at":"2030-11-03T11:57:00Z","status":"planned"},
            {"id":"next","organizer":"owner","starts_at":"2030-11-04T10:00:00Z","status":"planned"},
            {"id":"recent","organizer":"owner","starts_at":"2030-11-03T10:00:00Z","status":"planned"}
          ],
          "participants":[],
          "posts":[{"id":"unrelated","author":"owner","occurred_at":"2030-11-03T11:59:00Z","caption":"Another training"}],
          "tags":[],"likes":[],"comments":[],"credits":[],"media":[],"notifications":[]
        }
        """#.utf8)
        let model = SocialAppModel()
        model.userID = "owner"
        model.snapshot = try JSONDecoder().decode(SocialSnapshot.self, from: data)
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2030-11-03T12:00:00Z"))
        runtime.sync(now: now)
        XCTAssertEqual(ui.toComplete?.id, "recent")
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "recent", "A later post for another training must not hide this unshared session")
        model.snapshot.sessions.reverse()
        runtime.sync(now: now)
        XCTAssertEqual(ui.toComplete?.id, "recent")
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "recent")

        // Publishing or cancelling the closest session advances the prompt.
        let recentIndex = try XCTUnwrap(model.snapshot.sessions.firstIndex { $0.id == "recent" })
        model.snapshot.sessions[recentIndex].values["status"] = .string("completed")
        runtime.sync(now: now)
        XCTAssertTrue(ui.completedSessions.contains { $0.id == "recent" })
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "next")
        let nextIndex = try XCTUnwrap(model.snapshot.sessions.firstIndex { $0.id == "next" })
        model.snapshot.sessions[nextIndex].values["status"] = .string("cancelled")
        runtime.sync(now: now)
        XCTAssertEqual(ui.activityPrompt(at: now)?.id, "old")
    }

    func testEditingASessionsDateMovesItToItsChronologicalPosition() async throws {
        let ui = AppModel(live: false)
        let ticketIDs = ["s2", "s3", "s1"]
        ui.upcoming = ui.upcoming.filter { ticketIDs.contains($0.id) }
        // Preview tickets have labels only until they are edited.
        XCTAssertEqual(ui.plannedSessions.map(\.id), ticketIDs)
        // Give the label-only samples future starts so this checks ordering, not tab migration.
        let base = Date().addingTimeInterval(86400)
        for (index, id) in ticketIDs.enumerated() {
            let i = try XCTUnwrap(ui.upcoming.firstIndex { $0.id == id })
            ui.upcoming[i].startsAt = base.addingTimeInterval(Double(index) * 3600)
        }
        let first = try XCTUnwrap(ui.plannedSessions.first)
        let earlier = ui.startDate(of: first).addingTimeInterval(-3600)
        let edited = await ui.editSession("s1", title: "Earlier rolls", startsAt: earlier, gym: "Home gym", note: "")
        XCTAssertTrue(edited)
        XCTAssertEqual(ui.plannedSessions.map(\.id), ["s1", "s2", "s3"])
    }

    func testDidntTrainClearsTheSharePrompt() {
        let ui = AppModel(live: false)
        XCTAssertEqual(ui.readyToShare.map(\.id), ["c1"])
        ui.deleteSession("c1")
        XCTAssertTrue(ui.readyToShare.isEmpty, "Deleting a session you didn't train removes its \"How was …?\" card")
        XCTAssertNil(ui.findSession("c1"))
    }

    func testTrainingTabsUseExactStartWithoutRequiringAPhotoOrPost() {
        let ui = AppModel(live: true)
        let now = ISO8601DateFormatter().date(from: "2026-11-03T12:00:00Z")!
        func session(_ id: String, offset: TimeInterval, status: RSVP = .going) -> Session {
            Session(id: id, title: id, day: "Tue", date: 3, month: "Nov", time: "12:00 PM", gym: "Home gym",
                    organizer: "me", people: [Attendee(id: "me", status: status)], startsAt: now.addingTimeInterval(offset))
        }
        ui.upcoming = [session("old", offset: -86400), session("later", offset: 86400),
                       session("at-start", offset: 0), session("recent-b", offset: -60),
                       session("recent-a", offset: -60), session("invite", offset: 60, status: .invited),
                       session("declined", offset: -120, status: .declined)]
        ui.toComplete = ui.upcoming.first
        ui.completedSessions = [session("shared", offset: -3600)]
        XCTAssertTrue(ui.posts.isEmpty)
        XCTAssertEqual(ui.trainingSessions(past: false, relativeTo: now).map(\.id), ["invite", "later"])
        XCTAssertEqual(ui.trainingSessions(past: true, relativeTo: now).map(\.id),
                       ["at-start", "recent-a", "recent-b", "shared", "old"])
        XCTAssertEqual(ui.trainingSessions(past: true, relativeTo: now.addingTimeInterval(60)).first?.id, "invite")
        ui.clearLiveData()
        XCTAssertTrue(ui.trainingSessions(past: true, relativeTo: now).isEmpty)
    }

    func testEditingMovesTrainingBetweenTabsEvenWithAStaleCompletionPrompt() async throws {
        let ui = AppModel(live: false)
        let now = Date()
        let id = try XCTUnwrap(ui.upcoming.first { $0.organizer == "me" }?.id)
        let past = now.addingTimeInterval(-3600)
        let savedPast = await ui.editSession(id, title: "Past rolls", startsAt: past, gym: "Home gym", note: "")
        XCTAssertTrue(savedPast)
        ui.toComplete = ui.findSession(id)
        XCTAssertTrue(ui.trainingSessions(past: true, relativeTo: now).contains { $0.id == id })
        XCTAssertFalse(ui.trainingSessions(past: false, relativeTo: now).contains { $0.id == id })
        let savedFuture = await ui.editSession(id, title: "Future rolls", startsAt: now.addingTimeInterval(3600), gym: "Home gym", note: "")
        XCTAssertTrue(savedFuture)
        XCTAssertFalse(ui.trainingSessions(past: true, relativeTo: now).contains { $0.id == id })
        XCTAssertTrue(ui.trainingSessions(past: false, relativeTo: now).contains { $0.id == id })
    }

    @MainActor
    func testSessionPhotoIsRetainedBeforeAndAfterPublishing() async throws {
        let ui = AppModel(live: false)
        let session = try XCTUnwrap(ui.toComplete)
        let saved = await ui.saveSessionPhoto(session.id, photo: "training-photo")
        XCTAssertTrue(saved)
        XCTAssertEqual(ui.findSession(session.id)?.photos, ["training-photo"])
        XCTAssertFalse(ui.isCompleted(session), "Saving a photo does not publish or complete the session")
        let savedAgain = await ui.saveSessionPhoto(session.id, photo: "training-photo")
        XCTAssertTrue(savedAgain)
        XCTAssertEqual(ui.findSession(session.id)?.photos.count, 1)
        let result = try XCTUnwrap(ui.publish(session.id, photo: "training-photo", caption: "", people: ["me"]))
        XCTAssertEqual(result.post.photo, "training-photo")
        XCTAssertEqual(ui.findSession(session.id)?.photos, ["training-photo"])
        let guestSession = try XCTUnwrap(ui.upcoming.first { $0.organizer != "me" })
        let guestSave = await ui.saveSessionPhoto(guestSession.id, photo: "unauthorized-photo")
        XCTAssertFalse(guestSave)
        XCTAssertTrue(ui.findSession(guestSession.id)?.photos.isEmpty ?? false)
    }

    @MainActor
    func testSavedSessionPhotosLoadWithoutAnActivityPostAndSurviveRefresh() async throws {
        let model = SocialAppModel()
        model.userID = "owner"
        model.snapshot = try JSONDecoder().decode(SocialSnapshot.self, from: Data(#"""
        {"profiles":[],"friendships":[],
         "sessions":[{"id":"session","organizer":"owner","status":"planned"},
                     {"id":"other","organizer":"owner","status":"completed"}],
         "participants":[],"posts":[],"tags":[],"likes":[],"comments":[],"credits":[],"notifications":[],
         "media":[{"id":"older","session_id":"session","object_key":"owner/older.jpg","state":"ready","created_at":"2026-11-05T10:00:00Z"},
                  {"id":"newer","session_id":"session","object_key":"owner/newer.jpg","state":"ready","created_at":"2026-11-05T11:00:00Z"},
                  {"id":"other-photo","session_id":"other","object_key":"owner/other.jpg","state":"ready"}]}
        """#.utf8))
        let ui = AppModel(live: true)
        var requested: [String] = []
        let runtime = LiveMatMindRuntime(model: model, ui: ui) { key, bucket in
            requested.append(bucket + ":" + key)
            return Data(key.utf8)
        }
        await runtime.loadPhotos()
        let sources = try XCTUnwrap(ui.findSession("session")?.photos)
        XCTAssertEqual(try sources.map { try String(contentsOfFile: $0, encoding: .utf8) }, ["owner/newer.jpg", "owner/older.jpg"])
        XCTAssertEqual(ui.findSession("other")?.photos.count, 1)
        XCTAssertTrue(ui.posts.isEmpty)
        XCTAssertFalse(ui.isCompleted(try XCTUnwrap(ui.findSession("session"))))
        model.snapshot.media.reverse()
        await runtime.loadPhotos()
        XCTAssertEqual(ui.findSession("session")?.photos, sources)
        XCTAssertEqual(requested.count, 3, "A refresh reuses the existing downloaded photos")
        model.userID = nil
        runtime.sync()
        XCTAssertTrue(sources.allSatisfy { !FileManager.default.fileExists(atPath: $0) })
        XCTAssertNil(ui.findSession("session"))
    }

    func testUnsharedPastDraftRemainsInTrainingAfterPublishingWithoutAPhoto() throws {
        let ui = AppModel(live: false)
        let draft = SessionDraft(title: "Yesterday's rounds", day: "Mon", date: 2, month: "Nov", time: "6:00 PM",
                                 gym: "Home gym", note: "", invited: [], privacy: .friends, past: true,
                                 startsAt: Date().addingTimeInterval(-86400))
        ui.createSession(draft)
        let session = try XCTUnwrap(ui.drafts.last)
        XCTAssertTrue(ui.trainingSessions(past: true).contains { $0.id == session.id })
        XCTAssertNotNil(ui.findSession(session.id))
        let result = ui.publish(session.id, photo: nil, caption: "Great rounds", people: ["me"])
        XCTAssertNotNil(result)
        XCTAssertEqual(ui.trainingSessions(past: true).filter { $0.id == session.id }.count, 1)
        XCTAssertTrue(ui.isCompleted(session))
        XCTAssertNotNil(ui.findSession(session.id))
    }

    func testSuggestedSessionNameFollowsTheStartTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        // Tue, Nov 3 2026.
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 7)))
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 18, minute: 30)))
        let saturday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 7)))
        XCTAssertEqual(SessionDraft.suggestedTitle(for: morning), "Morning rolls")
        XCTAssertEqual(SessionDraft.suggestedTitle(for: evening), "Evening rolls")
        XCTAssertEqual(SessionDraft.suggestedTitle(for: saturday), "Saturday open mat")
        XCTAssertTrue(SessionDraft.isSuggestedTitle("Morning rolls"))
        XCTAssertFalse(SessionDraft.isSuggestedTitle("Comp prep"), "A name the host chose must not be replaced")
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

    func testGoalsSavedBeforePartsStillDecode() throws {
        let json = #"{"id":"old","title":"Single leg","position":"","notes":"Head inside","links":[],"photos":[]}"#
        let goal = try JSONDecoder().decode(MatGoal.self, from: Data(json.utf8))
        XCTAssertEqual(goal.title, "Single leg")
        XCTAssertEqual(goal.notes, "Head inside")
        XCTAssertTrue(goal.parts.isEmpty)

        var withParts = goal
        withParts.parts = [GoalPart(id: "p1", title: "Grip", notes: "Behind the knee", link: "https://youtu.be/abc", photos: ["x.jpg"])]
        let roundTrip = try JSONDecoder().decode(MatGoal.self, from: JSONEncoder().encode(withParts))
        XCTAssertEqual(roundTrip, withParts)
    }

    func testGoalPartSummaryAndVideoStartTimes() {
        XCTAssertEqual(GoalPart.summary(notes: "- Cup the knee\n\n- Pull it tight", hasLink: true, photoCount: 2), "2 notes · 1 video · 2 photos")
        XCTAssertEqual(GoalPart.summary(notes: "", hasLink: false, photoCount: 1), "1 photo")
        XCTAssertEqual(GoalPart.summary(notes: "  ", hasLink: false, photoCount: 0), "Nothing added yet")

        XCTAssertEqual(GoalPart.linkStart("https://youtu.be/abc?t=102"), "1:42")
        XCTAssertEqual(GoalPart.linkStart("https://www.youtube.com/watch?v=abc&t=1m42s"), "1:42")
        XCTAssertEqual(GoalPart.linkStart("https://www.youtube.com/embed/abc?start=3725"), "1:02:05")
        XCTAssertNil(GoalPart.linkStart("https://www.youtube.com/watch?v=abc"))
        XCTAssertNil(GoalPart.linkStart("https://youtu.be/abc?t=soon"))
        XCTAssertEqual(GoalPart.linkTitle("https://youtu.be/abc"), "YouTube video")
        XCTAssertEqual(GoalPart.linkTitle("https://www.bjjfanatics.com/x"), "bjjfanatics.com")
    }

    func testGoalPartsSavePhotosAndDropEmptyParts() throws {
        let ui = AppModel(live: false)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let data = try XCTUnwrap(image.pngData())

        var goal = MatGoal.new()
        goal.title = "Single leg from standing"
        var grip = GoalPartDraft(id: "grip")
        grip.title = "  Grip on the near leg "
        grip.link = "youtu.be/abc?t=102"
        grip.photos = [GoalPhotoDraft(data: data, preview: image), GoalPhotoDraft(data: data, preview: image)]
        var notesOnly = GoalPartDraft(id: "head")
        notesOnly.notes = "Head inside"
        let blank = GoalPartDraft(id: "blank")
        XCTAssertTrue(ui.saveGoal(goal, parts: [grip, notesOnly, blank]))

        let saved = try XCTUnwrap(ui.goal(goal.id))
        XCTAssertEqual(saved.parts.map(\.id), ["grip", "head"], "Parts with nothing in them are dropped")
        XCTAssertEqual(saved.parts[0].title, "Grip on the near leg")
        XCTAssertEqual(saved.parts[0].link, "https://youtu.be/abc?t=102")
        XCTAssertEqual(saved.parts[0].photos.count, 2)
        let files = saved.parts[0].photos.map { MatGoal.photoRoot.appendingPathComponent($0) }
        XCTAssertTrue(files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })

        // Remove one photo and the whole second part.
        var edited = GoalPartDraft(saved.parts[0])
        edited.photos.removeLast()
        XCTAssertTrue(ui.saveGoal(saved, parts: [edited]))
        XCTAssertEqual(ui.goal(goal.id)?.parts.count, 1)
        XCTAssertEqual(ui.goal(goal.id)?.parts.first?.photos.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: files[0].path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: files[1].path), "A removed photo loses its file")

        XCTAssertFalse(ui.saveGoal(MatGoal(id: "blank-goal", title: " "), parts: [grip]), "A goal still needs a name")
        ui.deleteGoal(goal.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: files[0].path), "Deleting a goal deletes its part photos")
    }

    @MainActor
    func testFocusCanBeAddedEditedAndClearedAfterCompletion() throws {
        let ui = AppModel(live: false)
        var session = try XCTUnwrap(ui.findSession("s1"))
        session.focusItems = []
        ui.upcoming.removeAll { $0.id == session.id }
        ui.completedSessions = [session]
        let focus = [TrainingFocus(title: "  Mount attacks ", children: [TrainingFocus(title: " Armbar ")])]

        XCTAssertTrue(ui.updateSessionFocus(session.id, focus))
        let saved = try XCTUnwrap(ui.findSession(session.id))
        XCTAssertTrue(ui.isCompleted(saved))
        XCTAssertEqual(saved.focusItems.first?.title, "Mount attacks")
        XCTAssertEqual(saved.focusItems.first?.children.first?.title, "Armbar")
        XCTAssertEqual(saved.people, session.people)
        XCTAssertEqual(saved.note, session.note)
        XCTAssertEqual(saved.startsAt, session.startsAt)
        XCTAssertFalse(ui.updateSessionFocus(session.id, [TrainingFocus()]))
        XCTAssertEqual(ui.findSession(session.id), saved)

        XCTAssertTrue(ui.updateSessionFocus(session.id, [TrainingFocus(title: "Escapes")]))
        XCTAssertEqual(ui.findSession(session.id)?.focusItems.first?.title, "Escapes")
        XCTAssertTrue(ui.updateSessionFocus(session.id, []))
        XCTAssertEqual(ui.findSession(session.id)?.focusItems, [])
        XCTAssertTrue(ui.isCompleted(try XCTUnwrap(ui.findSession(session.id))))

        session.organizer = "sarah"
        ui.completedSessions = [session]
        XCTAssertFalse(ui.updateSessionFocus(session.id, focus), "Guests cannot edit another organizer's focus")
        XCTAssertEqual(ui.findSession(session.id), session)
    }

    func testSessionEditSavesFocusAndGuestChangesWithoutResettingRSVPs() async throws {
        let ui = AppModel(live: false)
        let original = try XCTUnwrap(ui.findSession("s1"))
        let start = Date().addingTimeInterval(86400)
        let focus = [TrainingFocus(title: "  Mount attacks ", children: [TrainingFocus(title: " Armbar ")])]
        let guests: Set<String> = ["sarah", "kenji", "lena", "priya"]

        let edited = await ui.editSession("s1", title: original.title, startsAt: start, gym: original.gym,
                                          note: "Bring a gi", focusItems: focus, guestIDs: guests)
        XCTAssertTrue(edited)
        let saved = try XCTUnwrap(ui.findSession("s1"))
        XCTAssertEqual(saved.focusItems.first?.title, "Mount attacks")
        XCTAssertEqual(saved.focusItems.first?.children.first?.title, "Armbar")
        XCTAssertEqual(saved.note, "Bring a gi")
        XCTAssertNil(saved.status(of: "alex"))
        XCTAssertEqual(saved.status(of: "priya"), .invited)
        XCTAssertEqual(saved.status(of: "me"), .going, "The organizer stays even though guests excludes them")
        for id in ["sarah", "kenji", "lena"] {
            XCTAssertEqual(saved.status(of: id), original.status(of: id), "Retained guests keep their RSVP")
        }

        let invalid = await ui.editSession("s1", title: "Unsaved name", startsAt: start, gym: original.gym,
                                           note: "Unsaved note", focusItems: [TrainingFocus()], guestIDs: [])
        XCTAssertFalse(invalid)
        XCTAssertEqual(ui.findSession("s1"), saved, "Invalid focus prevents every change")
        let stranger = await ui.editSession("s1", title: "Unsaved name", startsAt: start, gym: original.gym,
                                            note: "", focusItems: [], guestIDs: ["stranger"])
        XCTAssertFalse(stranger)
        XCTAssertEqual(ui.findSession("s1"), saved)

        let cleared = await ui.editSession("s1", title: saved.title, startsAt: start, gym: saved.gym,
                                           note: "", focusItems: [], guestIDs: [])
        XCTAssertTrue(cleared)
        XCTAssertEqual(ui.findSession("s1")?.focusItems, [])
        XCTAssertEqual(ui.findSession("s1")?.people.map(\.id), ["me"])
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
          "posts":[{"id":"post","author":"owner","title":"Rounds","venue":"Home gym","occurred_at":"2026-09-28T10:00:00Z","caption":"Good rounds"}],
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

    func testInlineNamesLinkEachMemberEvenWhenTheirNamesMatch() throws {
        let ui = AppModel(live: false)
        var first = ui.person("sarah")
        var second = ui.person("alex")
        first.name = "Alex Lee"
        second.name = "Alex Lee"
        let people = [first, second, ui.person("kenji")]
        let runs = PersonText.names(people, size: 14)
        XCTAssertEqual(runs.map(\.text).joined(), "Alex, Alex +1")
        let ids = runs.compactMap(\.link).compactMap { PersonProfileLink.personID(from: $0) }
        XCTAssertEqual(ids, ["sarah", "alex"])
        XCTAssertNil(runs.last?.link, "The remaining-person count is not somebody's name")
        for id in ids {
            ui.openPerson(id)
            XCTAssertEqual(ui.path.last, .person(id: id))
        }
        XCTAssertEqual(PersonText.names([], size: 14).count, 0)
        XCTAssertEqual(PersonText.names([ui.me, first], size: 14).map(\.text).joined(), "You & Alex")
    }

    func testProfileLinksPreserveIDsAndRejectUnrelatedURLs() throws {
        for id in ["me", "sarah", "00000000-0000-0000-0000-000000000301", "member / +?&#é"] {
            let url = try XCTUnwrap(PersonProfileLink.url(for: id))
            XCTAssertEqual(PersonProfileLink.personID(from: url), id)
        }
        XCTAssertNil(PersonProfileLink.url(for: ""))
        for value in ["https://example.com/?id=sarah", "matmonkeys-person://other?id=sarah",
                      "matmonkeys-person://profile?id=", "matmonkeys-person://profile?id=sarah&id=alex"] {
            XCTAssertNil(PersonProfileLink.personID(from: try XCTUnwrap(URL(string: value))))
        }
        let ui = AppModel(live: false)
        ui.go(.post(id: "p1"))
        ui.openPerson(try XCTUnwrap(PersonProfileLink.personID(from: try XCTUnwrap(PersonProfileLink.url(for: "me")))))
        XCTAssertEqual(ui.tab, .profile)
        XCTAssertTrue(ui.path.isEmpty)
    }

    func testPeopleSearchStaysInYourCircleAndFollowingToggles() {
        let ui = AppModel(live: false)
        // Suggested: people who share a partner, most shared partners first; never your partners.
        XCTAssertEqual(ui.suggestedPeople.first?.id, "rafa")
        XCTAssertEqual(ui.mutualPartners("rafa").count, 4)
        XCTAssertFalse(ui.suggestedPeople.contains { ui.friendship($0.id) != nil })
        let counts = ui.suggestedPeople.map { ui.mutualPartners($0.id).count }
        XCTAssertEqual(counts, counts.sorted(by: >))
        // Search: word starts and usernames, partners first, nobody outside the circle.
        XCTAssertEqual(ui.searchPeople("ma").map(\.id), ["marco", "maya", "mariana"])
        XCTAssertEqual(ui.searchPeople("@rafam").map(\.id), ["rafa"])
        XCTAssertEqual(ui.searchPeople("Mendes").map(\.id), ["rafa"])
        XCTAssertTrue(ui.searchPeople("lena").isEmpty, "Lena isn't a partner and shares none with you")
        XCTAssertTrue(ui.searchPeople("  ").isEmpty)
        // Following needs no approval and can be undone.
        XCTAssertFalse(ui.isFollowing("rafa"))
        ui.setFollowing("rafa", true)
        XCTAssertTrue(ui.isFollowing("rafa"))
        ui.setFollowing("rafa", false)
        XCTAssertFalse(ui.isFollowing("rafa"))
        // Everyone, training partners included, opens the same profile page.
        ui.openPerson("sarah")
        XCTAssertEqual(ui.path.last, .person(id: "sarah"))
        ui.openPerson("rafa")
        XCTAssertEqual(ui.path.last, .person(id: "rafa"))
    }

    func testPartnerListsPutYourPartnersFirst() async {
        let ui = AppModel(live: false)
        await ui.loadPartners(of: "rafa")
        let list = ui.partnerLists["rafa"] ?? []
        XCTAssertEqual(list.count, 9)
        XCTAssertEqual(Array(list.prefix(4)), ["alex", "kenji", "priya", "sarah"])
        XCTAssertEqual(ui.person("owen").name, "Owen Brooks")
        XCTAssertTrue(ui.canFollow("owen"), "anyone on a partner list you can see can be followed")
        XCTAssertTrue(ui.canFollow("sarah"))
        XCTAssertFalse(ui.canFollow("lena"), "not your partner, not in your circle, on no list you've opened")
        XCTAssertFalse(ui.canFollow("me"))
        XCTAssertTrue(ui.searchPeople("owen").isEmpty, "a partner list doesn't widen search")
    }

    func testUsernameLookupFindsPeopleOutsideCircleAndFollowsLikeScanning() async throws {
        let ui = AppModel(live: false)
        XCTAssertTrue(ui.searchPeople("lena").isEmpty)
        XCTAssertFalse(ui.canFollow("lena"))
        let matches = try await ui.searchUsernames("  @LENA  ")
        XCTAssertEqual(matches.map(\.id), ["lena"])
        XCTAssertTrue(ui.canFollow("lena"))
        XCTAssertTrue(ui.searchPeople("lena").isEmpty, "Looking up a username doesn't add it to circle name search")
        ui.setFollowing("lena", true)
        XCTAssertTrue(ui.isFollowing("lena"))
        XCTAssertTrue(ui.canInvite("lena"))
        XCTAssertNotNil(ui.friendship("lena"), "Username follow uses the same connection path as scanning")
        ui.setFollowing("lena", false)
        XCTAssertFalse(ui.canInvite("lena"))
        ui.clearLiveData()
        XCTAssertTrue(ui.usernamePeople.isEmpty)
        XCTAssertFalse(ui.canFollow("lena"))
    }

    func testUsernameQueriesRequireLiteralValidPrefixes() async throws {
        XCTAssertEqual(AppModel.usernameQuery("  @RaFaM  "), "rafam")
        for query in ["", " ", "@", "@@lena", "le", "len%", "len a", "lén", String(repeating: "a", count: 41)] {
            XCTAssertFalse(AppModel.canSearchUsername(query), query)
        }
        XCTAssertTrue(AppModel.canSearchUsername("@len_a1"))
        let ui = AppModel(live: false)
        let found = try await ui.searchUsernames("le")
        XCTAssertTrue(found.isEmpty)
        XCTAssertTrue(ui.usernamePeople.isEmpty)
        let task = Task { try await ui.searchUsernames("lena") }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled lookups must not cache stale results") }
        catch is CancellationError { }
        XCTAssertTrue(ui.usernamePeople.isEmpty)
    }

    func testLiveSnapshotMapsCircleAndFollows() throws {
        let data = Data(#"""
        {
          "profiles":[{"id":"owner","name":"Dani"},{"id":"sarah","name":"Sarah Lee"},{"id":"rafa","name":"Rafa Mendes"}],
          "friendships":[{"id":"f1","a":"owner","b":"sarah","active":true,"timezone":"UTC"}],
          "circle":[{"id":"rafa","mutual":["sarah"]}],
          "follows":[{"follower":"owner","followee":"rafa"}],
          "sessions":[],"participants":[],"posts":[],"tags":[],"likes":[],"comments":[],"credits":[],"media":[],"notifications":[]
        }
        """#.utf8)
        let model = SocialAppModel()
        model.userID = "owner"
        model.snapshot = try JSONDecoder().decode(SocialSnapshot.self, from: data)
        let ui = AppModel(live: true)
        LiveMatMindRuntime(model: model, ui: ui).sync()
        XCTAssertEqual(ui.circle, [CirclePerson(id: "rafa", mutual: ["sarah"])])
        XCTAssertEqual(ui.suggestedPeople.map(\.id), ["rafa"])
        XCTAssertTrue(ui.isFollowing("rafa"))
        XCTAssertTrue(ui.isFollowing("sarah"), "QR partners follow each other even with older caches")
        XCTAssertTrue(ui.canInvite("sarah"))
        // Caches saved before following existed still decode.
        let old = try JSONDecoder().decode(SocialSnapshot.self, from: Data(#"{"profiles":[],"friendships":[],"sessions":[],"participants":[],"posts":[],"tags":[],"likes":[],"comments":[],"credits":[],"media":[],"notifications":[]}"#.utf8))
        XCTAssertNil(old.circle)
        XCTAssertNil(old.follows)
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

    func testGoalReferenceRecognizesPartsWithoutLegacyDetails() {
        var goal = MatGoal(id: "goal", title: "Passing open guard")
        XCTAssertFalse(goal.hasReferenceContent)
        goal.parts = [GoalPart(title: "Keep them on their back", notes: "Control the hips")]
        XCTAssertTrue(goal.hasReferenceContent)
        XCTAssertTrue(goal.notes.isEmpty)
        goal.parts = [GoalPart()]
        XCTAssertFalse(goal.hasReferenceContent)
        goal.parts = [GoalPart(link: "https://youtu.be/example")]
        XCTAssertTrue(goal.hasReferenceContent)
        goal.parts = [GoalPart(photos: ["reference.jpg"])]
        XCTAssertTrue(goal.hasReferenceContent)
    }

    func testGoalFocusReferenceSurvivesSessionSaveAndRenames() throws {
        let focus = TrainingFocus(title: "Passing open guard", goalID: "goal")
        let encoded = SessionNoteCodec.encode(note: "Bring a gi", focus: [focus])
        let decoded = SessionNoteCodec.decode(encoded)
        XCTAssertEqual(decoded.note, "Bring a gi")
        var restored = try XCTUnwrap(decoded.focus.first)
        XCTAssertEqual(restored.goalID, "goal")
        restored.title = "Today's passing focus"
        let goal = MatGoal(id: "goal", title: "Renamed goal", parts: [GoalPart(notes: "New saved note")])
        XCTAssertEqual(restored.linkedGoal(in: [goal]), goal)
        XCTAssertEqual(restored.linkedGoal(in: [goal])?.parts.first?.notes, "New saved note")
        XCTAssertNil(restored.linkedGoal(in: [MatGoal(id: "other", title: restored.title)]),
                     "A deleted goal must not be replaced by a different goal with the same name")
        let raw = try XCTUnwrap(Data(base64Encoded: String(encoded.dropFirst("matmind-focus-v1:".count))))
        XCTAssertFalse(String(decoding: raw, as: UTF8.self).contains("New saved note"))
    }

    func testOlderFocusFindsOnlyAnUnambiguousGoalByName() throws {
        let data = Data(#"{"id":"00000000-0000-0000-0000-000000000001","title":" Passing open guard ","children":[]}"#.utf8)
        let focus = try JSONDecoder().decode(TrainingFocus.self, from: data)
        XCTAssertNil(focus.goalID)
        let goal = MatGoal(id: "goal", title: "passing OPEN guard")
        XCTAssertEqual(focus.linkedGoal(in: [goal]), goal)
        XCTAssertNil(focus.linkedGoal(in: [goal, MatGoal(id: "duplicate", title: goal.title)]))
        XCTAssertNil(focus.linkedGoal(in: []))
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

final class SessionDaySelectionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testThursdayNovemberFifthShowsWednesdayFourthAsYesterday() {
        let selection = SessionDaySelection(now: date("2026-11-05T21:42:00Z"), calendar: calendar)
        let past = selection.days(past: true)
        XCTAssertEqual(past.map(\.date), [4, 3, 2, 1, 31])
        XCTAssertEqual(past.map(\.weekday), ["Wed", "Tue", "Mon", "Sun", "Sat"])
        XCTAssertEqual(past.map(\.label), ["Yesterday", "Tue", "Mon", "Sun", "Sat"])
        XCTAssertEqual(past.map(\.month), ["Nov", "Nov", "Nov", "Nov", "Oct"])
        let upcoming = selection.days(past: false)
        XCTAssertEqual(upcoming.map(\.date), [5, 6, 7, 8, 9, 10, 11])
        XCTAssertEqual(upcoming.first?.weekday, "Thu")
        XCTAssertEqual(upcoming.first?.label, "Today")
    }

    func testLocalDayDoesNotAdvanceAtUTCMidnight() {
        let selection = SessionDaySelection(now: date("2026-11-06T02:00:00Z"), calendar: calendar)
        XCTAssertEqual(selection.days(past: false).first?.date, 5)
        XCTAssertEqual(selection.days(past: true).first?.date, 4)
    }

    func testRefreshAfterMidnightKeepsSelectedCivilDates() {
        var selection = SessionDaySelection(now: date("2026-11-04T21:42:00Z"), calendar: calendar)
        selection.pastDayIndex = 1 // Monday, November 2.
        selection.selectedDays = [0, 2] // November 4 and 6.
        XCTAssertTrue(selection.refresh(now: date("2026-11-05T21:42:00Z"), calendar: calendar))
        XCTAssertEqual(selection.days(past: true).first?.date, 4)
        XCTAssertEqual(selection.pastDayIndex, 2)
        XCTAssertEqual(selection.days(past: true)[selection.pastDayIndex].date, 2)
        XCTAssertEqual(selection.selectedDays, [1], "Expired dates leave the selection; November 6 stays selected")
        XCTAssertEqual(selection.days(past: false)[1].date, 6)
    }

    func testRefreshAfterSeveralDaysDropsExpiredSelections() {
        var selection = SessionDaySelection(now: date("2026-11-01T20:00:00Z"), calendar: calendar)
        selection.pastDayIndex = 4
        selection.selectedDays = [0, 1]
        XCTAssertTrue(selection.refresh(now: date("2026-11-05T20:00:00Z"), calendar: calendar))
        XCTAssertEqual(selection.pastDayIndex, 0)
        XCTAssertTrue(selection.selectedDays.isEmpty)
        XCTAssertEqual(selection.days(past: true).first?.date, 4)
    }

    func testRefreshInSameLocalDayKeepsSelections() {
        var selection = SessionDaySelection(now: date("2026-11-05T09:00:00Z"), calendar: calendar)
        selection.pastDayIndex = 2
        selection.selectedDays = [1, 3]
        XCTAssertFalse(selection.refresh(now: date("2026-11-06T02:00:00Z"), calendar: calendar))
        XCTAssertEqual(selection.pastDayIndex, 2)
        XCTAssertEqual(selection.selectedDays, [1, 3])
    }

    func testTimezoneRefreshKeepsSelectedCalendarDates() {
        let now = date("2026-11-06T02:00:00Z")
        var selection = SessionDaySelection(now: now, calendar: calendar)
        selection.selectedDays = [1, 2] // November 6 and 7 in Los Angeles.
        var destination = calendar
        destination.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!
        XCTAssertTrue(selection.refresh(now: now, calendar: destination))
        XCTAssertEqual(selection.days(past: false).first?.date, 6)
        XCTAssertEqual(selection.selectedDays, [0, 1])
        XCTAssertEqual(selection.calendar.timeZone, destination.timeZone)
    }

    func testCalendarDaysCrossFallBackAndYearBoundary() {
        let fallBack = SessionDaySelection(now: date("2026-11-02T08:30:00Z"), calendar: calendar)
        let yesterday = fallBack.days(past: true)[0]
        XCTAssertEqual(yesterday.date, 1)
        XCTAssertEqual(yesterday.weekday, "Sun")
        XCTAssertEqual(fallBack.today.timeIntervalSince(yesterday.value), 25 * 60 * 60)
        let newYear = SessionDaySelection(now: date("2027-01-01T20:00:00Z"), calendar: calendar)
        XCTAssertEqual(newYear.days(past: true).first?.date, 31)
        XCTAssertEqual(newYear.days(past: true).first?.month, "Dec")
        XCTAssertEqual(newYear.days(past: false).first?.month, "Jan")
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

    func testMultipleTimesKeepSameDayOccurrencesAndDeduplicateMinutes() throws {
        let original = draft(title: "Partner drills")
        let first = date("2026-11-05T00:30:00Z")
        let second = date("2026-11-05T02:00:00Z")
        let nextDay = date("2026-11-06T00:30:00Z")
        let scheduled = original.scheduled(at: [nextDay, second, first.addingTimeInterval(25), first], calendar: calendar)
        XCTAssertEqual(scheduled.compactMap(\.startsAt), [first, second, nextDay])
        XCTAssertEqual(scheduled.map(\.time), ["4:30 PM", "6:00 PM", "4:30 PM"])
        XCTAssertEqual(scheduled.map(\.date), [4, 4, 5])
        for occurrence in scheduled {
            XCTAssertEqual(occurrence.title, original.title)
            XCTAssertEqual(occurrence.gym, original.gym)
            XCTAssertEqual(occurrence.note, original.note)
            XCTAssertEqual(occurrence.invited, original.invited)
            XCTAssertEqual(occurrence.focusItems, original.focusItems)
            XCTAssertEqual(occurrence.privacy, original.privacy)
            XCTAssertEqual(occurrence.timezone, "America/Los_Angeles")
        }
        XCTAssertTrue(original.scheduled(at: [], calendar: calendar).isEmpty)
    }

    func testAdditionalTimesUpdateSuggestedTitlesAndPreserveDSTInstants() {
        let scheduled = draft(title: "Morning rolls").scheduled(at: [date("2026-11-06T17:00:00Z"), date("2026-11-07T02:00:00Z")], calendar: calendar)
        XCTAssertEqual(scheduled.map(\.title), ["Morning rolls", "Evening rolls"])
        // Both occurrences of 1:30 AM on the fall-back day represent distinct instants.
        let starts = [date("2026-11-01T08:30:00Z"), date("2026-11-01T09:30:00Z")]
        XCTAssertEqual(draft().scheduled(at: starts, calendar: calendar).compactMap(\.startsAt), starts)
    }

    @MainActor
    func testAdditionalSessionCreationKeepsTheEditorRouteAndPendingGoal() async throws {
        let ui = AppModel(live: false)
        let original = try XCTUnwrap(ui.findSession("s1"))
        let start = Date().addingTimeInterval(86400)
        let updated = await ui.editSession(original.id, title: "Partner drills", startsAt: start,
                                           gym: "Home gym", note: "Bring a gi")
        XCTAssertTrue(updated)
        let savedOriginal = ui.findSession(original.id)
        ui.go(.session(id: original.id))
        ui.pendingPlanGoal = "g2"
        let route = ui.path
        let tab = ui.tab
        let before = ui.upcoming.count
        let requests = draft(title: "Partner drills").scheduled(at: [start.addingTimeInterval(3600)], calendar: calendar)
            .map { SessionCreationRequest(draft: $0) }
        let created = await ui.createSessions(requests, presentingResult: false)
        XCTAssertTrue(created)
        XCTAssertEqual(ui.path, route)
        XCTAssertEqual(ui.tab, tab)
        XCTAssertEqual(ui.pendingPlanGoal, "g2", "Editing must not consume a different planning flow's goal")
        XCTAssertEqual(ui.findSession(original.id), savedOriginal, "Original RSVPs remain unchanged")
        XCTAssertEqual(ui.upcoming.count, before + 1)
        let retry = await ui.createSessions(requests, presentingResult: false)
        XCTAssertTrue(retry)
        XCTAssertEqual(ui.upcoming.count, before + 1, "Retry skips saved occurrences")
        XCTAssertEqual(ui.path, route)
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

    func testDefaultTitleIsTheSameForEverySelectedDay() {
        let scheduled = draft(time: "10:00 AM").scheduled(on: [date("2026-11-06T20:00:00Z"), date("2026-11-07T20:00:00Z"), date("2026-11-08T20:00:00Z")], calendar: calendar)
        XCTAssertEqual(scheduled.map(\.title), Array(repeating: "Jiu-Jitsu training", count: 3))
    }

    func testPrefilledTitleSurvivesDateAndTimeChanges() {
        let original = draft(title: SessionDraft.defaultTitle)
        let scheduled = original.scheduled(at: [date("2026-11-06T17:00:00Z"), date("2026-11-08T02:00:00Z")], calendar: calendar)
        XCTAssertEqual(scheduled.map(\.title), ["Jiu-Jitsu training", "Jiu-Jitsu training"])
    }

    func testClearedTitleCanStillLogAPastSession() throws {
        var original = draft(title: " \n ")
        original.past = true
        let scheduled = original.scheduled(on: [date("2026-11-01T20:00:00Z")], calendar: calendar)
        let session = try XCTUnwrap(scheduled.first)
        XCTAssertEqual(session.title, "Jiu-Jitsu training")
        XCTAssertTrue(session.past)
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

    @MainActor
    func testLiveFriendCodeAndScansSurviveInvitationHostChanges() async throws {
        let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data())
        let fresh = CloudCredential(access_token: "fresh-token", refresh_token: "refresh", user: CloudUser(id: "owner"))
        let (client, _) = try makeClient(credential: fresh, fixture: fixture)
        let model = SocialAppModel(backend: client)
        model.userID = "owner"
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        ui.runtime = runtime
        let token = String(repeating: "a1", count: 32)
        let generatedCode = await runtime.friendCode()
        let code = try XCTUnwrap(generatedCode)
        XCTAssertEqual(code, "matmind://friend/" + token)
        for value in [code, "https://matmindbjj.lovable.app/friend/" + token,
                      " \nhttps://matmonkey.lovable.app/friend/" + token + "\n "] {
            let friendID = await runtime.connect(value)
            XCTAssertEqual(friendID, "partner")
            XCTAssertNil(model.error)
            XCTAssertNil(model.pendingLink)
        }
        let requests = await fixture.requests
        let redemptions = try requests.filter { $0.url?.path == "/rest/v1/rpc/command" }.compactMap { request -> [String: Any]? in
            let command = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
            return command?["operation"] as? String == "redeem_friend" ? command : nil
        }
        XCTAssertEqual(redemptions.count, 3)
        for command in redemptions {
            XCTAssertEqual((command["payload"] as? [String: String])?["token"], token)
        }
    }

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

    func testDeadRefreshTokenEndsTheSessionWithAClearMessage() async throws {
        // Supabase Auth's reply when a refresh token was revoked or already rotated.
        let dead = Data(#"{"code":400,"error_code":"refresh_token_not_found","msg":"Invalid Refresh Token: Refresh Token Not Found"}"#.utf8)
        let expired = CloudCredential(access_token: "old-token", refresh_token: "old-refresh", user: CloudUser(id: "owner"), expires_at: 1)
        let fixture = BackendHTTPFixture(failureStatus: 400, failureBody: expiryError, refreshStatus: 400, refreshBody: dead)
        let (client, store) = try makeClient(credential: expired, fixture: fixture)
        do {
            _ = try await client.command("save_profile", payload: ["name": "Alex"])
            XCTFail("A dead refresh token should stop the command")
        } catch let error as CloudError {
            XCTAssertTrue(error.sessionExpired)
            XCTAssertEqual(error.message, "Your sign-in expired. Sign in again to keep going.")
        }
        let identity = await client.identity()
        XCTAssertNil(identity, "The dead session is dropped instead of being retried on every request")
        XCTAssertNil(store.read())
        let requests = await fixture.requests
        XCTAssertEqual(requests.map { $0.url?.path }, ["/auth/v1/token"], "The command itself is never sent")
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
    func testAdditionalTimesRetryAfterLostResponseWithoutLeavingEditor() async throws {
        let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data(), loseCreateResponseAt: 2)
        let fresh = CloudCredential(access_token: "fresh-token", refresh_token: "refresh", user: CloudUser(id: "owner"))
        let (client, _) = try makeClient(credential: fresh, fixture: fixture)
        let model = SocialAppModel(backend: client)
        model.userID = "owner"
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        ui.runtime = runtime
        runtime.sync()
        ui.go(.session(id: "existing"))
        let route = ui.path
        let requests = creationRequests()
        let first = await ui.createSessions(requests, presentingResult: false)
        XCTAssertFalse(first)
        XCTAssertEqual(ui.createdCount(for: requests), 1)
        XCTAssertEqual(ui.path, route)
        let retry = await ui.createSessions(requests, presentingResult: false)
        XCTAssertTrue(retry)
        XCTAssertEqual(ui.createdCount(for: requests), 3)
        let saved = await fixture.createdSessionCount
        XCTAssertEqual(saved, 3, "A committed occurrence with a lost response must not be duplicated")
        XCTAssertEqual(ui.path, route)
        XCTAssertFalse(ui.busy)
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

    @MainActor
    func testUsernameLookupUsesRPCAndFailedFollowRestoresButton() async throws {
        let rows = try JSONDecoder().decode([SocialRow].self, from: Data(#"[{"id":"stranger","name":"Lena Park","username":"lena_park","belt":"white","stripes":1,"gym":"Home gym"}]"#.utf8))
        let fixture = BackendHTTPFixture(failureStatus: 403, failureBody: Data(), usernameRows: rows, followUsernameStatus: 409)
        let credential = CloudCredential(access_token: "fresh-token", refresh_token: "refresh", user: CloudUser(id: "owner"))
        let (client, _) = try makeClient(credential: credential, fixture: fixture)
        let model = SocialAppModel(backend: client)
        model.userID = "owner"
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        ui.runtime = runtime
        runtime.sync()
        let found = try await ui.searchUsernames(" @LENA_ ")
        XCTAssertEqual(found.map(\.id), ["stranger"])
        XCTAssertTrue(ui.canFollow("stranger"))
        runtime.sync()
        XCTAssertEqual(ui.person("stranger").username, "lena_park", "A snapshot refresh retains lookup profile details")
        ui.setFollowing("stranger", true)
        ui.setFollowing("stranger", false)
        XCTAssertTrue(ui.isFollowing("stranger"), "A second tap is ignored while saving")
        let deadline = Date().addingTimeInterval(5)
        while ui.pendingFollows.contains("stranger"), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(ui.pendingFollows.isEmpty)
        XCTAssertFalse(ui.isFollowing("stranger"), "Rejected follows restore the prior state")
        let requests = await fixture.requests
        let lookup = try XCTUnwrap(requests.first { $0.url?.path == "/rest/v1/rpc/search_usernames" })
        let searchBody = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(lookup.httpBody)) as? [String: String])
        XCTAssertEqual(searchBody, ["query": "lena_"])
        let commands = requests.filter { $0.url?.path == "/rest/v1/rpc/command" }
        XCTAssertEqual(commands.count, 1)
        let command = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(commands.first?.httpBody)) as? [String: Any])
        XCTAssertEqual(command["operation"] as? String, "follow_username")
        XCTAssertEqual(command["payload"] as? [String: String], ["username": "lena_park", "user_id": "stranger"])
        model.userID = nil
        runtime.sync()
        XCTAssertTrue(ui.usernamePeople.isEmpty)
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
                                    session: session, loadCredential: store.read, saveCredential: store.write, deleteCredential: store.clear)
        return (backend, store)
    }
}

private final class BackendCredentialStore {
    private let lock = NSLock()
    private var data: Data?
    init(_ data: Data) { self.data = data }
    func read() -> Data? { lock.lock(); defer { lock.unlock() }; return data }
    func write(_ data: Data) { lock.lock(); defer { lock.unlock() }; self.data = data }
    func clear() { lock.lock(); defer { lock.unlock() }; data = nil }
}

private actor BackendHTTPFixture {
    private(set) var requests: [URLRequest] = []
    let failureStatus: Int
    let failureBody: Data
    let rejectFreshToken: Bool
    let refreshStatus: Int
    let refreshBody: Data?
    let snapshotError: URLError.Code?
    let snapshotStarted: XCTestExpectation?
    private var holdSnapshots: Bool
    private var snapshotWaiters: [CheckedContinuation<Void, Never>] = []
    private var profileSaved = false
    private let rhythmRows: [RhythmSession]
    private let usernameRows: [SocialRow]
    private let followUsernameStatus: Int
    private let loseCreateResponseAt: Int?
    private var createAttempts = 0
    private var createReceipts: [String: (payload: Data, id: String)] = [:]
    var createdSessionCount: Int { createReceipts.count }

    init(failureStatus: Int, failureBody: Data, rejectFreshToken: Bool = false, refreshStatus: Int = 200, refreshBody: Data? = nil,
         snapshotError: URLError.Code? = nil, snapshotStarted: XCTestExpectation? = nil, holdSnapshots: Bool = false, loseCreateResponseAt: Int? = nil, rhythmRows: [RhythmSession] = [], usernameRows: [SocialRow] = [], followUsernameStatus: Int = 200) {
        self.failureStatus = failureStatus
        self.failureBody = failureBody
        self.rejectFreshToken = rejectFreshToken
        self.refreshStatus = refreshStatus
        self.refreshBody = refreshBody
        self.snapshotError = snapshotError
        self.snapshotStarted = snapshotStarted
        self.holdSnapshots = holdSnapshots
        self.loseCreateResponseAt = loseCreateResponseAt
        self.rhythmRows = rhythmRows
        self.usernameRows = usernameRows
        self.followUsernameStatus = followUsernameStatus
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
            if refreshStatus != 200 { return (refreshStatus, refreshBody ?? Data(#"{"message":"Refresh token rejected"}"#.utf8)) }
            let refreshed = CloudCredential(access_token: "fresh-token", refresh_token: "rotated-refresh", user: CloudUser(id: "owner"), expires_at: Date().timeIntervalSince1970 + 3600)
            return (200, try JSONEncoder().encode(refreshed))
        }
        if request.value(forHTTPHeaderField: "Authorization") != "Bearer fresh-token" || rejectFreshToken {
            return (failureStatus, failureBody)
        }
        if request.url?.path == "/rest/v1/sessions" {
            let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let offset = Int(items.first { $0.name == "offset" }?.value ?? "0") ?? 0
            let limit = Int(items.first { $0.name == "limit" }?.value ?? "200") ?? 200
            return (200, try JSONEncoder().encode(Array(rhythmRows.dropFirst(offset).prefix(limit))))
        }
        if request.url?.path == "/rest/v1/rpc/search_usernames" {
            return (200, try JSONEncoder().encode(usernameRows))
        }
        if request.url?.path == "/rest/v1/rpc/command", let body = request.httpBody,
           let command = try JSONSerialization.jsonObject(with: body) as? [String: Any],
           command["operation"] as? String == "follow_username" {
            return (followUsernameStatus, Data(#"{"message":"Username unavailable. Search again"}"#.utf8))
        }
        if request.url?.path == "/rest/v1/rpc/command",
           let body = request.httpBody,
           let command = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           command["operation"] as? String == "save_profile" { profileSaved = true }
        if request.url?.path == "/rest/v1/rpc/command", let body = request.httpBody,
           let command = try JSONSerialization.jsonObject(with: body) as? [String: Any] {
            if command["operation"] as? String == "friend_token" {
                return (200, try JSONSerialization.data(withJSONObject: ["token": String(repeating: "a1", count: 32)]))
            }
            if command["operation"] as? String == "redeem_friend" {
                return (200, Data(#"{"id":"partner"}"#.utf8))
            }
        }
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

final class GoalSharingTests: XCTestCase {
    @MainActor
    func testPreviewSharingInvitesTrainingPartnersAndRemembersWhoHasIt() async {
        let ui = AppModel(live: false)
        let shared = await ui.shareGoal("g1", with: ["sarah", "me"])
        XCTAssertTrue(shared)
        XCTAssertEqual(ui.recipients(ofGoal: "g1"), ["sarah": "pending"], "You never invite yourself")
        XCTAssertEqual(ui.toast?.message, "Shared with Sarah")
        let nobody = await ui.shareGoal("g1", with: [])
        XCTAssertFalse(nobody)
        ui.deleteGoal("g1")
        XCTAssertTrue(ui.recipients(ofGoal: "g1").isEmpty, "Deleting a goal stops sharing it")
    }

    @MainActor
    func testAcceptingMovesAnInvitationToSharedAndDecliningRemovesIt() async {
        let ui = AppModel(live: false)
        XCTAssertEqual(ui.goalInvites.map(\.id), ["sg-berimbolo"])
        XCTAssertEqual(ui.acceptedSharedGoals.map(\.id), ["sg-single-leg", "sg-closed-guard"], "Newest first")
        XCTAssertTrue(ui.notifications.contains { $0.kind == .goalShare && $0.unread })

        let accepted = await ui.respondToSharedGoal("sg-berimbolo", accept: true)
        XCTAssertTrue(accepted)
        XCTAssertTrue(ui.goalInvites.isEmpty)
        XCTAssertEqual(ui.acceptedSharedGoals.first?.id, "sg-berimbolo")
        XCTAssertFalse(ui.notifications.contains { $0.kind == .goalShare && $0.unread }, "Answering reads the alert")
        XCTAssertEqual(ui.toast?.message, "Berimbolo entries is in Shared")

        _ = await ui.respondToSharedGoal("sg-closed-guard", accept: false)
        XCTAssertNil(ui.sharedGoal("sg-closed-guard"))
        XCTAssertEqual(ui.toast?.message, "Removed from Shared")
    }

    func testSharedGoalSummarySaysWhatsInside() {
        let goal = SharedGoal(id: "x", owner: "sarah", title: "Single leg", links: ["https://a.example", "https://b.example"],
                              photos: ["a"], parts: [GoalPart(title: "Entry", photos: ["b", "c"]),
                                                     GoalPart(title: "Pipe", link: "https://youtu.be/x")])
        XCTAssertEqual(goal.contentsSummary, "2 parts · 1 video · 3 photos · 2 links")
        XCTAssertEqual(SharedGoal(id: "y", owner: "sarah", title: "Empty").contentsSummary, "")
        XCTAssertEqual(AppNotification.Kind(rawValue: "goal_share"), .goalShare)
    }

    func testSnapshotsCachedBeforeGoalSharingStillDecode() throws {
        let old = try JSONDecoder().decode(SocialSnapshot.self, from: Data(#"{"server_time":null,"profiles":[],"friendships":[],"sessions":[],"participants":[],"posts":[],"tags":[],"likes":[],"comments":[],"credits":[],"media":[],"notifications":[]}"#.utf8))
        XCTAssertNil(old.shared_goals)
        XCTAssertNil(old.goal_shares)
    }

    @MainActor
    func testLiveSyncSeparatesGoalsSharedWithYouFromYourOwn() throws {
        let json = #"""
        {"profiles":[{"id":"me-id","name":"Dani","belt":"purple","stripes":2,"gym":"Tidewater","username":"dani"},
                     {"id":"sarah-id","name":"Sarah Lee","belt":"blue","stripes":3,"gym":"Tidewater","username":"sarah"}],
         "friendships":[],"sessions":[],"participants":[],"posts":[],"tags":[],"likes":[],"comments":[],"credits":[],"media":[],
         "notifications":[{"id":"goal-note","recipient":"me-id","actor":"sarah-id","kind":"goal_update","entity_id":"cloud-1","message":"updated Single leg finish","created_at":"2026-11-04T10:00:00Z"}],
         "shared_goals":[
           {"id":"cloud-1","owner":"sarah-id","client_id":"g9","title":"Single leg finish","notes":"Head on the hip",
            "links":["https://example.com/a"],"photos":[],"media":["sarah-id/aa.jpg"],
            "parts":[{"id":"p1","title":"Run the pipe","notes":"","link":"https://youtu.be/x","photos":["sarah-id/aa.jpg"]}]},
           {"id":"cloud-2","owner":"me-id","client_id":"g1","title":"Knee cut","notes":"","links":[],"photos":[],"parts":[],"media":[]}],
         "goal_shares":[
           {"goal_id":"cloud-1","recipient":"me-id","status":"pending","via":"link","created_at":"2026-11-03T10:00:00Z"},
           {"goal_id":"cloud-2","recipient":"sarah-id","status":"accepted","via":"friend","created_at":"2026-11-03T09:00:00Z"}]}
        """#
        let model = SocialAppModel(backend: BackendClient(configuration: nil, loadCredential: { nil }, saveCredential: { _ in }))
        model.userID = "me-id"
        model.snapshot = try JSONDecoder().decode(SocialSnapshot.self, from: Data(json.utf8))
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        runtime.sync()

        XCTAssertEqual(ui.sharedGoals.map(\.id), ["cloud-1"], "Your own shared goal is not in Shared")
        let shared = try XCTUnwrap(ui.sharedGoal("cloud-1"))
        XCTAssertEqual(shared.owner, "sarah-id")
        XCTAssertEqual(shared.status, .pending)
        XCTAssertEqual(shared.parts.map(\.title), ["Run the pipe"])
        XCTAssertEqual(shared.parts.first?.link, "https://youtu.be/x")
        XCTAssertTrue(shared.parts.first?.photos.isEmpty ?? false, "Photos appear once downloaded")
        XCTAssertEqual(ui.person("sarah-id").name, "Sarah Lee", "The sender is known even when not a friend")
        XCTAssertEqual(ui.sharedGoalIDs, ["g1": "cloud-2"])
        XCTAssertEqual(ui.recipients(ofGoal: "g1"), ["sarah-id": "accepted"])
        let notification = try XCTUnwrap(ui.notifications.first)
        XCTAssertEqual(notification.kind, .goalUpdate)
        XCTAssertEqual(notification.session, shared.id)
        XCTAssertEqual(notification.who, shared.owner)
        XCTAssertEqual(notification.text, "updated Single leg finish")
        XCTAssertTrue(notification.unread)
    }

    @MainActor
    func testGoalLinksAreAcceptedLikeOtherInvitations() {
        let model = SocialAppModel(backend: BackendClient(configuration: nil, loadCredential: { nil }, saveCredential: { _ in }))
        let token = String(repeating: "a", count: 64)
        let link = URL(string: "matmind://goal/" + token)!
        model.handle(link)
        XCTAssertEqual(model.pendingLink, link)
        model.pendingLink = nil
        model.handle(URL(string: "matmind://elsewhere/" + token)!)
        XCTAssertNil(model.pendingLink)
        XCTAssertEqual(InvitationLinks.make(kind: "goal", token: token, host: "matmonkey.lovable.app", httpsEnabled: true).absoluteString,
                       "https://matmonkey.lovable.app/goal/" + token)
    }
}

@MainActor
final class MonkeyTests: XCTestCase {
    func testMonkeyCodesRoundTripAndMatchTheServerFormat() throws {
        // Mirrors the profiles.monkey check in 20261104170000_monkey_avatars.sql.
        let server = try NSRegularExpression(pattern: "^(happy|grin|focused|tired|side|tapped)\\.(ink-900|ink-700|ink-500|coral-700|sky-700|plum-700|mint-700)\\.(clean|tuft|fringe|mohawk|topknot|curls)$")
        for mood in MMMonkeyLook.Mood.allCases {
            for fur in MMMonkeyLook.Fur.allCases {
                for haircut in MMMonkeyLook.Haircut.allCases {
                    let look = MMMonkeyLook(mood: mood, fur: fur, haircut: haircut)
                    XCTAssertEqual(MMMonkeyLook(code: look.code), look)
                    XCTAssertEqual(server.numberOfMatches(in: look.code, range: NSRange(look.code.startIndex..., in: look.code)), 1, look.code)
                }
            }
        }
        XCTAssertEqual(MMMonkeyLook(code: "grin.coral-700.topknot"), MMMonkeyLook(mood: .grin, fur: .ginger, haircut: .topknot))
    }

    func testUnknownOrMissingMonkeysMeanJustTheName() {
        for code in ["", "happy.ink-900", "angry.ink-900.tuft", "happy.sun-600.tuft", "happy.ink-900.afro", "happy.ink-900.tuft.extra"] {
            XCTAssertNil(MMMonkeyLook(code: code), code)
        }
    }

#if DEBUG
    func testPreviewMembersGetOneInvitationAndSavingAnswersIt() async {
        let ui = AppModel(live: false)
        ui.enterDemo()
        XCTAssertNil(ui.me.monkey)
        XCTAssertTrue(ui.shouldAskForMonkey, "an account without a monkey is asked on Activity")
        ui.go(.notifications)
        XCTAssertFalse(ui.shouldAskForMonkey, "never over a pushed screen")
        ui.back()

        let look = MMMonkeyLook(mood: .focused, fur: .charcoal, haircut: .mohawk)
        let saved = await ui.saveMonkey(look)
        XCTAssertTrue(saved)
        XCTAssertEqual(ui.me.monkey, look)
        XCTAssertFalse(ui.shouldAskForMonkey)
    }

    func testMaybeLaterStopsTheInvitation() {
        let ui = AppModel(live: false)
        ui.enterDemo()
        ui.answerMonkeyPrompt()
        XCTAssertNil(ui.me.monkey)
        XCTAssertFalse(ui.shouldAskForMonkey, "Maybe later: the Account row is the way back in")
    }
#endif
}

final class TrainingCalendarTests: XCTestCase {
    @MainActor func testDaySheetClassificationAndCountsDaysNotEntries() {
        let ui = AppModel(live: true)
        let day = TrainingCalendar.calendar.startOfDay(for: Date())
        let key = TrainingCalendar.key(day)
        ui.quickLogs = [QuickLog(id: "a", loggedOn: key, loggedAt: day, timezone: "UTC"),
                        QuickLog(id: "b", loggedOn: key, loggedAt: day, timezone: "UTC")]
        XCTAssertEqual(ui.entryCount(day), 2)
        XCTAssertEqual(ui.trainedDays(TrainingCalendar.week(day)), 1)
        XCTAssertEqual(ui.trainingTap(day), .entries)
        XCTAssertEqual(ui.trainingTap(day, isActivity: true), .quickLog, "Filled dates without plans add directly from Activity")
        let plan = Session(id: "p", title: "No-gi", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                           people: [Attendee(id: "me", status: .going)], startsAt: day)
        ui.upcoming = [plan]
        XCTAssertEqual(ui.trainingTap(day), .choose, "The calendar/history chooser keeps the open plan available")
        XCTAssertEqual(ui.trainingTap(day, isActivity: true), .choose, "The whole Activity day opens the chooser even with multiple quick logs")
        ui.quickLogs = []
        XCTAssertEqual(ui.entryCount(day), 0, "Scheduled plans never count")
        XCTAssertEqual(ui.trainingTap(day, isActivity: true), .choose, "An empty planned day also opens the chooser")
        let future = TrainingCalendar.calendar.date(byAdding: .day, value: 1, to: day)!
        ui.upcoming[0].startsAt = future
        XCTAssertEqual(ui.trainingTap(future), .disabled, "A future plan cannot be logged")
        XCTAssertEqual(ui.trainingTap(future, isActivity: true), .choose, "Future planned days can show options without logging early")
        XCTAssertEqual(ui.trainingTap(day), .quickLog)
        XCTAssertEqual(ui.trainingTap(day, isActivity: true), .quickLog)
        ui.upcoming = []
        XCTAssertEqual(ui.trainingTap(future, isActivity: true), .disabled, "Future dates without a plan stay disabled")
    }
    @MainActor func testTrainingCompletionCTAExcludesFutureGuestAndAlreadyLoggedSessions() async throws {
        let ui = AppModel(live: false), now = Date()
        let session = Session(id: "needs-log", title: "Past rolls", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                              people: [Attendee(id: "me", status: .going), Attendee(id: "kenji", status: .going)], startsAt: now.addingTimeInterval(-60))
        ui.upcoming = [session]; ui.completedSessions = []; ui.drafts = []; ui.toComplete = nil
        ui.quickLogs = []; ui.sharedSessionIDs = []; ui.posts = []
        XCTAssertTrue(ui.canCompleteTraining(session, now: now))
        XCTAssertNil(ui.trainingCompletionStatus(session))

        await ui.addQuickLog(now)
        XCTAssertTrue(ui.canCompleteTraining(session, now: now), "A separate date-only quick log does not complete the plan")
        let marked = await ui.markTrainingDone(session)
        XCTAssertTrue(marked)
        XCTAssertTrue(ui.posts.isEmpty)
        XCTAssertFalse(ui.canCompleteTraining(session, now: now), "Attendance logged without a photo removes the card CTA")
        XCTAssertEqual(ui.trainingCompletionStatus(session), .completed, "Attendance without a photo shows Completed")
        await ui.undoTrainingToast(try XCTUnwrap(ui.toast?.id))
        XCTAssertTrue(ui.canCompleteTraining(session, now: now), "Undo makes the unlogged session actionable again")
        XCTAssertNil(ui.trainingCompletionStatus(session))

        ui.upcoming[0].startsAt = now.addingTimeInterval(60)
        XCTAssertFalse(ui.canCompleteTraining(session, now: now), "Use the current schedule after an edit, even with a stale card")
        ui.upcoming = [session]
        ui.upcoming[0].organizer = "kenji"
        XCTAssertFalse(ui.canCompleteTraining(session, now: now), "Guests cannot share a host's session")
        ui.upcoming = [session]
        ui.upcoming[0].people[0].attended = true
        XCTAssertFalse(ui.canCompleteTraining(session, now: now), "A logged participant does not need another completion")
        XCTAssertEqual(ui.trainingCompletionStatus(session), .completed, "Use current attendance even with a stale card")

        let photos: [String?] = [nil, "sample-photo"]
        for photo in photos {
            ui.upcoming = [session]; ui.completedSessions = []; ui.sharedSessionIDs = []; ui.posts = []
            XCTAssertTrue(ui.canCompleteTraining(session, now: now))
            XCTAssertNotNil(ui.publish(session.id, photo: photo, caption: photo == nil ? "Good rounds" : "", people: session.going))
            XCTAssertFalse(ui.canCompleteTraining(session, now: now), "Photo and note-only posts both remove the CTA")
            XCTAssertEqual(ui.trainingCompletionStatus(session), .completed, "Photo and note-only posts both show Completed")
            ui.completedSessions = []; ui.upcoming = [session]
            XCTAssertFalse(ui.canCompleteTraining(session, now: now), "A published session stays logged even when completion history is not loaded")
            ui.posts = []
            XCTAssertEqual(ui.trainingCompletionStatus(session), .completed, "Completed status survives feed pagination or post removal")
        }
    }

    func testMergeWindowIncludesExactlyThreeHoursAndRequiresSameLocalDay() {
        let day = TrainingCalendar.calendar.startOfDay(for: Date())
        let start = day.addingTimeInterval(12 * 3600)
        let s = Session(id: "p", title: "No-gi", day: "Wed", date: 4, month: "Nov", time: "12:00", gym: "Gym", organizer: "me", people: [], startsAt: start)
        var log = QuickLog(id: "a", loggedOn: TrainingCalendar.key(start), loggedAt: start.addingTimeInterval(-10800), timezone: TimeZone.current.identifier)
        XCTAssertTrue(TrainingCalendar.matches(log, session: s))
        log.loggedAt = start.addingTimeInterval(10801)
        XCTAssertFalse(TrainingCalendar.matches(log, session: s))
        log.loggedAt = start; log.loggedOn = "1999-01-01"
        XCTAssertFalse(TrainingCalendar.matches(log, session: s))
    }
    @MainActor func testHostCompletionAndUndoAffectJoinedParticipantsOnly() async {
        let ui = AppModel(live: false)
        let now = Date()
        let s = Session(id: "host", title: "No-gi", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                        people: [Attendee(id: "me", status: .going), Attendee(id: "kenji", status: .going), Attendee(id: "sarah", status: .invited)], startsAt: now)
        ui.upcoming = [s]; ui.completedSessions = []; ui.quickLogs = []; ui.posts = []; ui.toComplete = nil; ui.drafts = []
        await ui.markTrainingDone(s)
        XCTAssertEqual(ui.daySessions(now).count, 1)
        XCTAssertEqual(ui.completedSessions.first?.people.filter(\.attended).map(\.id), ["me", "kenji"])
        XCTAssertTrue(ui.posts.isEmpty)
        XCTAssertEqual(ui.toast?.message, "Marked done for you and Kenji")
        await ui.trainingUndo?()
        XCTAssertTrue(ui.completedSessions.isEmpty)
        XCTAssertEqual(ui.upcoming.first, s)
    }
    @MainActor func testGuestCompletionHasNoSharePromptAndCannotPublish() async {
        let ui = AppModel(live: false)
        let s = Session(id: "guest", title: "No-gi", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "kenji",
                        people: [Attendee(id: "me", status: .going), Attendee(id: "kenji", status: .going)], startsAt: Date())
        ui.upcoming = [s]; ui.completedSessions = []; ui.posts = []
        await ui.markTrainingDone(s)
        XCTAssertEqual(ui.upcoming.first?.people.filter(\.attended).map(\.id), ["me"])
        XCTAssertTrue(ui.completedSessions.isEmpty, "Guest attendance never completes the host plan")
        XCTAssertNil(ui.publish(s.id, photo: "photo", caption: "", people: s.going))
        await ui.trainingUndo?()
        XCTAssertEqual(ui.upcoming.first, s)
    }
}

extension TrainingCalendarTests {
    @MainActor func testUndeployedBackendNeverReceivesQuickLogWrites() async {
        let ui = AppModel(live: true), runtime = TrainingRuntimeStub()
        ui.runtime = runtime
        var requests = 0
        runtime.command = { _, _ in requests += 1; return true }
        let plan = Session(id: "pending", title: "Past rolls", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                           people: [Attendee(id: "me", status: .going)], startsAt: Date().addingTimeInterval(-60))
        ui.upcoming = [plan]
        XCTAssertFalse(ui.quickTrainingLogEnabled)
        let logged = await ui.addQuickLog(Date())
        let deleted = await ui.deleteQuickLog("missing")
        let marked = await ui.markTrainingDone(plan)
        XCTAssertFalse(logged)
        XCTAssertFalse(deleted)
        XCTAssertFalse(marked)
        XCTAssertEqual(requests, 0)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertNil(ui.toast)
        ui.quickTrainingLogBackendAvailable = true
        XCTAssertTrue(ui.quickTrainingLogEnabled)
        ui.clearLiveData()
        XCTAssertFalse(ui.quickTrainingLogEnabled, "Account clearing also disables the deferred backend feature")
    }

    @MainActor func testQuickLogUndoNeverCreatesSessionOrPost() async {
        let ui = AppModel(live: false)
        ui.quickLogs = []; ui.upcoming = []; ui.completedSessions = []; ui.posts = []; ui.drafts = []; ui.toComplete = nil
        let day = TrainingCalendar.calendar.startOfDay(for: Date())
        await ui.addQuickLog(day)
        XCTAssertEqual(ui.entryCount(day), 1)
        XCTAssertTrue(ui.trainingSessions(past: true).isEmpty)
        XCTAssertTrue(ui.trainingSessions(past: false).isEmpty)
        XCTAssertTrue(ui.posts.isEmpty)
        let toastID = ui.toast!.id
        await ui.undoTrainingToast(toastID)
        XCTAssertEqual(ui.entryCount(day), 0)
        XCTAssertNil(ui.toast)
        XCTAssertNil(ui.trainingUndo)
    }
    @MainActor func testLiveHistorySurvivesSchedulePaginationAndAccountClearing() throws {
        let model = SocialAppModel(); model.userID = "owner"
        model.snapshot.training_days = try JSONDecoder().decode([SocialRow].self, from: Data(#"""
        [{"day":"2026-11-04","quick_log_count":0,"sessions":[{"id":"older","organizer":"owner","title":"Older rolls","starts_at":"2026-11-04T12:00:00Z","venue":"Gym","status":"completed"}]}]
        """#.utf8))
        model.snapshot.participants = try JSONDecoder().decode([SocialRow].self, from: Data(#"""
        [{"session_id":"older","user_id":"owner","rsvp":"going","attended":true}]
        """#.utf8))
        model.snapshot.shared_session_ids = ["older"]
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        runtime.sync()
        let start = try XCTUnwrap(ui.findSession("older")?.startsAt)
        XCTAssertEqual(ui.entryCount(start), 1, "History must not depend on the schedule's 100-session page")
        XCTAssertFalse(ui.quickTrainingLogEnabled, "A partial snapshot does not enable undeployed operations")
        model.snapshot.quick_logs = []; model.snapshot.log_matches = []
        runtime.sync()
        XCTAssertTrue(ui.quickTrainingLogEnabled, "Only a complete backend feature snapshot enables live quick logging")
        XCTAssertFalse(ui.canCompleteTraining(try XCTUnwrap(ui.findSession("older"))), "Previously shared sessions must not get a completion CTA after feed pagination or post deletion")
        ui.clearLiveData()
        XCTAssertTrue(ui.calendarSessions.isEmpty)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertTrue(ui.sharedSessionIDs.isEmpty)
        XCTAssertNil(ui.trainingUndo)
    }
}

#if DEBUG
extension TrainingCalendarTests {
    @MainActor func testPreviewIncludesCompletedUnsharedPlanAndQuickLogs() throws {
        let ui = AppModel.uiReviewPreview()
        XCTAssertFalse(ui.quickLogs.isEmpty)
        let completed = try XCTUnwrap(ui.completedSessions.first)
        XCTAssertFalse(ui.canCompleteTraining(completed), "A session already logged without a photo must not get a completion CTA")
        XCTAssertFalse(ui.openPlans(Date()).isEmpty, "Today must offer the planned-session chooser")
    }
}
#endif

@MainActor
private final class TrainingRuntimeStub: AppRuntime {
    var busy = false
    var command: @MainActor (String, [String: Any]) async -> Bool = { _, _ in false }
    func perform(_ operation: String, _ payload: [String: Any]) async -> Bool { await command(operation, payload) }
    func authenticate() async {}
    func signOut() async {}
    func partners(of personID: String) async -> [Person]? { nil }
    func searchUsernames(_ query: String) async throws -> [Person] { [] }
    func enableNotifications() async -> String? { nil }
    func create(_ draft: SessionDraft, key: UUID) async -> String? { nil }
    func saveSessionPhoto(_ sessionID: String, photo: String) async -> Bool { false }
    func publish(_ sessionID: String, photo: String?, caption: String, people: [String]) async -> PublishResult? { nil }
    func saveAvatar(_ jpeg: Data) async -> Bool { false }
    func friendCode() async -> String? { nil }
    func connect(_ value: String) async -> String? { nil }
    func sessionInvitationURL(_ sessionID: String) async -> URL? { nil }
    func copySessionLink(_ sessionID: String) async {}
    func saveFocus(_ sessionID: String, _ items: [TrainingFocus]) async -> Bool { false }
    func editSession(_ sessionID: String, title: String, startsAt: Date, gym: String, note: String, focusItems: [TrainingFocus], addedGuests: [String], removedGuests: [String]) async -> Bool { false }
    func publishGoal(_ goal: MatGoal) async -> String? { nil }
    func copyGoalLink(_ sharedID: String) async -> Bool { false }
    func scannerView(found: @escaping (String) -> Void) -> AnyView { AnyView(EmptyView()) }
    func exportView() -> AnyView { AnyView(EmptyView()) }
}

final class TechniqueTrendTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return value
    }

    private func date(_ day: String, calendar: Calendar? = nil) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar ?? self.calendar
        formatter.timeZone = (calendar ?? self.calendar).timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: day + " 12:00")!
    }

    private func log(_ id: String, _ day: String) -> QuickLog {
        QuickLog(id: id, loggedOn: day, loggedAt: date(day), timezone: calendar.timeZone.identifier)
    }

    func testFirstLogCreatesOnlyItsTechniqueAndNoDefaults() throws {
        let entry = log("a", "2026-11-05")
        let history = TechniqueTrendHistory(logs: [entry], hitsByID: ["a": [QuickLogHit(id: "heel-hook", name: "Heel hook", count: 2)]],
                                            now: date("2026-11-05"), calendar: calendar)
        let trend = try XCTUnwrap(history.trends.first)
        XCTAssertEqual(history.trends.count, 1)
        XCTAssertEqual(history.currentDayIndex, 3)
        XCTAssertEqual(trend.thisWeek, [0, 0, 0, 2, 0, 0, 0])
        XCTAssertEqual(trend.thisWeekTotal, 2)
        XCTAssertEqual(trend.lastWeekTotal, 0)
    }

    func testMultipleLogsSumByDayAndComparePreviousMondayThroughSunday() throws {
        let logs = [log("a", "2026-10-26"), log("b", "2026-11-01"), log("c", "2026-11-02"), log("d", "2026-11-02"), log("e", "2026-11-05")]
        let counts = ["a": 4, "b": 7, "c": 2, "d": 3, "e": 1]
        let hits = counts.mapValues { [QuickLogHit(id: "armbar", name: "Armbar", count: $0)] }
        let history = TechniqueTrendHistory(logs: logs, hitsByID: hits, now: date("2026-11-05"), calendar: calendar)
        let trend = try XCTUnwrap(history.trends.first)
        XCTAssertEqual(trend.lastWeek, [4, 0, 0, 0, 0, 0, 7])
        XCTAssertEqual(trend.thisWeek, [5, 0, 0, 1, 0, 0, 0])
        XCTAssertEqual(trend.thisWeekTotal, 6)
        XCTAssertEqual(trend.lastWeekTotal, 11)
    }

    func testDeletedLogsAndUnloggedPresetsDoNotCreateCharts() {
        let orphaned = ["removed": [QuickLogHit(id: "heel-hook", name: "Heel hook", count: 4)]]
        let history = TechniqueTrendHistory(logs: [log("date-only", "2026-11-05")], hitsByID: orphaned,
                                            now: date("2026-11-05"), calendar: calendar)
        XCTAssertTrue(history.trends.isEmpty)
    }

    func testReaddedTechniqueUsesItsSavedNameAcrossIDsAndNeverCountsALogTwice() throws {
        let old = log("old", "2026-10-27"), recent = log("new", "2026-11-05")
        let history = TechniqueTrendHistory(logs: [old, recent, recent], hitsByID: [
            "old": [QuickLogHit(id: "old-id", name: " armbar ", count: 4)],
            "new": [QuickLogHit(id: "new-id", name: "Armbar", count: 2)]
        ], now: date("2026-11-05"), calendar: calendar)
        XCTAssertEqual(history.trends.count, 1)
        let trend = try XCTUnwrap(history.trends.first)
        XCTAssertEqual(trend.name, "Armbar")
        XCTAssertEqual(trend.lastWeekTotal, 4)
        XCTAssertEqual(trend.thisWeekTotal, 2)
    }

    func testFutureInvalidAndNonpositiveRecordsCannotCreateOrDistortAChart() {
        var invalid = log("invalid", "2026-11-05")
        invalid.loggedOn = "not-a-day"
        let logs = [invalid, log("future", "2026-11-06"), log("zero", "2026-11-05")]
        let positive = [QuickLogHit(id: "heel-hook", name: "Heel hook", count: 5)]
        let history = TechniqueTrendHistory(logs: logs, hitsByID: ["invalid": positive, "future": positive, "zero": [
            QuickLogHit(id: "a", name: "Armbar", count: 0), QuickLogHit(id: "b", name: "Back take", count: -1), QuickLogHit(id: "c", name: " ", count: 3)
        ]], now: date("2026-11-05"), calendar: calendar)
        XCTAssertTrue(history.trends.isEmpty)
    }

    func testTechniqueWithOnlyOlderHistoryKeepsItsChartWithoutFabricatingRecentReps() throws {
        let history = TechniqueTrendHistory(logs: [log("old", "2026-09-01")], hitsByID: [
            "old": [QuickLogHit(id: "triangle", name: "Triangle", count: 8)]
        ], now: date("2026-11-05"), calendar: calendar)
        let trend = try XCTUnwrap(history.trends.first)
        XCTAssertEqual(trend.name, "Triangle")
        XCTAssertEqual(trend.thisWeekTotal, 0)
        XCTAssertEqual(trend.lastWeekTotal, 0)
    }

    func testMondayStartsFreshAndMovesSundayIntoLastWeekAcrossDST() throws {
        let hits = ["sunday": [QuickLogHit(id: "armbar", name: "Armbar", count: 3)]]
        let logs = [log("sunday", "2026-11-01")]
        let sunday = TechniqueTrendHistory(logs: logs, hitsByID: hits, now: date("2026-11-01"), calendar: calendar)
        XCTAssertEqual(sunday.currentDayIndex, 6)
        XCTAssertEqual(sunday.trends.first?.thisWeekTotal, 3)
        let monday = TechniqueTrendHistory(logs: logs, hitsByID: hits, now: date("2026-11-02"), calendar: calendar)
        XCTAssertEqual(monday.currentDayIndex, 0)
        XCTAssertEqual(monday.trends.first?.lastWeek, [0, 0, 0, 0, 0, 0, 3])
        XCTAssertEqual(monday.trends.first?.thisWeekTotal, 0)
    }

    func testLoggedDateControlsTheBucketRatherThanTheSaveTimestampOrDeviceTimezone() throws {
        let backdated = QuickLog(id: "a", loggedOn: "2026-10-30", loggedAt: date("2026-11-05"), timezone: "Pacific/Auckland")
        var auckland = calendar
        auckland.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        let history = TechniqueTrendHistory(logs: [backdated], hitsByID: ["a": [QuickLogHit(id: "armbar", name: "Armbar", count: 2)]],
                                            now: date("2026-11-05", calendar: auckland), calendar: auckland)
        XCTAssertEqual(history.trends.first?.lastWeek, [0, 0, 0, 0, 2, 0, 0])
        XCTAssertEqual(history.trends.first?.thisWeekTotal, 0)
    }

    @MainActor func testSavedCountsAppearImmediatelyAndUndoAndAccountClearingRemoveThem() async throws {
        let ui = AppModel(live: false)
        ui.quickLogs = []
        let saved = await ui.addQuickLog(Date(), counts: ["heel-hook": 2])
        XCTAssertTrue(saved)
        var history = TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID)
        XCTAssertEqual(history.trends.first?.thisWeekTotal, 2)
        ui.removeQuickLogTechnique("heel-hook")
        history = TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID)
        XCTAssertEqual(history.trends.first?.thisWeekTotal, 2, "Removing a preset never erases logged history")
        let toast = try XCTUnwrap(ui.toast)
        await ui.undoTrainingToast(toast.id)
        XCTAssertTrue(TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID).trends.isEmpty)
        ui.clearLiveData()
        XCTAssertTrue(TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID).trends.isEmpty)
    }
}

#if DEBUG
extension TechniqueTrendTests {
    @MainActor func testQuickLogMockIncludesHitsAndNoLogStateCanSaveAndUndoItsFirstHits() async throws {
        let ui = AppModel.quickTrainingLogMock(.quickLogs)
        var history = TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID)
        XCTAssertFalse(ui.quickLogs.isEmpty)
        XCTAssertEqual(Set(history.trends.map(\.name)), Set(["Heel hook", "Armbar", "Back take"]))
        XCTAssertEqual(history.trends.first { $0.id == "heel hook" }?.thisWeekTotal, 3)

        ui.loadQuickLogMock(.noQuickLogs)
        XCTAssertEqual(ui.tab, .profile)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        history = TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID)
        XCTAssertTrue(history.trends.isEmpty, "No quick logs must show the empty-state invitation")

        let saved = await ui.addQuickLog(Date(), counts: ["heel-hook": 1])
        XCTAssertTrue(saved)
        history = TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID)
        XCTAssertEqual(history.trends.first?.thisWeekTotal, 1, "The first saved hits replace the monkey with charts")
        let toast = try XCTUnwrap(ui.toast)
        await ui.undoTrainingToast(toast.id)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertTrue(TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID).trends.isEmpty)

        let live = AppModel(live: true)
        live.loadQuickLogMock(.quickLogs)
        live.loadQuickLogMock(.noQuickLogs)
        XCTAssertTrue(live.quickLogs.isEmpty)
        XCTAssertTrue(live.quickLogHitsByID.isEmpty)
    }

    @MainActor func testExplicitStatsPreviewSeedsTwoWeeksWithoutLiveData() {
        let now = date("2026-11-05")
        let ui = AppModel(live: false)
        ui.loadQuickLogMock(.techniqueStats, now: now)
        let history = TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID, now: now)
        XCTAssertEqual(ui.tab, .profile)
        XCTAssertEqual(Set(history.trends.map(\.name)), Set(["Heel hook", "Armbar", "Back take"]))
        XCTAssertTrue(history.trends.allSatisfy { $0.lastWeekTotal > 0 })
        XCTAssertTrue(ui.quickLogs.allSatisfy { $0.loggedOn <= TrainingCalendar.key(now) })
        XCTAssertNil(ui.runtime)
        let live = AppModel(live: true)
        live.loadQuickLogMock(.techniqueStats, now: now)
        XCTAssertTrue(live.quickLogs.isEmpty)
        XCTAssertTrue(live.quickLogHitsByID.isEmpty)
    }
}
#endif

final class QuickLogTechniqueTests: XCTestCase {
    @MainActor func testLiveSaveMatchesLowercaseServerIDsAndUndoRemovesItsHitDetails() async throws {
        let ui = AppModel(live: true), runtime = TrainingRuntimeStub()
        ui.runtime = runtime
        ui.quickTrainingLogBackendAvailable = true
        runtime.command = { operation, payload in
            guard let id = payload["id"] as? String else { return false }
            let serverID = UUID(uuidString: id)!.uuidString.lowercased()
            if operation == "create_quick_log" {
                XCTAssertEqual(id, serverID, "Local hit keys must use Postgres's UUID representation")
                ui.quickLogs = [QuickLog(id: serverID, loggedOn: payload["logged_on"] as! String,
                                        loggedAt: Date(), timezone: payload["timezone"] as! String)]
                return true
            }
            if operation == "delete_quick_log" {
                ui.quickLogs.removeAll { $0.id == serverID }
                return true
            }
            return false
        }
        let saved = await ui.addQuickLog(Date(), counts: ["heel-hook": 3])
        XCTAssertTrue(saved)
        let log = try XCTUnwrap(ui.quickLogs.first)
        XCTAssertEqual(ui.quickLogHitsByID[log.id]?.first?.count, 3)
        XCTAssertEqual(TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID).trends.first?.thisWeekTotal, 3)
        let toast = try XCTUnwrap(ui.toast)
        await ui.undoTrainingToast(toast.id)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertTrue(ui.quickLogHitsByID.isEmpty)
    }

    @MainActor func testLiveSnapshotRecoversAndPersistsLegacyUppercaseHitKeys() throws {
        let owner = UUID().uuidString.lowercased()
        let key = "matmonkeys.quickLogTechniques.\(owner)"
        let upper = "ABCDEFAB-1234-4567-89AB-ABCDEFABCDEF"
        let lower = upper.lowercased()
        let cache: [String: Any] = [
            "techniques": [["id": "heel-hook", "name": "Heel hook"]],
            "hitsByID": [upper: [["id": "heel-hook", "name": "Heel hook", "count": 5]]]
        ]
        UserDefaults.standard.set(try JSONSerialization.data(withJSONObject: cache), forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        let model = SocialAppModel()
        model.userID = owner
        let rows: [[String: Any]] = [["id": lower, "logged_on": TrainingCalendar.key(Date()),
                                    "logged_at": ISO8601DateFormatter().string(from: Date()), "timezone": TimeZone.current.identifier]]
        model.snapshot.quick_logs = try JSONDecoder().decode([SocialRow].self, from: JSONSerialization.data(withJSONObject: rows))
        model.snapshot.training_days = []; model.snapshot.log_matches = []; model.snapshot.shared_session_ids = []
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        runtime.sync()
        XCTAssertNil(ui.quickLogHitsByID[upper])
        XCTAssertEqual(ui.quickLogHitsByID[lower]?.first?.count, 5)
        XCTAssertEqual(TechniqueTrendHistory(logs: ui.quickLogs, hitsByID: ui.quickLogHitsByID).trends.first?.thisWeekTotal, 5)
        runtime.sync()
        XCTAssertEqual(ui.quickLogHitsByID[lower]?.first?.count, 5, "A refresh keeps the recovered chart data")
        let migrated = try XCTUnwrap(UserDefaults.standard.data(forKey: key))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: migrated) as? [String: Any])
        let hits = try XCTUnwrap(object["hitsByID"] as? [String: Any])
        XCTAssertNil(hits[upper])
        XCTAssertNotNil(hits[lower], "Migration must persist for the next launch")
        let reopened = AppModel(live: true)
        reopened.loadQuickLogTechniques(account: owner)
        XCTAssertEqual(reopened.quickLogHitsByID[lower]?.first?.count, 5)
    }

    @MainActor func testLegacyKeyCollisionsPreferCanonicalDataAndKeepPreviewIDs() throws {
        let suite = "quick-log-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let upper = "ABCDEFAB-1234-4567-89AB-ABCDEFABCDEF", lower = upper.lowercased()
        let cache: [String: Any] = ["techniques": [], "hitsByID": [
            upper: [["id": "heel-hook", "name": "Heel hook", "count": 5]],
            lower: [["id": "heel-hook", "name": "Heel hook", "count": 2]],
            "Mock-Log": [["id": "armbar", "name": "Armbar", "count": 1]]
        ]]
        defaults.set(try JSONSerialization.data(withJSONObject: cache), forKey: "matmonkeys.quickLogTechniques.owner")
        let ui = AppModel(live: false)
        ui.loadQuickLogTechniques(account: "owner", defaults: defaults)
        XCTAssertEqual(ui.quickLogHitsByID.count, 2)
        XCTAssertEqual(ui.quickLogHitsByID[lower]?.first?.count, 2, "The same log must never be counted twice")
        XCTAssertEqual(ui.quickLogHitsByID["Mock-Log"]?.first?.count, 1)
        XCTAssertTrue(ui.quickLogTechniques.isEmpty, "An empty saved preset list stays empty")
    }

    @MainActor func testLatestListPersistsIncludingAnIntentionallyEmptyList() throws {
        let suite = "quick-log-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let ui = AppModel(live: false)
        ui.loadQuickLogTechniques(account: "owner", defaults: defaults)
        let triangle = try XCTUnwrap(ui.addQuickLogTechnique("  Triangle\n"))
        ui.removeQuickLogTechnique("back-take")
        ui.loadQuickLogTechniques(account: "owner", defaults: defaults)
        XCTAssertEqual(ui.quickLogTechniques.map(\.name), ["Heel hook", "Armbar", "Triangle"], "Refresh must not replace the latest list")
        let reopened = AppModel(live: false)
        reopened.loadQuickLogTechniques(account: "owner", defaults: defaults)
        XCTAssertEqual(reopened.quickLogTechniques.last, triangle)
        for technique in reopened.quickLogTechniques { reopened.removeQuickLogTechnique(technique.id) }
        let empty = AppModel(live: false)
        empty.loadQuickLogTechniques(account: "owner", defaults: defaults)
        XCTAssertTrue(empty.quickLogTechniques.isEmpty, "An empty saved list must not resurrect the defaults")
    }

    @MainActor func testCustomNamesRejectBlanksAndCaseInsensitiveDuplicates() throws {
        let ui = AppModel(live: false)
        XCTAssertNil(ui.addQuickLogTechnique(" \n "))
        XCTAssertNil(ui.addQuickLogTechnique(" HEEL HOOK "))
        let custom = try XCTUnwrap(ui.addQuickLogTechnique("D’Arce from half guard"))
        XCTAssertEqual(custom.name, "D’Arce from half guard")
        XCTAssertEqual(ui.quickLogTechniques.count, 4)
    }

    @MainActor func testRemovingAndUndoingDoesNotChangeSavedReps() async throws {
        let ui = AppModel(live: false)
        ui.quickLogs = []
        let saved = await ui.addQuickLog(Date(), counts: ["heel-hook": 2, "back-take": 1])
        XCTAssertTrue(saved)
        let log = try XCTUnwrap(ui.quickLogs.first)
        let backTake = try XCTUnwrap(ui.quickLogTechniques.first { $0.id == "back-take" })
        ui.removeQuickLogTechnique(backTake.id)
        XCTAssertEqual(ui.quickLogHitsByID[log.id]?.map(\.name), ["Heel hook", "Back take"])
        XCTAssertEqual(ui.quickLogHitsByID[log.id]?.map(\.count), [2, 1])
        ui.restoreQuickLogTechnique(backTake, at: 1)
        ui.restoreQuickLogTechnique(backTake, at: 1)
        XCTAssertEqual(ui.quickLogTechniques, QuickLogTechnique.defaults, "Undo restores order without duplicates")
        XCTAssertEqual(ui.quickLogs, [log])
    }

    @MainActor func testOlderDayUsesLatestListAndSavesOnlyItsOwnPositiveCounts() async throws {
        let ui = AppModel(live: false)
        ui.quickLogs = []
        let yesterday = try XCTUnwrap(TrainingCalendar.calendar.date(byAdding: .day, value: -1, to: Date()))
        let todaySaved = await ui.addQuickLog(Date(), counts: ["heel-hook": 5])
        XCTAssertTrue(todaySaved)
        let today = try XCTUnwrap(ui.quickLogs.first)
        let triangle = try XCTUnwrap(ui.addQuickLogTechnique("Triangle"))
        ui.removeQuickLogTechnique("back-take")
        let olderSaved = await ui.addQuickLog(yesterday, counts: [triangle.id: 2, "heel-hook": 0, "armbar": -1, "back-take": 9, "unknown": 4])
        XCTAssertTrue(olderSaved)
        let older = try XCTUnwrap(ui.dayLogs(yesterday).first)
        XCTAssertEqual(ui.quickLogHitsByID[older.id], [QuickLogHit(id: triangle.id, name: "Triangle", count: 2)])
        XCTAssertEqual(ui.quickLogHitsByID[today.id]?.map(\.count), [5])
        XCTAssertEqual(ui.quickLogTechniques.map(\.name), ["Heel hook", "Armbar", "Triangle"])
        XCTAssertTrue(ui.quickLogHits(counts: [:]).isEmpty, "Opening again starts fresh, without copying earlier counts")
        XCTAssertTrue(ui.posts.allSatisfy { $0.id != older.id })
    }

    @MainActor func testCountsAndPresetsRemainIsolatedBetweenAccountsAndRelaunches() async throws {
        let suite = "quick-log-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let ui = AppModel(live: false)
        ui.loadQuickLogTechniques(account: "alice", defaults: defaults)
        ui.quickLogs = []
        let triangle = try XCTUnwrap(ui.addQuickLogTechnique("Triangle"))
        let saved = await ui.addQuickLog(Date(), counts: [triangle.id: 3])
        XCTAssertTrue(saved)
        let log = try XCTUnwrap(ui.quickLogs.first)
        let reopened = AppModel(live: false)
        reopened.loadQuickLogTechniques(account: "alice", defaults: defaults)
        XCTAssertEqual(reopened.quickLogHitsByID[log.id]?.first?.count, 3)
        reopened.clearLiveData()
        XCTAssertEqual(reopened.quickLogTechniques, QuickLogTechnique.defaults)
        XCTAssertTrue(reopened.quickLogHitsByID.isEmpty)
        reopened.loadQuickLogTechniques(account: "bob", defaults: defaults)
        XCTAssertEqual(reopened.quickLogTechniques, QuickLogTechnique.defaults)
        XCTAssertTrue(reopened.quickLogHitsByID.isEmpty)
        reopened.loadQuickLogTechniques(account: "alice", defaults: defaults)
        XCTAssertEqual(reopened.quickLogTechniques.last, triangle)
        XCTAssertEqual(reopened.quickLogHitsByID[log.id]?.first?.count, 3)
    }

    @MainActor func testEmptyCountsCannotCreateATrainingEntry() async {
        let ui = AppModel(live: false)
        ui.quickLogs = []
        let saved = await ui.addQuickLog(Date(), counts: ["heel-hook": 0])
        XCTAssertFalse(saved)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertTrue(ui.quickLogHitsByID.isEmpty)
        XCTAssertNil(ui.trainingUndo)
    }

    @MainActor func testFailedSaveRetainsListAndDoesNotPersistCounts() async throws {
        let ui = AppModel(live: true), runtime = TrainingRuntimeStub()
        ui.runtime = runtime
        ui.quickTrainingLogBackendAvailable = true
        let triangle = try XCTUnwrap(ui.addQuickLogTechnique("Triangle"))
        let saved = await ui.addQuickLog(Date(), counts: [triangle.id: 2])
        XCTAssertFalse(saved)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertTrue(ui.quickLogHitsByID.isEmpty)
        XCTAssertEqual(ui.quickLogTechniques.last, triangle, "List changes survive a log save failure")
    }

    @MainActor func testUndoLogRemovesCountsButKeepsTheLatestTechniqueList() async throws {
        let ui = AppModel(live: false)
        ui.quickLogs = []
        let triangle = try XCTUnwrap(ui.addQuickLogTechnique("Triangle"))
        let saved = await ui.addQuickLog(Date(), counts: [triangle.id: 1])
        XCTAssertTrue(saved)
        let toast = try XCTUnwrap(ui.toast)
        await ui.undoTrainingToast(toast.id)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertTrue(ui.quickLogHitsByID.isEmpty)
        XCTAssertEqual(ui.quickLogTechniques.last, triangle)
    }

    @MainActor func testPendingSaveCannotWriteCountsIntoANewAccount() async {
        let ui = AppModel(live: true), runtime = TrainingRuntimeStub()
        ui.runtime = runtime
        ui.quickTrainingLogBackendAvailable = true
        let started = expectation(description: "Technique log started")
        var resume: CheckedContinuation<Bool, Never>?
        runtime.command = { _, _ in
            started.fulfill()
            return await withCheckedContinuation { resume = $0 }
        }
        let save = Task { await ui.addQuickLog(Date(), counts: ["heel-hook": 2]) }
        await fulfillment(of: [started], timeout: 1)
        ui.clearLiveData()
        resume?.resume(returning: true)
        let saved = await save.value
        XCTAssertFalse(saved)
        XCTAssertTrue(ui.quickLogHitsByID.isEmpty)
        XCTAssertNil(ui.quickLogAccount)
    }
}

extension TrainingCalendarTests {
    @MainActor func testUnstartedPlanIsDisabledButSeparateQuickLogStillWorks() async {
        let ui = AppModel(live: false)
        let start = Date().addingTimeInterval(60)
        let plan = Session(id: "later", title: "Later rolls", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                           people: [Attendee(id: "me", status: .going)], startsAt: start)
        ui.upcoming = [plan]; ui.completedSessions = []; ui.quickLogs = []; ui.toComplete = nil; ui.drafts = []
        XCTAssertFalse(ui.canMarkTrainingDone(plan, now: start.addingTimeInterval(-1)))
        XCTAssertTrue(ui.canMarkTrainingDone(plan, now: start))
        let saved = await ui.markTrainingDone(plan)
        XCTAssertFalse(saved)
        XCTAssertEqual(ui.upcoming.first, plan)
        let day = TrainingCalendar.calendar.startOfDay(for: Date())
        let logged = await ui.addQuickLog(day)
        XCTAssertTrue(logged)
        XCTAssertEqual(ui.entryCount(day), 1)
        XCTAssertEqual(ui.trainingTap(day), .choose, "The calendar action still offers the open plan after a separate quick log")
        XCTAssertEqual(ui.upcoming.first, plan)
    }

    @MainActor func testCompletionUndoIsUnavailableAfterPublishing() async throws {
        let ui = AppModel(live: false)
        let plan = Session(id: "published", title: "Rolls", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                           people: [Attendee(id: "me", status: .going)], startsAt: Date().addingTimeInterval(-60))
        ui.upcoming = [plan]; ui.completedSessions = []; ui.posts = []; ui.quickLogs = []; ui.toComplete = nil
        await ui.markTrainingDone(plan)
        let id = try XCTUnwrap(ui.toast?.id)
        XCTAssertTrue(ui.canUndoTrainingToast(id))
        XCTAssertNotNil(ui.publish(plan.id, photo: nil, caption: "Good rolls", people: ["me"]))
        XCTAssertFalse(ui.canUndoTrainingToast(id))
        await ui.undoTrainingToast(id)
        XCTAssertEqual(ui.posts.count, 1)
        XCTAssertTrue(ui.completedSessions.contains { $0.id == plan.id })
        XCTAssertTrue(ui.upcoming.isEmpty)
    }

    @MainActor func testFailedQuickLogBlocksDuplicateTapsAndLeavesStateUnchanged() async {
        let ui = AppModel(live: true), runtime = TrainingRuntimeStub()
        ui.runtime = runtime
        ui.quickTrainingLogBackendAvailable = true
        let started = expectation(description: "Save started")
        var resume: CheckedContinuation<Bool, Never>?
        var requests = 0
        runtime.command = { _, _ in
            requests += 1; started.fulfill()
            return await withCheckedContinuation { resume = $0 }
        }
        let day = TrainingCalendar.calendar.startOfDay(for: Date())
        let first = Task { await ui.addQuickLog(day) }
        await fulfillment(of: [started], timeout: 1)
        XCTAssertTrue(ui.savingTraining)
        let duplicate = await ui.addQuickLog(day)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(requests, 1)
        resume?.resume(returning: false)
        let saved = await first.value
        XCTAssertFalse(saved)
        XCTAssertFalse(ui.savingTraining)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertNil(ui.trainingUndo)
        XCTAssertTrue(ui.path.isEmpty)
    }

    @MainActor func testFailedCompletionLeavesPlanOpenAndCreatesNoUndo() async {
        let ui = AppModel(live: true), runtime = TrainingRuntimeStub()
        ui.runtime = runtime
        ui.quickTrainingLogBackendAvailable = true
        let plan = Session(id: "failure", title: "Rolls", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                           people: [Attendee(id: "me", status: .going)], startsAt: Date().addingTimeInterval(-60))
        ui.upcoming = [plan]
        let saved = await ui.markTrainingDone(plan)
        XCTAssertFalse(saved)
        XCTAssertEqual(ui.upcoming.first, plan)
        XCTAssertTrue(ui.completedSessions.isEmpty)
        XCTAssertNil(ui.trainingUndo)
        XCTAssertTrue(ui.path.isEmpty)
    }

    @MainActor func testAccountClearingDiscardsPendingTrainingResult() async {
        let ui = AppModel(live: true), runtime = TrainingRuntimeStub()
        ui.runtime = runtime
        ui.quickTrainingLogBackendAvailable = true
        let started = expectation(description: "Save started")
        var resume: CheckedContinuation<Bool, Never>?
        runtime.command = { _, _ in
            started.fulfill()
            return await withCheckedContinuation { resume = $0 }
        }
        let save = Task { await ui.addQuickLog(Date()) }
        await fulfillment(of: [started], timeout: 1)
        ui.clearLiveData()
        resume?.resume(returning: true)
        let saved = await save.value
        XCTAssertFalse(saved)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertNil(ui.toast)
        XCTAssertNil(ui.trainingUndo)
        XCTAssertFalse(ui.savingTraining)
    }
}

extension TrainingCalendarTests {
    @MainActor func testQuickLogsStayOnActivityAndKeepStartedPlanInComingUp() async {
        let ui = AppModel(live: false)
        let plan = Session(id: "c", title: "Rolls", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                           people: [Attendee(id: "me", status: .going)], startsAt: Date().addingTimeInterval(-60))
        ui.upcoming = [plan]; ui.completedSessions = []; ui.toComplete = nil; ui.posts = []; ui.quickLogs = []; ui.drafts = []; ui.discoverableSessions = []
        ui.setTab(.activity)
        XCTAssertEqual(ui.trainingTap(Date(), isActivity: true), .choose)
        await ui.addQuickLog(Date())
        await ui.addQuickLog(Date())
        XCTAssertEqual(ui.tab, .activity)
        XCTAssertTrue(ui.path.isEmpty)
        XCTAssertTrue(ui.posts.isEmpty)
        XCTAssertEqual(ui.entryCount(Date()), 2)
        XCTAssertEqual(ui.trainedDays(TrainingCalendar.week(Date())), 1)
        XCTAssertEqual(ui.trainingTap(Date()), .choose)
        XCTAssertEqual(ui.trainingTap(Date(), isActivity: true), .choose, "Adding quick logs must not bypass the planned-day chooser")
        XCTAssertEqual(ui.activityPlans().map(\.id), [plan.id])
        await ui.undoTrainingToast(ui.toast!.id)
        XCTAssertEqual(ui.entryCount(Date()), 1)
        XCTAssertEqual(ui.upcoming.first, plan)
        await ui.markTrainingDone(plan)
        XCTAssertTrue(ui.activityPlans().isEmpty)
        XCTAssertEqual(ui.trainingTap(Date()), .entries)
        XCTAssertEqual(ui.trainingTap(Date(), isActivity: true), .quickLog, "After the plan closes, Activity returns to direct quick logging")
    }
}

extension TrainingCalendarTests {
    @MainActor func testStripAddsToConfirmedDayWithoutAllowingUntap() async {
        let ui = AppModel(live: false)
        let day = Date()
        let session = Session(id: "confirmed", title: "Night training", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                              people: [Attendee(id: "me", status: .going, attended: true)], startsAt: day.addingTimeInterval(-60))
        ui.upcoming = []; ui.completedSessions = [session]; ui.toComplete = nil; ui.drafts = []; ui.quickLogs = []; ui.posts = []
        XCTAssertNotNil(ui.publish(session.id, photo: nil, caption: "Good rolls", people: ["me"]))
        await ui.addQuickLog(day)
        await ui.addQuickLog(day)
        XCTAssertEqual(ui.entryCount(day), 3)
        XCTAssertEqual(ui.trainedDays(TrainingCalendar.week(day)), 1)
        XCTAssertFalse(ui.canRemoveQuickLog(on: day))
        let removed = await ui.removeLatestQuickLog(on: day)
        XCTAssertFalse(removed, "A planned-session date is protected even when it also has quick logs")
        XCTAssertEqual(ui.entryCount(day), 3)
        XCTAssertEqual(ui.dayLogs(day).count, 2)
        XCTAssertEqual(ui.daySessions(day).map(\.id), [session.id])
        XCTAssertEqual(ui.posts.count, 1)
        XCTAssertTrue(ui.sharedSessionIDs.contains(session.id))
        XCTAssertTrue(ui.path.isEmpty)
    }

    @MainActor func testStripRemovalDoesNothingOnPlannedDate() async {
        let ui = AppModel(live: false)
        let day = Date()
        let session = Session(id: "planned", title: "Planned rolls", day: "Wed", date: 4, month: "Nov", time: "19:00", gym: "Gym", organizer: "me",
                              people: [Attendee(id: "me", status: .going)], startsAt: day.addingTimeInterval(-60))
        let log = QuickLog(id: "private-log", loggedOn: TrainingCalendar.key(day), loggedAt: day, timezone: TimeZone.current.identifier)
        ui.upcoming = [session]; ui.completedSessions = []; ui.toComplete = nil; ui.drafts = []; ui.quickLogs = [log]
        XCTAssertFalse(ui.canRemoveQuickLog(on: day))
        let removed = await ui.removeLatestQuickLog(on: day)
        XCTAssertFalse(removed)
        XCTAssertEqual(ui.quickLogs, [log])
        XCTAssertEqual(ui.upcoming.first, session)
        XCTAssertEqual(ui.entryCount(day), 1)
    }

    @MainActor func testStripRemovesNewestLogAndClearsOnlyAnEmptyDay() async {
        let ui = AppModel(live: false)
        let day = Date(), key = TrainingCalendar.key(Date())
        let earlier = QuickLog(id: "earlier", loggedOn: key, loggedAt: day.addingTimeInterval(-1), timezone: TimeZone.current.identifier)
        let latest = QuickLog(id: "latest", loggedOn: key, loggedAt: day, timezone: TimeZone.current.identifier)
        ui.upcoming = []; ui.completedSessions = []; ui.toComplete = nil; ui.drafts = []; ui.quickLogs = [earlier, latest]
        await ui.removeLatestQuickLog(on: day)
        XCTAssertEqual(ui.quickLogs, [earlier])
        XCTAssertEqual(ui.entryCount(day), 1)
        await ui.removeLatestQuickLog(on: day)
        XCTAssertEqual(ui.entryCount(day), 0)
        XCTAssertEqual(ui.trainedDays(TrainingCalendar.week(day)), 0)
    }

    @MainActor func testFailedStripRemovalPreservesCounterAndBlocksDuplicateTaps() async {
        let ui = AppModel(live: true), runtime = TrainingRuntimeStub()
        ui.runtime = runtime
        ui.quickTrainingLogBackendAvailable = true
        let day = Date()
        let log = QuickLog(id: "log", loggedOn: TrainingCalendar.key(day), loggedAt: day, timezone: TimeZone.current.identifier)
        ui.quickLogs = [log]
        let started = expectation(description: "Removal started")
        var resume: CheckedContinuation<Bool, Never>?
        var requests = 0
        runtime.command = { operation, _ in
            XCTAssertEqual(operation, "delete_quick_log")
            requests += 1; started.fulfill()
            return await withCheckedContinuation { resume = $0 }
        }
        let first = Task { await ui.removeLatestQuickLog(on: day) }
        await fulfillment(of: [started], timeout: 1)
        let duplicate = await ui.removeLatestQuickLog(on: day)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(requests, 1)
        resume?.resume(returning: false)
        let removed = await first.value
        XCTAssertFalse(removed)
        XCTAssertEqual(ui.quickLogs, [log])
        XCTAssertEqual(ui.entryCount(day), 1)
        XCTAssertFalse(ui.savingTraining)
    }
}

#if DEBUG
extension TrainingCalendarTests {
    @MainActor func testQuickLogMockSeedsCompletedAndSharedStates() throws {
        let mock = AppModel.quickTrainingLogMock(.hostPlan)
        let open = try XCTUnwrap(mock.findSession("mock-today"))
        let completed = try XCTUnwrap(mock.findSession("mock-completed"))
        let shared = try XCTUnwrap(mock.findSession("mock-shared"))
        let post = try XCTUnwrap(mock.posts.first { $0.id == "mock-shared-post" })
        XCTAssertTrue(mock.canCompleteTraining(open))
        XCTAssertNil(mock.trainingCompletionStatus(open))
        XCTAssertFalse(mock.canCompleteTraining(completed))
        XCTAssertEqual(mock.trainingCompletionStatus(completed), .completed)
        XCTAssertFalse(mock.canCompleteTraining(shared))
        XCTAssertEqual(mock.trainingCompletionStatus(shared), .completed)
        XCTAssertEqual(post.title, shared.title)
        XCTAssertEqual(post.occurredAt, shared.startsAt)
        XCTAssertEqual(post.participants, shared.going)
        mock.sharedSessionIDs = []
        mock.loadQuickLogMock(.hostPlan)
        XCTAssertEqual(mock.trainingCompletionStatus(shared), .completed, "Reset restores the completed state for a shared session")
        XCTAssertEqual(mock.posts.filter { $0.id == "mock-shared-post" }.count, 1)
    }

    @MainActor func testPromptAndQuickLogMockKeepsPlanUntilCompletion() async throws {
        let mock = AppModel.quickTrainingLogMock(.upcomingPrompt)
        let now = Date()
        let first = try XCTUnwrap(mock.quickLogActivityPrompt(keeping: nil, now: now))
        XCTAssertEqual(first.id, "mock-today", "Start with the closest upcoming training")
        XCTAssertGreaterThan(mock.startDate(of: first), now)
        mock.activityQuickLogPromptID = first.id
        let before = mock.entryCount(now)
        let logged = await mock.addQuickLog(now)
        XCTAssertTrue(logged)
        XCTAssertEqual(mock.entryCount(now), before + 1)
        XCTAssertEqual(mock.quickLogActivityPrompt(keeping: mock.activityQuickLogPromptID)?.id, first.id)
        XCTAssertNil(mock.trainingCompletionStatus(first), "A quick tap keeps the planned session open")

        mock.startMockPromptPlan()
        let started = try XCTUnwrap(mock.findSession(first.id))
        XCTAssertTrue(mock.canMarkTrainingDone(started))
        // Even much later, retain the current plan instead of jumping to a closer future one.
        let later = mock.startDate(of: try XCTUnwrap(mock.findSession("mock-future"))).addingTimeInterval(-1)
        XCTAssertEqual(mock.quickLogActivityPrompt(keeping: first.id, now: later)?.id, first.id)
        let completed = await mock.markTrainingDone(started)
        XCTAssertTrue(completed)
        XCTAssertEqual(mock.quickLogActivityPrompt(keeping: first.id)?.id, "mock-future")
        XCTAssertFalse(mock.isLive)
        XCTAssertNil(mock.runtime)

        let revision = mock.quickLogMockRevision
        mock.loadQuickLogMock(.upcomingPrompt)
        XCTAssertNotEqual(mock.quickLogMockRevision, revision)
        XCTAssertNil(mock.activityQuickLogPromptID)
        XCTAssertEqual(mock.quickLogActivityPrompt(keeping: nil)?.id, "mock-today")
    }

    @MainActor func testQuickLogMockRunsLocallyAndResetRestoresFixtures() async {
        let mock = AppModel.quickTrainingLogMock(.quickLogs)
        let day = Date(), posts = mock.posts
        XCTAssertFalse(mock.isLive)
        XCTAssertNil(mock.runtime)
        XCTAssertTrue(mock.isSignedIn)
        XCTAssertEqual(mock.tab, .activity)
        XCTAssertFalse(mock.shouldAskForMonkey)
        XCTAssertEqual(mock.entryCount(day), 2)
        XCTAssertTrue(mock.canRemoveQuickLog(on: day))
        await mock.addQuickLog(day)
        XCTAssertEqual(mock.entryCount(day), 3)
        await mock.removeLatestQuickLog(on: day)
        XCTAssertEqual(mock.entryCount(day), 2)
        XCTAssertEqual(mock.posts, posts)
        mock.go(.session(id: "mock-completed"))
        mock.loadQuickLogMock(.quickLogs)
        XCTAssertEqual(mock.entryCount(Date()), 2)
        XCTAssertEqual(mock.posts.count, posts.count)
        XCTAssertTrue(mock.path.isEmpty)
        XCTAssertNil(mock.toast)
        XCTAssertNil(mock.runtime)
    }

    @MainActor func testQuickLogMockHostAndGuestCompletionAreLocal() async throws {
        for scenario in [QuickLogMockScenario.hostPlan, .guestPlan] {
            let mock = AppModel.quickTrainingLogMock(scenario)
            let plan = try XCTUnwrap(mock.openPlans(Date()).first)
            let before = mock.posts.count
            XCTAssertNil(mock.runtime)
            XCTAssertTrue(mock.canMarkTrainingDone(plan))
            let saved = await mock.markTrainingDone(plan)
            XCTAssertTrue(saved)
            XCTAssertEqual(mock.posts.count, before, "Attendance never auto-publishes")
            let done = try XCTUnwrap(mock.findSession(plan.id))
            XCTAssertTrue(done.people.first { $0.id == "me" }!.attended)
            if scenario == .hostPlan {
                XCTAssertTrue(done.people.allSatisfy(\.attended))
                XCTAssertNotNil(mock.publish(plan.id, photo: nil, caption: "Good rolls", people: plan.going))
                XCTAssertEqual(mock.posts.count, before + 1)
            } else {
                XCTAssertFalse(done.people.first { $0.id == "kenji" }!.attended)
                XCTAssertNil(mock.publish(plan.id, photo: nil, caption: "Good rolls", people: plan.going))
                let removed = await mock.removeOwnTrainingAttendance(done)
                XCTAssertTrue(removed)
                XCTAssertTrue(mock.daySessions(Date()).isEmpty)
            }
            mock.loadQuickLogMock(scenario)
            XCTAssertEqual(mock.posts.count, before)
            XCTAssertTrue(mock.canMarkTrainingDone(try XCTUnwrap(mock.openPlans(Date()).first)))
        }
    }

    @MainActor func testQuickLogMockStartsLaterAndCannotLoadIntoLiveModel() throws {
        let mock = AppModel.quickTrainingLogMock(.startsLater)
        let plan = try XCTUnwrap(mock.openPlans(Date()).first)
        XCTAssertFalse(mock.canMarkTrainingDone(plan))
        XCTAssertGreaterThan(try XCTUnwrap(plan.startsAt), Date())
        let live = AppModel(live: true)
        live.me.name = "Live account"
        live.loadQuickLogMock(.quickLogs)
        XCTAssertTrue(live.isLive)
        XCTAssertEqual(live.me.name, "Live account")
        XCTAssertTrue(live.posts.isEmpty)
        XCTAssertTrue(live.quickLogs.isEmpty)
        XCTAssertFalse(live.isSignedIn)
    }
}
#endif

final class ProfileHeatmapTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    func testGridHasSeventeenMondayWeeksAndCountsDaysOnce() {
        let now = date("2026-11-05T04:00:00Z") // Wednesday evening in Los Angeles.
        let history = ProfileRhythmHistory(dates: [date("2026-11-04T16:00:00Z"), date("2026-11-05T02:00:00Z"), date("2026-11-03T16:00:00Z")], now: now, calendar: calendar)
        XCTAssertEqual(history.weeks.count, 17)
        XCTAssertEqual(history.weeks.flatMap { $0 }.count, 119)
        XCTAssertEqual(history.weeks.first?.first, date("2026-07-13T07:00:00Z"))
        XCTAssertEqual(history.visibleCount, 2, "Multiple sessions on the same local day fill only one square")
        XCTAssertTrue(history.isFuture(date("2026-11-05T20:00:00Z")))
        XCTAssertFalse(history.isFuture(date("2026-11-04T23:00:00Z")))
    }
    func testCalendarDaysSurviveDaylightSavingAndYearBoundary() {
        let history = ProfileRhythmHistory(dates: [date("2026-11-01T08:30:00Z"), date("2026-11-01T09:30:00Z")], now: date("2026-11-03T20:00:00Z"), calendar: calendar)
        XCTAssertEqual(history.visibleCount, 1, "The repeated DST hour is still one local day")
        XCTAssertTrue(history.weeks.allSatisfy { $0.count == 7 })
        let newYear = ProfileRhythmHistory(dates: [], now: date("2027-01-01T20:00:00Z"), calendar: calendar)
        XCTAssertEqual(newYear.weeks.last?.first, date("2026-12-28T08:00:00Z"))
    }
    func testUnsharedAndPhotoFreeSessionsCountButExcludedAttendanceDoesNot() {
        let now = date("2026-11-05T20:00:00Z")
        var record = RhythmSession(id: "log", starts_at: "2026-11-04T19:00:00Z", status: "planned", organizer: "me",
                                   session_participants: [.init(user_id: "me", rsvp: "going", attended: false)])
        XCTAssertNotNil(record.loggedDate(for: "me", now: now), "A past session log does not require completion, a post or a photo")
        record.status = "completed"
        XCTAssertNil(record.loggedDate(for: "me", now: now), "A correction removes an unattended completed session")
        record.session_participants[0].attended = true
        XCTAssertNotNil(record.loggedDate(for: "me", now: now))
        for rsvp in ["invited", "declined"] {
            record.session_participants[0].rsvp = rsvp
            XCTAssertNil(record.loggedDate(for: "me", now: now))
        }
        record.session_participants[0].rsvp = "going"; record.status = "cancelled"
        XCTAssertNil(record.loggedDate(for: "me", now: now))
        record.status = "planned"; record.starts_at = "2026-11-06T19:00:00Z"
        XCTAssertNil(record.loggedDate(for: "me", now: now), "Future plans do not count")
        XCTAssertNil(record.loggedDate(for: "someone-else", now: now))
    }
    @MainActor func testRuntimeUsesFullHistoryOutsideTheScheduleAndFeedPages() throws {
        let model = SocialAppModel(); model.userID = "owner"
        let now = date("2026-11-05T20:00:00Z")
        model.snapshot.rhythm_sessions = [RhythmSession(id: "unshared", starts_at: "2026-11-04T19:00:00Z", status: "planned", organizer: "owner",
                                                       session_participants: [.init(user_id: "owner", rsvp: "going", attended: false)])]
        let ui = AppModel(live: true)
        let runtime = LiveMatMindRuntime(model: model, ui: ui)
        runtime.sync(now: now)
        XCTAssertTrue(ui.posts.isEmpty); XCTAssertTrue(ui.upcoming.isEmpty)
        XCTAssertEqual(ui.trainingRhythm(now: now, calendar: calendar).visibleCount, 1)
        ui.clearLiveData()
        XCTAssertEqual(ui.trainingRhythm(now: now, calendar: calendar).visibleCount, 0)
    }
    func testReadQueryIsOwnerScopedAndBounded() throws {
        let path = BackendClient.rhythmPath(owner: "owner", from: date("2026-07-13T07:00:00Z"), through: date("2026-11-05T20:00:00Z"), offset: 200, pageSize: 200)
        let parts = try XCTUnwrap(URLComponents(string: "https://example.com/" + path))
        let items = parts.queryItems ?? []
        XCTAssertEqual(parts.path, "/rest/v1/sessions")
        XCTAssertEqual(items.first { $0.name == "session_participants.user_id" }?.value, "eq.owner")
        XCTAssertEqual(items.first { $0.name == "session_participants.rsvp" }?.value, "eq.going")
        XCTAssertEqual(items.filter { $0.name == "starts_at" }.count, 2)
        XCTAssertEqual(items.first { $0.name == "offset" }?.value, "200")
        XCTAssertFalse(path.contains("posts")); XCTAssertFalse(path.contains("media"))
    }
}

extension BackendSessionTests {
    func testHeatmapReadPaginatesBeyondTheScheduleLimitWithoutWrites() async throws {
        let rows = (0..<205).map { index in
            RhythmSession(id: "s\(index)", starts_at: "2026-11-04T12:00:00Z", status: "planned", organizer: "owner",
                          session_participants: [.init(user_id: "owner", rsvp: "going", attended: false)])
        }
        let fixture = BackendHTTPFixture(failureStatus: 401, failureBody: Data(), rhythmRows: rows)
        let credential = CloudCredential(access_token: "fresh-token", refresh_token: "refresh", user: CloudUser(id: "owner"), expires_at: Date().timeIntervalSince1970 + 3600)
        let (client, _) = try makeClient(credential: credential, fixture: fixture)
        let result = try await client.rhythmSessions(owner: "owner")
        XCTAssertEqual(result.count, 205)
        let requests = await fixture.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.allSatisfy { $0.httpMethod == "GET" && $0.url?.path == "/rest/v1/sessions" })
        let offsets = requests.map { URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "offset" }?.value }
        XCTAssertEqual(offsets, ["0", "200"])
    }
}


extension TrainingCalendarTests {
    @MainActor func testQuickLogPlanSelectionWaitsForExplicitCompletion() async throws {
        let ui = AppModel(live: false)
        let plan = Session(id: "quick-log-plan", title: "Open training", day: "Thu", date: 5, month: "Nov", time: "16:30", gym: "Ralph Gracie", organizer: "me",
                           people: [Attendee(id: "me", status: .going), Attendee(id: "kenji", status: .going), Attendee(id: "sarah", status: .invited)],
                           note: "Work on guard retention", focusItems: [TrainingFocus(title: "Frames")], startsAt: Date().addingTimeInterval(-60))
        ui.upcoming = [plan]; ui.completedSessions = []; ui.posts = []; ui.quickLogs = []; ui.toComplete = nil; ui.drafts = []
        ui.path = []

        XCTAssertTrue(ui.openQuickLogPlan(plan))
        XCTAssertEqual(ui.path, [.complete(id: plan.id)])
        XCTAssertEqual(ui.findSession(plan.id), plan)
        XCTAssertNil(ui.trainingCompletionStatus(plan))
        XCTAssertNil(ui.toast)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertTrue(ui.completedSessions.isEmpty)
        XCTAssertTrue(ui.posts.isEmpty)
        ui.back()
        XCTAssertEqual(ui.findSession(plan.id), plan, "Closing the composer leaves the plan unchanged")

        XCTAssertTrue(ui.openQuickLogPlan(plan))
        let saved = await ui.saveSessionPhoto(plan.id, photo: "training-photo")
        XCTAssertTrue(saved)
        var withPhoto = plan
        withPhoto.photos = ["training-photo"]
        XCTAssertEqual(ui.findSession(plan.id), withPhoto, "Saving a photo must preserve all plan details and attendance")
        XCTAssertNil(ui.trainingCompletionStatus(plan))
        XCTAssertTrue(ui.posts.isEmpty)
        ui.back()
        XCTAssertTrue(ui.openQuickLogPlan(plan), "A photo alone does not complete the plan")
        let result = try XCTUnwrap(ui.publish(plan.id, photo: "training-photo", caption: "", people: plan.going))
        XCTAssertEqual(result.post.photo, "training-photo")
        XCTAssertEqual(result.post.focusItems, plan.focusItems)
        XCTAssertEqual(ui.completedSessions.count, 1)
        XCTAssertEqual(ui.completedSessions.first?.id, plan.id)
        XCTAssertEqual(ui.completedSessions.first?.note, plan.note)
        XCTAssertEqual(ui.completedSessions.first?.startsAt, plan.startsAt)
        XCTAssertEqual(ui.completedSessions.first?.gym, plan.gym)
        XCTAssertEqual(ui.completedSessions.first?.people.filter(\.attended).map(\.id), ["me", "kenji"])
        XCTAssertEqual(ui.posts.count, 1)
        XCTAssertTrue(ui.quickLogs.isEmpty)
        XCTAssertTrue(ui.upcoming.isEmpty)
        XCTAssertEqual(ui.trainingCompletionStatus(plan), .completed)
        XCTAssertFalse(ui.canCompleteTraining(plan))
        XCTAssertFalse(ui.openQuickLogPlan(plan))
    }

    @MainActor func testLiveQuickLogPlanSelectionOnlyNavigatesForHostAndGuest() {
        let ui = AppModel(live: true), runtime = TrainingRuntimeStub()
        ui.runtime = runtime
        ui.quickTrainingLogBackendAvailable = true
        var writes = 0
        runtime.command = { _, _ in writes += 1; return true }
        var plan = Session(id: "live-plan", title: "Rolls", day: "Thu", date: 5, month: "Nov", time: "16:30", gym: "Gym", organizer: "me",
                           people: [Attendee(id: "me", status: .going), Attendee(id: "kenji", status: .going)], startsAt: Date().addingTimeInterval(-60))
        for organizer in ["me", "kenji"] {
            plan.organizer = organizer
            ui.upcoming = [plan]; ui.completedSessions = []; ui.toComplete = nil; ui.drafts = []; ui.path = []
            XCTAssertTrue(ui.openQuickLogPlan(plan))
            XCTAssertEqual(ui.path, [organizer == "me" ? .complete(id: plan.id) : .session(id: plan.id)])
            XCTAssertEqual(ui.upcoming, [plan])
            XCTAssertTrue(ui.completedSessions.isEmpty)
            XCTAssertNil(ui.trainingCompletionStatus(plan))
            XCTAssertNil(ui.trainingUndo)
            XCTAssertFalse(ui.savingTraining)
        }
        XCTAssertEqual(writes, 0, "Selecting a plan must never issue an attendance or creation command")
    }

    @MainActor func testQuickLogPlanSelectionRevalidatesCurrentSession() {
        let ui = AppModel(live: false)
        let now = Date()
        let plan = Session(id: "edited-plan", title: "Rolls", day: "Thu", date: 5, month: "Nov", time: "16:30", gym: "Gym", organizer: "me",
                           people: [Attendee(id: "me", status: .going)], startsAt: now.addingTimeInterval(-60))
        ui.upcoming = [plan]; ui.completedSessions = []; ui.toComplete = nil; ui.drafts = []; ui.path = []
        ui.upcoming[0].startsAt = now.addingTimeInterval(60)
        XCTAssertFalse(ui.openQuickLogPlan(plan, now: now))
        ui.upcoming = [plan]
        ui.upcoming[0].people[0].status = .declined
        XCTAssertFalse(ui.openQuickLogPlan(plan, now: now))
        ui.upcoming = [plan]
        ui.sharedSessionIDs.insert(plan.id)
        XCTAssertFalse(ui.openQuickLogPlan(plan, now: now))
        ui.sharedSessionIDs = []
        ui.upcoming = []
        XCTAssertFalse(ui.openQuickLogPlan(plan, now: now))
        XCTAssertTrue(ui.path.isEmpty)
    }
}
