// Widget tests for Discuss with Mari (plan 2026-11-06, Task 4, End state 3, PIN-6).
//
// The toggle on a Review session card, on a practice card and on the item page sets the item's
// Discuss mark and a second tap clears it; a mark writes no attempt and leaves the schedule, the
// mastery state and the day's position as they were; a card answered after a mark is graded as
// if it had none. The list is reached from Today's quiet links under the router, its link counts
// the marks, each row opens its item page, and "Discussed" clears the row. A mark carried
// through export and import shows in the list on the importing store.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/discuss_list_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_detail_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/plan_builder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/study_export.dart';

import 'jp_screen_harness.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));
final words = catalog.ofKind(ItemKind.word);

const int today = 300;

/// 10:00 local on [day].
DateTime at(int day) => dayStart(day).add(const Duration(hours: 6));

/// The fake probe: the item id and a clear and a wrong answer.
Widget fakeProbe(BuildContext context, SessionProbeRequest r) {
  final probe = r.item.scoredProbes.first;
  DrillAnswer draft(Grade g) => DrillAnswer(
      itemId: r.item.id,
      probeId: probe.id,
      template: probe.template,
      production: probe.production,
      selfGraded: probe.selfGraded,
      grade: g);
  return Column(children: [
    Text('probe ${r.item.id}'),
    for (final g in [Grade.clear, Grade.wrong])
      TextButton(
          onPressed: () => r.onAnswer(draft(g)),
          child: Text('answer ${g.name}')),
  ]);
}

DayPlan planOf(List<ItemDef> items) => DayPlan(
      day: today,
      builtAtUtc: at(today).toUtc(),
      entries: [
        for (final i in items)
          QueueEntry(
              itemId: i.id,
              kind: i.kind,
              section: PlanSection.due,
              costSeconds: 10,
              wasDue: true,
              lesson: i.lesson),
      ],
      daysMissed: 0,
      backlogSeconds: 0,
      targetSeconds: kTargetSeconds,
      ceilingSeconds: kCeilingSeconds,
      gateSeconds: (kTargetSeconds * kGateFactor).round(),
      repairSlotSeconds: kRepairSlotSeconds,
      newSkip: NewSkip.none,
      keepSharpRan: false,
      dueLeft: 0,
      stretchOffer: false,
      stretchEntries: const [],
      catchUpOffer: false,
      catchUpEntries: const [],
    );

/// A clear review on [item] on [day], written through the store's live path.
Future<void> clearOn(JpStore store, ItemDef item, int day) {
  final p = item.scoredProbes.first;
  return store.recordAnswer(
      Attempt(
        itemId: item.id,
        probeId: p.id,
        template: p.template,
        production: p.production,
        selfGraded: p.selfGraded,
        atUtc: at(day).toUtc(),
        localDay: day,
        grade: Grade.clear,
        rating: fsrsRatingFor(Grade.clear),
        hintLevel: 0,
        wasDue: true,
        source: Source.review,
        sessionId: 'test',
      ),
      item: item,
      scheduler: const FsrsScheduler());
}

/// What a mark must never move: the item's attempts, schedule and mastery state.
Future<List<Object?>> recordOf(JpStore store, String itemId) async => [
      (await store.attempts(itemId: itemId)).length,
      await store.srs(itemId),
      await store.mastery(itemId),
    ];

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  final f = find.text(label);
  expect(f, findsOneWidget, reason: 'a "$label" control');
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

Future<void> pumpSession(
    WidgetTester tester, JpStoreMemory store, List<ItemDef> items) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final plan = planOf(items);
  await store.putDay(DayRecord(day: today, plan: plan.encode()));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SessionWidget(
        // A new store is a new session, never the State of the one before.
        key: ObjectKey(store),
        plan: plan,
        store: store,
        clock: FixedClock(at(today)),
        catalog: catalog,
        probeBuilder: fakeProbe,
      ),
    ),
  ));
  await settle(tester);
}

