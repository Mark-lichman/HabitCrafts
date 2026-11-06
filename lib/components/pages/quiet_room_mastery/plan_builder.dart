// The daily plan builder (D5, D6, D9, D10, D11, D21, D26, D27). `buildPlan` reads the study
// record and returns one local day's `DayPlan`: ordered `QueueEntry` rows in sections, plus the
// offers the end card may show. It writes nothing; the caller serialises the plan into the
// day's `DayRecord` (jp_store.dart).
//
// Sections, in the order the session shows them:
//   * Warm-up (return mode only, PIN-9): 5 to 8 due stateful items that are level 0 or high
//     reuse, with retrievability 0.6 to 0.85, most likely recalled first.
//   * Repair (PIN-11): yesterday's wrongs. Today's wrongs come back at the end of the section
//     they were answered in, through `DayPlan.afterWrong`, paid from the repair slot the
//     budget holds back.
//   * Due (D26): stateful items by ascending retrievability, ties by prerequisite level then
//     lapses (most lapses first); then seeded items with no FSRS state by seed due day and
//     lesson order; interleaved so no more than two in a row share a kind or a lesson.
//   * Keep-sharp (PIN-10, D27): in the first session on or after the local day that is a
//     Monday, the 10 Mastered items with the lowest retrievability that are not already due.
//     A stored plan of the week counts only when its record shows an answer (operator ruling
//     ASK-7), so an unanswered plan leaves keep-sharp to the next one. In return mode it
//     waits until the backlog is under the gate.
//   * New (PIN-6): 8 a day in lesson order with prerequisites (`newIntakeOrder`).
//
// The budget (PIN-5, A2): a 15-minute target and a 20-minute ceiling, priced with per-kind
// answer estimates. Entries fill in this order: warm-up, repairs, keep-sharp, due, then New;
// nothing fills past the ceiling less the repair slot. Keep-sharp is priced before Due so a
// large backlog cannot starve the weekly set (End state 4); the session still shows it after
// Due. Every entry is one item, and each item appears once.
//
// 🚨 NEW INTAKE IS "NO SrsState AND NO SEED", NEVER MasteryStatus.neu (see the hazard in
// jp_store.dart): an early hinted answer can make an item Learning with no schedule.
//
// The gate is 1.5 times the target, measured on the backlog before the session (every due
// item plus yesterday's wrongs). New is skipped when the backlog is above the gate, when two or
// more days were missed, or when the target is already spent. `stretchOffer` and
// `catchUpOffer` are the end card's two opt-in offers; neither adds anything on its own.

import 'dart:convert';

import 'attempt.dart';
import 'fsrs.dart';
import 'item_catalog.dart';
import 'jp_store.dart';
import 'local_day.dart';
import 'mastery_rule.dart';
import 'scheduler.dart';

/// The daily target and ceiling, in seconds (D5, PIN-5).
const int kTargetSeconds = 15 * 60;
const int kCeilingSeconds = 20 * 60;

/// The estimated seconds per answer by kind, verdict included (A2). Retuned by hand from the
/// debug page's measured medians once 50 samples per kind exist.
const Map<ItemKind, int> kCostSeconds = {
  ItemKind.word: 10,
  ItemKind.conjugation: 12,
  ItemKind.pair: 15,
  ItemKind.tableRow: 15,
  ItemKind.grammar: 25,
  ItemKind.particle: 25,
};

/// Seconds held back under the ceiling for today's wrongs, re-asked in the session (PIN-11).
const int kRepairSlotSeconds = 90;

/// New items a day, and the opt-in stretch on top (D6, PIN-6).
const int kNewPerDay = 8;
const int kStretchNew = 4;

/// The "Catch up: 10 more" block past the ceiling (D21, PIN-12).
const int kCatchUpBlock = 10;

/// The weekly keep-sharp set size (D10, PIN-10).
const int kKeepSharpCount = 10;

/// The gate: the backlog before the session, as a multiple of the target.
const double kGateFactor = 1.5;

