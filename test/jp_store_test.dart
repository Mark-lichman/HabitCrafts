// The study store (Task 8, D14, D26, A4, A5). One suite runs against both implementations:
// `JpStoreMemory` (the web store) and `JpStoreSqlite` through the ffi factory. The SQLite-only
// group covers the schema version, the indexes and a reopen of the file.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/study_export.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart'
    show Judgement;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final grammarDoc = _read('assets/lessons/jp_grammar.json');
final catalog =
    ItemCatalog.fromDocs(grammarDoc, _read('assets/lessons/jp_lessons.json'));
const scheduler = FsrsScheduler();

final t0 = DateTime.utc(2026, 3, 2, 12);
DateTime at(int day, [int minute = 0]) =>
    t0.add(Duration(days: day, minutes: minute));

ItemDef firstOf(ItemKind kind) => catalog.ofKind(kind).first;

/// An attempt on [item]'s first scored probe, graded [grade], on local day [day].
Attempt answer(ItemDef item, int day, Grade grade,
    {Source source = Source.review,
    bool wasDue = true,
    int probe = 0,
    int minute = 0}) {
  final p = item.scoredProbes.elementAt(probe % item.probeCount);
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
    wasDue: wasDue,
    source: source,
    sessionId: 's$day',
  );
}

typedef Opener = Future<JpStore> Function();

final Map<String, Opener> implementations = {
  'memory': () async => JpStoreMemory(),
  'sqlite': () => JpStoreSqlite.open(
      factory: databaseFactoryFfi, path: inMemoryDatabasePath),
};

