// Widget tests for the Japanese start screen: the launch it resolves before it builds (the seed
// confirmation on a first launch, the Today card on today, resume and done), the launch it
// resolves again when a warm app meets a new local day, and the search over the extraction
// catalog.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/lessons_path_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/plan_builder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/relaunch.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed_confirm_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/study_export.dart'
    show kV2CanUseIt, kV2SelfCheckPrefix;

import 'jp_screen_harness.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));

const int day0 = 300;

/// 10:00 local on [day].
DateTime at(int day) => dayStart(day).add(const Duration(hours: 6));

/// A store whose first-launch seed ran on [day0]. [into] is the store to seed, else a new one.
Future<JpStoreMemory> seededStore({JpStoreMemory? into}) async {
  final store = into ?? JpStoreMemory();
  await seedFromLessons(day0, store, catalog, nowUtc: at(day0).toUtc());
  return store;
}

/// A memory store that counts its day-record reads: every launch resolution reads today's
/// record first, so the count tells whether the hub resolved the launch again.
class DayReadsStore extends JpStoreMemory {
  int dayReads = 0;

  @override
  Future<DayRecord?> day(int day) {
    dayReads++;
    return super.day(day);
  }
}

/// Pumps the hub on [store] at [day], and lets the launch resolve. A test that moves the day
/// under the warm hub passes its own [clock] and sets it later.
Future<void> pumpHub(WidgetTester tester, JpStore store,
    {int day = day0,
    Map<String, Object> prefs = const {},
    FixedClock? clock}) async {
  await pumpStudyScreen(
      tester,
      QuietRoomJapaneseWidget(
          store: store, catalog: catalog, clock: clock ?? FixedClock(at(day))),
      prefs: prefs);
  await settle(tester);
}

/// Sends one lifecycle event to the app, as the OS would, and lets the hub react.
Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
  tester.binding.handleAppLifecycleStateChanged(state);
  await settle(tester);
}

/// A store whose [day0] session is finished. [into] is the store to build it in.
Future<JpStoreMemory> doneStore({JpStoreMemory? into}) async {
  final store = await seededStore(into: into);
  final launch = await onLaunch(at(day0), store, catalog);
  await store.putDay(launch.record!.copyWith(position: 5, completed: true));
  return store;
}

/// Lets the store's futures and the asset loads finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

/// The hub on a seeded store: the Today card is up, so the search tests run over it.
Future<void> pumpSeededHub(WidgetTester tester) async =>
    pumpHub(tester, await seededStore());

Finder seedPill(String kind, int lesson) =>
    find.byKey(ValueKey('seed-$kind-$lesson'));

bool pillOn(WidgetTester tester, String kind, int lesson) =>
    tester.widget<QrPill>(seedPill(kind, lesson)).on;

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

/// A queue entry of [section], for a hand-built plan.
Map<String, dynamic> entryJson(String id, PlanSection section) => {
      'itemId': id,
      'kind': ItemKind.word.name,
      'section': section.name,
      'costSeconds': 15,
      'wasDue': true,
    };

/// A plan with no entries, for the queue line's format.
DayPlan emptyPlan() => DayPlan(
      day: day0,
      builtAtUtc: at(day0).toUtc(),
      entries: const [],
      daysMissed: 0,
      backlogSeconds: 0,
      targetSeconds: kTargetSeconds,
      ceilingSeconds: kCeilingSeconds,
      gateSeconds: 0,
      repairSlotSeconds: kRepairSlotSeconds,
      newSkip: NewSkip.values.first,
      keepSharpRan: false,
      dueLeft: 0,
      stretchOffer: true,
      catchUpOffer: false,
    );

