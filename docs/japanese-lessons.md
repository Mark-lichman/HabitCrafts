# Japanese lessons

How `assets/lessons/jp_lessons.json` is produced, what is deliberately missing from it, and what
the next pass has to solve. Source PDFs live outside the repo at `C:/Users/markl/Desktop/Japanese`
(51 files, Minna no Nihongo course material).

Companion: `docs/standards.md` says how code here is written; this file says how the lesson data
got here and what not to trust about it.

## Current state

| | |
| --- | --- |
| Words | **620** |
| Lessons | **25** — 2 to 17, 22 to 30 |
| Fields | `kana`, `gloss`, plus derived fields on lesson 30 |
| Missing | **1, 18, 19, 20, 21** — stated on screen, not hidden |

Rendered by `lib/components/pages/quiet_room_lesson/`. Cards are recall-first: the English is
hidden until tapped.

## The corpus is two families and they need different parsers

Characters per page separates them, which is the cheapest reliable signal.

| Family | Files | Shape | Reading order |
| --- | --- | --- | --- |
| `L<n>-roma.pdf` (Langoal) | 25 | dense grid, ~300 chars/page | **sound** |
| `_みん日_第N課.pdf` (Minna) | 19 | slide deck, 1 card/page, 20 to 52 chars/page | **unreliable** |
| outliers | 7 | phrasebook (0 kanji), `Verb_Group.pdf`, `TRIAL.pdf` (30pp / 493 chars) | per file |

Only the Langoal family is currently extracted. Page count lies about size in the Minna decks:
`第20課` is 95 pages holding 4,934 characters.

## 🚨 The failure mode is silent, fluent and wrong

Lesson 20 page 4 holds two verbs sharing a `(を)する` suffix. The text stream reads:

```text
(を) する · suru · でんわ · しゅうり · denwa · shūri · (o) · repair · call
```

Zip that in order and you get **でんわ = repair**. It is backwards, it reads perfectly, and nothing
downstream can detect it. The glyph **y-positions** say `でんわ → call` and `しゅうり → repair`.
Recovering it needs geometry, not a stream.

Two rules follow:

- **Use PyMuPDF (`fitz`), never `pdftotext`.** `pdftotext` drops every kana in this corpus and
  strips macrons, turning `sōdanshimasu` into `sdanshimasu`. Vowel length is phonemic, so that is
  data loss rather than cosmetics.
- **Hand-rolled geometry is not automatically safer.** A first attempt with too loose an
  x-tolerance gave かけます the romaji `harimasu`, an off-by-one that also looked fine.

## Why there is no romaji

The sheets print kana, romaji and gloss **with no labels**, so position does not tell you which
Latin string is which. The extractor therefore romanises the kana itself and uses that *only* to
identify and discard the printed romaji; whatever is left is the gloss.

That also disposes of the sheets' own defects, since their spelling is never kept:

| Sheet prints | Should be | |
| --- | --- | --- |
| `mīthingu` (ミーティング) | `mītingu` | ティ is *ti*, not *thi* |
| `yotē` (よてい) | `yotei` | the same file uses macrons for おう but not えい |

A learner reading kana is the point. A crutch spelled three ways across one course is not.

## Derived fields (lesson 30 only, so far)

The sheet never states these, and they are what makes the list usable:

- **Verb group I / II / III** — everything downstream depends on it. 16 verbs carry it.
  Two are flagged `groupUncertain` because the ます form alone genuinely cannot decide them
  (`しまいます`, `ふくしゅうします`); the UI badges those `I?` / `III?` rather than guessing.
- **Transitive / intransitive pairs** — 5 of them. Lesson 30 is a transitive-verb lesson because
  `〜てあります` requires one, and confusing the pair is the classic error at this level.

These were worked out by hand. Deriving them for the other 24 lessons is open work.

## What the next pass has to do

**Grammar lessons**, requested 2026-09-26: the **potential form**, **transitive / intransitive**,
and the rest. Sources already identified in the same folder:

- `Verb_Group.pdf` (16pp) — the I / II / III conjugation reference
- `L1_L13_まとめ.pdf` (8pp, no images, text-dense) — a review sheet
- The Minna decks carry grammar **tables** (`ていねいけい` / `ふつうけい` against affirmative,
  negative, present/future, past)

