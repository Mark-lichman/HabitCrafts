// The mastery rule (D4) and the states the learner sees (D16), as one pure fold over an item's
// own attempts (PIN-1). Nothing here reads a lesson number or the clock.
//
// An item is Mastered when all of these hold, each a query over its attempt log:
//   1. four clear answers on four different local days, each given while the item was due;
//   2. the fourth (the clear that completes the rule) at least 21 days after the previous scored
//      review of the item;
//   3. no wrong since the first of them; a hinted answer earns no credit and two hinted in a row
//      reset the count (PIN-3);
//   4. where the item has two or more templates: two different templates among the clears and,
//      where it has a production probe, one production clear; a one-template item needs only
//      the spaced clears (PIN-15);
//   5. transfer per kind: three sentences for a grammar point, three verbs for a conjugation
//      idea, both directions for a pair, two different cells for a table row (every cell where
//      the row has fewer than two).
// A wrong, or two hinted in a row, on a Mastered item makes it Shaky; two clears on two days,
// the second 7 or more days after the first, regain it (PIN-4).
//
// Early practice (PIN-14, ASK-2): a clear, hinted or self answer on an item that is not due
// changes nothing; a wrong counts. A self answer (Got it over a check that could not score)
// records the review with no credit and leaves the hinted row alone (ASK-3). Unscored changes
// nothing. The Say-it track never counts.
//
// The numbers are constants so they can change later: the log replays (D4).

import 'attempt.dart';

/// Clears needed for Mastered (D4 clause 1).
const int kClearsToMaster = 4;

/// Minimum days from the previous scored review to the completing clear (D4 clause 2).
const int kFinalGapDays = 21;

/// Hinted answers in a row that reset the count (D3).
const int kHintedInARowReset = 2;

/// Different templates needed where an item has two or more (D4 clause 4).
const int kTemplatesNeeded = 2;

/// Clears needed to regain a Shaky item, and the gap between the first and the last (D16).
const int kRegainClears = 2;
const int kRegainGapDays = 7;

/// Different probes needed per kind (D4 clause 5), before the cap at the item's probe count.
const Map<ItemKind, int> kTransferProbes = {
  ItemKind.grammar: 3,
  ItemKind.conjugation: 3,
  ItemKind.pair: 2,
  ItemKind.tableRow: 2,
};

/// What the rule needs to know about an item. Task 5's `ItemDef` implements it.
abstract class ItemDefLike {
  String get id;
  ItemKind get kind;

  /// The number of different question templates the item's probes use.
  int get templateCount;

  /// Whether the item has a scorable production probe (typed, spoken, conjugate, build).
  bool get hasProductionProbe;

  /// The number of different probes: sentences, verbs, directions or cells.
  int get probeCount;
}

/// The different probes an item needs among its clears (D4 clause 5).
int transferProbesNeeded(ItemDefLike item) {
  final need = kTransferProbes[item.kind] ?? 0;
  return need < item.probeCount ? need : item.probeCount;
}

/// New · Learning · Mastered · Shaky (D16). `neu` because `new` is a keyword.
enum MasteryStatus { neu, learning, mastered, shaky }

/// One clear that counts: in the current run toward Mastered, or toward the regain when Shaky.
class ClearRef {
  const ClearRef({
    required this.day,
    required this.template,
    required this.production,
    required this.probeId,
  });

  final int day;
  final String template;
  final bool production;
  final String probeId;

  Map<String, dynamic> toJson() => {
        'day': day,
        'template': template,
        'production': production,
        'probeId': probeId,
      };

