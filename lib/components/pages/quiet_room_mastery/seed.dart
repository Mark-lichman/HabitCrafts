// The first-launch seed (D7, D21, D26, PIN-7, PIN-12). `seedFromLessons` puts the lessons Mark
// has already studied into the review queue without counting any of it as mastered.
//
// What it seeds:
//   * every word of each ticked word lesson and every grammar point of each ticked grammar
//     lesson (by default word lessons 2 to 30 and grammar lessons 26 to 31);
//   * every level-0 item: particles, conjugation ideas, verb pairs and table rows.
// An unticked lesson seeds nothing: its items stay New and arrive through the daily intake in
// lesson order (`newIntakeOrder` in plan_builder.dart takes every item with no state and no seed).
//
// 🚨 A SEED IS NOT AN ANSWER (PIN-7, D26). Each seeded item gets one `seed` event in the log: an
// item id and a due day. It writes no attempt, no FSRS state and no clear, so no seeded item is
// Mastered until it earns the full rule from real answers, and the first real answer on it is
// FSRS review one and clear one of four. A rebuild from the log restores the seeded due days.
//
// The spread: the lesson items, in lesson order (each lesson's words before its grammar), are
// spread evenly over [kSeedSpreadDays] days from the seed day; the level-0 items, in catalog
// order, are spread over the same days beside them. An item that already has an FSRS state (from
// practice before the seed) keeps its own schedule and gets no seed.
//
// The v2 keys come in through the store's one-time migration (`migrateV2Keys`) before the seed;
// a point it marks due today keeps that earlier day, because the store keeps each item's
// earliest seeded due day. The seed itself runs once per store: a flag in the store's meta
// records it, written last.

import 'package:shared_preferences/shared_preferences.dart';

import 'attempt.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'study_export.dart';

/// The store flag set once the first-launch seed is written.
const String kSeedFlag = 'seed.v1';

/// The days the seed spreads its due days over (D7).
const int kSeedSpreadDays = 20;

/// The default ticked word lessons and grammar lessons (D7, PIN-12).
const int kSeedFirstWordLesson = 2;
const int kSeedLastWordLesson = 30;
const int kSeedFirstGrammarLesson = 26;
const int kSeedLastGrammarLesson = 31;

/// The lessons ticked at the seed confirmation. A word lesson and a grammar lesson with the
/// same number are separate ticks (word lessons 26 to 30 and grammar lessons 26 to 30 overlap).
class SeedLessons {
  const SeedLessons({required this.wordLessons, required this.grammarLessons});

  /// Every word lesson [kSeedFirstWordLesson] to [kSeedLastWordLesson] and every grammar lesson
  /// [kSeedFirstGrammarLesson] to [kSeedLastGrammarLesson].
  factory SeedLessons.standard() => SeedLessons(
        wordLessons: {
          for (var l = kSeedFirstWordLesson; l <= kSeedLastWordLesson; l++) l
        },
        grammarLessons: {
          for (var l = kSeedFirstGrammarLesson;
              l <= kSeedLastGrammarLesson;
              l++)
            l
        },
      );

  final Set<int> wordLessons;
  final Set<int> grammarLessons;

  /// This set with [wordLesson] unticked from the word lessons and [grammarLesson] from the
  /// grammar lessons.
  SeedLessons without({int? wordLesson, int? grammarLesson}) => SeedLessons(
        wordLessons: {...wordLessons}..remove(wordLesson),
        grammarLessons: {...grammarLessons}..remove(grammarLesson),
      );

  /// Whether [item] is seeded under this set. Level-0 items always are.
  bool covers(ItemDef item) {
    if (item.prereqLevel == 0) return true;
    final lesson = item.lesson;
    if (lesson == null) return false;
    return switch (item.kind) {
      ItemKind.word => wordLessons.contains(lesson),
      ItemKind.grammar => grammarLessons.contains(lesson),
      _ => false,
    };
  }
}

/// What the seed wrote.
class SeedReport {
  const SeedReport({
    this.alreadyRan = false,
    this.seeded = 0,
    this.keptSchedule = 0,
    this.migration,
  });

  /// The seed had run before; nothing was written.
  final bool alreadyRan;

  /// Items given a seeded due day.
  final int seeded;

  /// Covered items left out because they already had an FSRS state.
  final int keptSchedule;

  /// The v2 migration's report, when the v2 keys were passed.
  final V2MigrationReport? migration;
}

/// The items [lessons] seeds, in seed order: the lesson items in lesson order (each lesson's
/// words, then its grammar points, each in catalog order), then the level-0 items in catalog
/// order. Pure.
({List<ItemDef> lessonItems, List<ItemDef> foundations}) seedOrder(
    ItemCatalog catalog, SeedLessons lessons) {
  final foundations = [
    for (final i in catalog.items)
      if (i.prereqLevel == 0) i
  ];
  final covered = [
    for (final i in catalog.items)
      if (i.prereqLevel != 0 && lessons.covers(i)) i
  ];
  final byLesson = <int>{for (final i in covered) i.lesson!}.toList()..sort();
  final lessonItems = [
    for (final l in byLesson) ...[
      for (final i in covered)
        if (i.lesson == l && i.kind == ItemKind.word) i,
      for (final i in covered)
        if (i.lesson == l && i.kind != ItemKind.word) i,
    ],
  ];
  return (lessonItems: lessonItems, foundations: foundations);
}

/// The due day of the [index]th of [count] items spread evenly over [kSeedSpreadDays] days
/// from [day]. Never decreasing in [index]; the first is [day].
int seedDueDay(int day, int index, int count) =>
    day + (index * kSeedSpreadDays) ~/ (count < 1 ? 1 : count);

/// Seeds the lessons Mark keeps ticked, once per store (see the file comment). With [prefs]
/// and [grammar] (the decoded `jp_grammar.json`), the v2 keys are imported first through
/// [migrateV2Keys]. [nowUtc] stamps the seed events; [day] is today's local day.
Future<SeedReport> seedFromLessons(
  int day,
  JpStore store,
  ItemCatalog catalog, {
  SeedLessons? lessons,
  SharedPreferences? prefs,
  Map<String, dynamic>? grammar,
  required DateTime nowUtc,
}) async {
  if ((prefs == null) != (grammar == null)) {
    throw ArgumentError('seedFromLessons: pass prefs and grammar together');
  }
  if (await store.meta(kSeedFlag) != null) {
    return const SeedReport(alreadyRan: true);
  }
  final migration = prefs == null
      ? null
      : await migrateV2Keys(store, prefs,
          grammar: grammar!,
          known: (id) => catalog.byId(id) != null,
          today: day,
          nowUtc: nowUtc);

  final order = seedOrder(catalog, lessons ?? SeedLessons.standard());
  final stateful = await store.allSrs();
  final at = nowUtc.toUtc();
  final events = <SeedEvent>[];
  var kept = 0;
  void spread(List<ItemDef> items) {
    for (var i = 0; i < items.length; i++) {
      final id = items[i].id;
      if (stateful.containsKey(id)) {
        kept++;
        continue;
      }
      events.add(SeedEvent(
          itemId: id, dueDay: seedDueDay(day, i, items.length), atUtc: at));
    }
  }

  spread(order.lessonItems);
  spread(order.foundations);
  await store.appendSeeds(events);
  await store.putMeta(kSeedFlag, at.toIso8601String());
  return SeedReport(
      seeded: events.length, keptSchedule: kept, migration: migration);
}
