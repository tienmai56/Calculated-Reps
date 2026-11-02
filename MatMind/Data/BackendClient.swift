import Foundation
import Security
import AuthenticationServices
import CryptoKit
import SwiftUI
import SwiftData

struct BackendConfiguration {
    let url: URL
    let key: String
    static var configured: BackendConfiguration? {
        guard let string = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: string), url.scheme == "https", url.host != nil,
              let key = Bundle.main.object(forInfoDictionaryKey: "SupabasePublishableKey") as? String,
              !key.isEmpty, !key.contains("$("), !string.contains("example") else { return nil }
        return BackendConfiguration(url: url, key: key)
    }
}
struct CloudCredential: Codable {
    var access_token: String
    var refresh_token: String
    var user: CloudUser
}
struct CloudUser: Codable { var id: String }
struct SocialRow: Codable, Identifiable, Equatable {
    var values: [String: ArchiveValue]
    var id: String { text("id").isEmpty ? [text("session_id"),text("post_id"),text("user_id"),text("friendship_id")].joined(separator:":") : text("id") }
    init(from decoder: Decoder) throws { values = try decoder.singleValueContainer().decode([String: ArchiveValue].self) }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(values) }
    func text(_ key: String) -> String { values[key]?.string ?? "" }
    func flag(_ key: String) -> Bool { values[key] == .bool(true) }
    func number(_ key: String) -> Int { if case .number(let n) = values[key] { return Int(n) }; return 0 }
    func date(_ key: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: text(key)) ?? ISO8601DateFormatter().date(from: text(key))
    }
}
struct SocialSnapshot: Codable, Equatable {
    var server_time: String?
    var profiles: [SocialRow] = [], friendships: [SocialRow] = [], sessions: [SocialRow] = []
    var participants: [SocialRow] = [], posts: [SocialRow] = [], tags: [SocialRow] = []
    var likes: [SocialRow] = [], comments: [SocialRow] = [], credits: [SocialRow] = []
    var media: [SocialRow] = [], notifications: [SocialRow] = []
}

@Model final class CachedSocialState {
    @Attribute(.unique) var owner: String
    var payload: Data
    init(owner: String, payload: Data) { self.owner = owner; self.payload = payload }
}
@Model final class LocalSocialDraft {
    @Attribute(.unique) var key: String
    var payload: Data
    init(key: String, payload: Data) { self.key = key; self.payload = payload }
}

struct CloudError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum CloudSignInError: LocalizedError, Equatable {
    case googleUnavailable, cancelled, invalidCallback, providerRejected

    var errorDescription: String? {
        switch self {
        case .googleUnavailable: "Google sign-in is currently unavailable. Please try again later."
        case .cancelled: "Sign-in was cancelled."
        case .invalidCallback: "Couldn’t finish Google sign-in. Please try again."
        case .providerRejected: "Google couldn’t complete sign-in. Please try again."
        }
    }
}

struct CloudAuthSettings: Decodable {
    let external: [String: Bool]

    func requireGoogle() throws {
        guard external["google"] == true else { throw CloudSignInError.googleUnavailable }
    }
}

enum GoogleOAuthCallback {
    static func authorizationCode(from url: URL) throws -> String {
        guard url.scheme == "matmind", url.host == "auth",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            throw CloudSignInError.invalidCallback
        }
        if let failure = items.first(where: { $0.name == "error" }) {
            if failure.value == "access_denied" { throw CloudSignInError.cancelled }
            throw CloudSignInError.providerRejected
        }
        let codes = items.filter { $0.name == "code" }
        guard codes.count == 1, let code = codes.first?.value,
              !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CloudSignInError.invalidCallback
        }
        return code
    }
}

