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
          expect((await SharedPreferences.getInstance())
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

        test('a mark whose attempt never saved still keeps its entry',
            () async {
          final log =
              await SpeakScoreLog.mark(a, attempt('ねこ', at(2)), false);
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
          expect(log.map((x) => x.sentence),
              ['あたまが いたいんです。', 'ねこが います。'],
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

        test('two devices that import one value share one event', () async {
          final prefs = await prefsWith(oldPrefs());
          await importSpeakAndLessonPrefs(a, prefs: prefs);
          await importSpeakAndLessonPrefs(b, prefs: prefs);
          expect(idsOf(await a.sideEvents()), idsOf(await b.sideEvents()));
          await sync(a, b);
          expect(await b.sideEvents(), hasLength(3), reason: 'no duplicate');
          expect(await SpeakScoreLog.load(b), hasLength(2));
        });
      });
    });
  }

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
