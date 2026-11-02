# DESIGN.md — Mat Monkeys Design System

> **Source of truth.** Future Claude (and human) sessions should read this file first. When this file and any other doc disagree, this file wins; when this file and the token CSS disagree, the CSS in `design-system/tokens/` wins and this file should be updated.
>
> Version 1.2.0 · Last updated 2026-11-02

## Contents
1. Product
2. Repository map
3. Tokens
4. Content & voice
5. Visual foundations
6. Components
7. Iconography
8. Screens & journeys
9. Guardrails
10. Working with this system (for Claude)

---

## 1. Product
**Mat Monkeys** is a mobile-first social app for the Jiu-Jitsu community. Its job is to get training partners to **show up and train together in real life**: connect with partners (instant QR), plan sessions as easily as inviting a friend to hang out, share a photo memory after training, see friends' sessions, and keep **weekly friendship streaks**. Think Strava meets a close-knit academy: less competitive, more playful, focused on friendships.

One product surface: the **iOS/Android app** (390pt, light-first). Four tabs (Activity, Training, Friends, Profile) and a center **Plan a session** button.

### Sources & provenance
- Product brief pasted by the user (vision, 8 screens, 3 journeys, MVP constraints). No codebase, Figma, or brand files were provided. This is an original direction.
- **Logo: the Silverback** (adopted v1.1.0). A geometric gorilla head with a coral brow band, paired with the lowercase wordmark "mat monkeys." in Bricolage Grotesque 800 with a coral period. Files live in `assets/brand/`; rules in §5.1. **Mat Monkeys** is the product name as of design-system v1.2.0. Existing bundle identifiers, callbacks and storage keys (including `matmind.hasCompletedOnboarding` and `matmind.reflection.reminder`) retain their original values so existing installs, links and sign-in continue working.
- Fonts (Google Fonts, self-hosted in `assets/fonts/`): **Bricolage Grotesque** (display), **Archivo** (body), **JetBrains Mono** (codes/links only).
- Icons: **Lucide v0.454.0** (ISC), copied from `lucide-static` into `assets/icons/` and embedded in `design-system/components/core/Icon.jsx`.
- Photos: Unsplash (free license), 10 training photos in `assets/photos/`. Swap for real community photos when available.

## 2. Repository map
| Path | What it is |
|---|---|
| `DESIGN.md` | This spec |
| `README.md` | Short introduction |
| `.claude/skills/mat-monkeys-design/SKILL.md` | Agent skill: core rules and guardrails, loaded by Claude Code |
| `.claude/design-system-spec.json` | Machine-readable tokens, palettes, component parameters |
| `styles.css` | Global CSS entry point, `@import`s only |
| `design-system/tokens/` | `fonts.css`, `colors.css`, `typography.css`, `spacing.css`, `base.css` (CSS custom properties on `:root`) |
| `design-system/tailwind.config.js` | Tailwind preset mapped to the CSS variables |
| `design-system/components/` | React primitives (`.jsx` + `.d.ts` + `.prompt.md`), one preview `*.card.html` per group |
| `guidelines/` | Foundation specimen cards (HTML) |
| `ui_kits/app/` | `index.html` interactive prototype, `flows.html` IA & journeys |
| `assets/brand/` | Logo: `logo-mark.svg`, `logo-mark-mono.svg`, `app-icon.svg`, `app-icon-1024.png`, `logo-lockup.svg` |
| `assets/fonts/`, `assets/icons/`, `assets/photos/` | Webfonts, Lucide SVGs, sample photos |

## 3. Tokens
All tokens are CSS custom properties on `:root`. Use semantic aliases in UI code; use base ramps only when building new tokens.

### 3.1 Color — base ramps
**Paper & ink**
| Token | Value |
|---|---|
| `--paper` | `#FAF6EF` |
| `--paper-2` | `#F3ECE0` |
| `--paper-3` | `#E9E0D1` |
| `--white` | `#FFFFFF` |
| `--ink-900` | `#1D1B18` |
| `--ink-800` | `#2E2A25` |
| `--ink-700` | `#4A453D` |
| `--ink-500` | `#756E62` |
| `--ink-400` | `#9A9284` |
| `--ink-300` | `#BDB5A7` |
| `--ink-200` | `#DDD5C7` |
| `--ink-100` | `#EDE6DA` |

