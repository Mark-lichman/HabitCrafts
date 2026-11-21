---
name: event-time-compares-must-use-event-milliseconds-in-every-reader
description: Each event-time sort or compare must cut to milliseconds, including SQL order by and tie-break guards
metadata:
  type: project
  keywords: [eventMs, millisecond precision, microseconds, canonicalOrder, compareEvents, orderBy atUs, SQLite order, kLocalTieBump, isAfter, tie-break guard, PIN-12, End state 3]
  provenance: code-verified
  slug: event-time-compares-must-use-event-milliseconds-in-every-reader
  phase: 2
  tags: [jp-sync, web, platform-gotcha, pattern, resolved]
  created: 2026-11-19
---

Audit finding resolved in a fix round before land, recorded as pattern, not live instance.

The phone keeps microsecond event times and a Dart web `DateTime` keeps milliseconds.
Two events inside one millisecond then order by time on the phone and by event id on the web.
Task 3 fixed this one site at a time over three fix rounds: `canonicalOrder`, the seed versus attempt merge in `replayLog`, `compareEvents`, the local tie bump, and then the SQLite cache reader.
The SQLite `_refresh` and `sideEvents` queries had `orderBy: 'atUs ...'`, which is microsecond order, and each fix round missed a sibling reader.
At the tip no `orderBy` in `jp_store_sqlite.dart` names `atUs`.
A later audit also found `SpeakScoreLog.mark` guarding its tie bump with `!markAt.isAfter(at)`, which is microsecond precision.
At the phase 2 tip that guard reads `eventMs(markAt) <= eventMs(at)` in `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart`.
Three full-precision reads were left on purpose as display order only, with no winner picked: the `SpeakScoreLog.fromEvents` row sort, the sort in `discuss_list_widget.dart`, and the `isAfter` span in `mastery_debug_widget.dart`.
Two attempts in one millisecond can list in a different order on the phone and the web.

Rule: one precision for every event-time comparison.
Use `eventMs(t)` from `lib/components/pages/quiet_room_mastery/jp_event.dart`, and sweep SQL `ORDER BY`, `isAfter` and `compareTo` on event times together.
A VM test cannot show the gap, so pin each reader with two events 300 microseconds apart and ids against time order, run on both store types.

Related: [[one-microsecond-event-time-bump-is-a-noop-on-millisecond-datetime]], [[merged-attempts-replay-in-row-order-and-no-task-owns-the-sort]].
Verify still present before acting: `eventMs` in `jp_event.dart` and the `SpeakScoreLog.mark` guard @ phase 2 (read on the integration tip 91f7f18, the second parent of landed tip 3280a2d).
