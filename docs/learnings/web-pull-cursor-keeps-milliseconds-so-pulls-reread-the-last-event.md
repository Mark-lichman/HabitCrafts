---
name: web-pull-cursor-keeps-milliseconds-so-pulls-reread-the-last-event
description: A millisecond web cursor re-pulls the last event, so replay is flagged only for events the store lacks
metadata:
  type: project
  keywords: [pull cursor, Timestamp.toDate, serverAt, microseconds, replayPending, full rebuild every sync, held ids, JpSync, cloud_firestore web]
  provenance: code-verified
  slug: web-pull-cursor-keeps-milliseconds-so-pulls-reread-the-last-event
  phase: 2
  tags: [jp-sync, web, performance, hypothesis]
  created: 2026-11-19
---

Two auditors read that `JpRemoteFirestore.pullEvents` builds the next cursor with `Timestamp.toDate()`.
On web that `DateTime` keeps milliseconds, and `serverAt` keeps microseconds.
The cursor then floors below the last server time, and the next pull returns that event again.
`JpSync` set `sync.replayPending` from the raw pulled list, so each web run would rebuild the whole log.
Nobody ran this in a browser, so the web behavior is a code-reading hypothesis.

The landed fix in `lib/components/pages/quiet_room_mastery/jp_sync.dart` reads `store.allEvents()`, builds the held id set, and sets the replay flag only for a replayed kind the store lacks.
It costs one `allEvents` read per sync, which the Task 3 worker judged cheaper than the replay it saves.
Storing the cursor as seconds and nanoseconds was left out as unneeded.

Rule: a pull that can return an event already held must not count as new data.
Dedup by event id before deciding to replay.

Related: [[event-time-compares-must-use-event-milliseconds-in-every-reader]].
Verify still present before acting: the `held` filter in `JpSync._run` in `jp_sync.dart` (lines 114-119) @ phase 2 (tip 77441d6).
