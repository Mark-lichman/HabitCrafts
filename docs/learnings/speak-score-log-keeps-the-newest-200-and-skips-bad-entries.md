---
name: speak-score-log-keeps-the-newest-200-and-skips-bad-entries
description: SpeakScoreLog shows the newest 200 attempts from synced speak_score events and skips an unreadable entry
metadata:
  type: project
  provenance: code-verified
  slug: speak-score-log-keeps-the-newest-200-and-skips-bad-entries
  phase: 2
  keywords: [SpeakScoreLog, Recent scores, cutoff tuning, speak_score events, JpStore, SharedPreferences import, jp.speak.scores]
  created: 2026-11-20
---

Update of the older lesson of the same name. Phase 2 (Task 13) moved the log from SharedPreferences into the study store.

`SpeakScoreLog.fromEvents` reads `speak_score` events and keeps one entry per attempt, from its latest event.
`SpeakScoreLog.keep` is 200. It limits the shown list only.
The store keeps every event, because the log is append-only, and the oldest attempts drop off the list.
`SpeakAttempt.fromJson` returns null for a bad entry, and `fromEvents` skips it.
About 20 attempts are enough to tune the cutoffs.

`jp.speak.scores` in SharedPreferences is now read only by the one-time import (`importSpeakAndLessonPrefs`) and by `migrateV2Keys`. Nothing writes it.
The score list sorts by the attempt's full-precision time, then by event order. That is display order only, no winner is picked.

Related: [[event-time-compares-must-use-event-milliseconds-in-every-reader]].
Verify still present before acting: `SpeakScoreLog.keep` and `fromEvents` in `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart` @ phase 2 (read on the phase 2 integration tip 91f7f18, the second parent of landed tip 3280a2d).
