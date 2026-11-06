// Widget tests for the grammar screen: the By use view, a choice question's feedback,
// the typed-answer box (PIN-3), the hint behind its tap and the practice result
// (PIN-3 of the mastery plan), the 漢字 toggle (PIN-4), the tap-a-word reading hint
// (PIN-16), the speaking drill link (PIN-6) and the attempts the screen writes
// through its injected JpStore (Task 9 of the mastery plan: D17, PIN-3, PIN-14), and the
// open at one grammar point from a card, with the "Back to practice" bar (plan 2026-11-06,
// Task 1, D20).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart'
    show RubyTapText, TypedVerdict, kBackToPractice, rubyWords;
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';
import 'package:habit_craft/flutter_flow/quiet_room.dart';

import 'jp_screen_harness.dart';

/// The opening lesson, the one the screen shows first.
Map<String, dynamic> firstLesson() =>
    (readLessonFile()['grammar'] as List).first as Map<String, dynamic>;

/// The opening lesson's fill-in items, in screen order.
List<Map<String, dynamic>> firstFills() => [
      for (final p
          in (firstLesson()['points'] as List).cast<Map<String, dynamic>>())
        for (final q in (p['practice'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          if ((q['options'] as List? ?? const []).isEmpty) q,
    ];

/// The typed-answer boxes, in screen order. The search box has another hint.
final Finder answerBoxes = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Type the answer');

/// A fill-in prompt as the screen shows it before an answer.
String unanswered(String prompt) => prompt.replaceAll('＿＿', '＿＿＿');

/// A right pick names no wrong-option reason. The check reads each reason's own
/// text, which is the same whichever surface the 漢字 toggle shows, so it cannot
/// pass on a label mismatch. An item with no reason would make the loop empty
/// and the check vacuous, so the item must carry one.
void expectNoReason(Map<String, dynamic> item) {
  expect(item['why_wrong'], isNotEmpty,
      reason: 'the right-pick check needs a reason to look for');
  for (final reason in (item['why_wrong'] as Map? ?? const {}).values) {
    expect(find.textContaining(reason as String), findsNothing);
  }
}

void main() {
  testWidgets('By use lists every pattern tagged with the chosen use',
      (tester) async {
    final doc = readLessonFile();
    final use = (doc['uses'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((u) => u['id'] == 'advise');
    final patterns = [
      for (final l in (doc['grammar'] as List).cast<Map<String, dynamic>>())
        for (final p in (l['points'] as List).cast<Map<String, dynamic>>())
          if ((p['uses'] as List? ?? const []).contains('advise'))
            p['pattern'] as String,
    ];
    expect(patterns, isNotEmpty);

    await pumpStudyScreen(tester, const QuietRoomGrammarWidget());
    await tester.tap(find.text('By use'));
    await tester.pump();
    expect(find.text('Pick what you want to say.'), findsOneWidget);

    await tester.tap(find.text('${use['label']}  ${patterns.length}'));
    await tester.pump();
    await tester.pump();

    // The heading names the use, and the screen lists each of its patterns.
    expect(find.text(use['label'] as String), findsOneWidget);
    expect(find.textContaining('${patterns.length} patterns, from lessons'),
        findsOneWidget);
    for (final p in patterns) {
      expect(find.text(p), findsOneWidget);
    }
  });

  testWidgets('a wrong choice shows why that option is wrong', (tester) async {
    final doc = readLessonFile();
    final first = (doc['grammar'] as List).first as Map<String, dynamic>;
    // The first choice item in the opening lesson whose wrong options carry a reason.
    final item = [
      for (final p in (first['points'] as List).cast<Map<String, dynamic>>())
        for (final q in (p['practice'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          if ((q['options'] as List? ?? const []).isNotEmpty &&
              (q['why_wrong'] as Map? ?? const {}).isNotEmpty)
            q,
    ].first;
    final why = (item['why_wrong'] as Map).cast<String, String>();
    final wrong = why.keys.first;
    expect(wrong, isNot(item['answer']));

    await pumpStudyScreen(tester, const QuietRoomGrammarWidget());
    expect(find.textContaining('$wrong: ${why[wrong]}'), findsNothing);

    // No earlier widget in this lesson shows this option text, so .first is this item's option.
    await tester.tap(find.text(wrong).first);
    await tester.pump();

    expect(find.textContaining('$wrong: ${why[wrong]}'), findsOneWidget);
    if (item['hint'] != null) {
      expect(find.textContaining(item['hint'] as String), findsWidgets);
    }
  });

  testWidgets('a right choice shows no reason', (tester) async {
    final doc = readLessonFile();
    final first = (doc['grammar'] as List).first as Map<String, dynamic>;
    final item = [
      for (final p in (first['points'] as List).cast<Map<String, dynamic>>())
        for (final q in (p['practice'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
          if ((q['options'] as List? ?? const []).isNotEmpty &&
              (q['why_wrong'] as Map? ?? const {}).isNotEmpty)
            q,
    ].first;

    await pumpStudyScreen(tester, const QuietRoomGrammarWidget());
    await tester.tap(find.text(item['answer'] as String).first);
    await tester.pump();

    // The prompt swaps ＿＿ for ［answer］ once a pick is made, so this proves the tap registered.
    expect(find.textContaining('［${item['answer']}］'), findsOneWidget);
    expectNoReason(item);
  });

  testWidgets('every typed-answer box asks for the Japanese keyboard',
      (tester) async {
    final fills = firstFills();
    expect(fills, isNotEmpty);

    await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

    expect(answerBoxes, findsNWidgets(fills.length));
    for (final box in tester.widgetList<TextField>(answerBoxes)) {
      expect(box.hintLocales, contains(const Locale('ja', 'JP')));
    }
  });

  group('typed answers', () {
    /// The first fill-in item in the opening lesson whose answer has a kanji version.
    ({int index, Map<String, dynamic> q}) kanjiFill() {
      final fills = firstFills();
      final i = fills.indexWhere(
          (q) => rubySurface(q['answer_ruby'] as String? ?? '') != q['answer']);
      expect(i, isNonNegative, reason: 'no fill-in answer has kanji');
      return (index: i, q: fills[i]);
    }

    testWidgets('the kanji version of the answer is marked correct',
        (tester) async {
      final f = kanjiFill();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(
          answerBoxes.at(f.index), rubySurface(f.q['answer_ruby'] as String));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Correct.'), findsOneWidget);
      // The prompt fills its blank with the answer, and the box goes away.
      expect(
          find.text(
              (f.q['prompt'] as String).replaceAll('＿＿', '［${f.q['answer']}］')),
          findsOneWidget);
      expect(answerBoxes, findsNWidgets(firstFills().length - 1));
    });

    testWidgets('the hiragana answer is marked correct', (tester) async {
      final q = firstFills().first;
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, q['answer'] as String);
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(find.text('Correct.'), findsOneWidget);
    });

    testWidgets('a wrong kana answer is rejected and the box stays',
        (tester) async {
      final fills = firstFills();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, 'ぬぬぬ');
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(find.text('Correct.'), findsNothing);
      expect(find.textContaining('Not quite.'), findsOneWidget);
      expect(answerBoxes, findsNWidgets(fills.length));
      expect(find.text(unanswered(fills.first['prompt'] as String)),
          findsOneWidget);
    });

    testWidgets('a wrong typed answer leaves the hint behind its tap',
        (tester) async {
      final q = firstFills().first;
      final hint = q['hint'] as String?;
      expect(hint, isNotNull, reason: 'the opening fill item carries a hint');
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, 'ぬぬぬ');
      await tester.tap(find.text('Check').first);
      await tester.pump();

      // A wrong answer is no hint request, so the hint stays hidden.
      expect(find.textContaining('Not quite.'), findsOneWidget);
      expect(find.text('Hint: $hint'), findsNothing);

      await tester.tap(find.text('Show hint').first);
      await tester.pump();

      // The 'Hint:' row under the box is the only place the hint appears.
      expect(find.textContaining(hint!), findsOneWidget);
      expect(find.text('Hint: $hint'), findsOneWidget);
    });

    testWidgets('Show answer after a wrong answer drops the retry message',
        (tester) async {
      final q = firstFills().first;
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, 'ぬぬぬ');
      await tester.tap(find.text('Check').first);
      await tester.pump();
      expect(find.textContaining('Not quite.'), findsOneWidget);

      await tester.tap(find.text('Show answer').first);
      await tester.pump();

      // The box and the retry message go together. The prompt shows the answer.
      expect(find.textContaining('Not quite.'), findsNothing);
      expect(
          find.text(
              (q['prompt'] as String).replaceAll('＿＿', '［${q['answer']}］')),
          findsOneWidget);
    });

    testWidgets('an answer it cannot compare goes to self-check, not wrong',
        (tester) async {
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.enterText(answerBoxes.first, 'ittara');
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(find.textContaining('Not quite.'), findsNothing);
      expect(find.textContaining("Can't check that spelling"), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Missed it'), findsOneWidget);
    });
  });

  group('the practice result (PIN-3 of the mastery plan)', () {
    /// Pumps the screen with a recorder for every practice result it reports.
    Future<List<GrammarPracticeResult>> pumpRecorded(
        WidgetTester tester) async {
      final results = <GrammarPracticeResult>[];
      await pumpStudyScreen(
          tester, QuietRoomGrammarWidget(onPracticeResult: results.add));
      return results;
    }

    /// The opening point's second item, a choice.
    Map<String, dynamic> openingChoice() {
      final q = ((firstLesson()['points'] as List).first['practice'] as List)[1]
          as Map<String, dynamic>;
      expect(q['options'], isNotEmpty);
      return q;
    }

    testWidgets('a fill-in hint shows only after a Show hint tap',
        (tester) async {
      final fills = firstFills();
      final hint = fills.first['hint'] as String;
      final results = await pumpRecorded(tester);

      expect(find.text('Hint: $hint'), findsNothing);
      expect(find.textContaining(hint), findsNothing);
      expect(find.text('Show hint'),
          findsNWidgets(fills.where((f) => f['hint'] != null).length));

      await tester.tap(find.text('Show hint').first);
      await tester.pump();

      expect(find.text('Hint: $hint'), findsOneWidget);
      expect(results.last.hintTaken, isTrue);
      expect(results.last.revealed, isFalse);
      expect(results.last.pointId,
          ((firstLesson()['points'] as List).first as Map)['id']);
      expect(results.last.index, 0);
    });

    testWidgets('the hint tap is remembered on the item', (tester) async {
      final results = await pumpRecorded(tester);
      await tester.tap(find.text('Show hint').first);
      await tester.pump();

      // A clear typed after the hint still says the hint was taken.
      await tester.enterText(
          answerBoxes.first, firstFills().first['answer'] as String);
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(find.text('Correct.'), findsOneWidget);
      expect(results.last.verdict, TypedVerdict.right);
      expect(results.last.hintTaken, isTrue);
    });

    testWidgets('a clear typed with no hint says no hint was taken',
        (tester) async {
      final results = await pumpRecorded(tester);
      await tester.enterText(
          answerBoxes.first, firstFills().first['answer'] as String);
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(results, hasLength(1));
      expect(results.single.verdict, TypedVerdict.right);
      expect(results.single.hintTaken, isFalse);
      expect(results.single.revealed, isFalse);
      expect(results.single.picked, isNull);
    });

    testWidgets('Show answer is recorded as revealed', (tester) async {
      final results = await pumpRecorded(tester);
      await tester.tap(find.text('Show answer').first);
      await tester.pump();

      expect(results, hasLength(1));
      expect(results.single.revealed, isTrue);
      expect(results.single.hintTaken, isFalse);
      expect(results.single.verdict, isNull);
    });

    testWidgets('Show answer stays flush right under Check around the hint tap',
        (tester) async {
      await pumpRecorded(tester);
      expect(firstFills().first['hint'], isNotNull);
      double right(String label) =>
          tester.getTopRight(find.widgetWithText(TextButton, label).first).dx;

      expect(right('Show answer'), right('Check'));
      await tester.tap(find.text('Show hint').first);
      await tester.pump();
      expect(right('Show answer'), right('Check'));
    });

    testWidgets('an empty Check is not an attempt and says so', (tester) async {
      final fills = firstFills();
      final results = await pumpRecorded(tester);

      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(results, isEmpty);
      expect(find.text('Type an answer first.'), findsOneWidget);
      expect(find.text('Correct.'), findsNothing);
      expect(find.textContaining('Not quite.'), findsNothing);
      expect(answerBoxes, findsNWidgets(fills.length));

      // Typing clears the note, and typing alone is no attempt.
      await tester.enterText(answerBoxes.first, 'ぬ');
      await tester.pump();
      expect(find.text('Type an answer first.'), findsNothing);
      expect(results, isEmpty);
    });

    testWidgets('a whitespace-only Check is not an attempt either',
        (tester) async {
      final fills = firstFills();
      final results = await pumpRecorded(tester);

      // An ASCII space and a full-width space: the box is not empty, the answer is.
      await tester.enterText(answerBoxes.first, '  　');
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(results, isEmpty);
      expect(find.text('Type an answer first.'), findsOneWidget);
      expect(find.text('Correct.'), findsNothing);
      expect(find.textContaining('Not quite.'), findsNothing);
      expect(find.text('Got it'), findsNothing);
      expect(answerBoxes, findsNWidgets(fills.length));
    });

    testWidgets('a self-mark and a pick are carried in the result',
        (tester) async {
      final results = await pumpRecorded(tester);

      await tester.enterText(answerBoxes.first, 'ittara');
      await tester.tap(find.text('Check').first);
      await tester.pump();
      expect(results.last.verdict, TypedVerdict.selfCheck);
      expect(results.last.selfMark, isNull);

      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(results.last.selfMark, isTrue);
      expect(results.last.index, 0);

      final choice = openingChoice();
      await tester.tap(find.text(choice['answer'] as String).first);
      await tester.pump();
      expect(results.last.index, 1);
      expect(results.last.picked, choice['answer']);
      expect(results.last.hintTaken, isFalse);
    });

    testWidgets(
        'a wrong pick prints the hint after the lock, with no hint flag',
        (tester) async {
      final results = await pumpRecorded(tester);
      final choice = openingChoice();
      final hint = choice['hint'] as String;
      final wrong = (choice['options'] as List)
          .cast<String>()
          .firstWhere((o) => o != choice['answer']);
      // No fill-in hint is open, so the hint text is absent until the pick.
      expect(find.textContaining(hint), findsNothing);

      await tester.tap(find.text(wrong).first);
      await tester.pump();
      expect(find.textContaining(hint), findsOneWidget);
      expect(results.single.index, 1);
      expect(results.single.picked, wrong);
      expect(results.single.hintTaken, isFalse);
      expect(results.single.verdict, isNull);

      // The options are locked, so the printed hint cannot lead a second pick.
      await tester.tap(find.text(choice['answer'] as String).first);
      await tester.pump();
      expect(results.single.picked, wrong);
    });

    testWidgets('a right pick prints no hint, with no hint flag',
        (tester) async {
      final results = await pumpRecorded(tester);
      final choice = openingChoice();
      final hint = choice['hint'] as String;
      final wrong = (choice['options'] as List)
          .cast<String>()
          .firstWhere((o) => o != choice['answer']);
      expect(find.textContaining(hint), findsNothing);

      await tester.tap(find.text(choice['answer'] as String).first);
      await tester.pump();
      // The prompt shows the answer, so the tap registered, and the hint is the
      // wrong-pick arm's alone.
      expect(find.textContaining('［${choice['answer']}］'), findsOneWidget);
      expect(find.textContaining(hint), findsNothing);
      expect(results.single.index, 1);
      expect(results.single.picked, choice['answer']);
      expect(results.single.hintTaken, isFalse);
      expect(results.single.verdict, isNull);

      // The lock holds on this arm too: a wrong option after the pick reports
      // nothing and prints no hint.
      await tester.tap(find.text(wrong).first);
      await tester.pump();
      expect(results.single.picked, choice['answer']);
      expect(find.textContaining(hint), findsNothing);
    });

    testWidgets('an edit after Got it drops the self-mark from the next result',
        (tester) async {
      final results = await pumpRecorded(tester);

      await tester.enterText(answerBoxes.first, 'ittara');
      await tester.tap(find.text('Check').first);
      await tester.pump();
      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(results.last.selfMark, isTrue);

      // The edit takes the pills away, and the mark with them.
      await tester.enterText(answerBoxes.first, 'ぬ');
      await tester.pump();
      expect(find.text('Got it'), findsNothing);

      await tester.tap(find.text('Show answer').first);
      await tester.pump();

      expect(results.last.revealed, isTrue);
      expect(results.last.verdict, isNull);
      expect(results.last.selfMark, isNull);
    });

    testWidgets('Tap for English is a reading aid, not an attempt (D28)',
        (tester) async {
      final results = await pumpRecorded(tester);
      await tester.tap(find.text('Tap for English').first);
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets(
        'a typed answer, a hint, a pick and an English line survive the scroll',
        (tester) async {
      final fills = firstFills();
      final opening = (firstLesson()['points'] as List).first as Map;
      final shownEn =
          ((opening['examples'] as List).first as Map)['en'] as String;
      final choice = openingChoice();
      final pickedPrompt = (choice['prompt'] as String)
          .replaceAll('＿＿', '［${choice['answer']}］');
      await pumpRecorded(tester);

      await tester.enterText(answerBoxes.first, 'ぬぬぬ');
      await tester.tap(find.text('Show hint').first);
      await tester.tap(find.text('Tap for English').first);
      await tester.tap(find.text(choice['answer'] as String).first);
      // The keyboard goes away. A focused box would keep its card alive by itself.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text(pickedPrompt), findsOneWidget);
      expect(find.text(shownEn), findsOneWidget);

      // A phone-sized view, scrolled to the end, takes the first card off screen.
      final page = find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .first;
      tester.view.physicalSize = const Size(400, 500);
      await tester.pump();
      await tester.scrollUntilVisible(
          find.textContaining('Pattern, goal and first example'), 600,
          scrollable: page);
      await tester.pump();
      expect(find.text(pickedPrompt), findsNothing);

      // Back up. A card that lost its state would never show the picked prompt.
      await tester.scrollUntilVisible(find.text(pickedPrompt), -600,
          scrollable: page);
      await tester.pump();

      expect(find.text(pickedPrompt), findsOneWidget);
      expect(find.text(shownEn, skipOffstage: false), findsOneWidget);
      expect(find.text('Hint: ${fills.first['hint']}', skipOffstage: false),
          findsOneWidget);
      expect(
          tester
              .widget<TextField>(find
                  .byWidgetPredicate(
                      (w) =>
                          w is TextField &&
                          w.decoration?.hintText == 'Type the answer',
                      skipOffstage: false)
                  .first)
              .controller!
              .text,
          'ぬぬぬ');
    });

    testWidgets('a reveal survives the scroll', (tester) async {
      final q = firstFills().first;
      final before = unanswered(q['prompt'] as String);
      final revealedPrompt =
          (q['prompt'] as String).replaceAll('＿＿', '［${q['answer']}］');
      await pumpRecorded(tester);

      await tester.tap(find.text('Show answer').first);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text(revealedPrompt), findsOneWidget);
      expect(find.text(before), findsNothing);

      // A phone-sized view, scrolled to the end, takes the first card off screen.
      final page = find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .first;
      tester.view.physicalSize = const Size(400, 500);
      await tester.pump();
      await tester.scrollUntilVisible(
          find.textContaining('Pattern, goal and first example'), 600,
          scrollable: page);
      await tester.pump();
      expect(find.text(revealedPrompt), findsNothing);

      // Back up. A card that lost its reveal would show the blank again.
      await tester.scrollUntilVisible(find.text(revealedPrompt), -600,
          scrollable: page);
      await tester.pump();

      expect(find.text(revealedPrompt), findsOneWidget);
      expect(find.text(before, skipOffstage: false), findsNothing);
    });
  });

  group('the 漢字 toggle', () {
    /// The opening lesson's first example whose kanji version differs from its hiragana.
    Map<String, dynamic> kanjiExample() => [
          for (final p
              in (firstLesson()['points'] as List).cast<Map<String, dynamic>>())
            for (final e in (p['examples'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
              if (rubySurface(e['jp_ruby'] as String? ?? '') != e['jp']) e,
        ].first;

    /// The opening lesson's first fill-in prompt whose kanji version differs.
    Map<String, dynamic> kanjiPrompt() => firstFills().firstWhere(
        (q) => rubySurface(q['prompt_ruby'] as String? ?? '') != q['prompt']);

    testWidgets('hiragana is shown by default', (tester) async {
      final e = kanjiExample();
      final q = kanjiPrompt();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      expect(find.text(e['jp'] as String), findsOneWidget);
      expect(find.text(rubySurface(e['jp_ruby'] as String)), findsNothing);
      expect(find.text(unanswered(q['prompt'] as String)), findsOneWidget);
      expect(find.text(unanswered(rubySurface(q['prompt_ruby'] as String))),
          findsNothing);
    });

    testWidgets('the toggle shows the kanji versions, and back again',
        (tester) async {
      final e = kanjiExample();
      final q = kanjiPrompt();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.tap(find.text('漢字'));
      await tester.pump();

      expect(find.text(rubySurface(e['jp_ruby'] as String)), findsOneWidget);
      expect(find.text(e['jp'] as String), findsNothing);
      expect(find.text(unanswered(rubySurface(q['prompt_ruby'] as String))),
          findsOneWidget);
      expect(find.text(unanswered(q['prompt'] as String)), findsNothing);

      await tester.tap(find.text('漢字'));
      await tester.pump();

      expect(find.text(e['jp'] as String), findsOneWidget);
      expect(find.text(rubySurface(e['jp_ruby'] as String)), findsNothing);
    });

    testWidgets('a choice still checks the right option in kanji',
        (tester) async {
      // The first choice item in the opening lesson whose answer has a kanji version.
      final item = [
        for (final p
            in (firstLesson()['points'] as List).cast<Map<String, dynamic>>())
          for (final q in (p['practice'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
            if ((q['options'] as List? ?? const []).isNotEmpty &&
                rubySurface(q['answer_ruby'] as String? ?? '') != q['answer'])
              q,
      ].first;
      final shown = rubySurface(item['answer_ruby'] as String);
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.tap(find.text('漢字'));
      await tester.pump();
      await tester.tap(find.text(shown).first);
      await tester.pump();

      expect(
          find.text(rubySurface(item['prompt_ruby'] as String)
              .replaceAll('＿＿', '［$shown］')),
          findsOneWidget);
      expectNoReason(item);
    });

    testWidgets('a wrong pick in kanji quotes the kanji option in its reason',
        (tester) async {
      // The first choice item in the opening lesson with a reason for a wrong option
      // whose kanji version differs from its hiragana.
      final item = [
        for (final p
            in (firstLesson()['points'] as List).cast<Map<String, dynamic>>())
          for (final q in (p['practice'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
            if ((q['options'] as List? ?? const []).isNotEmpty &&
                (q['why_wrong'] as Map? ?? const {}).keys.any((w) {
                  final i = (q['options'] as List).indexOf(w);
                  final ruby = (q['options_ruby'] as List?)?[i] as String?;
                  return ruby != null && rubySurface(ruby) != w;
                }))
              q,
      ].first;
      final options = (item['options'] as List).cast<String>();
      final optionsRuby = (item['options_ruby'] as List).cast<String>();
      final why = (item['why_wrong'] as Map).cast<String, String>();
      final wrong = why.keys
          .firstWhere((w) => rubySurface(optionsRuby[options.indexOf(w)]) != w);
      final shown = rubySurface(optionsRuby[options.indexOf(wrong)]);
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      await tester.tap(find.text('漢字'));
      await tester.pump();
      await tester.tap(find.text(shown).first);
      await tester.pump();

      // The reason quotes the option as shown, not its hiragana key.
      expect(find.textContaining('$shown: ${why[wrong]}'), findsOneWidget);
      expect(find.textContaining('$wrong: ${why[wrong]}'), findsNothing);
    });
  });

  group('the reading hint', () {
    /// The opening lesson's first example with a kanji word, with one kanji word and
    /// one plain word that each occur once in the shown sentence, so a tap on either
    /// can only land on that word.
    ({
      String ruby,
      String surface,
      String en,
      ({String text, String? reading}) kanji,
      ({String text, String? reading}) plain,
    }) hintExample() {
      for (final p
          in (firstLesson()['points'] as List).cast<Map<String, dynamic>>()) {
        for (final e in (p['examples'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
          final ruby = e['jp_ruby'] as String?;
          if (ruby == null) continue;
          final surface = rubySurface(ruby);
          bool once(String w) =>
              w.trim().isNotEmpty &&
              surface.indexOf(w) == surface.lastIndexOf(w);
          final words = rubyWords(ruby);
          final kanji = words.where((w) => w.reading != null && once(w.text));
          final plain = words.where((w) => w.reading == null && once(w.text));
          if (kanji.isNotEmpty && plain.isNotEmpty) {
            return (
              ruby: ruby,
              surface: surface,
              en: e['en'] as String? ?? '',
              kanji: kanji.first,
              plain: plain.first,
            );
          }
        }
      }
      fail('no opening-lesson example has a kanji word and a plain word');
    }

    Finder sentence(String ruby) =>
        find.byWidgetPredicate((w) => w is RubyTapText && w.ruby == ruby);

    /// The sentence's spans: each word's own color, or the sentence color it inherits.
    Map<String, Color?> wordColors(WidgetTester tester, String ruby) {
      final text = tester.widget<Text>(find
          .descendant(of: sentence(ruby), matching: find.byType(Text))
          .first);
      return {
        for (final s in (text.textSpan! as TextSpan).children!.cast<TextSpan>())
          s.text!: s.style?.color ?? text.style?.color,
      };
    }

    Future<void> kanjiOn(WidgetTester tester, {bool dark = false}) async {
      await pumpStudyScreen(
          tester,
          dark
              ? Theme(
                  data: ThemeData(brightness: Brightness.dark),
                  child: const QuietRoomGrammarWidget())
              : const QuietRoomGrammarWidget());
      await tester.tap(find.text('漢字'));
      await tester.pump();
    }

    testWidgets('hiragana view has no tappable words', (tester) async {
      final ex = hintExample();
      await pumpStudyScreen(tester, const QuietRoomGrammarWidget());

      expect(find.byType(RubyTapText), findsNothing);
      expect(sentence(ex.ruby), findsNothing);
    });

    testWidgets('a kanji word shows in the hint color, a plain word does not',
        (tester) async {
      final ex = hintExample();
      const day = DaylightTokens();
      await kanjiOn(tester);

      expect(sentence(ex.ruby), findsOneWidget);
      final colors = wordColors(tester, ex.ruby);
      expect(colors[ex.kanji.text], day.brand600);
      expect(colors[ex.plain.text], day.inkStrong);
      expect(colors[ex.plain.text], isNot(day.brand600));
    });

    testWidgets('the hint color is the Nightfall token in dark',
        (tester) async {
      final ex = hintExample();
      const night = NightfallTokens();
      await kanjiOn(tester, dark: true);

      final colors = wordColors(tester, ex.ruby);
      expect(colors[ex.kanji.text], night.brand600);
      expect(colors[ex.plain.text], night.inkStrong);
    });

    testWidgets('a tap shows the reading, a second tap hides it',
        (tester) async {
      final ex = hintExample();
      final reading = find.descendant(
          of: sentence(ex.ruby), matching: find.text(ex.kanji.reading!));
      await kanjiOn(tester);
      expect(reading, findsNothing);

      await tester.tapOnText(find.textRange
          .ofSubstring(ex.kanji.text, descendentOf: sentence(ex.ruby)));
      await tester.pump();

      // The reading sits above the word, which is still shown. The tap is the word's,
      // so the row's English stays hidden.
      expect(reading, findsOneWidget);
      if (ex.en.isNotEmpty) expect(find.text(ex.en), findsNothing);
      final word = find.descendant(
          of: sentence(ex.ruby), matching: find.text(ex.kanji.text));
      expect(word, findsOneWidget);
      expect(tester.getRect(reading).bottom,
          lessThanOrEqualTo(tester.getRect(word).top + 0.5));

      await tester.tap(word);
      await tester.pump();

      expect(reading, findsNothing);
      // Hidden again, the sentence reads as one line of text, as before the tap.
      expect(find.text(ex.surface), findsOneWidget);
    });

    testWidgets('a tap on a plain word shows no reading', (tester) async {
      final ex = hintExample();
      await kanjiOn(tester);

      final root = tester
          .widget<Text>(find
              .descendant(of: sentence(ex.ruby), matching: find.byType(Text))
              .first)
          .textSpan! as TextSpan;
      final span = root.children!
          .cast<TextSpan>()
          .firstWhere((s) => s.text == ex.plain.text);
      expect(span.recognizer, isNull);

      await tester.tapOnText(find.textRange
          .ofSubstring(ex.plain.text, descendentOf: sentence(ex.ruby)));
      await tester.pump();

      expect(find.text(ex.surface), findsOneWidget);
      for (final w in rubyWords(ex.ruby)) {
        if (w.reading == null) continue;
        expect(
            find.descendant(
                of: sentence(ex.ruby), matching: find.text(w.reading!)),
            findsNothing);
      }
    });

    testWidgets('a fill-in prompt takes the hint too', (tester) async {
      // The opening lesson's first fill-in prompt with a kanji word, as the kanji
      // view shows it before an answer: its blank is ＿＿＿. The tapped word occurs
      // once in that prompt, so the tap can only land on it.
      final q = firstFills().firstWhere((q) =>
          rubyWords(q['prompt_ruby'] as String? ?? '')
              .any((w) => w.reading != null));
      final ruby = unanswered(q['prompt_ruby'] as String);
      final surface = rubySurface(ruby);
      final kanji = rubyWords(ruby).firstWhere((w) =>
          w.reading != null &&
          surface.indexOf(w.text) == surface.lastIndexOf(w.text));
      final reading = find.descendant(
          of: sentence(ruby), matching: find.text(kanji.reading!));
      await kanjiOn(tester);

      expect(sentence(ruby), findsOneWidget);
      expect(find.text(surface), findsOneWidget);
      expect(wordColors(tester, ruby)[kanji.text],
          const DaylightTokens().brand600);
      expect(reading, findsNothing);

      await tester.tapOnText(
          find.textRange.ofSubstring(kanji.text, descendentOf: sentence(ruby)));
      await tester.pump();

      expect(reading, findsOneWidget);
    });
  });

  testWidgets('Speak this lesson opens the drill for the lesson shown',
      (tester) async {
    final lesson = firstLesson()['lesson'] as int;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const QuietRoomGrammarWidget()),
      GoRoute(
        name: QuietRoomSpeakWidget.routeName,
        path: QuietRoomSpeakWidget.routePath,
        builder: (_, state) =>
            Text('drill for ${state.uri.queryParameters['lesson']}'),
      ),
    ]);
    addTearDown(router.dispose);
    await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));

    await tester.tap(find.text('Speak this lesson'));
    await tester.pumpAndSettle();

    expect(find.text('drill for $lesson'), findsOneWidget);
  });

  group('the attempts the screen writes (Task 9: D17, PIN-3, PIN-14)', () {
    /// The shipped catalog, built from the assets on disk.
    final catalog = ItemCatalog.fromDocs(
        readLessonFile(),
        json.decode(File('assets/lessons/jp_lessons.json').readAsStringSync())
            as Map<String, dynamic>);

    /// Noon on 2026-03-02, local time.
    final noon = DateTime(2026, 3, 2, 12);
    final today = localDay(noon);

    List<Map<String, dynamic>> openingPoints() =>
        (firstLesson()['points'] as List).cast<Map<String, dynamic>>();

    /// The opening point: its first item is a fill-in, its second a choice.
    String openingPoint() => openingPoints().first['id'] as String;

    /// Pumps the screen on a fresh memory store. [dueToday] seeds every point of the
    /// opening lesson due today, so its answers are reviews rather than early practice.
    Future<JpStore> pumpWithStore(WidgetTester tester,
        {bool dueToday = false}) async {
      final store = JpStoreMemory();
      if (dueToday) {
        for (final p in openingPoints()) {
          await store.appendSeed(p['id'] as String, today, atUtc: noon.toUtc());
        }
      }
      await pumpStudyScreen(
          tester,
          QuietRoomGrammarWidget(
              store: store, itemLookup: catalog.byId, clock: FixedClock(noon)));
      return store;
    }

    Future<void> typeAndCheck(WidgetTester tester, String text) async {
      await tester.enterText(answerBoxes.first, text);
      await tester.tap(find.text('Check').first);
      await tester.pump();
    }

    String fillAnswer() => firstFills().first['answer'] as String;

    testWidgets('a clear typed with no hint writes a clear', (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      await typeAndCheck(tester, fillAnswer());

      final a = (await store.attempts()).single;
      expect(a.itemId, openingPoint());
      expect(a.probeId, 'p0');
      expect(a.template, 'fill');
      expect(a.production, isTrue);
      expect(a.selfGraded, isFalse);
      expect(a.grade, Grade.clear);
      expect(a.rating, kRatingGood);
      expect(a.hintLevel, 0);
      expect(a.revealed, isFalse);
      expect(a.wasDue, isTrue);
      expect(a.source, Source.review);
      expect(a.localDay, today);

      // The schedule and the mastery moved with it, in the same answer.
      expect((await store.srs(openingPoint()))!.lastReviewDay, today);
      final m = (await store.mastery(openingPoint()))!;
      expect(m.status, MasteryStatus.learning);
      expect(m.clears, hasLength(1));
    });

    testWidgets('a clear typed after Show hint writes a hinted',
        (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      await tester.tap(find.text('Show hint').first);
      await tester.pump();
      // The hint tap alone is no attempt.
      expect(await store.attempts(), isEmpty);

      await typeAndCheck(tester, fillAnswer());

      final a = (await store.attempts()).single;
      expect(a.grade, Grade.hinted);
      expect(a.rating, kRatingHard);
      expect(a.hintLevel, 1);
      expect(a.revealed, isFalse);
      // A hinted answer earns no clear (PIN-3).
      expect((await store.mastery(openingPoint()))!.clears, isEmpty);
    });

    testWidgets('Show answer writes a wrong with the revealed flag',
        (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      await tester.tap(find.text('Show answer').first);
      await tester.pump();

      final a = (await store.attempts()).single;
      expect(a.probeId, 'p0');
      expect(a.grade, Grade.wrong);
      expect(a.rating, kRatingAgain);
      expect(a.revealed, isTrue);
      expect(a.hintLevel, 0);
    });

    testWidgets('an empty Check writes nothing', (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      await tester.tap(find.text('Check').first);
      await tester.pump();
      await tester.enterText(answerBoxes.first, '  　');
      await tester.tap(find.text('Check').first);
      await tester.pump();

      expect(find.text('Type an answer first.'), findsOneWidget);
      expect(await store.attempts(), isEmpty);
      expect(await store.srs(openingPoint()), isNull);
      expect(await store.mastery(openingPoint()), isNull);
    });

    testWidgets(
        'a wrong check, then the right answer, writes wrong then hinted',
        (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      await typeAndCheck(tester, 'ぬぬぬ');
      await typeAndCheck(tester, fillAnswer());

      final grades = [for (final a in await store.attempts()) a.grade];
      expect(grades, [Grade.wrong, Grade.hinted]);
    });

    testWidgets('a pick writes a clear when right and a wrong when not',
        (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      final choice = (openingPoints().first['practice'] as List)[1]
          as Map<String, dynamic>;
      expect(choice['options'], isNotEmpty);
      await tester.tap(find.text(choice['answer'] as String).first);
      await tester.pump();

      final a = (await store.attempts()).single;
      expect(a.probeId, 'p1');
      expect(a.template, 'choose');
      expect(a.production, isFalse);
      expect(a.grade, Grade.clear);
      expect(a.hintLevel, 0);

      // A wrong pick on the second point's first choice item, found inside the item
      // that shows its prompt, since another item may show the same option text.
      final second = openingPoints()[1];
      final practice =
          (second['practice'] as List).cast<Map<String, dynamic>>();
      final qi = practice
          .indexWhere((q) => (q['options'] as List? ?? const []).isNotEmpty);
      expect(qi, isNonNegative);
      final q = practice[qi];
      final wrong = (q['options'] as List)
          .cast<String>()
          .firstWhere((o) => o != q['answer']);
      final itemBox = find
          .ancestor(
              of: find.text(unanswered(q['prompt'] as String)),
              matching: find.byType(Column))
          .first;
      await tester
          .tap(find.descendant(of: itemBox, matching: find.text(wrong)));
      await tester.pump();

      final last = (await store.attempts()).last;
      expect(last.itemId, second['id']);
      expect(last.probeId, 'p$qi');
      expect(last.grade, Grade.wrong);
    });

    testWidgets(
        'Got it on an answer it cannot compare writes self, Missed it wrong',
        (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      await typeAndCheck(tester, 'ittara');
      // The check could not score, so the Check itself is no attempt yet.
      expect(await store.attempts(), isEmpty);

      await tester.tap(find.text('Got it'));
      await tester.pump();
      // A second tap on the same pill changes nothing and writes nothing.
      await tester.tap(find.text('Got it'));
      await tester.pump();
      await tester.tap(find.text('Missed it'));
      await tester.pump();

      final grades = [for (final a in await store.attempts()) a.grade];
      expect(grades, [Grade.self, Grade.wrong]);
      // Self earns no clear (PIN-3).
      expect((await store.mastery(openingPoint()))!.clears, isEmpty);
    });

    testWidgets(
        'the right answer retyped after a self-check showed it writes a hinted',
        (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      // Romaji from a keyboard left in English: the matcher cannot compare it, so
      // the screen prints the answer for the learner to compare.
      await typeAndCheck(tester, 'ittara');
      expect(find.textContaining('Compare with the answer:'), findsOneWidget);
      await typeAndCheck(tester, fillAnswer());

      final grades = [for (final a in await store.attempts()) a.grade];
      expect(grades, [Grade.hinted]);
      // The answer was on screen, so it earns no clear (PIN-3).
      expect((await store.mastery(openingPoint()))!.clears, isEmpty);
    });

    testWidgets('the right answer retyped after Got it writes self then hinted',
        (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      await typeAndCheck(tester, 'ittara');
      await tester.tap(find.text('Got it'));
      await tester.pump();
      await typeAndCheck(tester, fillAnswer());

      final grades = [for (final a in await store.attempts()) a.grade];
      expect(grades, [Grade.self, Grade.hinted]);
      expect((await store.mastery(openingPoint()))!.clears, isEmpty);
    });

    testWidgets(
        'an early clear changes neither the schedule nor mastery (PIN-14)',
        (tester) async {
      final store = await pumpWithStore(tester);
      await typeAndCheck(tester, fillAnswer());

      final a = (await store.attempts()).single;
      expect(a.grade, Grade.clear);
      expect(a.wasDue, isFalse);
      expect(a.source, Source.early);
      expect(await store.srs(openingPoint()), isNull);
      final m = await store.mastery(openingPoint());
      expect(m?.status ?? MasteryStatus.neu, MasteryStatus.neu);
      expect(m?.clears ?? const [], isEmpty);
    });

    testWidgets('an early wrong counts: the item is due tomorrow (PIN-14)',
        (tester) async {
      final store = await pumpWithStore(tester);
      await tester.tap(find.text('Show answer').first);
      await tester.pump();

      final a = (await store.attempts()).single;
      expect(a.grade, Grade.wrong);
      expect(a.source, Source.early);
      expect((await store.srs(openingPoint()))!.dueDay, today + 1);
    });

    testWidgets('a reading aid and the lesson pills write no attempt',
        (tester) async {
      final store = await pumpWithStore(tester, dueToday: true);
      await tester.tap(find.text('Tap for English').first);
      await tester.pump();
      await tester.tap(find.text('Can use it').first);
      await tester.pump();
      await tester.tap(find.text('Review').first);
      await tester.pump();

      expect(await store.attempts(), isEmpty);
    });

    testWidgets('a failed write says so, and the next answer still lands',
        (tester) async {
      final store = _FailingOnceStore();
      for (final p in openingPoints()) {
        await store.appendSeed(p['id'] as String, today, atUtc: noon.toUtc());
      }
      await pumpStudyScreen(
          tester,
          QuietRoomGrammarWidget(
              store: store, itemLookup: catalog.byId, clock: FixedClock(noon)));

      await typeAndCheck(tester, fillAnswer());
      await tester.pump();
      // Never lost quietly.
      expect(find.text('That answer was not saved.'), findsOneWidget);
      expect(await store.attempts(), isEmpty);

      // The write chain survives the failure.
      final choice = (openingPoints().first['practice'] as List)[1]
          as Map<String, dynamic>;
      await tester.tap(find.text(choice['answer'] as String).first);
      await tester.pump();
      final a = (await store.attempts()).single;
      expect(a.probeId, 'p1');
      expect(a.grade, Grade.clear);
    });

    testWidgets('a write that fails after the screen is gone is reported',
        (tester) async {
      final store = _GatedStore();
      for (final p in openingPoints()) {
        await store.appendSeed(p['id'] as String, today, atUtc: noon.toUtc());
      }
      await pumpStudyScreen(
          tester,
          QuietRoomGrammarWidget(
              store: store, itemLookup: catalog.byId, clock: FixedClock(noon)));
      await typeAndCheck(tester, fillAnswer());
      await tester.pump();
      expect(store.gate, isNotNull, reason: 'the write is in flight');

      // Leave the screen before the write settles.
      await tester.pumpWidget(const SizedBox());

      final reported = <FlutterErrorDetails>[];
      final prior = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = prior);
      store.gate!.completeError(StateError('disk full'));
      await tester.pump();
      FlutterError.onError = prior;

      // No snackbar can show, so the failure reaches a handler (S4).
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
      expect(reported.single.library, 'quiet room grammar');
      expect(reported.single.context.toString(),
          'while logging a grammar attempt');
      expect(await store.attempts(), isEmpty);
    });
  });

  group('opened at a point from a card (plan 2026-11-06, Task 1, D20)', () {
    /// The lesson with the most points, and its last point: the card furthest down.
    ({int lesson, Map<String, dynamic> point}) deepestPoint() {
      final lessons =
          (readLessonFile()['grammar'] as List).cast<Map<String, dynamic>>();
      final l = lessons.reduce((a, b) =>
          (b['points'] as List).length > (a['points'] as List).length ? b : a);
      return (
        lesson: l['lesson'] as int,
        point: (l['points'] as List).last as Map<String, dynamic>
      );
    }

    /// A practice card that opens [target] over itself.
    Widget card(Widget target) => Builder(
        builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => target)),
                  child: const Text('the card')),
            ));

    testWidgets('the screen opens on the point lesson with its card in view',
        (tester) async {
      final deep = deepestPoint();
      final pattern = deep.point['pattern'] as String;
      // The other lesson named too: the point wins.
      await pumpStudyScreen(
          tester,
          QuietRoomGrammarWidget(
              initialLesson: firstLesson()['lesson'] as int,
              initialPoint: deep.point['id'] as String),
          size: kPhoneView);
      await tester.pump();

      expect(
          find.text('第${deep.lesson}課', skipOffstage: false), findsOneWidget);
      expect(find.text(pattern), findsWidgets);
      expect(inView(tester, find.text(pattern).first), isTrue,
          reason: 'the point card is scrolled into the view');
    });

    testWidgets('the plain entry on the same lesson starts at the top',
        (tester) async {
      final deep = deepestPoint();
      final pattern = deep.point['pattern'] as String;
      await pumpStudyScreen(
          tester, QuietRoomGrammarWidget(initialLesson: deep.lesson),
          size: kPhoneView);
      await tester.pump();

      expect(find.text('第${deep.lesson}課'), findsOneWidget);
      final shown = find.text(pattern);
      expect(shown.evaluate().isEmpty || !inView(tester, shown.first), isTrue,
          reason: 'the last point sits below a phone view at the top');
      expect(find.text(kBackToPractice), findsNothing);
    });

    testWidgets('an open at a point leaves the remembered lesson alone',
        (tester) async {
      final deep = deepestPoint();
      // A lesson is named too, one that is neither the remembered 50 nor the point's
      // own: a plain open on it would remember it, an open at a point must not.
      final other = (readLessonFile()['grammar'] as List)
          .cast<Map<String, dynamic>>()
          .map((l) => l['lesson'] as int)
          .firstWhere((n) => n != deep.lesson && n != 50);
      await pumpStudyScreen(
          tester,
          QuietRoomGrammarWidget(
              initialLesson: other, initialPoint: deep.point['id'] as String),
          prefs: {'jp.grammar.lastLesson': 50});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('jp.grammar.lastLesson'), 50);
    });

    testWidgets('a point id in no lesson falls back to the lesson named',
        (tester) async {
      final deep = deepestPoint();
      await pumpStudyScreen(
          tester,
          QuietRoomGrammarWidget(
              initialLesson: deep.lesson, initialPoint: 'mari.point.999'),
          size: kPhoneView);
      await tester.pump();
      expect(find.text('第${deep.lesson}課'), findsOneWidget);
      expect(find.text(kBackToPractice), findsNothing);
    });

    testWidgets(
        'a point id in no lesson, with no lesson named, opens the first',
        (tester) async {
      await pumpStudyScreen(
          tester, const QuietRoomGrammarWidget(initialPoint: 'mari.point.999'),
          size: kPhoneView);
      await tester.pump();
      expect(find.text('第${firstLesson()['lesson']}課'), findsOneWidget);
    });

    testWidgets('Back to practice shows and returns to the card',
        (tester) async {
      final deep = deepestPoint();
      await pumpStudyScreen(
          tester,
          card(QuietRoomGrammarWidget(
              initialPoint: deep.point['id'] as String, fromCard: true)));
      await tester.tap(find.text('the card'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(kBackToPractice), findsOneWidget);
      await tester.tap(find.text(kBackToPractice));
      await tester.pumpAndSettle();
      expect(find.byType(QuietRoomGrammarWidget), findsNothing);
      expect(find.text('the card'), findsOneWidget);
    });

    testWidgets('opening at a point writes no attempt', (tester) async {
      final store = JpStoreMemory();
      final deep = deepestPoint();
      await pumpStudyScreen(
          tester,
          QuietRoomGrammarWidget(
              store: store,
              initialPoint: deep.point['id'] as String,
              fromCard: true));
      expect(await store.attempts(), isEmpty);
    });
  });
}

/// A memory store whose answer write waits on [gate] until the test settles it.
class _GatedStore extends JpStoreMemory {
  Completer<AnswerOutcome>? gate;

  @override
  Future<AnswerOutcome> recordAnswer(Attempt attempt,
      {required ItemDefLike? item, required Scheduler scheduler}) {
    gate = Completer<AnswerOutcome>();
    return gate!.future;
  }
}

/// A memory store whose first answer write throws, as a full disk would.
class _FailingOnceStore extends JpStoreMemory {
  bool _failed = false;

  @override
  Future<AnswerOutcome> recordAnswer(Attempt attempt,
      {required ItemDefLike? item, required Scheduler scheduler}) {
    if (!_failed) {
      _failed = true;
      return Future.error(StateError('disk full'));
    }
    return super.recordAnswer(attempt, item: item, scheduler: scheduler);
  }
}
