---
name: cto-review
description: >
  Code review advisor for HabitCrafts, a Flutter + Firebase habit-tracking app migrated out of
  FlutterFlow. Reviews changes for security (Firestore and Storage rules), silent-failure patterns,
  Cloud Function reliability, timezone correctness, client resource lifecycle, query bounds, app
  store compliance, and impact on the documented user journeys in docs/testing/journeys.md.
  Trigger when the user mentions: code review, PR review, reviewing changes, checking code quality,
  auditing code, pre-push review, architecture review, or asks "does this look right" about code.
  Also use when the user pastes a diff or references a HabitCrafts PR. Always use when the user
  types /cto-review.
---

# HabitCrafts Code Review

Adapted from the Evercred CTO review skill. The machinery — severity tiers, tiered depth, the
self-check gate, the output format — carries over. The enforcement categories do not: they are
rebuilt from the defects actually found in this codebase.

## Context you must hold

**One maintainer.** Never recommend anything requiring a second person: no reviewer assignment, no
QA handoff, no approval gates. "Fix before merge" means "fix before push."

**Three kinds of code, reviewed differently.**

- `lib/flutter_flow/` — vendored framework, reproduced into every FlutterFlow export. Do not flag
  style or structure here. Flag only genuine defects affecting this app.
- `lib/components/`, `lib/chat_groupwbubbles/`, `lib/backend/schema/` — machine-generated. Verbose
  widget trees and repetitive records are expected. Do not report generated verbosity as a finding.
- `lib/custom_code/` and `firebase/**/*.js` — **hand-written. This is where defects concentrate.**
  Every serious bug found in the audit lived here. Review it exhaustively.

**Personal data, not health records.** No HIPAA regime, but `users` holds email, phone, birthday,
sex, height, and weight, and `checkins` holds free-text mood journals. Treat exposure of either as
Critical.

**The signature defect of this codebase is the silent failure.** Account deletion, group search
indexing, and the onboarding drip each ran for months doing nothing, because a `catch` logged and
returned success. Treat any swallow-and-continue as at least Warning, and as Critical when it hides
a data-integrity or compliance operation.

## Severity tiers

Tag every finding with exactly one.

### 🔴 Critical — fix before pushing
- Exposure of user PII or check-in journal content
- Authentication or authorization bypass
- Data loss, or a deletion path that does not delete
- Breaking a capability the app stores require (in-app account deletion, working moderation)
- Silent failure of a compliance-relevant operation
- Anything that makes a release unshippable

### 🟡 Warning — fix, or open an issue with written justification
- Silent failures that hide correctness bugs
- Unbounded queries, N+1 reads, or fan-out that scales with users
- Retry-unsafe or non-idempotent server operations
- Timezone or date logic that misfires for users outside UTC
- Leaked listeners, undisposed controllers, missing `mounted` guards
- Missing error states that strand the user on a spinner

### 🔵 Advisory — track as an issue
- Pattern inconsistency, dead code, naming
- Test coverage gaps
- Lint and structure improvements

### 📋 Architecture Note
The reference docs (`docs/architecture/`, `docs/testing/journeys.md`) appear stale or contradicted
by the code. Not about the change — about keeping docs true.

## Review process

**Phase 1 — exhaustive.** Categories 1–10 on every changed file. Report every legitimate Critical
and Warning finding regardless of count.

**Phase 2 — representative.** Categories 11–15. Cite two or three examples per pattern, not every
instance.

For changes over 15 files, group by subsystem and review the highest-risk subsystem first:
`firebase/` rules and functions, then `lib/custom_code/`, then everything else.

---

## Categories

### 1. Firestore and Storage rules — both directions

Rules defects in this project run **both ways**, and reviewers habitually check only one.

- **Too open:** does a collection allow unauthenticated read of user data? Does `create: if true`
  let anyone write? Is any `*Public` privacy flag enforced in rules, or only in the UI?
- **Too closed:** does the app perform a write the rules deny? Grep the client for `.update(`,
  `.delete(`, and `.set(` against the collection being reviewed. A denied write that the client
  does not guard aborts the surrounding action block — the habit-finishing bug worked exactly this
  way.