  factory ClearRef.fromJson(Map<String, dynamic> j) => ClearRef(
        day: j['day'] as int,
        template: j['template'] as String,
        production: j['production'] as bool,
        probeId: j['probeId'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is ClearRef &&
      other.day == day &&
      other.template == template &&
      other.production == production &&
      other.probeId == probeId;

  @override
  int get hashCode => Object.hash(day, template, production, probeId);
}

/// Per-item mastery bookkeeping. Derivable from the log; the store keeps it for speed.
class MasteryState {
  const MasteryState({
    required this.itemId,
    required this.status,
    this.clears = const [],
    this.hintStreak = 0,
    this.lastScoredDay,
    this.masteredOn,
    this.shakyOn,
    this.keptReviews = 0,
    this.keptClear = 0,
  });

  /// An item with no attempt: New.
  const MasteryState.initial(this.itemId)
      : status = MasteryStatus.neu,
        clears = const [],
        hintStreak = 0,
        lastScoredDay = null,
        masteredOn = null,
        shakyOn = null,
        keptReviews = 0,
        keptClear = 0;

  final String itemId;
  final MasteryStatus status;

  /// The counting clears since the last reset. When Shaky, the regain clears.
  final List<ClearRef> clears;

  /// Hinted answers in a row. A self answer leaves it as it was (ASK-3).
  final int hintStreak;

  /// The local day of the last scored review: clear, hinted, self or wrong. Unscored is excluded.
  final int? lastScoredDay;
  final int? masteredOn;
  final int? shakyOn;

  /// Reviews of the item while Mastered, and how many of them were clear (the kept rate, A.4).
  final int keptReviews;
  final int keptClear;

  /// The "n of 4" a Learning pill shows; 4 when Mastered; the regain clears when Shaky.
  int get clearCount {
    if (status == MasteryStatus.mastered) return kClearsToMaster;
    return clears.length < kClearsToMaster ? clears.length : kClearsToMaster;
  }

  MasteryState copyWith({
    MasteryStatus? status,
    List<ClearRef>? clears,
    int? hintStreak,
    int? lastScoredDay,
    int? masteredOn,
    int? Function()? shakyOn,
    int? keptReviews,
    int? keptClear,
  }) =>
      MasteryState(
        itemId: itemId,
        status: status ?? this.status,
        clears: clears ?? this.clears,
        hintStreak: hintStreak ?? this.hintStreak,
        lastScoredDay: lastScoredDay ?? this.lastScoredDay,
        masteredOn: masteredOn ?? this.masteredOn,
        shakyOn: shakyOn != null ? shakyOn() : this.shakyOn,
        keptReviews: keptReviews ?? this.keptReviews,
        keptClear: keptClear ?? this.keptClear,
      );

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'status': status.name,
        'clears': [for (final c in clears) c.toJson()],
        'hintStreak': hintStreak,
        'lastScoredDay': lastScoredDay,
        'masteredOn': masteredOn,
        'shakyOn': shakyOn,
        'keptReviews': keptReviews,
        'keptClear': keptClear,
      };

  factory MasteryState.fromJson(Map<String, dynamic> j) => MasteryState(
        itemId: j['itemId'] as String,
        status: MasteryStatus.values.byName(j['status'] as String),
        clears: [
          for (final c in (j['clears'] as List? ?? const []))
            ClearRef.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
        hintStreak: (j['hintStreak'] as int?) ?? 0,
        lastScoredDay: j['lastScoredDay'] as int?,
        masteredOn: j['masteredOn'] as int?,
        shakyOn: j['shakyOn'] as int?,
        keptReviews: (j['keptReviews'] as int?) ?? 0,
        keptClear: (j['keptClear'] as int?) ?? 0,
      );

  @override
  bool operator ==(Object other) {
    if (other is! MasteryState) return false;
    if (other.clears.length != clears.length) return false;
    for (var i = 0; i < clears.length; i++) {
      if (other.clears[i] != clears[i]) return false;
    }
    return other.itemId == itemId &&
        other.status == status &&
        other.hintStreak == hintStreak &&
        other.lastScoredDay == lastScoredDay &&
        other.masteredOn == masteredOn &&
        other.shakyOn == shakyOn &&
        other.keptReviews == keptReviews &&
        other.keptClear == keptClear;
  }

  @override
  int get hashCode => Object.hash(itemId, status, Object.hashAll(clears),
      hintStreak, lastScoredDay, masteredOn, shakyOn, keptReviews, keptClear);

  @override
  String toString() =>
      'MasteryState($itemId ${status.name} $clearCount, streak $hintStreak, '
      'last $lastScoredDay)';
}

/// Whether [clears] complete the rule for [item] on [day], given the previous scored review.
bool _meetsRule(
    List<ClearRef> clears, int? previousScoredDay, int day, ItemDefLike item) {
  if (clears.length < kClearsToMaster) return false;
  if (previousScoredDay == null || day - previousScoredDay < kFinalGapDays) {
    return false;
  }
  if (item.templateCount >= kTemplatesNeeded) {
    final templates = {for (final c in clears) c.template};
    if (templates.length < kTemplatesNeeded) return false;
    if (item.hasProductionProbe && !clears.any((c) => c.production)) {
      return false;
    }
  }
  final probes = {for (final c in clears) c.probeId};
  return probes.length >= transferProbesNeeded(item);
}

/// The mastery state after one more attempt on the item (D4, D16, PIN-3, PIN-14).
///
/// Pure: the result depends only on [state], [attempt] and [item]. Replaying an item's attempts
/// in order from [MasteryState.initial] gives its state (see [masteryFromAttempts]).
MasteryState masteryAfter(
    MasteryState state, Attempt attempt, ItemDefLike item) {
  if (attempt.itemId != state.itemId || item.id != state.itemId) {
    throw ArgumentError(
        'attempt for ${attempt.itemId} applied to ${state.itemId} (${item.id})');
  }
  final grade = attempt.grade;
  // Nothing scored, the Say-it track, and an early clear, hinted or self answer leave the
  // state as it was. Only an early wrong counts (PIN-14, operator ruling ASK-2).
  if (grade == Grade.unscored) return state;
  if (attempt.source == Source.sayIt) return state;
  if (attempt.source == Source.early && grade != Grade.wrong) return state;

  final day = attempt.localDay;
  final wasMastered = state.status == MasteryStatus.mastered;
  final maintenance = wasMastered && attempt.source != Source.early;
  final keptReviews = state.keptReviews + (maintenance ? 1 : 0);
  final keptClear =
      state.keptClear + (maintenance && grade == Grade.clear ? 1 : 0);
  final status =
      state.status == MasteryStatus.neu ? MasteryStatus.learning : state.status;
  final base = state.copyWith(
    status: status,
    lastScoredDay: day,
    keptReviews: keptReviews,
    keptClear: keptClear,
  );

  switch (grade) {
    case Grade.wrong:
      // A wrong counts everywhere, early practice included (PIN-14).
      return base.copyWith(
        status: wasMastered ? MasteryStatus.shaky : null,
        shakyOn: wasMastered ? () => day : null,
        clears: const [],
        hintStreak: 0,
      );

    case Grade.self:
      // A Got it over a check that could not score: the review is recorded, with no credit
      // (PIN-3). It is neutral for the hinted row, so the streak and clears stay (ASK-3).
      return base;

    case Grade.hinted:
      // No credit (PIN-3). Two in a row: the hint is carrying the item.
      final streak = state.hintStreak + 1;
      if (streak < kHintedInARowReset) return base.copyWith(hintStreak: streak);
      return base.copyWith(
        status: wasMastered ? MasteryStatus.shaky : null,
        shakyOn: wasMastered ? () => day : null,
        clears: const [],
        hintStreak: streak,
      );

    case Grade.clear:
      final counts = attempt.wasDue &&
          !state.clears.any((c) => c.day == day);
      if (wasMastered || !counts) return base.copyWith(hintStreak: 0);
      final clears = [
        ...state.clears,
        ClearRef(
          day: day,
          template: attempt.template,
          production: attempt.production,
          probeId: attempt.probeId,
        ),
      ];
      if (status == MasteryStatus.shaky) {
        if (clears.length >= kRegainClears &&
            day - clears.first.day >= kRegainGapDays) {
          return base.copyWith(
            status: MasteryStatus.mastered,
            masteredOn: day,
            shakyOn: () => null,
            clears: clears,
            hintStreak: 0,
          );
        }
        return base.copyWith(clears: clears, hintStreak: 0);
      }
      if (_meetsRule(clears, state.lastScoredDay, day, item)) {
        return base.copyWith(
          status: MasteryStatus.mastered,
          masteredOn: day,
          clears: clears,
          hintStreak: 0,
        );
      }
      return base.copyWith(clears: clears, hintStreak: 0);

    case Grade.unscored:
      return state;
  }
}

/// The state of [item] replayed from its own attempts, oldest first (PIN-1).
MasteryState masteryFromAttempts(ItemDefLike item, Iterable<Attempt> attempts) {
  var state = MasteryState.initial(item.id);
  for (final a in attempts) {
    state = masteryAfter(state, a, item);
  }
  return state;
}
