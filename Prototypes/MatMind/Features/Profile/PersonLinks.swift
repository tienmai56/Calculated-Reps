import SwiftUI

/// Profile links carry member IDs, so people with the same name still open the right profile.
enum PersonProfileLink {
    static func url(for id: String) -> URL? {
        guard !id.isEmpty else { return nil }
        var url = URLComponents()
        url.scheme = "matmonkeys-person"
        url.host = "profile"
        url.queryItems = [URLQueryItem(name: "id", value: id)]
        return url.url
    }

    static func personID(from url: URL) -> String? {
        guard url.scheme == "matmonkeys-person", url.host == "profile",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 1, items[0].name == "id",
              let id = items[0].value, !id.isEmpty else { return nil }
        return id
    }
}

extension MMRun {
    static func person(_ person: Person, _ size: CGFloat, _ weight: MMWeight = .regular,
                       short: Bool = false, color: Color = MMColor.textPrimary) -> MMRun {
        var run = MMRun.body(person.id == "me" ? "You" : (short ? person.firstName : person.name), size, weight,
                             color: color, link: PersonProfileLink.url(for: person.id))
        run.monkey = person.monkey
        run.monkeySize = (size * 1.15).rounded()
        return run
    }
}

/// Inline links preserve the existing fonts, copy and wrapping of mixed name/action text.
struct PersonText: View {
    @Environment(AppModel.self) private var mm
    let runs: [MMRun]

    init(_ runs: [MMRun]) { self.runs = runs }

    /// Each name carries its member's monkey; the runs between names render as before.
    private var text: Text {
        runs.reduce(Text("")) { text, run in
            text + mmRich([run]) + (run.monkey == nil ? Text("") : mmMonkeyText(run.monkey, size: run.monkeySize))
        }
    }

    var body: some View {
        text
            .environment(\.openURL, OpenURLAction { url in
                guard let id = PersonProfileLink.personID(from: url) else { return .systemAction }
                mm.openPerson(id)
                return .handled
            })
    }

    /// Matches mmNames, with a separate destination for each visible name. The +N count is plain text.
    static func names(_ people: [Person], size: CGFloat, weight: MMWeight = .regular,
                      color: Color = MMColor.textPrimary, max: Int = 2) -> [MMRun] {
        let visible = Array(people.prefix(max))
        var runs: [MMRun] = []
        for (index, person) in visible.enumerated() {
            if index > 0 { runs.append(.body(people.count <= max ? " & " : ", ", size, weight, color: color)) }
            runs.append(.person(person, size, weight, short: true, color: color))
        }
        if people.count > max { runs.append(.body(" +\(people.count - max)", size, weight, color: color)) }
        return runs
    }
}

/// A name/avatar target separate from nearby comment, RSVP or removal controls.
struct PersonProfileButton<Label: View>: View {
    @Environment(AppModel.self) private var mm
    let person: Person
    @ViewBuilder var label: Label

    var body: some View {
        Button { mm.openPerson(person.id) } label: {
            label
                .frame(minHeight: MMLayout.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(person.id == "me" ? "View your profile" : "View \(person.name)'s profile")
        .accessibilityIdentifier("profile-link-\(person.id)")
    }
}
