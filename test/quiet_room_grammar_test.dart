// Widget tests for the grammar screen: the By use view and a choice question's feedback.

import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart';

import 'jp_screen_harness.dart';

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
}