/// Missed days that put the plan in return mode (D9, PIN-9).
const int kReturnModeDaysMissed = 2;

/// The return-mode warm-up: its size and its retrievability window (D9).
const int kWarmUpMin = 5;
const int kWarmUpMax = 8;
const double kWarmUpLowR = 0.6;
const double kWarmUpHighR = 0.85;

/// In return mode, stateful items under this retrievability are capped at
/// 1 / [kLowRCapDivisor] of the plan (D9, D26).
const double kLowRetrievability = 0.5;
const int kLowRCapDivisor = 3;

/// Level-0 items (particles, forms, pairs, table rows) sprinkled first into a day's New.
const int kFoundationNewPerDay = 2;

/// An item named as a prerequisite by at least this many catalog items is "high reuse".
const int kHighReusePrereqCount = 3;

/// The budget one plan is built against. Tests and the simulator pass smaller ones.
class PlanBudget {
  const PlanBudget({
    this.targetSeconds = kTargetSeconds,
    this.ceilingSeconds = kCeilingSeconds,
    this.costSeconds = kCostSeconds,
    this.repairSlotSeconds = kRepairSlotSeconds,
    this.newPerDay = kNewPerDay,
  });

  static const PlanBudget standard = PlanBudget();

  final int targetSeconds;
  final int ceilingSeconds;
  final Map<ItemKind, int> costSeconds;
  final int repairSlotSeconds;
  final int newPerDay;

  int costOf(ItemKind kind) => costSeconds[kind] ?? 15;

  /// The backlog above which New is skipped and the catch-up can be offered.
  int get gateSeconds => (targetSeconds * kGateFactor).round();

  /// The most a plan fills to: the ceiling less the repair slot.
  int get fillSeconds => ceilingSeconds - repairSlotSeconds;
}

/// The plan's sections, in display order. `newItems` because `new` is a keyword.
enum PlanSection { warmUp, repair, due, keepSharp, newItems }

/// Why New is empty today.
enum NewSkip { none, daysMissed, backlog, targetSpent }

/// One row of the plan: one item, asked once (unless re-asked or requeued).
class QueueEntry {
  const QueueEntry({
    required this.itemId,
    required this.kind,
    required this.section,
    required this.costSeconds,
    required this.wasDue,
    this.seeded = false,
    this.lesson,
    this.retrievability,
    this.requeued = false,
    this.reask = false,
  });

  final String itemId;
  final ItemKind kind;
  final PlanSection section;
  final int costSeconds;

  /// Whether an answer on this entry is written as due: the item's scheduled day had arrived
  /// when the plan was built, or the entry is a New or stretch introduction, which is the
  /// item's scheduled first day (operator ruling ASK-6), or false on a same-session re-ask,
  /// which the wrong before it moved to tomorrow (D11). The session copies it onto the attempt.
  final bool wasDue;

  /// A seeded item with no FSRS state yet (D26).
  final bool seeded;
  final int? lesson;

  /// The predicted recall when the plan was built; null with no FSRS state.
  final double? retrievability;

  /// Moved to the end of its section once after an unscored answer. Set on the entry that was
  /// skipped, never on a copy of it: [DayPlan.afterWrong] clears it on the re-ask.
  final bool requeued;

  /// A same-session re-ask of a wrong answer (PIN-11), at the end of its section.
  final bool reask;

  /// The attempt source an answer on this entry is written with. A re-ask is a review even in
  /// Keep-sharp, as it was when re-asks sat in Repair: the wrong before it was the keep-sharp
  /// answer.
  Source get source => section == PlanSection.keepSharp && !reask
      ? Source.keepSharp
      : Source.review;