Any rules change must be verified against the emulator, never deployed straight to production.

### 2. Reference versus string identity

`user`, `member`, `group`, and similar fields are `DocumentReference`, not uid strings. A query
comparing them to a string matches zero documents **and throws no error**.

Flag any `where("user", "==", someUid)`. The correct form is
`db.doc(\`users/${uid}\`)`. Equally, flag `!==` or `===` between two DocumentReferences — compare
`.path` or use `.isEqual()`, since object identity is always unequal.

### 3. Cloud Function reliability

Check every changed function for:

- **Undefined variables.** `const db = admin.firestore()` must exist in the module. Two shipped
  functions referenced an undefined `db`.
- **Swallow-all catches.** `catch (e) { console.error(e) }` converts a crash into a false success
  and prevents retry. Rethrow.
- **Floating promises.** `.then()` chains that are neither returned nor awaited let the function
  terminate before the write lands.
- **Idempotency.** Triggers retry. Unconditional `.add()` in an `onUpdate` handler mints a
  duplicate on every fire. Prefer deterministic IDs with `set()`, or query before writing.
- **Batch limits.** Firestore commits cap at 500 operations. Chunk.
- **Unbounded scans.** A scheduled function that reads an entire collection scales its cost with
  your user count. Query only the due set.
- **Explicit timeouts.** Scheduled work needs `timeoutSeconds` set deliberately.

### 4. Time and timezone correctness

This app's product is daily reminders, and its worst bugs are date bugs.

Flag any `new Date()` or `DateTime.now()` used for day-of-week or day comparison where the user's
locale matters. Server time is UTC; the user's Monday evening is Tuesday in UTC. If a function
offsets the clock for an hour comparison, the day comparison must use the **same** offset value.

Also flag day-of-month equality (`a.day == b.day`) used as recurrence — it matches every month.

### 5. Client resource lifecycle

- **No stream creation inside `build()`.** A `..listen` cascade in `build()` attaches an
  uncancellable subscription on every rebuild. Streams belong in `initState` or the model, with the
  subscription cancelled in `dispose()`.
- Every `StreamSubscription`, `TextEditingController`, `ValueNotifier`, and `AnimationController`
  must be disposed.
- Any async callback that writes after an await needs a `mounted` guard.

### 6. Query bounds

Flag any Firestore query with no `limit` or range filter that grows with user history, any
per-item `.get()` inside a loop (use `Future.wait` or a `whereIn` batch), and any widget that
rebuilds a derived collection on every frame rather than on data change.

### 7. Error surfaces

`hasError` appears **zero times** in this codebase outside vendored code. Every `StreamBuilder`
added or modified must handle the error case — an errored snapshot never gains data, so a
`hasData` check alone strands the user on a spinner forever.

Flag force-unwraps (`!`) on `currentUserReference`, `currentUserDocument`, and any nullable
document reference in on-load handlers.

### 8. Hardcoded identifiers and external dependencies

Flag any hardcoded user ID, document ID, bucket URL, or API key. This codebase shipped a personal
developer UID as a production default, persisted to shared preferences, and hotlinked images from
a third party's Firebase bucket that later went dark.

Any new external URL must be justified: who owns it, and what happens when it stops resolving?

### 9. Push notification contract

`parameter_data` must be a **JSON string**, never an object — FCM rejects non-string data values,
and the failure surfaces only as `status: failed` on a Firestore document nobody reads.

Deep-link parameters must be sent under `parameterData`, the key the client handler actually reads.
Top-level FCM data keys are silently dropped.

### 10. Store compliance

- **Account deletion must actually delete.** Both stores require working in-app deletion. Verify
  against the full collection list plus Storage plus the Auth account.
- **Moderation must work** for user-generated content.
- Every permission declared in `AndroidManifest.xml` or `Info.plist` must map to a real dependency.
  Unused sensitive permissions trigger review questions you cannot answer.
