---
name: tests-must-not-pin-state-a-later-task-flips
description: A test that asserts committed draft state or a ship-false flag breaks the later task that flips it; test invariants instead
metadata:
  type: project
  provenance: code-verified
  keywords: [REQUIRE_RUBY, test_ruby.py, drop_twins, invariant, later task, gate red]
---

Task 4 shipped `REQUIRE_RUBY = False`, and its first tests read the committed drafts and asserted the
flag value. Task 5 flips both, so its gate would have gone red on tests it does not own. The fix:
strip the state under test with a helper (`drop_twins(d)`), and replace the flag pin with an
invariant that holds before and after the flip (every committed draft passes `check_draft` under the
shipped flag). After fixing one such test, grep every caller of the same fixture: the audit found a
sibling only in round 3.