**Coral (primary)**
| Token | Value |
|---|---|
| `--coral-100` | `#FFE4DB` |
| `--coral-300` | `#FF9C80` |
| `--coral-500` | `#FF5C39` |
| `--coral-600` | `#EB4521` |
| `--coral-700` | `#C2350F` |

**Friend palette:** each friendship gets one hue and keeps it everywhere (streak belt, pair card, session ticket).
| Token | Value |
|---|---|
| `--sun-100` | `#FFF1C7` |
| `--sun-400` | `#FFC93C` |
| `--sun-600` | `#E0A100` |
| `--mint-100` | `#D6F5E8` |
| `--mint-500` | `#1FB27E` |
| `--mint-700` | `#0E7A55` |
| `--sky-100` | `#DCE6FF` |
| `--sky-500` | `#3E6BFF` |
| `--sky-700` | `#2347C4` |
| `--plum-100` | `#EDE3FF` |
| `--plum-500` | `#8D63F0` |
| `--plum-700` | `#5E3BB5` |

**Flame (streaks only)**
| Token | Value |
|---|---|
| `--flame-500` | `#FF7A1A` |
| `--flame-100` | `#FFE8D4` |

**Belt ranks (only to represent rank)**
| Token | Value |
|---|---|
| `--belt-white` | `#FFFFFF` |
| `--belt-blue` | `#1F5BD6` |
| `--belt-purple` | `#7A3FC4` |
| `--belt-brown` | `#7A4E2D` |
| `--belt-black` | `#16140F` |
| `--belt-coral` | `#E2563F` |
| `--belt-red` | `#C8232C` |
| `--belt-grey` | `#9AA0A6` |
| `--belt-yellow` | `#F2C230` |
| `--belt-orange` | `#F28C28` |
| `--belt-green` | `#2E9E4F` |
| `--belt-bar-black` | `#16140F` |
| `--belt-bar-red` | `#C8232C` |
| `--belt-stripe` | `#FFFFFF` |

**Status**
| Token | Value |
|---|---|
| `--success-500` | `#1FB27E` |
| `--success-tint` | `#D6F5E8` |
| `--warning-500` | `#E0A100` |
| `--warning-tint` | `#FFF1C7` |
| `--danger-500` | `#E5383B` |
| `--danger-tint` | `#FDE1E1` |
| `--info-500` | `#3E6BFF` |
| `--info-tint` | `#DCE6FF` |

### 3.2 Color — semantic aliases
| Token | Value |
|---|---|
| `--bg-app` | `#FAF6EF` ← `var(--paper)` |
| `--surface-base` | `#FAF6EF` ← `var(--paper)` |
| `--surface-card` | `#FFFFFF` ← `var(--white)` |
| `--surface-raised` | `#FFFFFF` ← `var(--white)` |
| `--surface-sunken` | `#F3ECE0` ← `var(--paper-2)` |
| `--surface-input` | `#FFFFFF` ← `var(--white)` |
| `--surface-hover` | `rgba(29,27,24,.04)` |
| `--surface-press` | `rgba(29,27,24,.08)` |
| `--surface-overlay` | `rgba(29,27,24,.48)` |
| `--surface-inverse` | `#1D1B18` ← `var(--ink-900)` |
| `--text-primary` | `#1D1B18` ← `var(--ink-900)` |
| `--text-secondary` | `#4A453D` ← `var(--ink-700)` |
| `--text-tertiary` | `#756E62` ← `var(--ink-500)` |
| `--text-disabled` | `#BDB5A7` ← `var(--ink-300)` |
| `--text-inverse` | `#FAF6EF` ← `var(--paper)` |
| `--text-on-accent` | `#FFFFFF` |
| `--text-accent` | `#EB4521` ← `var(--coral-600)` |
| `--text-link` | `#EB4521` ← `var(--coral-600)` |
| `--border-subtle` | `rgba(29,27,24,.06)` |
| `--border-default` | `rgba(29,27,24,.12)` |
| `--border-strong` | `rgba(29,27,24,.22)` |
| `--border-focus` | `#FF5C39` ← `var(--coral-500)` |
| `--control-off` | `#DDD5C7` ← `var(--ink-200)` |
| `--control-border` | `#BDB5A7` ← `var(--ink-300)` |
| `--accent` | `#FF5C39` ← `var(--coral-500)` |
| `--accent-hover` | `#FF6F4F` |
| `--accent-press` | `#EB4521` ← `var(--coral-600)` |
| `--accent-shade` | `#C2350F` ← `var(--coral-700)` |
| `--accent-tint` | `#FFE4DB` ← `var(--coral-100)` |

