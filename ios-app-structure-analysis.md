# iOS App Structure Analysis: IntentionalTrainingNotes

## Overview

This is a SwiftUI-based iOS app for training notes. The "black screen with Google OAuth sheet on launch" is **by design** — the app follows a state-based routing architecture that shows different views based on authentication status.

---

## App Launch Flow

### 1. **Entry Point: AppDelegate + SceneDelegate**

**AppDelegate.swift** (28 lines)
```swift
@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    // Minimal setup - delegates to SceneDelegate
    // Handles OAuth redirect URLs via AuthService.handleOpenURL()
}
```

**SceneDelegate.swift** (22 lines)
```swift
final class SceneDelegate: UIWindowSceneDelegate {
    var window: UIWindow?
    private let sessionStore = AppSessionStore()
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, ...) {
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: RootView(sessionStore: sessionStore)  // ← Root view
        )
        self.window = window
        window.makeKeyAndVisible()
    }
}
```

**Key Point:** The `AppSessionStore` is created here and passed to `RootView`. This initializes the app's state management.

---

## State Management: AppSessionStore

**Location:** Lines 808-908 in IntentionalTrainingNotes.swift

```swift
final class AppSessionStore: ObservableObject {
    @Published private(set) var route: AppRoute = .signedOut
    @Published private(set) var account: UserAccount?
    @Published private(set) var notebookStore: NotebookStore?
    @Published var errorMessage: String?
    
    init(
        accountStore: AccountStore = KeychainAccountStore(),
        authService: AuthServicing = AuthService(),
        persistenceFactory: @escaping (String) -> NotebookPersistence = ...
    ) {
        self.accountStore = accountStore
        self.authService = authService
        self.persistenceFactory = persistenceFactory
        restore()  // ← Attempts to restore saved session
    }
    
    func restore() {
        guard let restored = accountStore.loadAccount() else {
            account = nil
            notebookStore = nil
            route = .signedOut  // ← If no saved account, shows WelcomeView
            return
        }
        activate(account: restored)
    }
}
```

### App Routes (Enum)
```swift
enum AppRoute: Equatable {
    case signedOut              // Shows WelcomeView (login screen)
    case signedInMissingProfile // Shows ProfileSetupView
    case ready                  // Shows MainAppView (app content)
}
```

---

## Root View Routing

**Location:** Lines 1159-1202 in IntentionalTrainingNotes.swift

```swift
struct RootView: View {
    @ObservedObject var sessionStore: AppSessionStore
    @ObservedObject private var networkStatus = NetworkStatusStore()
    
    var body: some View {
        Group {
            if sessionStore.route == .signedOut {
                // Show login screen
                WelcomeView(
                    errorMessage: sessionStore.errorMessage,
                    isOffline: networkStatus.isOffline,
                    showsGoogleSignIn: GoogleSignInCoordinator.isConfigured,
                    onGoogle: { signIn(provider: .google) }
                )
            } else if sessionStore.route == .signedInMissingProfile {
                // Show profile setup
                ProfileSetupView(...)
            } else if let notebookStore = sessionStore.notebookStore {
                // Show main app
                MainAppView(sessionStore: sessionStore, store: notebookStore)
            } else {
                // Error state
                WelcomeView(...)
            }
        }
        .accentColor(.black)
    }
}
```

---

## WelcomeView: The Login Screen

**Location:** Lines 1206-1265

This is what displays on first launch (the "white screen with Google OAuth button"):

```swift
struct WelcomeView: View {
    var errorMessage: String?
    var isOffline: Bool = false
    var showsGoogleSignIn: Bool = true
    var onGoogle: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            // Logo area with dashed circles
            ZStack {
                Circle().stroke(...).frame(width: 300)
                Circle().stroke(...).frame(width: 210)
                VStack(spacing: 18) {
                    Text("Intentional\nTraining Notes")
                        .font(.system(size: 30, weight: .semibold))
                    VStack {
                        Text("Welcome to Intentional Training Notes")
                        Text("Train with more intentionality.\nGet better, faster.")
                    }
                }
            }
            Spacer()
            
            // Auth buttons area
            VStack(spacing: 10) {
                if let statusMessage = statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(errorMessage == nil ? .secondary : .red)
                }
                
                // Google Sign-In Button
                Button(action: onGoogle) {
                    HStack {
                        Text("G")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Continue with Google")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())  // Black button, white text
                
                Text("By continuing you agree to our Terms & Privacy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(Color.white.edgesIgnoringSafeArea(.all))  // ← WHITE background
    }
}
```

