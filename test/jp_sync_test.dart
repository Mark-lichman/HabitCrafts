// The study record's sync (plan 2026-11-19, Task 3, End states 1 to 4, 14 and 16, PIN-3,
// PIN-10, PIN-12, PIN-16).
//
// Two stores, a phone and a web browser, sync against one in-memory remote (`JpRemoteMemory`),
// online and offline. The phone runs on each store implementation; the web runs on the memory
// store. The legacy history test opens a real SQLite file written as a build before event ids
// left it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_event.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_remote.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_sync.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/study_export.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'jp_store_old_rows.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));
const scheduler = FsrsScheduler();

final t0 = DateTime.utc(2026, 3, 2, 12);
DateTime at(int day, [int minute = 0]) =>
    t0.add(Duration(days: day, minutes: minute));

ItemDef firstOf(ItemKind kind) => catalog.ofKind(kind).first;

Attempt answer(ItemDef item, int day, Grade grade,
    {int minute = 0, String session = 's'}) {
  final p = item.scoredProbes.first;
  return Attempt(
    itemId: item.id,
    probeId: p.id,
    template: p.template,
    production: p.production,
    selfGraded: p.selfGraded,
    atUtc: at(day, minute),
    localDay: day,
    grade: grade,
    rating: fsrsRatingFor(grade),
    wasDue: true,
    source: Source.review,
    sessionId: '$session$day',
  );
}

/// The clock every store and sync under test reads. Tests move it.
DateTime now = at(0);
DateTime clock() => now;

/// The local day every sync under test calls today.
int today = 0;

final Map<String, Future<JpStore> Function()> phones = {
  'memory': () async => JpStoreMemory(clock: clock),
  'sqlite': () => JpStoreSqlite.open(
      factory: databaseFactoryFfi, path: inMemoryDatabasePath, clock: clock),
};

/// One device: its store and its sync.
class Device {
  Device(this.store, this.remote, this.name)
      : sync = JpSync(
            store: store,
            remote: remote,
            lookup: catalog.byId,
            scheduler: scheduler,
            deviceName: name,
            clock: clock,
            today: () => today);

  final JpStore store;
  final JpRemoteMemory remote;
  final String name;
  final JpSync sync;

  Future<JpSyncResult> run() => sync.run();

  Future<AnswerOutcome> answer(Attempt a) => store.recordAnswer(a,
      item: catalog.byId(a.itemId), scheduler: scheduler);
}

Set<String> idsOf(Iterable<JpEvent> events) =>
    {for (final e in events) e.eventId};

List<Map<String, dynamic>> contentOf(Iterable<JpEvent> events) =>
    [for (final e in events) e.toFirestore()];

/// Asserts both stores hold the same events, field for field, and replay to the same states,
/// which are their logs' own replay.
Future<void> expectSameRecord(JpStore a, JpStore b) async {
  expect(contentOf(await a.allEvents()), contentOf(await b.allEvents()),
      reason: 'the same events on both devices');
  expect(await a.allSrs(), await b.allSrs(), reason: 'the same srs');
  expect(await a.allMastery(), await b.allMastery(),
      reason: 'the same mastery');
  final replay = replayLog(await a.exportLog(), catalog.byId, scheduler);
  expect(await a.allSrs(), replay.srs, reason: 'the cache is the replay');
  expect(await a.allMastery(), replay.mastery);
  expect(await a.notes(), await b.notes());
  expect(await a.discussMarks(), await b.discussMarks());
  expect(await a.lastLesson(), await b.lastLesson());
  expect(contentOf(await a.speakScores()), contentOf(await b.speakScores()));
}

