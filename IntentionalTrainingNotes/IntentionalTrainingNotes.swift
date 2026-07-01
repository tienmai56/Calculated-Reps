import AuthenticationServices
import AVFoundation
import Foundation
import Network
import Security
import Speech
import SwiftUI
import UIKit
import UserNotifications

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

final class NetworkStatusStore: ObservableObject {
    @Published private(set) var isOffline = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "IntentionalTrainingNotes.NetworkStatus")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = path.status != .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Persistence

protocol NotebookPersistence {
    func load(accountId: String) throws -> TrainingNotebook
    func save(_ notebook: TrainingNotebook) throws
}

enum PersistenceError: Error {
    case missingSupportDirectory
}

final class JSONNotebookPersistence: NotebookPersistence {
    private let rootDirectory: URL
    private let fileManager: FileManager

    init(rootDirectory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let rootDirectory = rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            self.rootDirectory = appSupport?
                .appendingPathComponent("IntentionalTrainingNotes", isDirectory: true)
                ?? fileManager.temporaryDirectory.appendingPathComponent("IntentionalTrainingNotes", isDirectory: true)
        }
    }

    func fileURL(accountId: String) -> URL {
        rootDirectory
            .appendingPathComponent("accounts", isDirectory: true)
            .appendingPathComponent(accountId.sanitizedAccountId, isDirectory: true)
            .appendingPathComponent("notebook.json")
    }

    func load(accountId: String) throws -> TrainingNotebook {
        let url = fileURL(accountId: accountId)
        guard fileManager.fileExists(atPath: url.path) else {
            return TrainingNotebook(accountId: accountId)
        }

        let data = try Data(contentsOf: url)
        return try NotebookMigration.decode(data: data, accountId: accountId)
    }

    func save(_ notebook: TrainingNotebook) throws {
        let url = fileURL(accountId: notebook.accountId)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(notebook)
        try data.write(to: url, options: [.atomic])
    }

    func noteImagesDirectory(accountId: String, noteId: String) -> URL {
        rootDirectory
            .appendingPathComponent("accounts", isDirectory: true)
            .appendingPathComponent(accountId.sanitizedAccountId, isDirectory: true)
            .appendingPathComponent("note-images", isDirectory: true)
            .appendingPathComponent(noteId, isDirectory: true)
    }

    func saveNoteImage(accountId: String, noteId: String, imageData: Data, fileName: String) throws -> URL {
        let dir = noteImagesDirectory(accountId: accountId, noteId: noteId)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let fileURL = dir.appendingPathComponent(fileName)
        try imageData.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func loadNoteImage(accountId: String, noteId: String, fileName: String) -> Data? {
        let fileURL = noteImagesDirectory(accountId: accountId, noteId: noteId).appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }

    func taskImagesDirectory(accountId: String, taskId: String) -> URL {
        rootDirectory
            .appendingPathComponent("accounts", isDirectory: true)
            .appendingPathComponent(accountId.sanitizedAccountId, isDirectory: true)
            .appendingPathComponent("task-images", isDirectory: true)
            .appendingPathComponent(taskId, isDirectory: true)
    }

    func saveTaskImage(accountId: String, taskId: String, imageData: Data, fileName: String) throws -> URL {
        let dir = taskImagesDirectory(accountId: accountId, taskId: taskId)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let fileURL = dir.appendingPathComponent(fileName)
        try imageData.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func loadTaskImage(accountId: String, taskId: String, fileName: String) -> Data? {
        let fileURL = taskImagesDirectory(accountId: accountId, taskId: taskId).appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }

    func reflectionImagesDirectory(accountId: String, reflectionId: String) -> URL {
        rootDirectory
            .appendingPathComponent("accounts", isDirectory: true)
            .appendingPathComponent(accountId.sanitizedAccountId, isDirectory: true)
            .appendingPathComponent("reflection-images", isDirectory: true)
            .appendingPathComponent(reflectionId, isDirectory: true)
    }

    func saveReflectionImage(accountId: String, reflectionId: String, imageData: Data, fileName: String) throws -> URL {
        let dir = reflectionImagesDirectory(accountId: accountId, reflectionId: reflectionId)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let fileURL = dir.appendingPathComponent(fileName)
        try imageData.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func loadReflectionImage(accountId: String, reflectionId: String, fileName: String) -> Data? {
        let fileURL = reflectionImagesDirectory(accountId: accountId, reflectionId: reflectionId).appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }
}

enum NotebookMigration {
    static func decode(data: Data, accountId: String) throws -> TrainingNotebook {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let notebook = try? decoder.decode(TrainingNotebook.self, from: data) {
            var migrated = notebook
            migrated.accountId = accountId
            migrated.schemaVersion = max(migrated.schemaVersion, 3)
            migrated.sessions = migrated.sessions.map {
                var session = $0
                session.date = Calendar.current.normalizedTrainingDay(session.date)
                return session
            }
            migrated.reflections = migrated.reflections.map {
                var reflection = $0
                reflection.date = Calendar.current.normalizedTrainingDay(reflection.date)
                return reflection
            }
            return migrated
        }

        let legacyDecoder = JSONDecoder()
        legacyDecoder.dateDecodingStrategy = .formatted(.trainingDay)
        let legacy = try legacyDecoder.decode(LegacyTrainingNotebook.self, from: data)
        return legacy.migrated(accountId: accountId)
    }
}

private struct LegacyTrainingNotebook: Codable {
    var focuses: [LegacyFocus]?
    var tasks: [LegacyTask]?
    var entries: [LegacyEntry]?

    func migrated(accountId: String) -> TrainingNotebook {
        let goals = (focuses ?? []).map {
            TrainingGoal(
                id: $0.id,
                accountId: accountId,
                name: $0.name,
                isArchived: $0.isArchived,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
        let migratedTasks = (tasks ?? []).map {
            TrainingTask(
                id: $0.id,
                goalId: $0.focusId,
                name: $0.name,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }

        var sessions: [PlannedSession] = []
        var reflections: [Reflection] = []
        for entry in entries ?? [] {
            let hasReflection = !(entry.stuckText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || entry.mood != nil
            let session = PlannedSession(
                id: entry.id,
                goalId: entry.focusId,
                date: entry.date,
                taskIds: entry.taskIds,
                status: hasReflection ? .done : .planned,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
            sessions.append(session)
            if hasReflection {
                reflections.append(
                    Reflection(
                        id: "r_\(entry.id)",
                        sessionId: entry.id,
                        date: entry.date,
                        workedText: "",
                        stuckText: entry.stuckText,
                        mood: entry.mood,
                        createdAt: entry.createdAt,
                        updatedAt: entry.updatedAt
                    )
                )
            }
        }

        return TrainingNotebook(
            schemaVersion: 2,
            accountId: accountId,
            goals: goals,
            tasks: migratedTasks,
            sessions: sessions,
            reflections: reflections
        )
    }
}

private struct LegacyFocus: Codable {
    var id: String
    var name: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
}

private struct LegacyTask: Codable {
    var id: String
    var focusId: String
    var name: String
    var createdAt: Date
    var updatedAt: Date
}

private struct LegacyEntry: Codable {
    var id: String
    var focusId: String
    var date: Date
    var taskIds: [String]
    var stuckText: String
    var mood: Mood?
    var createdAt: Date
    var updatedAt: Date
}

// MARK: - Keychain

protocol AccountStore {
    func loadAccount() -> UserAccount?
    func saveAccount(_ account: UserAccount) throws
    func clearAccount() throws
}

final class KeychainAccountStore: AccountStore {
    private let service = "com.tienmai.intentionaltrainingnotes.account"
    private let account = "current"

    func loadAccount() -> UserAccount? {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UserAccount.self, from: data)
    }

    func saveAccount(_ account: UserAccount) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(account)

        var query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }

    func clearAccount() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError(status: status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

struct KeychainError: Error {
    var status: OSStatus
}

// MARK: - Auth

enum AuthError: LocalizedError {
    case cancelled
    case noPresentationAnchor
    case unsupportedProvider
    case missingGoogleSDK
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in was cancelled."
        case .noPresentationAnchor:
            return "Could not find a window for sign in."
        case .unsupportedProvider:
            return "This sign-in provider is not available."
        case .missingGoogleSDK:
            return "Google Sign-In is not configured for this build."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

protocol AuthServicing {
    func signInWithApple(completion: @escaping (Result<UserAccount, AuthError>) -> Void)
    func signInWithGoogle(completion: @escaping (Result<UserAccount, AuthError>) -> Void)
    static func handleOpenURL(_ url: URL) -> Bool
}

final class AuthService: AuthServicing {
    private lazy var appleCoordinator = AppleSignInCoordinator()
    private lazy var googleCoordinator = GoogleSignInCoordinator()

    func signInWithApple(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        appleCoordinator.signIn(completion: completion)
    }

    func signInWithGoogle(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        googleCoordinator.signIn(completion: completion)
    }

    static func handleOpenURL(_ url: URL) -> Bool {
        GoogleSignInCoordinator.handleOpenURL(url)
    }
}

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var completion: ((Result<UserAccount, AuthError>) -> Void)?

    func signIn(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        self.completion = completion

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion?(.failure(.unsupportedProvider))
            completion = nil
            return
        }

        let formatter = PersonNameComponentsFormatter()
        let displayName = credential.fullName.map { formatter.string(from: $0) }?.nilIfBlank
        let account = UserAccount(
            provider: .apple,
            providerSubjectId: credential.user,
            email: credential.email,
            displayName: displayName
        )
        completion?(.success(account))
        completion = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            completion?(.failure(.cancelled))
        } else {
            completion?(.failure(.underlying(error)))
        }
        completion = nil
    }
}

final class GoogleSignInCoordinator {
    static var isConfigured: Bool {
        #if canImport(GoogleSignIn)
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String
        let hasClientID = clientID?.nilIfBlank != nil && clientID?.contains("REPLACE") == false
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let hasURLScheme = urlTypes.contains { type in
            let schemes = type["CFBundleURLSchemes"] as? [String] ?? []
            return schemes.contains { !$0.contains("REPLACE") && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        return hasClientID && hasURLScheme
        #else
        return false
        #endif
    }

    func signIn(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        #if canImport(GoogleSignIn)
        guard Self.isConfigured else {
            completion(.failure(.missingGoogleSDK))
            return
        }

        guard let rootViewController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            completion(.failure(.noPresentationAnchor))
            return
        }

        let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                completion(.failure(.underlying(error)))
                return
            }

            guard let user = result?.user else {
                completion(.failure(.unsupportedProvider))
                return
            }

            let profile = user.profile
            let subject = user.userID ?? profile?.email ?? UUID().uuidString
            completion(
                .success(
                    UserAccount(
                        provider: .google,
                        providerSubjectId: subject,
                        email: profile?.email,
                        displayName: profile?.name
                    )
                )
            )
        }
        #else
        completion(.failure(.missingGoogleSDK))
        #endif
    }

    static func handleOpenURL(_ url: URL) -> Bool {
        #if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
        #else
        return false
        #endif
    }
}

// MARK: - Stores

final class AppSessionStore: ObservableObject {
    @Published private(set) var route: AppRoute = .signedOut
    @Published private(set) var account: UserAccount?
    @Published private(set) var notebookStore: NotebookStore?
    @Published var errorMessage: String?

    private let accountStore: AccountStore
    private let authService: AuthServicing
    private let persistenceFactory: (String) -> NotebookPersistence

    init(
        accountStore: AccountStore = KeychainAccountStore(),
        authService: AuthServicing = AuthService(),
        persistenceFactory: @escaping (String) -> NotebookPersistence = { _ in JSONNotebookPersistence() }
    ) {
        self.accountStore = accountStore
        self.authService = authService
        self.persistenceFactory = persistenceFactory
        restore()
    }

    func restore() {
        // Local-only mode: no authentication required. Use a saved account if one exists
        // (legacy installs), otherwise launch straight into the app with a local account.
        if let restored = accountStore.loadAccount() {
            activate(account: restored)
        } else {
            activate(account: AppSessionStore.localAccount)
        }
    }

    func signIn(provider: AuthProvider) {
        errorMessage = nil

        let completion: (Result<UserAccount, AuthError>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let account):
                    self?.completeSignIn(account: account)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        switch provider {
        case .apple:
            authService.signInWithApple(completion: completion)
        case .google:
            authService.signInWithGoogle(completion: completion)
        }
    }

    func showOfflineSignInMessage(provider: AuthProvider) {
        errorMessage = "\(provider.label) sign-in needs internet. Turn off Airplane Mode or reconnect, then try again."
    }

    func completeSignIn(account: UserAccount) {
        var updated = account
        updated.lastSignedInAt = Date()

        do {
            try accountStore.saveAccount(updated)
            activate(account: updated)
        } catch {
            errorMessage = "Could not save sign-in state."
        }
    }

    func saveProfile(firstName: String, lastName: String) {
        guard let account = account, let notebookStore = notebookStore else { return }
        notebookStore.saveProfile(
            UserProfile(
                accountId: account.id,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: notebookStore.notebook.profile?.createdAt ?? Date(),
                updatedAt: Date()
            )
        )
        route = .ready
    }

    func signOut() {
        do {
            try accountStore.clearAccount()
        } catch {
            errorMessage = "Could not clear sign-in state."
        }
        account = nil
        notebookStore = nil
        route = .signedOut
    }

    private func activate(account: UserAccount) {
        let store = NotebookStore(accountId: account.id, persistence: persistenceFactory(account.id))
        self.account = account
        self.notebookStore = store

        #if DEBUG
        // DEBUG/QA: `RESET_ONBOARDING` clears the completed flag and wipes data on every launch so
        // onboarding can be re-tested repeatedly without deleting the app. Never present in release.
        if ProcessInfo.processInfo.environment["RESET_ONBOARDING"] != nil {
            UserDefaults.standard.removeObject(forKey: AppSessionStore.onboardingCompletedKey)
            UserDefaults.standard.removeObject(forKey: "matmind.debugSeedVersion")
            store.resetForOnboardingTestingDEBUG()
        }
        #endif

        // Upgrading users already have a notebook — never send them through first-run onboarding
        // (it would add a stray goal/task/session on top of their real data). Treat any existing
        // data as "already onboarded" and persist that so the check only runs once.
        let hasExistingData = !store.notebook.goals.isEmpty
            || !store.notebook.sessions.isEmpty
            || store.notebook.profile != nil
        if hasExistingData && !UserDefaults.standard.bool(forKey: AppSessionStore.onboardingCompletedKey) {
            UserDefaults.standard.set(true, forKey: AppSessionStore.onboardingCompletedKey)
        }

        // First-run onboarding: show the goal → task → session flow until it's completed once.
        if UserDefaults.standard.bool(forKey: AppSessionStore.onboardingCompletedKey) {
            self.route = .ready
            #if DEBUG
            // Only seed demo data when there's nothing yet, so it never overwrites
            // a real notebook created through onboarding.
            if store.notebook.goals.isEmpty {
                store.seedDemoDataIfEmpty()
            }
            #endif
        } else {
            self.route = .onboarding
        }
    }

    /// Persists the goal, first task(s) and first session captured during onboarding, wires up the
    /// default 8:00 reminder, then routes into the app. Called once when onboarding finishes.
    func completeOnboarding(_ draft: OnboardingDraft) {
        if let store = notebookStore,
           let goal = store.addGoal(name: draft.goalName, iconName: draft.iconName, colorName: draft.colorName) {
            let taskIds: [String] = draft.taskNames.compactMap { store.addTask(goalId: goal.id, name: $0)?.id }
            // Attach the optional free-form description to the first task.
            if let firstTaskId = taskIds.first {
                let notes = draft.firstTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                if !notes.isEmpty { store.updateTask(id: firstTaskId, notes: notes) }
            }
            store.planSessions(
                [ProposedSession(goalId: goal.id, date: draft.sessionDate, taskIds: taskIds)],
                overrideConflicts: false
            )
        }

        UserDefaults.standard.set(draft.reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(draft.reminderHour, forKey: "reminderHour")
        UserDefaults.standard.set(draft.reminderMinute, forKey: "reminderMinute")
        ReminderScheduler.shared.updateSchedule(
            enabled: draft.reminderEnabled,
            hour: draft.reminderHour,
            minute: draft.reminderMinute
        )

        UserDefaults.standard.set(true, forKey: AppSessionStore.onboardingCompletedKey)
        route = .ready
    }

    static let onboardingCompletedKey = "matmind.hasCompletedOnboarding"

    /// Fixed account used when running without authentication (local-only mode).
    static let localAccount = UserAccount(
        id: "local",
        provider: .apple,
        providerSubjectId: "local-device"
    )
}

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

    /// A goal qualifies for a bounty once it's been worked for 2+ weeks: created at
    /// least 14 days ago and has at least one completed session. The `MATMIND_FORCE_BOUNTY`
    /// launch env var force-unlocks eligibility for QA.
    func isGoalBountyEligible(_ goalId: String) -> Bool {
        guard let goal = goal(id: goalId), !goal.isArchived, goal.name.nilIfBlank != nil else { return false }
        #if DEBUG
        if ProcessInfo.processInfo.environment["MATMIND_FORCE_BOUNTY"] == "1" {
            return notebook.sessions.contains { $0.goalId == goalId }
        }
        #endif
        guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) else { return false }
        let hasActivity = notebook.sessions.contains { $0.goalId == goalId && $0.status == .done }
        return goal.createdAt <= twoWeeksAgo && hasActivity
    }

    var hasBountyEligibleGoal: Bool {
        activeGoals.contains { isGoalBountyEligible($0.id) }
    }

    /// Tasks the user can turn into a bounty: any task under a goal worked 2+ weeks,
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

    /// TEMPORARY demo data for testing. Re-seeds when `seedVersion` changes. Remove before shipping.
    func seedDemoDataIfEmpty() {
        let seedKey = "matmind.debugSeedVersion"
        let seedVersion = "v3-2goals-3sessions-2reflections-photos"
        let alreadySeeded = UserDefaults.standard.string(forKey: seedKey) == seedVersion
        if alreadySeeded && !notebook.goals.isEmpty { return }

        let acct = notebook.accountId
        func day(_ offset: Int) -> Date {
            calendar.normalizedTrainingDay(calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date())
        }

        // Renders a simple colored placeholder image so attached photos are visible in the UI.
        func placeholderImage(_ fill: UIColor, _ caption: String) -> Data {
            let size = CGSize(width: 640, height: 380)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { ctx in
                fill.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                UIColor.white.withAlphaComponent(0.12).setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: size.width - 200, y: -120, width: 320, height: 320))
                UIColor.black.withAlphaComponent(0.20).setFill()
                ctx.fill(CGRect(x: 0, y: size.height - 92, width: size.width, height: 92))
                let para = NSMutableParagraphStyle()
                para.lineBreakMode = .byTruncatingTail
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: para
                ]
                NSAttributedString(string: caption, attributes: attrs)
                    .draw(in: CGRect(x: 28, y: size.height - 66, width: size.width - 56, height: 48))
            }
            return image.jpegData(compressionQuality: 0.85) ?? Data()
        }

        func savePhoto(_ taskId: String, _ fill: UIColor, _ caption: String) -> [String] {
            guard let jsonPersistence = persistence as? JSONNotebookPersistence else { return [] }
            let fileName = "\(UUID().uuidString).jpg"
            let data = placeholderImage(fill, caption)
            guard (try? jsonPersistence.saveTaskImage(accountId: acct, taskId: taskId, imageData: data, fileName: fileName)) != nil else { return [] }
            return [fileName]
        }

        let indigoUI = UIColor(red: 63/255, green: 61/255, blue: 158/255, alpha: 1)
        let mintUI = UIColor(red: 94/255, green: 196/255, blue: 182/255, alpha: 1)

        // Goal 1 — Passing open guard (indigo); first task has a description + photo.
        let g1 = TrainingGoal(accountId: acct, name: "Passing open guard", iconName: "target", colorName: "indigo")
        var chaseHip = TrainingTask(goalId: g1.id, name: "Chase hip/torso",
            notes: "Clear whatever obstacle blocks the torso. Control the hip first with a leg on their tailbone, then address their arm framing before stepping around.")
        chaseHip.imageFileNames = savePhoto(chaseHip.id, indigoUI, "Hip control drill")
        let sepKnee = TrainingTask(goalId: g1.id, name: "Separate knee + elbow",
            notes: "Create the gap between their knee and elbow, then drive your hips through to begin the pass.")

        // Goal 2 — Leg locks (mint); first task has a description + photo.
        let g2 = TrainingGoal(accountId: acct, name: "Leg locks", iconName: "bolt.fill", colorName: "mint")
        var insideHeel = TrainingTask(goalId: g2.id, name: "Inside heel hook",
            notes: "Control the knee line, expose the heel, and rotate from your hips — never the hands. Stay tight to kill their rotation.")
        insideHeel.imageFileNames = savePhoto(insideHeel.id, mintUI, "Heel exposure")
        let ashiEntry = TrainingTask(goalId: g2.id, name: "Ashi garami entry",
            notes: "Off-balance them, secure the outside leg, and establish ashi garami before attacking the foot.")

        // 3 sessions: one planned today (Next Session) + two completed past days (with reflections).
        func sess(_ goal: TrainingGoal, _ offset: Int, _ taskIds: [String], _ status: SessionStatus = .planned) -> PlannedSession {
            PlannedSession(goalId: goal.id, date: day(offset), taskIds: taskIds, status: status, createdAt: day(offset))
        }
        let s1 = sess(g1, 0, [chaseHip.id, sepKnee.id])
        let s2 = sess(g1, -2, [chaseHip.id], .done)
        let s3 = sess(g2, -4, [insideHeel.id], .done)

        // Two reflections so Latest Entry + Patterns are populated for testing.
        let r1 = Reflection(
            sessionId: s2.id,
            date: day(-2),
            workedText: "Focusing on chasing the hip makes me move more; clearing the knee shield by push/pull then scooping and pushing the knee.\n- Cross-face frame is effective in keeping their shoulder down.",
            stuckText: "- Got swept by knee lever.\n- Hard time clearing the low knee shield, especially when John locked his feet.",
            tryNextText: "- Clear the upper knee shield by push/pull, then use a scoop grip to extend and push the knee.",
            mood: .neutral,
            isFavorite: true
        )
        let r2 = Reflection(
            sessionId: s3.id,
            date: day(-4),
            workedText: "Staying tight to the hip killed their rotation and let me keep the heel exposed.",
            stuckText: "Lost the position when I reached with my hands instead of rotating from the hips.",
            tryNextText: "Drill the ashi garami entry off a failed pass so the transition becomes automatic.",
            mood: .good,
            isFavorite: false
        )

        mutate {
            notebook.goals = [g1, g2]
            notebook.tasks = [chaseHip, sepKnee, insideHeel, ashiEntry]
            notebook.sessions = [s1, s2, s3]
            notebook.reflections = [r1, r2]
        }
        UserDefaults.standard.set(seedVersion, forKey: seedKey)
    }
#endif
}

