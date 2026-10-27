---
name: not-quite-card-is-reachable-only-in-tests
description: listenOnce never returns wrong live, so the speak drill's Not quite card appears only through the test fake
metadata:
  type: project
  provenance: code-verified
  keywords: [listenOnce, Judgement.wrong, unverified, FakeEar, Not quite]
---

`listenOnce` starts at `unverified` and ranks `wrong` below it, so a live mismatch shows "Can't check
this one". Tests inject a fake that calls `judge()` directly, which is the only path to Not quite.
This keeps "no correct answer marked wrong". Making `wrong` reachable live also changes the vocabulary
drill, so check that first.
