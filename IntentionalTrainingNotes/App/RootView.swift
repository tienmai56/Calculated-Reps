import Foundation
import SwiftUI

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

#if DEBUG
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
        func day(_ offset: Int) -> Date { Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date() }

        let goal = TrainingGoal(accountId: accountId, name: "Leg Locks", iconName: "bolt.fill", colorName: "mint")
        let task = TrainingTask(goalId: goal.id, name: "Entry from half guard")

        // Second goal with only a planned session → shows in the locked card at 0 / 8.
        let goal2 = TrainingGoal(accountId: accountId, name: "Passing open guard", iconName: "target", colorName: "indigo")
        let task2 = TrainingTask(goalId: goal2.id, name: "Chase hip/torso")
        let planned2 = PlannedSession(goalId: goal2.id, date: day(1), taskIds: [task2.id], status: .planned)

        // Upcoming session for the Next Session card.
        let planned = PlannedSession(goalId: goal.id, date: day(0), taskIds: [task.id], status: .planned)

        // Three reflected past sessions so the "Bounty locked" progress card renders
        // in the canvas (3 / 8 sessions reflected — not yet qualified).
        let s1 = PlannedSession(goalId: goal.id, date: day(-2), taskIds: [task.id], status: .done)
        let s2 = PlannedSession(goalId: goal.id, date: day(-5), taskIds: [task.id], status: .done)
        let s3 = PlannedSession(goalId: goal.id, date: day(-9), taskIds: [task.id], status: .done)
        let r1 = Reflection(sessionId: s1.id, date: day(-2), workedText: "Tight ashi control.", stuckText: "", mood: .good)
        let r2 = Reflection(sessionId: s2.id, date: day(-5), workedText: "Clean entry off the underhook.", stuckText: "", mood: .neutral)
        let r3 = Reflection(sessionId: s3.id, date: day(-9), workedText: "Kept the knee line.", stuckText: "", mood: .good)

        self.notebook = TrainingNotebook(
            accountId: accountId,
            goals: [goal, goal2],
            tasks: [task, task2],
            sessions: [planned, planned2, s1, s2, s3],
            reflections: [r1, r2, r3]
        )
    }

    func load(accountId: String) throws -> TrainingNotebook {
        notebook.accountId = accountId
        return notebook
    }

    func save(_ notebook: TrainingNotebook) throws {
        self.notebook = notebook
    }
}
#endif
