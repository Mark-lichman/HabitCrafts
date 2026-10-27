---
name: speak-score-log-keeps-the-newest-200-and-skips-bad-entries
description: SpeakScoreLog keeps the newest 200 attempts and skips an unreadable entry; it is not a full history
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-2
  keywords: [SpeakScoreLog, Recent scores, cutoff tuning, SharedPreferences]
---

`SpeakScoreLog.keep` is 200, and the oldest entry drops. `SpeakAttempt.fromJson` returns null for a bad
entry, and `load` skips it. About 20 attempts are enough to tune the cutoffs.
