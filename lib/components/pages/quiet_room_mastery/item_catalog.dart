// The item catalog: every mastery item the record tracks, with a stable id and its probes
// (D1, D19). Built once per app run from the two lesson assets, `jp_grammar.json` (through
// `JpGrammarData`) and the word file `jp_lessons.json`. Nothing here is stored: the ids are
// the join key between the catalog, the attempt log and the scheduler, so they must never
// change for the same data.
//
// | kind        | id                         | probes                                       |
// |-------------|----------------------------|----------------------------------------------|
// | grammar     | `mari.L31.3`               | its practice items, then its examples (Say-it) |
// | particle    | `mari.particle.14`         | its cloze                                    |
// | word        | image stem, `L30_02`       | card recall, spoken recall, reading typed    |
// | conjugation | `conj.<form>.g<group>`     | the verbs of that group that have the form   |
// | pair        | the catalog id             | both directions                              |
// | tableRow    | `ref.<table>.<row>`        | the cells of the row, irregular ones flagged |
//
// Prerequisite level orders introductions: 0 for particles, conjugation ideas, pairs and table
// rows; 1 for the words of a lesson; 2 for the grammar of a lesson. A grammar point's `prereqs`
// are the conjugation ideas of the forms it uses, one per verb group.
//
// A probe is `scored` when an answer on it can count toward the four clears. A grammar
// point's examples are the Say-it sentences, which never count (D4), so they are probes for
// lookup and practice but not scored; `templateCount`, `probeCount` and `hasProductionProbe`
// cover scored probes only.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../quiet_room_grammar/jp_study_kit.dart';
import 'attempt.dart';
import 'mastery_rule.dart';

/// The template of a grammar point's example sentence: the Say-it track, never scored (D4).
const String kSayItTemplate = 'say';

/// One question over an item.
class ProbeDef {
  const ProbeDef({
    required this.id,
    required this.template,
    required this.text,
    required this.answer,
    this.production = false,
    this.selfGraded = false,
    this.scored = true,
    this.irregular = false,
  });

  /// Unique within its item; the `probe` of an attempt.
  final String id;

  /// The question kind: choose, fill, say, cloze, card, spoken, typed, conjugate, a pair
  /// direction (`transitive`, `intransitive`) or cell.
  final String template;

  /// What the learner sees: the sentence, the reading, the verb or the cell's column.
  final String text;

  /// The expected answer.
  final String answer;

  /// Whether the learner produces the answer (typed, spoken, conjugate) rather than picks it.
  final bool production;

  /// Whether the probe has no machine check, so the learner grades it after the reveal
  /// (PIN-13).
  final bool selfGraded;

  /// Whether an answer on this probe can count toward the four clears.
  final bool scored;

  /// A table cell whose reading is not the regular one (a sound change or a special reading).
  final bool irregular;
}

/// One mastery item.
class ItemDef implements ItemDefLike {
  ItemDef({
    required this.id,
    required this.kind,
    required this.title,
    required this.probes,
    required this.prereqLevel,
    this.lesson,
    this.prereqs = const [],
  });

  @override
  final String id;
  @override
  final ItemKind kind;

  /// The display name: the pattern, the reading, the expression, the form or the row.
  final String title;

  /// The lesson a grammar point or a word belongs to; null for the lesson-free kinds.
  final int? lesson;

  /// 0 particles, conjugation ideas, pairs and table rows; 1 words; 2 grammar.
  final int prereqLevel;

  /// Ids of the items this one builds on.
  final List<String> prereqs;

  final List<ProbeDef> probes;

  Iterable<ProbeDef> get scoredProbes => probes.where((p) => p.scored);

  @override
  int get templateCount => scoredProbes.map((p) => p.template).toSet().length;

  @override
  bool get hasProductionProbe => scoredProbes.any((p) => p.production);

  @override
  int get probeCount => scoredProbes.length;
}

/// Every mastery item, in a stable order: grammar, particles, words, conjugation ideas, pairs,
/// table rows, each in asset order.
class ItemCatalog {
  ItemCatalog._(this.items) : _byId = {for (final i in items) i.id: i} {
    if (_byId.length != items.length) {
      throw StateError('item catalog: duplicate item ids');
    }
  }

