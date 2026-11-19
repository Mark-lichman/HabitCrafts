// Widget tests for the Japanese start screen: the search over the extraction catalog.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart';

import 'jp_screen_harness.dart';

/// The catalog entries the home search should list for [query]: the same fields the
/// screen searches (title, summary, type, search terms, source files, uses).
List<Map<String, dynamic>> expectedHits(
    Map<String, dynamic> doc, String query) {
  final useLabels = {
    for (final u in (doc['uses'] as List).cast<Map<String, dynamic>>())
      u['id']: u['label'] as String
  };
  final typeLabels = {
    for (final x in (doc['types'] as List).cast<Map<String, dynamic>>())
      x['id']: x['label'] as String
  };
  final q = query.toLowerCase();
  return (doc['catalog'] as List)
      .cast<Map<String, dynamic>>()
      .where((e) => [
            e['title'],
            e['summary'],
            typeLabels[e['type']],
            ...(e['search'] as List? ?? const []),
            ...(e['from'] as List? ?? const []),
            for (final u in e['uses'] as List) useLabels[u],
          ].any((h) => (h ?? '').toString().toLowerCase().contains(q)))
      .toList();
}

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
    final expected = expectedHits(doc, 'advice');
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

  testWidgets('home search finds a data file by name, with its live counts',
      (tester) async {
    final doc = readLessonFile();
    final file = (doc['catalog'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) =>
            e['type'] == 'source_file' && e['title'] == 'jp_lessons.json');

    await pumpStudyScreen(tester, const QuietRoomJapaneseWidget());
    await tester.enterText(find.byType(TextField), 'jp_lessons.json');
    await tester.pump();

    expect(
        find.descendant(
            of: find.byType(QrCard), matching: find.text('jp_lessons.json')),
        findsOneWidget);
    expect(find.text(file['summary'] as String), findsOneWidget);
    for (final entry in (file['counts'] as Map).entries) {
      expect(
          find.textContaining('${entry.value} ${entry.key}'), findsOneWidget);
    }
  });

  testWidgets('opening a data file applies its search to the search box',
      (tester) async {
    final doc = readLessonFile();
    final file = (doc['catalog'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) =>
            e['type'] == 'source_file' &&
            e['title'] == 's01_number/lesson_bundle.json');
    final query = (file['open'] as Map)['query'] as String;
    final expected = expectedHits(doc, query);
    expect(expected.length, greaterThan(1),
        reason: 'the number tables came from this file');

    await pumpStudyScreen(tester, const QuietRoomJapaneseWidget());
    await tester.enterText(
        find.byType(TextField), 's01_number/lesson_bundle.json');
    await tester.pump();
    expect(find.text('1 found'), findsOneWidget);

    // Drop focus first. A focused field repairs an invalid selection on its
    // own, so only an unfocused field shows the selection _searchFor sets.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    // The result card, not the search box that holds the same text.
    await tester.tap(find.descendant(
        of: find.byType(QrCard),
        matching: find.text('s01_number/lesson_bundle.json')));
    await tester.pump();

    final box = tester.widget<TextField>(find.byType(TextField));
    expect(box.controller!.text, query);
    // The cursor sits at the end, so the next typed character extends the query.
    expect(box.controller!.selection,
        TextSelection.collapsed(offset: query.length));
    expect(find.text('${expected.length} found'), findsOneWidget);
    for (final e in expected) {
      expect(find.text(e['title'] as String), findsOneWidget);
    }
  });
}
