# Mat Monkey prototype (SwiftUI)

A native port of the interactive prototype in `ui_kits/app/`, built on the Mat Monkey design system (`DESIGN.md`, `.claude/design-system-spec.json`). The production and prototype schemes share these screens; the prototype keeps an independent sample-data adapter.

## Run it

1. Open `IntentionalTrainingNotes.xcodeproj` in Xcode 26.
2. Pick the **MatMindPrototype** scheme and an iPhone simulator.
3. Run. It installs as "Mat Monkey Proto" (`com.tienmai.intentionaltrainingnotes.matmind`, iOS 17+), next to the production app.

The app now starts on the Mat Monkey welcome screen. **Continue with Google** shows a short loading state and opens the demo Activity feed. This is a simulated sign-up/login interaction: it does not connect a Google account or request credentials. Stats → Settings → Sign out returns to Welcome and resets sample data. A fresh launch also starts signed out.

The welcome photo stack fans into place and gently floats while the app is active. Both effects stop with Reduce Motion enabled. The lowercase Mat Monkey wordmark and existing design-system photos, type, surfaces, and buttons are reused. The Google icon is bundled unchanged from [FirebaseUI's official asset](https://github.com/firebase/firebaseui-web/blob/master/image/google.svg).

For visual review without Xcode, run `python3 Prototypes/WelcomePreview/serve.py` from the repository root and open the welcome preview on loopback port 4174. This standalone browser companion uses the same design-system tokens and assets; its demo continuation and return flow are independent of SwiftUI. Native compilation still requires Xcode 26 on macOS.

**Prototype tools:** long-press the "mat monkey." wordmark on Welcome, or the Silverback mark in the Activity header. That opens the review panel: journeys A–C, jumps to Welcome and the app screens, the key states, a component gallery, and "Reset demo".

All data is sample data held in memory (`App/SeedData.swift`, from `ui_kits/app/data.js`). Nothing is saved or sent anywhere.

## Quick training log UI mock

Choose the **QuickTrainingLogMock** Xcode scheme and run on an iPhone simulator.
It builds the separate MatMindPrototype app and opens Activity directly; sign-in,
Supabase setup and the opt-in database bundle are unnecessary. Nothing is sent to
or read from a backend.

The sample-data bar has seven states and **Reset**:

- **Upcoming prompt** (default): the ink quick-log strip comes first. The nearest
  upcoming session appears below on warm paper-2, with ink text, a white calendar
  tile and a secondary **View session** button.
  Tap any past or current day to log it at once: **↶ Undo** appears beside
  **This week**, keeping the title row, instruction and calendar in place, while
  **Not now** / **Log techniques** expand the card downward under the days.
  Undo disappears after five seconds without changing the header's height.
  Log techniques opens **What landed on {day}?**; counts save as you tap
  and the row then summarizes them. A quick log leaves that session open. Use
  **Start plan** to simulate its start, then complete it from View session.
  Returning to Activity shows the next open session in the prompter. It stays on the selected
  session after its start time and across tab switches until completion. Reset
  restores the original upcoming session.
- **No quick logs:** opens Stats with no quick-log records and the Peek-a-boo invitation. Log hits opens today’s counter sheet; saving the first hits replaces the invitation with charts.
- **Technique stats:** opens Stats with Heel hook, Armbar and Back take daily reps for this week and last week. Explicit sample data only; it never writes to an account or backend.
- **Host plan:** today has a started plan. Tapping the day logs a quick log like any
  other day (no chooser); the calendar badge stays and the plan stays open. Complete
  it from Training or session details with Complete & share.
- **Guest plan:** confirm only your own attendance; the host keeps sharing control.
- **Starts later:** today's plan hasn't started; tapping the day still quick-logs.
- **Quick logs:** two logs today include technique hits (Heel hook 3, Armbar 1, Back take 2), so Stats shows charts instead of the monkey. today starts with ×2; tap the date to add and its count to remove, on planned days too.

Dates follow the device’s current day. A future open mat, completed unshared
training, a completed-and-shared session with its sample post, and 17 weeks of
rhythm history are also seeded. Sharing
creates only a local post; Undo and attendance correction are simulated in memory.
Reset restores the selected state. The normal **MatMindPrototype** scheme retains
its welcome flow, and the production app’s scheme/backend settings are unchanged.

In **Training → Past**, unlogged sessions you host have a **Complete & Share**
button in place of **You host**, opening that session’s composer. Sessions already
marked done or published with a photo or note have no completion button in the
list: they all show **Completed** in place of **You host**, whether logged with
a photo or without one. The Host plan mock includes both private and published
completed sessions alongside the unlogged plan. The compact button is right-aligned
beside the avatars when it fits; ticket
cards show avatars without a going-count label. Training has no standalone share
prompter.

## Tap-to-log directions (exploration)

A browser comparison of three directions where tapping a day on Activity's week card logs training immediately, with no "What did you hit today?" sheet. Counting techniques becomes an optional follow-up below the days, always with **Not now**. Run `python3 Prototypes/QuickLogPreview/serve.py` from the repository root and open loopback port 4177. Both phones open just after tapping Friday; **Replay the tap** shows it again.

- **A · Moves row:** the week card grows a second row of technique circles that match the day circles. Tap a circle to count a hit; it fills coral, and a small − takes one back.
- **B · Tap pad:** a separate full-width white card lands below the calendar with a 2-column grid of technique tiles. Tap a tile to count; counted tiles turn coral-tinted with a − button.
- **C · Quiet line:** the subtle option. Below the days, only two options fade in: **Not now** and **Log techniques** (which pulses twice). Nothing is listed or expanded until Log techniques opens a short counter sheet; afterwards the line summarizes the hits with Edit.
- **C · planned day** (below the three phones): tapping a day with a planned session adds a quick log right away, like any other day. There's no chooser and no separate session tracking; the calendar badge stays on the day.

In all three, "Training logged · Undo" replaces the week card's subtitle for five seconds, next to the tap, instead of a toast at the bottom of the screen. Planned days log the same way as any other day: no chooser, only quick logs, and the calendar badge stays. Hits attach to the tapped day's quick log, so Stats' technique charts are unchanged. Sample data only; nothing is saved. (Round 1's speech bubble and tucked-under tray are in git history.)

