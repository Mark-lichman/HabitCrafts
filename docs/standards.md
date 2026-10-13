# HabitCrafts Coding Standards

Eleven rules. Each is stated here **once**, carries a stable ID (`S1`..`S11`), and names the surface
that enforces it.

Companions: `docs/architecture/` says what the system is, `docs/testing/` says what must be proven,
and `.claude/skills/cto-review/` says how a change is inspected. This file says what good code here
looks like *before* it reaches review.

## Why this file is shaped the way it is

The hand-written surface of this project is roughly **1,800 lines of Dart** in `lib/custom_code/`
(19 actions, 7 widgets) plus **13 JavaScript files** under `firebase/`. That is about 3% of the
64,700 lines in `lib/`. Everything else is FlutterFlow output: a build artefact this repository
inherited on 2026-07-26 and now owns.

> Check before citing: `find lib/custom_code -name '*.dart' -exec wc -l {} + | tail -1` and
> `find lib -name '*.dart' -exec cat {} + | wc -l`

So these standards do two jobs, and only two:

1. Govern how the 3% is written.
2. Govern how you decide to take ownership of any of the other 97%.

That second job is why the usual advice inverts here. "Match the surrounding style" is good counsel
in a codebase written by people with taste. It is bad counsel in one where the surrounding style was
emitted by a tool that is no longer the source of truth.

**One maintainer.** No rule below may require a second person to enforce it.

---

## S1. Omakase lints, stricter at the seam

`package:flutter_lints` stays as shipped. `dart format` is the only style authority in the project,
so layout is not a matter of opinion here and there is no hand-tuned rule list to argue about.

The tailoring is one extra file, `lib/custom_code/analysis_options.yaml`, which governs hand-written
Dart only. The analyzer resolves the *nearest enclosing* options file per directory, so the root file
stays permissive for the inherited backlog while the seam runs strict. CI invokes
`flutter analyze --no-fatal-infos --no-fatal-warnings`, which means **`error` is the only severity
that stops a push. A `warn` fence blocks nothing.**

Two severity groups, and the split is the whole design:

- **Fatal.** A rule is promoted to `error` only once it is at **zero violations** at the seam. Such a
  fence cannot fire except on code written after it existed, so it costs nothing on day one and holds
  a clean line from that day forward. `empty_catches`, `cancel_subscriptions`, `close_sinks`,
  `use_build_context_synchronously`, and `avoid_empty_else` qualified on 2026-09-14.
- **Ratchet.** A rule with live violations stays at `warning` and carries its **count** in the file.
  Clear the count, then promote it. Promoting it while it is red is how a gate gets disabled the
  first time it is inconvenient. A ratchet with no number is a wish, so the numbers are recorded with
  the command that reproduces them.

Rules are added **at the seam, never to the root file**. Widening the fence to generated code is a
separate decision with a separate cost, tracked at the bottom of this document.

> Verify the fence is live, not decorative: add a `try {} catch (e) {}` to a file under
> `lib/custom_code/`, run `flutter analyze lib/custom_code/ --no-fatal-warnings`, and confirm it
> exits non-zero. It did on 2026-09-14.

## S2. Hand-written code sets the house style; generated code does not

New hand-written code must not replicate the patterns the builder emitted:

- business logic inside `build()`
- thousand-line widget methods
- `FFAppState` used as an argument-passing channel between screens instead of route parameters
- record getters coercing null to a type default (`int get height => _height ?? 0`)

**"The file next to it does this" is not a justification when the file next to it was generated.**

Generated code also has no intent. When a question turns on whether some behaviour was deliberate,
the code cannot answer it and must not be read as if it can. The arbiter is
`docs/testing/journeys.md`. If the journeys are silent, the answer is "undecided", and the change
should decide it and record the decision rather than infer intent from generated structure.

## S3. Adopt a file, or leave it alone

Touching generated code is a deliberate act of adoption, not an accident of editing.

- **Surgical fix**, or **full rewrite into house style**. Never a half-adopted file, because the next
  reader cannot tell which half still deserves the generated-code discount.
