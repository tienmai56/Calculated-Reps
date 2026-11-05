# Profile heatmap regression testing

Run these checks when changing Profile, session history, attendance corrections, session deletion, snapshot loading, authentication/account switching, or date/timezone logic.

This feature is independent of the quick-training-log PR. It adds a static calendar to the same card as the existing Weekly/Monthly chart on your own Profile’s Progress tab. It introduces no Activity strip, quick logs, day sheets, attendance commands, database migration, or publishing-flow changes.

## Automated tests

With Xcode and the iPhone 17 Pro simulator:

```sh
xcodebuild -scheme IntentionalTrainingNotes -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Existing CI also runs the native test suite. Focused rerun:

```sh
xcodebuild -scheme IntentionalTrainingNotes -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:IntentionalTrainingNotesTests/ProfileHeatmapTests -only-testing:IntentionalTrainingNotesTests/BackendSessionTests/testHeatmapReadPaginatesBeyondTheScheduleLimitWithoutWrites test
```

`ProfileHeatmapTests` covers 119 squares across 17 Monday–Sunday weeks; same-local-day deduplication; future days; daylight saving and year boundaries; unshared and photo-free logs; completed attendance corrections; invitations, declines and cancellations; history outside the bounded schedule/feed; clearing account data; and owner/date filters in the API query.

`BackendSessionTests.testHeatmapReadPaginatesBeyondTheScheduleLimitWithoutWrites` reads 205 session records in two pages using the real client and the HTTP fixture. It verifies GET-only requests to existing tables, pagination offsets, and that a long history is not restricted by the schedule’s 100-session page. Existing authentication tests still exercise refresh, cancellation, caching and stale account responses.

## Counting contract

- Count all past sessions you host or joined, including saved past sessions that were never published and have no photo or note.
- Match the existing Training/Past rule: a joined/hosted plan whose start has elapsed is history. Existing data does not distinguish that record from an explicitly logged past session. No new completion operation or migration is added here.
- For completed sessions, honor your `attended` flag. Removing your attendance stops that session from filling a day. Another counted session on that date can still keep it filled.
- Exclude invitations, declined attendance, cancelled sessions, future sessions and records belonging only to other people.
- Bucket by the viewing device’s local calendar date. Two sessions on one date remain one colored square.
- Use the full session metadata range, not the feed’s published-photo records or the schedule’s 100-row page. Feed pagination and deleting a shared post do not erase session history.

## Manual UI checks

1. Open Debug → **Preview without signing in**. Navigate to **Profile → Progress**. Your rhythm is inside the same white card as Weekly/Monthly, above a divider and those controls.
2. Check 17 week columns, Monday–Sunday row ordering, month labels, correct Since date, Trained/No entry legend, coral/paper colors, and outlined future dates. Empty accounts show an empty grid without fabricated sessions.
3. Tap any square or week: nothing opens or changes. There is no explanatory paragraph, tap instruction, quick-log action or day sheet.
4. Switch Weekly/Monthly. Only the existing summary and bar chart change; the heatmap stays visible and retains the same date range.
5. Log a past session through the existing flow. Leave its composer without posting a photo or note. Return to Profile: its local day fills. Add another session that day: it stays one square and one trained day.
6. Verify hosted and joined past sessions, a declined/invited session, a future plan and a cancelled session. On an attended completed session, correct your attendance and confirm the day clears when no other counted session remains.
7. Test more than 100 sessions in the last 17 weeks, including many future plans. The oldest visible logged days must still be filled. Delete a shared post: its session still fills the day.
8. Check a timezone crossing midnight, daylight-saving boundary and December/January week. Confirm full-date bucketing and 17 complete week columns.
9. Switch to Profile → Activity/Gallery or another person’s profile: no private heatmap there. Sign out/switch accounts: no previous account’s trained days appear.
10. With VoiceOver, the heatmap is one static image summary with a trained-day count, not 119 buttons. Check default/large Dynamic Type and a smaller iPhone for clipping. Confirm the existing Activity, Training and Complete & share screens remain unchanged.

## Environment note

Swift syntax and whitespace can be checked in the Linux workspace. Native compilation, XCTest and simulator visual validation require Xcode; report their CI/local results explicitly rather than treating syntax parsing as a build.
