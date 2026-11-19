---
name: generated-auth-file-hand-edit-needs-an-adopted-files-row
description: A hand edit to a FlutterFlow-generated file needs a row in docs/architecture/adopted-files.md, or a re-export silently undoes it
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-1
  keywords: [adopted-files, FlutterFlow, S3, firebase_user_provider, loggedIn]
---

The `loggedIn` edit in `lib/auth/firebase_auth/firebase_user_provider.dart` was the first hand edit to a
FlutterFlow file. Standard S3 requires a register row in `docs/architecture/adopted-files.md`. Without
it, a FlutterFlow re-export restores `user != null` and anonymous users count as signed in again.