## Empty states

The first-session state uses the same paper canvas, photo-memory frame, ticket stub, typography, and pill actions as the design system. Activity shows all future hosted/accepted plans under Coming up and completed memories under Activity: an empty schedule alone never clears existing posts.

- **Home, no shared posts or plans:** “Good memories start on the mat.” Plan a training session; add friends by QR when the friend list is empty, or log a past session when friends already exist.
- **Home, a solo or friends-only plan exists:** show its ticket under **Coming up**, using the session’s own title. Pending invitations remain in Training. No completed post is created until a session is completed and published.
- **Home, an upcoming link-visible plan exists:** show its session ticket under **Coming up**, even with no completed posts. The host and accepted guests see it. Each session appears once, without a separate personal-session prompter. Tickets leave Activity when declined, cancelled or completed; quick-log-enabled clients keep started plans awaiting attendance.
- **Home, a session awaits completion:** “Proof you showed up.” Complete & share (in the card above) is the next action.
- **Training → Upcoming, no upcoming plans/invites:** “Summon your crew” Plan a training session, with “Already trained? Log it” as a secondary action. Existing activity and past sessions remain available.
- **Training → Past:** the same session tickets, newest first, including past sessions without a photo or shared post. Completed sessions stay here after publishing. The empty state offers **Log a past session**.

The review panel includes “First session,” “Plan made · no shared photo yet,” and “Empty training schedule · keep activity history.” These presets update actual in-memory collections, so a newly created plan replaces the empty state without restoring seeded sessions. Declined sessions do not count as upcoming plans.

For a browser visual companion, run `python3 Prototypes/EmptyPreview/serve.py` from the repository root. It serves only the preview's explicit assets on loopback port 4175. Use the state selector outside the phone frame to compare a fresh account, a planned session without a post, and existing history with no upcoming plans. This companion is independent of native state; Google, QR scanning, and backend services are not connected.

