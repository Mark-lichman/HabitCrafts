---
name: generated-auth-file-hand-edit-needs-an-adopted-files-row
description: A hand edit to a FlutterFlow-generated file needs a row in docs/architecture/adopted-files.md, or a re-export silently undoes it
metadata:
  type: project
  provenance: code-verified
  slug: generated-auth-file-hand-edit-needs-an-adopted-files-row
  phase: 3
  keywords: [adopted-files, FlutterFlow, S3, firebase_user_provider, loggedIn, nav.dart, main.dart, regenerate, sibling edit, row list survey]
  tags: [flutterflow, docs, recurrence]
  created: 2026-11-21
---

The `loggedIn` edit in `lib/auth/firebase_auth/firebase_user_provider.dart` was the first hand edit to a
FlutterFlow file. Standard S3 requires a register row in `docs/architecture/adopted-files.md`. Without
it, a FlutterFlow re-export restores `user != null` and anonymous users count as signed in again.

Recurrence in phase 3 of the web sync plan: the plan's row list was a survey and missed two hand edits.
- Task 6 wired `JpSyncHost` into `lib/main.dart`, and the existing `main.dart` row listed only theme changes. The phase-close sweep fixed it.
- Task 7 registered `DevicesPageWidget` in `lib/flutter_flow/nav/nav.dart`, and the `nav.dart` row still reads 2026-09-27 only. Two audit seats flagged it as `absorb`, but it landed unfixed.
- The register preamble still says the 2026-11-20 rows come from "Tasks 6 and 8".

A regenerate of `nav.dart` would drop the Devices route, and the profile page's `context.pushNamed(DevicesPageWidget.routeName)` would then fail.

Rule: a plan's list of rows to add is a floor. At phase close, diff every generated file the phase touched and check each against the register.
The file's own check command, `git log --diff-filter=M --name-only`, finds the stragglers.
When one task adds a row for a file, check the sibling files the same phase edited.

Locate: `docs/architecture/adopted-files.md`, the `lib/flutter_flow/nav/nav.dart` row. Verify still present before acting.
Grounding: read at the integration tip `5f9c4abd`, the second parent of the landed merge. No worktree sat at the landed tip itself.
Related: [[a-task-edit-to-a-file-a-sibling-task-owns-conflicts-at-pin-transfer]].
