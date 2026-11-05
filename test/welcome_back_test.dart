// The Welcome back screen (Task 20, D9, PIN-9). A store seeded and answered on day0, then
// launched after a break: the hub opens on Welcome back with the days away, the items due, the
// days to catch up at the target, New paused, the items now Shaky with the regain rule, and one
// loud Start. The screen resets no item, Start opens the session, and Not now shows the hub.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/plan_builder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/relaunch.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/welcome_back_widget.dart';

import 'jp_screen_harness.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));
const scheduler = FsrsScheduler();

const int day0 = 300;

/// Four days later: three local days missed, so return mode.
const int back = day0 + 4;

/// 10:00 local on [day].
DateTime at(int day) => dayStart(day).add(const Duration(hours: 6));

Attempt answerOn(ItemDef item, int day, Grade grade) {
  final p = item.scoredProbes.first;
  return Attempt(
    itemId: item.id,
    probeId: p.id,
    template: p.template,
    production: p.production,
    selfGraded: p.selfGraded,
    atUtc: at(day).toUtc(),
    localDay: day,
    grade: grade,
    rating: fsrsRatingFor(grade),
    wasDue: true,
    source: Source.review,
    sessionId: 'review-$day',
  );
}

/// The item made Shaky in [awayStore].
final ItemDef shakyItem = catalog.items.firstWhere(
    (i) => i.kind == ItemKind.particle && i.scoredProbes.isNotEmpty);

/// A store seeded on [day0], with a finished session that day and one item now Shaky.
Future<JpStoreMemory> awayStore() async {
  final store = JpStoreMemory();
  await seedFromLessons(day0, store, catalog, nowUtc: at(day0).toUtc());
  final first = await onLaunch(at(day0), store, catalog);
  for (final e in first.plan!.entries.take(6)) {
    final item = catalog.byId(e.itemId)!;
    await store.recordAnswer(answerOn(item, day0, Grade.clear),
        item: item, scheduler: scheduler);
  }
  await store.putDay(first.record!.copyWith(position: 6, completed: true));
  // A Shaky badge comes from a real wrong on a Mastered item; the screen only reads it.
  await store.putMastery(
      MasteryState(itemId: shakyItem.id, status: MasteryStatus.shaky));
  return store;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Future<void> pumpHub(WidgetTester tester, JpStore store, int day) async {
  await pumpStudyScreen(
      tester,
      QuietRoomJapaneseWidget(
          store: store, catalog: catalog, clock: FixedClock(at(day))));
  await settle(tester);
}

void main() {
  setUpAll(holdHttpRequests);

  testWidgets(
      'after two or more missed days the hub opens on Welcome back with the days '
      'away, the items due, the catch-up days, New paused and the Shaky badges',
      (tester) async {
    final store = await awayStore();
    await pumpHub(tester, store, back);

    final plan = DayPlan.decode((await store.day(back))!.plan);
    expect(plan.returnMode, isTrue);
    final due = (await store.dueOnOrBefore(back)).length;
    final catchUp =
        (plan.backlogSeconds + plan.targetSeconds - 1) ~/ plan.targetSeconds;

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('You were away 3 days.'), findsOneWidget);
    expect(find.text('$due items due.'), findsOneWidget);
    expect(
        find.text('About ${catchUp < 2 ? '1 day' : '$catchUp days'} to catch '
            'up at ${kTargetSeconds ~/ 60} minutes a day.'),
        findsOneWidget);
    expect(find.text('New items are paused until the backlog is down.'),
        findsOneWidget);
    expect(find.text('Now Shaky'), findsOneWidget);
    expect(find.text(shakyItem.title), findsOneWidget);
    expect(find.text(regainRuleLine()), findsOneWidget);
    expect(regainRuleLine(), contains('$kRegainGapDays or more days apart'));
    expect(find.text('Start'), findsOneWidget);
    // The hub waits behind it.
    expect(find.byKey(const ValueKey('today-card')), findsNothing);
  });

  testWidgets('Welcome back resets no item (PIN-9)', (tester) async {
    final store = await awayStore();
    final attempts = (await store.attempts()).length;
    final srs = {
      for (final e in (await store.allSrs()).entries) e.key: e.value.toJson()
    };
    final mastery = {
      for (final e in (await store.allMastery()).entries) e.key: e.value.status
    };

    await pumpHub(tester, store, back);
    expect(find.text('Welcome back'), findsOneWidget);

    expect((await store.attempts()).length, attempts);
    expect({
      for (final e in (await store.allSrs()).entries) e.key: e.value.toJson()
    }, srs);
    expect({
      for (final e in (await store.allMastery()).entries) e.key: e.value.status
    }, mastery);
  });

  testWidgets('Start opens the Review session on the return plan',
      (tester) async {
    final store = await awayStore();
    await pumpHub(tester, store, back);

    await tester.tap(find.text('Start'));
    await settle(tester);

    expect(find.byType(SessionWidget), findsOneWidget);
    final plan = DayPlan.decode((await store.day(back))!.plan);
    expect(find.text(sectionPosition(plan, 0)), findsOneWidget);
  });

  testWidgets('Not now shows the hub with the Today card', (tester) async {
    final store = await awayStore();
    await pumpHub(tester, store, back);

    await tester.tap(find.text('Not now'));
    await settle(tester);

    expect(find.text('Welcome back'), findsNothing);
    expect(find.byKey(const ValueKey('today-card')), findsOneWidget);
    final plan = DayPlan.decode((await store.day(back))!.plan);
    expect(find.text(todaySectionsLine(plan)), findsOneWidget);
    expect(todaySectionsLine(plan), isNot(contains('New')));
  });

  testWidgets('one missed day is no return: the hub opens on the Today card',
      (tester) async {
    final store = await awayStore();
    await pumpHub(tester, store, day0 + 2);

    expect(find.text('Welcome back'), findsNothing);
    expect(find.byKey(const ValueKey('today-card')), findsOneWidget);
  });

  test('the summary reads the return plan and the record, and writes nothing',
      () async {
    final store = await awayStore();
    final launch = await onLaunch(at(back), store, catalog);
    expect(launch.decision, LaunchDecision.welcomeBack);
    final log = await store.exportLog();

    final s = await welcomeBackSummary(launch, store, catalog);
    expect(s.daysAway, 3);
    expect(s.itemsDue, (await store.dueOnOrBefore(back)).length);
    expect(s.catchUpDays, greaterThanOrEqualTo(1));
    expect(
        s.catchUpDays,
        (launch.plan!.backlogSeconds + launch.plan!.targetSeconds - 1) ~/
            launch.plan!.targetSeconds);
    expect(s.newPaused, isTrue);
    expect(s.shaky, [shakyItem.title]);

    final after = await store.exportLog();
    expect(after.attempts.length, log.attempts.length);
    expect(after.seeds.length, log.seeds.length);
  });
}