void main() {
  sqfliteFfiInit();
  setUp(() {
    now = at(0);
    today = 0;
  });

  group('JpRemoteMemory', () {
    test('creates an event once and never touches it again (PIN-3)', () async {
      final remote = JpRemoteMemory();
      final e = noteEvent('x', 'first',
          eventId: newEventId(), deviceId: 'phone', atUtc: at(0));
      await remote.pushEvents([e]);
      // The same id from another device, with another body: left as it is.
      await remote.pushEvents([
        noteEvent('x', 'second',
            eventId: e.eventId, deviceId: 'web', atUtc: at(1))
      ]);
      expect(remote.events.length, 1);
      expect(remote.events.single.sameContent(e), isTrue);
      expect(remote.createAttempts, 2);
      final pull = await remote.pullEvents(null);
      expect(pull.events.single.sameContent(e), isTrue);
      expect((await remote.pullEvents(pull.cursor)).events, isEmpty);
    });

    test('offline, every call throws and changes nothing', () async {
      final remote = JpRemoteMemory()..online = false;
      final e = noteEvent('x', 'n',
          eventId: newEventId(), deviceId: 'phone', atUtc: at(0));
      await expectLater(remote.pushEvents([e]), throwsA(isA<JpRemoteUnavailable>()));
      await expectLater(remote.pullEvents(null), throwsA(isA<JpRemoteUnavailable>()));
      await expectLater(
          remote.createDay(const DayRecord(day: 1, plan: '{}')),
          throwsA(isA<JpRemoteUnavailable>()));
      remote.online = true;
      expect(remote.events, isEmpty);
      expect(await remote.day(1), isNull);
    });
  });

  for (final phoneEntry in phones.entries) {
    group('JpSync (phone ${phoneEntry.key}, web memory)', () {
      late JpRemoteMemory remote;
      late Device phone, web;
      setUp(() async {
        remote = JpRemoteMemory();
        phone = Device(await phoneEntry.value(), remote, 'Pixel');
        web = Device(JpStoreMemory(clock: clock), remote, 'Chrome');
      });
      tearDown(() async {
        await phone.store.close();
        await web.store.close();
      });

      test('an answer on one device shows on the other after its next sync (End state 1)',
          () async {
        final g = firstOf(ItemKind.grammar);
        final out = await phone.answer(answer(g, 1, Grade.clear));
        final first = await phone.run();
        expect(idsOf(first.pushed), {out.attempt.eventId});
        expect(await phone.store.unpushedEvents(), isEmpty);

        expect(await web.store.attempts(), isEmpty, reason: 'not synced yet');
        final second = await web.run();
        expect(idsOf(second.pulled), {out.attempt.eventId});
        expect(second.rebuilt, isTrue);
        final got = await web.store.attempts();
        expect(got.single.eventId, out.attempt.eventId);
        expect(got.single.deviceId, await phone.store.deviceId());
        expect(await web.store.srs(g.id), out.srs);
        expect(await web.store.mastery(g.id), out.mastery);
        await expectSameRecord(phone.store, web.store);

        // A second sync with nothing new moves nothing.
        final again = await web.run();
        expect([again.pushed, again.pulled], [isEmpty, isEmpty]);
        expect(again.rebuilt, isFalse);
      });

      test('answers made offline on both devices sync with no loss and no duplicate (End state 2)',
          () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        remote.online = false;
        await phone.answer(answer(g, 1, Grade.clear));
        await phone.answer(answer(w, 1, Grade.wrong, minute: 5));
        await web.answer(answer(g, 1, Grade.hinted, minute: 2));
        await web.answer(answer(w, 2, Grade.clear));
        await expectLater(phone.run(), throwsA(isA<JpRemoteUnavailable>()));
        await expectLater(web.run(), throwsA(isA<JpRemoteUnavailable>()));
        expect((await phone.store.unpushedEvents()).length, 2,
            reason: 'nothing lost while offline');
        expect((await web.store.unpushedEvents()).length, 2);

        remote.online = true;
        await phone.run();
        await web.run();
        await phone.run();
        expect(remote.events.length, 4, reason: 'each answer once on the server');
        for (final d in [phone, web]) {
          final attempts = await d.store.attempts();
          expect(attempts.length, 4, reason: d.name);
          expect({for (final a in attempts) a.eventId}.length, 4,
              reason: 'no duplicate on ${d.name}');
          expect(await d.store.unpushedEvents(), isEmpty);
        }
        await expectSameRecord(phone.store, web.store);
        // Another round adds nothing anywhere.
        await web.run();
        await phone.run();
        expect(remote.events.length, 4);
        expect((await web.store.attempts()).length, 4);
      });

      test('interleaved answers on one item replay to identical srs and mastery (End state 3)',
          () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        remote.online = false;
        // Each device holds its own answers first, so the two logs hold the same events in
        // different row orders once merged.
        await phone.answer(answer(g, 1, Grade.clear));
        await phone.answer(answer(g, 3, Grade.wrong));
        await phone.answer(answer(w, 4, Grade.clear));
        await web.answer(answer(g, 2, Grade.hinted));
        await web.answer(answer(g, 5, Grade.clear));
        await web.answer(answer(w, 2, Grade.wrong));
        remote.online = true;
        await phone.run();
        await web.run();
        await phone.run();
        final phoneRows = [for (final a in await phone.store.attempts()) a.eventId];
        final webRows = [for (final a in await web.store.attempts()) a.eventId];
        expect(phoneRows.toSet(), webRows.toSet());
        expect(phoneRows, isNot(webRows), reason: 'the row orders differ');
        await expectSameRecord(phone.store, web.store);
        // The states are the replay of the log in the canonical order.
        final log = await web.store.exportLog();
        final sorted = [...log.attempts]
          ..sort((a, b) => compareEvents(attemptEvent(a), attemptEvent(b)));
        final canonical = replayLog(
            StudyLog(attempts: sorted, seeds: log.seeds), catalog.byId, scheduler);
        expect(await phone.store.allSrs(), canonical.srs);
        expect(await phone.store.allMastery(), canonical.mastery);
        // A debug-page rebuild lands on the same states as the sync.
        await phone.store.rebuild(catalog.byId, scheduler);
        await web.store.rebuild(catalog.byId, scheduler);
        await expectSameRecord(phone.store, web.store);
      });

      test('a run cut short after the push still pulls and replays on the next run',
          () async {
        final g = firstOf(ItemKind.grammar);
        final fromWeb = await web.answer(answer(g, 1, Grade.clear));
        await web.run();
        await phone.answer(answer(g, 2, Grade.clear));
        final flaky = _PullFails(remote);
        final cut = Device(phone.store, flaky, 'Pixel');
        await expectLater(cut.run(), throwsA(isA<JpRemoteUnavailable>()));
        expect(await phone.store.unpushedEvents(), isEmpty,
            reason: 'the push finished and stays done');
        expect(await phone.store.meta(kSyncCursorMetaKey), isNull,
            reason: 'the cursor moves only after a pull');
        final next = await phone.run();
        expect(next.pushed, isEmpty);
        expect(idsOf(next.pulled), {fromWeb.attempt.eventId},
            reason: 'its own pushed answer comes back and is skipped');
        expect(next.rebuilt, isTrue);
        await web.run();
        await expectSameRecord(phone.store, web.store);
      });

      test('notes, Discuss marks, say-it scores and the last lesson: the later event time wins (End state 16)',
          () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        remote.online = false;
        now = at(1, 1);
        await phone.store.setNote(g.id, 'phone note');
        await phone.store.setDiscuss(w.id, note: 'ask Mari', atUtc: at(1, 2));
        await phone.store.recordSpeakScore({'sentence': 'a', 'score': 80},
            atUtc: at(1, 3));
        await phone.store.setLastLesson('L5', atUtc: at(1, 9));
        now = at(1, 4);
        await web.store.setNote(g.id, 'web note');
        now = at(1, 5);
        await web.store.setDiscuss(w.id, note: 'from web', atUtc: at(1, 1));
        await web.store.clearDiscuss(w.id);
        await web.store.recordSpeakScore({'sentence': 'b', 'score': 95},
            atUtc: at(1, 6));
        await web.store.setLastLesson('L4', atUtc: at(1, 7));
        remote.online = true;

        // The web syncs last, yet the phone's later last lesson still wins.
        await phone.run();
        await web.run();
        await phone.run();
        for (final d in [phone, web]) {
          expect(await d.store.notes(), {g.id: 'web note'}, reason: d.name);
          expect(await d.store.discuss(w.id), isNull,
              reason: 'the web cleared it after the phone set it');
          expect(await d.store.lastLesson(), 'L5', reason: d.name);
          expect([for (final e in await d.store.speakScores()) e.body['score']],
              [80, 95], reason: 'every score from both devices, once');
        }
        await expectSameRecord(phone.store, web.store);

        // A later change on one device shows on the other after sync.
        now = at(2);
        await phone.store.setNote(g.id, null);
        await phone.store.setDiscuss(g.id, note: 'again', atUtc: at(2, 1));
        await web.store.setLastLesson('L6', atUtc: at(2, 2));
        await phone.run();
        await web.run();
        await phone.run();
        for (final d in [phone, web]) {
          expect(await d.store.notes(), isEmpty, reason: d.name);
          expect((await d.store.discuss(g.id))?.note, 'again', reason: d.name);
          expect(await d.store.lastLesson(), 'L6', reason: d.name);
        }
        await expectSameRecord(phone.store, web.store);
        expect(await phone.store.allSrs(), isEmpty,
            reason: 'side events move no schedule');
      });

      test('the day plan: the first plan to reach the server wins, and position never moves back (End state 14)',
          () async {
        final g = firstOf(ItemKind.grammar);
        today = 5;
        remote.online = false;
        await phone.store.putDay(
            const DayRecord(day: 5, plan: '{"entries":["phone"]}', position: 3));
        final phoneAnswer = await phone.answer(answer(g, 5, Grade.clear));
        await web.store.putDay(
            const DayRecord(day: 5, plan: '{"entries":["web"]}', position: 1));
        remote.online = true;

        // The web reaches the server first: its plan wins.
        await web.run();
        expect((await remote.day(5))!.plan, '{"entries":["web"]}');
        final phoneRun = await phone.run();
        final adopted = (await phone.store.day(5))!;
        expect(adopted.plan, '{"entries":["web"]}', reason: 'the phone adopts it');
        expect(adopted.position, 3, reason: 'the phone\'s position never moves back');
        expect(phoneRun.days[5]!.plan, adopted.plan);
        expect(adopted.deviceId, await web.store.deviceId(),
            reason: 'the builder is the winning device');
        expect((await phone.store.attempts()).single.eventId,
            phoneAnswer.attempt.eventId,
            reason: 'the phone keeps its own answers');
        expect((await remote.day(5))!.position, 3);

        await web.run();
        expect(await web.store.day(5), adopted, reason: 'both show the same plan');
        expect((await web.store.attempts()).single.eventId,
            phoneAnswer.attempt.eventId);

        // A stale device never moves the server back, and adopts the further position.
        await phone.store.putDay(adopted.copyWith(position: 6, completed: true));
        await phone.run();
        await web.store.putDay((await web.store.day(5))!.copyWith(position: 4));
        await web.run();
        expect((await remote.day(5))!.position, 6);
        expect((await remote.day(5))!.completed, isTrue);
        expect((await web.store.day(5))!.position, 6);
        expect((await web.store.day(5))!.completed, isTrue);
        expect(await web.store.day(5), await phone.store.day(5));
      });

      test('a device with no plan today adopts the server\'s', () async {
        today = 7;
        await phone.store.putDay(const DayRecord(day: 7, plan: '{"p":1}'));
        await phone.run();
        expect(await web.store.day(7), isNull);
        await web.run();
        expect((await web.store.day(7))!.plan, '{"p":1}');
        expect(await web.store.lastDay(), 7);
      });

      test('each sync writes the device\'s last sync time to devices/{deviceId}',
          () async {
        now = at(3, 10);
        await phone.run();
        now = at(3, 20);
        await web.run();
        expect(await remote.devices(), [
          JpDevice(
              deviceId: await web.store.deviceId(),
              name: 'Chrome',
              lastSyncUtc: at(3, 20)),
          JpDevice(
              deviceId: await phone.store.deviceId(),
              name: 'Pixel',
              lastSyncUtc: at(3, 10)),
        ]);
        now = at(4);
        await phone.run();
        expect((await remote.devices()).first.lastSyncUtc, at(4));
        expect((await remote.devices()).length, 2);
      });

      test('overlapping runs share one run', () async {
        final g = firstOf(ItemKind.grammar);
        await phone.answer(answer(g, 1, Grade.clear));
        final a = phone.run(), b = phone.run();
        expect(identical(await a, await b), isTrue);
        expect(remote.createAttempts, 1);
      });
    });
  }

  group('the legacy history uploads once (End state 4)', () {
    late Directory dir;
    late String path;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('jp_sync_test');
      path = '${dir.path}/jp_study.db';
    });
    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Windows can hold the file a moment after close; the temp folder is the OS's.
      }
    });

    test(
        'the phone\'s migrated history and a web import of the same old backup are one set of events',
        () async {
      final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
      // The old phone file, as the build before event ids left it.
      final old = await JpStoreSqlite.open(
          factory: databaseFactoryFfi, path: path, version: 2);
      await old.close();
      final source = JpStoreMemory();
      await source.appendSeed(w.id, 2, atUtc: at(0));
      await source.recordAnswer(answer(g, 1, Grade.clear),
          item: g, scheduler: scheduler);
      await source.recordAnswer(answer(w, 2, Grade.wrong),
          item: w, scheduler: scheduler);
      final oldAttempts = await source.attempts();
      final oldSeeds = await source.seeds();
      await writeOldRows(path,
          attempts: oldAttempts,
          srs: await source.allSrs(),
          mastery: (await source.allMastery()).values.toList(),
          seeds: oldSeeds,
          notes: {g.id: kNoteCanUseIt},
          discuss: [DiscussMark(itemId: w.id, note: 'ask', atUtc: at(2, 5))]);
      // The same history as an old (pre-v3) backup.
      final backup = encodeStudyExport(
          StudyLog(
            attempts: [
              for (final a in oldAttempts)
                Attempt.fromJson(a.toJson()
                  ..remove('id')
                  ..remove('eventId')
                  ..remove('deviceId'))
            ],
            seeds: [
              for (final s in oldSeeds)
                SeedEvent(itemId: s.itemId, dueDay: s.dueDay, atUtc: s.atUtc)
            ],
            notes: {g.id: kNoteCanUseIt},
            discuss: {
              w.id: DiscussMark(itemId: w.id, note: 'ask', atUtc: at(2, 5))
            },
          ),
          exportedAt: at(3));

      final remote = JpRemoteMemory();
      final phoneStore = await JpStoreSqlite.open(
          factory: databaseFactoryFfi, path: path, clock: clock);
      final webStore = JpStoreMemory(clock: () => at(40));
      try {
        final phone = Device(phoneStore, remote, 'Pixel');
        final web = Device(webStore, remote, 'Chrome');
        final legacy = await phoneStore.allEvents();
        expect(legacy.length, 5);
        expect(legacy.every((e) => e.deviceId == null), isTrue);

        // The web imports the old backup before it ever syncs.
        await importStudy(webStore, backup,
            lookup: catalog.byId, scheduler: scheduler);
        expect(contentOf(await webStore.allEvents()), contentOf(legacy),
            reason: 'byte-identical legacy events');

        final first = await phone.run();
        expect(idsOf(first.pushed), idsOf(legacy));
        expect(remote.events.length, 5);
        for (final e in legacy) {
          expect(remote.document(e.eventId)!.containsKey('deviceId'), isFalse,
              reason: 'a legacy event carries no device id');
        }
        final second = await web.run();
        expect(idsOf(second.pushed), idsOf(legacy),
            reason: 'the web offers its copies once');
        expect(remote.events.length, 5, reason: 'uploaded once');
        expect(second.pulled, isEmpty, reason: 'it already holds them all');
        expect(await webStore.unpushedEvents(), isEmpty);
        expect(await phoneStore.unpushedEvents(), isEmpty);

        // The ids stay put on every later open and through export and import.
        await phoneStore.close();
        final reopened = await JpStoreSqlite.open(
            factory: databaseFactoryFfi, path: path, clock: clock);
        try {
          expect(contentOf(await reopened.allEvents()), contentOf(legacy));
          expect(await reopened.unpushedEvents(), isEmpty);
          await importStudy(
              reopened, await exportStudy(reopened, exportedAt: at(5)),
              lookup: catalog.byId, scheduler: scheduler);
          expect(await reopened.unpushedEvents(), isEmpty);
          final again = await Device(reopened, remote, 'Pixel').run();
          expect(again.pushed, isEmpty, reason: 'nothing uploads twice');
          expect(remote.events.length, 5);
          await expectSameRecord(reopened, webStore);
        } finally {
          await reopened.close();
        }
      } finally {
        await webStore.close();
      }
    });
  });
}

/// A remote whose first pull fails: a run cut short after its push.
class _PullFails extends JpRemoteMemory {
  _PullFails(this.inner);

  final JpRemoteMemory inner;
  bool _failed = false;

  @override
  Future<void> pushEvents(List<JpEvent> events) => inner.pushEvents(events);

  @override
  Future<JpPull> pullEvents(DateTime? cursor) {
    if (!_failed) {
      _failed = true;
      throw const JpRemoteUnavailable('cut short');
    }
    return inner.pullEvents(cursor);
  }
}
