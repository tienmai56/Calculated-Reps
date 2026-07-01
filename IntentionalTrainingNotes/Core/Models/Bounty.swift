import Foundation

/// The primary "shape" of a bounty chosen on the first step of the flow.
/// A bounty can still carry both a count and a partner regardless of kind
/// (see `Set the target`), but the kind drives the copy and default fields.
enum BountyKind: String, Codable, CaseIterable, Identifiable {
    case hitCount
    case targetPartner
    var id: String { rawValue }

    var title: String {
        switch self {
        case .hitCount: return "Hit count"
        case .targetPartner: return "Target a training partner"
        }
    }

    var blurb: String {
        switch self {
        case .hitCount: return "Land a submission a specific number of times."
        case .targetPartner: return "Land a submission on a specific person."
        }
    }

    var symbol: String {
        switch self {
        case .hitCount: return "target"
        case .targetPartner: return "person.fill"
        }
    }
}

enum BountyStatus: String, Codable {
    case active
    case collected
}

/// A self-set challenge to land a drilled technique. Unlocked after a goal has
/// been worked for 2+ weeks. No deadline — the user taps "I hit it" to record.
struct Bounty: Codable, Equatable, Identifiable {
    var id: String
    var accountId: String
    var goalId: String
    var taskId: String
    var kind: BountyKind
    /// Number of times to land it. `nil` means "not specified" → treated as 1.
    var targetCount: Int?
    /// Specific partner to land it on. `nil`/blank means no specific person.
    var targetPartner: String?
    var hitDates: [Date]
    var status: BountyStatus
    var createdAt: Date
    var collectedAt: Date?

    /// Hits needed before the bounty is collected. A partner-only bounty with no
    /// explicit count is landed once.
    var requiredHits: Int { max(1, targetCount ?? 1) }
    var hitCount: Int { hitDates.count }
    var isComplete: Bool { hitCount >= requiredHits }

    init(
        id: String = "b_\(UUID().uuidString)",
        accountId: String,
        goalId: String,
        taskId: String,
        kind: BountyKind,
        targetCount: Int? = nil,
        targetPartner: String? = nil,
        hitDates: [Date] = [],
        status: BountyStatus = .active,
        createdAt: Date = Date(),
        collectedAt: Date? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.goalId = goalId
        self.taskId = taskId
        self.kind = kind
        self.targetCount = targetCount
        self.targetPartner = targetPartner
        self.hitDates = hitDates
        self.status = status
        self.createdAt = createdAt
        self.collectedAt = collectedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, accountId, goalId, taskId, kind, targetCount, targetPartner, hitDates, status, createdAt, collectedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        accountId = try c.decode(String.self, forKey: .accountId)
        goalId = try c.decode(String.self, forKey: .goalId)
        taskId = try c.decode(String.self, forKey: .taskId)
        kind = try c.decodeIfPresent(BountyKind.self, forKey: .kind) ?? .hitCount
        targetCount = try c.decodeIfPresent(Int.self, forKey: .targetCount)
        targetPartner = try c.decodeIfPresent(String.self, forKey: .targetPartner)
        hitDates = try c.decodeIfPresent([Date].self, forKey: .hitDates) ?? []
        status = try c.decodeIfPresent(BountyStatus.self, forKey: .status) ?? .active
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        collectedAt = try c.decodeIfPresent(Date.self, forKey: .collectedAt)
    }
}
