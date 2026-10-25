# Plan: Japanese grammar from Mari's materials into the app

Status: **superseded** by `docs/plans/2026-10-24-japanese-typing-kanji-speaking.md`, 2026-10-24.
Steps 1 to 3 below shipped (`assets/lessons/jp_grammar.json`, the grammar and drill screens). The
five decisions in section 2 are resolved; each one carries its resolution. Read this file as a
record. For the shipped state, read `docs/japanese-lessons.md`.

Original status: for Mark's review, 2026-10-23. Branch `feat/jp-grammar-extraction` (worktree
`C:/Projects/habitcrafts-war`).

## 1. What ran

Five sources went through the OPM path one at a time. I reviewed and refined each one, then re-ran it.
Code: `pipeline/jp/`. Each run writes one JSON per stage to `pipeline/jp/out/<source>/`, which git
ignores.

| # | Source | Shape | Result | Hard checks |
| --- | --- | --- | --- | --- |
| 1 | `number.pdf` (counters, months and dates, lengths of time) | picture of a table, OCR layer | 267 cells, 4 tables | all pass |
| 2 | `し_と_うし__か__.pdf` (Mari, made in Canva) | vector table | 15 verb pairs, 30 examples | all pass |
| 3 | `他動詞_自動詞.png` (textbook 8課) | scanned image, no text | 20 pairs, 6 sentences | all pass |
| 4 | Mari's sheet "N4 Grammar_Markさん": Checklist, particle | Google Sheet | 89 grammar points (lessons 26 to 50), 15 particles, 25 Canva links | all pass |
| 5 | Same sheet: Verb Forms Summary | Google Sheet | 170 worked conjugations | engine agrees on 198 of 198 |

What the review found and fixed in the extractor:

- Source 1: the cell-edge walk stopped at colored glyphs. A header row was split into three cells.
  My own counter rule wrongly doubled 6 before さ (ろっさつ). A row-matching tolerance was too tight.
- Source 2: a fixed header cutoff dropped the first example sentence. The engine missed で in the
  e-row, so でる did not resolve.
- Source 4: the passive example uses よむ, not いく. The particle しか〜ません failed to link to lesson 27.

## 2. Decisions (all resolved)

1. **かえる (名前を かえる)**. The dictionary form cannot decide its group. Here it means 変える
   (to change), which is group 2. Approve group 2, or leave it flagged as uncertain in the app.
   **Resolved:** group 2. `pipeline/jp/corrections.json` sets `s03_pairs_textbook.19`
   `transitive_group` to 2, from the EDICT entry for 変える.
2. **Mari's L42.3 example**: `この しごとに 3にちも かかりました`. 3日 as a length of time reads
   **みっか**. Written as `3にち`, the app teaches さんにち. I suggest `みっかも` and a note to Mari.
   **Resolved:** `みっかも`. `corrections.json` corrects `mari.L42.3` `example`.
3. **number.pdf leaves 11か月 (じゅういっかげつ) unmarked**. It has a sound change, but the cell
   is grey. I suggest marking it orange in the app and keeping the source as it is.
   **Resolved:** marked as a sound change in the app, source unchanged. `corrections.json` sets
   `s01_number.months.〜か月.11` `mark` to `sound_change`.
4. **Kanji in examples.** Source 3 is printed with kanji and furigana. Mari's L33.3 quotes
   「立入禁止」. The app is kana-only today. I suggest kana by default, with the kanji form behind a
   tap. Source 3 already stores both.
   **Resolved:** hiragana by default, kanji behind a tap. The drills show source 3's kanji behind
   a 漢字 tap. Kanji versions of every grammar sentence, behind a 漢字 toggle, are D4 of the
   superseding plan.
5. **Mari's tools that are links, not data.** Her 25 Canva decks need a Canva login. The
   conjugation drill (`wkdonc.github.io/conjugation/drill.html`) is a third-party page. I suggest
   linking both from the app ("Mari's notes, lesson 27") and asking Mari for exports later.
   **Resolved:** not linked. The shipped build carries Mari's checklist data only, because the
   decks need a Canva login. Asking Mari for exports stays outside the app.

