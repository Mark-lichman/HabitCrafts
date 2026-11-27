---
name: architecture-docs-state-19-routes-while-nav-registers-37
description: Three architecture docs repeat a route count that nav.dart no longer matches
metadata:
  type: project
  keywords: [route count, 19 routes, nav.dart, FFRoute, architecture docs, snapshot count, doc drift, 03-navigation, module map]
  provenance: code-verified
  slug: architecture-docs-state-19-routes-while-nav-registers-37
  phase: 3
  tags: [docs, drift, snapshot-count]
  created: 2026-11-21
---

`docs/architecture/03-navigation.md`, `docs/architecture/02-module-map.md` and `docs/architecture/README.md` say "19 routes".
`lib/flutter_flow/nav/nav.dart` holds 37 `FFRoute(` entries at the integration tip.
The count was already wrong before the web sync plan, when the Quiet Room routes landed. Phase 3 added one more (Devices).

A phase-close audit noted this and no task owned it. It is a snapshot member count that rots silently.
Rule: a doc should name the file that holds the list, not repeat how many entries it has. See [[lesson-doc-must-hold-no-bare-counts]].
If a count must stay, add a test or script that reads `nav.dart` and compares.

Locate: `docs/architecture/03-navigation.md` line 4. Verify still present before acting.
Grounding: read at the integration tip `5f9c4abd`, the second parent of the landed merge. No worktree sat at the landed tip itself.