// MARK: - Root

struct RootView: View {
    @ObservedObject var sessionStore: AppSessionStore
    @ObservedObject private var networkStatus = NetworkStatusStore()

    var body: some View {
        Group {
            if sessionStore.route == .signedOut {
                WelcomeView(
                    errorMessage: sessionStore.errorMessage,
                    isOffline: networkStatus.isOffline,
                    showsGoogleSignIn: GoogleSignInCoordinator.isConfigured,
                    onGoogle: { signIn(provider: .google) }
                )
            } else if sessionStore.route == .signedInMissingProfile {
                ProfileSetupView(
                    account: sessionStore.account,
                    profile: nil,
                    onSave: { first, last in
                        sessionStore.saveProfile(firstName: first, lastName: last)
                    },
                    onSignOut: sessionStore.signOut
                )
            } else if sessionStore.route == .onboarding {
                OnboardingContainerView(onComplete: { draft in
                    sessionStore.completeOnboarding(draft)
                })
            } else if let notebookStore = sessionStore.notebookStore {
                MainAppView(sessionStore: sessionStore, store: notebookStore)
            } else {
                WelcomeView(
                    errorMessage: "Session could not be restored.",
                    isOffline: networkStatus.isOffline,
                    showsGoogleSignIn: GoogleSignInCoordinator.isConfigured,
                    onGoogle: { signIn(provider: .google) }
                )
            }
        }
        .accentColor(AppColors.indigo)
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private func signIn(provider: AuthProvider) {
        if networkStatus.isOffline {
            sessionStore.showOfflineSignInMessage(provider: provider)
        } else {
            sessionStore.signIn(provider: provider)
        }
    }
}

// MARK: - Onboarding Views

struct WelcomeView: View {
    var errorMessage: String?
    var isOffline: Bool = false
    var showsGoogleSignIn: Bool = true
    var onGoogle: () -> Void

    private var statusMessage: String? {
        errorMessage ?? (isOffline ? "You're offline. Saved training data works after sign-in, but signing in needs internet." : nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Color(.systemGray4)).frame(width: 300, height: 300)
                Circle().stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundColor(Color(.systemGray5)).frame(width: 210, height: 210)
                VStack(spacing: 18) {
                    Text("Intentional\nTraining Notes")
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                    VStack(spacing: 6) {
                        Text("Welcome to Intentional Training Notes")
                            .font(.caption)
                            .foregroundColor(AppColors.label)
                            .uppercaseTracking()
                        Text("Train with more intentionality.\nGet better, faster.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            Spacer()
            VStack(spacing: 10) {
                if let statusMessage = statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(errorMessage == nil ? .secondary : AppColors.coral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Button(action: onGoogle) {
                    HStack {
                        Text("G")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Text("Continue with Google")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("By continuing you agree to our Terms & Privacy.")
                    .font(.caption)
                    .foregroundColor(AppColors.label)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }
}

struct ProfileSetupView: View {
    var account: UserAccount?
    var profile: UserProfile?
    var onSave: (String, String) -> Void
    var onSignOut: () -> Void

    @State private var firstName = ""
    @State private var lastName = ""

    private var canSave: Bool {
        firstName.nilIfBlank != nil && lastName.nilIfBlank != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "Profile", rightTitle: "Sign out", rightAction: onSignOut)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Finish your setup")
                            .font(.title)
                            .fontWeight(.medium)
                        Text("This keeps your training notebook tied to the right account on this device.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.label)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("First name").fieldLabel()
                        TextField("Alex", text: $firstName)
                            .textFieldStyle(TrainingTextFieldStyle())
                        Text("Last name").fieldLabel()
                        TextField("Rivera", text: $lastName)
                            .textFieldStyle(TrainingTextFieldStyle())
                    }

                }
                .padding(20)
            }
            Button("Save Profile") {
                onSave(firstName, lastName)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave)
            .padding()
        }
        .onAppear {
            guard firstName.isEmpty, lastName.isEmpty else { return }
            if let profile = profile {
                firstName = profile.firstName
                lastName = profile.lastName
                return
            }
            guard let displayName = account?.displayName else { return }
            let parts = displayName.split(separator: " ")
            firstName = parts.first.map(String.init) ?? ""
            lastName = parts.dropFirst().joined(separator: " ")
        }
    }
}

// MARK: - Onboarding Flow

/// Everything captured during first-run onboarding, handed to `AppSessionStore.completeOnboarding`.
struct OnboardingDraft {
    var goalName: String
    var iconName: String = "target"
    var colorName: String = "indigo"
    var taskNames: [String]
    var firstTaskDescription: String = ""
    var sessionDate: Date
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
}

/// Static, illustrative example tasks shown under the first-task field. Intentionally a fixed list
/// (not derived from the live goal text) so typing in the goal field never rebuilds this section —
/// a changing list here would churn `WrappingHStack`'s layout state and drop the keyboard.
enum OnboardingSuggestions {
    static let examples = ["Break their posture", "Hip escape to angle", "Two-on-one grip", "Lasso grip"]
}

struct OnboardingContainerView: View {
    var onComplete: (OnboardingDraft) -> Void

    private enum Step { case splash, goal, session }
    @State private var step: Step = OnboardingContainerView.initialStep

    @State private var goalName = ""
    @State private var firstTask = ""
    @State private var firstTaskDescription = ""
    @State private var extraTasks: [String] = []
    @State private var sessionDay: Date = Calendar.current.normalizedTrainingDay(Date())
    @State private var reminderEnabled = true
    @State private var reminderHour = 8
    @State private var reminderMinute = 0

    var body: some View {
        ZStack {
            if step == .splash {
                OnboardingSplashView(onNext: { go(.goal) })
                    .transition(.opacity)
            } else if step == .goal {
                OnboardingGoalStepView(
                    goalName: $goalName,
                    firstTask: $firstTask,
                    firstTaskDescription: $firstTaskDescription,
                    onBack: { go(.splash) },
                    onNext: { go(.session) }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                OnboardingSessionStepView(
                    goalName: goalName,
                    firstTask: firstTask,
                    extraTasks: $extraTasks,
                    sessionDay: $sessionDay,
                    reminderEnabled: $reminderEnabled,
                    reminderHour: $reminderHour,
                    reminderMinute: $reminderMinute,
                    onBack: { go(.goal) },
                    onSkip: { finish(useDefaults: true) },
                    onStart: { finish(useDefaults: false) }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private func go(_ next: Step) {
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }

    /// DEBUG-only deep link into a specific onboarding step for screenshot/QA, mirroring
    /// `MainAppView.initialTab`'s `START_TAB` override.
    static private var initialStep: Step {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["ONBOARDING_STEP"] {
        case "goal": return .goal
        case "session": return .session
        default: return .splash
        }
        #else
        return .splash
        #endif
    }

    private func finish(useDefaults: Bool) {
        let goal = goalName.trimmingCharacters(in: .whitespacesAndNewlines)
        var tasks = [firstTask.trimmingCharacters(in: .whitespacesAndNewlines)]
        tasks.append(contentsOf: extraTasks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        tasks = tasks.filter { !$0.isEmpty }

        let day = useDefaults ? Calendar.current.normalizedTrainingDay(Date()) : sessionDay
        let hour = useDefaults ? 8 : reminderHour
        let minute = useDefaults ? 0 : reminderMinute

        onComplete(
            OnboardingDraft(
                goalName: goal,
                taskNames: tasks,
                firstTaskDescription: firstTaskDescription,
                sessionDate: day,
                reminderEnabled: reminderEnabled,
                reminderHour: hour,
                reminderMinute: minute
            )
        )
    }
}

// MARK: Onboarding · shared pieces

/// The Mat Mind "MM" monogram stroke used on the splash.
struct MatMindMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 120
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var path = Path()
        path.move(to: p(26, 88))
        path.addLine(to: p(26, 40))
        path.addLine(to: p(48, 64))
        path.addLine(to: p(70, 40))
        path.addLine(to: p(70, 64))
        path.addLine(to: p(92, 40))
        path.addLine(to: p(92, 88))
        return path
    }
}

private struct OnboardingProgressHeader: View {
    let step: Int          // 1 or 2
    let trailingLabel: String
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .frame(width: 32, height: 32, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            HStack(spacing: 7) {
                Capsule().fill(step == 1 ? AppColors.indigo : Color(red: 0.85, green: 0.83, blue: 0.80))
                    .frame(width: step == 1 ? 26 : 8, height: 6)
                Capsule().fill(step == 2 ? AppColors.indigo : Color(red: 0.85, green: 0.83, blue: 0.80))
                    .frame(width: step == 2 ? 26 : 8, height: 6)
                Spacer()
                Text(trailingLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
    }
}

private struct OnboardingFieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .tracking(1)
            .foregroundColor(AppColors.tertiaryLabel)
    }
}

private struct OnboardingIconTile: View {
    let systemName: String
    var body: some View {
        RoundedRectangle(cornerRadius: 11)
            .fill(AppColors.indigo.opacity(0.12))
            .frame(width: 38, height: 38)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.indigo)
            )
    }
}

// MARK: Onboarding · 1 · Splash

struct OnboardingSplashView: View {
    var onNext: () -> Void

    @State private var drawn = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 63/255, green: 61/255, blue: 158/255),
                    Color(red: 74/255, green: 63/255, blue: 160/255),
                    Color(red: 91/255, green: 71/255, blue: 166/255)
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppColors.mint.opacity(0.28))
                        .frame(width: 132, height: 132)
                        .blur(radius: 26)
                        .scaleEffect(pulse ? 1.08 : 0.92)
                    MatMindMarkShape()
                        .trim(from: 0, to: drawn ? 1 : 0)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                        .frame(width: 118, height: 118)
                    Circle()
                        .fill(AppColors.mint)
                        .frame(width: 13, height: 13)
                        .offset(x: 0, y: -19)
                        .opacity(drawn ? 1 : 0)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                }
                .frame(width: 148, height: 148)
                .padding(.bottom, 34)

                VStack(spacing: 14) {
                    Text("MAT MIND")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.62))
                    Text("Train with\nintention.")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                    Text("Make progress faster.")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.72))
                }

                Spacer()

                VStack(spacing: 18) {
                    Button(action: onNext) {
                        HStack(spacing: 9) {
                            Text("Next")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(AppColors.indigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(18)
                        .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 12)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("No account needed. Nothing to sign up for.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4)) { drawn = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: Onboarding · 2 · Goal & task

struct OnboardingGoalStepView: View {
    @Binding var goalName: String
    @Binding var firstTask: String
    @Binding var firstTaskDescription: String
    var onBack: () -> Void
    var onNext: () -> Void

    private var canContinue: Bool {
        goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && firstTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OnboardingProgressHeader(step: 1, trailingLabel: "Required", onBack: onBack)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 11) {
                        Text("What do you\nwant to get\nbetter at?")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.label)
                            .lineSpacing(1)
                        Text("Name one focus to train. Add the tasks you’ll drill inside it — you can change all of this later.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 26)

                    // Goal
                    OnboardingFieldLabel(text: "Your goal")
                        .padding(.bottom, 9)
                    HStack(spacing: 11) {
                        OnboardingIconTile(systemName: "target")
                        TextField("Closed Guard", text: $goalName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                            .accentColor(AppColors.indigo)
                    }
                    .padding(16)
                    .background(AppColors.background)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.indigo, lineWidth: 2))
                    .cornerRadius(16)
                    .shadow(color: AppColors.indigo.opacity(0.18), radius: 12, x: 0, y: 4)
                    .padding(.bottom, 22)

                    // First task
                    OnboardingFieldLabel(text: "First task to work on")
                        .padding(.bottom, 9)
                    HStack(spacing: 11) {
                        OnboardingIconTile(systemName: "pencil")
                        TextField("Standup", text: $firstTask)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                            .accentColor(AppColors.indigo)
                    }
                    .padding(15)
                    .background(AppColors.background)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.08), lineWidth: 1.5))
                    .cornerRadius(16)

                    // Example tasks — static, illustrative examples shown under the first-task
                    // field (not tappable, and independent of the goal text so typing above never
                    // rebuilds this section).
                    Text("Example tasks")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .padding(.top, 14)
                        .padding(.bottom, 10)

                    WrappingHStack(items: OnboardingSuggestions.examples.map { IdentifiableString($0) }) { item in
                        Text(item.value)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.indigo)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppColors.indigo.opacity(0.1))
                            .cornerRadius(14)
                    }
                    .allowsHitTesting(false)

                    // Task description (free-form, optional)
                    OnboardingFieldLabel(text: "Task description")
                        .padding(.top, 22)
                        .padding(.bottom, 9)
                    TrainingTextView(text: $firstTaskDescription, placeholder: "Pin their shoulders to the ground")
                        .frame(minHeight: 92)

                    // Session peek
                    VStack(alignment: .leading, spacing: 7) {
                        Divider()
                            .padding(.bottom, 17)
                        OnboardingFieldLabel(text: "Plan your first session")
                        Text("Next you’ll pick when you’ll train it ↓")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                    .padding(.top, 30)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            // Next CTA
            Button(action: onNext) {
                HStack(spacing: 9) {
                    Text("Next")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(canContinue ? AppColors.indigo : Color(.systemGray3))
                .cornerRadius(18)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 30)
            .background(AppColors.background.edgesIgnoringSafeArea(.bottom))
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }
}

/// Small Identifiable wrapper so `String` suggestions work with `FlowWrap`.
struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}

// MARK: Onboarding · 3 · Plan session

struct OnboardingSessionStepView: View {
    let goalName: String
    let firstTask: String
    @Binding var extraTasks: [String]
    @Binding var sessionDay: Date
    @Binding var reminderEnabled: Bool
    @Binding var reminderHour: Int
    @Binding var reminderMinute: Int
    var onBack: () -> Void
    var onSkip: () -> Void
    var onStart: () -> Void

    @State private var showDayPicker = false
    @State private var showTimePicker = false

    private var timeLabel: String {
        let h = reminderHour % 12 == 0 ? 12 : reminderHour % 12
        let period = reminderHour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, reminderMinute, period)
    }

    private var dayLabel: String {
        if Calendar.current.isDateInToday(sessionDay) {
            let f = DateFormatter(); f.dateFormat = "MMM d"
            return "Today, \(f.string(from: sessionDay))"
        }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: sessionDay)
    }

    private var timeBinding: Binding<Date> {
        Binding<Date>(
            get: { Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date() },
            set: {
                reminderHour = Calendar.current.component(.hour, from: $0)
                reminderMinute = Calendar.current.component(.minute, from: $0)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        OnboardingProgressHeader(step: 2, trailingLabel: "", onBack: onBack)
                        Spacer()
                        Button(action: onSkip) {
                            Text("Skip")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 48)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 11) {
                        Text("When will you\ntrain it?")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.label)
                            .lineSpacing(1)
                        Text("Plan your first session. We’ll have it ready on Home when you step on the mat.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                            .lineSpacing(2)
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 22)

                    sessionCard

                    // Reminder toggle
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(AppColors.mint.opacity(0.18))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(Color(red: 61/255, green: 161/255, blue: 147/255))
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Remind me at \(timeLabel)")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Text("A gentle nudge, never a guilt trip")
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                        Spacer()
                        OnboardingPillToggle(isOn: $reminderEnabled)
                    }
                    .padding(15)
                    .background(AppColors.background)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black.opacity(0.06), lineWidth: 1))
                    .cornerRadius(16)
                    .padding(.top, 16)

                    // Start CTA
                    Button(action: onStart) {
                        HStack(spacing: 9) {
                            Text("Start training")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                            Image(systemName: "arrow.right").font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppColors.indigo)
                        .cornerRadius(18)
                        .shadow(color: AppColors.indigo.opacity(0.5), radius: 18, x: 0, y: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 22)

                    Text("Everything stays on your device.\nNo account, no cloud, no sign-in.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle().fill(AppColors.mint).frame(width: 7, height: 7)
                Text("FIRST SESSION")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(Color.white.opacity(0.72))
            }

            Text(goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your goal" : goalName)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 14)

            // Day + Time
            HStack(spacing: 10) {
                pickerTile(title: "Day", value: dayLabel, expanded: showDayPicker) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDayPicker.toggle(); if showDayPicker { showTimePicker = false }
                    }
                }
                pickerTile(title: "Time", value: timeLabel, expanded: showTimePicker) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTimePicker.toggle(); if showTimePicker { showDayPicker = false }
                    }
                }
                .frame(width: 128)
            }
            .padding(.top, 16)

            if showDayPicker {
                DatePicker("", selection: $sessionDay, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            if showTimePicker {
                DatePicker("", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }

            // Tasks
            Text("TASKS")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.top, 20)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                taskRow(firstTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "First task" : firstTask)
                ForEach(extraTasks.indices, id: \.self) { i in
                    taskRow(extraTasks[i])
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 63/255, green: 61/255, blue: 158/255),
                    Color(red: 77/255, green: 63/255, blue: 159/255),
                    Color(red: 91/255, green: 71/255, blue: 166/255)
                ]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .cornerRadius(24)
        .shadow(color: AppColors.indigo.opacity(0.5), radius: 26, x: 0, y: 16)
    }

    private func pickerTile(title: String, value: String, expanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(Color.white.opacity(0.6))
                HStack(spacing: 6) {
                    Text(value)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.white.opacity(0.12))
            .cornerRadius(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func taskRow(_ name: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.mint)
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(AppColors.indigo)
                )
            Text(name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Indigo pill switch matching the onboarding prototype (avoids iOS-14-only tinted `SwitchToggleStyle`).
struct OnboardingPillToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.18)) { isOn.toggle() } }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? AppColors.indigo : Color(.systemGray4))
                    .frame(width: 48, height: 28)
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: Color.black.opacity(0.3), radius: 1.5, x: 0, y: 1)
                    .padding(3)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Main Shell

enum MainTab {
    case home
    case plan
    case goals
}

enum GoalsRoute: Equatable {
    case list
    case detail(String)
}

private enum MainSheet: Identifiable {
    case planning(String?)
    case reflect(String)
    case addGoal
    var id: String {
        switch self {
        case .planning(let g): return "plan-\(g ?? "new")"
        case .reflect(let s): return "reflect-\(s)"
        case .addGoal: return "addGoal"
        }
    }
}

struct MainAppView: View {
    @ObservedObject var sessionStore: AppSessionStore
    @ObservedObject var store: NotebookStore

    @State private var tab: MainTab = MainAppView.initialTab

    static var initialTab: MainTab {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["START_TAB"] {
        case "goals": return .goals
        case "plan": return .plan
        default: return .home
        }
        #else
        return .home
        #endif
    }
    @State private var stack: [GoalsRoute] = [.list]
    @State private var activeSheet: MainSheet?
    @State private var showCantReflect = false
    @State private var reflectResetToken = UUID()

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                if tab == .home {
                    HomeView(store: store, onOpenGoalTasks: { goalId in
                        stack = [.list, .detail(goalId)]
                        tab = .goals
                    }, onReflect: { sessionId in
                        requestReflect(sessionId)
                    }, onPlanTraining: {
                        activeSheet = .planning(nil)
                    }, onAddGoal: {
                        activeSheet = .addGoal
                    })
                } else if tab == .plan {
                    PlanListView(
                        store: store,
                        onAdd: {
                            activeSheet = .planning(nil)
                        },
                        onReflect: { sessionId in
                            requestReflect(sessionId)
                        }
                    )
                } else {
                    goalsScreen
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            BottomTabsView(
                active: tab,
                onHome: {
                    tab = .home
                },
                onGoals: {
                    tab = .goals
                    stack = [.list]
                },
                onPlan: {
                    tab = .plan
                }
            )
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .sheet(item: $activeSheet) { which in
            switch which {
            case .planning(let goalId):
                PlanTrainingView(
                    store: store,
                    onCancel: { activeSheet = nil },
                    onSaved: { created in
                        activeSheet = nil
                        if let first = created.first { routeToSession(first) }
                    },
                    initialGoalId: goalId
                )
            case .reflect(let sessionId):
                ReflectFlowView(
                    store: store,
                    initialSessionId: sessionId,
                    resetToken: reflectResetToken,
                    onClose: { activeSheet = nil },
                    onFinish: { _ in activeSheet = nil }
                )
            case .addGoal:
                AddGoalSheet(store: store, onDone: { activeSheet = nil })
            }
        }
        .alert(isPresented: $showCantReflect) {
            Alert(
                title: Text("Session hasn't happened yet"),
                message: Text("You can reflect after your session is done."),
                dismissButton: .default(Text("Got it"))
            )
        }
    }

    private func requestReflect(_ sessionId: String) {
        if store.canReflect(sessionId: sessionId) {
            reflectResetToken = UUID()
            activeSheet = .reflect(sessionId)
        } else {
            showCantReflect = true
        }
    }

    private var goalsScreen: some View {
        Group {
            switch stack.last ?? .list {
            case .list:
                GoalListView(store: store)
            case .detail(let goalId):
                GoalDetailView(
                    store: store,
                    goalId: goalId,
                    onBack: { pop() }
                )
            }
        }
    }

    private func pop() {
        if stack.count > 1 {
            stack.removeLast()
        }
    }

    private func routeToSession(_ session: PlannedSession) {
        stack = [.list, .detail(session.goalId)]
    }
}

// MARK: - HomeView

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
struct BountyFlowView: View {
    @ObservedObject var store: NotebookStore
    var onClose: () -> Void

    @State private var step = 0
    @State private var kind: BountyKind?
    @State private var selectedTaskId: String?
    @State private var count = 5
    @State private var partner = ""