### 3.3 Typography
Families: `--font-display` **Bricolage Grotesque** · `--font-body` **Archivo** · `--font-mono` **JetBrains Mono** (links/codes only).

| Step | Size | Line height | Face |
|---|---|---|---|
| display-xl | 48px | 0.95 | Bricolage 800 |
| display-l | 36px | 1 | Bricolage 800 |
| display-m | 28px | 1.05 | Bricolage 800 |
| title-l | 22px | 1.15 | Bricolage 800 |
| title-m | 18px | 1.2 | Bricolage 800 |
| title-s | 16px | 1.25 | Bricolage 800 |
| body-l | 17px | 1.45 | Archivo 400–700 |
| body | 15px | 1.45 | Archivo 400–700 |
| body-s | 13px | 1.4 | Archivo 400–700 |
| caption | 12px | 1.3 | Archivo 400–700 |
| overline | 11px | 1.2 | Archivo 400–700 |

Tracking: display `-0.03em`, title `-0.015em`, overline `0.1em`.

### 3.4 Spacing, layout, radii
| Token | Value |
|---|---|
| `--space-0` | `0` |
| `--space-1` | `2px` |
| `--space-2` | `4px` |
| `--space-3` | `6px` |
| `--space-4` | `8px` |
| `--space-5` | `12px` |
| `--space-6` | `16px` |
| `--space-7` | `20px` |
| `--space-8` | `24px` |
| `--space-9` | `32px` |
| `--space-10` | `40px` |
| `--space-11` | `56px` |

Layout: screen gutter 16px · tap target 44px · header 54px · tab bar 86px · section gap 22px · design frame 390×844.

| Token | Value |
|---|---|
| `--radius-xs` | `6px` |
| `--radius-sm` | `10px` |
| `--radius-md` | `14px` |
| `--radius-lg` | `22px` |
| `--radius-xl` | `28px` |
| `--radius-pill` | `999px` |

### 3.5 Elevation
| Token | Value |
|---|---|
| `--shadow-none` | `none` |
| `--shadow-hairline` | `0 0 0 1px var(--border-subtle)` |
| `--shadow-card` | `0 1px 0 rgba(29,27,24,.04), 0 6px 18px rgba(29,27,24,.06)` |
| `--shadow-float` | `0 12px 32px rgba(29,27,24,.16), 0 0 0 1px var(--border-subtle)` |
| `--shadow-sheet` | `0 -10px 40px rgba(29,27,24,.18)` |
| `--shadow-press` | `0 3px 0 var(--accent-shade)` |
| `--ring-focus` | `0 0 0 3px var(--accent-tint), 0 0 0 1.5px var(--border-focus)` |

### 3.6 Motion
| Token | Value |
|---|---|
| `--ease-out` | `cubic-bezier(.2,.8,.2,1)` |
| `--ease-in-out` | `cubic-bezier(.65,0,.35,1)` |
| `--ease-bounce` | `cubic-bezier(.34,1.56,.64,1)` |
| `--dur-fast` | `140ms` |
| `--dur-base` | `220ms` |
| `--dur-slow` | `420ms` |

