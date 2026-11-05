# Japanese lessons

What the Japanese study build ships, which data files feed it, and what not to trust about them.
Source files live outside the repo: the PDFs and the scanned image under
`C:/Users/markl/Desktop/Japanese` (Minna no Nihongo course material, Langoal word lists,
`number.pdf`, Mari's Canva table and the textbook page), and Mari's sheet as an exported .xlsx whose
path you pass to `s04` and `s05`.

Companion: `docs/standards.md` says how code here is written. `docs/opm-lesson-extraction.md`
models the pipeline stage by stage. This file says how the lesson data got here.

## Where the counts are

🚨 **This doc restates no count that a data file defines** (PIN-13). Word counts, lesson lists,
missing lessons, grammar point counts and item counts all drift when a file is regenerated, and a
copied number in prose goes stale without failing anything.

The live counts are in the **catalog**: the `catalog` list in `assets/lessons/jp_grammar.json`,
built by `pipeline/jp/catalog.py`. The catalog holds one `source_file` entry per data file, with
its role, its origin (for example "Mari's N4 sheet") and counts computed from the file when the
catalog is built. The app's home search finds each cataloged data file by name, so type a file
name such as `jp_lessons.json` into the search box to see its counts. Tapping a data file's entry
searches for everything that came from that file. The cataloged files are the extraction
bundles under `pipeline/jp/fixtures/`, each draft in `pipeline/jp/drafts/` (the `L<n>.json`
lessons and `_points.json`), `uses.json`, `kanji_n5_n4.json`, `corrections.json`,
`particle_clozes.json` and `jp_lessons.json`.
`jp_grammar.json` holds the catalog and has no entry of its own. `assets/lessons/img/`, the
judge files under `pipeline/jp/review/` and the archived Tanos pages under `pipeline/jp/tanos/`
have no entry.
`pipeline/jp/tests/test_catalog_sources.py` checks every entry's counts against its file, and
fails if this doc restates one.

## The data files

| File | Role | Origin | Produced by |
| --- | --- | --- | --- |
| `assets/lessons/jp_lessons.json` | vocabulary, lesson by lesson; the file states its own missing lessons | Langoal word-list PDFs | an extractor run from a scratchpad (see Regenerating), then `pipeline/jp/vocab_clean.py` |
| `assets/lessons/jp_grammar.json` | grammar lessons, particles, number tables, verb pairs, conjugation drill, and the catalog | everything below, merged | **only** `pipeline/jp/publish.py`, never by hand |
| `pipeline/jp/fixtures/s01_number/` | counters, months, dates and lengths of time | `number.pdf`, a picture of a table with an OCR layer | `s01_counters.py` |
| `pipeline/jp/fixtures/s02_pairs_mari/` | transitive and intransitive verb pairs with examples | Mari's Canva table | `s02_pairs_mari.py` |
| `pipeline/jp/fixtures/s03_pairs_textbook/` | verb pairs and sentences, printed with kanji | textbook 8課, a scanned page | `s03_pairs_textbook.py` (LM Transcribing, then review) |
| `pipeline/jp/fixtures/s04_mari_checklist/` | grammar points and particles, by lesson | Mari's N4 sheet, Checklist and particle tabs | `s04_mari_checklist.py` |
| `pipeline/jp/fixtures/s05_mari_verb_forms/` | worked conjugations, the gold set for `conjugate.py` | Mari's N4 sheet, Verb Forms Summary tab | `s05_mari_verb_forms.py` |
| `pipeline/jp/drafts/L<n>.json` | a short lesson per grammar point: explanation, second example, practice | LM Drafting, checked by `publish.check_draft()` and a judge pass | an LM, then review |
| `pipeline/jp/drafts/_points.json` | the grammar points handed to LM Drafting | Mari's N4 sheet, Checklist tab | the drafting input, kept with the drafts |
| `pipeline/jp/uses.json` | the uses each grammar point serves ("Asking for advice") | LM Use Tagging, kept as reviewable data | an LM, then review |
| `pipeline/jp/kanji_n5_n4.json` | the only kanji a kanji version may use; the file records its source URLs, its archived snapshots and each level's count and its operator additions, each with its reason | the Tanos JLPT N5 and N4 kanji pages, archived byte for byte under `pipeline/jp/tanos/`, plus the operator additions it records | fetched once, then by hand: `test_kanji_list.py` checks the file against the archived pages and every twin against the file |
| `pipeline/jp/corrections.json` | approved sources and reviewed corrections | Mark's review | by hand |
| `pipeline/jp/particle_clozes.json` | a cloze for each particle whose example does not hold it verbatim | hand-written from Mari's particle examples | by hand; `publish.py` blanks the rest itself |
| `assets/lessons/img/` | illustrations for the speaking drill | embedded images in the Langoal sheets | the vocabulary extractor |

Each extractor writes `out/<source>/lesson_bundle.json`, which git ignores, and the fixture
directory holds the committed copy. CI and tests read the fixtures through `JP_OUT_DIR`, because
the source files are not in the repo.

## What ships in the app

No login: the app opens on Japanese study when signed out (`nav.dart`). The Japanese study
screens read no Firestore data. Signing in still reaches Today, which does. Self-check marks and
the study record (see "The study record and the daily review" below) are kept on the phone.

Each word in `jp_lessons.json` carries two fields the app reads beside its reading and gloss:

- **`id`**: the word's image stem (`L30_02`). It is the word's mastery item id, the join key
  between the item catalog, the attempt log and the schedule, so it never changes for the same
  card. Identical duplicate cards keep their own ids and pictures.
- **`context`**: the bracketed or parenthesised part the sheet printed with the reading (`たばこを`
  for `すいます`). The reading holds only the head word, and the vocabulary cards show the context
  after it. A word without context has no such field.

`pipeline/jp/vocab_clean.py` writes both fields.

The grammar speaking drill signs in anonymously in the background, and only when a recording is
ready to score (`ensureCaller()` in `quiet_room_practice/anon_caller.dart`). The scoring function
accepts that caller. Everywhere else an anonymous user counts as signed out: `loggedIn` is false
for it, so the app still opens on Japanese study, and the Firestore and Storage rules refuse it
through their `signedIn()` helper.

| Screen | File | What it does |
| --- | --- | --- |
| Japanese home | `quiet_room_grammar/quiet_room_japanese_widget.dart` | the Today card (the day's review queue and Start or Resume), the grammar lesson to continue, search over the catalog, a By use view, and a quiet Study record link |
| Review session | `quiet_room_mastery/review_page.dart`, `session_widget.dart` | the day's review queue, one item per screen, then the end card (see "The study record and the daily review") |
| Welcome back | `quiet_room_mastery/welcome_back_widget.dart` | after a break: the days away, the items due, New paused, and Start |
| Seed confirmation | `quiet_room_mastery/seed_confirm_widget.dart` | on a first launch: one tick per lesson already studied, then Confirm |
| Study record | `quiet_room_mastery/mastery_debug_widget.dart` | every item under its state with its next due day, the coming days' load, answer times and session lengths; rebuild, export and import |
| Grammar | `quiet_room_grammar/quiet_room_grammar_widget.dart` | Mari's pattern, goal and example, then the drafted lesson: tap-to-choose practice, typed answers on each fill-in item, show-answer, and two self-check marks from Mari's tracking columns (Can use it, Review), kept on the phone. A 漢字 toggle swaps every sentence, option and answer to its kanji version, with the tap-a-word reading hint. "Speak this lesson" opens the grammar speaking drill |
| Grammar speaking drill | `quiet_room_grammar/quiet_room_speak_widget.dart` | one grammar lesson's sentences, point by point, each point's examples then its practice items with the answer filled in: play the sentence, speak it once, and get a score by sound from Azure Pronunciation Assessment. Needs the internet. Signs in anonymously in the background to score. Anything it cannot score falls back to self-check (below) |
| Drills | `quiet_room_grammar/quiet_room_drills_widget.dart` | number tables (sound-change cells in amber, special readings in blue), verb pairs, conjugation |
| Vocabulary | `quiet_room_lesson/quiet_room_lesson_widget.dart` | recall-first word cards, each word with its context; English hidden until tapped, then Knew it or Not yet; tap to hear |
| Vocabulary speaking | `quiet_room_practice/quiet_room_practice_widget.dart` | show the illustration, say the word, and see what was heard |

Grammar drafts ship marked as drafts until a person reviews them, and the screen says so.

### Typed answers

Each fill-in item has a text box whose `hintLocales` asks for the Japanese keyboard (ja-JP).
No test can tell whether Gboard opens in Japanese. Only a phone shows that.
`checkTypedAnswer()` in `quiet_room_grammar/jp_study_kit.dart` judges the answer after it drops
spacing and punctuation and folds katakana to hiragana:

- **Correct** when it equals the answer, any accepted form, or the kanji version of either.
- **Not quite** only when it is plain hiragana or katakana, which can be compared letter for
  letter.
- **Self-check** for anything else (another kanji spelling, romaji from a keyboard left in
  English): the screen shows the answer and asks "Got it" or "Missed it". The phone has no
  reading dictionary, so it cannot call that spelling wrong.

### The 漢字 toggle and the reading hint

Hiragana is the default. The 漢字 toggle on the grammar screen swaps every sentence, option and
answer to the surface of its kanji version (the `_ruby` twin with its readings dropped). In kanji
view each kanji word of an example or a prompt shows in the hint color (`rubyHintInk()`, the
Quiet Room `brand600` token, readable in Daylight and Nightfall) with a dotted underline, so color
is not the only sign that it can be tapped. A tap shows that word's hiragana reading above it, and
a second tap hides it. A word with no kanji keeps the normal text color and ignores taps. The
widget is `RubyTapText` in `jp_study_kit.dart`. Hiragana view has no hint color and no taps.

### The grammar speaking drill

The drill checks each sentence **by sound, not by spelling**. Whatever kanji a recogniser would
have written does not matter. `PronunciationService.check()` in
`quiet_room_practice/pronunciation_service.dart` records the learner and sends the recording, with
the sentence's hiragana as the reference text, to Azure Pronunciation Assessment through the
`scorePronunciation` Cloud Function in `firebase/speech_functions/`. The hiragana is the kanji
version's reading, so an example the lesson prints in kanji still has a hiragana reference. An
example that joins forms with ／ becomes one sentence per form.

- **Needs the internet.** With no connection, or a failed sign-in or call, the attempt cannot be
  scored and goes to self-check.
- **Signs in anonymously in the background** when a recording is ready to score, because the
  function rejects a caller with no Firebase sign-in (see above). The Azure key lives only in the
  function's secret, never in the app.
- **Stops listening by itself.** The live level animation follows the microphone, and the listen
  ends after a silence that follows speech, or at a cap. The timings are
  `PronunciationService.silenceAfterSpeech` and `PronunciationService.listenCap`. Stop stays as a
  way out of a false start, and its attempt is dropped instead of shown.
- **One check at a time.** Speak and Next wait until a check returns, so two checks never share
  the microphone.

Azure's `PronScore` decides the outcome. The cutoffs are `PronunciationService.correctCutoff` and
`PronunciationService.closeCutoff`. They are first guesses, to be tuned from real scores:

| Outcome | When | What the drill shows |
| --- | --- | --- |
| That's it | `PronScore` at or above `correctCutoff` | a right mark and the score, plus the kanji version when it differs |
| Close | `PronScore` at or above `closeCutoff` and below `correctCutoff` | the score in amber, then a self-check ("Got it" or "Missed it") |
| Not quite | `PronScore` below `closeCutoff` | the score, and a prompt to play the sentence and try again |
| Can't check this one | nothing could be scored: no microphone, no speech, no network, a failed sign-in or call | in amber: a note that scoring needs the internet and a microphone, then the same self-check |

Only a real Azure score can say Not quite. **Being unable to score is not the same as being
wrong.**

Every scored attempt shows the sentence with each hiragana letter colored by its syllable score.
When Azure's words do not line up with the sentence letter for letter, the drill colors the scored
words instead, so no scored letter is left uncolored. Words Azure heard that the sentence lacks
show struck through.

Each attempt's sentence, scores and verdict are kept on the device (`SpeakScoreLog`, under the
`shared_preferences` key `jp.speak.scores`). The newest show under **Recent scores** at the foot of
the drill, so the cutoffs can be tuned against real attempts.

Play speaks the sentence. `SpeechService.speak` waits for the voice to finish, or at most
`SpeechService.speakWait`, before it returns. Play and Speak stay disabled until then, so the
microphone does not hear the app's own voice during a sentence that ends inside the cap. A longer
sentence keeps playing after the cap. On the web `speak` returns at once.

## The study record and the daily review

The app tracks the idea, not the lesson. Every grammar point, particle, word, conjugation idea,
verb pair and table row is a **mastery item** with its own record, and a lesson's numbers are
counts over its items. An item's state comes from its own answers only, never from its lesson
number.

🚨 **This section restates no number that the code or the lesson files define.** Each rule below
names the constant that holds its number, and each constant lives in exactly one Dart file under
`lib/components/pages/quiet_room_mastery/`. Change the constant, not this doc. The counts (items
per state, items due, the coming days' load, answer times, session lengths) are on the **Study
record** page, `mastery_debug_widget.dart`, reached from the quiet Study record link at the foot
of the Japanese home. That page computes them from the store each time it opens.

### Items and the record

`item_catalog.dart` builds the catalog of items from the two lesson files once per app run.
Each item has a stable id, the join key between the catalog, the attempt log and the schedule: a
word's id is its `id` field (the image stem), and the header of `item_catalog.dart` lists the id
shape of every kind. Each item has one or more **probes**, the question templates that can ask
it. A grammar point's example sentences are the Say-it track: they can be practised, but they
never count toward mastery.

The record is an append-only log of attempts and seed events, and it is the source of truth.
The schedule and the mastery state are caches that `JpStore.rebuild` replays from the log
(`jp_store.dart`). On the phone the store is SQLite (`jp_store_sqlite.dart`). On the web it is
in memory (`jp_store_memory.dart`) and keeps nothing between loads. The Study record page
exports the log as JSON Lines and imports it back (`study_export.dart`). An export is a backup
and the input for fitting the scheduler offline.

A study day runs from `kDayStartHour` to `kDayStartHour` local time (`local_day.dart`), so a late
session after midnight still belongs to the evening it started in. The store, the daily plan and
the day dots all use the one `localDay` function.

### The grades

Every answer gets one grade, and the grades are the same on every screen (`Grade` in
`attempt.dart`, whose header holds the full table):

| Grade | When | Counts toward mastery |
| --- | --- | --- |
| clear | right with no hint and nothing revealed, or Got it (Knew it) after the reveal on a probe with no machine check | yes |
| hinted | right after a hint short of the answer, a second try, or a speech "close" | **never** |
| wrong | wrong, Missed it (Not yet), a hint that reveals the answer, or a reveal on a machine-checked probe | resets the count |
| unscored | nothing heard, an error, a cancel | no, and never wrong |
| self | the learner overrides a check that could not score (Got it on unverified) | no |

🚨 **A hinted answer earns zero credit toward mastery**, on every screen. Hints stay available.

A conjugation, a verb pair, a table cell and a word card have no machine check. The learner
thinks of the answer, reveals it and grades it: Got it is clear and Missed it is wrong.

**Early practice** is an answer on an item that is not due, from a word card, a drill or the
grammar screen. It is recorded, but a clear, a hinted or a self answer changes neither the
schedule nor mastery. A wrong counts: the item is due tomorrow and its count resets.

### The mastery rule

Each item shows its state: **New**, **Learning** with its count ("n of
`kClearsToMaster`"), **Mastered** or **Shaky**. `masteryAfter` in `mastery_rule.dart` computes
the state as a pure fold over the item's own attempts. The file's header states the rule in
full. In outline, an item is Mastered when all of these hold:

1. `kClearsToMaster` clear answers on as many different local days, each given while the item was
   due.
2. The clear that completes the rule comes at least `kFinalGapDays` after the previous scored
   review.
3. No wrong since the first of them. `kHintedInARowReset` hinted answers in a row reset the count.
4. Where the item has more than one template, `kTemplatesNeeded` different templates, with a
   production clear where the item has a production probe. An item with one template needs only
   the spaced clears.
5. Transfer per kind (`kTransferProbes`): different sentences, verbs, directions or cells, capped
   at the probes the item has.

A wrong, or `kHintedInARowReset` hinted in a row, on a Mastered item makes it Shaky.
`kRegainClears` clears on different days, the last at least `kRegainGapDays` after the first,
win it back. A Mastered item never leaves the queue: it keeps a due date forever.

### The scheduler

The schedule is FSRS-6, vendored into `fsrs.dart` with its MIT notice and with learning steps
removed. Its parameters, its desired retention (`fsrsDesiredRetention`) and its interval cap
(`fsrsMaximumInterval`) are constants in that file. Clear is Good, hinted and self are Hard,
wrong is Again, and unscored logs nothing. `Scheduler.nextDue` (`scheduler.dart`) spreads each
due day over the load of every other item, within `loadSpreadFraction` of the interval. The
time-aware Leitner in `leitner.dart` shares the same `Scheduler` interface as a fallback.

### The daily plan and its budget

`buildPlan` in `plan_builder.dart` builds one local day's plan, and the file's header describes
every section. The session shows the sections in this order:

- **Warm-up**, after a break only (see Relaunch).
- **Repair**: yesterday's wrongs. A wrong today comes back about `kRepairReaskSeconds` later in
  the same session, and again tomorrow.
- **Due**: items whose day has come, the least likely recalled first, then seeded items in seed
  order.
- **Keep-sharp**: in the first session of each week, the `kKeepSharpCount` Mastered items most at
  risk that are not already due.
- **New**: `kNewPerDay` items a day in lesson order, prerequisites first.

The budget is a target and a ceiling, `kTargetSeconds` and `kCeilingSeconds`, priced with the
per-kind answer estimates in `kCostSeconds`. The Study record page shows the measured median
answer time per kind, which is how the estimates get retuned by hand. New is skipped when the
backlog before the session is above the **gate** (`kGateFactor` times the target), after a break,
or when the target is already spent.

The **Review session** (`session_widget.dart`) walks the plan one item per screen under a line
such as "Due · n of m". It writes each answer at once and shows its verdict: Clear with the new
interval, Right with a hint and no credit, Not this time, or Mastered. At the target the **soft
stop** offers Stop and Keep going. The session never runs past the ceiling: what is left stays
due and the next plan picks it up. A relaunch resumes where the session stopped, with its budget
carried on.

The end card shows the day's counts, the items mastered today and the day dots, then the
opt-in offers, none of which runs on its own:

- **One more** (`kOneMoreBlock` more, in `session_widget.dart`): only while the next item fits
  inside the ceiling.
- **Catch up** (`kCatchUpBlock` more): past the ceiling, only when the session reached the ceiling
  with the backlog still above the gate, as in the first seeded weeks or after a break.
- **The stretch** (`kStretchNew` more new items): only when repairs and due items are done, the
  backlog before the session was under the gate, no day was missed, and the ceiling leaves room.
  The stretch is never forced.

### The first-launch seed

On a first launch the **seed confirmation** (`seed_confirm_widget.dart`) asks which lessons are
already studied: one tick per lesson, word lessons and grammar lessons apart. The default ticks
run from `kSeedFirstWordLesson` to `kSeedLastWordLesson` for words and from
`kSeedFirstGrammarLesson` to `kSeedLastGrammarLesson` for grammar (`seed.dart`). Any lesson can
be unticked to skip it for now: its items stay New and arrive through the daily intake.

`seedFromLessons` gives every word and grammar point of the ticked lessons, and every particle,
conjugation idea, verb pair and table row, a due day spread over `kSeedSpreadDays` days in lesson
order.

🚨 **A seed is not an answer.** Each seeded item gets one seed event: an item id and a due day.
The seed writes no attempt, no schedule and no clear, so no seeded item is Mastered until it
earns the full rule from real answers. The first real answer on it is review one and clear one.

The seed also imports the earlier study keys once (`migrateV2Keys` in `study_export.dart`): a
grammar point marked Review is due today, and a grammar speaking score becomes a Say-it attempt.

### Relaunch

`onLaunch` in `relaunch.dart` decides what the app opens on before the first screen draws. The
break threshold, `kReturnModeDaysMissed`, and the return-plan constants live in
`plan_builder.dart`.

| Decision | When | Opens on |
| --- | --- | --- |
| firstLaunch | the seed has never run | the seed confirmation, then today's plan |
| resume | today has a plan and its session is not finished | the Today card with Resume |
| done | today's session is finished | the Today card with the end state |
| today | the last session was yesterday, or fewer than `kReturnModeDaysMissed` days were missed | today's plan on the Today card |
| welcomeBack | `kReturnModeDaysMissed` or more days were missed | the Welcome back screen with the return plan |

The **return plan** pauses New, opens with a warm-up of items still likely recalled
(`kWarmUpMin` to `kWarmUpMax` items between `kWarmUpLowR` and `kWarmUpHighR` retrievability), and
caps the items least likely recalled at a share of the plan (`kLowRetrievability`,
`kLowRCapDivisor`). Keep-sharp waits until the backlog is under the gate.

🚨 **Nothing at relaunch resets an item.** `onLaunch` writes only today's day record. A break
changes what the plan shows first, never an item's schedule or mastery.

## Script rule: hiragana first

- Japanese words show in **hiragana** by default. **Katakana** is used for foreign loanwords.
- No romaji is kept as a reading (see below). The printed romaji the extractor failed to discard
  from some vocabulary glosses is dropped by `pipeline/jp/vocab_clean.py`.
- Kanji sits behind a tap. On the grammar screen the 漢字 toggle shows every sentence's kanji
  version, with a reading hint on each kanji word (see above). In the drills, a 漢字 tap shows the
  textbook verb pairs as printed.
- A kanji version uses only kanji from `pipeline/jp/kanji_n5_n4.json`. Its readings equal its
  hiragana sentence exactly, with one bracket per kanji word and okurigana outside it.
- No hiragana sentence holds a kanji. Mari's one kanji example, the sign in `mari.L33.3`, is
  written in hiragana by a reviewed correction in `pipeline/jp/corrections.json`.

## How the grammar file is built

```sh
cd pipeline/jp
../.venv/Scripts/python s01_counters.py
../.venv/Scripts/python s02_pairs_mari.py
../.venv/Scripts/python s03_pairs_textbook.py
../.venv/Scripts/python s04_mari_checklist.py <exported N4 Grammar .xlsx>
../.venv/Scripts/python s05_mari_verb_forms.py <same .xlsx>
# copy each fresh bundle into fixtures/; it refuses, copying nothing, if a bundle is missing
# or blocked. CI publishes from fixtures/ and fails on drift
../.venv/Scripts/python refresh_fixtures.py
../.venv/Scripts/python publish.py
```

Run sources 1 and 2 before 3 and 4, because the later sources cross-check against them.
`publish.py` runs Cataloging first, so the app's search and sort read the catalog the pipeline
checked. It publishes only the sources `corrections.json` approves. A correction whose `from` no
longer matches fails the publish, so a correction never lands on the wrong cell.

CI runs `pipeline/jp/tests`: the conjugation engine against Mari's worked forms, the draft
validator, the catalog, publishing with the reviewed corrections, and a drift check. CI fails when
the committed `jp_grammar.json` differs from a fresh publish.

Separately, an independent LM judge reviewed every drafted item once. Its findings are in
`pipeline/jp/review/judge_L*.json`, and `apply_judge_fixes.py` applied them. No CI test covers that
draft judge pass. A later judge pass checked the kanji twins. Its findings are in
`pipeline/jp/review/judge_ruby.json`, and `test_judge_applied.py` fails if any finding is not
marked `applied` or its fix is not in the draft, and if a `dismissed` entry has no `why` or the
draft no longer holds the text the judge saw. Mark's rulings of 2026-10-26 made the kanji list
strict, wrote the pronoun わたし as 私{わたし}, and wrote わかる as 分{わ}かる with 分 recorded as an
operator addition: `review/apply_kanji_rulings.py` applied them and
logged each change in `judge_ruby.json`, and `test_kanji_list.py` fails if a twin uses a kanji
outside `pipeline/jp/kanji_n5_n4.json`.

## The vocabulary corpus is two families and they need different parsers

Characters per page separates them, which is the cheapest reliable signal.

| Family | Shape | Reading order |
| --- | --- | --- |
| `L<n>-roma.pdf` (Langoal) | dense grid | **sound** |
| `_みん日_第N課.pdf` (Minna) | slide deck, one card per page | **unreliable** |
| outliers | a phrasebook with no kanji, `Verb_Group.pdf`, `TRIAL.pdf` | per file |

Only the Langoal family is extracted. Page count lies about size in the Minna decks: a long deck
can hold several thousand characters.

### 🚨 The failure mode is silent, fluent and wrong

One Minna page holds two verbs sharing a `(を)する` suffix. The text stream reads:

```text
(を) する · suru · でんわ · しゅうり · denwa · shūri · (o) · repair · call
```

Zip that in order and you get **でんわ = repair**. It is backwards, it reads perfectly, and nothing
downstream can detect it. The glyph **y-positions** say `でんわ → call` and `しゅうり → repair`.
Recovering it needs geometry, not a stream.

Two rules follow:

- **Use PyMuPDF (`fitz`), never `pdftotext`.** `pdftotext` drops every hiragana and katakana
  character in this corpus and strips macrons, turning `sōdanshimasu` into `sdanshimasu`. Vowel
  length is phonemic, so that is data loss rather than cosmetics.
- **Hand-rolled geometry is not automatically safer.** A first attempt with too loose an
  x-tolerance gave かけます the romaji `harimasu`, an off-by-one that also looked fine.

**Exclude a lesson rather than emit a scrambled one.** That is why `jp_lessons.json` lists missing
lessons and the vocabulary screen states the gap. Recovering them needs the slide-deck table
extractor, the same piece of work that would unlock grammar for the early lessons.

### Why there is no romaji

The sheets print the hiragana or katakana word, its romaji and a gloss **with no labels**, so
position does not tell you which Latin string is which. The extractor romanises the word itself
and uses that *only* to identify and discard the printed romaji. Whatever is left is the gloss.
The discard was not complete, so `pipeline/jp/vocab_clean.py` drops a gloss's leading token when
it is the item's own reading in Hepburn romaji. The match is strict, so an English first meaning
(`watch, clock`) stays.

That also disposes of the sheets' own defects, since their spelling is never kept:

| Sheet prints | Should be | |
| --- | --- | --- |
| `mīthingu` (ミーティング) | `mītingu` | ティ is *ti*, not *thi* |
| `yotē` (よてい) | `yotei` | the same file uses macrons for おう but not えい |

### Derived fields

The sheet never states these, and they make the list usable:

- **Verb group I / II / III.** Everything downstream depends on it. A verb whose ます form alone
  cannot decide its group (`しまいます`, `ふくしゅうします`) is flagged `groupUncertain`, and the UI
  badges it `I?` / `III?` rather than guessing.
- **Transitive / intransitive pairs.** Confusing the pair is the classic error at this level.

These were worked out by hand and do not yet cover every lesson. Deriving the rest is open work.

## Speaking practice

### 🚨 ASR tells you WHAT was said, not HOW WELL

This section is about the vocabulary speaking screen, which still listens with `speech_to_text`.
The grammar speaking drill scores by sound through Azure instead (see above).

`speech_to_text` returns a transcript. A correct transcript means the learner produced something
recognisable. The recogniser will happily normalise a bad pronunciation into the right word. Free
ASR therefore buys **spoken recall practice, not pronunciation assessment.** Do not label it as the
latter in the UI.

This bites harder in Japanese than most languages: **vowel length is phonemic.** `おばさん` /
`おばあさん` and `ここ` / `こうこう` are different words, and the recogniser's language model will pick
the likely one and *hide* the learner's error, which is the feedback they most need.

Scoring how well something was said needs a pronunciation service. The grammar speaking drill uses
Azure Pronunciation Assessment, which supports `ja-JP` and returns overall, per-word and
per-syllable scores. Speechace and ELSA are the alternatives. ⚠️ Verify current pricing at the time
rather than trusting a remembered figure.

### Kanji transcripts

Android ASR often returns kanji (`貼ります`, or a whole sentence in kanji) while the expected text
is hiragana (`はります`). The phone has no reading dictionary, so the vocabulary speaking screen
hands `judge()` in `speech_service.dart` a word's kanji spellings from EDICT2 to compare with. The
grammar speaking drill no longer goes through `judge()`: Azure scores the sound against the
hiragana, so a kanji transcript never arises there.

`judge()` runs both sides through `normalise()` first, so spacing and 。 in a kanji version do not
turn an exact match into a partial one.

An exact match with the hiragana or a kanji form is `correct`, a partial match is `close`, and a
transcript it cannot compare is `unverified`. The UI shows what was heard and lets the learner
decide. **Being unable to check is not the same as being wrong**, so no correct answer is ever
marked wrong.

### 🚨 flutter_tts: bind a VOICE, not a language

`flutter_tts`'s web `_setLanguage` is:

```dart
void _setLanguage(String language) {
  var targetList = synth.getVoices().toDart.where((e) => e.lang.startsWith(language));
  if (targetList.isNotEmpty) {        // silently does nothing when empty
    utterance.voice = targetList.first;
  }
}
```

Browsers fill `getVoices()` **asynchronously**, so calling `setLanguage` during init finds an empty
list, binds no voice, and the utterance keeps the default English one. Chrome is then handed
Japanese text to read with Microsoft David and produces **silence with no error anywhere**.

Fix: wait for the voice list (retry), find a `ja` locale, and call **`setVoice({name, locale})`**.

Second, latent: do **not** `stop()` immediately before `speak()`. `_stop()` calls `synth.cancel()`
whose state change arrives on a later event, and `_speak` refuses to run unless the state is
*already* stopped, so the speak is silently eaten. The first tap works, because the initial state
is stopped. Every tap after it breaks.

**Method that found it, not the guesses that didn't.** Three code changes against hypotheses all
failed. A ten-line static HTML page calling `window.speechSynthesis` directly settled it in one
click: the browser spoke Japanese perfectly, which proved the platform was fine and the fault was
ours. Isolate the layer before editing the code.

On Windows there are two speech registries, `Speech` (SAPI5, what Chrome reads) and
`Speech_OneCore`. A language-pack install often lands voices only in OneCore, where Chrome cannot
see them, so a voice can look installed in Settings and be unusable. Chrome caches the voice list
at startup, so a newly installed voice needs a full browser restart, not a refresh.

### 🚨 speech_to_text reports amplitude on mobile only, so the web needs its own tap

`onSoundLevelChange` comes from the Android and iOS implementations and **never from the web
one**. The Web Speech API has no such callback, so there is nothing to fix in `speech_to_text`.
Chrome is the platform this app is developed on, so a listening animation driven by that callback
is **flat on the only screen it gets iterated against**.

The fix is `lib/components/pages/quiet_room_practice/mic_level_web.dart`: open a second
`getUserMedia` stream, run it through an `AnalyserNode`, and take RMS off the time-domain buffer.
Chrome permits several consumers of one microphone, so it coexists with recognition.

Two decisions worth keeping:

- **RMS, not an FFT,** even though the FFT is free once the analyser exists. Mobile can only ever
  supply one scalar, so a real spectrum on web would make the same widget look different on the
  two platforms. One amplitude number feeds one renderer everywhere.
- **No new dependency.** `package:web` is only a transitive dependency of the Firebase plugins,
  and depending on it directly would be a promise not made (S11), so the four interfaces needed
  are declared with `dart:js_interop` instead. That needs a **Dart 3.3 floor** for extension
  types.

Failure stays honest: if the permission is refused or there is no input device, `start()` returns
false, the level stays 0, and the indicator holds its still state. `cancel()` must tear the tap
down as well as the recogniser, or the browser's recording indicator stays lit after Stop.

### The listening indicator is a visualiser, and the genre lies by default

`listening_bars.dart` is a symmetric bar row, the shape of podcast and voice-recording
visualisers. Those references are **loops**: they animate on a timer over a finished recording,
whether or not anyone is speaking. This one must not, so silence collapses every bar to a flat row
of dots, the same small mark as the dots of the Today day row.

The **amount** of movement is measured amplitude. The **spread across the bars is invented**, from
a fixed per-bar envelope and phase offset, because one scalar is not a spectrum. That is why the
bars may never move while the scalar is zero: the shape is decoration, the presence of motion is a
claim.

🚨 `live` must be **discovered, not declared**. A constructor flag is read once at mount, before
the first level arrives, so it stays false and the indicator never wakes, even on Android. This has
been the bug twice.

## Open work

- **Grammar and vocabulary for the early lessons:** needs the slide-deck table extractor. The
  Minna decks carry grammar tables (`ていねいけい` / `ふつうけい` against affirmative, negative,
  present and past) that defeat linear extraction.
- **Tune the pronunciation cutoffs:** `correctCutoff` and `closeCutoff` are first guesses. Read the
  drill's Recent scores after real attempts and adjust them. The first live Azure call, on the
  phone and on the web, also waits on the operator setup in
  `docs/plans/2026-10-27-azure-pronunciation-check.md` (Deferred validations).
- **Privacy statements for the Azure check:** before the release build, update the privacy policy,
  the store data declarations and the `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` strings in `ios/Runner/Info.plist` to say a recording goes
  to Microsoft Azure Speech through the scoring function. The speech-recognition string still says
  the app does not score how well you said it. `docs/plans/2026-10-27-azure-pronunciation-check.md`
  carries the item under Notes / conscious deviations.
- **Checks that need the phone:** run them after the release install.
  `docs/plans/2026-10-24-japanese-typing-kanji-speaking.md` lists them under Deferred validations.

## Regenerating the vocabulary file

The vocabulary extractor is not committed. It was run from a session scratchpad. If it is worth
keeping, `scripts/` is its home. Behaviour to preserve:

1. Group each page into its Japanese word plus trailing Latin strings.
2. Romanise the word, drop any Latin string that matches it, and keep the remainder as the gloss.
3. Prefer the Langoal sheet when both families cover a lesson.
4. **Exclude a lesson rather than emit a scrambled one.** A stated gap is honest. Wrong
   vocabulary teaches the wrong thing, and nothing later can catch it.
