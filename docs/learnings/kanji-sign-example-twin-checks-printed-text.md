---
name: kanji-sign-example-twin-checks-printed-text
description: Mari's L33.3 example is printed in kanji, so its twin is checked against the printed text, not a hiragana reading
metadata:
  type: project
  provenance: code-verified
  keywords: [mari.L33.3, kanji twin, ruby, twin_errors, plain_of, publish.py, 立入禁止]
---

End state 2 says each twin's reading equals its hiragana text. Mari's L33.3 first example quotes the
sign 「立入禁止」 verbatim in kanji, so no reading can equal it. `twin_errors` in `pipeline/jp/publish.py`
keeps the bracket checks for that field and requires `plain_of(ruby)` to equal the printed field
instead. Its twin is written as bracketed kanji with the sign's reading: `立入禁止{たちいりきんし}`.
