---
name: scorepronunciation-accepts-any-anonymous-token-with-no-abuse-limit
description: scorePronunciation has no App Check and no per-uid cap; any anonymous token can spend the Azure F0 audio allowance (open operator decision)
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-2
  keywords: [scorePronunciation, App Check, maxInstances, Azure F0, abuse]
---

The `onCall` options in `firebase/speech_functions/index.js` hold only region, secrets, timeoutSeconds and
memory. About 600 clips of 30 s use up Azure F0's monthly audio allowance. The drill then falls back to
self-check (PIN-3), so the failure is safe. The operator has not ruled on a cap yet. See
[[deploy-rules-before-enabling-the-anonymous-provider]].
