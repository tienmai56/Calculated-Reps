# Prompt for Codex: build an end-to-end QA skill for Intentional Training Notes

> Paste everything below the line into Codex. Replace the `<PRD>` block with the full PRD text first.

---

## Role and goal

You are a senior iOS QA automation engineer working in this repository (`IntentionalTrainingNotes`, a SwiftUI iOS 13+ app with `AppDelegate`/`SceneDelegate`, local JSON persistence, and Keychain account storage).

Build a **reusable agent skill** named `e2e-qa` that, every time it is invoked, tests the app end to end against the PRD and produces a **detailed defect report**. For every issue, the report says what is wrong, how to reproduce it step by step, and what the root cause is in the code.

Your deliverable in this task is the skill and the test harness it drives. Then run the skill once and commit the first report. **Do not fix product bugs.** Only report them.

## Source of truth

1. **The PRD** (below) defines expected behavior. Every test and every issue must trace back to a PRD requirement. Give requirements IDs (`PRD-AUTH-1`, `PRD-PLAN-3`, …) if the PRD doesn't have them, and list that mapping in the report.
2. `DESIGN.md` and `.claude/design-system-spec.json` define the expected visuals (Mat Mind design system: colors, type, radii, spacing, voice). Visual or copy deviations from them are reportable issues.
3. The code is evidence of *actual* behavior, never of *expected* behavior. If the code and the PRD disagree, that is a finding, not a reason to change the test.

<PRD>
PASTE THE FULL PRD HERE
</PRD>

## What the app contains today (use this to plan coverage; verify it yourself)

- **Routing:** `App/RootView.swift` switches on `AppSessionStore.route` (`.signedOut` → `WelcomeView`, `.signedInMissingProfile` → `ProfileSetupView`, `.ready` → `MainAppView`). Session restore is in `Core/Stores/AppSessionStore.swift` (`restore`, `signIn`, `completeSignIn`, `saveProfile`, `signOut`, `completeOnboarding`).
- **Auth:** `Core/Services/AuthService.swift` (Google sign-in; Apple provider exists in the enum), `Core/Persistence/KeychainAccountStore.swift`, offline message handling through `Core/Services/NetworkStatusStore.swift`.
- **Onboarding:** `Features/Onboarding/Onboarding.swift`, with the steps splash → goal → session → reflect → bounty.
- **Main tabs:** `App/MainAppView.swift` (`MainTab`: home, plan, goals), plus sheets for planning, reflect, and add goal.
- **Domain logic:** `Core/Stores/NotebookStore.swift` covers goals (add, update, archive, cascade delete), tasks (images, notes, links), planned sessions (single and batch proposals, duplicate conflict detection, override, edit, split by goal, delete), reflections (mood, worked/stuck/try-next, images, favorite, delete, `canReflect` gating), notes, bounties (eligibility, create, record hit, cancel, stats), competitions (strategy focus CRUD, log result, competition reflection), and weekly counts (`trainingDatesThisWeek`, `taskWeekDoneDayCount`, Monday-start weeks).
- **Feature UI:** `Features/Home`, `Features/Plan` (PlanTrainingView, PlanListView, EditSessionView), `Features/Goals`, `Features/Reflect`, `Features/Stats` (MonthStats, ReflectionQuotesSheet), `Features/Bounty`, `Features/Notes`, `Features/Settings`.
- **Services:** `ReminderScheduler` (local notifications), `SpeechRecognizer` (dictation; needs mic and speech permissions).
- **Persistence:** `Core/Persistence/NotebookPersistence.swift` (JSON per account under Application Support) and `NotebookMigration.swift` (schema migration).
- **Existing DEBUG hooks** (environment variables, compiled only in DEBUG): `RESET_ONBOARDING`, `SEED_DEMO_DATA`, `START_TAB=home|plan|goals`, `ONBOARDING_STEP=goal|session|reflect|bounty`, `MATMIND_FORCE_BOUNTY=1`.
- **Existing tests:** one unit-test target, `IntentionalTrainingNotesTests` (about 13 tests). There is **no UI-test target**, and the app has **zero `accessibilityIdentifier`s**.

## Part 1: Test harness (required before any testing)

