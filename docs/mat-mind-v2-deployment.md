# Mat Monkey v2 — implementation and deployment

## Implemented locally

The production target now launches `MatMindRoot`: Activity, Training, Friends and Profile, with planning, RSVP, organizer management, completion/photos, shared memories, likes/comments, QR connections, notifications and Settings. SwiftData stores per-account social caches and drafts. Keychain stores backend credentials. The client uses native Apple identity tokens and Google OAuth with PKCE; it does not trust previous local provider IDs as cloud sessions.

The production app and prototype now compile the same `MMAppShell`, feature screens, design tokens, fonts and components. The installed app injects a live runtime into an empty view model. Debug builds also offer an isolated sample-data UI preview. No demo source is passed into archive migration.

Previous data is reachable exclusively through **Settings → Export → Export local sessions**, available on Welcome and Profile. That route exposes the exporter without archive browsing. Nothing is uploaded. Legacy records never enter sessions, posts, attendance or streak commands. The archive keeps source date strings rather than generating social timestamps.

Discovery includes guest/local and previous local account namespaces. Only the captured previous local namespace and guest archive can be exposed; a cloud login cannot select a different local account by asserting a provider ID. Access uses device-owner authentication independently of cloud sign-in. Other account folders remain untouched. This intentionally does not claim that all accounts found on a device belong to the current cloud user.

Migration uses the supported `NotebookMigration` decoder for validation, retains lossless allowed fields, rejects unreadable/unknown/future formats, filters known debug seed identifiers, and creates a versioned JSON/attachment backup. It verifies document equality, counts, references and SHA-256 attachment hashes before committing. Missing attachments and existing broken references are warnings; they are not silently deleted. Source files are never removed. Reflection images support the old session-ID directory layout. Unreferenced attachments are backed up but excluded from the share ZIP.

Export uses a streaming ZIP32 writer and the native iOS share sheet. Each export has a unique temporary job directory, a versioned JSON document, referenced available attachments and README. Raw notebook backups, profile/account fields, credentials and other account data are excluded. Share completion/cancellation cleans up the export job, and jobs older than one day are removed on a later scan. The ZIP writer rejects oversized ZIP32 exports explicitly without changing source data.

## Project configuration

