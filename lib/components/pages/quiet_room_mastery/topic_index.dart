// The topic index (plan 2026-11-02, Task 22, D1, D16, PIN-1): every way to look an idea up,
// over the item catalog and a snapshot of the study record. The Topics screen and the topic
// page (Task 23) read it; it writes nothing.
//
// A `Topic` is any set of items: a use, a verb form, a verb group, a reference table, the
// words of a lesson, or one of the record's sets (Due today, Shaky, Not yet known). It shows
// counts by state, "7 of 9 mastered · 1 shaky", never a bare percentage, and one pill by the
// roll-up of D16 ([rollUp]): Mastered when every item is Mastered, Shaky when any is Shaky,
// Learning when any has an attempt, New otherwise. An item's state is its own (PIN-1): the
// index reads `MasteryState`, never a lesson number.
//
// Search covers the catalog rows' titles, summaries and search terms, the words' readings and
// glosses, the verb form names and the counters. A hit is an item or a topic, ranked exact,
// then prefix, then contains, over text with case and spaces ignored; a gloss with several
// meanings ("watch, clock") matches each meaning exactly. On a tie a topic comes first, then
// catalog order.
//
// 🚨 Due today and Not yet known come from the schedule and the seeds, never from
// MasteryStatus (the hazard in jp_store.dart): an early hinted answer can make an item
// Learning with no schedule, and it is still not yet known.

import 'attempt.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'mastery_rule.dart';
import 'probe_widgets.dart' show conjugationFormLabel;
import 'romaji.dart';
import 'scheduler.dart';

/// The browse sets on the Topics screen, in display order.
enum BrowseSet {
  byUse,
  verbForms,
  verbGroups,
  countersAndTables,
  wordsByLesson,
  dueToday,
  shaky,
  notYetKnown,
}

/// The learner-facing name of a browse set.
String browseSetLabel(BrowseSet s) => switch (s) {
      BrowseSet.byUse => 'By use',
      BrowseSet.verbForms => 'Verb forms',
      BrowseSet.verbGroups => 'Verb groups',
      BrowseSet.countersAndTables => 'Counters and tables',
      BrowseSet.wordsByLesson => 'Words by lesson',
      BrowseSet.dueToday => 'Due today',
      BrowseSet.shaky => 'Shaky',
      BrowseSet.notYetKnown => 'Not yet known',
    };

/// The topic pill (D16 roll-up): Mastered when every item is Mastered, Shaky when any is
/// Shaky, Learning when any has an attempt, New otherwise. An empty topic is New.
MasteryStatus rollUp(Iterable<MasteryStatus> states) {
  var any = false, attempted = false, allMastered = true;
  for (final s in states) {
    any = true;
    if (s == MasteryStatus.shaky) return MasteryStatus.shaky;
    if (s != MasteryStatus.neu) attempted = true;
    if (s != MasteryStatus.mastered) allMastered = false;
  }
  if (any && allMastered) return MasteryStatus.mastered;
  return attempted ? MasteryStatus.learning : MasteryStatus.neu;
}

/// A topic's items counted by state.
class TopicCounts {
  const TopicCounts({
    this.neu = 0,
    this.learning = 0,
    this.mastered = 0,
    this.shaky = 0,
  });

  final int neu;
  final int learning;
  final int mastered;
  final int shaky;

  int get total => neu + learning + mastered + shaky;

  /// "7 of 9 mastered · 1 shaky · 1 learning": always with its denominator, never a
  /// percentage; a state with no item is left out.
  String get label => [
        '$mastered of $total mastered',
        if (shaky > 0) '$shaky shaky',
        if (learning > 0) '$learning learning',
        if (neu > 0) '$neu new',
      ].join(' · ');
}

