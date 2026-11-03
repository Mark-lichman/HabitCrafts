// Tests for the per-lesson speaking drill (plan 2026-10-27, Task 3).
//
// The drill checks a sentence BY SOUND through PronunciationService (PIN-1). These tests
// build the real service with fake seams: a fake microphone fed PCM chunks, a fake clock,
// a fake Firebase auth behind the real ensureCaller() (PIN-9), and a fake function call
// that returns the committed Azure replies. So the verdict, the automatic stop (PIN-5,
// PIN-7) and the letter colors (PIN-8) all come from the code the drill ships with.
//
// The lessonSentences and judge() groups still pin the lesson data the drill walks.
//
// Plan 2026-11-02, Task 1 (End state 11) adds: the voice is stopped before the microphone
// opens and Play waits on speakAndWait; Cancel on Checking and a pause retire the attempt so
// a late result is dropped; a combined example's English splits with its Japanese; one
// position counter, with the tally on an end card; a self-mark is kept with its attempt in
// the score log; and the sentence box keeps Next in place.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/anon_caller.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/listening_bars.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/pronunciation_service.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart'
    show SpeechService;
import 'package:habit_craft/flutter_flow/quiet_room.dart';

import 'jp_screen_harness.dart';
import 'speech_service_test.dart' show FakeStt, FakeTts;

/// Lesson 26's sentences, as the drill walks them.
List<SpeakSentence> lesson26() {
  final doc = readLessonFile();
  final lesson = (doc['grammar'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((l) => l['lesson'] == 26);
  return lessonSentences(lesson);
}

/// The drill's first sentence, the one shown when the screen opens.
SpeakSentence firstSentence() => lesson26().first;

/// The first lesson 26 sentence whose kanji surface differs from its kana, with its index.
/// Chosen from the data, not pinned, so it holds whichever words a later twin rewrite
/// keeps in kanji.
({int index, SpeakSentence s}) kanjiSentence() {
  final all = lesson26();
  final i = all.indexWhere((x) => x.surface != x.kana);
  expect(i, isNonNegative, reason: 'lesson 26 has no sentence in kanji');
  return (index: i, s: all[i]);
}

/// The enabled state of the drill button labelled [label], read from the button itself.
VoidCallback? buttonAction(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)))
    .onPressed;

/// No spaces or punctuation, the way a recogniser returns a sentence.
String bare(String s) => s.replaceAll(RegExp(r'[\s、。！？「」]'), '');

/// The kanji forms judge() takes for [s]: its surface, when that differs from the kana.
List<String> formsOf(SpeakSentence s) =>
    s.surface == s.kana ? const [] : [s.surface];

const _goodFixture =
    'firebase/speech_functions/fixtures/azure-reply-L26-1-mark.json';
const _badFixture =
    'firebase/speech_functions/fixtures/azure-reply-L26-1-mark-mispronounced.json';

/// A fresh copy of a committed Azure reply, so a test may edit it.
Map<String, dynamic> fixture(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The good reply with its PronScore set to [score], so the verdict is the only change.
Map<String, dynamic> goodWithScore(double score) {
  final r = fixture(_goodFixture);
  ((r['NBest'] as List).first as Map<String, dynamic>)['PronScore'] = score;
  return r;
}

const _loud = 8000; // about -12 dBFS
const _quiet = 30; // about -61 dBFS

/// [ms] of 16 kHz mono 16-bit PCM, a square wave of ±[amp].
Uint8List pcm(int amp, int ms) {
  final n = PronunciationService.sampleRate * ms ~/ 1000;
  final b = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    b.setInt16(i * 2, i.isEven ? amp : -amp, Endian.little);
  }
  return b.buffer.asUint8List();
}

class FakeTimer implements Timer {
  FakeTimer(this.due, this.callback);
  final DateTime due;
  final void Function() callback;
  bool _active = true;
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
  @override
  void cancel() => _active = false;
}

class FakeClock implements PronClock {
  DateTime _now = DateTime(2026, 10, 27, 9);
  final List<FakeTimer> _timers = [];

  @override
  DateTime now() => _now;

  @override
  Timer timer(Duration after, void Function() callback) {
    final t = FakeTimer(_now.add(after), callback);
    _timers.add(t);
    return t;
  }

  void advance(Duration d) {
    _now = _now.add(d);
    for (final t in List.of(_timers)) {
      if (t.isActive && !t.due.isAfter(_now)) {
        t.cancel();
        t.callback();
      }
    }
  }
}

/// A microphone the test feeds by hand.
class FakeMic implements PronRecorder {
  StreamController<Uint8List>? ctl;
  int starts = 0;

  /// Runs at the top of [start], so a test can read state at the moment the mic opens.
  void Function()? onStart;

  bool get open => ctl != null && !ctl!.isClosed;

  @override
  Future<Stream<Uint8List>?> start(int sampleRate) async {
    onStart?.call();
    starts++;
    ctl = StreamController<Uint8List>(onCancel: () async {});
    return ctl!.stream;
  }

  @override
  Future<void> stop() async {
    final c = ctl;
    if (c == null || c.isClosed) return;
    final closed = c.close();
    if (c.hasListener) await closed;
  }

  @override
  Future<void> dispose() async {}
}

/// Firebase auth as ensureCaller() sees it.
class FakeAuth implements CallerAuth {
  FakeAuth({this.hasUser = false});
  @override
  bool hasUser;
  int anonymousSignIns = 0;
  Object? error;

  @override
  Future<void> signInAnonymously() async {
    anonymousSignIns++;
    if (error != null) throw error!;
    hasUser = true;
  }
}

/// The drill with a real PronunciationService on fake seams.
class Rig {
  Rig({this.reply, this.error, FakeAuth? auth}) : auth = auth ?? FakeAuth();

  Object? reply;
  Object? error;

  /// When set, the function call waits here, so a test can act while it scores.
  Completer<void>? scoreGate;
  final FakeAuth auth;
  final FakeMic mic = FakeMic();
  final FakeClock clock = FakeClock();

