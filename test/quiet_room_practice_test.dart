// Tests for the vocabulary speaking screen (plan 2026-11-02, Tasks 2 and 10).
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
//   * the result handed on carries the hint level and the revealed flag, after a
//     self-mark too;
//   * Next is disabled while listening, and Stop or a pause drops the listen's result,
//     even a Stop tapped while the app voice is still stopping;
//   * a raw recogniser code reaches the screen as a plain sentence;
//   * the deck is shuffled without replacement, with a position and an end, and Go again
//     starts every count of the tally from zero;
//   * each word counts once on the end card: a second listen leaves the tally alone (ASK-1).
//
// The attempt log (Task 10, D17): every verdict, self-mark and skip writes one Attempt to the
// injected JpStoreMemory with its hint level and revealed flag. Correct is clear, close is
// hinted, a hint is hinted, the whole answer showing writes one wrong per word, and later
// listens and the mark are unscored (ASK-4), unverified is unscored, a Got it over it is self
// and a Missed it is wrong, a skip is unscored, and a second listen is hinted.
// An answer on a word that is not due is early (PIN-14).
//
// The transcript's verdict never counts (plan 2026-11-06, Task 5, PIN-2): an attempt graded
// from a correct, close or wrong listen is on the Say-it track and moves no schedule and no
// mastery, even on a due word; a self-mark, a skip and the reveal wrong still count (ASK-4).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';
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

/// A word item as the catalog defines it: three templates, two production probes.
class _Word implements ItemDefLike {
  const _Word(this.id);

  @override
  final String id;
  @override
  ItemKind get kind => ItemKind.word;
  @override
  int get templateCount => 3;
  @override
  bool get hasProductionProbe => true;
  @override
  int get probeCount => 3;
}

/// A store whose attempt write always fails, as a disk I/O error would.
class _FailingStore extends JpStoreMemory {
  @override
  Future<Attempt> appendAttempt(Attempt attempt,
          {SrsState? srs, MasteryState? mastery}) async =>
      throw StateError('disk full');
}

/// 10:00 on 2026-11-03, well inside one local day.
final DateTime _now = DateTime(2026, 11, 3, 10);

class Rig {
  Rig({bool mic = true, JpStoreMemory? store})
      : store = store ?? JpStoreMemory() {
    service = SpeechService.withEngines(
        stt: stt, tts: tts, micPermission: () async => mic);
  }

  final FakeStt stt = FakeStt();
  final FakeTts tts = FakeTts();
  late final SpeechService service;
  final List<PracticeResult> results = [];
  final JpStoreMemory store;
  final FixedClock clock = FixedClock(_now);

  /// The attempts the screen has written, oldest first.
  Future<List<Attempt>> attempts(WidgetTester tester) async {
    await settle(tester);
    return store.attempts();
  }

  /// The item id of the word on screen.
  String shownId(WidgetTester tester) =>
      practiceItemId(lessonWords()[shownImage(tester)]!);

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
        store: store,
        items: _Word.new,
        clock: clock,
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

    testWidgets(
        'a self-mark keeps the hint level and the revealed flag (PIN-3)',
        (tester) async {
      final rig = Rig(mic: false);
      await rig.open(tester);
      await tester.tap(find.text('Give me a hint'));
      await tester.pump();
      await rig.tapSpeak(tester);
      await tester.tap(find.text('Got it'));
      await rig.settle(tester);
      expect(rig.results.last.selfMark, isTrue);
      expect(rig.results.last.hintLevel, 1);
      expect(rig.results.last.revealed, isFalse);
      expect(rig.results.last.tally, PracticeTally.hinted);

      // Down the whole ladder: a Got it with the answer showing is missed.
      await rig.next(tester);
      await tester.tap(find.text('Give me a hint'));
      await tester.pump();
      while (find.text('More').evaluate().isNotEmpty) {
        await tester.tap(find.text('More'));
        await tester.pump();
      }
      await rig.tapSpeak(tester);
      await tester.tap(find.text('Got it'));
      await rig.settle(tester);
      final r = rig.results.last;
      expect(r.selfMark, isTrue);
      expect(r.revealed, isTrue);
      expect(r.hintLevel, practiceHintSteps(r.word).length);
      expect(r.tally, PracticeTally.missed);
      expect(
          await finish(tester, rig), '0 on your own · 1 with help · 1 missed');
    });