1. **Add an XCUITest target** `IntentionalTrainingNotesUITests` to `IntentionalTrainingNotes.xcodeproj` and wire it into the `IntentionalTrainingNotes` scheme. Keep the existing unit-test target working.
2. **Bypass real Google OAuth in tests.** Add a DEBUG-only launch environment flag (for example `UITEST_STUB_AUTH=1`, with optional `UITEST_ACCOUNT_ID`) that injects an in-memory `AccountStore` and a stub `AuthServicing` returning a fixed `UserAccount`. A preview already does this with `MemoryAccountStore` and `PreviewAuthService` in `RootView.swift`, so reuse that pattern. Also add `UITEST_AUTH_RESULT=success|cancel|error` so the failure paths can be tested.
3. **Isolate data per test run.** Add a DEBUG-only flag (for example `UITEST_DATA_DIR`) that points `JSONNotebookPersistence` at a temp directory, so every test starts from a known state and relaunch-persistence tests are deterministic.
4. **Add `accessibilityIdentifier`s** to every interactive element and key label the tests need. Use a dotted naming scheme such as `home.planTraining`, `plan.save`, `reflect.mood.good`, and `goals.row.<index>`. This must cause **no visual or behavioral change**.
5. **Make dates controllable.** Week and month logic depends on "now". Either add a DEBUG-only `UITEST_NOW=<ISO8601>` clock override that the stores and views read through one injectable clock, or cover date-boundary behavior in unit tests against `NotebookStore` with explicit dates. Pick one, and say which you picked and why.
6. Every hook must sit behind `#if DEBUG` and must not change release behavior. List each production file you touched, and why, in the report's appendix.

## Part 2: The skill

Create the skill at the repo-scoped location your skill loader reads (default: `.codex/skills/e2e-qa/`):

```
.codex/skills/e2e-qa/
  SKILL.md                 # trigger description, procedure, guardrails, report template
  scripts/run_e2e.sh       # build + run UI and unit tests, collect artifacts
  scripts/summarize_xcresult.sh  # extract failures, screenshots, logs from .xcresult
  references/test-plan.md  # PRD requirement → test case matrix
  references/report-template.md
```

`SKILL.md` must tell the agent to do the following, in order:

1. **Prepare.** Read the PRD, `DESIGN.md`, and `references/test-plan.md`. Boot a simulator (default `iPhone 15`, plus one small device such as `iPhone SE (3rd generation)` for layout checks). Run `xcodebuild -scheme IntentionalTrainingNotes -destination '<dest>' build`. A build failure is itself a P0 issue, so report it and stop.
2. **Run the automated suite.** `xcodebuild test` with `-resultBundlePath qa-reports/<date>/results.xcresult`. Capture screenshots on failure, and at every key screen with `XCTAttachment`, `lifetime = .keepAlways`.
3. **Explore beyond the scripted tests.** Use the seeded state (`SEED_DEMO_DATA`) and an empty state, and probe the edge cases listed below. Log any new defect, even when no test failed.
4. **Reproduce every candidate issue at least twice** from a clean launch. Classify each one as `Reproducible`, `Intermittent (n/m)`, or `Could not reproduce`. Never report a flaky test as a product bug without checking it.
5. **Find the root cause** for every reproducible issue (see the rules below).
6. **Write the report** (format below) to `qa-reports/<YYYY-MM-DD>/report.md`, with screenshots in the same folder.

### Coverage the test plan must include (at minimum, plus everything else in the PRD)

- **Auth and session:** first launch shows the Welcome screen. Sign-in success, cancel, and error each show the right message. Offline sign-in shows the offline message. A new account goes to profile setup. Profile save leads to onboarding or the main app. Relaunch restores the session. Sign-out clears the route and data access. Two accounts never see each other's data.
- **Onboarding:** every step, back and skip behavior, "use defaults" versus custom input, empty or whitespace input, and the "already has a notebook" upgrade path. Onboarding must never appear for existing users or create stray data.
- **Goals and tasks:** create, edit (name, icon, color), archive, cascade delete (the confirmation summary must match what actually gets deleted), add and rename tasks, task notes, links, and images. Long names, emoji, and duplicates.
- **Planning:** plan a single session, plan batch multi-day sessions, the duplicate-conflict prompt and override, pre-selection of goal and task when planning from a task timeline, editing date and tasks, splitting a session by goal, and deleting. Check that Home, Plan list, and Goal detail all reflect each change at once.
- **Reflect:** only eligible sessions can be reflected (`canReflect`), and the "can't reflect" alert appears otherwise. Mood and the three text fields, dictation (permission granted and denied), images, favorite, delete, and editing an existing reflection.
- **Stats:** month stats math against seeded data (compute the expected numbers by hand from the seed), the reflection-quotes sheet, and an empty month.
- **Bounty:** eligibility threshold, create each `BountyKind`, record a hit, cancel, and stats and title text.
- **Competitions:** add, edit, delete, strategy focus CRUD, log a result (wins, losses, placement, focus worked), and the competition reflection.
- **Notes and Settings:** note CRUD with images, reminder scheduling (permission granted and denied; check the pending notifications), and sign-out.
- **Persistence and migration:** kill and relaunch after every mutation type, and confirm the data survives. Load an older-schema `notebook.json` fixture through `NotebookMigration`, with no data loss. A corrupt or empty JSON file must not crash or silently wipe data.
- **Dates:** Monday-start week boundaries, Sunday at 23:59, month rollover, DST change, a non-US locale and time zone, and 12h versus 24h time.
- **UI and design system:** the iPhone SE size, the largest Dynamic Type size (truncation and overlap), VoiceOver labels on interactive elements, keyboard covering inputs, light-mode lock, and Mat Mind token conformance (spot-check colors, fonts, and radii against the spec).
- **Robustness:** rapid double taps on save buttons (duplicate records?), dismissing sheets mid-edit (data loss or orphaned drafts, such as `createDraftGoal`), and backgrounding the app during a flow.

