// Tests for the lesson page (plan 2026-11-02, Task 25, End state 1, End state 9).
//
// One page per 第N課, read from a `TopicIndex` over the shipped catalog and a memory store,
// with an injected clock. The cases: the title and the counts over the lesson's items, each a
// count of the items' own states (PIN-1); the grammar points with state and n of 4; the words
// with state where a sheet exists, and a plain "no word sheet" line where none does; the Say-it
// counts over the lesson's grammar; Review these, which runs the session over the lesson's due
// items only, as reviews, and is off when nothing is due; Read the whole lesson, which opens the
// existing grammar screen on the lesson (by route name under the app router) and is absent
// where the lesson has no grammar; Word cards, which opens the word-card screen on the lesson
// (by route name under the app router) and is absent where the lesson has no words (operator
// ruling ASK-12); and a row opening the item page. A fake probe builder stands
// in for the probe widgets, as in topics_widget_test.dart.
//
// Plan 2026-11-06, Task 1: a particle a Mari lesson teaches opens this page with the particle
// block on top and never its example or cloze sentence (PIN-5, End state 2), with the "Back to
// practice" bar; and `lessonTargetOf` names the screen and query each item kind opens (D20).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart'
    show kBackToPractice;
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_drills_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_grammar_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_lesson/quiet_room_lesson_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_detail_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show debugSetSharedJpStore;
import 'package:habit_craft/components/pages/quiet_room_mastery/lesson_page_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_debug_widget.dart'
    show dueLabel;
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/topic_index.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/topic_page_widget.dart'
    show TopicPageWidget;

import 'jp_screen_harness.dart' show holdHttpRequests;

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final grammar = _read('assets/lessons/jp_grammar.json');
final catalog =
    ItemCatalog.fromDocs(grammar, _read('assets/lessons/jp_lessons.json'));

const int today = 300;

/// 10:00 local on [day].
DateTime at(int day) => dayStart(day).add(const Duration(hours: 6));

Attempt answer(ItemDef item, int day, Grade grade,
    {Source source = Source.review, ProbeDef? probe}) {
  final p = probe ?? item.scoredProbes.first;
  return Attempt(
    itemId: item.id,
    probeId: p.id,
    template: p.template,
    production: p.production,
    selfGraded: p.selfGraded,
    atUtc: at(day).toUtc(),
    localDay: day,
    grade: grade,
    rating: source == Source.sayIt ? null : fsrsRatingFor(grade),
    hintLevel: grade == Grade.hinted ? 1 : 0,
    wasDue: true,
    source: source,
    sessionId: 'test',
  );
}

Future<void> record(JpStore store, Attempt a) => store.recordAnswer(a,
    item: catalog.byId(a.itemId), scheduler: const FsrsScheduler());

