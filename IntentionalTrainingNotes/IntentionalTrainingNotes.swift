import AuthenticationServices
import AVFoundation
import Foundation
import Network
import Security
import Speech
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

    // Streak header gradient (Home)
    static let headerGradientTop = Color(red: 124/255, green: 112/255, blue: 214/255)
    static let headerGradientBottom = Color(red: 91/255, green: 82/255, blue: 176/255)

    // Reflection section accents: What worked / Where I got stuck / What I'll try next.
    // Keep UIColor variants so we can derive adaptive tints without iOS 14's UIColor(Color).
    static let indigoUI = UIColor(red: 63/255, green: 61/255, blue: 158/255, alpha: 1)
    static let winGreenUI = UIColor(red: 56/255, green: 178/255, blue: 144/255, alpha: 1)
    static let stuckCoralUI = UIColor(red: 235/255, green: 110/255, blue: 100/255, alpha: 1)
    static let winGreen = Color(winGreenUI)
    static let stuckCoral = Color(stuckCoralUI)
    static let nextIndigo = indigo

    /// Adaptive low-opacity tint (dark mode needs higher opacity to stay visible).
    /// Takes a UIColor to avoid the iOS 14-only `UIColor(Color)` initializer.
    static func tint(_ ui: UIColor, light: Double = 0.10, dark: Double = 0.24) -> Color {
        Color(UIColor { traits in
            ui.withAlphaComponent(CGFloat(traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
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
                        "figure.walk", "dollarsign.circle.fill", "music.note", "book.fill",
                        "wand.and.stars", "paintbrush.fill", "camera.fill", "leaf.fill",
                        "hammer.fill", "flag.fill", "shield.fill", "arrow.up.right",
                        "arrow.up.arrow.down", "sportscourt", "pencil",
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
    var notes: String
    var link: String
    var imageFileNames: [String]
    var createdAt: Date
    var updatedAt: Date

    var hasDetails: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !imageFileNames.isEmpty
    }

    init(
        id: String = "t_\(UUID().uuidString)",
        goalId: String,
        name: String,
        notes: String = "",
        link: String = "",
        imageFileNames: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.goalId = goalId
        self.name = name
        self.notes = notes
        self.link = link
        self.imageFileNames = imageFileNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, goalId, name, notes, link, imageFileNames, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        goalId = try c.decode(String.self, forKey: .goalId)
        name = try c.decode(String.self, forKey: .name)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        link = try c.decodeIfPresent(String.self, forKey: .link) ?? ""
        imageFileNames = try c.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
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
    var tryNextText: String
    var mood: Mood?
    var isFavorite: Bool
    var link: String
    var imageFileNames: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = "r_\(UUID().uuidString)",
        sessionId: String,
        date: Date,
        workedText: String,
        stuckText: String,
        tryNextText: String = "",
        mood: Mood?,
        isFavorite: Bool = false,
        link: String = "",
        imageFileNames: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.date = Calendar.current.normalizedTrainingDay(date)
        self.workedText = workedText
        self.stuckText = stuckText
        self.tryNextText = tryNextText
        self.mood = mood
        self.isFavorite = isFavorite
        self.link = link
        self.imageFileNames = imageFileNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, sessionId, date, workedText, stuckText, tryNextText, mood, isFavorite, link, imageFileNames, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        sessionId = try c.decode(String.self, forKey: .sessionId)
        date = Calendar.current.normalizedTrainingDay(try c.decode(Date.self, forKey: .date))
        workedText = try c.decode(String.self, forKey: .workedText)
        stuckText = try c.decode(String.self, forKey: .stuckText)
        tryNextText = try c.decodeIfPresent(String.self, forKey: .tryNextText) ?? ""
        mood = try c.decodeIfPresent(Mood.self, forKey: .mood)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        link = try c.decodeIfPresent(String.self, forKey: .link) ?? ""
        imageFileNames = try c.decodeIfPresent([String].self, forKey: .imageFileNames) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
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
        // Local-only mode skips the profile gate and goes straight into the app.
        self.route = .ready
        #if DEBUG
        store.seedDemoDataIfEmpty()
        #endif
    }

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

#if DEBUG
    /// TEMPORARY demo data for testing. Re-seeds when `seedVersion` changes. Remove before shipping.
    func seedDemoDataIfEmpty() {
        let seedKey = "matmind.debugSeedVersion"
        let seedVersion = "v2-2goals-3sessions-photos"
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

        // 3 planned sessions: today + two past days (past days are immediately reflectable).
        func sess(_ goal: TrainingGoal, _ offset: Int, _ taskIds: [String]) -> PlannedSession {
            PlannedSession(goalId: goal.id, date: day(offset), taskIds: taskIds, status: .planned, createdAt: day(offset))
        }
        let s1 = sess(g1, 0, [chaseHip.id, sepKnee.id])
        let s2 = sess(g2, -1, [insideHeel.id])
        let s3 = sess(g1, -3, [chaseHip.id])

        mutate {
            notebook.goals = [g1, g2]
            notebook.tasks = [chaseHip, sepKnee, insideHeel, ashiEntry]
            notebook.sessions = [s1, s2, s3]
            notebook.reflections = []
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
                        .font(.system(size: 14, design: .rounded))
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
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }

            Button(action: { sheet = .settings }) {
                HStack(spacing: 6) {
                    Text("🏆 \(bountyCount) bounty collected")
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

    // MARK: - Bounty (visual stub)

    private var bountyCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(AppColors.coral).frame(width: 5).padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text("🎯 Bounty Unlocked")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Text("You've put in the reps — set a challenge.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
            }
            Spacer()
            Button(action: { sheet = .settings }) {
                Text("Set")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(AppColors.coral))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Next Session

    private var nextSessionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Next Session")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
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
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
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
                        .font(.system(size: 22, weight: .bold, design: .rounded))
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
                    .font(.system(size: 22, weight: .bold, design: .rounded))
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

            HStack {
                goalFilterControl
                Spacer()
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
    }

    private var goalFilterControl: some View {
        ZStack(alignment: .topLeading) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { goalFilterOpen.toggle() } }) {
                HStack(spacing: 4) {
                    Text(patternGoalId.flatMap { store.goal(id: $0)?.name } ?? "All")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.label)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.secondaryLabel)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(.secondarySystemBackground)))
            }
            .buttonStyle(PlainButtonStyle())

            if goalFilterOpen {
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
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
                .frame(width: 200)
                .offset(y: 44)
                .zIndex(20)
            }
        }
        .zIndex(goalFilterOpen ? 20 : 0)
    }

    private func goalFilterRow(title: String, id: String?) -> some View {
        Button(action: {
            patternGoalId = id
            withAnimation(.easeInOut(duration: 0.15)) { goalFilterOpen = false }
        }) {
            HStack {
                Text(title).font(.system(size: 15, design: .rounded)).foregroundColor(AppColors.label)
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
        HStack(spacing: 4) {
            ForEach(PatternKind.allCases, id: \.self) { kind in
                Button(action: { patternKind = kind }) {
                    Text(kind.rawValue)
                        .font(.system(size: 15, weight: patternKind == kind ? .semibold : .regular, design: .rounded))
                        .foregroundColor(patternKind == kind ? AppColors.indigo : AppColors.secondaryLabel)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(patternKind == kind ? AppColors.indigo.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
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
    private var bountyCount: Int { max(0, completedAllTime / 3) }

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

enum HomeSheet: Identifiable {
    case settings
    case editSession(PlannedSession)
    case feedback(Reflection)
    var id: String {
        switch self {
        case .settings: return "settings"
        case .editSession(let s): return "edit-\(s.id)"
        case .feedback(let r): return "feedback-\(r.id)"
        }
    }
}

struct SettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Text("Mat Mind")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                Text("Train with intention.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
            .padding(.horizontal, 16)
            .background(AppColors.background.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Settings", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") { presentationMode.wrappedValue.dismiss() })
        }
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

    @State private var menuOpen = false

    var body: some View {
        let session = store.notebook.sessions.first { $0.id == reflection.sessionId }
        let goal = session.flatMap { store.goal(id: $0.goalId) }
        let color = goal?.goalColor ?? AppColors.indigo

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                if let mood = reflection.mood {
                    Text(mood.glyph).font(.system(size: 26))
                }
                Text(goal?.name ?? "Session")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Button(action: onShareFeedback) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 12))
                        Text("Get feedback").font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(AppColors.indigo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppColors.indigo.opacity(0.10)))
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: { store.toggleFavorite(reflectionId: reflection.id) }) {
                    Image(systemName: reflection.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(reflection.isFavorite ? AppColors.coral : AppColors.tertiaryLabel)
                }
                .buttonStyle(PlainButtonStyle())
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { menuOpen.toggle() } }) {
                    Image(systemName: "ellipsis").font(.system(size: 16)).foregroundColor(AppColors.secondaryLabel).frame(width: 22, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(menuOverlay, alignment: .topTrailing)
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
                    .font(.system(size: 15, design: .rounded))
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

    private func menuRowLabel(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, design: .rounded)).foregroundColor(color)
            Text(label).font(.system(size: 15, design: .rounded)).foregroundColor(color)
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
                    .font(.system(size: 16, design: .rounded))
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
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(Color(red: 120/255, green: 117/255, blue: 113/255))
                    Text("\(mood.glyph) \(mood.label)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 44/255, green: 42/255, blue: 41/255))
                }
            }
            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Thank you, see you on the mat.")
                    .font(.system(size: 16, design: .rounded))
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

// MARK: - Reusable Session Card (matches Mat Mind Home / Plan design)

struct SessionCardView: View {
    @ObservedObject var store: NotebookStore
    let session: PlannedSession
    var onReflect: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var showNotes = false
    @State private var menuOpen = false

    var body: some View {
        let goal = store.goal(id: session.goalId)
        let color = goal?.goalColor ?? AppColors.indigo
        let tasks = session.taskIds.compactMap { store.task(id: $0) }
        let hasNotes = tasks.contains { $0.hasDetails }
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
                WrappingHStack(items: tasks) { task in
                    Text(task.name)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.12))
                        .cornerRadius(14)
                }
            }

            if hasNotes {
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showNotes.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: showNotes ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                        Text("task notes")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(AppColors.secondaryLabel)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())

                if showNotes {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(tasks) { task in
                            taskNoteBlock(task, color: color)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.8
                )
        )
        .overlay(menuOverlay, alignment: .topTrailing)
    }

    @ViewBuilder
    private var menuOverlay: some View {
        if menuOpen {
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

    private func menuRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14, design: .rounded)).foregroundColor(color)
                Text(label).font(.system(size: 15, design: .rounded)).foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func taskNoteBlock(_ task: TrainingTask, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(task.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.label)
            }
            if let notes = task.notes.nilIfBlank {
                Text(notes)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No notes yet")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(AppColors.tertiaryLabel)
            }
            if let link = task.link.nilIfBlank {
                HStack(spacing: 4) {
                    Image(systemName: "link").font(.system(size: 11))
                    Text(link).font(.system(size: 13, design: .rounded)).lineLimit(1)
                }
                .foregroundColor(AppColors.indigo)
            }
            if !task.imageFileNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(task.imageFileNames, id: \.self) { fileName in
                            if let data = store.taskImageData(taskId: task.id, fileName: fileName), let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 220, height: 124)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
        }
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
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
                        .font(.system(size: 16, design: .rounded))
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
                EmptyDashedState(title: "Nothing planned.", subtitle: "Tap + to plan training for this day.")
            } else {
                ForEach(daySessions) { session in
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

    @State private var goalName: String
    @State private var iconName: String
    @State private var colorName: String
    @State private var addingTask = false
    @State private var newTaskName = ""
    @State private var expandedTaskIds: Set<String>
    @State private var activeAlert: EditGoalAlert?

    private var goalColor: Color { GoalIconLibrary.color(for: colorName) }

    init(store: NotebookStore, goalId: String, onDismiss: @escaping () -> Void) {
        self.store = store
        self.goalId = goalId
        self.onDismiss = onDismiss
        let goal = store.goal(id: goalId)
        _goalName = State(initialValue: goal?.name ?? "")
        _iconName = State(initialValue: goal?.iconName ?? "target")
        _colorName = State(initialValue: goal?.colorName ?? "indigo")
        let detailTasks = store.tasks(forGoal: goalId).filter { $0.hasDetails }.map { $0.id }
        _expandedTaskIds = State(initialValue: Set(detailTasks))
    }

    var body: some View {
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
                        .background(Capsule().fill(goalName.nilIfBlank == nil ? AppColors.indigo.opacity(0.4) : AppColors.indigo))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(goalName.nilIfBlank == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    previewHeader
                    appearanceSection
                    tasksSection
                    deleteGoalButton
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
                    .font(.system(size: 16, design: .rounded))
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
                    .font(.system(size: 14, design: .rounded))
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
                .font(.system(size: 16, design: .rounded))
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
    @State private var showingPhotoPicker = false

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
                TrainingTextView(text: notesBinding, placeholder: "Add a description...")
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
                        TextField("Paste link...", text: linkBinding).font(.system(size: 14, design: .rounded))
                    }
                    .padding(11)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.systemGray3), lineWidth: 1))
                }

                HStack(spacing: 10) {
                    chipButton(icon: "link", label: "Add link") { showLinkField = true }
                    chipButton(icon: "photo", label: "Photo") { showingPhotoPicker = true }
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash").font(.system(size: 16)).foregroundColor(AppColors.coral)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingPhotoPicker) {
            NoteImagePicker { data in
                store.addTaskImage(taskId: task.id, imageData: data)
            }
        }
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

