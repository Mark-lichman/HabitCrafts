// Widget tests for the vocabulary screen: the head word's `context` line (D18), the Knew it
// and Not yet pills after a reveal and the attempts they write (PIN-13, PIN-14), a failed
// write that says so (S4), and the remembered lesson.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/components/pages/quiet_room_lesson/quiet_room_lesson_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';

import 'jp_screen_harness.dart';

/// The word file, read straight from disk to derive what each test expects.
Map<String, dynamic> readWordFile() =>
    json.decode(File('assets/lessons/jp_lessons.json').readAsStringSync())
        as Map<String, dynamic>;

/// The words of lesson [no], in screen order.
List<Map<String, dynamic>> wordsOf(int no) => ((readWordFile()['lessons']
            as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((l) => l['lesson'] == no)['items'] as List)
    .cast<Map<String, dynamic>>();

/// The first word of the course that carries a `context` line, and its lesson.
({int lesson, Map<String, dynamic> word}) firstWithContext() {
  for (final l
      in (readWordFile()['lessons'] as List).cast<Map<String, dynamic>>()) {
    for (final w in (l['items'] as List).cast<Map<String, dynamic>>()) {
      if (w['context'] != null) return (lesson: l['lesson'] as int, word: w);
    }
  }
  throw StateError('no word carries a context line');
}

/// The real catalog, built from the shipped assets.
ItemCatalog catalog() => ItemCatalog.fromDocs(readLessonFile(), readWordFile());

/// A store whose writes fail, for the S4 message.
class FailingStore extends JpStoreMemory {
  @override
  Future<Attempt> appendAttempt(Attempt attempt,
          {SrsState? srs, MasteryState? mastery}) =>
      Future.error(StateError('disk full'));
}

/// 10:00 on 2026-11-03, well clear of the 04:00 day boundary.
final DateTime kNow = DateTime(2026, 11, 3, 10);

/// Pumps the screen. The word file is warmed under `runAsync` first: a large `loadString`
/// decodes on another isolate, which the fake clock never advances.
Future<void> pumpLesson(WidgetTester tester, QuietRoomLessonWidget screen) async {
  await tester.runAsync(
      () => rootBundle.loadString('assets/lessons/jp_lessons.json'));
  await pumpStudyScreen(tester, screen);
}

QuietRoomLessonWidget screen({int? lesson, JpStore? store}) =>
    QuietRoomLessonWidget(
      initialLesson: lesson,
      store: store ?? JpStoreMemory(),
      items: catalog().byId,
      clock: FixedClock(kNow),
      scheduler: const FsrsScheduler(),
    );

final Finder knewIt = find.text('Knew it');
final Finder notYet = find.text('Not yet');

/// Turns the card for [kana] over.
Future<void> reveal(WidgetTester tester, String kana) async {
  await tester.tap(find.text(kana).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the context line sits under its head word', (tester) async {
    final hit = firstWithContext();
    await pumpLesson(tester, screen(lesson: hit.lesson));

    final head = find.text(hit.word['kana'] as String).first;
    final context = find.text(hit.word['context'] as String);
    expect(context, findsOneWidget);
    // Under the head word, and shown before the card is turned over.
    expect(tester.getTopLeft(context).dy,
        greaterThan(tester.getBottomLeft(head).dy - 1));
    expect(find.text(hit.word['gloss'] as String), findsNothing);
  });

  testWidgets('the pills appear only after the meaning is revealed',
      (tester) async {
    final word = wordsOf(30).first;
    await pumpLesson(tester, screen(lesson: 30));
    expect(knewIt, findsNothing);
    expect(notYet, findsNothing);

    await reveal(tester, word['kana'] as String);
    expect(find.text(word['gloss'] as String), findsOneWidget);
    expect(knewIt, findsOneWidget);
    expect(notYet, findsOneWidget);
  });

  testWidgets('Knew it on a due word writes a clear review on the card probe',
      (tester) async {
    final word = wordsOf(30).first;
    final id = word['id'] as String;
    final store = JpStoreMemory();
    final today = FixedClock(kNow).today();
    await store.appendSeed(id, today, atUtc: kNow.toUtc());
    await pumpLesson(tester, screen(lesson: 30, store: store));

    await reveal(tester, word['kana'] as String);
    await tester.tap(knewIt);
    await tester.pumpAndSettle();

    final written = await store.attempts();
    expect(written, hasLength(1));
    final a = written.single;
    expect(a.itemId, id);
    expect(a.probeId, 'card');
    expect(a.template, 'card');
    expect(a.selfGraded, isTrue);
    expect(a.production, isFalse);
    expect(a.revealed, isTrue);
    expect(a.hintLevel, 0);
    expect(a.grade, Grade.clear);
    expect(a.rating, kRatingGood);
    expect(a.wasDue, isTrue);
    expect(a.source, Source.review);
    expect(a.localDay, today);
    // The schedule and the mastery moved in the same answer.
    expect(await store.srs(id), isNotNull);
    final m = await store.mastery(id);
    expect(m!.status, MasteryStatus.learning);
    expect(m.clears, hasLength(1));
    // One grade per reveal: the pills stop taking taps.
    await tester.tap(notYet);
    await tester.pumpAndSettle();
    expect(await store.attempts(), hasLength(1));
  });

  testWidgets('Not yet writes a wrong that counts even when not due',
      (tester) async {
    final word = wordsOf(30).first;
    final id = word['id'] as String;
    final store = JpStoreMemory();
    await pumpLesson(tester, screen(lesson: 30, store: store));

    await reveal(tester, word['kana'] as String);
    await tester.tap(notYet);
    await tester.pumpAndSettle();

    final a = (await store.attempts()).single;
    expect(a.itemId, id);
    expect(a.grade, Grade.wrong);
    expect(a.rating, kRatingAgain);
    expect(a.wasDue, isFalse);
    expect(a.source, Source.early);
    // An early wrong is a real wrong: due tomorrow (PIN-14).
    expect((await store.srs(id))!.dueDay, FixedClock(kNow).today() + 1);
    expect((await store.mastery(id))!.status, MasteryStatus.learning);
  });

  testWidgets('Knew it on a word not yet due is early and changes nothing',
      (tester) async {
    final word = wordsOf(30).first;
    final id = word['id'] as String;
    final store = JpStoreMemory();
    await pumpLesson(tester, screen(lesson: 30, store: store));

    await reveal(tester, word['kana'] as String);
    await tester.tap(knewIt);
    await tester.pumpAndSettle();

    final a = (await store.attempts()).single;
    expect(a.grade, Grade.clear);
    expect(a.source, Source.early);
    // PIN-14: an early clear moves neither the schedule nor the mastery.
    expect(await store.srs(id), isNull);
    final m = await store.mastery(id);
    expect(m == null || m.status == MasteryStatus.neu, isTrue);
  });

  testWidgets('a write that fails says so and leaves the pills to try again',
      (tester) async {
    final word = wordsOf(30).first;
    await pumpLesson(tester, screen(lesson: 30, store: FailingStore()));

    await reveal(tester, word['kana'] as String);
    await tester.tap(knewIt);
    await tester.pumpAndSettle();

    expect(find.text(QuietRoomLessonWidget.saveFailedMessage), findsOneWidget);
    // Not marked as graded: the pill still takes a tap.
    final pill = tester.widget<InkWell>(
        find.ancestor(of: knewIt, matching: find.byType(InkWell)).first);
    expect(pill.onTap, isNotNull);
  });

  testWidgets('the last-opened lesson is remembered', (tester) async {
    await pumpLesson(tester, screen(lesson: 30));
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    expect(find.text('第12課'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(QuietRoomLessonWidget.lastLessonKey), 12);

    // A fresh open with no lesson named continues from it. Prefs are kept, so the screen is
    // pumped directly rather than through the harness, which resets them.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: screen()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('第12課'), findsOneWidget);
  });

  testWidgets('a named lesson wins over the remembered one and is remembered',
      (tester) async {
    // A remembered lesson is seeded first, so the named one has something to beat. The
    // harness resets the prefs, so the screen is pumped directly, as the test above does.
    SharedPreferences.setMockInitialValues(
        {QuietRoomLessonWidget.lastLessonKey: 12});
    await tester.runAsync(
        () => rootBundle.loadString('assets/lessons/jp_lessons.json'));
    await tester.pumpWidget(MaterialApp(home: screen(lesson: 6)));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(find.text('第6課'), findsOneWidget);
    expect(find.text('第12課'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(QuietRoomLessonWidget.lastLessonKey), 6);
  });
}
