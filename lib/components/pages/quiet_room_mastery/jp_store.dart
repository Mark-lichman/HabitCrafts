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
// So is a Discuss mark (PIN-6): Mark's reminder to raise an item with Mari, with an optional
// short note. A mark never reaches `replayLog`, so setting or clearing one writes no attempt and
// moves no schedule and no mastery state.
//
// 🚨 EVERY EVENT HAS A GLOBAL ID (plan 2026-11-19, Task 1, jp_event.dart). The store stamps each
// new attempt and seed with an event id and this store's device id on append. A legacy row,
// written before event ids, takes its legacy id and no device id, so every device derives the
// same legacy event; dedup keys on the event id alone (operator ruling, Checkpoint 2026-11-19).
// Replay, rebuild and import apply the log in one canonical order, event time then event id
// (`replayLog`), whatever order the rows were appended in. A note, a Discuss
// mark, a say-it score and the last lesson are side events: each change is a timestamped
// `JpEvent`, and the note, the mark and the last lesson shown are the latest event by event time
// (last write wins, PIN-12, PIN-16). A local change always lands after the subject's latest
// event, so a clock behind an earlier event never hides the change just made. Every event starts
// unpushed; `unpushedEvents`, `markPushed` and `appendRemoteEvents` are the sync seam. A remote
// event is appended once, by id; the caller rebuilds after appending attempts or seeds. Day
// records carry the device and the time that built them.
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
// an early clear, hinted or self answer alone, the same set `srsAfter` leaves alone (ASK-2), so
// an early answer short of a wrong never moves an item out of New without a schedule. Still
// select New intake items by "no SrsState and no seed", never by MasteryStatus.neu, and build
// the Not yet known and Due today sets from SrsState and seeds, not from MasteryStatus: the
// schedule, not the badge, decides what is due.
//
// `rebuild` reads the log across several awaits before it writes, and `importLog` replaces the
// whole record, so both run on the same chain as `recordAnswer` (`_serialized`): no answer reads
// its before-state on one side of a replay's write and commits on the other.

import 'dart:convert';

import 'attempt.dart';
import 'jp_event.dart';
import 'mastery_rule.dart';
import 'scheduler.dart';

/// The note the v2 grammar card's "I can use it" pill becomes (migration, Task 8).
const String kNoteCanUseIt = 'can_use_it';

/// The store flag that holds this store's device id, written once.
const String kDeviceIdMetaKey = 'sync.deviceId';

/// The event time of a note written before event ids, whose own time was never kept: the Unix
/// epoch. A fixed time keeps a legacy note the same event on every device, and any later note
/// change wins over it (PIN-12).
final DateTime kLegacyNoteAtUtc = DateTime.utc(1970);

/// How far a local change moves past its subject's latest event when the clock is not after
/// it. A millisecond, because a DateTime on some web runtimes keeps no finer time (#193).
const Duration kLocalTieBump = Duration(milliseconds: 1);

/// Assigns legacy ids ([legacyEventId]) to rows written before event ids, in append order (the
/// store's one-time migration and a pre-v3 import; operator ruling, Checkpoint 2026-11-19).
///
/// The key is the row's kind, time, item and session. A seed has no session; a note has no
/// time, so its key is the item and the note text; a Discuss mark's adds its note. A row whose
/// key repeats an earlier one takes the next occurrence, so two rows never share an id. Feed
/// the rows of one log to one instance, each kind in append order: the same log then gets the
/// same ids on every device.
class LegacyEventIds {
  final Map<String, int> _seen = {};

  String _next(JpEventKind kind, List<Object?> fields) {
    final key = jsonEncode([kind.wire, ...fields]);
    final n = _seen[key] = (_seen[key] ?? -1) + 1;
    return legacyEventId(kind, fields, occurrence: n);
  }