    testWidgets('a Stop while the voice is stopping never opens the microphone',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      rig.tts.stopGate = Completer<void>();
      await rig.tapSpeak(tester);
      expect(find.text('Stop'), findsOneWidget);
      expect(rig.stt.listens, 0);

      await tester.tap(find.text('Stop'));
      await rig.settle(tester);
      rig.tts.stopGate!.complete();
      await rig.settle(tester);
      expect(rig.stt.listens, 0,
          reason: 'the retired attempt must not open the microphone');
      expect(find.text('Stop'), findsNothing);
      expect(find.byKey(const ValueKey('practice-verdict')), findsNothing);
      expect(rig.results, isEmpty);
      expect(find.text('Speak'), findsOneWidget);
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

    testWidgets(
        'a second listen on the same word leaves the tally alone (ASK-1)',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await rig.say(tester, rig.shownKana(tester));
      expect(rig.results.last.tally, PracticeTally.right);
      // A second listen on the same word, this time close: it is shown and logged, but the
      // word already counted.
      await rig.say(tester, '${rig.shownKana(tester)}です');
      expect(rig.results.last.tally, PracticeTally.hinted);
      expect(find.text('Close'), findsOneWidget);
      await rig.next(tester);
      // A self-checked word counts through its mark, once.
      await rig.say(tester, 'ぱぱぱ');
      await tester.tap(find.text('Missed it'));
      await rig.settle(tester);
      await rig.say(tester, rig.shownKana(tester));
      expect(rig.results.last.tally, PracticeTally.right);
      final words = lessonWords().length;
      final tally = await finish(tester, rig);
      expect(tally, '1 on your own · 0 with help · 1 missed');
      final sum = RegExp(r'\d+')
          .allMatches(tally)
          .map((m) => int.parse(m.group(0)!))
          .fold<int>(0, (a, b) => a + b);
      expect(sum, lessThanOrEqualTo(words));
    });
  });

  group('practiceGrade (D17)', () {
    const word = {'kana': 'ほん', 'gloss': 'book', 'image': 'x/L25_01.webp'};
    final top = practiceHintSteps(word).length;
    PracticeResult r(Judgement j,
            {int hint = 0, bool? mark, String heard = 'x'}) =>
        PracticeResult(
            word: word,
            speech: SpeechResult(heard, j),
            hintLevel: hint,
            revealed: hint >= top,
            selfMark: mark);

    test('each judgement maps to its grade', () {
      expect(practiceGrade(r(Judgement.correct)), Grade.clear);
      expect(practiceGrade(r(Judgement.close)), Grade.hinted);
      expect(practiceGrade(r(Judgement.wrong)), Grade.wrong);
      expect(practiceGrade(r(Judgement.unverified, heard: '')), Grade.unscored);
    });

    test('a hint is hinted and the whole answer showing is wrong (PIN-3)', () {
      expect(practiceGrade(r(Judgement.correct, hint: 1)), Grade.hinted);
      expect(practiceGrade(r(Judgement.correct, hint: top)), Grade.wrong);
      expect(practiceGrade(r(Judgement.close, hint: top)), Grade.wrong);
    });

    test('a second listen is hinted, never clear', () {
      expect(
          practiceGrade(r(Judgement.correct), secondTry: true), Grade.hinted);
      expect(practiceGrade(r(Judgement.wrong), secondTry: true), Grade.wrong);
    });

    test('a self-mark: Got it is self, Missed it is wrong', () {
      expect(practiceGrade(r(Judgement.unverified, heard: '', mark: true)),
          Grade.self);
      expect(practiceGrade(r(Judgement.unverified, heard: '漢', mark: true)),
          Grade.self);
      expect(practiceGrade(r(Judgement.unverified, hint: 1, mark: true)),
          Grade.self);
      expect(practiceGrade(r(Judgement.unverified, mark: false)), Grade.wrong);
      expect(practiceGrade(r(Judgement.unverified, hint: top, mark: true)),
          Grade.wrong);
    });

    test(
        "the transcript's own verdict never counts; the learner's mark and the "
        'reveal wrong do (plan 2026-11-06, Task 5, PIN-2, ASK-4)', () {
      bool fromTranscript(PracticeResult x) =>
          practiceVerdictFromTranscript(x, practiceGrade(x));
      expect(fromTranscript(r(Judgement.correct)), isTrue);
      expect(fromTranscript(r(Judgement.close)), isTrue);
      expect(fromTranscript(r(Judgement.wrong)), isTrue);
      expect(fromTranscript(r(Judgement.correct, hint: 1)), isTrue,
          reason: 'a hinted grade from the transcript is still its verdict');
      expect(fromTranscript(r(Judgement.correct, hint: top)), isFalse,
          reason: 'the wrong the whole answer showing earns still counts');
      expect(fromTranscript(r(Judgement.unverified, heard: '')), isFalse);
      expect(fromTranscript(r(Judgement.unverified, mark: true)), isFalse);
      expect(fromTranscript(r(Judgement.unverified, mark: false)), isFalse);
    });

    test('a skip is unscored unless the answer showed', () {
      expect(practiceSkipGrade(word, 0), Grade.unscored);
      expect(practiceSkipGrade(word, 1), Grade.unscored);
      expect(practiceSkipGrade(word, top), Grade.wrong);
    });

    test('the item id is the image stem, as the catalog names it', () {
      expect(practiceItemId(word), 'L25_01');
    });

    test(
        'every lesson word\'s id resolves to a catalog word with the spoken probe',
        () {
      Map<String, dynamic> read(String path) =>
          json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final lessons = read(_lessonFile);
      final catalog =
          ItemCatalog.fromDocs(read('assets/lessons/jp_grammar.json'), lessons);
      // Every illustrated word of every lesson, so lesson 25's deck is a subset.
      final words = [
        for (final l
            in (lessons['lessons'] as List).cast<Map<String, dynamic>>())
          for (final w in (l['items'] as List).cast<Map<String, dynamic>>())
            if (w['image'] != null) w,
      ];
      expect(words, containsAll(lessonWords().values));
      for (final w in words) {
        final id = practiceItemId(w);
        final item = catalog.byId(id);
        expect(item, isNotNull, reason: '$id is not in the catalog');
        expect(item!.kind, ItemKind.word, reason: '$id is not a word');
        final probe = item.probes.where((p) => p.id == kPracticeProbe);
        expect(probe, hasLength(1), reason: '$id has no $kPracticeProbe probe');
        expect(probe.single.production, isTrue,
            reason: '$id: the $kPracticeProbe probe is not production');
      }
    });
  });

  group('the attempt log (Task 10)', () {
    testWidgets('a correct answer writes one clear on the spoken probe',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      final id = rig.shownId(tester);
      await rig.say(tester, rig.shownKana(tester));
      final a = (await rig.attempts(tester)).single;
      expect(a.itemId, id);
      expect(a.probeId, 'spoken');
      expect(a.template, 'spoken');
      expect(a.production, isTrue);
      expect(a.selfGraded, isFalse);
      expect(a.grade, Grade.clear);
      expect(a.rating, kRatingGood);
      expect(a.hintLevel, 0);
      expect(a.revealed, isFalse);
      expect(a.localDay, localDay(_now));
      // The on-device transcript never counts (plan 2026-11-06, Task 5, PIN-2): the answer is
      // on the Say-it track and moves no schedule.
      expect(a.wasDue, isFalse);
      expect(a.source, Source.sayIt);
      expect(await rig.store.srs(id), isNull);
    });

    testWidgets(
        'an answer on a due word never counts: the Say-it track, no schedule and no '
        'mastery (PIN-2)', (tester) async {
      final rig = Rig();
      await rig.open(tester);
      final id = rig.shownId(tester);
      await rig.store.appendSeed(id, localDay(_now), atUtc: _now.toUtc());
      await rig.say(tester, rig.shownKana(tester));
      final a = (await rig.attempts(tester)).single;
      expect(a.wasDue, isTrue, reason: 'the due state is still logged');
      expect(a.source, Source.sayIt);
      expect(a.grade, Grade.clear);
      expect(await rig.store.srs(id), isNull,
          reason: 'only Azure scoring counts a spoken answer');
      final m = await rig.store.mastery(id);
      expect(m == null || m.clearCount == 0, isTrue,
          reason: 'an on-device clear never counts toward Mastered');
    });

    testWidgets(
        'a failed write reaches the error handler, the verdict still shows (S4)',
        (tester) async {
      final rig = Rig(store: _FailingStore());
      await rig.open(tester);
      await rig.say(tester, rig.shownKana(tester));
      expect(find.byKey(const ValueKey('practice-verdict')), findsOneWidget);
      expect(await rig.attempts(tester), isEmpty);
      final error = tester.takeException();
      expect(error, isNotNull);
      expect(error, isA<StateError>());
    });

    testWidgets('close writes hinted (PIN-3)', (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await rig.say(tester, '${rig.shownKana(tester)}です');
      final a = (await rig.attempts(tester)).single;
      expect(a.grade, Grade.hinted);
      expect(a.rating, kRatingHard);
      expect(a.hintLevel, 0);
      expect(a.source, Source.sayIt,
          reason: 'a transcript close never counts toward the hinted row (#88)');
    });

    testWidgets('a hint writes hinted, the whole answer showing writes wrong',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await tester.tap(find.text('Give me a hint'));
      await tester.pump();
      await rig.say(tester, rig.shownKana(tester));
      var a = (await rig.attempts(tester)).last;
      expect(a.grade, Grade.hinted);
      expect(a.hintLevel, 1);
      expect(a.revealed, isFalse);

      await rig.next(tester);
      await tester.tap(find.text('Give me a hint'));
      await tester.pump();
      while (find.text('More').evaluate().isNotEmpty) {
        await tester.tap(find.text('More'));
        await tester.pump();
      }
      await rig.say(tester, rig.shownKana(tester));
      final all = await rig.attempts(tester);
      expect(all, hasLength(2), reason: 'an answered word writes no skip');
      a = all.last;
      expect(a.grade, Grade.wrong);
      expect(a.revealed, isTrue);
      expect(a.hintLevel, practiceHintSteps(rig.results.last.word).length);
    });

    testWidgets(
        'unverified with nothing heard writes unscored, and Got it writes self',
        (tester) async {
      final rig = Rig(mic: false);
      await rig.open(tester);
      await rig.tapSpeak(tester);
      var all = await rig.attempts(tester);
      expect(all.single.grade, Grade.unscored);
      expect(all.single.rating, isNull);

      await tester.tap(find.text('Got it'));
      await rig.settle(tester);
      all = await rig.attempts(tester);
      expect(all, hasLength(2));
      expect(all.last.grade, Grade.self);
      expect(all.last.rating, kRatingHard);
      expect(all.last.itemId, all.first.itemId);
    });

    testWidgets('Missed it writes wrong (PIN-13)', (tester) async {
      final rig = Rig(mic: false);
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await tester.tap(find.text('Missed it'));
      await rig.settle(tester);
      final all = await rig.attempts(tester);
      expect(all.map((a) => a.grade), [Grade.unscored, Grade.wrong]);
    });

    testWidgets('Got it on an unverified transcript writes self',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await tester.tap(find.text('Give me a hint'));
      await tester.pump();
      await rig.say(tester, '漢');
      await tester.tap(find.text('Got it'));
      await rig.settle(tester);
      final all = await rig.attempts(tester);
      expect(all.map((a) => a.grade), [Grade.unscored, Grade.self]);
      expect(all.last.hintLevel, 1);
      expect(all.last.revealed, isFalse);
    });

    testWidgets('a skip writes unscored, or wrong when the answer showed',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      final first = rig.shownId(tester);
      await rig.next(tester);
      var all = await rig.attempts(tester);
      expect(all.single.itemId, first);
      expect(all.single.grade, Grade.unscored);

      final second = rig.shownId(tester);
      await tester.tap(find.text('Give me a hint'));
      await tester.pump();
      while (find.text('More').evaluate().isNotEmpty) {
        await tester.tap(find.text('More'));
        await tester.pump();
      }
      await rig.next(tester);
      all = await rig.attempts(tester);
      expect(all, hasLength(2));
      expect(all.last.itemId, second);
      expect(all.last.grade, Grade.wrong);
      expect(all.last.revealed, isTrue);
    });

    testWidgets('a Stop then Next writes one skip, not the dropped listen',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await rig.tapSpeak(tester);
      await tester.tap(find.text('Stop'));
      await rig.settle(tester);
      rig.stt.hear([rig.shownKana(tester)]);
      await rig.settle(tester);
      expect(await rig.attempts(tester), isEmpty);
      await rig.next(tester);
      expect((await rig.attempts(tester)).single.grade, Grade.unscored);
    });

    testWidgets(
        'after the whole answer shows, a word writes one wrong and one review (ASK-4)',
        (tester) async {
      final rig = Rig(mic: false);
      await rig.open(tester);
      final id = rig.shownId(tester);
      await rig.store.appendSeed(id, localDay(_now), atUtc: _now.toUtc());
      await tester.tap(find.text('Give me a hint'));
      await tester.pump();
      while (find.text('More').evaluate().isNotEmpty) {
        await tester.tap(find.text('More'));
        await tester.pump();
      }
      for (var i = 0; i < 3; i++) {
        await rig.tapSpeak(tester);
      }
      await tester.tap(find.text('Got it'));
      await rig.settle(tester);

      final all = await rig.attempts(tester);
      expect(all.map((a) => a.grade),
          [Grade.wrong, Grade.unscored, Grade.unscored, Grade.unscored]);
      expect(all.every((a) => a.itemId == id && a.revealed), isTrue);
      expect(all.skip(1).map((a) => a.rating), everyElement(isNull));
      final srs = await rig.store.srs(id);
      expect(srs!.reps, 1, reason: 'one scheduler review');
      expect(srs.lapses, 1);
    });

    testWidgets('a second listen on the same word writes hinted',
        (tester) async {
      final rig = Rig();
      await rig.open(tester);
      await rig.say(tester, rig.shownKana(tester));
      await rig.say(tester, rig.shownKana(tester));
      final all = await rig.attempts(tester);
      expect(all.map((a) => a.grade), [Grade.clear, Grade.hinted]);
    });
  });
}
