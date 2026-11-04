// The study record's store (D14, D26): one interface, two implementations.
//
// `JpStoreSqlite` (jp_store_sqlite.dart) keeps the record on the phone in SQLite. `JpStoreMemory`
// (jp_store_memory.dart) keeps it in memory and is the store on web, which keeps nothing between
// loads (A4). The same test suite runs against both (test/jp_store_test.dart).
//
// 🚨 THE LOG IS THE SOURCE OF TRUTH. Two event kinds are append-only:
//   * an `Attempt` per answer (attempt.dart);
//   * a `SeedEvent` per seeded item: the item and its due day, never an attempt (D26), so the
//     seed writes no review and no clear (PIN-7) and a rebuild still restores seeded due days.
// The `srs`, `mastery` and seed-due tables are caches: `rebuild` replays the log through the same
// pure functions the live writer uses (`srsAfter`, `masteryAfter`) and must land on the same
// states. A learner note (the v2 `can_use_it` pill) is kept beside the log and exported with it.
//
// The schedule rule per answer (`srsAfter`), the one place the store reads a grade:
//   * unscored, and the Say-it track: no change (D4, D17);
//   * early practice (PIN-14, D23): a clear, a hinted or a self answer changes nothing; a wrong
//     counts as a real Again and the item is due tomorrow;
//   * anything else: the scheduler's first or review, then `nextDue` spreads the due day over
//     the load of every other item.
// Mastery is `masteryAfter` (mastery_rule.dart), which owns PIN-3, PIN-4 and PIN-14.
//
// 🚨 HAZARD FOR THE INTAKE (Task 14), THE TOPIC INDEX (Task 22) AND THE PRACTICE-NOW ENTRY
// POINTS (Tasks 23, 24); the rule lives in mastery_rule.dart (Task 6): `masteryAfter` leaves
// only an early clear alone. An early hinted or self answer on an item with no SrsState and no
// seed moves its mastery from New to Learning with zero clears, while `srsAfter` writes no
// schedule, so the item is Learning and never due. Select New intake items by "no SrsState and
// no seed", never by MasteryStatus.neu, or that item drops out of the queue. Build the Not yet
// known and Due today sets from SrsState and seeds, not from MasteryStatus.
//
// `rebuild` reads the log across several awaits before it writes, and `importLog` replaces the
// whole record, so both run on the same chain as `recordAnswer` (`_serialized`): no answer reads
// its before-state on one side of a replay's write and commits on the other.

import 'attempt.dart';
import 'mastery_rule.dart';
import 'scheduler.dart';

/// The note the v2 grammar card's "I can use it" pill becomes (migration, Task 8).
const String kNoteCanUseIt = 'can_use_it';

/// The item definitions the replay needs: the catalog's `byId`. Null for an id the catalog no
/// longer knows; its attempts stay in the log and still move its schedule.
typedef ItemLookup = ItemDefLike? Function(String itemId);

/// One seeded item: due on [dueDay] with no FSRS state and no attempt (D26, PIN-7).
class SeedEvent {
  const SeedEvent({
    this.id,
    required this.itemId,
    required this.dueDay,
    required this.atUtc,
  });

  /// The log's row id, assigned by the store; null before it is written.
  final int? id;
  final String itemId;
  final int dueDay;
  final DateTime atUtc;

  SeedEvent withId(int id) =>
      SeedEvent(id: id, itemId: itemId, dueDay: dueDay, atUtc: atUtc);

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'itemId': itemId,
        'dueDay': dueDay,
        'atUtc': atUtc.toUtc().toIso8601String(),
      };

  factory SeedEvent.fromJson(Map<String, dynamic> j) => SeedEvent(
        id: j['id'] as int?,
        itemId: j['itemId'] as String,
        dueDay: j['dueDay'] as int,
        atUtc: DateTime.parse(j['atUtc'] as String).toUtc(),
      );

  @override
  bool operator ==(Object other) =>
      other is SeedEvent &&
      other.id == id &&
      other.itemId == itemId &&
      other.dueDay == dueDay &&
      other.atUtc.toUtc() == atUtc.toUtc();

  @override
  int get hashCode => Object.hash(id, itemId, dueDay, atUtc.toUtc());

  @override
  String toString() => 'SeedEvent($itemId due $dueDay)';
}

/// What the store keeps per item beside its schedule: the earliest seeded due day and a note.
class ItemRecord {
  const ItemRecord({required this.itemId, this.seedDueDay, this.note});

