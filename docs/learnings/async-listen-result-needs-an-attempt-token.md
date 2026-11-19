---
name: async-listen-result-needs-an-attempt-token
description: A speech listen that finishes after Next or Stop must be dropped with an attempt token; the vocabulary drill still lacks one
metadata:
  type: project
  provenance: code-verified
  keywords: [listenOnce, attempt token, stale result, speak drill, quiet_room_practice_widget]
---

The speak drill bumps an int `_attempt` in `_speak` and Stop, drops a result whose attempt is stale,
guards its `finally`, and ignores Next while listening. Without it, a result lands on the wrong
sentence. The vocabulary drill (`quiet_room_practice_widget.dart`) has the same shape and no token.
