# Reference — Release, testing, and documentation categories

Bodies for `store-compliance`, `dep-discipline`, `journey-impact`, `test-adequacy`, `doc-accuracy`.

Every embedded fact carries a **Check before citing** predicate. Run it. If it no longer holds,
the claim has expired — do not cite it, and apply the retirement instruction.

---

## `store-compliance`

The Critical parts of store compliance are enforced elsewhere and are always on:

- Account deletion that actually deletes → `data-lifecycle`
- Sign in with Apple alongside Google → `plat-matrix`
- Working moderation for user-generated content → `hardcoded-ids` (#17 routes every report to a
  hardcoded personal UID) and `journey-impact` (J8)

What remains here is the packaging surface, which is cheap to check but only when something in it
changes:

- **Declared permissions must map to a real dependency.** An unused sensitive permission triggers a
  store review question you cannot answer. `SCHEDULE_EXACT_ALARM` in particular requires a declared
  justification on Google Play.

  > **Check before citing:** `rg -n "uses-permission" android/app/src/main/AndroidManifest.xml`
  > Cite from this output. The declared set changes; a frozen list in prose does not.

- **Release builds must not be debug-signed.**
- **iOS builds require the current Xcode/SDK**, and `ios/Runner/PrivacyInfo.xcprivacy` must cover the
  required-reason APIs actually used.

  > **Check before citing:** `ls ios/Runner/PrivacyInfo.xcprivacy`
  > None of this is verifiable from Windows. Whatever you conclude here belongs in the
  > "Cannot determine by reading" section, not in Findings.

---

## `dep-discipline`

**"Resolvable" is not "safe."** `flutter pub outdated` reports the newest version, not the smallest
one that fixes your problem. Prefer the minimal bump, and verify the whole line is compatible before
assuming an intermediate version helps.

- Every bump must build.
- A major bump touching the Firebase suite needs the rules and functions emulator tiers green before
  and after.
- A bump to a plugin with platform-specific implementations also gets a `plat-matrix` statement: the
  iOS half of the bump cannot be built here, so it goes in "Cannot determine by reading."

> **Check before citing:** `git diff <base>...HEAD -- pubspec.yaml pubspec.lock firebase/*/package.json`
> Review the actual version deltas, not the summary in a commit message.

---

## `journey-impact`

Check the change against `docs/testing/journeys.md` (J1–J12).

- Does it change behaviour an assertion depends on? Update the journey doc in the same change.
- Does it fix a journey marked `BROKEN`? Update its status and note what now passes.
- Does it move a journey from `UNVERIFIED` to `WORKS`? Only a run against a real build can do that,
  and on iOS nothing here can. Say so rather than upgrading the status.
- Does it add a user-visible flow with no journey? Add one.

A journey doc contradicted by the code is worse than no journey doc.

> **Check before citing:** `rg -n "^## J|Status:" docs/testing/journeys.md`
> Gives the current journey set and their statuses. At last measurement there were twelve journeys,
> six known broken (J4, J5, J8, J10, J11, J12) and six unverified, with nothing yet `WORKS`.
> Do not describe a journey's status from memory — read it.

---

## `test-adequacy`

Name the tier that should cover this change: `test/unit/`, `test/widget/`, `firebase/test/rules/`,
`firebase/test/functions/`, or `integration_test/`. See `docs/testing/README.md`.

- Rules and Cloud Function changes without an emulator test are **Warning** — those are precisely
  the paths that failed silently for months.
- Never weaken an assertion to make a suite green. A red test for a known defect is correct.
- `integration_test/` runs on the Android emulator. It is **not** iOS coverage and must never be
  described as such.

> **Check before citing:** `ls test/ firebase/test/ integration_test/ 2>/dev/null`
> The tiers described in `docs/testing/README.md` are a plan; confirm which directories exist before
> asserting that a test "was not added" to a tier that has never existed. If a tier is absent
> entirely, that is an Architecture Note about the testing doc, not a Warning about this change.

### Do not flag

- Documentation-only or comment-only changes.
- Changes confined to generated widget trees with no behavioural delta.
- Formatting, import ordering, and lint-fix commits.

---

## `doc-accuracy`

If the change contradicts `docs/architecture/` — the system context, the module map, the navigation
diagram, the entity counts — say so as an **Architecture Note** and update the doc.

The architecture docs record a frozen snapshot and say so: entity counts come from
`.flutterflow/export_manifest.json` and drift as the code changes. A count that has drifted is not
automatically a finding. A *structural* claim that is now false — the route count, the module
stratification, which directory holds hand-written code — is.

> **Check before citing:** `rg -n "routes|Dart files|collections|Cloud Functions" docs/architecture/README.md`
> Compare against the current repository before calling a number stale, and prefer flagging
> structural contradictions over numeric drift.
