---
name: id-only-jpevent-equality-weakens-event-list-assertions
description: JpEvent equals by event id alone, so old expect-equals event-list tests ignore device, time and body
metadata:
  type: project
  keywords: [JpEvent equality, operator ==, eventId, contentOf, sameContent, test weakening, expect equals list, toFirestore, assertion silently weaker]
  provenance: code-verified
  slug: id-only-jpevent-equality-weakens-event-list-assertions
  phase: 2
  tags: [tests, jp-sync, equality, pattern]
  created: 2026-11-19
---

Task 3 changed `JpEvent.operator ==` and `hashCode` to key on `eventId` alone.
That follows the Phase 1 ruling that two devices can hold one legacy event with different device ids.

Every older `expect(listOfEvents, equals(otherList))` then passes when device, time or body differ.
The worker converted only some comparisons to the `contentOf` helper, which compares the `toFirestore()` map.
Auditors found about eleven left over in `test/jp_event_test.dart`, among them the End state 4 export and import round trip.
A drift in time or body would no longer fail them.

Rule: when a value type's `==` is loosened, grep every `expect(` over lists of that type in the same change.
Compare through `contentOf(...)` or `sameContent` wherever the test means "same bytes".
`jp_sync_test.dart` already uses `expectSameRecord` for the cross-device checks.

Related: [[sync-pusher-must-dedup-legacy-events-by-event-id-not-jpevent-equality]].
Verify still present before acting: `operator ==` in `lib/components/pages/quiet_room_mastery/jp_event.dart` (line 182) and `contentOf` in `test/jp_event_test.dart` @ phase 2 (tip 77441d6). Whether every list assertion was converted at the tip is not confirmed.
