# DESIGN.md — Mat Monkey Design System

> **Source of truth.** Future Claude (and human) sessions should read this file first. When this file and any other doc disagree, this file wins; when this file and the token CSS disagree, the CSS in `design-system/tokens/` wins and this file should be updated.
>
> Version 1.3.0 · Last updated 2026-11-04

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
**Mat Monkey** is a mobile-first social app for the Jiu-Jitsu community. Its job is to get training partners to **show up and train together in real life**: connect with partners (instant QR), plan sessions as easily as inviting a friend to hang out, share a photo memory after training, see friends' sessions, and keep **weekly friendship streaks**. Think Strava meets a close-knit academy: less competitive, more playful, focused on friendships.

One product surface: the **iOS/Android app** (390pt, light-first). Four tabs (Activity, Training, Goals, Stats) and a center **Plan a training** button.

### Following and session invitations
Scanning a code and tapping Follow create the same mutual training-partner connection immediately, with no approval. Both people can see each other's activity, invite each other to train, and explicitly share notes and goals. Personal notes stay private until shared. Unfollowing removes the connection for both people; it does not block them or erase shared training history.

An invitation shows the host with Accept and Decline. Accepting unlocks the session title, time, venue, notes, focus and guest list. Following, a pending invitation, or opening a session link does not reveal these details. Link previews are generic. Upcoming sessions appear only for the host and accepted guests.

### Sources & provenance
- Product brief pasted by the user (vision, 8 screens, 3 journeys, MVP constraints). No codebase, Figma, or brand files were provided. This is an original direction.
- **Logo: the Silverback** (adopted v1.1.0). A geometric gorilla head with a coral brow band, paired with the lowercase wordmark "mat monkey." in Bricolage Grotesque 800 with a coral period. Files live in `assets/brand/`; rules in §5.1. **Mat Monkey** is the product name as of design-system v1.2.0. Existing bundle identifiers, callbacks and storage keys (including `matmind.hasCompletedOnboarding` and `matmind.reflection.reminder`) retain their original values so existing installs, links and sign-in continue working.
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
- **Buttons:** verb-first, friendly: "Plan a training", "Join", "Invite Sarah to train", "Complete & share", "Start again".
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
| `assets/brand/logo-lockup.svg` | Horizontal lockup: mark + "mat monkey." wordmark. |

- **Colors:** ink `#1D1B18`, paper-3 `#E9E0D1`, coral `#FF5C39` brow; app icon ground sun `#FFC93C`. Nothing else.
- **Lockup:** mark left of the wordmark, mark height ≈ 1.7× the wordmark cap height, gap ≈ 0.3× mark height. The wordmark is always lowercase with a coral period (ink period on coral).
- **Clear space:** at least the brow band's height on every side.
- **Minimum size:** mark 24px tall; lockup 120px wide; below that use the mark alone.
- **Don't:** recolor the head, swap the brow to belt or friend hues, add outlines, shadows, gradients, or expressions, rotate it, place the ink head directly on ink (use the app-icon tile), or redraw it. Use the files.
- **In code:** use the `Logo` component (`design-system/components/core/Logo.jsx`, variants `mark` / `mono` / `appIcon` / `lockup` / `lockupInverse`). It draws from tokens, so no asset paths are needed.
- **In the app:** the full lockup (mark + wordmark) appears on the splash screen and onboarding. Activity, Training, Goals and Friends headers show the mark alone at 32pt, left of the plain Bricolage screen title. Profile hides the mark and shows only its title and Settings gear; pushed screens with a back button show the title only. The mark also appears as a character in empty-state artwork. One logo (mark or lockup) per screen at most, not counting empty-state artwork.

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
| **Monkey** | after the name, not the avatar · sizes: 16 (comments, tickets) / 20 (posts, lists) / 28 (profile) · fur: ink-900 / ink-700 / ink-500 / coral-700 / sky-700 / plum-700 / mint-700 · face: white · no backdrop |
| **AvatarStack** | overlap: 32% of size · ringWidth: 2.5 |
| **Belt** | sizes: xs 8, sm 12, md 16, lg 24 · stripes: 0–4 · bar: black; red for black/coral/red belts |
| **StreakBelt** | segment: 1 calendar week (Mon–Sun) · states: done / missed / pending-hatched · hues: friendHues |
| **Tabs** | variants: segmented / underline |
| **TabBar** | height: 86 · items: Activity / Training / Goals / Profile · centerAction: Plan a training (coral, 56×46 pill) |
| **Dialog** | variants: sheet / modal · sheetRadius: xl top · overlay: surface-overlay |
| **Toast** | shape: ink pill · variants: default / success / danger / streak / friend · autoDismissMs: 2600 |
| **Tooltip** | surface: ink-900 · radius: 10 |

