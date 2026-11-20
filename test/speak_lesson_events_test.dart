// Tests for the say-it scores and the last lesson in the study store (plan 2026-11-19, Task 13,
// D16, PIN-16, End state 16).
//
// Each runs on both stores (memory, as on the web, and SQLite through ffi, as on the phone):
//   * a say-it score is a `speak_score` event and the score log reads back from the store; a
//     self-mark is a later event that replaces the entry it marks;
//   * the last lesson is a `last_lesson` event, and two devices that swap events agree on it:
//     the later event time wins;
//   * the one-time import moves `jp.speak.scores` and `jp.grammar.lastLesson` into the store,
//     once, and an old last lesson with no time never beats one opened since.

import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterErrorDetails;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_speak_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_event.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed_confirm_widget.dart'
    show kLastGrammarLessonKey;
import 'package:habit_craft/components/pages/quiet_room_mastery/speak_lesson_events.dart';
import 'package:habit_craft/components/pages/quiet_room_practice/speech_service.dart'
    show Judgement;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'jp_screen_harness.dart' show ReportCapture;

DateTime at(int minute) => DateTime.utc(2026, 11, 19, 9, minute);

/// The clock every store under test reads. Tests move it.
DateTime now = at(0);
DateTime clock() => now;

final Map<String, Future<JpStore> Function()> implementations = {
  'memory': () async => JpStoreMemory(clock: clock),
  'sqlite': () => JpStoreSqlite.open(
      factory: databaseFactoryFfi, path: inMemoryDatabasePath, clock: clock),
};

SpeakAttempt attempt(String sentence, DateTime at,
        {Judgement verdict = Judgement.close, double? overall = 72.4}) =>
    SpeakAttempt(
        sentence: sentence, verdict: verdict, at: at, overall: overall);