/// Any set of items, with its counts and its pill.
class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.itemIds,
    required this.counts,
    required this.pill,
    this.subtitle,
  });

  /// Stable: `use.<id>`, `form.<form>`, `group.<n>`, `table.<id>`, `lesson.<n>.words`,
  /// `due`, `shaky`, `notYet`.
  final String id;
  final String title;
  final String? subtitle;

  /// Catalog order within the topic's own order (a use lists its rows in catalog order).
  final List<String> itemIds;
  final TopicCounts counts;
  final MasteryStatus pill;
}

/// One search result: an item or a topic.
class SearchHit {
  const SearchHit._(
      {this.itemId, this.topic, required this.title, required this.rank});

  /// The item found, or null for a topic.
  final String? itemId;

  /// The topic found, or null for an item.
  final Topic? topic;

  /// The row's title: the item's or the topic's.
  final String title;

  /// 0 exact, 1 prefix, 2 contains.
  final int rank;

  @override
  String toString() => 'SearchHit(${itemId ?? topic!.id} $rank)';
}

/// A topic before its counts: the record decides those.
class _TopicDef {
  _TopicDef(this.id, this.title, this.itemIds, {this.subtitle});

  final String id;
  final String title;
  final String? subtitle;
  final List<String> itemIds;
}

/// Text that a search matches, with the pieces that count as an exact match.
class _Field {
  _Field(String text) : norm = _norm(text) {
    for (final piece in text.split(RegExp(r'[,;/()（）、]'))) {
      final p = _norm(piece);
      if (p.isNotEmpty) pieces.add(p);
    }
  }

  final String norm;
  final Set<String> pieces = {};

  /// 0 exact, 1 prefix, 2 contains, null no match.
  int? rank(String q) {
    if (norm == q || pieces.contains(q)) return 0;
    if (norm.startsWith(q) || pieces.any((p) => p.startsWith(q))) return 1;
    if (norm.contains(q)) return 2;
    return null;
  }
}

/// Lower case with every space removed, so "Clock " and "clock", or "Nが できます" and
/// "Nができます", are one text.
String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s　]+'), '');

List<Map<String, dynamic>> _maps(Object? list) => [
      for (final m in (list as List? ?? const []))
        Map<String, dynamic>.from(m as Map)
    ];

List<String> _strings(Object? list) =>
    [for (final s in (list as List? ?? const [])) '$s'];

/// The index over [catalog] and one snapshot of the record.
class TopicIndex {
  TopicIndex({
    required this.catalog,
    required Map<String, dynamic> grammar,
    required this.today,
    Map<String, MasteryState> mastery = const {},
    Map<String, SrsState> srs = const {},
    Map<String, int> seedDue = const {},
  })  : _mastery = mastery,
        _srs = srs,
        _seedDue = seedDue {
    _build(grammar);
  }

  /// Reads the states, the schedules and the seeds from [store].
  static Future<TopicIndex> load({
    required JpStore store,
    required ItemCatalog catalog,
    required Map<String, dynamic> grammar,
    required int today,
  }) async {
    final seedDue = <String, int>{};
    for (final s in await store.seeds()) {
      final had = seedDue[s.itemId];
      if (had == null || s.dueDay < had) seedDue[s.itemId] = s.dueDay;
    }
    return TopicIndex(
      catalog: catalog,
      grammar: grammar,
      today: today,
      mastery: await store.allMastery(),
      srs: await store.allSrs(),
      seedDue: seedDue,
    );
  }

  final ItemCatalog catalog;

  /// The local day "Due today" is measured on.
  final int today;

  final Map<String, MasteryState> _mastery;
  final Map<String, SrsState> _srs;
  final Map<String, int> _seedDue;

  final List<_TopicDef> _uses = [];
  final List<_TopicDef> _forms = [];
  final List<_TopicDef> _groups = [];
  final List<_TopicDef> _tables = [];
  final List<_TopicDef> _lessons = [];
  final Map<String, _TopicDef> _byId = {};

