# Speaking drill: check pronunciation by sound with Azure, not by spelling

**Evidence consumed**
- Jam `41ca939f-5332-492f-8457-0167199655ce` (2026-10-26, web build of `c45b462`) · read: frames at 1.1 s and 8.5 s
- issue #88 (2026-10-26) · read, with the diagnosis comment
- `lib/components/pages/quiet_room_practice/speech_service.dart` `listenOnce()` / `judge()` at `c45b462` · read
- `firebase/firebase.json`, `firebase/functions/package.json` at `c45b462` · read
- Azure pricing sources (Microsoft Q&A 2025-11, 2026 reviews) · read; the paid rate conflicts ($1.00 to $1.32 per hour)

## Context — the gap / problem

The speaking drill marks a correct sentence as Close. For L26 sentence 1, あたまが いたいんです。, Chrome heard 頭が痛いんです, the whole sentence written in kanji (verified: Jam above, frame 8.5 s). 頭 and 痛 are outside the N5/N4 list, so the sentence's kanji twin stays hiragana and `kanjiForms` holds no 頭/痛 spelling (verified: `kanji_n5_n4.json` at `c45b462`). `judge()` has no reading dictionary, so it matches only the hiragana tail いんです (verified: `speech_service.dart` `judge()` at `c45b462`). A speech recognizer always returns written Japanese, never hiragana only (user, operator ruling 2026-10-27: spelling-based fixes are failure prone). The first attempt also heard only 頭が, so the listen ended before the sentence did (verified: Jam frame 1.1 s).

## Pivotal constraints

The repo is public, so no Azure key enters the repo or the app build · no login screen is added (PIN-7 of the 2026-10-24 plan) · Firebase project `tiny-habits-jf61nl` · the FlutterFlow-managed `firebase/functions` codebase is not edited.

## Resolved design tree

| # | Decision | Resolution | Source | Landing class |
|---|----------|------------|--------|---------------|
| D1 | How a spoken sentence is checked | Azure Pronunciation Assessment: the app sends the audio and the sentence's hiragana as the reference text; spelling never enters the check | (user) 2026-10-27 | PIN-1→guardrail ‡ |
| D2 | Where the Azure key lives | a new Firebase Cloud Function codebase, key in Secret Manager, callable only by a signed-in user | (user) 2026-10-27 | PIN-2→guardrail ‡ |
| D3 | No internet or a function error | self-check (Got it / Missed it), never a wrong mark | (user) 2026-10-27 | PIN-3→guardrail |
| D4 | Pass cutoffs | start at correct ≥ 80 and close 60 to 79, held in named constants; every attempt's scores are kept on the device so the operator tunes the cutoffs from real data | (user) 2026-10-27 "tune it after trying" | PIN-4→slice (T2, T3) |
| D5 | When listening stops | stop after a silence that follows speech, with a hard cap; the constants are named and tested | (user) 2026-10-27 | PIN-5→slice (T2) |
| D7 | Listening feedback | keep today's drill behavior: the live level animation while listening and the automatic stop when Mark goes quiet; no Stop button is needed | (user) 2026-10-27, after the test page lost both | PIN-7→guardrail ‡ |
| D6 | Audio format | 16 kHz mono 16-bit PCM WAV, the format Azure's short-audio REST endpoint takes | [assumed: Azure short-audio REST accepts WAV PCM 16 kHz — if wrong: the function converts] | PIN-6→slice (T1, T2) |

## Assumptions ledger