void main() {
  setUpAll(holdHttpRequests);

  test('the list reads oldest mark first, a tie by item id', () {
    DiscussMark m(String id, int minute) =>
        DiscussMark(itemId: id, atUtc: DateTime.utc(2026, 11, 6, 10, minute));
    expect(discussOrder([m('c', 2), m('b', 1), m('a', 2)]).map((x) => x.itemId),
        ['b', 'a', 'c']);
    expect(discussLinkLabel(0), kDiscussWithMari);
    expect(discussLinkLabel(3), '$kDiscussWithMari · 3');
  });

  group('the toggle on a session card', () {
    testWidgets(
        'sets the mark, a second tap clears it, and neither writes an attempt '
        'or moves the schedule, the mastery state or the day', (tester) async {
      final store = JpStoreMemory();
      final item = words.first;
      await clearOn(store, item, today - 3);
      final before = await recordOf(store, item.id);
      await pumpSession(tester, store, [item]);
      final dayBefore = await store.day(today);

      expect(find.text(kDiscussWithMari), findsOneWidget);
      await tapText(tester, kDiscussWithMari);
      expect(find.text(kDiscussMarked), findsOneWidget);
      final mark = await store.discuss(item.id);
      expect(mark, isNotNull);
      expect(mark!.atUtc, at(today).toUtc());
      expect(await recordOf(store, item.id), before);
      expect((await store.day(today))!.position, dayBefore!.position);
      expect(find.text('probe ${item.id}'), findsOneWidget,
          reason: 'the card stays unanswered');

      await tapText(tester, kDiscussMarked);
      expect(await store.discuss(item.id), isNull);
      expect(find.text(kDiscussWithMari), findsOneWidget);
      expect(await recordOf(store, item.id), before);
    });

    testWidgets(
        'a card answered after a mark is graded and scheduled as without one',
        (tester) async {
      final item = words.first;
      final unmarked = JpStoreMemory();
      await pumpSession(tester, unmarked, [item]);
      await tapText(tester, 'answer clear');

      final marked = JpStoreMemory();
      await pumpSession(tester, marked, [item]);
      await tapText(tester, kDiscussWithMari);
      await tapText(tester, 'answer clear');

      final a = (await marked.attempts(itemId: item.id)).single;
      expect(a.grade, Grade.clear);
      expect(a.hintLevel, 0);
      expect(await marked.srs(item.id), await unmarked.srs(item.id));
      expect(await marked.mastery(item.id), await unmarked.mastery(item.id));
      expect(await marked.discuss(item.id), isNotNull,
          reason: 'the answer leaves the mark in place');
    });

    testWidgets('a held card after a wrong still carries the toggle',
        (tester) async {
      final store = JpStoreMemory();
      final item = words.first;
      await pumpSession(tester, store, [item]);
      await tapText(tester, 'answer wrong');
      expect(find.text('Next'), findsOneWidget, reason: 'the probe is held');
      await tapText(tester, kDiscussWithMari);
      expect(await store.discuss(item.id), isNotNull);
      expect((await store.attempts(itemId: item.id)).single.grade, Grade.wrong,
          reason: 'the mark adds no attempt to the wrong');
    });
  });

  group('the toggle on the item page', () {
    Future<void> pumpItem(
        WidgetTester tester, JpStore store, ItemDef item) async {
      tester.view.physicalSize = const Size(1000, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: ItemDetailWidget(
          itemId: item.id,
          store: store,
          catalog: catalog,
          clock: FixedClock(at(today)),
          probeBuilder: fakeProbe,
        ),
      ));
      await settle(tester);
    }

    testWidgets('sets and clears the mark and writes nothing else',
        (tester) async {
      final store = JpStoreMemory();
      final item = words[1];
      await clearOn(store, item, today - 2);
      final before = await recordOf(store, item.id);
      await pumpItem(tester, store, item);

      await tapText(tester, kDiscussWithMari);
      expect(await store.discuss(item.id), isNotNull);
      expect(await recordOf(store, item.id), before);
      await tapText(tester, kDiscussMarked);
      expect(await store.discuss(item.id), isNull);
      expect(await recordOf(store, item.id), before);
    });

    testWidgets('shows a mark set elsewhere, and practice cards carry it too',
        (tester) async {
      final store = JpStoreMemory();
      final item = words[2];
      await store.setDiscuss(item.id, atUtc: at(today));
      await pumpItem(tester, store, item);
      expect(find.text(kDiscussMarked), findsOneWidget);

      await tapText(tester, kPracticeNow);
      await tester.pumpAndSettle();
      expect(find.text('probe ${item.id}'), findsOneWidget);
      expect(find.text(kDiscussMarked), findsOneWidget,
          reason: 'the practice card shows the same mark');
      await tapText(tester, kDiscussMarked);
      expect(await store.discuss(item.id), isNull);
      expect(await store.attempts(itemId: item.id), isEmpty);

      // Back on the item page, the toggle reads the cleared mark again.
      await tester.pageBack();
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.text(kDiscussWithMari), findsOneWidget);
      expect(find.text(kDiscussMarked), findsNothing);
    });
  });

  group('the list on Today', () {
    /// A store whose first-launch seed ran on [today].
    Future<JpStoreMemory> seeded([JpStoreMemory? into]) async {
      final store = into ?? JpStoreMemory();
      await seedFromLessons(today, store, catalog, nowUtc: at(today).toUtc());
      return store;
    }

    Future<void> pumpToday(WidgetTester tester, JpStore store) async {
      final clock = FixedClock(at(today));
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => QuietRoomJapaneseWidget(
                store: store, catalog: catalog, clock: clock)),
        GoRoute(
          name: DiscussListWidget.routeName,
          path: DiscussListWidget.routePath,
          builder: (_, __) =>
              DiscussListWidget(store: store, catalog: catalog, clock: clock),
        ),
      ]);
      addTearDown(router.dispose);
      await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));
      await settle(tester);
    }

    testWidgets(
        'the quiet link counts the marks and opens the list; a row opens its '
        'item and Discussed clears it', (tester) async {
      final store = await seeded();
      final a = words[3], b = words[4];
      await store.setDiscuss(a.id,
          note: 'when to use it', atUtc: at(today - 1));
      await store.setDiscuss(b.id, atUtc: at(today));
      final before = [
        await recordOf(store, a.id),
        await recordOf(store, b.id),
      ];
      await pumpToday(tester, store);

      expect(
          find.widgetWithText(TextButton, discussLinkLabel(2)), findsOneWidget);
      await tapText(tester, discussLinkLabel(2));
      await tester.pumpAndSettle();
      expect(find.byType(DiscussListWidget), findsOneWidget);
      expect(find.byKey(ValueKey('discuss-row-${a.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('discuss-row-${b.id}')), findsOneWidget);
      expect(find.text('when to use it'), findsOneWidget);
      expect(
          tester.getTopLeft(find.byKey(ValueKey('discuss-row-${a.id}'))).dy,
          lessThan(tester
              .getTopLeft(find.byKey(ValueKey('discuss-row-${b.id}')))
              .dy),
          reason: 'the older mark first');

      // A row opens its item page; Back returns to the list.
      await tester.tap(find.descendant(
          of: find.byKey(ValueKey('discuss-row-${a.id}')),
          matching: find.text(a.title)));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(
          find.byWidgetPredicate(
              (w) => w is ItemDetailWidget && w.itemId == a.id),
          findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DiscussListWidget), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('discussed-${a.id}')));
      await settle(tester);
      expect(find.byKey(ValueKey('discuss-row-${a.id}')), findsNothing);
      expect(await store.discuss(a.id), isNull);
      await tester.tap(find.byKey(ValueKey('discussed-${b.id}')));
      await settle(tester);
      expect(find.text(kDiscussEmpty), findsOneWidget);
      expect(await store.discussMarks(), isEmpty);
      expect([await recordOf(store, a.id), await recordOf(store, b.id)], before,
          reason: 'clearing a mark writes nothing else');

      await tester.pageBack();
      await tester.pumpAndSettle();
      await settle(tester);
      expect(find.widgetWithText(TextButton, kDiscussWithMari), findsOneWidget,
          reason: 'the count goes with the cleared marks');
    });

    testWidgets('a mark carried through export and import shows in the list',
        (tester) async {
      final source = JpStoreMemory();
      final item = words[5];
      await clearOn(source, item, today - 4);
      await source.setDiscuss(item.id, note: 'ask Mari', atUtc: at(today));
      final text = await exportStudy(source, exportedAt: at(today).toUtc());

      final target = JpStoreMemory();
      await importStudy(target, text,
          lookup: catalog.byId, scheduler: const FsrsScheduler());
      await seeded(target);
      await pumpToday(tester, target);

      await tapText(tester, discussLinkLabel(1));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('discuss-row-${item.id}')), findsOneWidget);
      expect(find.text('ask Mari'), findsOneWidget);
      expect(await target.srs(item.id), await source.srs(item.id));
      expect(await target.mastery(item.id), await source.mastery(item.id));
    });
  });
}
