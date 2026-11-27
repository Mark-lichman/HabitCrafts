---
name: flutter-web-test-server-answers-any-path-containing-host-dart-js
description: A web-tested library named like jp_sync_host.dart gets the Flutter test runner instead of its own code
metadata:
  type: project
  keywords: [host.dart.js, flutter_web_platform.dart, flutter test --platform chrome, file name collision, jp_sync_host, rename library, test server, Flutter SDK]
  provenance: code-verified
  slug: flutter-web-test-server-answers-any-path-containing-host-dart-js
  phase: 3
  tags: [flutter, web, toolchain, naming, jp-sync]
  created: 2026-11-20
---

The Flutter web test server in the SDK answers any request whose path contains `host.dart.js` with its own test host script.
A library file whose name ends in `host.dart` compiles to a path that matches, so the browser loads the runner and not the library.

Seen in phase 3 Task 6: the plan named `jp_sync_host.dart`, and the worker renamed it to `jp_sync_host_service.dart`.
The class name `JpSyncHost` and the test name stayed, so the Done-when command did not change.
An auditor judged the rename intent-consistent, a note and not a plan violation.

Rule: for any file that a `--platform chrome` test imports, do not end its name in `host.dart`.
When a plan names such a file, rename it and keep the symbol names.

Check command: `grep -n "host.dart.js" "<flutter-sdk>/packages/flutter_tools/lib/src/test/flutter_web_platform.dart"`.
Verified present at phase 3: the match is the `request.requestedUri.path.contains('host.dart.js')` branch (line 391 in the SDK in use) and a static path at line 199.
The root-cause claim comes from reading the SDK source and the worker's report. No one ran the collision with the original name.
Verify still present before acting: the SDK may change this in a later Flutter release.
