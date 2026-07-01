import AuthenticationServices
import AVFoundation
import Foundation
import Network
import Security
import Speech
import SwiftUI
import UIKit
import UserNotifications

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

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
            } else if sessionStore.route == .onboarding {
                OnboardingContainerView(onComplete: { draft in
                    sessionStore.completeOnboarding(draft)
                })
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

// MARK: - Onboarding Flow

/// Everything captured during first-run onboarding, handed to `AppSessionStore.completeOnboarding`.

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

// MARK: - Notes

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
