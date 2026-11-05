// Relaunch (Task 15, D9, PIN-9). Every case launches on a memory store and the shipped catalog
// at an injected instant, and states one launch case: first launch, first launch then the
// seed then today's plan, resume and done on the same day, the next day, one missed day, two
// or more missed days as Welcome back with the return plan and no item reset, Welcome back
// again until the first answer, an unanswered return or plan that is no session day (ASK-5),
// a stored plan this build cannot read (unfinished, and finished so it stays done), and the
// 04:00 boundary.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));
const scheduler = FsrsScheduler();

const int day0 = 300;

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
    sessionId: 's$day',
  );
}

/// A seeded store whose first launch was on [day0], with a few real answers on that day.
Future<JpStoreMemory> launchedStore() async {
  final store = JpStoreMemory();
  await seedFromLessons(day0, store, catalog, nowUtc: at(day0).toUtc());
  final first = await onLaunch(at(day0), store, catalog);
  expect(first.decision, LaunchDecision.today);
  for (final e in first.plan!.entries.take(6)) {
    final item = catalog.byId(e.itemId)!;
    await store.recordAnswer(answerOn(item, day0, Grade.clear),
        item: item, scheduler: scheduler);
  }
  final wrong = catalog.byId(first.plan!.entries[6].itemId)!;
  await store.recordAnswer(answerOn(wrong, day0, Grade.wrong),
      item: wrong, scheduler: scheduler);
  await store.putDay(first.record!.copyWith(position: 7, completed: true));
  return store;
}

