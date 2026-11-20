// The study store on the web (plan 2026-11-19, Task 5, A4): it keeps the record across reloads.
//
// A `JpStoreMemory` is the working copy. After each write the store saves the copy's whole
// snapshot (`JpStoreMemory.toSnapshot`) to browser storage as one JSON string, and an open
// reads it back. In the browser that storage is IndexedDB (jp_web_storage_idb.dart): one value
// in one object store, so each save replaces the last in a single put. IndexedDB, not
// localStorage, because a year of answers outgrows localStorage's few megabytes. The mechanism
// is the implementer's choice under the plan's latitude.
//
// One write at a time: each write runs its change and its save under [_locked], so memory
// always matches the last saved snapshot between writes. A save the browser refuses (a full
// quota, a closed database) puts the copy back to that snapshot and rethrows, so an answer's
// attempt, schedule and mastery land together or not at all, as on the phone. The device id is
// read or made at open, so no write inside the lock needs another write.
//
// Two open tabs (operator rulings, Checkpoint 2026-11-20): the lock spans every tab of the site
// (the Web Locks API, jp_web_storage_idb.dart), and inside it each write re-reads the saved
// snapshot before its change. So two tabs never save over each other, and a tab that still
// holds the old record never undoes another tab's sign-out [wipe]. Reads between writes come
// from this tab's copy, which catches up at its next write or open.
//
// An unreadable snapshot fails the open with a [FormatException] and stays where it is: the
// store never replaces a record it cannot read. Same contract as `JpStoreSqlite`; the shared
// suite in test/jp_store_test.dart runs against all three stores, and
// test/open_jp_store_test.dart covers the reload.

import 'dart:convert';

import 'attempt.dart';
import 'jp_event.dart';
import 'jp_store.dart';
import 'jp_store_memory.dart';
import 'jp_web_storage.dart';
import 'mastery_rule.dart';
import 'scheduler.dart';

export 'jp_web_storage.dart' show JpWebStorage, MemoryJpWebStorage;

/// The snapshot form this build writes and reads.
const int kJpWebSnapshotVersion = 1;

class JpStoreWeb extends JpStoreMemory {
  JpStoreWeb._(this._storage, {super.clock});

  final JpWebStorage _storage;

  /// The snapshot last saved, which memory matches between writes.
  late String _saved;

  /// The tail of the write lock.
  Future<void> _tail = Future.value();

  /// Opens the store over [storage]: the browser's IndexedDB when null. Reads the saved
  /// snapshot, or starts empty when there is none, then reads or makes the device id. The
  /// device id is made inside the lock, so two tabs that open a fresh browser at once share one.
  static Future<JpStoreWeb> open(
      {JpWebStorage? storage, DateTime Function()? clock}) async {
    final store = JpStoreWeb._(storage ?? browserJpWebStorage(), clock: clock);
    final raw = await store._storage.read();
    if (raw == null) {
      store._saved = store._encode();
    } else {
      store._restore(raw);
      store._saved = raw;
    }
    await store._locked(() async {
      if (await store.meta(kDeviceIdMetaKey) == null) {
        await store._putMeta(kDeviceIdMetaKey, newEventId());
      }
    });
    await store.deviceId();
    return store;
  }

  Future<void> _putMeta(String key, String value) => super.putMeta(key, value);

  String _encode() => jsonEncode({'v': kJpWebSnapshotVersion, ...toSnapshot()});

  void _restore(String raw) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('jp web store: the snapshot is not a map');
    }
    final snapshot = Map<String, dynamic>.from(decoded);
    final v = snapshot['v'];
    if (v != kJpWebSnapshotVersion) {
      throw FormatException('jp web store: unknown snapshot version $v');
    }
    try {
      restoreSnapshot(snapshot);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('jp web store: unreadable snapshot: $e');
    }
  }

  /// Brings memory up to the saved snapshot when another tab saved since this one last did.
  /// Nothing saved means the browser's storage was cleared: memory empties too, keeping this
  /// tab's device id and migration flags ([JpStoreMemory.clearRecord]). An unreadable snapshot
  /// throws a [FormatException] and changes nothing.
  Future<void> _reread() async {
    final raw = await _storage.read();
    if (raw == _saved) return;
    if (raw == null) {
      clearRecord();
      _saved = _encode();
    } else {
      _restore(raw);
      _saved = raw;
    }
  }

  /// Runs [change], then saves, after every earlier write settles and inside the storage's
  /// lock across tabs ([JpWebStorage.exclusive]). It re-reads the saved snapshot first
  /// ([_reread]), so a change lands on the latest record: one tab never saves over another
  /// tab's writes, nor undoes another tab's [wipe]. A failed change or save puts memory back
  /// to the last saved snapshot and rethrows.
  Future<T> _locked<T>(Future<T> Function() change) {
    final run = _tail.then((_) => _storage.exclusive(() async {
          await _reread();
          try {
            final result = await change();
            final next = _encode();
            await _storage.write(next);
            _saved = next;
            return result;
          } catch (_) {
            _restore(_saved);
            rethrow;
          }
        }));
    _tail = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  /// The sign-out wipe: empties this browser's study record and saves the empty record
  /// ([JpStoreMemory.wipe]). The sync cursor ([kSyncCursorMetaKey]) and the replay flag
  /// (`sync.replayPending`) go with it, so the next sign-in pulls the whole record. The device
  /// id stays, because it names the browser, not the account. Every migration flag
  /// ([kMigrationMetaPrefix]) stays too, so this browser's old study keys are never imported
  /// again into the next account (operator ruling, Checkpoint 2026-11-20). Every other open
  /// tab re-reads before its next write, so none of them puts the old record back.
  @override
  Future<void> wipe() => _locked(() => super.wipe());

  @override
  Future<Attempt> appendAttempt(Attempt attempt,
          {SrsState? srs, MasteryState? mastery}) =>
      _locked(() => super.appendAttempt(attempt, srs: srs, mastery: mastery));

  @override
  Future<void> appendSeeds(Iterable<SeedEvent> seeds) {
    final all = seeds.toList();
    return _locked(() => super.appendSeeds(all));
  }

  @override
  Future<void> putSrs(String itemId, SrsState state) =>
      _locked(() => super.putSrs(itemId, state));

  @override
  Future<void> putMastery(MasteryState state) =>
      _locked(() => super.putMastery(state));

  @override
  Future<void> putDay(DayRecord record) => _locked(() => super.putDay(record));

  @override
  Future<void> putMeta(String key, String value) =>
      _locked(() => super.putMeta(key, value));

  @override
  Future<void> writeSideEvent(JpEvent event) =>
      _locked(() => super.writeSideEvent(event));

  @override
  Future<void> markPushed(Iterable<String> eventIds) {
    final ids = eventIds.toList();
    return _locked(() => super.markPushed(ids));
  }

  @override
  Future<List<JpEvent>> writeRemoteEvents(List<JpEvent> events) =>
      _locked(() => super.writeRemoteEvents(events));

  @override
  Future<void> replaceDerived(ReplayResult result) =>
      _locked(() => super.replaceDerived(result));

  @override
  Future<void> replaceAll(StudyLog log, ReplayResult result) =>
      _locked(() => super.replaceAll(log, result));

  /// Waits for the writes in flight. The saved record stays for the next open; [wipe] is what
  /// empties it.
  @override
  Future<void> close() => _tail;
}