### Root-cause rules

- Trace each issue to specific code. Cite `path/to/File.swift:line`, quote the relevant lines, and explain the mechanism (for example, "`updateSessionSplittingByGoal` creates the new session before removing task IDs from the original, so the original keeps both").
- Back the cause with evidence: a failing unit test that isolates it, a debugger or log observation, or a minimal code-path walkthrough. State a **confidence level** (`Confirmed`, `Likely`, `Hypothesis`) and what would confirm it.
- If several symptoms share one cause, group them under one root cause and cross-link them.
- Suggest a fix direction in one to three sentences, but **do not apply it**.
- For each issue, write a regression test that fails today: a UI test or a unit test. Name it after the issue ID, and mark it `XCTExpectFailure` (or skip it with a reason) so the suite stays green while the bug is open.

## Report format (`qa-reports/<date>/report.md`)

1. **Summary:** build SHA, date, devices and iOS versions, counts by severity, pass/fail/blocked counts, and the top three risks in one line each.
2. **Coverage matrix:** a table of PRD requirement ID → test case(s) → result (Pass / Fail / Blocked / Not covered) → issue IDs.
3. **Issues**, sorted by severity, each in exactly this shape:

```
### E2E-012 — <one-line symptom>
- Severity: P0 crash/data loss | P1 core flow broken | P2 incorrect behavior, workaround exists | P3 cosmetic/copy/design-system
- PRD requirement: PRD-PLAN-3 — "<quoted requirement>"
- Area / screen: Plan › Edit session
- Reproducibility: Reproducible (3/3) | Intermittent (2/5)
- Environment: iPhone 15, iOS <x>, build <sha>, launch env: SEED_DEMO_DATA=1
- Preconditions: <state needed>
- Steps to reproduce:
  1. …
  2. …
- Expected (per PRD/DESIGN.md): …
- Actual: …
- Evidence: screenshots/E2E-012-1.png, xcresult test name, console log excerpt
- Root cause (Confidence: Confirmed): `Features/Plan/EditSessionView.swift:142` — <quoted code> — <explanation>
- Related issues: E2E-007 (same root cause)
- Suggested fix direction: …
- Regression test: `IntentionalTrainingNotesUITests/PlanTests.swift::test_E2E012_splitKeepsTasks` (currently expected-fail)
```

4. **Blocked and not tested:** what could not be tested, and why (for example, real Google OAuth or real push delivery).
5. **Appendix:** the harness changes made to production files, how to rerun (`.codex/skills/e2e-qa/scripts/run_e2e.sh`), and a list of artifacts.

## Guardrails

- Report only. Do not change product behavior to make tests pass. Do not delete, skip, or weaken tests to get green.
- Test hooks must be DEBUG-only and must not change visuals. Follow the Mat Mind design system rules (`.claude/skills/mat-mind-design/SKILL.md`) if you touch any UI file.
- No real credentials, no network-dependent tests, and no writes outside the simulator and `qa-reports/`.
- Never invent results. If a step could not run, mark it Blocked with the error output.
- Keep each issue to a single defect. Split compound issues.

## Done when

- `IntentionalTrainingNotesUITests` builds and runs from the CLI, and the existing unit tests still pass.
- The `.codex/skills/e2e-qa/` skill exists with the files listed above, and `run_e2e.sh` works from a clean checkout.
- `references/test-plan.md` maps every PRD requirement to at least one test, or explains why it can't be tested.
- The first `qa-reports/<date>/report.md` exists, with a reproduction and root-cause analysis for every issue found.
- Everything is committed on a branch, with a short summary of findings in the final message.
