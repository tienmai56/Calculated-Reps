import Foundation
import SwiftUI

@main
@MainActor
struct MatMindPrototypeApp: App {
    @State private var model: AppModel
    private let quickLogMock: Bool

    init() {
        _ = MMFont.registered
        let mock = ProcessInfo.processInfo.arguments.contains("--quick-log-mock")
        quickLogMock = mock
        let preview = mock ? AppModel.quickTrainingLogMock() : AppModel(live: false)
        preview.loadQuickLogTechniques(account: "preview")
        _model = State(initialValue: preview)
    }

    var body: some Scene {
        WindowGroup {
            MMAppShell()
                .id(model.quickLogMockRevision)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if quickLogMock { QuickLogMockControls() }
                }
                .environment(model)
                .preferredColorScheme(.light)
                .tint(MMColor.accent)
        }
    }
}

private struct QuickLogMockControls: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        HStack {
            Menu {
                ForEach(QuickLogMockScenario.allCases) { scenario in
                    Button(scenario.title) { mm.loadQuickLogMock(scenario) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Mock data · \(mm.quickLogMockScenario.title)")
                    MMIcon("chevron-down", size: 12)
                }
            }
            .accessibilityLabel("Choose a seeded mock state")
            Spacer(minLength: 8)
            if mm.quickLogMockScenario == .upcomingPrompt,
               let session = mm.findSession("mock-today"), mm.startDate(of: session) > Date() {
                Button("Start plan") { mm.startMockPromptPlan() }
            }
            Button("Reset") { mm.loadQuickLogMock(mm.quickLogMockScenario) }
        }
        .mmFont(.body, 12, .semibold)
        .foregroundStyle(MMColor.ink900)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(MMColor.sun100)
    }
}
