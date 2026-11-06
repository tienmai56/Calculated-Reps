# Mat Monkey iOS

Native SwiftUI app for planning training with partners, sharing completed sessions and maintaining weekly friendship streaks.

Navigation and cached content stay interactive during network requests. Pending saves disable their guarded controls rather than the entire app, and the loading indicator lets taps pass through. Refreshing after returning to the app runs in the background. This client fix requires a new iOS build to take effect on installed devices.

Taking or uploading a post-training photo saves it to the training session immediately, even before publishing to Activity. Training detail shows a Photos section for the host and accepted guests, and the share screen labels its text box **Caption**. The backend migration `20261105075631_save_session_photos.sql` is deployed; the updated iOS client still needs to be built and installed.

Planning and logging a session start with **Jiu-Jitsu training** filled in as the title. The small X on the right clears it and focuses the field for a custom title. Keeping the default needs no typing; submitting a cleared title also uses **Jiu-Jitsu training**.

The session date picker uses the device’s local calendar and refreshes when the screen reappears, the app becomes active, the day changes, or the time zone changes. Selected dates stay on the same calendar days while they remain in range. A partly saved batch keeps its original dates for retrying.

Session links preserve existing participants' latest RSVPs when reopened. This backend fix was deployed on November 5, 2026 as `supabase/migrations/20261105053014_preserve_session_link_rsvp.sql`; see the [investigation](docs/session-link-rsvp-investigation.md).

Scanning someone's code follows them immediately. Scanning and the Follow button both grant activity visibility and permission to invite that person to train. Following remains one-way; existing training connections are migrated to follows in both directions.

“My code” uses a stable `matmind://friend/…` QR so partners on builds with different website addresses can scan each other. The updated app also recognizes existing codes from both known invitation hosts. This compatibility fix requires a new iOS build; shared session and goal links continue using the current HTTPS website.

People search accepts **name or @username**. Enter at least three username characters (with or without `@`) to find someone outside your training circle, then tap **Follow**. Username follows use the same backend connection flow as scanning their code. Search is case-insensitive, shows up to 20 username matches, and hides blocked accounts. The backend migration `20261105181902_username_people_search.sql` is deployed; the updated iOS client still needs to be built and installed.

Session invitations show only who invited you, with Accept and Decline. Session title, time, location, notes, focus and guests are returned only after acceptance. Opening a shared session link creates a pending invitation; previews contain no session details. Upcoming plans are visible only to their host and accepted guests. Apply the `follows_and_private_invitations` migration together with the updated iOS client.

Session editing supports **Add another time**. The first date and time updates the existing session and keeps retained guests’ RSVPs; added times create independent sessions with the edited details and guest list. Duplicate times are blocked. If saving stops partway through, the editor shows what was saved and retries only the remaining sessions.

Live UI models start empty. Sample records and photos require explicit preview mode; Release/TestFlight builds exclude the sample photo catalog and demo tools. CI inspects the archived app's asset catalog to enforce this.

Open `IntentionalTrainingNotes.xcodeproj`, select `IntentionalTrainingNotes`, and run on iOS 17 or later. The installed app renders the shared screens in `Prototypes/MatMind/`, backed by live services in `MatMind/`. Debug builds also offer **Preview without signing in** on Welcome, with isolated sample data.