## 4. Content & voice
Voice: **your favorite training partner.** Warm, a little cheeky, mat-literate, never preachy or competitive.
- **Person:** "you" for the user. Friends by first name ("Roll together by Sunday to make it 9"). The product never says "we".
- **Casing:** sentence case everywhere: buttons, titles, badges. The wordmark is lowercase. No ALL-CAPS labels except the 3-letter day on session tickets (SAT).
- **Buttons:** verb-first, friendly: "Plan a session", "Join", "Invite Sarah to train", "Complete & share", "Start again".
- **Streak copy is encouraging, never guilt:** "8 weeks with Sarah", "Roll together by Sunday to make it 9", "This week's locked in". A broken streak reads "Pick it back up · best 12 weeks", never "You lost your streak".
- **Celebrate people, not numbers:** "Shared with the crew", "You & Lena are friends", "Sarah joined Saturday open mat". Avoid stats, scores, and rankings.
- **Light humor in empty and prompt states:** "Sweaty, smiling, slightly crooked. That's the one." / "Rolls are better with friends."
- **Jargon:** real BJJ words, unexplained: open mat, rolls, rounds, no-gi, stripes, knee cut, leg drag.
- **Emoji:** none in UI chrome (Lucide icons instead). Users may type them.
- **Confirmations:** short and human. "You're in. See you on the mat." / "Declined. No hard feelings."

## 5. Visual foundations
- **Mood:** an academy on a Saturday morning. A warm cotton canvas, a coral pop, and a different friendly hue for every friendship. Playful and soft, not a dashboard.
- **Color:** background **Paper #FAF6EF** (unbleached gi); white cards; ink #1D1B18 text (never pure black). **Coral #FF5C39** is the single primary: CTAs, the create button, likes, focus. The **friend palette** (sun, mint, sky, plum, coral, each with a 100 tint) colors streak belts, pair cards, and session tickets; a friend keeps the same hue everywhere. **Flame #FF7A1A** is only for streaks. Belt colors appear only to show rank.
- **Type:** **Bricolage Grotesque 800** for display, titles, and buttons (tight −0.02 to −0.04em tracking). **Archivo** 400–700 for body and meta. Mono only for links and codes, not for stats.
- **Spacing:** 2px-based steps; 16px screen gutters; cards padded 14–18px; sections separated by 22px with an 18px Bricolage section title. 44px minimum tap targets.
- **Radii:** soft everywhere. Inputs 14, cards 22–24, photo posts and sheets 28, buttons/chips/tabs pill. Rounded-but-not-round is reserved for photos (20–26).
- **Cards:** white, 22–24 radius, `--shadow-card` (soft two-layer), no borders. Tinted cards (friend hue 100) for streak and nudge moments, ink cards for prompts ("How was open mat?"), sun-100 for the QR prompt.
- **Signature motifs:**
  1. **Streak belt:** each calendar week is a belt segment with a white tape stripe; consecutive weeks join into one belt; missed weeks are bare mat; the current week is a hatched slot until you train.
  2. **Athletic tape label:** a slightly rotated, ragged-edge off-white strip on photos showing the gym.
  3. **Ticket stub:** session cards with a tinted date stub, dashed tear line, and punched notches.
  4. **Tied avatars:** two overlapping avatars with a small hue "knot" bar, the friendship mark.
- **Buttons:** pill-shaped. Primary has a 3px darker coral "pressable" bottom edge that sinks 2px on press. Secondary is white with a 1.5px border and a subtle edge.
- **Shadows:** `--shadow-card` for surfaces, `--shadow-float` for toasts and modals, `--shadow-sheet` for bottom sheets. No inner shadows except hairlines and outlines.
- **Backgrounds:** flat paper. No gradients (except the faint fade under sticky footers) and no textures, apart from a 135° hatch on empty photo slots and the pending week.
- **Imagery:** real, candid training photos: warm, natural light, people mid-roll or post-class. Full-bleed inside rounded tiles; double-tap to like. Celebration uses a tilted "polaroid" frame.
- **Motion:** quick, physical, joyful. `--ease-out` 140–220ms for UI and screen pushes; `--ease-bounce` (overshoot) for joins, likes, checkmarks, switches, and the QR "connect" moment; counters flip up when streaks increase. Toasts drop from the top as ink pills. No parallax and no long page transitions.
- **Hover/press:** hover lightens to paper-2 (secondary) or a lighter coral (primary); cards lift 1px. Press sinks the primary 2px, scales icon buttons to .86 with bounce, and scales cards to .985.
- **Transparency & blur:** the bottom TabBar (white 90% + 20px blur), the dialog overlay (ink 48%), and overlay icon buttons on photos (white 88%).
- **Layout:** status bar, screen header (large 32px Bricolage title on tabs, centered 18px on pushed screens), a scrolling body, then a sticky footer CTA on task screens or the 86px TabBar on tabs.

