---
name: n4-kanji-limit-has-no-committed-list
description: The "standard N4 kanji only" rule for kanji twins has no committed kanji list or test; auditors found 17 kanji outside the core set
metadata:
  type: project
  provenance: code-verified
  keywords: [N4, N5, kanji list, kanji twin, judge rule R1, わたし, 私, standard N4]
---

Judge rule R1 in `judge_ruby.json` says N5/N4 kanji only, and its method line cites a scripted check,
but no script, kanji list or test is committed. Auditors found 17 kanji outside the core N5+N4 set
(説 菜 好 頭 働 村 声 乗 薬 寒 暗 短 遠 暑 所 合 都), and R1 was applied unevenly (勝 and 描 rejected,
頭 and 村 kept). The pronoun わたし also stays in hiragana in about 45 twins although rule R6 implies 私.
Both are operator rulings (2026-10-26): ask Mark before changing twin kanji policy.
