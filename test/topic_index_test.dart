// The topic index (plan 2026-11-02, Task 22, End states 1 and 9).
//
// Every case builds a `TopicIndex` over the shipped catalog and a memory store with hand-set
// states, and states one rule: a search for an English gloss lands on the word; readings, form
// names, counters, use labels and catalog search terms are found too; a use lists its grammar
// points and particles; each browse set holds what it names; a topic counts its items by state
// and never as a bare percentage; and the topic pill follows the roll-up (Mastered when every
// item is Mastered, Shaky when any is Shaky, Learning when any has an attempt, New otherwise).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/topic_index.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final grammar = _read('assets/lessons/jp_grammar.json');
final catalog =
    ItemCatalog.fromDocs(grammar, _read('assets/lessons/jp_lessons.json'));

const int today = 200;

MasteryState stateOf(String id, MasteryStatus status) =>
    MasteryState(itemId: id, status: status);

SrsState srsDue(int dueDay) => SrsState(
    stability: 5,
    difficulty: 5,
    lastReviewDay: dueDay - 5,
    dueDay: dueDay,
    interval: 5);

TopicIndex indexOf({
  Map<String, MasteryStatus> states = const {},
  Map<String, SrsState> srs = const {},
  Map<String, int> seedDue = const {},
}) =>
    TopicIndex(
      catalog: catalog,
      grammar: grammar,
      today: today,
      mastery: {
        for (final e in states.entries) e.key: stateOf(e.key, e.value),
      },
      srs: srs,
      seedDue: seedDue,
    );

