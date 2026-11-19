---
name: recorder-seam-cleanup-calls-need-separate-guards
description: Each recorder cleanup call in _Listen.finish needs its own try block; tests must assert the later cleanup ran
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-1
  keywords: [_Listen.finish, recorder seam, finally, microphone left open]
---

Three audit rounds found one bug class in `_Listen.finish`. A throw in one recorder seam hung `check()`,
escaped it, or skipped `stop()` and left the microphone open. The landed shape uses separate try blocks
and a finally. Tests must assert the later cleanup call ran, not just the verdict.
