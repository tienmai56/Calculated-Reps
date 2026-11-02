import SwiftUI

struct MatMindRoot: View {
    @State var model: SocialAppModel
    @State private var openedNotification: PushRoute?
    private struct PushRoute: Identifiable { var id: String; var session: Bool }
    @State private var create = false
    @Environment(\.scenePhase) private var phase
    var body: some View {
        TabView(selection:$model.tab) {
            NavigationStack { SocialActivityScreen() }.tabItem { Label("Activity",systemImage:"house") }.tag(0)
            NavigationStack { SocialTrainingScreen() }.tabItem { Label("Training",systemImage:"calendar") }.tag(1)
            NavigationStack { SocialFriendsScreen() }.tabItem { Label("Friends",systemImage:"person.2") }.tag(2)
            NavigationStack { SocialProfileScreen() }.tabItem { Label("Profile",systemImage:"person") }.tag(3)
        }
        .environment(model)
        .tint(MMColor.accent)
        .safeAreaInset(edge:.top,spacing:0) {
            if model.busy { ProgressView().frame(maxWidth:.infinity).padding(6).background(MMColor.bgApp) }
            if let error = model.error { HStack { Text(error).font(.footnote); Button("Dismiss") { model.error = nil } }.padding(10).background(MMColor.paper2) }
            if model.pendingLink != nil {
                Button(model.userID == nil ? "Sign in in Profile to open invitation" : "Open invitation") { Task { await model.redeemPendingLink() } }.padding(8)
            }
        }
        .overlay(alignment:.bottomTrailing) {
            Button { create = true } label: { Image(systemName:"plus").font(.title2.bold()).foregroundStyle(.white).padding(18).background(Circle().fill(MMColor.accent)) }
                .accessibilityLabel("Plan a session").padding(.trailing,18).padding(.bottom,64)
        }
        .sheet(isPresented:$create) { NavigationStack { SocialCreateScreen() }.environment(model) }
        .sheet(item:$openedNotification) { route in NavigationStack { if route.session { SocialSessionScreen(id:route.id) } else { SocialPostScreen(postID:route.id) } }.environment(model) }
        .task { await model.start(); openNotification() }
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("MatMindPushOpen"))) { _ in Task { await model.refresh(); openNotification() } }
        .onChange(of:phase) { _,new in if new == .active { Task { await model.refresh() } } }
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("MatMindPushToken"))) { _ in Task { await SocialPushCoordinator.register(in:model) } }
        .onOpenURL { model.handle($0) }
        .preferredColorScheme(.light)
    }
    private func openNotification() {
        guard model.userID != nil, let info = SocialPushCoordinator.pending, let id = info["entity_id"] as? String else { return }
        let kind = info["kind"] as? String
        openedNotification = PushRoute(id:id, session:kind == "invite" || kind == "joined")
        SocialPushCoordinator.pending = nil
    }

}
