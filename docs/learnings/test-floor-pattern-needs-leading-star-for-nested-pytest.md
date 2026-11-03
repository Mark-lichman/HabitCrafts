---
name: test-floor-pattern-needs-leading-star-for-nested-pytest
description: The WAR test-floor token test_*.py never matches nested pytest files; use '*_test.dart */test_*.py' in this repo
metadata:
  type: project
  provenance: code-verified
  keywords: [testPattern, assert-test-in-diff, pytest, nested, glob, test floor, overrides.testPattern]
---

`assert-test-in-diff.sh` matches each test-pattern token with a bash `case` against the whole
repo-relative path. A token without a leading `*` (for example `test_*.py`) only matches files at the
repo root, so `pipeline/jp/tests/test_refresh.py` never matched and a task with a real, passing test
escalated as `no-test`. `*_test.dart` worked only because its leading `*` crosses `/`.

In this repo Dart tests live under `test/` and Python tests under `pipeline/jp/tests/`. The working
pattern is `*_test.dart */test_*.py`.
