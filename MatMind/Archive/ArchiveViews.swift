import SwiftUI
import LocalAuthentication

@MainActor @Observable
final class LocalArchiveModel {
    private(set) var archives: [LocalArchive] = []
    private(set) var issues: [String] = []
    private(set) var loading = false
    let repository: LegacyArchiveRepository
    // Captured from the previous local session, independent of cloud sign-in.
    private let localNamespaces: Set<String>
    init(repository: LegacyArchiveRepository = LegacyArchiveRepository(), previousLocalAccount: String? = KeychainAccountStore().loadAccount()?.id) {
        self.repository = repository
        localNamespaces = Set(["local", previousLocalAccount].compactMap { $0 })
    }
    func discover() async {
        guard !loading else { return }
        loading = true; defer { loading = false }
        var found: [LocalArchive] = []; var errors: [String] = []
        do {
            let accounts = try await repository.discover()
            // Discover every source, but never expose a different local namespace
            // just because someone signed into a matching cloud/provider account.
            for account in accounts where localNamespaces.contains(account) {
                do { if let archive = try await repository.migrate(account: account) { found.append(archive) } }
                catch { errors.append("Local training data could not be archived: \(error.localizedDescription). Original files are unchanged. Retry after restoring a readable backup.") }
            }
            try await repository.cleanupExpiredExports()
        } catch { errors.append(error.localizedDescription) }
        archives = found; issues = errors
    }
}

struct PreviousTrainingDataScreen: View {
    let model: LocalArchiveModel
    var exportOnly = false
    @Environment(\.dismiss) private var dismiss
    @State private var unlocked = false
    @State private var working = false
    @State private var status: String?
    @State private var failure: String?
    @State private var exportURL: URL?
    @State private var selection: String?
    private var selected: LocalArchive? { model.archives.first { $0.id == selection } ?? model.archives.first }
    var body: some View {
        List {
            Section {
                Text("Your previous training stays private on this device. It is read-only and does not count toward social attendance or streaks.")
            }
            if !unlocked {
                Button("Unlock local data") { Task { await unlock() } }
            } else if let archive = selected {
                if model.archives.count > 1 {
                    Picker("Local archive", selection: Binding(get: { selected?.id ?? "" }, set: { selection = $0 })) {
                        ForEach(Array(model.archives.enumerated()), id: \.element.id) { index, value in Text("Local archive \(index + 1)").tag(value.id) }
                    }
                }
                Section {
                    if !exportOnly { NavigationLink("View archive") { ArchiveCollectionsScreen(archive: archive) } }
                    Button("Export data") { Task { await export(archive) } }.disabled(working)
                }
                if !archive.manifest.warnings.isEmpty {
                    Section("Recoverable warnings") {
                        ForEach(archive.manifest.warnings, id: \.self) { Text($0).font(.footnote) }
                        Button("Retry verification") { Task { await model.discover() } }
                    }
                }
            }
            if unlocked && model.archives.isEmpty && !model.loading { Text("No previous local sessions were found on this device.") }
            if working { ProgressView(status ?? "Preparing export…") }
            else if let status { Text(status).foregroundStyle(.secondary).accessibilityAddTraits(.updatesFrequently) }
            if let failure { Text(failure).foregroundStyle(.red) }
        }
        .navigationTitle(exportOnly ? "Export local sessions" : "Previous training data")
        .toolbar { if exportOnly { Button("Done") { dismiss() } } }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { exportURL != nil }, set: { if !$0 { cleanup() } })) {
            if let exportURL {
                ArchiveShareSheet(url: exportURL) { completed, error in
                    failure = error?.localizedDescription
                    status = completed ? "Export shared successfully." : "Export ready. Sharing cancelled."
                    self.exportURL = nil
                    Task { await model.repository.cleanupExport(exportURL) }
                }
            }
        }
        .task { await unlock() }
    }
    private func unlock() async {
        let context = LAContext()
        var policyError: NSError?
        // Devices without a configured passcode retain their previous local-only
        // access model. Never require cloud sign-in to recover this archive.
        if !context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError), policyError?.code == LAError.passcodeNotSet.rawValue {
            unlocked = true; return
        }
        do {
            unlocked = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "View or export private training stored on this device.")
        } catch { failure = "Could not unlock local training data: \(error.localizedDescription)" }
    }
    private func export(_ archive: LocalArchive) async {
        working = true; failure = nil; status = "Preparing JSON, verifying attachments and creating ZIP…"
        do {
            exportURL = try await model.repository.export(archive)
            status = "ZIP created. Choose where to share or save it."
        } catch { failure = "Export failed: \(error.localizedDescription). Your archive is unchanged."; status = nil }
        working = false
    }
    private func cleanup() {
        if let url = exportURL { Task { await model.repository.cleanupExport(url) } }
        exportURL = nil
    }
}

struct ArchiveCollectionsScreen: View {
    let archive: LocalArchive
    var body: some View {
        List {
            ForEach(ArchiveDocument.categories, id: \.self) { category in
                NavigationLink {
                    List(archive.document.records[category] ?? []) { record in
                        NavigationLink(record.title) { ArchiveRecordScreen(record: record, archive: archive) }
                    }.navigationTitle(label(category))
                } label: {
                    HStack { Text(label(category)); Spacer(); Text("\(archive.document.records[category]?.count ?? 0)").foregroundStyle(.secondary) }
                }
            }
        }.navigationTitle("View archive")
    }
    private func label(_ category: String) -> String { category == "sessions" ? "Planned sessions" : category.capitalized }
}
struct ArchiveRecordScreen: View {
    let record: ArchiveRecord
    let archive: LocalArchive
    @State private var photo: UIImage?
    var body: some View {
        List {
            ForEach(record.fields.keys.sorted(), id: \.self) { key in
                if key != "imageFileNames", let value = record.fields[key] {
                    Section(key) {
                        Text(value.display).textSelection(.enabled)
                        ForEach(related(value, key: key)) { target in
                            NavigationLink("View \(target.title)") { ArchiveRecordScreen(record: target, archive: archive) }
                        }
                    }
                }
            }
            Section("Attachments") {
                let attachments = archive.manifest.attachments.filter { $0.recordID == record.id }
                if attachments.isEmpty { Text("None").foregroundStyle(.secondary) }
                ForEach(attachments, id: \.path) { a in
                    if a.missing { Text("\(a.path): missing from original files").foregroundStyle(.secondary) }
                    else {
                        NavigationLink(a.path.components(separatedBy: "/").last ?? a.path) {
                            ArchiveImageScreen(url: archive.directory.appendingPathComponent("backup/" + a.path))
                        }
                    }
                }
            }
        }.navigationTitle(record.title).navigationBarTitleDisplayMode(.inline)
    }
    private func related(_ value: ArchiveValue, key: String) -> [ArchiveRecord] {
        let category = ["goalId": "goals", "taskId": "tasks", "taskIds": "tasks", "sessionId": "sessions"][key]
        guard let category else { return [] }
        let ids = Set(value.string.map { [$0] } ?? value.strings)
        return (archive.document.records[category] ?? []).filter { ids.contains($0.id) }
    }
}
private struct ArchiveImageScreen: View {
    let url: URL
    @State private var data: Data?
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit() }
            else { ContentUnavailableView("Attachment unavailable", systemImage: "photo", description: Text("The file could not be displayed. Its original bytes remain in the export.")) }
        }.task { data = await Task.detached { try? Data(contentsOf: url) }.value }
    }
}
private struct ArchiveShareSheet: UIViewControllerRepresentable {
    let url: URL
    let completion: (Bool, Error?) -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, error in completion(completed, error) }
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
