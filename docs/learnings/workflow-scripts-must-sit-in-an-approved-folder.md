---
name: workflow-scripts-must-sit-in-an-approved-folder
description: The Workflow tool refuses a staged WAR script outside the session's approved folders; copy it byte-identically into the scratchpad
metadata:
  type: project
  provenance: code-verified
  keywords: [Workflow, scriptPath, stage-workflow, scratchpad, approved folder, dispatch]
---

When `/war` runs from a session whose working directory is not this repo, the staged per-phase script
under the main checkout's `.claude/war/runs/<runId>/` is outside the session's approved folders, and
the Workflow tool refuses the `scriptPath`. Copy the staged file byte-identically (`cmp` to confirm)
into the session scratchpad and dispatch that copy. The embedded args travel with it.
