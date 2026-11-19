---
name: live-storage-ruleset-d3a07e98-has-no-committed-copy
description: firebase/storage.rules was written to match console-only ruleset d3a07e98; diff it against the console before deploy
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-1
  keywords: [storage.rules, d3a07e98, console, drift]
---

No committed file held the text of live Storage ruleset `d3a07e98`. `firebase/storage.rules` was written
to match it. Diff the file against the console before a deploy. The anonymous exclusion holds either way.
