---
name: speak-attempt-time-is-written-in-utc-though-the-worker-report-says-local
description: The code already writes the say-it score time in UTC, so the parked ask is half answered
metadata:
  type: project
  keywords: [SpeakAttempt.toJson, UTC offset, identityKey, fromEvents, worker report stale, Ignore for now, parked ask, rung conflict, speak_score, time zone order]
  provenance: code-verified
  slug: speak-attempt-time-is-written-in-utc-though-the-worker-report-says-local
  phase: 2
  tags: [jp-sync, open-ask, evidence-conflict, task-13]
  created: 2026-11-19
---

The Task 13 worker report lists the say-it score time as still written in local ISO with no offset, and the plan did not ask to change it.
That is why an ask was parked: should the score body carry a UTC offset so synced devices in different zones order Recent scores by one instant?

The code differs. At the tip `SpeakAttempt.toJson` in `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart` writes `'at': at.toUtc().toIso8601String()` (line 284).
`identityKey` also reads the time in UTC (line 275), and `fromJson` reads both forms, so old offset-less bodies still match.
The test `toJson writes the attempt time in UTC` in `test/speak_lesson_events_test.dart` pins it. It arrived in a round 1 fix commit.
The pinned code outranks the worker report, so the ask's second fork is already in place.

If the operator rules for the old local form, revert `toJson`, that test and the mixed-form `fromEvents` test. `identityKey` can stay.
One more consequence: the `addOldSpeakScore` helper in `test/jp_store_test.dart` calls `toJson`, so it no longer writes the old offset-less form that real phones hold. Use `{...a.toJson(), 'at': a.at.toIso8601String()}` there.

Verify still present before acting: lines 275 and 284 of `quiet_room_speak_widget.dart` @ phase 2 (tip 77441d6).
