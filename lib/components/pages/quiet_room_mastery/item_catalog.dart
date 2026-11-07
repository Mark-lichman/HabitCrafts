// The item catalog: every mastery item the record tracks, with a stable id and its probes
// (D1, D19). Built once per app run from the two lesson assets, `jp_grammar.json` (through
// `JpGrammarData`) and the word file `jp_lessons.json`. Nothing here is stored: the ids are
// the join key between the catalog, the attempt log and the scheduler, so they must never
// change for the same data.
//
// | kind        | id                         | probes                                       |
// |-------------|----------------------------|----------------------------------------------|
// | grammar     | `mari.L31.3`               | its practice items, a say card per item, then its examples (Say-it) |
// | particle    | `mari.particle.14`         | its cloze, a choose card over it, a say card over it |
// | word        | image stem, `L30_02`       | card recall, spoken recall, reading typed, a say card |
// | conjugation | `conj.<form>.g<group>`     | the verbs of that group that have the form, a say card per verb |
// | pair        | the catalog id             | both directions, a say card per direction    |
// | tableRow    | `ref.<table>.<row>`        | the cells of the row, irregular ones flagged, a say card per cell |
//
// The say card (plan 2026-11-06, Task 6, D3, D18, PIN-12) is scored by Azure against its
// answer's hiragana, under [kSayCardTemplate], and shows the prompt only, never the answer: a
// grammar point or a particle says the whole sentence from its prompt and English; a word from
// its picture and meaning; a conjugation from the verb and the form name; a pair from the other
// side; a table row from the number and the counter. A say card twins the probe whose sentence,
// verb, direction or cell it asks, `say.<id>` (a word's is `say`), so the transfer clause counts
// the two as one (`transferKeyOf`, mastery_rule.dart). A particle's choose card (`choose.cloze`)
// offers its cloze answer among other particles that cannot complete the sentence
// ([particleChooseOptions], PIN-3, PIN-7).
//
// Prerequisite level orders introductions: 0 for particles, conjugation ideas, pairs and table
// rows; 1 for the words of a lesson; 2 for the grammar of a lesson. A grammar point's `prereqs`
// are the conjugation ideas of the forms it uses, one per verb group.
//
// A probe is `scored` when an answer on it can count toward the four clears. A grammar
// point's examples are the Say-it sentences, which never count (D4), so they are probes for
// lookup and practice but not scored; `templateCount`, `probeCount`, `hasProductionProbe` and
// `modes` (type it, see it, say it: PIN-7) cover scored probes only.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../quiet_room_grammar/jp_study_kit.dart';
import 'attempt.dart';
import 'mastery_rule.dart';

/// The template of a grammar point's example sentence: the Say-it track, never scored (D4).
const String kSayItTemplate = 'say';

/// The template of the scored say card every kind has (plan 2026-11-06, Task 6, D18): a
/// spoken answer scored by Azure that counts, unlike [kSayItTemplate]. Its attempts carry the
/// session's source, never `Source.sayIt`.
const String kSayCardTemplate = 'sayCard';

/// The id of the say card that twins the probe [probeId] (`say.p0`); see `transferKeyOf`.
String sayCardId(String probeId) => 'say.$probeId';

/// The id of a word's one say card.
const String kWordSayCardId = 'say';

/// The id of a particle's choose card, which twins its cloze.
const String kParticleChooseId = 'choose.cloze';

/// The options a particle's choose card offers: 3, the answer once among them.
const int kParticleChooseOptions = 3;

/// The prompt with its blank (a run of ＿ or _) filled by [answer], as the text before, the
/// answer and the text after. A prompt with no blank reads as the answer alone.
(String, String, String) fillBlank(String prompt, String answer) {
  final m = RegExp(r'[＿_]+').firstMatch(prompt);
  if (m == null) return ('', answer, '');
  return (prompt.substring(0, m.start), answer, prompt.substring(m.end));
}

