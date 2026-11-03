import SwiftUI

@main
struct MatMindPrototypeApp: App {
    @State private var model = AppModel(live: false)

    init() {
        _ = MMFont.registered
    }

    var body: some Scene {
        WindowGroup {
            MMAppShell()
                .environment(model)
                .preferredColorScheme(.light)
                .tint(MMColor.accent)
        }
    }
}
