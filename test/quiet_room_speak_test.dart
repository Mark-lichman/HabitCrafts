// Tests for the per-lesson speaking drill (plan 2026-10-27, Task 3).
//
// The drill checks a sentence BY SOUND through PronunciationService (PIN-1). These tests
// build the real service with fake seams: a fake microphone fed PCM chunks, a fake clock,
// a fake Firebase auth behind the real ensureCaller() (PIN-9), and a fake function call
// that returns the committed Azure replies. So the verdict, the automatic stop (PIN-5,
// PIN-7) and the letter colors (PIN-8) all come from the code the drill ships with.
//
// The lessonSentences and judge() groups still pin the lesson data the drill walks.

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

  bool get open => ctl != null && !ctl!.isClosed;

  @override
  Future<Stream<Uint8List>?> start(int sampleRate) async {
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

  Widget widget({SpeakPlay? play}) => QuietRoomSpeakWidget(
        lesson: 26,
        newService: make,
        callerAuth: auth,
        play: play ?? (_) async => null,
      );

  Future<void> open(WidgetTester tester, {SpeakPlay? play}) =>
      pumpStudyScreen(tester, widget(play: play));

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
      expect(find.text('1 of 1'), findsOneWidget);
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
    });

    testWidgets(
        'a wrong score shows the score, colors each letter by its syllable and '
        'strikes the inserted word', (tester) async {
      final rig = Rig(reply: fixture(_badFixture));
      await rig.speakOnce(tester);
      final t = tokensOf(tester);

      expect(find.text('Not quite'), findsOneWidget);
      expect(find.text('Score 44.8'), findsOneWidget);
      expect(find.text('0 of 1'), findsOneWidget);
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
      expect(find.text('Say it'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.text('Marked as said.'), findsOneWidget);
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
      expect(find.text('0 of 1'), findsOneWidget);
      expect(find.text('Not quite'), findsNothing);
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
      expect(find.text('Say it'), findsOneWidget);
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

    testWidgets('Next moves to the second sentence', (tester) async {
      final second = lesson26()[1];
      await Rig().open(tester);
      await tester.tap(find.text('Next sentence'));
      await tester.pump();
      expect(find.text(second.kana), findsOneWidget);
    });
  });
}
