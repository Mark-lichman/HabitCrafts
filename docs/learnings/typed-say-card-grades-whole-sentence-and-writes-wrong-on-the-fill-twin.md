---
name: typed-say-card-grades-whole-sentence-and-writes-wrong-on-the-fill-twin
description: A type-only say card judges a whole sentence with no accepted forms and can reset the typed twin
metadata:
  type: project
  keywords: [SayCardProbe, checkTypedAnswer, TypedVerdict, wholeSentence, accepted forms, Grade.wrong, type-only, say card twin, mastery reset]
  provenance: code-verified
  slug: typed-say-card-grades-whole-sentence-and-writes-wrong-on-the-fill-twin
  phase: 4
  tags: [speech, web, mastery, awaiting-ruling]
  created: 2026-11-21
---

On a type-only web browser, `SayCardProbe._check` in `lib/components/pages/quiet_room_mastery/probe_widgets.dart` calls `checkTypedAnswer` with only `{'answer': widget.probe.answer}`.
For a grammar say card, `lib/components/pages/quiet_room_mastery/item_catalog.dart` builds that answer with `wholeSentence(...)`.
The check gets no accepted-forms list, which the fill twin does get.

A plain-kana mismatch returns `TypedVerdict.wrong`, and the probe reports `Outcome.wrong`.
The host then writes `Grade.wrong` on the typed twin, and `docs/japanese-lessons.md` says wrong resets the clear count.
So a typo in a long sentence, or a valid variant the fill row accepts, resets the learner's typed clears.

The auditor asked the operator to choose.
1. Write only a right answer on the twin and send a mismatch to the Got it or Missed it self-check.
2. Keep wrong on the twin as built.

No ruling was recorded, and the behavior is unchanged at the landed tip.
The test fixture `say.p1` in `test/speech_service_web_test.dart` uses the blank as its answer, not the catalog's whole sentence, so the test hides the problem.
The path runs only on type-only browsers.

Verify still present before acting: `SayCardProbe._check` and `wholeSentence` in `item_catalog.dart` @ phase 4 tip cc5bd6e.
Grounding: read in the refinery worktree whose HEAD was the landed tip.
Related: [[web-say-it-cards-gate-on-web-speech-but-score-by-azure-recording]].
