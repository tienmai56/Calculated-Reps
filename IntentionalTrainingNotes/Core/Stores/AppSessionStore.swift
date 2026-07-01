import Foundation
import SwiftUI

// MARK: - Stores

final class AppSessionStore: ObservableObject {
    @Published private(set) var route: AppRoute = .signedOut
    @Published private(set) var account: UserAccount?
    @Published private(set) var notebookStore: NotebookStore?
    @Published var errorMessage: String?

    private let accountStore: AccountStore
    private let authService: AuthServicing
    private let persistenceFactory: (String) -> NotebookPersistence

    init(
        accountStore: AccountStore = KeychainAccountStore(),
        authService: AuthServicing = AuthService(),
        persistenceFactory: @escaping (String) -> NotebookPersistence = { _ in JSONNotebookPersistence() }
    ) {
        self.accountStore = accountStore
        self.authService = authService
        self.persistenceFactory = persistenceFactory
        restore()
    }

    func restore() {
        // Local-only mode: no authentication required. Use a saved account if one exists
        // (legacy installs), otherwise launch straight into the app with a local account.
        if let restored = accountStore.loadAccount() {
            activate(account: restored)
        } else {
            activate(account: AppSessionStore.localAccount)
        }
    }

    func signIn(provider: AuthProvider) {
        errorMessage = nil

        let completion: (Result<UserAccount, AuthError>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let account):
                    self?.completeSignIn(account: account)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }

        switch provider {
        case .apple:
            authService.signInWithApple(completion: completion)
        case .google:
            authService.signInWithGoogle(completion: completion)
        }
    }

    func showOfflineSignInMessage(provider: AuthProvider) {
        errorMessage = "\(provider.label) sign-in needs internet. Turn off Airplane Mode or reconnect, then try again."
    }

    func completeSignIn(account: UserAccount) {
        var updated = account
        updated.lastSignedInAt = Date()

        do {
            try accountStore.saveAccount(updated)
            activate(account: updated)
        } catch {
            errorMessage = "Could not save sign-in state."
        }
    }

    func saveProfile(firstName: String, lastName: String) {
        guard let account = account, let notebookStore = notebookStore else { return }
        notebookStore.saveProfile(
            UserProfile(
                accountId: account.id,
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: notebookStore.notebook.profile?.createdAt ?? Date(),
                updatedAt: Date()
            )
        )
        route = .ready
    }

    func signOut() {
        do {
            try accountStore.clearAccount()
        } catch {
            errorMessage = "Could not clear sign-in state."
        }
        account = nil
        notebookStore = nil
        route = .signedOut
    }

    private func activate(account: UserAccount) {
        let store = NotebookStore(accountId: account.id, persistence: persistenceFactory(account.id))
        self.account = account
        self.notebookStore = store

        #if DEBUG
        // DEBUG/QA: `RESET_ONBOARDING` clears the completed flag and wipes data on every launch so
        // onboarding can be re-tested repeatedly without deleting the app. Never present in release.
        if ProcessInfo.processInfo.environment["RESET_ONBOARDING"] != nil {
            UserDefaults.standard.removeObject(forKey: AppSessionStore.onboardingCompletedKey)
            UserDefaults.standard.removeObject(forKey: "matmind.debugSeedVersion")
            store.resetForOnboardingTestingDEBUG()
        }
        #endif

        // Upgrading users already have a notebook — never send them through first-run onboarding
        // (it would add a stray goal/task/session on top of their real data). Treat any existing
        // data as "already onboarded" and persist that so the check only runs once.
        let hasExistingData = !store.notebook.goals.isEmpty
            || !store.notebook.sessions.isEmpty
            || store.notebook.profile != nil
        if hasExistingData && !UserDefaults.standard.bool(forKey: AppSessionStore.onboardingCompletedKey) {
            UserDefaults.standard.set(true, forKey: AppSessionStore.onboardingCompletedKey)
        }

        // First-run onboarding: show the goal → task → session flow until it's completed once.
        if UserDefaults.standard.bool(forKey: AppSessionStore.onboardingCompletedKey) {
            self.route = .ready
            #if DEBUG
            // Only seed demo data when there's nothing yet, so it never overwrites
            // a real notebook created through onboarding.
            if store.notebook.goals.isEmpty {
                store.seedDemoDataIfEmpty()
            }
            #endif
        } else {
            self.route = .onboarding
        }
    }

    /// Persists the goal, first task(s) and first session captured during onboarding, wires up the
    /// default 8:00 reminder, then routes into the app. Called once when onboarding finishes.
    func completeOnboarding(_ draft: OnboardingDraft) {
        if let store = notebookStore,
           let goal = store.addGoal(name: draft.goalName, iconName: draft.iconName, colorName: draft.colorName) {
            let taskIds: [String] = draft.taskNames.compactMap { store.addTask(goalId: goal.id, name: $0)?.id }
            // Attach the optional free-form description to the first task.
            if let firstTaskId = taskIds.first {
                let notes = draft.firstTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                if !notes.isEmpty { store.updateTask(id: firstTaskId, notes: notes) }
            }
            store.planSessions(
                [ProposedSession(goalId: goal.id, date: draft.sessionDate, taskIds: taskIds)],
                overrideConflicts: false
            )
        }

        UserDefaults.standard.set(draft.reminderEnabled, forKey: "reminderEnabled")
        UserDefaults.standard.set(draft.reminderHour, forKey: "reminderHour")
        UserDefaults.standard.set(draft.reminderMinute, forKey: "reminderMinute")
        ReminderScheduler.shared.updateSchedule(
            enabled: draft.reminderEnabled,
            hour: draft.reminderHour,
            minute: draft.reminderMinute
        )

        UserDefaults.standard.set(true, forKey: AppSessionStore.onboardingCompletedKey)
        route = .ready
    }

    static let onboardingCompletedKey = "matmind.hasCompletedOnboarding"

    /// Fixed account used when running without authentication (local-only mode).
    static let localAccount = UserAccount(
        id: "local",
        provider: .apple,
        providerSubjectId: "local-device"
    )
}
