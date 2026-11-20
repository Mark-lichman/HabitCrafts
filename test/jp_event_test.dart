// Global event ids and their migration (plan 2026-11-19, Task 1, End state 4, PIN-12, PIN-16).
//
// `JpEvent` and its Firestore map form; the store stamping attempts, seeds and day records; note,
// Discuss, say-it score and last-lesson changes as timestamped events that resolve by last write
// wins; the sync seam (unpushed, mark pushed, append remote without duplicates); export and
// import at version 3; and the one-time SQLite migration that gives existing rows their ids and
// keeps them on every later open. Each store test runs against both implementations.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_event.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart';
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

Attempt answer(ItemDef item, int day, Grade grade, {int minute = 0}) {
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
    sessionId: 's$day',
  );
}

/// The clock every store under test reads. Tests move it.
DateTime now = at(0);
DateTime clock() => now;

typedef Opener = Future<JpStore> Function();

final Map<String, Opener> implementations = {
  'memory': () async => JpStoreMemory(clock: clock),
  'sqlite': () => JpStoreSqlite.open(
      factory: databaseFactoryFfi, path: inMemoryDatabasePath, clock: clock),
};

final RegExp uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

/// A legacy id: a name-based (version 5) UUID of the row content.
final RegExp uuidV5 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

/// A note event from another device.
JpEvent remoteNote(String itemId, String? note, DateTime atUtc,
        {String? eventId}) =>
    noteEvent(itemId, note,
        eventId: eventId ?? newEventId(), deviceId: 'phone-b', atUtc: atUtc);

/// Every field of [events], in order: event equality compares the id alone.
List<Map<String, dynamic>> contentOf(Iterable<JpEvent> events) =>
    [for (final e in events) e.toFirestore()];

/// The same events with their ids, as a set of ids.
Set<String> idsOf(Iterable<JpEvent> events) =>
    {for (final e in events) e.eventId};

