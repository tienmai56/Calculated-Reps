---
name: mat-monkeys-design
description: Use this skill to design or build anything for Mat Monkey, the friendship-first BJJ social app: production UI (SwiftUI or web), prototypes, mocks, or brand assets. Contains core styling rules, visual guidelines and guardrails; exact tokens are in design-system-spec.json.
user-invocable: true
---

# Mat Monkey design skill

Read `DESIGN.md` at the repo root first (it is the source of truth). Exact values: `.claude/design-system-spec.json`. CSS variables: `design-system/tokens/` via `styles.css`. Components: `design-system/components/`. Reference prototype: `ui_kits/app/index.html`.

If invoked with no task, ask what they want to build, then act as an expert product designer producing HTML artifacts or production code as needed.

## Core styling rules
- **Canvas:** Paper `#FAF6EF` app background, white cards, ink `#1D1B18` text. Never pure black, never grey-blue neutrals.
- **One primary:** Coral `#FF5C39` (`--accent`) for the main CTA, the center "Plan a training" button, likes, focus. One primary button per screen.
- **Friend hues:** sun / mint / sky / plum / coral. Assign one per friendship and reuse it everywhere (streak belt, pair card, ticket stub). Use the `-100` tint for backgrounds and `-700` for text on it.
- **Flame `#FF7A1A`** only for streaks. **Belt colors** only to show rank.
- **Type:** Bricolage Grotesque 800 for display, titles, buttons (tracking −0.02 to −0.04em). Archivo for body. JetBrains Mono only for links and codes, never for stats.
- **Shape:** everything soft. Inputs 14px, cards 22–24px, photo posts and sheets 28px, buttons/chips/tabs pill.
- **Elevation:** `--shadow-card` on white cards, no borders. Float shadow only for toasts and modals.
- **Buttons:** pill. Primary has a 3px `--accent-shade` bottom edge that sinks 2px on press.
- **Motion:** `--ease-out` 140–220ms for UI; `--ease-bounce` for joins, likes, checks, QR connect, streak counters.
- **Icons:** Lucide only (`assets/icons/`), 2px stroke (2.25 in buttons). Heart and flame are filled when active. No emoji in UI.
- **Spacing:** 16px screen gutters, 44px minimum tap targets, 22px between sections.

## Logo
- **The Silverback**: geometric gorilla head with a coral brow band, paired with the lowercase "mat monkey." wordmark (coral period). Files: `assets/brand/logo-mark.svg` (default), `logo-mark-mono.svg` (on coral / 1-color), `app-icon.svg` (sun ground; also the reversed logo on ink and photos), `app-icon-1024.png`, `logo-lockup.svg`. In React use `<Logo variant="mark|mono|appIcon|lockup|lockupInverse" />` from `design-system/components/core/`.
- Clear space = brow height; min 24px mark, 120px lockup. Never recolor, outline, animate a new expression, or redraw it. Full rules: `DESIGN.md` §5.1.

## Signature motifs (use them, don't dilute them)
1. **Streak belt:** one segment per Mon–Sun week, each with a white tape stripe; joined when consecutive; current week hatched until completed.
2. **Athletic-tape label:** rotated off-white strip on photos for the gym name.
3. **Ticket stub:** session cards with a tinted date stub, dashed tear, punched notches.
4. **Tied avatars:** two overlapping avatars with a hue "knot".

## Voice
Your favorite training partner: warm, a little cheeky, mat-literate. Sentence case. Verb-first buttons ("Invite Sarah to train"). Streak copy encourages and never guilts ("Pick it back up · best 12 weeks"). Celebrate people, not numbers.

## Guardrails (never)
- Free-form posts: posts come only from completed sessions.
- Public discovery or matching with strangers. Friends may join upcoming link-visible sessions from Activity.
- Group chat or DMs.
- Daily streaks, leaderboards, badges, milestones, rankings, performance analytics.
- Custom avatar builder (not MVP).
- Decorative gradients, dark "fitness dashboard" styling, emoji UI, a redrawn or recolored logo (use the Silverback files in `assets/brand/` as-is).

## When producing work
- Link `styles.css` and use `var(--token)`; no raw hex in UI code.
- Reuse components and match their `.d.ts` props before inventing new ones.
- Copy assets out of `assets/`; never hand-draw icons.
- If you change a token, update the CSS first, then the spec JSON, the Tailwind preset and `DESIGN.md`.
