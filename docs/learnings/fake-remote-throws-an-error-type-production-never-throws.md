---
name: fake-remote-throws-an-error-type-production-never-throws
description: The in-memory remote fake threw JpRemoteUnavailable while Firestore throws FirebaseException, so the real offline arm had no test
metadata:
  type: project
  keywords: [JpRemoteUnavailable, FirebaseException, unavailable, JpRemoteMemory, JpRemoteFirestore, devices page, offline message, fake fidelity, anonymous user, loggedIn]
  provenance: agent-unverified
  slug: fake-remote-throws-an-error-type-production-never-throws
  phase: 3
  tags: [testing, pattern, jp-sync, resolved]
  created: 2026-11-20
---

Audit finding resolved in a fix round before land, recorded as pattern, not live instance.

The devices page maps two errors to its offline message: `JpRemoteUnavailable` and a `FirebaseException` with code `unavailable`.
The offline test used `JpRemoteMemory` with `online = false`, which throws only `JpRemoteUnavailable`.
`JpRemoteFirestore` never throws that type, and its `devices()` reads with `Source.server`, so a real offline read raises `FirebaseException`.
The arm real users hit was the one arm no test drove.
A wrong code string or a deleted arm would have passed every test and shown raw error text.

A second gap in the same page: the signed-out test used `currentUser` null.
An anonymous user has a uid but `loggedIn` false, and the guardrail "anonymous users never sync" was not pinned on the page.

Both were absorbed.
`test/devices_page_test.dart` at the tip has a `_FailingRemote('unavailable')` case, a `permission-denied` case, and an anonymous-user case.
`JpRemoteUnavailable` now appears only in the remote seam, the page and tests.

Rule: a test double must throw what the production adapter throws.
List each error shape the real adapter raises, and drive each one through the page.
Test a signed-in-but-anonymous user wherever a page gates on `loggedIn`.

Related: [[rules-use-signedin-helper-never-bare-request-auth]].
Source: audit pins `a700fba`, `e845eb4` and the clean pin `cc325b0` for Task 7.