- Supabase project URL: `https://cmiqavyrazypmulrfezj.supabase.co`.
- Supplied publishable key is configured in the app's Info.plist. This key is intended to ship in clients; administrative keys must never be placed there.
- App Store installation destination: [Mat Monkey - Jiu-Jitsu Planner](https://apps.apple.com/app/id6767997652). Its URL and numeric ID are recorded as `AppStoreURL` and `AppStoreID` in Info.plist.
- Existing production bundle ID is retained: `com.tienmai.intentionaltrainingnotes`.
- Minimum deployment target is now iOS 17. Older devices need the previous app version; validate App Store rollout strategy before release.
- Apple sign-in/APNs entitlements are provided. Select the correct development team and regenerate provisioning profiles with these capabilities enabled.

## Backend deployment status

The CLI is linked to `cmiqavyrazypmulrfezj`. On November 1, 2026 (Pacific), the five app migrations were applied and the `delete-account` and `notification-worker` Edge Functions were deployed. No seed data, legacy notebooks or local archive attachments were uploaded.

Hosted validation identified a device-token column/variable collision, fixed in `202611020004_device_registration.sql`. It also confirmed that hosted Supabase default privileges explicitly granted anonymous execution; `202611020005_function_permissions.sql` removes those grants from app RPCs and internal helpers. The original applied migrations are retained unchanged. Local regression fixtures now reproduce the hosted function defaults and test both fixes.

**Profile setup deployed (November 2, 2026):** `20261102190144_profile_setup.sql` adds private `account_settings.phone`, the private JPEG-only `avatars` bucket and its upload/read policies, and `avatar_key`/`phone` support in `save_profile`. The filename matches the version assigned by the hosted migration service. `delete-account` version 2 removes all pages of profile photos before deleting account data and the Auth identity. Hosted verification confirms owner-only phone access, the private bucket and its policies, authenticated command access, and blocked anonymous command execution; the deployed function source matches the reviewed file. Security advisory findings are unchanged from before deployment. `supabase/tests/profile.sql` runs in CI and `scripts/test-database.sh`; `node scripts/test-delete-account.mjs` checks authentication, paginated cleanup and safe retries.

**Mat Monkeys notification branding deployed (November 2, 2026):** `notification-worker` version 2 changes the push alert title to **Mat Monkeys**. Hosted readback matches the repository source; worker-secret authentication and deployment configuration are unchanged. No database migration is required for the rename.

**Mat Monkey notification branding deployed (November 3, 2026):** `notification-worker` version 8 (deployed 22:40 UTC from `main`) changes the push alert title from **Mat Monkeys** to **Mat Monkey**. Worker-secret authentication, secrets and the minute schedule are unchanged. No database migration is required for the rename.

**Build 1.1 (4):** CI builds the Mat Monkey production Release archive without Apple signing, verifies its version/build against the project settings, and publishes an unsigned `MatMonkeys-unsigned.xcarchive.zip` artifact for seven days. Apple signing and TestFlight upload are a separate distribution step. The profile setup screen appears for signed-in accounts without a profile; existing completed profiles stay intact.

**Push for every notification and comment reports (deployed November 3, 2026):** `202611030001_push_and_reports.sql` adds `like` (once per person per post) and `friend` (when someone connects with your code) notifications. Invites, RSVPs, comments and shared memories already notified. Every notification is queued for push. The migration also adds `reports.comment_id` and a `report_comment` command, and the app now offers **Report post** in post options and **Report comment** on a long press. `notification-worker` now leads each push with the actor's name ("Sarah liked your memory") and shows banners while the app is open. The app asks for notification permission once a signed-in profile exists. The migration and current worker are deployed. A once-per-minute worker schedule is active, and the account owner confirmed all five APNs/worker secret names are present and device delivery works. Reports are stored in `public.reports` for the team to review: check them at least daily (App Store guideline 1.2).

**Usernames and @mentions (backend deployed November 3, 2026):** `20261103170658_username_mentions.sql` is applied to the hosted project. The account owner confirmed the updated app works on their device; the source changes still need to ship in the next distributed iOS build. Account settings now lets members save a unique username (3–40 letters, numbers or underscores); the original migration gave existing profiles `member_<id without hyphens>` until they choose one. Type `@` at the end of a caption or comment to see known partner suggestions. Matching is case-insensitive. Mentions notify only recipients who already have access to the post and are not blocked; tagging someone does not add them as an attendee or grant access. Repeated tags and command retries produce one notification per recipient per caption/comment. Caption edits notify newly mentioned recipients once per post. Mention notifications open the memory. In-app mentions remain available when push is off; the existing worker checks `account_settings.push_enabled` at delivery, and iOS controls device permission. The APNs/worker secrets and minute schedule are configured; verify production APNs through the next TestFlight build.

**Name-based default usernames (deployed November 3, 2026):** `20261103184940_name_based_usernames.sql` changes untouched generated usernames to readable handles based on the profile name: `Hippo` → `hippo`, a second `Hippo` → `hippo2`, and `José Núñez` → `jose_nunez`. Existing profiles are processed in sign-up order. Only exact old `member_<own id>` defaults without a recorded explicit username choice are replaced. User-selected handles remain unchanged. Future profiles get name-based defaults automatically; later display-name edits preserve the existing username. Names without usable Latin letters receive `member`, `member2`, etc. Very short and long names retain the existing 3–40 character username rules. Members can still edit usernames in Account; the existing database-wide case-insensitive unique index rejects taken names. A shared transaction lock serializes automatic allocation and manual username claims. This is a backend-only change and takes effect when the app next refreshes after deployment; no new iOS build is needed. Changing an old generated handle can affect references written using that old handle.

Validation: all 78 SQL assertions passed on disposable PostgreSQL 17, including the original mention tests. An old-schema upgrade fixture passed 14 assertions covering duplicate names, sign-up ordering, accents, custom-handle preservation, explicitly retaining an old default, and migration idempotence. Real concurrent transactions passed both automatic-vs-automatic signup and manual-vs-automatic allocation tests. CI runs `supabase/tests/usernames.sql` and `scripts/test-username-concurrency.py`. The account owner explicitly approved deployment and merging. Hosted verification confirms Hippo now has `hippo`, no eligible UUID defaults remain, all usernames satisfy the format and global uniqueness rules, and the allocation helper remains unavailable to app clients. The migration filename matches the version assigned by the hosted migration service.

Validation for mentions: the disposable PostgreSQL 17 suite covers username uniqueness, legacy-client defaults, caption and comment mentions, edits, retries, email/partial-token rejection, stranger isolation, blocks, duplicate-author-alert suppression, queue insertion and private helper permissions. `node scripts/test-notification-worker.mjs` checks enabled/disabled push and post routing with mocked delivery. The iOS XCTest suite includes UTF-16/emoji mention parsing and insertion checks; an iOS build/device run is required before release.

To link another checkout or deploy subsequent migrations:

```sh
supabase link --project-ref cmiqavyrazypmulrfezj
supabase db push --linked --skip-vault --dry-run
supabase db push --linked --skip-vault
supabase functions deploy delete-account notification-worker --project-ref cmiqavyrazypmulrfezj --use-api --no-verify-jwt
```

Both functions validate access in their own handlers: account deletion checks the caller with Supabase Auth, and the notification worker requires its server-only secret. Unauthenticated requests were rejected with HTTP 401. Hosted database lint reports no errors. All public app tables have RLS enabled, anonymous app-function execution is disabled, and authenticated clients cannot directly call the notification/streak write helpers.

**Sign-in setup:** Apple sign-in is hidden for now. Google requires a web OAuth client configured in the hosted provider settings; follow [Google sign-in setup](google-sign-in-setup.md). The app checks provider availability before opening the sign-in sheet. Hosted Google credentials still need to be saved and the live flow verified; local config files and passing CI do not enable the provider. As of November 3, 2026, the account owner confirmed the four APNs secret names and `NOTIFICATION_WORKER_SECRET` are present, the worker schedule is active, and device notification delivery works.

The migrations create social tables, RLS policies, transactional commands, command receipts, a private photo bucket, bounded reads and cursor pagination. They have no legacy notebook upload route. Worker grants are limited to the specific tables/functions it requires; the app has no administrative credential.

Configure Apple and Google providers in Supabase Auth. Apple must accept the existing app bundle/client ID. Google must use the correct OAuth client and the Supabase callback shown in its dashboard. Allow `matmind://auth` as a redirect URL. Test real account creation, refresh, provider cancellation, Apple private email, Google callback and account switching on devices.

Configure server-only function secrets with the Supabase secrets UI or CLI's secure environment-file mechanism:

- `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`.
- `NOTIFICATION_WORKER_SECRET`: a high-entropy value used only by the scheduler and worker.
- Supabase-provided `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are runtime server secrets; do not copy them into the client.

Schedule the notification worker (for example once per minute) with its `x-worker-secret` header. The worker leases outbox rows, retries with backoff and uses a stable APNs collapse ID. In-app notifications are durable and unique even when push delivery is retried. Monitoring should alert on sustained failures or growing outbox age. Verify the worker schedule and APNs behavior before enabling push for real users.

`delete-account` verifies the caller with Auth, removes owned cloud media, executes scoped social-data deletion and deletes the Auth identity. It never touches on-device archives. A failed partial cloud deletion is retryable; exercise this path against staging before production rollout.

**Goal sharing (not deployed yet):** `20261104120000_goal_sharing.sql` adds `shared_goals` (the copy an owner publishes when they share a goal, updated on every save) and `goal_shares` (one row per recipient: pending, accepted or declined), a `goal` capability kind for links, the private JPEG-only `goal-media` bucket, and the commands `publish_goal`, `share_goal`, `goal_token`, `redeem_goal_link`, `respond_goal_share` and `unshare_goal`. Recipients who aren't friends can see the sender's profile. `snapshot()` returns both tables, `erase_social_account` removes them, and `delete-account` also clears the member's `goal-media` folder. Notifications use the new kind `goal_share`. `supabase/tests/goal_sharing.sql` covers upload ownership, friend-only direct shares, link invitations for non-friends, decline and re-share, blocking, unsharing and account deletion; CI runs it with the other SQL tests. Deploy the migration and `delete-account` before shipping the app build that shows Share. The website needs a `/goal/:token` route (see website-link-handoff) before HTTPS goal links are enabled.

## Friend and session links

Development links use `matmind://friend/<token>`, `matmind://session/<token>` and `matmind://goal/<token>`. Real QR images encode those actual links, and scanning redeems a server-issued expiring capability.

The selected invitation host is **https://matmindbjj.lovable.app/**. It is configured as `AppLinkHost`, and `applinks:matmindbjj.lovable.app` is in the app's Associated Domains entitlement.

The site is live, but the association file and invitation paths currently return HTTP 404. `AppLinksEnabled` remains false until the website is published with those files and routes. The iOS client continues generating `matmind://` links during this setup.

The website source lives in [tienmai56/your-note-haven](https://github.com/tienmai56/your-note-haven). Its implemented association endpoint and invitation routes are in [draft PR #1](https://github.com/tienmai56/your-note-haven/pull/1). The production Cloudflare build, TypeScript, focused ESLint, six unit tests, and local HTTP checks passed. The iOS invitation-readiness test also passed. Static reference assets remain in [website-link-handoff](../website-link-handoff/README.md); the actual TanStack website implementation in the PR is the publication source. The AASA file uses the team configured in this Xcode project; confirm the production App Identifier Prefix before publishing it. The fallback uses the supplied App Store listing and asks users to return to their original invitation after installation.

Publish the web changes, regenerate the signing profile with Associated Domains, verify valid links on a physical device, then set `AppLinksEnabled` to true. No live website changes have been made.

## Validation

- Xcode 26.6, iOS 26.5 simulator: full suite passed, **25 tests**, including **11 archive tests**.
- A fresh local PostgreSQL 17 instance accepted the migrations and passed social/QR SQL behavior tests using test substitutes for Supabase-owned auth/storage schemas.
- Tests cover organizer restrictions, direct-write denial, stranger isolation, private photo access, retry-safe publishing, all attendee pairs, attendance correction, post deletion, QR replay, blocking, and Monday/DST boundaries.
- An independent Python ZIP reader verified exact entry paths, CRCs, UTF-8, binary bytes and empty files from the ZIP writer.
- `git diff --check` passed.
- The final app launched successfully on a separate fresh simulator; the initial empty Activity screen was visually inspected.
- Edge Function TypeScript syntax was parsed; both deployed functions rejected unauthenticated requests. Authorized account deletion and APNs delivery still require device/staging acceptance testing.

The local PostgreSQL harness and hosted schema/permission checks do not replace device acceptance. Live provider sign-in, cross-device journeys, APNs, media cleanup, backup restore, distribution signing and universal links still require configuration and device acceptance before release. Realtime subscriptions are deferred; pull-to-refresh and foreground revalidation provide recovery now. Android is not part of this iOS implementation.

## Run local checks

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -scheme IntentionalTrainingNotes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```

`scripts/test-database.sh` uses only the disposable local `matmind-v2-postgres` container and `matmind_test` database. Start PostgreSQL 17 locally and create the test roles from `supabase/tests/bootstrap.sql` on a fresh cluster first. Never point this harness at the hosted project. `scripts/check-zip.py <export.zip>` validates a real exported ZIP independently.

For rollout, run the migration fixtures against a production-signed upgrade build without deleting the old app. Check record counts, dates and attachments, cloud-independent archive access, hidden archive entry for new/demo-only installs, native sharing and cancellation. Keep the old source files and staged backups throughout rollout.
