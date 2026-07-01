import Foundation

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