No action is needed on two findings. Mari's sheet prints `kimashita` for かいました, and the app
drops romaji anyway. The sheet also has the typo `ふつうFrom`.

## 3. What changed in the OPM

The full text is in `docs/opm-lesson-extraction.md`, section SD3. The new page is in the `.drawio`.
`pipeline/extraction_schemas.py` passes its self-check (23 stages, 8 LM modules).

- **Normalizing splits by source shape.** Only one of the five sources was prose. A picture table
  keeps its cell colors, because the legend (sound change, special reading) is part of the answer.
- **Transcribing** is a new LM stage for images. Its output always goes to review. The Windows OCR
  is a second, independent reading, so the review notes name the exact lines to check.
- **Tutor path.** Mari's checklist is curriculum, so its grammar points are given, not mined.
  Curriculum Importing has Mari as its agent, and no LM touches her content.
- **Conjugation Engine** (`pipeline/jp/conjugate.py`) is plain code, with Mari's 170 rows as its
  gold set. It reproduces every row, plus her four example lists and all 16 hand labels in lesson 30.
- **Cross-source validation.** Sources that cover the same fact must agree. 12 verb pairings
  match between sources 2 and 3. Source 1's readings caught the `3にち` problem in source 4.
- **Answered:** a lesson carries 2 to 6 grammar points, not one. **New question:** levels are now
  `JLPT:N4` style, because CEFR does not grade Japanese.

## 4. App plan (after your review)

Ship the work in four steps. Each step ends with a build on your phone.

### Step 1: publish the data

- Publishing writes `assets/lessons/jp_grammar.json` from the **approved** bundles only.
- It contains grammar points by lesson, particles, reference tables, verb pairs and drill items.
- The existing `jp_lessons.json` stays as it is. Lesson 30's pair fields gain the 30 new pairs.
- Clear lesson 30's two "uncertain" flags with an EDICT lookup. EDICT is the dictionary the app
  already credits.

### Step 2: Grammar screen (Mari's lessons 26 to 50)

- One card per grammar point: pattern, goal, and the example hidden until tapped (recall first,
  like the vocabulary cards).
- A "Mari's notes" link per lesson, to her Canva deck.
- Her three columns (after class, can use it, review needed) become a per-point self-check.
  It is stored on the phone first. Firestore can come later.

### Step 3: drills

| Drill | Prompt | Answer | Source |
| --- | --- | --- | --- |
| Counters | 3 · 本 (pens) | さんぼん, with the sound-change color | 1 |
| Dates and lengths of time | 20日 | はつか | 1 |
| Verb pairs | ドアが ___ (あける / あく) | あきます | 2, 3 |
| Conjugation | たべる → potential | たべられる | engine, 62 verbs |

The conjugation drill uses the 62 verbs whose group is certain. かえる stays out until you decide
item 1. Speaking practice can reuse the existing `SpeechService` for every drill.

### Step 4: install on your phone

- Build the APK from the worktree. Use `C:/src/flutter`.
- Install over wireless debugging. I need the 6-digit pairing code from your phone.
- Check that Auto Blocker is off first, because it turns itself back on.
- A local build cannot use Google Sign-In, so sign in with the email test account.

## 5. How to run it

```sh
cd pipeline/jp
../.venv/Scripts/python s01_counters.py
../.venv/Scripts/python s02_pairs_mari.py
../.venv/Scripts/python s03_pairs_textbook.py
../.venv/Scripts/python s04_mari_checklist.py <exported N4 Grammar .xlsx>
../.venv/Scripts/python s05_mari_verb_forms.py <same .xlsx>
```

Run sources 1 and 2 before 3 and 4, because the later sources cross-check against them.

## 6. If you want WAR to build steps 1 to 3

This file has the four steps WAR needs as phases. Run `/war-strategy` on it, then `/red-team`,
then `/war` (economy preset).
