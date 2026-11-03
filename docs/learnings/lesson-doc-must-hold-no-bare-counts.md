---
name: lesson-doc-must-hold-no-bare-counts
description: test_catalog_sources.py fails on a bare integer in docs/japanese-lessons.md that equals a catalog count; state the invariant, not the number
metadata:
  type: project
  provenance: code-verified
  keywords: [japanese-lessons.md, test_catalog_sources, PIN-13, bare integer, doc counts]
---

The de-mirror guard scans `docs/japanese-lessons.md` for standalone integers that equal a catalog count.
A doc edit that writes a count turns the gate red. Write the invariant ("every lesson", "each data
file"), never the number.