void main() {
  sqfliteFfiInit();
  setUp(() => now = at(0));

  group('JpEvent', () {
    test('newEventId is a random UUID, distinct on every call', () {
      final ids = {for (var i = 0; i < 500; i++) newEventId()};
      expect(ids.length, 500);
      expect(ids.every(uuidV4.hasMatch), isTrue, reason: ids.first);
    });

    test('the Firestore map form round-trips every kind through JSON', () {
      final g = firstOf(ItemKind.grammar);
      final attempt = answer(g, 1, Grade.clear)
          .withEvent(eventId: newEventId(), deviceId: 'phone-a');
      final seed = SeedEvent(itemId: g.id, dueDay: 3, atUtc: at(0))
          .withEvent(eventId: newEventId(), deviceId: 'phone-a');
      final events = [
        attemptEvent(attempt),
        seedEvent(seed),
        remoteNote(g.id, kNoteCanUseIt, at(1)),
        remoteNote(g.id, null, at(2)),
        discussEvent(g.id,
            note: 'ask Mari',
            eventId: newEventId(),
            deviceId: 'web',
            atUtc: at(3)),
        discussEvent(g.id,
            cleared: true,
            eventId: newEventId(),
            deviceId: 'web',
            atUtc: at(4)),
        JpEvent(
            eventId: newEventId(),
            deviceId: 'web',
            atUtc: at(5).add(const Duration(microseconds: 7)),
            kind: JpEventKind.speakScore,
            body: {
              'sentence': 'たべます',
              'scores': [0.9, 0.7],
              'detail': {'accuracy': 88}
            }),
        JpEvent(
            eventId: newEventId(),
            deviceId: 'web',
            atUtc: at(6),
            kind: JpEventKind.lastLesson,
            body: {'lessonId': 'L26'}),
      ];
      expect(events.map((e) => e.kind).toSet(), JpEventKind.values.toSet());
      for (final e in events) {
        final map = e.toFirestore();
        expect(map['v'], kJpEventMapVersion);
        expect(map['kind'], e.kind.wire);
        expect(map['atUtc'], e.atUtc.toIso8601String());
        // Through JSON, as a document read back would arrive: every nested map loosened.
        final back = JpEvent.fromFirestore(
            jsonDecode(jsonEncode(map)) as Map<String, dynamic>);
        expect(back, e);
        expect(back.sameContent(e), isTrue, reason: '$map');
        expect(back.atUtc, e.atUtc, reason: 'microseconds survive');
      }
      expect([for (final k in JpEventKind.values) k.wire],
          ['attempt', 'seed', 'note', 'discuss', 'speak_score', 'last_lesson']);
      expect(attemptOfEvent(events[0]), attempt);
      expect(attemptOfEvent(events[0]).eventId, attempt.eventId);
      expect(seedOfEvent(events[1]), seed);
      expect(seedOfEvent(events[1]).deviceId, 'phone-a');
      // A server field the remote adds is ignored.
      expect(
          JpEvent.fromFirestore(
              {...events[2].toFirestore(), 'serverTime': 'anything'}),
          events[2]);
    });

    test('fromFirestore refuses a map it cannot trust', () {
      final good = remoteNote('x', 'n', at(0)).toFirestore();
      for (final bad in <Map<String, dynamic>>[
        {...good}..remove('eventId'),
        {...good, 'eventId': ''},
        {...good, 'deviceId': ''},
        {...good, 'deviceId': 7},
        {...good, 'atUtc': 'yesterday'},
        {...good, 'kind': 'mystery'},
        {...good, 'body': 'text'},
      ]) {
        expect(() => JpEvent.fromFirestore(bad), throwsFormatException,
            reason: '$bad');
      }
    });

    test(
        'a legacy event has no device id, and equality keys on the event id alone',
        () {
      final legacy = noteEvent('x', 'n',
          eventId: legacyEventId(JpEventKind.note, [null, 'x', null, 'n']),
          deviceId: null,
          atUtc: kLegacyNoteAtUtc);
      final map = legacy.toFirestore();
      expect(map.containsKey('deviceId'), isFalse);
      final back = JpEvent.fromFirestore(
          jsonDecode(jsonEncode(map)) as Map<String, dynamic>);
      expect(back.deviceId, isNull);
      expect(back.sameContent(legacy), isTrue);
      expect(
          JpEvent.fromFirestore({...map, 'deviceId': null}).deviceId, isNull);
      // The same id with another device or body is the same event (operator ruling,
      // Checkpoint 2026-11-19); sameContent still tells them apart.
      final copy = noteEvent('x', 'other',
          eventId: legacy.eventId, deviceId: 'web', atUtc: at(1));
      expect(copy, legacy);
      expect(copy.hashCode, legacy.hashCode);
      expect({legacy, copy}.length, 1);
      expect(copy.sameContent(legacy), isFalse);
      expect(remoteNote('x', 'n', kLegacyNoteAtUtc), isNot(legacy));
    });

    test('an attempt or a seed with no event id cannot become an event', () {
      final g = firstOf(ItemKind.grammar);
      expect(() => attemptEvent(answer(g, 1, Grade.clear)), throwsStateError);
      expect(() => seedEvent(SeedEvent(itemId: g.id, dueDay: 1, atUtc: at(0))),
          throwsStateError);
    });

    test('the replay stays pure: event ids and side events change no state',
        () {
      final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
      final bare = [
        answer(g, 1, Grade.clear),
        answer(w, 2, Grade.wrong),
        answer(g, 4, Grade.clear),
      ];
      final seeds = [SeedEvent(itemId: w.id, dueDay: 1, atUtc: at(0))];
      final plain = replayLog(
          StudyLog(attempts: bare, seeds: seeds), catalog.byId, scheduler);
      final stamped = replayLog(
          StudyLog(
            attempts: [
              for (final a in bare)
                a.withEvent(eventId: newEventId(), deviceId: 'web')
            ],
            seeds: [
              for (final s in seeds)
                s.withEvent(eventId: newEventId(), deviceId: 'web')
            ],
            events: [remoteNote(g.id, 'n', at(3))],
            notes: {g.id: 'n'},
          ),
          catalog.byId,
          scheduler);
      expect(stamped.srs, plain.srs);
      expect(stamped.mastery, plain.mastery);
      expect(stamped.seedDue, plain.seedDue);
    });
  });

  for (final entry in implementations.entries) {
    group('event ids (${entry.key})', () {
      late JpStore store;
      setUp(() async => store = await entry.value());
      tearDown(() => store.close());

      test(
          'every appended attempt and seed carries a distinct event id and this store\'s device id',
          () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        final device = await store.deviceId();
        expect(device, matches(uuidV4));
        expect(await store.deviceId(), device, reason: 'kept');
        expect(await store.meta(kDeviceIdMetaKey), device);

        final out = await store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        final plain = await store.appendAttempt(answer(w, 1, Grade.wrong));
        await store.appendSeeds([
          SeedEvent(itemId: 'a', dueDay: 2, atUtc: at(0)),
          SeedEvent(itemId: 'b', dueDay: 2, atUtc: at(0)),
        ]);
        expect(out.attempt.eventId, matches(uuidV4));
        expect(out.attempt.deviceId, device);
        final attempts = await store.attempts();
        expect([for (final a in attempts) a.eventId],
            [out.attempt.eventId, plain.eventId]);
        final seeds = await store.seeds();
        expect(seeds.every((s) => s.deviceId == device), isTrue);
        final ids = {
          for (final a in attempts) a.eventId,
          for (final s in seeds) s.eventId,
        };
        expect(ids.length, 4);
        expect(ids.every((id) => id != null && uuidV4.hasMatch(id)), isTrue);

        // An id already set (an import, a remote) is kept, never replaced.
        final given = answer(g, 2, Grade.clear)
            .withEvent(eventId: 'given-id', deviceId: 'phone-b');
        final kept = await store.appendAttempt(given);
        expect([kept.eventId, kept.deviceId], ['given-id', 'phone-b']);
      });

      test('a new event is unpushed until marked, and is pushed once',
          () async {
        final g = firstOf(ItemKind.grammar);
        expect(await store.unpushedEvents(), isEmpty);
        final out = await store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        await store.appendSeed(g.id, 5, atUtc: at(1, 1));
        now = at(1, 5);
        await store.setNote(g.id, kNoteCanUseIt);
        await store.setDiscuss(g.id, note: 'ask', atUtc: at(1, 6));
        await store
            .recordSpeakScore({'sentence': 'x', 'score': 80}, atUtc: at(1, 7));
        await store.setLastLesson('L26', atUtc: at(1, 8));

        final unpushed = await store.unpushedEvents();
        expect([
          for (final e in unpushed) e.kind
        ], [
          JpEventKind.attempt,
          JpEventKind.seed,
          JpEventKind.note,
          JpEventKind.discuss,
          JpEventKind.speakScore,
          JpEventKind.lastLesson,
        ], reason: 'oldest first');
        expect(contentOf([unpushed.first]),
            contentOf([attemptEvent(out.attempt)]));
        expect(contentOf(unpushed), contentOf(await store.allEvents()));

        await store.markPushed([
          for (final e in unpushed.take(3)) e.eventId,
          'an-id-nobody-holds',
        ]);
        expect(idsOf(await store.unpushedEvents()), idsOf(unpushed.skip(3)));
        await store.markPushed(idsOf(unpushed));
        expect(await store.unpushedEvents(), isEmpty);

        // Only what is new is unpushed after a push.
        final next = await store.recordAnswer(answer(g, 2, Grade.clear),
            item: g, scheduler: scheduler);
        expect(contentOf(await store.unpushedEvents()),
            contentOf([attemptEvent(next.attempt)]));
      });

      test(
          'remote events append once, land pushed, and replay to the same states',
          () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        final source = await entry.value();
        try {
          await source.appendSeed(w.id, 2, atUtc: at(0));
          for (final (item, day, grade) in [
            (g, 1, Grade.clear),
            (w, 2, Grade.wrong),
            (g, 4, Grade.clear),
            (w, 5, Grade.clear),
          ]) {
            await source.recordAnswer(answer(item, day, grade),
                item: item, scheduler: scheduler);
          }
          now = at(5, 30);
          await source.setNote(g.id, kNoteCanUseIt);
          await source.setDiscuss(w.id, note: 'why?', atUtc: at(5, 31));
          await source.setLastLesson('L27', atUtc: at(5, 32));
          final sent = await source.unpushedEvents();

          // Sent twice, and once more inside one batch: each lands once.
          final added = await store.appendRemoteEvents([...sent, sent.first]);
          expect(added, sent);
          expect(await store.appendRemoteEvents(sent), isEmpty);
          expect(await store.unpushedEvents(), isEmpty,
              reason: 'a remote event is already on the server');
          expect(contentOf(await store.allEvents()),
              contentOf(await source.allEvents()));
          expect((await store.attempts()).length, 4);
          expect((await store.seeds()).length, 1);

          // The side events show at once; the log waits for the rebuild.
          expect(await store.notes(), {g.id: kNoteCanUseIt});
          expect(await store.discuss(w.id),
              DiscussMark(itemId: w.id, note: 'why?', atUtc: at(5, 31)));
          expect(await store.lastLesson(), 'L27');
          expect(await store.allSrs(), isEmpty);
          await store.rebuild(catalog.byId, scheduler);
          expect(await store.allSrs(), await source.allSrs());
          expect(await store.allMastery(), await source.allMastery());
          expect(await store.dueOnOrBefore(1000),
              await source.dueOnOrBefore(1000));
        } finally {
          await source.close();
        }
      });

      test('a note resolves to the latest event time (PIN-12)', () async {
        final g = firstOf(ItemKind.grammar);
        now = at(3);
        await store.setNote(g.id, 'mine');
        // An older change from the other device loses.
        await store.appendRemoteEvents([remoteNote(g.id, 'older', at(2))]);
        expect(await store.notes(), {g.id: 'mine'});
        // A later one wins, and a later clear clears it.
        await store.appendRemoteEvents([remoteNote(g.id, 'newer', at(4))]);
        expect((await store.item(g.id))!.note, 'newer');
        await store.appendRemoteEvents([remoteNote(g.id, null, at(5))]);
        expect(await store.notes(), isEmpty);
        expect(await store.item(g.id), isNull);
        // Two events at one instant: the larger event id wins, whatever the order.
        await store.appendRemoteEvents([
          remoteNote(g.id, 'from-b', at(6), eventId: 'b-event'),
          remoteNote(g.id, 'from-a', at(6), eventId: 'a-event'),
        ]);
        expect(await store.notes(), {g.id: 'from-b'});
        expect(resolveNotes((await store.sideEvents()).reversed),
            {g.id: 'from-b'});
      });

      test('a Discuss mark resolves to the latest event time (PIN-12)',
          () async {
        final g = firstOf(ItemKind.grammar);
        await store.setDiscuss(g.id, note: 'mine', atUtc: at(3));
        await store.appendRemoteEvents([
          discussEvent(g.id,
              cleared: true,
              eventId: newEventId(),
              deviceId: 'phone-b',
              atUtc: at(2)),
        ]);
        expect(await store.discuss(g.id),
            DiscussMark(itemId: g.id, note: 'mine', atUtc: at(3)),
            reason: 'an older clear loses');
        await store.appendRemoteEvents([
          discussEvent(g.id,
              note: 'theirs',
              eventId: newEventId(),
              deviceId: 'phone-b',
              atUtc: at(4)),
        ]);
        expect(await store.discussMarks(),
            {g.id: DiscussMark(itemId: g.id, note: 'theirs', atUtc: at(4))});
        now = at(5);
        await store.clearDiscuss(g.id);
        expect(await store.discuss(g.id), isNull);
        final clear = (await store.sideEvents()).last;
        expect(clear.body, {'itemId': g.id, 'cleared': true});
        expect(clear.atUtc, at(5));
        expect(clear.deviceId, await store.deviceId());
      });

      test(
          'a local change lands after its subject\'s latest event, even with a clock behind it',
          () async {
        final g = firstOf(ItemKind.grammar);
        await store.appendRemoteEvents([remoteNote(g.id, 'future', at(9))]);
        now = at(1);
        await store.setNote(g.id, 'just now');
        expect(await store.notes(), {g.id: 'just now'});
        final mine = (await store.sideEvents()).last;
        // The bump is 1 ms, which a millisecond DateTime on the web still keeps (#193).
        expect(mine.atUtc, at(9).add(const Duration(milliseconds: 1)));
        // Two changes at one clock instant keep their order.
        now = at(20);
        await store.setNote(g.id, kNoteCanUseIt);
        await store.setNote(g.id, null);
        expect(await store.notes(), isEmpty);
        // Clearing a note or a mark that is not there writes nothing.
        final count = (await store.sideEvents()).length;
        await store.setNote('never-noted', null);
        await store.clearDiscuss('never-marked');
        expect((await store.sideEvents()).length, count);
      });

      test('say-it scores and the last lesson are timestamped events (PIN-16)',
          () async {
        expect(await store.lastLesson(), isNull);
        expect(await store.speakScores(), isEmpty);
        final first = await store.recordSpeakScore(
            {'sentence': 'たべます', 'verdict': 'correct'},
            atUtc: at(1));
        await store.recordSpeakScore({'sentence': 'のみます', 'verdict': 'close'},
            atUtc: at(1));
        final scores = await store.speakScores();
        expect(scores.length, 2, reason: 'a score replaces nothing');
        expect(scores.every((e) => e.kind == JpEventKind.speakScore), isTrue);
        expect(scores.first.atUtc, at(1), reason: 'a score keeps its time');
        expect(scores, contains(first));

        await store.setLastLesson('L26', atUtc: at(2));
        await store.appendRemoteEvents([
          JpEvent(
              eventId: newEventId(),
              deviceId: 'web',
              atUtc: at(1, 30),
              kind: JpEventKind.lastLesson,
              body: {'lessonId': 'L20'}),
        ]);
        expect(await store.lastLesson(), 'L26', reason: 'older loses');
        await store.appendRemoteEvents([
          JpEvent(
              eventId: newEventId(),
              deviceId: 'web',
              atUtc: at(3),
              kind: JpEventKind.lastLesson,
              body: {'lessonId': 'L28'}),
        ]);
        expect(await store.lastLesson(), 'L28');
        // Nothing here touches the log.
        expect(await store.attempts(), isEmpty);
        expect(await store.allSrs(), isEmpty);
      });

      test('a day record carries the device and the time that built it',
          () async {
        final device = await store.deviceId();
        now = at(4, 10);
        await store.putDay(const DayRecord(day: 4, plan: '{"p":1}'));
        var day = (await store.day(4))!;
        expect(day.deviceId, device);
        expect(day.builtAtUtc, at(4, 10));

        // A move through the plan keeps its builder and build time.
        now = at(4, 50);
        await store.putDay(day.copyWith(position: 2));
        await store
            .putDay(const DayRecord(day: 4, plan: '{"p":1}', position: 3));
        day = (await store.day(4))!;
        expect([day.position, day.deviceId, day.builtAtUtc],
            [3, device, at(4, 10)]);

        // A new plan for the day is built now; one from another device keeps its own.
        await store.putDay(const DayRecord(day: 4, plan: '{"p":2}'));
        expect((await store.day(4))!.builtAtUtc, at(4, 50));
        await store.putDay(DayRecord(
            day: 5, plan: '{}', deviceId: 'web', builtAtUtc: at(5, 1)));
        day = (await store.day(5))!;
        expect([day.deviceId, day.builtAtUtc], ['web', at(5, 1)]);
      });

      test('export and import carry event ids and event times (version 3)',
          () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        await store.appendSeed(w.id, 2, atUtc: at(0));
        await store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        await store.recordAnswer(answer(w, 2, Grade.wrong),
            item: w, scheduler: scheduler);
        now = at(2, 10);
        await store.setNote(g.id, 'first');
        now = at(2, 11);
        await store.setNote(g.id, null);
        await store.setNote(w.id, kNoteCanUseIt);
        await store.setDiscuss(g.id, note: 'ask', atUtc: at(2, 12));
        now = at(2, 13);
        await store.clearDiscuss(g.id);
        await store.setDiscuss(w.id, atUtc: at(2, 14));
        await store
            .recordSpeakScore({'sentence': 'x', 'score': 91}, atUtc: at(2, 15));
        await store.setLastLesson('L26', atUtc: at(2, 16));
        await store.appendRemoteEvents([remoteNote('z', 'from b', at(2, 17))]);

        final text = await exportStudy(store, exportedAt: at(10));
        final lines = const LineSplitter().convert(text);
        final header = jsonDecode(lines.first) as Map<String, dynamic>;
        expect(header['version'], kStudyExportVersion);
        expect(kStudyExportVersion, 3);
        expect([
          header['attempts'],
          header['seeds'],
          header['notes'],
          header['discuss'],
          header['events'],
        ], [
          2,
          1,
          4,
          3,
          2
        ], reason: 'every note and Discuss change is its own line');
        for (final l in lines.skip(1)) {
          final j = jsonDecode(l) as Map<String, dynamic>;
          expect(j['eventId'], isA<String>(), reason: l);
          expect(j['deviceId'], isA<String>(), reason: l);
          expect(j['atUtc'], isA<String>(), reason: l);
        }
        expect(lines.where((l) => l.contains('"type":"note"')).last,
            contains('"note":"from b"'));

        final log = decodeStudyExport(text);
        expect(log.notes, {w.id: kNoteCanUseIt, 'z': 'from b'});
        expect(log.discuss.keys, [w.id]);
        expect(idsOf(log.events), idsOf(await store.sideEvents()));

        for (final open in implementations.values) {
          final other = await open();
          try {
            await other.recordAnswer(answer(g, 20, Grade.wrong),
                item: g, scheduler: scheduler);
            await importStudy(other, text,
                lookup: catalog.byId, scheduler: scheduler);
            expect(contentOf(await other.allEvents()),
                contentOf(await store.allEvents()),
                reason: 'the same ids, devices and times');
            expect(await other.notes(), await store.notes());
            expect(await other.discussMarks(), await store.discussMarks());
            expect(await other.lastLesson(), 'L26');
            expect(contentOf(await other.speakScores()),
                contentOf(await store.speakScores()));
            expect(await other.allSrs(), await store.allSrs());
            expect(await exportStudy(other, exportedAt: at(10)), text);
          } finally {
            await other.close();
          }
        }
      });

      test('an import keeps pushed what this store already pushed', () async {
        final g = firstOf(ItemKind.grammar);
        await store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        await store.setNote(g.id, kNoteCanUseIt);
        await store.markPushed(idsOf(await store.unpushedEvents()));
        final text = await exportStudy(store, exportedAt: at(10));
        await store.recordAnswer(answer(g, 2, Grade.clear),
            item: g, scheduler: scheduler);
        await importStudy(store, text,
            lookup: catalog.byId, scheduler: scheduler);
        expect(await store.unpushedEvents(), isEmpty,
            reason: 'the record uploads once');
        expect((await store.attempts()).length, 1);
      });

      test('an export from before event ids gets an id on every event',
          () async {
        final fixture =
            File('test/fixtures/study_export_v1.jsonl').readAsStringSync();
        final log = decodeStudyExport(fixture);
        expect(log.attempts.every((a) => a.eventId == null), isTrue);
        expect(log.events, isEmpty);
        now = at(30);
        await importStudy(store, fixture,
            lookup: catalog.byId, scheduler: scheduler);
        final device = await store.deviceId();
        final events = await store.allEvents();
        expect(events.length,
            log.attempts.length + log.seeds.length + log.notes.length);
        expect(events.every((e) => e.deviceId == null), isTrue,
            reason: 'a legacy event carries no device id');
        expect(idsOf(events).length, events.length);
        expect(contentOf(await store.unpushedEvents()), contentOf(events));
        final notes = [
          for (final e in events)
            if (e.kind == JpEventKind.note) e
        ];
        expect(notes.every((e) => e.atUtc == kLegacyNoteAtUtc), isTrue,
            reason:
                'a note with no time takes the legacy time, not the import\'s');
        // Exported again, the ids are the store's own, the same on every export.
        final once = await exportStudy(store, exportedAt: at(31));
        expect(await exportStudy(store, exportedAt: at(31)), once);
        expect(idsOf(decodeStudyExport(once).events), idsOf(notes));

        // The ids derive from the rows (operator ruling, Checkpoint 2026-11-19): the same
        // old export on another device, at another time, gets the same events.
        for (final open in implementations.values) {
          final other = await open();
          try {
            now = at(40);
            await importStudy(other, fixture,
                lookup: catalog.byId, scheduler: scheduler);
            expect(await other.deviceId(), isNot(device));
            expect(idsOf(await other.allEvents()), idsOf(events));
            expect(contentOf(await other.allEvents()), contentOf(events),
                reason: 'byte-identical legacy events on every device');
          } finally {
            await other.close();
          }
        }
      });

      test('a legacy id hashes the row content, once per repeat', () {
        final g = firstOf(ItemKind.grammar);
        final a = answer(g, 1, Grade.clear);
        final ids = LegacyEventIds();
        final first = ids.attempt(a);
        final again = ids.attempt(a);
        expect(first, isNot(again), reason: 'a repeat of the same row');
        expect(LegacyEventIds().attempt(a), first, reason: 'stable');
        expect(uuidV5.hasMatch(first), isTrue, reason: first);
        // Time, item, session and kind each move the id.
        final fresh = LegacyEventIds();
        final moved = {
          fresh.attempt(answer(g, 2, Grade.clear)),
          fresh.attempt(Attempt.fromJson({...a.toJson(), 'sessionId': 'x'})),
          fresh.attempt(answer(firstOf(ItemKind.word), 1, Grade.clear)),
          fresh.seed(SeedEvent(itemId: g.id, dueDay: 1, atUtc: a.atUtc)),
        };
        expect(moved.length, 4);
        expect(moved, isNot(contains(first)));
        // The grade is not part of the key: the same answer slot keeps its id.
        expect(LegacyEventIds().attempt(answer(g, 1, Grade.wrong)), first);
      });

      test(
          'a legacy id keys the time to the millisecond, as a web DateTime holds',
          () {
        final g = firstOf(ItemKind.grammar);
        final a = answer(g, 1, Grade.clear);
        final ms = a.atUtc.add(const Duration(milliseconds: 7));
        final phone = ms.add(const Duration(microseconds: 321));
        Attempt timed(DateTime t) =>
            Attempt.fromJson({...a.toJson(), 'atUtc': t.toIso8601String()});
        // The oracle spells the millisecond time by hand, not through the code under test.
        const key = '2026-03-03T12:00:00.007Z';
        expect(
            LegacyEventIds().attempt(timed(phone)),
            legacyEventId(JpEventKind.attempt, [key, g.id, 's1'],
                occurrence: 0));
        expect(LegacyEventIds().attempt(timed(phone)),
            LegacyEventIds().attempt(timed(ms)),
            reason: 'microseconds alone never move the id');
        expect(
            LegacyEventIds()
                .seed(SeedEvent(itemId: g.id, dueDay: 1, atUtc: phone)),
            legacyEventId(JpEventKind.seed, [key, g.id, null], occurrence: 0));
        expect(
            LegacyEventIds()
                .discuss(DiscussMark(itemId: g.id, atUtc: phone, note: 'n')),
            legacyEventId(JpEventKind.discuss, [key, g.id, null, 'n'],
                occurrence: 0));
        // A whole millisecond still moves the id, and a shared key takes the next occurrence.
        final ids = LegacyEventIds();
        final x = ids.attempt(timed(phone));
        expect(ids.attempt(timed(ms)), isNot(x), reason: 'occurrence 1');
        expect(
            LegacyEventIds()
                .attempt(timed(ms.add(const Duration(milliseconds: 1)))),
            isNot(x));
      });

      test('an id-less import reuses the id the store holds for the same row',
          () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        final out = await store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        await store.appendSeed(w.id, 3, atUtc: at(1, 5));
        await store.setDiscuss(w.id, note: 'ask', atUtc: at(1, 6));
        now = at(1, 7);
        await store.setNote(g.id, kNoteCanUseIt);
        final held = await store.allEvents();
        expect(held.every((e) => uuidV4.hasMatch(e.eventId)), isTrue,
            reason: 'a new event takes a random id');
        final seed = (await store.seeds()).single;
        // The same rows with no ids, as a pre-v3 backup holds them.
        final bare = StudyLog(
          attempts: [
            Attempt.fromJson(out.attempt.toJson()
              ..remove('id')
              ..remove('eventId')
              ..remove('deviceId')),
            answer(g, 2, Grade.clear),
          ],
          seeds: [SeedEvent(itemId: w.id, dueDay: 3, atUtc: seed.atUtc)],
          notes: {g.id: kNoteCanUseIt},
          discuss: {
            w.id: DiscussMark(itemId: w.id, note: 'ask', atUtc: at(1, 6))
          },
        );
        await store.importLog(bare, catalog.byId, scheduler);
        final after = await store.allEvents();
        expect(idsOf(after), containsAll(idsOf(held)));
        expect(after.length, held.length + 1);
        final added =
            after.singleWhere((e) => !idsOf(held).contains(e.eventId));
        expect(
            added.eventId, LegacyEventIds().attempt(answer(g, 2, Grade.clear)),
            reason: 'a row the store does not hold takes its legacy id');
        for (final e in held) {
          expect(after.singleWhere((x) => x.eventId == e.eventId), e,
              reason: 'a held event keeps its device and time');
        }
      });
    });
  }

  group('the event id migration (SQLite, End state 4)', () {
    late Directory dir;
    late String path;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('jp_event_test');
      path = '${dir.path}/jp_study.db';
    });
    tearDown(() => dir.delete(recursive: true));

    Future<JpStoreSqlite> open() => JpStoreSqlite.open(
        factory: databaseFactoryFfi, path: path, clock: clock);

    test(
        'a version 2 file gets event ids once, keeps them on every later open, and uploads once',
        () async {
      final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
      // The file as the build before event ids left it.
      var store = await JpStoreSqlite.open(
          factory: databaseFactoryFfi, path: path, version: 2);
      expect(await store.schemaVersion(), 2);
      await store.close();
      final source = JpStoreMemory();
      await source.appendSeed(w.id, 2, atUtc: at(0));
      await source.recordAnswer(answer(g, 1, Grade.clear),
          item: g, scheduler: scheduler);
      await source.recordAnswer(answer(w, 2, Grade.wrong),
          item: w, scheduler: scheduler);
      final oldAttempts = await source.attempts();
      final oldSrs = await source.allSrs();
      final oldMastery = await source.allMastery();
      await writeOldRows(path,
          attempts: oldAttempts,
          srs: oldSrs,
          mastery: oldMastery.values.toList(),
          seeds: await source.seeds(),
          notes: {g.id: kNoteCanUseIt},
          discuss: [DiscussMark(itemId: w.id, note: 'ask', atUtc: at(2, 5))],
          days: [const DayRecord(day: 2, plan: '{}', position: 1)]);

      now = at(3);
      store = await open();
      expect(await store.schemaVersion(), kJpStoreSchemaVersion);
      final device = await store.deviceId();
      final attempts = await store.attempts();
      expect(attempts, oldAttempts, reason: 'every row stays');
      expect(attempts.every((a) => a.eventId != null && a.deviceId == null),
          isTrue,
          reason: 'a legacy row carries no device id');
      final seeds = await store.seeds();
      expect(seeds.single.deviceId, isNull);
      expect(await store.allSrs(), oldSrs);
      expect(await store.allMastery(), oldMastery);
      expect(await store.notes(), {g.id: kNoteCanUseIt});
      expect(await store.discuss(w.id),
          DiscussMark(itemId: w.id, note: 'ask', atUtc: at(2, 5)));
      expect((await store.day(2))!.deviceId, device);

      final events = await store.allEvents();
      expect(
          [for (final e in events) e.kind]..sort((a, b) => a.index - b.index), [
        JpEventKind.attempt,
        JpEventKind.attempt,
        JpEventKind.seed,
        JpEventKind.note,
        JpEventKind.discuss,
      ]);
      expect(idsOf(events).length, 5);
      expect(events.every((e) => uuidV5.hasMatch(e.eventId)), isTrue,
          reason: 'a migrated row takes its legacy id');
      final discussAt = events.firstWhere((e) => e.kind == JpEventKind.discuss);
      expect(discussAt.atUtc, at(2, 5), reason: 'a mark keeps its time');
      final noteAt = events.firstWhere((e) => e.kind == JpEventKind.note);
      expect(noteAt.atUtc, kLegacyNoteAtUtc,
          reason: 'a note with no time takes the legacy time');
      expect(contentOf(await store.unpushedEvents()), contentOf(events));

      // A move through a migrated day keeps its unknown build time (#191).
      final migratedDay = (await store.day(2))!;
      expect(migratedDay.builtAtUtc, isNull);
      await store.putDay(migratedDay.copyWith(position: 2));
      expect([(await store.day(2))!.position, (await store.day(2))!.builtAtUtc],
          [2, isNull]);
      await store.close();

      // A restored old backup on another device maps onto the uploaded events: the same
      // rows with no ids get the same ids and the same times.
      final restored = JpStoreMemory(clock: () => at(50));
      await restored.importLog(
          StudyLog(
            attempts: [
              for (final a in oldAttempts)
                Attempt.fromJson(a.toJson()
                  ..remove('id')
                  ..remove('eventId')
                  ..remove('deviceId'))
            ],
            seeds: [
              for (final s in await source.seeds())
                SeedEvent(itemId: s.itemId, dueDay: s.dueDay, atUtc: s.atUtc)
            ],
            notes: {g.id: kNoteCanUseIt},
            discuss: {
              w.id: DiscussMark(itemId: w.id, note: 'ask', atUtc: at(2, 5))
            },
          ),
          catalog.byId,
          scheduler);
      final restoredEvents = await restored.allEvents();
      expect(idsOf(restoredEvents), idsOf(events));
      expect([for (final e in restoredEvents) e.atUtc],
          [for (final e in events) e.atUtc]);
      expect([for (final e in restoredEvents) e.body],
          [for (final e in events) e.body]);
      expect(contentOf(restoredEvents), contentOf(events),
          reason: 'no device id, so the same events byte for byte');

      // Reopened: the same ids and the same device, still unpushed.
      now = at(9);
      store = await open();
      expect(await store.deviceId(), device);
      expect(contentOf(await store.allEvents()), contentOf(events));
      expect(contentOf(await store.unpushedEvents()), contentOf(events));
      await store.markPushed(idsOf(events));
      await store.close();

      // Pushed once: no later open offers them again.
      store = await open();
      expect(await store.unpushedEvents(), isEmpty);
      expect(contentOf(await store.allEvents()), contentOf(events));
      // The ids ride an export into another store.
      final other = JpStoreMemory();
      await importStudy(other, await exportStudy(store, exportedAt: at(10)),
          lookup: catalog.byId, scheduler: scheduler);
      expect(contentOf(await other.allEvents()), contentOf(events));
      expect(await other.allSrs(), oldSrs);
      await store.close();
    });

    test('the schema has the events table and unique event id indexes',
        () async {
      final store = await open();
      final g = firstOf(ItemKind.grammar);
      final out = await store.recordAnswer(answer(g, 1, Grade.clear),
          item: g, scheduler: scheduler);
      await store.close();
      final db = await databaseFactoryFfi.openDatabase(path);
      try {
        final tables = (await db.rawQuery(
                "SELECT name FROM sqlite_master WHERE type = 'table'"))
            .map((r) => r['name'])
            .toSet();
        expect(tables, contains('events'));
        final indexes = [
          for (final r in await db.rawQuery(
              "SELECT sql FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL"))
            r['sql'] as String
        ];
        expect(
            indexes,
            containsAll([
              contains('UNIQUE INDEX attempts_eventId ON attempts (eventId)'),
              contains('UNIQUE INDEX seeds_eventId ON seeds (eventId)'),
            ]));
        // The id lives in its column, not in the attempt's JSON.
        final row = (await db.query('attempts')).single;
        expect(row['eventId'], out.attempt.eventId);
        expect(row['pushed'], 0);
        expect(jsonDecode(row['json'] as String), isNot(contains('eventId')));
      } finally {
        await db.close();
      }
    });
  });
}
