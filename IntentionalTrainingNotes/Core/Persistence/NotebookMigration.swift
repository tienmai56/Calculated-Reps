import Foundation

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