private enum GoalSheet: Identifiable {
    case add
    case edit(String)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let goalId): return "edit-\(goalId)"
        }
    }
}

struct GoalListView: View {
    @ObservedObject var store: NotebookStore

    @State private var sheet: GoalSheet?
    @State private var expandedGoalIds: Set<String> = []
    @State private var confirmDeleteGoalId: String?
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
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    Spacer()
                    Button(action: { sheet = .add }) {
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
                                    expandedGoalIds = [goal.id]
                                }
                            }
                        },
                        onEdit: { sheet = .edit(goal.id) },
                        onDelete: { confirmDeleteGoalId = goal.id }
                    )
                    .zIndex(expandedGoalIds.contains(goal.id) ? 1 : 0)
                }

                if store.activeGoals.count > 1 {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                        Text("tap a goal to expand its tasks").font(.system(size: 14, design: .rounded))
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
        .alert(item: Binding(
            get: { confirmDeleteGoalId.map(GoalEditToken.init(id:)) },
            set: { confirmDeleteGoalId = $0?.id }
        )) { token in
            let goal = store.goal(id: token.id)
            let summary = store.goalCascadeSummary(goalId: token.id)
            return Alert(
                title: Text("Delete \"\(goal?.name ?? "goal")\"?"),
                message: Text("\(summary.taskCount) tasks, \(summary.sessionCount) sessions, and \(summary.reflectionCount) reflections will be deleted."),
                primaryButton: .destructive(Text("Delete")) { store.deleteGoalCascade(goalId: token.id) },
                secondaryButton: .cancel()
            )
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .add:
                AddGoalSheet(store: store, onDone: { sheet = nil })
            case .edit(let goalId):
                EditGoalView(store: store, goalId: goalId) { sheet = nil }
            }
        }
    }
}

