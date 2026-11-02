import Foundation
import CryptoKit

/// Lossless JSON values: date strings are never parsed or reformatted for storage.
indirect enum ArchiveValue: Codable, Equatable {
    case string(String), number(Double), bool(Bool), array([ArchiveValue]), object([String: ArchiveValue]), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let a = try? c.decode([ArchiveValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: ArchiveValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b): try c.encode(b)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        case .null: try c.encodeNil()
        }
    }
    var string: String? { if case .string(let s) = self { return s }; return nil }
    var strings: [String] { if case .array(let a) = self { return a.compactMap(\.string) }; return [] }
    var display: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(format: "%.0f", n) : String(n)
        case .bool(let b): return b ? "Yes" : "No"
        case .array(let a): return a.map(\.display).joined(separator: "\n")
        case .object(let o): return o.keys.sorted().map { "\($0): \(o[$0]!.display)" }.joined(separator: "\n")
        case .null: return "—"
        }
    }
}

struct ArchiveRecord: Codable, Identifiable, Equatable {
    var fields: [String: ArchiveValue]
    var id: String { fields["id"]?.string ?? "" }
    var title: String { fields["name"]?.string ?? fields["title"]?.string ?? id }
}
struct ArchiveDocument: Codable, Equatable {
    var formatVersion = 1
    var sourceSchemaVersion: Int
    var datePolicy = "Source date strings and precision preserved. No inferred session times."
    var records: [String: [ArchiveRecord]]
    var counts: [String: Int] { records.mapValues(\.count) }
    var hasRecords: Bool { records.values.contains { !$0.isEmpty } }
    static let categories = ["goals", "tasks", "sessions", "reflections", "notes", "bounties", "competitions"]
}
struct ArchiveAttachment: Codable, Equatable {
    var path: String
    var sha256: String?
    var missing: Bool
    var referenced: Bool = true
    var recordID: String?
    var category: String?
}
struct ArchiveManifest: Codable {
    var version = 1
    var sourceFingerprint: String
    var counts: [String: Int]
    var attachments: [ArchiveAttachment]
    var warnings: [String]
    var verified: Bool
}
struct LocalArchive: Identifiable {
    var id: String
    var directory: URL
    var document: ArchiveDocument
    var manifest: ArchiveManifest
}
enum ArchiveFailure: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let s) = self { return s }; return nil }
}

