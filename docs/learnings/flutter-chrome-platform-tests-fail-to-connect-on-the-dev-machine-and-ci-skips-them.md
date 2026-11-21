---
name: flutter-chrome-platform-tests-fail-to-connect-on-the-dev-machine-and-ci-skips-them
description: Flutter 3.44.8 on Windows serves canvaskit as 404 in flutter test --platform chrome, so every Chrome test hangs; fixed by a one-line local flutter_tools patch
metadata:
  type: project
  keywords: [flutter test --platform chrome, Connection closed before test suite loaded, canvaskit, 404, flutter_tools, _localCanvasKitHandler, path.fromUri, Windows, Flutter 3.44.8, Done-when, CI]
  provenance: lead-verified
  slug: flutter-chrome-platform-tests-fail-to-connect-on-the-dev-machine-and-ci-skips-them
  phase: 3
  tags: [environment, war, jp-sync, root-cause]
  created: 2026-11-20
---

Symptom: every `flutter test --platform chrome` run on the Windows dev machine hangs, then prints `Failed to load "...": Connection closed before test suite loaded`. A one-line test fails the same way. An older Chrome (Chrome for Testing 150) fails the same way, so Chrome is not the cause.

Root cause (Lead-verified 2026-11-20 by reading the test page console over DevTools): the test page requests `/canvaskit/chromium/canvaskit.js` and gets 404. In Flutter 3.44.8, `packages/flutter_tools/lib/src/test/flutter_web_platform.dart` `_localCanvasKitHandler` builds `fullPath` with `_fileSystem.path.fromUri(request.url)`. On Windows that gives backslashes, so `fullPath.startsWith('canvaskit/')` is false and the handler returns 404.

Fix applied on the dev machine: in `C:/src/flutter`, that line now reads `final String fullPath = request.url.path;`. Then remove `bin/cache/flutter_tools.stamp` so the tool rebuilds. Undo with `git -C C:/src/flutter checkout -- packages/flutter_tools`. A `flutter upgrade` drops the patch.

Check before relying on Chrome rows: `git -C C:/src/flutter diff --stat` shows the one-line change, and `flutter test --platform chrome test/romaji_test.dart` prints `All tests passed!`.

CI: no file under `.github/workflows` runs `--platform chrome`, so CI never confirms these End states. Only the dev machine (patched) does.

Second trap found the same day: once Chrome tests load, a debug web build (DDC) can still fail at load with `Cannot read properties of undefined (reading 'habit_craft__...')` when a new import closes a cycle of files that import each other. Task 6 hit this and broke the cycle.
