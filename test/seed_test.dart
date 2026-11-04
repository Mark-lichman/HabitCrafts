// The first-launch seed (Task 15, D7, D21, D26, PIN-7, PIN-12). Every case seeds a memory
// store from the shipped catalog: the default set re-counted from the catalog (A6), zero
// attempts and no state, every seeded item unmastered with zero clears, the 20-day spread in
// lesson order, an unticked lesson seeding nothing and arriving through the intake, the first
// real clear on a seeded item as clear one of four, the seed running once, an item with a
// schedule keeping it, the v2 keys coming in through the migration, and a rebuild restoring
// the seeded due days.

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
import 'package:habit_craft/components/pages/quiet_room_mastery/seed.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/study_export.dart'
    show kV2MigrationFlag;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final grammarDoc = _read('assets/lessons/jp_grammar.json');
final catalog =
    ItemCatalog.fromDocs(grammarDoc, _read('assets/lessons/jp_lessons.json'));
const scheduler = FsrsScheduler();

const int day = 300;
final DateTime nowUtc = dayStart(day).add(const Duration(hours: 6)).toUtc();

Future<SeedReport> seedDefault(JpStore store, {SeedLessons? lessons}) =>
    seedFromLessons(day, store, catalog, lessons: lessons, nowUtc: nowUtc);

/// The default seed set, counted straight from the catalog (A6).
Set<String> defaultSet() => {
      for (final i in catalog.items)
        if (i.prereqLevel == 0 ||
            (i.kind == ItemKind.word && i.lesson! >= 2 && i.lesson! <= 30) ||
            (i.kind == ItemKind.grammar && i.lesson! >= 26 && i.lesson! <= 31))
          i.id
    };

Attempt clearOn(ItemDef item, int on) {
  final p = item.scoredProbes.first;
  return Attempt(
    itemId: item.id,
    probeId: p.id,
    template: p.template,
    production: p.production,
    selfGraded: p.selfGraded,
    atUtc: dayStart(on).add(const Duration(hours: 8)).toUtc(),
    localDay: on,
    grade: Grade.clear,
    rating: fsrsRatingFor(Grade.clear),
    wasDue: true,
    source: Source.review,
    sessionId: 's$on',
  );
}