/// The whole sentence of a fill-in [prompt] with [answer] in its blank: what a say card hears.
String wholeSentence(String prompt, String answer) {
  final (before, filled, after) = fillBlank(prompt, answer);
  return '$before$filled$after';
}

/// The particles that complete a bare noun or a phrase ending in one (にとって after わたし),
/// and the ones that join a clause or follow の or な (のに after やくそくした). A particle's
/// choose card takes its wrong options from the other list only, so a wrong option cannot
/// complete the sentence (PIN-3, A4). A particle that fits both kinds of slot is in neither
/// list: として (〜たとして, "supposing"), でも, ながら (こどもながら) and ばかり (〜たばかり) are
/// never wrong options, though each still gets a choose card of its own.
const List<String> kNounSlotParticles = ['によって', 'にとって', 'について', 'しか'];
const List<String> kClauseSlotParticles = [
  'のに',
  'ので',
  'けれど',
  'ように',
  'ために',
  'とおりに',
  'まま',
];

/// The wrong-option list of each particle, by its cloze answer: the list of the other slot.
/// A particle missing here gets no choose card: the catalog never builds a card it cannot
/// show has one right option.
const Map<String, List<String>> kParticleWrongOptions = {
  'によって': kClauseSlotParticles,
  'として': kClauseSlotParticles,
  'にとって': kClauseSlotParticles,
  'について': kClauseSlotParticles,
  'でも': kClauseSlotParticles,
  'しか': kClauseSlotParticles,
  'ながら': kClauseSlotParticles,
  'ように': kNounSlotParticles,
  'ために': kNounSlotParticles,
  'のに': kNounSlotParticles,
  'ので': kNounSlotParticles,
  'けれど': kNounSlotParticles,
  'とおりに': kNounSlotParticles,
  'まま': kNounSlotParticles,
  'ばかり': kNounSlotParticles,
};

/// The options of the choose card for the particle at [index] whose cloze answer is [answer]
/// with [accepted] forms, or null when [kParticleWrongOptions] has no list for it. The wrong
/// options come from that list, never the answer or an accepted form, picked and placed by
/// [index], so the same data always builds the same card and the answer moves between places.
List<String>? particleChooseOptions(
    int index, String answer, List<String> accepted) {
  final pool = [
    for (final p in kParticleWrongOptions[answer] ?? const <String>[])
      if (p != answer && !accepted.contains(p)) p
  ];
  if (pool.length < kParticleChooseOptions - 1) return null;
  final wrong = [
    for (var i = 0; i < kParticleChooseOptions - 1; i++)
      pool[(index + i) % pool.length]
  ];
  final at = index % kParticleChooseOptions;
  return [...wrong.take(at), answer, ...wrong.skip(at)];
}

/// The templates of the self-graded drill probes. The drills screen writes its attempts with
/// these, so a drill and the catalog never name one template two ways.
const String kConjugateTemplate = 'conjugate';
const String kCellTemplate = 'cell';

/// A pair's two directions, each its own template and probe id: shown the intransitive verb,
/// recall the transitive one ([kPairToTransitive]), and the reverse.
const String kPairToTransitive = 'transitive';
const String kPairToIntransitive = 'intransitive';

/// The id of the conjugation idea for [form] in verb [group] (1, 2 or 3).
String conjugationItemId(String form, int group) => 'conj.$form.g$group';

/// The id of the reference table row [row] of table [tableId].
String tableRowItemId(String tableId, String row) => 'ref.$tableId.$row';

/// The pair ids, in the order of `grammar['pairs']`: the pairs carry no id in their own list,
/// so the catalog lists one `verb_pair` row per pair in the same order, titled
/// `intransitive / transitive`. Checked, so a reordered asset fails loudly rather than
/// shifting ids. Throws a [StateError] when the two lists do not line up.
List<String> pairItemIds(Map<String, dynamic> grammar) {
  final pairs = _maps(grammar['pairs']);
  final rows = [
    for (final c in _maps(grammar['catalog']))
      if (c['type'] == 'verb_pair') c
  ];
  if (rows.length != pairs.length) {
    throw StateError(
        'item catalog: ${pairs.length} pairs but ${rows.length} verb_pair rows');
  }
  final ids = <String>[];
  for (var i = 0; i < pairs.length; i++) {
    final title = _pairTitle(pairs[i]);
    if (rows[i]['title'] != title) {
      throw StateError(
          'item catalog: pair $i is "$title" but its catalog row is "${rows[i]['title']}"');
    }
    ids.add(rows[i]['id'] as String);
  }
  return ids;
}