  final List<ItemDef> items;
  final Map<String, ItemDef> _byId;

  static Future<ItemCatalog>? _loaded;

  /// Loaded once per app run.
  static Future<ItemCatalog> load() => _loaded ??= () async {
        final grammar = await JpGrammarData.load();
        final raw =
            await rootBundle.loadString('assets/lessons/jp_lessons.json');
        return ItemCatalog.fromDocs(
            grammar, json.decode(raw) as Map<String, dynamic>);
      }();

  ItemDef? byId(String id) => _byId[id];

  List<ItemDef> ofKind(ItemKind kind) =>
      items.where((i) => i.kind == kind).toList();

  /// Builds the catalog from the decoded `jp_grammar.json` and `jp_lessons.json`.
  factory ItemCatalog.fromDocs(
      Map<String, dynamic> grammar, Map<String, dynamic> lessons) {
    final conj = grammar['conjugation'] as Map<String, dynamic>;
    final forms = (conj['forms'] as List).cast<String>();
    final verbs = (conj['verbs'] as List).cast<Map<String, dynamic>>();
    final ideas = _conjugationIdeas(forms, verbs);
    final ideaIds = {for (final i in ideas) i.id};
    return ItemCatalog._([
      ..._grammarPoints(grammar, ideaIds),
      ..._particles(grammar),
      ..._words(lessons),
      ...ideas,
      ..._pairs(grammar),
      ..._tableRows(grammar),
    ]);
  }
}

List<Map<String, dynamic>> _maps(Object? list) =>
    (list as List? ?? const []).cast<Map<String, dynamic>>();

String _str(Object? v) => v as String? ?? '';

List<ItemDef> _grammarPoints(
    Map<String, dynamic> grammar, Set<String> conjugationIds) {
  final out = <ItemDef>[];
  for (final lesson in _maps(grammar['grammar'])) {
    for (final point in _maps(lesson['points'])) {
      final practice = _maps(point['practice']);
      final examples = _maps(point['examples']);
      final probes = [
        for (var i = 0; i < practice.length; i++)
          ProbeDef(
            id: 'p$i',
            template: _str(practice[i]['kind']),
            text: _str(practice[i]['prompt']),
            answer: _str(practice[i]['answer']),
            production: practice[i]['kind'] == 'fill',
          ),
        for (var i = 0; i < examples.length; i++)
          ProbeDef(
            id: 'ex$i',
            template: kSayItTemplate,
            text: _str(examples[i]['jp']),
            answer: _str(examples[i]['jp']),
            production: true,
            selfGraded: true,
            scored: false,
          ),
      ];
      // A point names the forms it uses (`conj.te`); the items are per verb group.
      final prereqs = [
        for (final form
            in (point['prereqs'] as List? ?? const []).cast<String>())
          for (final g in const [1, 2, 3])
            if (conjugationIds.contains('$form.g$g')) '$form.g$g'
      ];
      out.add(ItemDef(
        id: point['id'] as String,
        kind: ItemKind.grammar,
        title: _str(point['pattern']),
        lesson: lesson['lesson'] as int?,
        prereqLevel: 2,
        prereqs: prereqs,
        probes: probes,
      ));
    }
  }
  return out;
}

List<ItemDef> _particles(Map<String, dynamic> grammar) => [
      for (final p in _maps(grammar['particles']))
        if (p['cloze'] is Map<String, dynamic>)
          ItemDef(
            id: p['id'] as String,
            kind: ItemKind.particle,
            title: _str(p['expression']),
            prereqLevel: 0,
            probes: [
              ProbeDef(
                id: 'cloze',
                template: 'cloze',
                text: _str(p['cloze']['prompt']),
                answer: _str(p['cloze']['answer']),
                production: true,
              ),
            ],
          ),
    ];

