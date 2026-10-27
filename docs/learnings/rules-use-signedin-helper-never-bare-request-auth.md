---
name: rules-use-signedin-helper-never-bare-request-auth
description: An anonymous Firebase user passes request.auth != null; new Firestore and Storage rules must use the signedIn() helper
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-1
  keywords: [signedIn, request.auth, anonymous, firestore.rules, storage.rules, loggedIn]
---

An anonymous Firebase user passes `request.auth != null`. Both `firebase/firestore.rules` and
`firebase/storage.rules` define `signedIn()`, which also requires `sign_in_provider != 'anonymous'`.
New rules must call it. `loggedIn` in `lib/auth/firebase_auth/firebase_user_provider.dart` excludes
anonymous users the same way. No emulator test covers the rules.
