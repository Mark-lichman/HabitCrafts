// Widget tests for the seed confirmation's Select all / Clear all toggles (operator request
// 2026-11-05, from the Phase 4 local test; plan 2026-11-02, Tasks 20 and 24, PIN-12).
//
// Beside each section heading (Vocabulary lessons, Grammar lessons) a toggle reads Select all
// unless every lesson of that section is ticked, then Clear all. Each toggle ticks or unticks
// only its own section; the ticked count follows; Confirm with no lesson ticked stays allowed
// and seeds no lesson item (the level-0 items every seed holds still come in, End state 7).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart'
    show ItemKind;
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed_confirm_widget.dart';

import 'jp_screen_harness.dart' show holdHttpRequests;

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));

final wordLessons = catalogLessons(catalog, ItemKind.word);
final grammarLessons = catalogLessons(catalog, ItemKind.grammar);

class Page {
  Page(this.tester, this.store);

  final WidgetTester tester;
  final JpStoreMemory store;
  int seeded = 0;

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  /// Whether lesson [l] of section [key] (`word` or `grammar`) is ticked.
  bool ticked(String key, int l) =>
      tester.widget<QrPill>(find.byKey(ValueKey('seed-$key-$l'))).on;

  Set<int> tickedIn(String key, List<int> lessons) => {
        for (final l in lessons)
          if (ticked(key, l)) l
      };

  /// The label of section [key]'s toggle.
  String toggleLabel(String key) {
    final text = find.descendant(
        of: find.byKey(ValueKey('seed-$key-all')), matching: find.byType(Text));
    return tester.widget<Text>(text).data!;
  }

  Future<void> tapToggle(String key) async {
    final f = find.byKey(ValueKey('seed-$key-all'));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await settle();
  }

  Future<void> tapPill(String key, int l) async {
    final f = find.byKey(ValueKey('seed-$key-$l'));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await settle();
  }

  bool showsCount(int n) =>
      find.text('$n lessons ticked').evaluate().isNotEmpty;
}

Future<Page> pumpConfirm(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.runAsync(JpGrammarData.load);
  final store = JpStoreMemory();
  final page = Page(tester, store);
  await tester.pumpWidget(MaterialApp(
    home: SeedConfirmWidget(
      store: store,
      catalog: catalog,
      clock: FixedClock(DateTime(2026, 11, 5, 10)),
      onSeeded: () => page.seeded++,
    ),
  ));
  await page.settle();
  return page;
}

void main() {
  setUpAll(holdHttpRequests);

  for (final (key, lessons, other, otherLessons) in [
    ('word', wordLessons, 'grammar', grammarLessons),
    ('grammar', grammarLessons, 'word', wordLessons),
  ]) {
    group('the $key section toggle', () {
      testWidgets(
          'Select all ticks every lesson of the section and reads Clear all; the count '
          'follows; the other section is untouched', (tester) async {
        final p = await pumpConfirm(tester);
        // Untick one first, so the toggle reads Select all whatever the defaults are.
        if (!p.ticked(key, lessons.first)) await p.tapPill(key, lessons.first);
        await p.tapPill(key, lessons.first);
        expect(p.toggleLabel(key), kSeedSelectAll);
        final otherBefore = p.tickedIn(other, otherLessons);

        await p.tapToggle(key);
        expect(p.tickedIn(key, lessons), lessons.toSet());
        expect(p.toggleLabel(key), kSeedClearAll);
        expect(p.tickedIn(other, otherLessons), otherBefore);
        expect(p.showsCount(lessons.length + otherBefore.length), isTrue);

        // Unticking any one lesson puts the toggle back to Select all.
        await p.tapPill(key, lessons.last);
        expect(p.toggleLabel(key), kSeedSelectAll);
      });

      testWidgets(
          'Clear all unticks every lesson of the section and reads Select all; the count '
          'follows; the other section is untouched', (tester) async {
        final p = await pumpConfirm(tester);
        if (p.toggleLabel(key) == kSeedSelectAll) await p.tapToggle(key);
        expect(p.toggleLabel(key), kSeedClearAll);
        final otherBefore = p.tickedIn(other, otherLessons);

        await p.tapToggle(key);
        expect(p.tickedIn(key, lessons), isEmpty);
        expect(p.toggleLabel(key), kSeedSelectAll);
        expect(p.tickedIn(other, otherLessons), otherBefore);
        expect(p.showsCount(otherBefore.length), isTrue);
      });
    });
  }

  testWidgets(
      'Confirm with no lesson ticked is allowed and seeds no lesson item, only the level-0 '
      'items', (tester) async {
    final p = await pumpConfirm(tester);
    for (final key in ['word', 'grammar']) {
      if (p.toggleLabel(key) == kSeedSelectAll) await p.tapToggle(key);
      await p.tapToggle(key);
      expect(p.toggleLabel(key), kSeedSelectAll);
    }
    expect(p.showsCount(0), isTrue);

    final confirm = find.text('Confirm');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await p.settle();
    await p.settle();

    expect(p.seeded, 1);
    final seeds = await p.store.seeds();
    expect(seeds, isNotEmpty);
    for (final s in seeds) {
      expect(catalog.byId(s.itemId)!.prereqLevel, 0,
          reason: '${s.itemId} is a lesson item, but no lesson was ticked');
    }
    expect(await p.store.attempts(), isEmpty, reason: 'PIN-7');
  });
}
