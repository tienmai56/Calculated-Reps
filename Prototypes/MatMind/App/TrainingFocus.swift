import Foundation

/// A session's optional focus outline. Stable IDs keep edits attached to the
/// right item as parents and children are added or removed.
struct TrainingFocus: Identifiable, Hashable, Codable {
    var id = UUID()
    var title = ""
    var children: [TrainingFocus] = []
    /// Reference only: private goal notes are never copied into a session or post.
    var goalID: String? = nil
    /// Completion belongs to this session, not to the linked goal.
    var isCompleted = false

    /// The compact checklist description is the first saved detail. Keep the
    /// existing outline (including IDs and deeper details) when editing it.
    var detailDescription: String {
        get { children.first?.title ?? "" }
        set {
            if children.isEmpty {
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    children.append(TrainingFocus(title: newValue))
                }
            } else if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      children.count == 1, children[0].children.isEmpty {
                children.removeFirst()
            } else {
                children[0].title = newValue
            }
        }
    }

    func linkedGoal(in goals: [MatGoal]) -> MatGoal? {
        if let goalID { return goals.first { $0.id == goalID } }
        // Older sessions stored only the name. Avoid guessing between duplicate names.
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = goals.filter {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(name) == .orderedSame
        }
        return matches.count == 1 ? matches[0] : nil
    }
}

extension TrainingFocus {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        children = try values.decode([TrainingFocus].self, forKey: .children)
        goalID = try values.decodeIfPresent(String.self, forKey: .goalID)
        // Outlines saved before checklists start unchecked.
        isCompleted = try values.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }
}

enum TrainingFocusTree {
    struct Row: Identifiable {
        var node: TrainingFocus
        var depth: Int
        var id: UUID { node.id }
    }

    static func rows(_ items: [TrainingFocus], depth: Int = 0) -> [Row] {
        items.flatMap { [Row(node: $0, depth: depth)] + rows($0.children, depth: depth + 1) }
    }

    static func find(_ id: UUID, in items: [TrainingFocus]) -> TrainingFocus? {
        for item in items {
            if item.id == id { return item }
            if let found = find(id, in: item.children) { return found }
        }
        return nil
    }

    @discardableResult
    static func update(_ id: UUID, in items: inout [TrainingFocus], change: (inout TrainingFocus) -> Void) -> Bool {
        for i in items.indices {
            if items[i].id == id {
                change(&items[i])
                return true
            }
            if update(id, in: &items[i].children, change: change) { return true }
        }
        return false
    }

    @discardableResult
    static func remove(_ id: UUID, from items: inout [TrainingFocus]) -> Bool {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: index)
            return true
        }
        for i in items.indices {
            if remove(id, from: &items[i].children) { return true }
        }
        return false
    }

    static func isValid(_ items: [TrainingFocus]) -> Bool {
        items.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isValid($0.children) }
    }

    static func normalized(_ items: [TrainingFocus]) -> [TrainingFocus] {
        items.map { item in
            var result = item
            result.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            result.children = normalized(item.children)
            return result
        }
    }

    /// An untouched optional focus card is not part of the saved outline.
    /// Keep incomplete parents/details so validation never discards entered work.
    static func optionalOutline(_ items: [TrainingFocus]) -> [TrainingFocus] {
        normalized(items).filter { !$0.title.isEmpty || !$0.children.isEmpty }
    }

    /// Review-panel example only; the composer starts with a blank optional card.
    static var example: [TrainingFocus] {
        [TrainingFocus(title: "Guard passing", children: [
            TrainingFocus(title: "Knee-cut entry"),
            TrainingFocus(title: "Win the underhook"),
            TrainingFocus(title: "Settle into side control"),
        ]), TrainingFocus(title: "Back escapes")]
    }
}

/// Focus outlines travel inside the existing session note, with no server schema change.
enum SessionNoteCodec {
    private struct Content: Codable { var note: String; var focus: [TrainingFocus] }
    private static let prefix = "matmind-focus-v1:"
    static func encode(note: String, focus: [TrainingFocus]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard !focus.isEmpty, let data = try? encoder.encode(Content(note: note, focus: TrainingFocusTree.normalized(focus))) else { return note }
        return prefix + data.base64EncodedString()
    }
    static func decode(_ value: String) -> (note: String, focus: [TrainingFocus]) {
        guard value.hasPrefix(prefix), let data = Data(base64Encoded: String(value.dropFirst(prefix.count))),
              let content = try? JSONDecoder().decode(Content.self, from: data) else { return (value, []) }
        return (content.note, content.focus)
    }
}
