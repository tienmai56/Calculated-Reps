# Grip Gorillas iOS

Native SwiftUI app for planning training with partners, sharing completed sessions and maintaining weekly friendship streaks.

Open `IntentionalTrainingNotes.xcodeproj`, select `IntentionalTrainingNotes`, and run on iOS 17 or later. The installed app renders the shared screens in `Prototypes/MatMind/`, backed by live services in `MatMind/`. Debug builds also offer **Preview without signing in** on Welcome, with isolated sample data.

Google sign-in setup is described in [Google sign-in setup](docs/google-sign-in-setup.md). Apple sign-in is hidden for now. Backend migrations and functions are deployed; see [deployment and validation](docs/mat-mind-v2-deployment.md) for configuration and acceptance checks.

Previous local training data is available only through **Settings → Export → Export local sessions**, from Welcome or Profile. Legacy records are not imported into social sessions, photos or streaks.

The Silverback app icon and logo come from `assets/brand/`. The production bundle identifier, existing sign-in callbacks, and stored-data identifiers retain their original values for compatibility. The `MatMindPrototype` scheme installs a separate **Grip Gorillas Proto** app for reviewing the shared design.

```sh
xcodebuild -scheme IntentionalTrainingNotes -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Design system

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