String _pairTitle(Map<String, dynamic> p) =>
    '${_str(p['intransitive'])} / ${_str(p['transitive'])}';

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
    this.options = const [],
  });

  /// Unique within its item; the `probe` of an attempt.
  final String id;

  /// The question kind: choose, fill, say, cloze, card, spoken, typed, conjugate, a pair
  /// direction (`transitive`, `intransitive`), cell or the say card ([kSayCardTemplate]).
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

  /// The options of a choose card the catalog builds itself (a particle's); empty otherwise,
  /// where the host reads them from the lesson data.
  final List<String> options;
}

/// The say card that twins [base]: it shows [base]'s text, never the answer (PIN-12), and
/// Azure hears [answer], else [base]'s answer.
ProbeDef _sayCard(ProbeDef base, {String? answer}) => ProbeDef(
      id: sayCardId(base.id),
      template: kSayCardTemplate,
      text: base.text,
      answer: answer ?? base.answer,
      production: true,
    );

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

  /// The lesson a grammar point or a word belongs to, and the first Mari grammar lesson that
  /// teaches a particle (its `taught_in`); null for the lesson-free kinds and particles.
  final int? lesson;

  /// 0 particles, conjugation ideas, pairs and table rows; 1 words; 2 grammar.
  final int prereqLevel;

  /// A level-0 item that every learner gets, whatever lessons they tick: everything at level 0
  /// except a particle a Mari lesson teaches, which follows that lesson (operator ruling,
  /// 2026-11-05).
  bool get isFoundation =>
      prereqLevel == 0 && !(kind == ItemKind.particle && lesson != null);

  /// Ids of the items this one builds on.
  final List<String> prereqs;

  final List<ProbeDef> probes;

  Iterable<ProbeDef> get scoredProbes => probes.where((p) => p.scored);

  @override
  int get templateCount => scoredProbes.map((p) => p.template).toSet().length;

  @override
  bool get hasProductionProbe => scoredProbes.any((p) => p.production);

  /// Different sentences, verbs, directions or cells: a say card or a choose card counts as
  /// the probe it twins (`transferKeyOf`).
  @override
  int get probeCount =>
      scoredProbes.map((p) => transferKeyOf(p.id)).toSet().length;

  /// The modes of the scored probes (D18): type it, see it, say it. A template with no mode
  /// adds none.
  @override
  Set<ProbeMode> get modes => {
        for (final p in scoredProbes)
          if (modeOfTemplate(p.template) case final m?) m
      };
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
      final asked = [
        for (var i = 0; i < practice.length; i++)
          ProbeDef(
            id: 'p$i',
            template: _str(practice[i]['kind']),
            text: _str(practice[i]['prompt']),
            answer: _str(practice[i]['answer']),
            production: practice[i]['kind'] == 'fill',
          ),
      ];
      final probes = [
        ...asked,
        // Say the whole sentence from its prompt (and its English, which the host shows).
        for (final p in asked)
          _sayCard(p, answer: wholeSentence(p.text, p.answer)),
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

List<ItemDef> _particles(Map<String, dynamic> grammar) {
  final out = <ItemDef>[];
  final all = _maps(grammar['particles']);
  for (var i = 0; i < all.length; i++) {
    final p = all[i];
    final cloze = p['cloze'];
    if (cloze is! Map<String, dynamic>) continue;
    final asked = ProbeDef(
      id: 'cloze',
      template: 'cloze',
      text: _str(cloze['prompt']),
      answer: _str(cloze['answer']),
      production: true,
    );
    final options = particleChooseOptions(i, asked.answer,
        (cloze['accepted'] as List? ?? const []).cast<String>());
    out.add(ItemDef(
      id: p['id'] as String,
      kind: ItemKind.particle,
      title: _str(p['expression']),
      lesson: _firstLesson(p['taught_in']),
      prereqLevel: 0,
      probes: [
        asked,
        if (options != null)
          ProbeDef(
            id: kParticleChooseId,
            template: 'choose',
            text: asked.text,
            answer: asked.answer,
            options: options,
          ),
        _sayCard(asked, answer: wholeSentence(asked.text, asked.answer)),
      ],
    ));
  }
  return out;
}

/// The lowest lesson number in a particle's `taught_in`, or null when it names none.
int? _firstLesson(Object? taughtIn) {
  final ns = [
    if (taughtIn is List)
      for (final n in taughtIn)
        if (n is int) n
  ];
  return ns.isEmpty ? null : ns.reduce((a, b) => a < b ? a : b);
}

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
              // Say the word from its picture and meaning.
              ProbeDef(
                  id: kWordSayCardId,
                  template: kSayCardTemplate,
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
      final asked = [
        for (final v in verbs)
          if (v['group'] == group && _str(v[form]).isNotEmpty)
            ProbeDef(
              id: _str(v['dictionary']),
              template: kConjugateTemplate,
              text: _str(v['dictionary']),
              answer: _str(v[form]),
              production: true,
              selfGraded: true,
            ),
      ];
      // Say the form from the verb; the card names the form.
      final probes = [...asked, for (final p in asked) _sayCard(p)];
      if (probes.isEmpty) continue;
      out.add(ItemDef(
        id: conjugationItemId(form, group),
        kind: ItemKind.conjugation,
        title: '$form, group $group',
        prereqLevel: 0,
        probes: probes,
      ));
    }
  }
  return out;
}

