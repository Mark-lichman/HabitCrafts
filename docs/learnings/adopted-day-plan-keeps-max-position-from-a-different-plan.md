---
name: adopted-day-plan-keeps-max-position-from-a-different-plan
description: A device adopting another plan keeps its larger position and completed flag, which index a different plan
metadata:
  type: project
  keywords: [_syncDay, day plan, position, completed, PIN-10, End state 14, adopt plan, advanceDay, skip entries, open ask, parked ruling]
  provenance: code-verified
  slug: adopted-day-plan-keeps-max-position-from-a-different-plan
  phase: 2
  tags: [jp-sync, behavior, open-ask, day-plan]
  created: 2026-11-19
---

`_syncDay` in `lib/components/pages/quiet_room_mastery/jp_sync.dart` lets the server's plan win.
It takes `max(local.position, server.position)` and `server.completed || local.completed` even when `local.plan != server.plan`, then pushes the result with `advanceDay`.
A position is an index into one plan's entries.
A device at entry 5 of its own plan that adopts a plan at entry 0 jumps both devices past entries 0 to 4 that nobody answered.
A device that finished its own plan marks the winning plan completed on both.

The test `the day plan: the first plan to reach the server wins, and position never moves back (End state 14)` in `test/jp_sync_test.dart` pins the current behavior: the phone at position 3 adopts the web plan at position 3.
PIN-10 and D10 say position only moves forward and do not say what a position on another plan means.

Two audit seats raised this as an ask. It was not ruled when the phase held.
Fork 1 keeps the max across plans. Fork 2 carries local position and completed only when the plans match, otherwise takes the server's, and the End state 14 test changes with it.
The code comment at lines 164-165 states fork 1 as intent.

Verify still present before acting: `_syncDay` lines 153-184 in `jp_sync.dart` @ phase 2 (tip 77441d6).
