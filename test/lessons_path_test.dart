// Tests for the lesson path (plan 2026-11-02, Task 26, End states 1 and 9).
//
// The path is one vertical list read from a `TopicIndex` over the shipped catalog and a memory
// store, with an injected clock. The cases: 第26課 to 第50課 in order, each with its title, what
// it holds and the counts over its items (PIN-1), never a Done mark or a percentage; the current
// lesson as the one loud row (the last grammar lesson opened, else the first with an item not
// yet Mastered); a Words-only section for 第2課 to 第25課, where a lesson with no sheet says so;
// a row opening the lesson page, by route name under the app router; a 第26課 to 第50課 row
// making its lesson the current one when it opens (operator ruling ASK-11); and the home's
// Lessons tab opening the path instead of a fixed lesson.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show debugSetSharedJpStore;
import 'package:habit_craft/components/pages/quiet_room_mastery/lesson_page_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/lessons_path_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed_confirm_widget.dart'
    show kLastGrammarLessonKey;
import 'package:habit_craft/components/pages/quiet_room_mastery/topic_index.dart';
import 'package:habit_craft/flutter_flow/nav/nav.dart';

import 'jp_screen_harness.dart' show holdHttpRequests, pumpStudyScreen;

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final grammar = _read('assets/lessons/jp_grammar.json');
final catalog =
    ItemCatalog.fromDocs(grammar, _read('assets/lessons/jp_lessons.json'));

const int today = 300;

/// 10:00 local on [day].
DateTime at(int day) => dayStart(day).add(const Duration(hours: 6));

Future<void> clearOn(JpStore store, ItemDef item, int day) {
  final p = item.scoredProbes.first;
  return store.recordAnswer(
      Attempt(
        itemId: item.id,
        probeId: p.id,
        template: p.template,
        production: p.production,
        selfGraded: p.selfGraded,
        atUtc: at(day).toUtc(),
        localDay: day,
        grade: Grade.clear,
        rating: fsrsRatingFor(Grade.clear),
        hintLevel: 0,
        wasDue: true,
        source: Source.review,
        sessionId: 'test',
      ),
      item: item,
      scheduler: const FsrsScheduler());
}

List<ItemDef> grammarOf(int lesson) => [
      for (final i in catalog.ofKind(ItemKind.grammar))
        if (i.lesson == lesson) i
    ];

List<ItemDef> wordsOf(int lesson) => [
      for (final i in catalog.ofKind(ItemKind.word))
        if (i.lesson == lesson) i
    ];

String grammarTitle(int lesson) => (grammar['grammar'] as List)
    .cast<Map<String, dynamic>>()
    .firstWhere((l) => l['lesson'] == lesson)['title'] as String;

Future<TopicIndex> indexOf(JpStore store) => TopicIndex.load(
    store: store, catalog: catalog, grammar: grammar, today: today);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 12000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget path(JpStore store) => LessonsPathWidget(
      store: store,
      catalog: catalog,
      grammar: grammar,
      clock: FixedClock(at(today)),
    );