  /// The app's own voice, on a fake engine, so Play and the stop before Speak are real
  /// SpeechService calls.
  final FakeTts tts = FakeTts();
  late final SpeechService voice =
      SpeechService.withEngines(stt: FakeStt(), tts: tts);
  final List<Map<String, Object?>> sent = [];
  PronunciationService? service;

  PronunciationService make(CallerSignIn signIn) =>
      service = PronunciationService(
        recorder: mic,
        clock: clock,
        signIn: signIn,
        score: (payload) async {
          sent.add(payload);
          if (scoreGate != null) await scoreGate!.future;
          if (error != null) throw error!;
          return reply;
        },
      );

  /// [realVoice] plays through [voice] instead of the [play] seam.
  Widget widget({SpeakPlay? play, bool realVoice = false, int lesson = 26}) =>
      QuietRoomSpeakWidget(
        lesson: lesson,
        newService: make,
        callerAuth: auth,
        speech: voice,
        play: realVoice ? null : play ?? (_) async => null,
      );

  Future<void> open(WidgetTester tester,
          {SpeakPlay? play, bool realVoice = false, int lesson = 26}) =>
      pumpStudyScreen(
          tester, widget(play: play, realVoice: realVoice, lesson: lesson));

  /// Feeds [ms] of audio at [amp] in 100 ms chunks, advancing the clock with it.
  Future<void> feed(WidgetTester tester, int amp, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      if (!mic.open) return;
      clock.advance(const Duration(milliseconds: 100));
      if (!mic.open) return;
      mic.ctl!.add(pcm(amp, 100));
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Taps Speak and waits for the microphone to open.
  Future<void> tapSpeak(WidgetTester tester) async {
    await tester.tap(find.text('Speak'));
    await tester.pump();
    await tester.pump();
  }

  /// Says a sentence and goes quiet. Nobody taps Stop.
  Future<void> sayAndGoQuiet(WidgetTester tester) async {
    await feed(tester, _loud, 800);
    await feed(tester, _quiet, 1500);
    await settle(tester);
  }

  /// Lets the check, the score log and the rebuilds finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  /// Opens the drill and says its first sentence once.
  Future<void> speakOnce(WidgetTester tester) async {
    await open(tester);
    await tapSpeak(tester);
    await sayAndGoQuiet(tester);
  }
}

/// The colored letters of the result card, as (letter, color) pairs.
List<(String, Color?)> letterColors(WidgetTester tester) {
  final text = tester.widget<Text>(find.byKey(const ValueKey('speak-letters')));
  final out = <(String, Color?)>[];
  text.textSpan!.visitChildren((s) {
    if (s is TextSpan && s.text != null) out.add((s.text!, s.style?.color));
    return true;
  });
  return out;
}

/// Walks the rest of the set with Next and Finish, to the end card.
Future<void> walkToEnd(WidgetTester tester) async {
  for (var i = 0; i < 400; i++) {
    if (find.text('Finish').evaluate().isNotEmpty) {
      await tester.tap(find.text('Finish'));
      await tester.pump();
      return;
    }
    await tester.tap(find.text('Next sentence'));
    await tester.pump();
  }
  fail('the set never ended');
}

/// The end card's tally.
String tallyOf(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('speak-tally'))).data!;

/// The header's position counter.
String positionOf(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('speak-position'))).data!;

QuietRoomTokens tokensOf(WidgetTester tester) =>
    QuietRoomTokens.of(tester.element(find.text('Next sentence')));

Future<List<Map<String, dynamic>>> savedAttempts() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString(SpeakScoreLog.prefsKey);
  if (raw == null) return const [];
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

