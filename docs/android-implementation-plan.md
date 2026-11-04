# Mat Monkey for Android: implementation and beta plan

Prepared 2026-11-04. Planning only: this document changes no app code, cloud configuration, website or store listing.

Baseline: `tienmai56/Calculated-Reps`, branch `claude/determined-gates-thq12f`, commit `fbc1e827` ("Add monkey avatars after member names (#60)").

**Evidence labels used throughout**

| Label | Meaning |
| --- | --- |
| **[Repo]** | Verified by reading this repository at the baseline commit. |
| **[Doc]** | Claimed in repository documentation (for example `docs/mat-mind-v2-deployment.md`). Not independently verified against the hosted project. |
| **[Assume]** | Planning assumption. Change the plan if it is wrong. |
| **[Verify]** | Needs a check in an account, dashboard, hosted project or physical device before anyone relies on it. |

---

## 0. Recommendation in plain English

**Build a native Android app in Kotlin with Jetpack Compose, and keep the SwiftUI iOS app as it is.** The backend is already platform-neutral. Every client action goes through one Supabase RPC, `command(operation, payload, idempotency_key)`, plus a few read RPCs, Storage and one Edge Function. The iOS client talks to these endpoints over plain HTTPS without a Supabase SDK. An Android client can call the same endpoints with no changes to authorization or data rules.

The Android work comes down to:

1. **Port the client.** That means about 370 lines of networking (`MatMind/Data/BackendClient.swift`), about 230 lines of model logic (`MatMind/App/SocialAppModel.swift`), the snapshot-to-UI mapping in `LiveMatMindRuntime` (`MatMind/App/MatMindRoot.swift`), and roughly 12,500 lines of SwiftUI screens and design system under `Prototypes/MatMind/`, which become Compose.
2. **Make two small, backward-compatible backend changes** so push works on Android: device registration needs to record a provider, and `notification-worker` needs FCM support.
3. **Make two website changes** so links work on Android: serve `assetlinks.json`, and send Android visitors somewhere other than the App Store.
4. **Set up the store and accounts:** Google Play Console, Firebase, Android OAuth clients and signing keys.

Rewriting iOS in Flutter or React Native, or moving it to Kotlin Multiplatform, would delay the Android beta without fixing anything that is currently broken.

**Realistic timeline** [Assume: one coding agent doing the implementation, you as product owner, reviewer, account holder and tester, plus part-time help from a second human engineer for review if possible]:

- Internal Play testing of the first full journey: about **5–7 weeks** of active work.
- Closed beta with the recommended scope: about **9–13 weeks**.
- If your Play developer account is a *personal* account created after 13 Nov 2023, production access needs a closed test with at least 12 testers opted in for 14 consecutive days, plus Google's review. That adds **at least 3 weeks** after the beta is stable ([Play Console Help 14151465](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en), checked 2026-11-04).

### Biggest blockers, in priority order

1. **Android push would break the current worker and could cause repeated iOS alerts.** [Repo]
   - `device_tokens.environment` only accepts `'sandbox'|'production'` (`supabase/migrations/202611020001_social.sql:19`).
   - `notification-worker` sends every token to APNs (`supabase/functions/notification-worker/index.ts`).
   - If an Android build registered an FCM token through today's `register_device`, APNs would reject it. Any non-410 response throws, so the whole job, including the recipient's iOS devices, is retried with backoff and no attempt cap (`claim_notifications` in `202611020002_operations.sql`). Invalid tokens are only removed on HTTP 410.
   - The worker also builds the APNs JWT *before* claiming any work. A missing or broken APNs secret therefore stops all delivery, Android included.
   - **Backend change required before any Android build registers for push.**
