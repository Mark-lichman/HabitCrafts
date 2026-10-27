# Red Team: Speaking drill, check pronunciation by sound with Azure (2026-10-27)
**Verdict:** ADJUDICATED. Every blocker is patched in the plan by an operator ruling or a mechanical fix, and none was re-run by a probe.
**Rounds:** 1

## Attack surface
Spine: claims-vs-reality, executable-proof, coverage-vs-source, consistency-placeholders, dependency-feasibility, intent-vs-plan. Bespoke: mora-syllable-mapping (executed), end-state-commands-at-base (executed), firebase-codebase-feasibility (analyzed). Lead-run: the four drift-guard probes and the backstop check. 9 of 9 probes on target, none dropped. Artifact kind: impl-plan.

## Executed proof
- Fresh clone with `flutter pub get`: End state 6's original grep printed 1 at base. The hit was a committed Algolia key in `lib/backend/algolia/algolia_manager.dart`. After the patch scoped the grep to the new code, it prints 0 at base (Lead re-run).
- Both fixtures: every word's syllable count equals its mora count by index. Azure returns empty syllable text, so the mapping is by position only.
- The mispronounced fixture has AccuracyScore 60 and PronScore 44.8, so the choice of score field changes the verdict.
- Escape guard: exit 0 with the baseline.

## Findings
### Major
- The drill calls a function that needs a signed-in caller, but the app has no login screen. Resolution: PIN-9 (D9), a hidden anonymous sign-in, invisible to the rest of the app, with rules that exclude anonymous users. This is the new Task 5 and End state 7.
- The verdict's score field was not named. Resolution: PIN-10 (D10), `PronScore` decides, and the mispronounced fixture maps to wrong.
- End state 6 was red at base because of the Algolia key, and it missed uppercase hex and 84-character keys. Resolution: scoped to the new code, with both key shapes.
- Task 3 had `deps: []`. Resolution: `deps: [Task 1, Task 2, Task 5]`.
- Task 2's result type was unnamed. Resolution: `PronunciationResult` with per-word and per-syllable data, and the mora mapping lives in Task 2.
- PIN-7 named two things. Resolution: the old no-login floor is cited by its 2026-10-24 row, and PIN-7 means only listening feedback.
### Minor
- D6's assumed tag was replaced by evidence. The D rows are in order. D4's landing tasks are split (T2 constants, T3 score log). The granularity is now `Phoneme`. The region is a plain param, not a secret. The D8 claim is scoped to the fixtures by index, with unit tests for っ, ー and small kana.
- The `record` package on web is a backstop (A2), not proven here.

## Resolutions applied (grill decisions)
- Calling the function with no login screen → a hidden anonymous sign-in, with anonymous users excluded from the rules → D9 / PIN-9, Task 5, End state 7.
- Score that decides the verdict → `PronScore` → D10 / PIN-10, End state 2.

## Adjudications
- 2026-10-27 operator-ratified: the scoring function's caller is a hidden Firebase anonymous sign-in. Firestore and Storage rules treat anonymous users as signed out (PIN-9).
- 2026-10-27 operator-ratified: `PronScore` decides correct, close and wrong (PIN-10).

## Residual risk
- A4: anonymous sign-in must not move the app off the Japanese home. Backstop row 1 covers it.
- The Algolia key in `lib/backend/algolia/algolia_manager.dart` is committed in a public repo. It is out of scope here and tracked separately.
