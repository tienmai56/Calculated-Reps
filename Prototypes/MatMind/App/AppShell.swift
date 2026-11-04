import SwiftUI

struct MMAppShell: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        @Bindable var mm = mm
        Group {
            if mm.isSignedIn {
                NavigationStack(path: $mm.path) {
                    TabRoot()
                        .navigationDestination(for: Route.self) { route in
                            destination(route)
                        }
                }
                .transition(.opacity)
            } else {
                WelcomeScreen()
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let toast = mm.toast {
                MMToast(message: toast.message, variant: toast.variant)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .id(toast.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { mm.toast = nil }
            }
        }
        .animation(MMMotion.bounce(MMMotion.slow), value: mm.toast)
#if DEBUG || MAT_MIND_PROTOTYPE
        .sheet(isPresented: $mm.showDemoPanel) {
            if !mm.isLive { DemoPanel() }
        }
#endif
        .environment(\.allowsSamplePhotos, !mm.isLive)
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case let .post(id, menu, focus): PostDetailScreen(id: id, openMenu: menu, focusComment: focus)
        case let .session(id): SessionDetailScreen(id: id)
        case let .create(past, friend, focus): CreateScreen(startPast: past, friend: friend, initialFocus: focus)
        case let .complete(id): CompleteScreen(id: id)
        case let .friend(id): FriendProfileScreen(id: id)
        case .friends: FriendsScreen(pushed: true)
        case let .goal(id): GoalDetailScreen(id: id)
        case let .sharedGoal(id): SharedGoalScreen(id: id)
        case let .qr(scan): QRScreen(startOnScan: scan)
        case .notifications: NotificationsScreen()
        case .people: PeopleSearchScreen()
        case let .person(id): PersonProfileScreen(id: id)
        }
    }
}

/// The four tabs plus the custom tab bar. Pushed screens cover the bar.
struct TabRoot: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        ZStack {
            switch mm.tab {
            case .activity: ActivityScreen()
            case .training: TrainingScreen()
            case .goals: GoalsScreen()
            case .profile: ProfileScreen()
            }
        }
        .overlay(alignment: .bottom) {
            MMTabBar(
                items: [
                    MMTabBarItem(id: AppTab.activity.rawValue, label: "Activity", icon: "house"),
                    MMTabBarItem(id: AppTab.training.rawValue, label: "Training", icon: "calendar"),
                    MMTabBarItem(id: AppTab.goals.rawValue, label: "Goals", icon: "notebook-pen"),
                    // Friends live in Profile, so the streak reminder dot does too.
                    MMTabBarItem(id: AppTab.profile.rawValue, label: "Profile", icon: "user", badge: mm.friendsNeedAttention),
                ],
                selection: Binding(
                    get: { mm.tab.rawValue },
                    set: { mm.setTab(AppTab(rawValue: $0) ?? .activity) }
                ),
                centerAction: { mm.go(.create()) }
            )
            // 86pt including the home-indicator area, as specced.
            .ignoresSafeArea(edges: .bottom)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// Pushed screens hide the system navigation bar (they draw their own headers),
// which would otherwise also disable the edge-swipe back gesture. Keep it on.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
