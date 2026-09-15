# Reference — Dart client categories

Bodies for `client-lifecycle`, `error-surface`, `generated-vs-written`, `hardcoded-ids`, `a11y`.

Every embedded fact carries a **Check before citing** predicate. Run it. If it no longer holds,
the claim has expired — do not cite it, and apply the retirement instruction.

---

## `client-lifecycle`

**The rule is `docs/standards.md` S6.** Cite it; do not restate it. What belongs here is how to find
a violation in a diff.

The mechanical half is already fatal at the seam: S1 promotes `cancel_subscriptions`, `close_sinks`
and `use_build_context_synchronously` to `error` in `lib/custom_code/analysis_options.yaml`, so a new
instance in hand-written Dart fails CI before it reaches review. **That fence does not reach
generated code.** Outside `lib/custom_code/`, this category is the only thing checking S6, and the
live case below is exactly there.

The live case is #15, which puts J7 assertions 4 and 5 at risk.

> **Check before citing (#15):**
> `rg -n "listen" lib/chat_groupwbubbles/chat_thread_component/chat_thread_component_widget.dart`
> Confirm the listener is still created inside `build()` before describing it in the present tense.
> If the file has moved, `rg -rln "\.\.listen|\.listen\(" lib/ --glob '!lib/flutter_flow/'` finds
> the current instances.

### Do not flag

- Controllers owned and disposed by a generated `*_model.dart` the change does not touch.
- `StreamBuilder` and `FutureBuilder`, which manage their own subscriptions.
- Streams created in `initState` whose `dispose()` already cancels them.

---

## `error-surface` — error surfaces and silent fallbacks

**The rule is `docs/standards.md` S4**: every failure gets exactly one destination, and continuing as
though nothing happened is not one of them. The catalogue below is detection, not the rule.

Two families. The first swallows a failure. The second **fabricates a success**, which is worse,
because nothing anywhere reports a problem.

### Family one — swallow and continue

Every `StreamBuilder` added or modified must handle the error case. An errored snapshot never gains
data, so a `hasData` check alone strands the user on a spinner forever.

> **Check before citing:** `rg -n "hasError" lib/ --glob '!lib/flutter_flow/'`
> At last measurement this returned nothing — no hand-written or generated application widget
> handled an errored snapshot anywhere. If it now returns hits, stop asserting "zero" and check the
> specific builder in front of you.

Also flag:

- Force-unwraps (`!`) on `currentUserReference`, `currentUserDocument`, or any nullable document
  reference in on-load handlers.
- `catch` blocks that log and continue.

### Family two — fallbacks that fabricate success

These look defensive and read as careful code. They are not. In a habit tracker, silently rendering
"no habits" when the query failed teaches the user their data is gone.

- **`?? defaultValue` on a value that should never be null.** If correct code cannot produce null
  here, the `??` hides the bug that did. This is endemic in generated record getters
  (`int get height => _height ?? 0`) — that is bucket-two code, do not flag it there — but new
  hand-written code must not copy it. Absence that is genuinely possible gets an explicit branch.
- **`|| defaultValue`** — same, plus it catches empty string and zero, which are frequently the
  *correct* value.
- **`try { ... } catch { return defaultValue }`** — the caller believes it received real data.
- **`.catchError((_) => [])` / `.catchError((_) => null)`** — the same lie, in a chain.
- **Empty collection on error.** Returning `[]` when the read failed makes the UI render the empty
  state. "You have no habits" and "we could not load your habits" must never be the same pixels.
- **Default parameter values masking a missing argument.** If a caller failing to pass a value is a
  bug, make the parameter required.

### When fallbacks ARE appropriate — do not flag these

- Display fallbacks for genuinely optional profile fields — an em dash for an unset `bio`, `phone`,
  or `birthday`.
- Deliberate platform degradation: a `kIsWeb` branch that hides a contacts feature web cannot
  support, **where the user is told**, not silently handed an empty list.
- Loading and skeleton states before data arrives.
- Configuration and environment parsing with a documented sensible default.
- Generated record-class getters coercing null to a type default — bucket two, not a finding.
- Non-critical enhancements degrading gracefully: an animation that does not run, an avatar that
  falls back to initials.

The distinguishing question is always the same: **if this fallback fires, does anyone find out?**
If the answer is no and the value is load-bearing, it is a finding.

---

## `generated-vs-written`

**The rules are `docs/standards.md` S2 and S3.** S2 says hand-written code sets the house style and
generated code does not. S3 says an edit to generated code is an adoption: surgical fix or full
rewrite, never half, one-way and permanent, recorded in `docs/architecture/adopted-files.md`, and not
triggered by a mechanical tool pass. Cite them by ID; do not restate them in the review.

What this category does is decide **which bucket the changed file is in**, which is a question the
rules cannot answer for you.

1. **Read the register first.** `docs/architecture/adopted-files.md` lists every generated file a
   human has already edited. A file listed there is hand-written for review purposes, whatever its
   path suggests, and gets no verbosity discount.

   > **Check before citing:** the register's own predicate finds generated files carrying human
   > commits that are missing a row. A missing row is itself a finding, against S3.

2. **If the change edits generated code and the file is not in the register, that is the finding** —
   not the edit itself, which may well be correct, but the unrecorded adoption. The fix is a register
   row naming the cost, in this change.

3. **State the cost in the review when an adoption happens**, because the next reviewer will
   otherwise apply the generated-code discount to code nobody is discounting any more. Do not use the
   re-export framing: the project has left FlutterFlow, so "this will be overwritten on re-export" is
   false and invites dismissal. The real cost is permanent manual maintenance of code you did not
   write.

   > **Check before citing:** `rg -n "source of truth" docs/architecture/README.md`
   > If the project ever returns to FlutterFlow as the builder, S3 inverts and the re-export framing
   > becomes correct again.

4. **Generated code has no intent.** When a review question turns on whether some behaviour was
   deliberate, the code cannot answer it and must not be treated as if it can. The arbiter is
   `docs/testing/journeys.md`. If the journeys are silent, the answer is "undecided": the change
   should decide it and record the decision.

5. **Do not let "match the surrounding style" smuggle S2 violations in.** Ordinarily that is good
   advice. Here the surrounding style is a build artefact, so it is not. A new `build()` full of
   business logic is a finding even when every file around it looks the same.

## `hardcoded-ids`

Flag any hardcoded user ID, document ID, bucket URL, or API key.

This codebase shipped a personal developer UID as a production default, persisted to shared
preferences, and routes every content report to it (#17, J8) — while both stores require working
moderation. It also hotlinked images from a third party's Firebase bucket that later went dark.

> **Check before citing (#17):** `rg -n "marksUserId" lib/app_state.dart`
> Confirms the hardcoded default is still present and gives its current line. Also
> `rg -rn "instance\.doc\('/" lib/` finds any other hardcoded document path.

Any new external URL must be justified: who owns it, and what happens when it stops resolving?

---

## `a11y` — accessibility

Advisory ceiling. Lightweight, but web makes it visible in a way mobile did not.

- **Semantics labels.** Icon-only buttons — the check-in control, reaction buttons, navigation icons
  — need a `Semantics` label or a tooltip. A bare `IconButton` with no label announces nothing.
- **Contrast.** New colour pairs should clear WCAG AA — 4.5:1 for body text. Flag light-grey-on-white
  secondary text.
- **Focus order on web.** Keyboard tab order must follow visual order, dialogs must trap focus and
  restore it on close, and every interactive control must be reachable without a mouse. Flutter web
  can produce a focus order with no relationship to the layout; new forms and dialogs are where it
  goes wrong.
- **Text scale.** Fixed-height containers around text clip at large system font sizes.

### Do not flag

- Generated widget trees not touched by this change.
- Decorative imagery, which correctly has no semantic label.
- Contrast on brand colours already in use elsewhere — that is a design decision, not a code review
  finding. Raise it once as an issue, not on every screen.