/// Has no network dependency and accepts no cloud identity. A source account is
/// an on-device namespace, never proof of ownership of a backend account.
actor LegacyArchiveRepository {
    let sourceRoot: URL
    let vaultRoot: URL
    private let fm = FileManager.default
    init(sourceRoot: URL? = nil, vaultRoot: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.sourceRoot = sourceRoot ?? support.appendingPathComponent("IntentionalTrainingNotes/accounts")
        self.vaultRoot = vaultRoot ?? support.appendingPathComponent("MatMindLegacy/v1")
    }
    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func safeComponent(_ s: String) -> Bool {
        !s.isEmpty && s != "." && s != ".." && !s.contains("/") && !s.contains("\\") && !s.contains("\0")
    }
    private func regularFile(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        return values.isRegularFile == true && values.isSymbolicLink != true
    }
    private func ensureDirectory(_ url: URL) throws {
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        #if os(iOS)
        try fm.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        #endif
    }
    /// Discover all notebooks, including guest/local; migration is local-only.
    func discover() throws -> [String] {
        guard fm.fileExists(atPath: sourceRoot.path) else { return [] }
        return try fm.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: [.isSymbolicLinkKey]).filter {
            (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true &&
            fm.fileExists(atPath: $0.appendingPathComponent("notebook.json").path)
        }.map(\.lastPathComponent).sorted()
    }
    func migrate(account: String) throws -> LocalArchive? {
        guard Self.safeComponent(account) else { throw ArchiveFailure.invalid("Invalid local account path.") }
        let source = sourceRoot.appendingPathComponent(account)
        let input = source.appendingPathComponent("notebook.json")
        guard try regularFile(input) else { throw ArchiveFailure.invalid("Notebook is not a regular file.") }
        let original = try Data(contentsOf: input)
        let document = try NotebookMigration.archiveDocument(data: original)
        guard document.hasRecords else { return nil }
        let references = try referencedAttachments(document, source: source)
        // Back up all original attachment files, including unreferenced ones.
        var allPaths = Set(references.keys)
        for folder in ["note-images", "task-images", "reflection-images", "competition-images"] {
            let directory = source.appendingPathComponent(folder)
            if fm.fileExists(atPath: directory.path) {
                guard try safeParents(directory.appendingPathComponent("placeholder"), root: source) else { throw ArchiveFailure.invalid("Unsafe attachment directory.") }
                guard let walker = fm.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { throw ArchiveFailure.invalid("Cannot read attachment directory.") }
                for case let file as URL in walker {
                    let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    if values.isSymbolicLink == true { throw ArchiveFailure.invalid("Unsafe attachment symbolic link.") }
                    if values.isRegularFile == true { allPaths.insert(String(file.standardizedFileURL.path.dropFirst(source.standardizedFileURL.path.count + 1))) }
                }
            }
        }
        let attachmentPaths = allPaths.sorted()
        var attachments: [ArchiveAttachment] = []
        for path in attachmentPaths {
            let url = source.appendingPathComponent(path)
            if fm.fileExists(atPath: url.path) {
                guard try regularFile(url), try safeParents(url, root: source) else {
                    throw ArchiveFailure.invalid("Unsafe attachment path: \(path)")
                }
                attachments.append(ArchiveAttachment(path: path, sha256: Self.hash(try Data(contentsOf: url)), missing: false, referenced: references[path] != nil, recordID: references[path]?.0, category: references[path]?.1))
            } else { attachments.append(ArchiveAttachment(path: path, sha256: nil, missing: true, referenced: references[path] != nil, recordID: references[path]?.0, category: references[path]?.1)) }
        }
        let fingerprintEncoder = JSONEncoder(); fingerprintEncoder.outputFormatting = [.sortedKeys]
        let fingerprint = Self.hash(original + (try fingerprintEncoder.encode(attachments)))
        let accountKey = Self.hash(Data(account.utf8))
        let parent = vaultRoot.appendingPathComponent(accountKey)
        let finished = parent.appendingPathComponent(fingerprint, isDirectory: true)
        if fm.fileExists(atPath: finished.path) { return try load(finished) }
        try ensureDirectory(parent)
        // Deterministic staging directory: failures leave source and staged backup intact.
        let stage = parent.appendingPathComponent(fingerprint + ".pending")
        try ensureDirectory(stage)
        let backup = stage.appendingPathComponent("backup")
        try ensureDirectory(backup)
        try original.write(to: backup.appendingPathComponent("notebook.json"), options: .atomic)
        var warnings = relationshipWarnings(document)
        for attachment in attachments {
            if attachment.missing { warnings.append("Missing attachment: \(attachment.path). Original reference retained; retry after restoring the file."); continue }
            let destination = backup.appendingPathComponent(attachment.path)
            try ensureDirectory(destination.deletingLastPathComponent())
            let data = try Data(contentsOf: source.appendingPathComponent(attachment.path))
            guard Self.hash(data) == attachment.sha256 else { throw ArchiveFailure.invalid("Attachment changed during backup. Retry migration.") }
            try data.write(to: destination, options: .atomic)
        }
        guard try Data(contentsOf: backup.appendingPathComponent("notebook.json")) == original else {
            throw ArchiveFailure.invalid("Notebook backup verification failed.")
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = try encoder.encode(document)
        try payload.write(to: stage.appendingPathComponent("archive.json"), options: .atomic)
        let decoded = try JSONDecoder().decode(ArchiveDocument.self, from: Data(contentsOf: stage.appendingPathComponent("archive.json")))
        guard decoded == document else { throw ArchiveFailure.invalid("Archive records or relationships changed during migration.") }
        for a in attachments where !a.missing {
            guard Self.hash(try Data(contentsOf: backup.appendingPathComponent(a.path))) == a.sha256 else {
                throw ArchiveFailure.invalid("Attachment backup verification failed: \(a.path)")
            }
        }
        let manifest = ArchiveManifest(sourceFingerprint: fingerprint, counts: document.counts, attachments: attachments, warnings: warnings, verified: true)
        try encoder.encode(manifest).write(to: stage.appendingPathComponent("manifest.json"), options: .atomic)
        // Commit only after the full backup, records and attachment bytes verify.
        try fm.moveItem(at: stage, to: finished)
        return LocalArchive(id: accountKey, directory: finished, document: document, manifest: manifest)
    }
    private func load(_ url: URL) throws -> LocalArchive {
        let decoder = JSONDecoder()
        let doc = try decoder.decode(ArchiveDocument.self, from: Data(contentsOf: url.appendingPathComponent("archive.json")))
        let manifest = try decoder.decode(ArchiveManifest.self, from: Data(contentsOf: url.appendingPathComponent("manifest.json")))
        let original = try Data(contentsOf: url.appendingPathComponent("backup/notebook.json"))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard Self.hash(original + (try encoder.encode(manifest.attachments))) == manifest.sourceFingerprint,
              try NotebookMigration.archiveDocument(data: original) == doc,
              manifest.verified, manifest.counts == doc.counts else { throw ArchiveFailure.invalid("Archive integrity check failed. Original data is preserved.") }
        for a in manifest.attachments where !a.missing {
            guard Self.hash(try Data(contentsOf: url.appendingPathComponent("backup/" + a.path))) == a.sha256 else { throw ArchiveFailure.invalid("Archive attachment integrity check failed: \(a.path)") }
        }
        return LocalArchive(id: url.deletingLastPathComponent().lastPathComponent, directory: url, document: doc, manifest: manifest)
    }
    private func safeParents(_ url: URL, root: URL) throws -> Bool {
        var current = url.deletingLastPathComponent()
        while current.path != root.path {
            guard current.path.hasPrefix(root.path + "/"), try current.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { return false }
            current = current.deletingLastPathComponent()
        }
        return try root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true
    }
    private func referencedAttachments(_ doc: ArchiveDocument, source: URL) throws -> [String: (String, String)] {
        var paths: [String: (String, String)] = [:]
        for (category, folder) in [("tasks", "task-images"), ("notes", "note-images"), ("reflections", "reflection-images"), ("competitions", "competition-images")] {
            for record in doc.records[category] ?? [] {
                for filename in record.fields["imageFileNames"]?.strings ?? [] {
                    guard Self.safeComponent(record.id), Self.safeComponent(filename) else { throw ArchiveFailure.invalid("Invalid attachment reference in \(record.id).") }
                    var folderID = record.id
                    // Existing builds saved reflection photos under the SESSION
                    // identifier, not the reflection identifier. Support both layouts.
                    if category == "reflections", let sessionID = record.fields["sessionId"]?.string {
                        guard Self.safeComponent(sessionID) else { throw ArchiveFailure.invalid("Unsafe reflection relationship.") }
                        if fm.fileExists(atPath: source.appendingPathComponent("\(folder)/\(sessionID)/\(filename)").path) || !fm.fileExists(atPath: source.appendingPathComponent("\(folder)/\(record.id)/\(filename)").path) { folderID = sessionID }
                    }
                    paths["\(folder)/\(folderID)/\(filename)"] = (record.id, category)
                }
            }
        }
        return paths
    }
    private func relationshipWarnings(_ doc: ArchiveDocument) -> [String] {
        let goals = Set((doc.records["goals"] ?? []).map(\.id))
        let tasks = Set((doc.records["tasks"] ?? []).map(\.id))
        let sessions = Set((doc.records["sessions"] ?? []).map(\.id))
        var warnings: [String] = []
        for records in doc.records.values {
            for r in records {
                for (key, ids) in [("goalId", goals), ("taskId", tasks), ("sessionId", sessions)] {
                    if let ref = r.fields[key]?.string, !ref.isEmpty, !ids.contains(ref) { warnings.append("\(r.id): existing missing relationship \(key) = \(ref). Reference preserved.") }
                }
                for id in r.fields["taskIds"]?.strings ?? [] where !tasks.contains(id) { warnings.append("\(r.id): existing missing task \(id). Reference preserved.") }
            }
        }
        return warnings.sorted()
    }
    func export(_ archive: LocalArchive, temporaryRoot: URL = FileManager.default.temporaryDirectory) throws -> URL {
        // Verify archive afresh before every export. Never include the raw backup:
        // it may contain old profile/account fields not appropriate for sharing.
        let checked = try load(archive.directory)
        let root = temporaryRoot.appendingPathComponent("MatMindExports", isDirectory: true)
        try ensureDirectory(root)
        let job = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try ensureDirectory(job)
        do {
            let payload = job.appendingPathComponent("payload")
            try ensureDirectory(payload)
            try Data(contentsOf: checked.directory.appendingPathComponent("archive.json")).write(to: payload.appendingPathComponent("training-v1.json"))
            for a in checked.manifest.attachments where !a.missing && a.referenced {
                let dest = payload.appendingPathComponent("attachments/" + a.path)
                try ensureDirectory(dest.deletingLastPathComponent())
                try fm.copyItem(at: checked.directory.appendingPathComponent("backup/" + a.path), to: dest)
            }
            let readme = """
            Grip Gorillas previous training data — export format 1

            training-v1.json contains the seven record collections, original identifiers,
            relationship references and source date strings. Sessions are in the sessions
            collection. Day-only dates remain day-only. No session times were inferred.
            attachments/<kind>-images/<record-id>/<filename> contains available files.
            Missing source attachments and pre-existing broken relationships are listed below.
            This export includes only this local archive. It excludes authentication,
            credentials, tokens, profile/account identity and other accounts' data.

            \(checked.manifest.warnings.joined(separator: "\n"))
            """
            try Data(readme.utf8).write(to: payload.appendingPathComponent("README.txt"))
            let zip = job.appendingPathComponent("Previous-training-data.zip")
            try ArchiveZIP.write(directory: payload, destination: zip)
            try fm.removeItem(at: payload)
            return zip
        } catch {
            try? fm.removeItem(at: job)
            throw error
        }
    }
    func cleanupExport(_ url: URL, temporaryRoot: URL = FileManager.default.temporaryDirectory) {
        let root = temporaryRoot.appendingPathComponent("MatMindExports").standardizedFileURL
        let job = url.deletingLastPathComponent().standardizedFileURL
        guard job.deletingLastPathComponent() == root else { return }
        try? fm.removeItem(at: job)
    }
    func cleanupExpiredExports(now: Date = Date()) throws {
        let root = fm.temporaryDirectory.appendingPathComponent("MatMindExports")
        guard fm.fileExists(atPath: root.path) else { return }
        for job in try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey]) {
            if let created = try job.resourceValues(forKeys: [.creationDateKey]).creationDate, now.timeIntervalSince(created) > 86400 {
                try fm.removeItem(at: job)
            }
        }
    }
}

