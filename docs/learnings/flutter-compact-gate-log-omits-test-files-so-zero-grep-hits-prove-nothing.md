---
name: flutter-compact-gate-log-omits-test-files-so-zero-grep-hits-prove-nothing
description: The flutter compact reporter does not name every test file, so a zero-hit grep of a gate log proves nothing
metadata:
  type: project
  keywords: [gate log, flutter test compact reporter, execution-evidence, cannot-confirm, done-when log, test file not named, endstate log, audit evidence]
  provenance: agent-unverified
  slug: flutter-compact-gate-log-omits-test-files-so-zero-grep-hits-prove-nothing
  phase: 2
  tags: [gate, audit, flutter, pattern]
  created: 2026-11-20
---

Source is the phase 2 gate audit of Task 5, which I did not re-run. Gate logs live outside the repo and were not read here.

The `flutter test` compact reporter prints a running count and failures, not each file.
The full-suite gate log had no line naming `test/open_jp_store_test.dart`.
Three other files also had zero hits.
So a zero-hit grep on a test file name in that log is a soft cannot-confirm, never a hard missing-test finding.

Corroborate with the done-when log, which ran the mapped test files alone.
It listed all 12 tests of the file as passed and ended with `All tests passed!`.
Also compare the tip tree with the gate-HEAD tree: an empty `git diff --stat` between them means the gate ran the tip's content.

A related stamp rule: an end-state check that names a test file a later phase owns ends in a compile failure and attests unverified, never unmet.
See [[end-state-check-naming-a-later-phase-test-stays-unverified]].
