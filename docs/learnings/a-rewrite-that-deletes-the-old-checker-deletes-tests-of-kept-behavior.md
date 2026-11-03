---
name: a-rewrite-that-deletes-the-old-checker-deletes-tests-of-kept-behavior
description: When a rewrite deletes an old mechanism's tests, port the assertions about behavior the new code keeps first
metadata:
  type: project
  provenance: agent-unverified
  promoted: dev/2026-10-27-azure-pronunciation@phase-2
  keywords: [rewrite, deleted tests, retained behavior, coverage]
---

The Task 3 rewrite removed the old `judge()` tests and a fixture helper. That also dropped the test for
the correct card's kanji line, which the widget keeps. Two audit seats caught it before land. Port the
kept-behavior assertions before you delete a mechanism's tests.
