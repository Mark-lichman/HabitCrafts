# HabitCrafts Test Strategy

Adapted from the methodology used by `HPECid/evercred-e2e`, retargeted from
Playwright/Postgres to Flutter/Firebase, and scaled down for a single maintainer.

## What carries over

Five ideas from the Evercred suite are worth keeping regardless of stack:

1. **A tiered taxonomy, with tiers that cannot be confused for one another.** Evercred separates
   deployed-safe tests (`tests/`) from local-only integration (`integration/`) at the directory
   root, not by naming convention, so it is visually obvious which tier a spec belongs to.
2. **Page objects with fixtures.** Selectors live in one place per screen. Specs read as user
   intent, not as widget lookups.
3. **Positive controls.** Evercred's `assertAppReachable` is a "false-green floor" — a blocked or
   skipped spec must still prove the app was reachable, so a silently-skipped suite cannot pass.
4. **Hard environment guards.** `db-setup.ts` refuses any non-localhost `DATABASE_URL`. The guard
   is in the code, not in a README warning.
5. **Auth once, reuse the session.** A setup project authenticates and saves state; specs reuse it
   instead of logging in repeatedly.

## What does not carry over

- **Playwright cannot drive this app.** Flutter web renders to canvas, so there is no DOM to
  select against. The equivalent is Flutter's own `integration_test` package driving a real build.
- **Mailinator magic links** are replaced by the Firebase Auth emulator, which mints test users
  directly — no mail round-trip.
- **Postgres seeding** is replaced by Firestore emulator seeding.
- **A separate QA repo.** Evercred splits black-box E2E into its own repo because QA owns it.
  There is one maintainer here, so tests live beside the code.

## Tiers

```
test/
├── unit/           # Pure Dart. No Firebase, no widgets. Milliseconds.
├── widget/         # Leaf components under MaterialApp. No Firebase.
└── journey/        # Reserved — see integration_test/

integration_test/   # Real app build against the Firebase emulator suite

firebase/test/
├── rules/          # Firestore + Storage rules assertions (Node, emulator)
└── functions/      # Cloud Function behaviour (Node, emulator)
```

**`unit/`** — the 25 functions in `lib/flutter_flow/custom_functions.dart` plus schema
serialisation round-trips. Cheapest tier, and it covers the date/timezone helpers implicated in
the reminder defects.

**`firebase/test/rules/`** — the highest-value tier for this codebase. Security rules are the only
thing between an anonymous caller and the database (see `docs/architecture/01-system-context.md`),
and issues #1, #14, and the Storage rules in #23 are all rules defects. These tests are written in
Node against `@firebase/rules-unit-testing`, not in Dart.

**`firebase/test/functions/`** — issues #7 and #9 through #13 are all Cloud Function defects, three
of which have never executed successfully. Emulator tests are the only way to assert them without
touching production.

**`integration_test/`** — full journeys on the Android emulator against emulated Firebase.
Slowest tier; reserve it for the journeys in `journeys.md` that cross screens.

## Non-negotiable rules

**Never point tests at the production Firebase project.** Every test entry point must assert it is
talking to an emulator host and refuse otherwise — a guard in code, not a note in a README. The
production project ID is `tiny-habits-jf61nl`; a hardcoded refusal on that value is appropriate.

**Every suite carries a positive control.** If the emulator is not running, tests must fail loudly
rather than skip silently. A green run must mean the assertions executed.

**Tests describe intended behaviour, not current behaviour.** Several journeys documented in
`journeys.md` are known broken. Their tests are expected to fail until the corresponding issue is
fixed. A red test for a known defect is the correct state — do not weaken an assertion to make a
suite green.

## CI gating

`flutter analyze` currently reports 4,101 issues — all `info`, zero errors and zero warnings. Gating
on total issue count would fail immediately, so CI should gate on **errors and warnings only** at
first, with the lint backlog addressed separately. This is tracked in issue #19.

Suggested gate order as tiers come online: `analyze` (errors/warnings) → `unit` → `rules` →
`functions` → `widget` → `integration_test`.

## Current state

Nothing is implemented yet. `test/widget_test.dart` is the FlutterFlow scaffold and cannot pass —
it pumps `MyApp()` directly, but Firebase initialisation happens in `main()` outside it, so it
throws `[core/no-app]` before the first frame. Replacing it is part of issue #23.
