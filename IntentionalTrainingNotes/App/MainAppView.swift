import SwiftUI

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