  /// The search fields per item id, and per topic id.
  final Map<String, List<_Field>> _itemFields = {};
  final Map<String, List<_Field>> _topicFields = {};

  // --- the record ------------------------------------------------------------

  /// The item's mastery state; New when it has none.
  MasteryState stateOf(String itemId) =>
      _mastery[itemId] ?? MasteryState.initial(itemId);

  MasteryStatus statusOf(String itemId) => stateOf(itemId).status;

  /// The item's next review day: its schedule's, else its seeded day; null when neither.
  int? nextDue(String itemId) => _srs[itemId]?.dueDay ?? _seedDue[itemId];

  // --- topics ----------------------------------------------------------------

  /// [itemIds] as a topic with its counts and pill. Ids the catalog does not know are left
  /// out.
  Topic topic(String id, String title, Iterable<String> itemIds,
      {String? subtitle}) {
    final ids = [
      for (final i in itemIds)
        if (catalog.byId(i) != null) i
    ];
    var neu = 0, learning = 0, mastered = 0, shaky = 0;
    final states = [for (final i in ids) statusOf(i)];
    for (final s in states) {
      switch (s) {
        case MasteryStatus.neu:
          neu++;
        case MasteryStatus.learning:
          learning++;
        case MasteryStatus.mastered:
          mastered++;
        case MasteryStatus.shaky:
          shaky++;
      }
    }
    return Topic(
      id: id,
      title: title,
      subtitle: subtitle,
      itemIds: List.unmodifiable(ids),
      counts: TopicCounts(
          neu: neu, learning: learning, mastered: mastered, shaky: shaky),
      pill: rollUp(states),
    );
  }

  Topic _of(_TopicDef d) =>
      topic(d.id, d.title, d.itemIds, subtitle: d.subtitle);

  /// The topics of one browse set. The record's sets are one topic each.
  List<Topic> browse(BrowseSet set) => switch (set) {
        BrowseSet.byUse => [for (final d in _uses) _of(d)],
        BrowseSet.verbForms => [for (final d in _forms) _of(d)],
        BrowseSet.verbGroups => [for (final d in _groups) _of(d)],
        BrowseSet.countersAndTables => [for (final d in _tables) _of(d)],
        BrowseSet.wordsByLesson => [for (final d in _lessons) _of(d)],
        BrowseSet.dueToday => [
            topic('due', browseSetLabel(set), [
              for (final i in catalog.items)
                if ((nextDue(i.id) ?? today + 1) <= today) i.id
            ])
          ],
        BrowseSet.shaky => [
            topic('shaky', browseSetLabel(set), [
              for (final i in catalog.items)
                if (statusOf(i.id) == MasteryStatus.shaky) i.id
            ])
          ],
        BrowseSet.notYetKnown => [
            topic('notYet', browseSetLabel(set), [
              for (final i in catalog.items)
                if (_srs[i.id] == null && _seedDue[i.id] == null) i.id
            ])
          ],
      };

  /// The topic of use [useId] (`condition`), or null.
  Topic? use(String useId) => byId('use.$useId');

  /// A static topic by id (`use.reason`, `form.te`, `table.counters`), or null.
  Topic? byId(String topicId) {
    final d = _byId[topicId];
    return d == null ? null : _of(d);
  }

  /// The static topics [itemId] belongs to, for Related topics: its uses, its verb form and
  /// group, its table, its lesson's words.
  List<Topic> topicsOf(String itemId) => [
        for (final d in [
          ..._uses,
          ..._forms,
          ..._groups,
          ..._tables,
          ..._lessons
        ])
          if (d.itemIds.contains(itemId)) _of(d)
      ];

  // --- search ----------------------------------------------------------------

