import XCTest
@testable import IntentionalTrainingNotes

final class LegacyArchiveTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("archive-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories:true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at:root) }
    private func repository() -> LegacyArchiveRepository { LegacyArchiveRepository(sourceRoot:root.appendingPathComponent("accounts"),vaultRoot:root.appendingPathComponent("vault")) }
    private func source(_ data:Data, account:String="local") throws -> URL {
        let dir=root.appendingPathComponent("accounts/"+account)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        try data.write(to:dir.appendingPathComponent("notebook.json")); return dir
    }
    private func fixture() throws -> Data {
        let date=ISO8601DateFormatter().date(from:"2026-03-08T10:15:00Z")!
        let goal=TrainingGoal(id:"g",accountId:"local",name:"Guard",createdAt:date,updatedAt:date)
        let task=TrainingTask(id:"t",goalId:"g",name:"Frame",imageFileNames:["present.jpg","missing.jpg"],createdAt:date,updatedAt:date)
        let session=PlannedSession(id:"s",goalId:"g",date:date,taskIds:["t"],createdAt:date,updatedAt:date)
        let reflection=Reflection(id:"r",sessionId:"s",date:date,workedText:"Worked",stuckText:"Stuck",mood:.good,createdAt:date,updatedAt:date)
        let note=Note(id:"n",title:"Note",body:"Private",createdAt:date,updatedAt:date)
        let bounty=Bounty(id:"b",accountId:"local",goalId:"g",taskId:"t",kind:.hitCount,hitDates:[date],createdAt:date)
        let competition=Competition(id:"c",accountId:"local",name:"Open",date:date,draws:2,createdAt:date,updatedAt:date)
        let book=TrainingNotebook(accountId:"local",goals:[goal],tasks:[task],sessions:[session],reflections:[reflection],notes:[note],bounties:[bounty],competitions:[competition])
        let encoder=JSONEncoder();encoder.dateEncodingStrategy = .iso8601
        var object=try JSONSerialization.jsonObject(with:encoder.encode(book)) as! [String:Any]
        object["access_token"]="NEVER-EXPORT-THIS"; object["unrelatedAccount"]=["secret":"NO"]
        return try JSONSerialization.data(withJSONObject:object,options:.sortedKeys)
    }
    func testMigrationIsIdempotentPreservesRecordsRelationshipsDatesAndFiles() async throws {
        let bytes=try fixture();let src=try source(bytes)
        let images=src.appendingPathComponent("task-images/t")
        try FileManager.default.createDirectory(at:images,withIntermediateDirectories:true)
        try Data([1,2,3]).write(to:images.appendingPathComponent("present.jpg"))
        try Data([4,5]).write(to:images.appendingPathComponent("orphan.jpg"))
        let repo=repository()
        let first=try await repo.migrate(account:"local")!
        let second=try await repo.migrate(account:"local")!
        XCTAssertEqual(first.directory,second.directory)
        XCTAssertEqual(first.document.counts,Dictionary(uniqueKeysWithValues:ArchiveDocument.categories.map{($0,1)}))
        XCTAssertEqual(first.document.records["sessions"]?.first?.fields["taskIds"]?.strings,["t"])
        XCTAssertEqual(first.document.records["competitions"]?.first?.fields["draws"],.number(2))
        XCTAssertEqual(try Data(contentsOf:src.appendingPathComponent("notebook.json")),bytes)
        XCTAssertEqual(try Data(contentsOf:first.directory.appendingPathComponent("backup/notebook.json")),bytes)
        XCTAssertEqual(try Data(contentsOf:first.directory.appendingPathComponent("backup/task-images/t/present.jpg")),Data([1,2,3]))
        XCTAssertTrue(FileManager.default.fileExists(atPath:first.directory.appendingPathComponent("backup/task-images/t/orphan.jpg").path))
        XCTAssertEqual(first.manifest.attachments.filter(\.missing).count,1)
        XCTAssertFalse(first.manifest.warnings.isEmpty)
        let raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        XCTAssertEqual(first.document.records["sessions"]?.first?.fields["date"]?.string,(raw["sessions"] as! [[String:Any]])[0]["date"] as? String)
    }
    func testLegacyDayPrecisionIsPreserved() async throws {
        let data=Data(#"{"focuses":[{"id":"f","name":"Focus","isArchived":false,"createdAt":"2024-01-02","updatedAt":"2024-01-02"}],"tasks":[{"id":"t","focusId":"f","name":"Task","createdAt":"2024-01-02","updatedAt":"2024-01-02"}],"entries":[{"id":"e","focusId":"f","date":"2024-01-03","taskIds":["t"],"stuckText":"Late","mood":null,"createdAt":"2024-01-03","updatedAt":"2024-01-03"}]}"#.utf8)
        _=try source(data)
        let archive=try await repository().migrate(account:"local")!
        XCTAssertEqual(archive.document.records["sessions"]?.first?.fields["date"],.string("2024-01-03"))
        XCTAssertEqual(archive.document.records["reflections"]?.first?.fields["sessionId"],.string("e"))
        XCTAssertEqual(archive.document.records["tasks"]?.first?.fields["goalId"],.string("f"))
    }
    func testNewEmptyAndDemoUsersHaveNoArchive() async throws {
        let repo=repository(); let discovered=try await repo.discover();XCTAssertTrue(discovered.isEmpty)
        let encoder=JSONEncoder();encoder.dateEncodingStrategy = .iso8601
        _=try source(encoder.encode(TrainingNotebook()),account:"empty")
        let empty=try await repo.migrate(account:"empty");XCTAssertNil(empty)
        let goal=TrainingGoal(id:"seed-g1",accountId:"demo",name:"Closed Guard")
        _=try source(encoder.encode(TrainingNotebook(accountId:"demo",goals:[goal])),account:"demo")
        let demo=try await repo.migrate(account:"demo");XCTAssertNil(demo)
    }
    func testCorruptAndUnknownJSONNeverBecomeEmptyArchive() async throws {
        for bytes in [Data("not json".utf8),Data("{}".utf8),Data(#"{"sessions":"broken"}"#.utf8),Data(#"{"schemaVersion":99,"goals":[]}"#.utf8)] {
            let dir=try source(bytes)
            do {_=try await repository().migrate(account:"local");XCTFail("Corrupt data was accepted")}catch{}
            XCTAssertEqual(try Data(contentsOf:dir.appendingPathComponent("notebook.json")),bytes)
        }
    }
    func testMissingAttachmentCanBeRecoveredOnRetry() async throws {
        let src=try source(fixture());let repo=repository()
        let first=try await repo.migrate(account:"local")!
        let folder=src.appendingPathComponent("task-images/t")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        try Data([7]).write(to:folder.appendingPathComponent("missing.jpg"))
        let recovered=try await repo.migrate(account:"local")!
        XCTAssertNotEqual(first.directory,recovered.directory)
        XCTAssertEqual(recovered.manifest.attachments.filter(\.missing).count,1)
    }
    func testExportIsZIPAndContainsNoCredentialsOrOtherAccount() async throws {
        _=try source(fixture());_=try source(fixture(),account:"other")
        let repo=repository();let archive=try await repo.migrate(account:"local")!
        let zip=try await repo.export(archive,temporaryRoot:root)
        let bytes=try Data(contentsOf:zip)
        XCTAssertEqual(Array(bytes.prefix(4)),[0x50,0x4b,0x03,0x04])
        let text=String(decoding:bytes,as:UTF8.self)
        XCTAssertTrue(text.contains("training-v1.json"));XCTAssertTrue(text.contains("README.txt"))
        XCTAssertFalse(text.contains("NEVER-EXPORT-THIS"));XCTAssertFalse(text.contains("unrelatedAccount"))
        await repo.cleanupExport(zip,temporaryRoot:root)
        XCTAssertFalse(FileManager.default.fileExists(atPath:zip.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath:archive.directory.appendingPathComponent("archive.json").path))
    }
    func testPathTraversalAndSymlinksFailWithoutTouchingSource() async throws {
        let src=try source(fixture());let outside=root.appendingPathComponent("outside");try Data([1]).write(to:outside)
        let folder=src.appendingPathComponent("task-images/t");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        try FileManager.default.createSymbolicLink(at:folder.appendingPathComponent("present.jpg"),withDestinationURL:outside)
        do {_=try await repository().migrate(account:"local");XCTFail("Symlink accepted")}catch{}
        do {_=try await repository().migrate(account:"../outside");XCTFail("Traversal accepted")}catch{}
        XCTAssertEqual(try Data(contentsOf:outside),Data([1]))
    }
    @MainActor func testArchiveIsolationIsIndependentOfCloudIdentity() async throws {
        _=try source(fixture(),account:"other-provider")
        let model=LocalArchiveModel(repository:repository(),previousLocalAccount:nil)
        await model.discover();XCTAssertTrue(model.archives.isEmpty)
        let owner=LocalArchiveModel(repository:repository(),previousLocalAccount:"other-provider")
        await owner.discover();XCTAssertEqual(owner.archives.count,1)
    }
    func testReflectionAttachmentsUseExistingSessionFolderLayout() async throws {
        var object = try JSONSerialization.jsonObject(with: fixture()) as! [String: Any]
        var reflections = object["reflections"] as! [[String: Any]]
        reflections[0]["imageFileNames"] = ["reflection.jpg"]
        object["reflections"] = reflections
        let src = try source(JSONSerialization.data(withJSONObject: object))
        let dir = src.appendingPathComponent("reflection-images/s")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data([9,8,7]).write(to: dir.appendingPathComponent("reflection.jpg"))
        let archive = try await repository().migrate(account: "local")!
        let attachment = archive.manifest.attachments.first { $0.category == "reflections" }
        XCTAssertEqual(attachment?.path, "reflection-images/s/reflection.jpg")
        XCTAssertEqual(attachment?.recordID, "r")
        XCTAssertEqual(attachment?.missing, false)
    }
    func testPartialMigrationResumesAndPreservesSource() async throws {
        let bytes = try fixture()
        let sourceURL = try source(bytes).appendingPathComponent("notebook.json")
        let repo = repository()
        let first = try await repo.migrate(account:"local")!
        let pending = first.directory.deletingLastPathComponent().appendingPathComponent(first.directory.lastPathComponent + ".pending")
        try FileManager.default.moveItem(at: first.directory, to: pending)
        try FileManager.default.removeItem(at: pending.appendingPathComponent("archive.json"))
        let resumed = try await repo.migrate(account:"local")!
        XCTAssertTrue(resumed.manifest.verified)
        XCTAssertFalse(FileManager.default.fileExists(atPath:pending.path))
        XCTAssertEqual(try Data(contentsOf:sourceURL),bytes)
    }
    func testTamperingWithVerifiedArchiveIsDetected() async throws {
        _=try source(fixture());let repo=repository();let archive=try await repo.migrate(account:"local")!
        var doc=archive.document;doc.records["goals"]![0].fields["name"] = .string("Tampered")
        try JSONEncoder().encode(doc).write(to:archive.directory.appendingPathComponent("archive.json"))
        do {_=try await repo.export(archive,temporaryRoot:root);XCTFail("Tampered archive exported")}catch{}
    }

    func testExportedNotebookImportsActiveGoalsWithTaskDetailsAndPhotos() async throws {
        let date = ISO8601DateFormatter().date(from: "2026-03-08T10:15:00Z")!
        let active = TrainingGoal(id: "g1", accountId: "local", name: "Single leg", createdAt: date, updatedAt: date)
        let archived = TrainingGoal(id: "g2", accountId: "local", name: "Old guard", isArchived: true, createdAt: date, updatedAt: date)
        let task = TrainingTask(id: "t1", goalId: "g1", name: "Level change", notes: "Head inside\nEar on hip",
                                link: "https://example.com/single-leg", imageFileNames: ["grip.jpg"], createdAt: date, updatedAt: date)
        let session = PlannedSession(id: "s1", goalId: "g1", date: date, taskIds: ["t1"], createdAt: date, updatedAt: date)
        let book = TrainingNotebook(accountId: "local", goals: [active, archived], tasks: [task], sessions: [session])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let src = try source(encoder.encode(book))
        let images = src.appendingPathComponent("task-images/t1")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try Data([9, 8, 7]).write(to: images.appendingPathComponent("grip.jpg"))

        // The same file a person saves from Settings → Export local sessions.
        let repo = repository()
        let archive = try await repo.migrate(account: "local")!
        let zip = try await repo.export(archive, temporaryRoot: root.appendingPathComponent("exports"))
        let photos = root.appendingPathComponent("goal-photos")
        let imported = try LegacyGoalImporter.read(zip, photoRoot: photos)

        XCTAssertEqual(imported.archivedSkipped, 1)
        XCTAssertEqual(imported.goals.count, 1, "Archived goals and sessions are not imported")
        let goal = try XCTUnwrap(imported.goals.first)
        XCTAssertEqual(goal.id, "legacy-g1")
        XCTAssertEqual(goal.title, "Single leg")
        XCTAssertEqual(goal.notes, "- Level change: Head inside Ear on hip")
        XCTAssertEqual(goal.links, ["https://example.com/single-leg"])
        XCTAssertEqual(goal.photos, ["legacy-g1/t1-grip.jpg"])
        XCTAssertEqual(try Data(contentsOf: photos.appendingPathComponent("legacy-g1/t1-grip.jpg")), Data([9, 8, 7]))

        let counts = await MainActor.run { () -> (Int, Int) in
            let model = AppModel(live: false)
            return (model.importGoals(imported.goals), model.importGoals(imported.goals))
        }
        XCTAssertEqual(counts.0, 1)
        XCTAssertEqual(counts.1, 0, "Importing the same export twice adds nothing")
    }

    func testGoalImportRefusesFilesThatAreNotNotebookExports() throws {
        let file = root.appendingPathComponent("random.json")
        try Data(#"{"hello":"world"}"#.utf8).write(to: file)
        XCTAssertThrowsError(try LegacyGoalImporter.read(file, photoRoot: root))
    }
}

final class InvitationLinkTests: XCTestCase {
    func testProductionConfigurationGeneratesLinksOnThePublishedHost() throws {
        let host = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "AppLinkHost") as? String)
        let enabled = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "AppLinksEnabled") as? Bool)
        XCTAssertEqual(host, "matmonkey.lovable.app")
        XCTAssertTrue(enabled)
        let token = String(repeating: "a", count: 64)
        for kind in ["friend", "session", "goal"] {
            let link = InvitationLinks.make(kind: kind, token: token, host: host, httpsEnabled: enabled)
            XCTAssertEqual(link.absoluteString, "https://matmonkey.lovable.app/" + kind + "/" + token)
        }
    }

    func testWebsiteReadinessControlsHTTPSGeneration() {
        let token = String(repeating: "a", count: 64)
        for kind in ["friend", "session", "goal"] {
            let development = InvitationLinks.make(kind: kind, token: token, host: "matmonkey.lovable.app", httpsEnabled: false)
            XCTAssertEqual(development.absoluteString, "matmind://" + kind + "/" + token)
            let published = InvitationLinks.make(kind: kind, token: token, host: "matmonkey.lovable.app", httpsEnabled: true)
            XCTAssertEqual(published.absoluteString, "https://matmonkey.lovable.app/" + kind + "/" + token)
        }
        XCTAssertEqual(InvitationLinks.make(kind: "friend", token: token, host: nil, httpsEnabled: true).scheme, "matmind")
    }

    func testInvitationParsingUsesExactRoutesAndNormalizesTokens() throws {
        let token = String(repeating: "a1", count: 32)
        for kind in ["friend", "session", "goal"] {
            for prefix in ["matmind://", "https://matmonkey.lovable.app/"] {
                let url = try XCTUnwrap(URL(string: prefix + kind + "/" + token.uppercased()))
                XCTAssertEqual(InvitationLinks.parse(url, host: "matmonkey.lovable.app"),
                               InvitationLinks.Destination(kind: kind, token: token))
            }
        }
        for value in ["https://example.com/session/" + token,
                      "https://matmindbjj.lovable.app/session/" + token,
                      "https://matmonkey.lovable.app/session/extra/" + token,
                      "https://matmonkey.lovable.app/session//" + token,
                      "https://attacker@matmonkey.lovable.app/session/" + token,
                      "matmind://session/extra/" + token,
                      "matmind://auth/" + token,
                      "matmind://session/" + String(repeating: "１", count: 64),
                      "matmind://session/abc"] {
            XCTAssertNil(InvitationLinks.parse(try XCTUnwrap(URL(string: value)), host: "matmonkey.lovable.app"), value)
        }
    }
}
