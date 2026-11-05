# Technique stats

Stats uses the Quick Log technique sheet and personal saved hit details. Its empty state follows the shared Mat Monkey empty-state pattern.

## Preview

1. Run the **QuickTrainingLogMock** Xcode scheme on an iPhone simulator.
2. Choose **Mock data → Technique stats**. Stats opens with explicit sample hits for Heel hook, Armbar and Back take across the last two weeks.
3. Below **Your rhythm**, verify three cards: technique name, both week totals, weekday labels, integer hit ticks, solid coral this week and muted dashed last week. The current line stops at today. There is no paragraph, percentage comparison or selector.
4. The personal tab and header read **Stats**, retaining the person icon. Other people's pages remain profiles; Activity/Gallery, Friends and Settings remain accessible.

## Real quick-log behavior

- Choose **No quick logs** to open Stats → Progress with no quick-log records. Verify the Peek-a-boo invitation below Your rhythm: **What did you hit?**, **Your technique charts start with one log.**, and **Log hits**. No chart or legend is fabricated. Tap Log hits; today’s existing Quick Log sheet opens. Save positive hits; the sheet closes and the matching chart replaces the invitation. Cancel the sheet: the invitation stays. Failed saves retain the sheet and counts for retry.
- Choose **Quick logs**, then open Stats → Progress: two seeded quick logs contain actual hits (Heel hook 3, Armbar 1, Back take 2), so charts appear and the monkey is absent. **Technique stats** retains the richer two-week comparison fixture. These explicit preview fixtures never write live account data.
- Date-only legacy logs still have no technique statistics; the invitation remains until positive technique hits are saved.
- Save the same technique twice on one day; sum both logs at that day. Log an older date and verify its selected date, rather than the save time, determines the bucket.
- Delete/Undo a log; counts update and the final technique chart gives way to the Peek-a-boo invitation when no saved hits remain. Removing a technique from the usual list preserves its chart. Re-add the same name with different casing; it shares a chart with the earlier name.
- Log only last week: this week shows zero through today and last week's actual line. First-ever log this week: last week's line is zero. Older-only techniques retain a chart with zero recent totals. Future dates never add points.
- At Monday midnight, this week starts fresh and the completed week becomes last week. Repeat across a daylight-saving change, timezone change and Dec/Jan boundary.
- Sign out/switch accounts during a save: no list, rep totals or chart leaks into the next account. Hit details remain account-scoped device storage, without cross-device sync.
- In the installed app, save hits against a live Quick Log and refresh: its lowercase server UUID must match the local hit key. Relaunch with an older uppercase-key cache: prior hits should appear without logging them again. Migration preserves counts and avoids counting a mixed-case duplicate twice; no backend deployment is required.
- Check narrow screens, long technique names, large Dynamic Type, VoiceOver chart summaries and the live app's older-backend fallback heatmap. No technique chart appears on another person's profile.

## Verification

`TechniqueTrendTests` covers aggregation, empty states, removal/re-addition, date validation, older history, Monday/DST boundaries, selected-date timezone behavior, save/Undo, account clearing and the explicit preview. CI builds the shared prototype and tests the native app, then checks its Release archive. Swift syntax and Xcode project membership can be checked locally without Xcode.

## Empty-state visual checks

- The existing Silverback mark peeks and nods behind a white technique index card with paper rules and a coral plus. The mark is never redrawn; no camera or photo-memory caption appears in this variant. Existing Activity memory artwork retains its camera frame and behavior.
- Enable Reduce Motion: the artwork stays in the peeking pose with no looping animation. VoiceOver reads the headline, supporting copy and Log hits button; the illustration is decorative.
- Verify narrow phones, large Dynamic Type, scroll access to Log hits, and account changes with the sheet open. Unsupported backends do not show an action that could send Quick Log requests.
