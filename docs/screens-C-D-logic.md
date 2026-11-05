# Quick training log: screens C and D

Reference: canvas Page 2, `Activity-em83-6z5j.dc.html`. The current circular strip and simplified chooser remain in place. The supplied scratchpad path belonged to another workspace; this document records the implementation here.

## Screen files

- `Prototypes/MatMind/Features/Activity/ActivityScreen.swift`: week strip, chooser, successful-save dismissal and session navigation, retry message, disabled unstarted plans, later log removal.
- `Prototypes/MatMind/Features/Training/TrainingScreen.swift`: existing session detail page; host publishing action and guest sharing explanation.
- `Prototypes/MatMind/Features/Profile/ProfileScreen.swift`: personal Progress tab, using the shared rhythm component in ActivityScreen.
- `Prototypes/MatMind/App/AppModel.swift`: quick logs, attendance confirmation, save serialization, account-generation checks and Undo.
- `Prototypes/MatMind/App/AppShell.swift`: app-wide toast and conditional Undo action, including on session details.
- `MatMind/App/MatMindRoot.swift`: authenticated runtime, snapshots, private merge notices and server operation receipts.

## C: A quick log

1. Save one owner-private log with its date, timestamp and timezone. Disable repeated actions until the request finishes.
2. Tapping any non-future Activity date saves directly, including an already filled date. Do not open the day-entries / Log another session popup. On success, stay on Activity (or dismiss the chooser if its optional quick-log row was used). The day and Profile rhythm update; multiple entries change ×N without increasing the trained-day count.
3. Show **Training logged** with an **Undo** action. No photo, composer, post, session completion or friendship credit is created.
4. Keep the hosted/joined plan open in Coming up, including after its start time. Date taps keep adding logs. The separate calendar badge opens the chooser with **Already logged today**. A calendar icon below the week explains **You have a planned session** when a plan exists.
5. Undo removes only the new log. On quick-log-only dates, tapping the count badge immediately removes the latest log and decrements ×N, without confirmation; removing the last log clears the day. Dates with an open plan or confirmed attendance ignore removal taps. Never change session attendance or posts. The older-week entries sheet retains its confirmation flow.
6. A failed save changes no local training state and does not dismiss the chooser. Show a retry message. A result received after account clearing must not create feedback or Undo in the new account.

## D: The planned session

1. Before the exact start timestamp, disable the option and show **Starts at {time}**. The backend independently checks the timestamp; a caller-supplied timezone cannot bypass it. A separate quick log for today remains available.
2. A host confirms attendance for all joined participants; a guest confirms only their own attendance. Invited/declined participants are excluded.
3. After success, dismiss the chooser and open that session's existing detail page. Show **Marked done for you and {names}** for the host, or **Marked done for you**, with **Undo**. Do not insert a share card into Activity.
4. The host sees **Complete & share**. An attended guest sees **{Host} can share a photo from this session.** Guests cannot publish through either UI or API.
5. Completion Undo restores only that action's changes and merged logs. Hide it once a post exists; the server also rejects Undo after publication or an intervening session edit/removal.
6. A failed completion keeps the chooser open, with unchanged attendance and no navigation or success toast. Repeat actions are blocked while saving.

## Existing backend implementation

The pending `20261105070000_training_log.sql` migration already provides `quick_logs`, private `training_actions`/`log_matches`, `training_days`, and publishing after separate completion. The operation names used consistently by the app and dispatcher are `create_quick_log`, `delete_quick_log`, `mark_training_done`, `undo_training_done`, `restore_matched_log`, and `acknowledge_log_match`.

When a host completes a plan, guest quick logs on the recorded local day within three hours of its start (inclusive) are matched atomically. More distant logs remain separate. Merge Undo restores a separate log without removing attendance. Participant removal clears that session's contribution and invalidates incompatible attendance Undo.

No new completion push notification is sent to guests. Their next refresh fills the day; only a matched log produces the private merge toast.

Backend deployment remains on hold. See `quick-training-log-regression.md` for acceptance checks and verification results.