  /// The time cut to milliseconds: a web DateTime keeps no finer time (as [kLocalTieBump]), so
  /// a phone row with microseconds keys the same on the web. The occurrence splits a tie.
  static String _time(DateTime t) =>
      DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true)
          .toIso8601String();

  String attempt(Attempt a) =>
      _next(JpEventKind.attempt, [_time(a.atUtc), a.itemId, a.sessionId]);

  String seed(SeedEvent s) =>
      _next(JpEventKind.seed, [_time(s.atUtc), s.itemId, null]);

  String note(String itemId, String note) =>
      _next(JpEventKind.note, [null, itemId, null, note]);

  String discuss(DiscussMark m) =>
      _next(JpEventKind.discuss, [_time(m.atUtc), m.itemId, null, m.note]);
}

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
    this.eventId,
    this.deviceId,
  });

  /// The log's row id, assigned by the store; null before it is written.
  final int? id;
  final String itemId;
  final int dueDay;
  final DateTime atUtc;

  /// The global event id; the store assigns it on append when it is null.
  final String? eventId;

  /// The device that logged the seed; the store fills it on append when the seed has no
  /// [eventId]. A legacy seed, logged before event ids, keeps none.
  final String? deviceId;

  SeedEvent withId(int id) => SeedEvent(
      id: id,
      itemId: itemId,
      dueDay: dueDay,
      atUtc: atUtc,
      eventId: eventId,
      deviceId: deviceId);

  SeedEvent withEvent({required String eventId, required String? deviceId}) =>
      SeedEvent(
          id: id,
          itemId: itemId,
          dueDay: dueDay,
          atUtc: atUtc,
          eventId: eventId,
          deviceId: deviceId);

  /// The two event fields are written only when set, after every other field.
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'itemId': itemId,
        'dueDay': dueDay,
        'atUtc': atUtc.toUtc().toIso8601String(),
        if (eventId != null) 'eventId': eventId,
        if (deviceId != null) 'deviceId': deviceId,
      };

  factory SeedEvent.fromJson(Map<String, dynamic> j) => SeedEvent(
        id: j['id'] as int?,
        itemId: j['itemId'] as String,
        dueDay: j['dueDay'] as int,
        atUtc: DateTime.parse(j['atUtc'] as String).toUtc(),
        eventId: j['eventId'] as String?,
        deviceId: j['deviceId'] as String?,
      );

  /// Compares the seed and its row id; the event id and the device id are left out, like
  /// [Attempt]'s.
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

/// Mark's reminder to raise an item with Mari (PIN-6), with an optional short note. Kept beside
/// the log, carried by export and import, and read by nothing that grades or schedules.
class DiscussMark {
  const DiscussMark({required this.itemId, this.note, required this.atUtc});

  final String itemId;

  /// Null when the mark has no note. [JpStore.setDiscuss] trims it and stores a blank as null.
  final String? note;