## Session focus outline

Plan a training keeps its original date carousel, time pills, gym chips, notes, friend grid, and privacy controls. **Add a focus**, beside Add a note, expands the optional **What are we working on?** section and focuses a blank item. Each focus has one **Add a detail** at the bottom of its card, and details sit one level under the focus, each with its own remove button. Details don't nest further; deeper items saved by earlier builds still show and can be removed. Titles are editable in place; the outline is not a checklist or a performance tracker.

Blank items must be named or removed before saving; a completely empty outline is valid. Removing a parent asks for confirmation and removes its descendants. Cancel keeps the whole branch. Indentation is capped visually on small screens; deeper levels are labeled explicitly and retain their actual hierarchy.

When you have goals, they show as tags at the top of the section. Tapping one adds a focus named after the goal. Its session details start blank. **Goal notes** shows the goal’s saved parts, their notes, videos and photos, plus any earlier goal-level notes and references. It starts expanded when editing a session. On session detail and **Share the session**, it starts collapsed; tap to expand or collapse it. The goal reference survives saving and reopening the session, even after renaming the focus or goal; older focuses match an unambiguous goal name. References stay read-only and follow the goal’s latest saved edits without copying private content into the session or post. Tap the tag again to remove that focus. Without goals, the section starts with a blank card and a hint that goals will show up there.

The organizer can edit the outline on session details using the pencil beside **What we're working on**, or from a hosted ticket's **Edit session** sheet. That sheet also includes **Guest list**: check friends to invite and uncheck guests to remove them. The organizer stays on the list and retained guests keep their RSVP. Focus and guest changes save with the session details; closing discards unsaved edits. The outline is carried into the completion flow and kept with the published post. Posts show only the focus names: as one scrolling row of tags under the title in the Activity feed (the caption is cut to two lines there), and as wrapping tags under **What we worked on** on post detail. Details are never shown on posts.

For a populated example, long-press the Silverback mark on Activity → States → **Plan a training · nested focus details** (a focus with details). Normal planning starts with one blank optional focus card. This works for both upcoming sessions and logging a past session.

A standalone browser companion is in `Prototypes/FocusPreview/`. Run `python3 Prototypes/FocusPreview/serve.py` from the repository root; it serves only preview assets on loopback port 4176. The browser companion mirrors the native planning form, including the original date/time, gym, note, friend, and privacy controls. The Example and Blank buttons are review controls outside the phone. Browser state is independent of the native app. The browser's completion action uses a labeled sample photo; real authentication and backend services are not connected.

## Participant session photos

After training, confirmed attendees can add one photo from session details.
Photos keep main's 240pt rounded tiles, with the author's name above each,
directly on the paper canvas. There is no white wrapper, inset or outer shadow
around the name and photo; contributions are separated by 24pt of space.
**Add photo** opens a separate preview with the existing summary card, 330pt
photo and sticky **Post photo** action. Selection stays local until posting.
The participant's own menu offers **Replace photo** and confirmed **Remove photo**;
removal leaves attendance intact. Focus remains above Photos, and the existing
empty-photo reminder is retained. The host's Activity composer is separate.

Long-press the Activity mark → States → **Participant photos · attended as a
guest** to review with sample photos, including add, replace and remove. The live
app uses the real single-image library picker and private uploads. The guest
action remains hidden until the backend advertises the participant-photo
migration. See [regression and rollout notes](../docs/participant-session-photos.md).

## Layout

`Prototypes/MatMind/` is an Xcode *synchronized folder*: any file added there is part of the target automatically, with no project-file edits needed.

| Path | What |
|---|---|
| `DesignSystem/Tokens/` | Colors, friend hues, belt ranks, type scale, spacing, radii, shadows, motion |
| `DesignSystem/Components/` | The 20 components from `design-system/components/`, as SwiftUI views (`MMButton`, `MMStreakBelt`, …) |
| `DesignSystem/Patterns/` | Prototype patterns: screen shell, header, tape label, tied avatars, photo tile, wordmark |
| `App/` | App entry, navigation, state and actions (`AppModel`), seed data, demo panel, component gallery |
| `Features/` | Welcome, Activity, Training, Create, Complete & share, Friends, QR, Profile, Notifications |
| `Resources/` | Asset catalog (75 Lucide icons in regular / bold / filled variants, 10 sample photos) and fonts |

