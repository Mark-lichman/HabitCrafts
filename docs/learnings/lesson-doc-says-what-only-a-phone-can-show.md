---
name: lesson-doc-says-what-only-a-phone-can-show
description: docs/japanese-lessons.md must not state device effects (Gboard in Japanese) as fact, hold install-timed snapshots, or name shipped features in Open work
metadata:
  type: project
  provenance: code-verified
  keywords: [japanese-lessons.md, Open work, Deferred validations, hintLocales, Gboard, End state 14]
---

Phase 5 audits caught three doc slips: Gboard opening in Japanese stated as fact (only the phone shows
it, plan backstop A1), a "first install" ordinal snapshot, and an Open work bullet naming shipped
features. The fix: Open work holds one "Checks that need the phone" line that points to the plan's
Deferred validations. Also avoid "never" for the Play guard, which a long sentence outlasts. See
[[lesson-doc-must-hold-no-bare-counts]].