void main() {
  setUpAll(holdHttpRequests);

  group('launch', () {
    testWidgets(
        'first launch opens the seed confirmation with the default ticks, '
        'and nothing is written before Confirm', (tester) async {
      final store = JpStoreMemory();
      await pumpHub(tester, store);

      expect(find.text('Which lessons have you studied?'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byKey(const ValueKey('today-card')), findsNothing);

      final words = catalogLessons(catalog, ItemKind.word);
      final grammar = catalogLessons(catalog, ItemKind.grammar);
      expect(words, containsAll([2, 30]));
      expect(grammar, containsAll([26, 31, 32]));
      for (final l in words) {
        expect(pillOn(tester, 'word', l), l >= 2 && l <= 30,
            reason: 'word lesson $l');
      }
      for (final l in grammar) {
        expect(pillOn(tester, 'grammar', l), l >= 26 && l <= 31,
            reason: 'grammar lesson $l');
      }
      expect(await store.seeds(), isEmpty);
      expect(await store.meta(kSeedFlag), isNull);
      expect(await store.lastDay(), isNull);
    });

    testWidgets(
        'the last grammar lesson opened past 31 extends the grammar ticks to it',
        (tester) async {
      await pumpHub(tester, JpStoreMemory(),
          prefs: {kLastGrammarLessonKey: 33});
      expect(pillOn(tester, 'grammar', 31), isTrue);
      expect(pillOn(tester, 'grammar', 32), isTrue);
      expect(pillOn(tester, 'grammar', 33), isTrue);
      expect(pillOn(tester, 'grammar', 34), isFalse);
    });

    test('a last grammar lesson inside the range never unticks one', () {
      final words = catalogLessons(catalog, ItemKind.word).toSet();
      for (final last in [null, 20, 26, 28, 31]) {
        final ticks = defaultSeedLessons(catalog, lastGrammarLesson: last);
        expect(ticks.grammarLessons, {26, 27, 28, 29, 30, 31},
            reason: 'last $last');
        expect(ticks.wordLessons,
            {for (var l = 2; l <= 30; l++) l}.intersection(words));
      }
    });

    testWidgets(
        'Confirm seeds the ticked lessons only, imports the v2 keys, writes no '
        'attempt, and opens the hub', (tester) async {
      final store = JpStoreMemory();
      final skipped = catalog.items
          .firstWhere((i) => i.kind == ItemKind.grammar && i.lesson == 27);
      await pumpHub(tester, store,
          prefs: {'$kV2SelfCheckPrefix${skipped.id}': kV2CanUseIt});

      await tester.tap(seedPill('word', 5));
      await tester.tap(seedPill('grammar', 27));
      await tester.pump();
      expect(pillOn(tester, 'word', 5), isFalse);
      expect(pillOn(tester, 'grammar', 27), isFalse);

      await tester.tap(find.text('Confirm'));
      await settle(tester);

      final seeded = {for (final e in await store.seeds()) e.itemId};
      bool any(ItemKind kind, int lesson) => catalog.items.any(
          (i) => i.kind == kind && i.lesson == lesson && seeded.contains(i.id));
      expect(any(ItemKind.word, 5), isFalse,
          reason: 'an unticked lesson stays New');
      expect(any(ItemKind.grammar, 27), isFalse);
      expect(any(ItemKind.word, 6), isTrue);
      expect(any(ItemKind.grammar, 28), isTrue);
      // The v2 keys came in through the migration: prefs and the grammar went together.
      expect((await store.notes())[skipped.id], isNotNull);
      // PIN-7: the seed is no answer.
      expect(await store.attempts(), isEmpty);
      expect(await store.allMastery(), isEmpty);
      expect(await store.allSrs(), isEmpty);

      // Then the hub, with today's plan.
      expect(find.byKey(const ValueKey('today-card')), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('START HERE'), findsOneWidget);
    });
  });

  group('Today card', () {
    testWidgets(
        'names the sections and their counts, the minutes line and Start, '
        'above the hero', (tester) async {
      final store = await seededStore();
      await pumpHub(tester, store);

      final plan = DayPlan.decode((await store.day(day0))!.plan);
      final line = todaySectionsLine(plan);
      expect(line, contains('Due '));
      expect(find.text(line), findsOneWidget);
      expect(find.text(todayMinutesLine(plan)), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);

      final card = tester.getTopLeft(find.byKey(const ValueKey('today-card')));
      final hero = tester.getTopLeft(find.text('START HERE'));
      expect(card.dy, lessThan(hero.dy));
      expect(find.text('Grammar lessons'), findsOneWidget);
    });

    test('the queue line reads as the plan sections, then the stretch', () {
      var n = 0;
      List<Map<String, dynamic>> many(int count, PlanSection s) =>
          [for (var i = 0; i < count; i++) entryJson('x${n++}', s)];
      final plan = DayPlan.fromJson({
        ...emptyPlan().toJson(),
        'entries': [
          ...many(3, PlanSection.repair),
          ...many(42, PlanSection.due),
          ...many(10, PlanSection.keepSharp),
          ...many(8, PlanSection.newItems),
        ],
        'stretchEntries': many(4, PlanSection.newItems),
      });
      expect(todaySectionsLine(plan),
          'Repair 3 · Due 42 · Keep-sharp 10 · New 8 · +4 stretch');
      expect(todayMinutesLine(plan), '15 to 20 minutes');

      final noStretch =
          DayPlan.fromJson({...plan.toJson(), 'stretchOffer': false});
      expect(todaySectionsLine(noStretch),
          'Repair 3 · Due 42 · Keep-sharp 10 · New 8');

      final short = DayPlan.fromJson(
          {...plan.toJson(), 'entries': many(6, PlanSection.due)});
      expect(
          todayMinutesLine(short), 'About 2 min, under the 15-minute target');
    });

    testWidgets('a session already under way shows Resume', (tester) async {
      final store = await seededStore();
      final launch = await onLaunch(at(day0), store, catalog);
      await store.putDay(launch.record!.copyWith(position: 3));
      await pumpHub(tester, store);

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('3 of ${launch.plan!.entries.length} answered'),
          findsOneWidget);
    });

    testWidgets('a finished day shows the end state and no Start',
        (tester) async {
      await pumpHub(tester, await doneStore());

      expect(find.text('Done for today'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets("Start opens the Review session on today's plan",
        (tester) async {
      final store = await seededStore();
      await pumpHub(tester, store);

      await tester.tap(find.text('Start'));
      await settle(tester);

      expect(find.byType(SessionWidget), findsOneWidget);
      final plan = DayPlan.decode((await store.day(day0))!.plan);
      expect(find.text(sectionPosition(plan, 0)), findsOneWidget);
    });
  });

  // The hub is the app's home and stays warm overnight, so the launch resolved at start is
  // stale by morning. The store is the oracle: today's record exists only once the launch
  // ran again for the new day.
  group('a warm hub on a new day (End state 6)', () {
    testWidgets(
        'a resume on the next day replaces the end card with the new plan and Start; '
        'inactive, hidden and paused on that day change nothing',
        (tester) async {
      final store = await doneStore();
      final clock = FixedClock(at(day0));
      await pumpHub(tester, store, clock: clock);
      expect(find.text('Done for today'), findsOneWidget);

      clock.set(at(day0 + 1));
      // The states on the way to the background and back, in the order the framework
      // allows them. Only resumed is the app in front again.
      await lifecycle(tester, AppLifecycleState.inactive);
      await lifecycle(tester, AppLifecycleState.hidden);
      await lifecycle(tester, AppLifecycleState.paused);
      await lifecycle(tester, AppLifecycleState.hidden);
      await lifecycle(tester, AppLifecycleState.inactive);
      expect(find.text('Done for today'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(await store.day(day0 + 1), isNull);

      await lifecycle(tester, AppLifecycleState.resumed);
      expect(find.text('Done for today'), findsNothing);
      expect(find.text('Start'), findsOneWidget);
      final plan = DayPlan.decode((await store.day(day0 + 1))!.plan);
      expect(plan.returnMode, isFalse);
      expect(find.text(todaySectionsLine(plan)), findsOneWidget);
      // Yesterday stays finished: a relaunch rewrites no earlier day (PIN-9).
      expect((await store.day(day0))!.completed, isTrue);
    });

    testWidgets('a resume on the same day leaves the launch alone',
        (tester) async {
      final store = DayReadsStore();
      await doneStore(into: store);
      await pumpHub(tester, store);
      final reads = store.dayReads;
      expect(reads, greaterThan(0), reason: 'the first launch read the record');

      await lifecycle(tester, AppLifecycleState.resumed);
      expect(find.text('Done for today'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(store.dayReads, reads, reason: 'no second launch resolution');
    });

    testWidgets(
        'a resume behind the session waits: the new day resolves when the session '
        'returns, after its answers', (tester) async {
      final store = await seededStore();
      final clock = FixedClock(at(day0));
      await pumpHub(tester, store, clock: clock);
      await tester.tap(find.text('Start'));
      await settle(tester);
      expect(find.byType(SessionWidget), findsOneWidget);

      clock.set(at(day0 + 1));
      await lifecycle(tester, AppLifecycleState.resumed);
      expect(find.byType(SessionWidget), findsOneWidget);
      expect(await store.day(day0 + 1), isNull,
          reason: 'tomorrow is not built under a session still under way');

      Navigator.of(tester.element(find.byType(SessionWidget))).pop();
      await settle(tester);
      expect(find.byType(SessionWidget), findsNothing);
      expect(find.text('Start'), findsOneWidget);
      expect(await store.day(day0 + 1), isNotNull);
    });

    testWidgets(
        'a study screen that returns on a new day brings the new plan with it',
        (tester) async {
      final store = await doneStore();
      final clock = FixedClock(at(day0));
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => QuietRoomJapaneseWidget(
                store: store, catalog: catalog, clock: clock)),
        // "Grammar lessons" opens the lesson path (Task 26).
        GoRoute(
          name: LessonsPathWidget.routeName,
          path: LessonsPathWidget.routePath,
          builder: (_, __) => const Text('the grammar list'),
        ),
      ]);
      addTearDown(router.dispose);
      await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));
      await settle(tester);
      expect(find.text('Done for today'), findsOneWidget);

      await tester.tap(find.text('Grammar lessons'));
      await tester.pumpAndSettle();
      expect(find.text('the grammar list'), findsOneWidget);

      clock.set(at(day0 + 1));
      router.pop();
      await tester.pumpAndSettle();
      await settle(tester);
      expect(find.text('the grammar list'), findsNothing);
      expect(find.text('Done for today'), findsNothing);
      expect(find.text('Start'), findsOneWidget);
      expect(await store.day(day0 + 1), isNotNull);
    });
  });

  testWidgets('home renders the hero and the study rows with no search',
      (tester) async {
    await pumpSeededHub(tester);

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

    await pumpSeededHub(tester);
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
    await pumpSeededHub(tester);
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

    await pumpSeededHub(tester);
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

    await pumpSeededHub(tester);
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