/// One item per pair, with the ids from [pairItemIds].
List<ItemDef> _pairs(Map<String, dynamic> grammar) {
  final pairs = _maps(grammar['pairs']);
  final ids = pairItemIds(grammar);
  final out = <ItemDef>[];
  for (var i = 0; i < pairs.length; i++) {
    final p = pairs[i];
    // Shown the intransitive verb, give the transitive one, and the reverse.
    final asked = [
      ProbeDef(
          id: kPairToTransitive,
          template: kPairToTransitive,
          text: _str(p['intransitive']),
          answer: _str(p['transitive']),
          selfGraded: true),
      ProbeDef(
          id: kPairToIntransitive,
          template: kPairToIntransitive,
          text: _str(p['transitive']),
          answer: _str(p['intransitive']),
          selfGraded: true),
    ];
    out.add(ItemDef(
      id: ids[i],
      kind: ItemKind.pair,
      title: _pairTitle(p),
      prereqLevel: 0,
      // Say the partner from the other side.
      probes: [...asked, for (final a in asked) _sayCard(a)],
    ));
  }
  return out;
}

List<ItemDef> _tableRows(Map<String, dynamic> grammar) {
  final out = <ItemDef>[];
  for (final table in _maps(grammar['reference'])) {
    final cells = _maps(table['cells']);
    for (final row in (table['rows'] as List).cast<String>()) {
      final asked = [
        for (final c in cells)
          if (c['row'] == row)
            ProbeDef(
              id: _str(c['col']),
              template: kCellTemplate,
              text: '$row ${_str(c['col'])}',
              answer: _str(c['reading']),
              selfGraded: true,
              irregular: c['mark'] != 'regular',
            ),
      ];
      // Say the reading from the number and the counter.
      final probes = [...asked, for (final p in asked) _sayCard(p)];
      if (probes.isEmpty) continue;
      out.add(ItemDef(
        id: tableRowItemId(table['id'] as String, row),
        kind: ItemKind.tableRow,
        title: '${_str(table['title'])}: $row',
        prereqLevel: 0,
        probes: probes,
      ));
    }
  }
  return out;
}
