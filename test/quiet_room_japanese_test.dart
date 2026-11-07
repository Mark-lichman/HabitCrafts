// Widget tests for the Japanese home, which is Today (plan 2026-11-02, Task 27, D20, End
// state 14): the launch it resolves before it builds (the seed confirmation on a first launch,
// the session card on today, resume and done), the launch it resolves again when a warm app
// meets a new local day, the session card's section counts read from a memory store, the
// mastered count, the kept rate and the 14 dots, the quiet links, the bottom nav of Today,
// Lessons and Topics (a tab tap under the router is a `go` on the route the home is on, so
// the State and a dismissed Welcome back survive it, a tap on the errorBuilder home lands on
// `/`, and nav.dart's `/` route reads the tab like the named one), and the absence of the
// old hub's hero, rows, number strip, search and use strip (search and By use live in
// Topics, topics_widget_test.dart).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:habit_craft/components/pages/quiet_room_grammar/jp_study_kit.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_drills_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_grammar/quiet_room_japanese_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/lessons_path_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/plan_builder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/relaunch.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/seed_confirm_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/study_export.dart'
    show kV2CanUseIt, kV2SelfCheckPrefix;
import 'package:habit_craft/components/pages/quiet_room_mastery/topics_widget.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/welcome_back_widget.dart';
import 'package:habit_craft/auth/base_auth_user_provider.dart';
import 'package:habit_craft/backend/push_notifications/push_notifications_handler.dart';
import 'package:habit_craft/flutter_flow/nav/nav.dart';

import 'jp_screen_harness.dart';

/// Nobody signed in, with the app's splash off: `createRouter` then builds the signed-out
/// home for a route instead of the splash image.
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

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));

const int day0 = 300;

/// 10:00 local on [day].
DateTime at(int day) => dayStart(day).add(const Duration(hours: 6));

/// A store whose first-launch seed ran on [day0]. [into] is the store to seed, else a new one.
Future<JpStoreMemory> seededStore({JpStoreMemory? into}) async {
  final store = into ?? JpStoreMemory();
  await seedFromLessons(day0, store, catalog, nowUtc: at(day0).toUtc());
  return store;
}

/// A memory store that counts its day-record reads: every launch resolution reads today's
/// record first, so the count tells whether the hub resolved the launch again.
class DayReadsStore extends JpStoreMemory {
  int dayReads = 0;

  @override
  Future<DayRecord?> day(int day) {
    dayReads++;
    return super.day(day);
  }
}

/// Pumps the hub on [store] at [day], and lets the launch resolve. A test that moves the day
/// under the warm hub passes its own [clock] and sets it later.
Future<void> pumpHub(WidgetTester tester, JpStore store,
    {int day = day0,
    Map<String, Object> prefs = const {},
    FixedClock? clock}) async {
  await pumpStudyScreen(
      tester,
      QuietRoomJapaneseWidget(
          store: store, catalog: catalog, clock: clock ?? FixedClock(at(day))),
      prefs: prefs);
  await settle(tester);
}

/// Sends one lifecycle event to the app, as the OS would, and lets the hub react.
Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
  tester.binding.handleAppLifecycleStateChanged(state);
  await settle(tester);
}

/// A store whose [day0] session is finished. [into] is the store to build it in.
Future<JpStoreMemory> doneStore({JpStoreMemory? into}) async {
  final store = await seededStore(into: into);
  final launch = await onLaunch(at(day0), store, catalog);
  await store.putDay(launch.record!.copyWith(position: 5, completed: true));
  return store;
}

/// Lets the store's futures and the asset loads finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Finder seedPill(String kind, int lesson) =>
    find.byKey(ValueKey('seed-$kind-$lesson'));

bool pillOn(WidgetTester tester, String kind, int lesson) =>
    tester.widget<QrPill>(seedPill(kind, lesson)).on;

/// A queue entry of [section], for a hand-built plan.
Map<String, dynamic> entryJson(String id, PlanSection section) => {
      'itemId': id,
      'kind': ItemKind.word.name,
      'section': section.name,
      'costSeconds': 15,
      'wasDue': true,
    };