    private var eligible: [(task: TrainingTask, goal: TrainingGoal, sessionCount: Int)] {
        store.bountyEligibleTasks()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch step {
                    case 0: pickChallengeStep
                    case 1: pickTechniqueStep
                    default: setTargetStep
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            footer
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private var header: some View {
        HStack {
            Button(action: { if step == 0 { onClose() } else { step -= 1 } }) {
                HStack(spacing: 3) {
                    Image(systemName: step == 0 ? "xmark" : "chevron.left")
                    Text(step == 0 ? "Cancel" : "Back")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(step == 0 ? AppColors.secondaryLabel : AppColors.indigo)
            }
            Spacer()
            Text("New Bounty")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            Spacer()
            Color.clear.frame(width: 56, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // Step 1
    private var pickChallengeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick your challenge")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
            Text("What do you want to hunt?")
                .font(.matMindBody(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 8)
            VStack(spacing: 14) {
                ForEach(BountyKind.allCases) { k in
                    bountyChoiceCard(k)
                }
            }
            .padding(.top, 20)
        }
    }

    private func bountyChoiceCard(_ k: BountyKind) -> some View {
        let selected = kind == k
        return Button(action: { kind = k }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.coral.opacity(selected ? 0.22 : 0.14))
                            .frame(width: 40, height: 40)
                        Image(systemName: k.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.coralDeep)
                    }
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.coralDeep)
                    }
                }
                Text(k.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .padding(.top, 12)
                Text(k.blurb)
                    .font(.matMindBody(size: 13))
                    .foregroundColor(AppColors.secondaryLabel)
                    .padding(.top, 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(selected ? AppColors.coral.opacity(0.08) : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selected ? AppColors.coral : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Step 2
    private var pickTechniqueStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Which technique?")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
            Text("Tasks from goals you've trained for 2+ weeks.")
                .font(.matMindBody(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 8)
            if eligible.isEmpty {
                Text("No eligible techniques yet. Keep training a goal for two weeks to unlock the hunt.")
                    .font(.matMindBody(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
                    .padding(.top, 20)
            } else {
                VStack(spacing: 11) {
                    ForEach(eligible, id: \.task.id) { item in
                        techniqueRow(item)
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    private func techniqueRow(_ item: (task: TrainingTask, goal: TrainingGoal, sessionCount: Int)) -> some View {
        let selected = selectedTaskId == item.task.id
        return Button(action: { selectedTaskId = item.task.id }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.task.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Text(item.goal.name)
                        .font(.matMindBody(size: 12.5))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                Spacer()
                Text("\(item.sessionCount) \(item.sessionCount == 1 ? "session" : "sessions")")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
            .padding(.horizontal, 15).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? AppColors.coral.opacity(0.08) : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? AppColors.coral : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Step 3
    private var setTargetStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set the target")
                .font(.system(size: 27, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
            Text("How many, and on who? Leave blank for either.")
                .font(.matMindBody(size: 14))
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 8)

            Text("HIT IT · HOW MANY TIMES")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 24).padding(.bottom, 10)
            HStack {
                stepperButton("minus") { if count > 1 { count -= 1 } }
                Spacer()
                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Text("TIMES")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundColor(AppColors.secondaryLabel)
                }
                Spacer()
                stepperButton("plus") { count += 1 }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))

            HStack {
                Text("WHO ARE YOU HUNTING?")
                Spacer()
                Text(kind == .hitCount ? "OPTIONAL" : "REQUIRED").foregroundColor(AppColors.tertiaryLabel)
            }
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundColor(AppColors.secondaryLabel)
            .padding(.top, 22).padding(.bottom, 10)
            TextField("Name a partner", text: $partner)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.label)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground))

            VStack(alignment: .leading, spacing: 6) {
                Text("PREVIEW")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(AppColors.coralDeep)
                Text(previewText())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
                Text("No deadline. Hunt at your own pace.")
                    .font(.matMindBody(size: 12.5))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.coral)
                    .frame(width: 4)
                    .frame(maxWidth: .infinity, alignment: .leading),
                alignment: .leading
            )
            .padding(.top, 20)
        }
    }

    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.label)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.secondaryBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func previewText() -> String {
        let name = store.task(id: selectedTaskId ?? "")?.name ?? "it"
        var s = "Hit \(name)"
        if let p = partner.nilIfBlank { s += " on \(p)" }
        if count > 1 { s += ", \(count)×" }
        return s + "."
    }

    private var footer: some View {
        VStack(spacing: 0) {
            Button(action: advance) {
                Text(step == 2 ? "Start Bounty" : "Next")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16).fill(step == 2 ? AppColors.coralDeep : AppColors.indigo))
                    .opacity(canAdvance ? 1 : 0.4)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(AppColors.background)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return kind != nil
        case 1: return selectedTaskId != nil
        default:
            // Hit count doesn't need a partner; targeting a partner does.
            return kind == .hitCount || partner.nilIfBlank != nil
        }
    }

    private func advance() {
        guard canAdvance else { return }
        if step < 2 {
            step += 1
        } else if let taskId = selectedTaskId, let kind = kind {
            store.createBounty(taskId: taskId, kind: kind, targetCount: count, targetPartner: partner)
            onClose()
        }
    }
}

// MARK: - Bounty Collection

/// Trophy shelf of collected bounties, plus a celebration hero for the most recent.
struct BountyCollectionView: View {
    @ObservedObject var store: NotebookStore
    var onClose: () -> Void

    @State private var showFlow = false

    private var collected: [Bounty] { store.collectedBounties }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let latest = collected.first {
                        celebrationHero(latest)
                        featuredTrophy(latest)
                        if collected.count > 1 {
                            miniGrid(Array(collected.dropFirst()))
                        }
                    } else {
                        emptyState
                    }
                    newBountyButton
                        .padding(.top, 22)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 30)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $showFlow) {
            BountyFlowView(store: store, onClose: { showFlow = false })
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.left")
                    Text("Home")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.indigo)
            }
            Spacer()
            Text("Collection")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            Spacer()
            Color.clear.frame(width: 56, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func celebrationHero(_ bounty: Bounty) -> some View {
        let stats = store.bountyStats(bounty)
        let name = store.task(id: bounty.taskId)?.name ?? "your technique"
        var summary = "\(name.capitalizedFirst), landed \(stats.hits)×"
        if let p = bounty.targetPartner?.nilIfBlank { summary += " on \(p)" }
        summary += " over \(stats.days) \(stats.days == 1 ? "day" : "days")."
        return VStack(spacing: 6) {
            Text("🏆")
                .font(.system(size: 60))
                .padding(.top, 6)
            Text("BOUNTY COLLECTED")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(AppColors.gold)
            Text("You hunted it down.")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
                .padding(.top, 4)
            Text(summary)
                .font(.matMindBody(size: 13))
                .foregroundColor(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            HStack(spacing: 6) {
                Text("🏆 \(collected.count) \(collected.count == 1 ? "bounty" : "bounties") collected")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.gold)
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Capsule().fill(AppColors.gold.opacity(0.16)))
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private func featuredTrophy(_ bounty: Bounty) -> some View {
        let stats = store.bountyStats(bounty)
        let name = store.task(id: bounty.taskId)?.name ?? "Technique"
        var sub = "\(bounty.hitCount) \(bounty.hitCount == 1 ? "hit" : "hits")"
        if let p = bounty.targetPartner?.nilIfBlank { sub = "on \(p) · " + sub }
        return VStack(alignment: .leading, spacing: 6) {
            Text(collectedMeta(bounty))
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundColor(AppColors.gold)
            Text(name)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            Text(sub)
                .font(.matMindBody(size: 13))
                .foregroundColor(AppColors.secondaryLabel)
            HStack(spacing: 8) {
                statBox("SESSIONS", stats.sessions)
                statBox("DAYS", stats.days)
                statBox("HITS", stats.hits)
            }
            .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.gold)
                .frame(height: 3)
                .frame(maxWidth: .infinity, alignment: .top),
            alignment: .top
        )
        .padding(.top, 16)
    }

    private func statBox(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundColor(AppColors.secondaryLabel)
            Text("\(value)")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundColor(AppColors.label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.secondaryBackground))
    }

    private func miniGrid(_ bounties: [Bounty]) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(stride(from: 0, to: bounties.count, by: 2)), id: \.self) { i in
                HStack(spacing: 10) {
                    miniCard(bounties[i])
                    if i + 1 < bounties.count {
                        miniCard(bounties[i + 1])
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    private func miniCard(_ bounty: Bounty) -> some View {
        let name = store.task(id: bounty.taskId)?.name ?? "Technique"
        var sub = DateFormatter.monthDay.string(from: bounty.collectedAt ?? bounty.createdAt)
        if let p = bounty.targetPartner?.nilIfBlank {
            sub += " · on \(p)"
        } else {
            sub += " · \(bounty.hitCount)×"
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("🏆").font(.system(size: 20))
            Text(name)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(sub)
                .font(.matMindBody(size: 11))
                .foregroundColor(AppColors.secondaryLabel)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("🏆").font(.system(size: 52)).opacity(0.5)
            Text("No bounties collected yet")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            Text("Land your first hunt and it'll live here.")
                .font(.matMindBody(size: 13))
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    @ViewBuilder
    private var newBountyButton: some View {
        if store.activeBounty == nil && store.hasBountyEligibleGoal {
            Button(action: { showFlow = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("New bounty")
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.coralDeep))
            }
            .buttonStyle(PlainButtonStyle())
        } else if store.activeBounty != nil {
            Text("Finish your active hunt before starting a new one.")
                .font(.matMindBody(size: 12.5))
                .foregroundColor(AppColors.secondaryLabel)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func collectedMeta(_ bounty: Bounty) -> String {
        let d = bounty.collectedAt ?? bounty.createdAt
        let f = DateFormatter()
        f.dateFormat = "MMM d · h:mm a"
        return f.string(from: d).uppercased()
    }
}

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

struct SettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showReminders = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    settingsRow(icon: "bell.fill", iconColor: Color(red: 0.9, green: 0.4, blue: 0.4), label: "Reminders", showDivider: true) {
                        showReminders = true
                    }
                    settingsRow(icon: "star.fill", iconColor: AppColors.mint, label: "Rate Mat Mind", showDivider: true) {
                        openAppStoreRating()
                    }
                    settingsRow(icon: "envelope.fill", iconColor: AppColors.indigo, label: "Feedback", showDivider: false) {
                        // Placeholder — no action yet
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.groupedBackground.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    Text("Back")
                }
                .foregroundColor(AppColors.indigo)
            })
            .sheet(isPresented: $showReminders) {
                RemindersSettingsView()
            }
        }
    }

    private func settingsRow(icon: String, iconColor: Color, label: String, showDivider: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconColor)
                        .frame(width: 28)
                    Text(label)
                        .font(.system(size: 17, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(.systemGray3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            if showDivider {
                Divider().padding(.leading, 58)
            }
        }
    }

    private func openAppStoreRating() {
        let appId = "com.tienmai.intentionaltrainingnotes"
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appId)?action=write-review") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - Reminders Settings

struct RemindersSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var reminderEnabled: Bool = UserDefaults.standard.object(forKey: "reminderEnabled") as? Bool ?? true
    @State private var reminderHour: Int = UserDefaults.standard.object(forKey: "reminderHour") as? Int ?? 8
    @State private var reminderMinute: Int = UserDefaults.standard.object(forKey: "reminderMinute") as? Int ?? 0
    @State private var showTimePicker = false

    private var timeLabel: String {
        let h = reminderHour % 12 == 0 ? 12 : reminderHour % 12
        let period = reminderHour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, reminderMinute, period)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                Text("REFLECTION REMINDER")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .kerning(0.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 10)

                VStack(spacing: 0) {
                    // Toggle row
                    HStack(spacing: 14) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
                            .frame(width: 28)
                        Text("Reflection reminder")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundColor(AppColors.label)
                        Spacer()
                        Toggle("", isOn: $reminderEnabled)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider().padding(.leading, 58)

                    // Time row
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showTimePicker.toggle() } }) {
                        HStack(spacing: 14) {
                            Image(systemName: "clock")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.secondaryLabel)
                                .frame(width: 28)
                            Text("Time")
                                .font(.system(size: 17, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Spacer()
                            Text(timeLabel)
                                .font(.system(size: 17, design: .rounded))
                                .foregroundColor(AppColors.secondaryLabel)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(.systemGray3))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(reminderEnabled ? 1.0 : 0.4)
                    .disabled(!reminderEnabled)

                    if showTimePicker && reminderEnabled {
                        DatePicker("", selection: Binding(
                            get: {
                                var comps = DateComponents()
                                comps.hour = reminderHour
                                comps.minute = reminderMinute
                                return Calendar.current.date(from: comps) ?? Date()
                            },
                            set: { newDate in
                                reminderHour = Calendar.current.component(.hour, from: newDate)
                                reminderMinute = Calendar.current.component(.minute, from: newDate)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                        .padding(.horizontal, 16)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
                .padding(.horizontal, 16)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.groupedBackground.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Reminders", displayMode: .inline)
            .navigationBarItems(leading: Button(action: { presentationMode.wrappedValue.dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                    Text("Back")
                }
                .foregroundColor(AppColors.indigo)
            })
            .onDisappear { saveAndSchedule() }
        }
    }

    private func saveAndSchedule() {
        UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(reminderHour, forKey: "reminderHour")
        UserDefaults.standard.set(reminderMinute, forKey: "reminderMinute")
        ReminderScheduler.shared.updateSchedule(enabled: reminderEnabled, hour: reminderHour, minute: reminderMinute)
    }
}

// MARK: - Reminder Scheduler

final class ReminderScheduler {
    static let shared = ReminderScheduler()
    private let notificationId = "matmind.reflection.reminder"

    func updateSchedule(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])

        guard enabled else { return }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time to reflect 📖"
            content.body = "How did training go? Take a minute to capture what worked and where you got stuck."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: self.notificationId, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }

    func scheduleDefaultIfNeeded() {
        let enabled = UserDefaults.standard.object(forKey: "reminderEnabled") as? Bool ?? true
        let hour = UserDefaults.standard.object(forKey: "reminderHour") as? Int ?? 8
        let minute = UserDefaults.standard.object(forKey: "reminderMinute") as? Int ?? 0
        updateSchedule(enabled: enabled, hour: hour, minute: minute)
    }
}

// MARK: - Reflection Card (Latest Entry + Patterns)

struct ReflectionCardView: View {
    @ObservedObject var store: NotebookStore
    let reflection: Reflection
    var onReflect: () -> Void
    var onDelete: () -> Void
    var onShareFeedback: () -> Void
    var filter: PatternKind = .all
    /// When true, header shows date + mood label instead of the goal name. Used by the
    /// per-task reflections screen where the goal/task context is already in the screen header.
    var dateMode: Bool = false
    /// When false, hides the "Get feedback" share button (used in contexts where sharing is out of scope).
    var showShareButton: Bool = true
    /// When false, hides the "..." overflow menu (edit/delete). Used by read-only-ish surfaces
    /// like the per-task reflections list where the only meaningful in-place action is favorite.
    var showMenu: Bool = true

    @State private var menuOpen = false

    var body: some View {
        let session = store.notebook.sessions.first { $0.id == reflection.sessionId }
        let goal = session.flatMap { store.goal(id: $0.goalId) }
        let color = goal?.goalColor ?? AppColors.indigo

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                if let mood = reflection.mood {
                    Text(mood.glyph).font(.system(size: 26))
                }
                if dateMode {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.dateLabel(reflection.date))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.label)
                        if let mood = reflection.mood {
                            Text(mood.label)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                } else {
                    Text(goal?.name ?? "Session")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if showShareButton {
                    Button(action: onShareFeedback) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.indigo)
                            .frame(width: 32, height: 28)
                            .background(Capsule().fill(AppColors.indigo.opacity(0.10)))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Button(action: { store.toggleFavorite(reflectionId: reflection.id) }) {
                    Image(systemName: reflection.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17))
                        .foregroundColor(reflection.isFavorite ? AppColors.coral : AppColors.tertiaryLabel)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
                if showMenu {
                    Button(action: { withAnimation(.easeInOut(duration: 0.15)) { menuOpen.toggle() } }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            if shows(.wins), let s = reflection.workedText.nilIfBlank {
                sectionBlock(text: s, accent: AppColors.winGreen, tintUI: AppColors.winGreenUI, label: "What worked")
            }
            if shows(.stuck), let s = reflection.stuckText.nilIfBlank {
                sectionBlock(text: s, accent: AppColors.stuckCoral, tintUI: AppColors.stuckCoralUI, label: "Where I got stuck")
            }
            if shows(.upNext), let s = reflection.tryNextText.nilIfBlank {
                sectionBlock(text: s, accent: AppColors.indigo, tintUI: AppColors.indigoUI, label: "What I'll try next")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
        .overlay(menuOverlay, alignment: .topTrailing)
    }

    private static func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func shows(_ kind: PatternKind) -> Bool {
        filter == .all || filter == kind
    }

    private func sectionBlock(text: String, accent: Color, tintUI: UIColor, label: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                Text(text)
                    .font(.matMindBody(size: 15))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.tint(tintUI, light: 0.10, dark: 0.22)))
    }

    @ViewBuilder
    private var menuOverlay: some View {
        if menuOpen {
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.001)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .fixedSize()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { menuOpen = false } }

                VStack(alignment: .leading, spacing: 0) {
                    Button(action: { menuOpen = false; onReflect() }) {
                        menuRowLabel(icon: "pencil", label: "Edit", color: AppColors.label)
                    }
                    .buttonStyle(PlainButtonStyle())
                    Divider().padding(.horizontal, 10)
                    Button(action: { menuOpen = false; onDelete() }) {
                        menuRowLabel(icon: "trash", label: "Delete", color: AppColors.coral)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(AppColors.background)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 2)
                .frame(width: 150)
                .padding(.top, 40)
                .padding(.trailing, 6)
            }
        }
    }

    private func menuRowLabel(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.matMindBody(size: 14)).foregroundColor(color)
            Text(label).font(.matMindBody(size: 15)).foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Feedback share card

struct FeedbackCardView: View {
    let goalName: String
    let tryNextText: String
    let mood: Mood?
    let dateLabel: String
    let recipient: String
    let accent: Color

    private var tryNextLines: [String] {
        tryNextText
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dateLabel)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                Rectangle().fill(accent).frame(width: 60, height: 3).cornerRadius(2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Dear \(recipient.nilIfBlank ?? "Friend"),")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
                Text("Please fix my jiu-jitsu:")
                    .font(.matMindBody(size: 16))
                    .foregroundColor(Color(red: 120/255, green: 117/255, blue: 113/255))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("What I was working on")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                Text(goalName)
                    .font(.system(size: 18, design: .rounded))
                    .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
            }
            if !tryNextLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What I'll try next")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                    ForEach(Array(tryNextLines.enumerated()), id: \.offset) { idx, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(accent)
                            Text(line)
                                .font(.system(size: 18, design: .rounded))
                                .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let mood = mood {
                HStack(spacing: 6) {
                    Text("Feeling:")
                        .font(.matMindBody(size: 16))
                        .foregroundColor(Color(red: 120/255, green: 117/255, blue: 113/255))
                    Text("\(mood.glyph) \(mood.label)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
                }
            }
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Thank you, see you on the mat.")
                    .font(.matMindBody(size: 16))
                    .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
                Text("xoxo")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
            }
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
            VStack(spacing: 2) {
                Text("Mat Mind")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                Text("matmind.com")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(red: 165/255, green: 161/255, blue: 155/255))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.offWhite))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.3), lineWidth: 1))
    }
}

struct FeedbackPreviewView: View {
    @ObservedObject var store: NotebookStore
    let reflection: Reflection
    var onClose: () -> Void

    @State private var recipient = ""
    @State private var accentName = "indigo"

    private let styles: [(name: String, color: Color)] = [
        ("indigo", AppColors.indigo),
        ("mint", AppColors.mint),
        ("coral", AppColors.coral),
        ("slate", Color(.systemGray)),
        ("blue", Color(.systemBlue)),
        ("purple", Color(.systemPurple)),
        ("teal", Color(.systemTeal))
    ]
    private var accent: Color { styles.first { $0.name == accentName }?.color ?? AppColors.indigo }