🚨 Those tables are exactly the pages that defeat linear extraction, so **grammar work requires
solving the geometric/table case first**. It is the same problem as recovering lessons 1, 18, 20
and 21, which means one piece of work unblocks both. Potential form is Minna lesson 27.

## Pronunciation and speaking practice (scoped 2026-09-26, not built)

The ask: show a picture or an English sentence, have the learner **speak** the answer, and offer a
grammar or vocabulary hint on request.

### Already in place, and further along than it looks

- **`RECORD_AUDIO` is already declared** in `android/app/src/main/AndroidManifest.xml`, and
  `NSMicrophoneUsageDescription` is already in `ios/Runner/Info.plist`. The manifest half is done;
  what is missing is the runtime request. There is a pattern to copy in
  `lib/custom_code/actions/request_notification_permission.dart`.
- 🚨 **The pictures already exist.** The Langoal sheets carry **628 embedded illustrations** at
  265×200 against **620 words** — roughly one per word. Picture prompts need *extracting*, by the
  same PyMuPDF pass that produced the vocabulary. They do not need sourcing or generating.
- `audio_session` and `just_audio` are already dependencies.

### What has to be added

| Piece | How | Cost |
| --- | --- | --- |
| Runtime mic permission | `permission_handler` | free |
| Hear the word | `flutter_tts`, `ja-JP` | free, on-device |
| Hear the learner | `speech_to_text` (Android `SpeechRecognizer` / Apple Speech) | free |
| iOS speech | add `NSSpeechRecognitionUsageDescription` — **separate** from the mic string | free |
| Picture prompts | extract the 628 images, pair by position | free |

### 🚨 ASR tells you WHAT was said, not HOW WELL

`speech_to_text` returns a transcript. A correct transcript means the learner produced something
recognisable; the recogniser will happily normalise a bad pronunciation into the right word. Free
ASR therefore buys **spoken recall practice, not pronunciation assessment.** Do not label it as the
latter in the UI.

This bites harder in Japanese than most languages, for the reason this document already records:
**vowel length is phonemic.** `おばさん` / `おばあさん` and `ここ` / `こうこう` are different words,
and the recogniser's language model will pick the contextually likely one and *hide* the learner's
error — which is exactly the feedback they most need.

Phoneme-level scoring means a paid cloud service. Azure Pronunciation Assessment supports `ja-JP`
and returns per-phoneme scores; Speechace and ELSA are the alternatives. ⚠️ Verify current pricing
at the time rather than trusting a remembered figure.

**Second wrinkle:** Android ASR returns kanji (`貼ります`) while this data is kana (`はります`).
Comparing them needs a reading conversion (Kuromoji, Sudachi or MeCab) or fuzzy matching. Solvable,
not free.

### 🚨 flutter_tts: bind a VOICE, not a language

Cost an hour on 2026-09-26 and will cost it again. `flutter_tts`'s web `_setLanguage` is:

```dart
void _setLanguage(String language) {
  var targetList = synth.getVoices().toDart.where((e) => e.lang.startsWith(language));
  if (targetList.isNotEmpty) {        // silently does nothing when empty
    utterance.voice = targetList.first;
  }
}
```

Browsers populate `getVoices()` **asynchronously**, so calling `setLanguage` during init finds an
empty list, binds no voice, and the utterance keeps the default English one. Chrome is then handed
kana to read with Microsoft David and produces **silence with no error anywhere**.

Fix: wait for the voice list (retry), find a `ja` locale, and call **`setVoice({name, locale})`**.

Second, latent: do **not** `stop()` immediately before `speak()`. `_stop()` calls `synth.cancel()`
whose state change arrives on a later event, and `_speak` refuses to run unless the state is
*already* stopped, so the speak is silently eaten. Harmless on the first tap (initial state is
stopped), breaks every tap after.

**Method that found it, not the guesses that didn't.** Three code changes against hypotheses all
failed. A ten-line static HTML page calling `window.speechSynthesis` directly settled it in one
click: the browser spoke Japanese perfectly, which proved the platform was fine and the fault was
ours. Isolate the layer before editing the code.