  /// When the mark was last set.
  final DateTime atUtc;

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        if (note != null) 'note': note,
        'atUtc': atUtc.toUtc().toIso8601String(),
      };

  factory DiscussMark.fromJson(Map<String, dynamic> j) => DiscussMark(
        itemId: j['itemId'] as String,
        note: j['note'] as String?,
        atUtc: DateTime.parse(j['atUtc'] as String).toUtc(),
      );

  @override
  bool operator ==(Object other) =>
      other is DiscussMark &&
      other.itemId == itemId &&
      other.note == note &&
      other.atUtc.toUtc() == atUtc.toUtc();

  @override
  int get hashCode => Object.hash(itemId, note, atUtc.toUtc());

  @override
  String toString() => 'DiscussMark($itemId${note == null ? '' : ': $note'})';
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
    this.deviceId,
    this.builtAtUtc,
  });

  final int day;

  /// The plan, JSON-encoded by its owner. The store never reads inside it.
  final String plan;

  /// The index of the next entry to show.
  final int position;
  final bool completed;

  /// The device that built the plan. [JpStore.putDay] fills it when it is null; a day stored
  /// before event ids carries the migrating device.
  final String? deviceId;

  /// When the plan was built. [JpStore.putDay] fills it when it is null on a new plan. Null on
  /// a day stored before event ids, whose build time nobody recorded; a move through that
  /// plan keeps it null, so no build time is invented (#191).
  final DateTime? builtAtUtc;

  /// Whether the record shows an answer: a position above 0, or completed (operator rulings
  /// ASK-5 and ASK-7). A plan stored and never answered shows none.
  bool get answered => position > 0 || completed;

  /// Keeps the builder and the build time: a move through the plan does not rebuild it.
  DayRecord copyWith({String? plan, int? position, bool? completed}) =>
      DayRecord(
        day: day,
        plan: plan ?? this.plan,
        position: position ?? this.position,
        completed: completed ?? this.completed,
        deviceId: deviceId,
        builtAtUtc: builtAtUtc,
      );

  /// This record with its builder and build time set.
  DayRecord withBuilder(String deviceId, DateTime? builtAtUtc) => DayRecord(
        day: day,
        plan: plan,
        position: position,
        completed: completed,
        deviceId: deviceId,
        builtAtUtc: builtAtUtc?.toUtc(),
      );

  /// Compares the day's content: the builder and the build time are left out, so a record
  /// compares equal before and after the store stamps them.
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

/// Everything export writes and import reads: the two event logs, the notes, the Discuss marks
/// and the side events behind them. The replay reads only the two logs.
///
/// [events] holds every side event: note, Discuss, say-it score and last-lesson changes, oldest
/// first. [notes] and [discuss] are what those events resolve to. A log from before event ids
/// (an old export, or one built by hand) has notes and marks with no event; the store gives
/// each one an event when it imports the log ([JpStore.prepareLog]).
class StudyLog {
  const StudyLog({
    this.attempts = const [],
    this.seeds = const [],
    this.notes = const {},
    this.discuss = const {},
    this.events = const [],
  });

  /// Oldest first, in append order.
  final List<Attempt> attempts;

  /// Oldest first, in append order.
  final List<SeedEvent> seeds;

  /// Item id to note.
  final Map<String, String> notes;

  /// Item id to Discuss mark (PIN-6).
  final Map<String, DiscussMark> discuss;

  /// The side events, oldest first by [compareEvents].
  final List<JpEvent> events;

  /// A log whose notes and marks are [events] resolved, plus the [legacyNotes] and
  /// [legacyDiscuss] of items no note or Discuss event names.
  factory StudyLog.resolved({
    List<Attempt> attempts = const [],
    List<SeedEvent> seeds = const [],
    Map<String, String> legacyNotes = const {},
    Map<String, DiscussMark> legacyDiscuss = const {},
    List<JpEvent> events = const [],
  }) {
    final sorted = [...events]..sort(compareEvents);
    final noted = {
      for (final e in sorted)
        if (e.kind == JpEventKind.note) e.subject
    };
    final marked = {
      for (final e in sorted)
        if (e.kind == JpEventKind.discuss) e.subject
    };
    return StudyLog(
      attempts: attempts,
      seeds: seeds,
      notes: {
        for (final e in legacyNotes.entries)
          if (!noted.contains(e.key)) e.key: e.value,
        ...resolveNotes(sorted),
      },
      discuss: {
        for (final e in legacyDiscuss.entries)
          if (!marked.contains(e.key)) e.key: e.value,
        ...resolveDiscuss(sorted),
      },
      events: sorted,
    );
  }
}

// --- events ----------------------------------------------------------------------

/// The attempt as an event; a legacy attempt's has no device id. Throws a [StateError] for an
/// attempt with no event id.
JpEvent attemptEvent(Attempt attempt) {
  final eventId = attempt.eventId;
  if (eventId == null) {
    throw StateError('attempt on ${attempt.itemId} has no event id');
  }
  return JpEvent(
      eventId: eventId,
      deviceId: attempt.deviceId,
      atUtc: attempt.atUtc,
      kind: JpEventKind.attempt,
      body: attempt.toJson()
        ..remove('id')
        ..remove('eventId')
        ..remove('deviceId'));
}