### 5.1 Logo — the Silverback
A calm, front-facing gorilla head built from simple geometry: an ink head, a paper-3 face, a pill-shaped brow band, narrow eyes, two nostrils and a flat mouth. Strong, steady, a little cheeky; never snarling, never cute (no big round eyes, no smile).

| File | Use |
|---|---|
| `assets/brand/logo-mark.svg` | Default mark: ink head, `--paper-3` face, **coral brow**. On paper, white, or sun backgrounds. |
| `assets/brand/logo-mark-mono.svg` | Ink brow. On coral backgrounds and for one-color print. |
| `assets/brand/app-icon.svg` | 1024² app icon: default mark on **sun #FFC93C**. Also the reversed logo on ink or photos (as a rounded tile). |
| `assets/brand/app-icon-1024.png` | Opaque 1024² PNG render of the app icon, used by the iOS `AppIcon` set. Re-render it from the SVG if the SVG changes. |
| `assets/brand/logo-lockup.svg` | Horizontal lockup: mark + "mat monkeys." wordmark. |

- **Colors:** ink `#1D1B18`, paper-3 `#E9E0D1`, coral `#FF5C39` brow; app icon ground sun `#FFC93C`. Nothing else.
- **Lockup:** mark left of the wordmark, mark height ≈ 1.7× the wordmark cap height, gap ≈ 0.3× mark height. The wordmark is always lowercase with a coral period (ink period on coral).
- **Clear space:** at least the brow band's height on every side.
- **Minimum size:** mark 24px tall; lockup 120px wide; below that use the mark alone.
- **Don't:** recolor the head, swap the brow to belt or friend hues, add outlines, shadows, gradients, or expressions, rotate it, place the ink head directly on ink (use the app-icon tile), or redraw it. Use the files.
- **In code:** use the `Logo` component (`design-system/components/core/Logo.jsx`, variants `mark` / `mono` / `appIcon` / `lockup` / `lockupInverse`). It draws from tokens, so no asset paths are needed.
- **In the app:** the mark appears on the splash screen, onboarding and empty states; the tab-screen headers keep the plain Bricolage title. One logo per screen at most.

## 6. Components
React primitives live in `design-system/components/<group>/`. Each has `Name.jsx` (named export), `Name.d.ts` (props contract), and `Name.prompt.md` (usage). Styling comes only from the CSS variables, with no CSS-in-JS libraries and no npm dependencies besides React.

| Component | Key parameters |
|---|---|
| **Button** | variants: primary / secondary / soft / ghost / inverse / danger · sizes: sm 36, md 48, lg 56 · radius: pill · font: display 700 · pressEdge: 3px accent-shade, sinks 2px on press |
| **Logo** | variants: mark / mono / appIcon / lockup / lockupInverse · size: mark height or tile side, default 40, min 24 · tile: sun-400, radius 22.5% |
| **IconButton** | variants: ghost / filled / accent / overlay / inverse · defaultSize: 44 · press: scale(.86) ease-bounce |
| **Input** | minHeight: 50 · radius: md · border: 1.5px border-default · focus: border-focus + 4px accent-tint ring |
| **Select** | height: 50 · radius: md |
| **Checkbox** | size: 24 · radius: 8 |
| **Radio** | size: 24 |
| **Switch** | track: 52 / 32 · knob: 26 |
| **Card** | variants: default / sunken / outline · radius: lg · shadow: shadow-card |
| **Badge** | variants: neutral / accent / soft / success / warning / danger / info / flame · height: 24 · radius: pill · casing: sentence |
| **Tag** | sizes: sm 32, md 40 · selected: ink-900 fill, paper text |
| **Avatar** | sizes: 24 / 28 / 30 / 34 / 40 / 44 / 52 / 60 / 80 / 104 / 108 · fallback: initials on friend-hue tint · ring: belt color |
| **AvatarStack** | overlap: 32% of size · ringWidth: 2.5 |
| **Belt** | sizes: xs 8, sm 12, md 16, lg 24 · stripes: 0–4 · bar: black; red for black/coral/red belts |
| **StreakBelt** | segment: 1 calendar week (Mon–Sun) · states: done / missed / pending-hatched · hues: friendHues |
| **Tabs** | variants: segmented / underline |
| **TabBar** | height: 86 · items: Activity / Training / Friends / Profile · centerAction: Plan a session (coral, 56×46 pill) |
| **Dialog** | variants: sheet / modal · sheetRadius: xl top · overlay: surface-overlay |
| **Toast** | shape: ink pill · variants: default / success / danger / streak / friend · autoDismissMs: 2600 |
| **Tooltip** | surface: ink-900 · radius: 10 |