2. **Play Console account, identity verification and app signing are on the critical path.**
   - The Android OAuth client and `assetlinks.json` both need the Play app-signing certificate fingerprint, and that only exists after the app is created in Play Console with Play App Signing enabled.
   - Organization accounts need a D-U-N-S number, which "can take 30 days or more" ([Play Console Help 10841920](https://support.google.com/googleplay/android-developer/answer/10841920?hl=en), checked 2026-11-04).
3. **There is no staging backend.** [Repo/Doc] The only project referenced anywhere is the production project `cmiqavyrazypmulrfezj`. Android development and cross-platform tests need an isolated project.
4. **Hosted deployment state is unclear for nine migrations that the current iOS client already calls.** See §1.6. The Android client targets the same contract, so run `supabase migration list --linked` before building against it.
5. **The website sends every visitor without the app to the App Store, and there is no `assetlinks.json`.** [Repo/Doc] The site source is in another repository (`tienmai56/your-note-haven`) that this session cannot reach.
6. **Play policy gaps that also apply to iOS:**
   - No terms-of-use or community-guidelines acceptance before posting.
   - No way to unblock someone.
   - No web-based account-deletion route. Play requires one in addition to the in-app route ([Play Console Help 13327111](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)).
   - Reports land in `public.reports` with no tooling except manual review.
7. **Play reviewers need a way to sign in.** The app only offers Google sign-in, so you need a dedicated reviewer Google account, or a reviewer-only sign-in route. See the open questions in §9.

---

## 1. Current architecture and Android gap analysis

### 1.1 What is production and what is a prototype [Repo]

| Area | Path | Status | What it means for Android |
| --- | --- | --- | --- |
| iOS app entry | `IntentionalTrainingNotes/AppDelegate.swift` (`@UIApplicationMain`), `IntentionalTrainingNotes/SceneDelegate.swift` | **Production.** `SceneDelegate` builds `SocialAppModel()` and hosts `MatMindRoot(model:)`. It forwards URLs and universal links to `model.handle(_:)`. | Equivalent: `MainActivity` handling intents for links and notification taps. |
| Live root and runtime | `MatMind/App/MatMindRoot.swift`: `MatMindRoot`, `LiveProfileSetup`, `LiveMatMindRuntime: AppRuntime` | **Production.** Maps `SocialSnapshot` rows to UI models, runs mutations, uploads photos, routes links and notification taps. | Port the logic; this becomes repositories plus ViewModels. |
| Live state | `MatMind/App/SocialAppModel.swift`: `SocialAppModel` | **Production.** Session restore, single-flight snapshot refresh, account-scoped SwiftData cache and drafts, link redemption, streak calculation, logout and deletion. | Port the logic. |
| Backend client | `MatMind/Data/BackendClient.swift`: `BackendClient` actor, `CloudCredential`, `NativeCloudSignIn`, `InvitationLinks`, `GoogleOAuthCallback` | **Production.** Raw HTTPS, no Supabase SDK. | Port 1:1. This defines the backend contract. |
| Push | `MatMind/App/SocialPushCoordinator.swift`, plus the delegate methods in `AppDelegate.swift` | **Production.** APNs only. | Replace with FCM. |
| Legacy export | `MatMind/Archive/` (`LegacyArchive.swift`, `ArchiveZIP.swift`, `ArchiveViews.swift`) | **Production, iOS-only legacy.** Exports the old on-device notebook and imports goals from that export. | **Do not port.** Android has no legacy notebook data. |
| Old live screens | `MatMind/Features/SocialScreens.swift`, `MatMind/Features/ProfileFriendsScreens.swift` | **Mostly dead code.** Only `LiveScannerView` (QR scanner) is referenced outside this folder. `SocialActivityScreen`, `SocialCreateScreen` and the rest have no references. | Ignore, except as a reference for QR scanning and the camera. |
| Shared UI (the "prototype") | `Prototypes/MatMind/` (`App/AppShell.swift` `MMAppShell`, `App/AppModel.swift` `AppModel`/`AppRuntime`, `Features/*`, `DesignSystem/*`) | **Production UI.** Compiled into both the production target and the `MatMindPrototype` scheme. `AppModel(live: true)` starts empty. | This is the visual and behavioral source of truth to port to Compose. |
| Prototype-only parts | `Prototypes/MatMind/App/SeedData.swift`, `DemoPanel.swift`, `ComponentGallery.swift`, `MatMindPrototypeApp.swift`, `PreviewAssets.xcassets` | **Prototype and debug only.** Release builds exclude the sample photos (checked by `scripts/check-release-assets.py`). | Optional Android debug preview later. Never ship it in release builds. |
| Browser companions | `Prototypes/WelcomePreview`, `EmptyPreview`, `FocusPreview` (`serve.py`), `ui_kits/app/index.html`, `flows.html`, `design-system/components/*.jsx` | **Design references only**, not production. | Useful for visual review and for checking user journeys. |
| Legacy notebook app | `IntentionalTrainingNotes/Core/*`, `Features/*`, `App/RootView.swift`, `AuthViews.swift`, `MainAppView.swift` | **Legacy iOS-only.** Kept so the archive can be read and migrated. `RootView` is no longer the root. | **Do not port.** |
| Backend | `supabase/migrations/*.sql` (21 files), `supabase/functions/{delete-account,notification-worker}/index.ts`, `supabase/tests/*.sql` | Shared. | Reuse. Two additive changes (§4). |
| Website | `website-link-handoff/` (static reference); the real site is in `tienmai56/your-note-haven` | AASA only. | Add `assetlinks.json` and an Android fallback. |
| CI | `.github/workflows/mat-mind.yml`: iOS archive and tests on `macos-26-intel`, SQL tests on Postgres 17, Edge Function tests on Node 24 | iOS and backend only. | Add an Android workflow. |

> The user-supplied context said SwiftData holds "account-scoped caches/drafts". That matches the repo. However, **goals are stored in `UserDefaults`** (`matmonkeys.goals.<account>`, `Prototypes/MatMind/App/AppModel.swift` `loadGoals`/`persistGoals`), with photos under `Application Support/MatMonkeysGoalPhotos` (`MatGoal.photoRoot`, `Models.swift`). They are not in SwiftData. The one-time "monkey prompt" flag is also in `UserDefaults`. Goals are **device-local**: they don't sync between a member's devices. Only the *shared copy* of a goal (`publish_goal`) is stored on the server.

### 1.2 Runtime architecture (iOS, production) [Repo]

```
SceneDelegate ─► MatMindRoot(model: SocialAppModel)
                   ├─ AppModel(live:true)  ◄── UI state for all shared screens (MMAppShell)
                   │     └─ runtime: LiveMatMindRuntime (AppRuntime protocol)
                   └─ SocialAppModel
                         ├─ BackendClient (actor; Keychain credential; single-flight refresh)
                         ├─ snapshot: SocialSnapshot  (one RPC returns everything visible)
                         └─ ModelContainer(CachedSocialState, LocalSocialDraft)  (SwiftData)
```

- **Read model.** `rpc/snapshot` returns `profiles, friendships, sessions, activity_sessions, participants, posts(30), tags, likes, comments(300), credits, media, notifications(100), shared_goals, goal_shares, circle, follows, server_time` (latest definition: `20261104160002_upcoming_activity_sessions.sql`). Older pages come from `feed_page`, `post_details`, `comment_page` and `partners_of`. There is no realtime connection: data refreshes on foreground, pull-to-refresh, after each write, and when a push arrives.
- **Write model.** `rpc/command` takes `{operation, payload, idempotency_key}` (an idempotency key lets the server recognise a retried request and return the original result instead of applying it twice). The server serializes each member's commands with an advisory lock, stores a receipt (same key and same payload return the stored result; same key with a different payload raises an error), and rate-limits to 120 commands per minute, with comments capped at 20 per minute. RLS plus `SECURITY DEFINER` commands enforce every rule on the server.
- **Operations the client calls** (35 in total): `save_profile, set_username, set_monkey, create_session, edit_session, edit_session_details, manage_participant, cancel_session, set_rsvp, session_token, join_link, friend_token, redeem_friend, prepare_media, complete_and_publish, correct_attendance, edit_post, delete_post, remove_tag, set_like, add_comment, delete_comment, report_post, report_comment, read_notifications, register_device, unregister_device, block_user, set_follow, publish_goal, share_goal, goal_token, redeem_goal_link, respond_goal_share, unshare_goal`.
- **Auth.**
  - Google sign-in uses Supabase hosted OAuth with PKCE in `ASWebAuthenticationSession`, redirecting to `matmind://auth` (`NativeCloudSignIn.google`). The code exchange goes to `auth/v1/token?grant_type=pkce`.
  - Before opening the sign-in sheet, the app reads `auth/v1/settings` and checks that Google is enabled (`requireGoogleSignIn`).
  - After signing in, the client verifies the account through `auth/v1/user` and requires its ID to match the token's user before saving (`accept`).
  - Tokens are refreshed 60 seconds before `exp`. A refresh is also triggered by a 401, or by a Storage 400/403 whose message indicates an expired JWT. Only one refresh runs at a time, and the client refuses a refresh that comes back for a different user (`refreshCredential`).
  - The Apple sign-in code path exists but is hidden (`signIn(provider:"apple")` via the `id_token` grant).
- **Credential storage.** The credential is kept in the Keychain (service `com.tienmai.matmind.cloud`, account `session`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). The local cache is keyed by user ID and is deleted on logout.
- **Media.**
  - Session photos go through `prepare_media` (the server picks the object key) → `POST storage/v1/object/session-photos/<key>` → `complete_and_publish(media_id)`. If an upload fails, the client downloads the object and compares bytes, so a retry is safe.
  - Avatars go to `avatars/<uid>/<uuid>.jpg`. Shared goal photos go to `goal-media/<uid>/<sha256>.jpg`.
  - All three buckets are private and accept JPEG only (10 MB for session photos and goal media, 5 MB for avatars). Downloads use `storage/v1/object/authenticated/...`.
- **Links.**
  - `InvitationLinks.parse` accepts `https://<AppLinkHost>/<friend|session|goal>/<64 hex>` and `matmind://<kind>/<64 hex>`.
  - Info.plist has `AppLinkHost=matmindbjj.lovable.app` and `AppLinksEnabled=true`. (`docs/mat-mind-v2-deployment.md` still says `false`. `website-link-handoff/README.md` and the plist say `true`, and the plist is what ships.)
  - The pending link is held **in memory only** (`SocialAppModel.pendingLink`) and redeemed after sign-in and profile setup.
- **Push tap routing** (`MatMindRoot.openNotification`): `invite`/`joined` open the session, `friend` opens the friend, `goal_share` opens the shared goal, and everything else (`published, comment, like, mention`) opens the post.
- **Streaks are computed on the client** (`SocialAppModel.streak`, `LiveMatMindRuntime.sync`). The server stores `friendship_session_credits.week_start` (`rebuild_credits`). The client counts consecutive ISO weeks (Monday start, `minimumDaysInFirstWeek=4`) in the *friendship's* time zone, relative to the snapshot's `server_time`. Android must reproduce this exactly.
- **Focus outlines live inside `sessions.note`** (`SessionNoteCodec`, `Prototypes/MatMind/App/TrainingFocus.swift`): the prefix `matmind-focus-v1:` followed by base64 of JSON `{note, focus:[{id(UUID), title, children}]}`. Android must encode and decode this byte-compatibly.

### 1.3 Main user journeys (production)

1. **Welcome → Google → profile setup** (photo, name, optional phone, gym, belt, then the monkey meet/build/reveal steps) → push permission prompt.
2. **Plan a training:** date, time, gym, note, optional focus outline (goal tags), friend invites, and privacy (friends only, or anyone with the link) → invitations and notifications.
3. **Activity:** "Coming up" link-visible tickets from friends (join from the feed), and posts from completed sessions with likes, comments, @mentions, report, delete and edit.
4. **Training:** Upcoming and Past tabs; RSVP; organizer edit (details, focus, guests); cancel; share or copy the invite link.
5. **Complete & share:** choose attendees, take or pick a photo, caption → post → streak tick animation.
6. **Friends:** my QR code or share link, scan a partner's code, friend profile, streak belt, partner lists, follow, block.
7. **Goals (device-local):** create, break into parts, notes, links and photos. Share with friends or by link, and accept or decline goals shared with you.
8. **Profile/Settings:** edit profile, avatar, username, monkey, notifications, sign out, delete account, export legacy data (iOS only).

### 1.4 Dependencies

- **iOS** [Repo]: Apple frameworks only (SwiftUI, SwiftData, AuthenticationServices, CryptoKit, PhotosUI, VisionKit `DataScannerViewController`, CoreImage QR generation, UserNotifications, LocalAuthentication for the archive). No third-party packages.
- **Backend:** Supabase Auth, PostgREST, Storage, Edge Functions (Deno), `pg_cron`, `pg_net` and Vault for the worker schedule [Doc: `docs/mentions-push-rollout-plan.md`].
- **External:** Google Cloud OAuth (web client `523055768394-…` is the iOS client in Info.plist; a separate web client sits in Supabase [Doc]), the APNs key, Lovable hosting for `matmindbjj.lovable.app`, and App Store listing `id6767997652`.

### 1.5 Reuse, port, or change

| Reuse directly (no change) | Port to Kotlin (same behavior) | Needs backend or web change |
| --- | --- | --- |
| All tables, RLS, `command` operations, `snapshot`/`feed_page`/`post_details`/`comment_page`/`partners_of`/`invitation_preview`, Storage buckets and policies, `delete-account` | `BackendClient` (auth grants, refresh, retries, error mapping), `InvitationLinks`, `GoogleOAuthCallback` (if the Custom Tabs fallback is used), `SessionNoteCodec`, `TrainingFocusTree`, streak calculation, snapshot→UI mapping (`LiveMatMindRuntime.sync`), photo pipeline (resize, strip EXIF, JPEG), idempotent publish | `device_tokens` provider column plus a new `register_push_device` command (§4.4) |
| Design tokens: `.claude/design-system-spec.json`, `DESIGN.md` | Design system components (`Prototypes/MatMind/DesignSystem/Components/*`: 20 components), patterns, fonts (`Prototypes/MatMind/Resources/Fonts/*.ttf`), Lucide icons (`assets/icons/*.svg` → vector drawables), Silverback brand (`assets/brand/`) | `notification-worker`: FCM sender, lazy APNs, per-device results, attempt cap, invalid-token cleanup (§4.4) |
| SQL test harness (`supabase/tests/*.sql`, `scripts/test-database.sh`) | All feature screens in `Prototypes/MatMind/Features/*` | Website: `/.well-known/assetlinks.json`, Android-aware fallback for `/friend|session|goal/*`, web account-deletion page (§4.5, §7) |
| `scripts/test-*.mjs` pattern for Edge Function tests | Monkey avatar renderer and builder (`Features/Profile/MonkeyScreens.swift`) | Supabase Auth: Google provider client-ID list for native ID tokens (§4.1) |

### 1.6 Backend deployment status (evidence, not proof)

| Migration | Documented status | What it means for Android |
| --- | --- | --- |
| `202611020001`–`202611020005` (social, operations, feed, device registration, permissions) | Deployed 1–2 Nov [Doc] | Base contract. |
| `20261102190144_profile_setup` | Deployed 2 Nov [Doc] | Avatars, phone. |
| `202611030001_push_and_reports` | Deployed 3 Nov [Doc] | Likes, friend notifications, `report_comment`. |
| `20261103170658_username_mentions`, `20261103184940_name_based_usernames` | Deployed 3 Nov [Doc] | Mentions. |
| `20261104085624_invitation_previews` | Applied [Doc: `website-link-handoff/README.md`] | Web previews. |
| `20261104120000_goal_sharing` | **"Not deployed yet"** [Doc] | Goal sharing. |
| `20261104140001_edit_session_guests` | **"Not deployed yet"** [Doc] | `edit_session_details`. |
| `20261104160002_upcoming_activity_sessions` | "Apply … before shipping this UI" [Doc: README] | Activity "Coming up". |
| `20261103200000_post_needs_photo_or_note`, `20261103220518_persistent_friend_codes`, `20261104130000_notify_added_participants`, `20261104140000_delete_comments`, `20261104150000_people_and_follows`, `20261104160000_partner_lists`, `20261104160001_preserve_people_and_session_commands`, `20261104170000_monkey_avatars` | **Not mentioned** in the deployment docs | The current iOS UI calls `delete_comment`, `set_follow`, `partners_of` and `set_monkey`. |

**[Verify]** Run `supabase migration list --linked` and `supabase functions list` against `cmiqavyrazypmulrfezj`. Several later migrations patch `command` with `pg_get_functiondef` text replacement (for example `20261104170000_monkey_avatars.sql`), so they must be applied **in order**. A gap breaks later migrations. Android should target the contract the hosted project actually has, and degrade gracefully when an operation fails with "Unknown command", the same way the repo designed `edit_session_details`.

### 1.7 Incomplete or pending work that could block Android

| Item | Evidence | Impact |
| --- | --- | --- |
| No FCM path; APNs-only schema and worker | §0 blocker 1 | **Blocks Android push.** |
| No staging project | Only `cmiqavyrazypmulrfezj` is referenced | Blocks safe testing. |
| Website: no `assetlinks.json`, App Store-only fallback, separate repo | `website-link-handoff/README.md` | Android `https` links open the browser, and the fallback is wrong. |
| Pending link not persisted | `SocialAppModel.pendingLink` is in memory | Invitations are lost if the process dies during sign-in. Fix on Android, and consider fixing on iOS. |
| No terms/UGC acceptance, no unblock | No matches for "terms", "guidelines" or "unblock" in `Prototypes/`, `MatMind/` | Play UGC policy requires Terms acceptance and reporting/blocking ([Play UGC policy](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en)). |
| No web account deletion | No route in the repo | Play Data safety requirement. |
| Goal sharing and session editor migrations reportedly undeployed | §1.6 | Android features that depend on them stay behind feature flags. |
| `snapshot` returns every RLS-visible profile, 300 comments and so on in one payload | `20261104160002_…sql` | Fine for a beta. A larger payload on slow Android networks raises the importance of caching. |
| `push_enabled` column has no UI toggle | `docs/mentions-push-rollout-plan.md` | Not a blocker. |
| Worker retries with no cap; `last_error` is the only signal | `index.ts`, `claim_notifications` | Fix alongside FCM. |

### 1.8 Legacy iOS-only features vs. current product requirements

- **Legacy, do not port:** the notebook (`IntentionalTrainingNotes/Core`, `Features/{Notes,Reflect,Plan,Bounty,Stats,Home,Onboarding}`), speech-to-text reflections, daily reflection reminders (removed in `AppDelegate`), Settings → Export local sessions (ZIP), Goals → Import from that export, and Face ID-gated archive access. None of this data exists on Android, and none of it reaches the server.
- **Current requirements:** everything in §1.3. Goals are current, but device-local. An Android member starts with no goals, even if they have goals on an iPhone. Say so in beta notes. Syncing private goals is a separate product decision (§9).

---

## 2. Architecture recommendation

### 2.1 Options compared

**Staffing assumption** [Assume]: one coding agent writes most of the code. You review PRs, own every account and dashboard, and test on devices. Optionally a part-time senior human reviews Android and security PRs. There is no dedicated designer; `DESIGN.md` and the existing SwiftUI screens are the spec.

| Criterion | **A. Native Kotlin + Compose; keep SwiftUI** | B. Kotlin Multiplatform (shared logic, native UIs) | C. React Native / Flutter |
| --- | --- | --- | --- |
| Time to Android beta | **Shortest.** Port only Android. Backend is unchanged except push. | +2–4 weeks: KMP setup, iOS interop, and either a parallel iOS data layer or migrating iOS onto the shared module. | Longest if iOS migrates (~12.5k lines of SwiftUI plus live services rewritten and re-validated). If iOS doesn't migrate, you maintain three codebases. |
| Impact on the working iOS app | None | Medium–high: iOS's `BackendClient`/`SocialAppModel` would be replaced by Kotlin/Native code consumed from Swift. Risk for an app with live users and APNs. | Highest: full replacement and re-verification of push, links, Keychain and sign-in. |
| Code sharing | Contract shared through SQL, JSON fixtures and docs. Logic duplicated (about 1–1.5k lines of non-UI logic). | Networking, models, codec, streaks and links shared. UI not shared. | UI and logic shared. |
| Platform integrations (Credential Manager, FCM, App Links, photo picker, ML Kit scanner, edge-to-edge, predictive back) | First-class, current APIs | First-class on Android; Swift interop costs on iOS | Through plugins. Credential Manager nonce support, the photo picker and edge-to-edge rely on third-party plugin quality. |
| Ecosystem maturity | Very high | Production-ready, but tooling and interop are harder for a small team | High, but plugin dependency risk |
| Ongoing maintenance | Two UIs and two logic layers. Mitigated by shared contract fixtures. | Two UIs, one logic layer, plus KMP build complexity | One codebase plus plugin and platform-upgrade churn |
| Risk | Low; logic is small and well specified | Medium | High |

**Recommendation: option A.** The shared logic is small. The data contract is already concentrated server-side in `command`, RLS and `snapshot`. The iOS app works and has live users. Where duplication creates risk (focus codec, streaks, link parsing, row decoding), control it with **shared test vectors** in a new `contract/` directory that both XCTest and JUnit read. That gives most of KMP's correctness benefit without touching iOS. Revisit KMP only if a third surface appears or the logic grows a lot.

### 2.2 Repository layout and module boundaries

Keep a single repository. The backend contract changes atomically with both clients, and CI already validates migrations here.

```
android/
  settings.gradle.kts            # includes the modules below
  gradle/libs.versions.toml      # version catalog: every dependency pinned
  gradle/wrapper/                # wrapper with distributionSha256Sum
  gradle/verification-metadata.xml
  build-logic/                   # convention plugins (android-app, android-lib, compose, kotlin-jvm)
  app/                           # Application, MainActivity, NavHost, DI graph, manifest, flavors, FCM service
  core/model/                    # pure Kotlin/JVM: rows, domain models, SessionNoteCodec, FocusTree,
                                 #   StreakCalculator, InvitationLinks, MentionParser, mappers
  core/network/                  # BackendClient (OkHttp + kotlinx.serialization), AuthApi, StorageApi
  core/data/                     # repositories, Room DB, credential store, WorkManager workers, photo pipeline
  core/designsystem/             # MM tokens, fonts, icons, the 20 components and patterns (Compose)
  feature/welcome/  feature/activity/  feature/training/  feature/create/
  feature/complete/ feature/friends/   feature/goals/     feature/profile/
  feature/notifications/
contract/                        # shared, platform-neutral test vectors (JSON)
  focus-codec.json               # iOS-encoded notes ↔ decoded trees
  invitation-links.json          # valid/invalid URLs → {kind, token}
  streaks.json                   # credits + friendship tz + server_time → current/best/weeks
  snapshot-sample.json           # representative snapshot for decoding tests
  mentions.json                  # UTF-16/emoji mention cases (mirror the XCTest cases)
docs/android-*.md
.github/workflows/android.yml
```

Start with `app`, `core:model`, `core:network`, `core:data` and `core:designsystem`. Features can begin as packages inside `app` and become modules once each one exists. That keeps build complexity low early on. `core:model` has no Android dependency, so its tests run quickly on the JVM.

### 2.3 Layers

- **UI:** Jetpack Compose with Material 3 used *only* as a foundation (ripple, accessibility semantics, text fields). Every visible style comes from MM tokens: Paper `#FAF6EF`, Ink, Coral, friend hues, Bricolage Grotesque, Archivo, JetBrains Mono, pill radii, 22–28 px cards, and the streak belt, tape and ticket patterns. Take values only from `.claude/design-system-spec.json` and follow the `mat-monkeys-design` skill. Light-first like iOS (`preferredColorScheme(.light)`). Generate `MMColor`/`MMType`/`MMSpacing` Kotlin objects from the JSON spec with a small script, so the two platforms can't drift.
- **Navigation:** Navigation Compose with type-safe routes. Routes mirror `AppModel.Route` (`.session(id)`, `.post(id)`, `.friend(id)`, `.sharedGoal(id)`, `.goal(id)`). Four tabs (Activity, Training, Goals, Profile) plus the center "Plan a training" action, per `DESIGN.md` §1. Use the system back stack and support predictive back (§5).
- **State:** One `SessionRepository` exposes `StateFlow<Snapshot?>` keyed by the signed-in account. Feature ViewModels derive UI state with `combine`/`map` (the Android equivalent of `LiveMatMindRuntime.sync`). Keep one `epoch` concept (`SocialAppModel.epoch`): every async result is dropped if the account changed while it was in flight.
- **Domain:** Pure functions in `core:model`. `SocialRow` is a `JsonObject` wrapper with `text/flag/number/date` accessors, matching the dynamic iOS row model. That lets the app tolerate added columns, which matters because migrations add columns often. Typed mapping happens at the edge.
- **Data:** Repositories call `BackendClient`. Writes go through `CommandRunner`, which owns the idempotency keys (§2.5).

### 2.4 Networking and backend compatibility

Write a thin client of about 400 lines that mirrors `BackendClient.swift`: OkHttp, kotlinx.serialization, coroutines and a `Mutex` for single-flight refresh. It needs only these endpoints: `auth/v1/settings`, `auth/v1/token?grant_type=id_token|pkce|refresh_token`, `auth/v1/user`, `auth/v1/logout`, `rest/v1/rpc/{snapshot,command,feed_page,post_details,comment_page,partners_of}`, `storage/v1/object/{bucket}/{key}` (POST), `storage/v1/object/authenticated/{bucket}/{key}` (GET) and `functions/v1/delete-account`.

- Headers: `apikey: <publishable key>`, `Authorization: Bearer <access_token>`, 30-second timeout.
- Refresh rules are copied exactly: refresh 60 seconds before `exp`, decoding `exp` from the JWT when `expires_at` is missing. Retry once after a refresh on a 401, or on a Storage 400/403 whose body says `InvalidJWT` or "jwt expired". Reject a refresh whose `user.id` changed.
- Error mapping: use `message` or `error_description` from the response; otherwise "Request failed (code)".
- **Why not `supabase-kt`?** It is viable: Supabase publishes a Kotlin reference including `signInWith(IDToken)` ([Supabase Kotlin reference](https://supabase.com/docs/reference/kotlin/v2/auth-signinwithidtoken), checked 2026-11-04). But the app uses about 12 endpoints with specific retry and identity-verification semantics that are already proven on iOS. A hand-written client is easy to audit, carries no dependency risk, and keeps behavior identical on both platforms. Revisit if Realtime is adopted.
- **Contract tests:** a JVM test suite runs the client against a MockWebServer with recorded responses. An optional staging smoke test (§6) runs real commands.

### 2.5 Local persistence, drafts, offline and retries

| Concern | iOS today | Android plan |
| --- | --- | --- |
| Snapshot cache | SwiftData `CachedSocialState(owner, payload)` | Room table `snapshot_cache(owner PK, json, saved_at)`. Restored before the first network refresh. Deleted on logout. |
| Drafts (planning, completion) | SwiftData `LocalSocialDraft(key="<uid>:<key>")` | Room `drafts(owner, key, json, updated_at)`, plus `SavedStateHandle` for in-progress forms so they survive process death. |
| Goals (local) | `UserDefaults` JSON per account, photos in `Application Support/MatMonkeysGoalPhotos` | Room `goals`/`goal_parts` per owner. Photos in `filesDir/goal-photos/<owner>/`. Excluded from cloud backup unless you decide otherwise. |
| Downloaded images | Temporary files keyed by media ID | Coil 3 with a custom fetcher that adds auth headers, a disk cache in `cacheDir/images/<owner>` cleared on account change, and keys of `bucket/objectKey`. |
| Write retries | Idempotency keys held in memory per session or photo (`publishKeys`, `mediaKeys`) | **Persist** `(owner, intent, key, request_hash)` in Room, so a retry after process death reuses the same key and the server's receipt dedupes it. Publish runs as a WorkManager `CoroutineWorker` (`prepare_media` → upload → verify-on-error → `complete_and_publish`) with exponential backoff and a network constraint. Interactive commands stay in the foreground with a visible error, matching iOS. |
| Offline | Shows the cache; writes fail with an alert | Same. Show a banner when offline. Planning and completion drafts persist. No offline queue for social writes in beta, except publish. |

### 2.6 Secure session storage and account isolation

- Store `CloudCredential {access_token, refresh_token, user.id, expires_at}` as an AEAD-encrypted blob, using a non-exportable **Android Keystore** AES-GCM key (directly, or through Tink). Keep it in a private file or DataStore. **[Verify at bootstrap]**: `androidx.security:security-crypto` (`EncryptedSharedPreferences`) has been deprecated, so don't adopt it.
- Exclude the credential, the snapshot cache and drafts from Auto Backup and device transfer (`android:dataExtractionRules` / `fullBackupContent`). A restored token on a new device should not sign the user in. This matches iOS's `ThisDeviceOnly`.
- **Account isolation:**
  - Every Room row carries an `owner` column.
  - The image cache directory is per owner.
  - The logout order matches iOS: bump the epoch → clear UI state → delete the owner's cache rows → `unregister_push_device` → `FirebaseMessaging.deleteToken()` → `auth/v1/logout` → wipe the credential.
  - Notification taps carry the recipient's user ID (add `recipient` to the push data, §4.4), and the app ignores taps meant for a different signed-in account.
- If the Keystore key is invalidated (for example, the lock screen is removed on some OEM devices), treat it as signed out. Never crash.

### 2.7 Dependency injection and environment configuration

- **Hilt** for DI: it's standard, integrates with WorkManager (`@HiltWorker`) and ViewModels, and makes test substitution easy. For a very small codebase a manual `AppContainer` would also work. Hilt is recommended because WorkManager and instrumentation tests benefit from it.
- **Product flavors** `staging` and `prod`; build types `debug` and `release`:
  - `stagingDebug`: applicationId `<base>.staging.debug`, staging Supabase, debug-only tools (preview mode, log export).
  - `stagingRelease`: applicationId `<base>.staging`, staging backend, R8 on; for App Distribution.
  - `prodRelease`: applicationId `<base>`; the only variant uploaded to Play.
- Per-flavor `BuildConfig` fields: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `GOOGLE_WEB_CLIENT_ID`, `APP_LINK_HOST`, `APP_LINKS_ENABLED`, `PLAY_STORE_URL`. Publishable keys and client IDs are not secrets, but keep them in `android/config/<flavor>.properties` so the flavors are explicit. `google-services.json` per flavor goes in `app/src/<flavor>/`. **Never** put the service-role key, worker secret, APNs key or FCM service-account JSON into any Android file.

### 2.8 Error reporting and minimal observability

- **Firebase Crashlytics.** You need Firebase for FCM anyway, and it's free.
  - Send no PII: no tokens, no names, no captions.
  - Set a custom key for the app environment, and a *hashed* account ID only if you want per-user triage (disclose it in Data safety).
  - Upload R8 mapping files from CI (Crashlytics Gradle plugin).
- Structured local logging through Timber in debug builds only. A "Copy diagnostic info" button in Settings: app version, versionCode, flavor, Android version, push permission state, last push registration result. No secrets.
- Backend: extend the worker to return `{processed, delivered, failed_by_provider}` and log provider error codes without tokens. Set alerts as recommended in `docs/mentions-push-rollout-plan.md` §6 (outbox oldest pending age, attempts).
- Play Console Android vitals (crash and ANR rates) once on a Play track.

---

## 3. Feature-by-feature implementation scope

Effort is in engineer-days for the coding agent with human review, including tests. Ranges cover review cycles. **Beta** = first external (closed) beta. **Int** = also in the first internal build.

| Feature | Current iOS implementation | Android work | Backend/web work | Beta? | Effort | Acceptance criteria |
| --- | --- | --- | --- | --- | --- | --- |
| Google sign-in | Hosted OAuth + PKCE, `ASWebAuthenticationSession` → `matmind://auth` (`NativeCloudSignIn.google`, `BackendClient.exchange`) | Credential Manager `GetSignInWithGoogleOption` → `id_token` grant with nonce (§4.1). Custom Tabs + PKCE as fallback. Provider-disabled check via `auth/v1/settings`. Cancellation returns to Welcome silently. | Supabase Google provider: confirm the web client ID is the accepted audience. Android OAuth clients per signing cert. | **Int** | 3–5 | Same Google account on iOS and Android resolves to the **same** `auth.users.id`. Cancel shows no error. Disabled provider shows the availability message. |
| Apple sign-in | Hidden (code retained) | None for beta | — | Defer | — | Apple-only accounts (if any exist) are told to use iOS. [Verify] count of `auth.identities where provider='apple'`. |
| Session restore, refresh, sign-out | Keychain, single-flight refresh | Keystore-encrypted store, `Mutex` refresh, logout order (§2.6) | — | **Int** | 2–3 | Expired access token refreshes transparently. A refresh returning a different user forces sign-out. Process death keeps the session. |
| Profile setup + monkey | `LiveProfileSetup` (details → meet → build → reveal), `save_profile`, `set_monkey`, avatar upload | Compose flow. Photo picker → square JPEG ≤5 MB, EXIF stripped. Monkey renderer and builder. E.164 phone validation matching iOS (`phoneValid`). | `monkey_avatars` deployed [Verify] | **Int** | 4–6 | A new account must finish setup before reaching tabs. An existing iOS profile skips setup. Monkey text matches the server regex. |
| Activity feed | `ActivityScreen`, `snapshot.posts`, `feed_page` pagination, `post_details` hydration, "Coming up" tickets | Lazy list, pagination, pull-to-refresh, foreground refresh, empty states from `Prototypes/README.md` | `upcoming_activity_sessions` deployed [Verify] | **Int** | 5–8 | iOS-created posts and tickets render identically (title, focus tags, people, monkey, photo). Pagination has no duplicates. |
| Post detail, likes, comments, delete/edit post | `set_like`, `add_comment`, `delete_comment`, `edit_post`/`delete_post` with `version` | Optimistic hide while delete is in flight, as on iOS | `delete_comments` deployed [Verify] | **Beta** | 3–5 | Version conflicts show "Post changed. Refresh before editing". Comment rate-limit errors are shown. |
| @mentions | Suggestions after `@`, UTF-16-safe insertion (XCTest) | `MentionParser` with shared vectors (`contract/mentions.json`) | — | **Beta** | 2–3 | Mentioning an iOS user notifies them once. Emoji text doesn't corrupt offsets. |
| Training (Upcoming/Past) | `TrainingScreen`, `SessionTicket` | Tabs, tickets, RSVP (`set_rsvp`), join from feed | — | **Int** | 3–5 | RSVP shows on iOS after refresh. Declined sessions leave Upcoming. |
| Plan a training (create) | `CreateScreen`, `create_session`, past-session logging via `manage_participant`, focus outline with goal tags, `PlaceSearch` gym chips | Date carousel, time pills, gym chips, note, focus editor, friend grid, privacy. Timezone = `ZoneId.systemDefault().id` (IANA). | — | **Int** | 5–8 | iOS decodes the Android focus outline correctly, and the reverse. A past session requires attendance confirmation. |
| Edit session / guests / cancel | `edit_session` (focus), `edit_session_details` (guests), `cancel_session` | Edit sheet; handle "Unknown command" (older server) and stale `version` | `edit_session_guests` deployed — documented as **not deployed** [Verify] | **Beta** (flag) | 3–4 | Guest add/remove is atomic. A stale version produces the refresh prompt. |
| Session invite links | `session_token` → https link → share sheet / copy | `Intent.ACTION_SEND`, clipboard (Android 13+ shows its own confirmation) | assetlinks + Android fallback | **Beta** | 1–2 | A link made on Android opens iOS and the reverse. |
| Complete & share (photo) | `CompleteScreen`, `prepare_media` → upload → `complete_and_publish`, camera or library, JPEG 0.8 | Photo picker (no media permission), camera via `TakePicture` with a FileProvider URI, resize, EXIF strip, WorkManager publish with persisted keys | — | **Int** | 4–6 | Killing the app mid-upload and relaunching yields **one** post. Photo is visible to iOS attendees only. GPS EXIF is absent from the uploaded JPEG. |
| Correct attendance, remove tag | `correct_attendance`, `remove_tag` | Post options | — | Beta | 1 | Server rules enforced; errors shown. |
| Friends via QR / link | `friend_token` (persistent code), CoreImage QR, VisionKit scanner, `redeem_friend` | QR rendering (ZXing core), scanning with **Google code scanner** (`GmsBarcodeScanning`, no camera permission) with ML Kit + CameraX fallback | — | **Int** | 3–5 | An Android phone scans an iOS QR and connects, and the reverse. Expired or blocked links show "Link expired or unavailable". |
| Streaks | Client-side ISO-week calculation in friendship timezone | `StreakCalculator` with shared vectors including DST and year boundaries | — | **Int** | 2–3 | Identical current/best/weeks to iOS for the same snapshot (contract test). |
| Friend profile, partner lists, follow, circle search | `ProfileScreen`, `partners_of`, `set_follow`, `circle` | Friend profile and partners list for beta. Follow/search later. | `people_and_follows`, `partner_lists` deployed [Verify] | Partners **Beta**; follow/search defer | 2–4 | Following on iOS doesn't break Android (field ignored until implemented). |
| Goals (local) | `GoalsScreen` (~1,250 lines): parts, notes, links, photos (≤20 per part, 2048 px JPEG), reorder | Room-backed goals, photo picker multi-select, reorder, viewer | — | Beta 1.1 (fast follow) | 6–10 | Same feature set as iOS. Photos private. Data stays per account. |
| Goal sharing | `GoalSharing.swift`, `publish_goal`, `share_goal`, `goal_token`, `redeem_goal_link`, `respond_goal_share`, `unshare_goal`, `goal-media` | Beta: **receive, accept, decline and view** shared goals; open goal links. Later: share from Android. | `goal_sharing` documented **not deployed** [Verify]; website `/goal/:token` | Receive: Beta (if deployed); send: defer | 3–5 receive; 3–4 send | An iOS user shares a goal; the Android user accepts and sees parts and photos. |
| Notifications list | `read_notifications`, routing by `kind` | List, unread state, tap routing identical to `openNotification` | — | **Int** | 2 | Every kind (`invite, joined, published, comment, like, friend, mention, goal_share`) routes correctly. |
| Push notifications | APNs via `SocialPushCoordinator`, worker | FCM, `POST_NOTIFICATIONS` runtime prompt after profile exists, channels, foreground display, tap routing, token rotation, logout cleanup | **Required:** §4.4 migration + worker | **Beta** (Int after backend) | 3–5 app; 3–5 backend | §4.4 acceptance list. |
| Block | `block_user` from profile | Same entry point | — | **Beta** (policy) | 1 | A blocked user disappears; their links fail. |
| Unblock | **Missing** | Blocked-people list + unblock | New `unblock_user` command (additive) | **Beta** (recommended for UGC and support) | 1–2 + 1 | Unblocking restores the ability to reconnect (friendship isn't re-created automatically). |
| Report post/comment | `report_post`, `report_comment` → `public.reports` | Same | Moderation process: daily review (already documented); consider an email or Slack alert on new reports | **Beta** | 1 | Report reaches `public.reports` with the reason. |
| Terms / community guidelines | **Missing** | One-time acceptance screen before first post or comment; links in Settings | Hosted Terms and Privacy pages; optionally record acceptance (`account_settings.terms_accepted_at`) | **Beta** (Play UGC) | 1–2 | Can't post or comment until accepted; can't be skipped. |
| Username | `set_username` in Account | Same validation (3–40, `[A-Za-z0-9_]`) | — | Beta | 1 | Taken-name error shown. |
| Settings, sign out | Account sheet | Same | — | **Int** | 1–2 | — |
| Account deletion | `functions/v1/delete-account` | Same, with confirmation and retry messaging | **Web deletion request page** required by Play | **Beta** | 1 app; 1–2 web | Deleting removes Auth identity, data and media (`node scripts/test-delete-account.mjs` already covers the server). Web page linked in Data safety. |
| Legacy export / goal import | `MatMind/Archive/*` | **Not applicable** | — | N/A | — | — |
| UI preview mode (Debug) | `AppModel.uiReviewPreview()` | Optional `stagingDebug`-only sample data | — | Later | 2–3 | Never compiled into `prodRelease`. |
| Rich invitation previews (web) | `invitation_preview` RPC, PNG cards | — | Already platform-neutral | — | — | — |

### 3.1 Recommended first-beta scope

**Internal build (M3):** sign-in, profile setup with monkey, Activity, Training, plan/RSVP/join, complete and publish with photo, friends by QR/link, streaks, notifications list, settings/sign-out.

**Closed beta (M4–M6):** everything above, plus push (FCM), comments/likes/mentions, edit/cancel session, invite links over https, block + unblock, report, terms acceptance, username, account deletion (in-app and web), partner lists, receiving shared goals (only if that migration is deployed), and the Goals tab as a "Coming soon on Android" placeholder.

**Fast follow (Beta 1.1):** local Goals, then sharing goals from Android. **Later:** follow/search circle, debug preview mode, Apple sign-in on Android (only if needed), tablets and foldables, dark theme (iOS is light-only too).

**How deferred features affect iOS users:**

- **Goals:** iOS users can share a goal with an Android friend. If receiving isn't built, the Android user gets a `goal_share` notification that opens a "Goals are coming to Android" screen. Their share stays *pending* on iOS until they decline or accept later. Planning a session on Android shows no goal tags.
- **Follow/search:** iOS users can follow Android users; nothing breaks. Android users can't follow back yet.
- **Mentions:** if mention autocomplete slips, Android users still *receive* mentions (the server generates them) but must type the handle manually.
- **Apple sign-in:** hidden on iOS, so no current users depend on it [Verify].

---

## 4. Authentication, backend, push and links

### 4.1 Android Google sign-in

**Recommended path:** Credential Manager with Sign in with Google, then the Supabase `id_token` grant. This is the grant iOS already uses for Apple (`BackendClient.signIn(provider:idToken:nonce:)`), so the server path exists.

1. Generate a random raw nonce (32 bytes from `SecureRandom`, base64url).
2. Build `GetSignInWithGoogleOption.Builder(serverClientId = <existing Google *web* client ID configured in Supabase>).setNonce(sha256Hex(rawNonce))` for the explicit button, or `GetGoogleIdOption` for returning-user auto sign-in. Per the Android docs the server client ID is the **web** client ID, not the Android client ID ([Implement Sign in with Google](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation), checked 2026-11-04). Supabase documents giving Google the **hashed** nonce and giving `signInWithIdToken` the **raw** nonce ([Supabase: Sign in with Google](https://supabase.com/docs/guides/auth/social-sign-in/auth-google), checked 2026-11-04).
3. POST `auth/v1/token?grant_type=id_token` with `{"provider":"google","id_token":…, "nonce": rawNonce}`. Then run `auth/v1/user` identity verification exactly as `accept` does.
4. Keep nonce verification **enabled** in Supabase. Never use "skip nonce check".

**Google Cloud and Supabase configuration** (manual, §5):

- In the same Google Cloud project as the existing web client, create **Android** OAuth clients, one per package name and SHA-1 pair:

  | Identity | Package | Certificate | Purpose |
  | --- | --- | --- | --- |
  | Debug | `<base>.staging.debug` | Debug keystore SHA-1. Share one team debug keystore stored securely, or register each developer's. | Local development |
  | Local release / App Distribution | `<base>.staging` | Upload key (or a separate staging key) SHA-1 | Staging APKs |
  | Play | `<base>` | **Play App Signing key** SHA-1 (Play Console → Test and release → App integrity) | Every Play-installed build, internal testing included |
  | (Optional) Play upload key | `<base>` | Upload key SHA-1 | Only if you install locally signed prod builds |

- Supabase → Auth → Google provider: confirm the web client ID is in the accepted client IDs, so ID tokens with `aud=<web client>` validate. Android client IDs don't need to be listed there when `serverClientId` is the web client [Verify in dashboard].
- OAuth consent screen: `docs/google-sign-in-setup.md` mentions Testing mode and test users. While consent is in Testing, every Android tester's Google account must be on the test-user list [Verify publishing status].
- If staging uses a separate Supabase project, add its Google provider with the same web client (or a staging web client), and add the staging project's callback URL to that web client.

**Fallback path:** Custom Tabs, `auth/v1/authorize?provider=google&redirect_to=matmind://auth&code_challenge=…` (same as iOS), and a `matmind://auth` intent filter on a dedicated, `singleTop` callback activity. This needs no Android OAuth client and no SHA registration. It is a good plan B if Credential Manager hits device problems. Because a custom scheme can be claimed by another app, rely on PKCE, and persist the verifier in `SavedStateHandle` or encrypted storage so it survives process death while the browser is open.

**Preserving identities across platforms:** Supabase links an identity by provider plus the Google `sub`. Google's `sub` identifies the Google account, not the OAuth client, so iOS (hosted web client) and Android (ID token for the same web client) should resolve to the same `auth.users` row. **[Verify]** with two test accounts before beta: sign in on iOS, then on Android, and compare `userID`. A mismatch is a release blocker. If the projects differ, accounts would split.

**Other providers:** Apple is hidden on iOS. If it is ever re-enabled, Android would need Apple's web flow (Services ID + redirect) through Supabase hosted OAuth. Defer. **Reviewer access:** see §7.4 and §9.

### 4.2 Authorization, private media, server-authoritative rules

- No client-side authorization exists or is needed. Every rule lives in RLS and `command` (organizer checks, friend-only invites, blocks, attendance, rate limits). The Android client must not reimplement rules as a security measure, only as UX hints.
- Private media are fetched only through `storage/v1/object/authenticated/...` with the user's JWT. Never generate long-lived signed URLs on the client, and never cache media across accounts.
- Strip EXIF (GPS) by re-encoding through `Bitmap` → JPEG before upload. The buckets accept only `image/jpeg`. Convert HEIC and WebP inputs.
- **Never ship** `SUPABASE_SERVICE_ROLE_KEY`, `NOTIFICATION_WORKER_SECRET`, APNs keys, or the FCM service-account JSON. The publishable key (`sb_publishable_…`, already public in `Info.plist`) is the only Supabase key in the app.

### 4.3 Does an APNs failure block Android? [Repo]

Yes, in the current worker:

- `const jwt = await apnsJWT();` runs before `claim_notifications`. If any APNs secret is missing or malformed, the request returns 500 and **no job is claimed**. That would hold up Android deliveries once FCM is added to the same worker.
- Inside a job, any non-OK APNs response other than 410 throws. The whole job is retried, re-sending to devices that already received it. Today's iOS-only fan-out makes this rare; adding a second provider makes cross-provider duplicates likely.
- Attempts have no maximum. `next_attempt` is pushed back by up to an hour, forever.

### 4.4 FCM alongside APNs: backend plan (additive and compatible)

**Migration `supabase/migrations/<ts>_push_providers.sql`:**

```sql
-- Additive: existing rows and old iOS builds keep working unchanged.
alter table public.device_tokens
  add column provider text not null default 'apns' check (provider in ('apns','fcm')),
  add column created_at timestamptz not null default now(),
  add column last_seen_at timestamptz not null default now(),
  add column app_version text;
alter table public.device_tokens drop constraint device_tokens_environment_check;
alter table public.device_tokens add constraint device_tokens_environment_check
  check ((provider='apns' and environment in ('sandbox','production')) or (provider='fcm' and environment='production'));
create table public.notification_deliveries (       -- per-device idempotency for retries
  notification_id uuid references public.notifications on delete cascade,
  token text not null, delivered_at timestamptz not null default now(),
  primary key (notification_id, token));
-- command(): add a NEW operation 'register_push_device' {provider, token, environment, app_version}
--   insert … on conflict (token) do update set user_id=actor, provider=…, environment=…, last_seen_at=now()
-- Keep 'register_device' exactly as deployed (implicitly provider='apns') for shipped iOS builds.
-- 'unregister_device' already deletes by (actor, token): works for both providers.
-- erase_social_account already deletes device_tokens for the account.
-- Grants: service_role select/insert/delete on notification_deliveries; no app access.
```

Follow the repo's established pattern of patching `command` from `pg_get_functiondef` (see `20261104170000_monkey_avatars.sql`), and add a SQL test `supabase/tests/push_providers.sql` to CI.

**Why a new operation name:** an Android build that reaches a server without this migration gets "Unknown command" and simply doesn't register. It never inserts an FCM token that would be sent to APNs. The repo already uses this approach for `edit_session_details`.

**Worker changes (`supabase/functions/notification-worker/index.ts`):**

1. Load provider configuration lazily. An APNs JWT is built only if a claimed job has APNs devices. FCM uses a Google OAuth access token minted from a service-account secret `FCM_SERVICE_ACCOUNT_JSON` (RS256 JWT → `oauth2.googleapis.com/token`, cached for about 55 minutes). If a provider is unconfigured, only that provider's devices fail. Log `provider_unconfigured` and keep the job pending for those devices only.
2. Fan out per device and skip tokens already in `notification_deliveries` for that notification. Record each success.
3. Classify results:

   | Provider | Response | Action |
   | --- | --- | --- |
   | APNs | 410; 400 `BadDeviceToken`; `DeviceTokenNotForTopic` | Delete token |
   | APNs | 429, 5xx | Transient |
   | FCM v1 | 404 `UNREGISTERED`; 400 `INVALID_ARGUMENT` with a token-specific error when the payload is known valid | Delete token |
   | FCM v1 | 429, 5xx `UNAVAILABLE`/`INTERNAL` | Transient (honor `Retry-After`) |
   | FCM v1 | 403 `SENDER_ID_MISMATCH` / `PERMISSION_DENIED` | Configuration error; alert, don't delete |

   ([FCM error codes](https://firebase.google.com/docs/cloud-messaging/error-codes), [token management](https://firebase.google.com/docs/cloud-messaging/manage-tokens), checked 2026-11-04.)
4. Mark the job delivered when no transient failures remain. Otherwise back off. **Cap attempts** (for example 10), then set `delivered_at` with `last_error='abandoned'` so the outbox stays bounded. In-app notifications are unaffected.
5. FCM message (HTTP v1 `projects/<id>/messages:send`):
   ```json
   {"message":{"token":"…",
     "notification":{"title":"Mat Monkey","body":"Sarah liked your memory"},
     "data":{"kind":"like","entity_id":"…","actor":"…","recipient":"…","notification_id":"…"},
     "android":{"priority":"HIGH","collapse_key":"<job.id>",
       "notification":{"channel_id":"social","tag":"<job.id>","click_action":"OPEN_NOTIFICATION"}}}}
   ```
   Using `notification` plus `data` means the system shows the alert when the app is in the background or killed, and the tap delivers the `data` extras to the launch activity, which survives process death. In the foreground, `onMessageReceived` posts the same notification locally, matching the iOS `willPresent` banner behavior, and triggers a refresh. `tag` dedupes the displayed alert if a retry happens. Add `recipient` to the APNs payload too, which is harmless for old builds.
6. Extend `scripts/test-notification-worker.mjs` with mocked FCM: mixed providers, APNs-unconfigured with FCM working, 404 cleanup, 5xx retry without duplicate deliveries, attempt cap.

**Deployment order (each step safe on its own):** (1) migration → (2) worker with an empty `FCM_SERVICE_ACCOUNT_JSON` (APNs behavior unchanged; confirm with an iOS device) → (3) set the FCM secret → (4) ship the Android build that calls `register_push_device`. Rollback: redeploying the old worker is safe as long as no FCM tokens exist. If FCM tokens exist, first disable FCM sending by removing the secret; never revert the worker while FCM rows exist.

**Android client:**

- `FirebaseMessagingService.onNewToken` → enqueue a unique `RegisterPushWorker`. It sends `register_push_device` when signed in, and stores `(user, token)` as uploaded, the equivalent of iOS's `uploaded`. Re-register on every sign-in and on app start if more than 7 days have passed (updates `last_seen_at`).
- Ask for `POST_NOTIFICATIONS` (Android 13+) only after a profile exists, matching iOS. Keep a Settings button and deep-link to system settings once permission has been denied.
- Notification channels: `social` (likes, comments, mentions, published) and `invites` (invite, joined, friend, goal_share), so users control them separately.
- Multiple devices per user work already (`device_tokens` primary key is the token).
- Logout: `unregister_device(token)` → `deleteToken()`. Account deletion removes tokens server-side.

**Acceptance:**

- An iOS user likes an Android user's post: Android gets the alert within about 2 minutes (1-minute cron) and the tap opens the post.
- The reverse works.
- Breaking the APNs secret in staging still lets Android receive.
- An uninstalled Android app's token is removed after the first send.
- Signing out and then in as another account on the same phone delivers only to the new account.

### 4.5 Android App Links, QR and website fallback

**Manifest:** one `VIEW` intent filter with `android:autoVerify="true"` for `https://matmindbjj.lovable.app` and the path prefixes `/friend/`, `/session/` and `/goal/`. Include `http` as well, per Google's verification guidance. A separate, non-verified filter handles `matmind://friend|session|goal/*`, because older iOS builds, existing QR codes and messages may contain the custom scheme. Parse everything with the ported `InvitationLinks.parse` (same 64-hex-character and exact-path rules; test with `contract/invitation-links.json`).

**`assetlinks.json`** at `https://matmindbjj.lovable.app/.well-known/assetlinks.json` (in `tienmai56/your-note-haven`):

```json
[{"relation":["delegate_permission/common.handle_all_urls"],
  "target":{"namespace":"android_app","package_name":"<base>",
    "sha256_cert_fingerprints":["<PLAY APP SIGNING SHA-256>","<UPLOAD KEY SHA-256 (optional)>"]}},
 {"relation":["delegate_permission/common.handle_all_urls"],
  "target":{"namespace":"android_app","package_name":"<base>.staging",
    "sha256_cert_fingerprints":["<STAGING SIGNING SHA-256>"]}}]
```

Rules ([Configure website associations](https://developer.android.com/training/app-links/configure-assetlinks), [Verify App Links](https://developer.android.com/training/app-links/verify-applinks), checked 2026-11-04):

- Serve as `application/json` over HTTPS with no redirects.
- Use uppercase fingerprints. Take them from Play Console → App integrity, not from a local keytool run.
- Verify with `adb shell pm verify-app-links --re-verify <package>` and `adb shell pm get-app-links <package>`.
- **Firebase App Distribution AAB uploads are re-signed with a *test* certificate** ([App Distribution docs](https://firebase.google.com/docs/app-distribution/android/distribute-gradle?apptype=aab), checked 2026-11-04). Distribute **APKs** signed with the staging key there, or add that test certificate too.
- **[Verify]** that Lovable hosting can serve `/.well-known/assetlinks.json`. The AASA file is already served, so it probably can.

**Website fallback** (no app installed): today it shows the web summary plus an App Store link. Change it to detect Android:

- Before a public Play listing exists, show "Mat Monkey for Android is in beta. Ask for an invite or join here" with the Play testing opt-in URL (only works for invited or listed testers).
- After the listing is public, link to Play.
- Add an explicit **Open in Mat Monkey** button using an `intent://…#Intent;scheme=https;package=<base>;S.browser_fallback_url=…;end` URL for in-app browsers (Messenger, Instagram) that don't hand off App Links.
- Keep `invitation_preview` read-only, as it is now.

**Invitation continuation through sign-in:**

- On Android, persist the pending link (`kind`, `token`, received time) in encrypted DataStore with a 24-hour expiry. It must survive process death during Credential Manager or Custom Tabs sign-in and profile setup.
- Redeem it once `me != nil`, then clear it. Matches iOS behavior, but more robust.
- Recommend a follow-up iOS PR that persists `pendingLink` too.

**After installation (no deferred deep linking):** the app has no deferred deep-link mechanism, and none is planned for beta. A user without the app taps a link → website → Play → install → opens the app to Welcome with no context. The website and the app's empty states should say "Open your invitation link again after you sign in", the same approach iOS takes (`website-link-handoff/README.md` step 5). Optionally add a "Paste invitation link" field in Friends (QR scan already exists). Do **not** put bearer tokens into the Play Install Referrer or into analytics: they are capabilities.

**QR compatibility:** QR codes encode the full link (`friendCode()` returns `model.link(kind:"friend", …)`), and iOS currently generates https links. The Android scanner must accept both https and `matmind://`. Android-generated QR codes must use https (with `APP_LINKS_ENABLED`), so an iOS camera opens either the app or the website.

### 4.6 Compatibility with distributed iOS builds

- Only additive schema changes. `register_device` is unchanged. Old builds keep APNs registration and don't care about `provider`, `notification_deliveries` or `recipient` in the payload.
- The new `unblock_user` and optional `terms_accepted_at` are additive. Old iOS builds don't call them. Store-review timing for iOS is unaffected.
- `SessionNoteCodec` must stay byte-compatible: decode iOS output exactly, and emit JSON that Swift's `JSONDecoder` accepts. UUIDs as uppercase strings like Swift's encoder (Swift decodes either case), standard base64 with padding.
- Snapshot additions are optional fields on iOS (`shared_goals?`, `circle?`, etc.). Keep adding fields as optional, and never rename.

---

## 5. Developer tools and external setup checklist

Costs are from official pages where cited. Treat every price as **[Verify]** before paying.

| # | Item | Who | Where | Cost | Depends on | Verify by |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | **Google Play developer account** (personal or organization) | You | play.google.com/console | US$25 one-time ([Help 10841920](https://support.google.com/googleplay/android-developer/answer/10841920?hl=en)) | Government ID, card. Organization accounts also need D-U-N-S (free; can take 30+ days). | Console shows the account as verified. |
| S2 | Android developer verification status | You | Play Console / Android Developer Console | Included | S1 | Console shows verified identity. Enforcement on certified devices starts 30 Sep 2026 in BR/ID/SG/TH ([Android developer verification](https://developer.android.com/developer-verification), checked 2026-11-04). |
| S3 | Create the app in Play Console; enable **Play App Signing**; register an upload key | You (agent prepares the key-generation command) | Play Console → Create app → App integrity | — | S1, S5 | App signing key SHA-1 and SHA-256 visible on App integrity. |
| S4 | Choose a **permanent applicationId** | You decide; agent applies | `android/app/build.gradle.kts` | — | — | It can never change after first upload. Recommended `com.tienmai.matmonkey` (§9). |
| S5 | **Upload keystore** + backup | You (agent provides `keytool` command) | Local; then a password manager plus an offline encrypted backup; CI secret (base64) | — | — | `keytool -list -v` prints SHA-256; restore from backup tested once. If the upload key is lost, Play supports an upload-key reset, but it causes delays. |
| S6 | **Firebase project** (prod) and a **staging** Firebase project, or one project with two Android apps | You | console.firebase.google.com | FCM, Crashlytics and App Distribution are no-cost [Verify] | Google account; S4 | `google-services.json` per flavor downloaded; test message from the console arrives on a device. |
| S7 | FCM **service account** for the worker | You | Google Cloud IAM → service account with the FCM send role, key JSON → Supabase secret `FCM_SERVICE_ACCOUNT_JSON` | — | S6 | Worker staging test sends to a device. The key never appears in git or chat. Rotate it yearly. |
| S8 | **Android OAuth clients** (debug, staging, Play signing) | You | Google Cloud → Google Auth Platform → Clients, in the **same project** as the existing web client | — | S3, S5, debug keystore | Credential Manager returns an ID token on each variant. |
| S9 | Consent screen publishing status / test users | You | Google Auth Platform → Audience | — | — | A non-listed tester can sign in (if published), or the list is up to date. |
| S10 | **Staging Supabase project** | You (agent runs `supabase db push` with your approval) | supabase.com | Free tier may suffice; Pro plan around $25/month plus compute [Verify on pricing page] | — | All migrations applied; `delete-account` and `notification-worker` deployed; Google provider configured; cron schedule running. |
| S11 | Staging Google/FCM/APNs secrets | You | Supabase staging → Edge Function secrets; Vault for the cron secret | — | S6, S7, S10 | Worker returns `{processed: n}` and devices receive. |
| S12 | Test accounts: at least 4 Google accounts (2 iOS, 2 Android), plus a reviewer account | You | Google | Free | S9 | Each can sign in to staging. No production data used. |
| S13 | Website: `assetlinks.json`, Android fallback, web account deletion page, Terms/Privacy pages | Agent (in `your-note-haven`, if you attach that repo) + you to publish | `tienmai56/your-note-haven`, Lovable | — | S3 fingerprints | `curl -sI https://matmindbjj.lovable.app/.well-known/assetlinks.json` returns 200 `application/json`; Google's Statement List tester passes; `pm get-app-links` shows `verified`. |
| S14 | Privacy policy URL | You (agent drafts) | Website | — | Data inventory (§7.4) | Public URL loads; entered in Play Console. |
| S15 | **Android Studio** (latest stable), **JDK 17+** (bundled JBR is fine), Android SDK Platform **36**, Build-Tools, Platform-Tools, Emulator | Each developer | developer.android.com/studio | Free | — | `./gradlew --version`; `sdkmanager --list_installed` shows platform 36. |
| S16 | Gradle wrapper and AGP/Kotlin/Compose versions | Agent | `android/gradle/` | — | S15 | Pin the latest stable versions at bootstrap using the AGP↔Gradle↔JDK compatibility table [Verify that day]; record them in `android/README.md`. |
| S17 | Emulators: Pixel API 29, 33, 35, 36 with Google Play images | Developer | Device Manager | — | S15 | Credential Manager works on a Play image (it needs Google Play services). |
| S18 | Physical devices: at least one Pixel (current Android) and one Samsung mid-range (One UI), ideally one older device (Android 10–11) | You | — | Roughly $150–$450 each (used or mid-range) [Assume] | — | Installed through internal testing; push, links and camera work. |
| S19 | GitHub Actions secrets for Android | You | Repo settings → Secrets | — | S5, S6 | Signed `bundleProdRelease` succeeds in CI. Secrets: `ANDROID_UPLOAD_KEYSTORE_B64`, `ANDROID_UPLOAD_KEYSTORE_PASSWORD`, `ANDROID_UPLOAD_KEY_ALIAS`, `ANDROID_UPLOAD_KEY_PASSWORD`; optionally `PLAY_SERVICE_ACCOUNT_JSON` for upload. |
| S20 | Play Console API access (optional, for CI upload) | You | Play Console → Users and permissions + Google Cloud service account | — | S3 | `fastlane supply` or Gradle Play Publisher uploads to the internal track. |

**Platform defaults (code, agent-owned):**

- **minSdk 29** (Android 10) [Assume]: modern storage baseline, a smaller test matrix, and Credential Manager, the photo picker backport and Compose all support it. Lower it to 26–28 only if your target users need it (check Android Studio's API distribution, or Play Console device catalog data later).
- **targetSdk/compileSdk 36.** New apps and updates must target API 36 since 31 Aug 2026 ([Target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-GB), checked 2026-11-04). Plan for API 37 next year.
- **App icon:** adaptive icon (foreground Silverback from `assets/brand/` SVG, background Paper or Coral per `DESIGN.md` §5.1), a monochrome layer for themed icons, and a 512×512 Play icon.
- **Splash:** `androidx.core:core-splashscreen` with Paper background and the Silverback mark. No custom splash activity.
- **Fonts:** bundle the static `.ttf` files from `Prototypes/MatMind/Resources/Fonts/` (OFL) as `res/font`. Don't use downloadable fonts; offline parity matters.
- **Icons:** convert `assets/icons/*.svg` (Lucide, ISC) to vector drawables, keeping the regular/bold/filled variants used on iOS.
- **Permissions:**
  - `INTERNET` and `POST_NOTIFICATIONS`.
  - `CAMERA` only if you use CameraX (Google code scanner and `TakePicture` through an intent don't need it).
  - **No** `READ_MEDIA_IMAGES`: the photo picker covers every use, and Play restricts that permission ([Photo & Video Permissions](https://support.google.com/googleplay/android-developer/answer/16935362?hl=en), checked 2026-11-04).
  - No location.
- **Accessibility:** content descriptions for icon buttons, scalable `sp` type that respects font scale up to 200%, 48 dp touch targets, TalkBack labels for the streak belt and avatars (match iOS accessibility labels), and honor "Remove animations" the way iOS honors Reduce Motion (welcome photo float).
- **Back navigation:** predictive back is on by default for API 36 targets. Use `BackHandler`/`PredictiveBackHandler` only for unsaved-draft confirmation; never intercept `onBackPressed` ([Android 16 behavior changes](https://developer.android.com/about/versions/16/behavior-changes-16), checked 2026-11-04).
- **Edge-to-edge:** mandatory at API 36 with no opt-out. Handle `WindowInsets` for the system bars, IME (comment composer) and the center Plan button.

---

## 6. Testing and CI/CD

### 6.1 Automated tests (CI)

| Layer | What | Where | Tool |
| --- | --- | --- | --- |
| Unit (JVM) | `SessionNoteCodec` against iOS-produced vectors; `InvitationLinks` accept/reject; `StreakCalculator` (DST weeks, ISO week 53, friendship TZ ≠ device TZ, `server_time` vs device clock skew); `MentionParser` (UTF-16, emoji, ZWJ); snapshot row decoding with unknown fields; JWT `exp` parsing; refresh single-flight (10 concurrent 401s → one refresh); "user changed" refresh rejection; idempotency key reuse and new-key-on-changed-payload (`publishRequests` logic) | `android/core/*/src/test`, `contract/*.json` | JUnit5/Kotest, Turbine, MockWebServer |
| iOS parity | The same `contract/*.json` vectors read by XCTest | `IntentionalTrainingNotesTests/ContractVectorTests.swift` (new) | XCTest |
| Integration (Android) | Room migrations; credential encryption round trip; logout wipes owner rows; WorkManager publish worker survives a simulated process restart and reuses its key | `src/test` (Robolectric) and `src/androidTest` | Robolectric, WorkManager test helpers |
| UI | Compose screenshot tests for core components and key screens (empty states, tickets, post card, streak belt) at font scale 1.0 and 2.0; navigation and back-stack tests; notification-intent routing for every `kind` | `src/test` (Roborazzi or Paparazzi) / `androidTest` | Compose UI test |
| Backend contract | Existing SQL suites + new `push_providers.sql` and `unblock.sql`; worker tests with mocked FCM/APNs (`scripts/test-notification-worker.mjs`) | `supabase/tests`, `scripts` | Postgres 17, Node 24 |
| Staging smoke (nightly, optional) | Two scripted test users: create session → invite → RSVP → complete with photo → like/comment → check notifications rows; then delete both accounts | `scripts/staging-smoke.mjs` (new; staging URL and test credentials from CI secrets, **never** production) | Node |

### 6.2 Manual device acceptance (cross-platform)

Run each journey with one **Android** and one **iOS** account on staging, in both directions where it makes sense:

1. **Friendship:** Android scans the iOS QR; iOS scans the Android QR; an https friend link opens the app on both (installed) and the website (not installed); blocked users can't redeem.
2. **Invitations:** an iOS host invites the Android user (push + in-app) → Android RSVP → iOS sees "joined". A link-visible session from Android appears in iOS Activity "Coming up" and the reverse; joining from the feed works.
3. **Invitation through sign-in:** a signed-out Android user taps an iOS link → signs in → creates a profile → is joined. Repeat with the app killed during sign-in.
4. **Completion/photos:** the Android host completes with a camera photo; the iOS attendee sees the photo, the streak tick and the "published" push; no GPS EXIF in the stored object (download and inspect).
5. **Shared feed:** likes, comments and mentions in both directions; delete comment/post; edit-caption mention notifies only new people.
6. **Notifications:** foreground, background and killed-app taps route correctly; permission denied → in-app list still works; channel disabled → no alert.
7. **Blocking/reporting:** block on Android → iOS user loses access; report appears in `public.reports`; unblock.
8. **Deletion:** delete the Android account → iOS sees the posts and friendship gone; Android tokens removed; sign-in again creates a fresh profile.
9. **Robustness:**
   - Process death on each tab and mid-flow ("Don't keep activities" + `adb shell am kill`).
   - Session expiry (revoke the refresh token in the dashboard → graceful sign-out).
   - Denied camera and notification permissions.
   - Airplane mode and a throttled 3G profile (cache shows; publish retries).
   - Account switching on one device (no data or photo bleed; push goes only to the current account).
   - Device time zone ≠ friendship time zone; DST weekend.
   - Upgrade from the previous versionCode with data kept; fresh install vs upgrade.

### 6.3 Device matrix (practical)

| Tier | Devices / images | Purpose |
| --- | --- | --- |
| CI emulators | API 29 and API 36 (Google APIs, x86_64, through Gradle Managed Devices) | Instrumented tests on every PR (API 36) and nightly (both) |
| Physical, required | Pixel 7–9 class on Android 16; Samsung Galaxy A-series on its current One UI | Push, App Links, camera, Credential Manager, OEM battery behavior |
| Physical, recommended | One Android 10–12 device (Xiaomi or Motorola if available) | Older behavior, aggressive OEM task killing |
| Pre-launch report | Play Console pre-launch report (automatic on upload) | Crash and accessibility scan across Google's lab devices |

### 6.4 Build and release engineering

- **Reproducibility:**
  - Gradle wrapper with `distributionSha256Sum`.
  - Version catalog.
  - **Dependency locking** (`./gradlew dependencies --write-locks`, lockfiles committed).
  - **Dependency verification** (`gradle/verification-metadata.xml` with SHA-256).
  - JDK pinned via toolchains. CI uses `actions/setup-java` with the same distribution.
- **Static checks:** Android Lint (`warningsAsErrors` on new code), ktlint/Spotless, detekt, `./gradlew :app:checkReleaseManifest`-style assertions (no `READ_MEDIA_*`; `debuggable=false`; no cleartext traffic), plus a script equivalent to `scripts/check-release-assets.py` that proves `prodRelease` contains no sample data or debug tooling.
- **Versioning:**
  - `versionName` follows product versions (e.g. `1.0.0-beta.1`).
  - **`versionCode` is a monotonically increasing integer**, unique across all Play tracks. Play rejects reuse and a lower code can't replace a higher one on a device. Derive it from CI (e.g. `10000 + GITHUB_RUN_NUMBER`) or a checked-in counter bumped in the release PR. Never reset it.
  - To "roll back", rebuild the old commit with a **higher** versionCode.
- **Artifacts:**
  - `bundleProdRelease` (AAB, signed with the upload key) for Play.
  - `assembleStagingRelease` (APK, signed with the staging key) for App Distribution.
  - `assembleStagingDebug` for developers.
  - Keep R8 `mapping.txt` as a CI artifact (90 days) and upload it to Crashlytics (Gradle plugin). Play reads the deobfuscation mapping included with the bundle, or you upload it in App bundle explorer [Verify after first upload].
- **CI workflow `.github/workflows/android.yml`** (path-filtered to `android/**`, `contract/**`, the workflow file):
  - `ubuntu-latest` + `setup-java` + `gradle/actions/setup-gradle` cache.
  - `./gradlew spotlessCheck detekt lint testStagingDebugUnitTest verifyRoborazziStagingDebug assembleStagingDebug bundleProdRelease`.
  - Instrumented tests on Gradle Managed Device API 36 (KVM).
  - Signed bundle only on `main` with secrets present; unsigned otherwise, like the iOS job.
  - Optional manual `workflow_dispatch` job to upload to the internal track.
- **Automated vs manual:** CI covers everything in §6.1 plus build, lint, signing and artifact retention. Humans cover §6.2, Play Console forms, OAuth and App Links verification on installed Play builds, push on real devices, and the tester experience.

---

## 7. Android beta distribution

### 7.1 Routes compared

| Route | Artifact / signing | Good for | Limits |
| --- | --- | --- | --- |
| Direct APK (adb / file) | APK signed with debug or staging key | You and the agent on your own devices | No auto-update. Testers must allow unknown sources. Android developer verification starts 30 Sep 2026 in BR/ID/SG/TH on certified devices; Google's pages differ on how this applies to sideloaded apps from unregistered developers ([verification FAQ](https://developer.android.com/developer-verification/guides/faq?hl=en), checked 2026-11-04) [Verify]. Not for testers. |
| Firebase App Distribution | Staging APK (staging key). AABs are re-signed with a test key (breaks App Links and Google sign-in unless that cert is registered). | Fast staging builds for 2–10 trusted testers against **staging** | Up to 500 testers per project / 200 per group ([App Distribution](https://firebase.google.com/docs/app-distribution/android/distribute-gradle?apptype=aab)). Separate package ID from Play. |
| **Play internal testing** | Prod AAB (upload key) → Play App Signing | First real build with production identity (Google sign-in, App Links, FCM) | Up to 100 testers by email ([Help 9845334](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en), checked 2026-11-04). |
| **Play closed testing** | Same AAB | External beta (Google Groups or email lists) | Requires the store listing, Data safety, content rating and app access; review applies. For personal accounts this is also the 12-tester / 14-day gate before production. |
| Play open testing | Same AAB | Public beta | Public listing; only after the closed beta exit criteria are met. |

**Recommended progression:** direct APK (developers) → App Distribution (staging, optional) → **Play internal** (prod identity, you and close testers) → **Play closed** (external beta, 12+ engaged testers for at least 14 days) → open testing or production.

**Signing identities:** debug keystore (dev, `.staging.debug`) → staging key (`.staging`, App Distribution) → upload key (signs AABs you upload) → **Play app signing key** (what testers' devices see; drives OAuth SHA-1 and assetlinks SHA-256).

### 7.2 Ordered runbook: clean machine → tester using the app

1. **[You, today]** Create or confirm the Play developer account (S1–S2). If it's an organization account, request D-U-N-S now.
2. **[You]** Decide the applicationId (§9). **[Agent]** Bootstrap `android/` (M1), push, and get CI green.
3. **[You]** Install Android Studio, SDK 36 and an emulator; clone; `cd android && ./gradlew assembleStagingDebug installStagingDebug`.
4. **[You]** Create the staging Supabase project; the **agent** applies migrations to staging with your explicit approval; you configure the Google provider and secrets (S10–S11).
5. **[You]** Create the Firebase projects/apps and download `google-services.json` (S6). Create the debug and staging Android OAuth clients (S8).
6. **[Agent]** Implement M2–M3 against staging. **[You]** Install and sign in on a physical device.
7. **[You]** Generate the upload key (S5). Create the app in Play Console, accept Play App Signing, and record the app signing SHA-1/SHA-256 (S3). Create the Play Android OAuth client with the Play SHA-1 (S8).
8. **[Agent]** Backend push PR (migration + worker + tests). **[You]** Approve and deploy to staging, then production, in the order in §4.4; set `FCM_SERVICE_ACCOUNT_JSON`.
9. **[Agent + you]** Website PR: `assetlinks.json` (Play SHA-256 + staging), Android fallback, web deletion page, Terms and Privacy. You publish on Lovable and verify with curl and `pm get-app-links`.
10. **[You]** Play Console setup: app details, privacy policy URL, **App access** (reviewer instructions + test credentials), ads declaration (none), **content rating** questionnaire (user interaction / UGC → answer honestly), target audience (18+ or 13+, your decision; not designed for children), **Data safety** (§7.4), news/health declarations (none), store listing (short and full description, 512 px icon, 1024×500 feature graphic, at least 2 phone screenshots).
11. **[Agent]** Produce a signed `prodRelease` AAB through CI (versionCode N). **[You]** Upload it to **Internal testing**, add tester emails, and share the opt-in link.
12. **[Testers]** Open the opt-in link signed in with the listed Google account → "Become a tester" → install from Play → open → Continue with Google.
13. **[You]** Run §6.2 on the internal build (production backend, real test accounts) and fix issues with higher versionCodes.
14. **[You]** Create the closed testing track (Google Group recommended), invite 15–25 testers (to stay above 12 despite drop-offs), and roll the same versionCode into closed testing. Wait for review.
15. **[You]** Collect feedback (§7.5) for at least 14 days. If on a personal account, apply for production access after the exit criteria are met.

### 7.3 Initial beta access vs. later production access

- **Internal testing:** needs the app created, an AAB uploaded and testers listed. Which store-listing and policy declarations the console demands before an internal release can roll out was not confirmed here [Verify in console].
- **Closed testing:** needs the complete store listing, privacy policy, Data safety, content rating, target audience and app access, plus review.
- **Production (personal accounts created after 13 Nov 2023):** at least 12 testers opted in for 14 consecutive days, then an application whose review "usually takes seven days or less" ([Help 14151465](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en), checked 2026-11-04). Organization accounts are not subject to this gate [Verify for your account type in the console].
- **Target API 36** applies to every upload.

### 7.4 Policy content for Mat Monkey

- **Data safety inventory** (from the repo):

  | Data | Notes |
  | --- | --- |
  | Name, email (Google), user ID | |
  | Phone number (optional, private) | `account_settings.phone` |
  | Photos (session, avatar, goal) | |
  | User content | Captions, comments, session notes, gym names |
  | Social graph | Friends, follows |
  | Approximate time zone | |
  | Push tokens / device IDs | |
  | Crash logs | If Crashlytics |
  | Encryption and sharing | Encrypted in transit (HTTPS). Not sold. Shared only with service providers (Supabase, Google/Firebase). |
  | Deletion | In-app account deletion + **web deletion URL** (required, [Help 13327111](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)) |

  Disclose any retention, for example reports kept for safety review after deletion: today `erase_social_account` deletes the reporter's reports.
- **UGC:**
  - Terms acceptance before posting.
  - Report and block (separately labeled).
  - Timely action on reports. Commit to daily review, as `docs/mat-mind-v2-deployment.md` already notes for iOS.
  - Mentions and comments are a form of user-to-user interaction, so blocking must be available ([Play UGC policy](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en), checked 2026-11-04).
- **App access:** the app requires Google sign-in. Provide a dedicated reviewer Google account with a profile already created and a friend relationship and sample session already set up on **production** (clearly a test account; no real users' data). Google accounts with 2-step verification may block reviewers, so decide on the approach (§9).
- **Account deletion:** must be reachable in-app (exists) and on the web (to build).

### 7.5 Testers, feedback, support, updates

- **Recruitment:** existing iOS users who train with Android friends (cross-platform value), plus gym partners. Aim for 15–25 closed testers.
- **Invitation:** a Google Group `matmonkey-android-beta@…`. Send the Play opt-in URL plus a one-page guide: join the group with the same Google account used in Play, open the opt-in link, install, sign in with Google, allow notifications, then re-open any invitation link after signing in.
- **Feedback:**
  - Play's private feedback (testing tracks).
  - An in-app "Send feedback" item that opens an email with diagnostic info prefilled.
  - A short weekly form.
  - Crashlytics for crashes.
  - A pinned "known issues" note (Goals coming soon, no Apple sign-in).
- **Support:** one support email in the listing; respond within 2 business days; a dedicated channel for testers.
- **Updates:** ship weekly at most. Use release notes ("What's new") for every upload. Use staged rollout percentages once in production.

### 7.6 Exit criteria, rollout, incidents, recovery

- **Beta exit criteria:**
  - Crash-free users ≥ 99% over 14 days.
  - No open P0/P1 bugs.
  - All §6.2 journeys pass on both required physical devices.
  - Push delivery is confirmed for every notification kind.
  - Zero data or photo leakage across accounts in testing.
  - Reports are reviewed within 24 hours.
  - At least 12 testers stayed active for 14 days (personal accounts).
- **Rollout controls:**
  - Server-side: keep features that depend on undeployed migrations behind runtime capability checks ("Unknown command" → hide the feature).
  - Client-side: a small remote config, or simply the `stagingRelease` vs `prodRelease` flags at build time. Avoid adding a remote-config dependency in beta unless needed.
  - Push: removing `FCM_SERVICE_ACCOUNT_JSON` disables Android delivery without affecting iOS (after the worker change).
- **Incident response:**
  1. Halt the Play rollout (production) or pause the testing track.
  2. If the worker misbehaves, pause the cron job (`docs/mentions-push-rollout-plan.md` §6).
  3. Hotfix with **versionCode + 1** (you can't downgrade; to revert, rebuild the old code with a higher versionCode).
  4. Communicate to testers.
  5. Write a postmortem in `docs/`.
- **Recovery:**
  - Upload key lost → Play upload-key reset request.
  - Bad migration → forward-fix migration (never edit applied files, matching repo practice).
  - Corrupt local cache → the app wipes and refetches the snapshot cache on a decode failure. iOS reports an error for this case; Android should recover silently and log it.

---

## 8. Phased execution plan

Effort is in engineer-days of agent work including review iterations. Waiting time is calendar time spent on external processes.

### M0: Repository audit and decisions (this document) · 1 day · Owner: agent + you

- Tasks: review this plan; answer §9; run `supabase migration list --linked` and `supabase functions list` and record the results in `docs/android-implementation-plan.md` §1.6.
- Acceptance: decisions recorded; hosted migration state known.

### M1: Foundation · 5–8 days · Owner: agent (PRs), you (accounts)

| PR | Content | Files |
| --- | --- | --- |
| 1.1 | Gradle skeleton, version catalog, lockfiles, verification metadata, flavors, CI workflow | `android/**`, `.github/workflows/android.yml` |
| 1.2 | `core:model` + `contract/` vectors (focus codec, links, streaks, mentions, snapshot sample) with JVM tests; matching XCTest that reads the same vectors | `android/core/model`, `contract/`, `IntentionalTrainingNotesTests/ContractVectorTests.swift` |
| 1.3 | `core:network` BackendClient with MockWebServer tests (refresh, retry, error mapping) | `android/core/network` |
| 1.4 | Design system: token generation from `.claude/design-system-spec.json`, fonts, icons, the 20 components, screenshot tests | `android/core/designsystem`, `scripts/gen-android-tokens.py` |

- Verify: `cd android && ./gradlew spotlessCheck detekt lint testStagingDebugUnitTest assembleStagingDebug`.
- Depends on: S4 (applicationId), S15.
- Risks: picking toolchain versions (pin carefully); design fidelity (review against the prototype screens).
- External wait: none.

### M2: Staging backend and auth · 4–6 days agent; 1–3 days waiting

- Tasks: [You] S10–S12, S6, S8 (debug/staging). [Agent] Credential Manager sign-in, credential store, session restore, logout, profile setup + monkey, Welcome screen.
- Files: `android/feature/welcome`, `feature/profile`, `core/data/auth`.
- Acceptance: on a physical device, sign in to **staging**, create a profile, kill and relaunch, still signed in. The same Google account on iOS staging (debug iOS pointed at staging, or staging test users) maps to the same user ID. Sign out wipes data.
- Risks: OAuth SHA mismatches (error 10 / `DEVELOPER_ERROR`); consent-screen test-user limits.

### M3: First end-to-end journey · 10–15 days

- Tasks: Activity (feed, Coming up), Training, Plan a training (with focus), RSVP/join, Complete & share with photo (WorkManager publish), Friends QR/link + streaks, notifications list, Settings.
- Acceptance: §6.2 journeys 1, 2 and 4 pass Android ↔ iOS on staging; idempotent publish survives process death; screenshot tests are stable.
- Risks: photo pipeline on OEM devices; streak parity (covered by vectors).

### M4: Beta feature scope · 8–12 days agent (+ backend 3–5, web 2–3)

| PR | Content |
| --- | --- |
| 4.1 | **Backend push** migration + worker + tests (§4.4) |
| 4.2 | Android FCM client, channels, permission UX, tap routing |
| 4.3 | Comments, likes, mentions, edit/delete, report, block + `unblock_user` migration + UI |
| 4.4 | Terms acceptance; account deletion; username; partner lists; edit session/guests; receive shared goals (behind a capability check) |
| 4.5 | App Links + persisted pending link |
| 4.6 (website repo) | `assetlinks.json`, Android fallback, web deletion page, Terms/Privacy |

- Verify: `cat supabase/tests/bootstrap.sql supabase/migrations/*.sql supabase/tests/*.sql | psql …` (as in CI); `node scripts/test-notification-worker.mjs`; Android CI.
- Depends on: S3 (Play SHA for assetlinks), S7.
- Risks: deploying worker changes to production. Follow §4.4 ordering and confirm on an iOS device after each step.

### M5: Cross-platform validation · 4–6 days + device time

- Tasks: full §6.2 matrix on required devices; fix defects; accessibility pass (TalkBack, font scale 200%); performance on a mid-range Samsung (snapshot decode time, cold start < 2 s target).
- Acceptance: exit-criteria checklist drafted; zero P0/P1.

### M6: Internal distribution · 2–3 days agent; 1–7 days waiting

- Tasks: [You] S1–S3, S5, S8 Play client, S13–S14, Play Console forms. [Agent] release signing in CI, versionCode scheme, mapping uploads, release notes template, tester guide `docs/android-beta-testers.md`.
- Acceptance: a tester installs from the internal track and completes journeys 1–8 on **production** with test accounts; App Links verified on the Play-signed build; push from iOS → Android works in production.

### M7: External beta (closed testing) · 1–2 days setup; at least 14 days running

- Tasks: closed track, Google Group, recruitment, weekly updates, triage.
- Acceptance: §7.6 exit criteria → open testing or production application.

### Later improvements (not required for beta)

- Local Goals and goal sharing from Android.
- Follow/search circle.
- Realtime updates.
- Persist `pendingLink` on iOS.
- Server-side moderation alerts.
- Tablets and foldables.
- Debug preview mode.
- Baseline profiles for startup.
- Snapshot payload trimming.

### Critical path

```
Play account (S1/S2, D-U-N-S if org) ─► create app + Play App Signing (S3) ─► Play SHA-1/SHA-256
   ├─► Play Android OAuth client (S8) ─────────────┐
   └─► assetlinks.json on website (S13) ───────────┤
Staging Supabase (S10) ─► M2 auth ─► M3 journey ─► M4 (push backend needs S6/S7) ─► M5 ─► M6 internal ─► M7 closed (14+ days) ─► production
```

**Start these immediately (in parallel with M1):** S1/S2 (and D-U-N-S if organization), S4 decision, S10 staging project, S6 Firebase projects, S12 test accounts, plus asking for access to `tienmai56/your-note-haven` so the website PR can be prepared.

### Overall estimate

| Scope | Agent work | Calendar (with reviews and waiting) |
| --- | --- | --- |
| Internal build of the core journey (M1–M3) | 19–29 days | 5–7 weeks |
| Closed beta scope (M4–M6) | +17–29 days | 9–13 weeks total |
| Production access (personal account) | — | + at least 14 days testing + review (about 1 week) |

Recurring costs [Verify]:

| Item | Cost |
| --- | --- |
| Play | US$25 one-time |
| Firebase (FCM, Crashlytics, App Distribution) | $0 |
| Supabase staging | $0 (free tier) to about $35/month (Pro + small compute) |
| Production Supabase | Unchanged by Android, except slightly more traffic |
| Optional device purchases | $300–$900 one-time |

---

## 9. What I need to do first (prioritized checklist)

1. ☐ **Create or confirm your Google Play developer account** and start identity verification. Tell me whether it's **personal or organization** (organization: apply for D-U-N-S today).
2. ☐ **Pick the Android applicationId.** Recommended: `com.tienmai.matmonkey`. It's permanent, and nothing on Android depends on the old iOS bundle ID.
3. ☐ **Run and share** `supabase migration list --linked` and `supabase functions list` for `cmiqavyrazypmulrfezj`, so the actual deployed contract is known (§1.6).
4. ☐ **Create a staging Supabase project** and approve applying the migrations there.
5. ☐ **Create the Firebase project(s)** for prod and staging, with Android apps for the chosen package names.
6. ☐ **Attach `tienmai56/your-note-haven`** to a session (or grant access) so the `assetlinks.json`, Android fallback, Terms/Privacy and web deletion work can be prepared as a PR.
7. ☐ Check the **Google OAuth consent screen** publishing status and the test-user list.
8. ☐ Set up four Google test accounts (2 iOS, 2 Android) and get one physical Android phone.
9. ☐ Approve the **push backend change** (§4.4) as the first backend PR. It's needed before any Android push, and it also hardens iOS delivery.

### Open questions that materially change the plan

1. **Play account type (personal vs organization).** It decides whether the 12-tester / 14-day production gate applies, and whether D-U-N-S lead time is on the critical path.
2. **Reviewer and app access:** is a dedicated reviewer Google account (2-step verification considerations) acceptable, or do you want a restricted reviewer-only sign-in route (for example Supabase email/password limited to one account)? The second adds an auth provider and a security review.
3. **Goals in the first external beta:** ship with a placeholder (recommended; saves 6–10 days), or include local Goals? And should private goals eventually **sync** between devices? (Today they're device-only on iOS, which also affects iPhone → Android switchers.)
4. **Staging budget:** is a separate staging Supabase project acceptable? The alternative is testing on production with flagged test accounts, which is cheaper but riskier and not recommended.

---

## Sources (official; checked 2026-11-04)

- Play Console Help: [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- Play Console Help: [Set up an open, closed, or internal test](https://support.google.com/googleplay/android-developer/answer/9845334?hl=en)
- Play Console Help: [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-GB); Android Developers: [Meet Google Play's target API level requirement](https://developer.android.com/google/play/requirements/target-sdk)
- Play Console Help: [Verify your developer identity information](https://support.google.com/googleplay/android-developer/answer/10841920?hl=en); [Choose a developer account type](https://support.google.com/googleplay/android-developer/answer/13634885?hl=en)
- Android Developers: [Android developer verification](https://developer.android.com/developer-verification), [FAQ](https://developer.android.com/developer-verification/guides/faq?hl=en); Android Developers Blog: [Rolling out to all developers (March 2026)](https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html)
- Play Console Help: [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en); [Data safety section](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- Play Console Help: [User Generated Content policy](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en)
- Play Console Help: [Restricted permissions / photo picker](https://support.google.com/googleplay/android-developer/answer/16935362?hl=en)
- Android Developers: [Implement Sign in with Google (Credential Manager)](https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation); Google: [GetGoogleIdOption reference](https://developers.google.com/identity/android-credential-manager/android/reference/kotlin/com/google/android/libraries/identity/googleid/GetGoogleIdOption)
- Supabase: [Sign in with Google](https://supabase.com/docs/guides/auth/social-sign-in/auth-google); [Kotlin `signInWith(IDToken)`](https://supabase.com/docs/reference/kotlin/v2/auth-signinwithidtoken)
- Firebase: [FCM error codes](https://firebase.google.com/docs/cloud-messaging/error-codes); [Token management best practices](https://firebase.google.com/docs/cloud-messaging/manage-tokens); [App Distribution (Gradle, AAB)](https://firebase.google.com/docs/app-distribution/android/distribute-gradle?apptype=aab)
- Android Developers: [Configure website associations (assetlinks)](https://developer.android.com/training/app-links/configure-assetlinks); [Verify App Links](https://developer.android.com/training/app-links/verify-applinks)
- Android Developers: [Behavior changes for apps targeting Android 16](https://developer.android.com/about/versions/16/behavior-changes-16); [Predictive back](https://developer.android.com/guide/navigation/custom-back/predictive-back-gesture)

Not verified here (needs your accounts): hosted migration and function versions, Supabase Google provider settings, OAuth consent status, Lovable's ability to serve `assetlinks.json`, current Supabase pricing, and whether a Play developer account already exists.
