---
name: web-datetime-may-keep-microseconds-on-the-pinned-sdk-so-the-cut-rationale-is-stale
description: An auditor read the Dart SDK and found web DateTime keeps microseconds, so the millisecond-cut comments give a stale reason
metadata:
  type: project
  keywords: [DateTime precision, dart2js, date_time_patch, _microsecond, legacyTime, millisecond cut, Flutter 3.44.8, web DateTime, comment rationale, advisory]
  provenance: agent-unverified
  slug: web-datetime-may-keep-microseconds-on-the-pinned-sdk-so-the-cut-rationale-is-stale
  phase: 3
  tags: [jp-sync, web, platform-gotcha, hypothesis, comments]
  created: 2026-11-20
---

Hypothesis from one audit note. The servitor did not read the SDK.

A Task 15 audit read the local Dart SDK 3.12.2, which pairs with the Flutter 3.44.8 that `.github/workflows/ci.yml` pins.
Its file `lib/_internal/js_shared/lib/date_time_patch.dart` gives the dart2js `DateTime` a `_microsecond` field, and `DateTime.parse` passes it through.
If that holds, a browser keeps microseconds on this toolchain.

The millisecond cut stays correct.
It is deterministic and harmless on both runtimes, and the operator ruling (Checkpoint 2026-11-20) stands.
Only the stated reason is stale.
Comments at the tip still say a web `DateTime` keeps no finer time: `legacyTime` and `LegacyEventIds._time` in `lib/components/pages/quiet_room_mastery/jp_store.dart`, the SQLite header in `jp_store_sqlite.dart`, and a doc in `jp_event.dart`.

A VM test cannot show the difference.
To confirm, run a `--platform chrome` test that parses a time with microseconds and prints it, on a machine where Chrome tests connect: see [[flutter-chrome-platform-tests-fail-to-connect-on-the-dev-machine-and-ci-skips-them]].

This weakens the premise of [[one-microsecond-event-time-bump-is-a-noop-on-millisecond-datetime]] and [[event-time-compares-must-use-event-milliseconds-in-every-reader]].
Their fixes still hold, because milliseconds are safe on either runtime.
Do not remove a cut on the strength of this note.

Verify still present before acting: the comment text "keeps no finer time" in `jp_store.dart` @ phase 3 (read on the integration tip 6273976, refinery worktree). The SDK claim is unverified.
