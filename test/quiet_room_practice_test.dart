// Tests for the vocabulary speaking screen (plan 2026-11-02, Task 2).
//
// The screen runs a real SpeechService on fake engines (SpeechService.withEngines), so the
// listen, Stop, pause and error paths are the ones the screen ships with. The deck is the real
// lesson 25 of assets/lessons/jp_lessons.json, read through the screen's own asset load.
//
// What is pinned (End state 11, PIN-3):
//   * an unverified listen never counts by itself; it asks Got it or Missed it, as the speak
//     drill does, and the no-microphone case says why; Got it is right and Missed it is
//     missed (PIN-13);
//   * a speech "close" is with help, never right;
//   * the result handed on carries the hint level and the revealed flag;
//   * Next is disabled while listening, and Stop or a pause drops the listen's result;
//   * a raw recogniser code reaches the screen as a plain sentence;
//   * the deck is shuffled without replacement, with a position and an end, and Go again
//     starts every count of the tally from zero.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_practice/quiet_room_practice_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart';

import 'jp_screen_harness.dart';
import 'speech_service_test.dart' show FakeStt, FakeTts;

const _lesson = 25;
const _lessonFile = 'assets/lessons/jp_lessons.json';

/// Lesson 25's illustrated words, read straight from disk, keyed by image path.
Map<String, Map<String, dynamic>> lessonWords() {
  final d =
      json.decode(File(_lessonFile).readAsStringSync()) as Map<String, dynamic>;
  final l = (d['lessons'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((l) => l['lesson'] == _lesson);
  return {
    for (final i in (l['items'] as List).cast<Map<String, dynamic>>())
      if (i['image'] != null) i['image'] as String: i,
  };
}

class Rig {
  Rig({bool mic = true}) {
    service = SpeechService.withEngines(
        stt: stt, tts: tts, micPermission: () async => mic);
  }

  final FakeStt stt = FakeStt();
  final FakeTts tts = FakeTts();
  late final SpeechService service;
  final List<PracticeResult> results = [];

  Future<void> open(WidgetTester tester) async {
    // A future cached by an earlier test's fake clock never reaches this one: load afresh,
    // in the real zone, before the screen asks for it.
    rootBundle.evict(_lessonFile);
    await tester.runAsync(() => rootBundle.loadString(_lessonFile));
    await pumpStudyScreen(
      tester,
      QuietRoomPracticeWidget(
        lesson: _lesson,
        speech: service,
        random: Random(7),
        onResult: results.add,
      ),
    );
    // The lesson file is large, so its load decodes off the fake clock.
    for (var i = 0;
        i < 50 && find.text('What is this?').evaluate().isEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('What is this?'), findsOneWidget);
  }

  /// The image path of the word on screen.
  String shownImage(WidgetTester tester) =>
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

  /// The kana of the word on screen.
  String shownKana(WidgetTester tester) =>
      lessonWords()[shownImage(tester)]!['kana'] as String;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
  }

  Future<void> tapSpeak(WidgetTester tester) async {
    await tester.tap(find.text('Speak'));
    await settle(tester);
  }

  /// Speaks, and the recogniser hears [heard].
  Future<void> say(WidgetTester tester, String heard) async {
    await tapSpeak(tester);
    stt.hear([heard]);
    await settle(tester);
  }

  Future<void> next(WidgetTester tester) async {
    final label =
        find.text('Next word').evaluate().isNotEmpty ? 'Next word' : 'Finish';
    await tester.tap(find.text(label));
    await settle(tester);
  }
}

/// The Next button's action, read from the button itself.
VoidCallback? nextAction(WidgetTester tester) => tester
    .widget<TextButton>(find.ancestor(
        of: find.text('Next word'), matching: find.byType(TextButton)))
    .onPressed;

String tallyText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('practice-tally'))).data!;

/// Walks to the end of the deck and returns the tally line.
Future<String> finish(WidgetTester tester, Rig rig) async {
  while (find.text('Go again').evaluate().isEmpty) {
    await rig.next(tester);
  }
  return tallyText(tester);
}

