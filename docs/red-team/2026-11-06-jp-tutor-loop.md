# Red Team — 2026-11-06-jp-tutor-loop.md (2026-11-06)
**Verdict:** ADJUDICATED — every blocker and open decision was patched into the plan; four were ruled by the operator (PIN-10 to PIN-13), the rest are Lead patches (D18 to D21 and the task file lists) not re-verified by a probe re-run.
**Rounds:** 1

## Attack surface
Spine: claims-vs-reality, executable-proof, coverage-vs-source (merged arm, the plan is its own source), consistency-placeholders, dependency-feasibility, intent-vs-plan. Bespoke: data-claims (executed), command-diff (executed), decomposition-disjoint, mastery-rule-soundness, azure-feasibility, lesson-link-feasibility (analyzed). Executed in throwaway clones of a clean clone of `C:/Projects/habitcrafts-apk` at `a1da2a6`, provisioned with `flutter pub get`, a venv and `requirements-test.txt`.
Drift-guard spine probes (Lead-run): unguarded-new-mirror vacuous (no inline mirror); default-flip-old-absent vacuous in its strict sense (the mastery rule tightens, but no doc surface restates the old rule's values: Task 10 de-mirrors to `mastery_rule.dart`); guard-split-deps-edge vacuous (the OPM sync guard rides in Task 10 with the docs it guards); touched-doc-fact-coverage pass (Task 10 de-mirrors counts and constants to the data files and `mastery_rule.dart`).
Coverage 12 of 12 probes on target, none dropped. Escape guard: exit 0 before and after.
Artifact kind: impl-plan.

## Executed proof
- At base: `pytest pipeline/jp/tests -q` gives `499 passed, 1 skipped`; the named Flutter tests together give `341 tests, All tests passed!`.
- Data at `a1da2a6`: 89 grammar points with 4 practice rows and 2 examples each; 15 particles with one cloze each; 7 particles with an empty `taught_in`; templates per kind as the plan's table states; `kTransferProbes` has no particle entry; the session picks `probes[answered % probes.length]`.
- `PronunciationService.check` takes any hiragana as the reference text and `score.js` accepts 1 to 200 characters, so short targets are accepted at the API level.

## Findings
### Major (all patched)
- Rotation by `answered % length` never shows the 5th (say) probe in 4 clears, and non-counting attempts shift it → D19 mode-aware next card; test group "next card".
- Template to mode mapping unstated; the new say template collides with `kSayItTemplate` → D18 table; new template name; source never `Source.sayIt`.
- A spoken close (hinted) feeds the two-hinted reset → operator ruling PIN-10: close is neutral.
- Unverified spoken answers fall back to a Got it / Missed it self-mark → Task 5: unverified writes unscored, no self-mark.
- No pronunciation seam in the mastery session → Task 5 plumbs `PronunciationService` (with `ensureCaller`) through `standardProbeBuilder`, `SessionWidget` and `PracticeSessionWidget`.
- Azure allowance (about 600 clips a month on the free tier, no per-user cap) → operator ruling PIN-11: the paid tier; backstop row.
- Short-answer scoring untested on a device → operator ruling PIN-13: required from the start, phone test early in the 3-week window.
- What a say card shows → operator ruling PIN-12: the prompt only.
- The lesson page is an index, not the explanation → D20: a grammar point opens the grammar screen at the point.
- Particles are not rendered on the lesson page and topic page → Task 1 adds a particle block with no example sentence.
- Drills have no pair or row params; routes read no new params → Task 1 adds them and `nav.dart`.
- Task 7 cannot see an item's modes through `ItemDefLike` → Task 7 adds `item_catalog.dart` and the item page.
- End states 6 and 7 passed on a deleted feature → they name new test groups (`--plain-name`, `-k`); End state 11 and 12 added.
- "More than one sentence" in the Purpose had no check → End state 6 covers grammar 3 and particle 2.
### Minor (patched or noted)
- Practice-now cards and the lesson link → D21: both hosts.
- The review downgrade mechanism → Task 2: applied in the host's answer handler, clear only, hint level at least 1.
- `particle_sentences.json` had no catalog entry → Task 8 adds `catalog.py` and its test.
- Task 10's Done-when passed on a no-op → it greps the lesson doc and runs the OPM tests.
- The gate lives in the launch checkout's run config, outside this repo → End state 9 says so.
- Web scope for spoken scoring → backstop row 1 includes the web.
- Issue evidence not readable from the sandbox clone (envGap) → noted.

## Resolutions applied
PIN-10 to PIN-13 (operator) and D18 to D21 (Lead) in the design tree; Tasks 1, 2, 5, 6, 7, 8, 9, 10 file lists and slices; End states 6, 7, 9, 11, 12; backstop rows 1 and 2.

## Adjudications
| Row | Value | Supersedes | Provenance |
|---|---|---|---|
| PIN-10 | a spoken close is neutral for the two-hinted reset | close counted as hinted for the reset | operator-ratified (2026-11-06) |
| PIN-11 | Azure Speech on the paid tier | free tier, unstated | operator-ratified (2026-11-06) |
| PIN-12 | a say card shows the prompt only | unstated | operator-ratified (2026-11-06) |
| PIN-13 | the spoken requirement is on from the start | unstated | operator-ratified (2026-11-06) |
| D18 | template to mode table; a new scored say template | "each template maps to one mode" | AI-declared |
| D19 | mode-aware next card | `answered % length` | AI-declared |
| D20 | grammar point opens the grammar screen at the point | "the lesson page opens scrolled to a point" | AI-declared |
| D21 | Review session and Practice now both carry the link | "every unanswered card" | AI-declared |

## Residual risk
Lead patches D18 to D21 were not re-verified by a probe re-run. Short-answer Azure scoring and the paid tier are backstops on the phone.
