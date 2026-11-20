---
name: pre-v3-study-import-mints-fresh-event-ids-and-uploads-history-twice
description: Resolved in phase 1, legacy rows get ids hashed from their content so old backups map onto uploaded events
metadata:
  type: project
  keywords: [event id, prepareLog, LegacyEventIds, legacy export, v1 v2 backup, duplicate events, jp_events append-only, deterministic id, migration, millisecond time]
  provenance: code-verified
  slug: pre-v3-study-import-mints-fresh-event-ids-and-uploads-history-twice
  phase: 1
  tags: [jp-sync, study-store, resolved, pattern]
  created: 2026-11-19
---

Pattern: any row without a global id needs a deterministic id, or a restored backup uploads a second copy once sync exists.
`jp_events` is append-only (PIN-3), so a duplicate can never be removed.

The first audit found that `prepareLog` gave a random `newEventId()` to every id-less row in a v1 or v2 import.
The operator ruled (Checkpoint 2026-11-19) that legacy ids hash row content.
The landed code does this with `LegacyEventIds` in `lib/components/pages/quiet_room_mastery/jp_store.dart`.
The key is kind, time, item and session, and an occurrence ordinal splits equal keys.
The SQLite v3 migration in `lib/components/pages/quiet_room_mastery/jp_store_sqlite.dart` uses the same class.
`prepareLog` first reuses the id of a held event with the same content, and only then takes a legacy id.

Second pass (absorbed before land): the key hashed the full microsecond time.
A phone keeps microseconds and a web `DateTime` does not, so the same row got different ids on the two devices.
`LegacyEventIds._time` now cuts the time to milliseconds.
Any content-hash key over a time must use millisecond precision. See [[one-microsecond-event-time-bump-is-a-noop-on-millisecond-datetime]].

Cross-task note for Task 3: see [[sync-pusher-must-dedup-legacy-events-by-event-id-not-jpevent-equality]].

Verify still present before acting: `LegacyEventIds` and `_time` in `jp_store.dart` on `integration/jp-web-sync/phase-1` @ phase 1 (tip 74c4260).
