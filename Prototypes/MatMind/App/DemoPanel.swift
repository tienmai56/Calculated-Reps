import SwiftUI

/// The web prototype's review panel, as a sheet. Open it by long-pressing the
/// "grip gorillas." wordmark on the Activity tab.
struct DemoPanel: View {
    @Environment(AppModel.self) private var mm
    @Environment(\.dismiss) private var dismiss
    @State private var openJourney: String? = nil

    private struct Journey {
        var key: String
        var title: String
        var start: AppModel.Preset
        var steps: [String]
    }

    private let journeys = [
        Journey(key: "A", title: "Plan training together", start: .training, steps: [
            "Training tab → Plan a training session", "Pick a day, time and gym",
            "Tap friends to invite → Send", "Watch Sarah & Alex join live",
        ]),
        Journey(key: "B", title: "Share a training memory", start: .training, steps: [
            "\"How was Halloween open mat?\" → Complete & share", "Take photo → pick one",
            "Toggle Training completed → Publish", "See it in Activity; friends like & comment",
        ]),
        Journey(key: "C", title: "Keep a friendship streak", start: .friends, steps: [
            "Friends → tap You + Sarah", "Invite Sarah to train → send",
            "Training → Complete & share with Sarah in it", "Streak ticks 8 → 9",
        ]),
    ]

    private let screens: [(AppModel.Preset, String)] = [
        (.welcome, "Welcome & Google sign-in"),
        (.activity, "Activity feed"), (.training, "Upcoming training"), (.create, "Create session"),
        (.complete, "Complete & share"), (.friends, "Friends & streaks"), (.qr, "QR code"),
        (.profile, "Profile"), (.notifications, "Notifications"),
    ]

    private let states: [(AppModel.Preset, String)] = [
        (.focusPlan, "Plan a session · nested focus details"),
        (.firstSession, "First session · no plans or shared posts"),
        (.awaitingPhoto, "Plan made · no shared photo yet"),
        (.empty, "Empty training schedule · keep activity history"), (.invite, "Pending invitation"), (.active, "Active streak"),
        (.broken, "Broken streak"), (.scan, "Scan → instant friends"), (.post, "Post detail + comments"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MMWordmark(size: 26)
                    Text("First draft · interactive prototype").mmFont(.body, 13, .medium).foregroundStyle(MMColor.ink500).padding(.top, 6)

                    heading("Journeys")
                    ForEach(journeys, id: \.key) { j in journeyRow(j) }

                    heading("Screens")
                    ForEach(Array(screens.enumerated()), id: \.offset) { i, item in
                        presetRow(item.0) {
                            HStack(spacing: 8) {
                                Text("\(i + 1)").mmFont(.mono, 12, .semibold).foregroundStyle(MMColor.ink400)
                                Text(item.1)
                            }
                        }
                    }

                    heading("States")
                    ForEach(states, id: \.1) { item in
                        presetRow(item.0) { Text(item.1) }
                    }

                    heading("Design system")
                    NavigationLink {
                        ComponentGallery()
                    } label: {
                        rowLabel { Text("Component gallery") }
                    }
                    .buttonStyle(.plain)

                    Button("Reset demo") {
                        mm.reset()
                        dismiss()
                    }
                    .mmFont(.body, 13, .semibold)
                    .foregroundStyle(MMColor.coral600)
                    .padding(.top, 14)
                }
                .padding(20)
            }
            .background(MMColor.bgApp)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDragIndicator(.visible)
    }

    private func heading(_ text: String) -> some View {
        Text(text).mmFont(.display, 13, tracking: -0.01).foregroundStyle(MMColor.ink500)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }

    private func rowLabel<Label: View>(@ViewBuilder _ label: () -> Label) -> some View {
        label()
            .mmFont(.body, 14, .medium)
            .foregroundStyle(MMColor.ink800)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
    }

    private func presetRow<Label: View>(_ preset: AppModel.Preset, @ViewBuilder label: () -> Label) -> some View {
        Button {
            dismiss()
            mm.run(preset)
        } label: {
            rowLabel(label)
        }
        .buttonStyle(.plain)
    }

    private func journeyRow(_ j: Journey) -> some View {
        let open = openJourney == j.key
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(MMMotion.easeOut()) { openJourney = open ? nil : j.key }
            } label: {
                HStack(spacing: 10) {
                    Text(j.key).mmFont(.display, 13, tracking: 0, lineHeight: 1).foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(MMColor.accent))
                    Text(j.title).mmFont(.body, 14, .bold).foregroundStyle(MMColor.ink900)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(open ? MMColor.white : Color.clear)
                        .mmShadowCard(open)
                }
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(j.steps.enumerated()), id: \.offset) { i, step in
                        Text("\(i + 1). \(step)").mmFont(.body, 13, lineHeight: 1.5).foregroundStyle(MMColor.ink700)
                    }
                    MMButton("Start journey \(j.key)", size: .sm) {
                        dismiss()
                        mm.run(j.start)
                    }
                    .padding(.top, 6)
                }
                .padding(.leading, 46)
                .padding(.vertical, 8)
            }
        }
        .padding(.bottom, 6)
    }
}