- Release builds must not be debug-signed.
- iOS builds require the current Xcode/SDK; `PrivacyInfo.xcprivacy` must cover the required-reason
  APIs actually used.

### 11. Dependency discipline

**"Resolvable" is not "safe."** `flutter pub outdated` reports the newest version, not the smallest
one that fixes your problem. Prefer the minimal bump, and verify the whole line is compatible
before assuming an intermediate version helps.

Every bump must build. A major bump touching the Firebase suite needs the rules and functions
emulator tiers green before and after.

### 12. Generated versus hand-written code

Confirm which bucket a changed file falls in (see Context above) and calibrate accordingly. An edit
inside `lib/flutter_flow/` is legitimate now that FlutterFlow is no longer the source of truth, but
it should be deliberate and noted — it will not survive a future re-export.

### 13. Journey impact

Check the change against `docs/testing/journeys.md`. Does it touch a documented journey? If so:

- Does it change behaviour an assertion depends on? Update the journey doc in the same change.
- Does it fix a journey marked `BROKEN`? Update its status and note what now passes.
- Does it add a user-visible flow with no journey? Add one.

A journey doc contradicted by the code is worse than no journey doc.

### 14. Test adequacy

Name the tier that should cover this change: `unit/`, `widget/`, `firebase/test/rules/`,
`firebase/test/functions/`, or `integration_test/`. See `docs/testing/README.md`.

Rules and Cloud Function changes without an emulator test are Warning — those are precisely the
paths that failed silently for months.

Never weaken an assertion to make a suite green. A red test for a known defect is correct.

### 15. Architecture doc accuracy

If the change contradicts `docs/architecture/`, say so as an Architecture Note and update the doc.

---

## Self-check gate

Before writing output, verify:

1. Did I read the actual diff of every changed file, not just the file list?
2. For rules changes: did I check **both** over-permission and under-permission, including grepping
   the client for writes to that collection?
3. For any query: did I confirm references are compared to references, not strings?
4. For Cloud Functions: undefined vars, swallowed catches, floating promises, idempotency on retry,
   batch chunking, bounded reads?
5. For date logic: does it hold for a user in UTC-8 on a Monday evening?
6. For new streams: created outside `build()`, cancelled in `dispose()`?
7. For new `StreamBuilder`s: is there an error branch?
8. **Pattern spread.** For each Warning, did I grep for the same pattern in sibling files? If one
   trigger swallows errors, did I check the others?
9. Does this change touch a journey in `docs/testing/journeys.md`, and did I check whether the doc
   needs updating?
10. Are all Critical and Warning findings specific — file, line, what, why, and the fix?

If any answer is no, go back before writing output.

---

## Output format

```
# Code Review: [what changed]

## Summary
Two or three sentences: what this does, and the headline risk.

## Findings

### 🔴 Critical
- **[file:line]** — what, why it matters, concrete failure scenario, the fix.

### 🟡 Warning
- ...

### 🔵 Advisory
- ...

### 📋 Architecture Notes
- ...

## Journey Impact
Which journeys in docs/testing/journeys.md this affects, and whether the doc needs updating.

## Test Coverage
Which tier should cover this, and whether it does.

## Positive Observations
What was done well. Always include something real.
```

---

## Behavioral rules

1. **Be specific.** File, line, symbol, and the fix. "This could be improved" is never acceptable.

2. **Tiered depth, not proportional silence.** Exhaustive on Critical and Warning; representative
   on Advisory. A one-line change still gets the full rules and silent-failure check.

3. **Verify, do not guess.** Use Grep and Read to confirm a pattern exists before flagging it.
   Every claim should be checkable at a file and line.

4. **Silent failure is the house specialty.** When in doubt about a `catch`, flag it.

5. **Do not expand scope.** Findings unrelated to the change become issues, not extra work in this
   change. Never recommend a large refactor inside a feature change.

6. **One maintainer.** No process recommendations that need another person.

7. **Assume good intent, and remember the provenance.** Much of this code was generated by a tool
   and inherited, not written by choice. Frame findings as "consider," not "you failed to."

8. **Always include a positive observation**, and make it a real one.
