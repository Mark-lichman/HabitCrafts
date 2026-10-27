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

The repo is public, so no Azure key enters the repo or the app build · no login screen is added (the 2026-10-24 plan's no-login floor, its row D7) · Firebase project `tiny-habits-jf61nl` · the FlutterFlow-managed `firebase/functions` codebase is not edited.

## Resolved design tree

| # | Decision | Resolution | Source | Landing class |
|---|----------|------------|--------|---------------|
| D1 | How a spoken sentence is checked | Azure Pronunciation Assessment: the app sends the audio and the sentence's hiragana as the reference text; spelling never enters the check | (user) 2026-10-27 | PIN-1→guardrail ‡ |
| D2 | Where the Azure key lives | a new Firebase Cloud Function codebase, key in Secret Manager, callable only by a signed-in user | (user) 2026-10-27 | PIN-2→guardrail ‡ |
| D3 | No internet or a function error | self-check (Got it / Missed it), never a wrong mark | (user) 2026-10-27 | PIN-3→guardrail |
| D4 | Pass cutoffs | start at correct ≥ 80 and close 60 to 79, held in named constants; every attempt's scores are kept on the device so the operator tunes the cutoffs from real data | (user) 2026-10-27 "tune it after trying" | PIN-4→slice (T2 constants, T3 score log) |
| D5 | When listening stops | stop after a silence that follows speech, with a hard cap; the constants are named and tested | (user) 2026-10-27 | PIN-5→slice (T2) |
| D6 | Audio format | 16 kHz mono 16-bit PCM WAV, the format Azure's short-audio REST endpoint takes | (verified: 2026-10-27, both fixtures came from 16 kHz mono PCM WAV posted to the short-audio REST endpoint) | PIN-6→slice (T1, T2) |
| D7 | Listening feedback | keep today's drill behavior: the live level animation while listening and the automatic stop when Mark goes quiet; no Stop button is needed | (user) 2026-10-27, after the test page lost both | PIN-7→guardrail ‡ |
| D8 | Showing mistakes | color each hiragana letter of the sentence by its Azure syllable score (red below 60, amber 60 to 79, green 80 and up); Azure's syllables map to the word's morae by index, where a small kana (ゃゅょぁぃぅぇぉゎ and their katakana twins) joins the letter before it and っ, ん and ー each count as one mora; if the counts differ, color the whole word by its word score; an inserted word shows struck through | (user) 2026-10-27 "highlight the mispronounced letters"; (verified: both L26 fixtures, by index only, because Azure returns empty syllable text; no fixture yet has っ, ー or a small kana, so unit tests cover those words and the fallback) | PIN-8→slice (T1, T3) |
| D9 | How the app calls the function with no login screen | a hidden Firebase anonymous sign-in, made only when the drill first needs to score; the app treats an anonymous user as signed out everywhere else; Firestore and Storage rules stop treating an anonymous user as signed in | (user) 2026-10-27 red-team ruling | PIN-9→guardrail ‡ |
| D10 | Which Azure score decides the verdict | `PronScore` (Azure's overall pronunciation score); the mispronounced fixture's 44.8 maps to wrong, the good fixture's 98.6 to correct | (user) 2026-10-27 red-team ruling | PIN-10→slice (T2) |

## Assumptions ledger

| ID | Assumption | Basis | Blast radius if wrong | Check |
|----|-----------|-------|----------------------|-------|
| A1 | Azure Pronunciation Assessment scores ja-JP on the real-time short-audio REST endpoint | (verified: 2026-10-27, resource `habitcrafts-speech` F0 eastus; Mark's own recording scored 98.6 with per-word scores, reply saved as `firebase/speech_functions/fixtures/azure-reply-L26-1-mark.json`) | the whole approach | backstop row 1 |
| A2 | The `record` package captures 16 kHz mono WAV on Android and web | package docs | T2 needs a different recorder or a conversion | Task 2 tests plus backstop row 1 |
| A3 | Short learner sentences get usable scores | none yet | cutoffs need retuning | backstop row 2 |
| A4 | An anonymous user can call an `onCall` function, and the router ignores that user once `loggedIn` excludes anonymous users | Firebase docs | the drill cannot score, or the app jumps to the habit screens | Task 5 tests plus backstop row 1 |

## Non-goals / deferred

Vocabulary drill speaking (it keeps today's checker) · iOS · any paid tier above Azure F0 · removing `speech_to_text` from the app.

## New domain terms · Recommended ADRs

**Pronunciation score**: Azure's 0 to 100 score for how closely the audio matches the reference text. ADR: none.

## Commander's Intent

- **Purpose:** when Mark says a sentence correctly, the drill marks it correct, whatever kanji a recognizer would have written.
- **Method:** record the audio, score it against the hiragana sentence with Azure through a Cloud Function that a hidden anonymous sign-in may call, and map the score to correct, close or wrong. Anything that cannot be scored goes to self-check.
- **Mechanism latitude:** the recorder package, the silence detector, the function's HTTP client, the result card layout, and where on the device the score log lives are implementer's choice; substituting any of these mechanisms while the End states and binding guardrails hold is not a plan deviation and warrants no issue.
- **Binding guardrails:** no Azure key in the repo or the app (PIN-2) · the function rejects a caller with no Firebase sign-in (PIN-2) · an anonymous user stays signed out for every screen and every Firestore or Storage rule (PIN-9) · no network or a failed call goes to self-check, never wrong (PIN-3) · the reference text is the sentence's hiragana (PIN-1) · the drill keeps its live level animation and stops listening by itself when Mark goes quiet (PIN-7) · `firebase/functions` stays untouched.
- **End state:**
  1. The function rejects an unauthenticated call, rejects audio over its size cap, sends the hiragana reference text in the `Pronunciation-Assessment` header, and returns the overall, per-word and per-syllable scores from both recorded Azure replies · check: `node --test firebase/speech_functions` (prints `# fail 0`).
  2. The client maps `PronScore` (PIN-10) of 80 or more to correct, 60 to 79 to close, below 60 to wrong, and a network or function error to unverified; the mispronounced fixture maps to wrong · check: `/c/src/flutter/bin/flutter test test/pronunciation_service_test.dart` (prints `All tests passed!`).
  3. Listening stops by itself after a silence that follows speech, never before speech starts or later than the cap, and the service streams a live sound level while recording (PIN-5, PIN-7) · check: `/c/src/flutter/bin/flutter test test/pronunciation_service_test.dart` (prints `All tests passed!`).
  4. The speaking drill shows the live level animation while listening and needs no Stop tap (PIN-7), shows the score, colors each hiragana letter by its syllable score with a whole-word fallback when the counts differ (PIN-8), sends unverified to self-check, and keeps each attempt's scores on the device · check: `/c/src/flutter/bin/flutter test test/quiet_room_speak_test.dart` (prints `All tests passed!`).
  5. CI runs the function tests · check: `grep -c "node --test firebase/speech_functions" .github/workflows/ci.yml` (prints `1`).
  6. No Azure key is in the new code · check: `git grep -n -I -E "[0-9a-fA-F]{32}|[A-Za-z0-9]{84}" -- firebase/speech_functions lib/components/pages/quiet_room_practice lib/components/pages/quiet_room_grammar | wc -l` (prints `0`).
  7. An anonymous user counts as signed out in the app and in the rules, and the drill signs in anonymously only when it needs to score (PIN-9) · check: `/c/src/flutter/bin/flutter test test/anon_caller_test.dart` (prints `All tests passed!`) and `grep -c "request.auth != null" firebase/firestore.rules firebase/storage.rules` (prints `0` for each file).

## Build order (for /war)

Phase 1 (function, client service and anonymous caller, in parallel) → Phase 2 (drill wiring, then the doc).

## Phase 1 — The scoring function, the client service and the anonymous caller

### Task 1: The scorePronunciation Cloud Function
- Files: `firebase/speech_functions/package.json`, `firebase/speech_functions/index.js`, `firebase/speech_functions/score.js`, `firebase/speech_functions/score.test.js`, `firebase/speech_functions/fixtures/azure-reply-L26-1-mark.json`, `firebase/speech_functions/fixtures/azure-reply-L26-1-mark-mispronounced.json`, `firebase/firebase.json`, `.github/workflows/ci.yml`
- Plan slice: a new functions codebase `speech_functions` (Node 20, its own minimal dependencies), registered in `firebase/firebase.json`. An `onCall` function `scorePronunciation` in us-central1 takes `{ audio: <base64 WAV>, referenceText: <hiragana> }`. It rejects a caller with no auth (PIN-2) and audio over its size cap. It reads the key from Secret Manager (`AZURE_SPEECH_KEY`, a secret) and the region from a plain param (`AZURE_SPEECH_REGION`, not a secret). An anonymous Firebase user counts as authenticated here (PIN-9). It posts the 16 kHz mono WAV (PIN-6) to Azure's short-audio recognition endpoint with `language=ja-JP` and a base64 `Pronunciation-Assessment` header (reference text, HundredMark, miscue on). Request `Granularity: Phoneme`, which also returns syllable scores. It returns overall, accuracy, fluency and completeness scores, plus per word: the word, its score, its error type and its syllable scores in order (PIN-8). Put the pure request and response logic in `score.js` and test it with the committed real Azure reply (`fixtures/azure-reply-L26-1-mark.json` and the deliberate mispronunciation `fixtures/azure-reply-L26-1-mark-mispronounced.json`, Mark's voice, 2026-10-27) and a stubbed HTTP client. Add a CI step that runs `node --test firebase/speech_functions`.
- Done when: `node --test firebase/speech_functions`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 2: The client pronunciation service
- Files: `lib/components/pages/quiet_room_practice/pronunciation_service.dart`, `pubspec.yaml`, `test/pronunciation_service_test.dart`
- Plan slice: `PronunciationService.check(hiragana)` records 16 kHz mono WAV (PIN-6), stops by itself on silence after speech or at the cap (PIN-5), streams the live sound level for the drill's animation (PIN-7), calls `scorePronunciation`, and maps `PronScore` (PIN-10) with named cutoff constants (80 and 60, PIN-4). `check` returns a `PronunciationResult` holding the verdict, the overall, accuracy, fluency and completeness scores, and per word the word, its score, its error type and its syllable scores, so Task 3 can color letters (PIN-8). Put the mora splitter and the syllable-to-letter mapping here, tested on the two fixtures, on words with っ, ー and a small kana, and on the whole-word fallback. A network error, a function error or empty audio returns unverified (PIN-3). Expose the recorder, the clock, the caller sign-in and the function call as injectable seams so tests need no microphone or network.
- Done when: `/c/src/flutter/bin/flutter test test/pronunciation_service_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

### Task 5: The anonymous caller, invisible to the rest of the app
- Files: `lib/components/pages/quiet_room_practice/anon_caller.dart`, `lib/auth/firebase_auth/firebase_user_provider.dart`, `firebase/firestore.rules`, `firebase/storage.rules`, `test/anon_caller_test.dart`
- Plan slice: `ensureCaller()` returns at once when any Firebase user exists, else signs in anonymously (PIN-9). `loggedIn` in `firebase_user_provider.dart` is false for an anonymous user, so the router and every screen treat that user as signed out. Bring `firebase/firestore.rules` up to the ruleset now live (ruleset `fd1383f9`, from branch `fix/account-deletion-and-read-rules`) and `firebase/storage.rules` up to the live ruleset `d3a07e98`. In both, replace every `request.auth != null` with a helper that also requires `request.auth.token.firebase.sign_in_provider != 'anonymous'`. Deploying the rules is an operator step. Test `ensureCaller()` with a fake auth, and `loggedIn` for an anonymous user.
- Done when: `/c/src/flutter/bin/flutter test test/anon_caller_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: []
- target repo: superproject

## Phase 2 — The drill and the doc

### Task 3: The speaking drill uses the score
- Files: `lib/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart`, `test/quiet_room_speak_test.dart`
- Plan slice: the lesson speaking drill makes sure of a caller with Task 5's `ensureCaller()`, then calls `PronunciationService.check` with the sentence's hiragana. Keep the live level animation while listening, fed from the service's sound level, and keep the automatic stop: Mark never taps Stop (PIN-7). Every result shows the sentence with each hiragana letter colored by its syllable score (PIN-8). Correct shows the score. Close shows amber and the score, then self-check. Wrong shows the score. Unverified goes to self-check (PIN-3). Keep each attempt's sentence, scores and verdict on the device, and show a small "Recent scores" list on the drill so the operator can tune the cutoffs (PIN-4).
- Done when: `/c/src/flutter/bin/flutter test test/quiet_room_speak_test.dart`
- requiresTest: true
- requiresPackaging: false
- deps: [Task 1, Task 2, Task 5]
- target repo: superproject

### Task 4: Lesson doc for the new check
- Files: `docs/japanese-lessons.md`
- Plan slice: the speaking drill row says the check is by sound through Azure, needs internet, signs in anonymously in the background, and falls back to self-check. Point to the cutoff constants in `pronunciation_service.dart` instead of restating 80 and 60. Replace the open-work line for real pronunciation scoring. No bare counts.
- Done when: None — doc only; reviewed at audit.
- requiresTest: false
- requiresPackaging: false
- deps: [Task 3]
- target repo: superproject

## Deferred validations (backstops)

- A real Azure call scores a spoken L26 sentence on the phone and on web through an anonymous caller, and the app still opens on the Japanese home (A1, A2, A4) · why deferred: needs the Azure account, the Firebase pay-as-you-go plan, the secret and a deploy, all operator steps, plus deploying Task 5's rules · runner: Mark and the Lead after the operator setup, before the release build.
- Cutoffs fit real scores (A3) · why deferred: needs about 20 real attempts · runner: Mark reads the Recent scores list after a week and rules the cutoffs.

## Notes / conscious deviations

- Operator setup outside WAR: create the Azure account and a Speech resource on the free F0 tier, switch Firebase to the pay-as-you-go plan, enable the Anonymous sign-in provider, set `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION`, deploy `speech_functions`, and deploy Task 5's Firestore and Storage rules. Mark does the sign-ins and billing.
- The function test runs on the CI's Node, not inside the Flutter gate.
- `lib/backend/algolia/algolia_manager.dart` holds a committed 32-hex Algolia key (red-team 2026-10-27). End state 6 is scoped to the new code so it does not trip on it. The Algolia key is out of scope here and is tracked separately.
- Red-team 2026-10-27 rulings are pins PIN-9 (anonymous caller) and PIN-10 (`PronScore` decides).

## Open decisions

None.
