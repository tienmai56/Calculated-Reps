import SwiftUI
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var model: SocialAppModel?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let model = SocialAppModel()
        self.model = model
        window.rootViewController = UIHostingController(rootView: MatMindRoot(model: model))
        if let url = connectionOptions.urlContexts.first?.url { model.handle(url) }
        if let url = connectionOptions.userActivities.first?.webpageURL { model.handle(url) }
        self.window = window
        window.makeKeyAndVisible()
    }
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url { model?.handle(url) }
    }
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if let url = userActivity.webpageURL { model?.handle(url) }
    }

}
