---
name: url-document-route-reloads-behind-placeholder-on-every-router-rebuild
description: Hypothesis, a route with a URL-named document may reset its screen when the router rebuilds
metadata:
  type: project
  keywords: [FutureBuilder, completeFutures, go_router, pageBuilder, FFParameters, asyncParams, web reload, deep link, placeholder, screen state lost]
  provenance: agent-unverified
  slug: url-document-route-reloads-behind-placeholder-on-every-router-rebuild
  phase: 4
  tags: [web, nav, hypothesis, open-question]
  created: 2026-11-21
---

Labeled hypothesis. The auditor traced the library code and did not run it.

Task 14 made a web reload of a document route work.
A route like chat details, chat invite or image details keeps its document in the URL, not in `extra`.
`FFRoute.pageBuilder` in `lib/flutter_flow/nav/nav.dart` now wraps the page in a `FutureBuilder`.
That builder calls `ffParams.completeFutures()` inline and shows a blank `Container` until the state is `done`.

The claim: go_router 12.1.3 reruns `pageBuilder` for every page in the stack on each rebuild.
Each run makes a new future, and `FutureBuilder` moves back to `waiting` when the future changes.
So a push or pop over the route may swap its screen for the placeholder and rebuild it with its state lost.
The phone passes documents in `extra`, so `isAsyncParam` (needs a String value) is false there.

The route smoke test opens each route once and never navigates over it, so it cannot see this.
The operator was offered a fork: keep one `completeFutures()` future per page in a small private `StatefulWidget`, or accept the rebuild.
No ruling was recorded, and the inline `FutureBuilder` is still at the landed tip.

Absence of evidence note: the behavior is unrun, so check it in Chrome before acting.
A test could open a document route by URL, push a page over it and assert the first screen's state survives.

Construct found: inline `FutureBuilder` with `ffParams.completeFutures()` in `lib/flutter_flow/nav/nav.dart` @ phase 4 tip cc5bd6e.
Grounding: read in the refinery worktree whose HEAD was the landed tip.
