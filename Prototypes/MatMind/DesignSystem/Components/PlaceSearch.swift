import SwiftUI
import MapKit
import Observation

struct PlaceSuggestion: Hashable, Sendable {
    let title: String
    let subtitle: String
}

@MainActor
protocol PlaceSearchClient: AnyObject {
    func search(_ query: String, completion: @escaping (Result<[PlaceSuggestion], Error>) -> Void)
    func cancel()
}

/// A fresh completer per request keeps callbacks from older queries separate.
@MainActor
private final class ApplePlaceSearchClient: NSObject, PlaceSearchClient, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    private var completion: ((Result<[PlaceSuggestion], Error>) -> Void)?

    func search(_ query: String, completion: @escaping (Result<[PlaceSuggestion], Error>) -> Void) {
        self.completion = completion
        completer.resultTypes = [.pointOfInterest, .address]
        completer.delegate = self
        completer.queryFragment = query
    }

    func cancel() {
        completion = nil
        completer.delegate = nil
        completer.cancel()
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let found = completer.results.map { PlaceSuggestion(title: $0.title, subtitle: $0.subtitle) }
        Task { @MainActor [weak self] in self?.completion?(.success(found)) }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.completion?(.failure(error)) }
    }
}

/// Apple Maps suggestions are optional: a typed venue remains valid without a lookup.
@MainActor
@Observable
final class PlaceSearch {
    enum State: Equatable { case idle, searching, ready, unavailable }
    private(set) var query = ""
    private(set) var suggestions: [PlaceSuggestion] = []
    private(set) var state = State.idle
    @ObservationIgnored private let makeClient: @MainActor () -> any PlaceSearchClient
    @ObservationIgnored private var client: (any PlaceSearchClient)?
    @ObservationIgnored private var requestID = UUID()

    init(makeClient: (@MainActor () -> any PlaceSearchClient)? = nil) {
        self.makeClient = makeClient ?? { ApplePlaceSearchClient() }
    }

    func updateQuery(_ value: String) {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text != query else { return }
        requestID = UUID()
        client?.cancel()
        client = nil
        query = text
        suggestions = []
        guard text.count >= 2 else { state = .idle; return }
        state = .searching
        let request = requestID
        let client = makeClient()
        self.client = client
        client.search(text) { [weak self] result in
            guard let self, self.requestID == request else { return }
            switch result {
            case .success(let places):
                var seen = Set<PlaceSuggestion>()
                self.suggestions = Array(places.filter { !$0.title.isEmpty && seen.insert($0).inserted }.prefix(5))
                self.state = .ready
            case .failure:
                self.suggestions = []
                self.state = .unavailable
            }
        }
    }
}

/// Shared by home-gym setup and session venues. Only an actively edited field searches.
struct MMPlaceSearchField: View {
    var label: String
    var required = false
    var placeholder = "Search gyms or addresses"
    @Binding var text: String
    @State private var search = PlaceSearch()
    @State private var active = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MMTextField(label: label, required: required, placeholder: placeholder, text: $text, iconLeft: "map-pin",
                        onSubmit: { finishEditing() }, onFocusChange: { focused in
                active = focused
                if !focused { search.updateQuery("") }
            })
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .onChange(of: text) { _, _ in search.updateQuery("") }

            if active {
                if !search.suggestions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(search.suggestions.enumerated()), id: \.element) { index, place in
                            if index > 0 { Divider().overlay(MMColor.borderSubtle).padding(.leading, 44) }
                            Button {
                                finishEditing()
                                text = place.title
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    MMIcon("map-pin", size: 18, color: MMColor.textTertiary).padding(.top, 2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.title).mmFont(.body, 15, .semibold).foregroundStyle(MMColor.textPrimary)
                                        if !place.subtitle.isEmpty {
                                            Text(place.subtitle).mmFont(.body, 13).foregroundStyle(MMColor.textTertiary).lineLimit(2)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(minHeight: MMLayout.tapTarget)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(place.subtitle.isEmpty ? place.title : "\(place.title), \(place.subtitle)")
                        }
                    }
                    .mmCardSurface(radius: MMRadius.md)
                    .transition(.opacity)
                } else if search.state == .searching {
                    status("Searching…")
                } else if search.state == .unavailable {
                    status("Search unavailable. You can enter the venue name.")
                } else if search.state == .ready {
                    status("No matches. You can keep the name you entered.")
                }
            }
        }
        .animation(MMMotion.easeOut(MMMotion.fast), value: search.suggestions.isEmpty)
        .task(id: active ? text : nil) {
            guard active, text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { return }
            do {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
                search.updateQuery(text)
            } catch { /* A changed query or a dismissed field cancels the debounce. */ }
        }
        .onDisappear { search.updateQuery("") }
    }

    private func status(_ message: String) -> some View {
        Text(message).mmFont(.body, 13).foregroundStyle(MMColor.textTertiary)
    }

    private func finishEditing() {
        active = false
        search.updateQuery("")
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