    private var goalName: String {
        guard let s = store.notebook.sessions.first(where: { $0.id == reflection.sessionId }) else { return "Training" }
        return store.goal(id: s.goalId)?.name ?? "Training"
    }
    private var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d, yyyy"; return f.string(from: reflection.date)
    }
    private var card: FeedbackCardView {
        FeedbackCardView(goalName: goalName, tryNextText: reflection.tryNextText, mood: reflection.mood, dateLabel: dateLabel, recipient: recipient, accent: accent)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.label)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text("Preview").font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Spacer().frame(width: 44)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Text("To:").font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(AppColors.label)
                        TextField("Friend's name", text: $recipient).font(.system(size: 17, design: .rounded))
                    }
                    .padding(.bottom, 8)
                    .overlay(Rectangle().fill(Color(.systemGray4)).frame(height: 1), alignment: .bottom)

                    card

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CARD STYLE")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .kerning(0.5)
                            .foregroundColor(AppColors.secondaryLabel)
                            .frame(maxWidth: .infinity)
                        HStack(spacing: 10) {
                            ForEach(styles, id: \.name) { style in
                                Button(action: { accentName = style.name }) {
                                    ZStack {
                                        Circle().fill(style.color).frame(width: 36, height: 36)
                                        if accentName == style.name {
                                            Circle().stroke(style.color, lineWidth: 2).frame(width: 46, height: 46)
                                        }
                                    }
                                    .frame(width: 46, height: 46)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
            }

            Button(action: share) {
                Text("Share")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 28).fill(AppColors.indigo))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    private func share() {
        let image = ShareSnapshot.image(of: card, width: 360)
        let activity = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        guard let root = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        if let pop = activity.popoverPresentationController {
            pop.sourceView = top.view
            pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 80, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        top.present(activity, animated: true)
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum ShareSnapshot {
    /// Renders a SwiftUI view to a UIImage (iOS 13-safe; no ImageRenderer).
    static func image<V: View>(of view: V, width: CGFloat) -> UIImage {
        let controller = UIHostingController(rootView: view.frame(width: width))
        let target = controller.view
        target?.backgroundColor = .clear
        let fitting = target?.systemLayoutSizeFitting(
            CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ) ?? CGSize(width: width, height: 480)
        let size = CGSize(width: width, height: max(fitting.height, 200))
        target?.frame = CGRect(origin: .zero, size: size)

        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }), let target = target {
            window.addSubview(target)
            target.setNeedsLayout()
            target.layoutIfNeeded()
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { _ in
                target.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            target.removeFromSuperview()
            return image
        }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(red: 240/255, green: 237/255, blue: 235/255, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Day Trend Point

struct DayTrendPoint {
    let date: Date
    let sessionCount: Int
    let mood: Mood?
}

// MARK: - Section Header

struct SectionHeader: View {
    var icon: String
    var title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.clear)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [AppColors.indigo, AppColors.indigo.opacity(0.55)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .mask(
                        Image(systemName: icon)
                            .font(.caption)
                    )
                )
            Text(title.uppercased())
                .font(.system(size: 11, design: .rounded))
                .tracking(0.8)
                .fontWeight(.medium)
                .foregroundColor(AppColors.label)
        }
    }
}

// MARK: - Period Tab Bar

struct HomePeriodTabBar: View {
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 0) {
            segmentButton("Week", value: "week")
            segmentButton("Month", value: "month")
        }
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }

    private func segmentButton(_ label: String, value: String) -> some View {
        Button(action: { selected = value }) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(selected == value ? AppColors.label : AppColors.tertiaryLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected == value ? AppColors.background : Color.clear)
                .cornerRadius(7)
                .padding(2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat Row

struct HomeStatRow: View {
    let value: Int
    let description: String
    let systemName: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemName)
                .font(.matMindBody(size: 16))
                .foregroundColor(iconColor)
            Text("\(value)")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.label)
            Text(description)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Next Session Section

struct HomeNextSessionSection: View {
    @ObservedObject var store: NotebookStore
    let sessions: [PlannedSession]
    var onOpenGoalTasks: (String) -> Void
    var onReflect: (String) -> Void
    var onPlanTraining: () -> Void
    @State private var expandedGoalIds: Set<String> = []

    private var cal: Calendar { Calendar.current }

    private var dateLabel: String {
        guard let session = sessions.first else { return "" }
        if cal.isDateInToday(session.date) { return "Today" }
        if cal.isDateInTomorrow(session.date) { return "Tomorrow" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return fmt.string(from: session.date)
    }

    /// Groups sessions by goalId, preserving order of first appearance.
    private var groupedByGoal: [(goalId: String, sessions: [PlannedSession])] {
        var order: [String] = []
        var map: [String: [PlannedSession]] = [:]
        for s in sessions {
            if map[s.goalId] == nil { order.append(s.goalId) }
            map[s.goalId, default: []].append(s)
        }
        return order.map { (goalId: $0, sessions: map[$0]!) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row outside cards
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.clear)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [AppColors.indigo, AppColors.indigo.opacity(0.55)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .mask(
                                Image(systemName: "calendar")
                                    .font(.caption)
                            )
                        )
                    Text("NEXT SESSION")
                        .font(.system(size: 11, design: .rounded))
                        .tracking(0.8)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.label)
                }
                Spacer()
                if !sessions.isEmpty {
                    Text(dateLabel)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }

            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Text("Nothing planned yet.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: onPlanTraining) {
                        Text("Plan Training")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.indigo)
                            .cornerRadius(8)
                    }
                }
                .padding(12)
                .cardBackground()
            } else {
                ForEach(groupedByGoal, id: \.goalId) { group in
                    let goal = store.goal(id: group.goalId)
                    let goalColor = goal?.goalColor ?? AppColors.indigo
                    let isExpanded = expandedGoalIds.contains(group.goalId)

                    let taskIds = group.sessions.flatMap { $0.taskIds }
                    let tasks: [TrainingTask] = {
                        var seen = Set<String>()
                        var result = [TrainingTask]()
                        for id in taskIds {
                            if seen.insert(id).inserted, let t = store.task(id: id) {
                                result.append(t)
                            }
                        }
                        return result
                    }()

                    VStack(alignment: .leading, spacing: 0) {
                        // Header row — matches Goal card design
                        HStack(spacing: 10) {
                            // Expand/collapse chevron
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedGoalIds.contains(group.goalId) {
                                        expandedGoalIds.remove(group.goalId)
                                    } else {
                                        expandedGoalIds.insert(group.goalId)
                                    }
                                }
                            }) {
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.label)
                                    .frame(width: 20, height: 20)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Goal icon
                            GoalIconImage(name: goal?.iconName ?? "figure.martial.arts", color: goalColor, size: 38)

                            // Title + subtitle
                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal?.name ?? "No goal")
                                    .font(.headline)
                                    .foregroundColor(AppColors.label)
                                let count = tasks.count
                                Text("\(count) \(count == 1 ? "task" : "tasks")")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.secondaryLabel)
                            }
                            Spacer()

                            // Reflect pencil icon
                            Button(action: {
                                if let first = group.sessions.first {
                                    onReflect(first.id)
                                }
                            }) {
                                ReflectPencilIcon(size: 22, color: .primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedGoalIds.contains(group.goalId) {
                                    expandedGoalIds.remove(group.goalId)
                                } else {
                                    expandedGoalIds.insert(group.goalId)
                                }
                            }
                        }

                        // Expanded task pills
                        if isExpanded && !tasks.isEmpty {
                            WrappingHStack(items: tasks) { task in
                                PlanTaskTagView(task: task, goalColor: goalColor)
                            }
                            .padding(.leading, 80)
                            .padding(.trailing, 16)
                            .padding(.bottom, 12)
                        }
                    }
                    .cardBackground()
                }
            }
        }
    }
}

// MARK: - Working On Section

struct HomeWorkingOnSection: View {
    @ObservedObject var store: NotebookStore
    let goals: [TrainingGoal]
    var onAddGoal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row outside card
            SectionHeader(icon: "target", title: "WORKING ON")

            if goals.isEmpty {
                VStack(spacing: 12) {
                    Text("No goals yet.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(action: onAddGoal) {
                        Text("Add Goal")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.indigo)
                            .cornerRadius(8)
                    }
                }
                .padding(12)
                .cardBackground()
            } else {
                ForEach(goals) { goal in
                    let tasks = store.tasks(forGoal: goal.id)
                    HStack(alignment: .top, spacing: 12) {
                        // Left icon
                        GoalIconImage(name: goal.iconName, color: goal.goalColor, size: 56)

                        // Content
                        VStack(alignment: .leading, spacing: 6) {
                            Text(goal.name)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppColors.label)
                                .lineLimit(2)

                            if !tasks.isEmpty {
                                WrappingHStack(items: tasks) { task in
                                    PlanTaskTagView(task: task, goalColor: goal.goalColor)
                                }
                            } else {
                                Text("No tasks yet.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(AppColors.secondaryLabel)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .cardBackground()
                }
            }
        }
    }
}

// MARK: - Snippet Section

struct HomeSnippetSection: View {
    let title: String
    let icon: String
    let snippets: [String]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row — outside the card, matching Next Session pattern
            SectionHeader(icon: icon, title: title)

            // Card content
            if snippets.isEmpty {
                Text(emptyText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .cardBackground()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(snippets.enumerated()), id: \.offset) { _, snippet in
                        Text("• " + snippet)
                            .font(.matMindBody(size: 15))
                            .foregroundColor(AppColors.label)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .cardBackground()
            }
        }
    }
}

// MARK: - Training Trend Section

struct HomeTrendSection: View {
    let data: [DayTrendPoint]
    let isWeek: Bool
    let periodStart: Date

    private var cal: Calendar { Calendar.current }

    private var maxCount: Int {
        let m = data.map { $0.sessionCount }.max() ?? 0
        return max(m, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(icon: "chart.xyaxis.line", title: "TRAINING TREND")

            if data.isEmpty {
                Text("No data yet.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondaryLabel)
            } else {
                HomeTrendGraph(data: data, maxCount: maxCount, isWeek: isWeek, periodStart: periodStart)
                    .frame(height: 120)
            }
        }
    }
}

struct HomeTrendGraph: View {
    let data: [DayTrendPoint]
    let maxCount: Int
    let isWeek: Bool
    let periodStart: Date

    private var cal: Calendar { Calendar.current }

    var body: some View {
        GeometryReader { geo in
            let graphTop: CGFloat = 20
            let graphBottom: CGFloat = 20
            let graphHeight = geo.size.height - graphTop - graphBottom
            let count = max(data.count, 1)
            let stepX = geo.size.width / CGFloat(count)
            let barWidth = max(stepX * 0.4, 4)

            ZStack(alignment: .topLeading) {
                // Horizontal grid lines
                ForEach(0..<4, id: \.self) { i in
                    let y = graphTop + graphHeight * CGFloat(i) / 3
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color(.systemGray5), lineWidth: 0.5)
                }

                // Y-axis labels
                ForEach(0..<4, id: \.self) { i in
                    let value = maxCount - (maxCount * i / 3)
                    let y = graphTop + graphHeight * CGFloat(i) / 3
                    Text("\(value)")
                        .font(.system(size: 7, design: .rounded))
                        .foregroundColor(Color(.systemGray3))
                        .position(x: 10, y: y)
                }

                // Bars
                ForEach(Array(data.enumerated()), id: \.offset) { i, point in
                    let x = stepX * CGFloat(i) + stepX / 2
                    let yRatio = CGFloat(point.sessionCount) / CGFloat(maxCount)
                    let barH = graphHeight * yRatio
                    let y = graphTop + graphHeight - barH

                    if point.sessionCount > 0 {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.darkGray))
                            .frame(width: barWidth, height: barH)
                            .position(x: x, y: y + barH / 2)
                    }

                    // Mood emoji above bar
                    if let mood = point.mood {
                        Text(mood.glyph)
                            .font(.system(size: 12, design: .rounded))
                            .position(x: x, y: y - 10)
                    }
                }

                // Trend line connecting bars
                Path { path in
                    for (i, point) in data.enumerated() {
                        let x = stepX * CGFloat(i) + stepX / 2
                        let yRatio = CGFloat(point.sessionCount) / CGFloat(maxCount)
                        let y = graphTop + graphHeight * (1 - yRatio)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                // Day labels
                ForEach(Array(data.enumerated()), id: \.offset) { i, point in
                    let x = stepX * CGFloat(i) + stepX / 2
                    Text(dayLabel(index: i, date: point.date))
                        .font(.system(size: 8, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .position(x: x, y: geo.size.height - 6)
                }
            }
        }
    }

    private func dayLabel(index: Int, date: Date) -> String {
        if isWeek {
            let labels = ["M", "T", "W", "T", "F", "S", "S"]
            return index < labels.count ? labels[index] : ""
        } else {
            let day = cal.component(.day, from: date)
            return day % 5 == 1 || day == 1 ? "\(day)" : ""
        }
    }
}

// MARK: - Plan List

// MARK: - Reusable Session Card (matches Mat Mind Home / Plan design)

struct SessionCardView: View {
    @ObservedObject var store: NotebookStore
    let session: PlannedSession
    var onReflect: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var menuOpen = false

    var body: some View {
        let goal = store.goal(id: session.goalId)
        let color = goal?.goalColor ?? AppColors.indigo
        let tasks = session.taskIds.compactMap { store.task(id: $0) }
        let reflected = store.reflection(forSessionId: session.id) != nil

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    GoalIconImage(name: goal?.iconName ?? "target", color: color, size: 18)
                    Text(goal?.name ?? "No goal")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.label)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(color.opacity(0.14)))

                Spacer()

                Button(action: onReflect) {
                    HStack(spacing: 4) {
                        ReflectPencilIcon(size: 14, color: AppColors.indigo)
                        Text(reflected ? "Reflected" : "Reflect")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.indigo)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { menuOpen.toggle() } }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 28, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(tasks) { task in
                        sessionTaskRow(task, color, isLast: task.id == tasks.last?.id)
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 16)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground))
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.06), color.opacity(0.03)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(gradient: Gradient(colors: [color.opacity(0.22), color.opacity(0.06)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .overlay(
            HStack(spacing: 0) {
                Rectangle().fill(color).frame(width: 4)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        .overlay(menuOverlay, alignment: .topTrailing)
    }

    // MARK: Task row (matches "Next Session" screenshot design)

    @ViewBuilder
    private func sessionTaskRow(_ task: TrainingTask, _ color: Color, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(color)
                    .frame(width: 6, height: 6)
                    .padding(.top, 7)
                Text(task.name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            sessionTaskDetail(task, color)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func sessionTaskDetail(_ task: TrainingTask, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let notes = task.notes.nilIfBlank {
                Text(notes)
                    .font(.matMindBody(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !task.imageFileNames.isEmpty {
                VStack(spacing: 8) {
                    ForEach(task.imageFileNames, id: \.self) { fn in
                        if let data = store.taskImageData(taskId: task.id, fileName: fn), let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            if let link = task.link.nilIfBlank {
                HStack(spacing: 8) {
                    Image(systemName: "link").font(.system(size: 13)).foregroundColor(color)
                    Text(link).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(color).lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var menuOverlay: some View {
        if menuOpen {
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.001)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .fixedSize()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { menuOpen = false } }

                VStack(alignment: .leading, spacing: 0) {
                    menuRow(icon: "pencil", label: "Edit", color: AppColors.label) {
                        menuOpen = false
                        onEdit()
                    }
                    Divider().padding(.horizontal, 10)
                    menuRow(icon: "trash", label: "Delete", color: AppColors.coral) {
                        menuOpen = false
                        onDelete()
                    }
                }
                .background(AppColors.background)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.14), radius: 8, x: 0, y: 2)
                .frame(width: 150)
                .padding(.top, 44)
                .padding(.trailing, 8)
            }
        }
    }

    private func menuRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.matMindBody(size: 14)).foregroundColor(color)
                Text(label).font(.matMindBody(size: 15)).foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Plan (month calendar)

struct PlanListView: View {
    @ObservedObject var store: NotebookStore
    var onAdd: () -> Void
    var onReflect: (String) -> Void

    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var editingSession: PlannedSession?
    @State private var showDeleteConfirm = false
    @State private var sessionToDelete: PlannedSession?
    @State private var feedbackReflection: Reflection?

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Plan")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    calendarCard
                    selectedDaySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .sheet(item: $editingSession) { session in
            EditSessionView(store: store, session: session) {
                editingSession = nil
            }
        }
        .sheet(item: $feedbackReflection) { reflection in
            FeedbackPreviewView(store: store, reflection: reflection, onClose: { feedbackReflection = nil })
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("Delete Session"),
                message: Text("This will permanently delete this planned session and any associated reflection."),
                primaryButton: .destructive(Text("Delete")) {
                    if let s = sessionToDelete {
                        store.deleteSession(id: s.id)
                        sessionToDelete = nil
                    }
                },
                secondaryButton: .cancel { sessionToDelete = nil }
            )
        }
    }

    // MARK: Calendar card

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { shiftMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                Spacer()
                HStack(spacing: 8) {
                    Text(monthTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Text("\(monthEntryCount) \(monthEntryCount == 1 ? "Entry" : "Entries")")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.indigo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppColors.indigo.opacity(0.12)))
                }
                Spacer()
                Button(action: { shiftMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity)
                }
            }

            let days = gridDays
            let rows = (days.count + 6) / 7
            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < days.count, let date = days[idx] {
                                dayCell(date)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 48)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let isToday = cal.isDateInToday(date)
        let glyph = moodGlyph(on: date)
        let planned = glyph == nil && hasPlan(on: date)
        return Button(action: { selectedDate = date }) {
            VStack(spacing: 1) {
                ZStack {
                    if isSelected {
                        Circle().fill(AppColors.indigo).frame(width: 34, height: 34)
                    } else if isToday {
                        Circle().stroke(AppColors.indigo, lineWidth: 1.5).frame(width: 34, height: 34)
                    }
                    Text("\(cal.component(.day, from: date))")
                        .font(.matMindBody(size: 16))
                        .foregroundColor(isSelected ? .white : AppColors.label)
                }
                .frame(height: 34)
                ZStack {
                    if let glyph = glyph {
                        Text(glyph).font(.system(size: 12))
                    } else if planned {
                        Circle().fill(AppColors.coral).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 14)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Selected day

    private var selectedDaySection: some View {
        let daySessions = sessions(on: selectedDate)
        return VStack(alignment: .leading, spacing: 12) {
            Text(longDateLabel)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.label)
            if daySessions.isEmpty {
                VStack(spacing: 14) {
                    Text("Nothing planned.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(AppColors.indigo))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.cardBackground))
            } else {
                ForEach(daySessions) { session in
                    if let reflection = store.reflection(forSessionId: session.id) {
                        ReflectionCardView(
                            store: store,
                            reflection: reflection,
                            onReflect: { onReflect(session.id) },
                            onDelete: { store.deleteReflection(id: reflection.id) },
                            onShareFeedback: { feedbackReflection = reflection }
                        )
                    } else {
                        SessionCardView(
                            store: store,
                            session: session,
                            onReflect: { onReflect(session.id) },
                            onEdit: { editingSession = session },
                            onDelete: { sessionToDelete = session; showDeleteConfirm = true }
                        )
                        .zIndex(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Helpers

    private var weekdaySymbols: [String] { ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] }

    private var monthFirst: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: monthFirst)
    }

    private var longDateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d, yyyy"
        return fmt.string(from: selectedDate)
    }

    private var gridDays: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: monthFirst) else { return [] }
        let weekdayOfFirst = cal.component(.weekday, from: monthFirst) // 1 = Sunday
        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst - 1)
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: monthFirst))
        }
        return days
    }

    private var monthEntryCount: Int {
        store.notebook.sessions.filter { cal.isDate($0.date, equalTo: monthFirst, toGranularity: .month) }.count
    }

    private func sessions(on date: Date) -> [PlannedSession] {
        store.notebook.sessions
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private func moodGlyph(on date: Date) -> String? {
        store.notebook.reflections
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first?.mood?.glyph
    }

    private func hasPlan(on date: Date) -> Bool {
        store.notebook.sessions.contains { cal.isDate($0.date, inSameDayAs: date) }
    }

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: monthFirst) {
            displayedMonth = d
        }
    }
}

// MARK: - Edit Session

struct EditSessionView: View {
    @ObservedObject var store: NotebookStore
    let session: PlannedSession
    var onDismiss: () -> Void

    @State private var selectedGoalIds: Set<String>
    @State private var selectedTaskIds: Set<String>
    @State private var selectedDate: Date
    @State private var showDatePicker = false

    init(store: NotebookStore, session: PlannedSession, onDismiss: @escaping () -> Void) {
        self.store = store
        self.session = session
        self.onDismiss = onDismiss
        // Pre-select goals that own any of the session's tasks
        let taskGoalIds = Set(session.taskIds.compactMap { tid in
            store.notebook.tasks.first(where: { $0.id == tid })?.goalId
        })
        let initialGoalIds = taskGoalIds.union([session.goalId])
        _selectedGoalIds = State(initialValue: initialGoalIds)
        _selectedTaskIds = State(initialValue: Set(session.taskIds))
        _selectedDate = State(initialValue: session.date)
    }

    private var selectedGoalsSorted: [TrainingGoal] {
        store.activeGoals.filter { selectedGoalIds.contains($0.id) }
    }

    private var cal: Calendar { Calendar.current }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date (editable)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATE")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showDatePicker.toggle() } }) {
                            HStack {
                                let fmt = DateFormatter()
                                let _ = fmt.dateFormat = "EEE, MMM d"
                                Text(fmt.string(from: selectedDate))
                                    .font(.body)
                                    .foregroundColor(AppColors.label)
                                Spacer()
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.indigo)
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if showDatePicker {
                            editSessionCalendar
                                .transition(.opacity)
                        }
                    }

                    // Goal picker (multi-select)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GOAL")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        ForEach(store.activeGoals) { goal in
                            Button(action: {
                                if selectedGoalIds.contains(goal.id) {
                                    if selectedGoalIds.count > 1 {
                                        selectedGoalIds.remove(goal.id)
                                        // Remove tasks belonging to this goal
                                        let goalTaskIds = Set(store.tasks(forGoal: goal.id).map(\.id))
                                        selectedTaskIds.subtract(goalTaskIds)
                                    }
                                } else {
                                    selectedGoalIds.insert(goal.id)
                                }
                            }) {
                                HStack {
                                    Text(goal.name)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.label)
                                    Spacer()
                                    if selectedGoalIds.contains(goal.id) {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(AppColors.label)
                                    }
                                }
                                .padding(12)
                                .background(selectedGoalIds.contains(goal.id) ? Color(.systemGray5) : Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // Task picker (grouped by goal)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TASKS")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)

                        ForEach(selectedGoalsSorted) { goal in
                            let tasks = store.tasks(forGoal: goal.id)
                            if !tasks.isEmpty {
                                Text(goal.name)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(goal.goalColor)
                                    .padding(.top, 4)

                                ForEach(tasks) { task in
                                    Button(action: {
                                        if selectedTaskIds.contains(task.id) {
                                            selectedTaskIds.remove(task.id)
                                        } else {
                                            selectedTaskIds.insert(task.id)
                                        }
                                    }) {
                                        HStack {
                                            Text(task.name)
                                                .font(.subheadline)
                                                .foregroundColor(AppColors.label)
                                            Spacer()
                                            if selectedTaskIds.contains(task.id) {
                                                Image(systemName: "checkmark")
                                                    .font(.caption)
                                                    .foregroundColor(AppColors.label)
                                            }
                                        }
                                        .padding(12)
                                        .background(selectedTaskIds.contains(task.id) ? goal.goalColor.opacity(0.12) : Color(.systemGray6))
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }

                        if selectedGoalsSorted.allSatisfy({ store.tasks(forGoal: $0.id).isEmpty }) {
                            Text("No tasks for selected goals.")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.groupedBackground)
            .navigationBarTitle("Edit Session", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { onDismiss() },
                trailing: Button(action: {
                    let primaryGoalId = selectedGoalIds.first ?? session.goalId
                    store.updateSession(id: session.id, goalId: primaryGoalId, taskIds: Array(selectedTaskIds), date: selectedDate)
                    onDismiss()
                }) {
                    Text("Save").font(.system(size: 17, weight: .medium, design: .rounded))
                }
            )
        }
    }

    // MARK: - Inline Calendar

    @ViewBuilder
    private var editSessionCalendar: some View {
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: selectedDate)) ?? selectedDate
        let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let offset = (firstWeekday + 5) % 7 // Monday-start offset

        VStack(spacing: 12) {
            // Month nav
            HStack {
                Button(action: { shiftMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                }
                Spacer()
                Text(monthYearLabel(monthStart))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { shiftMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                }
            }

            // Day-of-week headers
            let days = ["M", "T", "W", "T", "F", "S", "S"]
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(days[i])
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.tertiaryLabel)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let totalCells = offset + daysInMonth
            let rows = (totalCells + 6) / 7
            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let cellIndex = row * 7 + col
                            let dayNum = cellIndex - offset + 1
                            if dayNum >= 1 && dayNum <= daysInMonth {
                                let cellDate = cal.date(byAdding: .day, value: dayNum - 1, to: monthStart) ?? monthStart
                                let isSelected = cal.isDate(cellDate, inSameDayAs: selectedDate)
                                Button(action: { selectedDate = cellDate }) {
                                    Text("\(dayNum)")
                                        .font(.system(size: 15, weight: isSelected ? .bold : .regular, design: .rounded))
                                        .foregroundColor(isSelected ? .white : AppColors.label)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle().fill(isSelected ? AppColors.indigo : Color.clear)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(maxWidth: .infinity)
                            } else {
                                Color.clear.frame(width: 36, height: 36).frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray4), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func shiftMonth(_ direction: Int) {
        if let newDate = cal.date(byAdding: .month, value: direction, to: selectedDate) {
            selectedDate = cal.date(from: cal.dateComponents([.year, .month], from: newDate))
                .flatMap { cal.date(byAdding: .day, value: 0, to: $0) } ?? newDate
        }
    }

    private func monthYearLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date)
    }
}

// MARK: - Edit Goal

private enum EditGoalAlert: Identifiable {
    case deleteTask(String)
    case deleteGoal
    var id: String {
        switch self {
        case .deleteTask(let id): return "task-\(id)"
        case .deleteGoal: return "goal"
        }
    }
}

struct EditGoalView: View {
    @ObservedObject var store: NotebookStore
    let goalId: String
    var onDismiss: () -> Void
    let isNewGoal: Bool

    @State private var goalName: String
    @State private var iconName: String
    @State private var colorName: String
    @State private var addingTask = false
    @State private var newTaskName = ""
    @State private var expandedTaskIds: Set<String>
    @State private var activeAlert: EditGoalAlert?

    private var goalColor: Color { GoalIconLibrary.color(for: colorName) }

    init(store: NotebookStore, goalId: String, isNewGoal: Bool = false, onDismiss: @escaping () -> Void) {
        self.store = store
        self.goalId = goalId
        self.isNewGoal = isNewGoal
        self.onDismiss = onDismiss
        let goal = store.goal(id: goalId)
        _goalName = State(initialValue: goal?.name ?? "")
        _iconName = State(initialValue: goal?.iconName ?? "target")
        _colorName = State(initialValue: goal?.colorName ?? "indigo")
        // Auto-expand any task that has details OR is missing a description, so the user can
        // immediately see what needs to be filled in (descriptions are required to save).
        let tasks = store.tasks(forGoal: goalId)
        let needsAttention = tasks
            .filter { $0.hasDetails || $0.notes.nilIfBlank == nil }
            .map { $0.id }
        _expandedTaskIds = State(initialValue: Set(needsAttention))
    }

    var body: some View {
        let tasks = store.tasks(forGoal: goalId)
        let missingDescription = tasks.contains(where: { $0.notes.nilIfBlank == nil })
        let saveDisabled = goalName.nilIfBlank == nil || missingDescription

        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { onDismiss() }
                    .font(.system(size: 17, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: saveAndDismiss) {
                    Text("Save")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(saveDisabled ? AppColors.indigo.opacity(0.4) : AppColors.indigo))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(saveDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if missingDescription {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                    Text("Add a description to each task before saving.")
                        .font(.system(size: 13, design: .rounded))
                }
                .foregroundColor(AppColors.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    previewHeader
                    appearanceSection
                    tasksSection
                    if !isNewGoal { deleteGoalButton }
                }
                .padding(16)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .alert(item: $activeAlert, content: alert(for:))
    }

    private var previewHeader: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18)
                .fill(goalColor.opacity(0.14))
                .frame(width: 76, height: 76)
                .overlay(GoalIconImage(name: iconName, color: goalColor, size: 36))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    TextField("Goal name", text: $goalName)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Image(systemName: "pencil").font(.system(size: 15)).foregroundColor(AppColors.secondaryLabel)
                }
                let n = store.tasks(forGoal: goalId).count
                Text("\(n) \(n == 1 ? "task" : "tasks")")
                    .font(.matMindBody(size: 16))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("APPEARANCE")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .kerning(0.5)
                .foregroundColor(AppColors.tertiaryLabel)
            GoalIconColorPicker(iconName: $iconName, colorName: $colorName)
            Divider().padding(.top, 6)
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("TASKS")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .kerning(0.5)
                    .foregroundColor(AppColors.tertiaryLabel)
                Spacer()
                Button(action: { addingTask = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                        Text("Add").font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(AppColors.indigo)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 4)

            let tasks = store.tasks(forGoal: goalId)
            if tasks.isEmpty && !addingTask {
                Text("No tasks yet.")
                    .font(.matMindBody(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
                    .padding(.top, 6)
            }
            ForEach(tasks) { task in
                TaskEditRow(
                    store: store,
                    task: task,
                    accentColor: goalColor,
                    expanded: Binding(
                        get: { expandedTaskIds.contains(task.id) },
                        set: { isOn in
                            if isOn { _ = expandedTaskIds.insert(task.id) }
                            else { _ = expandedTaskIds.remove(task.id) }
                        }
                    ),
                    onDelete: { activeAlert = .deleteTask(task.id) }
                )
                Divider()
            }
            if addingTask { addTaskField }
        }
    }

    private var addTaskField: some View {
        HStack(spacing: 8) {
            TextField("Task name", text: $newTaskName, onCommit: commitNewTask)
                .font(.matMindBody(size: 16))
                .textFieldStyle(TrainingTextFieldStyle())
            Button(action: commitNewTask) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(goalColor)
            }
            .disabled(newTaskName.nilIfBlank == nil)
            Button(action: { addingTask = false; newTaskName = "" }) {
                Image(systemName: "xmark.circle").foregroundColor(AppColors.secondaryLabel)
            }
        }
        .padding(.vertical, 8)
    }

    private var deleteGoalButton: some View {
        Button(action: { activeAlert = .deleteGoal }) {
            Text("Delete goal")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.coral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.coral.opacity(0.1)))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 8)
    }

    private func alert(for alert: EditGoalAlert) -> Alert {
        switch alert {
        case .deleteTask(let taskId):
            return Alert(
                title: Text("Delete Task"),
                message: Text("Are you sure you want to delete this task?"),
                primaryButton: .destructive(Text("Delete")) {
                    store.deleteTaskCascade(taskId: taskId)
                },
                secondaryButton: .cancel()
            )
        case .deleteGoal:
            let summary = store.goalCascadeSummary(goalId: goalId)
            return Alert(
                title: Text("Delete \"\(goalName)\"?"),
                message: Text("\(summary.taskCount) tasks, \(summary.sessionCount) sessions, and \(summary.reflectionCount) reflections will be deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    store.deleteGoalCascade(goalId: goalId)
                    onDismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func saveAndDismiss() {
        if goalName.nilIfBlank != nil {
            store.updateGoal(id: goalId, name: goalName, iconName: iconName, colorName: colorName)
        }
        onDismiss()
    }

    private func commitNewTask() {
        if let task = store.addTask(goalId: goalId, name: newTaskName) {
            newTaskName = ""
            addingTask = false
            _ = expandedTaskIds.insert(task.id)
        }
    }
}

struct TaskEditRow: View {
    @ObservedObject var store: NotebookStore
    let task: TrainingTask
    let accentColor: Color
    @Binding var expanded: Bool
    var onDelete: () -> Void

    @State private var name: String
    @State private var notes: String
    @State private var link: String
    @State private var showLinkField = false

    init(store: NotebookStore, task: TrainingTask, accentColor: Color, expanded: Binding<Bool>, onDelete: @escaping () -> Void) {
        self.store = store
        self.task = task
        self.accentColor = accentColor
        self._expanded = expanded
        self.onDelete = onDelete
        _name = State(initialValue: task.name)
        _notes = State(initialValue: task.notes)
        _link = State(initialValue: task.link)
    }

    private var imageFileNames: [String] {
        store.task(id: task.id)?.imageFileNames ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(accentColor)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .buttonStyle(PlainButtonStyle())

                if expanded {
                    TextField("Task name", text: nameBinding)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                } else {
                    Text(name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { expanded = true } }
                    Spacer()
                }
            }

            if expanded {
                TrainingTextView(text: notesBinding, placeholder: "Add a description (required)…")
                    .frame(height: 76)

                if !imageFileNames.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(imageFileNames, id: \.self) { fileName in
                            taskThumbnail(fileName)
                        }
                    }
                }

                if showLinkField || link.nilIfBlank != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "link").font(.system(size: 13)).foregroundColor(AppColors.secondaryLabel)
                        TextField("Paste link...", text: linkBinding).font(.matMindBody(size: 14))
                    }
                    .padding(11)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray3), lineWidth: 1))
                }

                HStack(spacing: 10) {
                    chipButton(icon: "link", label: "Add link") { showLinkField = true }
                    chipButton(icon: "photo", label: "Photo") {
                        UIKitImagePicker.present { data in
                            store.addTaskImage(taskId: task.id, imageData: data)
                        }
                    }
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 16)).foregroundColor(AppColors.coral)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func chipButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundColor(AppColors.secondaryLabel)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(.systemGray6)))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func taskThumbnail(_ fileName: String) -> some View {
        ZStack(alignment: .topTrailing) {
            if let data = store.taskImageData(taskId: task.id, fileName: fileName), let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)).frame(maxWidth: .infinity).frame(height: 160)
            }
            Button(action: { store.removeTaskImage(taskId: task.id, fileName: fileName) }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.45)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(8)
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { name }, set: { name = $0; store.updateTask(id: task.id, name: $0) })
    }
    private var notesBinding: Binding<String> {
        Binding(get: { notes }, set: { notes = $0; store.updateTask(id: task.id, notes: $0) })
    }
    private var linkBinding: Binding<String> {
        Binding(get: { link }, set: { link = $0; store.updateTask(id: task.id, link: $0) })
    }
}

