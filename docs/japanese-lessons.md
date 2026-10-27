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
lessons and `_points.json`), `uses.json`, `kanji_n5_n4.json`, `corrections.json` and
`jp_lessons.json`.
`jp_grammar.json` holds the catalog and has no entry of its own. `assets/lessons/img/`, the
judge files under `pipeline/jp/review/` and the archived Tanos pages under `pipeline/jp/tanos/`
have no entry.
`pipeline/jp/tests/test_catalog_sources.py` checks every entry's counts against its file, and
fails if this doc restates one.

## The data files

| File | Role | Origin | Produced by |
| --- | --- | --- | --- |
| `assets/lessons/jp_lessons.json` | vocabulary, lesson by lesson; the file states its own missing lessons | Langoal word-list PDFs | an extractor run from a scratchpad (see Regenerating) |
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
| `assets/lessons/img/` | illustrations for the speaking drill | embedded images in the Langoal sheets | the vocabulary extractor |

Each extractor writes `out/<source>/lesson_bundle.json`, which git ignores, and the fixture
directory holds the committed copy. CI and tests read the fixtures through `JP_OUT_DIR`, because
the source files are not in the repo.

## What ships in the app

No login: the app opens on Japanese study when signed out (`nav.dart`). The Japanese study
screens read no Firestore data. Signing in still reaches Today, which does. Self-check marks are
kept on the phone.

| Screen | File | What it does |
| --- | --- | --- |
| Japanese home | `quiet_room_grammar/quiet_room_japanese_widget.dart` | the grammar lesson to continue, search over the catalog, and a By use view |
| Grammar | `quiet_room_grammar/quiet_room_grammar_widget.dart` | Mari's pattern, goal and example, then the drafted lesson: tap-to-choose practice, typed answers on each fill-in item, show-answer, and two self-check marks from Mari's tracking columns (Can use it, Review), kept on the phone. A 漢字 toggle swaps every sentence, option and answer to its kanji version, with the tap-a-word reading hint. "Speak this lesson" opens the grammar speaking drill |
| Grammar speaking drill | `quiet_room_grammar/quiet_room_speak_widget.dart` | one grammar lesson's sentences, every example then every practice item with its answer filled in: play the sentence, speak it once, and see the outcome (below) |
| Drills | `quiet_room_grammar/quiet_room_drills_widget.dart` | number tables (sound-change cells in amber, special readings in blue), verb pairs, conjugation |
| Vocabulary | `quiet_room_lesson/quiet_room_lesson_widget.dart` | recall-first word cards; English hidden until tapped; tap to hear |
| Vocabulary speaking | `quiet_room_practice/quiet_room_practice_widget.dart` | show the illustration, say the word, and see what was heard |

Grammar drafts ship marked as drafts until a person reviews them, and the screen says so.

### Typed answers

Each fill-in item has a text box whose `hintLocales` asks for the Japanese keyboard (ja-JP), so
Gboard opens in Japanese. `checkTypedAnswer()` in `quiet_room_grammar/jp_study_kit.dart` judges
the answer after it drops spacing and punctuation and folds katakana to hiragana:

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

The drill judges each sentence with `SpeechService.judge()`. The expected hiragana is the kanji
version read out, and the kanji version's surface goes in as a kanji form, because Android
recognisers often return a sentence in kanji. An example that joins forms with ／ becomes one
sentence per form. No correct answer is ever marked wrong. The outcomes:

| Outcome | When | What the drill shows |
| --- | --- | --- |
| That's it | the transcript equals the hiragana sentence or its kanji version | a right mark, plus the kanji version when it differs |
| Close | part of the transcript matches | in amber: the heard text with its matching part highlighted, then a self-check ("Got it" or "Missed it") |
| Can't check this one | the transcript cannot be compared (kanji that match no form, digits or Latin letters) | in amber: what was heard, then the same self-check |
| Not quite | the transcript is plain hiragana or katakana and does not match | what was heard and the sentence. `listenOnce` does not return this verdict on a live device, so in practice it shows only under the test fake |
| Didn't catch that | nothing was heard | a prompt to try again or check the microphone permission |

