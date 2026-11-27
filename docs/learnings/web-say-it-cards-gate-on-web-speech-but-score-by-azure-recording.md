---
name: web-say-it-cards-gate-on-web-speech-but-score-by-azure-recording
description: Web say-it cards now gate on a recording probe, not Web Speech, because Azure scores the audio
metadata:
  type: project
  keywords: [say-it, Web Speech, SpeechRecognition, Firefox, type-only, Azure scoring, record package, getUserMedia, MediaRecorder, AudioWorklet, recordingSupport, noRecorder, browserRecordingSupport, operator ruling]
  provenance: code-verified
  slug: web-say-it-cards-gate-on-web-speech-but-score-by-azure-recording
  phase: 4
  tags: [speech, web, plan-fork, resolved, operator-ruling]
  created: 2026-11-21
---

Resolved in phase 4 by operator ruling of 2026-11-21. This note keeps the reason and the leftovers.

Task 9 first gated the web say-it cards on a Web Speech probe (`SpeechRecognition` plus `available()` for `ja-JP`).
Firefox has no recognizer, so it got type-only cards.
But the say cards score through `lib/components/pages/quiet_room_practice/pronunciation_service.dart`, which uses `package:record` and Azure.
That path needs a microphone and a recorder, not Web Speech.

The ruling chose option 2: gate the cards on the recording path.
Task seed-1 added `SpeechSupport.noRecorder`, `browserRecordingSupport` and `SpeechService.recordingSupport`.
The probe asks for `navigator.mediaDevices.getUserMedia` and a `MediaRecorder` global. A throw reads as works.
The word card, say card, Say-it sentence and speak drill all read `recordingSupport`.
A Firefox-shaped case (records, no recognizer) keeps the spoken cards and is tested on all four.

Leftovers:
- The Web Speech probe (`speechSupport`, `checkSpeechSupport`) stays by ruling, but no screen reads it. The Practice screen calls `listenOnce`, which only downgrades it on a recognizer error. Docs that say the probe stays "for the Practice screen" can mislead.
- `MediaRecorder` is the ruling's proxy for "can record". `pubspec.lock` pins `record_web` 2.1.3, whose `pcm16bits` stream uses `getUserMedia` plus an `AudioWorklet`, not `MediaRecorder`. A browser with `MediaRecorder` and no `AudioWorklet` would read works, then fail unscored. No Flutter-web browser is known to read wrong.
- Rule: a feature gate must probe the dependency the path uses. Name any proxy in a comment.

Verify still present before acting: `browserRecordingSupport` in `lib/components/pages/quiet_room_practice/speech_support_web.dart` and `recordingSupport` in `lib/components/pages/quiet_room_practice/speech_service.dart` @ phase 4 landed tip dcd890e.
The `AudioWorklet` fact comes from an audit read of `pubspec.lock` and was not re-read here.
Grounding: read in the refinery worktree whose HEAD was the landed tip.
Related: [[web-sign-out-and-phone-account-switch-edges-await-an-operator-decision]].