struct BottomTabsView: View {
    var active: MainTab
    var onHome: () -> Void
    var onGoals: () -> Void
    var onPlan: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            pillItem(title: "Home", icon: active == .home ? "house.fill" : "house", isActive: active == .home, action: onHome)
            pillItem(title: "Goals", icon: "target", isActive: active == .goals, action: onGoals)
            pillItem(title: "Plan", icon: active == .plan ? "calendar.circle.fill" : "calendar", isActive: active == .plan, action: onPlan)
        }
        .padding(6)
        .background(
            Capsule()
                .fill(AppColors.cardBackground)
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
        .padding(.bottom, 8)
    }

    private func pillItem(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 13, weight: isActive ? .bold : .medium, design: .rounded))
            }
            .foregroundColor(isActive ? AppColors.indigo : AppColors.secondaryLabel)
            .frame(width: 86, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isActive ? AppColors.indigo.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BottomTabButton: View {
    var title: String
    var systemName: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                Text(title)
                    .font(.caption)
                    .uppercaseTracking()
            }
            .foregroundColor(active ? AppColors.indigo : .secondary)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Notes

struct NotesListView: View {
    @ObservedObject var store: NotebookStore
    @State private var selectedNote: Note?
    @State private var isCreatingNote = false
    @State private var isEditingNote = false
    @State private var actionSheetNoteId: String?
    @State private var confirmDeleteNoteId: String?

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("NOTES")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(AppColors.secondaryLabel)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if store.sortedNotes.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.system(size: 40, design: .rounded))
                            .foregroundColor(Color(.systemGray3))
                        Text("No notes yet")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                        Text("Tap + to start writing.")
                            .font(.matMindBody(size: 15))
                            .foregroundColor(Color(.systemGray2))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(store.sortedNotes) { note in
                                ZStack(alignment: .topTrailing) {
                                    NoteRowView(note: note)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedNote = note
                                            isEditingNote = true
                                        }

                                    // 3-dots menu button
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            actionSheetNoteId = actionSheetNoteId == note.id ? nil : note.id
                                        }
                                    }) {
                                        Image(systemName: "ellipsis")
                                            .foregroundColor(AppColors.label)
                                            .frame(width: 32, height: 32)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.trailing, 8)
                                    .padding(.top, 8)

                                    // Dropdown menu overlay
                                    if actionSheetNoteId == note.id {
                                        VStack(alignment: .leading, spacing: 0) {
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    actionSheetNoteId = nil
                                                }
                                                confirmDeleteNoteId = note.id
                                            }) {
                                                HStack(spacing: 10) {
                                                    Image(systemName: "trash")
                                                        .font(.matMindBody(size: 14))
                                                        .foregroundColor(AppColors.coral)
                                                    Text("Delete")
                                                        .font(.matMindBody(size: 15))
                                                        .foregroundColor(AppColors.coral)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 12)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                        .background(AppColors.background)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                                        .frame(width: 160)
                                        .offset(x: -8, y: 36)
                                        .transition(.opacity)
                                        .zIndex(10)
                                    }
                                }
                                .zIndex(actionSheetNoteId == note.id ? 10 : 0)
                            }
                        }
                        .background(AppColors.background)
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }
                }
            }

            // Floating compose button (centered bottom, like Apple Notes)
            VStack {
                Spacer()
                Button(action: {
                    selectedNote = nil
                    isCreatingNote = true
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(AppColors.indigo)
                        .clipShape(Circle())
                        .shadow(color: AppColors.indigo.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $isEditingNote) {
            NoteEditorView(store: store, noteId: selectedNote?.id, onDone: {
                isEditingNote = false
            })
        }
        .sheet(isPresented: $isCreatingNote) {
            NoteEditorView(store: store, noteId: nil, onDone: {
                isCreatingNote = false
            })
        }
        .alert(isPresented: Binding(
            get: { confirmDeleteNoteId != nil },
            set: { if !$0 { confirmDeleteNoteId = nil } }
        )) {
            Alert(
                title: Text("Delete Note"),
                message: Text("This note will be permanently deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    if let id = confirmDeleteNoteId {
                        store.deleteNote(id: id)
                    }
                    confirmDeleteNoteId = nil
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct NoteRowView: View {
    var note: Note

    private var previewSnippet: String {
        let plain = note.body.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[image: [^\\]]+\\]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if plain.isEmpty { return "No additional text" }
        return String(plain.prefix(80))
    }

    private var displayTitle: String {
        let t = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "New Note" : t
    }

    private var dateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(note.updatedAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: note.updatedAt)
        } else if cal.isDateInYesterday(note.updatedAt) {
            return "Yesterday"
        } else {
            return DateFormatter.monthDay.string(from: note.updatedAt)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(dateLabel)
                        .font(.matMindBody(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                    Text(previewSnippet)
                        .font(.matMindBody(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.leading, 16)
        }
    }
}

// MARK: - Note Editor (Apple Notes style)

struct NoteEditorView: View {
    @ObservedObject var store: NotebookStore
    var noteId: String?
    var onDone: () -> Void

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var showDeleteConfirm = false
    @State private var noteWasDeleted = false
    @State private var showImagePicker = false
    @State private var focusBody = false
    @State private var saveTimer: Timer?
    @State private var isKeyboardVisible = false

    private var isNewNote: Bool { noteId == nil }
    @State private var createdNoteId: String?

    private var effectiveNoteId: String? { noteId ?? createdNoteId }

    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar — mirrors Apple Notes
            noteEditorTopBar

            Divider()

            // Scrollable content area
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title field
                    NotesTitleField(title: $title, onChanged: scheduleSave, onReturn: {
                        focusBody = true
                    })
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    // Date stamp (like Apple Notes shows date under title)
                    if let noteId = effectiveNoteId,
                       let note = store.notebook.notes.first(where: { $0.id == noteId }) {
                        Text(noteDateStamp(note.updatedAt))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Color(.systemGray2))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    // Body editor
                    // Attached images (above body so they appear near cursor context)
                    if let noteId = effectiveNoteId,
                       let note = store.notebook.notes.first(where: { $0.id == noteId }),
                       !note.imageFileNames.isEmpty,
                       let persistence = store.persistence as? JSONNotebookPersistence {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(note.imageFileNames, id: \.self) { fileName in
                                if let data = persistence.loadNoteImage(
                                    accountId: store.notebook.accountId,
                                    noteId: noteId,
                                    fileName: fileName
                                ), let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    NoteBodyEditor(text: $bodyText, onImageRequest: {
                        showImagePicker = true
                    }, onTextChanged: scheduleSave, shouldFocus: $focusBody)
                    .frame(minHeight: 200)
                    .padding(.horizontal, 16)
                }
            }

        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            if let noteId = noteId, let note = store.notebook.notes.first(where: { $0.id == noteId }) {
                title = note.title
                bodyText = note.body
            }
        }
        .onDisappear {
            saveTimer?.invalidate()
            saveNote()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("Delete Note"),
                message: Text("This note will be permanently deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    noteWasDeleted = true
                    if let id = effectiveNoteId {
                        store.deleteNote(id: id)
                    }
                    onDone()
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showImagePicker) {
            NoteImagePicker(onImageSelected: { imageData in
                if let id = effectiveNoteId ?? createNoteIfNeeded(),
                   let persistence = store.persistence as? JSONNotebookPersistence {
                    let fileName = "\(UUID().uuidString).jpg"
                    _ = try? persistence.saveNoteImage(
                        accountId: store.notebook.accountId,
                        noteId: id,
                        imageData: imageData,
                        fileName: fileName
                    )
                    var fileNames = store.notebook.notes.first(where: { $0.id == id })?.imageFileNames ?? []
                    fileNames.append(fileName)
                    store.updateNote(id: id, title: title, body: bodyText, imageFileNames: fileNames)
                    scheduleSave()
                }
            })
        }
    }

    // MARK: Top bar — < back, undo, share, ⋯, yellow done checkmark
    private var noteEditorTopBar: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: {
                saveNote()
                onDone()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.indigo)
            }

            Spacer()

            // Done checkmark (yellow, like Apple Notes)
            if isKeyboardVisible {
                Button(action: {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    saveNote()
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.0))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func noteDateStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    private func createNoteIfNeeded() -> String? {
        if let existing = effectiveNoteId { return existing }
        let note = store.addNote(title: title, body: bodyText)
        createdNoteId = note.id
        return note.id
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            DispatchQueue.main.async {
                saveNote()
            }
        }
    }

    private func saveNote() {
        guard !noteWasDeleted else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedBody.isEmpty else { return }

        if let id = effectiveNoteId {
            store.updateNote(id: id, title: title, body: bodyText, imageFileNames: nil)
        } else {
            let note = store.addNote(title: title, body: bodyText)
            createdNoteId = note.id
        }
    }
}

// MARK: - Notes Title Field (iOS 13 compatible)

struct NotesTitleField: UIViewRepresentable {
    @Binding var title: String
    var onChanged: () -> Void
    var onReturn: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        field.textColor = UIColor.label
        field.placeholder = "Title"
        field.borderStyle = .none
        field.returnKeyType = .next
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != title { uiView.text = title }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NotesTitleField
        init(_ parent: NotesTitleField) { self.parent = parent }
        @objc func textChanged(_ sender: UITextField) {
            parent.title = sender.text ?? ""
            parent.onChanged()
        }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onReturn?()
            return false
        }
    }
}

// MARK: - Note Body Editor (UITextView Wrapper)

struct NoteBodyEditor: UIViewRepresentable {
    @Binding var text: String
    var onImageRequest: () -> Void
    var onTextChanged: (() -> Void)?
    @Binding var shouldFocus: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.textColor = UIColor.label
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

        // Formatting toolbar above keyboard (bold, italic, bullets, heading)
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.sizeToFit()

        let textStyle = UIBarButtonItem(image: UIImage(systemName: "textformat.alt"), style: .plain, target: nil, action: nil)
        let checklist = UIBarButtonItem(image: UIImage(systemName: "checklist"), style: .plain, target: context.coordinator, action: #selector(Coordinator.insertBullet))
        let attachment = UIBarButtonItem(image: UIImage(systemName: "paperclip"), style: .plain, target: context.coordinator, action: #selector(Coordinator.requestImage))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = 20
        toolbar.items = [flex, textStyle, spacer, checklist, spacer, attachment, flex]
        textView.inputAccessoryView = toolbar

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if shouldFocus {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                self.shouldFocus = false
            }
        }
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteBodyEditor
        weak var textView: UITextView?

        init(_ parent: NoteBodyEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            parent.text = textView.text
            parent.onTextChanged?()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            self.textView = textView
        }

        @objc func toggleBold() {
            insertMarkers(around: "**")
        }

        @objc func toggleItalic() {
            insertMarkers(around: "_")
        }

        @objc func toggleUnderline() {
            insertMarkers(around: "__")
        }

        @objc func toggleStrikethrough() {
            insertMarkers(around: "~~")
        }

        @objc func insertBullet() {
            let needsNewline = !parent.text.isEmpty && !parent.text.hasSuffix("\n")
            parent.text += (needsNewline ? "\n" : "") + "• "
        }

        @objc func toggleHeading() {
            let needsNewline = !parent.text.isEmpty && !parent.text.hasSuffix("\n")
            parent.text += (needsNewline ? "\n" : "") + "# "
        }

        @objc func increaseIndent() {
            parent.text += "    "
        }

        @objc func requestImage() {
            parent.onImageRequest()
        }

        private func insertMarkers(around marker: String) {
            guard let tv = textView, let selectedRange = tv.selectedTextRange else {
                parent.text += "\(marker)text\(marker)"
                return
            }
            let selectedText = tv.text(in: selectedRange) ?? ""
            if selectedText.isEmpty {
                parent.text += "\(marker)text\(marker)"
            } else {
                let replacement = "\(marker)\(selectedText)\(marker)"
                tv.replace(selectedRange, withText: replacement)
                parent.text = tv.text
            }
        }
    }
}

// MARK: - Note Image Picker

// MARK: - UIKit Image Picker (presented directly to avoid nested-sheet bug on iOS 13/14)

final class UIKitImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private static var active: UIKitImagePicker?
    private let onPick: (Data) -> Void

    private init(onPick: @escaping (Data) -> Void) {
        self.onPick = onPick
    }

    static func present(onPick: @escaping (Data) -> Void) {
        guard let root = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        let presenter = UIKitImagePicker(onPick: onPick)
        active = presenter
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = presenter
        top.present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.originalImage] as? UIImage,
           let data = image.jpegData(compressionQuality: 0.8) {
            onPick(data)
        }
        picker.dismiss(animated: true)
        UIKitImagePicker.active = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        UIKitImagePicker.active = nil
    }
}

struct NoteImagePicker: UIViewControllerRepresentable {
    var onImageSelected: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: NoteImagePicker