  /// Items and topics matching [query], best first. An empty query finds nothing.
  /// A romaji query also searches the hiragana it spells (#137), so "mimasu" finds みます.
  List<SearchHit> search(String query) {
    final q = _norm(query);
    if (q.isEmpty) return const [];
    final kana = romajiToHiragana(q);
    final queries = [q, if (kana != null && kana != q) kana];
    int? best(List<_Field> fields) {
      int? r;
      for (final f in fields) {
        for (final each in queries) {
          final got = f.rank(each);
          if (got != null && (r == null || got < r)) r = got;
        }
      }
      return r;
    }

    final hits = <(SearchHit, int)>[];
    var order = 0;
    for (final e in _topicFields.entries) {
      final r = best(e.value);
      if (r == null) continue;
      final t = _of(_byId[e.key]!);
      hits.add((SearchHit._(topic: t, title: t.title, rank: r), order++));
    }
    for (final item in catalog.items) {
      final r = best(_itemFields[item.id] ?? const []);
      if (r == null) continue;
      hits.add(
          (SearchHit._(itemId: item.id, title: item.title, rank: r), order++));
    }
    hits.sort((a, b) {
      final byRank = a.$1.rank.compareTo(b.$1.rank);
      return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
    });
    return [for (final h in hits) h.$1];
  }

  // --- building --------------------------------------------------------------

  void _addTopic(List<_TopicDef> list, _TopicDef d, Iterable<String> fields) {
    list.add(d);
    _byId[d.id] = d;
    _topicFields[d.id] = [
      for (final f in fields)
        if (f.trim().isNotEmpty) _Field(f)
    ];
  }

  void _addItemField(String itemId, String text) {
    if (text.trim().isEmpty || catalog.byId(itemId) == null) return;
    (_itemFields[itemId] ??= []).add(_Field(text));
  }