- Adoption is **one-way and permanent**. From the first human edit onward you own that file: you
  maintain code you did not write and cannot re-derive, and every future framework or Firebase
  upgrade that would have arrived as a clean regenerated file now arrives as a manual merge against
  conventions that are not yours.
- That cost is real, permanent, and compounding, **and sometimes worth paying.** Say which, and why,
  in the commit.
- Record every adoption in `docs/architecture/adopted-files.md`. This is the only bookkeeping in this
  document, and it earns its place because the author and the reviewer are the same person weeks
  apart: a commit message is invisible at the moment the bucket question actually gets asked.

**Corollary: a mechanical, tool-applied change does not adopt a file.** `dart format`, a
`dart fix --apply` pass, and a dependency-driven codemod all leave a file in the generated bucket.
Without this carve-out, running `dart fix` once would silently adopt the entire tree and there would
be no generated bucket left to discount.

## S4. No silent success

Every failure gets exactly one destination: **the user sees it**, **a real handler records it**, or
**it throws**. The fourth option, where the code continues as though nothing happened, is how this
project's three worst defects survived for months. Deletion, search indexing, and the onboarding drip
each ran doing nothing, behind a `catch` that logged and returned success.

Banned in hand-written code:

- `?? defaultValue` on a load-bearing value. If correct code cannot produce null there, the `??` is
  hiding the bug that did. Absence that is genuinely possible gets an explicit branch.
- `try { ... } catch { return defaultValue }`, and `.catchError((_) => [])`. The caller believes it
  received real data.
- Returning an empty collection on a failed read. **"You have no habits" and "we could not load your
  habits" must never be the same pixels.**
- A default parameter value standing in for an argument the caller was required to pass. If omitting
  it is a bug, make the parameter `required`.

Fallbacks are correct for genuinely optional display fields, for deliberate platform degradation
**where the user is told**, for loading states, and for non-critical enhancements that degrade
gracefully. The distinguishing question is always the same: **if this fallback fires, does anyone
find out?** If the answer is no and the value is load-bearing, it is a defect.

## S5. Put the thinking where a test can reach it

If logic cannot be called from `test/unit/` without a `WidgetTester`, it is in the wrong file.

- Pure computation goes to `lib/flutter_flow/custom_functions.dart`.
- Logic used by more than one screen goes to `lib/actions/actions.dart`.
- Platform APIs go to `lib/custom_code/actions/`.
- Widgets stay thin. They arrange; they do not decide.

This is the structural rule that makes the tier ladder in `docs/testing/README.md` reachable at all.
The cheapest tier can only ever cover what is callable from it, so every decision buried in a
`build()` method is a decision that only the slowest tier can reach.

## S6. Every widget owns what it creates

- **No stream creation inside `build()`.** A `..listen` cascade in `build()` attaches an
  uncancellable subscription on every rebuild. Streams belong in `initState` or the model, with the
  subscription cancelled in `dispose()`.
- Every `StreamSubscription`, `TextEditingController`, `ValueNotifier`, and `AnimationController` is
  disposed.
- Every async callback that writes after an `await` carries a `mounted` guard.

`StreamBuilder` and `FutureBuilder` manage their own subscriptions and are exempt. S1's fatal
`cancel_subscriptions`, `close_sinks`, and `use_build_context_synchronously` catch the mechanical
half of this at the seam; the rest is a review question.

## S7. Say it in the user's words

Names come from the domain the user lives in: habit, check-in, streak, group, reminder.
`group_member_states_with_previous_checkins_removed` is what a builder emits when it names a function
after its implementation. A person would not say that out loud, so do not write it down.

This governs new names only. Renaming an inherited identifier is an adoption under S3, with the cost
that implies.

## S8. A comment that asserts a fact carries the command that checks it

Any comment claiming a count, a state, or a known defect ships with the invocation that settles it.
`ci.yml` and the review skill's "Check before citing" predicates already work this way; it is now the
standard, and this document obeys it too.