        init(_ parent: NoteImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                parent.onImageSelected(data)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Goals

// MARK: - Add Goal Sheet
struct AddGoalSheet: View {
    @ObservedObject var store: NotebookStore
    var onDone: () -> Void

    @State private var name = ""
    @State private var goalIconName = "target"
    @State private var goalColorName = "indigo"
    @State private var taskNames: [String] = []
    @State private var newTaskName = ""
    @State private var showTaskWarning = false

    @State private var taskFieldId = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                }
                Spacer()
                Button(action: {
                    if taskNames.isEmpty {
                        showTaskWarning = true
                        return
                    }
                    if let goal = store.addGoal(name: name, iconName: goalIconName, colorName: goalColorName) {
                        for taskName in taskNames {
                            store.addTask(goalId: goal.id, name: taskName)
                        }
                        name = ""
                        goalIconName = "target"
                        goalColorName = "indigo"
                        taskNames = []
                        onDone()
                    }
                }) {
                    Text("Create")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(name.nilIfBlank == nil ? Color.gray : AppColors.indigo)
                }
                .disabled(name.nilIfBlank == nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 0) {
                    // Icon preview
                    VStack(spacing: 8) {
                        let color = GoalIconLibrary.color(for: goalColorName)
                        GoalIconImage(name: goalIconName, color: color, size: 56)
                    }
                    .padding(.bottom, 12)

                    // Goal name input
                    VStack(spacing: 4) {
                        TextField("Goal name (e.g. Leg Locks)", text: $name)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("Tap to rename")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // Icon & color picker
                    GoalIconColorPicker(iconName: $goalIconName, colorName: $goalColorName)
                        .padding(.horizontal, 20)

                    // Tasks section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tasks")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.label)

                        ForEach(Array(taskNames.enumerated()), id: \.offset) { index, taskName in
                            HStack {
                                Text(taskName)
                                    .font(.subheadline)
                                Spacer()
                                Button(action: { taskNames.remove(at: index) }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppColors.secondaryLabel)
                                }
                            }
                            .padding(10)
                            .background(AppColors.background)
                            .cardBackground()
                        }

                        HStack(spacing: 8) {
                            AutoFocusTextField(text: $newTaskName, placeholder: "Add a task", id: taskFieldId)
                                .font(.subheadline)
                            Button(action: {
                                if let trimmed = newTaskName.nilIfBlank, trimmed.count <= 15 {
                                    taskNames.append(trimmed)
                                    newTaskName = ""
                                    showTaskWarning = false
                                    taskFieldId = UUID()
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24, weight: .regular, design: .rounded))
                                    .foregroundColor(newTaskName.nilIfBlank == nil || newTaskName.count > 19 ? Color.gray : AppColors.indigo)
                            }
                            .disabled(newTaskName.nilIfBlank == nil || newTaskName.count > 19)
                        }

                        if newTaskName.count > 19 {
                            Text("Keep it under 20 letters")
                                .font(.caption)
                                .foregroundColor(AppColors.coral)
                        }

                        if showTaskWarning && taskNames.isEmpty {
                            Text("You must create at least one task")
                                .font(.caption)
                                .foregroundColor(AppColors.coral)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }
}

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @ObservedObject var store: NotebookStore
    let goalId: String
    var onDone: () -> Void

    @State private var taskName = ""

    private var goal: TrainingGoal? {
        store.notebook.goals.first(where: { $0.id == goalId })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                }
                Spacer()
                Button(action: {
                    if store.addTask(goalId: goalId, name: taskName) != nil {
                        taskName = ""
                        onDone()
                    }
                }) {
                    Text("Create")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(taskName.nilIfBlank == nil || taskName.count > 19 ? Color.gray : AppColors.indigo)
                }
                .disabled(taskName.nilIfBlank == nil || taskName.count > 19)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Goal icon + name
            VStack(spacing: 8) {
                if let goal = goal {
                    GoalIconImage(name: goal.iconName, color: goal.goalColor, size: 56)
                }
                Text(goal?.name ?? "Goal")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            .padding(.bottom, 20)

            // Task name input
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "checklist")
                        .font(.matMindBody(size: 16))
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    TextField("Enter task name", text: $taskName)
                        .font(.matMindBody(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColors.groupedBackground)
                .cornerRadius(12)
                if taskName.count > 19 {
                    Text("Keep it under 20 letters")
                        .font(.caption)
                        .foregroundColor(AppColors.coral)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }
}

private enum GoalSheet: Identifiable {
    case edit(String)
    case reflections(String)  // taskId
    var id: String {
        switch self {
        case .edit(let goalId): return "edit-\(goalId)"
        case .reflections(let taskId): return "refl-\(taskId)"
        }
    }
}

// MARK: - Task Reflections (per-task list of all linked reflections)

struct TaskReflectionsView: View {
    @ObservedObject var store: NotebookStore
    let taskId: String
    var onClose: () -> Void

    @State private var filter: PatternKind = .all
    @State private var favoritesOnly = false

    var body: some View {
        let task = store.task(id: taskId)
        let goal = task.flatMap { store.goal(id: $0.goalId) }
        let allReflections = store.reflections(forTaskId: taskId)
        let favCount = allReflections.filter { $0.isFavorite }.count
        let filtered = allReflections.filter { r in
            (!favoritesOnly || r.isFavorite) && matchesKind(r, filter)
        }

        VStack(spacing: 0) {
            header(task: task, goal: goal, total: allReflections.count)
            filterBar(allCount: allReflections.count, favCount: favCount)

            ScrollView {
                VStack(spacing: 12) {
                    if filtered.isEmpty {
                        EmptyDashedState(
                            title: "Nothing here yet.",
                            subtitle: allReflections.isEmpty
                                ? "Reflect after a session to capture what worked and where you got stuck."
                                : "Try a different filter."
                        )
                        .padding(.top, 32)
                    }
                    ForEach(filtered) { r in
                        ReflectionCardView(
                            store: store,
                            reflection: r,
                            onReflect: {},
                            onDelete: { store.deleteReflection(id: r.id) },
                            onShareFeedback: {},
                            filter: filter,
                            dateMode: true,
                            showShareButton: false,
                            showMenu: false
                        )
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
    }

    // MARK: Header

    private func header(task: TrainingTask?, goal: TrainingGoal?, total: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.label)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.cardBackground))
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(task?.name ?? "Task")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Text("\(goal?.name ?? "Goal") · \(total) \(total == 1 ? "reflection" : "reflections")")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: Filter bar

    private func filterBar(allCount: Int, favCount: Int) -> some View {
        HStack(spacing: 8) {
            filterChip(label: "All \(allCount)", isOn: filter == .all && !favoritesOnly) {
                filter = .all
                favoritesOnly = false
            }
            filterChip(label: "Wins", isOn: filter == .wins) {
                filter = (filter == .wins) ? .all : .wins
                favoritesOnly = false
            }
            filterChip(label: "Stuck", isOn: filter == .stuck) {
                filter = (filter == .stuck) ? .all : .stuck
                favoritesOnly = false
            }
            filterChip(label: "Up next", isOn: filter == .upNext) {
                filter = (filter == .upNext) ? .all : .upNext
                favoritesOnly = false
            }
            Spacer(minLength: 0)
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { favoritesOnly.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: favoritesOnly ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                    if favCount > 0 {
                        Text("\(favCount)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundColor(favoritesOnly ? AppColors.coral : AppColors.secondaryLabel)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(favoritesOnly ? AppColors.coral.opacity(0.14) : Color.clear))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func filterChip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { action() } }) {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isOn ? .white : AppColors.label)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(isOn ? AppColors.indigo : AppColors.cardBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func matchesKind(_ r: Reflection, _ kind: PatternKind) -> Bool {
        switch kind {
        case .all: return true
        case .wins: return r.workedText.nilIfBlank != nil
        case .stuck: return r.stuckText.nilIfBlank != nil
        case .upNext: return r.tryNextText.nilIfBlank != nil
        }
    }
}

struct GoalListView: View {
    @ObservedObject var store: NotebookStore

    @State private var sheet: GoalSheet?
    @State private var expandedGoalIds: Set<String> = []
    @State private var pendingNewGoalId: String?
    @State private var didInit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active goals")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                        Text("What are you working on right now?")
                            .font(.matMindBody(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    Spacer()
                    Button(action: {
                        let draft = store.createDraftGoal()
                        pendingNewGoalId = draft.id
                        sheet = .edit(draft.id)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.indigo)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.top, 12)

                if store.activeGoals.isEmpty {
                    EmptyDashedState(title: "No goals yet.", subtitle: "Add one to begin.")
                }

                ForEach(store.activeGoals) { goal in
                    GoalCard(
                        store: store,
                        goal: goal,
                        isExpanded: expandedGoalIds.contains(goal.id),
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                if expandedGoalIds.contains(goal.id) {
                                    expandedGoalIds.remove(goal.id)
                                } else {
                                    _ = expandedGoalIds.insert(goal.id)
                                }
                            }
                        },
                        onEdit: { sheet = .edit(goal.id) },
                        onShowReflections: { taskId in sheet = .reflections(taskId) }
                    )
                    .zIndex(expandedGoalIds.contains(goal.id) ? 1 : 0)
                }

                if store.activeGoals.count > 1 {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                        Text("tap a goal to expand its tasks").font(.matMindBody(size: 14))
                    }
                    .foregroundColor(AppColors.tertiaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .padding(.bottom, 110)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            if !didInit {
                didInit = true
                if let first = store.activeGoals.first { expandedGoalIds = [first.id] }
            }
        }
        .sheet(item: $sheet, onDismiss: discardDraftIfUnsaved) { which in
            switch which {
            case .edit(let goalId):
                EditGoalView(store: store, goalId: goalId, isNewGoal: goalId == pendingNewGoalId) { sheet = nil }
            case .reflections(let taskId):
                TaskReflectionsView(store: store, taskId: taskId, onClose: { sheet = nil })
            }
        }
    }

    /// When the add-goal flow closes, drop the draft goal if it was never named (i.e. discarded
    /// via Cancel or swipe-to-dismiss). Saving a goal sets a non-blank name, so it's kept.
    private func discardDraftIfUnsaved() {
        guard let id = pendingNewGoalId else { return }
        pendingNewGoalId = nil
        if let g = store.goal(id: id), g.name.nilIfBlank == nil {
            store.deleteGoalCascade(goalId: id)
        }
    }
}

struct GoalCard: View {
    @ObservedObject var store: NotebookStore
    let goal: TrainingGoal
    let isExpanded: Bool
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onShowReflections: (String) -> Void

    @State private var expandedTaskIds: Set<String> = []
    @State private var menuOpen = false
    @State private var confirmDelete = false

    private var cal: Calendar { Calendar.current }

    var body: some View {
        let tasks = store.tasks(forGoal: goal.id)
        let color = goal.goalColor
        let trained = tasks.filter { trainedThisWeek($0) }.count

        VStack(alignment: .leading, spacing: 0) {
            header(tasks: tasks, color: color, trained: trained)
            if isExpanded {
                expandedBody(tasks: tasks, color: color, trained: trained)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground))
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(gradient: Gradient(colors: [color.opacity(0.06), color.opacity(0.03)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(gradient: Gradient(colors: [color.opacity(0.22), color.opacity(0.06)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        .overlay(menuOverlay, alignment: .topTrailing)
        // Owned here (not on GoalListView) so it doesn't collide with that view's `.sheet`,
        // which previously stopped the goal-delete confirmation from ever presenting.
        .alert(isPresented: $confirmDelete) {
            let summary = store.goalCascadeSummary(goalId: goal.id)
            return Alert(
                title: Text("Delete \"\(goal.name)\"?"),
                message: Text(goalDeleteMessage(summary)),
                primaryButton: .destructive(Text("Delete")) { store.deleteGoalCascade(goalId: goal.id) },
                secondaryButton: .cancel()
            )
        }
    }

    private func goalDeleteMessage(_ s: GoalCascadeSummary) -> String {
        func plural(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }
        return "This will permanently delete the goal along with its \(plural(s.taskCount, "task")), "
            + "\(plural(s.sessionCount, "training session")), and \(plural(s.reflectionCount, "reflection")). "
            + "This can't be undone."
    }

    // MARK: Header

    @ViewBuilder
    private func header(tasks: [TrainingTask], color: Color, trained: Int) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 13)
                .fill(color.opacity(0.14))
                .frame(width: 46, height: 46)
                .overlay(GoalIconImage(name: goal.iconName, color: color, size: 23))

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                if isExpanded {
                    Text("\(tasks.count) \(tasks.count == 1 ? "task" : "tasks")")
                        .font(.matMindBody(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                } else {
                    HStack(spacing: 10) {
                        progressBar(trained, tasks.count, color).frame(width: 120)
                        Text("\(trained) of \(tasks.count) this week")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }
            }

            Spacer()

            if isExpanded {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { menuOpen.toggle() } }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
        }
        .padding(16)
        .padding(.leading, 4)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }

    // MARK: Expanded body

    @ViewBuilder
    private func expandedBody(tasks: [TrainingTask], color: Color, trained: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Trained this week")
                    .font(.matMindBody(size: 15))
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                Text("\(trained) / \(tasks.count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 16)
            .padding(.leading, 4)
            .padding(.top, 4)

            progressBar(trained, tasks.count, color)
                .padding(.horizontal, 16)
                .padding(.leading, 4)
                .padding(.top, 8)
                .padding(.bottom, 14)

            ForEach(tasks) { task in
                taskRow(task, color, isLast: task.id == tasks.last?.id)
            }
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func taskRow(_ task: TrainingTask, _ color: Color, isLast: Bool) -> some View {
        let trained = trainedThisWeek(task)
        let isOpen = expandedTaskIds.contains(task.id)
        let reflCount = store.reflections(forTaskId: task.id).count
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { toggleTask(task.id) } }) {
                HStack(spacing: 12) {
                    checkbox(trained, color)
                    Text(task.name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Spacer()
                    if reflCount > 0 {
                        reflectionBadge(reflCount)
                    }
                    if task.link.nilIfBlank != nil {
                        Image(systemName: "link").font(.system(size: 13)).foregroundColor(AppColors.tertiaryLabel)
                    }
                    if !task.imageFileNames.isEmpty {
                        Image(systemName: "photo").font(.system(size: 13)).foregroundColor(AppColors.tertiaryLabel)
                    }
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.tertiaryLabel)
                }
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isOpen {
                taskDetail(task, color)
            }
            if !isLast { Divider() }
        }
        .padding(.horizontal, 16)
        .padding(.leading, 14)
    }

    @ViewBuilder
    private func taskDetail(_ task: TrainingTask, _ color: Color) -> some View {
        let reflCount = store.reflections(forTaskId: task.id).count
        VStack(alignment: .leading, spacing: 12) {
            if let notes = task.notes.nilIfBlank {
                Text(notes)
                    .font(.matMindBody(size: 16))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No notes yet")
                    .font(.matMindBody(size: 15))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
            if !task.imageFileNames.isEmpty {
                VStack(spacing: 8) {
                    ForEach(task.imageFileNames, id: \.self) { fn in
                        if let data = store.taskImageData(taskId: task.id, fileName: fn), let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            if let link = task.link.nilIfBlank {
                HStack(spacing: 8) {
                    Image(systemName: "link").font(.system(size: 13)).foregroundColor(color)
                    Text(link).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(color).lineLimit(1)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.secondaryBackground))
            }
            if reflCount > 0 {
                viewAllReflectionsCTA(taskId: task.id, count: reflCount)
            }
        }
        .padding(.leading, 38)
        .padding(.bottom, 14)
    }

    private func reflectionBadge(_ count: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "text.bubble").font(.system(size: 10))
            Text("\(count)").font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundColor(AppColors.winGreen)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(AppColors.winGreen.opacity(0.15)))
    }

    private func viewAllReflectionsCTA(taskId: String, count: Int) -> some View {
        Button(action: { onShowReflections(taskId) }) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble").font(.system(size: 12))
                Text("View all reflections")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundColor(AppColors.indigo)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Pieces

    private func checkbox(_ done: Bool, _ color: Color) -> some View {
        ZStack {
            if done {
                Circle().fill(color).frame(width: 26, height: 26)
                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
            } else {
                Circle().stroke(Color(.systemGray3), lineWidth: 2).frame(width: 26, height: 26)
            }
        }
    }

    private func progressBar(_ value: Int, _ total: Int, _ color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5)).frame(height: 6)
                Capsule().fill(color)
                    .frame(width: total > 0 ? geo.size.width * CGFloat(value) / CGFloat(total) : 0, height: 6)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private var menuOverlay: some View {
        if menuOpen {
            ZStack(alignment: .topTrailing) {
                Color.black.opacity(0.001)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .fixedSize()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { menuOpen = false } }

                VStack(spacing: 0) {
                    menuRow(icon: "pencil", label: "Edit goal", color: AppColors.label) { menuOpen = false; onEdit() }
                    Divider().padding(.horizontal, 10)
                    menuRow(icon: "trash", label: "Delete goal", color: AppColors.coral) { menuOpen = false; confirmDelete = true }
                }
                .background(AppColors.background)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
                .frame(width: 170)
                .padding(.top, 54)
                .padding(.trailing, 12)
            }
        }
    }

    private func menuRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                Text(label).font(.matMindBody(size: 15)).foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Helpers

    private func trainedThisWeek(_ task: TrainingTask) -> Bool {
        store.taskWeekDoneDayCount(taskId: task.id, goalId: goal.id, anchor: Date()) > 0
    }

    private func toggleTask(_ id: String) {
        if expandedTaskIds.contains(id) { expandedTaskIds.remove(id) } else { _ = expandedTaskIds.insert(id) }
    }
}

struct GoalDetailView: View {
    @ObservedObject var store: NotebookStore
    var goalId: String
    var onBack: () -> Void

    @State private var adding = false
    @State private var name = ""
    @State private var confirmTaskId: String?

    var body: some View {
        let goal = store.goal(id: goalId)
        VStack(spacing: 0) {
            HeaderView(title: goal?.name ?? "Goal", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WeekStripView(dayStates: store.dayStateMap(goalId: goalId))
                    Text("Tasks").fieldLabel()

                    let tasks = store.tasks(forGoal: goalId)
                    if tasks.isEmpty && !adding {
                        EmptyDashedState(title: "No tasks yet.", subtitle: "Tasks help break a goal into specific drills.")
                    }

                    ForEach(tasks) { task in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.label)
                                Text("\(store.taskWeekDoneDayCount(taskId: task.id, goalId: goalId, anchor: Date())) days completed this week")
                                    .font(.caption)
                                    .foregroundColor(AppColors.label)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            if #available(iOS 14.0, *) {
                                Menu {
                                    Button(action: { confirmTaskId = task.id }) {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("Delete task")
                                        }
                                        .foregroundColor(AppColors.coral)
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(AppColors.label)
                                        .frame(width: 36, height: 44)
                                }
                                .padding(.trailing, 4)
                            } else {
                                Button(action: { confirmTaskId = task.id }) {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(AppColors.label)
                                        .frame(width: 36, height: 44)
                                }
                                .padding(.trailing, 4)
                            }
                        }
                        .cardBackground()
                    }

                    if adding {
                        DashedPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Task name (e.g. Finishing mechanics)", text: $name)
                                    .textFieldStyle(TrainingTextFieldStyle())
                                if name.count > 19 {
                                    Text("Keep it under 20 letters")
                                        .font(.caption)
                                        .foregroundColor(AppColors.coral)
                                }
                                HStack(spacing: 8) {
                                    Button("Add") {
                                        if store.addTask(goalId: goalId, name: name) != nil {
                                            name = ""
                                            adding = false
                                        }
                                    }
                                    .buttonStyle(SmallPrimaryButtonStyle())
                                    .disabled(name.nilIfBlank == nil || name.count > 19)
                                    Button("Cancel") {
                                        name = ""
                                        adding = false
                                    }
                                    .buttonStyle(SmallSecondaryButtonStyle())
                                    Spacer()
                                }
                            }
                        }
                    } else {
                        Button(action: { adding = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add task")
                                Spacer()
                            }
                            .foregroundColor(AppColors.indigo)
                            .padding(12)
                            .cardBackground(stronger: true)
                        }
                    }
                }
                .padding(16)
            }
        }
        .alert(item: Binding(
            get: { confirmTaskId.map(TaskDeleteAlertToken.init(id:)) },
            set: { confirmTaskId = $0?.id }
        )) { token in
            let task = store.task(id: token.id)
            let summary = store.cascadeSummary(forTask: token.id)
            return Alert(
                title: Text("Delete \"\(task?.name ?? "task")\"?"),
                message: Text("\(summary.sessionCount) planned sessions and \(summary.reflectionCount) reflections will be deleted."),
                primaryButton: .destructive(Text("Delete task")) {
                    store.deleteTaskCascade(taskId: token.id)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

private struct TaskDeleteAlertToken: Identifiable {
    var id: String
}

private struct GoalDeleteAlertToken: Identifiable {
    var id: String
}

private struct GoalEditToken: Identifiable {
    var id: String
}

struct TaskTimelineView: View {
    @ObservedObject var store: NotebookStore
    var goalId: String
    var taskId: String
    var onBack: () -> Void
    var onReflect: (String) -> Void
    var onPlanTraining: (String, String) -> Void

    @State private var expandedId: String?

    var body: some View {
        let task = store.task(id: taskId)
        let goal = store.goal(id: goalId)
        let sessions = store.sessions(forTask: taskId, goalId: goalId)
        let sorted = sessions.sorted { $0.date > $1.date }
        let latest = sorted.first
        let rest = sorted.dropFirst()

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let thisWeekMonday = cal.mondayStartOfWeek(containing: today)
        let lastWeekMonday = cal.date(byAdding: .day, value: -7, to: thisWeekMonday)!

        let weekGroups: [(key: Date, value: [PlannedSession])] = {
            var dict: [Date: [PlannedSession]] = [:]
            for s in rest {
                let monday = cal.mondayStartOfWeek(containing: s.date)
                dict[monday, default: []].append(s)
            }
            return dict.sorted { $0.key > $1.key }
        }()

        func weekLabel(for monday: Date) -> String {
            if monday == thisWeekMonday { return "This Week" }
            if monday == lastWeekMonday { return "Last Week" }
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            return "Week of \(fmt.string(from: monday))"
        }

        return VStack(spacing: 0) {
            HeaderView(title: task?.name ?? "Task", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(goal?.name ?? "Goal") · \(sessions.count) \(sessions.count == 1 ? "session" : "sessions")")
                        .font(.caption)
                        .foregroundColor(AppColors.label)

                    Button(action: { onPlanTraining(goalId, taskId) }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Plan Training")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(AppColors.label)
                    }

                    if sessions.isEmpty {
                        EmptyDashedState(title: "No sessions planned for this task yet.", subtitle: "Plan training from the center button.")
                    }

                    if let latestSession = latest {
                        TimelineSection(title: "Latest", count: 1) {
                            timelineRow(for: latestSession)
                        }
                    }

                    ForEach(weekGroups, id: \.key) { group in
                        TimelineSection(title: weekLabel(for: group.key), count: group.value.count) {
                            ForEach(group.value.sorted(by: { $0.date > $1.date })) { session in
                                timelineRow(for: session)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func timelineRow(for session: PlannedSession) -> some View {
        TimelineRow(
            session: session,
            reflection: store.reflection(forSessionId: session.id),
            tasks: store.notebook.tasks,
            expanded: expandedId == session.id,
            onTapCircle: {
                if session.status == .planned {
                    onReflect(session.id)
                }
            },
            onToggleExpand: {
                if session.status == .done {
                    if store.reflection(forSessionId: session.id) != nil {
                        expandedId = expandedId == session.id ? nil : session.id
                    } else {
                        onReflect(session.id)
                    }
                } else {
                    onReflect(session.id)
                }
            },
            onDeleteReflection: { id in store.deleteReflection(id: id) }
        )
    }
}

struct TimelineSection<Content: View>: View {
    var title: String
    var count: Int
    var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).fieldLabel()
                Text("· \(count)")
                    .font(.caption)
                    .foregroundColor(AppColors.label)
            }
            content()
        }
    }
}

struct TimelineRow: View {
    var session: PlannedSession
    var reflection: Reflection?
    var tasks: [TrainingTask]
    var expanded: Bool
    var onTapCircle: () -> Void
    var onToggleExpand: () -> Void
    var onDeleteReflection: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onTapCircle) {
                    ZStack {
                        Circle()
                            .fill(session.status == .done ? AppColors.mint : AppColors.background)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(session.status == .done ? AppColors.mint : AppColors.indigo, lineWidth: 1))
                        Image(systemName: session.status == .done ? "checkmark" : "circle")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(session.status == .done ? .white : AppColors.indigo)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .disabled(session.status == .done)
                .accessibility(label: Text(session.status == .done ? "Completed session" : "Reflect on session"))

                Button(action: onToggleExpand) {
                    HStack {
                        Text(shortDate(session.date))
                            .font(.subheadline)
                            .foregroundColor(AppColors.label)
                        Spacer()
                        if reflection == nil {
                            ReflectPencilIcon(size: 16, color: .primary)
                        } else {
                            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(AppColors.label)
                        }
                    }
                }
            }
            .padding(12)

            if expanded, let reflection = reflection {
                VStack(alignment: .leading, spacing: 14) {
                    if !reflection.workedText.isEmpty {
                        ZStack(alignment: .topLeading) {
                            Text(reflection.workedText)
                                .font(.subheadline)
                                .foregroundColor(AppColors.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 20)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            Text("What worked")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(8)
                                .offset(x: 12, y: -10)
                        }
                    }
                    if !reflection.stuckText.isEmpty {
                        ZStack(alignment: .topLeading) {
                            Text(reflection.stuckText)
                                .font(.subheadline)
                                .foregroundColor(AppColors.label)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 20)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            Text("Where I got stuck")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppColors.coral)
                                .cornerRadius(8)
                                .offset(x: 12, y: -10)
                        }
                    }
                    if let mood = reflection.mood {
                        Text("\(mood.glyph) \(mood.label)")
                            .font(.caption)
                            .foregroundColor(AppColors.label)
                    }
                    Button("Delete reflection") {
                        onDeleteReflection(reflection.id)
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.label)
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
            }
        }
        .cardBackground()
    }

    private func shortDate(_ date: Date) -> String {
        DateFormatter.timelineShortDate.string(from: date)
    }
}

// MARK: - Plan Training

struct PlanTrainingView: View {
    @ObservedObject var store: NotebookStore
    var onCancel: () -> Void
    var onSaved: ([PlannedSession]) -> Void
    var initialGoalId: String?

    private let totalSteps = 2
    private let calendar = Calendar.current

    @State private var step = 1
    @State private var displayedMonth: Date = Date()
    @State private var selectedDays: Set<Date> = []
    @State private var selectedGoalIds: Set<String> = []
    @State private var selectedTasksByDay: [Date: Set<String>] = [:]
    @State private var didApplyInitial = false
    @State private var newGoalSheet: GoalEditToken?
    @State private var pendingNewGoalId: String?

    private var sortedDays: [Date] { selectedDays.sorted() }
    private var selectedGoals: [TrainingGoal] { store.activeGoals.filter { selectedGoalIds.contains($0.id) } }

    // Every selected day must have at least one task chosen — no taskless sessions allowed.
    private var planIsValid: Bool {
        !sortedDays.isEmpty && sortedDays.allSatisfy { !(selectedTasksByDay[$0]?.isEmpty ?? true) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PlanStepHeader(
                step: step,
                totalSteps: totalSteps,
                progress: CGFloat(step) / CGFloat(totalSteps),
                onBack: {
                    if step <= 1 { onCancel() }
                    else { withAnimation(.easeOut(duration: 0.2)) { step -= 1 } }
                },
                onClose: onCancel
            )
            if step == 1 { stepDaysGoals } else { stepTasks }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            if !didApplyInitial {
                didApplyInitial = true
                if let g = initialGoalId { _ = selectedGoalIds.insert(g) }
            }
        }
        .sheet(item: $newGoalSheet, onDismiss: finalizeNewGoalDraft) { token in
            EditGoalView(store: store, goalId: token.id, isNewGoal: true) { newGoalSheet = nil }
        }
    }

    /// Mirrors `GoalListView.discardDraftIfUnsaved`: if the user saved the draft (it has a name now),
    /// auto-select it for this plan; otherwise discard the empty draft.
    private func finalizeNewGoalDraft() {
        guard let id = pendingNewGoalId else { return }
        pendingNewGoalId = nil
        if let g = store.goal(id: id), g.name.nilIfBlank != nil {
            _ = selectedGoalIds.insert(id)
        } else {
            store.deleteGoalCascade(goalId: id)
        }
    }

    // MARK: - Step 1: days + goals

    private var stepDaysGoals: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Plan your training")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                        Text("Tap the days you want to train, then pick your goals.")
                            .font(.matMindBody(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    monthCalendar
                    Text(daysSelectedLabel)
                        .font(.matMindBody(size: 15))
                        .foregroundColor(AppColors.label)
                    if !selectedDays.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goals")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.secondaryLabel)
                            WrappingHStack(items: store.activeGoals) { goal in
                                goalChip(goal)
                            }
                            Button(action: {
                                let draft = store.createDraftGoal()
                                pendingNewGoalId = draft.id
                                newGoalSheet = GoalEditToken(id: draft.id)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("New Goal")
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                }
                                .foregroundColor(AppColors.indigo)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(AppColors.indigo.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(16)
            }
            bottomBar(title: "Continue", enabled: !selectedDays.isEmpty && !selectedGoalIds.isEmpty) {
                withAnimation(.easeOut(duration: 0.2)) { step = 2 }
            }
        }
    }

    private func goalChip(_ goal: TrainingGoal) -> some View {
        let selected = selectedGoalIds.contains(goal.id)
        return Button(action: {
            if selected { _ = selectedGoalIds.remove(goal.id) } else { _ = selectedGoalIds.insert(goal.id) }
        }) {
            Text(goal.name)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(selected ? .white : AppColors.label)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(chipBackground(selected: selected, color: goal.goalColor))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Step 2: tasks per day

    private var stepTasks: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What will you drill?")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.label)
                        Text(drillSubtitle)
                            .font(.matMindBody(size: 16))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    ForEach(sortedDays, id: \.self) { day in
                        dayTaskCard(day)
                    }
                    Text("Planning creates an unchecked entry for each day. Check it off after training to reflect.")
                        .font(.matMindBody(size: 15))
                        .foregroundColor(AppColors.label)
                }
                .padding(16)
            }
            if !planIsValid {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Select at least one task to continue")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(Color(.systemRed))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            bottomBar(title: "Save plan (\(sortedDays.count) \(sortedDays.count == 1 ? "day" : "days"))", enabled: planIsValid) {
                handleSave()
            }
        }
    }

    private func dayTaskCard(_ day: Date) -> some View {
        let taskCount = selectedTasksByDay[day]?.count ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(dowString(day))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                Text(mdString(day))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Text("· \(taskCount) \(taskCount == 1 ? "task" : "tasks")")
                    .font(.matMindBody(size: 14))
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                if sortedDays.count > 1 {
                    Button(action: { applyToAll(from: day) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc").font(.system(size: 12))
                            Text("APPLY TO ALL")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .kerning(0.5)
                        }
                        .foregroundColor(AppColors.secondaryLabel)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            ForEach(selectedGoals) { goal in
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(goal.goalColor)
                    let tasks = store.tasks(forGoal: goal.id)
                    if tasks.isEmpty {
                        Text("Add a task to this goal to plan it")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(AppColors.tertiaryLabel)
                    } else {
                        WrappingHStack(items: tasks) { task in
                            taskChip(day: day, task: task, color: goal.goalColor)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.secondaryBackground))
    }

    private func taskChip(day: Date, task: TrainingTask, color: Color) -> some View {
        let selected = selectedTasksByDay[day]?.contains(task.id) ?? false
        return Button(action: { toggleTask(day: day, taskId: task.id) }) {
            Text(task.name)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(selected ? .white : AppColors.label)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(chipBackground(selected: selected, color: color))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func chipBackground(selected: Bool, color: Color) -> some View {
        ZStack {
            if selected {
                Capsule().fill(color)
            } else {
                Capsule().fill(Color(.systemBackground))
                Capsule().stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
    }

    // MARK: - Month calendar (multi-select)

    private var monthCalendar: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { shiftMonth(-1) }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { shiftMonth(1) }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                        .frame(maxWidth: .infinity)
                }
            }
            let days = gridDays
            let rows = (days.count + 6) / 7
            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < days.count, let date = days[idx] {
                                daySelectCell(date)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.secondaryBackground))
    }

    private func daySelectCell(_ date: Date) -> some View {
        let norm = calendar.normalizedTrainingDay(date)
        let selected = selectedDays.contains(norm)
        let isToday = calendar.isDateInToday(date)
        return Button(action: { toggleDay(date) }) {
            ZStack {
                if selected {
                    Circle().fill(AppColors.indigo).frame(width: 36, height: 36)
                } else if isToday {
                    Circle().stroke(AppColors.indigo, lineWidth: 1.5).frame(width: 36, height: 36)
                }
                Text("\(calendar.component(.day, from: date))")
                    .font(.matMindBody(size: 16))
                    .foregroundColor(selected ? .white : AppColors.label)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Bottom bar

    private func bottomBar(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: action) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 28).fill(enabled ? AppColors.indigo : AppColors.indigo.opacity(0.4)))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!enabled)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Actions

    private func toggleDay(_ date: Date) {
        let norm = calendar.normalizedTrainingDay(date)
        if selectedDays.contains(norm) {
            _ = selectedDays.remove(norm)
            selectedTasksByDay.removeValue(forKey: norm)
        } else {
            _ = selectedDays.insert(norm)
        }
    }

    private func toggleTask(day: Date, taskId: String) {
        var set = selectedTasksByDay[day] ?? []
        if set.contains(taskId) { set.remove(taskId) } else { set.insert(taskId) }
        selectedTasksByDay[day] = set
    }

    private func applyToAll(from source: Date) {
        let src = selectedTasksByDay[source] ?? []
        for d in selectedDays { selectedTasksByDay[d] = src }
    }

    private func handleSave() {
        guard planIsValid else { return }
        var proposals: [ProposedSession] = []
        for day in sortedDays {
            let dayTasks = selectedTasksByDay[day] ?? []
            for goal in selectedGoals {
                let goalTaskIds = Set(store.tasks(forGoal: goal.id).map { $0.id })
                let tasksForGoal = Array(dayTasks.intersection(goalTaskIds))
                if tasksForGoal.isEmpty { continue }
                proposals.append(ProposedSession(goalId: goal.id, date: day, taskIds: tasksForGoal))
            }
        }
        let created = store.planSessions(proposals, overrideConflicts: true)
        onSaved(created)
    }

    // MARK: - Calendar helpers

    private var monthFirst: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: monthFirst)
    }

    private var gridDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthFirst) else { return [] }
        let weekdayOfFirst = calendar.component(.weekday, from: monthFirst)
        var days: [Date?] = Array(repeating: nil, count: weekdayOfFirst - 1)
        for d in range {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: monthFirst))
        }
        return days
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: monthFirst) {
            displayedMonth = d
        }
    }

    private var daysSelectedLabel: String {
        selectedDays.isEmpty ? "No days picked yet." : "\(selectedDays.count) day\(selectedDays.count == 1 ? "" : "s") selected."
    }

    private var drillSubtitle: String {
        let names = selectedGoals.map { $0.name }.joined(separator: ", ")
        return "Pick at least one task under \(names) for each day."
    }

    private func dowString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: d).uppercased()
    }

    private func mdString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}

// MARK: - Plan Step Header

private struct PlanStepHeader: View {
    var step: Int
    var totalSteps: Int
    var progress: CGFloat
    var onBack: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                        .dashedCircle()
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Back"))

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule()
                            .fill(AppColors.indigo)
                            .frame(width: geometry.size.width * progress)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                    }
                }
                .frame(height: 6)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                        .dashedCircle()
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Close"))
            }
            .padding(.horizontal, 4)

            Text("STEP \(step) OF \(totalSteps) · PLAN TRAINING")
                .font(.system(size: 10, design: .rounded))
                .tracking(0.8)
                .foregroundColor(AppColors.label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Step 1: Focus

private struct PlanStepFocus: View {
    var goals: [TrainingGoal]
    var goalId: String?
    var onPickGoal: (String) -> Void
    var weekStart: Date
    var weekEnd: Date
    var onShiftWeek: (Int) -> Void
    var canAdvance: Bool
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's your focus?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                        Text("Pick one goal to anchor this week's training.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Week").fieldLabel()
                        HStack {
                            Button(action: { onShiftWeek(-1) }) {
                                Image(systemName: "chevron.left")
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            Spacer()
                            Text(weekRangeLabel)
                                .font(.subheadline.monospacedDigit())
                            Spacer()
                            Button(action: { onShiftWeek(1) }) {
                                Image(systemName: "chevron.right")
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundColor(Color(.systemGray4))
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal").fieldLabel()
                        if goals.isEmpty {
                            EmptyDashedState(title: "No goals yet.", subtitle: "Create one from the Goals tab first.")
                        } else {
                            FlowWrap(goals) { goal in
                                ChipButton(
                                    title: goal.name,
                                    isSelected: goalId == goal.id,
                                    action: { onPickGoal(goal.id) }
                                )
                            }
                        }
                    }

                    Text("Next you'll pick which days you'll train, then which tasks to drill on each day.")
                        .font(.caption)
                        .foregroundColor(AppColors.label)
                }
                .padding(16)
            }

            Divider()
            Button("Continue") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canAdvance)
                .padding()
        }
    }

    private var weekRangeLabel: String {
        let fmt = DateFormatter.monthDay
        return "\(fmt.string(from: weekStart)) – \(fmt.string(from: weekEnd))"
    }
}