Groups: **core/** Button, IconButton, Icon, Logo · **forms/** Input, Select, Checkbox, Radio, Switch · **display/** Belt, Avatar, AvatarStack, StreakBelt, Badge, Tag, Card · **navigation/** Tabs, TabBar · **feedback/** Dialog, Toast, Tooltip.

Prototype-level patterns (in `ui_kits/app/Shell.jsx` and `Training.jsx`, candidates for promotion): **TapeLabel**, **PairAvatars**, **SessionTicket**, **PhotoTile**.

## 7. Iconography
- **Set:** Lucide (outline, round caps and joins). 2px stroke by default, 2.25 in buttons, 2.5 for the active tab. CDN-available, ISC license. **This is a substitution; no brand icon set was provided.**
- **Delivery:** about 75 glyphs copied into `assets/icons/*.svg` and embedded in `design-system/components/core/Icon.jsx` (`<Icon name="qr-code" />`). To add more, copy from `https://unpkg.com/lucide-static@0.454.0/icons/<name>.svg` into both.
- **Key glyphs:** house (Activity), calendar (Training), notebook-pen (Goals), user (Profile), users (Friends), plus (create), flame (streak, filled when alive), qr-code / scan-line (add friend), handshake (connected), calendar-plus (invite to train), camera / image-plus (photo), map-pin (gym), link (invite link), lock / globe (privacy).
- **Color:** inherit currentColor. Active like = coral, filled. Flame = flame orange, filled when the streak is alive and grey outline when not.
- **No emoji, no unicode icons** (only "·" as a meta separator). No PNG icons.

## 8. Screens & journeys
Tabs: **Activity** (open upcoming plans and completed sessions) · **Training** (upcoming and past) · **Goals** (what you're working on) · **Profile** (me, friends and streaks, my sessions). The center tab button is **Plan a training**.

Upcoming link-visible sessions appear in the host's and accepted guests' Activity, ordered soonest first. Followers receive a generic invitation with Accept and Decline; session tickets and details appear only after acceptance. Opening an invitation link creates a pending invitation and never accepts automatically. Declined, started, cancelled and completed plans leave Coming up. Publishing a completed session creates a separate memory with the existing photo-or-note rule, visible to its participants and followers. Blocks revoke access. Invitation links require a Mat Monkey account.

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
| 9 | Search & discover people | `Prototypes/MatMind/Features/Friends/FriendsScreen.swift` (`PeopleSearchScreen`) |
| 10 | Someone else's profile | `Prototypes/MatMind/Features/Profile/ProfileScreen.swift` (`PersonProfileScreen`) |

Journeys:
- **A — Plan together:** Training → Plan a training → gym/date/time → invite → friends join → session shows participants.
- **B — Share a memory:** completed session → take or upload a photo and/or write a note → publish → post on every participant's profile and friends' feeds → likes/comments. A photo **or** a note enables publishing (see Share the session); no completion toggle is required.
- **C — Keep a streak:** Stats → Friends → active streak → friend profile → invite → complete together → streak +1.

Streak rule: a week counts when two friends both participate in ≥1 **completed** session together within the same Mon–Sun calendar week; consecutive weeks extend the streak.

### Share the session

**Rule: a photo or a note, at least one.** Photos are optional, but a post is never blank. **Complete & Share** unlocks once there is a photo, a note, or both; already completed, unshared sessions use **Share a memory**. The session focus ("What we worked on") is copied from the plan and never counts on its own. A note that is only whitespace or only `@tags` counts as empty (trim before checking).

- **Remember the session.** The Activity prompt and the white details card above the photo area use "How was {session title}?", preserving the full session title. The details card shows the gym, host, session access and saved session note when present; omit the date and time. Allow long text to wrap. Show the full "What we worked on" outline immediately below the details, before the photo area; "Who trained" remains below the caption. Keep the saved session note separate from the new post's caption.
- **Keep the photo with the training.** Taking or uploading a photo saves it to the session immediately, even if the organizer closes the composer without publishing. Show a Photos section on training detail above the focus outline, with a count and the saved photos. Before the first photo, show the hatched camera prompt and organizer guidance; only the organizer can add photos, after the session starts. Accepted guests can see saved session photos. Publishing reuses the selected photo; it does not create a second copy.
- **Label the note.** Show **Caption** above the "What happened on the mat?" text box using the standard field label.
- **Say the rule up front.** One hint line sits centered above Publish (13px Archivo with a 16px Lucide icon). Neither field is labeled required or optional.
- **Nothing yet:** Publish uses the standard disabled button (no shade edge). Hint: info icon, ink-700, “Add a photo, a few words, or both to share.”
- **Publish tapped while empty:** no banner, toast or dialog. The hint turns coral-700 with a circle-alert icon, “Add a photo or a few words first”, and the note field takes focus (`--ring-focus`, keyboard up), since typing is the fastest fix. Announce the hint to VoiceOver.
- **Photo, no note:** the photo fills the slot with Retake and Remove. The note placeholder becomes “Add a few words? @tag a partner”. Hint: circle-check, mint-700, “Photo's in. Words are a bonus.”
- **Note, no photo:** the photo slot stays as the hatched prompt, but Take photo turns white so Publish is the only coral button. Hint: “Words are in. A photo's a bonus.”
- **Both:** hint “Photo and words. The crew's going to love it.”
- Removing the photo or clearing the note re-evaluates the rule immediately; the hint and button change with `--ease-out` at `--dur-fast`.

**A post without a photo** in Activity is the same white card (radius 28) with the pair header, the note as plain body-l text (17px Archivo, ink-900, coral mentions), the focus as a neutral paper-2 chip, then Like and Comment. No colored block, quote mark or placeholder image: the card is simply shorter.

### Session focus outline

Session planning keeps its existing form layout and controls. A compact **Add a focus** action beside Add a note expands the optional **What are we working on?** section. The browser companion must mirror the original date carousel, time pills, gym chips, friend grid, and privacy controls rather than replacing them with a summary. Use white focus groups on the paper canvas, Archivo body text, Lucide notebook / chevron icons, a quiet coral Add a detail action, and the existing pill buttons. Big idea first, details underneath. Adding a detail uses the existing bounce motion and respects Reduce Motion.

**Picking from goals.** When the user has goals, they appear as small `+` tags at the top of the section ("Pick from your goals, or add your own.") and the section starts with no blank card. Tapping a goal adds a focus carrying over the goal's name only, and the tag turns selected (ink, check). Tapping the tag again removes that focus. The goal's notes are never copied into the session: a collapsed "Goal notes" toggle on that card shows them read-only on a sunken panel, so the session's details are written fresh. With no goals, the section looks as it did before, plus one tertiary hint line ("Goals you set will show up here as one-tap picks."), with no second action.

Details are one level deep: each focus card has a single Add a detail at its foot, and each detail row has its own remove button (no nested details). Keep stable IDs and sibling order. Deeper items saved by earlier builds still render indented, labeled by level, and can be removed. Suggestions only populate content when selected; never pre-fill a real user's plan. Named items are required when present; no content at all is allowed.

Removing a branch requires confirmation and removes all descendants; cancel preserves the branch. The organizer can edit the session's outline. Store it with the session and copy it to the completed post so publication does not discard the plan. Read-only outlines retain the same hierarchy. **Posts show focus names only, never details:** in the Activity feed, one horizontally scrolling row of small non-interactive tags directly under the post title, led by a notebook icon on a sunken circle (the caption clamps to two lines); on post detail, the same tags wrapping under "What we worked on". No technique scoring, rankings, completion counters, or free-form posts are added.

Native: `TrainingFocus.swift` and `Features/Focus/TrainingFocusEditor.swift`. Browser companion: `Prototypes/FocusPreview/`.

### Activity feed

Activity shows the private This week strip, Coming up and completed-session posts. Coming up contains hosted/joined personal open plans, including friends-only plans and started plans awaiting attendance; a separate quick log never closes or removes them. The ink How was…? catch-up prompt lives in Training. It has no friendship streak reminder cards ("8 weeks with Sarah" / "Roll together by Sunday").

### Week strip and quick logs (UI preview)

The quick-log database is deployed through `20261105212524_quick_training_log.sql`. Live accounts enable the shared quick-log UI when their snapshot exposes all four feature fields. The **QuickTrainingLogMock** scheme continues to use isolated seeded data without a runtime. Older backend snapshots keep the existing Activity flow and read-only Profile heatmap; unsupported operations remain disabled.

In the mock, the dark quick-log strip appears first. The calendar prompter sits
below on paper-2, with ink-900 title, ink-700 metadata, a white calendar tile and
a secondary View session button so quick logging retains the main emphasis.
Initially show the closest upcoming session you host or accepted, with **Coming
up: {title}**, its date/time/gym, and **View session**. Keep that session after its
start and across tab switches until completion; a day-only quick log never
completes it. Then advance to the next open session, or hide the prompter if none
remain. Reuse the existing tilted calendar tile, 24pt card shape and layout.

The preview Activity card uses ink-900, paper text, 24pt radius and no shadow. Its heading is **This week**, followed by **Tap a day to quickly log your training.** in 13pt ink-200. There is no trained-day count. Seven equal columns have an 11pt weekday and a 40pt date circle. Trained days are solid coral; today has a coral ring; future dates are outlined, with a dashed outline for plans. Corner badges show ×N and/or a calendar. Below the dates, show **[calendar] = You have a planned session** in 12pt ink-300 when a plan exists.

Tapping a planned day or either badge always opens **What are you logging?** with the planned session and **A quick log** options, even when the day already has logs. Selecting a started host plan opens its existing Complete & Share composer without writing attendance or creating a session. Selecting an accepted guest plan opens session details without changing attendance. Photos may be saved before completion; only the organizer’s explicit **Complete & Share** confirms completion and attendance. Closing the composer leaves the plan open. Completed sessions may offer **Share a memory**, but never show an active Complete & Share beside Completed. Unstarted plans are disabled; future quick logs are disabled. Other elapsed dates open the technique sheet before saving a private quick log. A count tap removes the latest log only on a date with no planned or confirmed session. Successful saves offer Undo and never publish automatically.

Quick logs open a content-sized white sheet headed **What did you hit today?**, with no date title, day picker, search or privacy helper. Save log follows the content with the shared dialog action spacing. Start with Heel hook, Back take and Armbar; use 44pt minus/plus buttons and zero counts. **Add technique** opens a plain name field with separate Cancel/Add technique buttons. Cancel text aligns with the field’s leading edge. Edit switches to removal controls with Undo. Additions and removals save immediately as the latest usual list, including edits made while logging an older date; an intentionally empty list stays empty. **Save log** requires positive reps and saves only that log’s name/count snapshots; past saved reps never change when the list changes. Use the shared dialog, text field, buttons, icons and layout tokens. Like Goals, the usual list and per-log rep details are account-scoped data on this device, without cross-device sync. The preview uses its own storage namespace; live quick logging retains the existing backend gate.

Training has Upcoming/Past lists and no standalone share prompter or Coming up heading. In Past, an unlogged hosted session replaces **You host** with a compact, right-aligned **Complete & Share** action (12pt text), opening the existing photo/note composer. A session already logged privately or published, with or without a photo, shows the **Completed** tag. Ticket footers show avatars without a going-count label. On narrow screens, the action/tag moves below the avatars while staying right-aligned.

### Your rhythm (quick-log preview)

In the mock or after explicit backend support, Stats Progress can show the interactive 17-week quick-log calendar, including older-week editing. Older backends without quick-log snapshot fields use the read-only Profile rhythm described below; the deployed backend enables the interactive quick-log calendar.

Regression commands and acceptance checks: [Quick training log UI guide](docs/quick-training-log-regression.md).

### Stats and technique trends

The personal tab and its screen heading read **Stats**, retaining the existing `user` icon and the internal `profile` route for navigation compatibility. Other people still have profile pages.

Below **Your rhythm**, show one compact line chart per technique with positive hits in a saved quick log. Unused presets and orphaned/deleted logs create no chart. The shared legend identifies solid coral as This week and a muted dashed line as Last week. Chart each Monday–Sunday day’s total, include zero for elapsed days without hits, and stop this week’s line at today; future days have no points. Show this week’s running total and last week’s full total without a percentage claim about an unfinished week. Use integer y-axis ticks, restrained grid lines, the shared paper/white card treatment and existing typography. No explanatory paragraph or new controls are needed.

Use each log’s selected `loggedOn` date, sum multiple logs per day, and combine a removed/re-added technique by its case-insensitive saved name. Older techniques retain their chart with zero recent totals; changing presets never rewrites saved history. Delete/Undo and account clearing update the chart immediately. Hit details retain Quick Log’s account-scoped on-device storage boundary. This personal technique-count view is explicitly supported; competitive rankings and leaderboards remain out of scope.

### Profile training rhythm

On your own **Stats → Progress**, **Your rhythm** sits below the section tabs, followed by the technique hit charts when saved hits exist. The Weekly/Monthly selector, period summary counts (Sessions, Partners, Photos) and session bar chart are removed. Backends without quick-log support show the static heatmap in its own white card; supported backends use the interactive rhythm card. The heatmap always shows the last 17 Monday–Sunday weeks, oldest on the left. It is private to your own Progress tab.

Each day is a 14pt square, with 4pt gaps and a 4pt radius. A logged training day is coral-500; no entry is paper-3; future days are outlined and empty. Month labels appear above and M / W / F / S labels to the left. The heading has **Since {first Monday}** and the legend reads **Trained** / **No entry**. There is no explanatory paragraph, tap hint, button, day sheet or interaction on the heatmap. VoiceOver announces a single chart summary and trained-day count.

A day fills for any past session you host or joined, including an unshared past-session log with no photo or note. This follows the existing Training/Past definition: an elapsed joined/hosted plan is also past history. Completed sessions only count when your attendance remains confirmed. Invitations, declined/cancelled sessions and future sessions do not count. Multiple sessions on one local calendar date fill one square at one intensity. The source is session history, independently of feed posts, post deletion and photos; a paginated, owner-filtered read covers the whole 17-week range beyond the schedule's 100-row limit. No quick-log records, logging controls, attendance writes or backend migrations are introduced.

Regression commands and acceptance checks: [Profile heatmap regression guide](docs/profile-heatmap-regression.md).

### Empty Activity and Training

Use the paper canvas with a small photo-memory frame for Activity and an undated ticket for Training, reusing existing typography, surfaces, icons, and pill actions. No placeholder people, fake dates, zero-stat dashboards, or loading skeletons.

- Activity artwork (all Activity empty states: a first-time user, someone who deleted their only post, and a planned first session still awaiting its photo): **Peek-a-boo**. A Silverback hides behind the photo-memory frame, springs out past its edge with `--ease-bounce`, the camera "clicks" (a white flash over the photo slot as the icon squeezes to .86), nods, then ducks back; about a 5s loop. The mark only moves as a whole and is never redrawn. Reduce Motion shows it still, peeking.
- No completed posts or plans: “Good memories start on the mat.” Plan a training session; add existing friends by QR as the secondary action when needed.
- A friends-only plan exists but no shared post or open link-visible plan: “Your first photo is on its way.” View the plan or invitation. An upcoming link-visible plan renders its Activity ticket even without any memories. Training past cards show Complete & Share for an unlogged hosted session, or Completed once it is logged.
- No upcoming sessions/invitations: “Summon your crew” Plan a training session; Already trained? Log it is secondary.
- No personal past sessions: offer Log a past session.
- No saved technique hits on **Stats → Progress**: show the **Peek-a-boo** Silverback behind a tilted white index card with three paper rules and a coral plus. Reuse the existing mark and peek/nod phases; move the asset as a whole and hold the peeking pose with Reduce Motion. Copy: **What did you hit?** · **Your technique charts start with one log.** · **Log hits**. The action opens today’s existing Quick Log sheet. The first saved hit replaces the invitation with technique charts; removing the last log restores it. No fabricated line charts, counts or legend are shown. Hide the logging invitation when the backend does not support Quick Log.
- No goals: three athletic-tape strips with example goals ("Single leg", "RNC finish", "Knee cut") drop in one after another with `--ease-bounce`, then sway gently; Reduce Motion shows them still. "What are you chasing?" · "Name it. Bring it to the mat." · **Add a goal**, with a ghost **Import from old notebook** when available. The export steps live in a dialog shown before the file picker, not on the screen.
- An empty schedule never removes completed posts from Activity. Declined invitations do not count as upcoming plans.
- Training’s ink “How was {session title}?” prompt shows the most recent completed, unshared planned session you host. Match main’s ReadyToShare prompt: 24pt card corners, 16pt padding, a 64pt paper-2 camera tile with a 3pt white rim rotated −4° on the left, and a text/action stack 14pt away. Use a 17pt Bricolage title, inline 13pt ink-200 audience copy 4pt below, and the small coral Complete & share button 10pt below that. The audience explanation sits directly on ink. Full titles and copy wrap. Complete & share opens that session’s composer. It never appears for guests or quick logs.

Native pattern: `Prototypes/MatMind/DesignSystem/Patterns/EmptyState.swift`. Browser companion: `Prototypes/EmptyPreview/`.

### Tabs, Goals and Training

Tab bar: **Activity · Training · + (Plan a training) · Goals · Profile**. Friends is no longer a tab: it opens from Profile, and the streak reminder dot sits on the Profile tab. Activity, Training, Goals and Friends headers carry **Search**, **Notifications** (with the shared unread count), and **My code** (QR), in that order. Profile shows only its title and **Settings** gear, with all other header icons hidden. Header actions retain 44pt tap targets; titles can scale down to fit narrow screens. Other pushed screens keep their own back and action buttons.

- **Training** has **Upcoming** and **Past** tabs using the same ticket cards, spacing and layout. Upcoming shows Invites (Decline / Join) and Coming up, soonest first. Past shows sessions whose start time has passed, newest first, including sessions without a photo or shared post and completed sessions. Declined and cancelled sessions stay out. Editing the date moves a session between tabs; publishing keeps it in Past. Every upcoming ticket carries an ellipsis menu with **Share session**. For a host in the live app, it creates an invitation URL and opens the native share sheet with that URL, enabling the rich preview described below. Other participants and the demo share the existing plain-text summary (name, date/time including timezone, and gym), without granting invitation permissions. Uncompleted tickets you host also offer: **Edit session** (name, date and time, gym, note, **What we're working on**, and **Guest list**) and **Delete session** (confirmed; it comes off everyone's schedule). Focus and guest changes stay in the draft until **Save changes**. The organizer stays on the list; retained guests keep their RSVP and newly added friends receive invitations for upcoming sessions. Stats → Activity still shows shared posts.
- **Goals** lists what you're working on as white cards: name, a two-line notes preview, link/photo counts and when it's next on the mat ("On Sat with Sarah", never a score). **Add a goal** sits in the section header; its sheet has the name, notes and **References** (an **Add photo** tile and **Add a link**, each removable before saving; photos are saved when the goal is added). **Import** (in the empty state, a quiet link under the list) reads the file from Settings → Export local sessions (the .zip, or its training-v1.json): each active goal keeps its name; each task becomes a "- Task: notes" line, with its link and photos. Archived goals, sessions and reflections are left out, and importing twice adds nothing.
- **Goal page** is edited in place: the name (a 28pt display field) and next session; **Details** as a multi-line field ("-" starts a sub-point); **References** (photos, with an **Add photo** tile that opens the photo library and touch-and-hold to remove; links shown by host in mono, opening in the browser; **Add a link**). Goal photos are re-encoded as JPEG without location metadata, capped at 2048 px and stored privately on the device; an ellipsis menu with **Plan a training for this** (attaches the goal to the session you create) and Delete goal; and the primary **Save goal**, enabled once the name or details change. Leaving with unsaved edits asks before discarding. Photos and links save as soon as they're added.
- **Stats → Friends:** a card with friend avatars and the count (opens the friends list), or "Add your first training partner" (opens My code), followed by Weekly streaks and Activity.
- Goals are personal (name, free-form notes, reference links and photos). They're stored on the device per account and attached only to sessions in your own schedule until you share one. No progress, completion counts or rankings.

### Sharing goals

Sharing works like a session invite. Goals has two segmented tabs under the title, **Mine** and **Shared**; Shared carries the coral count badge while invitations are waiting.

- **Share** (the share icon on the goal page, also in its ellipsis menu) opens a sheet: "Share <goal>", a line saying exactly what goes along (notes, parts, videos, photos, links; read-only, saved edits come through), a row of training partners (56pt avatars with belt rings; a picked one gets a coral ring and check, ones who already have it read "Has it" or "Invited" and can't be picked again), **Copy a link to this goal**, a lock-icon note that the link needs a Mat Monkey account, and the primary **Share with Dani** / **Share with 2 partners**. Unsaved edits must be saved first.
- **The shared goal page** (from the notification, a link or **Look**) opens with who sent it: tied avatars on the sender's friend-hue tint, "Sarah Lee shared a goal with you", belt · gym · when. Then the name (28pt), "Sarah's notes · read-only", Details, the parts (notes, video row, photos) and References. A pending invitation has a sticky footer: "Lands in Goals under Shared. Sarah's edits come through.", secondary **Decline** and primary **Add to my goals**. Accepting switches Goals to Shared with the toast "<goal> is in Shared"; declining reads "Declined. No hard feelings." An accepted goal's ellipsis menu has **Remove from Shared**.
- **Goals › Shared** lists **Invites** (avatar, "Kenji shared Berimbolo entries", what's inside · when; ghost Decline, secondary Look, inverse Accept, matching session invites) and **Shared with you** (white cards with a "From Sarah" chip on the sender's hue, the notes preview and what's inside). With nothing shared, a sunken card reads "Nothing shared yet".
- **Links** (`/goal/<token>`, valid 30 days) work for anyone with an account, friend or not. Opening one creates the same pending invitation; opening your own opens your goal. Without the app, the web fallback only says someone shared a goal and offers the App Store; it never shows the goal's content.
- Shared copies follow the owner's saves. Deleting a goal stops sharing it for everyone; blocking hides it. There's still no feed, discovery, comments or chat on goals.

Native: `Features/Goals/GoalsScreen.swift`, `Features/Goals/GoalSharing.swift`, `Features/Training/TrainingScreen.swift`, `MatGoal` and `SharedGoal` in `App/Models.swift`.

### External shared-link previews

Training-session links show a useful summary before opening the app: session title,
date/time with timezone, gym, confirmed participant names (up to three plus a
remaining count), and up to three top-level focus names. Full session notes and
nested focus details remain inside the app. This session summary is intentionally
visible to anyone receiving the bearer invitation link. Friend and goal links use
generic branded previews; goal content remains private.

Use the ticket motif: **paper-3** main canvas, **coral-500** date stub, ink text,
white focus chips, and the supplied monochrome Silverback on coral. Headline in
Bricolage Grotesque 800, body in Archivo, Lucide location and people icons. Design
canvas 1200 × 630. Long titles fit two lines; full metadata and the browser summary
retain the original title and details. No pretend buttons in the preview image.

An HTTPS link supplies server-rendered Open Graph / Twitter metadata and a PNG
image, and routes to the exact native invitation via Universal Links. The web
fallback has **Open in Mat Monkey** and App Store actions. It does not redeem an
invitation. After installation, return to the original link. Expired, revoked, and
cancelled session links show an unavailable state. Social apps control preview
layout and caching.

Implementation: website repository `your-note-haven`, with the read-only
`invitation_preview` RPC in this repository. Rollout: `website-link-handoff/README.md`.

### Search & people profiles

**Your circle** is your training partners plus the people they train with (one shared partner is enough). Suggestions and name search come from it. Explicit username search can find someone outside your circle; following that account has the same behavior as scanning their code. Circle members can see each other's name, belt, gym and photo.

- **Profile navigation:** tapping a member name or avatar in a post, comment, participant list, notification or shared-goal sender opens that member's profile. Inline names keep their existing typography and link by member ID; tapping your own name opens your Profile tab. Comment expansion, notification details, RSVP and guest selection keep their separate actions.
- **Entry:** a round paper-2 **Search** button (Lucide `search`) in Activity, Training, Goals and Friends headers, before Notifications and My code. It pushes Search from the current screen; Back returns there.
- **Search**: back button and a search field ("Search name or @username") at the top. Before typing, **Suggested for you** · "People who train with your training partners": a plain list, most shared partners first. Rows show a 48pt avatar with belt ring, name (display 16), @username, gym and mutual partners. The row opens the profile; **Follow** sits on the right as a small inverse pill with `user-plus`, and turns into a secondary **Following** pill with `check` (tap again to unfollow). Name search matches word starts in your circle. At three valid username characters, a debounced server lookup adds up to 20 username prefix matches from outside your circle, with optional `@` and case-insensitive matching. Username results come first and duplicates are removed; results include an xs belt strip with belt · gym. Blank, short and malformed queries never enumerate accounts. Blocked accounts and yourself are omitted. Show loading and retry states; ignore cancelled responses. No match: "No people found", with a hint to check the username or scan a code. Follow is disabled while saving and restores its prior state if saving fails.
- **Someone else's profile** reuses the personal profile header (80pt avatar, 28pt name, @username · gym, belt strip), then the same partners row as your own profile (a 30pt avatar stack, "12 training partners", chevron) that opens **Rafa's training partners**: the full list, **Your training partners** first, then **Others**, in Search's row style. Then a full-width primary **Follow Rafa**, or a secondary **Following** that opens an "Unfollow Rafa?" sheet ("You can follow again anytime"). Two underline tabs only: **Activity** (ticket stubs grouped by week, "with …" listing everyone but the profile's owner) and **Gallery** (3-column photo grid by month). No Progress and no Training partners tab. A closing line explains the scope: "You see the sessions Rafa trained in with you or your training partners."
- **Partner lists** are visible for anyone in your circle, and include people outside it: every row has Follow (your own partners included), and you can open their profiles. People outside your circle appear only through explicit username search, not suggestions, and show no partner list of their own before connecting.
- **Following** and QR scanning create the same mutual training-partner connection, instantly and without approval. Both partners see each other's activity, can invite each other, and can explicitly share notes and goals. Unfollowing removes the connection both ways; blocking also prevents reconnection. Tapping anyone, training partners included, opens this same profile page. A training partner's version adds your streak line under the header ("8-week streak together · 31 sessions together", flame only while the streak is live) and a secondary **Invite to train** beside Follow, which keeps the streak journey (Stats → Friends → partner → invite).

Native: `PeopleSearchScreen`, `PersonProfileScreen`, `AppModel.circle` / `following`. Backend: `supabase/migrations/20261104150000_people_and_follows.sql` (`follows`, `in_circle`, `my_circle`, `set_follow`), `20261104160000_partner_lists.sql` (`partners_of`) and `20261105181902_username_people_search.sql` (`search_usernames`, `follow_username`).

### Monkeys

Every member can have a **monkey**: a minimal two-color face that sits **right after their name**, about the height of the text. It never replaces the avatar; photos, initials, belt rings and friend hues stay as they are. No monkey yet means just the name, with no placeholder.

- **Drawing:** a round fur head, two ears with light centers, a peanut-shaped white face mask, dot eyes and a single mouth line, all drawn in the fur color. No backdrop circle, outline, blush, highlight or attire. It's a separate character from the Silverback, which is never redrawn.
- **Options (three, nothing more):** **Mood** (Oss., Good rolls, Game face, Round six, Side-eye, Tapped), **Fur** (Midnight `ink-900`, Charcoal `ink-700`, Smoke `ink-500`, Ginger `coral-700`, Navy `sky-700`, Grape `plum-700`, Moss `mint-700`; dark tokens only, at least 3:1 on white, because the features are drawn in the fur color. Monkey fur is the one place friend-hue 700s appear outside a friendship, and a monkey's fur never signals one) and **Haircut** (Clean, Tuft, Fringe, Mohawk, Top knot, Curls). The face is always white. A monkey that isn't built yet (the invitation sheet, the Account row) is drawn in `ink-300` (`--text-disabled`), never faded with opacity.
- **Sizes:** 28 on profile headers, 20 in post headers and lists, 16 in comments and tickets. Inside a sentence ("Sam trained with Lena & Kenji") each first name carries its own monkey.
- **Builder:** a large preview, a "Name + monkey" chip, one hint line, a segmented **Mood · Fur · Haircut** control and a 3-column grid of white tiles. Every tile previews *your* monkey with that option; the selected tile gets a 2pt ink border. Changes pop with `--ease-bounce`; Reduce Motion skips the pop.
- **New members:** profile setup is four steps. 1 Details ("First, who's rolling?", button **Next**) · 2 **Meet your monkey** (a random one is already waiting; Build my monkey, or Keep this one / Skip) · 3 **Build** ("Looks like me") · 4 **Reveal** ("Looking sharp, Sam.", a tilted polaroid and a name-row preview) with **Complete my profile**, which saves the profile and the monkey together.
- **Existing members:** one sheet on Activity, once the feed is up, never over a pushed screen: "Your monkey's waiting, Lena." · "Your monkey goes next to your name." · **Build my monkey** / **Maybe later**. Building opens the builder over the current screen; **Save my monkey** closes it onto the same screen, refreshed with the monkey after their name, and the toast "Fresh monkey on the mat". Maybe later (or swiping the sheet away) ends the invitation; **Account** keeps a **Build my monkey** row (later **Edit my monkey**).
- **Storage:** `profiles.monkey` holds `mood.fur.haircut` (null until built), changed only through the `set_monkey` command and returned in the snapshot like the rest of the profile.

Native: `DesignSystem/Components/Display.swift` (`MMMonkey`, `MMMonkeyLook`, `mmMonkey`, `mmMonkeyText`), `Features/Profile/MonkeyScreens.swift`, profile setup in `MatMind/App/MatMindRoot.swift`. Backend: `supabase/migrations/20261104170000_monkey_avatars.sql`.

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
- Public browsing or matching. Suggestions and name search stay inside your circle; explicit username lookup is available to follow someone as you would by scanning their code.
- Group chat / DMs.
- Daily streaks.
- Leaderboards.
- Badges or milestones.
- Performance analytics.
- Avatar options beyond the monkey (mood, fur, haircut): no outfits, accessories, photo filters or extra colors.
- Emoji in UI chrome.
- Gradients as decoration.
- Pure black text.
- Altered, redrawn or recolored logo (use `assets/brand/` files as-is).

**Product constraints (MVP)**
- Activity shows upcoming link-visible session tickets and posts tied to completed sessions; the completion flow remains the memory composer.
- Join sessions via invitation, direct addition, a valid link (Mat Monkey account required), or a friend's upcoming link-visible ticket in Activity. No public discovery of strangers.
- Only the organizer can publish, edit, or delete the shared Activity post; participants can like, comment, and remove themselves. Confirmed attendees can separately post one session photo each after training, replace it or remove it. Session photo cards show the author's name and photo; only their own card has a menu. A participant photo does not publish an Activity post or change attendance. Photos stay below the session focus and use the existing session audience.
- Friends connect instantly via QR, with no requests or approvals.

## 10. Working with this system (for Claude)
1. Read `DESIGN.md`, then `.claude/design-system-spec.json` for exact values.
2. Link `styles.css` (or the five token files) and use `var(--…)` tokens, never raw hex in UI code.
3. Reuse components from `design-system/components/` before inventing new ones; match their `.d.ts` props.
4. Copy icons from `assets/icons/` and fonts from `assets/fonts/`; don't hand-draw SVGs or use emoji.
5. When adding a token, update the CSS first, then regenerate the spec JSON / Tailwind preset and this file.
6. Native iOS (SwiftUI): mirror the semantic aliases as `Color` assets with the same names (`bgApp`, `surfaceCard`, `textPrimary`, `accent` …) and the type scale as `Font` extensions.