**UI-only quick-log mock:** choose the **QuickTrainingLogMock** Xcode scheme to open Activity immediately with seeded data. Its state selector and Reset let you try quick logs, host/guest completion and an unstarted plan without sign-in or database calls. See [mock instructions](Prototypes/README.md#quick-training-log-ui-mock).

**Quick training logging is deployed.** Migration [`20261105212524_quick_training_log.sql`](supabase/migrations/20261105212524_quick_training_log.sql) was applied to the Mat Mind project. Live accounts enable the strip, chooser and private quick logs when their next snapshot includes the feature fields. Use the regular **IntentionalTrainingNotes** scheme and refresh/restart the app for real data; **QuickTrainingLogMock** continues to use isolated seeded data.

Google sign-in setup is described in [Google sign-in setup](docs/google-sign-in-setup.md). Apple sign-in is hidden for now. Backend migrations and functions are deployed; see [deployment and validation](docs/mat-mind-v2-deployment.md) for configuration and acceptance checks.

Previous local training data is available only through **Settings → Export → Export local sessions**, from Welcome or Profile. Legacy records are not imported into social sessions, photos or streaks. Goals are the one exception: **Goals → Import** reads that export file and brings over active goals with their task names, notes, links and photos (on the device only; sessions and reflections stay in the export).

After accepting a shared goal, you receive an in-app notification and a push when its owner changes the title, notes, links, photos or parts. Tapping either opens that shared goal. Unchanged saves stay quiet; pending, declined and blocked recipients receive no update alerts. Push follows your notification settings. The `goal_update_notifications` backend migration is deployed; the updated iOS client still needs to ship for goal notification display and navigation.

After commenting on a memory, you receive an in-app notification and a queued push for every new comment from someone else on that memory, including its author and people you do not follow. Each comment produces one alert per recipient; an @mention takes the place of the ordinary comment alert. Blocks and current post access still apply, and push follows your notification settings and iOS permission. The `comment_thread_notifications` backend migration is deployed and works with the existing app.

The Silverback app icon and logo come from `assets/brand/`. The production bundle identifier, existing sign-in callbacks, and stored-data identifiers retain their original values for compatibility. The `MatMindPrototype` scheme installs a separate **Mat Monkey Proto** app for reviewing the shared design.

The next production build is **1.1 (4)**. The Xcode project, schemes and source module identifiers keep their existing names; both installed app labels and wordmarks use **Mat Monkey**. Store/TestFlight listing names and Google's OAuth consent name are managed separately in App Store Connect and Google Auth Platform; set those display names to **Mat Monkey** while retaining the existing app and OAuth client IDs.

```sh
xcodebuild -scheme IntentionalTrainingNotes -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

## Design system

The design system for **Mat Monkey**, a friendship-first social app for the Jiu-Jitsu community: plan training with partners, share a photo after you roll, and keep **weekly friendship streaks**. Warm, playful, and soft, not a fitness dashboard.

> **Start with [`DESIGN.md`](DESIGN.md).** It is the full specification and the source of truth.

## What's inside
| Path | Contents |
|---|---|
| [`DESIGN.md`](DESIGN.md) | Complete spec: tokens, voice, visuals, components, screens, guardrails |
| [`.claude/skills/mat-monkeys-design/SKILL.md`](.claude/skills/mat-monkeys-design/SKILL.md) | Agent skill for Claude Code: core rules and guardrails |
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
- **Logo:** the Silverback, a geometric gorilla head with a coral brow band, next to the lowercase "mat monkey." wordmark
- **Signature:** the streak belt, athletic-tape labels, ticket-stub sessions, tied avatars

## Components
Button, IconButton, Icon, Logo · Input, Select, Checkbox, Radio, Switch · Belt, Avatar, AvatarStack, StreakBelt, Badge, Tag, Card · Tabs, TabBar · Dialog, Toast, Tooltip

## Use it
```html
<link rel="stylesheet" href="styles.css">
<button style="background:var(--accent);color:var(--text-on-accent);border-radius:var(--radius-pill)">Plan a training</button>
```
```js
// tailwind.config.js
module.exports = { presets: [require('./design-system/tailwind.config.js')], content: ['./src/**/*.{html,js,jsx,tsx}'] };
```

## Credits
Fonts from Google Fonts (OFL). Icons: Lucide v0.454.0 (ISC). Sample photos: Unsplash (Unsplash License). Logo: the Silverback mark (`assets/brand/`), paired with the "mat monkey." wordmark; see `DESIGN.md` §5.1.

## Regression tests

Changes to Activity logging, Profile training rhythm, attendance, RSVP or publishing must follow the [quick training log regression guide](docs/quick-training-log-regression.md). It includes native checks, protected invariants and the current UI acceptance checklist. The SQL suite is included in `scripts/test-database.sh`.
## Profile training heatmap

Stats → Progress shows the 17-week **Your rhythm** heatmap followed by technique hit charts when hits have been logged. The Weekly/Monthly session chart and period summary card are removed. Past hosted/joined sessions fill a day even without a shared photo. Older backends use the read-only heatmap; quick-log-enabled backends use the interactive rhythm card. See the [regression guide](docs/profile-heatmap-regression.md).

### Technique stats

The **Stats** tab retains the person icon. Below **Your rhythm**, each technique with saved Quick Log hits gets a daily line chart: this week in coral through today, last week dashed, plus both weekly totals. Unused presets stay hidden. Hits use the selected log date and remain private, account-scoped data on this device. Without saved technique hits, the existing monkey peeks behind an index card with a **Log hits** action that opens today’s Quick Log sheet. The first saved hit replaces it with the charts.

To preview: run **QuickTrainingLogMock**, then choose **Mock data → Technique stats**. This opens Stats with two weeks of sample technique hits. Choose Quick logs to test real counting in the preview, save a technique, and open Stats → Progress.