// MARK: - Step 2: Days

private struct PlanStepDays: View {
    var weekDays: [Date]
    var selectedDays: Set<Date>
    var onToggleDay: (Date) -> Void
    var focusName: String
    var canAdvance: Bool
    var onContinue: () -> Void

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Which days?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                        (Text("Pick the days you'll train ") + Text(focusName).bold() + Text(". Tap to toggle."))
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    HStack(spacing: 6) {
                        ForEach(Array(weekDays.enumerated()), id: \.offset) { index, date in
                            PlanDayCell(
                                label: dayLabels[index],
                                dayNumber: calendar.component(.day, from: date),
                                isSelected: selectedDays.contains(calendar.normalizedTrainingDay(date)),
                                isToday: calendar.isDateInToday(date),
                                onTap: { onToggleDay(date) }
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Text(selectedDays.isEmpty ? "No days picked yet." : "\(selectedDays.count) \(selectedDays.count == 1 ? "day" : "days") selected.")
                        .font(.caption)
                        .foregroundColor(AppColors.label)
                }
                .padding(16)
            }

            Divider()
            Button("Continue") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canAdvance)
                .padding()
        }
    }
}

private struct PlanDayCell: View {
    var label: String
    var dayNumber: Int
    var isSelected: Bool
    var isToday: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                Text("\(dayNumber)")
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? AppColors.indigo : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? AppColors.indigo : (isToday ? AppColors.indigo : Color(.systemGray4)),
                        style: isSelected || isToday ? StrokeStyle(lineWidth: 1) : StrokeStyle(lineWidth: 1, dash: [5])
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Step 3: Tasks per day

private struct PlanStepTasks: View {
    var selectedDays: [Date]
    var tasksByDay: [Date: [String]]
    var goalTasks: [TrainingTask]
    var onToggleTask: (Date, String) -> Void
    var onApplyToAll: (Date) -> Void
    var totalDays: Int
    var focusName: String
    var onSave: () -> Void

    private let calendar = Calendar.current

    private var hasAnyTaskSelected: Bool {
        let cal = Calendar.current
        return selectedDays.allSatisfy { day in
            let normalized = cal.normalizedTrainingDay(day)
            return !(tasksByDay[normalized] ?? []).isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What will you drill?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                        (Text("Pick tasks under ") + Text(focusName).bold() + Text(" for each day. Leave empty to plan a whole-goal session."))
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    if goalTasks.isEmpty {
                        DashedPanel {
                            Text("No tasks under this goal yet. You can still save — each day will be a whole-goal session.")
                                .font(.caption)
                                .foregroundColor(AppColors.label)
                        }
                    }

                    ForEach(selectedDays, id: \.self) { day in
                        PlanDayTaskSection(
                            day: day,
                            tasksByDay: tasksByDay,
                            goalTasks: goalTasks,
                            totalDays: totalDays,
                            onToggleTask: onToggleTask,
                            onApplyToAll: onApplyToAll
                        )
                    }

                    Text("Planning creates an unchecked entry for each day. Check it off after training to reflect.")
                        .font(.caption)
                        .foregroundColor(AppColors.label)

                    if !goalTasks.isEmpty && !hasAnyTaskSelected {
                        Text("Select at least one task for every day")
                            .font(.caption)
                            .foregroundColor(AppColors.coral)
                    }
                }
                .padding(16)
            }

            Divider()
            Button("Save plan (\(totalDays) \(totalDays == 1 ? "day" : "days"))") { onSave() }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
                .disabled(!goalTasks.isEmpty && !hasAnyTaskSelected)
                .opacity(!goalTasks.isEmpty && !hasAnyTaskSelected ? 0.4 : 1)
        }
    }
}

private struct PlanDayTaskSection: View {
    var day: Date
    var tasksByDay: [Date: [String]]
    var goalTasks: [TrainingTask]
    var totalDays: Int
    var onToggleTask: (Date, String) -> Void
    var onApplyToAll: (Date) -> Void

    private let calendar = Calendar.current
    private let fullDayLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    private var normalized: Date { calendar.normalizedTrainingDay(day) }
    private var dayIdx: Int { (calendar.component(.weekday, from: day) + 5) % 7 }
    private var selectedTaskIds: [String] { tasksByDay[normalized] ?? [] }

    var body: some View {
        DashedPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(fullDayLabels[dayIdx])
                            .font(.system(size: 10, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(AppColors.label)
                        Text(DateFormatter.monthDay.string(from: day))
                            .font(.subheadline.weight(.medium).monospacedDigit())
                        Text("· \(selectedTaskIds.count) \(selectedTaskIds.count == 1 ? "task" : "tasks")")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(AppColors.label)
                    }
                    Spacer()
                    if totalDays > 1 && !selectedTaskIds.isEmpty {
                        Button(action: { onApplyToAll(day) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10, design: .rounded))
                                Text("APPLY TO ALL")
                                    .font(.system(size: 10, design: .rounded))
                                    .tracking(0.5)
                            }
                            .foregroundColor(AppColors.label)
                        }
                    }
                }

                if !goalTasks.isEmpty {
                    FlowWrap(goalTasks) { task in
                        ChipButton(
                            title: task.name,
                            isSelected: selectedTaskIds.contains(task.id),
                            action: { onToggleTask(day, task.id) }
                        )
                    }
                }
            }
        }
    }
}

private struct DuplicateAlertToken: Identifiable {
    var id: String
}

// MARK: - Reflect

struct ReflectFlowView: View {
    @ObservedObject var store: NotebookStore
    var initialSessionId: String?
    var resetToken: UUID
    var onClose: () -> Void
    var onFinish: (PlannedSession) -> Void

    @State private var step: Int
    @State private var selectedSessionId: String?
    @State private var mood: Mood?
    @State private var worked: String
    @State private var stuck: String
    @State private var tryNext: String
    @State private var link: String
    @State private var images: [String]
    @State private var showVoice = false

    init(store: NotebookStore, initialSessionId: String?, resetToken: UUID, onClose: @escaping () -> Void, onFinish: @escaping (PlannedSession) -> Void) {
        self.store = store
        self.initialSessionId = initialSessionId
        self.resetToken = resetToken
        self.onClose = onClose
        self.onFinish = onFinish
        // Initialize once per presentation (identity is keyed by .id(resetToken)).
        // Previously this lived in .onAppear, which re-fires on every re-render — so
        // saving (which mutates the store) reset `step` back to the mood screen.
        let existing = initialSessionId.flatMap { store.reflection(forSessionId: $0) }
        _step = State(initialValue: initialSessionId == nil ? 1 : 2)
        _selectedSessionId = State(initialValue: initialSessionId)
        _mood = State(initialValue: existing?.mood)
        _worked = State(initialValue: existing?.workedText ?? "")
        _stuck = State(initialValue: existing?.stuckText ?? "")
        _tryNext = State(initialValue: existing?.tryNextText ?? "")
        _link = State(initialValue: existing?.link ?? "")
        _images = State(initialValue: existing?.imageFileNames ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            ReflectHeader(step: step, onBack: goBack, onClose: onClose)
            Group {
                if step == 1 {
                    ReflectPickSessionStep(
                        store: store,
                        selectedSessionId: $selectedSessionId,
                        onContinue: { if selectedSessionId != nil { step = 2 } }
                    )
                } else if step == 2 {
                    ReflectMoodStep(store: store, session: selectedSession, mood: $mood, onContinue: { if mood != nil { step = 3 } })
                } else if step == 3 {
                    ReflectNotesStep(
                        store: store,
                        sessionId: selectedSessionId,
                        worked: $worked,
                        stuck: $stuck,
                        tryNext: $tryNext,
                        link: $link,
                        imageFileNames: $images,
                        onUseVoice: { showVoice = true },
                        onFinish: saveReflection
                    )
                } else {
                    ReflectDoneStep(
                        store: store,
                        sessionId: selectedSessionId,
                        mood: mood,
                        onDone: {
                            if let session = selectedSession {
                                onFinish(session)
                            } else {
                                onClose()
                            }
                        }
                    )
                }
            }
        }
        .id(resetToken)
        .sheet(isPresented: $showVoice) {
            VoiceReflectionView(worked: $worked, stuck: $stuck, tryNext: $tryNext, onClose: { showVoice = false })
        }
    }

    private var selectedSession: PlannedSession? {
        guard let selectedSessionId = selectedSessionId else { return nil }
        return store.notebook.sessions.first { $0.id == selectedSessionId }
    }

    private func goBack() {
        if step <= 1 || (step == 2 && initialSessionId != nil) {
            onClose()
        } else {
            step -= 1
        }
    }

