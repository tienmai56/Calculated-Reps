import Foundation
import Network
import SwiftUI

final class NetworkStatusStore: ObservableObject {
    @Published private(set) var isOffline = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "IntentionalTrainingNotes.NetworkStatus")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = path.status != .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