void main() {
  group('search', () {
    final index = indexOf();

    test('an English gloss lands on the word', () {
      final hits = index.search('book');
      expect(hits, isNotEmpty);
      expect(hits.first.itemId, 'L02_00');
      expect(catalog.byId(hits.first.itemId!)!.title, 'ほん');
      // The longer glosses that contain it still come, after the exact one.
      final ids = [for (final h in hits) h.itemId];
      expect(ids, containsAll(['L10_22', 'L27_21']));
    });

    test('one meaning of a gloss with several lands on the word', () {
      final watch = catalog
          .ofKind(ItemKind.word)
          .firstWhere((w) => w.probes.first.text == 'watch, clock');
      expect(index.search('clock').first.itemId, watch.id);
      expect(index.search('Clock ').first.itemId, watch.id,
          reason: 'case and spaces do not matter');
    });

    test('a reading lands on the word', () {
      expect(index.search('じしょ').first.itemId, 'L02_01');
    });

    test('a romaji query lands on the word its hiragana spells (#137)', () {
      expect(index.search('jisho').first.itemId, 'L02_01');
      expect(index.search('JISHO').first.itemId, 'L02_01');
    });

    test('a pattern, a summary and a catalog search term land on the point',
        () {
      expect(index.search('Nが できます').first.itemId, 'mari.L27.3');
      expect(index.search('Describe abilities using a noun').first.itemId,
          'mari.L27.3');
      expect(index.search('にほんごが できます。').first.itemId, 'mari.L27.3');
    });

    test('a form name lands on the verb form topic', () {
      final hit = index.search('て form').first;
      expect(hit.topic, isNotNull);
      expect(hit.topic!.id, 'form.te');
      expect(hit.topic!.itemIds, ['conj.te.g1', 'conj.te.g2', 'conj.te.g3']);
      expect(index.search('causative passive').first.topic!.id,
          'form.causative_passive');
    });

    test('a counter lands on the counters table', () {
      for (final q in ['people', '人', 'にん']) {
        final hit = index.search(q).firstWhere((h) => h.topic != null);
        expect(hit.topic!.id, 'table.counters', reason: q);
        expect(hit.topic!.itemIds.every((id) => id.startsWith('ref.counters.')),
            isTrue);
      }
    });

    test('a use label lands on the use', () {
      final hit = index.search('giving advice').first;
      expect(hit.topic!.id, 'use.advise');
    });

    test('an empty query finds nothing', () {
      expect(index.search(''), isEmpty);
      expect(index.search('   '), isEmpty);
    });

    test('a hit carries the item state and its next review', () {
      final withState = indexOf(
          states: {'L02_00': MasteryStatus.learning},
          srs: {'L02_00': srsDue(today + 3)});
      final hit = withState.search('book').first;
      expect(hit.itemId, 'L02_00');
      expect(withState.statusOf('L02_00'), MasteryStatus.learning);
      expect(withState.nextDue('L02_00'), today + 3);
      expect(withState.nextDue('L02_01'), isNull);
    });
  });

  group('browse', () {
    test('By use holds the 30 uses, and a use lists its points and particles',
        () {
      final index = indexOf();
      final uses = index.browse(BrowseSet.byUse);
      expect(uses.length, (grammar['uses'] as List).length);
      expect(uses.length, 30);
      final condition = index.use('condition')!;
      expect(condition.title, 'If and when');
      expect(
          condition.itemIds,
          containsAll(
              ['mari.L35.1', 'mari.L35.2', 'mari.L45.1', 'mari.particle.1']));
      expect(condition.itemIds.map((id) => catalog.byId(id)!.kind).toSet(),
          {ItemKind.grammar, ItemKind.particle});
      // The use rows that are not points or particles expand to their items.
      expect(index.use('forms')!.itemIds, contains('conj.masu.g1'));
      expect(
          index.use('transitivity')!.itemIds,
          everyElement(predicate<String>(
              (id) => catalog.byId(id)!.kind == ItemKind.pair)));
      expect(index.use('counting')!.itemIds, contains('ref.counters.1'));
    });

    test('Verb forms, Verb groups, Counters and tables, Words by lesson', () {
      final index = indexOf();
      final forms = index.browse(BrowseSet.verbForms);
      expect(forms.length, 12);
      expect(forms.first.title, 'ます form');
      final groups = index.browse(BrowseSet.verbGroups);
      expect(groups.length, 3);
      expect(groups.first.itemIds, contains('conj.te.g1'));
      expect(groups.first.itemIds.any((id) => id.endsWith('.g2')), isFalse);
      final tables = index.browse(BrowseSet.countersAndTables);
      expect([for (final t in tables) t.id],
          ['table.counters', 'table.months', 'table.dates', 'table.durations']);
      final lessons = index.browse(BrowseSet.wordsByLesson);
      expect(lessons.first.id, 'lesson.2.words');
      expect(lessons.first.itemIds, contains('L02_00'));
      expect(
          lessons.first.itemIds
              .every((id) => catalog.byId(id)!.kind == ItemKind.word),
          isTrue);
    });

    test('Due today, Shaky and Not yet known come from the record', () {
      final index = indexOf(
        states: {
          'L02_00': MasteryStatus.learning,
          'L02_01': MasteryStatus.shaky,
          // An early hinted answer: Learning by its badge, but with no schedule and no
          // seed, so it is still not yet known.
          'L02_03': MasteryStatus.learning,
        },
        srs: {
          'L02_00': srsDue(today),
          'L02_01': srsDue(today + 4),
        },
        seedDue: {'L02_02': today - 1, 'L02_04': today + 2},
      );
      final due = index.browse(BrowseSet.dueToday).single;
      expect(due.itemIds, unorderedEquals(['L02_00', 'L02_02']));
      final shaky = index.browse(BrowseSet.shaky).single;
      expect(shaky.itemIds, ['L02_01']);
      final notYet = index.browse(BrowseSet.notYetKnown).single;
      expect(notYet.itemIds, contains('L02_03'));
      expect(notYet.itemIds, isNot(contains('L02_00')));
      expect(notYet.itemIds, isNot(contains('L02_02')));
      expect(notYet.itemIds, isNot(contains('L02_04')));
      expect(notYet.itemIds.length, catalog.items.length - 4);
    });

    test('an item lists the topics it belongs to', () {
      final index = indexOf();
      final related = [for (final t in index.topicsOf('mari.particle.1')) t.id];
      expect(related, containsAll(['use.manner', 'use.condition']));
      expect([for (final t in index.topicsOf('L02_00')) t.id],
          contains('lesson.2.words'));
    });
  });

  group('counts and the roll-up pill (D16)', () {
    test('the pill rules', () {
      const m = MasteryStatus.mastered,
          s = MasteryStatus.shaky,
          l = MasteryStatus.learning,
          n = MasteryStatus.neu;
      expect(rollUp([m, m, m]), m, reason: 'every item Mastered');
      expect(rollUp([m, m, s]), s, reason: 'any Shaky');
      expect(rollUp([s, n, n]), s, reason: 'Shaky outranks the rest');
      expect(rollUp([m, n]), l, reason: 'some attempted, not all Mastered');
      expect(rollUp([l, n, n]), l);
      expect(rollUp([n, n]), n, reason: 'nothing attempted');
      expect(rollUp(const []), n, reason: 'an empty topic is New');
    });

    test('a topic counts its items by state and never shows a percentage', () {
      final use = indexOf().use('condition')!;
      final ids = use.itemIds;
      final index = indexOf(states: {
        ids[0]: MasteryStatus.mastered,
        ids[1]: MasteryStatus.shaky,
        ids[2]: MasteryStatus.learning,
      });
      final topic = index.use('condition')!;
      expect(topic.counts.mastered, 1);
      expect(topic.counts.shaky, 1);
      expect(topic.counts.learning, 1);
      expect(topic.counts.neu, ids.length - 3);
      expect(topic.counts.total, ids.length);
      expect(topic.pill, MasteryStatus.shaky);
      expect(topic.counts.label,
          '1 of ${ids.length} mastered · 1 shaky · 1 learning · ${ids.length - 3} new');
      expect(topic.counts.label, isNot(contains('%')));

      final all = indexOf(states: {
        for (final id in ids) id: MasteryStatus.mastered,
      }).use('condition')!;
      expect(all.pill, MasteryStatus.mastered);
      expect(all.counts.label, '${ids.length} of ${ids.length} mastered');
    });

    test('load reads the states, schedules and seeds from the store', () async {
      final store = JpStoreMemory();
      await store.putMastery(stateOf('L02_00', MasteryStatus.mastered));
      await store.putSrs('L02_00', srsDue(today + 30));
      await store.appendSeed('L02_01', today, atUtc: DateTime.utc(2026, 1, 1));
      final index = await TopicIndex.load(
          store: store, catalog: catalog, grammar: grammar, today: today);
      expect(index.statusOf('L02_00'), MasteryStatus.mastered);
      expect(index.nextDue('L02_00'), today + 30);
      expect(index.nextDue('L02_01'), today);
      expect(index.browse(BrowseSet.dueToday).single.itemIds, ['L02_01']);
      final lesson = index.browse(BrowseSet.wordsByLesson).first;
      expect(lesson.counts.mastered, 1);
      expect(lesson.pill, MasteryStatus.learning);
    });
  });
}