Play speaks the sentence. `SpeechService.speak` waits for the voice to finish, or at most
`SpeechService.speakWait` (3 seconds), before it returns. Play and Speak stay disabled until then,
so the microphone never hears the app's own voice. A longer sentence keeps playing after the cap.
On the web `speak` returns at once. A listen that finishes after the learner pressed Stop, or
Speak again, is dropped instead of shown.

## Script rule: hiragana first

- Japanese words show in **hiragana** by default. **Katakana** is used for foreign loanwords.
- No romaji is kept as a reading (see below). Some vocabulary glosses in `jp_lessons.json` still
  carry a romaji spelling the extractor failed to discard; that is a known data defect.
- Kanji sits behind a tap. On the grammar screen the 漢字 toggle shows every sentence's kanji
  version, with a reading hint on each kanji word (see above). In the drills, a 漢字 tap shows the
  textbook verb pairs as printed.
- A kanji version uses only kanji from `pipeline/jp/kanji_n5_n4.json`. Its readings equal its
  hiragana sentence exactly, with one bracket per kanji word and okurigana outside it.
- One Mari example, `mari.L33.3`, quotes the sign 「立入禁止」 printed in kanji, so it shows the
  sign in kanji in both views. Its kanji version carries the sign's reading, so the reading hint
  and the speaking drill still have hiragana for it.

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
The discard is not complete: some glosses in `jp_lessons.json` still carry the printed romaji (the
known data defect named under Script rule above).

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

`speech_to_text` returns a transcript. A correct transcript means the learner produced something
recognisable. The recogniser will happily normalise a bad pronunciation into the right word. Free
ASR therefore buys **spoken recall practice, not pronunciation assessment.** Do not label it as the
latter in the UI.

This bites harder in Japanese than most languages: **vowel length is phonemic.** `おばさん` /
`おばあさん` and `ここ` / `こうこう` are different words, and the recogniser's language model will pick
the likely one and *hide* the learner's error, which is the feedback they most need.

Phoneme-level scoring means a paid cloud service. Azure Pronunciation Assessment supports `ja-JP`
and returns per-phoneme scores. Speechace and ELSA are the alternatives. ⚠️ Verify current pricing
at the time rather than trusting a remembered figure.

### Kanji transcripts

Android ASR often returns kanji (`貼ります`, or a whole sentence in kanji) while the expected text
is hiragana (`はります`). The phone has no reading dictionary, so the caller hands `judge()` in
`speech_service.dart` the kanji forms to compare with:

- **A vocabulary word:** its kanji spellings from EDICT2.
- **A grammar sentence:** its kanji version, the `_ruby` twin with the readings dropped. That
  covers the kanji of the whole sentence, not only a vocabulary word's forms.

An exact match with the hiragana or a kanji form is `correct`, a partial match is `close`, and a
transcript it cannot compare is `unverified`. The UI shows what was heard and lets the learner
decide. **Being unable to check is not the same as being wrong**, so no correct answer is ever
marked wrong. The grammar drill also sends a `wrong` verdict to self-check unless the transcript
is plain hiragana or katakana.

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
- **Real pronunciation scoring:** the paid tier above.

## Regenerating the vocabulary file

The vocabulary extractor is not committed. It was run from a session scratchpad. If it is worth
keeping, `scripts/` is its home. Behaviour to preserve:

1. Group each page into its Japanese word plus trailing Latin strings.
2. Romanise the word, drop any Latin string that matches it, and keep the remainder as the gloss.
3. Prefer the Langoal sheet when both families cover a lesson.
4. **Exclude a lesson rather than emit a scrambled one.** A stated gap is honest. Wrong
   vocabulary teaches the wrong thing, and nothing later can catch it.
