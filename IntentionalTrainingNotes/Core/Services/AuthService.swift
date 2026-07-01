import AuthenticationServices
import Foundation
import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

// MARK: - Auth

enum AuthError: LocalizedError {
    case cancelled
    case noPresentationAnchor
    case unsupportedProvider
    case missingGoogleSDK
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in was cancelled."
        case .noPresentationAnchor:
            return "Could not find a window for sign in."
        case .unsupportedProvider:
            return "This sign-in provider is not available."
        case .missingGoogleSDK:
            return "Google Sign-In is not configured for this build."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

protocol AuthServicing {
    func signInWithApple(completion: @escaping (Result<UserAccount, AuthError>) -> Void)
    func signInWithGoogle(completion: @escaping (Result<UserAccount, AuthError>) -> Void)
    static func handleOpenURL(_ url: URL) -> Bool
}

final class AuthService: AuthServicing {
    private lazy var appleCoordinator = AppleSignInCoordinator()
    private lazy var googleCoordinator = GoogleSignInCoordinator()

    func signInWithApple(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        appleCoordinator.signIn(completion: completion)
    }

    func signInWithGoogle(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        googleCoordinator.signIn(completion: completion)
    }

    static func handleOpenURL(_ url: URL) -> Bool {
        GoogleSignInCoordinator.handleOpenURL(url)
    }
}

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var completion: ((Result<UserAccount, AuthError>) -> Void)?

    func signIn(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        self.completion = completion

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion?(.failure(.unsupportedProvider))
            completion = nil
            return
        }

        let formatter = PersonNameComponentsFormatter()
        let displayName = credential.fullName.map { formatter.string(from: $0) }?.nilIfBlank
        let account = UserAccount(
            provider: .apple,
            providerSubjectId: credential.user,
            email: credential.email,
            displayName: displayName
        )
        completion?(.success(account))
        completion = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            completion?(.failure(.cancelled))
        } else {
            completion?(.failure(.underlying(error)))
        }
        completion = nil
    }
}

final class GoogleSignInCoordinator {
    static var isConfigured: Bool {
        #if canImport(GoogleSignIn)
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String
        let hasClientID = clientID?.nilIfBlank != nil && clientID?.contains("REPLACE") == false
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let hasURLScheme = urlTypes.contains { type in
            let schemes = type["CFBundleURLSchemes"] as? [String] ?? []
            return schemes.contains { !$0.contains("REPLACE") && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        return hasClientID && hasURLScheme
        #else
        return false
        #endif
    }

    func signIn(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        #if canImport(GoogleSignIn)
        guard Self.isConfigured else {
            completion(.failure(.missingGoogleSDK))
            return
        }

        guard let rootViewController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            completion(.failure(.noPresentationAnchor))
            return
        }

        let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                completion(.failure(.underlying(error)))
                return
            }

            guard let user = result?.user else {
                completion(.failure(.unsupportedProvider))
                return
            }

            let profile = user.profile
            let subject = user.userID ?? profile?.email ?? UUID().uuidString
            completion(
                .success(
                    UserAccount(
                        provider: .google,
                        providerSubjectId: subject,
                        email: profile?.email,
                        displayName: profile?.name
                    )
                )
            )
        }
        #else
        completion(.failure(.missingGoogleSDK))
        #endif
    }

    static func handleOpenURL(_ url: URL) -> Bool {
        #if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
        #else
        return false
        #endif
    }
}
