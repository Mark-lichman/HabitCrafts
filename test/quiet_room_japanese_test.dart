// Widget tests for the Japanese start screen: the search over the extraction catalog.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart';

import 'jp_screen_harness.dart';

void main() {
  testWidgets('home renders the hero and the study rows with no search',
      (tester) async {
    await pumpStudyScreen(tester, const QuietRoomJapaneseWidget());

    expect(find.text('日本語'), findsOneWidget);
    expect(find.text('START HERE'), findsOneWidget);
    expect(find.text('Grammar lessons'), findsOneWidget);
    expect(find.textContaining('found'), findsNothing);
  });

  testWidgets(
      'home search for "advice" lists the advice entries in the catalog',
      (tester) async {
    final doc = readLessonFile();
    final useLabels = {
      for (final u in (doc['uses'] as List).cast<Map<String, dynamic>>())
        u['id']: u['label'] as String
    };
    final typeLabels = {
      for (final x in (doc['types'] as List).cast<Map<String, dynamic>>())
        x['id']: x['label'] as String
    };
    // The same fields the screen searches: title, summary, type, search terms, uses.
    final expected = (doc['catalog'] as List)
        .cast<Map<String, dynamic>>()
        .where((e) => [
              e['title'],
              e['summary'],
              typeLabels[e['type']],
              ...(e['search'] as List? ?? const []),
              for (final u in e['uses'] as List) useLabels[u],
            ].any((h) => (h ?? '').toString().toLowerCase().contains('advice')))
        .toList();
    expect(expected, isNotEmpty,
        reason: 'the lesson file should hold advice patterns');

    await pumpStudyScreen(tester, const QuietRoomJapaneseWidget());
    await tester.enterText(find.byType(TextField), 'advice');
    await tester.pump();

    expect(find.text('${expected.length} found'), findsOneWidget);
    for (final e in expected) {
      expect(find.text(e['title'] as String), findsOneWidget);
    }
    // The hero gives way to the results.
    expect(find.text('START HERE'), findsNothing);
  });

  testWidgets('home search with no match says so', (tester) async {
    await pumpStudyScreen(tester, const QuietRoomJapaneseWidget());
    await tester.enterText(find.byType(TextField), 'zzqqxx');
    await tester.pump();

    expect(find.text('Nothing matches that.'), findsOneWidget);
  });
}
