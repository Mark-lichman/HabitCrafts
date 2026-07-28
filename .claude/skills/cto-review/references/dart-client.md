# Reference — Dart client categories

Bodies for `client-lifecycle`, `error-surface`, `generated-vs-written`, `hardcoded-ids`, `a11y`.

Every embedded fact carries a **Check before citing** predicate. Run it. If it no longer holds,
the claim has expired — do not cite it, and apply the retirement instruction.

---

## `client-lifecycle`

- **No stream creation inside `build()`.** A `..listen` cascade in `build()` attaches an
  uncancellable subscription on every rebuild. Streams belong in `initState` or the model, with the
  subscription cancelled in `dispose()`.
- Every `StreamSubscription`, `TextEditingController`, `ValueNotifier`, and `AnimationController`
  must be disposed.
- Any async callback that writes after an `await` needs a `mounted` guard.

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

Confirm which of the three buckets a changed file falls in, and calibrate. Three rules govern the
boundary.

### (a) Editing generated code costs fork ownership, not re-export loss

The project has left FlutterFlow. `docs/architecture/README.md` states the repository is now the
source of truth, so "this will be overwritten on re-export" is false and invites dismissal. State
the real cost: **from the first edit onward you own that file.** You maintain code you did not write
and cannot re-derive, and every future framework or Firebase upgrade that would have arrived as a
clean regenerated file now arrives as a manual merge you perform by hand against conventions that
are not yours. That cost is real, permanent, and compounding — and sometimes worth paying. Say
which, and why, in the review.

> **Check before citing:** `rg -n "source of truth" docs/architecture/README.md`
> If the project ever returns to FlutterFlow as the builder, this entire rule inverts and the
> re-export framing becomes correct again.

### (b) Bucket migration is one-way and permanent

The moment a human edits a generated file, it is hand-written **forever after** — not just for this
change. It leaves the "do not flag verbosity" bucket and joins the "review exhaustively" bucket.
Note the migration explicitly in the review when it happens, because the next reviewer will
otherwise apply the generated-code discount to code nobody is discounting any more.

### (c) Generated code has no intent

Bucket-one and bucket-two code expresses what a builder emitted, not what anyone decided. When a
review question turns on whether some behaviour was deliberate, **the code cannot answer it and must
not be treated as if it can.** The arbiter is `docs/testing/journeys.md`. If the journeys are
silent, the answer is "undecided" — the change should decide it and record the decision, not infer
intent from generated structure.

### Corollary — do not imitate generated anti-patterns

State this plainly, because it inverts normal review doctrine. Ordinarily "match the surrounding
style" is good advice. Here it is not, because the surrounding style was emitted by a tool. New
hand-written code must not replicate:

- business logic inside `build()`
- thousand-line widget methods
- `FFAppState` used as an argument-passing channel between screens instead of route parameters

"The file next to it does this" is not a justification when the file next to it was generated.
Hand-written code sets the house style; generated code does not.

---

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