  final String itemId;
  final int? seedDueDay;
  final String? note;
}

/// An item due on or before a day. [seeded] is true for an item with a seeded due day and no
/// FSRS state yet (D26).
class DueItem {
  const DueItem(
      {required this.itemId, required this.dueDay, required this.seeded});

  final String itemId;
  final int dueDay;
  final bool seeded;

  @override
  bool operator ==(Object other) =>
      other is DueItem &&
      other.itemId == itemId &&
      other.dueDay == dueDay &&
      other.seeded == seeded;

  @override
  int get hashCode => Object.hash(itemId, dueDay, seeded);

  @override
  String toString() => 'DueItem($itemId $dueDay${seeded ? ' seeded' : ''})';
}

/// One local day's session: the plan as opaque JSON (Phase 3's `DayPlan` serialises into it),
/// how far through it the learner is, and whether it is done.
class DayRecord {
  const DayRecord({
    required this.day,
    required this.plan,
    this.position = 0,
    this.completed = false,
  });

  final int day;

  /// The plan, JSON-encoded by its owner. The store never reads inside it.
  final String plan;

  /// The index of the next entry to show.
  final int position;
  final bool completed;

  DayRecord copyWith({String? plan, int? position, bool? completed}) =>
      DayRecord(
        day: day,
        plan: plan ?? this.plan,
        position: position ?? this.position,
        completed: completed ?? this.completed,
      );

  @override
  bool operator ==(Object other) =>
      other is DayRecord &&
      other.day == day &&
      other.plan == plan &&
      other.position == position &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(day, plan, position, completed);

  @override
  String toString() =>
      'DayRecord($day at $position${completed ? ', done' : ''})';
}

/// Everything export writes and import reads: the two event logs and the notes.
class StudyLog {
  const StudyLog({
    this.attempts = const [],
    this.seeds = const [],
    this.notes = const {},
  });

  /// Oldest first, in append order.
  final List<Attempt> attempts;

  /// Oldest first, in append order.
  final List<SeedEvent> seeds;

  /// Item id to note.
  final Map<String, String> notes;
}

/// The states a replay of the log lands on.
class ReplayResult {
  const ReplayResult(
      {required this.srs, required this.mastery, required this.seedDue});

  final Map<String, SrsState> srs;
  final Map<String, MasteryState> mastery;

  /// The earliest seeded due day per seeded item.
  final Map<String, int> seedDue;
}

/// What one recorded answer wrote.
class AnswerOutcome {
  const AnswerOutcome(
      {required this.attempt, required this.srs, required this.mastery});

  /// The attempt as logged, with its row id.
  final Attempt attempt;

  /// The item's schedule after the answer; null for an item still without one.
  final SrsState? srs;

  /// The item's mastery after the answer; null when the catalog does not know the item.
  final MasteryState? mastery;
}

/// The item's schedule after [attempt] (D12, D23, PIN-14). Pure.
///
/// [loadByDay] is the load of every other item (the answered item's own due day removed), so
/// the live writer and the replay spread due days alike.
SrsState? srsAfter(Scheduler scheduler, SrsState? state, Attempt attempt,
    Map<int, int> loadByDay) {
  final rating = attempt.rating;
  if (rating == null || attempt.grade == Grade.unscored) return state;
  if (attempt.source == Source.sayIt) return state;
  final day = attempt.localDay;
  if (attempt.source == Source.early) {
    // Only an early wrong counts: a real Again, and the item is due tomorrow.
    if (attempt.grade != Grade.wrong) return state;
    final next = state == null
        ? scheduler.first(SrsRating.again, day)
        : scheduler.review(state, SrsRating.again, day);
    return next.copyWith(dueDay: day + 1);
  }
  final r = SrsRating.fromValue(rating);
  final next =
      state == null ? scheduler.first(r, day) : scheduler.review(state, r, day);
  return next.copyWith(dueDay: scheduler.nextDue(next, loadByDay));
}

void _bump(Map<int, int> load, int? day, int by) {
  if (day == null) return;
  final n = (load[day] ?? 0) + by;
  if (n <= 0) {
    load.remove(day);
  } else {
    load[day] = n;
  }
}

