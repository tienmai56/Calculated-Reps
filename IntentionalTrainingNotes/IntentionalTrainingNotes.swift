import AuthenticationServices
import Foundation
import Network
import Security
import SwiftUI
import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

// MARK: - Shared Formatters

extension DateFormatter {
    static let trainingDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let timelineShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

extension Calendar {
    func normalizedTrainingDay(_ date: Date) -> Date {
        startOfDay(for: date)
    }

    func mondayStartOfWeek(containing date: Date) -> Date {
        let start = startOfDay(for: date)
        let weekday = component(.weekday, from: start)
        let daysFromMonday = weekday == 1 ? -6 : 2 - weekday
        return self.date(byAdding: .day, value: daysFromMonday, to: start) ?? start
    }

    func sameTrainingDay(_ lhs: Date, _ rhs: Date) -> Bool {
        isDate(lhs, inSameDayAs: rhs)
    }
}

extension Date {
    var trainingDayString: String {
        DateFormatter.trainingDay.string(from: self)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

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

// MARK: - Domain Models

enum AuthProvider: String, Codable, CaseIterable {
    case apple
    case google

    var label: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }
}

enum AppRoute: Equatable {
    case signedOut
    case signedInMissingProfile
    case ready
}

enum Belt: String, Codable, CaseIterable, Identifiable {
    case white
    case blue
    case purple
    case brown
    case black

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

enum Mood: String, Codable, CaseIterable, Identifiable {
    case frustrated
    case neutral
    case good
    case great

    var id: String { rawValue }

    var label: String {
        switch self {
        case .frustrated: return "Frustrated"
        case .neutral: return "Neutral"
        case .good: return "Good"
        case .great: return "Great"
        }
    }

    var glyph: String {
        switch self {
        case .frustrated: return "😤"
        case .neutral: return "😐"
        case .good: return "😊"
        case .great: return "🔥"
        }
    }
}

enum SessionStatus: String, Codable {
    case planned
    case done
}

struct UserAccount: Codable, Equatable {
    var id: String
    var provider: AuthProvider
    var providerSubjectId: String
    var email: String?
    var displayName: String?
    var createdAt: Date
    var lastSignedInAt: Date

    init(
        id: String? = nil,
        provider: AuthProvider,
        providerSubjectId: String,
        email: String? = nil,
        displayName: String? = nil,
        createdAt: Date = Date(),
        lastSignedInAt: Date = Date()
    ) {
        let accountId = id ?? "\(provider.rawValue)_\(providerSubjectId)"
        self.id = accountId.sanitizedAccountId
        self.provider = provider
        self.providerSubjectId = providerSubjectId
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.lastSignedInAt = lastSignedInAt
    }
}

struct UserProfile: Codable, Equatable {
    var accountId: String
    var firstName: String
    var lastName: String
    var belt: Belt?
    var createdAt: Date
    var updatedAt: Date

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    init(
        accountId: String,
        firstName: String,
        lastName: String,
        belt: Belt? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.accountId = accountId
        self.firstName = firstName
        self.lastName = lastName
        self.belt = belt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct AppColors {
    static let indigo = Color(red: 63/255, green: 61/255, blue: 158/255)
    static let mint = Color(red: 94/255, green: 196/255, blue: 182/255)
    static let coral = Color(red: 242/255, green: 139/255, blue: 130/255)
    static let offWhite = Color(red: 240/255, green: 237/255, blue: 235/255)

    // Warm background: faint warm off-white in light mode, system default in dark
    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemBackground : UIColor(red: 250/255, green: 249/255, blue: 247/255, alpha: 1)
    })
    static let secondaryBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondarySystemBackground : UIColor(red: 245/255, green: 243/255, blue: 240/255, alpha: 1)
    })
    static let groupedBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 250/255, green: 249/255, blue: 247/255, alpha: 1)
    })
    static let cardBackground = Color(.systemBackground) // true white cards for contrast

    // Warm grays for text
    static let label = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .label : UIColor(red: 44/255, green: 42/255, blue: 41/255, alpha: 1)
    })
    static let secondaryLabel = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .secondaryLabel : UIColor(red: 120/255, green: 117/255, blue: 113/255, alpha: 1)
    })
    static let tertiaryLabel = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .tertiaryLabel : UIColor(red: 165/255, green: 161/255, blue: 155/255, alpha: 1)
    })
    static let separator = Color(.separator)
}

struct AppTypography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded).weight(.medium)
    static let title = Font.system(size: 22, weight: .medium, design: .rounded)
    static let headline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
    static let subhead = Font.system(.subheadline, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let micro = Font.system(size: 10, weight: .medium, design: .rounded)

    // Convenience for custom sizes with rounded design
    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }
}

struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

struct GoalIconLibrary {
    static let icons = ["target", "flame", "bolt.fill", "star.fill", "heart.fill",
                        "figure.walk", "sportscourt", "music.note", "book.fill",
                        "pencil", "paintbrush.fill", "camera.fill", "leaf.fill",
                        "hammer.fill", "flag.fill",
                        "custom.arm", "custom.leg", "custom.toe"]
    static let customIcons: Set<String> = ["custom.arm", "custom.leg", "custom.toe"]

    static func isCustomIcon(_ name: String) -> Bool { customIcons.contains(name) }
    static let colors: [(name: String, color: Color)] = [
        ("indigo", AppColors.indigo),
        ("mint", AppColors.mint),
        ("coral", AppColors.coral),
        ("slate", Color(.systemGray)),
        ("blue", Color(.systemBlue)),
        ("purple", Color(.systemPurple)),
        ("teal", Color(.systemTeal)),
        ("orange", .orange)
    ]
    static func color(for name: String) -> Color {
        colors.first(where: { $0.name == name })?.color ?? AppColors.indigo
    }
}

// Renders SF Symbol or custom SVG icon with gradient fill, standalone (no background shape)
struct GoalIconImage: View {
    let name: String
    let color: Color
    let size: CGFloat

    private var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [color, color.opacity(0.55)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        if GoalIconLibrary.isCustomIcon(name) {
            filledShape
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size * 0.5, weight: .medium, design: .rounded))
                .foregroundColor(.clear)
                .overlay(
                    gradient.mask(
                        Image(systemName: name)
                            .font(.system(size: size * 0.5, weight: .medium, design: .rounded))
                    )
                )
        }
    }

    @ViewBuilder
    private var filledShape: some View {
        switch name {
        case "custom.arm": ArmIconShape().fill(gradient)
        case "custom.leg": LegIconShape().fill(gradient)
        case "custom.toe": ToeIconShape().fill(gradient)
        default: ArmIconShape().fill(gradient)
        }
    }
}

struct TrainingGoal: Codable, Equatable, Identifiable {
    var id: String
    var accountId: String
    var name: String
    var iconName: String
    var colorName: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    var goalColor: Color { GoalIconLibrary.color(for: colorName) }

