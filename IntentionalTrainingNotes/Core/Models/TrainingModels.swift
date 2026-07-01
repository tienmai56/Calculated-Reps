import Foundation
import SwiftUI

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
    var bounties: [Bounty]

    init(
        schemaVersion: Int = 4,
        accountId: String = "local",
        profile: UserProfile? = nil,
        goals: [TrainingGoal] = [],
        tasks: [TrainingTask] = [],
        sessions: [PlannedSession] = [],
        reflections: [Reflection] = [],
        notes: [Note] = [],
        bounties: [Bounty] = []
    ) {
        self.schemaVersion = schemaVersion
        self.accountId = accountId
        self.profile = profile
        self.goals = goals
        self.tasks = tasks
        self.sessions = sessions
        self.reflections = reflections
        self.notes = notes
        self.bounties = bounties
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
        case bounties
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
        bounties = try container.decodeIfPresent([Bounty].self, forKey: .bounties) ?? []
    }
}