actor BackendClient {
    private let configuration: BackendConfiguration?
    private var credential: CloudCredential?
    init(configuration: BackendConfiguration? = .configured) {
        self.configuration = configuration
        if let data = Self.readKeychain() { credential = try? JSONDecoder().decode(CloudCredential.self, from: data) }
    }
    func identity() -> String? { credential?.user.id }
    func requireGoogleSignIn() async throws {
        let data = try await request(path: "auth/v1/settings", body: nil, authenticated: false)
        try JSONDecoder().decode(CloudAuthSettings.self, from: data).requireGoogle()
    }
    func signIn(provider: String, idToken: String, nonce: String) async throws -> String {
        let response = try await request(path: "auth/v1/token?grant_type=id_token", body: ["provider": provider, "id_token": idToken, "nonce": nonce], authenticated: false)
        try await accept(response)
        return credential!.user.id
    }
    func exchange(code: String, verifier: String) async throws {
        let response = try await request(path: "auth/v1/token?grant_type=pkce", body: ["auth_code":code,"code_verifier":verifier], authenticated:false)
        try await accept(response)
    }
    private func accept(_ data: Data) async throws {
        let candidate = try JSONDecoder().decode(CloudCredential.self, from: data)
        credential = candidate
        do {
            // Verify identity against the auth service rather than trusting a local ID.
            let verified = try await request(path:"auth/v1/user", body:nil)
            let user = try JSONDecoder().decode(CloudUser.self, from: verified)
            guard user.id == candidate.user.id else { throw CloudError(message:"Identity verification failed.") }
            try Self.saveKeychain(JSONEncoder().encode(candidate))
        } catch { credential = nil; throw error }
    }
    func signOut() async {
        _ = try? await request(path:"auth/v1/logout",body:[:])
        credential = nil
        SecItemDelete(Self.keychainQuery() as CFDictionary)
    }
    func snapshot() async throws -> SocialSnapshot { try JSONDecoder().decode(SocialSnapshot.self, from: await request(path:"rest/v1/rpc/snapshot",body:[:])) }
    func command(_ operation: String, payload: [String: Any], key: UUID = UUID()) async throws -> [String: ArchiveValue] {
        let data = try await request(path:"rest/v1/rpc/command", body:["operation":operation,"payload":payload,"idempotency_key":key.uuidString])
        return try JSONDecoder().decode([String: ArchiveValue].self, from:data)
    }
    func feed(before: SocialRow) async throws -> [SocialRow] {
        let data = try await request(path:"rest/v1/rpc/feed_page",body:["before_time":before.text("published_at"),"before_id":before.id])
        return try JSONDecoder().decode([SocialRow].self,from:data)
    }
    func postDetails(_ id: String) async throws -> [String:[SocialRow]] {
        try JSONDecoder().decode([String:[SocialRow]].self,from:await request(path:"rest/v1/rpc/post_details",body:["post_id":id]))
    }
    func comments(post: String, before: SocialRow) async throws -> [SocialRow] {
        try JSONDecoder().decode([SocialRow].self,from:await request(path:"rest/v1/rpc/comment_page",body:["target_post":post,"before_time":before.text("created_at"),"before_id":before.id]))
    }
    func upload(_ data: Data, objectKey: String, bucket: String = "session-photos") async throws {
        _ = try await request(path:"storage/v1/object/\(bucket)/" + objectKey, body:nil, bytes:data, contentType:"image/jpeg")
    }
    func image(key: String, bucket: String = "session-photos") async throws -> Data {
        try await request(path:"storage/v1/object/authenticated/\(bucket)/" + key, body:nil)
    }
    func deleteAccount() async throws {
        _ = try await request(path:"functions/v1/delete-account",body:[:])
        credential = nil; SecItemDelete(Self.keychainQuery() as CFDictionary)
    }
    private func request(path: String, body: [String: Any]?, authenticated: Bool = true, bytes: Data? = nil, contentType: String = "application/json", retry: Bool = true) async throws -> Data {
        guard let configuration else { throw CloudError(message:"Cloud services are not configured for this build. Local training data remains available in Settings.") }
        guard !authenticated || credential != nil else { throw CloudError(message:"Sign in to use shared training.") }
        let url = URL(string:configuration.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn:"/")) + "/" + path)!
        var req = URLRequest(url:url); req.timeoutInterval = 30
        req.httpMethod = body != nil || bytes != nil ? "POST" : "GET"
        req.setValue(configuration.key,forHTTPHeaderField:"apikey")
        if authenticated, let credential { req.setValue("Bearer " + credential.access_token,forHTTPHeaderField:"Authorization") }
        req.setValue(contentType,forHTTPHeaderField:"Content-Type")
        req.httpBody = try bytes ?? body.map { try JSONSerialization.data(withJSONObject:$0) }
        let (data,response) = try await URLSession.shared.data(for:req)
        guard let http = response as? HTTPURLResponse else { throw CloudError(message:"No server response.") }
        if http.statusCode == 401, authenticated, retry, let old = credential {
            let refreshed = try await request(path:"auth/v1/token?grant_type=refresh_token",body:["refresh_token":old.refresh_token],authenticated:false,retry:false)
            credential = try JSONDecoder().decode(CloudCredential.self,from:refreshed)
            try Self.saveKeychain(JSONEncoder().encode(credential!))
            return try await request(path:path,body:body,authenticated:authenticated,bytes:bytes,contentType:contentType,retry:false)
        }
        guard (200..<300).contains(http.statusCode) else {
            let object = try? JSONSerialization.jsonObject(with:data) as? [String:Any]
            throw CloudError(message:object?["message"] as? String ?? object?["error_description"] as? String ?? "Request failed (\(http.statusCode)). Try again.")
        }
        return data
    }
    private static func keychainQuery() -> [String:Any] { [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.tienmai.matmind.cloud",kSecAttrAccount as String:"session"] }
    private static func readKeychain() -> Data? {
        var query = keychainQuery(); query[kSecReturnData as String] = true
        var result: CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary,&result) == errSecSuccess else { return nil }; return result as? Data
    }
    private static func saveKeychain(_ data: Data) throws {
        let query = keychainQuery()
        let status = SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query; insert[kSecValueData as String] = data; insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(insert as CFDictionary,nil) == errSecSuccess else { throw CloudError(message:"Could not securely save sign-in.") }; return
        }
        guard status == errSecSuccess else { throw CloudError(message:"Could not securely save sign-in.") }
    }
}