Future<void> pumpPath(WidgetTester tester, JpStore store,
    {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  bigView(tester);
  await tester.pumpWidget(MaterialApp(home: path(store)));
  await settle(tester);
}

LessonPathRow row(int lesson,
        {int points = 2, int words = 0, int mastered = 0}) =>
    LessonPathRow(
      lesson: lesson,
      title: null,
      points: points,
      words: words,
      counts: TopicCounts(mastered: mastered, neu: points + words - mastered),
      pill: MasteryStatus.neu,
    );

void main() {
  setUpAll(holdHttpRequests);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The shipped data the cases lean on: 第30課 has grammar and a word sheet, 第31課 has grammar
  // and no word sheet, 第5課 has words and no grammar, 第18課 has neither.
  test('the shipped lessons hold the shapes the cases use', () {
    expect(grammarOf(30), isNotEmpty);
    expect(wordsOf(30), isNotEmpty);
    expect(grammarOf(31), isNotEmpty);
    expect(wordsOf(31), isEmpty);
    expect(grammarOf(5), isEmpty);
    expect(wordsOf(5), isNotEmpty);
    expect(grammarOf(18), isEmpty);
    expect(wordsOf(18), isEmpty);
  });

  group('lessonHoldsLine', () {
    test('names the grammar points and the words, or says there is no sheet',
        () {
      expect(lessonHoldsLine(4, 48), '4 grammar points · 48 words');
      expect(lessonHoldsLine(1, 1), '1 grammar point · 1 word');
      expect(lessonHoldsLine(3, 0), '3 grammar points · no word sheet');
      expect(lessonHoldsLine(0, 20), '20 words');
      expect(lessonHoldsLine(0, 0), 'No word sheet');
    });
  });

  group('lessonPathOf', () {
    test('lists 第26課 to 第50課 in order with titles, then 第2課 to 第25課', () async {
      final p = lessonPathOf(await indexOf(JpStoreMemory()), grammar);
      expect([for (final r in p.grammar) r.lesson],
          [for (var l = 26; l <= 50; l++) l]);
      expect([for (final r in p.wordsOnly) r.lesson],
          [for (var l = 2; l <= 25; l++) l]);
      for (final r in p.grammar) {
        expect(r.title, grammarTitle(r.lesson), reason: '第${r.lesson}課');
        expect(r.points, grammarOf(r.lesson).length);
        expect(r.words, wordsOf(r.lesson).length);
      }
      for (final r in p.wordsOnly) {
        expect(r.points, 0, reason: 'words only: 第${r.lesson}課');
        expect(r.words, wordsOf(r.lesson).length);
      }
    });

    test('counts each lesson by its items own states, never the lesson number',
        () async {
      final store = JpStoreMemory();
      await clearOn(store, grammarOf(30).first, today - 2);
      await clearOn(store, wordsOf(5).first, today - 2);
      final p = lessonPathOf(await indexOf(store), grammar);
      final r30 = p.grammar.firstWhere((r) => r.lesson == 30);
      final total30 = grammarOf(30).length + wordsOf(30).length;
      expect(r30.counts.learning, 1);
      expect(r30.counts.total, total30);
      expect(r30.countsLine, '0 mastered · 1 learning · ${total30 - 1} new');
      expect(r30.pill, MasteryStatus.learning);
      final r5 = p.wordsOnly.firstWhere((r) => r.lesson == 5);
      expect(r5.countsLine,
          '0 mastered · 1 learning · ${wordsOf(5).length - 1} new');
      // A lesson nobody touched is all New, whatever its number.
      final r26 = p.grammar.firstWhere((r) => r.lesson == 26);
      expect(r26.counts.neu, r26.counts.total);
      expect(r26.pill, MasteryStatus.neu);
    });

    test('a seeded first launch leaves every lesson at zero mastered',
        () async {
      final store = JpStoreMemory();
      await seedFromLessons(today, store, catalog, nowUtc: at(today).toUtc());
      final p = lessonPathOf(await indexOf(store), grammar);
      for (final r in [...p.grammar, ...p.wordsOnly]) {
        expect(r.counts.mastered, 0, reason: '第${r.lesson}課');
      }
    });

    test('a lesson with no sheet keeps its row, says so and has no counts',
        () async {
      final p = lessonPathOf(await indexOf(JpStoreMemory()), grammar);
      final r18 = p.wordsOnly.firstWhere((r) => r.lesson == 18);
      expect(r18.isEmpty, isTrue);
      expect(r18.holds, 'No word sheet');
      expect(r18.countsLine, isNull);
    });
  });

  group('currentLessonOf', () {
    test('the last lesson the grammar screen opened wins', () {
      expect(currentLessonOf([row(26), row(27), row(28)], 28), 28);
    });

    test('else the first lesson with an item not yet Mastered', () {
      final rows = [row(26, mastered: 2), row(27, mastered: 1), row(28)];
      expect(currentLessonOf(rows, null), 27);
    });

    test('a last lesson off the path is ignored', () {
      expect(currentLessonOf([row(26, mastered: 2), row(27)], 5), 27);
    });

    test('every lesson Mastered falls back to the first', () {
      expect(
          currentLessonOf([row(26, mastered: 2), row(27, mastered: 2)], null),
          26);
    });
  });

  group('the path', () {
    testWidgets(
        'shows every lesson with its title, what it holds and its counts, and no Done',
        (tester) async {
      final store = JpStoreMemory();
      await clearOn(store, grammarOf(30).first, today - 2);
      await pumpPath(tester, store);

      expect(find.text(kLessonsTitle), findsOneWidget);
      expect(find.text(kPathGrammarHeading), findsOneWidget);
      expect(find.text(kWordsOnlyHeading), findsOneWidget);
      for (var l = 27; l <= 50; l++) {
        expect(find.byKey(ValueKey('path-$l')), findsOneWidget, reason: '第$l課');
        expect(find.text('第$l課  ${grammarTitle(l)}'), findsOneWidget);
      }
      for (var l = 2; l <= 25; l++) {
        expect(find.byKey(ValueKey('path-$l')), findsOneWidget, reason: '第$l課');
        expect(find.text('第$l課'), findsOneWidget);
      }
      final r30 = find.byKey(const ValueKey('path-30'));
      final total30 = grammarOf(30).length + wordsOf(30).length;
      expect(
          find.descendant(
              of: r30,
              matching: find.text(
                  lessonHoldsLine(grammarOf(30).length, wordsOf(30).length))),
          findsOneWidget);
      expect(
          find.descendant(
              of: r30,
              matching:
                  find.text('0 mastered · 1 learning · ${total30 - 1} new')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('path-18')),
              matching: find.text('No word sheet')),
          findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('with no lesson opened yet, 第26課 is the one loud row',
        (tester) async {
      await pumpPath(tester, JpStoreMemory());
      final loud = find.byKey(const ValueKey('path-current'));
      expect(loud, findsOneWidget);
      expect(find.descendant(of: loud, matching: find.text('第26課')),
          findsOneWidget);
      expect(find.descendant(of: loud, matching: find.text(grammarTitle(26))),
          findsOneWidget);
      expect(
          find.descendant(of: loud, matching: find.text(kCurrentLessonLabel)),
          findsOneWidget);
      expect(find.byKey(const ValueKey('path-26')), findsNothing,
          reason: 'the loud row stands in for the quiet one');
    });

    testWidgets('the last lesson the grammar screen opened is the loud row',
        (tester) async {
      await pumpPath(tester, JpStoreMemory(),
          prefs: {kLastGrammarLessonKey: 33});
      final loud = find.byKey(const ValueKey('path-current'));
      expect(find.descendant(of: loud, matching: find.text('第33課')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('path-33')), findsNothing);
      expect(find.byKey(const ValueKey('path-26')), findsOneWidget);
    });

    testWidgets('a row opens the lesson page on its lesson', (tester) async {
      await pumpPath(tester, JpStoreMemory());
      final f = find.byKey(const ValueKey('path-5'));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle(tester);
      expect(
          find.byWidgetPredicate((w) => w is LessonPageWidget && w.lesson == 5),
          findsOneWidget);
    });

    testWidgets(
        'opening a grammar lesson makes it the current lesson; a words-only one '
        'does not (ASK-11)', (tester) async {
      await pumpPath(tester, JpStoreMemory());
      final f = find.byKey(const ValueKey('path-41'));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle(tester);
      expect(
          find.byWidgetPredicate(
              (w) => w is LessonPageWidget && w.lesson == 41),
          findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kLastGrammarLessonKey), 41);

      Navigator.of(tester.element(find.byType(LessonPageWidget))).pop();
      await settle(tester);
      final loud = find.byKey(const ValueKey('path-current'));
      expect(find.descendant(of: loud, matching: find.text('第41課')),
          findsOneWidget,
          reason: 'the loud row follows the learner');
      expect(find.byKey(const ValueKey('path-26')), findsOneWidget);

      final words = find.byKey(const ValueKey('path-5'));
      await tester.ensureVisible(words);
      await tester.tap(words);
      await settle(tester);
      expect(prefs.getInt(kLastGrammarLessonKey), 41,
          reason: 'a words-only lesson is not a grammar lesson');
    });

    testWidgets('the loud row opens the lesson page on the current lesson',
        (tester) async {
      await pumpPath(tester, JpStoreMemory(),
          prefs: {kLastGrammarLessonKey: 30});
      await tester.tap(find.byKey(const ValueKey('path-current')));
      await settle(tester);
      expect(
          find.byWidgetPredicate(
              (w) => w is LessonPageWidget && w.lesson == 30),
          findsOneWidget);
    });

    testWidgets('under the app router a row pushes the lesson page route',
        (tester) async {
      debugSetSharedJpStore(JpStoreMemory());
      addTearDown(() => debugSetSharedJpStore(null));
      bigView(tester);
      String? pushed;
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => LessonsPathWidget(
              catalog: catalog, grammar: grammar, clock: FixedClock(at(today))),
        ),
        GoRoute(
          name: LessonPageWidget.routeName,
          path: LessonPageWidget.routePath,
          builder: (_, state) {
            pushed = state.uri.queryParameters['lesson'];
            return const Text('the lesson page');
          },
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await settle(tester);

      final f = find.byKey(const ValueKey('path-41'));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle(tester);
      expect(find.text('the lesson page'), findsOneWidget);
      expect(pushed, '41');
    });
  });

  testWidgets('the Lessons tab of the home opens the path, not a fixed lesson',
      (tester) async {
    final store = JpStoreMemory();
    await seedFromLessons(today, store, catalog, nowUtc: at(today).toUtc());
    await pumpStudyScreen(
        tester,
        QuietRoomJapaneseWidget(
            store: store, catalog: catalog, clock: FixedClock(at(today))));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('tab-lessons')));
    await settle(tester);
    expect(find.byType(LessonsPathWidget), findsOneWidget);
    expect(find.byType(LessonPageWidget), findsNothing);
    expect(find.byKey(const ValueKey('path-current')), findsOneWidget);
  });

  test('nav.dart registers the lesson path and lesson page routes', () {
    final router = createRouter(AppStateNotifier.instance);
    addTearDown(router.dispose);
    expect(router.namedLocation(LessonsPathWidget.routeName),
        LessonsPathWidget.routePath);
    expect(
        router.namedLocation(LessonPageWidget.routeName,
            queryParameters: {'lesson': '30'}),
        '${LessonPageWidget.routePath}?lesson=30');
  });
}
