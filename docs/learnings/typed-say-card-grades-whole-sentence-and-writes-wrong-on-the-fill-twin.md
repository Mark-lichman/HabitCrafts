---
name: typed-say-card-grades-whole-sentence-and-writes-wrong-on-the-fill-twin
description: Resolved in phase 5, a type-only say card scores only a match and sends a kana mismatch to Got it or Missed it
metadata:
  type: project
  keywords: [SayCardProbe, checkTypedAnswer, TypedVerdict, wholeSentence, accepted forms, Grade.wrong, type-only, say card twin, mastery reset, operator ruling, unscored]
  provenance: code-verified
  slug: typed-say-card-grades-whole-sentence-and-writes-wrong-on-the-fill-twin
  phase: 5
  tags: [speech, web, mastery, ruling-applied, one-fork-open]
  created: 2026-11-21
---

Phase 4 found that `SayCardProbe._check` in `lib/components/pages/quiet_room_mastery/probe_widgets.dart` called `checkTypedAnswer` with only the say card's own answer.
For a grammar say card that answer is `wholeSentence(...)` from `lib/components/pages/quiet_room_mastery/item_catalog.dart`.
It carries none of the fill twin's accepted forms, so a typo or a valid variant wrote `Grade.wrong` on the typed twin and reset its clears.

**Resolved in phase 5 (task seed-1), by the operator ruling of 2026-11-21.**
Only a match is scored by the matcher.
A plain-kana mismatch no longer writes wrong by itself.
Where the twin is a type-it card, a mismatch asks Got it or Missed it.
Where the twin is not a type-it card, a mismatch goes out unscored at once with the answer hidden.
The test `a kana mismatch on a choose twin is unscored at once, no marks` in `test/speech_service_web_test.dart` pins it.
The phase 4 fixture gap is closed: the fixture now uses the catalog's whole sentence, and a test types a form the twin may accept.

**One fork stays open.**
The ruling named only the plain-kana mismatch.
The guard `case TypedVerdict.wrong || TypedVerdict.selfCheck when _typedProbe == null` also covers `selfCheck` (kanji or romaji the matcher cannot judge).
Before phase 5 that answer showed the answer and Got it or Missed it on every twin, and both marks wrote unscored.
Now on a non-type-it twin it goes unscored at once with no prompt and no answer.
Three auditors raised this as an ask, and no operator answer was recorded.
If the operator wants the old self-check there, narrow the guard to `TypedVerdict.wrong` and change the test `an unjudged answer on a choose twin is unscored at once, no marks`.

**Pattern.**
A ruling worded for one verdict was coded with a guard that caught two.
Check that a guard covers exactly the verdicts the ruling names, and list any extra verdict in the worker report.

**Doc wording.**
`docs/japanese-lessons.md` first said "exact match" for this matcher.
`normaliseTyped` folds spacing, punctuation and katakana, so the audit asked for softer wording, and the doc now says so.

Verify still present before acting: `SayCardProbe._check` and `_reportTyped` in `lib/components/pages/quiet_room_mastery/probe_widgets.dart` @ phase 5 (integration tip 97afac9, content equal to landed tip ed8df39).
Grounding: read in the refinery worktree whose HEAD was integration/jp-web-sync/phase-5.
Replaces the phase 4 "awaiting-ruling" text, same tier.
Related: [[web-say-it-cards-gate-on-web-speech-but-score-by-azure-recording]].
