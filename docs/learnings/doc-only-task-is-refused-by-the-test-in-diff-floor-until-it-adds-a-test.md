---
name: doc-only-task-is-refused-by-the-test-in-diff-floor-until-it-adds-a-test
description: A comment-only fix task got no-test at merge, and merged only after a test was added
metadata:
  type: project
  keywords: [assert-test-in-diff, no-test, floor-retry, comment-only task, doc-only task, merge floor, seed-3, jp_event.dart, late fix, test floor]
  provenance: agent-unverified
  slug: doc-only-task-is-refused-by-the-test-in-diff-floor-until-it-adds-a-test
  phase: 3
  tags: [war, merge-floor, process, jp-sync]
  created: 2026-11-20
---

Task seed-3 fixed the legacy-id key doc comments in `lib/components/pages/quiet_room_mastery/jp_event.dart`. Its diff had no test file.

The first merge attempt returned `no-test`.
The engine ran `assert-test-in-diff.sh` with the pattern `*_test.dart */test_*.py *.test.js`, and it exited 1.
Nothing merged and no gate ran.
A floor retry then merged the branch at `dcd26dc`.
That tip adds one test to `test/speak_lesson_events_test.dart`, which pins the key fields the new comments name.

The worker report said "comments only".
The pinned diff showed an extra test and three reformatted `expect` calls.
The auditor trusted the diff over the report, and found each assertion unchanged.

Rule: a plan task that only edits comments or docs still needs one test that pins the claim it writes.
Name that test in the task slice, or the first merge fails.
Pin comment claims about key fields with a test, because a comment cannot go stale in a way a test sees.

Related: [[japanese-lessons-doc-storage-prose-is-owned-by-no-task]].
Source: engine merge records for `seed-3` (`git-confirmed:no-test`, then `git-confirmed:merged` at integration tip 6273976). Not read from a gate log by this servitor.
