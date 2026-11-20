// The in-memory study store: a fast store for tests and the simulator, and the working copy
// under the web store (jp_store_web.dart), which saves its snapshot ([toSnapshot]) in the
// browser after each write (A4). Same contract as `JpStoreSqlite`; the shared suite in
// test/jp_store_test.dart runs against all three. Every write is synchronous inside one call
// once its event ids are stamped, so an answer's attempt, schedule and mastery land together or
// not at all. A fresh memory store holds no rows from before event ids, so it needs no
// migration.

import 'attempt.dart';
import 'jp_event.dart';
import 'jp_store.dart';
import 'mastery_rule.dart';
import 'scheduler.dart';

class JpStoreMemory extends JpStore {
  JpStoreMemory({super.clock});

  final List<Attempt> _attempts = [];
  final List<SeedEvent> _seeds = [];

  /// The side events, in append order.
  final List<JpEvent> _events = [];

  /// The ids of every event pushed or appended from a remote.
  final Set<String> _pushed = {};
  final Map<String, SrsState> _srs = {};
  final Map<String, MasteryState> _mastery = {};
  final Map<String, int> _seedDue = {};
  final Map<String, String> _notes = {};
  final Map<String, DiscussMark> _discuss = {};
  final Map<int, DayRecord> _days = {};
  final Map<String, String> _meta = {};
  int _attemptSeq = 0;
  int _seedSeq = 0;

  @override
  Future<Attempt> appendAttempt(Attempt attempt,
      {SrsState? srs, MasteryState? mastery}) async {
    checkAnswerStates(attempt, mastery);
    final stamped = await stampAttempt(attempt);
    final written = attemptWithId(stamped, ++_attemptSeq);
    _attempts.add(written);
    if (srs != null) _srs[attempt.itemId] = srs;
    if (mastery != null) _mastery[attempt.itemId] = mastery;
    return written;
  }

  void _addSeed(SeedEvent s) {
    _seeds.add(s.withId(++_seedSeq));
    final old = _seedDue[s.itemId];
    if (old == null || s.dueDay < old) _seedDue[s.itemId] = s.dueDay;
  }

  @override
  Future<void> appendSeeds(Iterable<SeedEvent> seeds) async {
    final stamped = [for (final s in seeds) await stampSeed(s)];
    stamped.forEach(_addSeed);
  }

  @override
  Future<List<Attempt>> attempts({String? itemId}) async => [
        for (final a in _attempts)
          if (itemId == null || a.itemId == itemId) a
      ];

  @override
  Future<List<SeedEvent>> seeds() async => [..._seeds];

  @override
  Future<SrsState?> srs(String itemId) async => _srs[itemId];

  @override
  Future<void> putSrs(String itemId, SrsState state) async =>
      _srs[itemId] = state;

  @override
  Future<Map<String, SrsState>> allSrs() async => {..._srs};

  @override
  Future<MasteryState?> mastery(String itemId) async => _mastery[itemId];

  @override
  Future<void> putMastery(MasteryState state) async =>
      _mastery[state.itemId] = state;

  @override
  Future<Map<String, MasteryState>> allMastery() async => {..._mastery};

  @override
  Future<ItemRecord?> item(String itemId) async {
    final due = _seedDue[itemId];
    final note = _notes[itemId];
    if (due == null && note == null) return null;
    return ItemRecord(itemId: itemId, seedDueDay: due, note: note);
  }

  @override
  Future<Map<String, String>> notes() async => {..._notes};

  @override
  Future<DiscussMark?> discuss(String itemId) async => _discuss[itemId];

  @override
  Future<Map<String, DiscussMark>> discussMarks() async => {..._discuss};

  Iterable<DueItem> get _allDue sync* {
    for (final e in _srs.entries) {
      yield DueItem(itemId: e.key, dueDay: e.value.dueDay, seeded: false);
    }
    for (final e in _seedDue.entries) {
      if (!_srs.containsKey(e.key)) {
        yield DueItem(itemId: e.key, dueDay: e.value, seeded: true);
      }
    }
  }

  @override
  Future<List<DueItem>> dueOnOrBefore(int day) async =>
      sortDue([..._allDue.where((d) => d.dueDay <= day)]);

