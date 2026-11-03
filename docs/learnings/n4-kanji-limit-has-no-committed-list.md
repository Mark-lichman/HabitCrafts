---
name: n4-kanji-limit-has-no-committed-list
description: The strict N5+N4 kanji list for twins is committed (pipeline/jp/kanji_n5_n4.json) and enforced by test_kanji_list.py
metadata:
  type: project
  provenance: code-verified
  keywords: [N4, N5, kanji list, kanji_n5_n4.json, test_kanji_list, 私, strict]
---

Phase 4 committed `pipeline/jp/kanji_n5_n4.json` (Tanos N5 79 + N4 166, pages archived under
`pipeline/jp/tanos/` and sha256-pinned) and `pipeline/jp/tests/test_kanji_list.py`, which checks every
twin against it. Operator rulings (2026-10-26): 私{わたし} for the pronoun (私 is on the N4 page), and
words with kanji outside the list are hiragana in their twin. Superseded: the earlier state with no
committed list or test.
