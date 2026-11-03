---
name: drill-signs-in-through-the-service-seam-only-when-it-scores
description: The speak drill passes ensureCaller as PronunciationService's signIn seam, so sign-in runs only after a recording
metadata:
  type: project
  provenance: code-verified
  promoted: dev/2026-10-27-azure-pronunciation@phase-2
  keywords: [ensureCaller, signIn seam, PIN-9, anonymous, quiet_room_speak_widget]
---

The drill passes `ensureCaller` as the service's `signIn` seam. It runs after the recording and before
the call. An earlier sign-in would make an anonymous user for every visitor who never speaks.