/// The seed as an event; a legacy seed's has no device id. Throws a [StateError] for a seed
/// with no event id.
JpEvent seedEvent(SeedEvent seed) {
  final eventId = seed.eventId;
  if (eventId == null) {
    throw StateError('seed of ${seed.itemId} has no event id');
  }
  return JpEvent(
      eventId: eventId,
      deviceId: seed.deviceId,
      atUtc: seed.atUtc,
      kind: JpEventKind.seed,
      body: seed.toJson()
        ..remove('id')
        ..remove('eventId')
        ..remove('deviceId'));
}

/// The attempt an attempt event carries, with no row id.
Attempt attemptOfEvent(JpEvent e) => Attempt.fromJson({
      ...e.body,
      'eventId': e.eventId,
      if (e.deviceId != null) 'deviceId': e.deviceId
    }..remove('id'));

/// The seed a seed event carries, with no row id.
SeedEvent seedOfEvent(JpEvent e) => SeedEvent.fromJson({
      ...e.body,
      'eventId': e.eventId,
      if (e.deviceId != null) 'deviceId': e.deviceId
    }..remove('id'));

/// A note event: [note] set on [itemId], or cleared when null. A legacy note has no
/// [deviceId].
JpEvent noteEvent(String itemId, String? note,
        {required String eventId,
        required String? deviceId,
        required DateTime atUtc}) =>
    JpEvent(
        eventId: eventId,
        deviceId: deviceId,
        atUtc: atUtc,
        kind: JpEventKind.note,
        body: {'itemId': itemId, 'note': note});

/// A Discuss event: [mark] set, its time the event time; or, with [cleared], [itemId]'s mark
/// cleared. A legacy mark has no [deviceId].
JpEvent discussEvent(String itemId,
    {String? note,
    bool cleared = false,
    required String eventId,
    required String? deviceId,
    required DateTime atUtc}) {
  return JpEvent(
      eventId: eventId,
      deviceId: deviceId,
      atUtc: atUtc,
      kind: JpEventKind.discuss,
      body: {
        'itemId': itemId,
        if (!cleared && note != null) 'note': note,
        if (cleared) 'cleared': true,
      });
}

/// Item id to note, by the latest note event per item (PIN-12). Pure.
Map<String, String> resolveNotes(Iterable<JpEvent> events) => {
      for (final e in latestBySubject(events, JpEventKind.note).entries)
        if (e.value.body['note'] is String)
          e.key: e.value.body['note'] as String
    };

/// Item id to Discuss mark, by the latest Discuss event per item (PIN-12). The mark's time is
/// its event's. Pure.
Map<String, DiscussMark> resolveDiscuss(Iterable<JpEvent> events) => {
      for (final e in latestBySubject(events, JpEventKind.discuss).entries)
        if (e.value.body['cleared'] != true)
          e.key: DiscussMark(
              itemId: e.key,
              note: e.value.body['note'] as String?,
              atUtc: e.value.atUtc)
    };

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

/// [rows] in the canonical replay order: event time, then event id (operator ruling,
/// Checkpoint 2026-11-19). A row with no event id (a log built by hand or read below the
/// current schema) sorts before an id at the same time, and rows that tie on both keep their
/// order. Pure; [rows] is not changed.
List<T> canonicalOrder<T>(List<T> rows, DateTime Function(T row) atUtc,
    String? Function(T row) eventId) {
  final indexed = [for (var i = 0; i < rows.length; i++) (i, rows[i])];
  indexed.sort((x, y) {
    final byTime = atUtc(x.$2).toUtc().compareTo(atUtc(y.$2).toUtc());
    if (byTime != 0) return byTime;
    final byId = (eventId(x.$2) ?? '').compareTo(eventId(y.$2) ?? '');
    return byId != 0 ? byId : x.$1.compareTo(y.$1);
  });
  return [for (final r in indexed) r.$2];
}

