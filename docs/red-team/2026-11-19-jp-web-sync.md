# Red Team — HabitCrafts on the web, with one account and a synced Japanese record (2026-11-19)
**Verdict:** ADJUDICATED — every blocker and decision was patched into the plan; no probe re-ran a patch.
**Rounds:** 1

## Attack surface
Spine: claims-vs-reality, executable-proof, coverage-vs-source, consistency-placeholders, dependency-feasibility, intent-vs-plan. Bespoke: command-diff, dep-resolves (executed); footprint-completeness, delete-paths, web-runtime-gaps (analyzed). Executed in sandbox: executable-proof, command-diff, dep-resolves (clones of `b77ada4` plus the plan commit `7fb0c9b`).
Fallback: none. Artifact kind: impl-plan.
Drift-guard probes (Lead-run): unguarded-new-mirror vacuous, default-flip-old-absent vacuous, guard-split-deps-edge pass, touched-doc-fact-coverage one finding (Task 12 runbook restated deploy facts; patched to point at `firebase/firebase.json` and `deploy-web.yml`).
Backstop legitimacy: all five rows name a reason, a runner and a timing. No `judge:` tags.
Escape guard: exit 0 after both runs.
The first run returned INCOMPLETE: two probes reported the plan path as `C:/…` instead of `/c/…`. Both re-ran with the path form pinned, and coverage was then 11 of 11.

## Executed proof
- `flutter build web --release` at base → succeeds already, and prints `Built build\web` on Windows. The old End state 6 was vacuous and its token never matched.
- `node --test` on Node 24.13.0, piped → prints `ℹ fail 0`. `# fail 0` appears only with `--test-reporter=tap`.
- `flutter test` on an existing file → prints `All tests passed!`, as the plan states.
- `firebase-tools` current releases need Java 21. CI's default JDK is 17.

## Findings
### Major (all patched, adjudicated)
- `# fail 0` token never prints on Node 23+ → the suite pins `--test-reporter=tap`, and CI pins Node.
- End state 6 green before any work, and its token wrong on Windows → replaced by a Chrome route smoke test (End state 6, Task 14). Task 12's Done when now checks the CI job, the deploy workflow and the Hosting rewrite (`web-ship-ok`).
- Rules CI job fails on Java 17 → setup-java 21 (A5 retired).
- Task 6 opens a route Task 7 creates in the same phase → Task 6 `deps: [7]`.
- Task 5 breaks `test/jp_store_test.dart` (A4 web-is-memory test) and omits `pubspec.lock` → both added.
- Task 1 omits `attempt.dart` and `study_export.dart` → added. Export carries event ids and times.
- Generated FlutterFlow files edited with no `adopted-files.md` row (S3) → Task 8 owns rows in Phase 3, Task 14 in Phase 4.
- Task 4 cannot fire an auth trigger with a rules-only emulator → Task 2 adds the auth, functions and firestore emulators and installs every functions codebase.
- Notes and Discuss marks had no End state → End state 16.
- Web checks ran outside a browser → `--platform chrome` on End states 6, 7, 8, 10, 11.
- Home page contacts fetch and the Notifications row crash on the web → Task 14 guards both.
- Task 9 needs the say-it card files → added. Its slice now starts from the existing `speech_to_text` web path.

### Minor
- Task 10 duplicated an existing download path → rewritten to test `PickerStudyRecordFiles` and add no helper.
- Task 12 claimed `requiresTest: true` without a test file → `requiresTest: false`, with a Done-when command.
- The 11/02 plan's other floor items → noted as scoped to that plan only.

## Resolutions applied (grill decisions)
- Day plan tiebreak → first to reach the server wins (create-once) → D10, End state 14, Tasks 2 and 3.
- Late writes after account delete → rules require `users/{uid}` to exist → D13 (PIN-13), End state 17, Task 2.
- Delete proof → the real auth trigger on emulators → D14 (PIN-14), End state 8, Tasks 2 and 4.
- Web proof → Chrome tests plus a route smoke test → D15 (PIN-15), End state 6, Task 14.
- Say-it scores and last lesson → both sync as events → D16 (PIN-16), End state 16, Tasks 1 and 13.

## Adjudications
- End state 6 check `flutter test --platform chrome test/web_routes_smoke_test.dart` supersedes `flutter build web --release` (prints `Built build/web`) — End state 6 — operator-ratified (2026-11-19)
- Task 12 Done when `node -e …` (prints `web-ship-ok`) supersedes `flutter build web --release` (prints `Built build/web`) — Task 12 — AI-declared

## Residual risk
- A9: fake Firebase under `--platform chrome` is unproven. If it fails, Task 14 runs the smoke test against the emulators.
- A2: web reminders through the existing scheduled push function are unproven until backstop row 2.
- No probe re-ran the patched plan. WAR's auditors are the next check.
