# Mat Mind prototype (SwiftUI)

A native port of the interactive prototype in `ui_kits/app/`, built on the Mat Mind design system (`DESIGN.md`, `.claude/design-system-spec.json`). It's a separate app target, so production code is untouched.

## Run it

1. Open `IntentionalTrainingNotes.xcodeproj` in Xcode 26.
2. Pick the **MatMindPrototype** scheme and an iPhone simulator.
3. Run. It installs as "Mat Mind Proto" (`com.tienmai.intentionaltrainingnotes.matmind`, iOS 17+), next to the production app.

The app now starts on the Mat Mind welcome screen. **Continue with Google** shows a short loading state and opens the demo Activity feed. This is a simulated sign-up/login interaction: it does not connect a Google account or request credentials. Profile → Settings → Sign out returns to Welcome and resets sample data. A fresh launch also starts signed out.

The welcome photo stack fans into place and gently floats while the app is active. Both effects stop with Reduce Motion enabled. The lowercase Mat Mind wordmark and existing design-system photos, type, surfaces, and buttons are reused. The Google icon is bundled unchanged from [FirebaseUI's official asset](https://github.com/firebase/firebaseui-web/blob/master/image/google.svg).

For visual review without Xcode, run `python3 Prototypes/WelcomePreview/serve.py` from the repository root and open the welcome preview on loopback port 4174. This standalone browser companion uses the same design-system tokens and assets; its demo continuation and return flow are independent of SwiftUI. Native compilation still requires Xcode 26 on macOS.

**Prototype tools:** long-press the "mat mind." wordmark on Welcome or Activity. That opens the review panel: journeys A–C, jumps to Welcome and the app screens, the key states, a component gallery, and "Reset demo".

All data is sample data held in memory (`App/SeedData.swift`, from `ui_kits/app/data.js`). Nothing is saved or sent anywhere.

## Empty states

The first-session state uses the same paper canvas, photo-memory frame, ticket stub, typography, and pill actions as the design system. Activity is a completed-session feed: an empty schedule alone never clears existing posts.

- **Home, no shared posts or plans:** “Good memories start on the mat.” Plan a training session; add friends by QR when the friend list is empty, or log a past session when friends already exist.
- **Home, a plan exists:** “Your first photo is on its way.” View the plan or invitation. No post is created until a session is completed and published.
- **Home, a session awaits completion:** Complete & share is the next action.
- **Training, no upcoming plans/invites:** “Make it a mat date.” Plan a training session, with “Already trained? Log it” as a secondary action. Existing activity and past sessions remain available.
- **Past, no personal shared sessions:** Log a past session.

The review panel includes “First session,” “Plan made · no shared photo yet,” and “Empty training schedule · keep activity history.” These presets update actual in-memory collections, so a newly created plan replaces the empty state without restoring seeded sessions. Declined sessions do not count as upcoming plans.

For a browser visual companion, run `python3 Prototypes/EmptyPreview/serve.py` from the repository root. It serves only the preview's explicit assets on loopback port 4175. Use the state selector outside the phone frame to compare a fresh account, a planned session without a post, and existing history with no upcoming plans. This companion is independent of native state; Google, QR scanning, and backend services are not connected.

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
