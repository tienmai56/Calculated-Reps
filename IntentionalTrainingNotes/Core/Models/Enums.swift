import Foundation
import SwiftUI

// MARK: - Domain Models

enum AuthProvider: String, Codable, CaseIterable {
    case apple
    case google

    var label: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }
}

enum AppRoute: Equatable {
    case signedOut
    case signedInMissingProfile
    case onboarding
    case ready
}

enum Belt: String, Codable, CaseIterable, Identifiable {
    case white
    case blue
    case purple
    case brown
    case black

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

enum Mood: String, Codable, CaseIterable, Identifiable {
    case frustrated
    case neutral
    case good
    case great

    var id: String { rawValue }

    var label: String {
        switch self {
        case .frustrated: return "Frustrated"
        case .neutral: return "Neutral"
        case .good: return "Good"
        case .great: return "Great"
        }
    }

    var glyph: String {
        switch self {
        case .frustrated: return "😤"
        case .neutral: return "😐"
        case .good: return "😊"
        case .great: return "🔥"
        }
    }
}

enum SessionStatus: String, Codable {
    case planned
    case done
}
