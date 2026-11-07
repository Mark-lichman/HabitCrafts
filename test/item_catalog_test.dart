// Tests for the item catalog (D1, D19, Task 5). Every expected count is re-measured from the
// shipped assets on each run, never hard-coded, so a regenerated asset moves the snapshot and
// the catalog together. What stays fixed is the shape: stable unique ids, at least one probe
// per item, at least three sentence probes per grammar point, and prerequisites that resolve.
//
// New cards (plan 2026-11-06, Task 6, End state 5): every kind has a scored say card that
// shows the prompt only (PIN-12) and twins the probe it asks, and every particle has a choose
// card whose wrong options are other particles of the other slot, so exactly one option
// completes the sentence (PIN-7, A4).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_detail_widget.dart'
    show remainingFor;
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
    // Each practice item, its say card, and each example (plan 2026-11-06, Task 6).
    expect(item.probes.length, 2 * practice.length + examples.length);
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
      // A say or choose card asks the sentence, verb, direction or cell of the probe it
      // twins, so the probe count counts each one once (D4 clause 5).
      expect(item.probeCount,
          scored.map((p) => transferKeyOf(p.id)).toSet().length);
      expect(item.hasProductionProbe, scored.any((p) => p.production));
    }
    final word = catalog.ofKind(ItemKind.word).first;
    expect(word.probes.map((p) => p.template).toList(),
        ['card', 'spoken', 'typed', kSayCardTemplate]);
    expect(word.hasProductionProbe, isTrue);
    expect(
        word.probes.firstWhere((p) => p.template == 'card').selfGraded, isTrue);
    for (final p in catalog.ofKind(ItemKind.particle)) {
      // The cloze, the choose card and the say card (Task 6, PIN-7), over one sentence.
      expect(p.templateCount, 3, reason: 'cloze, choose and say card');
      expect(p.probeCount, 1, reason: 'one sentence per particle');
    }
    for (final p in catalog.ofKind(ItemKind.pair)) {
      expect(p.templateCount, 3,
          reason: 'both directions (D4) and the say card');
      expect(p.probeCount, 2);
      expect(p.hasProductionProbe, isTrue, reason: 'the say card');
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
    // Every form a point names must reach the item, so a silent drop (a form with no
    // matching idea) fails here and never reorders the introductions (Task 14).
    for (final lesson in grammarDoc['grammar'] as List) {
      for (final point
          in (lesson['points'] as List).cast<Map<String, dynamic>>()) {
        final forms = (point['prereqs'] as List? ?? const []).cast<String>();
        final item = catalog.byId(point['id'] as String)!;
        for (final form in forms) {
          expect(item.prereqs.where((p) => p.startsWith('$form.g')), isNotEmpty,
              reason: '$form is not carried onto ${item.id}');
        }
      }
    }
  });

  group('fromDocs fails loudly on a doctored asset', () {
    Map<String, dynamic> copyOf(Map<String, dynamic> doc) =>
        json.decode(json.encode(doc)) as Map<String, dynamic>;

    Matcher throwsStateErrorWith(String fragment) => throwsA(isA<StateError>()
        .having((e) => e.message, 'message', contains(fragment)));

    test('a missing verb_pair row is a row count mismatch', () {
      final grammar = copyOf(grammarDoc);
      final rows = grammar['catalog'] as List;
      final i = rows.indexWhere((c) => c['type'] == 'verb_pair');
      rows.removeAt(i);
      expect(() => ItemCatalog.fromDocs(grammar, lessonsDoc),
          throwsStateErrorWith('verb_pair rows'));
    });

    test('a verb_pair row whose title differs from its pair is a mismatch', () {
      final grammar = copyOf(grammarDoc);
      final rows = grammar['catalog'] as List;
      final row = rows.firstWhere((c) => c['type'] == 'verb_pair') as Map;
      row['title'] = 'なし / なし';
      expect(() => ItemCatalog.fromDocs(grammar, lessonsDoc),
          throwsStateErrorWith('its catalog row'));
    });

    test('a repeated word item is a duplicate id', () {
      final lessons = copyOf(lessonsDoc);
      final items = (lessons['lessons'] as List).first['items'] as List;
      items.add(copyOf(items.first as Map<String, dynamic>));
      expect(() => ItemCatalog.fromDocs(grammarDoc, lessons),
          throwsStateErrorWith('duplicate item ids'));
    });
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
    expect(item.probes.map((p) => p.id).toList(),
        [...expected, for (final v in expected) sayCardId(v)]);
    final conjugate =
        item.probes.where((p) => p.template == kConjugateTemplate).toList();
    expect(conjugate.map((p) => p.id).toList(), expected);
    expect(conjugate.every((p) => p.selfGraded), isTrue);
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
    // Each cell, then a say card per cell (Task 6).
    expect(item.probes.length, 2 * cells.length);
    for (var i = 0; i < cells.length; i++) {
      expect(item.probes[i].answer, cells[i]['reading']);
      expect(item.probes[i].irregular, cells[i]['mark'] != 'regular');
      expect(item.probes[cells.length + i].answer, cells[i]['reading']);
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
      final probe = item.probes.firstWhere((p) => p.template == 'cloze');
      expect(probe.text, cloze['prompt']);
      expect(probe.answer, cloze['answer']);
    }
  });

  test('ItemDef satisfies the mastery rule contract', () {
    final ItemDefLike item = catalog.ofKind(ItemKind.particle).first;
    expect(transferProbesNeeded(item), 0);
    final grammar = catalog.ofKind(ItemKind.grammar).first;
    expect(transferProbesNeeded(grammar), 3);
  });

  group('say cards and the particle choose card (plan 2026-11-06, Task 6)', () {
    Iterable<ProbeDef> sayCards(ItemDef item) =>
        item.probes.where((p) => p.template == kSayCardTemplate);

    test('every kind has a scored say card, every item at least one (D3)', () {
      for (final kind in ItemKind.values) {
        expect(catalog.ofKind(kind).expand(sayCards), isNotEmpty,
            reason: 'no $kind say card');
      }
      for (final item in catalog.items) {
        final says = sayCards(item).toList();
        expect(says, isNotEmpty, reason: '${item.id} has no say card');
        for (final p in says) {
          expect(p.scored, isTrue, reason: '${item.id} ${p.id} must count');
          expect(p.production, isTrue);
          expect(p.selfGraded, isFalse, reason: 'Azure scores it (PIN-2)');
          expect(p.answer, isNotEmpty);
        }
      }
    });

    test(
        'the say card is spoken, under a new name beside the Say-it template (D18)',
        () {
      expect(kSayCardTemplate, isNot(kSayItTemplate));
      expect(modeOfTemplate(kSayCardTemplate), ProbeMode.spoken);
      expect(modeOfTemplate(kSayItTemplate), isNull,
          reason: 'the Say-it track never counts');
    });

    test('a say card shows the prompt only, never the answer (PIN-12)', () {
      for (final item in catalog.items) {
        for (final p in sayCards(item)) {
          expect(p.text.contains(p.answer), isFalse,
              reason: '${item.id} ${p.id} shows its answer ${p.answer}');
        }
      }
    });

    test('a grammar point says the whole sentence of each practice item', () {
      for (final item in catalog.ofKind(ItemKind.grammar)) {
        final asked = item.probes
            .where((p) => p.scored && p.template != kSayCardTemplate)
            .toList();
        expect(sayCards(item).map((p) => p.id).toList(),
            [for (final p in asked) sayCardId(p.id)]);
        for (final p in asked) {
          final say = item.probes.firstWhere((s) => s.id == sayCardId(p.id));
          expect(say.text, p.text, reason: 'the prompt, with its blank');
          expect(say.answer, wholeSentence(p.text, p.answer));
          expect(say.answer.contains(RegExp(r'[＿_]')), isFalse,
              reason: '${item.id} ${say.id} hears a blank');
        }
      }
    });

    test('a particle says its whole cloze sentence', () {
      for (final item in catalog.ofKind(ItemKind.particle)) {
        final cloze = item.probes.firstWhere((p) => p.template == 'cloze');
        final say = sayCards(item).single;
        expect(say.id, sayCardId('cloze'));
        expect(say.text, cloze.text);
        expect(say.answer, wholeSentence(cloze.text, cloze.answer));
      }
    });

    test('a word says its reading from its meaning', () {
      for (final item in catalog.ofKind(ItemKind.word)) {
        final card = item.probes.firstWhere((p) => p.template == 'card');
        final say = sayCards(item).single;
        expect(say.id, kWordSayCardId);
        expect(say.text, card.text, reason: 'the meaning, beside the picture');
        expect(say.answer, card.answer, reason: 'the hiragana');
      }
    });

    test('a conjugation, a pair and a table row twin each asked probe', () {
      for (final kind in [
        ItemKind.conjugation,
        ItemKind.pair,
        ItemKind.tableRow
      ]) {
        for (final item in catalog.ofKind(kind)) {
          final asked =
              item.probes.where((p) => p.template != kSayCardTemplate).toList();
          final says = sayCards(item).toList();
          expect(says.length, asked.length, reason: item.id);
          for (var i = 0; i < asked.length; i++) {
            expect(says[i].id, sayCardId(asked[i].id));
            expect(says[i].text, asked[i].text,
                reason: 'the verb, the other side, or the number and counter');
            expect(says[i].answer, asked[i].answer);
            expect(transferKeyOf(says[i].id), asked[i].id);
          }
        }
      }
    });

    test(
        'every particle has a choose card with exactly one right option (PIN-7, A4)',
        () {
      final particles = catalog.ofKind(ItemKind.particle);
      final answers = {
        for (final p in particles)
          p.probes.firstWhere((q) => q.template == 'cloze').answer
      };
      final places = <int>{};
      for (final item in particles) {
        final cloze = item.probes.firstWhere((p) => p.template == 'cloze');
        final raw = (grammarDoc['particles'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((p) => p['id'] == item.id);
        final accepted =
            ((raw['cloze'] as Map)['accepted'] as List).cast<String>();
        final choose = item.probes.where((p) => p.template == 'choose');
        expect(choose, hasLength(1), reason: '${item.id} has no choose card');
        final c = choose.single;
        expect(c.id, kParticleChooseId);
        expect(transferKeyOf(c.id), cloze.id, reason: 'the same sentence');
        expect(c.scored, isTrue);
        expect(c.production, isFalse, reason: 'a recognition card');
        expect(modeOfTemplate(c.template), ProbeMode.recognition);
        expect(c.text, cloze.text);
        expect(c.answer, cloze.answer);
        expect(c.options, hasLength(kParticleChooseOptions));
        expect(c.options.toSet().length, c.options.length,
            reason: '${item.id} repeats an option');
        expect(c.options.where((o) => o == c.answer), hasLength(1));
        places.add(c.options.indexOf(c.answer));
        final slot = kParticleWrongOptions[c.answer]!;
        for (final o in c.options.where((o) => o != c.answer)) {
          expect(answers.contains(o), isTrue,
              reason: '${item.id}: $o is not another particle');
          expect(accepted.contains(o), isFalse,
              reason: '${item.id}: $o is an accepted form');
          // The wrong options fill the other kind of slot, so none completes the sentence.
          expect(slot.contains(o), isTrue,
              reason: '${item.id}: $o is not in the other slot list');
          expect(identical(kParticleWrongOptions[o], slot), isFalse,
              reason: '${item.id}: $o fills the same slot as ${c.answer}');
        }
      }
      expect(places.length, greaterThan(1),
          reason: 'the right option does not always sit in one place');
    });

    test('a particle with no slot gets no choose card, never a guessed one',
        () {
      expect(particleChooseOptions(0, 'は', const []), isNull);
      final options = particleChooseOptions(4, 'のに', const ['によって']);
      expect(options, isNotNull);
      expect(options!.contains('によって'), isFalse,
          reason: 'an accepted form is never a wrong option');
    });

    test('a twin counts as the probe it twins for transfer (D4 clause 5)', () {
      expect(transferKeyOf('say.p0'), 'p0');
      expect(transferKeyOf('choose.cloze'), 'cloze');
      expect(transferKeyOf('p0'), 'p0');
      expect(transferKeyOf(kWordSayCardId), kWordSayCardId);
      final pair = catalog.ofKind(ItemKind.pair).first;
      expect(transferProbesNeeded(pair), 2, reason: 'both directions, still');
    });
  });

  // The rule that consumes transferKeyOf, replayed over real grammar points: a say card
  // beside the practice item it twins is one sentence, so no point reaches Mastered on two
  // sentences however many cards asked them (D4 clause 5, plan 2026-11-06 Task 6).
  group('the mastery rule counts a say card as the sentence it twins', () {
    final grammar = catalog.ofKind(ItemKind.grammar).toList();
    // Four due clears on four days, the last 21 days after the third (D4 clauses 1 and 2).
    const days = [0, 2, 8, 29];

    ProbeDef probe(ItemDef item, String id) =>
        item.probes.firstWhere((p) => p.id == id);

    /// A due, review-sourced clear on [probe], with the template and production flag the
    /// catalog gives that card, so the template and production clauses read the real card.
    Attempt clear(ItemDef item, ProbeDef probe, int day) => Attempt(
          itemId: item.id,
          probeId: probe.id,
          template: probe.template,
          production: probe.production,
          selfGraded: probe.selfGraded,
          atUtc: DateTime.utc(2026, 1, 1, 12).add(Duration(days: day)),
          localDay: day,
          grade: Grade.clear,
          rating: kRatingGood,
          wasDue: true,
          source: Source.review,
          sessionId: 'twin-$day',
        );

    MasteryState replay(ItemDef item, List<String> probeIds) =>
        masteryFromAttempts(item, [
          for (var i = 0; i < probeIds.length; i++)
            clear(item, probe(item, probeIds[i]), days[i]),
        ]);

    test('every grammar point has the three practice items the fixtures use',
        () {
      expect(grammar, isNotEmpty);
      for (final item in grammar) {
        for (final id in ['p0', 'p1', 'p2']) {
          expect(item.probes.any((p) => p.id == id), isTrue,
              reason: '${item.id} has no $id');
          expect(item.probes.any((p) => p.id == sayCardId(id)), isTrue,
              reason: '${item.id} has no ${sayCardId(id)}');
        }
        // The say card is the second template and the production clear, so only the
        // transfer clause decides the fixtures below.
        expect(probe(item, 'p0').template, isNot(kSayCardTemplate));
        expect(probe(item, sayCardId('p0')).production, isTrue);
      }
    });

    test('one sentence asked both ways stays Learning', () {
      for (final item in grammar) {
        final s = replay(item, ['p0', 'say.p0', 'p0', 'say.p0']);
        expect(s.status, MasteryStatus.learning, reason: item.id);
        expect(s.clears.length, 4, reason: '${item.id}: all four clears count');
      }
    });

    test('two sentences asked both ways stay Learning, four ids or not', () {
      // Four different probe ids over two sentences: a rule that counted raw ids would
      // see four probes and master the point here.
      for (final item in grammar) {
        final s = replay(item, ['p0', 'say.p0', 'p1', 'say.p1']);
        expect(s.status, MasteryStatus.learning, reason: item.id);
        expect(s.clears.length, 4, reason: '${item.id}: all four clears count');
      }
    });

    test('a third sentence, with one of them a say card, is Mastered', () {
      for (final item in grammar) {
        expect(replay(item, ['p0', 'say.p0', 'p1', 'p2']).status,
            MasteryStatus.mastered,
            reason: item.id);
        // The say card alone as the third sentence counts as that sentence too.
        expect(replay(item, ['p0', 'p1', 'say.p2', 'p0']).status,
            MasteryStatus.mastered,
            reason: item.id);
      }
    });

    test('what remains after a say card on the same sentence does not move',
        () {
      final item = grammar.first;
      ClearRef ref(String id, int day) {
        final p = probe(item, id);
        return ClearRef(
            day: day,
            template: p.template,
            production: p.production,
            probeId: p.id);
      }

      MasteryState learning(List<ClearRef> clears) =>
          MasteryState.initial(item.id).copyWith(
              status: MasteryStatus.learning,
              clears: clears,
              lastScoredDay: clears.last.day);

      const twoMore = 'clears on 2 more different sentences';
      final afterP0 = remainingFor(item, learning([ref('p0', 0)]));
      expect(afterP0, contains(twoMore));
      final afterTwin =
          remainingFor(item, learning([ref('p0', 0), ref('say.p0', 2)]));
      expect(afterTwin, contains(twoMore),
          reason: 'say.p0 is the sentence p0 already cleared');
      final afterSecond =
          remainingFor(item, learning([ref('p0', 0), ref('p1', 2)]));
      expect(afterSecond, contains('clears on 1 more different sentence'));
      expect(afterSecond, isNot(contains(twoMore)));
    });
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
