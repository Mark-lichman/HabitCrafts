---
name: stampday-fabricates-build-time-for-migrated-days
description: Resolved in phase 1, a null-means-unknown field fell through a double null-coalesce to now
metadata:
  type: project
  keywords: [stampDay, builtAtUtc, null coalesce, ?? chain, DayRecord, migrated day, position move, PIN-10, day plan merge]
  provenance: code-verified
  slug: stampday-fabricates-build-time-for-migrated-days
  phase: 1
  tags: [jp-sync, pattern, null-handling, resolved]
  created: 2026-11-19
---

Pattern: when null means "never recorded", a `a ?? b ?? now()` chain turns unknown into a made-up value.

The first audit found `stampDay` in `lib/components/pages/quiet_room_mastery/jp_store.dart` inventing a build time.
The v3 migration leaves `builtAtUtc` null on existing days, and a position move kept the plan but fell through to now.
The landed code (#191) keeps the stored null when the plan is the same: `record.builtAtUtc ?? old.builtAtUtc`.
Only a new plan takes `_nowUtc()`.

Why it matters for Task 3: the day-plan merge (PIN-10, first plan to reach the server wins) may read `builtAtUtc` as the real build time.
Note that `stampDay` uses the store clock, not the relaunch `FixedClock`.
Note also that `session_widget._insert` rewrites the plan JSON, which counts as a new build.

Verify still present before acting: `stampDay` in `jp_store.dart` on `integration/jp-web-sync/phase-1` @ phase 1 (tip 74c4260).
