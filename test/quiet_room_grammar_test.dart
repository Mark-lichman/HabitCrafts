// Widget tests for the grammar screen: the By use view, a choice question's feedback,
// the typed-answer box (PIN-3), the 漢字 toggle (PIN-4) and the speaking drill link (PIN-6).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';

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
    final why = (item['why_wrong'] as Map).cast<String, String>();

    await pumpStudyScreen(tester, const QuietRoomGrammarWidget());
    await tester.tap(find.text(item['answer'] as String).first);
    await tester.pump();

    // The prompt swaps ＿＿ for ［answer］ once a pick is made, so this proves the tap registered.
    expect(find.textContaining('［${item['answer']}］'), findsOneWidget);
    for (final w in why.keys) {
      expect(find.textContaining('$w: ${why[w]}'), findsNothing);
    }
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
      // A right pick names no wrong-option reason.
      for (final w in (item['why_wrong'] as Map? ?? const {}).keys) {
        expect(find.textContaining('$w: '), findsNothing);
      }
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
}
