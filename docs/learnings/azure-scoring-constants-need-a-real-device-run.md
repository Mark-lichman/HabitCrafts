---
name: azure-scoring-constants-need-a-real-device-run
description: The dBFS thresholds (-40, -50) and the EnableMiscue boolean passed offline tests but were never observed live
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-1
  keywords: [speechDbfs, silenceDbfs, EnableMiscue, auto-stop, backstop]
---

`speechDbfs` is -40 and `silenceDbfs` is -50 in `pronunciation_service.dart`. A noise floor at or above
-50 dBFS stops the auto-stop, so each listen runs the 10 s cap. `EnableMiscue` goes as a JSON boolean.
Neither was seen on a real device. The first real run on phone and web is the check.
