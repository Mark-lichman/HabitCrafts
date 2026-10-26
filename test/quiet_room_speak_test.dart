// Tests for the per-lesson speaking drill (PIN-6, PIN-2, PIN-10).
//
// The recogniser is replaced by a fake that returns a fixed transcript, but the
// verdict still comes from the real `SpeechService.judge()`, so these tests check the
// judging the drill ships with, over the shipped lesson file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart';
import 'package:habit_craft/flutter_flow/quiet_room.dart';

import 'jp_screen_harness.dart';

/// The drill's first sentence: lesson 26, first point, first example.
({String kana, String surface}) firstSentence() {
  final doc = readLessonFile();
  final lesson = (doc['grammar'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((l) => l['lesson'] == 26);
  final ex = ((lesson['points'] as List).first['examples'] as List).first
      as Map<String, dynamic>;
  return (
    kana: ex['jp'] as String,
    surface: rubySurface(ex['jp_ruby'] as String),
  );
}

/// No spaces or punctuation, the way a recogniser returns a sentence.
String bare(String s) => s.replaceAll(RegExp(r'[\s、。！？]'), '');

class FakeEar {
  FakeEar(this.heard);
  final String heard;
  final calls = <({String kana, List<String> kanjiForms})>[];

  Future<SpeechResult> listen(String kana, List<String> kanjiForms) async {
    calls.add((kana: kana, kanjiForms: kanjiForms));
    return SpeechResult(
        heard, SpeechService.judge(heard, kana, kanjiForms: kanjiForms));
  }
}

Future<FakeEar> speakOnce(WidgetTester tester, String heard) async {
  final ear = FakeEar(heard);
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
  await tester.pump();
  return ear;
}

void main() {
  group('rubySurface', () {
    test('drops every reading and keeps okurigana', () {
      expect(rubySurface('買{か}い物{もの}に 行{い}きます。'), '買い物に 行きます。');
      expect(rubySurface('あした テストが あるんです。'), 'あした テストが あるんです。');
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
  });

  group('judge on a whole sentence', () {
    test('an exact hiragana sentence is correct', () {
      final s = firstSentence();
      expect(SpeechService.judge(bare(s.kana), s.kana, kanjiForms: [s.surface]),
          Judgement.correct);
    });

    test('an exact kanji sentence is correct without its spaces or 。', () {
      final s = firstSentence();
      expect(s.surface, isNot(s.kana));
      expect(
          SpeechService.judge(bare(s.surface), s.kana, kanjiForms: [s.surface]),
          Judgement.correct);
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
      final s = firstSentence();
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
      await speakOnce(tester, bare(firstSentence().surface));
      expect(find.text('That’s it'), findsOneWidget);
      expect(find.text('1 of 1'), findsOneWidget);
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
      final doc = readLessonFile();
      final lesson = (doc['grammar'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((l) => l['lesson'] == 26);
      final second = lessonSentences(lesson)[1];
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