@MainActor final class NativeCloudSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, ASWebAuthenticationPresentationContextProviding {
    private var continuation: CheckedContinuation<(String,String),Error>?
    private var nonce = ""
    private var web: ASWebAuthenticationSession?
    func apple() async throws -> (String,String) {
        nonce = UUID().uuidString + UUID().uuidString
        let hash = SHA256.hash(data:Data(nonce.utf8)).map { String(format:"%02x",$0) }.joined()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest(); request.requestedScopes = [.fullName,.email]; request.nonce = hash
            let controller = ASAuthorizationController(authorizationRequests:[request]); controller.delegate = self; controller.presentationContextProvider = self; controller.performRequests()
        }
    }
    func google(configuration: BackendConfiguration) async throws -> (String,String) {
        let verifier = UUID().uuidString.replacingOccurrences(of:"-",with:"") + UUID().uuidString.replacingOccurrences(of:"-",with:"")
        let challenge = Data(SHA256.hash(data:Data(verifier.utf8))).base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")
        var components = URLComponents(url:configuration.url.appendingPathComponent("auth/v1/authorize"),resolvingAgainstBaseURL:false)!
        components.queryItems = [.init(name:"provider",value:"google"),.init(name:"redirect_to",value:"matmind://auth"),.init(name:"code_challenge",value:challenge),.init(name:"code_challenge_method",value:"s256")]
        return try await withCheckedThrowingContinuation { continuation in
            web = ASWebAuthenticationSession(url:components.url!,callbackURLScheme:"matmind") { url,error in
                Task { @MainActor in
                    defer { self.web = nil }
                    if let error {
                        let failure = error as NSError
                        let cancelled = failure.domain == ASWebAuthenticationSessionError.errorDomain && failure.code == ASWebAuthenticationSessionError.Code.canceledLogin.rawValue
                        continuation.resume(throwing: cancelled ? CloudSignInError.cancelled : error)
                        return
                    }
                    guard let url else { continuation.resume(throwing: CloudSignInError.invalidCallback); return }
                    do { continuation.resume(returning: (try GoogleOAuthCallback.authorizationCode(from: url), verifier)) }
                    catch { continuation.resume(throwing: error) }
                }
            }
            web?.presentationContextProvider = self
            if web?.start() != true { continuation.resume(throwing:CloudError(message:"Could not open sign-in.")); web = nil }
        }
    }
    func authorizationController(controller: ASAuthorizationController,didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential, let token = credential.identityToken, let string = String(data:token,encoding:.utf8) else { continuation?.resume(throwing:CloudError(message:"Missing Apple identity token.")); continuation = nil; return }
        continuation?.resume(returning:(string,nonce)); continuation = nil
    }
    func authorizationController(controller: ASAuthorizationController,didCompleteWithError error: Error) { continuation?.resume(throwing:error); continuation = nil }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { anchor() }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor() }
    private func anchor() -> ASPresentationAnchor { UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor() }
}

/// Enable HTTPS generation only after the host's association file and fallback
/// routes are deployed and verified. Existing custom-scheme links still work.
enum InvitationLinks {
    static func make(kind: String, token: String, host: String?, httpsEnabled: Bool) -> URL {
        var components = URLComponents()
        if httpsEnabled, let host, !host.isEmpty {
            components.scheme = "https"
            components.host = host
            components.path = "/" + kind + "/" + token
        } else {
            components.scheme = "matmind"
            components.host = kind
            components.path = "/" + token
        }
        return components.url!
    }
}