  QueueEntry copyWith(
          {PlanSection? section, bool? wasDue, bool? requeued, bool? reask}) =>
      QueueEntry(
        itemId: itemId,
        kind: kind,
        section: section ?? this.section,
        costSeconds: costSeconds,
        wasDue: wasDue ?? this.wasDue,
        seeded: seeded,
        lesson: lesson,
        retrievability: retrievability,
        requeued: requeued ?? this.requeued,
        reask: reask ?? this.reask,
      );

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'kind': kind.name,
        'section': section.name,
        'costSeconds': costSeconds,
        'wasDue': wasDue,
        'seeded': seeded,
        'lesson': lesson,
        'retrievability': retrievability,
        'requeued': requeued,
        'reask': reask,
      };

  factory QueueEntry.fromJson(Map<String, dynamic> j) => QueueEntry(
        itemId: j['itemId'] as String,
        kind: ItemKind.values.byName(j['kind'] as String),
        section: PlanSection.values.byName(j['section'] as String),
        costSeconds: j['costSeconds'] as int,
        wasDue: j['wasDue'] as bool,
        seeded: (j['seeded'] as bool?) ?? false,
        lesson: j['lesson'] as int?,
        retrievability: (j['retrievability'] as num?)?.toDouble(),
        requeued: (j['requeued'] as bool?) ?? false,
        reask: (j['reask'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is QueueEntry &&
      other.itemId == itemId &&
      other.kind == kind &&
      other.section == section &&
      other.costSeconds == costSeconds &&
      other.wasDue == wasDue &&
      other.seeded == seeded &&
      other.lesson == lesson &&
      other.retrievability == retrievability &&
      other.requeued == requeued &&
      other.reask == reask;

  @override
  int get hashCode => Object.hash(itemId, kind, section, costSeconds, wasDue,
      seeded, lesson, retrievability, requeued, reask);

  @override
  String toString() => 'QueueEntry($itemId ${section.name}'
      '${retrievability == null ? '' : ' R ${retrievability!.toStringAsFixed(2)}'})';
}

/// One local day's plan.
class DayPlan {
  const DayPlan({
    required this.day,
    required this.builtAtUtc,
    required this.entries,
    required this.daysMissed,
    required this.backlogSeconds,
    required this.targetSeconds,
    required this.ceilingSeconds,
    required this.gateSeconds,
    required this.repairSlotSeconds,
    required this.newSkip,
    required this.keepSharpRan,
    required this.dueLeft,
    required this.stretchOffer,
    this.stretchEntries = const [],
    required this.catchUpOffer,
    this.catchUpEntries = const [],
  });

  final int day;
  final DateTime builtAtUtc;

  /// The session's rows, in order.
  final List<QueueEntry> entries;
  final int daysMissed;

  /// The estimated cost of every due item and yesterday's wrongs before the session.
  final int backlogSeconds;
  final int targetSeconds;
  final int ceilingSeconds;
  final int gateSeconds;
  final int repairSlotSeconds;
  final NewSkip newSkip;

  /// Whether this plan ran the weekly keep-sharp step (D27).
  final bool keepSharpRan;

  /// Due items and repairs left out of the plan, due again tomorrow.
  final int dueLeft;

  /// The "4 more new" offer (PIN-6) and the items it would add.
  final bool stretchOffer;
  final List<QueueEntry> stretchEntries;

  /// The "Catch up: 10 more" offer past the ceiling (PIN-12) and the due items it would add.
  final bool catchUpOffer;
  final List<QueueEntry> catchUpEntries;

  bool get returnMode => daysMissed >= kReturnModeDaysMissed;

  /// Whether the backlog before the session was at or under the gate.
  bool get gateHeld => backlogSeconds <= gateSeconds;

  /// The estimated cost of the planned entries.
  int get plannedSeconds => entries.fold(0, (sum, e) => sum + e.costSeconds);

  List<QueueEntry> section(PlanSection s) => [
        for (final e in entries)
          if (e.section == s) e
      ];

  /// Entries per section, for the Today screen's counts (D20).
  Map<PlanSection, int> get counts => {
        for (final s in PlanSection.values) s: section(s).length,
      };

  DayPlan _withEntries(List<QueueEntry> next) => DayPlan(
        day: day,
        builtAtUtc: builtAtUtc,
        entries: List.unmodifiable(next),
        daysMissed: daysMissed,
        backlogSeconds: backlogSeconds,
        targetSeconds: targetSeconds,
        ceilingSeconds: ceilingSeconds,
        gateSeconds: gateSeconds,
        repairSlotSeconds: repairSlotSeconds,
        newSkip: newSkip,
        keepSharpRan: keepSharpRan,
        dueLeft: dueLeft,
        stretchOffer: stretchOffer,
        stretchEntries: stretchEntries,
        catchUpOffer: catchUpOffer,
        catchUpEntries: catchUpEntries,
      );

  /// The index after the last entry of [section] in [list], or [from] when none sits at or
  /// after it.
  static int _sectionEnd(List<QueueEntry> list, PlanSection section, int from) {
    final last = list.lastIndexWhere((e) => e.section == section);
    return last < from ? from : last + 1;
  }

  /// The plan after the entry at [index] was answered unscored: the entry moves to the end of
  /// its section, after any re-ask there, once. An entry already requeued stays where it is.
  DayPlan afterUnscored(int index) {
    final entry = entries[index];
    if (entry.requeued) return this;
    final next = [...entries]..removeAt(index);
    next.insert(_sectionEnd(next, entry.section, index),
        entry.copyWith(requeued: true));
    return _withEntries(next);
  }

  /// The plan after the entry at [index] was answered wrong: a re-ask of the item goes to the
  /// end of the section it was answered in (Repair, Due, Keep-sharp, New), after every entry
  /// and re-ask already there (operator ruling 2026-11-05, PIN-11). The re-ask is not due:
  /// the wrong scheduled the item Again for tomorrow at the earliest, so its clear starts no
  /// run of counting clears (End state 2). A re-ask is not re-asked again. The re-ask starts
  /// unrequeued, whatever its source: `requeued` means the entry itself was skipped once, and
  /// the session's resume estimate counts each such entry's skip on that.
  DayPlan afterWrong(int index) {
    final entry = entries[index];
    if (entry.reask) return this;
    final next = [...entries]..insert(
        _sectionEnd(entries, entry.section, index + 1),
        entry.copyWith(wasDue: false, requeued: false, reask: true));
    return _withEntries(next);
  }

  Map<String, dynamic> toJson() => {
        'day': day,
        'builtAtUtc': builtAtUtc.toUtc().toIso8601String(),
        'entries': [for (final e in entries) e.toJson()],
        'daysMissed': daysMissed,
        'backlogSeconds': backlogSeconds,
        'targetSeconds': targetSeconds,
        'ceilingSeconds': ceilingSeconds,
        'gateSeconds': gateSeconds,
        'repairSlotSeconds': repairSlotSeconds,
        'newSkip': newSkip.name,
        'keepSharpRan': keepSharpRan,
        'dueLeft': dueLeft,
        'stretchOffer': stretchOffer,
        'stretchEntries': [for (final e in stretchEntries) e.toJson()],
        'catchUpOffer': catchUpOffer,
        'catchUpEntries': [for (final e in catchUpEntries) e.toJson()],
      };

  static List<QueueEntry> _entries(Object? list) => [
        for (final e in (list as List? ?? const []))
          QueueEntry.fromJson(Map<String, dynamic>.from(e as Map)),
      ];

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
        day: j['day'] as int,
        builtAtUtc: DateTime.parse(j['builtAtUtc'] as String).toUtc(),
        entries: List.unmodifiable(_entries(j['entries'])),
        daysMissed: j['daysMissed'] as int,
        backlogSeconds: j['backlogSeconds'] as int,
        targetSeconds: j['targetSeconds'] as int,
        ceilingSeconds: j['ceilingSeconds'] as int,
        gateSeconds: j['gateSeconds'] as int,
        repairSlotSeconds: j['repairSlotSeconds'] as int,
        newSkip: NewSkip.values.byName(j['newSkip'] as String),
        keepSharpRan: j['keepSharpRan'] as bool,
        dueLeft: j['dueLeft'] as int,
        stretchOffer: j['stretchOffer'] as bool,
        stretchEntries: _entries(j['stretchEntries']),
        catchUpOffer: j['catchUpOffer'] as bool,
        catchUpEntries: _entries(j['catchUpEntries']),
      );

  /// The JSON a `DayRecord.plan` holds.
  String encode() => json.encode(toJson());

  static DayPlan decode(String plan) =>
      DayPlan.fromJson(json.decode(plan) as Map<String, dynamic>);
}

/// The local day of the Monday that starts [day]'s week.
int weekStartDay(int day) => day - (dateOfDay(day).weekday - DateTime.monday);

/// Whether a plan built on a day from this week's Monday up to the day before [day] ran
/// keep-sharp (D27). A plan counts only when its record shows an answer (operator ruling
/// ASK-7, the ASK-5 test): an unanswered plan leaves keep-sharp to the next plan that week.
/// A record that does not decode as a plan is ignored.
Future<bool> keepSharpRanThisWeek(JpStore store, int day) async {
  for (var d = weekStartDay(day); d < day; d++) {
    final record = await store.day(d);
    if (record == null || !record.answered) continue;
    try {
      if (DayPlan.decode(record.plan).keepSharpRan) return true;
    } on Object {
      continue;
    }
  }
  return false;
}

/// Keeps [ordered] in order where it can while no more than two entries in a row share a
/// kind, or a lesson where the lesson is known. When every remaining entry would make a third
/// in a row, the first one goes next.
List<QueueEntry> interleaveRuns(List<QueueEntry> ordered) {
  final pending = [...ordered];
  final out = <QueueEntry>[];
  bool breaksRun(QueueEntry e) {
    if (out.length < 2) return false;
    final a = out[out.length - 1], b = out[out.length - 2];
    if (a.kind == e.kind && b.kind == e.kind) return true;
    final lesson = e.lesson;
    return lesson != null && a.lesson == lesson && b.lesson == lesson;
  }

  while (pending.isNotEmpty) {
    var pick = pending.indexWhere((e) => !breaksRun(e));
    if (pick < 0) pick = 0;
    out.add(pending.removeAt(pick));
  }
  return out;
}

/// The next new items in intake order (PIN-6): up to [kFoundationNewPerDay] level-0 items
/// first (particles, forms, pairs, table rows in catalog order), then lessons in ascending
/// order, each lesson's words before its grammar, and each grammar point after the
/// conjugation ideas it uses; then the rest of the level-0 items. [introduced] holds every
/// item with an FSRS state or a seed. Returns at most [limit] items.
List<ItemDef> newIntakeOrder(
    ItemCatalog catalog, Set<String> introduced, int limit) {
  final taken = {...introduced};
  final out = <ItemDef>[];
  bool add(ItemDef item) {
    if (out.length >= limit || taken.contains(item.id)) return false;
    taken.add(item.id);
    out.add(item);
    return true;
  }

  final foundations = [
    for (final i in catalog.items)
      if (i.prereqLevel == 0 && !taken.contains(i.id)) i
  ];
  for (final f in foundations.take(kFoundationNewPerDay)) {
    add(f);
  }

  final lessons = <int>{
    for (final i in catalog.items)
      if (i.lesson != null) i.lesson!
  }.toList()
    ..sort();
  for (final lesson in lessons) {
    if (out.length >= limit) break;
    final ofLesson = [
      for (final i in catalog.items)
        if (i.lesson == lesson) i
    ];
    for (final w in ofLesson.where((i) => i.kind == ItemKind.word)) {
      add(w);
    }
    for (final g in ofLesson.where((i) => i.kind != ItemKind.word)) {
      if (out.length >= limit) break;
      for (final p in g.prereqs) {
        final pre = catalog.byId(p);
        if (pre != null) add(pre);
      }
      // A point waits for a day with room after its forms.
      if (g.prereqs.every(taken.contains)) add(g);
    }
  }
  for (final f in foundations) {
    add(f);
  }
  return out;
}

/// Builds [day]'s plan from the record (Task 14). [day] defaults to [clock]'s today.
/// [daysMissed] is the number of local days with no session since the last one; two or more
/// is return mode (D9).
Future<DayPlan> buildPlan({
  int? day,
  PlanBudget budget = PlanBudget.standard,
  int daysMissed = 0,
  required JpStore store,
  required ItemCatalog catalog,
  Clock clock = const SystemClock(),
  Scheduler scheduler = const FsrsScheduler(),
}) async {
  final today = day ?? clock.today();
  final returnMode = daysMissed >= kReturnModeDaysMissed;
  final srs = await store.allSrs();
  final mastery = await store.allMastery();
  final dueRows = await store.dueOnOrBefore(today);
  final seededIds = {for (final s in await store.seeds()) s.itemId};
  final attempts = await store.attempts();

  final order = <String, int>{
    for (var i = 0; i < catalog.items.length; i++) catalog.items[i].id: i,
  };
  double? rOf(String id) {
    final s = srs[id];
    return s == null ? null : scheduler.retrievability(s, today);
  }

  final dueById = <String, DueItem>{
    for (final d in dueRows)
      if (catalog.byId(d.itemId) != null) d.itemId: d,
  };

  // A New or stretch entry is the item's scheduled introduction, so its answer is due and a
  // clear on it is the first of the four (operator ruling ASK-6).
  QueueEntry entryFor(ItemDef item, PlanSection section) {
    final due = dueById[item.id];
    return QueueEntry(
      itemId: item.id,
      kind: item.kind,
      section: section,
      costSeconds: budget.costOf(item.kind),
      wasDue: due != null || section == PlanSection.newItems,
      seeded:
          due?.seeded ?? (srs[item.id] == null && seededIds.contains(item.id)),
      lesson: item.lesson,
      retrievability: rOf(item.id),
    );
  }

  // Yesterday's wrongs, in the order they were first answered wrong.
  final repairIds = <String>{
    for (final a in attempts)
      if (a.localDay == today - 1 &&
          a.grade == Grade.wrong &&
          a.source != Source.sayIt &&
          catalog.byId(a.itemId) != null)
        a.itemId,
  };

  final backlogIds = {...dueById.keys, ...repairIds};
  final backlogSeconds = backlogIds.fold<int>(
      0, (sum, id) => sum + budget.costOf(catalog.byId(id)!.kind));
  final gateHeld = backlogSeconds <= budget.gateSeconds;

  final planned = <String>{};
  var cost = 0;
  var stoppedForBudget = false;
  bool fits(ItemDef item) =>
      cost + budget.costOf(item.kind) <= budget.fillSeconds;
  QueueEntry take(ItemDef item, PlanSection section) {
    planned.add(item.id);
    cost += budget.costOf(item.kind);
    return entryFor(item, section);
  }

  // Warm-up (return mode): foundational items still likely recalled, most likely first.
  final warmUp = <QueueEntry>[];
  if (returnMode) {
    final reuse = <String, int>{};
    for (final i in catalog.items) {
      for (final p in i.prereqs) {
        reuse[p] = (reuse[p] ?? 0) + 1;
      }
    }
    final candidates = [
      for (final d in dueById.values)
        if (!d.seeded && !repairIds.contains(d.itemId)) catalog.byId(d.itemId)!
    ].where((i) {
      final r = rOf(i.id);
      final foundational =
          i.prereqLevel == 0 || (reuse[i.id] ?? 0) >= kHighReusePrereqCount;
      return foundational && r != null && r >= kWarmUpLowR && r <= kWarmUpHighR;
    }).toList()
      ..sort((a, b) {
        final byR = rOf(b.id)!.compareTo(rOf(a.id)!);
        return byR != 0 ? byR : order[a.id]!.compareTo(order[b.id]!);
      });
    for (final item in candidates.take(kWarmUpMax)) {
      if (!fits(item)) break;
      warmUp.add(take(item, PlanSection.warmUp));
    }
  }

  // Repairs: yesterday's wrongs first, whatever the budget left for the rest.
  final repairs = <QueueEntry>[];
  var repairsLeft = 0;
  for (final id in repairIds) {
    if (planned.contains(id)) continue;
    final item = catalog.byId(id)!;
    if (!fits(item)) {
      repairsLeft++;
      stoppedForBudget = true;
      continue;
    }
    repairs.add(take(item, PlanSection.repair));
  }

  // Keep-sharp (D27): the first session of the week; in return mode only under the gate.
  final keepSharp = <QueueEntry>[];
  final keepSharpRan =
      (!returnMode || gateHeld) && !await keepSharpRanThisWeek(store, today);
  if (keepSharpRan) {
    final candidates = [
      for (final m in mastery.values)
        if (m.status == MasteryStatus.mastered &&
            srs[m.itemId] != null &&
            srs[m.itemId]!.dueDay > today &&
            !planned.contains(m.itemId) &&
            catalog.byId(m.itemId) != null)
          catalog.byId(m.itemId)!
    ]..sort((a, b) {
        final byR = rOf(a.id)!.compareTo(rOf(b.id)!);
        return byR != 0 ? byR : order[a.id]!.compareTo(order[b.id]!);
      });
    for (final item in candidates.take(kKeepSharpCount)) {
      if (!fits(item)) break;
      keepSharp.add(take(item, PlanSection.keepSharp));
    }
  }

  // Due (D26): stateful by ascending retrievability, then seeded by seed day and lesson.
  final ordered = orderDue(
    [
      for (final d in dueById.values)
        if (!planned.contains(d.itemId)) d
    ],
    catalog: catalog,
    srs: srs,
    retrievability: rOf,
  );
  final lowQ = <ItemDef>[];
  final restQ = <ItemDef>[];
  for (final item in ordered) {
    final r = rOf(item.id);
    if (returnMode && r != null && r < kLowRetrievability) {
      lowQ.add(item);
    } else {
      restQ.add(item);
    }
  }
  final rank = {for (var i = 0; i < ordered.length; i++) ordered[i].id: i};
  var low = 0;
  var total = planned.length;
  final dueChosen = <QueueEntry>[];
  var li = 0, ri = 0;
  while (li < lowQ.length || ri < restQ.length) {
    final lowFirst = ri >= restQ.length ||
        (li < lowQ.length && rank[lowQ[li].id]! < rank[restQ[ri].id]!);
    final lowAllowed = kLowRCapDivisor * (low + 1) <= total + 1;
    final ItemDef item;
    var isLow = false;
    if (lowFirst && lowAllowed) {
      item = lowQ[li];
      isLow = true;
    } else if (ri < restQ.length) {
      item = restQ[ri];
    } else {
      break; // only under-0.5 items remain, and the cap is reached
    }
    if (!fits(item)) {
      stoppedForBudget = true;
      break;
    }
    dueChosen.add(take(item, PlanSection.due));
    total++;
    if (isLow) {
      low++;
      li++;
    } else {
      ri++;
    }
  }
  final due = interleaveRuns(dueChosen);
  final leftover = interleaveRuns([
    for (final item in ordered)
      if (!planned.contains(item.id)) entryFor(item, PlanSection.due)
  ]);
  final dueLeft = leftover.length + repairsLeft;

  // New (PIN-6): skipped on a return, above the gate, or once the target is spent.
  final NewSkip newSkip;
  if (returnMode) {
    newSkip = NewSkip.daysMissed;
  } else if (!gateHeld) {
    newSkip = NewSkip.backlog;
  } else if (cost >= budget.targetSeconds) {
    newSkip = NewSkip.targetSpent;
  } else {
    newSkip = NewSkip.none;
  }
  final newEntries = <QueueEntry>[];
  final stretchEntries = <QueueEntry>[];
  var newCut = false;
  if (newSkip == NewSkip.none) {
    final introduced = {...srs.keys, ...seededIds, ...planned};
    final intake =
        newIntakeOrder(catalog, introduced, budget.newPerDay + kStretchNew);
    for (final item in intake.take(budget.newPerDay)) {
      if (!fits(item)) {
        newCut = true;
        break;
      }
      newEntries.add(take(item, PlanSection.newItems));
    }
    if (!newCut) {
      for (final item in intake.skip(budget.newPerDay)) {
        stretchEntries.add(entryFor(item, PlanSection.newItems));
      }
    }
  }

  final stretchSeconds =
      stretchEntries.fold<int>(0, (sum, e) => sum + e.costSeconds);
  final stretchOffer = newSkip == NewSkip.none &&
      !newCut &&
      dueLeft == 0 &&
      gateHeld &&
      daysMissed == 0 &&
      stretchEntries.isNotEmpty &&
      cost + stretchSeconds <= budget.fillSeconds;

  final leftoverSeconds =
      leftover.fold<int>(0, (sum, e) => sum + e.costSeconds);
  final catchUp = leftover.take(kCatchUpBlock).toList();
  final catchUpOffer = stoppedForBudget &&
      leftoverSeconds > budget.gateSeconds &&
      catchUp.isNotEmpty;

  return DayPlan(
    day: today,
    builtAtUtc: clock.now().toUtc(),
    entries: List.unmodifiable(
        [...warmUp, ...repairs, ...due, ...keepSharp, ...newEntries]),
    daysMissed: daysMissed,
    backlogSeconds: backlogSeconds,
    targetSeconds: budget.targetSeconds,
    ceilingSeconds: budget.ceilingSeconds,
    gateSeconds: budget.gateSeconds,
    repairSlotSeconds: budget.repairSlotSeconds,
    newSkip: newSkip,
    keepSharpRan: keepSharpRan,
    dueLeft: dueLeft,
    stretchOffer: stretchOffer,
    stretchEntries: stretchOffer ? stretchEntries : const [],
    catchUpOffer: catchUpOffer,
    catchUpEntries: catchUpOffer ? catchUp : const [],
  );
}

/// The Due order before interleaving (D26): stateful items by ascending retrievability, ties
/// by prerequisite level, then most lapses first, then catalog order; then seeded items by
/// seed due day, lesson (lesson-free kinds first) and catalog order.
List<ItemDef> orderDue(
  List<DueItem> due, {
  required ItemCatalog catalog,
  required Map<String, SrsState> srs,
  required double? Function(String id) retrievability,
}) {
  final order = <String, int>{
    for (var i = 0; i < catalog.items.length; i++) catalog.items[i].id: i,
  };
  final stateful = [
    for (final d in due)
      if (srs[d.itemId] != null && catalog.byId(d.itemId) != null)
        catalog.byId(d.itemId)!
  ]..sort((a, b) {
      final byR = retrievability(a.id)!.compareTo(retrievability(b.id)!);
      if (byR != 0) return byR;
      final byLevel = a.prereqLevel.compareTo(b.prereqLevel);
      if (byLevel != 0) return byLevel;
      final byLapses = srs[b.id]!.lapses.compareTo(srs[a.id]!.lapses);
      if (byLapses != 0) return byLapses;
      return order[a.id]!.compareTo(order[b.id]!);
    });
  final seedDay = {for (final d in due) d.itemId: d.dueDay};
  final seeded = [
    for (final d in due)
      if (srs[d.itemId] == null && catalog.byId(d.itemId) != null)
        catalog.byId(d.itemId)!
  ]..sort((a, b) {
      final byDay = seedDay[a.id]!.compareTo(seedDay[b.id]!);
      if (byDay != 0) return byDay;
      final byLesson = (a.lesson ?? 0).compareTo(b.lesson ?? 0);
      if (byLesson != 0) return byLesson;
      return order[a.id]!.compareTo(order[b.id]!);
    });
  return [...stateful, ...seeded];
}
