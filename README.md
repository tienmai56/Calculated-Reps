# grip gorillas. — Design System

The design system for **Grip Gorillas**, a friendship-first social app for the Jiu-Jitsu community: plan training with partners, share a photo after you roll, and keep **weekly friendship streaks**. Warm, playful, and soft, not a fitness dashboard.

> **Start with [`DESIGN.md`](DESIGN.md).** It is the full specification and the source of truth.

## What's inside
| Path | Contents |
|---|---|
| [`DESIGN.md`](DESIGN.md) | Complete spec: tokens, voice, visuals, components, screens, guardrails |
| [`.claude/skills/grip-gorillas-design/SKILL.md`](.claude/skills/grip-gorillas-design/SKILL.md) | Agent skill for Claude Code: core rules and guardrails |
| [`.claude/design-system-spec.json`](.claude/design-system-spec.json) | Machine-readable tokens and component parameters |
| [`styles.css`](styles.css) | Global entry point (imports the token files) |
| [`design-system/tokens/`](design-system/tokens) | CSS custom properties: colors, typography, spacing, fonts |
| [`design-system/tailwind.config.js`](design-system/tailwind.config.js) | Tailwind preset mapped to the tokens |
| [`design-system/components/`](design-system/components) | React primitives with `.d.ts` contracts and usage notes |
| [`guidelines/`](guidelines) | Foundation specimen cards |
| [`ui_kits/app/`](ui_kits/app) | Interactive prototype (`index.html`) and IA/journeys (`flows.html`) |
| [`assets/brand/`](assets/brand) | The Silverback logo: mark, one-color mark, app icon (SVG + 1024 PNG), lockup |
| [`assets/`](assets) | Fonts, Lucide icons, sample photos |

## At a glance
- **Colors:** Paper `#FAF6EF` · Ink `#1D1B18` · Coral `#FF5C39` (primary) · friend hues sun, mint, sky, plum · Flame `#FF7A1A` for streaks
- **Type:** Bricolage Grotesque (display) · Archivo (body) · JetBrains Mono (codes)
- **Shape:** pill buttons, 22–28px cards and photos, soft shadows
- **Logo:** the Silverback, a geometric gorilla head with a coral brow band, next to the lowercase "grip gorillas." wordmark
- **Signature:** the streak belt, athletic-tape labels, ticket-stub sessions, tied avatars

## Components
Button, IconButton, Icon, Logo · Input, Select, Checkbox, Radio, Switch · Belt, Avatar, AvatarStack, StreakBelt, Badge, Tag, Card · Tabs, TabBar · Dialog, Toast, Tooltip

## Use it
```html
<link rel="stylesheet" href="styles.css">
<button style="background:var(--accent);color:var(--text-on-accent);border-radius:var(--radius-pill)">Plan a session</button>
```
```js
// tailwind.config.js
module.exports = { presets: [require('./design-system/tailwind.config.js')], content: ['./src/**/*.{html,js,jsx,tsx}'] };
```

## Credits
Fonts from Google Fonts (OFL). Icons: Lucide v0.454.0 (ISC). Sample photos: Unsplash (Unsplash License). Logo: the Silverback mark (`assets/brand/`), paired with the "grip gorillas." wordmark; see `DESIGN.md` §5.1.

---

## Grip Gorillas iOS app

This repository also contains the native SwiftUI MVP, shown on the home screen as **Grip Gorillas**. The Xcode project, scheme and bundle ID still use the original `IntentionalTrainingNotes` name, so existing installs and App Store records keep working. Open `IntentionalTrainingNotes.xcodeproj` in Xcode and run the `IntentionalTrainingNotes` scheme (iOS 13+, SwiftUI with `AppDelegate` / `SceneDelegate`, local JSON persistence, no external dependencies).

```sh
xcodebuild -scheme IntentionalTrainingNotes -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild -scheme IntentionalTrainingNotes -destination 'platform=iOS Simulator,name=iPhone 15' test
```