**Visual Layout:**
```
┌─────────────────────────────────┐
│                                 │
│    (dashed circle logo)         │
│    "Intentional Training Notes" │
│    "Train with more intent..."  │
│                                 │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ G  Continue with Google     │ │  (Black background, white text)
│ └─────────────────────────────┘ │
│                                 │
│ "By continuing you agree..."    │
│                                 │
└─────────────────────────────────┘
```

---

## Authentication Flow

### Google Sign-In Setup

**GoogleSignInCoordinator** (Lines 737-804)

```swift
final class GoogleSignInCoordinator {
    static var isConfigured: Bool {
        // Check if GoogleClientID and URL scheme are properly set
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String
        let hasClientID = clientID?.nilIfBlank != nil && 
                         clientID?.contains("REPLACE") == false
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let hasURLScheme = urlTypes.contains { type in
            let schemes = type["CFBundleURLSchemes"] as? [String] ?? []
            return schemes.contains { 
                !$0.contains("REPLACE") && 
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            }
        }
        return hasClientID && hasURLScheme
    }
    
    func signIn(completion: @escaping (Result<UserAccount, AuthError>) -> Void) {
        // 1. Get root view controller
        guard let rootViewController = UIApplication.shared.windows
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            completion(.failure(.noPresentationAnchor))
            return
        }
        
        // 2. Configure GIDSignIn with clientID
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        // 3. Present Google OAuth sheet
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            // Handle result
        }
    }
}
```

**Info.plist Configuration:**
```xml
<key>GoogleClientID</key>
<string>523055768394-20kj4rgm70vmohh0bebegvu13hdqmv1a.apps.googleusercontent.com</string>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.523055768394-20kj4rgm70vmohh0bebegvu13hdqmv1a</string>
        </array>
    </dict>
</array>
```

**Note:** The Google Sign-In SDK automatically presents a native iOS sheet (modal) when `signIn()` is called. This sheet has a dark/black background.

---

## Why "Black Screen with Google OAuth Sheet"?

When you launch the app for the first time:

1. **AppSessionStore.restore()** is called
2. Keychain lookup finds no saved account
3. `route` is set to `.signedOut`
4. **RootView** displays **WelcomeView** (white background screen)
5. User taps "Continue with Google"
6. **GoogleSignInCoordinator.signIn()** is called
7. **Google Sign-In SDK presents a native iOS modal sheet** (this has a dark/black theme)

```
App Launch
    ↓
SceneDelegate creates UIWindow
    ↓
RootView(sessionStore: AppSessionStore)
    ↓
AppSessionStore.init() → restore()
    ↓
KeychainAccountStore.loadAccount() → nil
    ↓
route = .signedOut
    ↓
RootView renders WelcomeView
    ↓
User taps "Continue with Google"
    ↓
GoogleSignInCoordinator.signIn(withPresenting: rootViewController)
    ↓
GIDSignIn SDK presents native OAuth sheet (iOS modal, dark background)
    ↓
User completes OAuth
    ↓
AppSessionStore.completeSignIn() saves account to Keychain
    ↓
route = .signedInMissingProfile or .ready
    ↓
RootView rerenders based on new route
```

---

## File Structure

```
IntentionalTrainingNotes/
├── AppDelegate.swift              (28 lines)
│   └── Minimal setup, handles OAuth URLs
│
├── SceneDelegate.swift            (22 lines)
│   └── Creates window, instantiates AppSessionStore, shows RootView
│
├── IntentionalTrainingNotes.swift (2987 lines)
│   ├── Formatters & Extensions
│   ├── NetworkStatusStore (connectivity monitoring)
│   ├── Domain Models (AuthProvider, AppRoute, Belt, Mood, UserAccount, UserProfile, etc.)
│   ├── AuthService & AuthServicing protocol
│   │   ├── AppleSignInCoordinator (ASAuthorizationController)
│   │   └── GoogleSignInCoordinator (GIDSignIn)
│   ├── AppSessionStore (state management, restore logic)
│   ├── NotebookStore (training data management)
│   ├── RootView (routing based on AppRoute)
│   │   ├── WelcomeView (login screen, white background)
│   │   ├── ProfileSetupView (onboarding)
│   │   └── MainAppView (main app content)
│   ├── Style definitions
│   │   ├── PrimaryButtonStyle (black background, white text)
│   │   ├── SecondaryButtonStyle
│   │   └── Various UI components
│   └── Preview providers
│
├── Info.plist
│   ├── GoogleClientID
│   ├── CFBundleURLTypes (Google OAuth redirect scheme)
│   └── Scene configuration pointing to SceneDelegate
│
└── Assets.xcassets/
    └── AppIcon.appiconset/
```