    init(
        id: String = "g_\(UUID().uuidString)",
        accountId: String,
        name: String,
        iconName: String = "target",
        colorName: String = "indigo",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.accountId = accountId
        self.name = name
        self.iconName = iconName
        self.colorName = colorName
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, accountId, name, iconName, colorName, isArchived, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        accountId = try c.decode(String.self, forKey: .accountId)
        name = try c.decode(String.self, forKey: .name)
        iconName = try c.decodeIfPresent(String.self, forKey: .iconName) ?? "target"
        colorName = try c.decodeIfPresent(String.self, forKey: .colorName) ?? "indigo"
        isArchived = try c.decode(Bool.self, forKey: .isArchived)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

struct TrainingTask: Codable, Equatable, Identifiable {
    var id: String
    var goalId: String
    var name: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = "t_\(UUID().uuidString)",
        goalId: String,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.goalId = goalId
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct PlannedSession: Codable, Equatable, Identifiable {
    var id: String
    var goalId: String
    var date: Date
    var taskIds: [String]
    var status: SessionStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = "p_\(UUID().uuidString)",
        goalId: String,
        date: Date,
        taskIds: [String],
        status: SessionStatus = .planned,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.goalId = goalId
        self.date = Calendar.current.normalizedTrainingDay(date)
        self.taskIds = taskIds
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Reflection: Codable, Equatable, Identifiable {
    var id: String
    var sessionId: String
    var date: Date
    var workedText: String
    var stuckText: String
    var mood: Mood?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = "r_\(UUID().uuidString)",
        sessionId: String,
        date: Date,
        workedText: String,
        stuckText: String,
        mood: Mood?,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.date = Calendar.current.normalizedTrainingDay(date)
        self.workedText = workedText
        self.stuckText = stuckText
        self.mood = mood
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Note: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var body: String
    var imageFileNames: [String]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = "n_\(UUID().uuidString)",
        title: String = "",
        body: String = "",
        imageFileNames: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.imageFileNames = imageFileNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TrainingNotebook: Codable, Equatable {
    var schemaVersion: Int
    var accountId: String
    var profile: UserProfile?
    var goals: [TrainingGoal]
    var tasks: [TrainingTask]
    var sessions: [PlannedSession]
    var reflections: [Reflection]
    var notes: [Note]

    init(
        schemaVersion: Int = 3,
        accountId: String = "local",
        profile: UserProfile? = nil,
        goals: [TrainingGoal] = [],
        tasks: [TrainingTask] = [],
        sessions: [PlannedSession] = [],
        reflections: [Reflection] = [],
        notes: [Note] = []
    ) {
        self.schemaVersion = schemaVersion
        self.accountId = accountId
        self.profile = profile
        self.goals = goals
        self.tasks = tasks
        self.sessions = sessions
        self.reflections = reflections
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case accountId
        case profile
        case goals
        case tasks
        case sessions
        case reflections
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 3
        accountId = try container.decodeIfPresent(String.self, forKey: .accountId) ?? "local"
        profile = try container.decodeIfPresent(UserProfile.self, forKey: .profile)
        goals = try container.decodeIfPresent([TrainingGoal].self, forKey: .goals) ?? []
        tasks = try container.decodeIfPresent([TrainingTask].self, forKey: .tasks) ?? []
        sessions = try container.decodeIfPresent([PlannedSession].self, forKey: .sessions) ?? []
        reflections = try container.decodeIfPresent([Reflection].self, forKey: .reflections) ?? []
        notes = try container.decodeIfPresent([Note].self, forKey: .notes) ?? []
    }
}

struct ProposedSession: Equatable {
    var goalId: String
    var date: Date
    var taskIds: [String]
}

struct DuplicatePlanConflict: Equatable {
    var goal: TrainingGoal
    var date: Date
    var sharedTaskNames: [String]
}

struct TaskCascadeSummary: Equatable {
    var sessionCount: Int
    var reflectionCount: Int
}

struct GoalCascadeSummary: Equatable {
    var taskCount: Int
    var sessionCount: Int
    var reflectionCount: Int
}

private extension String {
    var sanitizedAccountId: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.map(String.init).joined()
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
        guard let restored = accountStore.loadAccount() else {
            account = nil
            notebookStore = nil
            route = .signedOut
            return
        }
        activate(account: restored)
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
        self.route = store.notebook.profile == nil ? .signedInMissingProfile : .ready
    }
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
    var activeGoals: [TrainingGoal] { notebook.goals.filter { !$0.isArchived }.sorted { $0.createdAt < $1.createdAt } }

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
    func saveReflection(sessionId: String, mood: Mood?, workedText: String, stuckText: String) -> Reflection? {
        guard let sessionIndex = notebook.sessions.firstIndex(where: { $0.id == sessionId }) else { return nil }
        let session = notebook.sessions[sessionIndex]
        let reflection = Reflection(
            sessionId: session.id,
            date: session.date,
            workedText: workedText.trimmingCharacters(in: .whitespacesAndNewlines),
            stuckText: stuckText.trimmingCharacters(in: .whitespacesAndNewlines),
            mood: mood
        )
        mutate {
            notebook.reflections.removeAll { $0.sessionId == sessionId }
            notebook.reflections.append(reflection)
            notebook.sessions[sessionIndex].status = .done
            notebook.sessions[sessionIndex].updatedAt = Date()
        }
        return reflection
    }

    func deleteReflection(id: String) {
        mutate {
            notebook.reflections.removeAll { $0.id == id }
        }
    }

    func updateSession(id: String, goalId: String, taskIds: [String]) {
        guard let idx = notebook.sessions.firstIndex(where: { $0.id == id }) else { return }
        mutate {
            notebook.sessions[idx].goalId = goalId
            notebook.sessions[idx].taskIds = taskIds
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

// MARK: - Main Shell

enum MainTab {
    case home
    case plan
    case goals
    case notes
}

enum GoalsRoute: Equatable {
    case list
    case detail(String)
}

struct MainAppView: View {
    @ObservedObject var sessionStore: AppSessionStore
    @ObservedObject var store: NotebookStore

    @State private var tab: MainTab = .home
    @State private var stack: [GoalsRoute] = [.list]
    @State private var isPlanning = false
    @State private var planningGoalId: String?
    @State private var isProfileOpen = false
    @State private var reflectSessionId: String?
    @State private var reflectResetToken = UUID()
    @State private var isAddingGoalFromHome = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if tab == .home {
                    HomeView(store: store, onOpenGoalTasks: { goalId in
                        stack = [.list, .detail(goalId)]
                        tab = .goals
                    }, onReflect: { sessionId in
                        reflectSessionId = sessionId
                        reflectResetToken = UUID()
                    }, onPlanTraining: {
                        planningGoalId = nil
                        isPlanning = true
                    }, onAddGoal: {
                        isAddingGoalFromHome = true
                    })
                } else if tab == .plan {
                    PlanListView(
                        store: store,
                        onAdd: {
                            planningGoalId = nil
                            isPlanning = true
                        },
                        onReflect: { sessionId in
                            reflectSessionId = sessionId
                            reflectResetToken = UUID()
                        }
                    )
                } else if tab == .notes {
                    NotesListView(store: store)
                } else {
                    goalsScreen
                }
            }
            BottomTabsView(
                active: tab,
                onHome: {
                    tab = .home
                },
                onPlan: {
                    tab = .plan
                },
                onGoals: {
                    tab = .goals
                    stack = [.list]
                },
                onNotes: {
                    tab = .notes
                }
            )
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .sheet(isPresented: $isPlanning) {
            PlanTrainingView(
                store: store,
                onCancel: {
                    isPlanning = false
                    planningGoalId = nil
                },
                onSaved: { created in
                    isPlanning = false
                    planningGoalId = nil
                    if let first = created.first {
                        routeToSession(first)
                    }
                },
                initialGoalId: planningGoalId
            )
        }
        .sheet(isPresented: $isProfileOpen) {
            ProfileSetupView(
                account: sessionStore.account,
                profile: store.profile,
                onSave: { firstName, lastName in
                    sessionStore.saveProfile(firstName: firstName, lastName: lastName)
                    isProfileOpen = false
                },
                onSignOut: {
                    isProfileOpen = false
                    sessionStore.signOut()
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { reflectSessionId != nil },
            set: { if !$0 { reflectSessionId = nil } }
        )) {
            ReflectFlowView(
                store: store,
                initialSessionId: reflectSessionId,
                resetToken: reflectResetToken,
                onClose: {
                    reflectSessionId = nil
                },
                onFinish: { _ in
                    reflectSessionId = nil
                }
            )
        }
        .sheet(isPresented: $isAddingGoalFromHome) {
            AddGoalSheet(store: store, onDone: { isAddingGoalFromHome = false })
        }
    }

    private var goalsScreen: some View {
        Group {
            switch stack.last ?? .list {
            case .list:
                GoalListView(
                    store: store,
                    onOpenGoal: { stack.append(.detail($0)) },
                    onOpenProfile: { isProfileOpen = true },
                    onSignOut: sessionStore.signOut
                )
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

struct HomeView: View {
    @ObservedObject var store: NotebookStore
    var onOpenGoalTasks: (String) -> Void
    var onReflect: (String) -> Void
    var onPlanTraining: () -> Void
    var onAddGoal: () -> Void

    @State private var selectedPeriod: String = "week"

    private var cal: Calendar { Calendar.current }

    private var greeting: String {
        let hour = cal.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    // MARK: - Period boundaries

    private var weekStart: Date { cal.mondayStartOfWeek(containing: Date()) }
    private var weekEnd: Date {
        let endOfThisWeek = cal.date(byAdding: .day, value: 6, to: weekStart)!
        let today = cal.startOfDay(for: Date())
        let daysLeft = cal.dateComponents([.day], from: today, to: endOfThisWeek).day ?? 0
        if daysLeft < 2 {
            return cal.date(byAdding: .day, value: 13, to: weekStart)!
        }
        return endOfThisWeek
    }

    private var monthStart: Date {
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }
    private var monthEnd: Date {
        guard let next = cal.date(byAdding: .month, value: 1, to: monthStart) else { return Date() }
        return cal.date(byAdding: .day, value: -1, to: next) ?? Date()
    }

    private var periodStart: Date { selectedPeriod == "week" ? weekStart : monthStart }
    private var periodEnd: Date { selectedPeriod == "week" ? weekEnd : monthEnd }

    private var daysInPeriod: Int {
        if selectedPeriod == "week" { return 7 }
        return (cal.dateComponents([.day], from: monthStart, to: monthEnd).day ?? 29) + 1
    }

    // MARK: - Filtered data

    private var sessionsForPeriod: [PlannedSession] {
        store.notebook.sessions.filter { s in
            let d = cal.startOfDay(for: s.date)
            return d >= periodStart && d <= periodEnd
        }
    }

    private var completedForPeriod: Int {
        sessionsForPeriod.filter { $0.status == .done }.count
    }

    /// Consecutive weeks with at least one completed session, counting back from current week
    private var trainingStreak: Int {
        let doneDates = Set(
            store.notebook.sessions
                .filter { $0.status == .done }
                .map { cal.startOfDay(for: $0.date) }
        )
        // Group done dates by week start (Monday)
        let doneWeeks = Set(doneDates.map { cal.mondayStartOfWeek(containing: $0) })
        var streak = 0
        var weekStart = cal.mondayStartOfWeek(containing: Date())
        // If no session this week, start from last week
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

    private var totalReflections: Int {
        store.notebook.reflections.count
    }

    private var reflectionsForPeriod: [Reflection] {
        store.notebook.reflections.filter { r in
            let d = cal.startOfDay(for: r.date)
            return d >= periodStart && d <= periodEnd
        }
    }

    private var workedSnippets: [String] {
        reflectionsForPeriod
            .map { $0.workedText.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var stuckSnippets: [String] {
        reflectionsForPeriod
            .map { $0.stuckText.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var nextPlannedSession: PlannedSession? {
        store.notebook.sessions
            .filter { $0.status == .planned }
            .sorted { $0.date < $1.date }
            .first
    }

    private var nextDaySessions: [PlannedSession] {
        guard let next = nextPlannedSession else { return [] }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: next.date)
        return store.notebook.sessions
            .filter { $0.status == .planned && cal.startOfDay(for: $0.date) == dayStart }
            .sorted { $0.date < $1.date }
    }

    private var goalsForPeriod: [TrainingGoal] {
        store.notebook.goals
    }

    // MARK: - Trend data

    private var trendData: [DayTrendPoint] {
        var points: [DayTrendPoint] = []
        for offset in 0..<daysInPeriod {
            guard let day = cal.date(byAdding: .day, value: offset, to: periodStart) else { continue }
            let dayStart = cal.startOfDay(for: day)
            let count = sessionsForPeriod.filter { cal.startOfDay(for: $0.date) == dayStart && $0.status == .done }.count
            let dayReflections = reflectionsForPeriod.filter { cal.startOfDay(for: $0.date) == dayStart }
            let mood = dayReflections.compactMap { $0.mood }.first
            points.append(DayTrendPoint(date: day, sessionCount: count, mood: mood))
        }
        return points
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Name chip
                HStack {
                    Text(store.profile?.firstName ?? "there")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    Spacer()
                }
                .padding(.top, 8)

                // ── Period tabs ──
                HomePeriodTabBar(selected: $selectedPeriod)

                // Section title
                Text("My Weekly Insights")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.label)

                // Subtitle + 2-card grid
                Text("I've been intentionally training for")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(AppColors.label)

                HStack(spacing: 12) {
                    // Training sessions card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(completedForPeriod)")
                                .font(.system(size: 32, weight: .medium, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 18, design: .rounded))
                                .foregroundColor(AppColors.coral)
                        }
                        Text(completedForPeriod == 1 ? "SESSION COMPLETED" : "SESSIONS COMPLETED")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .tracking(0.5)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .cardBackground()

                    // Total reflections card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(totalReflections)")
                                .font(.system(size: 32, weight: .medium, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Image(systemName: "text.bubble.fill")
                                .font(.system(size: 18, design: .rounded))
                                .foregroundColor(AppColors.mint)
                        }
                        Text("TOTAL REFLECTIONS")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .tracking(0.5)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .cardBackground()
                }

                // ── Training Streak (Headspace-style) ──
                VStack(alignment: .leading, spacing: 12) {
                    Text("Training streak")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)

                    HStack(spacing: 12) {
                        Image(systemName: "figure.martial.arts")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.indigo)

                        Text(trainingStreak == 1 ? "1 week" : "\(trainingStreak) weeks")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.label)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .cardBackground()

                // ── Next Session ──
                HomeNextSessionSection(store: store, sessions: nextDaySessions, onOpenGoalTasks: onOpenGoalTasks, onReflect: onReflect, onPlanTraining: onPlanTraining)

                // ── Working On ──
                HomeWorkingOnSection(store: store, goals: goalsForPeriod, onAddGoal: onAddGoal)

                // ── What's Working ──
                HomeSnippetSection(title: "WHAT'S WORKING", icon: "sparkles", snippets: workedSnippets, emptyText: "No wins logged yet.")

                // ── Where I Got Stuck ──
                HomeSnippetSection(title: "WHERE I GOT STUCK", icon: "exclamationmark.circle", snippets: stuckSnippets, emptyText: "Nothing flagged yet.")

            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
        .background(AppColors.groupedBackground.edgesIgnoringSafeArea(.all))
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
                .font(.system(size: 16, design: .rounded))
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
                            .font(.system(size: 15, design: .rounded))
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

struct PlanListView: View {
    @ObservedObject var store: NotebookStore
    var onAdd: () -> Void
    var onReflect: (String) -> Void

    @State private var expandedSessionId: String?
    @State private var showPast = false
    @State private var editingSession: PlannedSession?
    @State private var actionSheetSessionId: String?
    @State private var showDeleteConfirm = false
    @State private var sessionToDelete: PlannedSession?

    private var cal: Calendar { Calendar.current }

    private var weekStart: Date { cal.mondayStartOfWeek(containing: Date()) }
    private var weekEnd: Date {
        let endOfThisWeek = cal.date(byAdding: .day, value: 6, to: weekStart)!
        let today = cal.startOfDay(for: Date())
        // If less than 2 days remain in the Mon-Sun week, extend to include next week
        let daysLeft = cal.dateComponents([.day], from: today, to: endOfThisWeek).day ?? 0
        if daysLeft < 2 {
            return cal.date(byAdding: .day, value: 13, to: weekStart)!
        }
        return endOfThisWeek
    }
    private var nextWeekStart: Date { cal.date(byAdding: .day, value: 1, to: weekEnd)! }

    private var allSorted: [PlannedSession] {
        store.notebook.sessions.sorted { $0.date < $1.date }
    }

    private var thisWeekSessions: [PlannedSession] {
        allSorted.filter { s in
            let d = cal.startOfDay(for: s.date)
            return d >= weekStart && d <= weekEnd
        }
    }

    private var upcomingSessions: [PlannedSession] {
        allSorted.filter { s in
            cal.startOfDay(for: s.date) >= nextWeekStart
        }
    }

    private var pastSessions: [PlannedSession] {
        allSorted.filter { s in
            cal.startOfDay(for: s.date) < weekStart
        }.reversed()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Plan")
                    .font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.indigo)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // This Week
                    Text("THIS WEEK (\(thisWeekSessions.count))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.label)
                        .padding(.top, 4)

                    if thisWeekSessions.isEmpty {
                        EmptyDashedState(title: "No sessions this week.", subtitle: "Tap + to plan your training.")
                    } else {
                        ForEach(thisWeekSessions) { session in
                            planEntryCard(session: session)
                                .zIndex(actionSheetSessionId == session.id ? 10 : 0)
                        }
                    }

                    // Upcoming
                    Text("UPCOMING (\(upcomingSessions.count))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.label)
                        .padding(.top, 8)

                    if upcomingSessions.isEmpty {
                        EmptyDashedState(title: "Nothing planned yet.", subtitle: "Tap + to schedule ahead.")
                    } else {
                        ForEach(upcomingSessions) { session in
                            planEntryCard(session: session)
                                .zIndex(actionSheetSessionId == session.id ? 10 : 0)
                        }
                    }

                    // Past (collapsible)
                    Button(action: { withAnimation { showPast.toggle() } }) {
                        HStack {
                            Text("PAST  · \(pastSessions.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.label)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(AppColors.label)
                                .rotationEffect(.degrees(showPast ? 90 : 0))
                        }
                        .padding(12)
                        .cardBackground()
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 8)

                    if showPast {
                        ForEach(pastSessions) { session in
                            planEntryCard(session: session)
                                .zIndex(actionSheetSessionId == session.id ? 10 : 0)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .sheet(item: $editingSession) { session in
            EditSessionView(store: store, session: session) {
                editingSession = nil
            }
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
                secondaryButton: .cancel {
                    sessionToDelete = nil
                }
            )
        }
    }

    @ViewBuilder
    private func planEntryCard(session: PlannedSession) -> some View {
        let goal = store.goal(id: session.goalId)
        let tasks = session.taskIds.compactMap { store.task(id: $0) }
        let reflection = store.reflection(forSessionId: session.id)
        let hasReflection = reflection != nil
        let isExpanded = expandedSessionId == session.id

        let fmt = DateFormatter()
        let _ = fmt.dateFormat = "EEE, MMM d"

        VStack(alignment: .leading, spacing: 0) {
            // Header row: chevron + date + status + ellipsis
            HStack(spacing: 10) {
                // Expand/collapse arrow
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(fmt.string(from: session.date))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.label)
                    if let goal = goal {
                        Text(goal.name)
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                }

                Spacer()

                if session.status == .planned && cal.startOfDay(for: session.date) <= cal.startOfDay(for: Date()) {
                    // Today or past + planned → show reflect button + planned pill
                    HStack(spacing: 6) {
                        sessionStatusPill(label: "Planned", color: Color(.systemGray4), textColor: .secondary, icon: nil)
                        Button(action: { onReflect(session.id) }) {
                            ReflectPencilIcon(size: 14, color: .primary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else if session.status == .planned {
                    sessionStatusPill(label: "Planned", color: Color(.systemGray4), textColor: .secondary, icon: nil)
                } else if session.status == .done && !hasReflection {
                    HStack(spacing: 6) {
                        sessionStatusPill(label: "Done", color: Color.green.opacity(0.15), textColor: .green, icon: "checkmark")
                        Button(action: { onReflect(session.id) }) {
                            ReflectPencilIcon(size: 14, color: .primary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } else if hasReflection {
                    sessionStatusPill(label: "Reflected", color: AppColors.indigo.opacity(0.12), textColor: AppColors.indigo, icon: "text.book.closed")
                }

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        actionSheetSessionId = actionSheetSessionId == session.id ? nil : session.id
                    }
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(AppColors.label)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSessionId = isExpanded ? nil : session.id
                }
            }

            // Expanded content: task pills + reflection
            if isExpanded {
                if !tasks.isEmpty {
                    WrappingHStack(items: tasks) { task in
                        Text(task.name)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(goal?.goalColor ?? AppColors.indigo)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (goal?.goalColor ?? AppColors.indigo).opacity(0.12)
                            )
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 42)
                    .padding(.bottom, 12)
                }

                if let ref = reflection {
                    VStack(alignment: .leading, spacing: 8) {
                        if let mood = ref.mood {
                            HStack(spacing: 4) {
                                Text("Mood:")
                                    .font(.caption)
                                    .foregroundColor(AppColors.label)
                                Text(mood.glyph)
                                    .font(.caption)
                            }
                        }
                        let worked = ref.workedText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !worked.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WHAT WORKED")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundColor(AppColors.label)
                                Text(worked)
                                    .font(.caption)
                            }
                        }
                        let stuck = ref.stuckText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !stuck.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WHERE I GOT STUCK")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundColor(AppColors.label)
                                Text(stuck)
                                    .font(.caption)
                            }
                        }
                        Button(action: { onReflect(session.id) }) {
                            Text("Edit reflection")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.label)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 42)
                    .padding(.bottom, 14)
                }
            }
        }
        .cardBackground()
        .overlay(
            // Left color strip indicating session state
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(sessionStatusColor(session: session, hasReflection: hasReflection))
                    .frame(width: 4)
                    .padding(.vertical, 6)
                Spacer()
            }
            .padding(.leading, 4)
        , alignment: .leading)
        .overlay(
            Group {
                if actionSheetSessionId == session.id {
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                actionSheetSessionId = nil
                            }
                            editingSession = session
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(AppColors.label)
                                Text("Edit")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(AppColors.label)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                            .padding(.horizontal, 10)

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                actionSheetSessionId = nil
                            }
                            sessionToDelete = session
                            showDeleteConfirm = true
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(AppColors.coral)
                                Text("Delete")
                                    .font(.system(size: 15, design: .rounded))
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
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
                    .frame(width: 160)
                    .padding(.top, 40)
                    .padding(.trailing, 4)
                }
            }
        , alignment: .topTrailing)
    }

    private func sessionStatusColor(session: PlannedSession, hasReflection: Bool) -> Color {
        if hasReflection { return AppColors.indigo }
        if session.status == .done { return .green }
        return Color(.systemGray4)
    }

    @ViewBuilder
    private func sessionStatusPill(label: String, color: Color, textColor: Color, icon: String?) -> some View {
        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(textColor)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color)
        .cornerRadius(6)
    }
}

// MARK: - Edit Session

struct EditSessionView: View {
    @ObservedObject var store: NotebookStore
    let session: PlannedSession
    var onDismiss: () -> Void

    @State private var selectedGoalId: String
    @State private var selectedTaskIds: Set<String>

    init(store: NotebookStore, session: PlannedSession, onDismiss: @escaping () -> Void) {
        self.store = store
        self.session = session
        self.onDismiss = onDismiss
        _selectedGoalId = State(initialValue: session.goalId)
        _selectedTaskIds = State(initialValue: Set(session.taskIds))
    }

    private var availableTasks: [TrainingTask] {
        store.tasks(forGoal: selectedGoalId)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date (read-only)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATE")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        let fmt = DateFormatter()
                        let _ = fmt.dateFormat = "EEE, MMM d"
                        Text(fmt.string(from: session.date))
                            .font(.body)
                            .foregroundColor(AppColors.label)
                    }

                    // Goal picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GOAL")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        ForEach(store.notebook.goals) { goal in
                            Button(action: {
                                if selectedGoalId != goal.id {
                                    selectedGoalId = goal.id
                                    selectedTaskIds.removeAll()
                                }
                            }) {
                                HStack {
                                    Text(goal.name)
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.label)
                                    Spacer()
                                    if selectedGoalId == goal.id {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(AppColors.label)
                                    }
                                }
                                .padding(12)
                                .background(selectedGoalId == goal.id ? Color(.systemGray5) : Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // Task picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TASKS")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        if availableTasks.isEmpty {
                            Text("No tasks for this goal.")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryLabel)
                        } else {
                            ForEach(availableTasks) { task in
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
                                    .background(selectedTaskIds.contains(task.id) ? Color(.systemGray5) : Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
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
                    store.updateSession(id: session.id, goalId: selectedGoalId, taskIds: Array(selectedTaskIds))
                    onDismiss()
                }) {
                    Text("Save").font(.system(size: 17, weight: .medium, design: .rounded))
                }
            )
        }
    }
}

// MARK: - Edit Goal

struct EditGoalView: View {
    @ObservedObject var store: NotebookStore
    let goalId: String
    var onDismiss: () -> Void

    @State private var goalName: String
    @State private var iconName: String
    @State private var colorName: String
    @State private var addingTask = false
    @State private var newTaskName = ""
    @State private var confirmDeleteTaskId: String?

    init(store: NotebookStore, goalId: String, onDismiss: @escaping () -> Void) {
        self.store = store
        self.goalId = goalId
        self.onDismiss = onDismiss
        let goal = store.goal(id: goalId)
        _goalName = State(initialValue: goal?.name ?? "")
        _iconName = State(initialValue: goal?.iconName ?? "target")
        _colorName = State(initialValue: goal?.colorName ?? "indigo")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Goal name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NAME")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        TextField("Goal name", text: $goalName)
                            .font(.body)
                            .textFieldStyle(TrainingTextFieldStyle())
                    }

                    // Icon & color
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ICON & COLOR")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        GoalIconColorPicker(iconName: $iconName, colorName: $colorName)
                    }

                    // Tasks
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TASKS")
                            .font(.system(size: 10, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.secondaryLabel)
                        let tasks = store.tasks(forGoal: goalId)
                        if tasks.isEmpty && !addingTask {
                            Text("No tasks yet.")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                        ForEach(tasks) { task in
                            HStack {
                                Text(task.name)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.label)
                                Spacer()
                                Button(action: { confirmDeleteTaskId = task.id }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundColor(AppColors.coral)
                                }
                            }
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }

                        if addingTask {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    TextField("Task name", text: $newTaskName)
                                        .font(.subheadline)
                                        .textFieldStyle(TrainingTextFieldStyle())
                                    Button(action: {
                                        if store.addTask(goalId: goalId, name: newTaskName) != nil {
                                            newTaskName = ""
                                            addingTask = false
                                        }
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.indigo)
                                    }
                                    .disabled(newTaskName.nilIfBlank == nil || newTaskName.count > 19)
                                    Button(action: {
                                        addingTask = false
                                        newTaskName = ""
                                    }) {
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(AppColors.label)
                                    }
                                }
                                if newTaskName.count > 19 {
                                    Text("Keep it under 20 letters")
                                        .font(.caption)
                                        .foregroundColor(AppColors.coral)
                                }
                            }
                        } else {
                            Button(action: { addingTask = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.caption)
                                    Text("Add task")
                                        .font(.subheadline)
                                }
                                .foregroundColor(AppColors.indigo)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.groupedBackground)
            .navigationBarTitle("Edit Goal", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { onDismiss() },
                trailing: Button(action: {
                    if goalName.nilIfBlank != nil {
                        store.updateGoal(id: goalId, name: goalName, iconName: iconName, colorName: colorName)
                    }
                    onDismiss()
                }) {
                    Text("Save").font(.system(size: 17, weight: .medium, design: .rounded))
                }
                .disabled(goalName.nilIfBlank == nil)
            )
            .alert(isPresented: Binding(
                get: { confirmDeleteTaskId != nil },
                set: { if !$0 { confirmDeleteTaskId = nil } }
            )) {
                Alert(
                    title: Text("Delete Task"),
                    message: Text("Are you sure you want to delete this task?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let taskId = confirmDeleteTaskId {
                            store.deleteTaskCascade(taskId: taskId)
                        }
                        confirmDeleteTaskId = nil
                    },
                    secondaryButton: .cancel { confirmDeleteTaskId = nil }
                )
            }
        }
    }
}

struct BottomTabsView: View {
    var active: MainTab
    var onHome: () -> Void
    var onPlan: () -> Void
    var onGoals: () -> Void
    var onNotes: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            BottomTabButton(title: "Home", systemName: "house", active: active == .home, action: onHome)
            BottomTabButton(title: "Goals", systemName: "target", active: active == .goals, action: onGoals)
            BottomTabButton(title: "Plan", systemName: "calendar", active: active == .plan, action: onPlan)
            BottomTabButton(title: "Notes", systemName: "square.and.pencil", active: active == .notes, action: onNotes)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(AppColors.background.edgesIgnoringSafeArea(.bottom))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(.systemGray4)), alignment: .top)
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
                    .font(.system(size: 20, design: .rounded))
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
                            .font(.system(size: 15, design: .rounded))
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
                                                        .font(.system(size: 14, design: .rounded))
                                                        .foregroundColor(AppColors.coral)
                                                    Text("Delete")
                                                        .font(.system(size: 15, design: .rounded))
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
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                    Text(previewSnippet)
                        .font(.system(size: 14, design: .rounded))
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
                        .font(.system(size: 24, design: .rounded))
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
                                    .font(.system(size: 24, design: .rounded))
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
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    TextField("Enter task name", text: $taskName)
                        .font(.system(size: 16, design: .rounded))
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

struct GoalListView: View {
    @ObservedObject var store: NotebookStore
    var onOpenGoal: (String) -> Void
    var onOpenProfile: () -> Void
    var onSignOut: () -> Void

    @State private var adding = false
    @State private var name = ""
    @State private var goalIconName = "target"
    @State private var goalColorName = "indigo"
    @State private var menuOpen = false
    @State private var addingTaskForGoalId: String?
    @State private var newTaskName = ""
    @State private var confirmDeleteGoalId: String?
    @State private var actionSheetGoalId: String?
    @State private var editingGoalId: String?

    var body: some View {
        ZStack(alignment: .bottom) {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Goals")
                                .font(.largeTitle)
                                .fontWeight(.medium)
                            Text("What are you working on right now?")
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                        .padding(.top, 12)

                        if store.activeGoals.isEmpty && !adding {
                            EmptyDashedState(title: "No goals yet.", subtitle: "Add one to begin.")
                        }

                        ForEach(store.activeGoals) { goal in
                            GoalExpandedCard(
                                store: store,
                                goal: goal,
                                actionSheetGoalId: $actionSheetGoalId,
                                onEdit: { editingGoalId = goal.id },
                                onDelete: { confirmDeleteGoalId = goal.id }
                            )
                        }
                    }
                    .padding(16)
                }
            }

            if menuOpen {
                Color.black.opacity(0.001)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture { menuOpen = false }
            }

            AccountMenuButton(
                menuOpen: $menuOpen,
                onOpenProfile: {
                    menuOpen = false
                    onOpenProfile()
                },
                onSignOut: {
                    menuOpen = false
                    onSignOut()
                }
            )
            .padding(.top, 6)
            .padding(.trailing, 16)
        }
        .background(AppColors.background.edgesIgnoringSafeArea(.all))
        .alert(item: Binding(
            get: { confirmDeleteGoalId.map(GoalDeleteAlertToken.init(id:)) },
            set: { confirmDeleteGoalId = $0?.id }
        )) { token in
            let goal = store.notebook.goals.first(where: { $0.id == token.id })
            let summary = store.goalCascadeSummary(goalId: token.id)
            return Alert(
                title: Text("Delete \"\(goal?.name ?? "goal")\"?"),
                message: Text("\(summary.taskCount) tasks, \(summary.sessionCount) sessions, and \(summary.reflectionCount) reflections will be deleted."),
                primaryButton: .destructive(Text("Delete")) {
                    store.deleteGoalCascade(goalId: token.id)
                },
                secondaryButton: .cancel()
            )
        }
        .sheet(item: Binding(
            get: { editingGoalId.map(GoalEditToken.init(id:)) },
            set: { editingGoalId = $0?.id }
        )) { token in
            EditGoalView(store: store, goalId: token.id) {
                editingGoalId = nil
            }
        }
        .sheet(item: Binding(
            get: { addingTaskForGoalId.map(GoalEditToken.init(id:)) },
            set: { addingTaskForGoalId = $0?.id }
        )) { token in
            AddTaskSheet(store: store, goalId: token.id, onDone: {
                addingTaskForGoalId = nil
            })
        }

            // Floating add button
                Button(action: { adding = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(AppColors.indigo)
                        .clipShape(Circle())
                        .shadow(color: AppColors.indigo.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 24)
        }
        .sheet(isPresented: $adding) {
            AddGoalSheet(store: store, onDone: { adding = false })
        }
    }
}

struct AccountMenuButton: View {
    @Binding var menuOpen: Bool
    var onOpenProfile: () -> Void
    var onSignOut: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button(action: { menuOpen.toggle() }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .frame(width: 32, height: 32)
            }
            .accessibility(label: Text("Account menu"))

            if menuOpen {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onOpenProfile) {
                        menuRow(systemName: "person", title: "Profile")
                    }
                    Divider()
                    Button(action: onSignOut) {
                        menuRow(systemName: "rectangle.portrait.and.arrow.right", title: "Sign out")
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 160)
                .background(AppColors.background)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.indigo.opacity(0.3), lineWidth: 1))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 4)
            }
        }
    }

    private func menuRow(systemName: String, title: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .frame(width: 18)
            Text(title)
                .font(.subheadline)
            Spacer()
        }
        .foregroundColor(AppColors.label)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - Goal Expanded Card

