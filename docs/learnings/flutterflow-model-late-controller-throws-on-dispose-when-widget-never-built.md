---
name: flutterflow-model-late-controller-throws-on-dispose-when-widget-never-built
description: A generated model with a late controller field throws on dispose if its widget never built
metadata:
  type: project
  keywords: [LateInitializationError, ExpandableController, FlutterFlow model, createModel, dispose, route smoke test, create habit page, generated model]
  provenance: code-verified
  slug: flutterflow-model-late-controller-throws-on-dispose-when-widget-never-built
  phase: 4
  tags: [flutterflow, web, route-smoke-test, recurring-risk]
  created: 2026-11-21
---

A FlutterFlow page model creates child models with `createModel` and disposes all of them.
A child widget sets its `late ExpandableController` field in its own `initState`.
If the page never builds that child, the field stays unset and `dispose` throws `LateInitializationError`.

The Chrome route smoke test in phase 4 (Task 14) hit this on three models.
The create habit page makes one `NewHabitComponentModel` per step but builds only the step it shows.
Task 14 fixed the three models by holding a nullable controller and calling `_expandableController?.dispose()`.
The getter keeps its `!`, so a built widget still reads a set controller.

Ten other generated models at the landed tip still keep `late ExpandableController`, in twelve fields across ten files.
They are the chat thread check-in, group manage list item, goal habit list item, the two habit group list items, lesson category list item, profile page, progress page, profile goal habit list item and resources list item models.
The smoke test passes without touching them.
Any new page that creates one of these models and does not build its widget will throw on dispose.

Rule: when a route test throws `LateInitializationError` in `dispose`, make the field nullable and dispose with `?.`.
Do not count the models in a comment, because the count rots: a Task 14 comment said nine and the page made ten.
Record each hand edit in `docs/architecture/adopted-files.md`.

Verify still present before acting: `lib/components/habit_components/new_habit_component/new_habit_component_model.dart` (nullable `_expandableController`) @ phase 4 tip cc5bd6e.
Grounding: read in the refinery worktree whose HEAD was the landed tip.
Related: [[generated-auth-file-hand-edit-needs-an-adopted-files-row]].
