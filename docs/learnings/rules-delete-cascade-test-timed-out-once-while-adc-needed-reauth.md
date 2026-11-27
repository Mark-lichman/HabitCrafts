---
name: rules-delete-cascade-test-timed-out-once-while-adc-needed-reauth
description: Hypothesis, the delete cascade rules test hit its 60 s cap once while local Google credentials needed reauth
metadata:
  type: project
  keywords: [delete_cascade.test.js, CASCADE_TIMEOUT_MS, invalid_rapt, invalid_grant, ADC reauth, gate_failed environment, flaky rules test, deleteAllUserData, emulator, oauth2.googleapis.com]
  provenance: agent-unverified
  slug: rules-delete-cascade-test-timed-out-once-while-adc-needed-reauth
  phase: 2
  tags: [war, gate, hypothesis, flaky, firebase]
  created: 2026-11-19
---

Hypothesis note, not a confirmed root cause.

The Task 13 gate failed once on `after account delete, a device that recreates users/{uid} still cannot write study data (PIN-13)` in `firebase/rules-tests/delete_cascade.test.js`.
The error was "timed out after 60000 ms" with the cascade state `{"profile":false,"marker":true,"jp_events":2,"jp_days":1,"devices":2}`.
That matches `CASCADE_TIMEOUT_MS = 60000` in the test file.

Evidence for an environment cause:
- The emulated `deleteAllUserData` logged a call to the real Google token endpoint and `invalid_grant ... invalid_rapt`, which means local Application Default Credentials needed reauth.
- Task 4's own gate log showed the same `invalid_rapt` lines and still passed.
- Task 13 changed no `firebase/` file.
- A rerun in a fresh shell and TMPDIR passed 25 of 25 in 53.7 s. The engine classed it `environment` and re-ran the gate green.

Ruled out: a task regression and a base failure (the test did not exist at the phase base).
Not ruled out: a real race, because the passing run took 53.7 s against a 60 s cap.

If this recurs, raise the cap or stub the credentials, and check `gcloud auth application-default login` state before blaming code.

Verify still present before acting: `CASCADE_TIMEOUT_MS` in `firebase/rules-tests/delete_cascade.test.js` @ phase 2 (tip 77441d6).
