---
name: speak-play-guard-ends-at-the-4-second-cap
description: The speak drill's Play guard releases when SpeechService.speak times out at 4 s, not when the voice ends
metadata:
  type: project
  provenance: code-verified
  keywords: [SpeechService, speak, timeout, 4 s, Play guard, quiet_room_speak_widget]
---

`quiet_room_speak_widget.dart` clears `_playing` once `_say` returns, but `SpeechService.speak` wraps
the wait in a 4-second timeout. A long sentence can still be playing when Speak enables. It is bounded:
a tail reaches at most Close, which goes to self-check. Whether to lengthen the cap is an operator
question (2026-10-26).
