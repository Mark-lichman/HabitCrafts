// The web study store keeps the record across reloads (plan 2026-11-19, Task 5, A4). A reload
// is a second open over the same browser storage. The contract suite in test/jp_store_test.dart
// runs against `JpStoreWeb` too; this file covers what only the web store does: the open,
// the reload, the rollback of a write the browser refuses, an unreadable snapshot, two open
// tabs over one browser storage, and the sign-out wipe (operator rulings, Checkpoint
// 2026-11-20).

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_event.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_web.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_sync.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';

final t0 = DateTime.utc(2026, 3, 2, 12);

Attempt answer(String itemId, int day, Grade grade, {int minute = 0}) =>
    Attempt(
      itemId: itemId,
      probeId: '$itemId#p0',
      template: 'meaning',
      production: false,
      selfGraded: false,
      atUtc: t0.add(Duration(days: day, minutes: minute)),
      localDay: day,
      grade: grade,
      rating: fsrsRatingFor(grade),
      wasDue: true,
      source: Source.review,
      sessionId: 's$day',
    );

const srsA = SrsState(
    stability: 2.5,
    difficulty: 5.25,
    lastReviewDay: 3,
    dueDay: 6,
    interval: 3,
    reps: 1);

/// Browser storage that refuses every write after [failAfter] successful ones.
class _Refusing extends MemoryJpWebStorage {
  _Refusing(this.failAfter);

  int failAfter;

  @override
  Future<void> write(String snapshot) async {
    if (failAfter <= 0) throw StateError('quota exceeded');
    failAfter--;
    await super.write(snapshot);
  }
}

