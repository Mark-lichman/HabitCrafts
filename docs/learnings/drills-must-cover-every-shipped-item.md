---
name: drills-must-cover-every-shipped-item
description: A drill that judges data text verbatim failed on slash-joined examples; split on ／, judge the twin kana, and test every shipped item
metadata:
  type: project
  provenance: code-verified
  keywords: [speak drill, ／, slash, normalise, rubyKana, every item]
---

Ten shipped examples join forms with the full-width slash, which `SpeechService.normalise` keeps, so
those could only ever reach Close. The drill now splits `jp` and `jp_ruby` on ／ into one sentence per
form and derives kana and surface from the twin. A test over every lesson asserts no sentence keeps the
slash. Test a drill over every shipped item, not a sample.