  @override
  Future<Map<int, int>> loadByDay() async {
    final load = <int, int>{};
    for (final d in _allDue) {
      load[d.dueDay] = (load[d.dueDay] ?? 0) + 1;
    }
    return load;
  }

  @override
  Future<DayRecord?> day(int day) async => _days[day];

  @override
  Future<void> putDay(DayRecord record) async {
    final stamped = await stampDay(record);
    _days[stamped.day] = stamped;
  }

  @override
  Future<int?> lastDay() async =>
      _days.isEmpty ? null : _days.keys.reduce((a, b) => a > b ? a : b);

  @override
  Future<String?> meta(String key) async => _meta[key];

  @override
  Future<void> putMeta(String key, String value) async => _meta[key] = value;

  // --- side events and sync ----------------------------------------------------

  /// Moves the note or Discuss mark [event] names to the latest event for its item.
  void _refresh(JpEvent event) {
    final id = event.subject;
    if (id == null) return;
    if (event.kind == JpEventKind.note) {
      final note = resolveNotes(_events)[id];
      note == null ? _notes.remove(id) : _notes[id] = note;
    } else if (event.kind == JpEventKind.discuss) {
      final mark = resolveDiscuss(_events)[id];
      mark == null ? _discuss.remove(id) : _discuss[id] = mark;
    }
  }

  @override
  Future<List<JpEvent>> sideEvents() async => [..._events]..sort(compareEvents);

  @override
  Future<void> writeSideEvent(JpEvent event) async {
    _events.add(event);
    _refresh(event);
  }

  @override
  Future<List<JpEvent>> unpushedEvents() async => [
        for (final e in await allEvents())
          if (!_pushed.contains(e.eventId)) e
      ];

  @override
  Future<void> markPushed(Iterable<String> eventIds) async {
    final held = {for (final e in await allEvents()) e.eventId};
    _pushed.addAll(eventIds.where(held.contains));
  }

  @override
  Future<List<JpEvent>> writeRemoteEvents(List<JpEvent> events) async {
    final held = {for (final e in await allEvents()) e.eventId};
    final added = <JpEvent>[];
    for (final e in events) {
      if (held.contains(e.eventId)) continue;
      switch (e.kind) {
        case JpEventKind.attempt:
          _attempts.add(attemptWithId(attemptOfEvent(e), ++_attemptSeq));
        case JpEventKind.seed:
          _addSeed(seedOfEvent(e));
        case JpEventKind.note:
        case JpEventKind.discuss:
        case JpEventKind.speakScore:
        case JpEventKind.lastLesson:
          _events.add(e);
          _refresh(e);
      }
      _pushed.add(e.eventId);
      added.add(e);
    }
    return added;
  }

  void _writeDerived(ReplayResult result) {
    _srs
      ..clear()
      ..addAll(result.srs);
    _mastery
      ..clear()
      ..addAll(result.mastery);
    _seedDue
      ..clear()
      ..addAll(result.seedDue);
  }

  /// Writes a prepared log ([prepareLog]): every attempt and seed has an event id.
  void _writeLog(StudyLog log) {
    final ids = <String>{
      for (final a in log.attempts) a.eventId!,
      for (final s in log.seeds) s.eventId!,
      for (final e in log.events) e.eventId,
    };
    _pushed.retainWhere(ids.contains);
    _attempts.clear();
    _seeds.clear();
    _attemptSeq = 0;
    _seedSeq = 0;
    for (final a in log.attempts) {
      _attempts.add(attemptWithId(a, ++_attemptSeq));
    }
    for (final s in log.seeds) {
      _seeds.add(s.withId(++_seedSeq));
    }
    _events
      ..clear()
      ..addAll(log.events);
    _notes
      ..clear()
      ..addAll(log.notes);
    _discuss
      ..clear()
      ..addAll(log.discuss);
  }

  @override
  Future<void> replaceDerived(ReplayResult result) async =>
      _writeDerived(result);

  /// One synchronous block, no await between the log and the states.
  @override
  Future<void> replaceAll(StudyLog log, ReplayResult result) async {
    final prepared = await prepareLog(log);
    _writeLog(prepared);
    _writeDerived(result);
  }

  @override
  Future<void> close() async {}