/// Replays the log from nothing (D14, D26). Seeds and attempts are applied in the canonical
/// order ([canonicalOrder]: event time, then event id), a seed before an attempt at the same
/// instant, so two devices that hold the same events in different row orders land on the same
/// states. A seed keeps the earliest due day per item. Pure.
ReplayResult replayLog(StudyLog log, ItemLookup lookup, Scheduler scheduler) {
  final srs = <String, SrsState>{};
  final mastery = <String, MasteryState>{};
  final seedDue = <String, int>{};
  final load = <int, int>{};
  int? dueOf(String id) => srs[id]?.dueDay ?? seedDue[id];

  final seeds = canonicalOrder(log.seeds, (s) => s.atUtc, (s) => s.eventId);
  final attempts =
      canonicalOrder(log.attempts, (a) => a.atUtc, (a) => a.eventId);
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
  /// [clock] gives the time of a note change, a Discuss clear and a day plan's build; the
  /// system clock by default.
  JpStore({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final DateTime Function() clock;

  DateTime _nowUtc() => clock().toUtc();

  Future<String>? _deviceId;

  /// This store's device id: read from [kDeviceIdMetaKey], or created there on first use and
  /// kept. A failed read is not kept, so the next call tries again.
  Future<String> deviceId() => _deviceId ??= () async {
        final kept = await meta(kDeviceIdMetaKey);
        if (kept != null) return kept;
        final id = newEventId();
        await putMeta(kDeviceIdMetaKey, id);
        return id;
      }()
          .catchError((Object e) {
        _deviceId = null;
        throw e;
      });

  /// [attempt] with a new event id and this store's device id when it has no event id. An
  /// attempt that has one (an import, a remote, a legacy row) is kept as it is. Each
  /// implementation calls it before it writes an attempt.
  Future<Attempt> stampAttempt(Attempt attempt) async => attempt.eventId != null
      ? attempt
      : attempt.withEvent(
          eventId: newEventId(),
          deviceId: attempt.deviceId ?? await deviceId());

  /// [seed] with a new event id and this store's device id when it has no event id.
  Future<SeedEvent> stampSeed(SeedEvent seed) async => seed.eventId != null
      ? seed
      : seed.withEvent(
          eventId: newEventId(), deviceId: seed.deviceId ?? await deviceId());

  /// [record] with its builder and build time. A record that leaves either out keeps the
  /// stored record's when the plan is the same one (a position move), even a null build time
  /// on a day stored before event ids (#191). A new plan is otherwise built now on this device.
  Future<DayRecord> stampDay(DayRecord record) async {
    if (record.deviceId != null && record.builtAtUtc != null) return record;
    final old = await day(record.day);
    if (old != null && old.plan == record.plan) {
      return record.withBuilder(
          record.deviceId ?? old.deviceId ?? await deviceId(),
          record.builtAtUtc ?? old.builtAtUtc);
    }
    return record.withBuilder(
        record.deviceId ?? await deviceId(), record.builtAtUtc ?? _nowUtc());
  }

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
  /// when given (one transaction per answer, D14). Returns the attempt with its row id, its
  /// event id and its device id ([stampAttempt]); it starts unpushed. Throws an
  /// [ArgumentError], and writes nothing, when [mastery] names another item.
  Future<Attempt> appendAttempt(Attempt attempt,
      {SrsState? srs, MasteryState? mastery});

  /// Appends seed events in one transaction, each stamped ([stampSeed]) and unpushed. Each
  /// item keeps its earliest seeded due day. Writes no attempt, no schedule and no mastery
  /// (PIN-7).
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

  /// Sets or, with null, clears the item's note, as a note event at the [clock]'s time
  /// (PIN-12). Clearing an item with no note writes nothing.
  Future<void> setNote(String itemId, String? note) async {
    if (note == null && (await item(itemId))?.note == null) return;
    await appendLocalEvent(JpEventKind.note, {'itemId': itemId, 'note': note});
  }

  /// Every note, by item id.
  Future<Map<String, String>> notes();

  /// Sets the item's Discuss mark (PIN-6), replacing any earlier one. [note] is trimmed, and a
  /// blank note is stored as none. Writes no attempt, no schedule and no mastery.
  Future<void> setDiscuss(String itemId,
          {String? note, required DateTime atUtc}) =>
      putDiscuss(DiscussMark(
          itemId: itemId,
          note: (note == null || note.trim().isEmpty) ? null : note.trim(),
          atUtc: atUtc.toUtc()));

  /// Writes [mark] as given, as a Discuss event at the mark's time (PIN-12). [setDiscuss] is
  /// the caller; it normalises the note.
  Future<void> putDiscuss(DiscussMark mark) => appendLocalEvent(
      JpEventKind.discuss,
      {'itemId': mark.itemId, if (mark.note != null) 'note': mark.note},
      atUtc: mark.atUtc);

  /// Clears the item's Discuss mark, if any, as a Discuss event at the [clock]'s time. Writes
  /// nothing else, and nothing at all for an unmarked item.
  Future<void> clearDiscuss(String itemId) async {
    if (await discuss(itemId) == null) return;
    await appendLocalEvent(
        JpEventKind.discuss, {'itemId': itemId, 'cleared': true});
  }

  /// The item's Discuss mark; null when it has none.
  Future<DiscussMark?> discuss(String itemId);

  /// Every Discuss mark, by item id.
  Future<Map<String, DiscussMark>> discussMarks();

  /// Every item due on or before [day]: stateful items by their FSRS due day, and seeded
  /// items with no FSRS state by their seeded due day (D26). Sorted by due day, stateful
  /// before seeded, then by item id. The plan builder orders them for the session.
  Future<List<DueItem>> dueOnOrBefore(int day);

  /// Local day to the number of items due on it, by the same rule as [dueOnOrBefore].
  Future<Map<int, int>> loadByDay();

  // --- the days --------------------------------------------------------------

  Future<DayRecord?> day(int day);

  /// Writes the day's record, replacing any earlier one for the same day. The record is
  /// stamped first ([stampDay]), so it carries its builder and build time.
  Future<void> putDay(DayRecord record);

  /// The latest local day with a [DayRecord], or null before the first session.
  Future<int?> lastDay();

  // --- bookkeeping -----------------------------------------------------------

  /// A store-level flag, such as the one-time v2 migration's.
  Future<String?> meta(String key);
  Future<void> putMeta(String key, String value);

  /// Replaces the schedule, the mastery states and the seeded due days in one transaction.
  /// Notes, Discuss marks, the log, the days and the flags stay.
  Future<void> replaceDerived(ReplayResult result);

  /// Replaces the log, the side events, the notes and the Discuss marks with [log] and the
  /// derived states with [result], in one transaction: a write that fails leaves the old log,
  /// caches, notes and marks in place. The days and the flags stay. Each implementation runs
  /// [prepareLog] first, so every imported event has an id. An event already pushed from this
  /// store stays pushed. [importLog] is its caller; [result] is [log]'s replay.
  Future<void> replaceAll(StudyLog log, ReplayResult result);

  Future<void> close();

  // --- side events and sync ----------------------------------------------------

  /// Every side event (note, Discuss, say-it score, last lesson), oldest first by
  /// [compareEvents].
  Future<List<JpEvent>> sideEvents();

  /// Appends one side event, unpushed, and moves the note or Discuss mark it names to the
  /// latest event for that item. Callers go through [appendLocalEvent].
  Future<void> writeSideEvent(JpEvent event);

  /// Appends a side event of [kind] written on this device, at [atUtc] or the [clock]'s time.
  /// An event that replaces (a note, a mark, the last lesson) lands at least [kLocalTieBump]
  /// after its subject's latest event, so a change made here always shows here. Returns it.
  Future<JpEvent> appendLocalEvent(JpEventKind kind, Map<String, dynamic> body,
      {DateTime? atUtc}) async {
    var at = (atUtc ?? _nowUtc()).toUtc();
    final draft = JpEvent(
        eventId: newEventId(),
        deviceId: await deviceId(),
        atUtc: at,
        kind: kind,
        body: body);
    final subject = draft.subject;
    if (subject != null) {
      final latest = latestBySubject(await sideEvents(), kind)[subject];
      if (latest != null && !at.isAfter(latest.atUtc)) {
        at = latest.atUtc.add(kLocalTieBump);
      }
    }
    final event = JpEvent(
        eventId: draft.eventId,
        deviceId: draft.deviceId,
        atUtc: at,
        kind: kind,
        body: draft.body);
    await writeSideEvent(event);
    return event;
  }

  /// Logs one say-it score (PIN-16). [score] is the score log's own entry; the store never
  /// reads inside it.
  Future<JpEvent> recordSpeakScore(Map<String, dynamic> score,
          {required DateTime atUtc}) =>
      appendLocalEvent(JpEventKind.speakScore, score, atUtc: atUtc);

  /// The say-it score events, oldest first.
  Future<List<JpEvent>> speakScores() async => [
        for (final e in await sideEvents())
          if (e.kind == JpEventKind.speakScore) e
      ];

  /// Records [lessonId] as the last grammar lesson opened (PIN-16).
  Future<JpEvent> setLastLesson(String lessonId, {required DateTime atUtc}) =>
      appendLocalEvent(JpEventKind.lastLesson, {'lessonId': lessonId},
          atUtc: atUtc);

  /// The last grammar lesson opened, by the latest event time; null before the first.
  Future<String?> lastLesson() async => resolveLastLesson(await sideEvents());

  /// Every event this store has not pushed yet, of every kind, oldest first by
  /// [compareEvents].
  Future<List<JpEvent>> unpushedEvents();

  /// Marks the events with [eventIds] pushed. An id the store does not hold is ignored.
  Future<void> markPushed(Iterable<String> eventIds);

  /// Appends [events] from another device, each once: an event id the store already holds, or
  /// one repeated in [events], is skipped. They land pushed. A note or Discuss event moves the
  /// item's note or mark when it is the latest for that item. Attempts and seeds join the log
  /// but leave the schedule and the mastery states as they were: the caller [rebuild]s. Runs
  /// on the [recordAnswer] chain. Returns the events appended.
  Future<List<JpEvent>> appendRemoteEvents(Iterable<JpEvent> events) {
    final seen = <String>{};
    final fresh = [
      for (final e in events)
        if (seen.add(e.eventId)) e
    ];
    return _serialized(() => writeRemoteEvents(fresh));
  }

  /// Appends [events], whose ids are distinct, skipping the ids the store holds, in one
  /// transaction. [appendRemoteEvents] is its caller.
  Future<List<JpEvent>> writeRemoteEvents(List<JpEvent> events);

  /// Every event the store holds, of every kind, oldest first by [compareEvents]. An attempt
  /// or seed with no event id (only in a file a test opens below the current schema) is left
  /// out.
  Future<List<JpEvent>> allEvents() async => [
        for (final a in await attempts())
          if (a.eventId != null) attemptEvent(a),
        for (final s in await seeds())
          if (s.eventId != null) seedEvent(s),
        ...await sideEvents(),
      ]..sort(compareEvents);

  /// [log] with an event id on every attempt and seed, and an event for each note and Discuss
  /// mark no event names. The notes and marks are then the events resolved.
  ///
  /// An id-less row (a pre-v3 import) first reuses the event this store holds for the same
  /// row: an attempt or seed with the same content, a note event with the same item and text,
  /// a Discuss event with the same item, note and time. It keeps that event's id, device and
  /// time. Otherwise it takes its legacy id ([LegacyEventIds]) and no device id; a note takes
  /// [kLegacyNoteAtUtc] and a mark its own time. So a restored old backup maps onto the events
  /// this store or another device already holds, byte for byte (operator ruling, Checkpoint
  /// 2026-11-19).
  Future<StudyLog> prepareLog(StudyLog log) async {
    final legacy = LegacyEventIds();
    final heldAttempts = <String, List<Attempt>>{};
    for (final a in await attempts()) {
      if (a.eventId == null) continue;
      heldAttempts.putIfAbsent(_attemptKey(a), () => []).add(a);
    }
    final heldSeeds = <String, List<SeedEvent>>{};
    for (final s in await seeds()) {
      if (s.eventId == null) continue;
      heldSeeds.putIfAbsent(_seedKey(s), () => []).add(s);
    }
    final heldSide = await sideEvents();
    final used = <String>{};
    JpEvent? heldSideEvent(bool Function(JpEvent e) match) {
      JpEvent? best;
      for (final e in heldSide) {
        if (used.contains(e.eventId) || !match(e)) continue;
        if (best == null || compareEvents(e, best) > 0) best = e;
      }
      if (best != null) used.add(best.eventId);
      return best;
    }

    final events = [...log.events];
    final noted = {
      for (final e in events)
        if (e.kind == JpEventKind.note) e.subject
    };
    final marked = {
      for (final e in events)
        if (e.kind == JpEventKind.discuss) e.subject
    };
    for (final n in log.notes.entries) {
      if (noted.contains(n.key)) continue;
      final id = legacy.note(n.key, n.value);
      events.add(heldSideEvent((e) =>
              e.kind == JpEventKind.note &&
              e.subject == n.key &&
              e.body['note'] == n.value) ??
          noteEvent(n.key, n.value,
              eventId: id, deviceId: null, atUtc: kLegacyNoteAtUtc));
    }
    for (final m in log.discuss.values) {
      if (marked.contains(m.itemId)) continue;
      final id = legacy.discuss(m);
      events.add(heldSideEvent((e) =>
              e.kind == JpEventKind.discuss &&
              e.subject == m.itemId &&
              e.body['cleared'] != true &&
              e.body['note'] == m.note &&
              e.atUtc == m.atUtc.toUtc()) ??
          discussEvent(m.itemId,
              note: m.note, eventId: id, deviceId: null, atUtc: m.atUtc));
    }
    T? take<T>(Map<String, List<T>> held, String key) {
      final queue = held[key];
      return queue == null || queue.isEmpty ? null : queue.removeAt(0);
    }

    return StudyLog.resolved(
      attempts: [
        for (final a in log.attempts)
          if (a.eventId != null)
            a
          else
            () {
              final id = legacy.attempt(a);
              final held = take(heldAttempts, _attemptKey(a));
              return a.withEvent(
                  eventId: held?.eventId ?? id, deviceId: held?.deviceId);
            }()
      ],
      seeds: [
        for (final s in log.seeds)
          if (s.eventId != null)
            s
          else
            () {
              final id = legacy.seed(s);
              final held = take(heldSeeds, _seedKey(s));
              return s.withEvent(
                  eventId: held?.eventId ?? id, deviceId: held?.deviceId);
            }()
      ],
      events: events,
    );
  }

  /// An attempt's content, without its row id and event fields.
  static String _attemptKey(Attempt a) => jsonEncode(a.toJson()
    ..remove('id')
    ..remove('eventId')
    ..remove('deviceId'));

  /// A seed's content, without its row id and event fields.
  static String _seedKey(SeedEvent s) => jsonEncode(s.toJson()
    ..remove('id')
    ..remove('eventId')
    ..remove('deviceId'));

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

  /// The whole log, for export (study_export.dart): the two logs, the notes, the marks and
  /// every side event.
  Future<StudyLog> exportLog() async => StudyLog(
      attempts: await attempts(),
      seeds: await seeds(),
      notes: await notes(),
      discuss: await discussMarks(),
      events: await sideEvents());

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
