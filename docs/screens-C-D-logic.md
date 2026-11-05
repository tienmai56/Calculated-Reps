# Quick training log: screens C and D

Database deployment is paused. Use the **QuickTrainingLogMock** Xcode scheme for an in-memory seeded UI with host, guest, unstarted-plan and quick-log states.

Reference: canvas Page 2, `Activity-em83-6z5j.dc.html`. The current circular strip and simplified chooser remain in place. The supplied scratchpad path belonged to another workspace; this document records the implementation here.

The follow-up UI mock shows the dark quick-log strip first, with the calendar prompter
below on warm paper-2, ink text and a secondary View session button. It initially selects the closest upcoming accepted/hosted plan and retains
that session after its start time and across tab switches until it is completed.
Quick logs do not close the plan or advance the prompter. Completion advances it
to the next open plan; when none remain, the prompter disappears. The default
**Upcoming prompt** mock state includes a **Start plan** time shortcut so the
entire flow can be tried immediately without database access.

## Screen files

- `Prototypes/MatMind/Features/Activity/ActivityScreen.swift`: week strip, chooser, successful-save dismissal and session navigation, retry message, disabled unstarted plans, later log removal.
- `Prototypes/MatMind/Features/Training/TrainingScreen.swift`: Training lists with completion actions on eligible past tickets; existing session detail page, host publishing action and guest sharing explanation.
- `Prototypes/MatMind/Features/Profile/ProfileScreen.swift`: personal Progress tab, using the shared rhythm component in ActivityScreen.
- `Prototypes/MatMind/App/AppModel.swift`: quick logs, attendance confirmation, save serialization, account-generation checks and Undo.
- `Prototypes/MatMind/App/AppShell.swift`: app-wide toast and conditional Undo action, including on session details.
- `MatMind/App/MatMindRoot.swift`: authenticated runtime, snapshots, private merge notices and server operation receipts.

## C: A quick log

1. Save one owner-private log with its date, timestamp and timezone. Disable repeated actions until the request finishes.
2. Tapping a non-future Activity date without an open plan saves directly, including an already filled date. A day with an open plan always opens **What are you logging?**, whether the date, count badge or calendar badge is tapped. Do not open the day-entries / Log another session popup. On success, stay on Activity (or dismiss the chooser if its quick-log row was used). The day and Profile rhythm update; multiple entries change ×N without increasing the trained-day count.
3. Show **Training logged** with an **Undo** action. No photo, composer, post, session completion or friendship credit is created.
4. Keep the hosted/joined plan open in Coming up, including after its start time. Subsequent day taps reopen the chooser with **Already logged today** until the plan closes. Future planned days also open the chooser, with quick logging disabled until that day and plan completion disabled until its start time. Under This week, show **Tap a day to quickly log your training.** Below the date grid, show **[calendar] = You have a planned session** when the week has an open plan.
5. Undo removes only the new log. On quick-log-only dates, tapping the count badge immediately removes the latest log and decrements ×N, without confirmation; removing the last log clears the day. Dates with an open plan open the chooser instead of removing logs; confirmed-attendance dates ignore removal taps. Never change session attendance or posts. The older-week entries sheet retains its confirmation flow.
6. A failed save changes no local training state and does not dismiss the chooser. Show a retry message. A result received after account clearing must not create feedback or Undo in the new account.

## D: The planned session

1. Before the exact start timestamp, disable the option and show **Starts at {time}**. The backend independently checks the timestamp; a caller-supplied timezone cannot bypass it. A separate quick log for today remains available.
2. A host confirms attendance for all joined participants; a guest confirms only their own attendance. Invited/declined participants are excluded.
3. After success, dismiss the chooser and open that session's existing detail page. Show **Marked done for you and {names}** for the host, or **Marked done for you**, with **Undo**. Do not insert a share card into Activity.
4. The host sees **Complete & share**. An attended guest sees **{Host} can share a photo from this session.** Guests cannot publish through either UI or API.
5. Completion Undo restores only that action's changes and merged logs. Hide it once a post exists; the server also rejects Undo after publication or an intervening session edit/removal.
6. A failed completion keeps the chooser open, with unchanged attendance and no navigation or success toast. Repeat actions are blocked while saving.
7. Training has no standalone share prompter. In Past, an unlogged session you host replaces **You host** with **Complete & Share**, opening the existing composer for that session. Hide this card action for guests, future sessions, confirmed attendance without a post, and published sessions with or without a photo. A separate date-only quick log leaves the plan open and does not suppress its completion action.
8. Past tickets show only two states: **Complete & Share** for an unlogged hosted session, or **Completed** once the session is logged, whether privately, with a photo or with a note. Known shared session IDs preserve Completed independently of feed pagination. The mock seeds an unlogged host plan, private completed training, and a shared completed session with its local post.

## Deferred backend

This UI merge contains no quick-log migration or SQL test changes. The implementation is preserved on [`feat/activity-quick-log-db-deferred`](https://github.com/tienmai56/Calculated-Reps/tree/feat/activity-quick-log-db-deferred/supabase/features/quick-training-log). Deployment remains paused until explicitly requested.

Live quick logging is disabled unless the server returns all four feature snapshot fields: `quick_logs`, `training_days`, `log_matches`, and `shared_session_ids`. Until then, production uses the existing Activity prompt and read-only Profile heatmap; quick-log save/delete, separate completion and their Undo actions cannot send unsupported requests. Training ticket styling and the existing photo/note composer work with the current backend.

Use **QuickTrainingLogMock** for the complete in-memory UI. See [acceptance checks](quick-training-log-regression.md).
