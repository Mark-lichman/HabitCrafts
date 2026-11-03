---
name: callable-must-log-the-cause-before-it-throws-httpserror
description: A callable that wraps every failure in HttpsError must log the cause first, or a wrong key leaves no log line
metadata:
  type: project
  provenance: agent-unverified
  promoted: dev/2026-10-27-azure-pronunciation@phase-1
  keywords: [HttpsError, logger, scorePronunciation, index.js, fetch timeout]
---

An audit said firebase-functions logs only errors that are not `HttpsError`. A catch that wraps every
failure then hides a wrong Azure key. `firebase/speech_functions/index.js` now calls `logger.warn` and
`logger.error` before it throws, and aborts the Azure fetch after 20 s. The SDK claim was not checked
against its source.