/// A plan with no entries, for the queue line's format.
DayPlan emptyPlan() => DayPlan(
      day: day0,
      builtAtUtc: at(day0).toUtc(),
      entries: const [],
      daysMissed: 0,
      backlogSeconds: 0,
      targetSeconds: kTargetSeconds,
      ceilingSeconds: kCeilingSeconds,
      gateSeconds: 0,
      repairSlotSeconds: kRepairSlotSeconds,
      newSkip: NewSkip.values.first,
      keepSharpRan: false,
      dueLeft: 0,
      stretchOffer: true,
      catchUpOffer: false,
    );

void main() {
  setUpAll(holdHttpRequests);

  group('launch', () {
    testWidgets(
        'first launch opens the seed confirmation with the default ticks, '
        'and nothing is written before Confirm', (tester) async {
      final store = JpStoreMemory();
      await pumpHub(tester, store);

      expect(find.text('Which lessons have you studied?'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byKey(const ValueKey('today-card')), findsNothing);

      final words = catalogLessons(catalog, ItemKind.word);
      final grammar = catalogLessons(catalog, ItemKind.grammar);
      expect(words, containsAll([2, 30]));
      expect(grammar, containsAll([26, 31, 32]));
      for (final l in words) {
        expect(pillOn(tester, 'word', l), l >= 2 && l <= 30,
            reason: 'word lesson $l');
      }
      for (final l in grammar) {
        expect(pillOn(tester, 'grammar', l), l >= 26 && l <= 31,
            reason: 'grammar lesson $l');
      }
      expect(await store.seeds(), isEmpty);
      expect(await store.meta(kSeedFlag), isNull);
      expect(await store.lastDay(), isNull);
    });

    testWidgets(
        'the last grammar lesson opened past 31 extends the grammar ticks to it',
        (tester) async {
      await pumpHub(tester, JpStoreMemory(),
          prefs: {kLastGrammarLessonKey: 33});
      expect(pillOn(tester, 'grammar', 31), isTrue);
      expect(pillOn(tester, 'grammar', 32), isTrue);
      expect(pillOn(tester, 'grammar', 33), isTrue);
      expect(pillOn(tester, 'grammar', 34), isFalse);
    });

    test('a last grammar lesson inside the range never unticks one', () {
      final words = catalogLessons(catalog, ItemKind.word).toSet();
      for (final last in [null, 20, 26, 28, 31]) {
        final ticks = defaultSeedLessons(catalog, lastGrammarLesson: last);
        expect(ticks.grammarLessons, {26, 27, 28, 29, 30, 31},
            reason: 'last $last');
        expect(ticks.wordLessons,
            {for (var l = 2; l <= 30; l++) l}.intersection(words));
      }
    });

    testWidgets(
        'Confirm seeds the ticked lessons only, imports the v2 keys, writes no '
        'attempt, and opens the hub', (tester) async {
      final store = JpStoreMemory();
      final skipped = catalog.items
          .firstWhere((i) => i.kind == ItemKind.grammar && i.lesson == 27);
      await pumpHub(tester, store,
          prefs: {'$kV2SelfCheckPrefix${skipped.id}': kV2CanUseIt});

      await tester.tap(seedPill('word', 5));
      await tester.tap(seedPill('grammar', 27));
      await tester.pump();
      expect(pillOn(tester, 'word', 5), isFalse);
      expect(pillOn(tester, 'grammar', 27), isFalse);

      await tester.tap(find.text('Confirm'));
      await settle(tester);

      final seeded = {for (final e in await store.seeds()) e.itemId};
      bool any(ItemKind kind, int lesson) => catalog.items.any(
          (i) => i.kind == kind && i.lesson == lesson && seeded.contains(i.id));
      expect(any(ItemKind.word, 5), isFalse,
          reason: 'an unticked lesson stays New');
      expect(any(ItemKind.grammar, 27), isFalse);
      expect(any(ItemKind.word, 6), isTrue);
      expect(any(ItemKind.grammar, 28), isTrue);
      // The v2 keys came in through the migration: prefs and the grammar went together.
      expect((await store.notes())[skipped.id], isNotNull);
      // PIN-7: the seed is no answer.
      expect(await store.attempts(), isEmpty);
      expect(await store.allMastery(), isEmpty);
      expect(await store.allSrs(), isEmpty);

      // Then Today, with today's plan.
      expect(find.byKey(const ValueKey('today-card')), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text(masteredLine(0)), findsOneWidget);
    });
  });

  group('Today card', () {
    testWidgets(
        'names the sections with the counts of the plan in the memory store, '
        'the minutes line and Start', (tester) async {
      final store = await seededStore();
      await pumpHub(tester, store);

      final plan = DayPlan.decode((await store.day(day0))!.plan);
      final line = todaySectionsLine(plan);
      expect(line, contains('Due '));
      final counts = plan.counts;
      for (final s in PlanSection.values) {
        final n = counts[s] ?? 0;
        if (n > 0) {
          expect(line, contains('${sectionLabel(s)} $n'), reason: s.name);
        } else {
          expect(line, isNot(contains(sectionLabel(s))), reason: s.name);
        }
      }
      final card = find.byKey(const ValueKey('today-card'));
      expect(
          find.descendant(of: card, matching: find.text(line)), findsOneWidget);
      expect(
          find.descendant(
              of: card, matching: find.text(todayMinutesLine(plan))),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Start')),
          findsOneWidget);
      expect(find.text('Resume'), findsNothing);
    });

    test('the queue line reads as the plan sections, then the stretch', () {
      var n = 0;
      List<Map<String, dynamic>> many(int count, PlanSection s) =>
          [for (var i = 0; i < count; i++) entryJson('x${n++}', s)];
      final plan = DayPlan.fromJson({
        ...emptyPlan().toJson(),
        'entries': [
          ...many(3, PlanSection.repair),
          ...many(42, PlanSection.due),
          ...many(10, PlanSection.keepSharp),
          ...many(8, PlanSection.newItems),
        ],
        'stretchEntries': many(4, PlanSection.newItems),
      });
      expect(todaySectionsLine(plan),
          'Repair 3 · Due 42 · Keep-sharp 10 · New 8 · +4 stretch');
      expect(todayMinutesLine(plan), '15 to 20 minutes');

      final noStretch =
          DayPlan.fromJson({...plan.toJson(), 'stretchOffer': false});
      expect(todaySectionsLine(noStretch),
          'Repair 3 · Due 42 · Keep-sharp 10 · New 8');

      final short = DayPlan.fromJson(
          {...plan.toJson(), 'entries': many(6, PlanSection.due)});
      expect(
          todayMinutesLine(short), 'About 2 min, under the 15-minute target');
    });

    testWidgets('a session already under way shows Resume', (tester) async {
      final store = await seededStore();
      final launch = await onLaunch(at(day0), store, catalog);
      await store.putDay(launch.record!.copyWith(position: 3));
      await pumpHub(tester, store);

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('3 of ${launch.plan!.entries.length} answered'),
          findsOneWidget);
    });

    testWidgets('a finished day shows the end state and no Start',
        (tester) async {
      await pumpHub(tester, await doneStore());

      expect(find.text('Done for today'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets("Start opens the Review session on today's plan",
        (tester) async {
      final store = await seededStore();
      await pumpHub(tester, store);

      await tester.tap(find.text('Start'));
      await settle(tester);

      expect(find.byType(SessionWidget), findsOneWidget);
      final plan = DayPlan.decode((await store.day(day0))!.plan);
      expect(find.text(sectionPosition(plan, 0)), findsOneWidget);
    });
  });

  // The hub is the app's home and stays warm overnight, so the launch resolved at start is
  // stale by morning. The store is the oracle: today's record exists only once the launch
  // ran again for the new day.
  group('a warm hub on a new day (End state 6)', () {
    testWidgets(
        'a resume on the next day replaces the end card with the new plan and Start; '
        'inactive, hidden and paused on that day change nothing',
        (tester) async {
      final store = await doneStore();
      final clock = FixedClock(at(day0));
      await pumpHub(tester, store, clock: clock);
      expect(find.text('Done for today'), findsOneWidget);

      clock.set(at(day0 + 1));
      // The states on the way to the background and back, in the order the framework
      // allows them. Only resumed is the app in front again.
      await lifecycle(tester, AppLifecycleState.inactive);
      await lifecycle(tester, AppLifecycleState.hidden);
      await lifecycle(tester, AppLifecycleState.paused);
      await lifecycle(tester, AppLifecycleState.hidden);
      await lifecycle(tester, AppLifecycleState.inactive);
      expect(find.text('Done for today'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(await store.day(day0 + 1), isNull);

      await lifecycle(tester, AppLifecycleState.resumed);
      expect(find.text('Done for today'), findsNothing);
      expect(find.text('Start'), findsOneWidget);
      final plan = DayPlan.decode((await store.day(day0 + 1))!.plan);
      expect(plan.returnMode, isFalse);
      expect(find.text(todaySectionsLine(plan)), findsOneWidget);
      // Yesterday stays finished: a relaunch rewrites no earlier day (PIN-9).
      expect((await store.day(day0))!.completed, isTrue);
    });

    testWidgets('a resume on the same day leaves the launch alone',
        (tester) async {
      final store = DayReadsStore();
      await doneStore(into: store);
      await pumpHub(tester, store);
      final reads = store.dayReads;
      expect(reads, greaterThan(0), reason: 'the first launch read the record');

      await lifecycle(tester, AppLifecycleState.resumed);
      expect(find.text('Done for today'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(store.dayReads, reads, reason: 'no second launch resolution');
    });

    testWidgets(
        'a resume behind the session waits: the new day resolves when the session '
        'returns, after its answers', (tester) async {
      final store = await seededStore();
      final clock = FixedClock(at(day0));
      await pumpHub(tester, store, clock: clock);
      await tester.tap(find.text('Start'));
      await settle(tester);
      expect(find.byType(SessionWidget), findsOneWidget);

      clock.set(at(day0 + 1));
      await lifecycle(tester, AppLifecycleState.resumed);
      expect(find.byType(SessionWidget), findsOneWidget);
      expect(await store.day(day0 + 1), isNull,
          reason: 'tomorrow is not built under a session still under way');

      Navigator.of(tester.element(find.byType(SessionWidget))).pop();
      await settle(tester);
      expect(find.byType(SessionWidget), findsNothing);
      expect(find.text('Start'), findsOneWidget);
      expect(await store.day(day0 + 1), isNotNull);
    });

    testWidgets(
        'a study screen that returns on a new day brings the new plan with it',
        (tester) async {
      final store = await doneStore();
      final clock = FixedClock(at(day0));
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => QuietRoomJapaneseWidget(
                store: store, catalog: catalog, clock: clock)),
        // A quiet link opens a drill screen on top of Today.
        GoRoute(
          name: QuietRoomDrillsWidget.routeName,
          path: QuietRoomDrillsWidget.routePath,
          builder: (_, __) => const Text('the drills'),
        ),
      ]);
      addTearDown(router.dispose);
      await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));
      await settle(tester);
      expect(find.text('Done for today'), findsOneWidget);

      await tester.tap(find.text('Conjugation'));
      await tester.pumpAndSettle();
      expect(find.text('the drills'), findsOneWidget);

      clock.set(at(day0 + 1));
      router.pop();
      await tester.pumpAndSettle();
      await settle(tester);
      expect(find.text('the drills'), findsNothing);
      expect(find.text('Done for today'), findsNothing);
      expect(find.text('Start'), findsOneWidget);
      expect(await store.day(day0 + 1), isNotNull);
    });
  });

  group('Today (D20)', () {
    testWidgets(
        'holds no number strip, hero, study rows, search box or use strip; '
        'the quiet links and the three tabs instead', (tester) async {
      await pumpHub(tester, await seededStore());

      expect(find.byKey(const ValueKey('today-card')), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'no search box');
      expect(find.byType(QrPill), findsNothing, reason: 'no strip of pills');
      expect(
          find.byWidgetPredicate(
              (w) => w is ListView && w.scrollDirection == Axis.horizontal),
          findsNothing,
          reason: 'no horizontal strip');
      expect(find.textContaining(RegExp(r'第\d+課')), findsNothing,
          reason: 'no lesson number on the home');
      for (final gone in [
        'START HERE',
        'CONTINUE',
        'Grammar lessons',
        'Vocabulary',
        'Verb pairs · が and を',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      for (final link in [
        'Conjugation',
        'Verb pairs',
        'Numbers and counters',
        'Study record',
      ]) {
        expect(find.widgetWithText(TextButton, link), findsOneWidget,
            reason: link);
      }
      for (final tab in HomeTab.values) {
        final key = find.byKey(ValueKey('tab-${tab.name}'));
        expect(key, findsOneWidget, reason: tab.name);
        expect(find.descendant(of: key, matching: find.text(homeTabLabel(tab))),
            findsOneWidget);
      }
      // One loud object: Start is the only filled button.
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets(
        'shows the mastered count and the kept rate over 30 days from the store',
        (tester) async {
      final store = JpStoreMemory();
      final item = catalog.ofKind(ItemKind.word).first;
      final probes = item.scoredProbes.toList();
      // Four clears on four days, the fourth 22 days after the third: Mastered on day0 - 28.
      final clears = [day0 - 60, day0 - 57, day0 - 50, day0 - 28];
      for (var i = 0; i < clears.length; i++) {
        await record(
            store,
            answer(item, clears[i], Grade.clear,
                probe: probes[i % probes.length]));
      }
      expect((await store.mastery(item.id))!.status, MasteryStatus.mastered,
          reason: 'the four clears master the word');
      // Two maintenance reviews in the window, one clear and one hinted; an early clear
      // and a Say-it answer are no review.
      await record(store, answer(item, day0 - 20, Grade.clear));
      await record(store, answer(item, day0 - 10, Grade.hinted));
      await record(
          store,
          answer(item, day0 - 5, Grade.clear,
              source: Source.early, wasDue: false));
      await seededStore(into: store);
      await pumpHub(tester, store);

      expect(
          keptRateOf(await store.attempts(), catalog.byId, day0),
          isA<KeptRate>()
              .having((r) => r.kept, 'kept', 1)
              .having((r) => r.reviews, 'reviews', 2));
      expect(find.text(masteredLine(1)), findsOneWidget);
      expect(find.text('Kept rate 50% over 30 days · 1 of 2'), findsOneWidget);
    });

    testWidgets('a record with no review of a Mastered item says so plainly',
        (tester) async {
      await pumpHub(tester, await seededStore());
      expect(find.text(masteredLine(0)), findsOneWidget);
      expect(find.text(keptRateLine(const KeptRate(kept: 0, reviews: 0))),
          findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('the 14 dots mark the days whose session completed',
        (tester) async {
      final store = await seededStore();
      final plan = jsonEncode(emptyPlan().toJson());
      await store.putDay(DayRecord(day: day0 - 3, plan: plan, completed: true));
      await store.putDay(DayRecord(day: day0 - 2, plan: plan, position: 4));
      await store.putDay(DayRecord(day: day0 - 1, plan: plan, completed: true));
      await pumpHub(tester, store);

      final dots = (await loadHomeRecord(store, catalog.byId, day0)).dots;
      expect(dots, [
        for (var i = 0; i < kHomeDots; i++) i == 10 || i == 12,
      ]);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('home-dots')),
              matching: find.text('2 of 14 days')),
          findsOneWidget);
    });

    testWidgets('a quiet link opens its screen over Today', (tester) async {
      final store = await seededStore();
      String? mode;
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => QuietRoomJapaneseWidget(
                store: store, catalog: catalog, clock: FixedClock(at(day0)))),
        GoRoute(
          name: QuietRoomDrillsWidget.routeName,
          path: QuietRoomDrillsWidget.routePath,
          builder: (_, state) {
            mode = state.uri.queryParameters['mode'];
            return const Text('the drills');
          },
        ),
      ]);
      addTearDown(router.dispose);
      await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));
      await settle(tester);

      await tester.tap(find.text('Verb pairs'));
      await tester.pumpAndSettle();
      expect(find.text('the drills'), findsOneWidget);
      expect(mode, 'pairs');
    });
  });

  group('the tabs', () {
    testWidgets(
        'Lessons and Topics replace Today in place, with no back button',
        (tester) async {
      await pumpHub(tester, await seededStore());

      await tester.tap(find.byKey(const ValueKey('tab-lessons')));
      await settle(tester);
      expect(
          find.byWidgetPredicate((w) => w is LessonsPathWidget && !w.showBack),
          findsOneWidget);
      expect(find.byKey(const ValueKey('path-current')), findsOneWidget);
      expect(find.byKey(const ValueKey('today-card')), findsNothing);
      expect(find.byTooltip('Back'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tab-topics')));
      await settle(tester);
      expect(
          find.byWidgetPredicate(
              (w) => w is QuietRoomTopicsWidget && !w.showBack),
          findsOneWidget);
      expect(find.text(kTopicsSearchHint), findsOneWidget,
          reason: 'search lives in Topics');
      expect(find.byTooltip('Back'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tab-today')));
      await settle(tester);
      expect(find.byKey(const ValueKey('today-card')), findsOneWidget);
      expect(find.byType(QuietRoomTopicsWidget), findsNothing);
    });

    testWidgets(
        'under the app router a tab is a go: the URL names it and '
        'the stack stays flat', (tester) async {
      final store = await seededStore();
      final router = GoRouter(routes: [
        GoRoute(
          name: QuietRoomJapaneseWidget.routeName,
          path: '/',
          builder: (_, state) => QuietRoomJapaneseWidget(
              store: store,
              catalog: catalog,
              clock: FixedClock(at(day0)),
              tab: homeTabOf(state.uri.queryParameters['tab'])),
        ),
      ]);
      addTearDown(router.dispose);
      await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));
      await settle(tester);
      String? tabInUrl() =>
          router.routeInformationProvider.value.uri.queryParameters['tab'];

      await tester.tap(find.byKey(const ValueKey('tab-lessons')));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(tabInUrl(), 'lessons');
      expect(find.byType(LessonsPathWidget), findsOneWidget);
      expect(router.canPop(), isFalse);

      await tester.tap(find.byKey(const ValueKey('tab-topics')));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(tabInUrl(), 'topics');
      expect(find.byType(QuietRoomTopicsWidget), findsOneWidget);
      expect(router.canPop(), isFalse);

      await tester.tap(find.byKey(const ValueKey('tab-today')));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(tabInUrl(), isNull);
      expect(find.byKey(const ValueKey('today-card')), findsOneWidget);
      expect(router.canPop(), isFalse);
    });

    testWidgets(
        'on the errorBuilder home a tab tap lands on /: Lessons shows on a real route',
        (tester) async {
      // nav.dart's errorBuilder serves the signed-out home for an unmatched URL. go_router
      // builds that page outside its State registry, so `GoRouterState.of` throws there,
      // and a `go` on the bogus path would build a new State on every tap.
      final store = await seededStore();
      Widget home(GoRouterState state) => QuietRoomJapaneseWidget(
          store: store,
          catalog: catalog,
          clock: FixedClock(at(day0)),
          tab: homeTabOf(state.uri.queryParameters['tab']));
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, state) => home(state))],
        errorBuilder: (_, state) => home(state),
      );
      addTearDown(router.dispose);
      await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));
      await settle(tester);
      Uri location() => router.routeInformationProvider.value.uri;
      // Each step here crosses page keys, so a page transition runs, and the finders
      // wait for it to end.
      Future<void> transition() async {
        await settle(tester);
        await tester.pumpAndSettle();
        await settle(tester);
      }

      router.go('/nowhere');
      await transition();
      expect(location().path, '/nowhere');
      expect(find.byKey(const ValueKey('today-card')), findsOneWidget,
          reason: 'the errorBuilder serves the home');

      await tester.tap(find.byKey(const ValueKey('tab-lessons')));
      await transition();
      expect(tester.takeException(), isNull);
      expect(find.byType(LessonsPathWidget), findsOneWidget);
      expect(location().path, '/',
          reason: 'the tap lands on a real route, not the bogus path');
      expect(location().queryParameters['tab'], 'lessons');
    });

    test('a tab parameter names its tab, and anything else is Today', () {
      expect(homeTabOf('lessons'), HomeTab.lessons);
      expect(homeTabOf('topics'), HomeTab.topics);
      expect(homeTabOf(null), HomeTab.today);
      expect(homeTabOf('nonsense'), HomeTab.today);
    });

    test('nav.dart gives each tab a URL on the home route', () {
      final router = createRouter(AppStateNotifier.instance);
      addTearDown(router.dispose);
      expect(
          router.namedLocation(QuietRoomJapaneseWidget.routeName,
              queryParameters: {'tab': HomeTab.topics.name}),
          '${QuietRoomJapaneseWidget.routePath}?tab=topics');
    });

    testWidgets(
        'from the root route, after Not now, a tab tap keeps the home: Lessons shows '
        'and Welcome back stays dismissed (End state 6)', (tester) async {
      // nav.dart's shape: the app starts at `/`, and the home has a named route too. A
      // `goNamed` from `/` builds a second page and a fresh State, which asks Welcome back
      // again; a `go` on `/` keeps the one State.
      final store = DayReadsStore();
      await doneStore(into: store);
      const back = day0 + 4; // three local days missed: return mode
      final clock = FixedClock(at(back));
      Widget home(GoRouterState state) => QuietRoomJapaneseWidget(
          store: store,
          catalog: catalog,
          clock: clock,
          tab: homeTabOf(state.uri.queryParameters['tab']));
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, state) => home(state)),
        GoRoute(
          name: QuietRoomJapaneseWidget.routeName,
          path: QuietRoomJapaneseWidget.routePath,
          builder: (_, state) => home(state),
        ),
      ]);
      addTearDown(router.dispose);
      await pumpStudyScreen(tester, MaterialApp.router(routerConfig: router));
      await settle(tester);
      expect(find.byType(WelcomeBackWidget), findsOneWidget);
      String path() => router.routeInformationProvider.value.uri.path;

      await tester.tap(find.text('Not now'));
      await settle(tester);
      expect(find.byType(WelcomeBackWidget), findsNothing);
      expect(find.byKey(const ValueKey('today-card')), findsOneWidget);
      final readsAfterNotNow = store.dayReads;

      await tester.tap(find.byKey(const ValueKey('tab-lessons')));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.byType(LessonsPathWidget), findsOneWidget);
      expect(find.byType(WelcomeBackWidget), findsNothing);
      expect(find.byKey(const ValueKey('tab-today')), findsOneWidget,
          reason: 'the bottom nav stays under Lessons');
      expect(path(), '/',
          reason: 'the tab is a query on the route the home is on');
      expect(store.dayReads, readsAfterNotNow,
          reason: 'a tab tap resolves no launch: the State survived the tap');

      await tester.tap(find.byKey(const ValueKey('tab-topics')));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.byType(QuietRoomTopicsWidget), findsOneWidget);
      expect(find.byType(WelcomeBackWidget), findsNothing);
      expect(path(), '/');

      // Today again on the same day: the launch resolves to Welcome back once more, and
      // Not now still holds.
      await tester.tap(find.byKey(const ValueKey('tab-today')));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.byKey(const ValueKey('today-card')), findsOneWidget);
      expect(find.byType(WelcomeBackWidget), findsNothing);
      expect(path(), '/');
    });

    testWidgets(
        'nav.dart serves the signed-out home at / and by name as two pages, and '
        'each reads the tab', (tester) async {
      final router = createRouter(AppStateNotifier.instance);
      addTearDown(router.dispose);
      final config = router.configuration;
      RouteMatchList match(String location) => config.findMatch(location);
      final root = match('/?tab=lessons');
      final named = match('${QuietRoomJapaneseWidget.routePath}?tab=topics');
      expect(root.error, isNull);
      expect(named.error, isNull);
      // The premise of the tab tap: `/?tab=...` is the same page as `/`, and the named
      // route is another page, so only a `go` on the current path keeps the State.
      expect(root.matches.single.pageKey, match('/').matches.single.pageKey);
      expect(root.matches.single.pageKey, isNot(named.matches.single.pageKey));

      // The page each route builds, with the splash off and nobody signed in.
      final app = AppStateNotifier.instance;
      app.user = _SignedOut();
      app.showSplashImage = false;
      addTearDown(() {
        app.user = null;
        app.showSplashImage = true;
      });
      HomeTab? built(RouteMatchList list) {
        final m = list.matches.single;
        final state = router.routerDelegate.builder.buildState(list, m);
        HomeTab? tab;
        final context = tester.element(find.byType(SizedBox));
        final page = (m.route as GoRoute).pageBuilder!(context, state);
        final child = page is MaterialPage
            ? page.child
            : (page as CustomTransitionPage).child;
        final home = (child as PushNotificationsHandler).child;
        if (home is QuietRoomJapaneseWidget) tab = home.tab;
        return tab;
      }

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(built(root), HomeTab.lessons);
      expect(built(named), HomeTab.topics);
      expect(built(match('/')), HomeTab.today);
      expect(built(match(QuietRoomJapaneseWidget.routePath)), HomeTab.today);
    });
  });

  group('keptRateOf (A1)', () {
    const w = _Word('w');
    Attempt bare(int day, Grade grade,
            {Source source = Source.review, String id = 'w'}) =>
        Attempt(
          itemId: id,
          probeId: 'p',
          template: 'reveal',
          production: false,
          selfGraded: true,
          atUtc: at(day).toUtc(),
          localDay: day,
          grade: grade,
          rating: source == Source.sayIt ? null : fsrsRatingFor(grade),
          hintLevel: grade == Grade.hinted ? 1 : 0,
          wasDue: source != Source.early,
          source: source,
          sessionId: 'test',
        );
    ItemDefLike? lookup(String id) => id == 'w' ? w : null;
    final log = [
      // Mastered by the clear on day 32.
      for (final d in [0, 3, 10, 32]) bare(d, Grade.clear),
      bare(35, Grade.clear),
      bare(50, Grade.clear),
      bare(60, Grade.hinted),
      bare(65, Grade.clear, source: Source.early),
      bare(66, Grade.clear, source: Source.sayIt),
      bare(67, Grade.unscored),
      bare(68,
          Grade.wrong), // a review of a Mastered item: kept no, and now Shaky
      bare(69, Grade.clear), // Shaky: no longer a kept review
      bare(55, Grade.clear, id: 'unknown'),
    ];

    test(
        'counts the scored reviews of a Mastered item in the 30 days, and the clear ones',
        () {
      final r = keptRateOf(log, lookup, 70);
      expect(r.reviews, 3, reason: 'days 50, 60 and 68');
      expect(r.kept, 1, reason: 'day 50');
    });

    test('never counts the answer that masters, nor one past the window', () {
      final r = keptRateOf(log, lookup, 70, days: 100);
      expect(r.reviews, 4, reason: 'days 35, 50, 60 and 68; not day 32');
      expect(r.kept, 2);
      expect(
          keptRateOf(log, lookup, 40),
          isA<KeptRate>()
              .having((r) => r.reviews, 'reviews', 1)
              .having((r) => r.kept, 'kept', 1));
    });

    test('the line reads as a whole percent with its counts, or plainly', () {
      expect(keptRateLine(const KeptRate(kept: 23, reviews: 25)),
          'Kept rate 92% over 30 days · 23 of 25');
      expect(const KeptRate(kept: 0, reviews: 0).rate, isNull);
      expect(keptRateLine(const KeptRate(kept: 0, reviews: 0)),
          'Kept rate: no reviews of mastered items in the last 30 days');
    });
  });
}

/// A word with one probe, for the kept rate's pure cases.
class _Word implements ItemDefLike {
  const _Word(this.id);
  @override
  final String id;
  @override
  ItemKind get kind => ItemKind.word;
  @override
  int get templateCount => 1;
  @override
  bool get hasProductionProbe => false;
  @override
  int get probeCount => 1;

  // No moded card, so the three-mode clause (plan 2026-11-06, Task 7, PIN-7) never binds here.
  @override
  Set<ProbeMode> get modes => const {};
}

/// An answer on [item] on [day], as the session writes it.
Attempt answer(ItemDef item, int day, Grade grade,
    {Source source = Source.review, ProbeDef? probe, bool wasDue = true}) {
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
    rating: fsrsRatingFor(grade),
    hintLevel: grade == Grade.hinted ? 1 : 0,
    wasDue: wasDue,
    source: source,
    sessionId: 'test',
  );
}

Future<void> record(JpStore store, Attempt a) => store.recordAnswer(a,
    item: catalog.byId(a.itemId), scheduler: const FsrsScheduler());
