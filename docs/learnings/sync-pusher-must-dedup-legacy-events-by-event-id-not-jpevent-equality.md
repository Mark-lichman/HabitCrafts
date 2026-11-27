---
name: sync-pusher-must-dedup-legacy-events-by-event-id-not-jpevent-equality
description: Two devices can hold one legacy event id with different device ids, so the pusher must compare by event id
metadata:
  type: project
  keywords: [JpEvent equality, deviceId, eventId dedup, jp_events create denied, append-only, Task 3, pusher, legacy event, forecast]
  provenance: code-verified
  slug: sync-pusher-must-dedup-legacy-events-by-event-id-not-jpevent-equality
  phase: 1
  tags: [jp-sync, cross-task, forecast]
  created: 2026-11-19
---

Forecast for Task 3 (Phase 2, not landed). The referents are verified, the failure itself is not yet observable.

A legacy row takes the local store's device id when it gets its event id.
The phone migration and a web import of the same old backup therefore make the same `eventId` with different `deviceId` values.
`JpEvent.operator ==` in `lib/components/pages/quiet_room_mastery/jp_event.dart` compares `deviceId`, so the two copies are not equal.
The `jp_events` rule in `firebase/firestore.rules` allows read and create only, so a second device's create for an existing document counts as an update and is denied.

Task 3 must treat an existing document with the same `eventId` as already pushed.
Its dedup must key on `eventId`, never on `JpEvent ==`.
Replay and last write wins never read `deviceId`, so the store is correct.

Related: [[pre-v3-study-import-mints-fresh-event-ids-and-uploads-history-twice]].
Verify still present before acting: `operator ==` in `jp_event.dart` and the `jp_events` match block in `firebase/firestore.rules` on `integration/jp-web-sync/phase-1` @ phase 1 (tip 74c4260).
