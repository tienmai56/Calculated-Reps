import Foundation
import SwiftUI

@main
@MainActor
struct MatMindPrototypeApp: App {
    @State private var model: AppModel
    private let quickLogMock: Bool
    private let checklistReview: Bool
    private let goalNotesReview: Bool
    private let mediaReview: Bool
    private let invitationMock: Bool

    init() {
        _ = MMFont.registered
        let mock = ProcessInfo.processInfo.arguments.contains("--quick-log-mock")
        quickLogMock = mock
        mediaReview = ProcessInfo.processInfo.arguments.contains("--session-media-review")
        let invite = ProcessInfo.processInfo.arguments.contains("--training-invitation-mock")
        invitationMock = invite
        checklistReview = ProcessInfo.processInfo.arguments.contains("--session-checklist-review")
        goalNotesReview = ProcessInfo.processInfo.arguments.contains("--goal-notes-review")
        let preview = invite ? AppModel.trainingInvitationMock() : mock ? AppModel.quickTrainingLogMock() : AppModel(live: false)
        preview.loadQuickLogTechniques(account: "preview")
        if mediaReview { preview.enterDemo() }
        if mediaReview, let session = preview.toComplete {
            let sources = ["roll-gi", "group-class", "coach-help"]
            preview.toComplete?.photos = sources
            if ProcessInfo.processInfo.arguments.contains("--activity") {
                _ = preview.publish(session.id, media: sources, caption: "Good rounds. Better company.", people: session.going)
                preview.tab = .activity
            } else { preview.path = [.complete(id: session.id)] }
        }
        _model = State(initialValue: preview)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if goalNotesReview { GoalNotesReview() }
                else if checklistReview { SessionChecklistReview() }
                else if invitationMock {
                    VStack(spacing: 0) {
                        TrainingInvitationMockControls()
                        MMAppShell()
                    }
                }
                else { MMAppShell() }
            }
                .id(model.quickLogMockRevision)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if quickLogMock && !invitationMock { QuickLogMockControls() }
                }
                .environment(model)
                .preferredColorScheme(.light)
                .tint(MMColor.accent)
        }
    }
}

private struct TrainingInvitationMockControls: View {
    @Environment(AppModel.self) private var mm

    var body: some View {
        HStack(spacing: MMSpace.s4) {
            Text("Mock · Jamie invited you")
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Reset invite") { mm.loadTrainingInvitationMock() }
                .frame(minHeight: MMLayout.tapTarget)
        }
        .mmFont(.body, 12, .semibold)
        .foregroundStyle(MMColor.ink900)
        .padding(.horizontal, MMSpace.s6)
        .background(MMColor.sun100)
    }
}

/// The production goal editor, with isolated review data in the prototype target.
private struct GoalNotesReview: View {
    var body: some View {
        MatGoalEditorSheet(draft: MatGoal(id: "goal-notes-review", title: "Single leg from standing", parts: [
            GoalPart(id: "setup", title: "Setup & level change", noteItems: [
                GoalNote(id: "entry", text: "Collar tie, snap them down, shoot when their head comes back up. Step in first, don’t reach.",
                         links: ["https://youtu.be/example"], photos: ["roll-gi", "coach-help"]),
                GoalNote(id: "corner", text: "Hips under me before I lift. Turn the corner, don’t run straight.", photos: ["floor-drill"])
            ]),
            GoalPart(id: "finish", title: "Finish: run the pipe", noteItems: [
                GoalNote(id: "pipe", text: "Keep their leg high and circle toward the heel.", links: ["https://example.com/finish"])
            ])
        ]), isNew: true)
    }
}

/// A native review surface for the exact components used in the session form.
/// This entry point belongs only to the sample-data prototype target.
private struct SessionChecklistReview: View {
    private let past = ProcessInfo.processInfo.arguments.contains("--past")
    @State private var description = "Guard retention and escapes."
    @State private var items: [TrainingFocus] = {
        if ProcessInfo.processInfo.arguments.contains("--empty") { return [TrainingFocus()] }
        let past = ProcessInfo.processInfo.arguments.contains("--past")
        return [TrainingFocus(title: "Guard retention", children: [TrainingFocus(title: "Frame early and recover position")], isCompleted: past),
                TrainingFocus(title: "Side-control escape", children: [TrainingFocus(title: "Create space before bridging")])]
    }()

    var body: some View {
        MMScreen {
            MMHeader(title: past ? "Log a past session" : "Plan a training", leading: {
                MMIconButton("x", label: "Close") { }
            })
        } content: {
            VStack(alignment: .leading, spacing: MMSpace.s8) {
                MMTextField(label: "Location", text: .constant("Ralph Gracie"), iconLeft: "map-pin")
                VStack(alignment: .leading, spacing: MMSpace.s5) {
                    HStack {
                        Text("Description").mmFont(.display, 16)
                        Spacer()
                        MMMeta("Optional")
                    }
                    MMTextField(placeholder: "Gi or no-gi? Bring anything?", text: $description, multiline: true, rows: 3)
                }
                VStack(alignment: .leading, spacing: MMSpace.s5) {
                    HStack {
                        Text("What are we working on?").mmFont(.display, 16)
                        Spacer()
                        let outline = TrainingFocusTree.optionalOutline(items)
                        MMMeta(outline.isEmpty ? "Optional" : "\(outline.filter(\.isCompleted).count)/\(outline.count)")
                    }
                    TrainingFocusComposer(items: $items, allowsCompletion: past)
                }
            }
            .padding(MMSpace.s6)
        } footer: {
            MMButton(past ? "Next: add a photo" : "Create session", iconLeft: past ? "camera" : "send", fullWidth: true) { }
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