## Fonts

`Resources/Fonts/*.ttf` are static instances cut from the design system's variable `.woff2` files (iOS can't load woff2): Bricolage Grotesque 600/700/800, Archivo 400/500/600/700 + italic, JetBrains Mono 400/600. They're licensed under the SIL Open Font License 1.1 (see each font's embedded name table). Icons: Lucide v0.454.0 (ISC). Photos: Unsplash License.

## Shipping it later

The App Store treats a build as an update when it has the same bundle ID. When the revamp is ready, move `com.tienmai.intentionaltrainingnotes` onto this target (or move this code into the production target), raise the version to 2.0, and archive as usual.

## Shared UI in the installed app

`IntentionalTrainingNotes` now renders `MMAppShell` and the same feature screens as `MatMindPrototype`. The prototype is the visual source of truth; there is no second live-app tab shell or list-based replacement for these screens. Changes to the shared files affect both schemes.

**UI review without sign-in:** in a Debug build of IntentionalTrainingNotes, choose **Preview without signing in** on Welcome. It opens the shared screens using a separate sample-data model, including simulated planning, publishing, and QR success. An **Exit preview** bar returns to the live welcome screen. Review changes are temporary and never use the live backend. This entry point is excluded from Release builds; real Google/Apple sign-in still needs the Supabase providers configured.

The installed app injects `LiveMatMindRuntime` into an empty `AppModel(live: true)`. It maps authenticated backend snapshots to the view models, translates the current user's UUID to the UI's `me` identifier, and sends mutations to the backend. Only the prototype uses seed data, pretend QR scans, automatic RSVPs and simulated reactions. The live app uses Google sign-in, camera scanning, expiring invitation codes, real photo selection/upload and confirmed server results. The existing live account, cloud data and bundle identifier are retained.

Previous device-local notebook data appears only under **Settings → Export → Export local sessions**, available from the welcome screen's Settings or Profile's Account sheet. That route exports the existing verified JSON/attachment ZIP; it does not import legacy records into social sessions, show an archive tab, or add an archive browser to the new UI.

Validation: CI builds `MatMindPrototype` and builds/tests `IntentionalTrainingNotes`. Locally check Google sign-in/profile creation, empty states, planning and RSVP with two accounts, QR redemption, publishing a photo, and exporting legacy sessions from Settings. Camera QR scanning requires a supported physical device.

## Goal parts

**Add a goal** asks what you're working on, then **Break it down** splits it into parts (e.g. "Grip on the near leg", "Head position"). Parts are components of the goal, not steps: there are no numbers, no order to follow and nothing to tick off. Each part has its own name, free-form notes, one YouTube (or other) link and photos.

One part card is open at a time; the others show a summary such as "2 notes · 1 video · 3 photos". Touch and hold a closed card to move it up or down or remove it. **Add photos** opens the photo library in multi-select (up to 20 per part, kept in the order picked). Tapping a thumbnail opens the photos full screen: swipe or use the filmstrip, and **Remove photo** takes it out with a few seconds to undo. Links with a timestamp (`t=102`, `t=1m42s`) show where the clip starts.

Nothing is written until **Add goal** / **Save goal**: picked photos are then saved privately on the device (JPEG, no metadata, at most 2048 px), photos taken out lose their files, and parts with nothing in them are dropped. Goals saved by earlier builds still open; their own notes and references stay editable.

## Rich session links

In the live app, a host's Upcoming → Share session action creates an invitation
URL before opening the native share sheet, so messaging apps receive a URL they
can preview. Other participants retain the plain-text session summary; this does
not expand invitation permissions. Copy link uses the same URL generator. HTTPS
previews require the staged rollout in `website-link-handoff/README.md`; custom
scheme sharing remains in use until `AppLinksEnabled` is enabled after verification.
