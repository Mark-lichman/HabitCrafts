// The study store (Task 8, D14, D26, A4, A5). One suite runs against both implementations:
// `JpStoreMemory` (the web store) and `JpStoreSqlite` through the ffi factory. The SQLite-only
// group covers the schema version, the indexes, a reopen of the file, the upgrade steps and
// the rollback of an answer that fails inside its transaction. The gated memory store holds a
// rebuild or an import open so an answer can try to land inside it.

import 'dart:async';
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

/// [attempt] with a rating no [SrsRating] has: the replay throws on it.
Attempt withBadRating(Attempt attempt) =>
    Attempt.fromJson({...attempt.toJson(), 'rating': 9});

/// The error [withBadRating] trips in the replay (`SrsRating.fromValue`), pinned by message.
final Matcher throwsBadRating = throwsA(isA<ArgumentError>()
    .having((e) => e.message, 'message', 'Invalid rating value: 9'));

/// The scheduler without its load term: the nominal due day, whatever the load. The replay
/// through it must differ from the live states, or load spreading moved no due day and the
/// rebuild test proves nothing about the load term.
class _NoSpread extends FsrsScheduler {
  const _NoSpread();

  @override
  int nextDue(SrsState state, Map<int, int> loadByDay) =>
      state.lastReviewDay + state.interval;
}

/// A mastery state that cannot be serialised: the SQLite write throws inside its transaction.
class _Unwritable extends MasteryState {
  const _Unwritable(String id)
      : super(itemId: id, status: MasteryStatus.learning);

  @override
  Map<String, dynamic> toJson() => throw StateError('unwritable');
}

/// A memory store whose log read (in a rebuild) and whole-record write (in an import) wait on
/// [gate], so a test can start an answer while either is open.
class _Gated extends JpStoreMemory {
  Completer<void>? gate;

  Future<void> _wait() => gate?.future ?? Future.value();

  @override
  Future<List<SeedEvent>> seeds() async {
    await _wait();
    return super.seeds();
  }

  @override
  Future<void> replaceAll(StudyLog log, ReplayResult result) async {
    await _wait();
    return super.replaceAll(log, result);
  }
}

/// The grammar point [id] as the asset defines it.
Map<String, dynamic> pointDef(String id) {
  for (final lesson in (grammarDoc['grammar'] as List)) {
    for (final p in ((lesson as Map)['points'] as List)) {
      if ((p as Map)['id'] == id) return Map<String, dynamic>.from(p);
    }
  }
  throw StateError('no grammar point $id');
}

