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

Rule: when a plan row mixes tests from two phases, split its check per phase, or write the earlier half first and join with `;`.
Treat the row as open until the later task lands.

Verify still present before acting: absence of `test/web_auth_test.dart` and presence of `firebase/rules-tests/delete_cascade.test.js` @ phase 2 (tip 77441d6).
