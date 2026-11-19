---
name: overlapping-pronunciation-checks-close-the-second-microphone
description: Two overlapping PronunciationService.check calls can close the second microphone; the drill must keep one check in flight
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-1
  keywords: [PronunciationService, _cancelledStart, attempt token, microphone]
---

In `PronunciationService`, check B's `cancel()` marks check A's pending start as cancelled. A's late
`stop()` can then close B's microphone. The speaking drill must keep one check in flight and drop stale
results with an attempt token. See [[async-listen-result-needs-an-attempt-token]].
