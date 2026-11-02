# Mat Mind iOS

Native SwiftUI app for planning training with partners, sharing completed sessions and maintaining weekly friendship streaks.

Open `IntentionalTrainingNotes.xcodeproj`, select the `IntentionalTrainingNotes` scheme and run on iOS 17 or later. The existing production bundle identifier is retained.

Production code lives in `MatMind/`. The design system comes from the pinned prototype in `Prototypes/MatMind/DesignSystem/`. Prototype seed data and demo features are excluded from the production target.

The app is configured with the supplied Supabase project URL and publishable key. **Hosted migrations, auth providers and server functions still need deployment/configuration.** See [deployment and validation instructions](docs/mat-mind-v2-deployment.md).

Existing notebooks stay private and local. Their sole entry point is **Profile → Settings → Previous training data**, shown only when genuine legacy records exist. It contains a read-only archive and native ZIP export. Migration preserves original JSON, dates, relationships and attachments; it never generates social posts, attendance or streak credit.

```sh
xcodebuild -scheme IntentionalTrainingNotes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```

The previous notebook implementation remains in `IntentionalTrainingNotes/` for decoding, compatibility and migration tests. It is not the production navigation root.

## Design system references

# Mat Mind design system

The design system for **Mat Mind**, a friendship-first social app for the Jiu-Jitsu community: plan training with partners, share a photo after you roll, and keep **weekly friendship streaks**. Warm, playful, and soft, not a fitness dashboard.

> **Start with [`DESIGN.md`](DESIGN.md).** It is the full specification and the source of truth.

## What's inside
| Path | Contents |
|---|---|
| [`DESIGN.md`](DESIGN.md) | Complete spec: tokens, voice, visuals, components, screens, guardrails |
| [`.claude/skills/mat-mind-design/SKILL.md`](.claude/skills/mat-mind-design/SKILL.md) | Agent skill for Claude Code: core rules and guardrails |
| [`.claude/design-system-spec.json`](.claude/design-system-spec.json) | Machine-readable tokens and component parameters |
| [`styles.css`](styles.css) | Global entry point (imports the token files) |
| [`design-system/tokens/`](design-system/tokens) | CSS custom properties: colors, typography, spacing, fonts |
| [`design-system/tailwind.config.js`](design-system/tailwind.config.js) | Tailwind preset mapped to the tokens |
| [`design-system/components/`](design-system/components) | React primitives with `.d.ts` contracts and usage notes |
| [`guidelines/`](guidelines) | Foundation specimen cards |
| [`ui_kits/app/`](ui_kits/app) | Interactive prototype (`index.html`) and IA/journeys (`flows.html`) |
| [`assets/`](assets) | Fonts, Lucide icons, sample photos |

## At a glance
- **Colors:** Paper `#FAF6EF` · Ink `#1D1B18` · Coral `#FF5C39` (primary) · friend hues sun, mint, sky, plum · Flame `#FF7A1A` for streaks
- **Type:** Bricolage Grotesque (display) · Archivo (body) · JetBrains Mono (codes)
- **Shape:** pill buttons, 22–28px cards and photos, soft shadows
- **Signature:** the streak belt, athletic-tape labels, ticket-stub sessions, tied avatars

## Components
Button, IconButton, Icon · Input, Select, Checkbox, Radio, Switch · Belt, Avatar, AvatarStack, StreakBelt, Badge, Tag, Card · Tabs, TabBar · Dialog, Toast, Tooltip

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
Fonts from Google Fonts (OFL). Icons: Lucide v0.454.0 (ISC). Sample photos: Unsplash (Unsplash License). No official logo yet; the wordmark is set in type.

