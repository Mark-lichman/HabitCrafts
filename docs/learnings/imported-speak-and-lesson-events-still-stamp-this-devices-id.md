---
name: imported-speak-and-lesson-events-still-stamp-this-devices-id
description: The one-time import gives legacy-id events a device id, against the null legacy device ruling
metadata:
  type: project
  keywords: [legacyEventId, deviceId, legacy event, importOnce, speak_score, last_lesson, sameContent, export bytes, Phase 1 Checkpoint ruling, third legacy-id site]
  provenance: code-verified
  slug: imported-speak-and-lesson-events-still-stamp-this-devices-id
  phase: 2
  tags: [jp-sync, plan-mismatch, live]
  created: 2026-11-19
---

The Phase 1 Checkpoint ruling says a legacy event carries no device id, so two devices derive the same event byte for byte.
`lib/components/pages/quiet_room_mastery/jp_event.dart` says so in its header, and Task 3 applied it to the v3 migration and `prepareLog`.

At the tip `_importOnce` in `lib/components/pages/quiet_room_mastery/speak_lesson_events.dart` builds both imported events with `legacyEventId(...)` and `deviceId: device` from `store.deviceId()` (lines 76, 101, 113).
Two phones that import one old value then hold one event id with two device ids.
The pusher keeps the first upload, the stores keep their own copies, `sameContent` is false, and `encodeStudyExport` writes `deviceId` when it is set, so two exports of one record differ.
The test `two devices that import one value share one event` compares ids only, so it passes.

An auditor rated this Minor and marked it absorb in round 3, and the tip still has the code.
Task 3's file list did not include this new file, so its sweep could not reach it.

Fix: pass `deviceId: null` on both imported events, drop the `device` read, and assert in that test that both devices hold `sameContent` events with a null device id.
Grep `legacyEventId(` for callers whenever the legacy ruling changes.

Related: [[sync-pusher-must-dedup-legacy-events-by-event-id-not-jpevent-equality]], [[id-only-jpevent-equality-weakens-event-list-assertions]].
Verify still present before acting: `deviceId: device` in `_importOnce` @ phase 2 (tip 77441d6).
