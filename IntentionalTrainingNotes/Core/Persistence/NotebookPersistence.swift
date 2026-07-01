import Foundation
import UIKit

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