void main() {
  sqfliteFfiInit();

  for (final entry in implementations.entries) {
    group('JpStore (${entry.key})', () {
      late JpStore store;
      setUp(() async => store = await entry.value());
      tearDown(() => store.close());

      test('appends attempts in order with row ids and filters by item',
          () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        final a1 = await store.appendAttempt(answer(g, 1, Grade.clear));
        final a2 =
            await store.appendAttempt(answer(w, 1, Grade.hinted, minute: 1));
        final a3 = await store.appendAttempt(answer(g, 2, Grade.wrong));
        expect([a1.id, a2.id, a3.id], [1, 2, 3]);
        expect(await store.attempts(), [a1, a2, a3]);
        expect(await store.attempts(itemId: g.id), [a1, a3]);
        expect((await store.attempts()).first.hintLevel, 0);
      });

      test('one answer writes its attempt, schedule and mastery together',
          () async {
        final g = firstOf(ItemKind.grammar);
        final out = await store.recordAnswer(answer(g, 5, Grade.clear),
            item: g, scheduler: scheduler);
        expect(await store.attempts(), [out.attempt]);
        expect(out.srs, isNotNull);
        expect(await store.srs(g.id), out.srs);
        expect(out.mastery!.status, MasteryStatus.learning);
        expect(out.mastery!.clearCount, 1);
        expect(await store.mastery(g.id), out.mastery);
      });

      test('a mastery state for another item writes nothing', () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        await expectLater(
            store.appendAttempt(answer(g, 1, Grade.clear),
                srs: scheduler.first(SrsRating.good, 1),
                mastery: MasteryState.initial(w.id)),
            throwsArgumentError);
        expect(await store.attempts(), isEmpty);
        expect(await store.srs(g.id), isNull);
        expect(await store.mastery(w.id), isNull);
      });

      test('reads and writes SrsState and MasteryState', () async {
        final s = scheduler.first(SrsRating.hard, 3);
        await store.putSrs('x', s);
        expect(await store.srs('x'), s);
        expect(await store.allSrs(), {'x': s});
        const m = MasteryState(
            itemId: 'x',
            status: MasteryStatus.learning,
            clears: [
              ClearRef(
                  day: 3, template: 'fill', production: true, probeId: 'p0')
            ],
            lastScoredDay: 3);
        await store.putMastery(m);
        expect(await store.mastery('x'), m);
        expect(await store.allMastery(), {'x': m});
        expect(await store.srs('missing'), isNull);
        expect(await store.mastery('missing'), isNull);
      });

      test(
          'a seed writes a due day, no attempt, no schedule and no mastery (D26, PIN-7)',
          () async {
        final g = firstOf(ItemKind.grammar);
        await store.appendSeed(g.id, 7, atUtc: at(0));
        expect(await store.attempts(), isEmpty);
        expect(await store.srs(g.id), isNull);
        expect(await store.mastery(g.id), isNull);
        expect((await store.item(g.id))!.seedDueDay, 7);
        expect(await store.seeds(),
            [SeedEvent(id: 1, itemId: g.id, dueDay: 7, atUtc: at(0))]);
        // The earliest seeded due day wins.
        await store.appendSeed(g.id, 9, atUtc: at(0, 1));
        await store.appendSeed(g.id, 4, atUtc: at(0, 2));
        expect((await store.item(g.id))!.seedDueDay, 4);
        expect((await store.seeds()).length, 3);
        // A first real clear on a seeded item is clear one of four.
        final out = await store.recordAnswer(answer(g, 4, Grade.clear),
            item: g, scheduler: scheduler);
        expect(out.mastery!.clearCount, 1);
        expect(out.mastery!.status, MasteryStatus.learning);
      });

      test(
          'due items on or before a day: stateful by FSRS, seeded by seed, sorted',
          () async {
        await store.appendSeeds([
          SeedEvent(itemId: 'b', dueDay: 2, atUtc: at(0)),
          SeedEvent(itemId: 'a', dueDay: 2, atUtc: at(0)),
          SeedEvent(itemId: 'c', dueDay: 9, atUtc: at(0)),
          SeedEvent(itemId: 'd', dueDay: 1, atUtc: at(0)),
        ]);
        await store.putSrs(
            's', scheduler.first(SrsRating.good, 0).copyWith(dueDay: 2));
        await store.putSrs(
            't', scheduler.first(SrsRating.good, 0).copyWith(dueDay: 30));
        // `d` has a schedule now: its FSRS due day replaces the seed's.
        await store.putSrs(
            'd', scheduler.first(SrsRating.good, 0).copyWith(dueDay: 12));
        expect(await store.dueOnOrBefore(2), const [
          DueItem(itemId: 's', dueDay: 2, seeded: false),
          DueItem(itemId: 'a', dueDay: 2, seeded: true),
          DueItem(itemId: 'b', dueDay: 2, seeded: true),
        ]);
        expect(await store.dueOnOrBefore(1), isEmpty);
        expect(await store.loadByDay(), {2: 3, 9: 1, 12: 1, 30: 1});
      });

      test(
          'a DayRecord per local day holds the plan, its position and completion',
          () async {
        expect(await store.lastDay(), isNull);
        expect(await store.day(40), isNull);
        final plan = jsonEncode({
          'entries': ['a', 'b', 'c'],
          'stretchOffer': false
        });
        await store.putDay(DayRecord(day: 40, plan: plan));
        await store
            .putDay(const DayRecord(day: 38, plan: '{}', completed: true));
        expect(await store.day(40), DayRecord(day: 40, plan: plan));
        await store.putDay(DayRecord(day: 40, plan: plan, position: 2));
        await store.putDay(
            (await store.day(40))!.copyWith(position: 3, completed: true));
        expect(await store.day(40),
            DayRecord(day: 40, plan: plan, position: 3, completed: true));
        expect(await store.lastDay(), 40);
      });

      test('notes and flags', () async {
        await store.setNote('n', kNoteCanUseIt);
        expect((await store.item('n'))!.note, kNoteCanUseIt);
        expect(await store.notes(), {'n': kNoteCanUseIt});
        await store.setNote('n', null);
        expect(await store.notes(), isEmpty);
        expect(await store.item('n'), isNull);
        expect(await store.meta('k'), isNull);
        await store.putMeta('k', 'v');
        expect(await store.meta('k'), 'v');
      });

      test(
          'early practice: a clear changes nothing, a wrong counts and is due tomorrow (PIN-14)',
          () async {
        final g = firstOf(ItemKind.grammar);
        final first = await store.recordAnswer(answer(g, 10, Grade.clear),
            item: g, scheduler: scheduler);
        final early = await store.recordAnswer(
            answer(g, 11, Grade.clear, source: Source.early, wasDue: false),
            item: g,
            scheduler: scheduler);
        expect(early.srs, first.srs);
        expect(early.mastery, first.mastery);
        expect(await store.srs(g.id), first.srs);
        final wrong = await store.recordAnswer(
            answer(g, 11, Grade.wrong,
                source: Source.early, wasDue: false, minute: 5),
            item: g,
            scheduler: scheduler);
        expect(wrong.srs!.dueDay, 12);
        expect(wrong.srs!.lapses, 1);
        expect(wrong.mastery!.clearCount, 0);
        expect((await store.attempts()).length, 3);
      });

      test('unscored and Say-it answers move neither schedule nor mastery',
          () async {
        final g = firstOf(ItemKind.grammar);
        final before = await store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        final unscored = await store.recordAnswer(answer(g, 2, Grade.unscored),
            item: g, scheduler: scheduler);
        final sayIt = await store.recordAnswer(
            answer(g, 2, Grade.clear, source: Source.sayIt, minute: 1),
            item: g,
            scheduler: scheduler);
        expect(unscored.srs, before.srs);
        expect(sayIt.srs, before.srs);
        expect(sayIt.mastery, before.mastery);
      });

      test(
          'a rebuild from the log and the seed events lands on the live states',
          () async {
        // A 120-day learner over a slice of the catalog, answering whatever is due, with load
        // spreading over a crowded seed, early practice and Say-it in the mix.
        final rng = Random(8);
        final items = [
          ...catalog.ofKind(ItemKind.grammar).take(12),
          ...catalog.ofKind(ItemKind.word).take(20),
          ...catalog.ofKind(ItemKind.particle).take(6),
          ...catalog.ofKind(ItemKind.conjugation).take(6),
        ];
        await store.appendSeeds([
          for (var i = 0; i < items.length; i++)
            SeedEvent(itemId: items[i].id, dueDay: i % 10, atUtc: at(-1)),
          // A crowded far day pushes spread due days around.
          for (var i = 0; i < 40; i++)
            SeedEvent(itemId: 'crowd.$i', dueDay: 30 + i % 3, atUtc: at(-1)),
        ]);
        for (var day = 0; day < 120; day++) {
          final due = await store.dueOnOrBefore(day);
          var minute = 0;
          for (final d in due) {
            final item = catalog.byId(d.itemId);
            if (item == null) continue;
            final roll = rng.nextDouble();
            final grade = roll < 0.80
                ? Grade.clear
                : roll < 0.90
                    ? Grade.hinted
                    : roll < 0.97
                        ? Grade.wrong
                        : Grade.unscored;
            await store.recordAnswer(
                answer(item, day, grade,
                    probe: rng.nextInt(5), minute: minute++),
                item: item,
                scheduler: scheduler);
          }
          if (day % 9 == 0) {
            final item = items[rng.nextInt(items.length)];
            await store.recordAnswer(
                answer(item, day, rng.nextBool() ? Grade.clear : Grade.wrong,
                    source: Source.early, wasDue: false, minute: minute++),
                item: item,
                scheduler: scheduler);
            await store.recordAnswer(
                answer(item, day, Grade.clear,
                    source: Source.sayIt, minute: minute++),
                item: item,
                scheduler: scheduler);
          }
        }
        final srs = await store.allSrs();
        final mastery = await store.allMastery();
        final load = await store.loadByDay();
        expect(srs.values.any((s) => s.interval >= 20), isTrue,
            reason:
                'the history reaches intervals where load spreading moves due days');
        expect(mastery.values.any((m) => m.status == MasteryStatus.mastered),
            isTrue);

        // Wreck the caches, then rebuild from the log.
        for (final id in srs.keys) {
          await store.putSrs(id, scheduler.first(SrsRating.again, 0));
        }
        for (final id in mastery.keys) {
          await store.putMastery(MasteryState.initial(id));
        }
        final result = await store.rebuild(catalog.byId, scheduler);
        expect(result.srs, srs);
        expect(await store.allSrs(), srs);
        expect(await store.allMastery(), mastery);
        expect(await store.loadByDay(), load);
        expect((await store.item('crowd.1'))!.seedDueDay, 31);
      });

      test('a rebuild restores seeded due days (D26)', () async {
        final w = firstOf(ItemKind.word);
        await store.appendSeeds([
          SeedEvent(itemId: w.id, dueDay: 3, atUtc: at(0)),
          SeedEvent(itemId: 'other', dueDay: 6, atUtc: at(0)),
        ]);
        await store.replaceDerived(
            const ReplayResult(srs: {}, mastery: {}, seedDue: {}));
        expect(await store.dueOnOrBefore(10), isEmpty);
        await store.rebuild(catalog.byId, scheduler);
        expect(await store.dueOnOrBefore(10), [
          DueItem(itemId: w.id, dueDay: 3, seeded: true),
          const DueItem(itemId: 'other', dueDay: 6, seeded: true),
        ]);
        expect(await store.attempts(), isEmpty);
      });

      test(
          'export writes JSON Lines with a header and reads back through the replay',
          () async {
        final g = firstOf(ItemKind.grammar), p = firstOf(ItemKind.particle);
        await store.appendSeed(p.id, 2, atUtc: at(0));
        await store.setNote(g.id, kNoteCanUseIt);
        for (final (day, grade) in [
          (1, Grade.clear),
          (4, Grade.hinted),
          (9, Grade.clear)
        ]) {
          await store.recordAnswer(answer(g, day, grade),
              item: g, scheduler: scheduler);
        }
        await store.recordAnswer(answer(p, 2, Grade.wrong),
            item: p, scheduler: scheduler);
        final text = await exportStudy(store, exportedAt: at(10));
        final lines = const LineSplitter().convert(text);
        final header = jsonDecode(lines.first) as Map<String, dynamic>;
        expect(header['format'], kStudyExportFormat);
        expect(header['version'], kStudyExportVersion);
        expect(
            [header['attempts'], header['seeds'], header['notes']], [4, 1, 1]);
        expect(lines.length, 7);
        for (final l in lines.skip(1)) {
          expect(jsonDecode(l), isA<Map<String, dynamic>>());
        }

        // Into a fresh store of each kind: the same states and the same export.
        for (final open in implementations.values) {
          final other = await open();
          try {
            await other.putDay(const DayRecord(day: 1, plan: '{}'));
            await other.appendSeed('stale', 1, atUtc: at(0));
            await importStudy(other, text,
                lookup: catalog.byId, scheduler: scheduler);
            expect(await other.allSrs(), await store.allSrs());
            expect(await other.allMastery(), await store.allMastery());
            expect(await other.notes(), {g.id: kNoteCanUseIt});
            expect(await other.dueOnOrBefore(1000),
                await store.dueOnOrBefore(1000));
            expect(await other.day(1), isNotNull, reason: 'days stay');
            expect(await exportStudy(other, exportedAt: at(10)), text);
          } finally {
            await other.close();
          }
        }
      });

      test('a bad export is refused and changes nothing', () async {
        await store.appendSeed('keep', 1, atUtc: at(0));
        final good = encodeStudyExport(const StudyLog(), exportedAt: at(0));
        final bad = <String>[
          '',
          '{"format":"other","version":1}',
          good.replaceFirst('"version":1', '"version":2'),
          '$good{"type":"mystery"}\n',
          '$good{"type":"seed","itemId":"x","dueDay":1,"atUtc":"2026-01-01T00:00:00.000Z"}\n',
          '${good}not json\n',
        ];
        for (final text in bad) {
          await expectLater(
              importStudy(store, text,
                  lookup: catalog.byId, scheduler: scheduler),
              throwsFormatException,
              reason: text);
        }
        expect((await store.seeds()).single.itemId, 'keep');
      });

      group('the v2 migration', () {
        final point = catalog.ofKind(ItemKind.grammar).first;
        final other = catalog.ofKind(ItemKind.grammar)[1];
        final third = catalog.ofKind(ItemKind.grammar)[2];
        final today = localDay(DateTime(2026, 11, 3, 9));
        final sentence = sayItSentences(grammarDoc)
            .entries
            .firstWhere((e) => e.value.itemId == point.id);

        setUp(() async {
          SharedPreferences.setMockInitialValues({});
          // Written the way the v2 screens write them.
          await SelfCheck.set(point.id, 'review_needed');
          await SelfCheck.set(other.id, 'can_use_it');
          await SelfCheck.set('mari.L99.9', 'review_needed');
          await SelfCheck.set(third.id, 'something_else');
          await SpeakScoreLog.add(SpeakAttempt(
              sentence: sentence.key,
              verdict: Judgement.correct,
              at: DateTime(2026, 10, 20, 19)));
          await SpeakScoreLog.add(SpeakAttempt(
              sentence: sentence.key,
              verdict: Judgement.unverified,
              at: DateTime(2026, 10, 21, 19),
              selfMark: false));
          await SpeakScoreLog.add(SpeakAttempt(
              sentence: 'どこにもないぶん',
              verdict: Judgement.correct,
              at: DateTime(2026, 10, 22, 19)));
        });

        Future<V2MigrationReport> migrate() async => migrateV2Keys(
              store,
              await SharedPreferences.getInstance(),
              grammar: grammarDoc,
              known: (id) => catalog.byId(id) != null,
              today: today,
              nowUtc: DateTime.utc(2026, 11, 3, 9),
            );

        test('imports self-checks and Say-it history once and leaves the keys',
            () async {
          final report = await migrate();
          expect(report.dueToday, 1);
          expect(report.notes, 1);
          expect(report.sayIt, 2);
          expect(report.skipped, 3);

          // review_needed: due today, by a seed event, with no attempt on the self-check.
          expect(await store.dueOnOrBefore(today),
              [DueItem(itemId: point.id, dueDay: today, seeded: true)]);
          expect(await store.notes(), {other.id: kNoteCanUseIt});
          expect(await store.srs(other.id), isNull);

          // Say-it history: on the point, never credit, never a schedule.
          final log = await store.attempts();
          expect(log.map((a) => a.itemId).toSet(), {point.id});
          expect(
              log.every((a) => a.source == Source.sayIt && !a.wasDue), isTrue);
          expect(log.map((a) => a.probeId).toSet(), {sentence.value.probeId});
          expect(log.map((a) => a.grade), [Grade.clear, Grade.unscored],
              reason: 'an unverified check is never wrong');
          expect(await store.srs(point.id), isNull);
          await store.rebuild(catalog.byId, scheduler);
          expect((await store.mastery(point.id))!.status, MasteryStatus.neu);
          expect(await store.srs(point.id), isNull);

          // The keys stay for one release.
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('jp.selfcheck.${point.id}'), 'review_needed');
          expect(prefs.getString(SpeakScoreLog.prefsKey), isNotNull);

          // Once only.
          final again = await migrate();
          expect(again.alreadyRan, isTrue);
          expect((await store.attempts()).length, 2);
          expect((await store.seeds()).length, 1);
        });
      });
    });
  }

  group('JpStoreSqlite', () {
    test('the file survives a reopen, and the schema is the planned one',
        () async {
      final dir = await Directory.systemTemp.createTemp('jp_store_test');
      final path = '${dir.path}/jp_study.db';
      try {
        final g = firstOf(ItemKind.grammar);
        var store =
            await JpStoreSqlite.open(factory: databaseFactoryFfi, path: path);
        final out = await store.recordAnswer(answer(g, 3, Grade.clear),
            item: g, scheduler: scheduler);
        await store.appendSeed('seeded', 5, atUtc: at(0));
        await store
            .putDay(const DayRecord(day: 3, plan: '{"x":1}', position: 1));
        await store.close();

        store =
            await JpStoreSqlite.open(factory: databaseFactoryFfi, path: path);
        expect(await store.schemaVersion(), 1);
        expect(await store.attempts(), [out.attempt]);
        expect(await store.srs(g.id), out.srs);
        expect(await store.mastery(g.id), out.mastery);
        expect((await store.item('seeded'))!.seedDueDay, 5);
        expect(await store.lastDay(), 3);
        await store.close();

        final db = await databaseFactoryFfi.openDatabase(path);
        final tables = (await db.rawQuery(
                "SELECT name FROM sqlite_master WHERE type = 'table'"))
            .map((r) => r['name'])
            .toSet();
        expect(tables,
            containsAll(['items', 'srs', 'mastery', 'attempts', 'days']));
        final indexes = await db.rawQuery(
            "SELECT tbl_name, sql FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL");
        expect(
            indexes.map((r) => r['sql'] as String),
            containsAll([
              contains('ON srs (dueDay)'),
              contains('ON attempts (itemId)'),
            ]));
        await db.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  test('the web store is the memory store (A4)', () async {
    final store = await openJpStore(isWeb: true);
    expect(store, isA<JpStoreMemory>());
    await store.close();
  });
}
