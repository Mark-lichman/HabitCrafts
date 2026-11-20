// The remote side of the study record's sync (plan 2026-11-19, Task 3, D3, D10, PIN-3, PIN-10).
//
// `JpRemote` is what `JpSync` (jp_sync.dart) talks to: the learner's `users/{uid}/jp_events`,
// `jp_days` and `devices` in Firestore (`JpRemoteFirestore`, jp_remote_firestore.dart), or the
// in-memory `JpRemoteMemory` below, which tests drive with two stores at once.
//
// The rules the remote keeps (firebase/firestore.rules):
//   * an event is created once and never updated or deleted (PIN-3). A push of an id the
//     remote already holds leaves it as it is and counts as pushed: a legacy event can reach
//     the remote from two devices, and dedup keys on the event id alone (operator ruling,
//     Checkpoint 2026-11-19);
//   * a pull returns the events the server received after a cursor, the latest server time
//     the device has pulled up to, oldest first;
//   * a day plan is created once: the first plan to reach the server wins. After that only
//     the position moves, forward, and completed turns on, never off (PIN-10).
// Every call throws `JpRemoteUnavailable` (or the backend's own error) when the remote cannot
// be reached, and changes nothing it did not finish.

import 'jp_event.dart';
import 'jp_store.dart';

/// The remote could not be reached: offline, or the backend refused.
class JpRemoteUnavailable implements Exception {
  const JpRemoteUnavailable([this.message = 'the remote is unavailable']);

  final String message;

  @override
  String toString() => 'JpRemoteUnavailable: $message';
}

/// One pull: the events after the cursor, oldest server time first, and the cursor to pass
/// next time. [cursor] is the one passed in when nothing new arrived.
class JpPull {
  const JpPull({required this.events, required this.cursor});

  final List<JpEvent> events;
  final DateTime? cursor;
}

/// One device that synced: its id, a plain name and its last sync time.
class JpDevice {
  const JpDevice(
      {required this.deviceId, required this.name, required this.lastSyncUtc});

  final String deviceId;
  final String name;
  final DateTime lastSyncUtc;

  @override
  bool operator ==(Object other) =>
      other is JpDevice &&
      other.deviceId == deviceId &&
      other.name == name &&
      other.lastSyncUtc == lastSyncUtc;

  @override
  int get hashCode => Object.hash(deviceId, name, lastSyncUtc);

  @override
  String toString() =>
      'JpDevice($deviceId $name ${lastSyncUtc.toIso8601String()})';
}

/// The learner's synced record on the server.
abstract class JpRemote {
  /// Creates each of [events] the remote does not hold, by event id. An id it holds already is
  /// left as it is (PIN-3). Returns when every event is on the server.
  Future<void> pushEvents(List<JpEvent> events);

  /// The events the server received after [cursor] (every event when null), oldest first.
  Future<JpPull> pullEvents(DateTime? cursor);

  /// The day plan the server holds for local day [day]; null when none reached it yet.
  Future<DayRecord?> day(int day);

  /// Creates [record] as the server's plan for its day when the server holds none, and
  /// returns the server's plan after: [record], or the plan that reached it first (PIN-10).
  Future<DayRecord> createDay(DayRecord record);

  /// Moves the server's plan for [day] to [position] and [completed], forward only: a lower
  /// position, or completed off, leaves that field as it is (PIN-10). Returns the server's
  /// plan after; null when the server holds no plan for [day].
  Future<DayRecord?> advanceDay(int day,
      {required int position, required bool completed});

  /// Writes [deviceId]'s plain [name] and last sync time to `devices/{deviceId}`.
  Future<void> putDevice(String deviceId,
      {required String name, required DateTime lastSyncUtc});

  /// Every device that synced, newest sync first.
  Future<List<JpDevice>> devices();
}

/// An in-memory remote for tests. Every event goes through its map form ([JpEvent.toFirestore])
/// as a Firestore document would. The server clock moves one millisecond per received event, so
/// a cursor orders them. [online] false makes every call throw [JpRemoteUnavailable].
class JpRemoteMemory implements JpRemote {
  JpRemoteMemory({DateTime? serverEpoch})
      : _serverNow = (serverEpoch ?? DateTime.utc(2026)).toUtc();

  /// Whether the remote can be reached. Tests turn it off and on.
  bool online = true;

  DateTime _serverNow;

  /// Event id to its document and the server time it arrived.
  final Map<String, ({Map<String, dynamic> doc, DateTime serverAt})> _events =
      {};
  final Map<int, DayRecord> _days = {};
  final Map<String, JpDevice> _devices = {};

  /// How many create calls reached the event store, a re-push of a held id included.
  int createAttempts = 0;

  void _check() {
    if (!online) throw const JpRemoteUnavailable('offline');
  }

  /// The events held, in arrival order, read back from their documents.
  List<JpEvent> get events => [
        for (final e
            in _events.values.toList()
              ..sort((a, b) => a.serverAt.compareTo(b.serverAt)))
          JpEvent.fromFirestore(e.doc)
      ];

  /// The stored document for [eventId], as Firestore would hold it.
  Map<String, dynamic>? document(String eventId) => _events[eventId]?.doc;

  @override
  Future<void> pushEvents(List<JpEvent> events) async {
    _check();
    for (final e in events) {
      createAttempts++;
      // Create only: an existing document is never touched (PIN-3).
      if (_events.containsKey(e.eventId)) continue;
      _serverNow = _serverNow.add(const Duration(milliseconds: 1));
      _events[e.eventId] = (doc: e.toFirestore(), serverAt: _serverNow);
    }
  }

  @override
  Future<JpPull> pullEvents(DateTime? cursor) async {
    _check();
    final after = [
      for (final e in _events.values)
        if (cursor == null || e.serverAt.isAfter(cursor)) e
    ]..sort((a, b) => a.serverAt.compareTo(b.serverAt));
    return JpPull(
      events: [for (final e in after) JpEvent.fromFirestore(e.doc)],
      cursor: after.isEmpty ? cursor : after.last.serverAt,
    );
  }

  @override
  Future<DayRecord?> day(int day) async {
    _check();
    return _days[day];
  }

  @override
  Future<DayRecord> createDay(DayRecord record) async {
    _check();
    return _days[record.day] ??= record;
  }

  @override
  Future<DayRecord?> advanceDay(int day,
      {required int position, required bool completed}) async {
    _check();
    final old = _days[day];
    if (old == null) return null;
    return _days[day] = old.copyWith(
        position: position > old.position ? position : old.position,
        completed: old.completed || completed);
  }

  @override
  Future<void> putDevice(String deviceId,
      {required String name, required DateTime lastSyncUtc}) async {
    _check();
    _devices[deviceId] = JpDevice(
        deviceId: deviceId, name: name, lastSyncUtc: lastSyncUtc.toUtc());
  }

  @override
  Future<List<JpDevice>> devices() async {
    _check();
    return [..._devices.values]
      ..sort((a, b) => b.lastSyncUtc.compareTo(a.lastSyncUtc));
  }
}