void main() {
  test(
      'first launch: no seed yet, so the seed confirmation, and nothing is written',
      () async {
    final store = JpStoreMemory();
    final launch = await onLaunch(at(day0), store, catalog);
    expect(launch.decision, LaunchDecision.firstLaunch);
    expect(launch.plan, isNull);
    expect(launch.day, day0);
    expect(await store.lastDay(), isNull);
    expect(await store.seeds(), isEmpty);
    // Asked again before the seed, it is still the first launch.
    expect((await onLaunch(at(day0), store, catalog)).decision,
        LaunchDecision.firstLaunch);
  });

  test(
      'first launch seeds, then plans: the launch after the seed is today with the '
      'seeded items due', () async {
    final store = JpStoreMemory();
    await seedFromLessons(day0, store, catalog, nowUtc: at(day0).toUtc());
    final launch = await onLaunch(at(day0), store, catalog);
    expect(launch.decision, LaunchDecision.today);
    expect(launch.daysMissed, 0);
    expect(launch.plan!.day, day0);
    expect(launch.plan!.section(PlanSection.due), isNotEmpty);
    expect(
        launch.plan!.section(PlanSection.due).every((e) => e.seeded), isTrue);
    final stored = await store.day(day0);
    expect(stored, isNotNull);
    expect(DayPlan.decode(stored!.plan).toJson(), launch.plan!.toJson());
    expect(stored.position, 0);
    expect(stored.completed, isFalse);
  });

  test(
      'same day, session not finished: resume the stored plan where it stopped',
      () async {
    final store = JpStoreMemory();
    await seedFromLessons(day0, store, catalog, nowUtc: at(day0).toUtc());
    final first = await onLaunch(at(day0), store, catalog);
    await store.putDay(first.record!.copyWith(position: 5));
    final later =
        await onLaunch(at(day0).add(const Duration(hours: 4)), store, catalog);
    expect(later.decision, LaunchDecision.resume);
    expect(later.record!.position, 5);
    expect(later.plan!.toJson(), first.plan!.toJson());
  });

  test('same day, session finished: the end card', () async {
    final store = await launchedStore();
    final later =
        await onLaunch(at(day0).add(const Duration(hours: 8)), store, catalog);
    expect(later.decision, LaunchDecision.done);
    expect(later.record!.completed, isTrue);
  });

  test("the next day: today's plan, no day missed, yesterday's wrong in Repair",
      () async {
    final store = await launchedStore();
    final launch = await onLaunch(at(day0 + 1), store, catalog);
    expect(launch.decision, LaunchDecision.today);
    expect(launch.daysMissed, 0);
    expect(launch.plan!.day, day0 + 1);
    expect(launch.plan!.returnMode, isFalse);
    expect(launch.plan!.section(PlanSection.repair), hasLength(1));
    expect(await store.lastDay(), day0 + 1);
  });

  test('one missed day: still today, with the missed day counted (no stretch)',
      () async {
    final store = await launchedStore();
    final launch = await onLaunch(at(day0 + 2), store, catalog);
    expect(launch.decision, LaunchDecision.today);
    expect(launch.daysMissed, 1);
    expect(launch.plan!.daysMissed, 1);
    expect(launch.plan!.returnMode, isFalse);
    expect(launch.plan!.stretchOffer, isFalse);
  });

  test(
      'two or more missed days: Welcome back with the return plan, New paused, and '
      'no item reset (PIN-9)', () async {
    final store = await launchedStore();
    final srsBefore = await store.allSrs();
    final masteryBefore = await store.allMastery();
    final seedsBefore = await store.seeds();
    final attemptsBefore = await store.attempts();
    expect(srsBefore, isNotEmpty);
    expect(masteryBefore, isNotEmpty);

    // The first return is never answered, so it is no session day (ASK-5): the second
    // return still counts from day0, the last day with an answer.
    for (final away in [3, 12]) {
      final launch = await onLaunch(at(day0 + away), store, catalog);
      expect(launch.decision, LaunchDecision.welcomeBack, reason: 'away $away');
      expect(launch.daysMissed, away - 1);
      expect(launch.plan!.returnMode, isTrue);
      expect(launch.plan!.newSkip, NewSkip.daysMissed);
      expect(launch.plan!.section(PlanSection.newItems), isEmpty);
    }
    expect(await store.allSrs(), srsBefore);
    expect(await store.allMastery(), masteryBefore);
    expect(await store.seeds(), seedsBefore);
    expect(await store.attempts(), attemptsBefore);
  });

  test(
      'the return plan is shown behind Welcome back until the first answer, then resumes',
      () async {
    final store = await launchedStore();
    final back = await onLaunch(at(day0 + 4), store, catalog);
    expect(back.decision, LaunchDecision.welcomeBack);
    final again = await onLaunch(
        at(day0 + 4).add(const Duration(hours: 2)), store, catalog);
    expect(again.decision, LaunchDecision.welcomeBack);
    expect(again.plan!.toJson(), back.plan!.toJson());
    await store.putDay(back.record!.copyWith(position: 1));
    final resumed = await onLaunch(
        at(day0 + 4).add(const Duration(hours: 3)), store, catalog);
    expect(resumed.decision, LaunchDecision.resume);
    expect(resumed.daysMissed, 3);
  });

  test(
      'an unanswered Welcome back is no session day: the next day is still a return '
      '(ASK-5)', () async {
    final store = await launchedStore();
    final back = await onLaunch(at(day0 + 4), store, catalog);
    expect(back.decision, LaunchDecision.welcomeBack);
    expect(back.daysMissed, 3);
    // Nothing answered on day0 + 4; the next day counts from day0 again.
    final next = await onLaunch(at(day0 + 5), store, catalog);
    expect(next.decision, LaunchDecision.welcomeBack);
    expect(next.daysMissed, 4);
    expect(next.plan!.returnMode, isTrue);
    expect(next.plan!.newSkip, NewSkip.daysMissed);
    // Once the return is answered, the day after it is an ordinary next day.
    await store.putDay(next.record!.copyWith(position: 1));
    final after = await onLaunch(at(day0 + 6), store, catalog);
    expect(after.decision, LaunchDecision.today);
    expect(after.daysMissed, 0);
  });

  test(
      'a plan built but never answered is no session day, a completed one is (ASK-5)',
      () async {
    final store = await launchedStore();
    // Day0 + 1 is planned and left untouched; day0 + 2 then has one missed day, not none.
    await onLaunch(at(day0 + 1), store, catalog);
    final launch = await onLaunch(at(day0 + 2), store, catalog);
    expect(launch.decision, LaunchDecision.today);
    expect(launch.daysMissed, 1);
  });

  test('a stored plan this build cannot read is built again, not shown',
      () async {
    final store = JpStoreMemory();
    await seedFromLessons(day0, store, catalog, nowUtc: at(day0).toUtc());
    await store.putDay(const DayRecord(day: day0, plan: '{"not": "a plan"}'));
    final launch = await onLaunch(at(day0), store, catalog);
    expect(launch.decision, LaunchDecision.today);
    expect(launch.daysMissed, 0);
    expect(DayPlan.decode((await store.day(day0))!.plan).day, day0);
  });

  test(
      'a finished session whose stored plan this build cannot read stays done, '
      'not reopened (PIN-6)', () async {
    final store = JpStoreMemory();
    await seedFromLessons(day0, store, catalog, nowUtc: at(day0).toUtc());
    await store.putDay(const DayRecord(
        day: day0, plan: '{"not": "a plan"}', position: 9, completed: true));
    final launch = await onLaunch(at(day0), store, catalog);
    expect(launch.decision, LaunchDecision.done);
    expect(launch.record!.completed, isTrue);
    final stored = await store.day(day0);
    expect(stored!.completed, isTrue);
    expect(DayPlan.decode(stored.plan).day, day0);
    // Asked again the same day, it is still done.
    expect(
        (await onLaunch(at(day0).add(const Duration(hours: 2)), store, catalog))
            .decision,
        LaunchDecision.done);
  });

  test(
      'the day turns at 04:00 local: 01:00 still resumes the evening before (D15)',
      () async {
    final store = JpStoreMemory();
    await seedFromLessons(day0, store, catalog, nowUtc: at(day0).toUtc());
    final first = await onLaunch(at(day0), store, catalog);
    await store.putDay(first.record!.copyWith(position: 2));
    final late = dayStart(day0 + 1).subtract(const Duration(hours: 3));
    expect(
        (await onLaunch(late, store, catalog)).decision, LaunchDecision.resume);
    final morning = dayStart(day0 + 1).add(const Duration(minutes: 1));
    final next = await onLaunch(morning, store, catalog);
    expect(next.decision, LaunchDecision.today);
    expect(next.day, day0 + 1);
  });

  test('a mastered item stays mastered across a long break', () async {
    final store = await launchedStore();
    final item = catalog.ofKind(ItemKind.particle).first;
    final mastered = MasteryState(
        itemId: item.id, status: MasteryStatus.mastered, masteredOn: 250);
    await store.putMastery(mastered);
    await onLaunch(at(day0 + 60), store, catalog);
    expect(await store.mastery(item.id), mastered);
  });
}
