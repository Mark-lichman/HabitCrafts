---
name: end-state-check-naming-a-later-phase-test-stays-unverified
description: End state 8 check chains a Phase 3 test with an and-and, so the phase 2 half never runs
metadata:
  type: project
  keywords: [End state 8, web_auth_test.dart, endstate-2-5, short-circuit, unverified, plan check, Task 8, deleteAllUserData, PIN-14, phase end-state audit]
  provenance: code-verified
  slug: end-state-check-naming-a-later-phase-test-stays-unverified
  phase: 2
  tags: [plan-mismatch, end-state, war, jp-sync]
  created: 2026-11-19
---

End state 8 joins two checks with `&&`: `flutter test --platform chrome test/web_auth_test.dart`, then `npm --prefix firebase/rules-tests test`.
The plan puts `test/web_auth_test.dart` in Task 8 (Phase 3).
At the phase 2 tip that file is absent, so the first command fails with "File not found" and the `&&` skips the rules half.
Every phase 2 gate-audit therefore attested End state 8 as `unverified` and raised a Nit, and the artifact `endstate-2-5.log` was red.

The delete half (PIN-14) is Task 4's and was evidenced from the gate log instead: `deleteAllUserData` empties `jp_events`, `jp_days` and `devices`, and the rules suite ended `# pass 25`, `# fail 0`.

Recurred in phase 3, with Tasks 6 and 8 as the owners.
Phase 3 End states 7 (`test/web_auth_test.dart` and `test/jp_sync_host_test.dart`) and 8 stayed `unverified` in every gate-audit.
Both Chrome tests were still absent at the tip (6273976) because Tasks 6 and 8 escalated on a Chrome environment fault: see [[flutter-chrome-platform-tests-fail-to-connect-on-the-dev-machine-and-ci-skips-them]].
Each gate-audit raised the same two Nits on every landed task, which is noise once the owner is known.
The rules half of End state 8 was green in each gate log (`# pass 25`, `# fail 0`), but the artifact itself was red.

Third pass, later phase 3 run: Task 8 landed, so `test/web_auth_test.dart` is present and ran 12 of 12 in Chrome.
`test/jp_sync_host_test.dart` is still absent at tip 1658879 because Task 6 (deps 7) is held on AUDIT-TAMPER (see [[audit-tamper-escalates-pinned-audits-when-cwd-has-no-git-dir]]).
End state 7 therefore stays `unverified` (compile error "File not found: jp_sync_host_test.dart"), and its sync-host half must be re-checked after Task 6 lands.
End states 8 and 9 and the whole suite were `met`.
The gate-audit Nits about this are noise once the owner is known.

Rule: when a plan row mixes tests from two phases, split its check per phase, or write the earlier half first and join with `;`.
Treat the row as open until the later task lands.

Verify still present before acting: absence of `test/web_auth_test.dart` and presence of `firebase/rules-tests/delete_cascade.test.js` @ phase 2 (tip 77441d6).
