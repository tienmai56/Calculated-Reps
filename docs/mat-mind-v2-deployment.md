# Mat Monkeys v2 — implementation and deployment

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
- App Store installation destination: [Mat Monkeys - Jiu-Jitsu Planner](https://apps.apple.com/app/id6767997652). Its URL and numeric ID are recorded as `AppStoreURL` and `AppStoreID` in Info.plist.
- Existing production bundle ID is retained: `com.tienmai.intentionaltrainingnotes`.
- Minimum deployment target is now iOS 17. Older devices need the previous app version; validate App Store rollout strategy before release.
- Apple sign-in/APNs entitlements are provided. Select the correct development team and regenerate provisioning profiles with these capabilities enabled.

## Backend deployment status

The CLI is linked to `cmiqavyrazypmulrfezj`. On November 1, 2026 (Pacific), the five app migrations were applied and the `delete-account` and `notification-worker` Edge Functions were deployed. No seed data, legacy notebooks or local archive attachments were uploaded.

Hosted validation identified a device-token column/variable collision, fixed in `202611020004_device_registration.sql`. It also confirmed that hosted Supabase default privileges explicitly granted anonymous execution; `202611020005_function_permissions.sql` removes those grants from app RPCs and internal helpers. The original applied migrations are retained unchanged. Local regression fixtures now reproduce the hosted function defaults and test both fixes.

**Profile setup deployed (November 2, 2026):** `20261102190144_profile_setup.sql` adds private `account_settings.phone`, the private JPEG-only `avatars` bucket and its upload/read policies, and `avatar_key`/`phone` support in `save_profile`. The filename matches the version assigned by the hosted migration service. `delete-account` version 2 removes all pages of profile photos before deleting account data and the Auth identity. Hosted verification confirms owner-only phone access, the private bucket and its policies, authenticated command access, and blocked anonymous command execution; the deployed function source matches the reviewed file. Security advisory findings are unchanged from before deployment. `supabase/tests/profile.sql` runs in CI and `scripts/test-database.sh`; `node scripts/test-delete-account.mjs` checks authentication, paginated cleanup and safe retries.

**Mat Monkeys notification branding deployed (November 2, 2026):** `notification-worker` version 2 changes the push alert title to **Mat Monkeys**. Hosted readback matches the repository source; worker-secret authentication and deployment configuration are unchanged. No database migration is required for the rename.

**Build 1.1 (4):** CI builds the Mat Monkeys production Release archive without Apple signing, verifies its version/build against the project settings, and publishes an unsigned `MatMonkeys-unsigned.xcarchive.zip` artifact for seven days. Apple signing and TestFlight upload are a separate distribution step. The profile setup screen appears for signed-in accounts without a profile; existing completed profiles stay intact.

**Push for every notification and comment reports (not yet deployed):** `202611030001_push_and_reports.sql` adds `like` (once per person per post) and `friend` (when someone connects with your code) notifications. Invites, RSVPs, comments and shared memories already notified. Every notification is queued for push. The migration also adds `reports.comment_id` and a `report_comment` command, and the app now offers **Report post** in post options and **Report comment** on a long press. `notification-worker` now leads each push with the actor's name ("Sarah liked your memory") and shows banners while the app is open. The app asks for notification permission once a signed-in profile exists. Deploy the migration and the worker, then set the APNs secrets and schedule the worker as described below; until then notifications stay in-app only. Reports are stored in `public.reports` for the team to review: check them at least daily (App Store guideline 1.2).

To link another checkout or deploy subsequent migrations:

```sh
supabase link --project-ref cmiqavyrazypmulrfezj
supabase db push --linked --skip-vault --dry-run
supabase db push --linked --skip-vault
supabase functions deploy delete-account notification-worker --project-ref cmiqavyrazypmulrfezj --use-api --no-verify-jwt
```

Both functions validate access in their own handlers: account deletion checks the caller with Supabase Auth, and the notification worker requires its server-only secret. Unauthenticated requests were rejected with HTTP 401. Hosted database lint reports no errors. All public app tables have RLS enabled, anonymous app-function execution is disabled, and authenticated clients cannot directly call the notification/streak write helpers.

**Sign-in setup:** Apple sign-in is hidden for now. Google requires a web OAuth client configured in the hosted provider settings; follow [Google sign-in setup](google-sign-in-setup.md). The app checks provider availability before opening the sign-in sheet. Hosted Google credentials still need to be saved and the live flow verified; local config files and passing CI do not enable the provider. The four APNs secrets and `NOTIFICATION_WORKER_SECRET` are absent; push delivery remains inactive and no worker schedule was enabled.

The migrations create social tables, RLS policies, transactional commands, command receipts, a private photo bucket, bounded reads and cursor pagination. They have no legacy notebook upload route. Worker grants are limited to the specific tables/functions it requires; the app has no administrative credential.

Configure Apple and Google providers in Supabase Auth. Apple must accept the existing app bundle/client ID. Google must use the correct OAuth client and the Supabase callback shown in its dashboard. Allow `matmind://auth` as a redirect URL. Test real account creation, refresh, provider cancellation, Apple private email, Google callback and account switching on devices.

Configure server-only function secrets with the Supabase secrets UI or CLI's secure environment-file mechanism:

- `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`.
- `NOTIFICATION_WORKER_SECRET`: a high-entropy value used only by the scheduler and worker.
- Supabase-provided `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are runtime server secrets; do not copy them into the client.

Schedule the notification worker (for example once per minute) with its `x-worker-secret` header. The worker leases outbox rows, retries with backoff and uses a stable APNs collapse ID. In-app notifications are durable and unique even when push delivery is retried. Monitoring should alert on sustained failures or growing outbox age. Verify the worker schedule and APNs behavior before enabling push for real users.

`delete-account` verifies the caller with Auth, removes owned cloud media, executes scoped social-data deletion and deletes the Auth identity. It never touches on-device archives. A failed partial cloud deletion is retryable; exercise this path against staging before production rollout.

## Friend and session links

Development links use `matmind://friend/<token>` and `matmind://session/<token>`. Real QR images encode those actual links, and scanning redeems a server-issued expiring capability.

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