void main() {
  test(
      'the default set is every word of lessons 2 to 30, every grammar point of '
      '26 to 31 and every level-0 item, re-counted from the catalog (A6)',
      () async {
    final store = JpStoreMemory();
    final report = await seedDefault(store);
    final seeded = {for (final s in await store.seeds()) s.itemId};
    final expected = defaultSet();
    expect(seeded, expected);
    expect(report.seeded, expected.length);
    expect(report.alreadyRan, isFalse);
    // Every level-0 kind is in, and the grammar outside 26 to 31 is not.
    for (final kind in [
      ItemKind.particle,
      ItemKind.conjugation,
      ItemKind.pair,
      ItemKind.tableRow,
    ]) {
      expect(catalog.ofKind(kind).every((i) => seeded.contains(i.id)), isTrue,
          reason: '$kind');
    }
    expect(
        catalog
            .ofKind(ItemKind.grammar)
            .where((g) => g.lesson! > 31)
            .any((g) => seeded.contains(g.id)),
        isFalse);
    final byKind = <ItemKind, int>{};
    for (final id in seeded) {
      final k = catalog.byId(id)!.kind;
      byKind[k] = (byKind[k] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('seed set: ${seeded.length} items, $byKind');
  });

  test(
      'the seed writes no attempt, no FSRS state and no clear: every seeded item is '
      'unmastered with zero clears (PIN-7)', () async {
    final store = JpStoreMemory();
    await seedDefault(store);
    expect(await store.attempts(), isEmpty);
    expect(await store.allSrs(), isEmpty);
    expect(await store.allMastery(), isEmpty);
    for (final s in await store.seeds()) {
      final m = await store.mastery(s.itemId) ?? MasteryState.initial(s.itemId);
      expect(m.status, isNot(MasteryStatus.mastered));
      expect(m.clears, isEmpty);
    }
    // The same holds after a rebuild from the log.
    final replay = await store.rebuild(catalog.byId, scheduler);
    expect(replay.srs, isEmpty);
    expect(replay.mastery, isEmpty);
  });

  test('the due days spread over 20 days from the seed day, in lesson order',
      () async {
    final store = JpStoreMemory();
    await seedDefault(store);
    final due = {for (final s in await store.seeds()) s.itemId: s.dueDay};
    final days = due.values.toSet();
    expect(days.length, kSeedSpreadDays);
    expect(days.reduce((a, b) => a < b ? a : b), day);
    expect(days.reduce((a, b) => a > b ? a : b), day + kSeedSpreadDays - 1);

    // Lesson order: a later lesson is never due before an earlier one, and a lesson's words
    // are never due after its grammar.
    final order = seedOrder(catalog, SeedLessons.standard()).lessonItems;
    for (var i = 1; i < order.length; i++) {
      expect(due[order[i].id]!, greaterThanOrEqualTo(due[order[i - 1].id]!),
          reason: '${order[i].id} after ${order[i - 1].id}');
      expect(order[i].lesson!, greaterThanOrEqualTo(order[i - 1].lesson!));
    }
    // No day carries much more than its share of the seed.
    final load = <int, int>{};
    for (final d in due.values) {
      load[d] = (load[d] ?? 0) + 1;
    }
    final share = (due.length / kSeedSpreadDays).ceil();
    for (final n in load.values) {
      expect(n, lessThanOrEqualTo(share + 2));
    }
    // Day one's queue holds the first lessons' words, not the last ones.
    final first = await store.dueOnOrBefore(day);
    final lessonsDueFirst = {
      for (final d in first)
        if (catalog.byId(d.itemId)!.lesson != null)
          catalog.byId(d.itemId)!.lesson!
    };
    expect(lessonsDueFirst, contains(2));
    expect(lessonsDueFirst, isNot(contains(30)));
  });

  test(
      'an unticked lesson seeds nothing; its items stay New and arrive through the '
      'daily intake in lesson order (PIN-12)', () async {
    final store = JpStoreMemory();
    final lessons =
        SeedLessons.standard().without(wordLesson: 10, grammarLesson: 27);
    await seedDefault(store, lessons: lessons);
    final seeded = {for (final s in await store.seeds()) s.itemId};
    final words10 = [
      for (final w in catalog.ofKind(ItemKind.word))
        if (w.lesson == 10) w.id
    ];
    final grammar27 = [
      for (final g in catalog.ofKind(ItemKind.grammar))
        if (g.lesson == 27) g.id
    ];
    expect(words10, isNotEmpty);
    expect(grammar27, isNotEmpty);
    for (final id in [...words10, ...grammar27]) {
      expect(seeded.contains(id), isFalse, reason: id);
      expect(await store.srs(id), isNull);
      expect(await store.mastery(id), isNull);
    }
    // The word lesson 27 stays ticked: its words are seeded though grammar 27 is not.
    expect(
        catalog
            .ofKind(ItemKind.word)
            .where((w) => w.lesson == 27)
            .every((w) => seeded.contains(w.id)),
        isTrue);
    expect(
        seeded.length, defaultSet().length - words10.length - grammar27.length);

    // The intake takes them first, in lesson order: lesson 10's words, then 27's points.
    final introduced = {...(await store.allSrs()).keys, ...seeded};
    final intake =
        newIntakeOrder(catalog, introduced, words10.length + grammar27.length);
    expect([for (final i in intake) i.id], [...words10, ...grammar27]);
  });

  test('a first real clear on a seeded item is clear one of four', () async {
    final store = JpStoreMemory();
    await seedDefault(store);
    final dueToday = await store.dueOnOrBefore(day);
    final word = catalog.byId(dueToday
        .firstWhere((d) => catalog.byId(d.itemId)!.kind == ItemKind.word)
        .itemId)!;
    final outcome = await store.recordAnswer(clearOn(word, day),
        item: word, scheduler: scheduler);
    expect(outcome.mastery!.status, MasteryStatus.learning);
    expect(outcome.mastery!.clears.length, 1);
    expect(kClearsToMaster, 4);
    // The answer is FSRS review one: the item now has a state, first reviewed today.
    expect(outcome.srs, isNotNull);
    expect(outcome.srs!.lastReviewDay, day);
    expect((await store.attempts()).length, 1);
  });

  test('the seed runs once per store', () async {
    final store = JpStoreMemory();
    final first = await seedDefault(store);
    final again = await seedDefault(store);
    expect(again.alreadyRan, isTrue);
    expect(again.seeded, 0);
    expect((await store.seeds()).length, first.seeded);
    expect(await store.meta(kSeedFlag), isNotNull);
  });

  test('an item already practised keeps its schedule and gets no seed',
      () async {
    final store = JpStoreMemory();
    final word = catalog.ofKind(ItemKind.word).first;
    await store.recordAnswer(clearOn(word, day - 3),
        item: word, scheduler: scheduler);
    final before = await store.srs(word.id);
    final report = await seedDefault(store);
    expect(report.keptSchedule, 1);
    expect(report.seeded, defaultSet().length - 1);
    expect((await store.seeds()).any((s) => s.itemId == word.id), isFalse);
    expect(await store.srs(word.id), before);
  });

  test(
      'the v2 keys come in through the migration: review_needed is due today, '
      'can_use_it is a note, and no attempt is written', () async {
    final unticked =
        catalog.ofKind(ItemKind.grammar).firstWhere((g) => g.lesson! > 31);
    final ticked =
        catalog.ofKind(ItemKind.grammar).lastWhere((g) => g.lesson == 31);
    final noted =
        catalog.ofKind(ItemKind.grammar).firstWhere((g) => g.lesson == 26);
    SharedPreferences.setMockInitialValues({
      'jp.selfcheck.${unticked.id}': 'review_needed',
      'jp.selfcheck.${ticked.id}': 'review_needed',
      'jp.selfcheck.${noted.id}': 'can_use_it',
    });
    final store = JpStoreMemory();
    final report = await seedFromLessons(day, store, catalog,
        prefs: await SharedPreferences.getInstance(),
        grammar: grammarDoc,
        nowUtc: nowUtc);
    expect(report.migration, isNotNull);
    expect(report.migration!.dueToday, 2);
    expect(await store.meta(kV2MigrationFlag), isNotNull);
    expect((await store.item(unticked.id))!.seedDueDay, day);
    // A ticked point the lesson spread would place later keeps the earlier day.
    expect((await store.item(ticked.id))!.seedDueDay, day);
    expect((await store.item(noted.id))!.note, 'can_use_it');
    expect(await store.attempts(), isEmpty);
    expect(await store.allMastery(), isEmpty);
  });

  test(
      'prefs without the grammar document is refused before anything is written',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = JpStoreMemory();
    await expectLater(
        seedFromLessons(day, store, catalog,
            prefs: await SharedPreferences.getInstance(), nowUtc: nowUtc),
        throwsArgumentError);
    expect(await store.seeds(), isEmpty);
    expect(await store.meta(kSeedFlag), isNull);
  });

  test('a rebuild from the log restores every seeded due day (D26)', () async {
    final store = JpStoreMemory();
    await seedDefault(store);
    final before = await store.dueOnOrBefore(day + kSeedSpreadDays);
    await store.rebuild(catalog.byId, scheduler);
    expect(await store.dueOnOrBefore(day + kSeedSpreadDays), before);
    expect(before.length, defaultSet().length);
    expect(before.every((d) => d.seeded), isTrue);
  });
}
