---
name: one-microsecond-event-time-bump-is-a-noop-on-millisecond-datetime
description: Resolved in phase 1, a 1 microsecond tie-break bump does nothing where Dart web DateTime keeps milliseconds
metadata:
  type: project
  keywords: [DateTime precision, microseconds, milliseconds, appendLocalEvent, kLocalTieBump, last write wins, PIN-12, Dart web, tie-break, dart2js]
  provenance: code-verified
  slug: one-microsecond-event-time-bump-is-a-noop-on-millisecond-datetime
  phase: 1
  tags: [jp-sync, web, platform-gotcha, resolved, pattern]
  created: 2026-11-19
---

Pattern: any code that relies on sub-millisecond time must also work on web, because a Dart web `DateTime` may keep only milliseconds.

The first audit found `appendLocalEvent` adding `Duration(microseconds: 1)` so a local change beats the held event (PIN-12).
On a millisecond runtime that add leaves the time unchanged, the tie falls to random event-id order, and a web change can lose locally.
The landed code uses `kLocalTieBump = Duration(milliseconds: 1)` in `lib/components/pages/quiet_room_mastery/jp_store.dart` (#193), which holds on both runtimes.

A VM test run cannot show the difference, so a regression test for this needs `flutter test --platform chrome`.
The same precision trap hit the legacy event id hash, which now cuts times to milliseconds: [[pre-v3-study-import-mints-fresh-event-ids-and-uploads-history-twice]].

Verify still present before acting: `kLocalTieBump` in `jp_store.dart` on `integration/jp-web-sync/phase-1` @ phase 1 (tip 74c4260).