void main() {
  group('PracticeResult.tally', () {
    PracticeResult r(Judgement j,
            {int hint = 0, bool revealed = false, bool? mark}) =>
        PracticeResult(
            word: const {'kana': 'ほん'},
            speech: SpeechResult('x', j),
            hintLevel: hint,
            revealed: revealed,
            selfMark: mark);

    test('only a clean correct is right', () {
      expect(r(Judgement.correct).tally, PracticeTally.right);
      expect(r(Judgement.correct, hint: 1).tally, PracticeTally.hinted);
      expect(r(Judgement.close).tally, PracticeTally.hinted);
      expect(r(Judgement.wrong).tally, PracticeTally.missed);
    });

    test('an answer given while it was showing is missed', () {
      expect(r(Judgement.correct, hint: 3, revealed: true).tally,
          PracticeTally.missed);
      expect(r(Judgement.close, hint: 3, revealed: true).tally,
          PracticeTally.missed);
    });

    test('unverified counts only through the learner mark', () {
      expect(r(Judgement.unverified).tally, PracticeTally.uncounted);
      expect(r(Judgement.unverified, mark: true).tally, PracticeTally.right);
      expect(r(Judgement.unverified, mark: false).tally, PracticeTally.missed);
      expect(r(Judgement.unverified, hint: 1, mark: true).tally,
          PracticeTally.hinted);
    });
  });

  group('practice screen', () {
    testWidgets('a correct answer with no hint is right', (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await rig.say(tester, rig.shownKana(tester));
      expect(find.text('That’s it'), findsOneWidget);
      expect(rig.results.single.tally, PracticeTally.right);
      expect(rig.results.single.hintLevel, 0);
      expect(rig.results.single.revealed, isFalse);
      expect(await finish(tester, rig), startsWith('1 on your own'));
    });

    testWidgets('a close answer is with help, not right (PIN-3)',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      // A transcript that contains the answer and more judges close.
      await rig.say(tester, '${rig.shownKana(tester)}です');
      expect(rig.results.single.speech.judgement, Judgement.close);
      expect(rig.results.single.tally, PracticeTally.hinted);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Close enough'), findsNothing);
      expect(find.byKey(const ValueKey('practice-tally-note')), findsOneWidget);
      expect(
          await finish(tester, rig), '0 on your own · 1 with help · 0 missed');
    });

    testWidgets('the result carries the hint level and the revealed flag',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await tester.tap(find.text('Give me a hint'));
      await tester.pump();
      await rig.say(tester, rig.shownKana(tester));
      expect(rig.results.last.hintLevel, 1);
      expect(rig.results.last.revealed, isFalse);
      expect(rig.results.last.tally, PracticeTally.hinted);

      // Down the whole ladder: the answer is showing.
      while (find.text('More').evaluate().isNotEmpty) {
        await tester.tap(find.text('More'));
        await tester.pump();
      }
      await rig.say(tester, rig.shownKana(tester));
      final r = rig.results.last;
      expect(r.revealed, isTrue);
      expect(r.hintLevel, practiceHintSteps(r.word).length);
      expect(r.tally, PracticeTally.missed);
    });

    testWidgets('no microphone asks the self-check and never counts by itself',
        (tester) async {
      final rig = Rig(mic: false);
      await rig.open(tester);
      await rig.tapSpeak(tester);
      expect(rig.stt.listens, 0);
      expect(find.text('Can’t check this one'), findsOneWidget);
      expect(find.textContaining('Microphone permission'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Missed it'), findsOneWidget);
      expect(rig.results.single.tally, PracticeTally.uncounted);

      await tester.tap(find.text('Got it'));
      await rig.settle(tester);
      expect(find.text('Marked as said.'), findsOneWidget);
      expect(find.text('Got it'), findsNothing);
      expect(rig.results.last.selfMark, isTrue);
      expect(rig.results.last.tally, PracticeTally.right);
      expect(await finish(tester, rig), startsWith('1 on your own'));
    });

    testWidgets('Missed it after an unverified listen is missed (PIN-13)',
        (tester) async {
      final rig = Rig(mic: false);
      await rig.open(tester);
      await rig.tapSpeak(tester);
      expect(find.text('Missed it'), findsOneWidget);

      await tester.tap(find.text('Missed it'));
      await rig.settle(tester);
      expect(find.text('Marked to try again.'), findsOneWidget);
      expect(find.text('Missed it'), findsNothing);
      expect(rig.results.last.selfMark, isFalse);
      expect(rig.results.last.tally, PracticeTally.missed);
      expect(
          await finish(tester, rig), '0 on your own · 0 with help · 1 missed');
    });

    testWidgets('an unmarked unverified listen leaves the tally at zero',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      // A kanji transcript that matches no kanji form cannot be checked.
      await rig.say(tester, '漢');
      expect(rig.results.single.speech.judgement, Judgement.unverified);
      expect(find.text('Can’t check this one'), findsOneWidget);
      expect(
          await finish(tester, rig), '0 on your own · 0 with help · 0 missed');
    });

    testWidgets('Next is disabled while listening, and Stop drops the result',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      expect(nextAction(tester), isNotNull);
      await rig.tapSpeak(tester);
      expect(find.text('Stop'), findsOneWidget);
      expect(nextAction(tester), isNull);

      await tester.tap(find.text('Stop'));
      await rig.settle(tester);
      expect(find.text('Stop'), findsNothing);
      expect(nextAction(tester), isNotNull);
      // A result that arrives after Stop is not shown and not counted.
      rig.stt.hear([rig.shownKana(tester)]);
      await rig.settle(tester);
      expect(find.byKey(const ValueKey('practice-verdict')), findsNothing);
      expect(rig.results, isEmpty);
      expect(rig.stt.cancels, greaterThanOrEqualTo(1));
    });

    testWidgets('Speak stops the app voice before the microphone opens',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      final before = rig.tts.stops;
      // Read at the moment the recogniser opens, so a stop that lands later cannot pass.
      int? stopsWhenMicOpened;
      rig.stt.onListen = () => stopsWhenMicOpened = rig.tts.stops;
      await rig.tapSpeak(tester);
      expect(stopsWhenMicOpened, before + 1,
          reason: 'the voice is stopped before the microphone opens');
      expect(rig.tts.stops, before + 1);
      expect(rig.stt.listens, 1);
      await tester.tap(find.text('Stop'));
      await rig.settle(tester);
    });

    testWidgets('the app going to the background cancels the listen',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await rig.tapSpeak(tester);
      expect(find.text('Stop'), findsOneWidget);
      // Inactive and hidden come first on the way down and must not end the listen: a
      // permission dialog or a notification shade makes the app inactive too.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await rig.settle(tester);
      expect(find.text('Stop'), findsOneWidget);
      expect(rig.stt.cancels, 0);

      // Paused is the state that ends it. The recogniser is cancelled on the spot, before
      // any frame: hidden switched frames off, so the screen is checked after resumed.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(rig.stt.cancels, greaterThanOrEqualTo(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await rig.settle(tester);
      expect(find.text('Stop'), findsNothing);
      expect(rig.results, isEmpty);
    });

    testWidgets('a raw recogniser code shows as a plain sentence',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await rig.tapSpeak(tester);
      rig.stt.fail('error_network');
      await rig.settle(tester);
      final msg = tester
          .widget<Text>(find.byKey(const ValueKey('practice-mic-error')))
          .data!;
      expect(msg, SpeechService.describeError('error_network'));
      expect(find.textContaining('error_'), findsNothing);
    });

    testWidgets('the deck shows every word once, with a position and an end',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      final words = lessonWords();
      final seen = <String>[];
      for (var i = 1; i <= words.length; i++) {
        expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('practice-position')))
                .data,
            '$i of ${words.length}');
        seen.add(rig.shownImage(tester));
        if (i == words.length) expect(find.text('Finish'), findsOneWidget);
        await rig.next(tester);
      }
      expect(seen.toSet(), words.keys.toSet(),
          reason: 'shuffled without replacement');
      expect(seen.length, words.length);
      // Random(7) fixes the order, and that order is not the file's.
      expect(seen, isNot(orderedEquals(words.keys.toList())),
          reason: 'the deck is shuffled');
      expect(find.text('That’s all ${words.length} words'), findsOneWidget);
      expect(find.text('Go again'), findsOneWidget);

      await tester.tap(find.text('Go again'));
      await rig.settle(tester);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('practice-position')))
              .data,
          '1 of ${words.length}');
    });

    testWidgets('Go again starts every count of the tally from zero',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      // One of each on the first pass, so a reset that skips any one count is visible.
      await rig.say(tester, rig.shownKana(tester));
      expect(rig.results.last.tally, PracticeTally.right);
      await rig.next(tester);
      await rig.say(tester, '${rig.shownKana(tester)}です');
      expect(rig.results.last.tally, PracticeTally.hinted);
      await rig.next(tester);
      // A plain-kana mismatch cannot be checked by itself, so the miss is the learner's mark
      // (PIN-13).
      await rig.say(tester, 'ぱぱぱ');
      await tester.tap(find.text('Missed it'));
      await rig.settle(tester);
      expect(rig.results.last.tally, PracticeTally.missed);
      expect(
          await finish(tester, rig), '1 on your own · 1 with help · 1 missed');

      await tester.tap(find.text('Go again'));
      await rig.settle(tester);
      expect(find.byKey(const ValueKey('practice-verdict')), findsNothing,
          reason: 'the first pass’s card does not carry over');
      await rig.say(tester, 'ぱぱぱ');
      await tester.tap(find.text('Missed it'));
      await rig.settle(tester);
      // Each unverified listen hands on its uncounted result and then the mark, so the first
      // pass handed on four results and the second pass two more.
      expect(rig.results, hasLength(6));
      expect(rig.results.last.tally, PracticeTally.missed);
      expect(
          await finish(tester, rig), '0 on your own · 0 with help · 1 missed',
          reason: 'no count from the first pass carries over');
    });
  });
}
