# Technique stats

This change builds on the Quick Log technique sheet in PR #90. The separate Stats PR targets that branch until #90 merges.

## Preview

1. Run the **QuickTrainingLogMock** Xcode scheme on an iPhone simulator.
2. Choose **Mock data → Technique stats**. Stats opens with explicit sample hits for Heel hook, Armbar and Back take across the last two weeks.
3. Below **Your rhythm**, verify three cards: technique name, both week totals, weekday labels, integer hit ticks, solid coral this week and muted dashed last week. The current line stops at today. There is no paragraph, percentage comparison or selector.
4. The personal tab and header read **Stats**, retaining the person icon. Other people's pages remain profiles; Activity/Gallery, Friends and Settings remain accessible.

## Real quick-log behavior

- Switch to **Quick logs**. Unused defaults and date-only logs produce no technique card. Save positive technique hits; the matching card appears under Stats → Progress immediately.
- Save the same technique twice on one day; sum both logs at that day. Log an older date and verify its selected date, rather than the save time, determines the bucket.
- Delete/Undo a log; counts update and the final technique chart disappears when no saved hits remain. Removing a technique from the usual list preserves its chart. Re-add the same name with different casing; it shares a chart with the earlier name.
- Log only last week: this week shows zero through today and last week's actual line. First-ever log this week: last week's line is zero. Older-only techniques retain a chart with zero recent totals. Future dates never add points.
- At Monday midnight, this week starts fresh and the completed week becomes last week. Repeat across a daylight-saving change, timezone change and Dec/Jan boundary.
- Sign out/switch accounts during a save: no list, rep totals or chart leaks into the next account. Hit details remain account-scoped device storage, without cross-device sync.
- Check narrow screens, long technique names, large Dynamic Type, VoiceOver chart summaries and the live app's older-backend fallback heatmap. No technique chart appears on another person's profile.

## Verification

`TechniqueTrendTests` covers aggregation, empty states, removal/re-addition, date validation, older history, Monday/DST boundaries, selected-date timezone behavior, save/Undo, account clearing and the explicit preview. CI builds the shared prototype and tests the native app, then checks its Release archive. Swift syntax and Xcode project membership can be checked locally without Xcode.
