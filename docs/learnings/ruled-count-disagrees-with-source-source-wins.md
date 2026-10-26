---
name: ruled-count-disagrees-with-source-source-wins
description: The kanji ruling said 80 N5 kanji; the archived Tanos page holds 79 and no 分. The source rules the content and the report names both
metadata:
  type: project
  provenance: code-verified
  keywords: [Tanos, N5, 79, 分, わかる, operator_additions, ruling]
---

The ruling said Tanos N5 holds 80 kanji. The archived primary page holds 79 rows and no 分, so under
"strict" the わかる twins stay hiragana. An auditor reading only mirror sites first rated it Major; the
round that read the archived page closed it as a Nit. Rule: when a ruling's count disagrees with the
primary source, the source decides the content and the report names both. Adding 分 is one entry in
`operator_additions`, then rerun `apply_kanji_rulings.py` and `publish.py`.