---

## Key Technical Details

### 1. **State Restoration on Launch**
- `AppSessionStore.init()` calls `restore()`
- `restore()` checks `KeychainAccountStore` for saved account
- If account exists, loads it; otherwise shows `.signedOut` route

### 2. **OAuth Coordination**
- Google Sign-In uses native iOS SDK (`GoogleSignIn` framework)
- Presents modal sheet automatically
- OAuth URL scheme in Info.plist handles callback (`com.googleusercontent.apps.523055768394-20kj4rgm70vmohh0bebegvu13hdqmv1a`)

### 3. **Session Persistence**
- Accounts stored in Keychain (KeychainAccountStore)
- Training data stored as JSON (JSONNotebookPersistence)
- Both keyed by account ID

### 4. **View Hierarchy**
- `RootView` acts as single source of truth for routing
- All state changes flow through `AppSessionStore`
- View updates automatically via `@Published` properties

---

## Potential Issues & Observations

### ✅ What's Working
- State restoration logic is solid
- OAuth coordination handles both Apple and Google
- Network status monitoring
- Profile setup flow for new users

### ⚠️ Potential Issues

1. **Black Screen on App Refresh**
   - If Keychain data is cleared but app doesn't restart
   - If `restore()` fails silently
   - If `route` state isn't persisted correctly

2. **OAuth Sheet Presentation**
   - Requires valid rootViewController
   - Can fail if window isn't key when button tapped
   - URL scheme mismatch between app and Google credentials

3. **Missing Persistence Check**
   - No visible indication that app is checking Keychain on launch
   - User might see blank screen briefly

### 🔧 Debugging Steps
1. Check Keychain data: `security find-generic-password -a`
2. Verify Info.plist GoogleClientID matches Firebase console
3. Check URL schemes in Xcode Build Settings
4. Add logging to `AppSessionStore.restore()`
5. Verify Google SDK is initialized before button tap

---

## Summary

The "black screen with Google OAuth sheet" is the Google Sign-In SDK's native modal. The app is functioning as designed:

1. **On first launch:** Shows white WelcomeView (login screen) → user sees Google button
2. **User taps Google:** Native iOS sheet appears (dark background, part of Google SDK)
3. **After OAuth:** App saves account and shows either ProfileSetupView or MainAppView

If this is happening unexpectedly, check:
- Info.plist GoogleClientID and URL schemes
- Keychain access permissions
- Whether `AppSessionStore.restore()` is properly detecting saved accounts

---

## UI/UX Enhancements (Implemented — May 2026)

Five improvements shipped to make the app more usable on iPhone:

### 1. ✅ Removed Google Provider Field from Profile
**What changed:** ProfileSetupView no longer shows the DashedPanel with Google provider label, display name, and email. Only first name and last name fields remain — cleaner onboarding.

### 2. ✅ Inline Expandable Tasks Under Goals
**What changed:** Goals on the main screen now expand/collapse in place to show tasks, instead of navigating to a separate GoalDetailView.
- Tap goal header → expands to show task list with "X days this wk" counts
- Tap a task → navigates directly to TaskTimelineView
- Inline "Add task" TextField at bottom of expanded card
- Chevron rotates with animation on expand/collapse

### 3. ✅ Auto-Populate Goal/Task in Plan Training
**What changed:** When tapping "Plan Training" from within a specific task's timeline, PlanTrainingView now pre-selects that goal and task. User can still change selections.
- Added `initialGoalId` / `initialTaskId` params to PlanTrainingView
- TaskTimelineView passes context through to MainAppView routing

### 4. ✅ Enhanced Reflection Session Cards
**What changed:** ReflectPickSessionStep cards now show:
- Date prominently formatted as "MMM d" (e.g., "May 10") on the left
- Goal name as secondary label on the right
- Task names on individual lines instead of dot-separated string

### 5. ✅ Task Timeline Organized by Week
**What changed:** TaskTimelineView replaced flat "Up next" / "Completed" split with:
- **Latest section** pinned at top — single most recent session regardless of status
- **Weekly groups** below — "This Week", "Last Week", or "Week of MMM d"
- Sessions sorted by date descending within each week
- Status indicators (planned vs done) on each row
- Uses existing `Calendar.mondayStartOfWeek(containing:)` utility

### Layout Fixes (Earlier)
- Added `UILaunchScreen` to Info.plist (fixed letterboxing/zoomed mode on modern iPhones)
- Force light mode with `.preferredColorScheme(.light)`
- Extended backgrounds into safe areas
