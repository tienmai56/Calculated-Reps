# Mat Mind prototype (SwiftUI)

A native port of the interactive prototype in `ui_kits/app/`, built on the Mat Mind design system (`DESIGN.md`, `.claude/design-system-spec.json`). It's a separate app target, so production code is untouched.

## Run it

1. Open `IntentionalTrainingNotes.xcodeproj` in Xcode 26.
2. Pick the **MatMindPrototype** scheme and an iPhone simulator.
3. Run. It installs as "Mat Mind Proto" (`com.tienmai.intentionaltrainingnotes.matmind`, iOS 17+), next to the production app.

**Prototype tools:** long-press the "mat mind." wordmark on the Activity tab. That opens the review panel: journeys A–C, jumps to all 8 screens, the key states, a component gallery, and "Reset demo".

All data is sample data held in memory (`App/SeedData.swift`, from `ui_kits/app/data.js`). Nothing is saved or sent anywhere.

## Layout

`Prototypes/MatMind/` is an Xcode *synchronized folder*: any file added there is part of the target automatically, with no project-file edits needed.

| Path | What |
|---|---|
| `DesignSystem/Tokens/` | Colors, friend hues, belt ranks, type scale, spacing, radii, shadows, motion |
| `DesignSystem/Components/` | The 20 components from `design-system/components/`, as SwiftUI views (`MMButton`, `MMStreakBelt`, …) |
| `DesignSystem/Patterns/` | Prototype patterns: screen shell, header, tape label, tied avatars, photo tile, wordmark |
| `App/` | App entry, navigation, state and actions (`AppModel`), seed data, demo panel, component gallery |
| `Features/` | Activity, Training, Create, Complete & share, Friends, QR, Profile, Notifications |
| `Resources/` | Asset catalog (75 Lucide icons in regular / bold / filled variants, 10 sample photos) and fonts |

## Fonts

`Resources/Fonts/*.ttf` are static instances cut from the design system's variable `.woff2` files (iOS can't load woff2): Bricolage Grotesque 600/700/800, Archivo 400/500/600/700 + italic, JetBrains Mono 400/600. They're licensed under the SIL Open Font License 1.1 (see each font's embedded name table). Icons: Lucide v0.454.0 (ISC). Photos: Unsplash License.

## Shipping it later

The App Store treats a build as an update when it has the same bundle ID. When the revamp is ready, move `com.tienmai.intentionaltrainingnotes` onto this target (or move this code into the production target), raise the version to 2.0, and archive as usual.