Also worth knowing on Windows: there are two speech registries, `Speech` (SAPI5, what Chrome reads)
and `Speech_OneCore`. A language-pack install often lands voices only in OneCore, where Chrome
cannot see them, so a voice can look installed in Settings and be unusable. And Chrome caches the
voice list at startup, so a newly installed voice needs a full browser restart, not a refresh.

### 🚨 speech_to_text reports amplitude on mobile only, so the web needs its own tap

`onSoundLevelChange` is emitted by the Android and iOS implementations and **never by the web
one** — the Web Speech API simply has no such callback. That is not a bug to hunt for; there is
nothing to fix in `speech_to_text`. The consequence is what matters: Chrome is the platform this
app is actually developed on, so a listening animation driven by that callback is **flat on the
only screen it gets iterated against**, and cannot be judged without a full APK cycle.

The fix is `lib/components/pages/quiet_room_practice/mic_level_web.dart`: open a second
`getUserMedia` stream, run it through an `AnalyserNode`, and take RMS off the time-domain
buffer. Chrome permits several consumers of one microphone, so it coexists with recognition.

Two decisions worth keeping:

- **RMS, not an FFT,** even though the FFT is free once the analyser exists. Mobile can only ever
  supply one scalar, so a real spectrum on web would make the same widget look different on the
  two platforms. One amplitude number feeds one renderer everywhere.
- **No new dependency.** `package:web` is only a transitive dependency of the Firebase plugins,
  and depending on it directly would be a promise not made (S11), so the four interfaces needed
  are declared with `dart:js_interop` instead. That needs a **Dart 3.3 floor** for extension
  types; `pubspec.yaml` said `>=3.0.0` while CI pins Flutter 3.44.8, so raising it retired a
  stale constraint rather than imposing a new one.

Failure stays honest: if the permission is refused or there is no input device, `start()` returns
false, the level stays 0, and the indicator holds its still state. And `cancel()` must tear the
tap down as well as the recogniser, or the browser's recording indicator stays lit after Stop.

### The listening indicator is a visualiser, and the genre lies by default

`listening_bars.dart` is a symmetric bar row, the shape of the podcast/voice-recording
visualisers Mark pointed at. Those references are **loops**: they animate on a timer over a
finished recording, whether or not anyone is speaking. This one must not, so silence collapses
every bar to a flat row of dots — deliberately the same small mark as the 14 dots of the Today
day row, so a quiet row still looks like the app.

What is real and what is licence, stated so nobody has to guess later: the **amount** of movement
is measured amplitude; the **distribution across the bars is invented**, from a fixed per-bar
envelope and phase offset, because one scalar is not a spectrum. That is why the bars may never
move while the scalar is zero — the shape is decoration, the presence of motion is a claim.

🚨 `live` must be **discovered, not declared**. Passing it as a constructor flag reads it once at
mount, before the first level arrives, so it is permanently false and the indicator never wakes
even on Android. This has now been the bug twice.

### Ladder, cheap wins first

1. **Tap to hear** — TTS on every existing card. No ASR, no permission prompt, works across all 620
   words immediately.
2. **Picture prompts** — extract the illustrations; show the image, speak the word, ASR checks
   *which word*. Frame it honestly as a recall drill you speak rather than tap.
3. **Hints on demand** — `gloss`, `verbGroup`, `dictionary`, `teForm` and `intransitive` are already
   in the data, so this is a reveal ladder in UI, not new extraction. Grammar hints depend on the
   grammar work above.
4. **Real pronunciation scoring, and English-sentence prompts** — the expensive tier. Sentences do
   not exist in the word lists at all, so they need sourcing or generating.

### Where the extraction-framework question returns

Step 4's judging is Jev-shaped: *"is this spoken answer acceptable?"* is a **Noul** question with a
confidence, at $0.042/M input and free output. That beats exact string matching, which rejects
correct answers phrased differently and cannot bridge the kanji/kana mismatch on its own.

## Regenerating

The extractor is not committed; it was run from the session scratchpad. If it is worth keeping,
`scripts/` is its home. Behaviour to preserve:

1. Group each page into kana plus trailing Latin strings.
2. Romanise the kana; drop any Latin string that matches it; the remainder is the gloss.
3. Prefer the Langoal sheet when both families cover a lesson.
4. **Exclude a lesson rather than emit a scrambled one.** A stated gap is honest; wrong vocabulary
   teaches the wrong thing and nothing later can catch it.