struct GoalExpandedCard: View {
    @ObservedObject var store: NotebookStore
    let goal: TrainingGoal
    @Binding var actionSheetGoalId: String?
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        let tasks = store.tasks(forGoal: goal.id)

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                // Header row with icon + name
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        goal.goalColor.opacity(0.15),
                                        goal.goalColor.opacity(0.08)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        GoalIconImage(name: goal.iconName, color: goal.goalColor, size: 22)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.name)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.label)
                        let count = tasks.count
                        Text("\(count) \(count == 1 ? "task" : "tasks")")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                    }

                    Spacer()
                }

                // Tasks
                if !tasks.isEmpty {
                    WrappingHStack(items: tasks) { task in
                        Text(task.name)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(goal.goalColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(goal.goalColor.opacity(0.12))
                            .cornerRadius(10)
                    }
                } else {
                    Text("No tasks yet")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: goal.goalColor.opacity(0.15), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(goal.goalColor.opacity(0.2), lineWidth: 1)
            )

            // Ellipsis menu button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    actionSheetGoalId = actionSheetGoalId == goal.id ? nil : goal.id
                }
            }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(AppColors.secondaryLabel)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .offset(x: -4, y: 4)

            // Dropdown menu
            if actionSheetGoalId == goal.id {
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) { actionSheetGoalId = nil }
                        onEdit()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Text("Edit")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Divider().padding(.horizontal, 10)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) { actionSheetGoalId = nil }
                        onDelete()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(AppColors.coral)
                            Text("Delete")
                                .font(.system(size: 15, design: .rounded))
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
                .offset(x: -8, y: 44)
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity)
        .zIndex(actionSheetGoalId == goal.id ? 10 : 0)
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

    private let totalSteps = 3
    private let calendar = Calendar.current

    @State private var step = 1
    @State private var weekAnchor: Date = {
        Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }()
    @State private var goalId: String?
    @State private var selectedDays: Set<Date> = []
    @State private var tasksByDay: [Date: [String]] = [:]
    @State private var pendingProposals: [ProposedSession]?
    @State private var conflicts: [DuplicatePlanConflict] = []
    @State private var didApplyInitial = false

    private var weekStart: Date {
        calendar.mondayStartOfWeek(containing: weekAnchor)
    }

    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekEnd: Date {
        weekDays.last ?? weekStart
    }

    private var focusGoal: TrainingGoal? {
        goalId.flatMap { store.goal(id: $0) }
    }

    private var goalTasks: [TrainingTask] {
        goalId.map { store.tasks(forGoal: $0) } ?? []
    }

    private var progressFraction: CGFloat {
        CGFloat(step) / CGFloat(totalSteps)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress bar
            PlanStepHeader(
                step: step,
                totalSteps: totalSteps,
                progress: progressFraction,
                onBack: {
                    if step <= 1 { onCancel() }
                    else { withAnimation(.easeOut(duration: 0.2)) { step -= 1 } }
                },
                onClose: onCancel
            )

            // Step content
            Group {
                if step == 1 {
                    PlanStepFocus(
                        goals: store.activeGoals,
                        goalId: goalId,
                        onPickGoal: { goalId = $0 },
                        weekStart: weekStart,
                        weekEnd: weekEnd,
                        onShiftWeek: shiftWeek,
                        canAdvance: goalId != nil,
                        onContinue: { withAnimation(.easeOut(duration: 0.2)) { step = 2 } }
                    )
                } else if step == 2 {
                    PlanStepDays(
                        weekDays: weekDays,
                        selectedDays: selectedDays,
                        onToggleDay: toggleDay,
                        focusName: focusGoal?.name ?? "",
                        canAdvance: !selectedDays.isEmpty,
                        onContinue: { withAnimation(.easeOut(duration: 0.2)) { step = 3 } }
                    )
                } else {
                    PlanStepTasks(
                        selectedDays: Array(selectedDays).sorted(),
                        tasksByDay: tasksByDay,
                        goalTasks: goalTasks,
                        onToggleTask: toggleTaskForDay,
                        onApplyToAll: applyTasksToAllDays,
                        totalDays: selectedDays.count,
                        focusName: focusGoal?.name ?? "",
                        onSave: handleSave
                    )
                }
            }
        }
        .alert(item: Binding(
            get: { pendingProposals.map { _ in DuplicateAlertToken(id: "duplicate") } },
            set: { if $0 == nil { pendingProposals = nil } }
        )) { _ in
            let proposalsToCreate = pendingProposals ?? []
            let message = conflictMessage()
            return Alert(
                title: Text("Some days already have planned sessions"),
                message: Text(message),
                primaryButton: .destructive(Text("Yes, create")) {
                    guard !proposalsToCreate.isEmpty else { return }
                    let created = store.planSessions(proposalsToCreate, overrideConflicts: true)
                    pendingProposals = nil
                    conflicts = []
                    onSaved(created)
                },
                secondaryButton: .cancel {
                    pendingProposals = nil
                    conflicts = []
                }
            )
        }
        .onAppear {
            if !didApplyInitial {
                didApplyInitial = true
                if let gId = initialGoalId {
                    goalId = gId
                    weekAnchor = Date() // current week when pre-selecting
                }
            }
        }
    }

    // MARK: - Actions

    private func shiftWeek(_ delta: Int) {
        weekAnchor = calendar.date(byAdding: .day, value: delta * 7, to: weekAnchor) ?? weekAnchor
        selectedDays = []
        tasksByDay = [:]
    }

    private func toggleDay(_ date: Date) {
        let normalized = calendar.normalizedTrainingDay(date)
        if selectedDays.contains(normalized) {
            selectedDays.remove(normalized)
            tasksByDay.removeValue(forKey: normalized)
        } else {
            selectedDays.insert(normalized)
        }
    }

    private func toggleTaskForDay(_ date: Date, _ taskId: String) {
        let normalized = calendar.normalizedTrainingDay(date)
        var current = tasksByDay[normalized] ?? []
        if current.contains(taskId) {
            current.removeAll { $0 == taskId }
        } else {
            current.append(taskId)
        }
        tasksByDay[normalized] = current
    }

    private func applyTasksToAllDays(from sourceDate: Date) {
        let source = tasksByDay[calendar.normalizedTrainingDay(sourceDate)] ?? []
        for day in selectedDays {
            tasksByDay[day] = source
        }
    }

    private func handleSave() {
        guard let gId = goalId, !selectedDays.isEmpty else { return }
        let proposals = store.proposeBatchSessions(
            goalId: gId,
            dayDates: Array(selectedDays).sorted(),
            tasksByDay: tasksByDay
        )
        let found = store.duplicateConflicts(for: proposals)
        if found.isEmpty {
            onSaved(store.planSessions(proposals, overrideConflicts: false))
        } else {
            pendingProposals = proposals
            conflicts = found
        }
    }

    private func conflictMessage() -> String {
        let lines = conflicts.map { conflict -> String in
            let tasks = conflict.sharedTaskNames.isEmpty ? "this goal" : conflict.sharedTaskNames.joined(separator: ", ")
            return "\(conflict.goal.name) · \(conflict.date.trainingDayString) already covers \(tasks)."
        }
        return (lines + ["Existing entries on those days will be replaced. Reflections tied to them will move to the new entries."]).joined(separator: "\n\n")
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

    @State private var step: Int = 1
    @State private var selectedSessionId: String?
    @State private var mood: Mood?
    @State private var worked = ""
    @State private var stuck = ""

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
                    ReflectMoodStep(mood: $mood, onContinue: { if mood != nil { step = 3 } })
                } else if step == 3 {
                    ReflectNotesStep(worked: $worked, stuck: $stuck, onFinish: saveReflection)
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
        .onAppear(perform: resetIfNeeded)
        .id(resetToken)
    }

    private var selectedSession: PlannedSession? {
        guard let selectedSessionId = selectedSessionId else { return nil }
        return store.notebook.sessions.first { $0.id == selectedSessionId }
    }

    private func resetIfNeeded() {
        selectedSessionId = initialSessionId
        step = initialSessionId == nil ? 1 : 2
        mood = nil
        worked = ""
        stuck = ""
    }

    private func goBack() {
        if step <= 1 || (step == 2 && initialSessionId != nil) {
            onClose()
        } else {
            step -= 1
        }
    }

    private func saveReflection() {
        guard let sessionId = selectedSessionId,
              mood != nil,
              (worked.nilIfBlank != nil || stuck.nilIfBlank != nil) else { return }
        _ = store.saveReflection(sessionId: sessionId, mood: mood, workedText: worked, stuckText: stuck)
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
    @Binding var mood: Mood?
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("How did it feel?")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .fontWeight(.medium)
                    Text("One quick read on the session. You can change it any time.")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryLabel)
                }
                LazyMoodGrid(mood: $mood)
                Spacer()
            }
            .padding(16)
            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(mood == nil)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
        }
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
            .foregroundColor(mood == option ? .white : .primary)
            .background(mood == option ? AppColors.indigo : Color.white)
            .cardBackground()
        }
    }
}

