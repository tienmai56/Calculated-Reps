import SwiftUI

@main
struct MatMindPrototypeApp: App {
    @State private var model = AppModel()

    init() {
        _ = MMFont.registered
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.light)
                .tint(MMColor.accent)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        @Bindable var mm = mm
        NavigationStack(path: $mm.path) {
            TabRoot()
                .navigationDestination(for: Route.self) { route in
                    destination(route)
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
        .sheet(isPresented: $mm.showDemoPanel) {
            DemoPanel()
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case let .post(id, menu, focus): PostDetailScreen(id: id, openMenu: menu, focusComment: focus)
        case let .session(id): SessionDetailScreen(id: id)
        case let .create(past, friend): CreateScreen(startPast: past, friend: friend)
        case let .complete(id): CompleteScreen(id: id)
        case let .friend(id): FriendProfileScreen(id: id)
        case let .qr(scan): QRScreen(startOnScan: scan)
        case .notifications: NotificationsScreen()
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
            case .friends: FriendsScreen()
            case .profile: ProfileScreen()
            }
        }
        .overlay(alignment: .bottom) {
            MMTabBar(
                items: [
                    MMTabBarItem(id: AppTab.activity.rawValue, label: "Activity", icon: "house"),
                    MMTabBarItem(id: AppTab.training.rawValue, label: "Training", icon: "calendar"),
                    MMTabBarItem(id: AppTab.friends.rawValue, label: "Friends", icon: "users", badge: mm.friendsNeedAttention),
                    MMTabBarItem(id: AppTab.profile.rawValue, label: "Profile", icon: "user"),
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
        .ignoresSafeArea(.keyboard)
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