/// The fake probe: the item id and two answers.
Widget fakeProbe(BuildContext context, SessionProbeRequest r) {
  final probe = r.item.scoredProbes.first;
  DrillAnswer draft(Grade g) => DrillAnswer(
      itemId: r.item.id,
      probeId: probe.id,
      template: probe.template,
      production: probe.production,
      selfGraded: probe.selfGraded,
      grade: g,
      hintLevel: 0);
  return Column(children: [
    Text('probe ${r.item.id}'),
    for (final g in [Grade.clear, Grade.wrong])
      TextButton(
          onPressed: () => r.onAnswer(draft(g)),
          child: Text('answer ${g.name}')),
  ]);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  final f = find.text(label);
  expect(f, findsOneWidget, reason: 'a "$label" control');
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 12000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget lessonPage(JpStore store, int lesson) => LessonPageWidget(
      lesson: lesson,
      store: store,
      catalog: catalog,
      grammar: grammar,
      clock: FixedClock(at(today)),
      probeBuilder: fakeProbe,
    );

Future<void> pumpLesson(WidgetTester tester, JpStore store, int lesson) async {
  bigView(tester);
  await tester.pumpWidget(MaterialApp(home: lessonPage(store, lesson)));
  await settle(tester);
}

bool shows(String text) => find.text(text).evaluate().isNotEmpty;

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

void main() {
  setUpAll(holdHttpRequests);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The shipped data the cases lean on: 第30課 has grammar and a word sheet, 第31課 has grammar
  // and no word sheet, 第5課 has words and no grammar.
  test('the shipped lessons hold the shapes the cases use', () {
    expect(grammarOf(30), isNotEmpty);
    expect(wordsOf(30), isNotEmpty);
    expect(grammarOf(31), isNotEmpty);
    expect(wordsOf(31), isEmpty);
    expect(grammarOf(5), isEmpty);
    expect(wordsOf(5), isNotEmpty);
  });

  group('lessonCountsLabel', () {
    test('names mastered always and the other states only when present', () {
      expect(lessonCountsLabel(const TopicCounts(learning: 3, neu: 2)),
          '0 mastered · 3 learning · 2 new');
      expect(lessonCountsLabel(const TopicCounts(mastered: 2, shaky: 1)),
          '2 mastered · 1 shaky');
      expect(lessonCountsLabel(const TopicCounts()), '0 mastered');
    });
  });

  group('lessonPageOf (PIN-1)', () {
    test('counts the lesson items by their own states, never the lesson number',
        () {
      final g = grammarOf(30);
      final w = wordsOf(30);
      final learning = MasteryState.initial(g.first.id)
          .copyWith(status: MasteryStatus.learning);
      final shaky = MasteryState.initial(w.first.id)
          .copyWith(status: MasteryStatus.shaky);
      final index = TopicIndex(
        catalog: catalog,
        grammar: grammar,
        today: today,
        mastery: {g.first.id: learning, w.first.id: shaky},
        seedDue: {w[1].id: today, g.last.id: today - 2, w[2].id: today + 3},
      );
      final page = lessonPageOf(30, index, grammar, const []);
      expect(page.title, grammarTitle(30));
      expect(page.grammarIds, [for (final i in g) i.id]);
      expect(page.wordIds, [for (final i in w) i.id]);
      expect(page.hasWordSheet, isTrue);
      expect(page.hasGrammar, isTrue);
      expect(page.counts.total, g.length + w.length);
      expect(page.counts.learning, 1);
      expect(page.counts.shaky, 1);
      expect(page.counts.neu, g.length + w.length - 2);
      expect(page.counts.mastered, 0);
      // Due today or before, soonest first; a later seed is not due.
      expect(page.dueIds, [g.last.id, w[1].id]);

      // The same states in another lesson's items count there, not here.
      final other = lessonPageOf(31, index, grammar, const []);
      expect(other.counts.learning + other.counts.shaky, 0);
      expect(other.hasWordSheet, isFalse);
      expect(other.dueIds, isEmpty);
    });

    test('Say-it counts sum the lesson grammar sayIt answers only', () {
      final g = grammarOf(30).first;
      final ex = g.probes.firstWhere((p) => p.template == kSayItTemplate);
      final elsewhere = grammarOf(31).first;
      final exElse =
          elsewhere.probes.firstWhere((p) => p.template == kSayItTemplate);
      final attempts = [
        answer(g, today - 1, Grade.clear, source: Source.sayIt, probe: ex),
        answer(g, today - 1, Grade.wrong, source: Source.sayIt, probe: ex),
        answer(g, today - 1, Grade.unscored, source: Source.sayIt, probe: ex),
        answer(g, today - 1, Grade.clear),
        answer(elsewhere, today - 1, Grade.clear,
            source: Source.sayIt, probe: exElse),
      ];
      final index =
          TopicIndex(catalog: catalog, grammar: grammar, today: today);
      final page = lessonPageOf(30, index, grammar, attempts);
      expect(page.sayItTries, 2, reason: 'an unscored try is no try');
      expect(page.sayItClear, 1);
    });

    test('a lesson with no grammar and no sheet is empty, never an error', () {
      final index =
          TopicIndex(catalog: catalog, grammar: grammar, today: today);
      final page = lessonPageOf(19, index, grammar, const []);
      expect(page.title, isNull);
      expect(page.grammarIds, isEmpty);
      expect(page.wordIds, isEmpty);
      expect(page.counts.total, 0);
    });
  });

  group('the lesson page', () {
    testWidgets(
        'shows its title, its counts, its grammar with n of 4 and its words with state',
        (tester) async {
      final store = JpStoreMemory();
      final g = grammarOf(30);
      final w = wordsOf(30);
      await record(store, answer(g.first, today - 2, Grade.clear));
      await store.appendSeed(w.first.id, today, atUtc: at(today - 1).toUtc());
      await pumpLesson(tester, store, 30);

      expect(shows('第30課'), isTrue);
      expect(shows(grammarTitle(30)), isTrue);
      final total = g.length + w.length;
      expect(shows('0 mastered · 1 learning · ${total - 1} new'), isTrue);
      expect(find.textContaining('%'), findsNothing);
      expect(shows(kGrammarHeading), isTrue);
      expect(shows(kWordsHeading), isTrue);
      expect(shows(kNoWordSheetLine), isFalse);
      for (final i in [...g, ...w]) {
        expect(find.byKey(ValueKey('item-${i.id}')), findsOneWidget,
            reason: i.id);
      }
      final row = find.byKey(ValueKey('item-${g.first.id}'));
      expect(find.descendant(of: row, matching: find.text('1 of 4 clears')),
          findsOneWidget);
      final due = (await store.srs(g.first.id))!.dueDay;
      expect(
          find.descendant(
              of: row,
              matching: find.text('Next review: ${dueLabel(due, today)}')),
          findsOneWidget);
      final word = find.byKey(ValueKey('item-${w.first.id}'));
      expect(find.descendant(of: word, matching: find.text('0 of 4 clears')),
          findsOneWidget);
      expect(
          find.descendant(of: word, matching: find.text('Next review: today')),
          findsOneWidget);
      expect(shows(dueTodayLine(1)), isTrue);
      expect(find.text(kReviewThese), findsOneWidget,
          reason: 'one loud action');
      expect(shows(kReadWholeLesson), isTrue);
    });

    testWidgets('a lesson with no word sheet says so plainly', (tester) async {
      await pumpLesson(tester, JpStoreMemory(), 31);
      expect(shows('第31課'), isTrue);
      expect(shows(kNoWordSheetLine), isTrue);
      for (final i in grammarOf(31)) {
        expect(find.byKey(ValueKey('item-${i.id}')), findsOneWidget,
            reason: i.id);
      }
      expect(shows('0 mastered · ${grammarOf(31).length} new'), isTrue);
    });

    testWidgets('shows the Say-it counts, which never count toward mastered',
        (tester) async {
      final store = JpStoreMemory();
      final g = grammarOf(30).first;
      final ex = g.probes.firstWhere((p) => p.template == kSayItTemplate);
      await store.appendAttempt(
          answer(g, today - 1, Grade.clear, source: Source.sayIt, probe: ex));
      await store.appendAttempt(
          answer(g, today - 1, Grade.wrong, source: Source.sayIt, probe: ex));
      await pumpLesson(tester, store, 30);
      expect(shows(sayItLine(2, 1)), isTrue);
      expect(shows(kSayItNeverCounts), isTrue);
      expect(sayItLine(1, 0), 'Say it: 1 try · 0 clear');
    });

    testWidgets(
        'Review these runs the session over the due items only, each as a review',
        (tester) async {
      final store = JpStoreMemory();
      final g = grammarOf(30);
      final w = wordsOf(30);
      await store.appendSeed(g[1].id, today, atUtc: at(today - 1).toUtc());
      await store.appendSeed(w[2].id, today - 1, atUtc: at(today - 2).toUtc());
      await store.appendSeed(w[3].id, today + 2, atUtc: at(today - 1).toUtc());
      await pumpLesson(tester, store, 30);

      expect(shows(dueTodayLine(2)), isTrue);
      await tapText(tester, kReviewThese);
      expect(shows('Practice · 1 of 2'), isTrue);
      expect(shows('probe ${w[2].id}'), isTrue,
          reason: 'the soonest due first');
      await tapText(tester, 'answer clear');
      final first = (await store.attempts(itemId: w[2].id)).single;
      expect(first.source, Source.review);
      expect(first.wasDue, isTrue);
      await tapText(tester, 'Next');

      expect(shows('probe ${g[1].id}'), isTrue);
      await tapText(tester, 'answer clear');
      expect(
          (await store.attempts(itemId: g[1].id)).single.source, Source.review);
      await tapText(tester, 'Done');

      expect(await store.attempts(itemId: w[3].id), isEmpty,
          reason: 'an item not yet due is not asked');
      expect(await store.day(today), isNull,
          reason: 'the lesson review never moves the day\'s session record');
      // Back on the page, which reads the record again: nothing is due now.
      expect(shows(kNothingDueLine), isTrue);
      final button = tester.widget<FilledButton>(find.ancestor(
          of: find.text(kReviewThese), matching: find.byType(FilledButton)));
      expect(button.onPressed, isNull);
    });

    testWidgets('Review these is off when nothing in the lesson is due',
        (tester) async {
      await pumpLesson(tester, JpStoreMemory(), 30);
      expect(shows(kNothingDueLine), isTrue);
      final button = tester.widget<FilledButton>(find.ancestor(
          of: find.text(kReviewThese), matching: find.byType(FilledButton)));
      expect(button.onPressed, isNull);
    });

    testWidgets('Read the whole lesson opens the grammar screen on the lesson',
        (tester) async {
      debugSetSharedJpStore(JpStoreMemory());
      addTearDown(() => debugSetSharedJpStore(null));
      await pumpLesson(tester, JpStoreMemory(), 30);
      await tapText(tester, kReadWholeLesson);
      expect(
          find.byWidgetPredicate(
              (w) => w is QuietRoomGrammarWidget && w.initialLesson == 30,
              skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('a lesson with no grammar has no Read the whole lesson',
        (tester) async {
      await pumpLesson(tester, JpStoreMemory(), 5);
      expect(shows('第5課'), isTrue);
      expect(shows(kReadWholeLesson), isFalse);
      expect(shows(kGrammarHeading), isFalse);
      for (final i in wordsOf(5)) {
        expect(find.byKey(ValueKey('item-${i.id}')), findsOneWidget,
            reason: i.id);
      }
    });

    testWidgets(
        'a lesson with words shows Word cards, which opens the word-card screen '
        'on the lesson (ASK-12)', (tester) async {
      await pumpLesson(tester, JpStoreMemory(), 30);
      expect(shows(kWordCards), isTrue);
      await tapText(tester, kWordCards);
      expect(
          find.byWidgetPredicate(
              (w) => w is QuietRoomLessonWidget && w.initialLesson == 30,
              skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('a words-only lesson shows Word cards too', (tester) async {
      await pumpLesson(tester, JpStoreMemory(), 5);
      expect(shows(kWordCards), isTrue);
    });

    testWidgets('a lesson with no words has no Word cards (ASK-12)',
        (tester) async {
      await pumpLesson(tester, JpStoreMemory(), 31);
      expect(shows(kNoWordSheetLine), isTrue);
      expect(shows(kWordCards), isFalse);
    });

    testWidgets('an item row opens the item page', (tester) async {
      await pumpLesson(tester, JpStoreMemory(), 30);
      final f = find.byKey(ValueKey('item-${grammarOf(30).first.id}'));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle(tester);
      expect(find.byType(ItemDetailWidget), findsOneWidget);
    });
  });

  testWidgets(
      'under the app router Read the whole lesson pushes the grammar route with the lesson',
      (tester) async {
    // No injected store: the page uses the shared one, so it opens the screen by route name.
    debugSetSharedJpStore(JpStoreMemory());
    addTearDown(() => debugSetSharedJpStore(null));
    bigView(tester);
    String? pushed;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => LessonPageWidget(
          lesson: 30,
          catalog: catalog,
          grammar: grammar,
          clock: FixedClock(at(today)),
          probeBuilder: fakeProbe,
        ),
      ),
      GoRoute(
        name: QuietRoomGrammarWidget.routeName,
        path: QuietRoomGrammarWidget.routePath,
        builder: (_, state) {
          pushed = state.uri.queryParameters['lesson'];
          return const Text('the grammar screen');
        },
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await settle(tester);

    await tapText(tester, kReadWholeLesson);
    expect(find.text('the grammar screen'), findsOneWidget);
    expect(pushed, '30');
  });

  testWidgets(
      'under the app router Word cards pushes the word-card route with the lesson',
      (tester) async {
    debugSetSharedJpStore(JpStoreMemory());
    addTearDown(() => debugSetSharedJpStore(null));
    bigView(tester);
    String? pushed;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => LessonPageWidget(
          lesson: 30,
          catalog: catalog,
          grammar: grammar,
          clock: FixedClock(at(today)),
          probeBuilder: fakeProbe,
        ),
      ),
      GoRoute(
        name: QuietRoomLessonWidget.routeName,
        path: QuietRoomLessonWidget.routePath,
        builder: (_, state) {
          pushed = state.uri.queryParameters['lesson'];
          return const Text('the word cards');
        },
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await settle(tester);

    await tapText(tester, kWordCards);
    expect(find.text('the word cards'), findsOneWidget);
    expect(pushed, '30');
  });

  group('a particle opened from a card (plan 2026-11-06, Task 1, PIN-5)', () {
    List<Map<String, dynamic>> particlesTaught() => [
          for (final p
              in (grammar['particles'] as List).cast<Map<String, dynamic>>())
            if (catalog.byId(p['id'] as String)?.lesson != null) p
        ];

    Widget atParticle(Map<String, dynamic> p, {bool fromCard = true}) =>
        LessonPageWidget(
          lesson: catalog.byId(p['id'] as String)!.lesson!,
          particleId: p['id'] as String,
          fromCard: fromCard,
          store: JpStoreMemory(),
          catalog: catalog,
          grammar: grammar,
          clock: FixedClock(at(today)),
          probeBuilder: fakeProbe,
        );

    test('the shipped particles include ones a Mari lesson teaches', () {
      expect(particlesTaught(), isNotEmpty);
    });

    testWidgets(
        'the lesson page opens with the particle block on top, and never its '
        'example or cloze sentence (End state 2)', (tester) async {
      for (final p in particlesTaught()) {
        bigView(tester);
        await tester.pumpWidget(MaterialApp(home: atParticle(p)));
        await settle(tester);

        final id = p['id'] as String;
        final block = find.byKey(const ValueKey('particle-block'));
        expect(block, findsOneWidget, reason: id);
        expect(
            find.descendant(
                of: block, matching: find.text(p['expression'] as String)),
            findsOneWidget);
        expect(
            find.descendant(
                of: block, matching: find.text(p['meaning'] as String)),
            findsOneWidget);
        // On top: over the lesson title.
        final title = find.text('第${catalog.byId(id)!.lesson}課');
        expect(
            tester.getTopLeft(block).dy, lessThan(tester.getTopLeft(title).dy));
        final cloze = p['cloze'] as Map<String, dynamic>;
        for (final hidden in [
          p['example'] as String,
          p['example_en'] as String,
          (cloze['prompt'] as String).split('＿＿').first,
        ]) {
          expect(find.textContaining(hidden), findsNothing,
              reason: '$id shows "$hidden"');
        }
        expect(find.text(kBackToPractice), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the plain entry shows no particle block and no bar',
        (tester) async {
      await pumpLesson(tester, JpStoreMemory(), 39);
      expect(find.byKey(const ValueKey('particle-block')), findsNothing);
      expect(find.text(kBackToPractice), findsNothing);
    });

    testWidgets('an unknown particle says so instead of an empty page',
        (tester) async {
      bigView(tester);
      await tester.pumpWidget(MaterialApp(
          home: LessonPageWidget(
        lesson: 39,
        particleId: 'mari.particle.999',
        fromCard: true,
        store: JpStoreMemory(),
        catalog: catalog,
        grammar: grammar,
        clock: FixedClock(at(today)),
        probeBuilder: fakeProbe,
      )));
      await settle(tester);
      expect(find.textContaining('Could not open the lesson'), findsOneWidget);
      expect(
          find.textContaining('no particle mari.particle.999'), findsOneWidget);
      expect(find.byKey(const ValueKey('particle-block')), findsNothing);
    });

    testWidgets('Back to practice returns to the card', (tester) async {
      bigView(tester);
      final p = particlesTaught().first;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => atParticle(p))),
                        child: const Text('the card')),
                  ))));
      await tester.tap(find.text('the card'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);

      await tester.tap(find.text(kBackToPractice));
      await tester.pumpAndSettle();
      expect(find.byType(LessonPageWidget), findsNothing);
      expect(find.text('the card'), findsOneWidget);
    });
  });

  group('lessonTargetOf (D20)', () {
    ItemDef first(ItemKind kind, [bool Function(ItemDef)? where]) =>
        catalog.ofKind(kind).firstWhere(where ?? (_) => true);

    test('names the screen and query each kind opens at', () {
      final point = first(ItemKind.grammar);
      expect(lessonTargetOf(point).routeName, QuietRoomGrammarWidget.routeName);
      expect(lessonTargetOf(point).query, {'point': point.id, 'from': 'card'});

      final word = first(ItemKind.word);
      expect(lessonTargetOf(word).routeName, QuietRoomLessonWidget.routeName);
      expect(lessonTargetOf(word).query, {'word': word.id, 'from': 'card'});

      final conj = catalog.byId('conj.causative_passive.g1')!;
      expect(lessonTargetOf(conj).routeName, QuietRoomDrillsWidget.routeName);
      expect(lessonTargetOf(conj).query,
          {'mode': 'conjugation', 'form': 'causative_passive', 'from': 'card'});

      final pair = first(ItemKind.pair);
      expect(lessonTargetOf(pair).routeName, QuietRoomDrillsWidget.routeName);
      expect(lessonTargetOf(pair).query,
          {'mode': 'pairs', 'pair': pair.id, 'from': 'card'});

      final row = catalog.byId('ref.dates.31')!;
      expect(lessonTargetOf(row).routeName, QuietRoomDrillsWidget.routeName);
      expect(lessonTargetOf(row).query,
          {'mode': 'reference', 'table': 'dates', 'row': '31', 'from': 'card'});

      final taught = first(ItemKind.particle, (i) => i.lesson != null);
      expect(lessonTargetOf(taught).routeName, LessonPageWidget.routeName);
      expect(lessonTargetOf(taught).query, {
        'lesson': '${taught.lesson}',
        'particle': taught.id,
        'from': 'card'
      });

      final untaught = first(ItemKind.particle, (i) => i.lesson == null);
      expect(lessonTargetOf(untaught).routeName, TopicPageWidget.routeName);
      expect(lessonTargetOf(untaught).query,
          {'particle': untaught.id, 'from': 'card'});
    });

    test('every table row id splits into a table and a row of the asset', () {
      final tables = {
        for (final t
            in (grammar['reference'] as List).cast<Map<String, dynamic>>())
          t['id'] as String: (t['rows'] as List).cast<String>()
      };
      for (final r in catalog.ofKind(ItemKind.tableRow)) {
        final q = lessonTargetOf(r).query;
        expect(tables[q['table']], contains(q['row']), reason: r.id);
      }
    });

    // The two receivers below read their key from the asset lists the drills screen
    // itself reads, so an id the catalog mints that the screen cannot open fails here.
    test('every conjugation id names a form the conjugation drill offers', () {
      final forms = (grammar['conjugation']['forms'] as List).cast<String>();
      for (final c in catalog.ofKind(ItemKind.conjugation)) {
        expect(forms, contains(lessonTargetOf(c).query['form']), reason: c.id);
      }
    });

    test('every pair id is one the pairs drill lists', () {
      final ids = pairItemIds(grammar);
      for (final p in catalog.ofKind(ItemKind.pair)) {
        expect(ids, contains(lessonTargetOf(p).query['pair']), reason: p.id);
      }
    });
  });
}