struct ReflectNotesStep: View {
    @Binding var worked: String
    @Binding var stuck: String
    var onFinish: () -> Void

    private var canFinish: Bool {
        worked.nilIfBlank != nil || stuck.nilIfBlank != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What stood out?")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .fontWeight(.medium)
                        Text("A line or two for each is plenty. Skip what doesn't apply.")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    ZStack(alignment: .topLeading) {
                        TrainingTextView(text: $worked, placeholder: "A grip, a setup, a moment that clicked...")
                            .frame(height: 116)
                            .padding(.top, 8)
                        Text("What worked today")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(8)
                            .offset(x: 8, y: -10)
                    }
                    ZStack(alignment: .topLeading) {
                        TrainingTextView(text: $stuck, placeholder: "What didn't work, what felt off, what to adjust...")
                            .frame(height: 116)
                            .padding(.top, 8)
                        Text("Where I got stuck")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppColors.coral)
                            .cornerRadius(8)
                            .offset(x: 8, y: -10)
                    }
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
                .font(.system(size: 28, design: .rounded))
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

// MARK: - SVG Path Parser

private func parseSVGPath(_ d: String, in rect: CGRect, viewBox: CGRect) -> Path {
    var path = Path()
    let scaleX = rect.width / viewBox.width
    let scaleY = rect.height / viewBox.height
    let offsetX = -viewBox.minX
    let offsetY = -viewBox.minY

    func scale(_ point: CGPoint, relative: Bool = false) -> CGPoint {
        if relative {
            return CGPoint(x: point.x * scaleX, y: point.y * scaleY)
        }
        return CGPoint(x: (point.x + offsetX) * scaleX, y: (point.y + offsetY) * scaleY)
    }

    var tokens: [String] = []
    var current = ""
    var lastWasDigit = false
    for char in d {
        if char.isLetter {
            if !current.isEmpty { tokens.append(current); current = "" }
            tokens.append(String(char))
            lastWasDigit = false
        } else if char == "-" {
            if lastWasDigit && !current.isEmpty { tokens.append(current); current = String(char) }
            else { current.append(char) }
            lastWasDigit = false
        } else if char == "." || char.isNumber {
            current.append(char)
            lastWasDigit = true
        } else if char == " " || char == "," {
            if !current.isEmpty { tokens.append(current); current = "" }
            lastWasDigit = false
        }
    }
    if !current.isEmpty { tokens.append(current) }

    var cp = CGPoint.zero
    var lastCP = CGPoint.zero
    var i = 0

    while i < tokens.count {
        let token = tokens[i]
        guard let cmd = token.first, token.count == 1, cmd.isLetter else { i += 1; continue }
        i += 1

        func num() -> Double? {
            guard i < tokens.count, let v = Double(tokens[i]) else { return nil }
            i += 1; return v
        }
        func pt(_ rel: Bool) -> CGPoint? {
            guard let x = num(), let y = num() else { return nil }
            return rel ? CGPoint(x: cp.x + x, y: cp.y + y) : CGPoint(x: x, y: y)
        }
        func hasMore() -> Bool { i < tokens.count && tokens[i].first?.isLetter == false }

        switch cmd {
        case "M":
            if let p = pt(false) { path.move(to: scale(p)); cp = p; lastCP = p
                while hasMore() { if let lp = pt(false) { path.addLine(to: scale(lp)); cp = lp; lastCP = lp } else { break } }
            }
        case "m":
            if let p = pt(true) { path.move(to: scale(p)); cp = p; lastCP = p
                while hasMore() { if let lp = pt(true) { path.addLine(to: scale(lp)); cp = lp; lastCP = lp } else { break } }
            }
        case "L":
            while hasMore() { if let p = pt(false) { path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "l":
            while hasMore() { if let p = pt(true) { path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "H":
            while hasMore() { if let x = num() { let p = CGPoint(x: x, y: cp.y); path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "h":
            while hasMore() { if let dx = num() { let p = CGPoint(x: cp.x + dx, y: cp.y); path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "V":
            while hasMore() { if let y = num() { let p = CGPoint(x: cp.x, y: y); path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "v":
            while hasMore() { if let dy = num() { let p = CGPoint(x: cp.x, y: cp.y + dy); path.addLine(to: scale(p)); cp = p; lastCP = p } else { break } }
        case "C":
            while hasMore() { if let c1 = pt(false), let c2 = pt(false), let e = pt(false) { path.addCurve(to: scale(e), control1: scale(c1), control2: scale(c2)); lastCP = c2; cp = e } else { break } }
        case "c":
            while hasMore() { if let c1 = pt(true), let c2 = pt(true), let e = pt(true) { path.addCurve(to: scale(e), control1: scale(c1), control2: scale(c2)); lastCP = c2; cp = e } else { break } }
        case "S":
            while hasMore() { let r = CGPoint(x: 2*cp.x - lastCP.x, y: 2*cp.y - lastCP.y)
                if let c2 = pt(false), let e = pt(false) { path.addCurve(to: scale(e), control1: scale(r), control2: scale(c2)); lastCP = c2; cp = e } else { break } }
        case "s":
            while hasMore() { let r = CGPoint(x: 2*cp.x - lastCP.x, y: 2*cp.y - lastCP.y)
                if let c2 = pt(true), let e = pt(true) { path.addCurve(to: scale(e), control1: scale(r), control2: scale(c2)); lastCP = c2; cp = e } else { break } }
        case "Z", "z":
            path.closeSubpath()
        default: break
        }
    }
    return path
}

// MARK: - Custom SVG Icon Shapes

struct ArmIconShape: Shape {
    private let pathData = "m70.012 11.109c0.38672-0.78125 1.2383-1.2188 2.0977-1.0859l15.949 2.5 0.17578 0.035156c0.86719 0.21875 1.4922 0.98828 1.5117 1.8984 0.16797 7.5117 0.31641 18.656 0.22656 28.934-0.089844 10.184-0.41797 19.773-1.2578 24-0.86328 4.3281-3.0742 8.8945-5.3945 12.762-2.332 3.8945-4.8633 7.2344-6.5156 9.1523-0.50781 0.58984-1.3164 0.83203-2.0664 0.61719l-13.953-4c-0.03125-0.007813-0.066406-0.019531-0.097656-0.03125-15.156-5.1836-26.875-16.148-36.418-28.105l-11.465 5.0469c-0.61719 0.26953-1.332 0.21094-1.8984-0.15625-0.56641-0.37109-0.90625-1-0.90625-1.6758v-36.5c0-1.1055 0.89453-2 2-2h4.8203c6.3789 0 12.496 2.5391 17 7.0586l29.648 29.746c2.168-3.4531 4.75-7.5781 6.7852-11.746 1.2305-2.5234 2.2266-4.9961 2.8008-7.2734 0.51562-2.0625 0.65625-3.8477 0.39453-5.3203l-8.5859-9.0938c-0.70703-0.75-0.72656-1.9219-0.039062-2.6992l1.3164-1.4844-0.28125-1.2539c-0.097656-0.44922-0.039063-0.91406 0.16406-1.3242zm0.97266 7.0078c0.25 0.089843 0.47656 0.23047 0.67578 0.41016l1.0977 1.0078 0.77344-1.4336 0.078125-0.13672c0.44141-0.67969 1.25-1.0312 2.0547-0.87891l4.9844 0.94922c0.67187 0.12891 1.2305 0.58984 1.4844 1.2266 0.25 0.63672 0.16016 1.3594-0.23828 1.9102l-3.9883 5.5c-0.33594 0.46484-0.85156 0.76172-1.4219 0.81641-0.56641 0.058594-1.1328-0.12891-1.5508-0.51562l-4.4805-4.1211-0.64453 0.72266-0.78125 0.88281 7.7148 8.168 0.085937 0.097656c0.19141 0.23047 0.32812 0.50391 0.40234 0.79297 0.60938 2.4414 0.36328 5.1172-0.29688 7.7461-0.66406 2.6445-1.7852 5.3906-3.0859 8.0547-2.2891 4.6914-5.2461 9.3359-7.4805 12.898l4.3594 4.3711c0.77734 0.78516 0.77734 2.0508-0.007812 2.832-0.78125 0.77734-2.0469 0.77734-2.8242-0.007813l-36.91-37.027c-3.75-3.7656-8.8477-5.8828-14.164-5.8828h-2.8203v31.434l7.3672-3.2422c-1.1484-0.76562-2.4922-1.1914-3.8828-1.1914-1.1055 0-2-0.89453-2-2s0.89453-2 2-2c3.4648 0 6.6797 1.6562 8.7734 4.3477 9.5469 12.262 21 23.211 35.684 28.246l12.645 3.6211c1.4766-1.8281 3.457-4.5352 5.3047-7.6172 2.2266-3.7148 4.168-7.8164 4.8984-11.488 0.75391-3.7734 1.0898-12.934 1.1836-23.254 0.085938-9.4844-0.039062-19.73-0.19141-27.141l-12.844-2.0117zm4.8086 4.2109 0.19141 0.17578 0.82031-1.1289-0.44922-0.085938z"
    func path(in rect: CGRect) -> Path {
        parseSVGPath(pathData, in: rect, viewBox: CGRect(x: -5, y: -10, width: 110, height: 135))
    }
}

struct LegIconShape: Shape {
    private let pathData = "m86 18c0-2.2148-1.7891-4-3.9805-4h-43.746c-5.8281 0-11.105 3.4727-13.426 8.8477-0.46094 1.0742-0.79297 2.1992-0.99219 3.3516l-9.8242 57.461c-0.21094 1.2305 0.73438 2.3398 1.957 2.3398h9.207c0.61719 0 1.1953-0.28516 1.5742-0.78125l9.0547-11.828c2.1445-2.8008 3.5117-6.1172 3.9609-9.6172l1.5625-12.117c0.65234-5.0352 5.7617-8.207 10.559-6.5234l13.031 4.5859c0.25781 0.089844 0.52344 0.15234 0.79688 0.1875l11.02 1.4531h5.2656c2.1914 0 3.9805-1.7852 3.9805-4zm-44.359 1.7578c0.41406-1.0273 1.5781-1.5273 2.6016-1.1133 1.0273 0.41016 1.5273 1.5742 1.1133 2.5977-1.1523 2.8828-5.1875 9.0586-12.594 12.105-1.0195 0.42188-2.1914-0.066406-2.6133-1.0859-0.41797-1.0195 0.070312-2.1914 1.0898-2.6094 6.1953-2.5508 9.5586-7.7773 10.402-9.8945zm48.359 27.602c0 4.4141-3.5664 8-7.9805 8h-5.3945c-0.085938 0-0.17188-0.003906-0.26172-0.015625l-11.152-1.4727c-0.54688-0.070313-1.082-0.19922-1.6016-0.38281l-13.031-4.582c-2.3789-0.83594-4.9375 0.73438-5.2617 3.2617l-1.5625 12.117c-0.54297 4.1953-2.1797 8.1758-4.75 11.535l-9.0586 11.832c-1.1328 1.4805-2.8867 2.3477-4.75 2.3477h-9.207c-3.7188 0-6.5273-3.3555-5.9023-7.0156l9.8281-57.461c0.25-1.4648 0.67578-2.8945 1.2617-4.2578 2.9492-6.8359 9.6641-11.266 17.098-11.266h43.746c4.4141 0 7.9805 3.5898 7.9805 8z"
    func path(in rect: CGRect) -> Path {
        parseSVGPath(pathData, in: rect, viewBox: CGRect(x: -5, y: -10, width: 110, height: 135))
    }
}

struct ToeIconShape: Shape {
    private let pathData = "m69 36h-1v0.5l0.011719 0.10156c0.042969 0.22656 0.24609 0.39844 0.48828 0.39844 0.27734 0 0.5-0.22266 0.5-0.5zm-24.082 2.3203v-19.227c0-2.7891-2.2969-5.0938-5.1875-5.0938s-5.1914 2.3047-5.1914 5.0938v21.227c0 1.1055-0.89453 2-2 2-1.1016 0-1.9961-0.89453-2-2v-14.133c0-4.4688-3.6758-8.1328-8.2695-8.1328s-8.2695 3.6641-8.2695 8.1328v35.34c0 1.9102 0.27344 3.8086 0.8125 5.6406l5.5352 18.832h61.496l3.4727-12.945c0.45312-1.6875 0.68359-3.4336 0.68359-5.1836v-22.871l-0.003906 0.20703c-0.10938 2.1133-1.8555 3.793-3.9961 3.793-2.2109 0-4-1.7891-4-4v-2c0-1.1055 0.89453-2 2-2h4c1.1055 0 2 0.89453 2 2v-0.59766c0-2.2305-1.8398-4.082-4.1602-4.082-2.2539 0-4.0508 1.7383-4.1602 3.8711l-0.003907 0.21094v8.1055c0 1.1016-0.89453 2-2 2s-2-0.89844-2-2v-17.227c0-2.7891-2.2969-5.0938-5.1914-5.0938-2.8906 0-5.1875 2.3047-5.1875 5.0938v9.1211c0 1.1016-0.89453 2-2 2-1.1055-0.003906-2-0.89844-2-2v-17.23c0-2.7852-2.2969-5.0898-5.1875-5.0898-2.8008 0-5.0469 2.1602-5.1836 4.832l-0.007812 0.25781v13.148c0 1.1055-0.89453 2-2 2-1.1016 0-2-0.89453-2-2zm-19.918-11.984c-0.875-0.32813-1.5586-0.48047-2.2422-0.49609-0.72656-0.019532-1.5742 0.10938-2.7578 0.52344v2.1367c0 1.3789 1.1211 2.5 2.5 2.5s2.5-1.1211 2.5-2.5zm29.5 0.66406h-1v0.5l0.011719 0.10156c0.042969 0.22656 0.24609 0.39844 0.48828 0.39844 0.27734 0 0.5-0.22266 0.5-0.5zm-14.5-5h-1v0.5l0.011719 0.10156c0.042969 0.22656 0.24609 0.39844 0.48828 0.39844 0.27734 0 0.5-0.22266 0.5-0.5zm32.992 14.73c-0.11719 2.3789-2.0859 4.2695-4.4922 4.2695-2.4844 0-4.5-2.0156-4.5-4.5v-2.5c0-1.1055 0.89453-2 2-2h5c1.1055 0 2 0.89453 2 2v2.5zm-43.992-8.2305c0 3.5898-2.9102 6.5-6.5 6.5s-6.5-2.9102-6.5-6.5v-3.5c0-0.80078 0.48047-1.5273 1.2148-1.8398 2.1172-0.90234 3.8867-1.3672 5.6484-1.3203s3.3125 0.60156 4.9531 1.332c0.71875 0.32031 1.1836 1.0391 1.1836 1.8281zm29.492-0.76953c-0.11719 2.3789-2.0859 4.2695-4.4922 4.2695-2.4844 0-4.5-2.0156-4.5-4.5v-2.5c0-1.1055 0.89453-2 2-2h5c1.1055 0 2 0.89453 2 2v2.5zm4.8047-1.9531c1.4805-1.0039 3.2695-1.5898 5.1875-1.5898 5.0508 0 9.1914 4.0469 9.1914 9.0938v2.168c1.2227-0.71875 2.6445-1.1289 4.1641-1.1289 4.4805 0 8.1602 3.5938 8.1602 8.082v25.469c0 2.1016-0.27344 4.1953-0.82031 6.2227l-3.8711 14.426c-0.23438 0.87109-1.0273 1.4805-1.9297 1.4805h-64.527c-0.88672 0-1.668-0.58594-1.918-1.4336l-5.9609-20.27c-0.64453-2.1992-0.97266-4.4805-0.97266-6.7695v-35.34c0-6.7266 5.5195-12.133 12.27-12.133 3.2617 0 6.2344 1.2617 8.4375 3.3242 0.80859-4.2188 4.5586-7.3789 9.0234-7.3789 4.5898 0 8.4258 3.3438 9.0859 7.7383 1.5-1.043 3.3281-1.6562 5.293-1.6562 5.0469 0 9.1875 4.043 9.1875 9.0898zm-19.305-3.0469c-0.11719 2.3789-2.0859 4.2695-4.4922 4.2695-2.4844 0-4.5-2.0156-4.5-4.5v-2.5c0-1.1055 0.89453-2 2-2h5c1.1055 0 2 0.89453 2 2v2.5z"
    func path(in rect: CGRect) -> Path {
        parseSVGPath(pathData, in: rect, viewBox: CGRect(x: -5, y: -10, width: 110, height: 135))
    }
}

// MARK: - Custom Pencil Icon (from SVG)

struct ReflectPencilShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let sx = w / 100
        let sy = h / 100

        var path = Path()
        // Main pencil body
        path.move(to: CGPoint(x: 82.6 * sx, y: 16.9 * sy))
        path.addCurve(to: CGPoint(x: 78.2 * sx, y: 9.8 * sy),
                      control1: CGPoint(x: 82.1 * sx, y: 14.0 * sy),
                      control2: CGPoint(x: 80.6 * sx, y: 11.5 * sy))
        path.addLine(to: CGPoint(x: 73.1 * sx, y: 6.0 * sy))
        path.addCurve(to: CGPoint(x: 66.7 * sx, y: 3.9 * sy),
                      control1: CGPoint(x: 71.2 * sx, y: 4.6 * sy),
                      control2: CGPoint(x: 68.6 * sx, y: 3.9 * sy))
        path.addCurve(to: CGPoint(x: 57.8 * sx, y: 8.4 * sy),
                      control1: CGPoint(x: 63.2 * sx, y: 3.9 * sy),
                      control2: CGPoint(x: 59.9 * sx, y: 5.6 * sy))
        path.addLine(to: CGPoint(x: 14.7 * sx, y: 68.0 * sy))
        path.addCurve(to: CGPoint(x: 14.5 * sx, y: 68.3 * sy),
                      control1: CGPoint(x: 14.6 * sx, y: 68.1 * sy),
                      control2: CGPoint(x: 14.6 * sx, y: 68.2 * sy))
        path.addCurve(to: CGPoint(x: 14.4 * sx, y: 68.7 * sy),
                      control1: CGPoint(x: 14.5 * sx, y: 68.4 * sy),
                      control2: CGPoint(x: 14.5 * sx, y: 68.5 * sy))
        path.addLine(to: CGPoint(x: 12.3 * sx, y: 93.5 * sy))
        path.addCurve(to: CGPoint(x: 12.9 * sx, y: 94.8 * sy),
                      control1: CGPoint(x: 12.3 * sx, y: 94.0 * sy),
                      control2: CGPoint(x: 12.5 * sx, y: 94.5 * sy))
        path.addCurve(to: CGPoint(x: 14.4 * sx, y: 95.0 * sy),
                      control1: CGPoint(x: 13.2 * sx, y: 95.0 * sy),
                      control2: CGPoint(x: 13.8 * sx, y: 95.1 * sy))
        path.addLine(to: CGPoint(x: 36.9 * sx, y: 85.0 * sy))
        path.addCurve(to: CGPoint(x: 37.5 * sx, y: 84.5 * sy),
                      control1: CGPoint(x: 37.1 * sx, y: 84.9 * sy),
                      control2: CGPoint(x: 37.4 * sx, y: 84.7 * sy))
        path.addLine(to: CGPoint(x: 37.6 * sx, y: 84.4 * sy))
        path.addLine(to: CGPoint(x: 80.7 * sx, y: 25.0 * sy))
        path.addCurve(to: CGPoint(x: 82.6 * sx, y: 16.9 * sy),
                      control1: CGPoint(x: 82.4 * sx, y: 22.7 * sy),
                      control2: CGPoint(x: 83.1 * sx, y: 19.8 * sy))
        path.closeSubpath()
        return path
    }
}

struct ReflectPencilIcon: View {
    var size: CGFloat = 20
    var color: Color = .primary

    var body: some View {
        ReflectPencilShape()
            .fill(color)
            .frame(width: size, height: size)
    }
}

struct GoalIconColorPicker: View {
    @Binding var iconName: String
    @Binding var colorName: String

    private var selectedColor: Color { GoalIconLibrary.color(for: colorName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ICON")
                .font(.system(size: 10, design: .rounded))
                .tracking(0.8)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryLabel)

            let rowCount = (GoalIconLibrary.icons.count + 4) / 5
            VStack(spacing: 8) {
                ForEach(0..<rowCount, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { col in
                            let idx = row * 5 + col
                            if idx < GoalIconLibrary.icons.count {
                                let icon = GoalIconLibrary.icons[idx]
                                Button(action: { iconName = icon }) {
                                    GoalIconImage(name: icon, color: iconName == icon ? selectedColor : Color(.systemGray3), size: 36)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                            }
                        }
                    }
                }
            }

            Text("COLOR")
                .font(.system(size: 10, design: .rounded))
                .tracking(0.8)
                .fontWeight(.medium)
                .foregroundColor(AppColors.secondaryLabel)
                .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GoalIconLibrary.colors, id: \.name) { item in
                        Button(action: { colorName = item.name }) {
                            ZStack {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 30, height: 30)
                                if colorName == item.name {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
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

// MARK: - Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(AppColors.indigo.opacity(configuration.isPressed ? 0.8 : 1))
            .cornerRadius(24)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(AppColors.indigo)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(AppColors.background.opacity(configuration.isPressed ? 0.7 : 1))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(.systemGray3), lineWidth: 1))
            .cornerRadius(24)
    }
}

struct SmallPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isEnabled ? AppColors.indigo : Color(.systemGray3))
            .cornerRadius(20)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SmallSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundColor(AppColors.secondaryLabel)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

struct TrainingTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(11)
            .background(AppColors.background)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

extension View {
    func cardBackground(stronger: Bool = false) -> some View {
        self
            .background(AppColors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }

    func dashedCircle() -> some View {
        self
            .background(Circle().fill(Color(.systemGray6)))
    }
}

extension Text {
    func fieldLabel() -> some View {
        font(.caption)
            .fontWeight(.medium)
            .foregroundColor(AppColors.label)
            .uppercaseTracking()
    }

    func uppercaseTracking() -> some View {
        tracking(0.8)
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