/// Sends every event [from] has not pushed to [to], as a sync would, and marks them pushed.
Future<void> sync(JpStore from, JpStore to) async {
  final sent = await from.unpushedEvents();
  await to.appendRemoteEvents(sent);
  await from.markPushed(sent.map((e) => e.eventId));
}

Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  sqfliteFfiInit();
  setUp(() {
    now = at(0);
    SharedPreferences.setMockInitialValues({});
  });

  for (final entry in implementations.entries) {
    group('${entry.key} store', () {
      late JpStore a;
      late JpStore b;
      setUp(() async {
        a = await entry.value();
        b = await entry.value();
      });
      tearDown(() async {
        await a.close();
        await b.close();
      });

      group('the say-it score log', () {
        test('a score is a speak_score event and reads back from the store',
            () async {
          final log = await SpeakScoreLog.add(a, attempt('あたま', at(1)));
          expect(log.map((x) => x.sentence), ['あたま']);
          final events = await a.speakScores();
          expect(events, hasLength(1));
          expect(events.single.kind, JpEventKind.speakScore);
          expect(events.single.atUtc, at(1));
          expect(events.single.body['sentence'], 'あたま');
          expect(events.single.body['overall'], 72.4);
          expect(idsOf(await a.unpushedEvents()), {events.single.eventId},
              reason: 'the score waits for the next sync');
          expect(
              (await SharedPreferences.getInstance())
                  .get(SpeakScoreLog.prefsKey),
              isNull,
              reason: 'nothing writes the old key any more');
        });

        test('a self-mark is a later event that replaces the entry it marks',
            () async {
          final x = attempt('あたま', at(5));
          await SpeakScoreLog.add(a, x);
          // The clock sits behind the attempt: the mark still lands after it.
          now = at(1);
          final log = await SpeakScoreLog.mark(a, x, true);
          expect(log, hasLength(1));
          expect(log.single.selfMark, isTrue);
          final events = await a.speakScores();
          expect(events, hasLength(2), reason: 'the log is append-only');
          expect(events.last.atUtc.isAfter(events.first.atUtc), isTrue);
        });

        // The mark's event must land in a later whole millisecond than the attempt's, because
        // the merge order compares whole milliseconds. Each row is one arm of that test in
        // SpeakScoreLog.mark. The oracle reads millisecondsSinceEpoch itself, not eventMs.
        const us = Duration(microseconds: 1);
        final markTimeRows = <(String, DateTime, DateTime, DateTime)>[
          // (name, the attempt's time, the clock at the mark, the mark event's time)
          (
            'the clock in the same millisecond, later in microseconds',
            at(5),
            at(5).add(us * 500),
            at(5).add(kLocalTieBump),
          ),
          (
            'the clock at the attempt\'s own time',
            at(5),
            at(5),
            at(5).add(kLocalTieBump),
          ),
          (
            'the clock in the same millisecond, earlier in microseconds',
            at(5).add(us * 700),
            at(5).add(us * 200),
            at(5).add(us * 700).add(kLocalTieBump),
          ),
          (
            'an attempt with microseconds and the clock later in its millisecond',
            at(5).add(us * 700),
            at(5).add(us * 900),
            at(5).add(us * 700).add(kLocalTieBump),
          ),
          (
            'the clock behind the attempt',
            at(5),
            at(1),
            at(5).add(kLocalTieBump),
          ),
          (
            'the clock in a later millisecond keeps its own time',
            at(5),
            at(5).add(kLocalTieBump * 5),
            at(5).add(kLocalTieBump * 5),
          ),
          (
            'the clock in the next millisecond keeps its own time',
            at(5).add(us * 700),
            at(5).add(kLocalTieBump).add(us * 100),
            at(5).add(kLocalTieBump).add(us * 100),
          ),
        ];
        for (final (name, attemptAt, markClock, wantMarkAt) in markTimeRows) {
          test('a self-mark lands in a later millisecond: $name', () async {
            final x = attempt('あたま', attemptAt);
            await SpeakScoreLog.add(a, x);
            now = markClock;
            await SpeakScoreLog.mark(a, x, true);

            final events = await a.speakScores();
            expect(events, hasLength(2));
            final marks = [
              for (final e in events)
                if (e.body['selfMark'] != null) e
            ];
            final plain = [
              for (final e in events)
                if (e.body['selfMark'] == null) e
            ];
            expect(marks, hasLength(1));
            expect(plain, hasLength(1));
            expect(
                marks.single.atUtc.millisecondsSinceEpoch,
                greaterThan(plain.single.atUtc.millisecondsSinceEpoch),
                reason: 'a tie on the millisecond lets the event id pick');
            expect(marks.single.atUtc.microsecondsSinceEpoch,
                wantMarkAt.microsecondsSinceEpoch);
            expect((await SpeakScoreLog.load(a)).single.selfMark, isTrue);
          });
        }

        test('a mark whose attempt never saved still keeps its entry',
            () async {
          final log = await SpeakScoreLog.mark(a, attempt('ねこ', at(2)), false);
          expect(log.single.sentence, 'ねこ');
          expect(log.single.selfMark, isFalse);
        });

        test('a score and its mark made on one device show on the other',
            () async {
          final x = attempt('あたま', at(1));
          await SpeakScoreLog.add(a, x);
          await sync(a, b);
          expect((await SpeakScoreLog.load(b)).single.sentence, 'あたま');

          now = at(3);
          await SpeakScoreLog.mark(b, x, true);
          await sync(b, a);
          expect((await SpeakScoreLog.load(a)).single.selfMark, isTrue);
          expect((await SpeakScoreLog.load(b)).single.selfMark, isTrue);
        });
      });

      group('the last lesson', () {
        test('reads back as the latest event', () async {
          expect(await readLastGrammarLesson(a), isNull);
          now = at(1);
          await rememberLastGrammarLesson(a, 33);
          now = at(2);
          await rememberLastGrammarLesson(a, 41);
          expect(await readLastGrammarLesson(a), 41);
          final events = [
            for (final e in await a.sideEvents())
              if (e.kind == JpEventKind.lastLesson) e
          ];
          expect(events.map((e) => e.body['lessonId']), ['33', '41']);
        });

        test('two devices agree: the later event time wins', () async {
          now = at(5);
          await rememberLastGrammarLesson(b, 44);
          now = at(1);
          await rememberLastGrammarLesson(a, 30);
          await sync(a, b);
          await sync(b, a);
          expect(await readLastGrammarLesson(a), 44);
          expect(await readLastGrammarLesson(b), 44);

          // A later change on the device that lost shows on both after the next sync.
          now = at(9);
          await rememberLastGrammarLesson(a, 31);
          await sync(a, b);
          expect(await readLastGrammarLesson(a), 31);
          expect(await readLastGrammarLesson(b), 31);
        });
      });

      group('the one-time import', () {
        Map<String, Object> oldPrefs() => {
              SpeakScoreLog.prefsKey: jsonEncode([
                'not an attempt',
                {'verdict': 'close', 'overall': 50, 'words': []},
                {
                  'sentence': 'あたまが いたいんです。',
                  'verdict': 'close',
                  'overall': 72.4,
                  'at': '2026-10-27T09:00:00.000Z',
                  'words': [],
                  'selfMark': 'got_it',
                },
                {
                  'sentence': 'no time',
                  'verdict': 'wrong',
                  'at': 'never',
                  'words': [],
                },
                {
                  'sentence': 'ねこが います。',
                  'verdict': 'correct',
                  'overall': 95,
                  'at': '2026-10-28T09:00:00.000Z',
                  'words': [],
                },
              ]),
              kLastGrammarLessonKey: 33,
            };

        test('moves both old values into the store once', () async {
          final prefs = await prefsWith(oldPrefs());
          expect(await importSpeakAndLessonPrefs(a, prefs: prefs), 3);
          final log = await SpeakScoreLog.load(a);
          expect(log.map((x) => x.sentence), ['あたまが いたいんです。', 'ねこが います。'],
              reason: 'the unreadable entries are skipped');
          expect(log.first.selfMark, isTrue);
          expect((await a.speakScores()).first.atUtc,
              DateTime.utc(2026, 10, 27, 9));
          expect(await readLastGrammarLesson(a), 33);
          expect(await a.meta(kSpeakLessonImportFlag), isNotNull);

          // Every later open finds the flag and writes nothing.
          expect(await importSpeakAndLessonPrefs(a, prefs: prefs), 0);
          expect(await a.speakScores(), hasLength(2));
          expect(prefs.getInt(kLastGrammarLessonKey), 33,
              reason: 'the old keys stay in place');
        });

        test('the reads run it before they read', () async {
          await prefsWith(oldPrefs());
          expect(await readLastGrammarLesson(a), 33);
          expect(await SpeakScoreLog.load(b), hasLength(2));
        });

        test('an old last lesson never beats one opened since', () async {
          final prefs = await prefsWith({kLastGrammarLessonKey: 33});
          // Device b opened 第45課 after the update, and a synced it before importing.
          now = at(1);
          await rememberLastGrammarLesson(b, 45);
          await sync(b, a);
          await importSpeakAndLessonPrefs(a, prefs: prefs);
          expect(await readLastGrammarLesson(a), 45);

          // Imported before the sync, the old value still loses on both devices.
          final c = await entry.value();
          addTearDown(c.close);
          await importSpeakAndLessonPrefs(c, prefs: prefs);
          expect(await readLastGrammarLesson(c), 33);
          await sync(c, b);
          // b pushed its events earlier, so c pulls them as they sit on the server.
          await c.appendRemoteEvents(await b.sideEvents());
          expect(await readLastGrammarLesson(c), 45);
          expect(await readLastGrammarLesson(b), 45);
          expect(
              (await c.sideEvents())
                  .firstWhere((e) => e.kind == JpEventKind.lastLesson)
                  .atUtc,
              kLegacyLastLessonAtUtc);
        });

        test('a run cut short before the flag skips what it already wrote',
            () async {
          final prefs = await prefsWith(oldPrefs());
          // The first readable old score, as a run cut short wrote it, with no flag.
          final first = DateTime.utc(2026, 10, 27, 9);
          await a.writeSideEvent(JpEvent(
            eventId: legacyEventId(JpEventKind.speakScore,
                [first.toIso8601String(), 'あたまが いたいんです。', true]),
            deviceId: null,
            atUtc: first,
            kind: JpEventKind.speakScore,
            body: attempt('あたまが いたいんです。', first).marked(true).toJson(),
          ));
          expect(await a.meta(kSpeakLessonImportFlag), isNull);
          expect(await importSpeakAndLessonPrefs(a, prefs: prefs), 2,
              reason: 'the second score and the last lesson');
          expect(await a.speakScores(), hasLength(2),
              reason: 'one speak_score event per old entry');
          expect(await a.meta(kSpeakLessonImportFlag), isNotNull);
        });

        test('first calls that overlap share one run and write each id once',
            () async {
          final prefs = await prefsWith(oldPrefs());
          final results = await Future.wait([
            importSpeakAndLessonPrefs(a, prefs: prefs),
            importSpeakAndLessonPrefs(a, prefs: prefs),
            readLastGrammarLesson(a, prefs: prefs),
            SpeakScoreLog.load(a).then((log) => log.length),
          ]);
          expect(results, [3, 3, 33, 2]);
          final events = await a.sideEvents();
          expect(events, hasLength(3), reason: 'no duplicate row');
          expect(idsOf(events), hasLength(3));
          // Once the run ends, a later call reads the flag again.
          expect(await importSpeakAndLessonPrefs(a, prefs: prefs), 0);
        });

        for (final bad in <String, Object>{
          'not JSON': 'not json [',
          'JSON but not a list': '{"sentence": "x"}',
          'not a string': 7,
        }.entries) {
          test('a score log that is ${bad.key} is reported, never silent',
              () async {
            final prefs = await prefsWith(
                {SpeakScoreLog.prefsKey: bad.value, kLastGrammarLessonKey: 33});
            final capture = ReportCapture();
            final written = await importSpeakAndLessonPrefs(a, prefs: prefs);
            final reports = capture.stop();
            expect(written, 1, reason: 'the last lesson still imports');
            expect(reports, hasLength(1));
            expect(reports.single.context.toString(),
                contains('while importing the old say-it score log'));
            expect(await a.meta(kSpeakLessonImportFlag), isNotNull);
          });
        }

        test('an absent score log is not reported', () async {
          final prefs = await prefsWith({kLastGrammarLessonKey: 33});
          final capture = ReportCapture();
          final written = await importSpeakAndLessonPrefs(a, prefs: prefs);
          expect(capture.stop(), isEmpty);
          expect(written, 1);
        });

        test('two devices that import one value share one event', () async {
          final prefs = await prefsWith(oldPrefs());
          await importSpeakAndLessonPrefs(a, prefs: prefs);
          await importSpeakAndLessonPrefs(b, prefs: prefs);
          expect(idsOf(await a.sideEvents()), idsOf(await b.sideEvents()));
          // A legacy event carries no device id, so both devices hold it field for field.
          Future<void> expectSameLegacyEvents() async {
            final fromA = {for (final e in await a.sideEvents()) e.eventId: e};
            final fromB = await b.sideEvents();
            expect(
                {for (final e in fromB) e.kind},
                {JpEventKind.speakScore, JpEventKind.lastLesson},
                reason: 'both imported kinds are checked');
            for (final e in [...fromA.values, ...fromB]) {
              expect(e.deviceId, isNull, reason: '${e.kind.wire} ${e.eventId}');
            }
            for (final e in fromB) {
              expect(e.sameContent(fromA[e.eventId]!), isTrue,
                  reason: '${e.kind.wire} ${e.eventId}');
            }
          }

          await expectSameLegacyEvents();
          await sync(a, b);
          expect(await b.sideEvents(), hasLength(3), reason: 'no duplicate');
          expect(await SpeakScoreLog.load(b), hasLength(2));
          await sync(b, a);
          expect(await a.sideEvents(), hasLength(3), reason: 'no duplicate');
          await expectSameLegacyEvents();
        });

        test('an import alone leaves every event with no device id', () async {
          final prefs = await prefsWith(oldPrefs());
          expect(await importSpeakAndLessonPrefs(a, prefs: prefs), 3);
          final events = await a.sideEvents();
          expect({for (final e in events) e.kind},
              {JpEventKind.speakScore, JpEventKind.lastLesson});
          for (final e in events) {
            expect(e.deviceId, isNull, reason: '${e.kind.wire} ${e.eventId}');
          }
          expect([for (final e in await a.unpushedEvents()) e.deviceId],
              [null, null, null],
              reason: 'the events wait for the sync as they were written');
        });
      });
    });
  }

  group('a failed score log write', () {
    List<String> contexts(List<FlutterErrorDetails> reports) =>
        [for (final r in reports) r.context.toString()];

    test('a failed score write is reported and add still returns', () async {
      final store = _ScoreWriteFailsStore();
      final capture = ReportCapture();
      final log = await SpeakScoreLog.add(store, attempt('あたま', at(1)));
      final reports = capture.stop();
      expect(log, isEmpty);
      expect(contexts(reports), ['while saving a say-it score']);
      expect(reports.single.library, 'say-it score log');
    });

    test('a failed mark write is reported and mark still returns', () async {
      final store = _ScoreWriteFailsStore();
      final capture = ReportCapture();
      final log = await SpeakScoreLog.mark(store, attempt('ねこ', at(1)), true);
      final reports = capture.stop();
      expect(log, isEmpty);
      expect(contexts(reports), ['while saving a say-it score']);
    });

    test('a failed import is reported and the score still lands', () async {
      final store = _ImportFailsStore(clock: clock);
      final capture = ReportCapture();
      final log = await SpeakScoreLog.add(store, attempt('あたま', at(1)));
      final reports = capture.stop();
      expect(contexts(reports), ['while saving a say-it score']);
      expect(
          (await store.speakScores()).map((e) => e.body['sentence']), ['あたま']);
      // The list add returns still reads the store when only the import fails.
      expect(log.map((x) => x.sentence), ['あたま']);
    });

    test('a failed import still shows a synced score on load', () async {
      final store = _ImportFailsStore(clock: clock);
      await store.recordSpeakScore(attempt('ねこ', at(1)).toJson(),
          atUtc: at(1).toUtc());
      final log = await SpeakScoreLog.load(store);
      expect(log.map((x) => x.sentence), ['ねこ']);
    });

    test('a failed mark import still returns the marked score', () async {
      final store = _ImportFailsStore(clock: clock);
      final capture = ReportCapture();
      final log = await SpeakScoreLog.mark(store, attempt('いぬ', at(1)), true);
      capture.stop();
      expect(log.map((x) => x.sentence), ['いぬ']);
    });

    test('a write that lands reports nothing', () async {
      final capture = ReportCapture();
      await SpeakScoreLog.add(JpStoreMemory(clock: clock), attempt('x', at(1)));
      expect(capture.stop(), isEmpty);
    });
  });

  group('a failed import on the last lesson', () {
    List<String> contexts(List<FlutterErrorDetails> reports) =>
        [for (final r in reports) r.context.toString()];

    test('remember still writes the lesson and read still returns it',
        () async {
      final store = _ImportFailsStore(clock: clock);
      final capture = ReportCapture();
      await rememberLastGrammarLesson(store, 41);
      final read = await readLastGrammarLesson(store);
      final reports = capture.stop();
      final events = (await store.sideEvents())
          .where((e) => e.kind == JpEventKind.lastLesson)
          .toList();
      expect(events, hasLength(1));
      expect(events.single.body['lessonId'], '41');
      expect(read, 41);
      expect(contexts(reports), [
        'while importing the old last lesson',
        'while importing the old last lesson',
      ]);
      expect(reports.first.library, 'speak lesson events');
    });

    test('read still returns a synced lesson', () async {
      final store = _ImportFailsStore(clock: clock);
      await store.setLastLesson('7', atUtc: at(1).toUtc());
      final capture = ReportCapture();
      final read = await readLastGrammarLesson(store);
      final reports = capture.stop();
      expect(read, 7);
      expect(contexts(reports), ['while importing the old last lesson']);
    });
  });

  group('SpeakScoreLog.fromEvents', () {
    JpEvent score(Map<String, dynamic> body, DateTime atUtc) => JpEvent(
        eventId: newEventId(),
        deviceId: 'd',
        atUtc: atUtc,
        kind: JpEventKind.speakScore,
        body: body);

    test('keeps the newest ${SpeakScoreLog.keep} attempts, oldest first', () {
      final events = [
        for (var i = 0; i <= SpeakScoreLog.keep; i++)
          score(attempt('s$i', at(0).add(Duration(seconds: i))).toJson(),
              at(0).add(Duration(seconds: i)))
      ];
      final log = SpeakScoreLog.fromEvents(events.reversed);
      expect(log, hasLength(SpeakScoreLog.keep));
      expect(log.first.sentence, 's1');
      expect(log.last.sentence, 's${SpeakScoreLog.keep}');
    });

    test('orders bodies from two zones by instant, not wall clock', () {
      // 10:00 in Tokyo is 01:00Z, before 09:00Z, though its wall clock reads later.
      final log = SpeakScoreLog.fromEvents([
        score(attempt('utc', at(0)).toJson(), at(0)),
        score({
          ...attempt('tokyo', at(0)).toJson(),
          'at': '2026-11-19T10:00:00.000+09:00',
        }, DateTime.utc(2026, 11, 19, 1)),
      ]);
      expect(log.map((x) => x.sentence), ['tokyo', 'utc']);
    });

    test('an attempt and its mark share one entry across time forms', () {
      // An offset-less local time, as an older body held it, and its mark in UTC.
      final x = attempt('あたま', DateTime(2026, 11, 19, 9));
      final log = SpeakScoreLog.fromEvents([
        score({...x.toJson(), 'at': x.at.toIso8601String()}, x.at.toUtc()),
        score(x.marked(true).toJson(), x.at.toUtc().add(kLocalTieBump)),
      ]);
      expect(log, hasLength(1));
      expect(log.single.selfMark, isTrue);
    });

    test('toJson writes the attempt time in UTC', () {
      final local = DateTime(2026, 11, 19, 9);
      final json = attempt('x', local).toJson();
      expect(json['at'], local.toUtc().toIso8601String());
      expect((json['at'] as String).endsWith('Z'), isTrue);
      expect(SpeakAttempt.fromJson(json)!.at.isAtSameMomentAs(local), isTrue);
    });

    test('skips a body this build cannot read', () {
      final log = SpeakScoreLog.fromEvents([
        score({'verdict': 'close'}, at(1)),
        score(attempt('ok', at(2)).toJson(), at(2)),
      ]);
      expect(log.map((x) => x.sentence), ['ok']);
    });
  });
}

Set<String> idsOf(Iterable<JpEvent> events) =>
    {for (final e in events) e.eventId};

/// A memory store whose say-it score write fails, as a locked database would.
class _ScoreWriteFailsStore extends JpStoreMemory {
  _ScoreWriteFailsStore() : super(clock: clock);

  @override
  Future<JpEvent> recordSpeakScore(Map<String, dynamic> score,
          {required DateTime atUtc}) =>
      Future.error(StateError('jp store: database is locked'));
}

/// A memory store whose one-time import fails at its flag read. Every other read works.
class _ImportFailsStore extends JpStoreMemory {
  _ImportFailsStore({super.clock});

  @override
  Future<String?> meta(String key) => key == kSpeakLessonImportFlag
      ? Future.error(StateError('jp store: database is locked'))
      : super.meta(key);
}