/// Replays the log from nothing (D14, D26). Seeds and attempts are applied in time order, a
/// seed before an attempt at the same instant, each kind in append order. A seed keeps the
/// earliest due day per item. Pure.
ReplayResult replayLog(StudyLog log, ItemLookup lookup, Scheduler scheduler) {
  final srs = <String, SrsState>{};
  final mastery = <String, MasteryState>{};
  final seedDue = <String, int>{};
  final load = <int, int>{};
  int? dueOf(String id) => srs[id]?.dueDay ?? seedDue[id];

  final seeds = [...log.seeds];
  final attempts = [...log.attempts];
  var s = 0, a = 0;
  while (s < seeds.length || a < attempts.length) {
    final takeSeed = a >= attempts.length ||
        (s < seeds.length &&
            !seeds[s].atUtc.toUtc().isAfter(attempts[a].atUtc.toUtc()));
    if (takeSeed) {
      final seed = seeds[s++];
      final id = seed.itemId;
      _bump(load, dueOf(id), -1);
      final old = seedDue[id];
      seedDue[id] = old == null || seed.dueDay < old ? seed.dueDay : old;
      _bump(load, dueOf(id), 1);
      continue;
    }
    final attempt = attempts[a++];
    final id = attempt.itemId;
    _bump(load, dueOf(id), -1);
    final next = srsAfter(scheduler, srs[id], attempt, load);
    if (next != null) srs[id] = next;
    _bump(load, dueOf(id), 1);
    final item = lookup(id);
    if (item != null) {
      mastery[id] =
          masteryAfter(mastery[id] ?? MasteryState.initial(id), attempt, item);
    }
  }
  return ReplayResult(srs: srs, mastery: mastery, seedDue: seedDue);
}

/// The study record. Every method is asynchronous because the phone's store is SQLite.
abstract class JpStore {
  JpStore();

  /// The tail of the write chain: each [recordAnswer], [rebuild] or [importLog] starts after
  /// the one before it settles.
  Future<void> _answers = Future.value();

