// The daily plan builder (Task 14, PIN-5, PIN-6, PIN-9, PIN-10, PIN-11, PIN-12, D26, D27).
// Every case builds a plan from a memory store and the shipped catalog with an injected clock,
// and states one rule: the sections, the Due order and interleave, keep-sharp's week, the
// budget and its hard stop, the New skips and the New exclusion of every item with a seed or a
// state, the stretch and catch-up offers, return mode's
// warm-up and its cap, and the requeue of an unscored entry.

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
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));
const scheduler = FsrsScheduler();

/// The first local day on or after day 60 whose date is [weekday].
int dayOn(int weekday) {
  var d = 60;
  while (dateOfDay(d).weekday != weekday) {
    d++;
  }
  return d;
}

final int monday = dayOn(DateTime.monday);
final int wednesday = monday + 2;

/// A clock at 10:00 local on [day].
FixedClock clockOn(int day) =>
    FixedClock(dayStart(day).add(const Duration(hours: 6)));

List<ItemDef> ofKind(ItemKind kind) => catalog.ofKind(kind);
List<ItemDef> wordsOf(int lesson) => [
      for (final w in ofKind(ItemKind.word))
        if (w.lesson == lesson) w
    ];

/// A state last reviewed 10 days before [day], due on [day] (or [dueDay]), whose
/// retrievability on [day] is [r].
SrsState stateWithR(int day, double r, {int lapses = 0, int? dueDay}) {
  const elapsed = 10;
  var lo = 0.01, hi = 10000.0;
  for (var i = 0; i < 200; i++) {
    final mid = (lo + hi) / 2;
    final got =
        fsrsRetrievability(elapsedDays: elapsed.toDouble(), stability: mid);
    if (got < r) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return SrsState(
    stability: (lo + hi) / 2,
    difficulty: 5,
    lastReviewDay: day - elapsed,
    dueDay: dueDay ?? day,
    interval: elapsed,
    lapses: lapses,
  );
}

Future<void> due(JpStore store, ItemDef item, int day, double r,
        {int lapses = 0}) =>
    store.putSrs(item.id, stateWithR(day, r, lapses: lapses));

Future<void> mastered(JpStore store, ItemDef item, int day, double r) async {
  await store.putSrs(item.id, stateWithR(day, r, dueDay: day + 30));
  await store.putMastery(MasteryState(
      itemId: item.id, status: MasteryStatus.mastered, masteredOn: day - 40));
}

Future<void> seed(JpStore store, ItemDef item, int dueDay) =>
    store.appendSeed(item.id, dueDay, atUtc: DateTime.utc(2026, 1, 1));

Attempt wrongOn(ItemDef item, int day) {
  final p = item.scoredProbes.first;
  return Attempt(
    itemId: item.id,
    probeId: p.id,
    template: p.template,
    production: p.production,
    selfGraded: p.selfGraded,
    atUtc: dayStart(day).add(const Duration(hours: 8)).toUtc(),
    localDay: day,
    grade: Grade.wrong,
    rating: fsrsRatingFor(Grade.wrong),
    wasDue: true,
    source: Source.review,
    sessionId: 's$day',
  );
}

Attempt clearOn(ItemDef item, int day) => Attempt.fromJson(
    {...wrongOn(item, day).toJson(), 'grade': 'clear', 'rating': 3});

Future<DayPlan> plan(JpStore store, int day,
        {int daysMissed = 0, PlanBudget budget = PlanBudget.standard}) =>
    buildPlan(
      day: day,
      budget: budget,
      daysMissed: daysMissed,
      store: store,
      catalog: catalog,
      clock: clockOn(day),
      scheduler: scheduler,
    );

/// Every New candidate seeded far in the future, so New stays empty unless a test frees some.
Future<void> seedEverything(JpStore store, int day,
        {Set<String> except = const {}}) =>
    store.appendSeeds([
      for (final i in catalog.items)
        if (!except.contains(i.id))
          SeedEvent(
              itemId: i.id, dueDay: day + 500, atUtc: DateTime.utc(2026, 1, 1)),
    ]);

/// New is empty and the stretch is off: every candidate was already introduced. Asserted
/// wherever a test relies on [seedEverything] or a repair to keep New out of the plan.
void expectNoNew(DayPlan p) {
  expect(p.section(PlanSection.newItems), isEmpty);
  expect(p.stretchOffer, isFalse);
  expect(p.stretchEntries, isEmpty);
}

void expectNoTripleRuns(List<QueueEntry> entries) {
  for (var i = 2; i < entries.length; i++) {
    final a = entries[i - 2], b = entries[i - 1], c = entries[i];
    expect(a.kind == b.kind && b.kind == c.kind, isFalse,
        reason: 'three ${c.kind} in a row at $i: $entries');
    expect(c.lesson != null && a.lesson == c.lesson && b.lesson == c.lesson,
        isFalse,
        reason: 'three of lesson ${c.lesson} in a row at $i: $entries');
  }
}

void main() {
  final tuesday = monday + 1;

  test(
      'the budget constants: a 15-minute target, a 20-minute ceiling, per-kind costs (A2)',
      () {
    expect(kTargetSeconds, 15 * 60);
    expect(kCeilingSeconds, 20 * 60);
    expect(PlanBudget.standard.gateSeconds, (1.5 * 15 * 60).round());
    expect(PlanBudget.standard.fillSeconds, lessThan(kCeilingSeconds));
    for (final k in ItemKind.values) {
      expect(kCostSeconds[k], isNotNull, reason: 'no cost for $k');
    }
    expect(kCostSeconds[ItemKind.word], 10);
    expect(kCostSeconds[ItemKind.conjugation], 12);
    expect(kCostSeconds[ItemKind.pair], 15);
    expect(kCostSeconds[ItemKind.tableRow], 15);
    expect(kCostSeconds[ItemKind.grammar], 25);
    expect(kCostSeconds[ItemKind.particle], 25);
    expect(kNewPerDay, 8);
    expect(kStretchNew, 4);
  });

  test('the day and the build time come from the injected clock', () async {
    final store = JpStoreMemory();
    final clock = clockOn(tuesday);
    final p = await buildPlan(store: store, catalog: catalog, clock: clock);
    expect(p.day, tuesday);
    expect(p.builtAtUtc, clock.now().toUtc());
  });

  group('Repair (PIN-11)', () {
    test("yesterday's wrongs open the plan, once each, and leave Due",
        () async {
      final store = JpStoreMemory();
      final words = wordsOf(5);
      // words[1] has no seed and no state: a wrong on an early practice. Its repair alone
      // keeps it out of New.
      await seedEverything(store, tuesday, except: {words[1].id});
      // Wrong yesterday, and due today too: Repair only.
      await store.appendAttempt(wrongOn(words[0], tuesday - 1));
      await store.appendAttempt(wrongOn(words[0], tuesday - 1));
      await due(store, words[0], tuesday, 0.3);
      // Wrong yesterday, not due today: still a repair.
      await store.appendAttempt(wrongOn(words[1], tuesday - 1));
      // Clear yesterday, wrong two days ago: neither is a repair.
      await store.appendAttempt(clearOn(words[2], tuesday - 1));
      await store.appendAttempt(wrongOn(words[3], tuesday - 2));
      await due(store, words[3], tuesday, 0.5);

      final p = await plan(store, tuesday);
      expect([for (final e in p.section(PlanSection.repair)) e.itemId],
          [words[0].id, words[1].id]);
      expect(p.entries.first.section, PlanSection.repair);
      expect([for (final e in p.section(PlanSection.due)) e.itemId],
          [words[3].id]);
      final ids = [for (final e in p.entries) e.itemId];
      expect(ids.toSet().length, ids.length, reason: 'one entry per item');
      expectNoNew(p);
    });

    test('a wrong is re-asked about 10 minutes later from the repair slot',
        () async {
      final store = JpStoreMemory();
      final words = ofKind(ItemKind.word).take(80).toList();
      for (final w in words) {
        await due(store, w, tuesday, 0.7);
      }
      final p = await plan(store, tuesday);
      expect(p.repairSlotSeconds, kRepairSlotSeconds);
      final after = p.afterWrong(0);
      expect(after.entries.length, p.entries.length + 1);
      final at = after.entries.indexWhere((e) => e.reask);
      expect(after.entries[at].itemId, p.entries[0].itemId);
      expect(after.entries[at].section, PlanSection.repair);
      final between = after.entries
          .sublist(1, at)
          .fold<int>(0, (s, e) => s + e.costSeconds);
      expect(between, greaterThanOrEqualTo(kRepairReaskSeconds));
      expect(between - after.entries[at - 1].costSeconds,
          lessThan(kRepairReaskSeconds));
      // A re-ask is not re-asked again.
      expect(identical(after.afterWrong(at), after), isTrue);
      // Near the end the re-ask goes last.
      final late = p.afterWrong(p.entries.length - 2);
      expect(late.entries.last.reask, isTrue);
    });
  });

  group('Due (D26)', () {
    test(
        'stateful by ascending retrievability, ties by level then lapses, then seeded by '
        'seed day and lesson', () async {
      final store = JpStoreMemory();
      await seedEverything(store, tuesday);
      final grammar = ofKind(ItemKind.grammar).first;
      final particle = ofKind(ItemKind.particle).first;
      final conj = ofKind(ItemKind.conjugation).first;
      final pair = ofKind(ItemKind.pair).first;
      final row = ofKind(ItemKind.tableRow).first;
      final word = wordsOf(4).first;
      await due(store, grammar, tuesday, 0.80);
      await due(store, particle, tuesday, 0.40);
      await due(store, word, tuesday, 0.60);
      // The same retrievability: the level-0 items before the word, more lapses first.
      final tieWord = wordsOf(6).first;
      await due(store, tieWord, tuesday, 0.70);
      await due(store, conj, tuesday, 0.70, lapses: 1);
      await due(store, pair, tuesday, 0.70, lapses: 3);
      // Seeded, no FSRS state: after every stateful item, by seed day then lesson.
      final seedLate = wordsOf(3).first;
      final seedEarlyHigh = wordsOf(10).first;
      final seedEarlyLow = wordsOf(8).first;
      await seed(store, seedLate, tuesday - 1);
      await seed(store, seedEarlyHigh, tuesday - 3);
      await seed(store, seedEarlyLow, tuesday - 3);
      await seed(store, row, tuesday - 2);

      final p = await plan(store, tuesday);
      expect([
        for (final e in p.section(PlanSection.due)) e.itemId
      ], [
        particle.id,
        word.id,
        pair.id,
        conj.id,
        tieWord.id,
        grammar.id,
        seedEarlyLow.id,
        seedEarlyHigh.id,
        row.id,
        seedLate.id,
      ]);
      final dueEntries = p.section(PlanSection.due);
      expect(
          dueEntries
              .take(6)
              .every((e) => !e.seeded && e.retrievability != null),
          isTrue);
      expect(
          dueEntries.skip(6).every((e) => e.seeded && e.retrievability == null),
          isTrue);
      expect(dueEntries.every((e) => e.wasDue && e.source == Source.review),
          isTrue);
      // Every item has a seed or a state, so nothing is New.
      expectNoNew(p);
    });

    test('no more than two in a row share a kind or a lesson', () async {
      final store = JpStoreMemory();
      await seedEverything(store, tuesday);
      final words = wordsOf(7).take(6).toList();
      final particles = ofKind(ItemKind.particle).take(3).toList();
      // The six words are the least retrievable, so without the interleave they run.
      for (var i = 0; i < words.length; i++) {
        await due(store, words[i], tuesday, 0.2 + i * 0.01);
      }
      for (var i = 0; i < particles.length; i++) {
        await due(store, particles[i], tuesday, 0.8 + i * 0.01);
      }
      final p = await plan(store, tuesday);
      final d = p.section(PlanSection.due);
      expect(d.length, 9);
      expectNoTripleRuns(d);
      expect([for (final e in d) e.itemId].take(2), [words[0].id, words[1].id]);
      expectNoNew(p);
    });

    test(
        'interleaveRuns keeps the order when it can and the first when it cannot',
        () {
      QueueEntry e(String id, ItemKind kind, int? lesson) => QueueEntry(
          itemId: id,
          kind: kind,
          section: PlanSection.due,
          costSeconds: 10,
          wasDue: true,
          lesson: lesson);
      final mixed = [
        e('a', ItemKind.word, 2),
        e('b', ItemKind.word, 2),
        e('c', ItemKind.word, 3),
        e('d', ItemKind.particle, null),
      ];
      expect([for (final x in interleaveRuns(mixed)) x.itemId],
          ['a', 'b', 'd', 'c']);
      final lessonRun = [
        e('g', ItemKind.grammar, 26),
        e('w1', ItemKind.word, 26),
        e('w2', ItemKind.word, 26),
        e('w3', ItemKind.word, 2),
      ];
      expect([for (final x in interleaveRuns(lessonRun)) x.itemId],
          ['g', 'w1', 'w3', 'w2']);
      final only = [
        e('x', ItemKind.word, 2),
        e('y', ItemKind.word, 2),
        e('z', ItemKind.word, 2)
      ];
      expect([for (final x in interleaveRuns(only)) x.itemId], ['x', 'y', 'z']);
    });
  });

  group('Keep-sharp (PIN-10, D27)', () {
    Future<List<ItemDef>> masterTwelve(JpStore store, int day) async {
      final items = ofKind(ItemKind.word).skip(200).take(12).toList();
      for (var i = 0; i < items.length; i++) {
        await mastered(store, items[i], day, 0.95 - i * 0.01);
      }
      return items;
    }

    test(
        'the first session on Monday adds the 10 Mastered items most at risk, not due',
        () async {
      final store = JpStoreMemory();
      await seedEverything(store, monday);
      final items = await masterTwelve(store, monday);
      // A Mastered item already due is a Due entry, not a keep-sharp one.
      final dueMastered = ofKind(ItemKind.word)[300];
      await due(store, dueMastered, monday, 0.5);
      await store.putMastery(
          MasteryState(itemId: dueMastered.id, status: MasteryStatus.mastered));

      final p = await plan(store, monday);
      expect(p.keepSharpRan, isTrue);
      final keep = p.section(PlanSection.keepSharp);
      expect([for (final e in keep) e.itemId],
          [for (final i in items.reversed.take(kKeepSharpCount)) i.id]);
      expect(
          keep.every((e) => e.source == Source.keepSharp && !e.wasDue), isTrue);
      expect([for (final e in p.section(PlanSection.due)) e.itemId],
          [dueMastered.id]);
      // The two Mastered items keep-sharp left out have a state: not New either.
      expectNoNew(p);
    });

    test(
        'later sessions that week add none; a week with no Monday session runs it on the '
        'first session after', () async {
      final store = JpStoreMemory();
      await seedEverything(store, monday);
      await masterTwelve(store, monday);
      final mon = await plan(store, monday);
      await store
          .putDay(DayRecord(day: monday, plan: mon.encode(), completed: true));
      final tue = await plan(store, tuesday);
      expect(tue.keepSharpRan, isFalse);
      expect(tue.section(PlanSection.keepSharp), isEmpty);

      final other = JpStoreMemory();
      await seedEverything(other, monday);
      await masterTwelve(other, monday);
      final wed = await plan(other, wednesday);
      expect(wed.keepSharpRan, isTrue);
      expect(wed.section(PlanSection.keepSharp).length, kKeepSharpCount);
      // The next week starts over.
      await store.putDay(DayRecord(day: tuesday, plan: tue.encode()));
      final next = await plan(store, monday + 7);
      expect(next.keepSharpRan, isTrue);
    });

    test('in return mode keep-sharp waits until the backlog is under the gate',
        () async {
      final store = JpStoreMemory();
      await seedEverything(store, monday);
      await masterTwelve(store, monday);
      final big = ofKind(ItemKind.grammar).take(60).toList();
      for (final g in big) {
        await due(store, g, monday, 0.7);
      }
      final waiting = await plan(store, monday, daysMissed: 3);
      expect(waiting.gateHeld, isFalse);
      expect(waiting.keepSharpRan, isFalse);
      expect(waiting.section(PlanSection.keepSharp), isEmpty);

      final small = JpStoreMemory();
      await seedEverything(small, monday);
      await masterTwelve(small, monday);
      final ran = await plan(small, monday, daysMissed: 3);
      expect(ran.gateHeld, isTrue);
      expect(ran.keepSharpRan, isTrue);
      expect(ran.section(PlanSection.keepSharp).length, kKeepSharpCount);
    });
  });

  group('New (PIN-6)', () {
    test(
        'a fresh record introduces 8, level-0 items sprinkled first, and offers the stretch',
        () async {
      final store = JpStoreMemory();
      final p = await plan(store, tuesday);
      final news = p.section(PlanSection.newItems);
      expect(news.length, kNewPerDay);
      expect(p.newSkip, NewSkip.none);
      final levels = [
        for (final e in news) catalog.byId(e.itemId)!.prereqLevel
      ];
      expect(levels.take(kFoundationNewPerDay), everyElement(0));
      expect(levels.skip(kFoundationNewPerDay).first, isNot(0));
      expect(p.stretchOffer, isTrue);
      expect(p.stretchEntries.length, kStretchNew);
      final planned = {for (final e in p.entries) e.itemId};
      expect(
          p.stretchEntries.every((e) => !planned.contains(e.itemId)), isTrue);
      expect(p.catchUpOffer, isFalse);
    });

    test(
        'intake: words of a lesson before its grammar, a point after the forms it uses',
        () {
      for (final lesson in [26, 27, 28, 29, 30]) {
        // Everything before this lesson's words is introduced, and none of the forms.
        final introduced = <String>{
          for (final i in catalog.items)
            if (i.prereqLevel == 0 && i.kind != ItemKind.conjugation) i.id,
          for (final i in catalog.items)
            if (i.lesson != null && i.lesson! < lesson) i.id,
        };
        // Leave only the last two words of the lesson to introduce.
        final words = wordsOf(lesson);
        introduced.addAll(words.take(words.length - 2).map((w) => w.id));
        final out = newIntakeOrder(catalog, introduced, 40);
        final seen = {...introduced};
        for (final item in out) {
          if (item.kind == ItemKind.grammar) {
            for (final w in wordsOf(item.lesson!)) {
              expect(seen, contains(w.id),
                  reason: '${item.id} before word ${w.id} of its lesson');
            }
            for (final pre in item.prereqs) {
              expect(seen, contains(pre),
                  reason: '${item.id} before its form $pre');
            }
          }
          seen.add(item.id);
        }
        expect(out.where((i) => i.kind == ItemKind.grammar), isNotEmpty);
        expect(out.length, 40);
      }
    });

    test('intake never offers an item with a state or a seed', () {
      final introduced = {for (final i in catalog.items.take(400)) i.id};
      final out = newIntakeOrder(catalog, introduced, 50);
      expect(out.where((i) => introduced.contains(i.id)), isEmpty);
      expect(out.map((i) => i.id).toSet().length, out.length);
    });

    test(
        'the plan never introduces an item that has a seed or a state, due or not',
        () async {
      final store = JpStoreMemory();
      // A fresh record introduces two particles and then lesson 2's words in order, so
      // these five would be among the first ten words without their seed or state.
      final words = wordsOf(2);
      final seeded = [words[0], words[2], words[4]];
      final stated = [words[1], words[3]];
      for (final w in seeded) {
        await seed(store, w, tuesday + 500);
      }
      for (final w in stated) {
        await store.putSrs(
            w.id, stateWithR(tuesday, 0.9, dueDay: tuesday + 30));
      }
      final p = await plan(store, tuesday);
      expect(p.newSkip, NewSkip.none);
      expect(p.section(PlanSection.due), isEmpty, reason: 'none of them is due');
      expect(p.stretchOffer, isTrue);
      final offered = [
        for (final e in [...p.section(PlanSection.newItems), ...p.stretchEntries])
          e.itemId
      ];
      final held = {for (final w in [...seeded, ...stated]) w.id};
      expect(offered.where(held.contains), isEmpty);
      // The oracle is the catalog, not the intake: the first two level-0 items, then the
      // first unintroduced words of the first lesson fill New and then the stretch.
      final rest = [
        for (final w in words)
          if (!held.contains(w.id)) w.id
      ];
      expect(offered, [
        for (final i in ofKind(ItemKind.particle).take(kFoundationNewPerDay))
          i.id,
        ...rest.take(kNewPerDay + kStretchNew - kFoundationNewPerDay),
      ]);
      expect(p.section(PlanSection.newItems).length, kNewPerDay);
      expect(p.stretchEntries.length, kStretchNew);
    });

    test('New is skipped when two or more days were missed', () async {
      final store = JpStoreMemory();
      final p = await plan(store, tuesday, daysMissed: 2);
      expect(p.returnMode, isTrue);
      expect(p.newSkip, NewSkip.daysMissed);
      expect(p.section(PlanSection.newItems), isEmpty);
      expect(p.stretchOffer, isFalse);
    });

    test('one missed day keeps New but never offers the stretch', () async {
      final store = JpStoreMemory();
      final p = await plan(store, tuesday, daysMissed: 1);
      expect(p.section(PlanSection.newItems).length, kNewPerDay);
      expect(p.stretchOffer, isFalse);
    });

    test('New is skipped when the backlog before the session is above the gate',
        () async {
      final store = JpStoreMemory();
      // 56 grammar points at 25 s: 1400 s, above the 1350 s gate.
      for (final g in ofKind(ItemKind.grammar).take(56)) {
        await due(store, g, tuesday, 0.7);
      }
      final p = await plan(store, tuesday);
      expect(p.backlogSeconds, 56 * 25);
      expect(p.gateHeld, isFalse);
      expect(p.newSkip, NewSkip.backlog);
      expect(p.section(PlanSection.newItems), isEmpty);
    });

    test('New is skipped once the target is spent', () async {
      final store = JpStoreMemory();
      // 95 words at 10 s: 950 s, past the target and under the gate; all of it fits.
      for (final w in ofKind(ItemKind.word).take(95)) {
        await due(store, w, tuesday, 0.7);
      }
      final p = await plan(store, tuesday);
      expect(p.gateHeld, isTrue);
      expect(p.dueLeft, 0);
      expect(p.newSkip, NewSkip.targetSpent);
      expect(p.section(PlanSection.newItems), isEmpty);
      expect(p.stretchOffer, isFalse);
    });
  });

  group('The budget (PIN-5) and the offers (PIN-6, PIN-12)', () {
    test(
        'a large backlog fills to the ceiling less the repair slot and stops there',
        () async {
      final store = JpStoreMemory();
      // The seeded first weeks: 300 seeded words due today.
      for (final w in ofKind(ItemKind.word).take(300)) {
        await seed(store, w, tuesday);
      }
      final p = await plan(store, tuesday);
      expect(
          p.plannedSeconds, lessThanOrEqualTo(PlanBudget.standard.fillSeconds));
      expect(p.plannedSeconds + p.repairSlotSeconds,
          lessThanOrEqualTo(kCeilingSeconds));
      expect(p.plannedSeconds + kCostSeconds[ItemKind.word]!,
          greaterThan(PlanBudget.standard.fillSeconds));
      expect(p.dueLeft, 300 - p.entries.length);
      expect(p.newSkip, NewSkip.backlog);
      expect(p.stretchOffer, isFalse);
      // The catch-up: one block of 10 due items past the ceiling, none of them planned.
      expect(p.catchUpOffer, isTrue);
      expect(p.catchUpEntries.length, kCatchUpBlock);
      final planned = {for (final e in p.entries) e.itemId};
      expect(
          p.catchUpEntries.every((e) => !planned.contains(e.itemId)), isTrue);
      expect(
          p.catchUpEntries.every((e) => e.section == PlanSection.due), isTrue);
    });

    test('no catch-up when what the ceiling leaves is under the gate',
        () async {
      final store = JpStoreMemory();
      // 130 words: 1300 s, under the gate, more than the ceiling holds.
      for (final w in ofKind(ItemKind.word).take(130)) {
        await due(store, w, tuesday, 0.7);
      }
      final p = await plan(store, tuesday);
      expect(p.dueLeft, greaterThan(0));
      expect(p.catchUpOffer, isFalse);
      expect(p.catchUpEntries, isEmpty);
      expect(p.stretchOffer, isFalse, reason: 'due items are left');
      expect(p.newSkip, NewSkip.targetSpent);
    });

    test('a small day fills under the target with repairs, due and 8 new',
        () async {
      final store = JpStoreMemory();
      for (final w in ofKind(ItemKind.word).skip(100).take(20)) {
        await due(store, w, tuesday, 0.8);
      }
      await store
          .appendAttempt(wrongOn(ofKind(ItemKind.word)[150], tuesday - 1));
      final p = await plan(store, tuesday);
      expect(p.section(PlanSection.repair).length, 1);
      expect(p.section(PlanSection.due).length, 20);
      expect(p.section(PlanSection.newItems).length, kNewPerDay);
      expect(p.plannedSeconds, lessThan(kTargetSeconds));
      expect(p.stretchOffer, isTrue);
      // Section order: repair, due, keep-sharp, new.
      final sections = [for (final e in p.entries) e.section.index];
      expect(sections, [...sections]..sort());
    });

    test('the stretch needs room under the ceiling for four introductions',
        () async {
      final store = JpStoreMemory();
      for (final w in ofKind(ItemKind.word).skip(100).take(20)) {
        await due(store, w, tuesday, 0.8);
      }
      final roomy = await plan(store, tuesday);
      expect(roomy.stretchOffer, isTrue);
      final need = roomy.plannedSeconds +
          roomy.stretchEntries.fold<int>(0, (s, e) => s + e.costSeconds);
      // The same day against a ceiling that leaves no room for the four.
      final tight = await plan(store, tuesday,
          budget: PlanBudget(
              targetSeconds: kTargetSeconds,
              ceilingSeconds: need + kRepairSlotSeconds - 1));
      expect(tight.section(PlanSection.newItems).length, kNewPerDay);
      expect(tight.dueLeft, 0);
      expect(tight.gateHeld, isTrue);
      expect(tight.stretchOffer, isFalse);
      expect(tight.stretchEntries, isEmpty);
    });
  });

  group('Return mode (PIN-9, D26)', () {
    test(
        'a warm-up of 5 to 8 level-0 stateful items between 0.6 and 0.85 comes first',
        () async {
      final store = JpStoreMemory();
      await seedEverything(store, tuesday);
      final foundations = [
        ...ofKind(ItemKind.particle).take(4),
        ...ofKind(ItemKind.conjugation).take(4),
        ...ofKind(ItemKind.tableRow).take(2),
      ];
      for (var i = 0; i < foundations.length; i++) {
        await due(store, foundations[i], tuesday, 0.62 + i * 0.02);
      }
      // Outside the window, or not foundational: never a warm-up.
      final tooLow = ofKind(ItemKind.pair)[0];
      final tooHigh = ofKind(ItemKind.pair)[1];
      final word = ofKind(ItemKind.word)[10];
      await due(store, tooLow, tuesday, 0.55);
      await due(store, tooHigh, tuesday, 0.88);
      await due(store, word, tuesday, 0.7);
      final seededRow = ofKind(ItemKind.tableRow)[5];
      await seed(store, seededRow, tuesday - 3);

      final p = await plan(store, tuesday, daysMissed: 4);
      final warm = p.section(PlanSection.warmUp);
      expect(warm.length, inInclusiveRange(kWarmUpMin, kWarmUpMax));
      expect(warm.length, kWarmUpMax);
      expect(
          p.entries
              .take(warm.length)
              .every((e) => e.section == PlanSection.warmUp),
          isTrue);
      for (final e in warm) {
        expect(catalog.byId(e.itemId)!.prereqLevel, 0);
        expect(e.retrievability, inInclusiveRange(kWarmUpLowR, kWarmUpHighR));
        expect(e.seeded, isFalse);
      }
      final warmIds = {for (final e in warm) e.itemId};
      expect(
          warmIds.intersection({tooLow.id, tooHigh.id, word.id, seededRow.id}),
          isEmpty);
      // Most likely recalled first.
      final rs = [for (final e in warm) e.retrievability!];
      expect(rs, [...rs]..sort((a, b) => b.compareTo(a)));
      final ids = [for (final e in p.entries) e.itemId];
      expect(ids.toSet().length, ids.length);
    });

    test(
        'stateful items under 0.5 are capped at a third of the plan; seeded ones are not',
        () async {
      final store = JpStoreMemory();
      await seedEverything(store, tuesday);
      final low = ofKind(ItemKind.word).take(30).toList();
      final mid = ofKind(ItemKind.word).skip(30).take(10).toList();
      for (var i = 0; i < low.length; i++) {
        await due(store, low[i], tuesday, 0.1 + i * 0.01);
      }
      for (final w in mid) {
        await due(store, w, tuesday, 0.55);
      }
      final seededWords = ofKind(ItemKind.word).skip(40).take(6).toList();
      for (final w in seededWords) {
        await seed(store, w, tuesday - 5);
      }
      final p = await plan(store, tuesday, daysMissed: 3);
      final lows = p.entries
          .where((e) =>
              e.retrievability != null &&
              e.retrievability! < kLowRetrievability)
          .length;
      expect(lows, greaterThan(0));
      expect(lows * kLowRCapDivisor, lessThanOrEqualTo(p.entries.length));
      // Every non-low due item is planned; the capped lows wait for tomorrow.
      final ids = {for (final e in p.entries) e.itemId};
      expect(
          ids.containsAll(
              [...mid.map((w) => w.id), ...seededWords.map((w) => w.id)]),
          isTrue);
      expect(p.dueLeft, low.length - lows);
      expect(p.catchUpOffer, isFalse);
      // Without the return, nothing caps them.
      final normal = await plan(store, tuesday);
      expect(normal.section(PlanSection.due).length, 46);
      expectNoNew(normal);
    });
  });

  group('Unscored and the record', () {
    test('an unscored entry returns to the end of its section, once', () async {
      final store = JpStoreMemory();
      await store
          .appendAttempt(wrongOn(ofKind(ItemKind.word)[150], tuesday - 1));
      for (final w in ofKind(ItemKind.word).skip(100).take(5)) {
        await due(store, w, tuesday, 0.8);
      }
      final p = await plan(store, tuesday);
      final dueStart =
          p.entries.indexWhere((e) => e.section == PlanSection.due);
      final first = p.entries[dueStart];
      final once = p.afterUnscored(dueStart);
      final dueEnd =
          once.entries.lastIndexWhere((e) => e.section == PlanSection.due);
      expect(once.entries[dueEnd].itemId, first.itemId);
      expect(once.entries[dueEnd].requeued, isTrue);
      expect(once.entries.length, p.entries.length);
      expect(once.entries[dueEnd + 1].section, PlanSection.newItems);
      // A second unscored answer leaves it where it is.
      expect(identical(once.afterUnscored(dueEnd), once), isTrue);
      // The only entry of its section stays put.
      final repaired = p.afterUnscored(0);
      expect(repaired.entries[0].itemId, p.entries[0].itemId);
      expect(repaired.entries[0].requeued, isTrue);
    });

    test('the plan round-trips through the day record', () async {
      final store = JpStoreMemory();
      for (final w in ofKind(ItemKind.word).take(300)) {
        await seed(store, w, tuesday);
      }
      final p = await plan(store, tuesday);
      await store.putDay(DayRecord(day: tuesday, plan: p.encode()));
      final back = DayPlan.decode((await store.day(tuesday))!.plan);
      expect(back.toJson(), p.toJson());
      expect(back.entries, p.entries);
      expect(back.catchUpEntries, p.catchUpEntries);
    });

    test('building a plan writes nothing to the record', () async {
      final store = JpStoreMemory();
      await store
          .appendAttempt(wrongOn(ofKind(ItemKind.word)[150], tuesday - 1));
      await seed(store, ofKind(ItemKind.word)[3], tuesday);
      final before = jsonEncode([
        for (final a in await store.attempts()) a.toJson(),
        for (final s in await store.seeds()) s.toJson(),
        (await store.allSrs()).length,
        (await store.allMastery()).length,
      ]);
      await plan(store, tuesday);
      final after = jsonEncode([
        for (final a in await store.attempts()) a.toJson(),
        for (final s in await store.seeds()) s.toJson(),
        (await store.allSrs()).length,
        (await store.allMastery()).length,
      ]);
      expect(after, before);
      expect(await store.lastDay(), isNull);
    });
  });
}
