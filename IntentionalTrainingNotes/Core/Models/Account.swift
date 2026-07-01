import Foundation

struct UserAccount: Codable, Equatable {
    var id: String
    var provider: AuthProvider
    var providerSubjectId: String
    var email: String?
    var displayName: String?
    var createdAt: Date
    var lastSignedInAt: Date

    init(
        id: String? = nil,
        provider: AuthProvider,
        providerSubjectId: String,
        email: String? = nil,
        displayName: String? = nil,
        createdAt: Date = Date(),
        lastSignedInAt: Date = Date()
    ) {
        let accountId = id ?? "\(provider.rawValue)_\(providerSubjectId)"
        self.id = accountId.sanitizedAccountId
        self.provider = provider
        self.providerSubjectId = providerSubjectId
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.lastSignedInAt = lastSignedInAt
    }
}

struct UserProfile: Codable, Equatable {
    var accountId: String
    var firstName: String
    var lastName: String
    var belt: Belt?
    var createdAt: Date
    var updatedAt: Date

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    init(
        accountId: String,
        firstName: String,
        lastName: String,
        belt: Belt? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.accountId = accountId
        self.firstName = firstName
        self.lastName = lastName
        self.belt = belt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
