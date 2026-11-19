---
name: reading-hint-covers-examples-and-prompts-only
description: The tap-a-word reading hint (RubyTapText) covers the example sentence and the fill-in prompt only; options and answer lines stay plain by design
metadata:
  type: project
  provenance: code-verified
  keywords: [RubyTapText, jp_study_kit.dart, reading hint, PIN-16, kanji view, didUpdateWidget]
---

`RubyTapText` in `jp_study_kit.dart` renders the example sentence and the fill-in prompt. Option
chips, the Also-correct line and the self-check answer line stay plain: a scope boundary, not a gap.
`didUpdateWidget` clears open readings when the ruby string changes, so a reading open in a prompt
hides when the blank fills. Tappable words use a hint color (operator ruling PIN-16). A prompt-path
widget test pins the second call site.
