// The study record's remote in Firestore (plan 2026-11-19, Task 3, D3, D10, PIN-3, PIN-10,
// PIN-13). The contract is `JpRemote`'s (jp_remote.dart); the rules are in
// firebase/firestore.rules and their emulator suite.
//
// Documents under `users/{uid}`:
//   jp_events/{eventId}  `JpEvent.toFirestore()` plus `serverAt`, the server time it arrived
//                        (`FieldValue.serverTimestamp()`); created once, never updated (PIN-3)
//   jp_days/{day}        {day, plan, position, completed, deviceId, builtAt}: `builtAt` in
//                        milliseconds since the epoch; created once, then only a forward
//                        `position` or `completed` turning on (PIN-10)
//   devices/{deviceId}   {name, lastSyncAt}: `lastSyncAt` a Timestamp
//
// Every write runs in a transaction. A transaction needs the server, so a call made offline
// fails at once instead of queuing in the offline cache and resolving who knows when: the
// phone keeps working offline on its own store (PIN-9), and the next run retries. A push reads
// each event's document first and creates only the missing ones, because the rules deny a
// write to an existing event. Reads ask the server, never the cache.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'jp_event.dart';
import 'jp_remote.dart';
import 'jp_store.dart';

/// How many events one push transaction reads and creates. Firestore allows 500 writes.
const int kJpPushChunk = 200;

/// How many events one pull query reads.
const int kJpPullPage = 500;

class JpRemoteFirestore implements JpRemote {
  JpRemoteFirestore({required this.firestore, required this.uid});

  final FirebaseFirestore firestore;

  /// The signed-in, non-anonymous user's id. Anonymous users never sync.
  final String uid;

  static const GetOptions _server = GetOptions(source: Source.server);

  DocumentReference<Map<String, dynamic>> get _user =>
      firestore.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _events =>
      _user.collection('jp_events');
  CollectionReference<Map<String, dynamic>> get _days =>
      _user.collection('jp_days');
  CollectionReference<Map<String, dynamic>> get _devices =>
      _user.collection('devices');

  @override
  Future<void> pushEvents(List<JpEvent> events) async {
    for (var i = 0; i < events.length; i += kJpPushChunk) {
      final chunk = events.sublist(
          i, i + kJpPushChunk > events.length ? events.length : i + kJpPushChunk);
      await firestore.runTransaction((tx) async {
        final missing = <JpEvent>[];
        for (final e in chunk) {
          final snap = await tx.get(_events.doc(e.eventId));
          if (!snap.exists) missing.add(e);
        }
        for (final e in missing) {
          tx.set(_events.doc(e.eventId), {
            ...e.toFirestore(),
            'serverAt': FieldValue.serverTimestamp(),
          });
        }
      });
    }
  }

  @override
  Future<JpPull> pullEvents(DateTime? cursor) async {
    final out = <JpEvent>[];
    var next = cursor;
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      Query<Map<String, dynamic>> q = _events.orderBy('serverAt');
      if (cursor != null) {
        q = q.where('serverAt', isGreaterThan: Timestamp.fromDate(cursor));
      }
      if (last != null) q = q.startAfterDocument(last);
      final page = await q.limit(kJpPullPage).get(_server);
      for (final d in page.docs) {
        out.add(JpEvent.fromFirestore(d.data()));
        final at = d.data()['serverAt'];
        if (at is Timestamp) next = at.toDate().toUtc();
      }
      if (page.docs.length < kJpPullPage) break;
      last = page.docs.last;
    }
    return JpPull(events: out, cursor: next);
  }

  static Map<String, dynamic> _dayMap(DayRecord r) => {
        'day': r.day,
        'plan': r.plan,
        'position': r.position,
        'completed': r.completed,
        if (r.deviceId != null) 'deviceId': r.deviceId,
        if (r.builtAtUtc != null) 'builtAt': r.builtAtUtc!.millisecondsSinceEpoch,
      };

  static DayRecord _dayOf(int day, Map<String, dynamic> m) {
    final built = m['builtAt'];
    return DayRecord(
      day: day,
      plan: m['plan'] as String,
      position: (m['position'] as num).toInt(),
      completed: m['completed'] == true,
      deviceId: m['deviceId'] as String?,
      builtAtUtc: built is num
          ? DateTime.fromMillisecondsSinceEpoch(built.toInt(), isUtc: true)
          : null,
    );
  }

  @override
  Future<DayRecord?> day(int day) async {
    final snap = await _days.doc('$day').get(_server);
    final data = snap.data();
    return data == null ? null : _dayOf(day, data);
  }

  @override
  Future<DayRecord> createDay(DayRecord record) =>
      firestore.runTransaction((tx) async {
        final ref = _days.doc('${record.day}');
        final data = (await tx.get(ref)).data();
        if (data != null) return _dayOf(record.day, data);
        tx.set(ref, _dayMap(record));
        return record;
      });

  @override
  Future<DayRecord?> advanceDay(int day,
          {required int position, required bool completed}) =>
      firestore.runTransaction((tx) async {
        final ref = _days.doc('$day');
        final data = (await tx.get(ref)).data();
        if (data == null) return null;
        final old = _dayOf(day, data);
        final after = old.copyWith(
            position: position > old.position ? position : old.position,
            completed: old.completed || completed);
        if (after != old) {
          tx.update(ref,
              {'position': after.position, 'completed': after.completed});
        }
        return after;
      });

  @override
  Future<void> putDevice(String deviceId,
          {required String name, required DateTime lastSyncUtc}) =>
      firestore.runTransaction((tx) async {
        tx.set(_devices.doc(deviceId), {
          'name': name,
          'lastSyncAt': Timestamp.fromDate(lastSyncUtc.toUtc()),
        });
      });

  @override
  Future<List<JpDevice>> devices() async {
    final snap =
        await _devices.orderBy('lastSyncAt', descending: true).get(_server);
    return [
      for (final d in snap.docs)
        JpDevice(
          deviceId: d.id,
          name: (d.data()['name'] as String?) ?? d.id,
          lastSyncUtc: switch (d.data()['lastSyncAt']) {
            final Timestamp t => t.toDate().toUtc(),
            final num ms =>
              DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true),
            _ => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          },
        )
    ];
  }
}
