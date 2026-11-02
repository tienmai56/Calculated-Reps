import Foundation

/// A session's optional focus outline. Stable IDs keep edits attached to the
/// right item as parents and children are added or removed.
struct TrainingFocus: Identifiable, Hashable {
    var id = UUID()
    var title = ""
    var children: [TrainingFocus] = []
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

    /// Review-panel example only; the real composer starts with an empty outline.
    static var example: [TrainingFocus] {
        [TrainingFocus(title: "Guard passing", children: [
            TrainingFocus(title: "Knee-cut entry", children: [TrainingFocus(title: "Win the underhook")]),
            TrainingFocus(title: "Settle into side control"),
        ]), TrainingFocus(title: "Back escapes")]
    }
}