```dart
// 19 actions as of 2026-09: `ls lib/custom_code/actions | grep -v index.dart | wc -l`
```

**Facts frozen in prose go false exactly when the project succeeds.** A comment citing a defect that
has since been fixed is worse than no comment, because it spends the credibility that the correct
comments beside it depend on. This project has already shipped one pair of documents disagreeing
about its own analyzer counts.

## S9. Delete it, git remembers

Unreachable code is deleted. Not commented out, not left behind a disabled flag, not kept "for
later."

Two standing examples, both inherited. `free_trial_screen_widget.dart` is 675 lines of marketing for
a subscription tier that exists in no other form: no payment dependency in `pubspec.yaml`, no
entitlement field on any record, no billing collection, and nothing that navigates to the screen.
`lib/flutter_flow/random_data_util.dart` is 3,066 lines of builder scaffolding.

Deleting inherited code is **not** an adoption under S3. Adoption is taking on maintenance; deletion
is the opposite of that.

## S10. A green check must have asserted something

- Every suite carries a positive control. If the emulator is not running, the suite fails loudly
  rather than skipping silently.
- **Tests describe intended behaviour, not current behaviour.** Several documented journeys are known
  broken. A red test for a known defect is the correct state. Weakening an assertion to turn a suite
  green is never the fix.
- Never point a test at the production Firebase project. The guard is a hardcoded refusal on
  `tiny-habits-jf61nl` in the test entry point, not a warning in a README.

The project currently violates this rule against itself: `test/` does not exist on disk, so CI's test
step emits a warning and exits 0 on every run. That is deliberate and it is honest, and it is the
first thing the test tiers should retire.

> Verify: `ls test/ integration_test/ firebase/test/ 2>&1`

## S11. A dependency is a promise you are making

A new package needs a written reason and an answer to one question: **what happens when this goes
unmaintained?**

This project is already paying that bill twice over. `dropdown_button2` is pinned to a FlutterFlow
fork at a raw commit SHA, so its upstream is a third party's branch rather than a published package.
And the app previously hotlinked images out of a third party's Firebase bucket that later went dark,
taking the check-in slider's artwork with it.

"Resolvable" is not "safe." `flutter pub outdated` reports the newest version, not the smallest one
that fixes your problem. Prefer the minimal bump, verify the whole line, and treat any bump to a
plugin with platform-specific implementations as unverified on iOS until TestFlight.

---

## Where a rule lives

**One rule, one home.** The failure this prevents is three documents saying the same thing in
different words, drifting apart, and none of them being trusted afterwards.

| Surface | Owns |
| --- | --- |
| `docs/standards.md` (this file) | The rule. The only place a standard is *stated*. |
| `.claude/skills/cto-review/` | Detection: how to find a violation in a diff and how to tier it. Cites `S1`..`S11`; never restates them. |
| `analysis_options.yaml` (root and seam), `.github/workflows/ci.yml` | Anything mechanically checkable. |

The governing rule: **if a standard can be a lint, it must be a lint and not prose.** Prose is what
you fall back on when no tool can decide the question.

## Deliberately left open

- **Clearing the analyzer backlog.** Running `dart fix --apply` across the tree would let warnings go
  fatal globally rather than only at the seam. Deferred, not rejected: the cost is a very large diff
  across generated files at a moment when there are no tests to catch a regression. Gate it behind
  the first working test tier. Per S3 it adopts nothing.
- **Clearing the seam ratchet.** 11 violations of the ratcheted rules exist in `lib/custom_code/`,
  listed with line numbers in `lib/custom_code/analysis_options.yaml`. Four of them are unawaited
  Futures, two inside deletion actions, which is the same failure shape as S4 in a path this project
  has already shipped broken once. Worth an issue, and worth tests before the fix.
- **Feature-first organisation.** `lib/chat_groupwbubbles/` is the one part of the tree organised by
  feature rather than by kind. If the codebase ever moves that way, it is the precedent. Until then,
  new code follows the placement map in `docs/architecture/02-module-map.md`.
