// One sync of the study record with the remote (plan 2026-11-19, Task 3, D3, D10, PIN-3,
// PIN-10, PIN-12, PIN-16).
//
// `JpSync.run()`, in order:
//   1. push: every event the store has not pushed goes to the remote, then is marked pushed.
//      The remote creates each id once, so a re-push after a cut-short run, or a legacy event
//      another device already uploaded, adds nothing (dedup by event id alone);
//   2. pull: the events the server received after the sync cursor are appended, each id once.
//      No cursor (none yet, or cleared by an import) pulls every event;
//   3. replay: when an attempt or a seed was pushed or newly pulled, the store rebuilds the schedule
//      and mastery from the merged log, in the canonical order (event time, then event id), so
//      every device lands on the same states. Notes, Discuss marks, say-it scores and the last
//      lesson are side events: the store resolves them by the latest event time on append;
//   4. the sync cursor moves to the last pulled server time, after the replay;
//   5. the day plan: for today and the store's latest day, the first plan to reach the server
//      wins. The other device adopts it, keeps its own answers (they are in the log), and the
//      position only moves forward on either side (PIN-10);
//   6. the device's last sync time goes to `devices/{deviceId}`.
// A remote failure stops the run where it is and throws. Nothing the run finished is lost and
// nothing is half-written: an event is marked pushed only after the remote holds it, and the
// cursor moves only after the pulled events are appended and replayed. The next run picks up
// the rest. Overlapping calls share one run.
//
// The store stays the one seam for study data: JpSync reads and writes only through `JpStore`
// and `JpRemote`, and the replay stays the store's pure `replayLog`.

import 'jp_event.dart';
import 'jp_remote.dart';
import 'jp_store.dart';
import 'local_day.dart';
import 'scheduler.dart';

export 'jp_store.dart' show kSyncCursorMetaKey;

/// The store flag set while a pulled or pushed attempt or seed waits for its replay, so a run
/// cut short between the append and the rebuild still rebuilds on the next run.
const String kSyncReplayPendingMetaKey = 'sync.replayPending';

/// What one run did.
class JpSyncResult {
  const JpSyncResult({
    required this.pushed,
    required this.pulled,
    required this.rebuilt,
    required this.days,
  });

  /// The events pushed, oldest first.
  final List<JpEvent> pushed;

  /// The events pulled and appended (new to this store), oldest server time first.
  final List<JpEvent> pulled;

  /// Whether the store replayed the merged log.
  final bool rebuilt;

  /// The day plans after the run, by local day.
  final Map<int, DayRecord> days;
}

class JpSync {
  JpSync({
    required this.store,
    required this.remote,
    required this.lookup,
    required this.scheduler,
    required this.deviceName,
    DateTime Function()? clock,
    int Function()? today,
  })  : clock = clock ?? DateTime.now,
        _today = today;

  final JpStore store;
  final JpRemote remote;

  /// The catalog's `byId`, for the replay.
  final ItemLookup lookup;
  final Scheduler scheduler;

  /// The plain device name the devices page shows, such as "Pixel 8" or "Chrome".
  final String deviceName;

  /// The device clock: the last sync time and, by default, today's local day.
  final DateTime Function() clock;
  final int Function()? _today;

  /// Today's local day (D15).
  int today() => _today?.call() ?? localDay(clock());

  Future<JpSyncResult>? _running;

  /// Runs one sync (see the file comment). A call while a run is going returns that run.
  Future<JpSyncResult> run() =>
      _running ??= _run().whenComplete(() => _running = null);

  Future<JpSyncResult> _run() async {
    final device = await store.deviceId();

    // 1. Push.
    final pushed = await store.unpushedEvents();
    if (pushed.isNotEmpty) {
      if (pushed.any((e) => e.kind.replayed)) {
        await store.putMeta(kSyncReplayPendingMetaKey, '1');
      }
      await remote.pushEvents(pushed);
      await store.markPushed([for (final e in pushed) e.eventId]);
    }

    // 2. Pull.
    final kept = await store.meta(kSyncCursorMetaKey);
    final cursor =
        kept == null || kept.isEmpty ? null : DateTime.parse(kept).toUtc();
    final pull = await remote.pullEvents(cursor);
    // Only events the store lacks call for a replay. A pull can return events it already
    // holds: a web cursor keeps milliseconds, the server time keeps microseconds.
    final held = {for (final e in await store.allEvents()) e.eventId};
    if (pull.events.any((e) => e.kind.replayed && !held.contains(e.eventId))) {
      await store.putMeta(kSyncReplayPendingMetaKey, '1');
    }
    final pulled = await store.appendRemoteEvents(pull.events);

    // 3. Replay.
    var rebuilt = false;
    if (await store.meta(kSyncReplayPendingMetaKey) == '1') {
      await store.rebuild(lookup, scheduler);
      await store.putMeta(kSyncReplayPendingMetaKey, '0');
      rebuilt = true;
    }

    // 4. The cursor, after the replay.
    final next = pull.cursor;
    if (next != null && next != cursor) {
      await store.putMeta(kSyncCursorMetaKey, next.toUtc().toIso8601String());
    }

    // 5. The day plan.
    final days = <int, DayRecord>{};
    final last = await store.lastDay();
    for (final d in {today(), if (last != null) last}) {
      final record = await _syncDay(d);
      if (record != null) days[d] = record;
    }

    // 6. The device's last sync time.
    await remote.putDevice(device, name: deviceName, lastSyncUtc: clock());

    return JpSyncResult(
        pushed: pushed, pulled: pulled, rebuilt: rebuilt, days: days);
  }

  /// Syncs local day [day]'s plan (PIN-10) and returns the store's record after; null when
  /// neither side has one.
  Future<DayRecord?> _syncDay(int day) async {
    final local = await store.day(day);
    var server = await remote.day(day);
    if (server == null) {
      if (local == null) return null;
      server = await remote.createDay(local);
    }
    final position = local == null || local.position < server.position
        ? server.position
        : local.position;
    final completed = server.completed || (local?.completed ?? false);
    // The server's plan wins. A plan adopted from another device keeps this device's
    // position when it is further on: the position never moves back.
    final merged = DayRecord(
      day: day,
      plan: server.plan,
      position: position,
      completed: completed,
      deviceId: server.deviceId,
      builtAtUtc: server.builtAtUtc,
    );
    if (local == null ||
        local != merged ||
        local.deviceId != merged.deviceId ||
        local.builtAtUtc != merged.builtAtUtc) {
      await store.putDay(merged);
    }
    if (position > server.position || (completed && !server.completed)) {
      await remote.advanceDay(day, position: position, completed: completed);
    }
    return store.day(day);
  }
}