List<ItemDef> _words(Map<String, dynamic> lessons) => [
      for (final lesson in _maps(lessons['lessons']))
        for (final w in _maps(lesson['items']))
          ItemDef(
            id: _imageStem(w),
            kind: ItemKind.word,
            title: _str(w['kana']),
            lesson: lesson['lesson'] as int?,
            prereqLevel: 1,
            probes: [
              // The picture and meaning, then the learner reveals and grades (PIN-13).
              ProbeDef(
                  id: 'card',
                  template: 'card',
                  text: _str(w['gloss']),
                  answer: _str(w['kana']),
                  selfGraded: true),
              ProbeDef(
                  id: 'spoken',
                  template: 'spoken',
                  text: _str(w['gloss']),
                  answer: _str(w['kana']),
                  production: true),
              ProbeDef(
                  id: 'typed',
                  template: 'typed',
                  text: _str(w['gloss']),
                  answer: _str(w['kana']),
                  production: true),
            ],
          ),
    ];

/// The word id is its image stem (D19): `assets/lessons/img/L30_02.webp` is `L30_02`.
String _imageStem(Map<String, dynamic> w) {
  final image = w['image'] as String?;
  if (image == null || image.isEmpty) return w['id'] as String;
  final file = image.split('/').last;
  final dot = file.lastIndexOf('.');
  return dot > 0 ? file.substring(0, dot) : file;
}

List<ItemDef> _conjugationIdeas(
    List<String> forms, List<Map<String, dynamic>> verbs) {
  final out = <ItemDef>[];
  for (final form in forms) {
    for (final group in const [1, 2, 3]) {
      final probes = [
        for (final v in verbs)
          if (v['group'] == group && _str(v[form]).isNotEmpty)
            ProbeDef(
              id: _str(v['dictionary']),
              template: 'conjugate',
              text: _str(v['dictionary']),
              answer: _str(v[form]),
              production: true,
              selfGraded: true,
            ),
      ];
      if (probes.isEmpty) continue;
      out.add(ItemDef(
        id: 'conj.$form.g$group',
        kind: ItemKind.conjugation,
        title: '$form, group $group',
        prereqLevel: 0,
        probes: probes,
      ));
    }
  }
  return out;
}

/// The pairs carry no id in their own list; the catalog lists one `verb_pair` row per pair in
/// the same order, titled `intransitive / transitive`. Checked, so a reordered asset fails
/// loudly rather than shifting ids.
List<ItemDef> _pairs(Map<String, dynamic> grammar) {
  final pairs = _maps(grammar['pairs']);
  final rows = [
    for (final c in _maps(grammar['catalog']))
      if (c['type'] == 'verb_pair') c
  ];
  if (rows.length != pairs.length) {
    throw StateError(
        'item catalog: ${pairs.length} pairs but ${rows.length} verb_pair rows');
  }
  final out = <ItemDef>[];
  for (var i = 0; i < pairs.length; i++) {
    final p = pairs[i];
    final title = '${_str(p['intransitive'])} / ${_str(p['transitive'])}';
    if (rows[i]['title'] != title) {
      throw StateError(
          'item catalog: pair $i is "$title" but its catalog row is "${rows[i]['title']}"');
    }
    out.add(ItemDef(
      id: rows[i]['id'] as String,
      kind: ItemKind.pair,
      title: title,
      prereqLevel: 0,
      probes: [
        // Shown the intransitive verb, give the transitive one, and the reverse.
        ProbeDef(
            id: 'transitive',
            template: 'transitive',
            text: _str(p['intransitive']),
            answer: _str(p['transitive']),
            selfGraded: true),
        ProbeDef(
            id: 'intransitive',
            template: 'intransitive',
            text: _str(p['transitive']),
            answer: _str(p['intransitive']),
            selfGraded: true),
      ],
    ));
  }
  return out;
}

List<ItemDef> _tableRows(Map<String, dynamic> grammar) {
  final out = <ItemDef>[];
  for (final table in _maps(grammar['reference'])) {
    final cells = _maps(table['cells']);
    for (final row in (table['rows'] as List).cast<String>()) {
      final probes = [
        for (final c in cells)
          if (c['row'] == row)
            ProbeDef(
              id: _str(c['col']),
              template: 'cell',
              text: '$row ${_str(c['col'])}',
              answer: _str(c['reading']),
              selfGraded: true,
              irregular: c['mark'] != 'regular',
            ),
      ];
      if (probes.isEmpty) continue;
      out.add(ItemDef(
        id: 'ref.${table['id']}.$row',
        kind: ItemKind.tableRow,
        title: '${_str(table['title'])}: $row',
        prereqLevel: 0,
        probes: probes,
      ));
    }
  }
  return out;
}
