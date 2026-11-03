---
name: speak-play-guard-ends-at-the-speakwait-cap
description: The speak drill's Play guard releases when SpeechService.speak returns at SpeechService.speakWait (3 s), not when the voice ends
metadata:
  type: project
  provenance: code-verified
  keywords: [SpeechService, speakWait, speak, timeout, 3 s, Play guard, quiet_room_speak_widget]
---

`quiet_room_speak_widget.dart` clears `_playing` once `_say` returns, and `SpeechService.speak` wraps
the wait in `SpeechService.speakWait`, a 3-second cap. A sentence longer than the cap keeps playing
after Play and Speak re-enable. It is bounded: a tail reaches at most Close, which goes to self-check.
The cap is the operator's ruling of 2026-10-26 (PIN-15), held in one named constant.
