---
name: ace-commits-after-the-audited-pin-stay-out-of-a-manual-land
description: Ace workers here edit the active plan to hand duties forward; an ace commit after the audited pin is unreviewed and must not ride a manual land
metadata:
  type: project
  provenance: code-verified
  keywords: [ace, plan edit, audited pin, manual land, Files list, re-audit]
---

Ace workers in this repo edit the active plan under `docs/plans/` outside their task's `Files:` list,
to hand a duty to a later task (adding a file to a later task's `Files:`, naming a helper in a later
slice). The edits were useful, but one landed after the audit pin and was never re-audited.

When landing by hand, merge the audited pin, not the branch tip, and carry any useful unreviewed
note into the later task's slice yourself.
