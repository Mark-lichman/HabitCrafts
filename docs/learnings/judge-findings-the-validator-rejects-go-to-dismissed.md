---
name: judge-findings-the-validator-rejects-go-to-dismissed
description: A judge fix that publish validation would reject moves to judge_ruby.json's dismissed list with a reason, pinned by a test
metadata:
  type: project
  provenance: code-verified
  keywords: [judge_ruby.json, dismissed, test_judge_applied, mari.L33.3, twin_errors, judge pass]
---

When a judge fix cannot land because `publish` validation would reject it (Mari's L33.3 sign, see
[[kanji-sign-example-twin-checks-printed-text]]), the finding moves to a separate `dismissed` list in
`pipeline/jp/review/judge_ruby.json`. Each entry needs `status: dismissed`, a non-empty `why`, and the
`current` text. `test_judge_applied.py` pins all three, so an unfixed finding cannot slip into
`dismissed` to turn the gate green. A phase report names every dismissal, because the plan said
"applied" only.
