---
name: land-gate-runs-rules-emulator-tests-without-the-pinned-firebase-tools
description: The phase 1 land gate failed on a Java 21 error because the refinery tree had no pinned firebase-tools
metadata:
  type: project
  keywords: [land gate, gate_failed, introduced, firebase-tools, Java 21, JDK 17, rules-tests, npm ci, lockfile, global binary, node_modules, refinery provision, held:land-failed]
  provenance: agent-unverified
  slug: land-gate-runs-rules-emulator-tests-without-the-pinned-firebase-tools
  phase: 1
  tags: [war, gate, firebase, hypothesis]
  created: 2026-11-19
---

Phase 1 of jp-web-sync landed both tasks but held with `held:land-failed` (`gate_failed`, class `introduced`).
Nothing was pushed, and the base branch stayed at 47045f2.

Evidence:
- The failing step was `npm --prefix firebase/rules-tests test`.
- Its error was "firebase-tools no longer supports Java version before 21". The refiner host has JDK 17 only.
- The failure reproduced on a second run with a fresh TMPDIR.
- The base has no `firebase/rules-tests` directory, so that gate step is vacuously green there. A first emulator-backed test therefore turns an unseen gap into an "introduced" failure.
- The same suite ran green in the task 2 gate (`# pass 21`, `# fail 0`).

Resolved cause (supersedes the earlier hypothesis): the `_refinery` worktree never ran `npm ci` in `firebase/rules-tests`.
The pinned `firebase-tools` 13.35.1 (works on Java 17) was absent, so `npm` ran the GLOBAL firebase CLI 15.30.2, which needs Java 21.
Ruled out: a code defect (the suite is green with the pinned binary) and a flaky run (it reproduced).
Fix that worked: the gate clause now runs `npm ci --prefix firebase/rules-tests` and `npm install --ignore-scripts --no-save` in each functions codebase before the suite.
The Lead then completed the land by the escalation-completion recipe: merge 6ee0ee3, gate green (flutter 1031, pytest 521, rules 21/21), land-advance exit 0.

Rule: a gate step that runs an npm script must install that package's lockfile first.
If it does not, the script silently resolves a global binary of another version. Installing JDK 21 on the host was not needed.
The same cause turned End state 5 and 17 check artifacts red (`unverified`, not `unmet`), so those rows stay open until a rerun.

Related: [[rules-test-ci-job-installs-function-codebases-without-lockfile-or-token-limits]], [[recovery-relaunch-can-hold-on-pin-transfer-finish-by-hand]].
Grounding: read at the refinery worktree attached to `integration/jp-web-sync/phase-1`, whose ref equals tip 74c4260 (rung 2).