  // --- the snapshot ------------------------------------------------------------

  /// Everything this store holds as JSON values: the logs with their row ids, event ids and
  /// pushed marks, the derived states, the days and the meta. [restoreSnapshot] reads it back.
  /// The web store (jp_store_web.dart) keeps it in the browser between loads.
  Map<String, dynamic> toSnapshot() => {
        'attempts': [for (final a in _attempts) a.toJson()],
        'seeds': [for (final s in _seeds) s.toJson()],
        'events': [for (final e in _events) e.toFirestore()],
        'pushed': [..._pushed],
        'srs': {for (final e in _srs.entries) e.key: e.value.toJson()},
        'mastery': {for (final e in _mastery.entries) e.key: e.value.toJson()},
        'seedDue': {..._seedDue},
        'notes': {..._notes},
        'discuss': {for (final e in _discuss.entries) e.key: e.value.toJson()},
        'days': [
          for (final d in _days.values)
            {
              'day': d.day,
              'plan': d.plan,
              'position': d.position,
              'completed': d.completed,
              if (d.deviceId != null) 'deviceId': d.deviceId,
              if (d.builtAtUtc != null)
                'builtAtUtc': d.builtAtUtc!.toUtc().toIso8601String(),
            }
        ],
        'meta': {..._meta},
        'attemptSeq': _attemptSeq,
        'seedSeq': _seedSeq,
      };

  /// Replaces everything this store holds with [snapshot] ([toSnapshot]'s form). Throws, and
  /// changes nothing, when a field is missing or of the wrong type.
  void restoreSnapshot(Map<String, dynamic> snapshot) {
    Map<String, dynamic> obj(Object? v) => Map<String, dynamic>.from(v as Map);
    Map<String, dynamic> field(String k) => obj(snapshot[k]);
    List<Object?> list(String k) => snapshot[k] as List<Object?>;
    final attempts = [
      for (final a in list('attempts')) Attempt.fromJson(obj(a))
    ];
    final seeds = [for (final s in list('seeds')) SeedEvent.fromJson(obj(s))];
    final events = [
      for (final e in list('events')) JpEvent.fromFirestore(obj(e))
    ];
    final pushed = {for (final id in list('pushed')) id as String};
    final srs = {
      for (final e in field('srs').entries)
        e.key: SrsState.fromJson(obj(e.value))
    };
    final mastery = {
      for (final e in field('mastery').entries)
        e.key: MasteryState.fromJson(obj(e.value))
    };
    final seedDue = {
      for (final e in field('seedDue').entries) e.key: e.value as int
    };
    final notes = {
      for (final e in field('notes').entries) e.key: e.value as String
    };
    final discuss = {
      for (final e in field('discuss').entries)
        e.key: DiscussMark.fromJson(obj(e.value))
    };
    final days = <int, DayRecord>{};
    for (final raw in list('days')) {
      final d = obj(raw);
      final built = d['builtAtUtc'] as String?;
      final record = DayRecord(
        day: d['day'] as int,
        plan: d['plan'] as String,
        position: d['position'] as int,
        completed: d['completed'] as bool,
        deviceId: d['deviceId'] as String?,
        builtAtUtc: built == null ? null : DateTime.parse(built).toUtc(),
      );
      days[record.day] = record;
    }
    final meta = {
      for (final e in field('meta').entries) e.key: e.value as String
    };
    final attemptSeq = snapshot['attemptSeq'] as int;
    final seedSeq = snapshot['seedSeq'] as int;

    _attempts
      ..clear()
      ..addAll(attempts);
    _seeds
      ..clear()
      ..addAll(seeds);
    _events
      ..clear()
      ..addAll(events);
    _pushed
      ..clear()
      ..addAll(pushed);
    _srs
      ..clear()
      ..addAll(srs);
    _mastery
      ..clear()
      ..addAll(mastery);
    _seedDue
      ..clear()
      ..addAll(seedDue);
    _notes
      ..clear()
      ..addAll(notes);
    _discuss
      ..clear()
      ..addAll(discuss);
    _days
      ..clear()
      ..addAll(days);
    _meta
      ..clear()
      ..addAll(meta);
    _attemptSeq = attemptSeq;
    _seedSeq = seedSeq;
  }
}