/// The first example in the asset that joins forms with ／: its point id, its index among the
/// point's examples and its second form. Read from the asset, not from `sayItSentences`.
({String itemId, int index, String form}) firstSlashExample() {
  for (final lesson in (grammarDoc['grammar'] as List)) {
    for (final p in ((lesson as Map)['points'] as List)) {
      final examples = ((p as Map)['examples'] as List? ?? const []);
      for (var i = 0; i < examples.length; i++) {
        final jp = (examples[i] as Map)['jp'] as String;
        if (jp.contains('／')) {
          return (itemId: p['id'] as String, index: i, form: jp.split('／')[1]);
        }
      }
    }
  }
  throw StateError('the asset has no ／ example');
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

      test('overlapping answers on one item run in order and match a rebuild',
          () async {
        final g = firstOf(ItemKind.grammar);
        // Neither call is awaited before the next starts.
        final first = store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        final second = store.recordAnswer(answer(g, 2, Grade.clear),
            item: g, scheduler: scheduler);
        final outs = await Future.wait([first, second]);
        expect(outs[1].srs!.reps, 2,
            reason: 'the second answer reviews the first one\'s schedule');
        expect(outs[1].mastery!.clearCount, 2);
        final srs = await store.allSrs();
        final mastery = await store.allMastery();
        final result = await store.rebuild(catalog.byId, scheduler);
        expect(srs, result.srs);
        expect(mastery, result.mastery);
        // A failed answer does not break the chain for the next one.
        final bad = store.recordAnswer(withBadRating(answer(g, 3, Grade.clear)),
            item: g, scheduler: scheduler);
        final third = store.recordAnswer(answer(g, 3, Grade.clear, minute: 1),
            item: g, scheduler: scheduler);
        await expectLater(bad, throwsBadRating);
        expect((await third).srs!.reps, 3);
        expect((await store.attempts()).length, 3);
      });

      test('a mastery state for another item writes nothing', () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        await expectLater(
            store.appendAttempt(answer(g, 1, Grade.clear),
                srs: scheduler.first(SrsRating.good, 1),
                mastery: MasteryState.initial(w.id)),
            throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
                contains('written with an attempt on'))));
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
          'early practice: a clear, a hinted or a self answer leaves the schedule alone, a wrong counts and is due tomorrow (PIN-14)',
          () async {
        final g = firstOf(ItemKind.grammar), w = firstOf(ItemKind.word);
        final first = await store.recordAnswer(answer(g, 10, Grade.clear),
            item: g, scheduler: scheduler);
        final early = await store.recordAnswer(
            answer(g, 11, Grade.clear, source: Source.early, wasDue: false),
            item: g,
            scheduler: scheduler);
        expect(early.srs, first.srs);
        expect(early.mastery, first.mastery);
        expect(await store.srs(g.id), first.srs);
        // A hinted and a self answer leave the schedule alone too. Their mastery is not
        // asserted: the intake owner may change that rule (the jp_store.dart hazard note).
        for (final (grade, minute) in [(Grade.hinted, 1), (Grade.self, 2)]) {
          final out = await store.recordAnswer(
              answer(g, 11, grade,
                  source: Source.early, wasDue: false, minute: minute),
              item: g,
              scheduler: scheduler);
          expect(out.srs, first.srs, reason: '$grade');
          expect(await store.srs(g.id), first.srs, reason: '$grade');
        }
        final wrong = await store.recordAnswer(
            answer(g, 11, Grade.wrong,
                source: Source.early, wasDue: false, minute: 5),
            item: g,
            scheduler: scheduler);
        expect(wrong.srs!.dueDay, 12);
        expect(wrong.srs!.lapses, 1);
        expect(wrong.mastery!.clearCount, 0);
        // An early wrong on an item with no schedule yet: due tomorrow all the same.
        expect(await store.srs(w.id), isNull);
        final fresh = await store.recordAnswer(
            answer(w, 11, Grade.wrong,
                source: Source.early, wasDue: false, minute: 6),
            item: w,
            scheduler: scheduler);
        expect(fresh.srs!.dueDay, 12);
        expect(fresh.srs,
            scheduler.first(SrsRating.again, 11).copyWith(dueDay: 12),
            reason: 'a first review rated Again, not a clear');
        expect(await store.srs(w.id), fresh.srs);
        expect((await store.attempts()).length, 6);
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
        // spreading over a crowded seed, early practice, Say-it and late seeds in the mix.
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
        // Late seeds, after every attempt is logged (more lessons ticked after the first
        // launch), all on a day an attempt's spread chose from a window wider than one day.
        // A replay that applied every seed first would show that attempt the late seeds on its
        // day, a load the live writer never saw, and spread it onto another day of its window.
        // The seeds follow the last attempt, so no later review (which reads `lastReviewDay`,
        // not the due day) hides the moved day from the equality below.
        final spread = (await store.allSrs()).values.firstWhere(
            (s) =>
                s.dueDay > 119 &&
                (s.interval * loadSpreadFraction).round() >= 1,
            orElse: () => throw StateError('no spread due day past day 119'));
        await store.appendSeeds([
          for (var i = 0; i < 10; i++)
            SeedEvent(itemId: 'late.$i', dueDay: spread.dueDay, atUtc: at(120)),
        ]);
        final srs = await store.allSrs();
        final mastery = await store.allMastery();
        final load = await store.loadByDay();
        // The load term moved at least one due day: without it the replay lands elsewhere.
        expect(
            replayLog(await store.exportLog(), catalog.byId, const _NoSpread())
                .srs,
            isNot(srs),
            reason:
                'the history reaches states where load spreading moves due days');
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
        // Two notes, written in the reverse of their id order: the export sorts them.
        final noted = {g.id: kNoteCanUseIt, p.id: 'other'};
        for (final id in noted.keys.toList()..sort((a, b) => b.compareTo(a))) {
          await store.setNote(id, noted[id]);
        }
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
            [header['attempts'], header['seeds'], header['notes']], [4, 1, 2]);
        expect(lines.length, 8);
        for (final l in lines.skip(1)) {
          expect(jsonDecode(l), isA<Map<String, dynamic>>());
        }
        final noteIds = [
          for (final l in lines.skip(1))
            if (l.contains('"type":"note"'))
              (jsonDecode(l) as Map<String, dynamic>)['itemId'] as String
        ];
        expect(noteIds, noted.keys.toList()..sort());

        // Into a fresh store of each kind: the same states and the same export.
        for (final open in implementations.values) {
          final other = await open();
          try {
            await other.putDay(const DayRecord(day: 1, plan: '{}'));
            await other.putMeta('k', 'v');
            await other.appendSeed('stale', 1, atUtc: at(0));
            // A logged attempt too: the import restarts both row id sequences, or the
            // re-export's ids drift from the file's.
            await other.recordAnswer(answer(g, 20, Grade.wrong),
                item: g, scheduler: scheduler);
            await importStudy(other, text,
                lookup: catalog.byId, scheduler: scheduler);
            expect(await other.allSrs(), await store.allSrs());
            expect(await other.allMastery(), await store.allMastery());
            expect(await other.notes(), noted);
            expect(await other.dueOnOrBefore(1000),
                await store.dueOnOrBefore(1000));
            expect(await other.day(1), isNotNull, reason: 'days stay');
            expect(await other.meta('k'), 'v', reason: 'flags stay');
            expect(await exportStudy(other, exportedAt: at(10)), text);
          } finally {
            await other.close();
          }
        }
      });

      test(
          'a bad export is refused, by the guard it trips, and changes nothing',
          () async {
        final g = firstOf(ItemKind.grammar);
        await store.appendSeed('keep', 1, atUtc: at(0));
        await store.setNote('keep', 'note');
        final kept = await store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        final good = encodeStudyExport(const StudyLog(), exportedAt: at(0));
        final oneAttempt = encodeStudyExport(
            StudyLog(attempts: [withBadRating(answer(g, 2, Grade.clear))]),
            exportedAt: at(0));
        final bad = <String, String>{
          '': 'empty',
          '{"format":"other","version":1}': 'line 1 is not the header',
          good.replaceFirst('"version":1', '"version":2'):
              'version 2 is not readable',
          '$good{"type":"mystery"}\n': 'unknown type',
          '$good{"type":"seed","itemId":"x","dueDay":1,"atUtc":"2026-01-01T00:00:00.000Z"}\n':
              'line counts disagree',
          '${good}not json\n': 'line 2 is not a JSON object',
          oneAttempt: 'line 2: FormatException: rating 9 is outside 1 to 4',
          // A blank line is skipped and still counted: the named line is the file's own.
          '$good\n{"type":"mystery"}\n':
              'line 3: FormatException: unknown type',
          '$good\n\nnot json\n': 'line 4 is not a JSON object',
          '\n{"format":"other","version":1}\n': 'line 2 is not the header',
        };
        for (final e in bad.entries) {
          await expectLater(
              importStudy(store, e.key,
                  lookup: catalog.byId, scheduler: scheduler),
              throwsA(isA<FormatException>()
                  .having((x) => x.message, 'message', contains(e.value))),
              reason: e.key);
        }
        expect((await store.seeds()).single.itemId, 'keep');
        expect(await store.attempts(), [kept.attempt]);
        expect(await store.notes(), {'keep': 'note'});
        expect(await store.srs(g.id), kept.srs);
        expect(await store.mastery(g.id), kept.mastery);
      });

      test('a log the replay rejects is not imported', () async {
        final g = firstOf(ItemKind.grammar);
        await store.appendSeed('keep', 1, atUtc: at(0));
        final kept = await store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        final log = StudyLog(
            attempts: [withBadRating(answer(g, 2, Grade.clear))],
            seeds: [SeedEvent(itemId: 'x', dueDay: 1, atUtc: at(0))]);
        await expectLater(
            store.importLog(log, catalog.byId, scheduler), throwsBadRating);
        expect((await store.seeds()).single.itemId, 'keep');
        expect(await store.attempts(), [kept.attempt]);
        expect(await store.srs(g.id), kept.srs);
        expect(await store.mastery(g.id), kept.mastery);
        expect((await store.item('keep'))!.seedDueDay, 1);
      });

      group('the v2 migration', () {
        final point = catalog.ofKind(ItemKind.grammar).first;
        final other = catalog.ofKind(ItemKind.grammar)[1];
        final third = catalog.ofKind(ItemKind.grammar)[2];
        final today = localDay(DateTime(2026, 11, 3, 9));
        final sentence = sayItSentences(grammarDoc)
            .entries
            .firstWhere((e) => e.value.itemId == point.id);
        // A practice sentence and a ／-split example form, read from the asset itself.
        final practice = (pointDef(point.id)['practice'] as List).first as Map;
        final practiceKana = (practice['prompt'] as String)
            .replaceAll('＿＿', practice['answer'] as String);
        final slash = firstSlashExample();
        final spokenAt = [
          DateTime(2026, 10, 20, 19),
          DateTime(2026, 10, 21, 19),
          DateTime(2026, 10, 23, 19),
          DateTime(2026, 10, 24, 19),
        ];

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
              at: spokenAt[0]));
          await SpeakScoreLog.add(SpeakAttempt(
              sentence: sentence.key,
              verdict: Judgement.unverified,
              at: spokenAt[1],
              selfMark: false));
          await SpeakScoreLog.add(SpeakAttempt(
              sentence: 'どこにもないぶん',
              verdict: Judgement.correct,
              at: DateTime(2026, 10, 22, 19)));
          await SpeakScoreLog.add(SpeakAttempt(
              sentence: practiceKana,
              verdict: Judgement.correct,
              at: spokenAt[2]));
          await SpeakScoreLog.add(SpeakAttempt(
              sentence: slash.form,
              verdict: Judgement.correct,
              at: spokenAt[3]));
        });

        /// The attempt the migration writes for the first spoken sentence.
        Attempt firstSayIt({String sessionId = kV2MigrationSession}) => Attempt(
              itemId: point.id,
              probeId: sentence.value.probeId,
              template: kSayItTemplate,
              production: true,
              selfGraded: false,
              atUtc: spokenAt[0].toUtc(),
              localDay: localDay(spokenAt[0]),
              grade: Grade.clear,
              rating: fsrsRatingFor(Grade.clear),
              wasDue: false,
              source: Source.sayIt,
              sessionId: sessionId,
            );

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
          expect(report.sayIt, 4);
          expect(report.alreadyLogged, 0);
          expect(report.skipped, 3);

          // review_needed: due today, by a seed event, with no attempt on the self-check.
          expect(await store.dueOnOrBefore(today),
              [DueItem(itemId: point.id, dueDay: today, seeded: true)]);
          expect(await store.notes(), {other.id: kNoteCanUseIt});
          expect(await store.srs(other.id), isNull);

          // Say-it history: on the point, never credit, never a schedule.
          final log = await store.attempts();
          expect(log.map((a) => a.itemId).toSet(), {point.id, slash.itemId});
          expect(
              log.every((a) => a.source == Source.sayIt && !a.wasDue), isTrue);
          // The example, the practice item (answer in the blank) and the ／-split form each
          // name the probe they came from.
          expect(log.map((a) => a.probeId), [
            sentence.value.probeId,
            sentence.value.probeId,
            'p0',
            'ex${slash.index}'
          ]);
          expect(log.map((a) => a.grade),
              [Grade.clear, Grade.unscored, Grade.clear, Grade.clear],
              reason: 'an unverified check is never wrong');
          // Each attempt keeps its own instant and local day, not the migration's.
          expect(log.map((a) => a.localDay), spokenAt.map(localDay).toList());
          expect(
              log.map((a) => a.atUtc), spokenAt.map((d) => d.toUtc()).toList());
          expect(await store.srs(point.id), isNull);
          await store.rebuild(catalog.byId, scheduler);
          expect((await store.mastery(point.id))!.status, MasteryStatus.neu);
          expect(await store.srs(point.id), isNull);
          expect(await store.srs(slash.itemId), isNull);

          // The keys stay for one release.
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('jp.selfcheck.${point.id}'), 'review_needed');
          expect(prefs.getString(SpeakScoreLog.prefsKey), isNotNull);

          // Once only.
          final again = await migrate();
          expect(again.alreadyRan, isTrue);
          expect((await store.attempts()).length, 4);
          expect((await store.seeds()).length, 1);
        });

        test('a run cut short before the flag logs no Say-it attempt twice',
            () async {
          // The first run died after the seed and one Say-it attempt, before the flag.
          await store.appendSeed(point.id, today,
              atUtc: DateTime.utc(2026, 11, 3, 9));
          await store.appendAttempt(firstSayIt(sessionId: 'first-run'));
          final report = await migrate();
          expect(report.sayIt, 3);
          expect(report.alreadyLogged, 1);
          expect(report.dueToday, 1);
          final log = await store.attempts();
          expect(log.length, 4);
          expect(
              log.where((a) =>
                  a.itemId == point.id &&
                  a.probeId == sentence.value.probeId &&
                  a.atUtc == spokenAt[0].toUtc()),
              hasLength(1));
          expect(log.first.sessionId, 'first-run',
              reason: 'the logged one stays');
          // The seed repeats in the log and the item is still due once, today.
          expect((await store.seeds()).length, 2);
          expect(await store.dueOnOrBefore(today),
              [DueItem(itemId: point.id, dueDay: today, seeded: true)]);
          expect((await migrate()).alreadyRan, isTrue);
        });

        test(
            'an unreadable score log is counted as skipped, never read as empty',
            () async {
          for (final (raw, name) in [
            ('not json', 'not JSON'),
            ('{"a":1}', 'not a list'),
            (1, 'not a string'),
          ]) {
            await store.close();
            store = await entry.value();
            final prefs = await SharedPreferences.getInstance();
            if (raw is String) {
              await prefs.setString(SpeakScoreLog.prefsKey, raw);
            } else {
              await prefs.setInt(SpeakScoreLog.prefsKey, raw as int);
            }
            final report = await migrate();
            expect(report.sayIt, 0, reason: name);
            expect(report.skipped, 3, reason: '$name: two keys and the blob');
            expect(await store.attempts(), isEmpty, reason: name);
            expect(await store.meta(kV2MigrationFlag), isNotNull, reason: name);
          }
        });
      });
    });
  }

  test('every drill sentence of every lesson maps to a point of that lesson',
      () {
    // The oracle is the drill's own `lessonSentences` over each whole lesson, not the map
    // under test. A sentence it would show must land on a point of its lesson.
    final map = sayItSentences(grammarDoc);
    var sentences = 0, practice = 0, forms = 0;
    for (final lesson in (grammarDoc['grammar'] as List)) {
      final l = Map<String, dynamic>.from(lesson as Map);
      final ids = {for (final p in l['points'] as List) (p as Map)['id']};
      for (final s in lessonSentences(l)) {
        sentences++;
        final hit = map[s.kana];
        expect(hit, isNotNull, reason: 'lesson ${l['lesson']}: ${s.kana}');
        expect(ids, contains(hit!.itemId), reason: s.kana);
        if (hit.probeId.startsWith('p')) practice++;
        if (RegExp(r'^ex\d+$').hasMatch(hit.probeId)) forms++;
      }
    }
    expect(sentences, greaterThan(0));
    expect(practice, greaterThan(0), reason: 'the practice branch is mapped');
    expect(forms, greaterThan(0), reason: 'the examples branch is mapped');
    // A ／-joined example maps each form, by the asset's own split.
    final slash = firstSlashExample();
    expect(
        map[slash.form], (itemId: slash.itemId, probeId: 'ex${slash.index}'));
  });

  group('the write chain', () {
    final g = firstOf(ItemKind.grammar);

    test('an answer never lands between a rebuild\'s read and its write',
        () async {
      final store = _Gated();
      final first = await store.recordAnswer(answer(g, 1, Grade.clear),
          item: g, scheduler: scheduler);
      store.gate = Completer<void>();
      final rebuilding = store.rebuild(catalog.byId, scheduler);
      final answering = store.recordAnswer(answer(g, 2, Grade.clear),
          item: g, scheduler: scheduler);
      // Everything that can run before the gate opens has run.
      await Future<void>.delayed(Duration.zero);
      expect(await store.attempts(), [first.attempt],
          reason: 'the answer waits for the rebuild');
      store.gate!.complete();
      final result = await rebuilding;
      final second = await answering;
      expect(result.srs[g.id], first.srs);
      expect(second.srs!.reps, 2);
      expect(await store.srs(g.id), second.srs,
          reason: 'the answer\'s write stands, not the stale replay');
      expect(await store.mastery(g.id), second.mastery);
      expect((await store.attempts()).length, 2);
      await store.close();
    });

    test('an answer never lands during an import\'s write', () async {
      final store = _Gated();
      store.gate = Completer<void>();
      final log =
          StudyLog(seeds: [SeedEvent(itemId: 'x', dueDay: 1, atUtc: at(0))]);
      final importing = store.importLog(log, catalog.byId, scheduler);
      final answering = store.recordAnswer(answer(g, 1, Grade.clear),
          item: g, scheduler: scheduler);
      await Future<void>.delayed(Duration.zero);
      expect(await store.attempts(), isEmpty,
          reason: 'the answer waits for the import');
      store.gate!.complete();
      await importing;
      final out = await answering;
      expect(await store.attempts(), [out.attempt]);
      expect(await store.srs(g.id), out.srs);
      expect((await store.seeds()).single.itemId, 'x');
      await store.close();
    });

    test('a failed rebuild does not break the chain for the next answer',
        () async {
      final store = JpStoreMemory();
      await store.appendAttempt(withBadRating(answer(g, 1, Grade.clear)));
      final rebuilding = store.rebuild(catalog.byId, scheduler);
      final answering = store.recordAnswer(answer(g, 2, Grade.clear),
          item: g, scheduler: scheduler);
      await expectLater(rebuilding, throwsBadRating);
      expect((await answering).srs, isNotNull);
      await store.close();
    });
  });

  test(
      'sayItGrade: a speech close is hinted, unverified is never wrong (PIN-3)',
      () {
    SpeakAttempt spoke(Judgement verdict, {bool? selfMark}) => SpeakAttempt(
        sentence: 'x', verdict: verdict, at: at(0), selfMark: selfMark);
    expect(sayItGrade(spoke(Judgement.correct)), Grade.clear);
    expect(sayItGrade(spoke(Judgement.close)), Grade.hinted);
    expect(sayItGrade(spoke(Judgement.wrong)), Grade.wrong);
    expect(sayItGrade(spoke(Judgement.unverified, selfMark: true)), Grade.self);
    expect(sayItGrade(spoke(Judgement.unverified, selfMark: false)),
        Grade.unscored);
    expect(sayItGrade(spoke(Judgement.unverified)), Grade.unscored);
  });

  group('JpStoreSqlite', () {
    test('an answer that fails inside its transaction writes nothing',
        () async {
      final store = await JpStoreSqlite.open(
          factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      try {
        final g = firstOf(ItemKind.grammar);
        // The throw lands in the mastery write, after the attempt and schedule rows went
        // in: only a rollback leaves all three empty.
        await expectLater(
            store.appendAttempt(answer(g, 1, Grade.clear),
                srs: scheduler.first(SrsRating.good, 1),
                mastery: _Unwritable(g.id)),
            throwsStateError);
        expect(await store.attempts(), isEmpty);
        expect(await store.srs(g.id), isNull);
        expect(await store.mastery(g.id), isNull);
      } finally {
        await store.close();
      }
    });

    test('an import whose derived write fails keeps the old record', () async {
      final store = await JpStoreSqlite.open(
          factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      try {
        final g = firstOf(ItemKind.grammar);
        await store.appendSeed('keep', 1, atUtc: at(0));
        await store.setNote('keep', 'note');
        await store.putMeta('k', 'v');
        final kept = await store.recordAnswer(answer(g, 1, Grade.clear),
            item: g, scheduler: scheduler);
        // The throw lands in the mastery write, after the new log and the new schedule rows
        // went in: only one transaction over both leaves the old record whole.
        final log = StudyLog(
            attempts: [answer(g, 2, Grade.clear)],
            seeds: [SeedEvent(itemId: 'x', dueDay: 2, atUtc: at(0))],
            notes: const {'x': 'new'});
        final result = ReplayResult(
            srs: {g.id: scheduler.first(SrsRating.good, 2)},
            mastery: {g.id: _Unwritable(g.id)},
            seedDue: const {'x': 2});
        await expectLater(store.replaceAll(log, result), throwsStateError);
        expect((await store.seeds()).single.itemId, 'keep');
        expect(await store.attempts(), [kept.attempt]);
        expect(await store.notes(), {'keep': 'note'});
        expect(await store.srs(g.id), kept.srs);
        expect(await store.mastery(g.id), kept.mastery);
        expect((await store.item('keep'))!.seedDueDay, 1);
        expect(await store.item('x'), isNull);
        expect(await store.meta('k'), 'v');
      } finally {
        await store.close();
      }
    });

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

    test('onUpgrade runs the step to each later version and keeps the rows',
        () async {
      final dir = await Directory.systemTemp.createTemp('jp_store_test');
      final path = '${dir.path}/jp_study.db';
      try {
        final g = firstOf(ItemKind.grammar);
        var store =
            await JpStoreSqlite.open(factory: databaseFactoryFfi, path: path);
        final out = await store.recordAnswer(answer(g, 3, Grade.clear),
            item: g, scheduler: scheduler);
        await store.close();

        final ran = <int>[];
        final toV2 = {
          2: (Database db) async {
            ran.add(2);
            await db.execute('CREATE TABLE v2 (x INTEGER)');
          },
        };
        store = await JpStoreSqlite.open(
            factory: databaseFactoryFfi,
            path: path,
            version: 2,
            upgrades: toV2);
        expect(ran, [2]);
        expect(await store.schemaVersion(), 2);
        expect(await store.attempts(), [out.attempt]);
        expect(await store.srs(g.id), out.srs);
        await store.close();

        // No step to version 3: the open throws, and the file stays at 2 with its rows.
        await expectLater(
            JpStoreSqlite.open(
                factory: databaseFactoryFfi,
                path: path,
                version: 3,
                upgrades: toV2),
            throwsA(isA<StateError>().having((e) => e.message, 'message',
                contains('no upgrade step to version 3'))));
        store = await JpStoreSqlite.open(
            factory: databaseFactoryFfi,
            path: path,
            version: 2,
            upgrades: toV2);
        expect(ran, [2], reason: 'a step runs once per file');
        expect(await store.schemaVersion(), 2);
        expect(await store.attempts(), [out.attempt]);
        await store.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('onCreate at a later version runs the steps after version 1',
        () async {
      final ran = <int>[];
      final store = await JpStoreSqlite.open(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
          version: 3,
          upgrades: {
            2: (db) async => ran.add(2),
            3: (db) async => ran.add(3),
          });
      try {
        expect(ran, [2, 3]);
        expect(await store.schemaVersion(), 3);
        expect(await store.attempts(), isEmpty);
      } finally {
        await store.close();
      }
      await expectLater(
          JpStoreSqlite.open(
              factory: databaseFactoryFfi,
              path: inMemoryDatabasePath,
              version: 2,
              upgrades: {}),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              contains('no upgrade step to version 2'))));
    });
  });

  test('the web store is the memory store (A4)', () async {
    final store = await openJpStore(isWeb: true);
    expect(store, isA<JpStoreMemory>());
    await store.close();
  });
}
