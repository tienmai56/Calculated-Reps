# @mentions backend and APNs rollout plan

Status checked against the live `Mat Mind` Supabase project on November 3, 2026.
The live checks were read-only. Backend deployment and the account owner’s device test are now complete; retain this checklist for future rollout verification.

## Verified current state

- Project: `cmiqavyrazypmulrfezj`.
- `202611030001_push_and_reports.sql` is deployed.
- `notification-worker` version 7 is active and its source matches the local worker.
- An active `notification-worker` Cron job runs every minute (`* * * * *`).
- The five most recent retained HTTP responses were HTTP 200 without timeouts.
- Two device tokens are registered and there are zero pending outbox jobs.
- Vault contains a secret named `notification_worker_secret`; its value was not read.
- `pg_cron`, `pg_net`, and Vault are installed.
- `20261103170658_username_mentions.sql` is deployed; the username column and mention function were verified.
- The account owner confirmed all five APNs/worker secret names are present and reported that the device test works.

The successful HTTP responses show that the worker is running. They do not prove
that an alert reached an iPhone. Edge Function secret values were not read. The account owner’s Xcode screenshot confirms automatic signing, the expected bundle ID and Push Notifications capability. Older deployment notes describe previous setup
states; use the live checks above for this rollout.

## 1. Deploy and verify the mention migration

Owner: developer with Supabase project access.

Completed for `supabase/migrations/20261103170658_username_mentions.sql`: the hosted migration list, username column and mention function were verified. For future deployments, use the linked project’s tracked migration workflow before distributing the updated app. Confirm existing profiles receive default usernames and authenticated members can save unique usernames. Check database security advisories and confirm
that the internal mention helpers cannot be executed by anonymous or app clients.

The current deployed worker already accepts mention notifications and checks push
preferences. No additional worker deployment is required for the mention feature
while its source continues to match the repository.

Completion: the hosted schema and command support usernames and generate a single
mention notification/outbox entry for an eligible tagged recipient.

## 2. Verify Apple Developer configuration

Owner: Apple Developer account holder or an authorized team member.

In Apple Developer, confirm Push Notifications is enabled for the existing App ID
`com.tienmai.intentionaltrainingnotes`. Confirm the APNs signing key authorizes
that app/topic and the environment being tested. If a key needs to be created,
download its `.p8` file when Apple offers it and retain it securely. Record its
Key ID and the owning Team ID. The Xcode project currently selects Team ID
`9R4A2F8F94`; confirm that it is the team owning the app and APNs key.

In the production Xcode target, verify the Push Notifications capability and
refresh signing/provisioning as needed. The checked-in settings use
`aps-environment=development` for Debug and `production` for Release. The client
registers Debug tokens as sandbox and Release tokens as production. Validate those
settings against the entitlements in the actual signed builds. Alert pushes do
not require adding silent-background notification handling.

Completion: the signed app can register with APNs under the intended environment.

## 3. Verify server secrets and the existing schedule

Owner: developer with Supabase Edge Function secret access.

Confirm these Edge Function secret names and mappings in the Supabase dashboard:

| Secret | Required value |
| --- | --- |
| `APNS_KEY_ID` | Apple APNs signing key's Key ID |
| `APNS_TEAM_ID` | Team ID that owns the key and app |
| `APNS_PRIVATE_KEY` | Complete `.p8` PEM contents, including header/footer |
| `APNS_TOPIC` | `com.tienmai.intentionaltrainingnotes` |
| `NOTIFICATION_WORKER_SECRET` | Server-only random value matching the scheduler |

The worker accepts actual PEM newlines or escaped `\n`. Keep private keys and
worker secrets in server secret storage. Supabase supplies `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY` to the function runtime.

The existing Cron job should POST to:
`https://cmiqavyrazypmulrfezj.supabase.co/functions/v1/notification-worker`
with the `x-worker-secret` header resolved from Vault. Confirm the existing Vault
secret and function secret agree if authentication fails. Maintain one active
schedule, every minute. This implies roughly a minute of queue delay under light
load, plus APNs delivery time. The current worker processes up to 25 jobs per run.

Completion: scheduled calls succeed and a controlled test notification has an
observable processing outcome. An empty queue returning HTTP 200 alone does not
validate APNs delivery.

## 4. Build and distribute the updated iOS app

Owner: developer with Xcode and App Store Connect access.

Run the production and shared prototype builds and the XCTest suite on macOS.
Increment the build number as needed for the next TestFlight upload. Archive and
upload a signed Release build. TestFlight uses production APNs. Install it on a
physical iPhone, sign in, finish profile setup, and allow notifications. If iOS
permission was previously denied, enable it in the iPhone's app notification
settings. Confirm that token registration succeeds for the correct account and
APNs environment; existing token counts do not prove this new installation is
registered.

Completion: the new app can save usernames, offer mention suggestions, and
register its receiving device.

## 5. Run an end-to-end acceptance test

Owner: two testers, or a developer using two accounts/devices.

1. Connect accounts A and B so B can already view A's completed-session post.
2. Set a recognizable username for B, such as `hippo`.
3. With B's app in the background and notifications enabled, publish a caption
   mentioning `@hippo`. Confirm an in-app mention and a visible device alert.
4. Tap the alert and confirm it opens the correct post.
5. Repeat using an inline comment, then a post-detail comment.
6. Repeat the same handle twice in one body; confirm only one mention event.
7. Turn off B's iOS notifications and repeat; confirm no device alert and that the
   in-app notification remains. Separately verify `push_enabled=false` if testing
   the backend preference; the current app exposes notification permission setup,
   not a toggle for that database flag.
8. Verify that self-mentions, blocked recipients, and people without post access
   do not receive mention notifications. Confirm caption edits notify newly
   mentioned eligible recipients without repeating existing mention events.

Completion: real production-device delivery, notification preference behavior,
and post navigation are verified. The local SQL and mocked worker tests already
passed; they do not replace this device test.

## 6. Observe rollout and keep a pause option

Monitor Edge Function errors and the outbox's pending count, oldest pending job,
`attempts`, and `last_error`. A delivered timestamp can also mean delivery was
skipped because push was disabled or there were no registered devices; correlate
it with APNs results and the device test. Investigate HTTP 401 for scheduler-secret
mismatches, APNs 403 for key/team/topic authorization, and APNs 400 for device-token
or environment mismatches. Never include key values in diagnostic output.

If delivery misbehaves, pause the existing Cron job while investigating. Keep
in-app notifications and queued records available. Resume the single schedule
after the cause is corrected. Broader rollout is ready after the signed build,
hosted migration, production-device test, and worker monitoring all pass.

References:
- https://supabase.com/dashboard/project/cmiqavyrazypmulrfezj
- https://supabase.com/docs/guides/functions/schedule-functions
- https://developer.apple.com/account/
