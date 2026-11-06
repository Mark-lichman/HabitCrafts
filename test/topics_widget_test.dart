// Tests for the Topics screen and the topic page (plan 2026-11-02, Task 23, End state 9).
//
// Both screens read a `TopicIndex` over the shipped catalog and a memory store, with an injected
// clock. The cases: the Topics tab has one search box and the browse sets; a search result row
// shows the item's state pill and its next review; a browse set lists its topics with counts by
// state and a pill; a topic page shows its counts, its items with state and next due, Related
// topics, and one loud Practice this topic; Practice this topic asks the due items first and
// writes early answers per PIN-14 (a clear changes nothing, a wrong counts); a row opens the
// item page; a query past kSearchMax ends with a line that says the list is cut; the app
// router resolves the Topics, topic page and item page routes by name with their query keys;
// and under a router a topic row pushes the topic route with its id. A fake probe builder
// stands in for the probe widgets, as in item_detail_test.dart.
//
// Plan 2026-11-06, Task 1: a particle that no Mari lesson teaches opens its topic page with
// the particle block on top and never its example or cloze sentence (PIN-5, End state 2), and
// the app router reads every lesson screen's new query keys.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/auth/base_auth_user_provider.dart';
import 'package:habit_craft/backend/push_notifications/push_notifications_handler.dart';
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
import 'package:habit_craft/components/pages/quiet_room_mastery/lesson_page_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_sqlite.dart'
    show debugSetSharedJpStore;
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_debug_widget.dart'
    show dueLabel;
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/topic_index.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/topic_page_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/topics_widget.dart';
import 'package:habit_craft/flutter_flow/nav/nav.dart';

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
    {Source source = Source.review, bool wasDue = true}) {
  final p = item.scoredProbes.first;
  return Attempt(
    itemId: item.id,
    probeId: p.id,
    template: p.template,
    production: p.production,
    selfGraded: p.selfGraded,
    atUtc: at(day).toUtc(),
    localDay: day,
    grade: grade,
    rating: fsrsRatingFor(grade),
    hintLevel: grade == Grade.hinted ? 1 : 0,
    wasDue: wasDue,
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

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  expect(f, findsOneWidget, reason: 'a "$key" row');
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

void bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpTopics(WidgetTester tester, JpStore store) async {
  bigView(tester);
  await tester.pumpWidget(MaterialApp(
    home: QuietRoomTopicsWidget(
      store: store,
      catalog: catalog,
      grammar: grammar,
      clock: FixedClock(at(today)),
      probeBuilder: fakeProbe,
    ),
  ));
  await settle(tester);
}

Future<void> pumpTopic(WidgetTester tester, JpStore store, String id) async {
  bigView(tester);
  await tester.pumpWidget(MaterialApp(
    home: TopicPageWidget(
      topicId: id,
      store: store,
      catalog: catalog,
      grammar: grammar,
      clock: FixedClock(at(today)),
      probeBuilder: fakeProbe,
    ),
  ));
  await settle(tester);
}

bool shows(String text) => find.text(text).evaluate().isNotEmpty;

/// The three ideas of the て form, the second one due today by its seed.
const teIds = ['conj.te.g1', 'conj.te.g2', 'conj.te.g3'];

void main() {
  setUpAll(holdHttpRequests);

  group('the Topics tab', () {
    testWidgets('has one search box and the browse sets, By use first',
        (tester) async {
      await pumpTopics(tester, JpStoreMemory());
      expect(find.byType(TextField), findsOneWidget);
      for (final s in BrowseSet.values) {
        expect(shows(browseSetLabel(s)), isTrue, reason: browseSetLabel(s));
      }
      // By use is open: every use is a row with its counts and pill.
      final index =
          TopicIndex(catalog: catalog, grammar: grammar, today: today);
      final uses = index.browse(BrowseSet.byUse);
      expect(uses, isNotEmpty);
      for (final u in uses) {
        expect(find.byKey(ValueKey('topic-${u.id}')), findsOneWidget,
            reason: u.id);
      }
      final condition = index.use('condition')!;
      expect(shows(condition.counts.label), isTrue);
      expect(condition.counts.label, isNot(contains('%')));
    });

    testWidgets(
        'a search result row shows the item state pill and its next review',
        (tester) async {
      final store = JpStoreMemory();
      final book = catalog.byId('L02_00')!;
      await record(store, answer(book, today - 2, Grade.clear));
      await pumpTopics(tester, store);

      await tester.enterText(find.byType(TextField), 'book');
      await settle(tester);
      final row = find.byKey(const ValueKey('item-L02_00'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('1 of 4 clears')),
          findsOneWidget);
      final due = (await store.srs(book.id))!.dueDay;
      expect(
          find.descendant(
              of: row,
              matching: find.text('Next review: ${dueLabel(due, today)}')),
          findsOneWidget);
      // The browse sets give way to the results while a query is typed.
      expect(find.byKey(const ValueKey('topic-use.condition')), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await settle(tester);
      expect(find.byKey(const ValueKey('topic-use.condition')), findsOneWidget);
    });

    testWidgets('a New result with no schedule says it is not in the queue',
        (tester) async {
      await pumpTopics(tester, JpStoreMemory());
      await tester.enterText(find.byType(TextField), 'book');
      await settle(tester);
      final row = find.byKey(const ValueKey('item-L02_00'));
      expect(find.descendant(of: row, matching: find.text('0 of 4 clears')),
          findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(kNotQueuedShort)),
          findsOneWidget);
    });

    testWidgets(
        'a query past kSearchMax lists the first kSearchMax and says so',
        (tester) async {
      // A single letter is a substring of many English glosses.
      const query = 'a';
      final index =
          TopicIndex(catalog: catalog, grammar: grammar, today: today);
      final all = index.search(query);
      expect(all.length, greaterThan(kSearchMax),
          reason: 'the query must overflow the list');
      await pumpTopics(tester, JpStoreMemory());
      await tester.enterText(find.byType(TextField), query);
      await settle(tester);
      expect(find.text(searchCutLine(all.length)), findsOneWidget);
      final rows = find.byType(TopicListRow, skipOffstage: false);
      expect(rows, findsNWidgets(kSearchMax));

      // A narrow query is whole and has no such line.
      await tester.enterText(find.byType(TextField), 'book');
      await settle(tester);
      expect(find.textContaining('Showing the first'), findsNothing);
    });

    testWidgets('a search result row opens the item page', (tester) async {
      await pumpTopics(tester, JpStoreMemory());
      await tester.enterText(find.byType(TextField), 'book');
      await settle(tester);
      await tapKey(tester, 'item-L02_00');
      await settle(tester);
      expect(find.byType(ItemDetailWidget), findsOneWidget);
      expect(shows(kPracticeNow), isTrue);
    });

    testWidgets('a browse set lists its topics; a topic opens its page',
        (tester) async {
      await pumpTopics(tester, JpStoreMemory());
      await tapText(tester, browseSetLabel(BrowseSet.verbForms));
      expect(find.byKey(const ValueKey('topic-form.te')), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-use.condition')), findsNothing);
      await tapKey(tester, 'topic-form.te');
      await settle(tester);
      expect(find.byType(TopicPageWidget), findsOneWidget);
      expect(shows(kPracticeThisTopic), isTrue);
    });

    testWidgets('a search hit on a topic opens the topic page', (tester) async {
      await pumpTopics(tester, JpStoreMemory());
      await tester.enterText(find.byType(TextField), 'て form');
      await settle(tester);
      await tapKey(tester, 'topic-form.te');
      await settle(tester);
      expect(find.byType(TopicPageWidget), findsOneWidget);
    });

    testWidgets('Shaky is a record set with its own page', (tester) async {
      final store = JpStoreMemory();
      await pumpTopics(tester, store);
      await tapText(tester, browseSetLabel(BrowseSet.shaky));
      await tapKey(tester, 'topic-shaky');
      await settle(tester);
      expect(find.byType(TopicPageWidget), findsOneWidget);
      expect(shows(kEmptyTopicLine), isTrue);
    });
  });

  group('the topic page', () {
    testWidgets(
        'shows its counts, its items with state and next due, and Related topics',
        (tester) async {
      final store = JpStoreMemory();
      final g1 = catalog.byId(teIds[0])!;
      await record(store, answer(g1, today - 2, Grade.clear));
      await store.appendSeed(teIds[1], today, atUtc: at(today - 1).toUtc());
      await pumpTopic(tester, store, 'form.te');

      // 1 learning, 2 new, never a percentage.
      expect(shows('0 of 3 mastered · 1 learning · 2 new'), isTrue);
      expect(find.textContaining('%'), findsNothing);
      for (final id in teIds) {
        expect(find.byKey(ValueKey('item-$id')), findsOneWidget, reason: id);
      }
      final row1 = find.byKey(ValueKey('item-${teIds[0]}'));
      expect(find.descendant(of: row1, matching: find.text('1 of 4 clears')),
          findsOneWidget);
      final due1 = (await store.srs(teIds[0]))!.dueDay;
      expect(
          find.descendant(
              of: row1,
              matching: find.text('Next review: ${dueLabel(due1, today)}')),
          findsOneWidget);
      final row2 = find.byKey(ValueKey('item-${teIds[1]}'));
      expect(
          find.descendant(of: row2, matching: find.text('Next review: today')),
          findsOneWidget);

      expect(shows(kRelatedTopics), isTrue);
      expect(find.byKey(const ValueKey('related-group.1')), findsOneWidget);
      expect(find.byKey(const ValueKey('related-form.te')), findsNothing,
          reason: 'a topic is not related to itself');
      expect(find.text(kPracticeThisTopic), findsOneWidget,
          reason: 'one loud action');
    });

    testWidgets('a related topic opens its own page', (tester) async {
      await pumpTopic(tester, JpStoreMemory(), 'form.te');
      await tapKey(tester, 'related-group.1');
      await settle(tester);
      expect(shows('Group 1 verbs'), isTrue);
      // The row's title alone would show on the form.te page too: the pushed page is the proof.
      expect(
          find.byWidgetPredicate(
              (w) => w is TopicPageWidget && w.topicId == 'group.1',
              skipOffstage: false),
          findsOneWidget);
    });

    testWidgets('an item row opens the item page', (tester) async {
      await pumpTopic(tester, JpStoreMemory(), 'form.te');
      await tapKey(tester, 'item-${teIds[0]}');
      await settle(tester);
      expect(find.byType(ItemDetailWidget), findsOneWidget);
    });

    testWidgets('an unknown topic id says so instead of an empty page',
        (tester) async {
      await pumpTopic(tester, JpStoreMemory(), 'use.nope');
      expect(find.textContaining('Could not open the topic'), findsOneWidget);
    });
  });

  group('Practice this topic (PIN-14)', () {
    test('asks the due items first, soonest first, then the rest in order', () {
      final index = TopicIndex(
        catalog: catalog,
        grammar: grammar,
        today: today,
        seedDue: {teIds[2]: today - 1, teIds[1]: today, teIds[0]: today + 4},
      );
      expect(practiceOrder(index, index.byId('form.te')!),
          [teIds[2], teIds[1], teIds[0]]);
      final none = TopicIndex(catalog: catalog, grammar: grammar, today: today);
      expect(practiceOrder(none, none.byId('form.te')!), teIds);
    });

    test('topicOf resolves the record sets due, shaky and notYet by id', () {
      final index = TopicIndex(
        catalog: catalog,
        grammar: grammar,
        today: today,
        seedDue: {teIds[1]: today},
      );
      expect(topicOf(index, 'due')!.itemIds, [teIds[1]]);
      final notYet = topicOf(index, 'notYet')!.itemIds;
      expect(notYet, contains(teIds[0]));
      expect(notYet, isNot(contains(teIds[1])));
      expect(topicOf(index, 'shaky')!.itemIds, isEmpty);
      expect(topicOf(index, 'use.nope'), isNull);
      // Every id the browse sets hand out resolves back to that topic, so a record-set id in
      // topicOf cannot drift from the one browse() mints.
      for (final set in BrowseSet.values) {
        for (final topic in index.browse(set)) {
          expect(topicOf(index, topic.id)?.id, topic.id,
              reason: '${browseSetLabel(set)} minted ${topic.id}');
        }
      }
    });

    testWidgets(
        'runs the session over the items, due first: a due clear is a review, an early clear '
        'changes nothing, an early wrong counts', (tester) async {
      final store = JpStoreMemory();
      final g1 = catalog.byId(teIds[0])!;
      await record(store, answer(g1, today - 1, Grade.clear));
      final srs1 = await store.srs(g1.id);
      final mastery1 = await store.mastery(g1.id);
      expect(srs1!.dueDay, greaterThan(today));
      await store.appendSeed(teIds[1], today, atUtc: at(today - 1).toUtc());
      await pumpTopic(tester, store, 'form.te');

      await tapText(tester, kPracticeThisTopic);
      expect(shows('Practice · 1 of 3'), isTrue);
      expect(shows('probe ${teIds[1]}'), isTrue, reason: 'the due item first');
      await tapText(tester, 'answer clear');
      final due = (await store.attempts(itemId: teIds[1])).single;
      expect(due.source, Source.review);
      expect(due.wasDue, isTrue);
      await tapText(tester, 'Next');

      expect(shows('probe ${teIds[0]}'), isTrue);
      await tapText(tester, 'answer clear');
      expect(shows(kEarlyNoChange), isTrue);
      final early = (await store.attempts(itemId: g1.id)).last;
      expect(early.source, Source.early);
      expect(await store.srs(g1.id), srs1);
      expect(await store.mastery(g1.id), mastery1);
      await tapText(tester, 'Next');

      expect(shows('probe ${teIds[2]}'), isTrue);
      await tapText(tester, 'answer wrong');
      final wrong = (await store.attempts(itemId: teIds[2])).single;
      expect(wrong.source, Source.early);
      expect(wrong.grade, Grade.wrong);
      expect((await store.srs(teIds[2]))!.dueDay, today + 1,
          reason: 'an early wrong counts: due tomorrow');
      expect(await store.day(today), isNull,
          reason: 'practice never touches the day\'s session record');
      await tapText(tester, 'Next');
      await tapText(tester, 'Done');

      // Back on the topic page, which reads the record again.
      expect(shows(kPracticeThisTopic), isTrue);
      final row3 = find.byKey(ValueKey('item-${teIds[2]}'));
      expect(
          find.descendant(
              of: row3, matching: find.text('Next review: tomorrow')),
          findsOneWidget);
    });

    testWidgets('a topic with no items has no practice to run', (tester) async {
      await pumpTopic(tester, JpStoreMemory(), 'shaky');
      final button = tester.widget<FilledButton>(find.ancestor(
          of: find.text(kPracticeThisTopic),
          matching: find.byType(FilledButton)));
      expect(button.onPressed, isNull);
    });
  });

  test('nav.dart registers the Topics, topic page and item page routes', () {
    final router = createRouter(AppStateNotifier.instance);
    addTearDown(router.dispose);
    expect(router.namedLocation(QuietRoomTopicsWidget.routeName),
        '/quietRoomTopics');
    expect(
        router.namedLocation(TopicPageWidget.routeName,
            queryParameters: {'topic': 'form.te'}),
        '/quietRoomTopic?topic=form.te');
    expect(
        router.namedLocation(ItemDetailWidget.routeName,
            queryParameters: {'item': 'L02_00'}),
        '/quietRoomItem?item=L02_00');
    expect(QuietRoomTopicsWidget.routePath, '/quietRoomTopics');
    expect(TopicPageWidget.routePath, '/quietRoomTopic');
    expect(ItemDetailWidget.routePath, '/quietRoomItem');
  });

  testWidgets(
      'under the app router a topic row pushes the topic route with its id',
      (tester) async {
    // No injected store: the screen uses the shared one, so the row opens by route name.
    debugSetSharedJpStore(JpStoreMemory());
    addTearDown(() => debugSetSharedJpStore(null));
    bigView(tester);
    String? pushed;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => QuietRoomTopicsWidget(
          catalog: catalog,
          grammar: grammar,
          clock: FixedClock(at(today)),
          probeBuilder: fakeProbe,
        ),
      ),
      GoRoute(
        name: TopicPageWidget.routeName,
        path: TopicPageWidget.routePath,
        builder: (_, state) {
          pushed = state.uri.queryParameters['topic'];
          return const Text('the topic page');
        },
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await settle(tester);

    await tapKey(tester, 'topic-use.condition');
    await settle(tester);
    expect(find.text('the topic page'), findsOneWidget);
    expect(pushed, 'use.condition');
  });

  group(
      'a particle with no lesson opened from a card (plan 2026-11-06, Task 1)',
      () {
    List<Map<String, dynamic>> particlesUntaught() => [
          for (final p
              in (grammar['particles'] as List).cast<Map<String, dynamic>>())
            if (catalog.byId(p['id'] as String) != null &&
                catalog.byId(p['id'] as String)!.lesson == null)
              p
        ];

    Future<void> pumpAtParticle(WidgetTester tester, String id,
        {bool fromCard = true}) async {
      bigView(tester);
      await tester.pumpWidget(MaterialApp(
        home: TopicPageWidget(
          topicId: '',
          particleId: id,
          fromCard: fromCard,
          store: JpStoreMemory(),
          catalog: catalog,
          grammar: grammar,
          clock: FixedClock(at(today)),
          probeBuilder: fakeProbe,
        ),
      ));
      await settle(tester);
    }

    test('the shipped particles include ones no Mari lesson teaches', () {
      expect(particlesUntaught(), isNotEmpty);
    });

    testWidgets(
        'the topic page opens on the particle with its block on top, and never '
        'its example or cloze sentence (End state 2)', (tester) async {
      final index = await TopicIndex.load(
          store: JpStoreMemory(),
          catalog: catalog,
          grammar: grammar,
          today: today);
      for (final p in particlesUntaught()) {
        final id = p['id'] as String;
        await pumpAtParticle(tester, id);

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
        // The particle's own first topic, under the block.
        final topic = index.topicsOf(id).first;
        final title = find.text(topic.title);
        expect(title, findsOneWidget, reason: id);
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
      await pumpTopic(tester, JpStoreMemory(), 'use.manner');
      expect(find.byKey(const ValueKey('particle-block')), findsNothing);
      expect(find.text(kBackToPractice), findsNothing);
    });

    testWidgets('an unknown particle says so instead of an empty page',
        (tester) async {
      await pumpAtParticle(tester, 'mari.particle.999');
      expect(find.textContaining('Could not open the topic'), findsOneWidget);
      // The particle guard, not the later 'no topic' guard with the same prefix.
      expect(
          find.textContaining('no particle mari.particle.999'), findsOneWidget);
    });
  });

  testWidgets(
      'nav.dart reads each lesson screen\'s new keys: point, word, pair, row, '
      'particle and from (plan 2026-11-06, Task 1)', (tester) async {
    final router = createRouter(AppStateNotifier.instance);
    addTearDown(router.dispose);
    final app = AppStateNotifier.instance;
    app.user = _SignedOut();
    app.showSplashImage = false;
    addTearDown(() {
      app.user = null;
      app.showSplashImage = true;
    });
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    /// The screen the app router builds for [location].
    Widget built(String location) {
      final list = router.configuration.findMatch(location);
      expect(list.error, isNull, reason: location);
      final m = list.matches.single;
      final state = router.routerDelegate.builder.buildState(list, m);
      final context = tester.element(find.byType(SizedBox));
      final page = (m.route as GoRoute).pageBuilder!(context, state);
      final child = page is MaterialPage
          ? page.child
          : (page as CustomTransitionPage).child;
      return (child as PushNotificationsHandler).child;
    }

    final grammarAt =
        built('${QuietRoomGrammarWidget.routePath}?point=mari.L31.3&from=card')
            as QuietRoomGrammarWidget;
    expect(grammarAt.initialPoint, 'mari.L31.3');
    expect(grammarAt.fromCard, isTrue);
    final grammarPlain = built('${QuietRoomGrammarWidget.routePath}?lesson=31')
        as QuietRoomGrammarWidget;
    expect(grammarPlain.initialPoint, isNull);
    expect(grammarPlain.fromCard, isFalse);
    expect(grammarPlain.initialLesson, 31);

    final words =
        built('${QuietRoomLessonWidget.routePath}?word=L30_02&from=card')
            as QuietRoomLessonWidget;
    expect(words.initialWord, 'L30_02');
    expect(words.fromCard, isTrue);
    expect(
        (built(QuietRoomLessonWidget.routePath) as QuietRoomLessonWidget)
            .fromCard,
        isFalse);

    final pairs = built(
            '${QuietRoomDrillsWidget.routePath}?mode=pairs&pair=s02_pairs_mari.1.1&from=card')
        as QuietRoomDrillsWidget;
    expect(pairs.mode, 'pairs');
    expect(pairs.pair, 's02_pairs_mari.1.1');
    expect(pairs.fromCard, isTrue);
    final row = built(
            '${QuietRoomDrillsWidget.routePath}?mode=reference&table=dates&row=31')
        as QuietRoomDrillsWidget;
    expect(row.table, 'dates');
    expect(row.row, '31');
    expect(row.fromCard, isFalse);
    final form = built(
            '${QuietRoomDrillsWidget.routePath}?mode=conjugation&form=te&from=card')
        as QuietRoomDrillsWidget;
    expect(form.form, 'te');
    expect(form.fromCard, isTrue);

    final lessonPage = built(
            '${LessonPageWidget.routePath}?lesson=39&particle=mari.particle.14&from=card')
        as LessonPageWidget;
    expect(lessonPage.lesson, 39);
    expect(lessonPage.particleId, 'mari.particle.14');
    expect(lessonPage.fromCard, isTrue);

    final topic =
        built('${TopicPageWidget.routePath}?particle=mari.particle.1&from=card')
            as TopicPageWidget;
    expect(topic.topicId, '');
    expect(topic.particleId, 'mari.particle.1');
    expect(topic.fromCard, isTrue);
    final topicPlain =
        built('${TopicPageWidget.routePath}?topic=form.te') as TopicPageWidget;
    expect(topicPlain.particleId, isNull);
    expect(topicPlain.fromCard, isFalse);
  });
}

/// Nobody signed in, with the app's splash off: `createRouter` then builds each route's own
/// screen instead of the splash image (as in quiet_room_japanese_test.dart).
class _SignedOut extends BaseAuthUser {
  @override
  bool get loggedIn => false;
  @override
  bool get emailVerified => false;
  @override
  AuthUserInfo get authUserInfo => const AuthUserInfo();
  @override
  Future? delete() => null;
  @override
  Future? updateEmail(String email) => null;
  @override
  Future? updatePassword(String password) => null;
  @override
  Future? sendEmailVerification() => null;
}
