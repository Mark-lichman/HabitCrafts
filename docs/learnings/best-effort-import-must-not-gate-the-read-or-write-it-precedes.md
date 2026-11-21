---
name: best-effort-import-must-not-gate-the-read-or-write-it-precedes
description: A failed one-time import must be reported and skipped by every caller, not abort the required call after it
metadata:
  type: project
  keywords: [one-time import, importSpeakAndLessonPrefs, best effort, FlutterError.reportError, S4, sibling sweep, last lesson, SpeakScoreLog, swallowed catch, fix round]
  provenance: code-verified
  slug: best-effort-import-must-not-gate-the-read-or-write-it-precedes
  phase: 2
  tags: [pattern, error-handling, jp-sync, sibling-sweep]
  created: 2026-11-19
---

Task 13 moved the say-it score log and the last-opened lesson from `shared_preferences` into study-store events.
A one-time import (`importSpeakAndLessonPrefs`) copies the old values on first use.

Across rounds the same defect class showed up at three call sites, one per fix round:
- `SpeakScoreLog.load` returned an empty list when only the import threw.
- `rememberLastGrammarLesson` and `readLastGrammarLesson` awaited the import with no try, so a failed import dropped the lesson change.
- The lessons path `_open` had no try around the last-lesson write.

Each fix round repaired the named site and left its siblings, and the reviewer's sibling sweep dismissed them with a reason that did not hold.
The old value is stamped at the Unix epoch (`kLegacyLastLessonAtUtc`), so it loses to any real event in either order, which is why skipping a failed import loses nothing.

Rule: when a round fixes one caller of a best-effort step, grep every caller of that step in the same commit.
Report through `FlutterError.reportError` (standard S4) and carry on.
The landed helper is `_importForLastLesson` in `lib/components/pages/quiet_room_mastery/speak_lesson_events.dart`.

Verify still present before acting: `_importForLastLesson` in `speak_lesson_events.dart` (used at lines 147 and 157) @ phase 2 (tip 77441d6).