    private func saveReflection() {
        guard let sessionId = selectedSessionId, mood != nil, tryNext.nilIfBlank != nil else { return }
        _ = store.saveReflection(sessionId: sessionId, mood: mood, workedText: worked, stuckText: stuck, tryNextText: tryNext, link: link, imageFileNames: images)
        step = 4
    }
}

struct ReflectHeader: View {
    var step: Int
    var onBack: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .frame(width: 30, height: 30)
                        .dashedCircle()
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Back"))
                Spacer()
                if step >= 2 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemGray5))
                            Capsule()
                                .fill(AppColors.indigo)
                                .frame(width: geometry.size.width * CGFloat(step - 1) / 3.0)
                        }
                    }
                    .frame(height: 6)
                    Spacer()
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(width: 30, height: 30)
                        .dashedCircle()
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Close"))
            }
            if step >= 2 {
                Text("Step \(step - 1) of 3")
                    .font(.caption)
                    .foregroundColor(AppColors.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
    }
}

struct ReflectPickSessionStep: View {
    @ObservedObject var store: NotebookStore
    @Binding var selectedSessionId: String?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Which session are you reflecting on?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .fontWeight(.medium)
                        Text("Pick a planned or completed training session.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    let sessions = allSessions()
                    let planned = sessions.filter { $0.status == .planned }
                    let done = sessions.filter { $0.status == .done && !sessionHasReflection($0) }

                    if planned.isEmpty && done.isEmpty {
                        EmptyDashedState(title: "No sessions to reflect on.", subtitle: "Plan a session from the + button, or all sessions have been reflected on.")
                    }

                    if !planned.isEmpty {
                        reflectSessionList(title: "Up next", sessions: planned)
                    }

                    if !done.isEmpty {
                        reflectSessionList(title: "Completed", sessions: done)
                    }
                }
                .padding(16)
            }
        }
    }

    private func sessionHasReflection(_ session: PlannedSession) -> Bool {
        store.reflection(forSessionId: session.id) != nil
    }

    private func reflectSessionList(title: String, sessions: [PlannedSession]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) · \(sessions.count)").fieldLabel()
            ForEach(sessions) { session in
                ReflectSessionRow(
                    store: store,
                    session: session,
                    selected: selectedSessionId == session.id,
                    onSelect: {
                        selectedSessionId = session.id
                        onContinue()
                    }
                )
            }
        }
    }

    private func allSessions() -> [PlannedSession] {
        return store.notebook.sessions
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status == .planned
                }
                return lhs.date > rhs.date
            }
    }
}

struct ReflectSessionRow: View {
    @ObservedObject var store: NotebookStore
    var session: PlannedSession
    var selected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(store.goal(id: session.goalId)?.name ?? "Goal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(DateFormatter.monthDay.string(from: session.date))
                        .font(.caption)
                        .foregroundColor(selected ? Color.white.opacity(0.7) : .secondary)
                }
                let names = session.taskIds.compactMap { store.task(id: $0)?.name }
                if names.isEmpty {
                    Text("No tasks attached")
                        .font(.caption)
                        .foregroundColor(selected ? Color.white.opacity(0.7) : .secondary)
                } else {
                    Text(names.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(selected ? Color.white.opacity(0.7) : .secondary)
                }
            }
            .foregroundColor(selected ? .white : .primary)
            .padding(12)
            .background(selected ? AppColors.indigo : AppColors.background)
            .cardBackground()
        }
    }

    private func taskNames() -> String {
        let names = session.taskIds.compactMap { store.task(id: $0)?.name }
        return names.isEmpty ? "No tasks attached" : names.joined(separator: " · ")
    }
}

struct ReflectMoodStep: View {
    @ObservedObject var store: NotebookStore
    let session: PlannedSession?
    @Binding var mood: Mood?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How did it feel?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .fontWeight(.medium)
                        Text("One quick read on the session. You can change it any time.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    if let session = session {
                        reflectGoalCard(session)
                    }
                    LazyMoodGrid(mood: $mood)
                }
                .padding(16)
            }
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(mood == nil)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
    }

    @ViewBuilder
    private func reflectGoalCard(_ session: PlannedSession) -> some View {
        let goal = store.goal(id: session.goalId)
        let color = goal?.goalColor ?? AppColors.indigo
        let tasks = session.taskIds.compactMap { store.task(id: $0) }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                GoalIconImage(name: goal?.iconName ?? "target", color: color, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal?.name ?? "Session")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Text(longDate(session.date))
                        .font(.matMindBody(size: 14))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                Spacer()
            }
            if !tasks.isEmpty {
                WrappingHStack(items: tasks) { task in
                    Text(task.name)
                        .font(.matMindBody(size: 14))
                        .foregroundColor(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.12))
                        .cornerRadius(14)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.secondaryBackground))
    }

    private func longDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: d)
    }
}

struct LazyMoodGrid: View {
    @Binding var mood: Mood?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                moodButton(.frustrated)
                moodButton(.neutral)
            }
            HStack(spacing: 12) {
                moodButton(.good)
                moodButton(.great)
            }
        }
    }

    private func moodButton(_ option: Mood) -> some View {
        Button(action: { mood = option }) {
            VStack(spacing: 8) {
                Text(option.glyph)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                Text(option.label)
                    .font(.caption)
                    .uppercaseTracking()
            }
            .frame(maxWidth: .infinity, minHeight: 124)
            .foregroundColor(mood == option ? .white : AppColors.label)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(mood == option ? AppColors.indigo : AppColors.secondaryBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ReflectNotesStep: View {
    @ObservedObject var store: NotebookStore
    let sessionId: String?
    @Binding var worked: String
    @Binding var stuck: String
    @Binding var tryNext: String
    @Binding var link: String
    @Binding var imageFileNames: [String]
    var onUseVoice: () -> Void
    var onFinish: () -> Void

    @State private var showLinkField = false
    @State private var showPhotoPicker = false

    private var canFinish: Bool { tryNext.nilIfBlank != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What stood out?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .fontWeight(.medium)
                        Text("A line or two for each is plenty.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    Button(action: onUseVoice) {
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                            Text("Use Voice Instead")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(AppColors.indigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.indigo.opacity(0.10)))
                    }
                    .buttonStyle(PlainButtonStyle())

                    labeledField($worked, "What worked today", AppColors.winGreen, "A grip, a setup, a moment that clicked...")
                    labeledField($stuck, "Where I got stuck", AppColors.stuckCoral, "What didn't work, what felt off, what to adjust...")
                    labeledField($tryNext, "What I'll try next *", AppColors.indigo, "A different angle, a drill to try, something to focus on...")

                    linkRow
                    photosRow
                }
                .padding(16)
            }
            Button("Save reflection", action: onFinish)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canFinish)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
        .sheet(isPresented: $showPhotoPicker) {
            NoteImagePicker { data in
                if let sid = sessionId, let fn = store.addReflectionImage(sessionId: sid, imageData: data) {
                    imageFileNames.append(fn)
                }
            }
        }
    }

    private func labeledField(_ text: Binding<String>, _ label: String, _ color: Color, _ placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            TrainingTextView(text: text, placeholder: placeholder)
                .frame(height: 108)
                .padding(.top, 8)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(color)
                .cornerRadius(8)
                .offset(x: 8, y: -10)
        }
    }

    @ViewBuilder
    private var linkRow: some View {
        if showLinkField || link.nilIfBlank != nil {
            HStack(spacing: 8) {
                Image(systemName: "link").foregroundColor(AppColors.secondaryLabel)
                TextField("Paste link...", text: $link).font(.matMindBody(size: 14))
            }
            .padding(11)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), lineWidth: 1))
        } else {
            Button(action: { showLinkField = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "link.badge.plus")
                    Text("Add link").font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .foregroundColor(AppColors.label)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var photosRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                Text("Attach photos").font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundColor(AppColors.label)

            if !imageFileNames.isEmpty, let sid = sessionId {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(imageFileNames, id: \.self) { fn in
                            thumbnail(sid: sid, fn: fn)
                        }
                    }
                }
            }

            Button(action: { showPhotoPicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20))
                    Text("Choose from album").font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundColor(AppColors.indigo)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.indigo.opacity(0.08)))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func thumbnail(sid: String, fn: String) -> some View {
        ZStack(alignment: .topTrailing) {
            if let data = store.reflectionImageData(sessionId: sid, fileName: fn), let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)).frame(width: 84, height: 84)
            }
            Button(action: { imageFileNames.removeAll { $0 == fn } }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.4)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(4)
        }
    }
}

// MARK: - Voice Reflection

struct VoiceReflectionView: View {
    @Binding var worked: String
    @Binding var stuck: String
    @Binding var tryNext: String
    var onClose: () -> Void

    private enum Phase { case idle, recording, recorded }

    @State private var index = 0
    @State private var phase: Phase = .idle
    @State private var draft = ""
    @State private var elapsed = 0
    @State private var statusMessage: String?
    @State private var recognizer = SpeechRecognizer()
    @State private var timer: Timer?

    private let questions: [(label: String, color: Color, prompt: String)] = [
        ("What worked today", AppColors.winGreen, "A grip, a setup, a moment that clicked..."),
        ("Where I got stuck", AppColors.stuckCoral, "What didn't work, what felt off, what to adjust..."),
        ("What I'll try next", AppColors.indigo, "A different angle, a drill to try, something to focus on...")
    ]
    private var q: (label: String, color: Color, prompt: String) { questions[index] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: handleBack) {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.label).frame(width: 44, height: 44)
                }
                Spacer()
                Text("\(index + 1) of 3")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { stopRecording(); onClose() }) {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.label).frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(q.color).frame(width: geo.size.width * CGFloat(index + 1) / 3.0)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 16)

            Spacer()

            Text(q.label)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(q.color))
            Text(q.prompt)
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundColor(AppColors.secondaryLabel)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            Spacer()

            phaseContent

            Spacer()

            if let s = statusMessage {
                Text(s)
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            bottomButton
                .padding(.horizontal, 16)
                .padding(.bottom, phase == .idle ? 8 : 30)

            if phase == .idle {
                Button(action: skip) {
                    Text("Skip").font(.system(size: 17, design: .rounded)).foregroundColor(AppColors.secondaryLabel)
                }
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .onAppear {
            draft = bindingValue()
            phase = draft.nilIfBlank != nil ? .recorded : .idle
            recognizer.onText = { text in draft = text }
            recognizer.onStatus = { msg in statusMessage = msg }
        }
        .onDisappear { stopRecording() }
    }

    @ViewBuilder
    private var phaseContent: some View {
        if phase == .recording {
            VStack(spacing: 16) {
                VoiceWaveform(color: q.color)
                    .frame(height: 44)
                    .padding(.horizontal, 40)
                HStack(spacing: 8) {
                    Circle().fill(AppColors.stuckCoral).frame(width: 10, height: 10)
                    Text("Recording…")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.stuckCoral)
                    Text(timeString)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                }
            }
        } else if phase == .recorded {
            VStack(spacing: 10) {
                TrainingTextView(text: $draft, placeholder: "Your words appear here. You can edit them.")
                    .frame(height: 150)
                    .padding(.horizontal, 16)
                Button(action: reRecord) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 13))
                        Text("Re-record").font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(AppColors.secondaryLabel)
                }
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch phase {
        case .idle:
            bigButton("Tap to Record", icon: "mic.fill", color: q.color, action: startRecording)
        case .recording:
            bigButton("Done", icon: "stop.fill", color: AppColors.stuckCoral, action: finishRecording)
        case .recorded:
            bigButton(index < questions.count - 1 ? "Next" : "Done", icon: nil, color: AppColors.indigo, action: next)
        }
    }

    private func bigButton(_ title: String, icon: String?, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon { Image(systemName: icon).font(.system(size: 18)) }
                Text(title).font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 16).fill(color))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var timeString: String { String(format: "%d:%02d", elapsed / 60, elapsed % 60) }

    private func bindingValue() -> String { index == 0 ? worked : (index == 1 ? stuck : tryNext) }
    private func setBindingValue(_ v: String) { if index == 0 { worked = v } else if index == 1 { stuck = v } else { tryNext = v } }

    private func startRecording() {
        recognizer.requestAuthorization { granted in
            if !granted { statusMessage = "Mic/speech access is off — you can still type your answer." }
            recognizer.start()
            elapsed = 0
            phase = .recording
            startTimer()
        }
    }

    private func finishRecording() {
        stopRecording()
        phase = .recorded
    }

    private func reRecord() {
        draft = ""
        startRecording()
    }

    private func skip() { goNext() }

    private func next() {
        setBindingValue(draft)
        goNext()
    }

    private func goNext() {
        stopRecording()
        if index < questions.count - 1 {
            index += 1
            draft = bindingValue()
            phase = draft.nilIfBlank != nil ? .recorded : .idle
            statusMessage = nil
        } else {
            onClose()
        }
    }

    private func handleBack() {
        stopRecording()
        if phase == .recorded { setBindingValue(draft) }
        if index > 0 {
            index -= 1
            draft = bindingValue()
            phase = draft.nilIfBlank != nil ? .recorded : .idle
            statusMessage = nil
        } else {
            onClose()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsed += 1 }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        recognizer.stop()
    }
}

struct VoiceWaveform: View {
    let color: Color
    @State private var heights: [CGFloat] = Array(repeating: 6, count: 26)
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<heights.count, id: \.self) { i in
                Capsule().fill(color).frame(width: 4, height: heights[i])
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.12)) {
                    heights = (0..<heights.count).map { idx in
                        // Taller toward the right, like a live meter.
                        let bias = CGFloat(idx) / CGFloat(heights.count)
                        return CGFloat.random(in: 6...(10 + bias * 34))
                    }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

final class SpeechRecognizer {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var onText: ((String) -> Void)?
    var onStatus: ((String) -> Void)?

    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func start() {
        stop()
        guard let recognizer = recognizer, recognizer.isAvailable else {
            onStatus?("Speech recognition isn't available right now. Type below.")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onStatus?("Couldn't start audio. Type below.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                self?.onText?(result.bestTranscription.formattedString)
            }
            if error != nil || (result?.isFinal ?? false) {
                self?.stop()
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            onStatus?("Couldn't start the microphone. Type below.")
            stop()
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }
}

struct ReflectDoneStep: View {
    @ObservedObject var store: NotebookStore
    var sessionId: String?
    var mood: Mood?
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 38, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 82, height: 82)
                .background(AppColors.mint)
                .clipShape(Circle())
            Text("Reflection logged.")
                .font(.title)
                .fontWeight(.medium)
            Text("Small notes compound. Keep showing up.")
                .font(.subheadline)
                .foregroundColor(AppColors.label)
                .multilineTextAlignment(.center)
            if let session = session {
                DashedPanel {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.date.trainingDayString).fieldLabel()
                        Text(store.goal(id: session.goalId)?.name ?? "Goal")
                            .font(.headline)
                        let names = session.taskIds.compactMap { store.task(id: $0)?.name }
                        if !names.isEmpty {
                            Text(names.joined(separator: " · "))
                                .font(.caption)
                                .foregroundColor(AppColors.label)
                        }
                        if let mood = mood {
                            Text("\(mood.glyph) \(mood.label)")
                                .font(.caption)
                                .foregroundColor(AppColors.label)
                        }
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
    }

    private var session: PlannedSession? {
        guard let sessionId = sessionId else { return nil }
        return store.notebook.sessions.first { $0.id == sessionId }
    }
}

// MARK: - Shared Views

struct HeaderView: View {
    var title: String
    var onBack: (() -> Void)?
    var rightTitle: String?
    var rightAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let onBack = onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Back"))
            } else {
                Spacer().frame(width: 44)
            }
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if let rightTitle = rightTitle, let rightAction = rightAction {
                Button(rightTitle, action: rightAction)
                    .font(.caption)
                    .foregroundColor(AppColors.label)
                    .frame(minWidth: 44, minHeight: 44)
            } else {
                Spacer().frame(width: 44)
            }
        }
        .padding(.horizontal, 6)
        .background(AppColors.background)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(.systemGray4)), alignment: .bottom)
    }
}

struct WeekStripView: View {
    var dayStates: [String: SessionStatus]
    @State private var anchor = Date()

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let start = Calendar.current.mondayStartOfWeek(containing: anchor)
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
        return VStack(spacing: 10) {
            HStack {
                Button(action: { shift(-7) }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Previous week"))
                Spacer()
                Text("\(shortMonthDay(days.first ?? start)) - \(shortMonthDay(days.last ?? start))")
                    .font(.caption)
                    .uppercaseTracking()
                    .foregroundColor(AppColors.label)
                Spacer()
                Button(action: { shift(7) }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibility(label: Text("Next week"))
            }
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    VStack(spacing: 5) {
                        Text(labels[index])
                            .font(.caption)
                            .foregroundColor(AppColors.label)
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(.caption)
                            .frame(width: 32, height: 32)
                            .background(background(for: day))
                            .foregroundColor(foreground(for: day))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cardBackground()
    }

    private func shift(_ days: Int) {
        anchor = Calendar.current.date(byAdding: .day, value: days, to: anchor) ?? anchor
    }

    private func state(for day: Date) -> SessionStatus? {
        dayStates[day.trainingDayString]
    }

    private func background(for day: Date) -> Color {
        state(for: day) == .done ? AppColors.indigo : AppColors.background
    }

    private func foreground(for day: Date) -> Color {
        state(for: day) == .done ? .white : AppColors.label
    }

    private func shortMonthDay(_ date: Date) -> String {
        DateFormatter.monthDay.string(from: date)
    }
}

struct TaskTagView: View {
    let task: TrainingTask
    @ObservedObject var store: NotebookStore

    var body: some View {
        let completed = store.notebook.sessions.filter { $0.taskIds.contains(task.id) && $0.status == .done }.count
        let label = task.name + " · " + "\(completed)d"
        return Text(label)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(Color(.label))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

struct PlanTaskTagView: View {
    let task: TrainingTask
    var goalColor: Color = AppColors.indigo

    var body: some View {
        Text(task.name)
            .font(.system(size: 11, design: .rounded))
            .foregroundColor(goalColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(goalColor.opacity(0.12))
            .cornerRadius(10)
    }
}

struct WrappingHStack<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    let spacing: CGFloat = 8

    @State private var totalHeight: CGFloat = 30

    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: max(totalHeight, 1))
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geometry.size.width {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if index == items.count - 1 {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { d in
                        let result = height
                        if index == items.count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { totalHeight = $0 }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct EmptyDashedState: View {
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryLabel)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardBackground()
    }
}

struct EmptyStateCard: View {
    var icon: String
    var title: String
    var subtitle: String
    var ctaTitle: String?
    var ctaAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .foregroundColor(AppColors.indigo.opacity(0.5))
            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryLabel)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.secondaryLabel)
            if let ctaTitle = ctaTitle, let ctaAction = ctaAction {
                Button(action: ctaAction) {
                    Text(ctaTitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppColors.indigo)
                        .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardBackground()
    }
}

struct CircleIcon: View {
    var systemName: String
    var bgColor: Color = .black

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(AppColors.label)
            .frame(width: 38, height: 38)
            .dashedCircle()
    }
}

struct ChipButton: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .background(isSelected ? AppColors.indigo : Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(.systemGray2), style: StrokeStyle(lineWidth: 1, dash: isSelected ? [] : [4, 3])))
        }
        .contentShape(Rectangle())
    }
}

struct DashedPanel<Content: View>: View {
    var content: () -> Content

    var body: some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cardBackground()
    }
}

struct FlowWrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(data), id: \.id) { item in
                content(item)
            }
        }
    }
}

struct AutoFocusTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var id: UUID

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = UIFont.preferredFont(forTextStyle: .subheadline)
        tf.borderStyle = .none
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tf.becomeFirstResponder()
        }
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        if context.coordinator.lastId != id {
            context.coordinator.lastId = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                uiView.becomeFirstResponder()
            }
        }
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AutoFocusTextField
        var lastId: UUID

        init(_ parent: AutoFocusTextField) {
            self.parent = parent
            self.lastId = parent.id
        }

        @objc func textChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let trimmed = parent.text.nilIfBlank, trimmed.count <= 15 {
                // Let the button action handle adding
            }
            return false
        }
    }
}

struct TrainingTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray3.cgColor
        view.layer.cornerRadius = 8
        view.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        view.text = placeholder
        view.textColor = .placeholderText
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if text.isEmpty && !uiView.isFirstResponder {
            uiView.text = placeholder
            uiView.textColor = .placeholderText
        } else if uiView.textColor == .placeholderText && !text.isEmpty {
            uiView.text = text
            uiView.textColor = .label
        } else if uiView.textColor != .placeholderText && uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TrainingTextView

        init(_ parent: TrainingTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == .placeholderText {
                textView.text = ""
                textView.textColor = .label
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.textColor == .placeholderText ? "" : textView.text
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                textView.text = parent.placeholder
                textView.textColor = .placeholderText
                parent.text = ""
            }
        }
    }
}

// MARK: - Preview

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(sessionStore: previewSessionStore())
    }

    private static func previewSessionStore() -> AppSessionStore {
        let account = UserAccount(provider: .google, providerSubjectId: "preview")
        let memory = MemoryAccountStore(account: account)
        let session = AppSessionStore(accountStore: memory, authService: PreviewAuthService()) { _ in
            PreviewPersistence()
        }
        if session.route == .signedInMissingProfile {
            session.saveProfile(firstName: "Alex", lastName: "Rivera")
        }
        return session
    }
}

private final class PreviewAuthService: AuthServicing {
    func signInWithApple(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        completion(.success(UserAccount(provider: .apple, providerSubjectId: "preview-apple")))
    }

    func signInWithGoogle(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        completion(.success(UserAccount(provider: .google, providerSubjectId: "preview-google")))
    }

    static func handleOpenURL(_ url: URL) -> Bool { false }
}

private final class MemoryAccountStore: AccountStore {
    var account: UserAccount?

    init(account: UserAccount?) {
        self.account = account
    }

    func loadAccount() -> UserAccount? { account }
    func saveAccount(_ account: UserAccount) throws { self.account = account }
    func clearAccount() throws { account = nil }
}

private final class PreviewPersistence: NotebookPersistence {
    private var notebook: TrainingNotebook

    init() {
        let accountId = "google_preview"
        let goal = TrainingGoal(accountId: accountId, name: "Leg Locks")
        let task = TrainingTask(goalId: goal.id, name: "Entry from half guard")
        let session = PlannedSession(goalId: goal.id, date: Date(), taskIds: [task.id], status: .planned)
        self.notebook = TrainingNotebook(accountId: accountId, goals: [goal], tasks: [task], sessions: [session])
    }

    func load(accountId: String) throws -> TrainingNotebook {
        notebook.accountId = accountId
        return notebook
    }

    func save(_ notebook: TrainingNotebook) throws {
        self.notebook = notebook
    }
}
