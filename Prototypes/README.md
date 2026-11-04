# Mat Monkey prototype (SwiftUI)

A native port of the interactive prototype in `ui_kits/app/`, built on the Mat Monkey design system (`DESIGN.md`, `.claude/design-system-spec.json`). The production and prototype schemes share these screens; the prototype keeps an independent sample-data adapter.

## Run it

1. Open `IntentionalTrainingNotes.xcodeproj` in Xcode 26.
2. Pick the **MatMindPrototype** scheme and an iPhone simulator.
3. Run. It installs as "Mat Monkey Proto" (`com.tienmai.intentionaltrainingnotes.matmind`, iOS 17+), next to the production app.

The app now starts on the Mat Monkey welcome screen. **Continue with Google** shows a short loading state and opens the demo Activity feed. This is a simulated sign-up/login interaction: it does not connect a Google account or request credentials. Profile → Settings → Sign out returns to Welcome and resets sample data. A fresh launch also starts signed out.

The welcome photo stack fans into place and gently floats while the app is active. Both effects stop with Reduce Motion enabled. The lowercase Mat Monkey wordmark and existing design-system photos, type, surfaces, and buttons are reused. The Google icon is bundled unchanged from [FirebaseUI's official asset](https://github.com/firebase/firebaseui-web/blob/master/image/google.svg).

For visual review without Xcode, run `python3 Prototypes/WelcomePreview/serve.py` from the repository root and open the welcome preview on loopback port 4174. This standalone browser companion uses the same design-system tokens and assets; its demo continuation and return flow are independent of SwiftUI. Native compilation still requires Xcode 26 on macOS.

**Prototype tools:** long-press the "mat monkey." wordmark on Welcome or Activity. That opens the review panel: journeys A–C, jumps to Welcome and the app screens, the key states, a component gallery, and "Reset demo".

All data is sample data held in memory (`App/SeedData.swift`, from `ui_kits/app/data.js`). Nothing is saved or sent anywhere.

## Empty states

The first-session state uses the same paper canvas, photo-memory frame, ticket stub, typography, and pill actions as the design system. Activity is a completed-session feed: an empty schedule alone never clears existing posts.

- **Home, no shared posts or plans:** “Good memories start on the mat.” Plan a training session; add friends by QR when the friend list is empty, or log a past session when friends already exist.
- **Home, a plan exists:** “Your first photo is on its way.” View the plan or invitation. No post is created until a session is completed and published.
- **Home, a session awaits completion:** “Proof you showed up.” Complete & share (in the card above) is the next action.
- **Training → Upcoming, no upcoming plans/invites:** “Summon your crew” Plan a training session, with “Already trained? Log it” as a secondary action. Existing activity and past sessions remain available.
- **Training → Past:** the same session tickets, newest first, including past sessions without a photo or shared post. Completed sessions stay here after publishing. The empty state offers **Log a past session**.

The review panel includes “First session,” “Plan made · no shared photo yet,” and “Empty training schedule · keep activity history.” These presets update actual in-memory collections, so a newly created plan replaces the empty state without restoring seeded sessions. Declined sessions do not count as upcoming plans.

For a browser visual companion, run `python3 Prototypes/EmptyPreview/serve.py` from the repository root. It serves only the preview's explicit assets on loopback port 4175. Use the state selector outside the phone frame to compare a fresh account, a planned session without a post, and existing history with no upcoming plans. This companion is independent of native state; Google, QR scanning, and backend services are not connected.

## Session focus outline

Plan a session keeps its original date carousel, time pills, gym chips, notes, friend grid, and privacy controls. **Add a focus**, beside Add a note, expands the optional **What are we working on?** section and focuses a blank item. Each focus has one **Add a detail** at the bottom of its card, and details sit one level under the focus, each with its own remove button. Details don't nest further; deeper items saved by earlier builds still show and can be removed. Titles are editable in place; the outline is not a checklist or a performance tracker.

Blank items must be named or removed before saving; a completely empty outline is valid. Removing a parent asks for confirmation and removes its descendants. Cancel keeps the whole branch. Indentation is capped visually on small screens; deeper levels are labeled explicitly and retain their actual hierarchy.

When you have goals, they show as tags at the top of the section. Tapping one adds a focus named after the goal. Its details start blank, and a collapsed **Goal notes** toggle shows the goal's notes for reference without copying them into the session. Tap the tag again to remove that focus. Without goals, the section starts with a blank card and a hint that goals will show up there.

The organizer can edit the outline on session details using the pencil beside **What we're working on**, or from a hosted ticket's **Edit session** sheet. That sheet also includes **Guest list**: check friends to invite and uncheck guests to remove them. The organizer stays on the list and retained guests keep their RSVP. Focus and guest changes save with the session details; closing discards unsaved edits. The outline is carried into the completion flow and kept with the published post. Posts show only the focus names: as one scrolling row of tags under the title in the Activity feed (the caption is cut to two lines there), and as wrapping tags under **What we worked on** on post detail. Details are never shown on posts.

For a populated example, long-press the Mat Monkey wordmark → States → **Plan a session · nested focus details** (a focus with details). Normal planning starts with one blank optional focus card. This works for both upcoming sessions and logging a past session.

A standalone browser companion is in `Prototypes/FocusPreview/`. Run `python3 Prototypes/FocusPreview/serve.py` from the repository root; it serves only preview assets on loopback port 4176. The browser companion mirrors the native planning form, including the original date/time, gym, note, friend, and privacy controls. The Example and Blank buttons are review controls outside the phone. Browser state is independent of the native app. The browser's completion action uses a labeled sample photo; real authentication and backend services are not connected.

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
