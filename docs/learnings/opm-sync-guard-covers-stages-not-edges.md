---
name: opm-sync-guard-covers-stages-not-edges
description: test_opm_sync.py checks stage sets, box kinds, OPL sentences and the module registry, but not edges or STAGE_IO inputs
metadata:
  type: project
  provenance: code-verified
  keywords: [test_opm_sync, OPM, STAGE_IO, stages.py, diagram, edges, drift guard]
---

The OPM guard catches a missing stage, box, OPL sentence, kind mismatch or unregistered module. It does
not check diagram edges, `STAGE_IO` inputs, or object names inside OPL text, so those can drift unseen.
Changing a stage's inputs needs four manual updates: `STAGE_IO`, the OPL text, the generator edge, and
`stages.py`. Composite LM stages also inflate the LM count `_check()` reports.
