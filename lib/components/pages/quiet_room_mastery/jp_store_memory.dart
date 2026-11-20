// The in-memory study store: the store on web, where nothing persists between loads (A4), and
// a fast store for tests and the simulator. Same contract as `JpStoreSqlite`; the shared suite
// in test/jp_store_test.dart runs against both. Every write is synchronous inside one call once
// its event ids are stamped, so an answer's attempt, schedule and mastery land together or not
// at all. A fresh memory store holds no rows from before event ids, so it needs no migration.

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
}
