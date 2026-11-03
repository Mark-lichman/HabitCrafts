// Tests for the item catalog (D1, D19, Task 5). Every expected count is re-measured from the
// shipped assets on each run, never hard-coded, so a regenerated asset moves the snapshot and
// the catalog together. What stays fixed is the shape: stable unique ids, at least one probe
// per item, at least three sentence probes per grammar point, and prerequisites that resolve.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final grammarDoc = _read('assets/lessons/jp_grammar.json');
final lessonsDoc = _read('assets/lessons/jp_lessons.json');

/// The per-kind counts measured straight from the raw assets, independent of the catalog code.
Map<ItemKind, int> measuredCounts() {
  final points = [
    for (final l in grammarDoc['grammar'] as List) ...(l['points'] as List)
  ];
  final words = [
    for (final l in lessonsDoc['lessons'] as List) ...(l['items'] as List)
  ];
  final conj = grammarDoc['conjugation'] as Map<String, dynamic>;
  final verbs = (conj['verbs'] as List).cast<Map<String, dynamic>>();
  final ideas = <String>{
    for (final form in (conj['forms'] as List).cast<String>())
      for (final v in verbs)
        if ((v[form] as String? ?? '').isNotEmpty) '$form.${v['group']}'
  };
  final rows = [
    for (final t in grammarDoc['reference'] as List) ...(t['rows'] as List)
  ];
  return {
    ItemKind.grammar: points.length,
    ItemKind.particle: (grammarDoc['particles'] as List).length,
    ItemKind.word: words.length,
    ItemKind.conjugation: ideas.length,
    ItemKind.pair: (grammarDoc['pairs'] as List).length,
    ItemKind.tableRow: rows.length,
  };
}

