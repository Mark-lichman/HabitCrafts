---
name: a-no-await-before-popup-test-must-assert-before-the-first-await
description: A call-order test on a fake cannot fail when an await is added, so start the call and assert at once
metadata:
  type: project
  keywords: [popup before await, signInWithPopup, popup blocked, test cannot fail, fake call list, user gesture, Google sign-in web, web_auth_test, signInFunc, setPersistence]
  provenance: code-verified
  slug: a-no-await-before-popup-test-must-assert-before-the-first-await
  phase: 3
  tags: [testing, web, auth, task-8, jp-sync]
  created: 2026-11-20
---

A browser blocks a sign-in popup that does not open inside the user's tap, so the popup call must run before any `await`.
The Task 8 code comments call this load-bearing.

The first version of the test asserted `h.auth.calls.first == 'popup'`.
The fake records only auth calls, so an `await` added before the popup still leaves `'popup'` first, and the test passes either way.
The audit raised it as a Minor, and a fix round absorbed it.

Fixed form, present at the landed tip: call `signInWithGoogle` without `await`, then assert `h.auth.calls == ['popup']` at once, then `await` the pending future.
Nothing past the first `await` has run at that point, so the assertion holds only if the popup call is synchronous.

Rule: to test "X runs before any await", start the call, assert on the recorded effects with no `await` between, and only then await the result.
A test that reads call order after completion proves nothing about await placement.

Same pass, a Nit: a "reload restores the same user" test only wrapped the fake's own `currentUser`, so it did not prove survival across a reload.
It was renamed and commented, and the IndexedDB persistence test is the real guard. A real reload needs a browser.
In the manager, `_keepWebSession` pins `Persistence.INDEXED_DB` after the sign-in, never before, for the same popup reason.

Verify still present before acting: `test/web_auth_test.dart` (group "Google sign-in on the web") and `_signInOrCreateAccount`, `_keepWebSession` in `lib/auth/firebase_auth/firebase_auth_manager.dart` @ phase 3 (read on the refinery worktree at tip 1658879).