void main() {
  group('rubySurface', () {
    test('drops every reading and keeps okurigana', () {
      expect(rubySurface('買{か}い物{もの}に 行{い}きます。'), '買い物に 行きます。');
      expect(rubySurface('あした テストが あるんです。'), 'あした テストが あるんです。');
    });
  });

  group('rubyKana', () {
    test('reads every bracket and keeps okurigana', () {
      expect(rubyKana('買{か}い物{もの}に 行{い}きます。'), 'かいものに いきます。');
      expect(rubyKana('「立入禁止{たちいりきんし}」は だめです。'), '「たちいりきんし」は だめです。');
      expect(rubyKana('あした テストが あるんです。'), 'あした テストが あるんです。');
    });
  });

  group('lessonSentences', () {
    test('holds every example and every completed practice item', () {
      final doc = readLessonFile();
      final lesson = (doc['grammar'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((l) => l['lesson'] == 26);
      final points = (lesson['points'] as List).cast<Map<String, dynamic>>();
      final expected = points.fold<int>(
          0,
          (n, p) =>
              n +
              (p['examples'] as List? ?? const []).length +
              (p['practice'] as List? ?? const []).length);
      final s = lessonSentences(lesson);
      expect(s.length, expected);
      for (final x in s) {
        expect(x.kana.contains('＿＿'), isFalse);
        expect(x.surface.contains('＿＿'), isFalse);
        expect(x.surface.contains('{'), isFalse);
      }
      // A practice sentence is its prompt with the answer in the blank.
      final q =
          (points.first['practice'] as List).first as Map<String, dynamic>;
      final done =
          (q['prompt'] as String).replaceAll('＿＿', q['answer'] as String);
      expect(s.map((x) => x.kana), contains(done));
    });

    test(
        'walks point by point, one point\'s practice before the next point\'s examples',
        () {
      final lesson = {
        'points': [
          {
            'examples': [
              {'jp': 'あめが ふります。', 'en': 'rain'}
            ],
            'practice': [
              {'prompt': 'ゆきが ＿＿。', 'answer': 'ふります', 'en': 'snow'}
            ],
          },
          {
            'examples': [
              {'jp': 'かぜが ふきます。', 'en': 'wind'}
            ],
            'practice': [
              {'prompt': 'かぜが ＿＿か。', 'answer': 'ふきます', 'en': 'wind?'}
            ],
          },
        ],
      };
      expect(lessonSentences(lesson).map((x) => x.kana).toList(), [
        'あめが ふります。',
        'ゆきが ふります。',
        'かぜが ふきます。',
        'かぜが ふきますか。',
      ]);
    });

    test('splits an example that joins forms with ／ into one sentence each',
        () {
      final lesson = {
        'points': [
          {
            'examples': [
              {
                'jp': 'いこう／たべよう／しよう',
                'jp_ruby': '行{い}こう／食{た}べよう／しよう',
                'en': 'volitional',
              }
            ],
          }
        ],
      };
      final s = lessonSentences(lesson);
      expect(s.map((x) => x.kana), ['いこう', 'たべよう', 'しよう']);
      expect(s.map((x) => x.surface), ['行こう', '食べよう', 'しよう']);
      expect(s.map((x) => x.en), everyElement('volitional'));
    });

    test('splits the English of a combined example alongside its Japanese', () {
      List<SpeakSentence> one(String jp, String en) => lessonSentences({
            'points': [
              {
                'examples': [
                  {'jp': jp, 'en': en}
                ],
              }
            ],
          });
      // Slash, sentence and comma joins each split when the count matches.
      expect(one('とまれ！／はいるな！', "Stop! / Don't enter!").map((x) => x.en),
          ['Stop!', "Don't enter!"]);
      expect(one('あめが ふります。／ゆきが ふります。', 'It rains. It snows.').map((x) => x.en),
          ['It rains.', 'It snows.']);
      expect(one('いかせる／たべさせる', 'to make go, to make eat').map((x) => x.en),
          ['to make go', 'to make eat']);
      // A shared lead is carried onto the bare items of a comma list.
      expect(one('よまれる／たべられる', 'passive of よむ, たべる').map((x) => x.en),
          ['passive of よむ', 'passive of たべる']);
      // A count that does not match keeps the whole English on every form.
      expect(one('いこう／たべよう', 'volitional').map((x) => x.en),
          ['volitional', 'volitional']);
      expect(one('いこう／たべよう', 'a / b / c').map((x) => x.en),
          ['a / b / c', 'a / b / c']);
    });

    test('every shipped combined example gives each form its own English', () {
      final doc = readLessonFile();
      var combined = 0;
      for (final lesson
          in (doc['grammar'] as List).cast<Map<String, dynamic>>()) {
        for (final p
            in (lesson['points'] as List).cast<Map<String, dynamic>>()) {
          for (final e in (p['examples'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
            final jp = e['jp'] as String;
            if (!jp.contains('／')) continue;
            combined++;
            final s = lessonSentences({
              'points': [
                {
                  'examples': [e]
                }
              ]
            });
            final where = 'lesson ${lesson['lesson']}: $jp';
            expect(s, hasLength(jp.split('／').length), reason: where);
            expect(s.map((x) => x.en).toSet(), hasLength(s.length),
                reason: '$where -> ${s.map((x) => x.en).toList()}');
            for (final x in s) {
              expect(x.en, isNotEmpty, reason: where);
              expect(x.en.contains('／') || x.en.contains(' / '), isFalse,
                  reason: where);
            }
          }
        }
      }
      expect(combined, greaterThan(0));
    });

    test('every shipped sentence is judged correct in kana and in kanji', () {
      final doc = readLessonFile();
      final kanji = RegExp(r'[一-鿿]');
      var count = 0;
      for (final lesson
          in (doc['grammar'] as List).cast<Map<String, dynamic>>()) {
        for (final s in lessonSentences(lesson)) {
          count++;
          final where = 'lesson ${lesson['lesson']}: ${s.kana}';
          expect(s.kana.contains('／'), isFalse, reason: where);
          expect(s.surface.contains('／'), isFalse, reason: where);
          expect(s.kana.contains('{'), isFalse, reason: where);
          expect(kanji.hasMatch(s.kana), isFalse, reason: where);
          final forms = formsOf(s);
          expect(SpeechService.judge(bare(s.kana), s.kana, kanjiForms: forms),
              Judgement.correct,
              reason: where);
          expect(
              SpeechService.judge(bare(s.surface), s.kana, kanjiForms: forms),
              Judgement.correct,
              reason: '$where (kanji ${s.surface})');
        }
      }
      expect(count, greaterThan(0));
    });
  });

  group('judge on a whole sentence', () {
    test('an exact hiragana sentence is correct', () {
      final s = firstSentence();
      expect(SpeechService.judge(bare(s.kana), s.kana, kanjiForms: formsOf(s)),
          Judgement.correct);
    });

    test('an exact kanji sentence is correct without its spaces or 。', () {
      final s = kanjiSentence().s;
      expect(s.surface, isNot(s.kana));
      expect(
          SpeechService.judge(bare(s.surface), s.kana, kanjiForms: [s.surface]),
          Judgement.correct);
    });

    test(
        'a vocabulary word with an EDICT kanji form is judged on the same path',
        () {
      // The vocabulary drill calls judge() with EDICT forms. Both sides now go through
      // normalise(), so spacing and 。 no longer turn an exact match into close.
      expect(
          SpeechService.judge('山', 'やま', kanjiForms: ['山']), Judgement.correct);
      expect(SpeechService.judge('山。', 'やま', kanjiForms: ['山']),
          Judgement.correct);
      expect(
          SpeechService.judge('山です', 'やま', kanjiForms: ['山']), Judgement.close);
      // An empty form is skipped, not matched by contains('').
      expect(SpeechService.judge('猫', 'ねこ', kanjiForms: ['']),
          Judgement.unverified);
    });
  });

  group('the drill screen', () {
    testWidgets('plays the sentence and scores it against its hiragana',
        (tester) async {
      final (index: index, s: s) = kanjiSentence();
      final played = <String>[];
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.open(tester, play: (text) async {
        played.add(text);
        return null;
      });
      expect(find.text(firstSentence().kana), findsOneWidget);
      for (var i = 0; i < index; i++) {
        await tester.tap(find.text('Next sentence'));
        await tester.pump();
      }
      expect(find.text(s.kana), findsOneWidget);

      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(played, [s.kana]);

      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      // The reference text is the hiragana, never the kanji surface (PIN-1).
      expect(rig.sent.single['referenceText'], s.kana);
      expect(rig.sent.single['audio'], isA<String>());
    });

    testWidgets(
        'shows the live level while listening and stops by itself, no Stop tap '
        '(PIN-7)', (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.open(tester);
      await rig.tapSpeak(tester);

      expect(find.text('Listening'), findsOneWidget);
      expect(rig.mic.open, isTrue);
      // The animation is fed from the service's own sound level.
      final bars = tester.widget<ListeningBars>(find.byType(ListeningBars));
      expect(identical(bars.level, rig.service!.level), isTrue);

      await rig.feed(tester, _loud, 800);
      expect(rig.service!.level.value, greaterThan(0));
      expect(find.text('Hearing you'), findsOneWidget);
      expect(rig.sent, isEmpty);

      // Quiet after speech ends the listen. Nobody taps Stop.
      await rig.feed(tester, _quiet, 1500);
      await rig.settle(tester);
      expect(rig.mic.open, isFalse);
      expect(find.byType(ListeningBars), findsNothing);
      expect(rig.sent, hasLength(1));
      expect(find.text('That’s it'), findsOneWidget);
    });

    testWidgets(
        'signs in anonymously only when it scores, then reuses that caller '
        '(PIN-9)', (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await rig.feed(tester, _loud, 800);
      // Opening the drill and listening sign nobody in.
      expect(rig.auth.anonymousSignIns, 0);
      await rig.feed(tester, _quiet, 1500);
      await rig.settle(tester);
      expect(rig.auth.anonymousSignIns, 1);
      expect(rig.sent, hasLength(1));

      // A second attempt reuses the caller it made.
      await tester.tap(find.text('Next sentence'));
      await tester.pump();
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      expect(rig.auth.anonymousSignIns, 1);
      expect(rig.sent, hasLength(2));
    });

    testWidgets('a signed-in user is reused with no anonymous sign-in',
        (tester) async {
      final rig =
          Rig(reply: fixture(_goodFixture), auth: FakeAuth(hasUser: true));
      await rig.speakOnce(tester);
      expect(rig.auth.anonymousSignIns, 0);
      expect(rig.sent, hasLength(1));
    });

    testWidgets('a correct score shows the score and colors every letter',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.speakOnce(tester);
      final t = tokensOf(tester);

      expect(find.text('That’s it'), findsOneWidget);
      expect(find.text('Score 98.6'), findsOneWidget);
      expect(find.text('Got it'), findsNothing);

      final letters = letterColors(tester);
      expect(letters.map((l) => l.$1).join(), firstSentence().kana);
      // あ scored 85: green.
      expect(letters.first, ('あ', t.sage600));
      // Every letter takes the color of its own syllable score.
      final scores = PronunciationResult.fromReply(fixture(_goodFixture))
          .sentenceLetters(firstSentence().kana);
      for (var i = 0; i < letters.length; i++) {
        final score = scores[i].score;
        expect(letters[i].$2,
            score == null ? isNot(t.sage600) : scoreColor(t, score),
            reason: letters[i].$1);
      }
      expect(letters.where((l) => l.$2 == t.sage600).length, greaterThan(5));

      // The tally waits for the end of the set.
      expect(find.byKey(const ValueKey('speak-tally')), findsNothing);
      await walkToEnd(tester);
      expect(tallyOf(tester), '1 of 1');
    });

    testWidgets(
        'a right card adds the kanji surface, and never repeats a sentence '
        'that has no kanji', (tester) async {
      // Case 1: a sentence the lesson prints in kanji shows that form once.
      final (index: index, s: s) = kanjiSentence();
      final rig = Rig(reply: goodWithScore(95));
      await rig.open(tester);
      for (var i = 0; i < index; i++) {
        await tester.tap(find.text('Next sentence'));
        await tester.pump();
      }
      expect(find.text(s.surface), findsNothing);
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      expect(find.text('That’s it'), findsOneWidget);
      expect(find.text(s.surface), findsOneWidget);

      // Case 2: a sentence with no kanji keeps its kana on the sentence card only.
      final all = lesson26();
      final plain = all.indexWhere((x) => x.surface == x.kana);
      expect(plain, isNonNegative,
          reason: 'lesson 26 has no kana-only sentence');
      // Clear the tree first, or the drill keeps its State and the first rig's seams.
      await tester.pumpWidget(const SizedBox());
      final again = Rig(reply: goodWithScore(95));
      await again.open(tester);
      for (var i = 0; i < plain; i++) {
        await tester.tap(find.text('Next sentence'));
        await tester.pump();
      }
      await again.tapSpeak(tester);
      await again.sayAndGoQuiet(tester);
      expect(find.text('That’s it'), findsOneWidget);
      expect(
          find.byWidgetPredicate((w) => w is Text && w.data == all[plain].kana),
          findsOneWidget);
    });

    testWidgets(
        'a wrong score shows the score, colors each letter by its syllable and '
        'strikes the inserted word', (tester) async {
      final rig = Rig(reply: fixture(_badFixture));
      await rig.speakOnce(tester);
      final t = tokensOf(tester);

      expect(find.text('Not quite'), findsOneWidget);
      expect(find.text('Score 44.8'), findsOneWidget);
      expect(find.text('Got it'), findsNothing);

      final letters = letterColors(tester);
      expect(letters.map((l) => l.$1).join(), firstSentence().kana);
      // あたま scored 12, 64 and 0 syllable by syllable: red, amber, red (PIN-8).
      expect(
          letters.take(3).map((l) => l.$2), [t.clay600, t.amber700, t.clay600]);
      // が scored 100.
      expect(letters[3], ('が', t.sage600));
      // ん scored 6.
      expect(letters.firstWhere((l) => l.$1 == 'ん').$2, t.clay600);

      // The extra あたま Mark said is shown struck through.
      final inserted =
          tester.widget<Text>(find.byKey(const ValueKey('speak-inserted')));
      final spans = <TextSpan>[];
      inserted.textSpan!.visitChildren((s) {
        if (s is TextSpan && s.text != null) spans.add(s);
        return true;
      });
      final struck =
          spans.where((s) => s.style?.decoration == TextDecoration.lineThrough);
      expect(struck.map((s) => s.text), ['あたま']);

      await walkToEnd(tester);
      expect(tallyOf(tester), '0 of 1');
    });

    testWidgets('a close score is amber with the score, then self-check',
        (tester) async {
      final rig = Rig(reply: goodWithScore(70));
      await rig.speakOnce(tester);
      final t = tokensOf(tester);

      final head = tester.widget<Text>(find.text('Close'));
      expect(head.style?.color, t.amber700);
      expect(find.text('Score 70'), findsOneWidget);
      expect(find.byKey(const ValueKey('speak-letters')), findsOneWidget);
      expect(find.text('That’s it'), findsNothing);
      expect(find.text('Not quite'), findsNothing);

      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(find.text('Marked as said.'), findsOneWidget);
      await walkToEnd(tester);
      expect(tallyOf(tester), '1 of 1');
    });

    testWidgets(
        'a word whose syllables do not line up is colored by its word score',
        (tester) async {
      final reply = fixture(_goodFixture);
      final atama = (((reply['NBest'] as List).first as Map)['Words'] as List)
          .first as Map<String, dynamic>;
      atama['AccuracyScore'] = 50;
      (atama['Syllables'] as List).removeLast();
      final rig = Rig(reply: reply);
      await rig.speakOnce(tester);
      final t = tokensOf(tester);

      // Three letters, two syllables: the whole word takes its score of 50.
      expect(letterColors(tester).take(3).map((l) => l.$2),
          [t.clay600, t.clay600, t.clay600]);
      expect(letterColors(tester)[3], ('が', t.sage600));
    });

    testWidgets(
        'a reply whose words do not match the sentence still colors every word',
        (tester) async {
      // The scored words stop matching the sentence after あたまが, so the sentence letters
      // cannot line up. The drill shows the scored words instead, one space apart.
      final rig = Rig(reply: <String, Object?>{
        'PronScore': 65,
        'Words': [
          {
            'Word': 'あたま',
            'AccuracyScore': 90,
            'ErrorType': 'None',
            'Syllables': [
              {'AccuracyScore': 90},
              {'AccuracyScore': 90},
              {'AccuracyScore': 90},
            ],
          },
          {
            'Word': 'が',
            'AccuracyScore': 90,
            'ErrorType': 'None',
            'Syllables': [
              {'AccuracyScore': 90}
            ],
          },
          {
            'Word': 'いたくない',
            'AccuracyScore': 40,
            'ErrorType': 'Mispronunciation',
            'Syllables': [],
          },
        ],
      });
      await rig.speakOnce(tester);
      final t = tokensOf(tester);

      final letters = letterColors(tester);
      expect(letters.map((l) => l.$1).join(), 'あたま が いたくない');
      expect(letters.where((l) => l.$1 != ' ' && l.$2 == null), isEmpty);
      expect(letters.first.$2, t.sage600);
      expect(letters.last, ('い', t.clay600));
    });

    testWidgets('a function error goes to self-check, never wrong (PIN-3)',
        (tester) async {
      final rig = Rig(error: Exception('network down'));
      await rig.speakOnce(tester);

      expect(rig.sent, hasLength(1));
      expect(find.text('Can’t check this one'), findsOneWidget);
      expect(find.text('Not quite'), findsNothing);
      expect(find.textContaining('Score '), findsNothing);
      await tester.tap(find.text('Missed it'));
      await tester.pump();
      expect(find.text('Not quite'), findsNothing);
      await walkToEnd(tester);
      expect(tallyOf(tester), '0 of 1');
    });

    testWidgets('a failed anonymous sign-in goes to self-check with no call',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture))
        ..auth.error = Exception('anonymous sign-in disabled');
      await rig.speakOnce(tester);

      expect(rig.auth.anonymousSignIns, 1);
      expect(rig.sent, isEmpty);
      expect(find.text('Can’t check this one'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('silence with no speech goes to self-check, never wrong',
        (tester) async {
      final rig = Rig(reply: fixture(_badFixture));
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await rig.feed(
          tester, _quiet, PronunciationService.listenCap.inMilliseconds + 200);
      await rig.settle(tester);

      expect(rig.mic.open, isFalse);
      expect(rig.sent, isEmpty);
      expect(find.text('Can’t check this one'), findsOneWidget);
      expect(find.text('Not quite'), findsNothing);
    });

    testWidgets(
        'keeps every attempt on the device and lists it under Recent scores '
        '(PIN-4)', (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.speakOnce(tester);
      await rig.settle(tester);

      var saved = await tester.runAsync(savedAttempts);
      expect(saved, hasLength(1));
      expect(saved!.single['sentence'], firstSentence().kana);
      expect(saved.single['verdict'], 'correct');
      expect(saved.single['overall'], 98.6);
      expect(saved.single['accuracy'], 98);
      expect(saved.single['fluency'], 99);
      expect(saved.single['completeness'], 100);
      final words =
          (saved.single['words'] as List).cast<Map<String, dynamic>>();
      expect(words.first['word'], 'あたま');
      expect(words.first['score'], 97);
      expect(words.first['syllables'], [85, 100, 100]);

      // A second attempt that cannot be scored is kept too, as unverified.
      await tester.tap(find.text('Next sentence'));
      await tester.pump();
      rig.error = Exception('offline');
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      await rig.settle(tester);

      saved = await tester.runAsync(savedAttempts);
      expect(saved!.map((a) => a['verdict']), ['correct', 'unverified']);
      expect(saved.last['sentence'], lesson26()[1].kana);
      expect(saved.last['overall'], isNull);

      expect(find.text('Recent scores'), findsOneWidget);
      final recent = find.byKey(const ValueKey('speak-recent'));
      final rows = tester
          .widgetList<Text>(
              find.descendant(of: recent, matching: find.byType(Text)))
          .map((w) => w.data ?? '')
          .where((d) => d.contains('·'))
          .toList();
      // Newest first.
      expect(rows, hasLength(2));
      expect(rows.first, contains('no score'));
      expect(rows.first, contains(lesson26()[1].kana));
      expect(rows.last, contains('98.6 · correct'));
    });

    testWidgets('Recent scores shows attempts kept from an earlier visit',
        (tester) async {
      await Rig().open(tester);
      expect(find.text('Recent scores'), findsNothing);
      await tester.runAsync(() async {
        final p = await SharedPreferences.getInstance();
        await p.setString(
            SpeakScoreLog.prefsKey,
            jsonEncode([
              {
                'sentence': 'あたまが いたいんです。',
                'verdict': 'close',
                'overall': 72.4,
                'at': '2026-10-27T09:00:00.000',
                'words': [],
              }
            ]));
      });
      // Open the drill again on the same device.
      final again = Rig();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: again.widget()));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await again.settle(tester);
      expect(find.text('Recent scores'), findsOneWidget);
      expect(find.textContaining('72.4 · close'), findsOneWidget);
    });

    testWidgets('the score log keeps the newest ${SpeakScoreLog.keep} attempts',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.open(tester);
      // A device that already holds a full log.
      await tester.runAsync(() async {
        final p = await SharedPreferences.getInstance();
        await p.setString(
            SpeakScoreLog.prefsKey,
            jsonEncode([
              for (var i = 0; i < SpeakScoreLog.keep; i++)
                {
                  'sentence': 'seed $i',
                  'verdict': 'correct',
                  'overall': 90,
                  'at': '2026-10-27T09:00:00.000',
                  'words': [],
                }
            ]));
      });
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      await rig.settle(tester);

      final saved = await tester.runAsync(savedAttempts);
      expect(saved, hasLength(SpeakScoreLog.keep));
      // The oldest entry dropped off, and the new attempt is last.
      expect(saved!.first['sentence'], 'seed 1');
      expect(saved.map((a) => a['sentence']), isNot(contains('seed 0')));
      expect(saved.last['sentence'], firstSentence().kana);
    });

    testWidgets('one bad log entry never hides the rest', (tester) async {
      await Rig().open(tester);
      await tester.runAsync(() async {
        final p = await SharedPreferences.getInstance();
        await p.setString(
            SpeakScoreLog.prefsKey,
            jsonEncode([
              'not an attempt',
              {'verdict': 'close', 'overall': 50, 'words': []},
              {
                'sentence': 'あたまが いたいんです。',
                'verdict': 'close',
                'overall': 72.4,
                'at': '2026-10-27T09:00:00.000',
                'words': [],
              },
            ]));
      });
      // Open the drill again on the same device.
      final again = Rig();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: again.widget()));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await again.settle(tester);
      expect(find.text('Recent scores'), findsOneWidget);
      final rows = tester
          .widgetList<Text>(find.descendant(
              of: find.byKey(const ValueKey('speak-recent')),
              matching: find.byType(Text)))
          .map((w) => w.data ?? '')
          .where((d) => d.contains('·'))
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single, contains('72.4 · close'));
    });

    testWidgets(
        'one check at a time: Speak and Next wait while the sentence is scored',
        (tester) async {
      final first = firstSentence();
      final rig = Rig(reply: fixture(_goodFixture))
        ..scoreGate = Completer<void>();
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);

      expect(rig.sent, hasLength(1));
      expect(find.text('Checking…'), findsOneWidget);
      expect(find.text('Speak'), findsNothing);
      await tester.tap(find.text('Next sentence'), warnIfMissed: false);
      await tester.pump();
      expect(find.text(first.kana), findsOneWidget);

      rig.scoreGate!.complete();
      await rig.settle(tester);
      expect(find.text('That’s it'), findsOneWidget);
      expect(rig.mic.starts, 1);
    });

    testWidgets('Stop drops the listen it cut short and scores nothing',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await rig.feed(tester, _loud, 300);

      await tester.tap(find.text('Stop'));
      await rig.settle(tester);
      expect(find.text('Listening'), findsNothing);
      expect(find.text('Hearing you'), findsNothing);
      expect(rig.mic.open, isFalse);
      expect(rig.sent, isEmpty);
      expect(find.text('That’s it'), findsNothing);
      expect(find.text('Can’t check this one'), findsNothing);
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(await tester.runAsync(savedAttempts), isEmpty);
    });

    testWidgets('Speak and Play are disabled while the sentence plays',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      final voice = Completer<String?>();
      await rig.open(tester, play: (_) => voice.future);
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(buttonAction(tester, 'Play'), isNotNull);

      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(buttonAction(tester, 'Speak'), isNull);
      expect(buttonAction(tester, 'Play'), isNull);
      await tester.tap(find.text('Speak'), warnIfMissed: false);
      await tester.pump();
      expect(rig.mic.starts, 0);
      expect(find.text('Listening'), findsNothing);

      voice.complete(null);
      await tester.pump();
      await tester.pump();
      expect(buttonAction(tester, 'Speak'), isNotNull);
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      expect(rig.mic.starts, 1);
      expect(find.text('That’s it'), findsOneWidget);
    });

    testWidgets('a voice error is shown and still re-enables Speak',
        (tester) async {
      await Rig().open(tester, play: (_) async => 'No Japanese voice found.');
      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump();
      expect(find.text('No Japanese voice found.'), findsOneWidget);
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(buttonAction(tester, 'Play'), isNotNull);
    });

    testWidgets('stops its own voice before the microphone opens',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.open(tester);
      int? stopsAtMic;
      rig.mic.onStart = () => stopsAtMic = rig.tts.stops;
      final before = rig.tts.stops;
      await rig.tapSpeak(tester);
      await rig.settle(tester);
      expect(rig.mic.starts, 1);
      expect(stopsAtMic, before + 1,
          reason: 'the voice is stopped before the microphone opens');
      await rig.sayAndGoQuiet(tester);
      expect(find.text('That’s it'), findsOneWidget);
    });

    testWidgets(
        'Play holds Speak until the voice finishes, past the speak() cap',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.open(tester, realVoice: true);
      await tester.tap(find.text('Play'));
      await rig.settle(tester);
      expect(rig.tts.spoken, [firstSentence().kana]);
      expect(buttonAction(tester, 'Speak'), isNull);

      // speak() would have returned at its cap. speakAndWait waits for the voice.
      await tester.pump(SpeechService.speakWait + const Duration(seconds: 1));
      await rig.settle(tester);
      expect(buttonAction(tester, 'Speak'), isNull);
      expect(buttonAction(tester, 'Play'), isNull);

      rig.tts.finish();
      await rig.settle(tester);
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(buttonAction(tester, 'Play'), isNotNull);
    });

    testWidgets('Cancel on Checking drops the late result and frees Speak',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture))
        ..scoreGate = Completer<void>();
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      expect(find.text('Checking…'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await rig.settle(tester);
      expect(find.text('Checking…'), findsNothing);
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(buttonAction(tester, 'Next sentence'), isNotNull);

      // The score lands after the Cancel: it is dropped, shown nowhere and kept nowhere.
      rig.scoreGate!.complete();
      await rig.settle(tester);
      expect(find.text('That’s it'), findsNothing);
      expect(find.textContaining('Score '), findsNothing);
      expect(await tester.runAsync(savedAttempts), isEmpty);
      await walkToEnd(tester);
      expect(find.byKey(const ValueKey('speak-tally')), findsNothing);
      expect(find.text('Nothing was scored this time.'), findsOneWidget);
    });

    testWidgets('a late result after Cancel never lands on a newer attempt',
        (tester) async {
      final rig = Rig(reply: fixture(_badFixture))
        ..scoreGate = Completer<void>();
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      await tester.tap(find.text('Cancel'));
      await rig.settle(tester);

      // A new attempt opens the microphone while the old score is still out.
      await rig.tapSpeak(tester);
      await rig.settle(tester);
      expect(rig.mic.starts, 2);
      expect(find.text('Listening'), findsOneWidget);
      rig.scoreGate!.complete();
      await rig.settle(tester);
      // The old wrong score neither shows nor ends the new listen.
      expect(find.text('Not quite'), findsNothing);
      expect(find.text('Listening'), findsOneWidget);
      expect(rig.mic.open, isTrue);
      await tester.tap(find.text('Stop'));
      await rig.settle(tester);
    });

    testWidgets('the app going to the background retires the attempt',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await rig.feed(tester, _loud, 300);
      expect(rig.mic.open, isTrue);
      final stops = rig.tts.stops;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await rig.settle(tester);
      expect(rig.mic.open, isTrue,
          reason: 'inactive and hidden keep the listen');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await rig.settle(tester);
      expect(rig.mic.open, isFalse);
      expect(rig.tts.stops, greaterThan(stops));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await rig.settle(tester);
      expect(find.text('Listening'), findsNothing);
      expect(find.text('Can’t check this one'), findsNothing);
      expect(rig.sent, isEmpty);
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(await tester.runAsync(savedAttempts), isEmpty);
    });

    testWidgets('a pause while Checking drops the result that lands later',
        (tester) async {
      final rig = Rig(reply: fixture(_goodFixture))
        ..scoreGate = Completer<void>();
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      expect(find.text('Checking…'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      rig.scoreGate!.complete();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await rig.settle(tester);
      expect(find.text('That’s it'), findsNothing);
      expect(find.text('Checking…'), findsNothing);
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(await tester.runAsync(savedAttempts), isEmpty);
    });

    testWidgets('a Got it after an unverified result is kept with the attempt',
        (tester) async {
      final rig = Rig(error: Exception('offline'));
      await rig.speakOnce(tester);
      expect(find.text('Can’t check this one'), findsOneWidget);
      // Marked at once, before the attempt's own save has a chance to finish.
      await tester.tap(find.text('Got it'));
      await rig.settle(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await rig.settle(tester);

      var saved = await tester.runAsync(savedAttempts);
      expect(saved, hasLength(1));
      expect(saved!.single['verdict'], 'unverified');
      expect(saved.single['selfMark'], 'got_it');

      // A Missed it on the next sentence is kept too, on its own attempt.
      await tester.tap(find.text('Next sentence'));
      await tester.pump();
      await rig.tapSpeak(tester);
      await rig.sayAndGoQuiet(tester);
      await tester.tap(find.text('Missed it'));
      await rig.settle(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await rig.settle(tester);
      saved = await tester.runAsync(savedAttempts);
      expect(saved!.map((a) => a['selfMark']), ['got_it', 'missed_it']);
      expect(saved.last['sentence'], lesson26()[1].kana);
      expect(saved.map((a) => a['verdict']), everyElement('unverified'));

      // The marks read back, and Recent scores names them.
      final back = await tester.runAsync(SpeakScoreLog.load);
      expect(back!.map((a) => a.selfMark), [true, false]);
      expect(find.textContaining('unverified · got it'), findsOneWidget);
      expect(find.textContaining('unverified · missed it'), findsOneWidget);
    });

    testWidgets('a close result keeps its self-mark too', (tester) async {
      final rig = Rig(reply: goodWithScore(70));
      await rig.speakOnce(tester);
      await tester.tap(find.text('Missed it'));
      await rig.settle(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await rig.settle(tester);
      final saved = await tester.runAsync(savedAttempts);
      expect(saved!.single['verdict'], 'close');
      expect(saved.single['selfMark'], 'missed_it');
    });

    testWidgets('a scored attempt carries no self-mark', (tester) async {
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.speakOnce(tester);
      await rig.settle(tester);
      final saved = await tester.runAsync(savedAttempts);
      expect(saved!.single['verdict'], 'correct');
      expect(saved.single['selfMark'], isNull);
    });

    testWidgets(
        'the header shows one position counter, and the tally waits for the end',
        (tester) async {
      final all = lesson26();
      await Rig().open(tester);
      expect(positionOf(tester), '1 of ${all.length}');
      expect(find.textContaining('Sentence 1 of'), findsNothing);
      expect(find.byKey(const ValueKey('speak-tally')), findsNothing);
      await tester.tap(find.text('Next sentence'));
      await tester.pump();
      expect(positionOf(tester), '2 of ${all.length}');
    });

    testWidgets('the set ends on a tally card instead of wrapping silently',
        (tester) async {
      final all = lesson26();
      final rig = Rig(reply: fixture(_goodFixture));
      await rig.speakOnce(tester);
      for (var i = 1; i < all.length; i++) {
        await tester.tap(find.text('Next sentence'));
        await tester.pump();
      }
      // The last sentence offers Finish, not another Next.
      expect(find.text(all.last.kana), findsOneWidget);
      expect(positionOf(tester), '${all.length} of ${all.length}');
      expect(find.text('Next sentence'), findsNothing);
      await tester.tap(find.text('Finish'));
      await tester.pump();

      expect(find.text('End of the lesson'), findsOneWidget);
      expect(tallyOf(tester), '1 of 1');
      expect(find.text(firstSentence().kana), findsNothing);
      expect(find.text('Speak'), findsNothing);

      // Go again starts the set and its tally from the top.
      await tester.tap(find.text('Go again'));
      await tester.pump();
      expect(find.text(firstSentence().kana), findsOneWidget);
      expect(positionOf(tester), '1 of ${all.length}');
      await walkToEnd(tester);
      expect(find.byKey(const ValueKey('speak-tally')), findsNothing);
      expect(find.text('Nothing was scored this time.'), findsOneWidget);
    });

    testWidgets('Next does not move from sentence to sentence', (tester) async {
      final all = lesson26();
      await Rig().open(tester);
      final box = find.byKey(const ValueKey('speak-sentence-box'));
      final firstBox = tester.getSize(box);
      final firstNext = tester.getTopLeft(find.text('Next sentence'));
      // The minimum is in effect: at the wide test view every lesson 26 sentence is one
      // line of kana and one of English, so a box that merely fits its text would be
      // shorter than this. The box holds three lines of kana, the gap and two of English.
      final kanaLine = tester.getSize(find.text(all.first.kana)).height;
      final enLine = tester.getSize(find.text(all.first.en)).height;
      expect(firstBox.height, greaterThan(kanaLine + 6 + enLine));
      expect(firstBox.height, closeTo(3 * kanaLine + 6 + 2 * enLine, 0.01));
      for (var i = 1; i < all.length - 1; i++) {
        await tester.tap(find.text('Next sentence'));
        await tester.pump();
        expect(tester.getSize(box).height, firstBox.height,
            reason: 'sentence ${i + 1}: ${all[i].kana}');
        expect(tester.getTopLeft(find.text('Next sentence')), firstNext,
            reason: 'sentence ${i + 1}: ${all[i].kana}');
      }
    });

    testWidgets('a sentence taller than the minimum grows the box',
        (tester) async {
      // The other arm of the minimum: it is a floor, not a fixed height. At a phone
      // width lesson 26's longest sentence wraps past three lines of kana and two of
      // English, and the box must follow its text rather than clip it.
      final all = lesson26();
      await Rig().open(tester);
      final box = find.byKey(const ValueKey('speak-sentence-box'));
      final floor = tester.getSize(box).height;
      tester.view.physicalSize = const Size(360, 12000);
      await tester.pump();
      var grew = 0;
      for (var i = 0; i < all.length; i++) {
        if (i > 0) {
          await tester.tap(find.text('Next sentence'));
          await tester.pump();
        }
        final content = tester.getSize(find.text(all[i].kana)).height +
            6 +
            tester.getSize(find.text(all[i].en)).height;
        if (content > floor) grew++;
        expect(tester.getSize(box).height,
            closeTo(content > floor ? content : floor, 0.01),
            reason: 'sentence ${i + 1}: ${all[i].kana}');
        expect(tester.takeException(), isNull,
            reason: 'sentence ${i + 1}: ${all[i].kana}');
      }
      expect(grew, greaterThan(0),
          reason: 'no lesson 26 sentence outgrows the minimum at 360 px');
    });

    testWidgets('a combined example shows each form with its own English',
        (tester) async {
      final doc = readLessonFile();
      final lesson = (doc['grammar'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((l) => l['lesson'] == 31);
      final all = lessonSentences(lesson);
      final i = all.indexWhere((x) => x.kana == 'たべよう');
      expect(i, isNonNegative);
      await Rig().open(tester, lesson: 31);
      for (var k = 0; k < i; k++) {
        await tester.tap(find.text('Next sentence'));
        await tester.pump();
      }
      expect(find.text('たべよう'), findsOneWidget);
      expect(find.text("let's eat"), findsOneWidget);
      expect(find.textContaining("let's go /"), findsNothing);
    });

    testWidgets('Next moves to the second sentence', (tester) async {
      final second = lesson26()[1];
      await Rig().open(tester);
      await tester.tap(find.text('Next sentence'));
      await tester.pump();
      expect(find.text(second.kana), findsOneWidget);
    });
  });
}