void main() {
  test('openJpStore on web opens the web store over browser storage', () async {
    final storage = MemoryJpWebStorage();
    final store = await openJpStore(isWeb: true, webStorage: storage);
    expect(store, isA<JpStoreWeb>());
    await store.close();
  });

  test('a reload keeps the whole record, the device id and the pushed marks',
      () async {
    final storage = MemoryJpWebStorage();
    final first = await openJpStore(isWeb: true, webStorage: storage);
    final a1 = await first.appendAttempt(answer('g1', 1, Grade.clear),
        srs: srsA,
        mastery:
            const MasteryState(itemId: 'g1', status: MasteryStatus.learning));
    await first.appendAttempt(answer('w1', 2, Grade.wrong, minute: 1));
    await first.appendSeed('s1', 9, atUtc: t0);
    await first.setNote('g1', 'can use it');
    await first.setDiscuss('w1', note: 'ask Mari', atUtc: t0);
    await first.recordSpeakScore({'sentence': 'x', 'score': 80}, atUtc: t0);
    await first.setLastLesson('L3', atUtc: t0);
    await first.putDay(const DayRecord(day: 4, plan: '{"p":1}', position: 2));
    await first.putMeta('flag', 'on');
    await first.markPushed([a1.eventId!]);
    final remote = JpEvent(
      eventId: 'remote-1',
      deviceId: 'phone',
      atUtc: t0.add(const Duration(hours: 1)),
      kind: JpEventKind.note,
      body: const {'itemId': 'p1', 'note': 'from the phone'},
    );
    await first.appendRemoteEvents([remote]);
    final device = await first.deviceId();
    final before = (
      attempts: await first.attempts(),
      seeds: await first.seeds(),
      srs: await first.allSrs(),
      mastery: await first.allMastery(),
      notes: await first.notes(),
      discuss: await first.discussMarks(),
      side: await first.sideEvents(),
      unpushed: [for (final e in await first.unpushedEvents()) e.eventId],
      due: await first.dueOnOrBefore(100),
    );
    await first.close();

    final second = await openJpStore(isWeb: true, webStorage: storage);
    expect(await second.attempts(), before.attempts);
    expect([for (final a in await second.attempts()) a.eventId],
        [for (final a in before.attempts) a.eventId]);
    expect(await second.seeds(), before.seeds);
    expect(await second.allSrs(), before.srs);
    expect(await second.allMastery(), before.mastery);
    expect(await second.notes(), before.notes);
    expect(await second.notes(), containsPair('p1', 'from the phone'));
    expect(await second.discussMarks(), before.discuss);
    expect(await second.sideEvents(), before.side);
    expect([for (final e in await second.unpushedEvents()) e.eventId],
        before.unpushed);
    expect(before.unpushed, isNot(contains(a1.eventId)));
    expect(before.unpushed, isNot(contains('remote-1')));
    expect(await second.dueOnOrBefore(100), before.due);
    expect(await second.lastLesson(), 'L3');
    final day = await second.day(4);
    expect(day, const DayRecord(day: 4, plan: '{"p":1}', position: 2));
    expect(day!.deviceId, device);
    expect(day.builtAtUtc, isNotNull);
    expect(await second.meta('flag'), 'on');
    expect(await second.deviceId(), device);

    // The next attempt continues the row ids.
    final a3 = await second.appendAttempt(answer('g1', 5, Grade.clear));
    expect(a3.id, 3);
    await second.close();
  });

  test('an import and a rebuild survive a reload', () async {
    final storage = MemoryJpWebStorage();
    final first = await openJpStore(isWeb: true, webStorage: storage);
    await first.appendAttempt(answer('g1', 1, Grade.clear));
    final log = await first.exportLog();
    await first.replaceAll(
        log,
        const ReplayResult(
            srs: {'g1': srsA}, mastery: {}, seedDue: {'s9': 12}));
    await first.close();

    final second = await openJpStore(isWeb: true, webStorage: storage);
    expect(await second.allSrs(), {'g1': srsA});
    expect((await second.item('s9'))?.seedDueDay, 12);
    expect(await second.attempts(), log.attempts);
    await second.close();
  });

  test('a write the browser refuses rolls back and throws', () async {
    final storage = _Refusing(1000);
    final store = await JpStoreWeb.open(storage: storage);
    await store.deviceId();
    final kept = await store.appendAttempt(answer('g1', 1, Grade.clear));
    storage.failAfter = 0;
    await expectLater(
        store.appendAttempt(answer('g1', 2, Grade.clear), srs: srsA),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'message', 'quota exceeded')));
    expect(await store.attempts(), [kept]);
    expect(await store.srs('g1'), isNull);
    await expectLater(store.putMeta('k', 'v'), throwsStateError);
    expect(await store.meta('k'), isNull);

    storage.failAfter = 1000;
    final reloaded = await JpStoreWeb.open(storage: storage);
    expect(await reloaded.attempts(), [kept]);
    // The refused attempt's row id is free again.
    final next = await store.appendAttempt(answer('g1', 3, Grade.clear));
    expect(next.id, 2);
  });

  test('an unreadable snapshot fails the open and is left in place', () async {
    final storage = MemoryJpWebStorage()..snapshot = '{not json';
    await expectLater(
        JpStoreWeb.open(storage: storage), throwsA(isA<FormatException>()));
    expect(storage.snapshot, '{not json');
    storage.snapshot = '{"v":99}';
    await expectLater(
        JpStoreWeb.open(storage: storage),
        throwsA(isA<FormatException>().having(
            (e) => e.message, 'message', contains('snapshot version 99'))));
  });

  test('a fresh browser opens an empty store', () async {
    final store = await JpStoreWeb.open(storage: MemoryJpWebStorage());
    expect(await store.attempts(), isEmpty);
    expect(await store.lastDay(), isNull);
  });

  // Two open tabs are two stores over one browser storage.
  group('two open tabs', () {
    test('share one device id, even when both open a fresh browser at once',
        () async {
      final storage = MemoryJpWebStorage();
      final tabs = await Future.wait([
        JpStoreWeb.open(storage: storage),
        JpStoreWeb.open(storage: storage)
      ]);
      expect(await tabs[0].deviceId(), await tabs[1].deviceId());
      final reloaded = await JpStoreWeb.open(storage: storage);
      expect(await reloaded.deviceId(), await tabs[0].deviceId());
    });

    test('a write in one tab never overwrites the other tab\'s answers',
        () async {
      final storage = MemoryJpWebStorage();
      final a = await JpStoreWeb.open(storage: storage);
      final b = await JpStoreWeb.open(storage: storage);
      final fromA = await a.appendAttempt(answer('g1', 1, Grade.clear));
      final fromB = await b.appendAttempt(answer('w1', 2, Grade.wrong));
      await a.setNote('g1', 'from tab a');

      // Each tab re-reads before it writes, so the record holds both tabs' writes.
      final reloaded = await JpStoreWeb.open(storage: storage);
      expect([for (final x in await reloaded.attempts()) x.eventId],
          [fromA.eventId, fromB.eventId]);
      expect(await reloaded.notes(), {'g1': 'from tab a'});
      // Tab a saw tab b's answer when it wrote its note.
      expect(await a.attempts(), hasLength(2));
    });

    test('writes in flight in both tabs at once all land', () async {
      final storage = MemoryJpWebStorage();
      final a = await JpStoreWeb.open(storage: storage);
      final b = await JpStoreWeb.open(storage: storage);
      await Future.wait([
        for (var i = 0; i < 5; i++) ...[
          a.appendAttempt(answer('a$i', 1, Grade.clear, minute: i)),
          b.appendAttempt(answer('b$i', 1, Grade.clear, minute: i)),
          b.putMeta('b.$i', 'v'),
        ]
      ]);
      final reloaded = await JpStoreWeb.open(storage: storage);
      expect({
        for (final x in await reloaded.attempts()) x.itemId
      }, {
        for (var i = 0; i < 5; i++) ...['a$i', 'b$i']
      });
      for (var i = 0; i < 5; i++) {
        expect(await reloaded.meta('b.$i'), 'v');
      }
      // Row ids stay unique across the tabs.
      final ids = [for (final x in await reloaded.attempts()) x.id];
      expect(ids.toSet(), hasLength(10));
    });
  });

  group('the sign-out wipe', () {
    Future<JpStoreWeb> withRecord(MemoryJpWebStorage storage) async {
      final store = await JpStoreWeb.open(storage: storage);
      await store.appendAttempt(answer('g1', 1, Grade.clear),
          srs: srsA,
          mastery:
              const MasteryState(itemId: 'g1', status: MasteryStatus.learning));
      await store.appendSeed('s1', 9, atUtc: t0);
      await store.setNote('g1', 'can use it');
      await store.setDiscuss('g1', note: 'ask Mari', atUtc: t0);
      await store.setLastLesson('L3', atUtc: t0);
      await store.putDay(const DayRecord(day: 4, plan: '{}', position: 1));
      await store.putMeta(kSyncCursorMetaKey, '2026-11-20T00:00:00.000Z');
      await store.putMeta(kSyncReplayPendingMetaKey, '1');
      return store;
    }

    Future<void> expectEmpty(JpStore store) async {
      expect(await store.attempts(), isEmpty);
      expect(await store.seeds(), isEmpty);
      expect(await store.allSrs(), isEmpty);
      expect(await store.allMastery(), isEmpty);
      expect(await store.notes(), isEmpty);
      expect(await store.discussMarks(), isEmpty);
      expect(await store.sideEvents(), isEmpty);
      expect(await store.unpushedEvents(), isEmpty);
      expect(await store.lastLesson(), isNull);
      expect(await store.lastDay(), isNull);
      expect(await store.dueOnOrBefore(100), isEmpty);
    }

    test('clears the record, the sync cursor and the replay flag', () async {
      final storage = MemoryJpWebStorage();
      final store = await withRecord(storage);
      final device = await store.deviceId();
      await store.wipe();

      await expectEmpty(store);
      expect(await store.meta(kSyncCursorMetaKey), isNull);
      expect(await store.meta(kSyncReplayPendingMetaKey), isNull);
      // The browser keeps its device id: the wipe clears study data only.
      expect(await store.deviceId(), device);

      final reloaded = await JpStoreWeb.open(storage: storage);
      await expectEmpty(reloaded);
      expect(await reloaded.meta(kSyncCursorMetaKey), isNull);
      expect(await reloaded.meta(kSyncReplayPendingMetaKey), isNull);
      expect(await reloaded.deviceId(), device);
    });

    test(
        'keeps every migration flag, so old browser keys are never imported again',
        () async {
      // Operator ruling, Checkpoint 2026-11-20: the next account must not import this
      // browser's old study keys a second time.
      final storage = MemoryJpWebStorage();
      final store = await withRecord(storage);
      await store.putMeta('migration.v2', '2026-11-01T00:00:00.000Z');
      await store.putMeta('migration.speakLesson', '2026-11-02T00:00:00.000Z');
      await store.putMeta('migrationv2', 'not a migration flag');
      await store.wipe();

      for (final s in [store, await JpStoreWeb.open(storage: storage)]) {
        await expectEmpty(s);
        expect(await s.meta('migration.v2'), '2026-11-01T00:00:00.000Z');
        expect(
            await s.meta('migration.speakLesson'), '2026-11-02T00:00:00.000Z');
        expect(await s.meta('migrationv2'), isNull);
        expect(await s.meta(kSyncCursorMetaKey), isNull);
        expect(await s.meta(kSyncReplayPendingMetaKey), isNull);
      }
    });

    test('another open tab never undoes it', () async {
      final storage = MemoryJpWebStorage();
      final a = await withRecord(storage);
      final b = await JpStoreWeb.open(storage: storage);
      expect(await b.attempts(), hasLength(1));

      await a.wipe();
      // Tab b still holds the old record in memory, and then writes.
      final later = await b.appendAttempt(answer('n1', 5, Grade.clear));
      await b.setNote('n1', 'after sign-out');

      final reloaded = await JpStoreWeb.open(storage: storage);
      expect([for (final x in await reloaded.attempts()) x.eventId],
          [later.eventId]);
      expect(await reloaded.notes(), {'n1': 'after sign-out'});
      expect(await reloaded.seeds(), isEmpty);
      expect(await reloaded.allSrs(), isEmpty);
      expect(await reloaded.lastLesson(), isNull);
      expect(await reloaded.meta(kSyncCursorMetaKey), isNull);
      expect(await reloaded.meta(kSyncReplayPendingMetaKey), isNull);
    });

    test('a cleared browser storage counts as a wipe', () async {
      final storage = MemoryJpWebStorage();
      final store = await withRecord(storage);
      final device = await store.deviceId();
      await storage.clear();
      await store.putMeta('flag', 'on');

      final reloaded = await JpStoreWeb.open(storage: storage);
      await expectEmpty(reloaded);
      expect(await reloaded.meta(kSyncCursorMetaKey), isNull);
      expect(await reloaded.meta('flag'), 'on');
      expect(await reloaded.deviceId(), device);
    });
  });
}
