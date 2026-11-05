# Quick training log regression tests

Run these checks whenever changes touch Activity, Training, Profile, Complete & share, attendance, RSVP/guest lists, date/timezone handling, snapshots, caching, or sign-in/account switching. Source of truth: DESIGN.md, “Week strip and quick logs” and “Your rhythm”. Design reference: canvas Page 2 (`Activity-em83-6z5j.dc.html`) supersedes the earlier Activity strip and chooser styling; the current boards A–E retain the interaction and data rules. The later UI decision moves Your rhythm from board E’s Training placement to your own Profile.

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

1. **A, Activity (Page 2, `Activity-em83-6z5j.dc.html`):** verify the ink-900 card, paper text, 24pt radius, 16/14/12pt padding and no shadow. The 18pt Bricolage title and quiet 13pt ink-300 count share a baseline, separated by 8pt; the 13pt ink-200 helper sits 4pt below. No pill, chevron, navigation action or temporary count highlight. Leave 12pt before seven equal Monday–Sunday columns. Each column is one button, with an 11pt weekday, 7pt gap and 40pt circle containing only the date. Today’s letter is coral-300; its circle has a 2pt coral ring, without a dot. Trained circles are solid coral with no check; past empty circles use paper-10%; future circles are disabled with a 1.5pt paper-14% outline, dashed paper-50% for a future plan. Corner badges are 18pt with a 2pt ink ring: ×N on paper for multiple entries, otherwise a calendar on ink-700 for an open plan. Verify a trained day with a plan, multiple entries with a plan, and future plans. No Planned session legend. Check narrow screens and larger text: the helper wraps, each full column remains tappable, and badges stay attached to their circles. Coming up and friends’ posts remain below.
2. **B, chooser:** tap today’s plan. Verify **What are you logging?** and the close button, without a subtitle. The plan option keeps its date stub, title and host/time/participant line only, with a chevron; no completion paragraph. The quick-log option has its check stub, **A quick log**, **Just marks the day. Nothing is posted.** and a chevron; no lock icon or Separate from the plan line. Keep an existing quick-log time below the options when present. The sheet fits its content and scrolls when needed. Dismiss by close button, dragging or backdrop; nothing changes. Repeat with two plans, long titles/names, large Dynamic Type, a solo host and as a guest.
3. **C, quick log:** choose A quick log. The day fills, count changes once, ink Training logged toast offers Undo. No camera/composer/share card appears. The plan remains open, so tapping again still asks. Undo removes only the new log.
4. **D, plan completion:** choose the host plan. Joined guests’ days fill, the plan leaves Coming up, and only the host sees the session-bound paper-2 share panel with ink text inside the ink card and the required gets-posted line. Add a photo to post opens that exact plan. Close or navigate away: card disappears; Training still offers catch-up. Repeat as guest: Marked done for you, no photo prompt, host unchanged.
5. **Day entries:** a filled day without an open plan opens entries with quick-log times and session titles/sharing state. Log another session adds a quick log; count remains one day and the circle gains a ×2 corner badge. After the toast expires, delete a quick log, cancel confirmation, then confirm. A remaining session still fills the day.
6. **E, Training and Profile:** Training has no strip or rhythm grid. Its most recent hosted completed unshared plan gets the ink catch-up card, followed by Upcoming/Past planned-session lists with no quick logs. On your own Profile’s Progress tab, Your rhythm appears below the Profile section tabs and before the Weekly/Monthly board. Switch to Activity and Gallery: the rhythm card must not appear in those tabs. It has 17 columns, Monday–Sunday rows, month labels, correct Since date, exact rest copy and legend, one coral intensity and outlined future days. Open an older week and log a day; close/reopen and verify persistence. Return to Activity and confirm its day/count updates. Visiting another member’s profile must not show your private rhythm.
7. **Merge:** guest logs within three hours; host completes the plan. On the guest’s next app open/refresh, the log has become the attended session and a matched-log toast offers Undo. Undo restores a separate log. Repeat beyond three hours: retain both. Repeat exactly at three hours and across local midnight/timezones.
8. **Permissions and correction:** guest cannot publish even via a deep link/API call. Host removes a joined guest; that session stops counting for them. Guest removes their own attendance. Invited/declined participants never gain attendance. Host Undo restores only people changed by that action.
9. **Persistence:** relaunch and refresh; private logs and attendance remain correct. Switch accounts and sign out; no other account’s logs, merge toast, undo or share card appears. Test a week across a daylight-saving change and Dec/Jan year boundary.
10. **Accessibility:** with Reduce Motion, no day/count pop. With VoiceOver, each day button announces the full date, trained state, entry count and planned titles, including a plan on an already trained day. The quiet count announces trained days and has no navigation action. Decorative circle badges are part of the day button, not separate controls. The rhythm grid still announces summary and week actions. Check large Dynamic Type, long session titles, multiple participant names, a solo host, and fully visible badges. Profile’s older-week sheet retains its white card, larger tiles and ×N pill.

## Validation recorded during implementation

The new migration, training-log SQL regression, and all 14 existing SQL suites passed in PGlite after applying the existing migration chain. The harness translated psql variables for the existing suites. This harness used replacement crypto functions because PGlite lacks pgcrypto; cryptographic invitation behavior was not validated there. Native XCTest, the Docker suite and simulator visual checks still require the environments above. Treat those as release checks, not as completed verification.