void main() {
  final catalog = ItemCatalog.fromDocs(grammarDoc, lessonsDoc);

  test('the counts per kind match a re-measure of the shipped assets', () {
    final measured = measuredCounts();
    final built = {
      for (final k in ItemKind.values) k: catalog.ofKind(k).length,
    };
    // Printed so a reviewer sees the dated snapshot this run measured.
    // ignore: avoid_print
    print('item catalog snapshot: $built, total ${catalog.items.length}');
    expect(built, measured);
    expect(catalog.items.length,
        measured.values.fold<int>(0, (sum, n) => sum + n));
    for (final k in ItemKind.values) {
      expect(built[k], greaterThan(0), reason: 'no $k items were built');
    }
  });

  test('every id is unique and resolves through byId', () {
    final ids = catalog.items.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final item in catalog.items) {
      expect(identical(catalog.byId(item.id), item), isTrue);
    }
    expect(catalog.byId('no.such.item'), isNull);
  });

  test('ids follow the stable scheme for each kind', () {
    final scheme = {
      ItemKind.grammar: RegExp(r'^mari\.L\d+\.\d+$'),
      ItemKind.particle: RegExp(r'^mari\.particle\.\d+$'),
      ItemKind.word: RegExp(r'^L\d\d_\d\d+$'),
      ItemKind.conjugation: RegExp(r'^conj\.[a-z_]+\.g[123]$'),
      ItemKind.pair: RegExp(r'^s0[23]_pairs_[a-z]+\.[\d.]+$'),
      ItemKind.tableRow: RegExp(r'^ref\.[a-z]+\..+$'),
    };
    for (final item in catalog.items) {
      expect(scheme[item.kind]!.hasMatch(item.id), isTrue,
          reason: '${item.id} does not fit the ${item.kind} id scheme');
    }
  });

  test('every word id is its image stem (D19)', () {
    for (final l in lessonsDoc['lessons'] as List) {
      for (final w in (l['items'] as List).cast<Map<String, dynamic>>()) {
        final stem = (w['image'] as String).split('/').last.split('.').first;
        final item = catalog.byId(stem);
        expect(item, isNotNull, reason: 'no item for word $stem');
        expect(item!.kind, ItemKind.word);
        expect(item.lesson, l['lesson']);
      }
    }
  });

  test('pairs carry their catalog id, in the order the catalog lists them', () {
    final catalogPairs = [
      for (final c in (grammarDoc['catalog'] as List).cast<Map>())
        if (c['type'] == 'verb_pair') c['id'] as String
    ];
    expect(
        catalog.ofKind(ItemKind.pair).map((i) => i.id).toList(), catalogPairs);
  });

  test('every item has at least one probe, and probe ids are unique per item',
      () {
    for (final item in catalog.items) {
      expect(item.probes, isNotEmpty, reason: '${item.id} has no probe');
      final ids = item.probes.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: '${item.id} repeats a probe id');
      expect(item.probeCount, greaterThan(0),
          reason: '${item.id} has no probe that can earn a clear');
      expect(item.templateCount, greaterThan(0));
    }
  });

  test('every grammar point has at least three sentence probes', () {
    for (final item in catalog.ofKind(ItemKind.grammar)) {
      final sentences = item.probes.map((p) => p.text).toSet();
      expect(sentences.length, greaterThanOrEqualTo(3),
          reason: '${item.id} has under three sentence probes');
      // Transfer (D4 clause 5) needs three different scored sentences.
      expect(item.probeCount, greaterThanOrEqualTo(3),
          reason: '${item.id} has under three scored sentence probes');
    }
  });

  test('grammar probes are its practice items and its examples', () {
    final point = (grammarDoc['grammar'] as List).first['points'].first
        as Map<String, dynamic>;
    final item = catalog.byId(point['id'] as String)!;
    final practice = point['practice'] as List;
    final examples = point['examples'] as List;
    expect(item.probes.length, practice.length + examples.length);
    expect(item.lesson, (grammarDoc['grammar'] as List).first['lesson']);
    expect(item.prereqLevel, 2);
    final fill = item.probes.where((p) => p.template == 'fill');
    final choose = item.probes.where((p) => p.template == 'choose');
    expect(fill.every((p) => p.production), isTrue);
    expect(choose.every((p) => !p.production), isTrue);
    // Examples are the Say-it sentences: they never count toward the four clears (D4).
    final say = item.probes.where((p) => p.template == kSayItTemplate);
    expect(say.length, examples.length);
    expect(say.every((p) => !p.scored), isTrue);
  });

  test('templates and the production flag follow the scored probes', () {
    for (final item in catalog.items) {
      final scored = item.probes.where((p) => p.scored);
      expect(item.templateCount, scored.map((p) => p.template).toSet().length);
      expect(item.probeCount, scored.length);
      expect(item.hasProductionProbe, scored.any((p) => p.production));
    }
    final word = catalog.ofKind(ItemKind.word).first;
    expect(word.probes.map((p) => p.template).toList(),
        ['card', 'spoken', 'typed']);
    expect(word.hasProductionProbe, isTrue);
    expect(
        word.probes.firstWhere((p) => p.template == 'card').selfGraded, isTrue);
    for (final p in catalog.ofKind(ItemKind.particle)) {
      expect(p.templateCount, 1, reason: 'one cloze per particle (PIN-15)');
    }
    for (final p in catalog.ofKind(ItemKind.pair)) {
      expect(p.templateCount, 2, reason: 'both directions (D4)');
      expect(p.probeCount, 2);
      expect(p.hasProductionProbe, isFalse);
    }
  });

  test('prerequisite levels: 0 foundations, 1 words, 2 grammar', () {
    const level = {
      ItemKind.particle: 0,
      ItemKind.conjugation: 0,
      ItemKind.pair: 0,
      ItemKind.tableRow: 0,
      ItemKind.word: 1,
      ItemKind.grammar: 2,
    };
    for (final item in catalog.items) {
      expect(item.prereqLevel, level[item.kind], reason: item.id);
    }
    for (final kind in [ItemKind.word, ItemKind.grammar]) {
      for (final item in catalog.ofKind(kind)) {
        expect(item.lesson, isNotNull, reason: '${item.id} has no lesson');
      }
    }
  });

  test('every prerequisite resolves to a catalog item', () {
    var withPrereqs = 0;
    for (final item in catalog.items) {
      if (item.prereqs.isNotEmpty) withPrereqs++;
      for (final p in item.prereqs) {
        expect(catalog.byId(p), isNotNull,
            reason: '${item.id} needs $p, which is not an item');
      }
    }
    expect(withPrereqs, greaterThan(0));
    final first = (grammarDoc['grammar'] as List).first['points'].first
        as Map<String, dynamic>;
    final forms = (first['prereqs'] as List).cast<String>();
    final item = catalog.byId(first['id'] as String)!;
    for (final form in forms) {
      expect(item.prereqs.where((p) => p.startsWith('$form.g')), isNotEmpty,
          reason: '$form is not carried onto ${item.id}');
    }
  });

  test('conjugation ideas take the verbs of their group as probes', () {
    final conj = grammarDoc['conjugation'] as Map<String, dynamic>;
    final verbs = (conj['verbs'] as List).cast<Map<String, dynamic>>();
    final item = catalog.byId('conj.te.g2')!;
    final expected = [
      for (final v in verbs)
        if (v['group'] == 2 && (v['te'] as String? ?? '').isNotEmpty)
          v['dictionary'] as String
    ];
    expect(item.probes.map((p) => p.id).toList(), expected);
    expect(item.probes.every((p) => p.selfGraded), isTrue);
  });

  test('table rows take their cells as probes and flag irregular readings', () {
    final table =
        (grammarDoc['reference'] as List).first as Map<String, dynamic>;
    final row = (table['rows'] as List).first as String;
    final item = catalog.byId('ref.${table['id']}.$row')!;
    final cells = [
      for (final c in (table['cells'] as List).cast<Map<String, dynamic>>())
        if (c['row'] == row) c
    ];
    expect(item.probes.length, cells.length);
    for (var i = 0; i < cells.length; i++) {
      expect(item.probes[i].answer, cells[i]['reading']);
      expect(item.probes[i].irregular, cells[i]['mark'] != 'regular');
    }
    final allIrregular = catalog
        .ofKind(ItemKind.tableRow)
        .expand((i) => i.probes)
        .where((p) => p.irregular);
    expect(allIrregular, isNotEmpty);
  });

  test('particles take the cloze from the lesson data', () {
    for (final raw
        in (grammarDoc['particles'] as List).cast<Map<String, dynamic>>()) {
      final item = catalog.byId(raw['id'] as String)!;
      final cloze = raw['cloze'] as Map<String, dynamic>;
      expect(item.probes.single.text, cloze['prompt']);
      expect(item.probes.single.answer, cloze['answer']);
    }
  });

  test('ItemDef satisfies the mastery rule contract', () {
    final ItemDefLike item = catalog.ofKind(ItemKind.particle).first;
    expect(transferProbesNeeded(item), 0);
    final grammar = catalog.ofKind(ItemKind.grammar).first;
    expect(transferProbesNeeded(grammar), 3);
  });

  testWidgets('load() reads the bundled assets and caches one catalog',
      (tester) async {
    late ItemCatalog loaded;
    await tester.runAsync(() async {
      loaded = await ItemCatalog.load();
      expect(identical(await ItemCatalog.load(), loaded), isTrue);
    });
    expect(loaded.items.length, catalog.items.length);
  });
}