| ID | Assumption | Basis | Blast radius if wrong | Check |
|----|-----------|-------|----------------------|-------|
| A1 | Azure Pronunciation Assessment scores ja-JP on the real-time short-audio REST endpoint | (verified: 2026-10-27, resource `habitcrafts-speech` F0 eastus; Mark's own recording scored 98.6 with per-word scores, reply saved as `firebase/speech_functions/fixtures/azure-reply-L26-1-mark.json`) | the whole approach | backstop row 1 |
| A2 | The `record` package captures 16 kHz mono WAV on Android and web | package docs | T2 needs a different recorder or a conversion | Task 2 tests plus backstop row 1 |
| A3 | Short learner sentences get usable scores | none yet | cutoffs need retuning | backstop row 2 |

## Non-goals / deferred

Vocabulary drill speaking (it keeps today's checker) · iOS · any paid tier above Azure F0 · removing `speech_to_text` from the app.

## New domain terms · Recommended ADRs

**Pronunciation score**: Azure's 0 to 100 score for how closely the audio matches the reference text. ADR: none.

## Commander's Intent

- **Purpose:** when Mark says a sentence correctly, the drill marks it correct, whatever kanji a recognizer would have written.
- **Method:** record the audio, score it against the hiragana sentence with Azure through a signed-in Cloud Function, and map the score to correct, close or wrong. Anything that cannot be scored goes to self-check.
- **Mechanism latitude:** the recorder package, the silence detector, the function's HTTP client, the result card layout, and where on the device the score log lives are implementer's choice; substituting any of these mechanisms while the End states and binding guardrails hold is not a plan deviation and warrants no issue.
- **Binding guardrails:** no Azure key in the repo or the app (PIN-2) · the function rejects a caller with no Firebase sign-in (PIN-2) · no network or a failed call goes to self-check, never wrong (PIN-3) · the reference text is the sentence's hiragana (PIN-1) · the drill keeps its live level animation and stops listening by itself when Mark goes quiet (PIN-7) · `firebase/functions` stays untouched.
- **End state:**
  1. The function rejects an unauthenticated call, rejects audio over its size cap, sends the hiragana reference text in the `Pronunciation-Assessment` header, and returns the overall and per-word scores from a recorded Azure reply · check: `node --test firebase/speech_functions` (prints `# fail 0`).
  2. The client maps a score of 80 or more to correct, 60 to 79 to close, below 60 to wrong, and a network or function error to unverified · check: `/c/src/flutter/bin/flutter test test/pronunciation_service_test.dart` (prints `All tests passed!`).
  3. Listening stops by itself after a silence that follows speech, never before speech starts or later than the cap, and the service streams a live sound level while recording (PIN-5, PIN-7) · check: `/c/src/flutter/bin/flutter test test/pronunciation_service_test.dart` (prints `All tests passed!`).
  4. The speaking drill shows the live level animation while listening and needs no Stop tap (PIN-7), shows the score, highlights low-scoring words on Close and wrong, sends unverified to self-check, and keeps each attempt's scores on the device · check: `/c/src/flutter/bin/flutter test test/quiet_room_speak_test.dart` (prints `All tests passed!`).
  5. CI runs the function tests · check: `grep -c "node --test firebase/speech_functions" .github/workflows/ci.yml` (prints `1`).
  6. No Azure key or region secret is in the tree · check: `git grep -n -I -E "[0-9a-f]{32}" -- firebase/speech_functions lib | wc -l` (prints `0`).

## Build order (for /war)

Phase 1 (function and client service, in parallel) → Phase 2 (drill wiring, then the doc).

## Phase 1 — The scoring function and the client service

### Task 1: The scorePronunciation Cloud Function
- Files: `firebase/speech_functions/package.json`, `firebase/speech_functions/index.js`, `firebase/speech_functions/score.js`, `firebase/speech_functions/score.test.js`, `firebase/speech_functions/fixtures/azure-reply-L26-1-mark.json`, `firebase/firebase.json`, `.github/workflows/ci.yml`
- Plan slice: a new functions codebase `speech_functions` (Node 20, its own minimal dependencies), registered in `firebase/firebase.json`. An `onCall` function `scorePronunciation` in us-central1 takes `{ audio: <base64 WAV>, referenceText: <hiragana> }`. It rejects a caller with no auth (PIN-2) and audio over its size cap. It reads the key from Secret Manager (`AZURE_SPEECH_KEY`) and the region from a param (`AZURE_SPEECH_REGION`). It posts the 16 kHz mono WAV (PIN-6) to Azure's short-audio recognition endpoint with `language=ja-JP` and a base64 `Pronunciation-Assessment` header (reference text, HundredMark, miscue on). It returns overall, accuracy, fluency and completeness scores plus per-word scores and error types. Put the pure request and response logic in `score.js` and test it with the committed real Azure reply (`fixtures/azure-reply-L26-1-mark.json`, Mark's voice, 2026-10-27) and a stubbed HTTP client. Add a CI step that runs `node --test firebase/speech_functions`.
- Done when: `node --test firebase/speech_functions`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 2: The client pronunciation service
- Files: `lib/components/pages/quiet_room_practice/pronunciation_service.dart`, `pubspec.yaml`, `test/pronunciation_service_test.dart`
- Plan slice: `PronunciationService.check(hiragana)` records 16 kHz mono WAV (PIN-6), stops by itself on silence after speech or at the cap (PIN-5), streams the live sound level for the drill's animation (PIN-7), calls `scorePronunciation`, and maps the score with named cutoff constants (80 and 60, PIN-4). A network error, a function error or empty audio returns unverified (PIN-3). Expose the recorder, the clock and the function call as injectable seams so tests need no microphone or network.
- Done when: `/c/src/flutter/bin/flutter test test/pronunciation_service_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 2 — The drill and the doc

### Task 3: The speaking drill uses the score
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart`, `test/quiet_room_speak_test.dart`
- Plan slice: the lesson speaking drill calls `PronunciationService.check` with the sentence's hiragana. Keep the live level animation while listening, fed from the service's sound level, and keep the automatic stop: Mark never taps Stop (PIN-7). Correct shows the score. Close shows amber, the score, and the low-scoring words highlighted, then self-check. Wrong shows the low-scoring words. Unverified goes to self-check (PIN-3). Keep each attempt's sentence, scores and verdict on the device, and show a small "Recent scores" list on the drill so the operator can tune the cutoffs (PIN-4).
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_speak_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 4: Lesson doc for the new check
- Files: `docs/japanese-lessons.md`
- Plan slice: the speaking drill row says the check is by sound through Azure, needs internet and a signed-in user, and falls back to self-check. Replace the open-work line for real pronunciation scoring. No bare counts.
- Done when: None — doc only; reviewed at audit.
- requiresTest: false
- requiresPackaging: false
- deps: [Task 3]
- target repo: superproject

## Deferred validations (backstops)

- A real Azure call scores a spoken L26 sentence on the phone and on web (A1, A2) · why deferred: needs the Azure account, the Firebase pay-as-you-go plan, the secret and a deploy, all operator steps · runner: Mark and the Lead after the operator setup, before the release build.
- Cutoffs fit real scores (A3) · why deferred: needs about 20 real attempts · runner: Mark reads the Recent scores list after a week and rules the cutoffs.

## Notes / conscious deviations

- Operator setup outside WAR: create the Azure account and a Speech resource on the free F0 tier, switch Firebase to the pay-as-you-go plan, set `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION`, and deploy `speech_functions`. Mark does the sign-ins and billing.
- The function test runs on the CI's Node, not inside the Flutter gate.

## Open decisions

None.