struct GoalCard: View {
    @ObservedObject var store: NotebookStore
    let goal: TrainingGoal
    let isExpanded: Bool
    var onToggle: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var expandedTaskIds: Set<String> = []
    @State private var menuOpen = false
    @State private var addingTask = false
    @State private var newTaskName = ""

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
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.8
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 3)
        .overlay(menuOverlay, alignment: .topTrailing)
    }

    // MARK: Header

    @ViewBuilder
    private func header(tasks: [TrainingTask], color: Color, trained: Int) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay(GoalIconImage(name: goal.iconName, color: color, size: 26))

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.label)
                if isExpanded {
                    Text("\(tasks.count) \(tasks.count == 1 ? "task" : "tasks")")
                        .font(.system(size: 14, design: .rounded))
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
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(AppColors.secondaryLabel)
                Spacer()
                Text("\(trained) / \(tasks.count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 16)
            .padding(.leading, 4)

            progressBar(trained, tasks.count, color)
                .padding(.horizontal, 16)
                .padding(.leading, 4)
                .padding(.top, 8)

            Divider().padding(.horizontal, 16).padding(.top, 14)

            ForEach(tasks) { task in
                taskRow(task, color)
            }
            addTaskRow(color)
        }
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func taskRow(_ task: TrainingTask, _ color: Color) -> some View {
        let trained = trainedThisWeek(task)
        let isOpen = expandedTaskIds.contains(task.id)
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { toggleTask(task.id) } }) {
                HStack(spacing: 12) {
                    checkbox(trained, color)
                    Text(task.name)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(trained ? AppColors.label : AppColors.secondaryLabel)
                    Spacer()
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
            Divider()
        }
        .padding(.horizontal, 16)
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func taskDetail(_ task: TrainingTask, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let notes = task.notes.nilIfBlank {
                Text(notes)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No notes yet")
                    .font(.system(size: 15, design: .rounded))
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
        }
        .padding(.leading, 38)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func addTaskRow(_ color: Color) -> some View {
        Group {
            if addingTask {
                HStack(spacing: 8) {
                    TextField("Task name", text: $newTaskName, onCommit: commitTask)
                        .font(.system(size: 16, design: .rounded))
                        .textFieldStyle(TrainingTextFieldStyle())
                    Button(action: commitTask) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(color)
                    }
                    .disabled(newTaskName.nilIfBlank == nil)
                    Button(action: { addingTask = false; newTaskName = "" }) {
                        Image(systemName: "xmark.circle").foregroundColor(AppColors.secondaryLabel)
                    }
                }
                .padding(.vertical, 8)
            } else {
                Button(action: { addingTask = true }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(Color(.systemGray3), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 26, height: 26)
                            Image(systemName: "plus").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.secondaryLabel)
                        }
                        Text("Add task")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                    }
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.leading, 4)
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
            VStack(spacing: 0) {
                menuRow(icon: "pencil", label: "Edit goal", color: AppColors.label) { menuOpen = false; onEdit() }
                Divider().padding(.horizontal, 10)
                menuRow(icon: "trash", label: "Delete goal", color: AppColors.coral) { menuOpen = false; onDelete() }
            }
            .background(AppColors.background)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 4)
            .frame(width: 170)
            .padding(.top, 54)
            .padding(.trailing, 12)
        }
    }

    private func menuRow(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                Text(label).font(.system(size: 15, design: .rounded)).foregroundColor(color)
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

    private func commitTask() {
        if let t = store.addTask(goalId: goal.id, name: newTaskName) {
            newTaskName = ""
            addingTask = false
            _ = expandedTaskIds.insert(t.id)
        }
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

    private let totalSteps = 2
    private let calendar = Calendar.current

    @State private var step = 1
    @State private var displayedMonth: Date = Date()
    @State private var selectedDays: Set<Date> = []
    @State private var selectedGoalIds: Set<String> = []
    @State private var selectedTasksByDay: [Date: Set<String>] = [:]
    @State private var didApplyInitial = false

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
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    monthCalendar
                    Text(daysSelectedLabel)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(AppColors.label)
                    if !selectedDays.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goals")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.secondaryLabel)
                            WrappingHStack(items: store.activeGoals) { goal in
                                goalChip(goal)
                            }
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
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(AppColors.secondaryLabel)
                    }
                    ForEach(sortedDays, id: \.self) { day in
                        dayTaskCard(day)
                    }
                    Text("Planning creates an unchecked entry for each day. Check it off after training to reflect.")
                        .font(.system(size: 15, design: .rounded))
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
                    .font(.system(size: 14, design: .rounded))
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
                    .font(.system(size: 16, design: .rounded))
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
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(AppColors.secondaryLabel)
                }
                Spacer()
            }
            if !tasks.isEmpty {
                WrappingHStack(items: tasks) { task in
                    Text(task.name)
                        .font(.system(size: 14, design: .rounded))
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
                TextField("Paste link...", text: $link).font(.system(size: 14, design: .rounded))
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
                .font(.system(size: 22, design: .rounded))
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
        VStack(alignment: .leading, spacing: 16) {
            let columns = 6
            let rowCount = (GoalIconLibrary.icons.count + columns - 1) / columns
            VStack(spacing: 10) {
                ForEach(0..<rowCount, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<columns, id: \.self) { col in
                            let idx = row * columns + col
                            if idx < GoalIconLibrary.icons.count {
                                let icon = GoalIconLibrary.icons[idx]
                                let isSelected = iconName == icon
                                Button(action: { iconName = icon }) {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(isSelected ? selectedColor.opacity(0.16) : Color(.systemGray6))
                                        .frame(height: 52)
                                        .overlay(GoalIconImage(name: icon, color: isSelected ? selectedColor : Color(.systemGray), size: 24))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? selectedColor.opacity(0.4) : Color.clear, lineWidth: 1.5))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(maxWidth: .infinity)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(GoalIconLibrary.colors, id: \.name) { item in
                    Button(action: { colorName = item.name }) {
                        ZStack {
                            Circle().fill(item.color).frame(width: 32, height: 32)
                            if colorName == item.name {
                                Circle().stroke(item.color, lineWidth: 2.5).frame(width: 42, height: 42)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
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