  /// Runs [body] after every earlier chained write settles. A failed body does not break the
  /// chain for the next one.
  Future<T> _serialized<T>(Future<T> Function() body) {
    final run = _answers.then((_) => body());
    _answers = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  // --- the log ---------------------------------------------------------------

  /// Appends [attempt] and, in the same transaction, writes the item's [srs] and [mastery]
  /// when given (one transaction per answer, D14). Returns the attempt with its row id.
  /// Throws an [ArgumentError], and writes nothing, when [mastery] names another item.
  Future<Attempt> appendAttempt(Attempt attempt,
      {SrsState? srs, MasteryState? mastery});

  /// Appends seed events in one transaction. Each item keeps its earliest seeded due day.
  /// Writes no attempt, no schedule and no mastery (PIN-7).
  Future<void> appendSeeds(Iterable<SeedEvent> seeds);

  Future<void> appendSeed(String itemId, int dueDay,
          {required DateTime atUtc}) =>
      appendSeeds([SeedEvent(itemId: itemId, dueDay: dueDay, atUtc: atUtc)]);

  /// The attempts, oldest first; only [itemId]'s when given.
  Future<List<Attempt>> attempts({String? itemId});

  /// The seed events, oldest first.
  Future<List<SeedEvent>> seeds();

  // --- the derived states ----------------------------------------------------

  Future<SrsState?> srs(String itemId);
  Future<void> putSrs(String itemId, SrsState state);
  Future<Map<String, SrsState>> allSrs();

  Future<MasteryState?> mastery(String itemId);
  Future<void> putMastery(MasteryState state);
  Future<Map<String, MasteryState>> allMastery();

  /// The item's seeded due day and note; null for an item never seeded or noted.
  Future<ItemRecord?> item(String itemId);

  /// Sets or, with null, clears the item's note.
  Future<void> setNote(String itemId, String? note);

  /// Every note, by item id.
  Future<Map<String, String>> notes();

  /// Every item due on or before [day]: stateful items by their FSRS due day, and seeded
  /// items with no FSRS state by their seeded due day (D26). Sorted by due day, stateful
  /// before seeded, then by item id. The plan builder orders them for the session.
  Future<List<DueItem>> dueOnOrBefore(int day);

  /// Local day to the number of items due on it, by the same rule as [dueOnOrBefore].
  Future<Map<int, int>> loadByDay();

  // --- the days --------------------------------------------------------------

  Future<DayRecord?> day(int day);

  /// Writes the day's record, replacing any earlier one for the same day.
  Future<void> putDay(DayRecord record);

  /// The latest local day with a [DayRecord], or null before the first session.
  Future<int?> lastDay();

  // --- bookkeeping -----------------------------------------------------------

  /// A store-level flag, such as the one-time v2 migration's.
  Future<String?> meta(String key);
  Future<void> putMeta(String key, String value);

  /// Replaces the schedule, the mastery states and the seeded due days in one transaction.
  /// Notes, the log, the days and the flags stay.
  Future<void> replaceDerived(ReplayResult result);

  /// Replaces the log and the notes with [log] and the derived states with [result], in one
  /// transaction: a write that fails leaves the old log, caches and notes in place. The days
  /// and the flags stay. [importLog] is its caller; [result] is [log]'s replay.
  Future<void> replaceAll(StudyLog log, ReplayResult result);

  Future<void> close();

  // --- composed operations -----------------------------------------------------

  /// Records one answer: the attempt, the item's next schedule and its next mastery state,
  /// written in one transaction (D14). [item] is null only for an id the catalog no longer
  /// knows; its mastery is then left alone.
  ///
  /// Answers run one at a time, in call order, on the chain [rebuild] and [importLog] also
  /// join: the reads before the write span several awaits, so two overlapping answers on one
  /// item would both start from the same state and the second write would drop the first. A
  /// failed answer does not break the chain.
  Future<AnswerOutcome> recordAnswer(Attempt attempt,
          {required ItemDefLike? item, required Scheduler scheduler}) =>
      _serialized(
          () => _recordAnswer(attempt, item: item, scheduler: scheduler));

  Future<AnswerOutcome> _recordAnswer(Attempt attempt,
      {required ItemDefLike? item, required Scheduler scheduler}) async {
    final id = attempt.itemId;
    final before = await srs(id);
    final record = await this.item(id);
    final load = await loadByDay();
    _bump(load, before?.dueDay ?? record?.seedDueDay, -1);
    final nextSrs = srsAfter(scheduler, before, attempt, load);
    final nextMastery = item == null
        ? null
        : masteryAfter(
            await mastery(id) ?? MasteryState.initial(id), attempt, item);
    final written =
        await appendAttempt(attempt, srs: nextSrs, mastery: nextMastery);
    return AnswerOutcome(attempt: written, srs: nextSrs, mastery: nextMastery);
  }

  /// The whole log, for export (study_export.dart).
  Future<StudyLog> exportLog() async => StudyLog(
      attempts: await attempts(), seeds: await seeds(), notes: await notes());

  /// Rebuilds the schedule, the mastery states and the seeded due days from the log and the
  /// seed events (D14, D26), and returns what it wrote. Runs on the [recordAnswer] chain, so
  /// no answer lands between its read of the log and its write.
  Future<ReplayResult> rebuild(ItemLookup lookup, Scheduler scheduler) =>
      _serialized(() async {
        final result = replayLog(await exportLog(), lookup, scheduler);
        await replaceDerived(result);
        return result;
      });

  /// Replaces the record with [log] (an import) and the derived states with its replay, in
  /// one transaction ([replaceAll]). The replay runs first, before any write: a log it cannot
  /// replay (such as an attempt whose rating no [SrsRating] has) throws here and the record
  /// stays as it was. Runs on the [recordAnswer] chain, so no answer lands during its write.
  Future<ReplayResult> importLog(
          StudyLog log, ItemLookup lookup, Scheduler scheduler) =>
      _serialized(() async {
        final result = replayLog(log, lookup, scheduler);
        await replaceAll(log, result);
        return result;
      });
}

/// Throws when [mastery] belongs to another item than [attempt]. Both implementations call it
/// before they write anything.
void checkAnswerStates(Attempt attempt, MasteryState? mastery) {
  if (mastery != null && mastery.itemId != attempt.itemId) {
    throw ArgumentError(
        'mastery for ${mastery.itemId} written with an attempt on ${attempt.itemId}');
  }
}

/// [attempt] with the log's row id [id].
Attempt attemptWithId(Attempt attempt, int id) =>
    Attempt.fromJson({...attempt.toJson(), 'id': id});

/// The [JpStore.dueOnOrBefore] order: due day, stateful before seeded, then item id.
List<DueItem> sortDue(List<DueItem> due) => due
  ..sort((a, b) {
    final byDay = a.dueDay.compareTo(b.dueDay);
    if (byDay != 0) return byDay;
    if (a.seeded != b.seeded) return a.seeded ? 1 : -1;
    return a.itemId.compareTo(b.itemId);
  });
