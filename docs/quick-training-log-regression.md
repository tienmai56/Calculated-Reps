# Quick training log regression tests

Run these checks whenever changes touch Activity, Training, Complete & share, attendance, RSVP/guest lists, date/timezone handling, snapshots, caching, or sign-in/account switching. Source of truth: DESIGN.md, “Week strip and quick logs” and “Your rhythm”. Design reference: current boards A–E in the Quick training log canvas; earlier boards and Edge cases are superseded.

## Automated checks

On macOS with the iPhone 17 Pro simulator installed:

```sh
xcodebuild -scheme IntentionalTrainingNotes -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`TrainingCalendarTests` in `IntentionalTrainingNotesTests/IntentionalTrainingNotesTests.swift` covers tap precedence, day counting, plan exclusion, the three-hour merge boundary, local-day matching, host versus guest completion, host/guest undo, organizer-only publishing, quick-log Undo, calendar history beyond schedule pagination, and account clearing. Existing tests continue covering the photo-or-note rule, session lists, Activity discovery and live snapshot mapping.

For the database, use the repository’s **disposable local test database**, never production. With the existing PostgreSQL test container `matmind-v2-postgres` running:

```sh
sh scripts/test-database.sh
```

The script drops/recreates only `matmind_test` in that test container, applies all migrations and includes `supabase/tests/training_log.sql`. It checks owner privacy, guest-only attendance, host completion for joined participants, no automatic post, near-log merge versus distant-log retention, undo restoring attendance and merged logs, publication after separate completion, and participant removal. New operation calls still pass through `command` receipts and authorization.

For focused reruns against a newly migrated disposable fixture, run `supabase/tests/training_log.sql` as the test database owner. It creates users inside a transaction, switches to `authenticated` for API checks, and rolls back its fixtures. Do not run it against a populated database.

## Invariants to preserve

- One trained day means at least one quick log or confirmed attendance. Plans alone never count; multiple entries do not increase the day count.
- Quick logs are owner-private and cannot create posts, media, session tickets, or friendship credits.
- Future tiles are disabled. Open plans always ask, even after a quick log; multiple plans are separate choices. A trained tile never toggles off.
- Host completion fills joined participants only. Guest completion never changes the host or another guest. Removing attendance removes that session’s contribution; another entry can still keep the day filled.
- Only the host sees share prompts or can publish. Every photo invitation explains that the photo gets posted to Activity. Existing photo-or-note validation remains enforced by both app and database.
- Undo targets one mutation. After newer edits/publication, attendance undo must fail safely without reverting other work. Quick-log removal after the toast requires confirmation.
- A merge requires the quick log’s recorded local day and a timestamp within three hours (inclusive) of the plan’s start. Merge Undo restores the log without removing attendance.
- Calendar history comes from `training_days`, independently of the feed’s 30-post and schedule’s 100-session limits.
- Logout/account switching clears logs, share cards and undo state. Preview fixtures never load into a live account.

## Manual acceptance checks (boards A–E)

Use explicit UI preview mode for sample records; use two test accounts for live host/guest behavior. Never seed a live account automatically.

1. **A, Activity:** verify the compact white This week card, singular/plural pill, Monday–Sunday ordering, today ring/dot, calendar legend, future dashed plan and disabled empty days. Chevron opens Training. Coming up and friends’ posts remain below it.
2. **B, chooser:** tap today’s plan. Verify title, date subtitle, mini date stub, host/time/participant metadata, both exact option descriptions, and existing quick-log time. Dismiss by dragging/backdrop; nothing changes. Repeat with two plans and as a guest.
3. **C, quick log:** choose A quick log. The day fills, count changes once, ink Training logged toast offers Undo. No camera/composer/share card appears. The plan remains open, so tapping again still asks. Undo removes only the new log.
4. **D, plan completion:** choose the host plan. Joined guests’ days fill, the plan leaves Coming up, and only the host sees the session-bound share card and required gets-posted line. Add a photo to post opens that exact plan. Close or navigate away: card disappears; Training still offers catch-up. Repeat as guest: Marked done for you, no photo prompt, host unchanged.
5. **Day entries:** a filled day without an open plan opens entries with quick-log times and session titles/sharing state. Log another session adds a quick log; count remains one day and tile shows ×2. After the toast expires, delete a quick log, cancel confirmation, then confirm. A remaining session still fills the day.
6. **E, Training:** no strip. Most recent hosted completed unshared plan gets the ink catch-up card. Grid has 17 columns, Monday–Sunday rows, month labels, correct Since date, exact rest copy and legend, one coral intensity and outlined future days. Upcoming/Past contain no quick logs. Open an older week and log a day; close/reopen and verify persistence.
7. **Merge:** guest logs within three hours; host completes the plan. On the guest’s next app open/refresh, the log has become the attended session and a matched-log toast offers Undo. Undo restores a separate log. Repeat beyond three hours: retain both. Repeat exactly at three hours and across local midnight/timezones.
8. **Permissions and correction:** guest cannot publish even via a deep link/API call. Host removes a joined guest; that session stops counting for them. Guest removes their own attendance. Invited/declined participants never gain attendance. Host Undo restores only people changed by that action.
9. **Persistence:** relaunch and refresh; private logs and attendance remain correct. Switch accounts and sign out; no other account’s logs, merge toast, undo or share card appears. Test a week across a daylight-saving change and Dec/Jan year boundary.
10. **Accessibility:** with Reduce Motion, no tile/count pop. With VoiceOver, each tile announces full date, trained state and planned title; grid announces summary and week actions. Check large Dynamic Type, long session titles, multiple participant names, and a solo host. In each strip, the weekday and status must have visible top/bottom insets; the date, check/calendar and ×2 pill must stay fully inside the tile at default and larger text sizes.

## Validation recorded during implementation

The new migration, training-log SQL regression, and all 14 existing SQL suites passed in PGlite after applying the existing migration chain. The harness translated psql variables for the existing suites. This harness used replacement crypto functions because PGlite lacks pgcrypto; cryptographic invitation behavior was not validated there. Native XCTest, the Docker suite and simulator visual checks still require the environments above. Treat those as release checks, not as completed verification.