  void _build(Map<String, dynamic> grammar) {
    final rows = _maps(grammar['catalog']);
    final conj = Map<String, dynamic>.from(
        (grammar['conjugation'] as Map?) ?? const <String, dynamic>{});
    final forms = _strings(conj['forms']);

    // The items a catalog row stands for.
    List<String> itemsOfRow(Map<String, dynamic> row) {
      final id = row['id'] as String? ?? '';
      final open = Map<String, dynamic>.from((row['open'] as Map?) ?? const {});
      switch (row['type']) {
        case 'grammar_point' || 'particle' || 'verb_pair':
          return catalog.byId(id) != null ? [id] : const [];
        case 'conjugation':
          final form = open['form'] as String? ?? id.replaceFirst('conj.', '');
          return [
            for (final g in const [1, 2, 3])
              if (catalog.byId(conjugationItemId(form, g)) != null)
                conjugationItemId(form, g)
          ];
        case 'reference_table':
          final table = open['table'] as String?;
          if (table == null) return const [];
          return [
            for (final i in catalog.items)
              if (i.id.startsWith('ref.$table.')) i.id
          ];
        case 'vocabulary':
          final lesson = row['lesson'];
          return [
            for (final i in catalog.items)
              if (i.kind == ItemKind.word && i.lesson == lesson) i.id
          ];
        default:
          return const [];
      }
    }

    // By use: the uses in asset order, each listing its rows' items in catalog order.
    for (final u in _maps(grammar['uses'])) {
      final useId = u['id'] as String;
      final ids = <String>{
        for (final row in rows)
          if (_strings(row['uses']).contains(useId)) ...itemsOfRow(row)
      };
      _addTopic(
          _uses,
          _TopicDef('use.$useId', u['label'] as String? ?? useId, ids.toList()),
          [u['label'] as String? ?? '']);
    }

    // Verb forms: one topic per form, its conjugation ideas of the three groups.
    final formRows = {
      for (final row in rows)
        if (row['type'] == 'conjugation')
          (Map<String, dynamic>.from((row['open'] as Map?) ?? const {})['form']
              as String?): row
    };
    for (final form in forms) {
      final row = formRows[form];
      final title = row?['title'] as String? ?? conjugationFormLabel(form);
      _addTopic(
          _forms,
          _TopicDef('form.$form', title, [
            for (final g in const [1, 2, 3])
              if (catalog.byId(conjugationItemId(form, g)) != null)
                conjugationItemId(form, g)
          ]),
          [
            title,
            form,
            form.replaceAll('_', ' '),
            conjugationFormLabel(form),
            ..._strings(row?['search']),
          ]);
    }

    // Verb groups: each group's conjugation ideas, then the words of that group.
    final wordGroup = <String, int>{
      for (final w in _maps(grammar['words']))
        if (w['verbGroup'] is int) w['id'] as String: w['verbGroup'] as int
    };
    for (final g in const [1, 2, 3]) {
      _addTopic(
          _groups,
          _TopicDef('group.$g', 'Group $g verbs', [
            for (final form in forms)
              if (catalog.byId(conjugationItemId(form, g)) != null)
                conjugationItemId(form, g),
            for (final i in catalog.items)
              if (i.kind == ItemKind.word && wordGroup[i.id] == g) i.id
          ]),
          ['Group $g verbs', 'group $g']);
    }

    // Counters and tables: one topic per reference table; a counter is searchable by its
    // kanji, its reading and what it counts.
    final tableRows = {
      for (final row in rows)
        if (row['type'] == 'reference_table')
          (Map<String, dynamic>.from((row['open'] as Map?) ?? const {})['table']
              as String?): row
    };
    for (final table in _maps(grammar['reference'])) {
      final id = table['id'] as String;
      final row = tableRows[id];
      final columns = _maps(table['columns']);
      _addTopic(
          _tables,
          _TopicDef(
            'table.$id',
            table['title'] as String? ?? id,
            [
              for (final i in catalog.items)
                if (i.id.startsWith('ref.$id.')) i.id
            ],
            subtitle: row?['summary'] as String?,
          ),
          [
            table['title'] as String? ?? '',
            row?['title'] as String? ?? '',
            row?['summary'] as String? ?? '',
            ..._strings(row?['search']),
            for (final c in columns) ...[
              c['written'] as String? ?? '',
              c['kana'] as String? ?? '',
              c['gloss'] as String? ?? '',
            ],
          ]);
    }

    // Words by lesson.
    final lessons = <int>{
      for (final i in catalog.items)
        if (i.kind == ItemKind.word && i.lesson != null) i.lesson!
    }.toList()
      ..sort();
    for (final n in lessons) {
      final row = rows.firstWhere(
          (r) => r['type'] == 'vocabulary' && r['lesson'] == n,
          orElse: () => const {});
      _addTopic(
          _lessons,
          _TopicDef(
            'lesson.$n.words',
            '第$n課 words',
            [
              for (final i in catalog.items)
                if (i.kind == ItemKind.word && i.lesson == n) i.id
            ],
            subtitle: row['summary'] as String?,
          ),
          ['第$n課 words', '第$n課', 'lesson $n', row['title'] as String? ?? '']);
    }

    // The items' own fields: the title (pattern, reading, expression, pair), the catalog
    // row's summary and search terms, and a word's gloss.
    for (final item in catalog.items) {
      _addItemField(item.id, item.title);
    }
    for (final row in rows) {
      final type = row['type'];
      if (type != 'grammar_point' &&
          type != 'particle' &&
          type != 'verb_pair') {
        continue;
      }
      final id = row['id'] as String? ?? '';
      _addItemField(id, row['title'] as String? ?? '');
      _addItemField(id, row['summary'] as String? ?? '');
      for (final s in _strings(row['search'])) {
        _addItemField(id, s);
      }
    }
    final glosses = {
      for (final w in _maps(grammar['words']))
        w['id'] as String: w['gloss'] as String? ?? ''
    };
    for (final w in catalog.ofKind(ItemKind.word)) {
      final card = w.probes.where((p) => p.template == 'card').firstOrNull;
      _addItemField(w.id, glosses[w.id] ?? card?.text ?? '');
    }
  }
}