extension NotebookMigration {
    /// Reuses the supported-format decoder as validation; retain raw values for a
    /// lossless read-only archive instead of its normalized Date model.
    static func archiveDocument(data: Data) throws -> ArchiveDocument {
        _ = try decode(data: data, accountId: "archive-validation")
        let source = try JSONDecoder().decode([String: ArchiveValue].self, from: data)
        if source["dataOrigin"]?.string == "demo" { return ArchiveDocument(sourceSchemaVersion: 4, records: [:]) }
        let raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let version = raw["schemaVersion"] as? Int ?? (raw["focuses"] != nil ? 1 : 3)
        // Explicit allowlist prevents credentials or future unrelated account data
        // being copied into archive payloads and exports.
        let fields: [String: Set<String>] = [
            "goals": Set("id name iconName colorName isArchived createdAt updatedAt".split(separator: " ").map(String.init)),
            "tasks": Set("id goalId name notes link imageFileNames createdAt updatedAt".split(separator: " ").map(String.init)),
            "sessions": Set("id goalId date taskIds status createdAt updatedAt".split(separator: " ").map(String.init)),
            "reflections": Set("id sessionId date workedText stuckText tryNextText mood isFavorite link imageFileNames createdAt updatedAt".split(separator: " ").map(String.init)),
            "notes": Set("id title body imageFileNames createdAt updatedAt".split(separator: " ").map(String.init)),
            "bounties": Set("id goalId taskId kind targetCount targetPartner hitDates status createdAt collectedAt".split(separator: " ").map(String.init)),
            "competitions": Set("id name date venue division rank strategy result wins losses draws placement loggedAt mood workedText stuckText tryNextText reflectedAt createdAt updatedAt imageFileNames link".split(separator: " ").map(String.init))
        ]
        var collections: [String: [[String: ArchiveValue]]] = [:]
        for category in ArchiveDocument.categories {
            if case .array(let values) = source[category] { collections[category] = values.compactMap { if case .object(let o) = $0 { return o }; return nil } }
        }
        if case .array(let focuses) = source["focuses"] {
            collections["goals"] = focuses.compactMap { if case .object(let o) = $0 { return o }; return nil }
            collections["tasks"] = (collections["tasks"] ?? []).map { value in var v = value; v["goalId"] = v.removeValue(forKey: "focusId"); return v }
            if case .array(let entries) = source["entries"] {
                collections["sessions"] = []; collections["reflections"] = []
                for entry in entries {
                    guard case .object(let e) = entry else { continue }
                    var session = e; session["goalId"] = e["focusId"]
                    let reflected = !(e["stuckText"]?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (e["mood"] != nil && e["mood"] != .null)
                    session["status"] = .string(reflected ? "done" : "planned")
                    collections["sessions"]!.append(session)
                    if reflected {
                        var reflection = e
                        reflection["id"] = .string("r_" + (e["id"]?.string ?? ""))
                        reflection["sessionId"] = e["id"]
                        collections["reflections"]!.append(reflection)
                    }
                }
            }
        }
        var records: [String: [ArchiveRecord]] = [:]
        for category in ArchiveDocument.categories {
            var ids: Set<String> = []
            records[category] = try (collections[category] ?? []).filter { value in
                // Existing debug seed fixtures have explicit seed-* identifiers.
                !(value["id"]?.string ?? "").hasPrefix("seed-") &&
                !["goalId", "sessionId", "taskId"].contains { (value[$0]?.string ?? "").hasPrefix("seed-") }
            }.map { value in
                guard let id = value["id"]?.string, !id.isEmpty, ids.insert(id).inserted else { throw ArchiveFailure.invalid("Missing or duplicate \(category) identifier.") }
                return ArchiveRecord(fields: value.filter { fields[category]!.contains($0.key) })
            }
        }
        return ArchiveDocument(sourceSchemaVersion: version, records: records)
    }
}
