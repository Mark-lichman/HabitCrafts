// Tests for the per-lesson speaking drill (PIN-6, PIN-2, PIN-10).
//
// The recogniser is replaced by a fake that returns a fixed transcript, but the
// verdict still comes from the real `SpeechService.judge()`, so these tests check the
// judging the drill ships with, over the shipped lesson file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart';
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

/// The first lesson 26 sentence with no kanji at all, with its index. Chosen from the
/// data, like [kanjiSentence], so it holds whichever words a later twin rewrite keeps in
/// hiragana.
({int index, SpeakSentence s}) kanaOnlySentence() {
  final all = lesson26();
  final i = all.indexWhere((x) => x.surface == x.kana);
  expect(i, isNonNegative, reason: 'lesson 26 has no sentence without kanji');
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

/// What the drill passes judge() as kanji forms for [s].
List<String> formsOf(SpeakSentence s) =>
    s.surface == s.kana ? const [] : [s.surface];

class FakeEar {
  FakeEar(this.heard);
  final String heard;
  final calls = <({String kana, List<String> kanjiForms})>[];

  /// When set, a listen waits here before it answers, so a test can act mid-listen.
  Completer<void>? gate;

  Future<SpeechResult> listen(String kana, List<String> kanjiForms) async {
    calls.add((kana: kana, kanjiForms: kanjiForms));
    if (gate != null) await gate!.future;
    return SpeechResult(
        heard, SpeechService.judge(heard, kana, kanjiForms: kanjiForms));
  }
}

/// Opens lesson 26, moves [index] sentences on, and speaks [heard] once.
Future<FakeEar> speakOnce(WidgetTester tester, String heard,
    {int index = 0}) async {
  final ear = FakeEar(heard);
  await pumpStudyScreen(
    tester,
    QuietRoomSpeakWidget(
      lesson: 26,
      listen: ear.listen,
      play: (_) async => null,
    ),
  );
  for (var i = 0; i < index; i++) {
    await tester.tap(find.text('Next sentence'));
    await tester.pump();
  }
  await tester.tap(find.text('Speak'));
  await tester.pump();
  await tester.pump();
  return ear;
}

/// Opens lesson 26 and starts a listen that waits on the returned ear's gate.
Future<FakeEar> speakPending(WidgetTester tester, String heard) async {
  final ear = FakeEar(heard)..gate = Completer<void>();
  await pumpStudyScreen(
    tester,
    QuietRoomSpeakWidget(
      lesson: 26,
      listen: ear.listen,
      play: (_) async => null,
    ),
  );
  await tester.tap(find.text('Speak'));
  await tester.pump();
  expect(find.text('Listening'), findsOneWidget);
  return ear;
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

    test('walks point by point, one point\'s practice before the next point\'s examples',
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

  group('speakVerdict', () {
    test('never marks an uncomparable transcript wrong', () {
      expect(speakVerdict(Judgement.wrong, 'atama ga itai'),
          SpeakVerdict.selfCheck);
      expect(speakVerdict(Judgement.wrong, '3じです'), SpeakVerdict.selfCheck);
      expect(speakVerdict(Judgement.unverified, '猫です'), SpeakVerdict.selfCheck);
      expect(speakVerdict(Judgement.wrong, 'さかなです'), SpeakVerdict.wrong);
      expect(speakVerdict(Judgement.close, '頭が'), SpeakVerdict.close);
      expect(speakVerdict(Judgement.correct, 'あたま'), SpeakVerdict.right);
      expect(speakVerdict(Judgement.unverified, ''), SpeakVerdict.nothing);
    });
  });

  group('the drill screen', () {
    testWidgets('plays the sentence and passes its kanji surface to judge()',
        (tester) async {
      final (index: index, s: s) = kanjiSentence();
      final played = <String>[];
      final ear = FakeEar(bare(s.kana));
      await pumpStudyScreen(
        tester,
        QuietRoomSpeakWidget(
          lesson: 26,
          listen: ear.listen,
          play: (text) async {
            played.add(text);
            return null;
          },
        ),
      );
      expect(find.text(firstSentence().kana), findsOneWidget);
      for (var i = 0; i < index; i++) {
        await tester.tap(find.text('Next sentence'));
        await tester.pump();
      }
      expect(find.text(s.kana), findsOneWidget);

      await tester.tap(find.text('Play'));
      await tester.pump();
      expect(played, [s.kana]);

      await tester.tap(find.text('Speak'));
      await tester.pump();
      await tester.pump();
      expect(ear.calls.single.kana, s.kana);
      expect(ear.calls.single.kanjiForms, contains(s.surface));
    });

    testWidgets('an exact hiragana match is marked right', (tester) async {
      await speakOnce(tester, bare(firstSentence().kana));
      expect(find.text('That’s it'), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.text('Got it'), findsNothing);
    });

    testWidgets('an exact kanji match is marked right', (tester) async {
      final (index: index, s: s) = kanjiSentence();
      await speakOnce(tester, bare(s.surface), index: index);
      expect(find.text('That’s it'), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
      // The right card adds the kanji surface under the kana sentence card.
      expect(find.text(s.surface), findsOneWidget);
      expect(find.text(s.kana), findsOneWidget);
    });

    testWidgets('a right card never repeats a sentence that has no kanji',
        (tester) async {
      final (index: index, s: s) = kanaOnlySentence();
      await speakOnce(tester, bare(s.kana), index: index);
      expect(find.text('That’s it'), findsOneWidget);
      // Once on the sentence card, and not again on the right card.
      expect(find.text(s.kana), findsOneWidget);
    });

    testWidgets('Speak and Play are disabled while the sentence plays',
        (tester) async {
      final s = firstSentence();
      final ear = FakeEar(bare(s.kana));
      final voice = Completer<String?>();
      await pumpStudyScreen(
        tester,
        QuietRoomSpeakWidget(
          lesson: 26,
          listen: ear.listen,
          play: (_) => voice.future,
        ),
      );
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(buttonAction(tester, 'Play'), isNotNull);

      await tester.tap(find.text('Play'));
      await tester.pump();
      // The buttons themselves are the oracle, not the fake ear.
      expect(buttonAction(tester, 'Speak'), isNull);
      expect(buttonAction(tester, 'Play'), isNull);
      await tester.tap(find.text('Speak'), warnIfMissed: false);
      await tester.pump();
      expect(ear.calls, isEmpty);
      expect(find.text('Listening'), findsNothing);

      voice.complete(null);
      await tester.pump();
      await tester.pump();
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(buttonAction(tester, 'Play'), isNotNull);
      await tester.tap(find.text('Speak'));
      await tester.pump();
      await tester.pump();
      expect(ear.calls, hasLength(1));
      expect(find.text('That’s it'), findsOneWidget);
    });

    testWidgets('a voice error is shown and still re-enables Speak',
        (tester) async {
      final ear = FakeEar(bare(firstSentence().kana));
      await pumpStudyScreen(
        tester,
        QuietRoomSpeakWidget(
          lesson: 26,
          listen: ear.listen,
          play: (_) async => 'No Japanese voice found.',
        ),
      );
      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump();
      expect(find.text('No Japanese voice found.'), findsOneWidget);
      expect(buttonAction(tester, 'Speak'), isNotNull);
      expect(buttonAction(tester, 'Play'), isNotNull);
    });

    testWidgets(
        'Next is ignored mid-listen, so the result lands on its sentence',
        (tester) async {
      final first = firstSentence();
      final second = lesson26()[1];
      final ear = await speakPending(tester, bare(first.kana));

      await tester.tap(find.text('Next sentence'), warnIfMissed: false);
      await tester.pump();
      expect(find.text(first.kana), findsOneWidget);
      expect(find.text(second.kana), findsNothing);

      ear.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('That’s it'), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.text(first.kana), findsOneWidget);
    });

    testWidgets('Stop drops the result of the listen it cut short',
        (tester) async {
      final ear = await speakPending(tester, bare(firstSentence().kana));

      await tester.tap(find.text('Stop'));
      await tester.pump();
      expect(find.text('Listening'), findsNothing);
      expect(find.text('Speak'), findsOneWidget);

      ear.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('That’s it'), findsNothing);
      expect(find.text('Didn’t catch that'), findsNothing);
      expect(find.text('Say it'), findsOneWidget);
      expect(find.text('Speak'), findsOneWidget);
    });

    testWidgets(
        'a Close result is amber, highlights the match, then self-check',
        (tester) async {
      final s = firstSentence();
      // The opening half of the kanji sentence: contained in it, so judge() says close.
      final part = bare(s.surface).substring(0, 3);
      await speakOnce(tester, part);

      final head = tester.widget<Text>(find.text('Close'));
      final t = QuietRoomTokens.of(tester.element(find.text('Close')));
      expect(head.style?.color, t.amber700);
      expect(find.text('That’s it'), findsNothing);
      expect(find.text('Not quite'), findsNothing);

      // The heard text is shown, and its matching part carries the highlight.
      final heard =
          tester.widget<Text>(find.byKey(const ValueKey('speak-heard')));
      final spans = <TextSpan>[];
      heard.textSpan!.visitChildren((s) {
        if (s is TextSpan && s.text != null) spans.add(s);
        return true;
      });
      expect(spans.map((s) => s.text).join(), part);
      final lit =
          spans.where((s) => s.style?.backgroundColor == t.amberSurface);
      expect(lit.map((s) => s.text).join(), part);

      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Missed it'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(find.text('1 of 1'), findsOneWidget);
    });

    testWidgets('a kanji transcript it cannot compare goes to self-check',
        (tester) async {
      await speakOnce(tester, '猫です');
      expect(find.text('Can’t check this one'), findsOneWidget);
      expect(find.textContaining('猫です'), findsWidgets);
      expect(find.text('Not quite'), findsNothing);
      await tester.tap(find.text('Missed it'));
      await tester.pump();
      expect(find.text('0 of 1'), findsOneWidget);
      expect(find.text('Not quite'), findsNothing);
    });

    testWidgets('a wrong verdict on an uncomparable transcript is self-check',
        (tester) async {
      final ear = await speakOnce(tester, 'atama ga itai');
      // judge() itself calls this wrong; the drill must not.
      expect(
          SpeechService.judge('atama ga itai', ear.calls.single.kana,
              kanjiForms: ear.calls.single.kanjiForms),
          Judgement.wrong);
      expect(find.text('Not quite'), findsNothing);
      expect(find.text('Can’t check this one'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets('a hiragana transcript of another sentence is wrong',
        (tester) async {
      await speakOnce(tester, 'さかなを たべました');
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.text('0 of 1'), findsOneWidget);
    });

    testWidgets('Next moves to the second sentence', (tester) async {
      final second = lesson26()[1];
      await pumpStudyScreen(
        tester,
        QuietRoomSpeakWidget(
          lesson: 26,
          listen: FakeEar('').listen,
          play: (_) async => null,
        ),
      );
      await tester.tap(find.text('Next sentence'));
      await tester.pump();
      expect(find.text(second.kana), findsOneWidget);
    });
  });
}