Groups: **core/** Button, IconButton, Icon, Logo · **forms/** Input, Select, Checkbox, Radio, Switch · **display/** Belt, Avatar, AvatarStack, StreakBelt, Badge, Tag, Card · **navigation/** Tabs, TabBar · **feedback/** Dialog, Toast, Tooltip.

Prototype-level patterns (in `ui_kits/app/Shell.jsx` and `Training.jsx`, candidates for promotion): **TapeLabel**, **PairAvatars**, **SessionTicket**, **PhotoTile**.

## 7. Iconography
- **Set:** Lucide (outline, round caps and joins). 2px stroke by default, 2.25 in buttons, 2.5 for the active tab. CDN-available, ISC license. **This is a substitution; no brand icon set was provided.**
- **Delivery:** about 75 glyphs copied into `assets/icons/*.svg` and embedded in `design-system/components/core/Icon.jsx` (`<Icon name="qr-code" />`). To add more, copy from `https://unpkg.com/lucide-static@0.454.0/icons/<name>.svg` into both.
- **Key glyphs:** house (Activity), calendar (Training), users (Friends), user (Profile), plus (create), flame (streak, filled when alive), qr-code / scan-line (add friend), handshake (connected), calendar-plus (invite to train), camera / image-plus (photo), map-pin (gym), link (invite link), lock / globe (privacy).
- **Color:** inherit currentColor. Active like = coral, filled. Flame = flame orange, filled when the streak is alive and grey outline when not.
- **No emoji, no unicode icons** (only "·" as a meta separator). No PNG icons.

## 8. Screens & journeys
Tabs: **Activity** (feed of completed sessions) · **Training** (upcoming, invites, past, plan) · **Friends** (weekly streaks, QR) · **Profile**. The center tab button is **Plan a session**.

| # | Screen | Prototype file |
|---|---|---|
| 0 | Welcome / Google sign-up and login | `Prototypes/MatMind/Features/Welcome/WelcomeScreen.swift` (native), `Prototypes/WelcomePreview/` (browser companion) |
| 1 | Activity feed | `ui_kits/app/Activity.jsx` |
| 2 | Upcoming training (+ empty state) | `ui_kits/app/Training.jsx` |
| 3 | Create training session (plan / log past) | `ui_kits/app/Create.jsx` |
| 4 | Complete & share → celebration | `ui_kits/app/Complete.jsx` |
| 5 | Friends & weekly streaks | `ui_kits/app/Friends.jsx` |
| 6 | Add friends via QR | `ui_kits/app/Friends.jsx` |
| 7 | Profile (+ account sheet) | `ui_kits/app/Me.jsx` |
| 8 | Notifications | `ui_kits/app/Me.jsx` |

Journeys:
- **A — Plan together:** Training → Plan a session → gym/date/time → invite → friends join → session shows participants.
- **B — Share a memory:** completed session → take or upload a photo → publish → post on every participant's profile and friends' feeds → likes/comments. A photo enables publishing; no completion toggle is required.
- **C — Keep a streak:** Friends → active streak → friend profile → invite → complete together → streak +1.

Streak rule: a week counts when two friends both participate in ≥1 **completed** session together within the same Mon–Sun calendar week; consecutive weeks extend the streak.

### Session focus outline

Session planning keeps its existing form layout and controls. A compact **Add a focus** action beside Add a note expands the optional **What are we working on?** section. The browser companion must mirror the original date carousel, time pills, gym chips, friend grid, and privacy controls rather than replacing them with a summary. Use white focus groups on the paper canvas, Archivo body text, Lucide notebook / chevron icons, a quiet coral Add a detail action, and the existing pill buttons. Big idea first, details underneath. Adding a detail uses the existing bounce motion and respects Reduce Motion.

Any item can have children; keep stable IDs, retain sibling order, and visually cap indentation to preserve room for text and 44pt controls. Label deeper levels explicitly. Suggestions only populate content when selected; never pre-fill a real user's plan. Named items are required when present; no content at all is allowed.

Removing a branch requires confirmation and removes all descendants; cancel preserves the branch. The organizer can edit the session's outline. Store it with the session and copy it to the completed post so publication does not discard the plan. Read-only outlines retain the same hierarchy. No technique scoring, rankings, completion counters, or free-form posts are added.

Native: `TrainingFocus.swift` and `Features/Focus/TrainingFocusEditor.swift`. Browser companion: `Prototypes/FocusPreview/`.

### Empty Activity and Training

Use the paper canvas with a small photo-memory frame for Activity and an undated ticket for Training, reusing existing typography, surfaces, icons, and pill actions. No placeholder people, fake dates, zero-stat dashboards, or loading skeletons.

- No completed posts or plans: “Good memories start on the mat.” Plan a training session; add existing friends by QR as the secondary action when needed.
- Plan exists but no shared post: “Your first photo is on its way.” View the plan or invitation. A pending completion uses Complete & share instead.
- No upcoming sessions/invitations: “Make it a mat date.” Plan a training session; Already trained? Log it is secondary.
- No personal past sessions: offer Log a past session.
- An empty schedule never removes completed posts from Activity. Declined invitations do not count as upcoming plans.

Native pattern: `Prototypes/MatMind/DesignSystem/Patterns/EmptyState.swift`. Browser companion: `Prototypes/EmptyPreview/`.

## 9. Guardrails
**Always**
- One primary button per screen.
- Coral is the only primary accent.
- Flame color only for streaks.
- Belt colors only to represent rank.
- Each friend keeps one hue everywhere.
- Posts originate only from completed sessions.
- Sentence case everywhere.

**Never**
- Free-form posts.
- Public discovery.
- Group chat / DMs.
- Daily streaks.
- Leaderboards.
- Badges or milestones.
- Performance analytics.
- Custom avatar builder.
- Emoji in UI chrome.
- Gradients as decoration.
- Pure black text.
- Altered, redrawn or recolored logo (use `assets/brand/` files as-is).

**Product constraints (MVP)**
- Activity only shows posts tied to completed sessions; the completion flow *is* the composer.
- Join sessions only via invitation, direct addition, or a valid link (Mat Monkeys account required), never from the feed.
- Only the organizer can publish, edit, or delete the shared post; participants can like, comment, and remove themselves.
- Friends connect instantly via QR, with no requests or approvals.

## 10. Working with this system (for Claude)
1. Read `DESIGN.md`, then `.claude/design-system-spec.json` for exact values.
2. Link `styles.css` (or the five token files) and use `var(--…)` tokens, never raw hex in UI code.
3. Reuse components from `design-system/components/` before inventing new ones; match their `.d.ts` props.
4. Copy icons from `assets/icons/` and fonts from `assets/fonts/`; don't hand-draw SVGs or use emoji.
5. When adding a token, update the CSS first, then regenerate the spec JSON / Tailwind preset and this file.
6. Native iOS (SwiftUI): mirror the semantic aliases as `Color` assets with the same names (`bgApp`, `surfaceCard`, `textPrimary`, `accent` …) and the type scale as `Font` extensions.
