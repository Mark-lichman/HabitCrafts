// Widget tests for the Review session (plan 2026-11-02, Task 18, End state 10).
//
// The session walks a hand-built `DayPlan` over the shipped catalog on a memory store with an
// injected clock. A fake probe builder stands in for the probe widgets (tested on their own in
// probe_widgets_test.dart): it shows four buttons that hand on a clear, a hinted, a wrong or an
// unscored draft. The cases: the section order and the "Due · 1 of 2" line, the attempt written
// at answer time with the entry's `wasDue` and source (ASK-6), the no-credit card (PIN-3), the
// Clear and Mastered cards (the fourth clear, and a Shaky item's regain), a wrong with no card
// (straight on when the answer was on screen, else the probe held under one Next, with the
// real probes) and its re-ask as the last entry of its section, not due (PIN-11, operator
// ruling 2026-11-05), the skip that moves an entry to the end of its
// section once, the soft stop at the target with Stop and Keep going, the end at the ceiling
// with the rest left due (PIN-5), One more (10) inside the ceiling, the catch-up only when the
// plan offers it and only on a tap (PIN-12), the stretch only under its conditions (PIN-6),
// the 14 dots over the days whose session completed, the end card listing two mastered items
// that share a title (PIN-16), a resume (`position`) that carries the estimate (skips
// included, a skipped re-ask among them), the day's counts, the mastered-today list and a
// taken offer on instead of restarting them, and a double tap on a card's button that runs
// its action once.
//
// Review the lesson (plan 2026-11-06, Task 2, End state 1, PIN-5): under the app's router the
// link on an unanswered card pushes the item kind's lesson target, Back returns to the same
// card unanswered and marked "Lesson reviewed", and a clear after it is written hinted at hint
// level 1; wrong, hinted and unscored answers are untouched; the review covers that card only;
// the link is gone once the card is answered; opening a lesson writes no attempt; an opener
// that fails leaves the card unreviewed, so a clear after it stays clear, and a failure after
// an earlier open of the same card keeps that mark; every item kind's link, and both a taught
// and an untaught particle's, pushes its own target and query through the router and Back
// returns to its card.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/lesson_page_widget.dart'
    show lessonTargetOf;
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/plan_builder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/probe_widgets.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/session_widget.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));
final words = catalog.ofKind(ItemKind.word);

const int today = 300;

/// 10:00 local on [day].
DateTime at(int day) => dayStart(day).add(const Duration(hours: 6));

QueueEntry entryOf(ItemDef item, PlanSection section,
        {int cost = 10, bool wasDue = true}) =>
    QueueEntry(
        itemId: item.id,
        kind: item.kind,
        section: section,
        costSeconds: cost,
        wasDue: wasDue,
        lesson: item.lesson);

DayPlan planOf(
  List<QueueEntry> entries, {
  int target = kTargetSeconds,
  int ceiling = kCeilingSeconds,
  bool stretchOffer = false,
  List<QueueEntry> stretchEntries = const [],
  bool catchUpOffer = false,
  List<QueueEntry> catchUpEntries = const [],
}) =>
    DayPlan(
      day: today,
      builtAtUtc: at(today).toUtc(),
      entries: entries,
      daysMissed: 0,
      backlogSeconds: 0,
      targetSeconds: target,
      ceilingSeconds: ceiling,
      gateSeconds: (target * kGateFactor).round(),
      repairSlotSeconds: kRepairSlotSeconds,
      newSkip: NewSkip.none,
      keepSharpRan: false,
      dueLeft: 0,
      stretchOffer: stretchOffer,
      stretchEntries: stretchEntries,
      catchUpOffer: catchUpOffer,
      catchUpEntries: catchUpEntries,
    );

/// The fake probe: the item id and four answers.
Widget fakeProbe(BuildContext context, SessionProbeRequest r) {
  final probe = r.item.scoredProbes.first;
  DrillAnswer draft(Grade g) => DrillAnswer(
      itemId: r.item.id,
      probeId: probe.id,
      template: probe.template,
      production: probe.production,
      selfGraded: probe.selfGraded,
      grade: g,
      hintLevel: g == Grade.hinted ? 1 : 0);
  return Column(children: [
    Text('probe ${r.item.id}'),
    for (final g in [Grade.clear, Grade.hinted, Grade.wrong, Grade.unscored])
      TextButton(
          onPressed: () => r.onAnswer(draft(g)),
          child: Text('answer ${g.name}')),
  ]);
}

class Harness {
  Harness(this.tester, this.store);

  final WidgetTester tester;
  final JpStoreMemory store;

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Future<void> tap(String label) async {
    final f = find.text(label);
    expect(f, findsOneWidget, reason: 'a "$label" control');
    await tester.ensureVisible(f);
    await tester.tap(f);
    await settle();
  }

  /// Answers the entry on screen with [g] and taps Next on the verdict card.
  Future<void> answer(Grade g) async {
    await tap('answer ${g.name}');
    await tap('Next');
  }

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  /// The item id of the entry on screen, or null.
  String? get onScreen {
    final f = find.textContaining('probe ');
    if (f.evaluate().isEmpty) return null;
    return (f.evaluate().first.widget as Text).data!.substring(6);
  }
}

/// An answer on [item] on [day] with [grade], under [sessionId].
Attempt attemptOf(ItemDef item, int day, Grade grade,
    {String sessionId = '${kReviewSessionPrefix}earlier'}) {
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
    wasDue: true,
    source: Source.review,
    sessionId: sessionId,
  );
}

/// Pumps the session over [plan]; [position] above 0 is a resume of the stored day.
Future<Harness> pumpSession(WidgetTester tester, DayPlan plan,
    {JpStoreMemory? store, int position = 0, LessonOpener? openLesson}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final s = store ?? JpStoreMemory();
  await s
      .putDay(DayRecord(day: today, plan: plan.encode(), position: position));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SessionWidget(
        plan: plan,
        store: s,
        clock: FixedClock(at(today)),
        catalog: catalog,
        position: position,
        probeBuilder: fakeProbe,
        openLesson: openLesson,
      ),
    ),
  ));
  final h = Harness(tester, s);
  await h.settle();
  return h;
}

void main() {
  testWidgets(
      'walks the sections in plan order with the section line, and writes each answer '
      'with the entry wasDue and source (ASK-6)', (tester) async {
    final plan = planOf([
      entryOf(words[0], PlanSection.repair),
      entryOf(words[1], PlanSection.due),
      entryOf(words[2], PlanSection.due),
      entryOf(words[3], PlanSection.keepSharp, wasDue: false),
      entryOf(words[4], PlanSection.newItems),
    ]);
    final h = await pumpSession(tester, plan);
    final seen = <String>[];
    for (final label in [
      'Repair · 1 of 1',
      'Due · 1 of 2',
      'Due · 2 of 2',
      'Keep-sharp · 1 of 1',
      'New · 1 of 1',
    ]) {
      expect(h.shows(label), isTrue, reason: label);
      seen.add(h.onScreen!);
      await h.answer(Grade.clear);
    }
    expect(seen, [for (final e in plan.entries) e.itemId]);
    expect(h.shows('Done for today'), isTrue);

    final attempts = await h.store.attempts();
    expect([for (final a in attempts) a.itemId], seen);
    expect(
        [for (final a in attempts) a.wasDue], [true, true, true, false, true]);
    expect([
      for (final a in attempts) a.source
    ], [
      Source.review,
      Source.review,
      Source.review,
      Source.keepSharp,
      Source.review,
    ]);
    // The New entry's introduction clear is the first of the four (ASK-6).
    expect((await h.store.mastery(words[4].id))!.clearCount, 1);
    final record = await h.store.day(today);
    expect(record!.completed, isTrue);
    expect(record.position, plan.entries.length);
  });

  testWidgets('each answer is in the store before its verdict card shows',
      (tester) async {
    final h = await pumpSession(
        tester,
        planOf([
          entryOf(words[0], PlanSection.due),
          entryOf(words[1], PlanSection.due),
        ]));
    await h.tap('answer clear');
    expect(h.shows('Clear'), isTrue);
    expect(await h.store.attempts(), hasLength(1));
    expect((await h.store.day(today))!.position, 1,
        reason: 'the day record moves with the answer, so a relaunch resumes');
  });

  testWidgets(
      'a hinted answer shows Right with a hint and earns no credit (PIN-3); a clear '
      'shows its new interval', (tester) async {
    final h = await pumpSession(
        tester,
        planOf([
          entryOf(words[0], PlanSection.due),
          entryOf(words[1], PlanSection.due),
        ]));
    await h.tap('answer hinted');
    expect(h.shows('Right with a hint'), isTrue);
    expect(h.shows('No credit this time.'), isTrue);
    expect(h.shows('Clear'), isFalse);
    final hinted = await h.store.mastery(words[0].id);
    expect(hinted!.clearCount, 0);
    expect((await h.store.attempts()).single.grade, Grade.hinted);
    await h.tap('Next');

    await h.tap('answer clear');
    expect(h.shows('Clear'), isTrue);
    final srs = await h.store.srs(words[1].id);
    expect(
        h.shows(
            'Next review in ${srs!.dueDay - today == 1 ? '1 day' : '${srs.dueDay - today} days'}.'),
        isTrue);
    expect((await h.store.mastery(words[1].id))!.clearCount, 1);
  });

  testWidgets(
      'the fourth clear that completes the rule shows Mastered and the end card lists it',
      (tester) async {
    // A particle has one template and one probe, so only the spaced clears count.
    final particle = catalog.ofKind(ItemKind.particle).first;
    final probe = particle.scoredProbes.first;
    ClearRef c(int day) => ClearRef(
        day: day,
        template: probe.template,
        production: probe.production,
        probeId: probe.id);
    final store = JpStoreMemory();
    await store.putMastery(MasteryState(
      itemId: particle.id,
      status: MasteryStatus.learning,
      clears: [c(today - 70), c(today - 50), c(today - 30)],
      lastScoredDay: today - 30,
    ));
    final h = await pumpSession(
        tester, planOf([entryOf(particle, PlanSection.due)]),
        store: store);
    await h.tap('answer clear');
    expect(h.shows('Mastered'), isTrue);
    expect(
        h.shows('Four clears over time. It still comes back to keep it sharp.'),
        isTrue);
    expect((await store.mastery(particle.id))!.status, MasteryStatus.mastered);
    await h.tap('Next');
    expect(h.shows('Mastered today'), isTrue);
    expect(h.shows(particle.title), isTrue);
  });

  testWidgets(
      'the clear that regains a Shaky item shows Mastered without the four-clears line',
      (tester) async {
    final particle = catalog.ofKind(ItemKind.particle).first;
    final probe = particle.scoredProbes.first;
    final store = JpStoreMemory();
    // One regain clear eight days ago: this clear is the second, past the 7-day gap.
    await store.putMastery(MasteryState(
      itemId: particle.id,
      status: MasteryStatus.shaky,
      clears: [
        ClearRef(
            day: today - 8,
            template: probe.template,
            production: probe.production,
            probeId: probe.id)
      ],
      lastScoredDay: today - 8,
      shakyOn: today - 20,
    ));
    final h = await pumpSession(
        tester, planOf([entryOf(particle, PlanSection.due)]),
        store: store);
    await h.tap('answer clear');
    expect(h.shows('Mastered'), isTrue);
    expect(h.shows('Back to mastered. It still comes back to keep it sharp.'),
        isTrue);
    expect(
        h.shows('Four clears over time. It still comes back to keep it sharp.'),
        isFalse);
    expect((await store.mastery(particle.id))!.status, MasteryStatus.mastered);
    await h.tap('Next');
    expect(h.shows(particle.title), isTrue);
  });

  testWidgets(
      'the end card lists two items mastered today that share a title, one line each '
      '(PIN-16)', (tester) async {
    final byTitle = <String, List<ItemDef>>{};
    for (final w in words) {
      byTitle.putIfAbsent(w.title, () => []).add(w);
    }
    final twins = byTitle.values.firstWhere((v) => v.length > 1);
    final store = JpStoreMemory();
    for (final twin in twins.take(2)) {
      await store.putMastery(MasteryState(
          itemId: twin.id, status: MasteryStatus.mastered, masteredOn: today));
    }
    final h = await pumpSession(
        tester, planOf([entryOf(words[0], PlanSection.due)]),
        store: store);
    await h.answer(Grade.clear);
    expect(h.shows('Mastered today'), isTrue);
    expect(find.text(twins.first.title), findsNWidgets(2));
  });

  testWidgets(
      'a wrong shows no card: the probe stays under one Next, and the item is re-asked '
      'as the last entry of its section, not due (operator ruling 2026-11-05, PIN-11)',
      (tester) async {
    final rest = [
      for (final w in words.skip(1).take(4))
        entryOf(w, PlanSection.due, cost: 100)
    ];
    final fresh = entryOf(words[5], PlanSection.newItems, cost: 100);
    final plan = planOf(
        [entryOf(words[0], PlanSection.due, cost: 100), ...rest, fresh],
        target: 10000, ceiling: 20000);
    final h = await pumpSession(tester, plan);
    await h.tap('answer wrong');
    // The fake probe's draft does not say the answer was on screen, so the probe stays.
    expect(h.onScreen, words[0].id);
    expect(h.shows('Due · 1 of 5'), isTrue);
    for (final retired in [
      'Not this time',
      'Not quite',
      'It comes back in about 10 minutes, and again tomorrow.',
      'It comes back tomorrow.',
    ]) {
      expect(h.shows(retired), isFalse, reason: retired);
    }
    await h.tap('Next');
    for (var i = 0; i < rest.length; i++) {
      expect(h.onScreen, rest[i].itemId);
      await h.answer(Grade.clear);
    }
    // The re-ask is the last entry of Due, before New.
    expect(h.onScreen, words[0].id);
    expect(h.shows('Due · 6 of 6'), isTrue);
    final stored = DayPlan.decode((await h.store.day(today))!.plan)
        .section(PlanSection.due);
    expect(stored.last.itemId, words[0].id);
    expect(stored.last.reask, isTrue);
    await h.answer(Grade.clear);
    expect(h.onScreen, fresh.itemId);
    final onItem = await h.store.attempts(itemId: words[0].id);
    expect([for (final a in onItem) a.grade], [Grade.wrong, Grade.clear]);
    expect([for (final a in onItem) a.wasDue], [true, false]);
    // The wrong scheduled it Again for another day, and a not-due clear starts no run of
    // counting clears.
    expect((await h.store.srs(words[0].id))!.dueDay, greaterThan(today));
    expect((await h.store.mastery(words[0].id))!.clearCount, 0);
  });

  group('the real probes after a wrong (operator ruling 2026-11-05)', () {
    final grammar = _read('assets/lessons/jp_grammar.json');
    final particle = catalog.ofKind(ItemKind.particle).first;

    Future<Harness> pumpReal(WidgetTester tester, DayPlan plan) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final s = JpStoreMemory();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SessionWidget(
            plan: plan,
            store: s,
            clock: FixedClock(at(today)),
            catalog: catalog,
            probeBuilder: standardProbeBuilder(grammar: grammar),
          ),
        ),
      ));
      final h = Harness(tester, s);
      await h.settle();
      return h;
    }

    testWidgets('Not yet on a word card moves straight on, with no card',
        (tester) async {
      final plan = planOf([
        entryOf(words[0], PlanSection.due),
        entryOf(words[1], PlanSection.due),
      ]);
      final h = await pumpReal(tester, plan);
      expect(h.shows(words[0].probes.first.text), isTrue,
          reason: 'the card shows the meaning');
      await h.tap('Show me');
      await h.tap('Not yet');
      // The next word's card, with no result card and no Next between.
      expect(h.shows('Due · 2 of 3'), isTrue);
      expect(h.shows(words[1].probes.first.text), isTrue);
      expect(h.shows('Next'), isFalse);
      expect(h.shows('Not quite'), isFalse);
      final onItem = await h.store.attempts(itemId: words[0].id);
      expect([for (final a in onItem) a.grade], [Grade.wrong]);
      // The re-ask is the last entry of Due.
      final stored = DayPlan.decode((await h.store.day(today))!.plan);
      expect(stored.section(PlanSection.due).last.itemId, words[0].id);
      expect(stored.section(PlanSection.due).last.reask, isTrue);
    });

    testWidgets(
        'a particle card offers its English and its meaning as the grammar hint',
        (tester) async {
      final plan = planOf([entryOf(particle, PlanSection.due)]);
      final h = await pumpReal(tester, plan);
      final row = (grammar['particles'] as List)
          .cast<Map>()
          .firstWhere((p) => p['id'] == particle.id);
      expect(h.shows(row['example_en'] as String), isFalse);
      await h.tap('Show English');
      expect(h.shows(row['example_en'] as String), isTrue);
      await h.tap('Show grammar hint');
      expect(h.shows('The missing part means: ${row['meaning']}'), isTrue);
    });

    testWidgets('Show answer shows the full answer and one Next',
        (tester) async {
      final plan = planOf([
        entryOf(particle, PlanSection.due),
        entryOf(words[1], PlanSection.due),
      ]);
      final h = await pumpReal(tester, plan);
      final probe = particle.scoredProbes.first;
      await h.tap('Show answer');
      final (before, filled, after) = fillBlank(probe.text, probe.answer);
      expect(h.shows('$before$filled$after'), isTrue,
          reason: 'the prompt with the missing part filled in');
      expect(h.shows('Next'), isTrue);
      expect(h.shows('Not this time'), isFalse);
      // Still the particle, under its line from before the re-ask, until Next.
      expect(h.shows('Due · 1 of 2'), isTrue);
      await h.tap('Next');
      expect(h.shows('Due · 2 of 3'), isTrue);
      expect(h.shows(words[1].probes.first.text), isTrue);
    });

    testWidgets('a wrong typed answer shows both answers under one Next',
        (tester) async {
      final plan = planOf([entryOf(particle, PlanSection.due)]);
      final h = await pumpReal(tester, plan);
      final probe = particle.scoredProbes.first;
      await tester.enterText(find.byType(TextField), 'を');
      await h.tap('Check');
      final (before, filled, after) = fillBlank(probe.text, probe.answer);
      expect(h.shows('Your answer: を'), isTrue);
      expect(h.shows('$before$filled$after'), isTrue);
      expect(h.shows('Next'), isTrue);
    });
  });

  group('a skip (unscored)', () {
    testWidgets(
        'shows Not counted, asks the item again at the end of its section, and counts '
        'as answered', (tester) async {
      final plan = planOf([
        entryOf(words[0], PlanSection.due),
        entryOf(words[1], PlanSection.due),
        entryOf(words[2], PlanSection.due),
        entryOf(words[3], PlanSection.keepSharp, wasDue: false),
      ]);
      final h = await pumpSession(tester, plan);
      await h.tap('answer unscored');
      expect(h.shows('Not counted'), isTrue);
      expect(h.shows('It comes back later in this part.'), isTrue);
      await h.tap('Next');
      expect(h.onScreen, words[1].id);
      expect(h.shows('Due · 1 of 3'), isTrue);
      await h.answer(Grade.clear);
      await h.answer(Grade.clear);
      expect(h.onScreen, words[0].id, reason: 'the skipped item, last in Due');
      expect(h.shows('Due · 3 of 3'), isTrue);
      await h.answer(Grade.clear);
      expect(h.onScreen, words[3].id);
      await h.answer(Grade.clear);
      expect(h.shows('Done for today'), isTrue);
      // The skip is an answer on the end card; it is none of the three listed counts.
      expect(h.shows('5 answered · 4 clear · 0 with help · 0 missed'), isTrue);
      final onItem = await h.store.attempts(itemId: words[0].id);
      expect([for (final a in onItem) a.grade], [Grade.unscored, Grade.clear]);
      expect((await h.store.mastery(words[0].id))!.clearCount, 1);
    });

    testWidgets('a second skip on the same entry moves on', (tester) async {
      final h = await pumpSession(
          tester,
          planOf([
            entryOf(words[0], PlanSection.due),
            entryOf(words[1], PlanSection.due),
          ]));
      await h.answer(Grade.unscored);
      expect(h.onScreen, words[1].id);
      await h.answer(Grade.unscored);
      // Both moved once: the order is as it was.
      expect(h.onScreen, words[0].id);
      await h.answer(Grade.unscored);
      expect(h.onScreen, words[1].id, reason: 'a requeued entry stays put');
      await h.answer(Grade.unscored);
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 answered · 0 clear · 0 with help · 0 missed'), isTrue);
      final record = await h.store.day(today);
      expect(record!.position, 2);
      expect(
          DayPlan.decode(record.plan).entries.every((e) => e.requeued), isTrue);
    });
  });

  testWidgets(
      'the soft stop shows when the estimate reaches the target; Keep going runs on and '
      'the ceiling ends the session with the rest left due (PIN-5)',
      (tester) async {
    final entries = [
      for (final w in words.take(15)) entryOf(w, PlanSection.due, cost: 100)
    ];
    final h = await pumpSession(tester, planOf(entries));
    for (var i = 0; i < 9; i++) {
      expect(h.shows('About 15 minutes'), isFalse, reason: 'answer $i');
      await h.answer(Grade.clear);
    }
    expect(h.shows('About 15 minutes'), isTrue);
    expect(h.shows('Stop'), isTrue);
    await h.tap('Keep going');
    for (var i = 0; i < 3; i++) {
      expect(h.onScreen, entries[9 + i].itemId);
      await h.answer(Grade.clear);
    }
    // 1200 seconds spent: the next entry would pass the ceiling.
    expect(h.onScreen, isNull);
    expect(h.shows("That is today's 20 minutes"), isTrue);
    expect(h.shows('The rest is due tomorrow.'), isTrue);
    expect(h.shows('One more (10)'), isFalse,
        reason: 'One more stays inside the ceiling');
    expect(h.shows('Catch up: 10 more'), isFalse,
        reason: 'the plan does not offer the catch-up');
    expect(await h.store.attempts(), hasLength(12));
    final record = await h.store.day(today);
    expect(record!.completed, isTrue);
    expect(record.position, 12);
    // The three left were never answered, so they stay as due as they were.
    for (final e in entries.skip(12)) {
      expect(await h.store.attempts(itemId: e.itemId), isEmpty);
    }
  });

  testWidgets('Stop at the soft stop ends on the end card with One more (10)',
      (tester) async {
    final entries = [
      for (final w in words.take(25)) entryOf(w, PlanSection.due, cost: 60)
    ];
    final h = await pumpSession(tester, planOf(entries));
    for (var i = 0; i < 15; i++) {
      await h.answer(Grade.clear);
    }
    expect(h.shows('About 15 minutes'), isTrue);
    await h.tap('Stop');
    expect(h.shows('Done for today'), isTrue);
    expect(h.shows('15 answered · 15 clear · 0 with help · 0 missed'), isTrue);
    expect((await h.store.day(today))!.completed, isTrue);
    // One more runs at most 10 entries, and never past the ceiling (5 fit: 900 + 5 x 60).
    await h.tap('One more (10)');
    var more = 0;
    while (h.onScreen != null) {
      await h.answer(Grade.clear);
      more++;
    }
    expect(more, 5);
    expect(h.shows("That is today's 20 minutes"), isTrue);
    expect(h.shows('One more (10)'), isFalse);
  });

  testWidgets(
      'the catch-up shows past the ceiling only when the plan offers it, and adds '
      'nothing until tapped (PIN-12)', (tester) async {
    final entries = [
      for (final w in words.take(13)) entryOf(w, PlanSection.due, cost: 100)
    ];
    final block = [
      for (final w in words.skip(13).take(10)) entryOf(w, PlanSection.due)
    ];
    final h = await pumpSession(
        tester, planOf(entries, catchUpOffer: true, catchUpEntries: block));
    for (var i = 0; i < 9; i++) {
      await h.answer(Grade.clear);
    }
    await h.tap('Keep going');
    for (var i = 0; i < 3; i++) {
      await h.answer(Grade.clear);
    }
    expect(h.shows("That is today's 20 minutes"), isTrue);
    expect(h.shows('Catch up: 10 more'), isTrue);
    expect(await h.store.attempts(), hasLength(12));
    await h.tap('Catch up: 10 more');
    final asked = <String>[];
    while (h.onScreen != null) {
      asked.add(h.onScreen!);
      await h.answer(Grade.clear);
    }
    expect(asked, [for (final e in block) e.itemId]);
    expect(h.shows('Catch up: 10 more'), isFalse, reason: 'once only');
  });

  group('a double tap on a card runs its action once', () {
    testWidgets('on Catch up: 10 more, the whole block is still asked',
        (tester) async {
      final entries = [
        for (final w in words.take(13)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(13).take(10)) entryOf(w, PlanSection.due)
      ];
      final h = await pumpSession(
          tester, planOf(entries, catchUpOffer: true, catchUpEntries: block));
      for (var i = 0; i < 9; i++) {
        await h.answer(Grade.clear);
      }
      await h.tap('Keep going');
      for (var i = 0; i < 3; i++) {
        await h.answer(Grade.clear);
      }
      // Two taps inside the day write the first one starts: no frame between them.
      final f = find.text('Catch up: 10 more');
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.tap(f);
      await h.settle();
      final asked = <String>[];
      while (h.onScreen != null) {
        asked.add(h.onScreen!);
        await h.answer(Grade.clear);
      }
      expect(asked, [for (final e in block) e.itemId]);
      expect(h.shows('Done for today'), isTrue);
    });

    testWidgets('on Next at the target, the soft stop still shows',
        (tester) async {
      final entries = [
        for (final w in words.take(10)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(tester, planOf(entries));
      for (var i = 0; i < 8; i++) {
        await h.answer(Grade.clear);
      }
      await h.tap('answer clear');
      final f = find.text('Next');
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.tap(f);
      await h.settle();
      expect(h.onScreen, isNull, reason: 'the second tap asks no entry');
      expect(h.shows('About 15 minutes'), isTrue);
      await h.tap('Keep going');
      expect(h.onScreen, entries[9].itemId);
    });
  });

  group('the stretch offer (PIN-6)', () {
    final base = [for (final w in words.take(3)) entryOf(w, PlanSection.due)];
    final stretch = [
      for (final w in words.skip(3).take(kStretchNew))
        entryOf(w, PlanSection.newItems)
    ];

    testWidgets(
        'offered when the plan offers it and every entry is answered; tapped, it runs '
        'the four as New', (tester) async {
      final h = await pumpSession(
          tester, planOf(base, stretchOffer: true, stretchEntries: stretch));
      for (var i = 0; i < base.length; i++) {
        expect(h.shows('4 more new'), isFalse);
        await h.answer(Grade.clear);
      }
      expect(h.shows('4 more new'), isTrue);
      await h.tap('4 more new');
      final asked = <String>[];
      while (h.onScreen != null) {
        expect(h.shows('New · ${asked.length + 1} of $kStretchNew'), isTrue);
        asked.add(h.onScreen!);
        await h.answer(Grade.clear);
      }
      expect(asked, [for (final e in stretch) e.itemId]);
      expect(h.shows('4 more new'), isFalse, reason: 'once only');
      final news = await h.store.attempts();
      expect(news.skip(base.length).every((a) => a.wasDue), isTrue);
    });

    testWidgets('not offered when the plan does not offer it', (tester) async {
      final h = await pumpSession(tester, planOf(base));
      for (var i = 0; i < base.length; i++) {
        await h.answer(Grade.clear);
      }
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 more new'), isFalse);
    });

    testWidgets('not offered while a re-ask is still to come', (tester) async {
      final h = await pumpSession(
          tester, planOf(base, stretchOffer: true, stretchEntries: stretch));
      await h.answer(Grade.wrong);
      await h.answer(Grade.clear);
      await h.answer(Grade.clear);
      // The re-ask goes last; it is asked before any offer.
      expect(h.onScreen, base[0].itemId);
      expect(h.shows('4 more new'), isFalse);
      await h.answer(Grade.clear);
      expect(h.shows('4 more new'), isTrue);
    });

    testWidgets('not offered after Stop with entries left', (tester) async {
      final entries = [
        for (final w in words.take(12)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(
          tester, planOf(entries, stretchOffer: true, stretchEntries: stretch));
      for (var i = 0; i < 9; i++) {
        await h.answer(Grade.clear);
      }
      await h.tap('Stop');
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 more new'), isFalse);
    });

    testWidgets('not offered when the ceiling leaves no room for the four',
        (tester) async {
      final full = [
        for (final w in words.take(12)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(
          tester, planOf(full, stretchOffer: true, stretchEntries: stretch));
      for (var i = 0; i < 9; i++) {
        await h.answer(Grade.clear);
      }
      await h.tap('Keep going');
      for (var i = 0; i < 3; i++) {
        await h.answer(Grade.clear);
      }
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 more new'), isFalse);
    });
  });

  testWidgets(
      'the end card draws 14 dots over the days whose session completed',
      (tester) async {
    final store = JpStoreMemory();
    for (final d in [today - 1, today - 2, today - 5, today - 20]) {
      await store.putDay(DayRecord(day: d, plan: '{}', completed: true));
    }
    // A day planned and not finished is no dot.
    await store
        .putDay(const DayRecord(day: today - 3, plan: '{}', position: 4));
    final h = await pumpSession(
        tester, planOf([entryOf(words[0], PlanSection.due)]),
        store: store);
    await h.answer(Grade.clear);
    // Today, yesterday, two and five days ago; twenty days ago is outside the 14.
    expect(h.shows('4 of 14 days'), isTrue);
  });

  group('a resume carries the day on (PIN-5)', () {
    testWidgets(
        'at 900 seconds answered, the soft stop shows before the first resumed entry, and '
        'the ceiling still ends the session', (tester) async {
      final entries = [
        for (final w in words.take(15)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(tester, planOf(entries), position: 9);
      expect(h.onScreen, isNull, reason: 'no entry before the soft stop');
      expect(h.shows('About 15 minutes'), isTrue);
      await h.tap('Keep going');
      for (var i = 0; i < 3; i++) {
        expect(h.onScreen, entries[9 + i].itemId);
        await h.answer(Grade.clear);
      }
      // 900 before the resume and 300 since: the next entry would pass the ceiling.
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(h.shows('The rest is due tomorrow.'), isTrue);
      expect(await h.store.attempts(), hasLength(3));
      final record = await h.store.day(today);
      expect(record!.completed, isTrue);
      expect(record.position, 12);
    });

    testWidgets(
        'a skipped entry after the position still counts toward the estimate: at 800 '
        'answered and one skip, the soft stop shows first', (tester) async {
      final entries = [
        for (final w in words.take(15)) entryOf(w, PlanSection.due, cost: 100)
      ];
      // The plan as a skip of the first entry left it: moved to the end of Due, requeued;
      // eight answered since.
      final plan = planOf([
        ...entries.skip(1),
        entries[0].copyWith(requeued: true),
      ]);
      final h = await pumpSession(tester, plan, position: 8);
      expect(h.onScreen, isNull, reason: '800 + the 100 skipped is the target');
      expect(h.shows('About 15 minutes'), isTrue);
      await h.tap('Keep going');
      for (var i = 0; i < 3; i++) {
        expect(h.onScreen, entries[9 + i].itemId);
        await h.answer(Grade.clear);
      }
      // 900 before the resume and 300 since: the next entry would pass the ceiling.
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(await h.store.attempts(), hasLength(3));
    });

    testWidgets(
        'at 1200 seconds answered, the session ends on the ceiling card',
        (tester) async {
      final entries = [
        for (final w in words.take(13)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(tester, planOf(entries), position: 12);
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(h.shows('The rest is due tomorrow.'), isTrue);
      expect(h.shows('One more (10)'), isFalse);
      expect(await h.store.attempts(), isEmpty);
      final record = await h.store.day(today);
      expect(record!.completed, isTrue);
      expect(record.position, 12);
    });

    testWidgets('wrong answers after a resume re-ask inside the ceiling only',
        (tester) async {
      final entries = [
        for (final w in words.take(12)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final h = await pumpSession(tester, planOf(entries), position: 10);
      await h.tap('Keep going');
      // 1000 before the resume: two entries fit, and the wrong's re-ask does not.
      await h.answer(Grade.wrong);
      await h.answer(Grade.clear);
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(await h.store.attempts(itemId: entries[10].itemId), hasLength(1));
    });

    testWidgets(
        'the end card counts the day\'s review answers and lists the items mastered today',
        (tester) async {
      final entries = [
        for (final w in words.take(10)) entryOf(w, PlanSection.due, cost: 60)
      ];
      final store = JpStoreMemory();
      // Nine review answers today before the relaunch, one from a drill screen today and
      // one review answer yesterday: only the nine count.
      for (var i = 0; i < 9; i++) {
        await store.appendAttempt(attemptOf(words[i], today,
            i == 7 ? Grade.hinted : (i == 8 ? Grade.wrong : Grade.clear)));
      }
      await store.appendAttempt(
          attemptOf(words[20], today, Grade.clear, sessionId: 'drill-1'));
      await store.appendAttempt(attemptOf(words[21], today - 1, Grade.clear));
      await store.putMastery(MasteryState(
          itemId: words[30].id,
          status: MasteryStatus.mastered,
          masteredOn: today));
      await store.putMastery(MasteryState(
          itemId: words[31].id,
          status: MasteryStatus.mastered,
          masteredOn: today - 1));
      final h =
          await pumpSession(tester, planOf(entries), store: store, position: 9);
      expect(h.onScreen, entries[9].itemId);
      await h.answer(Grade.clear);
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('10 answered · 8 clear · 1 with help · 1 missed'), isTrue);
      expect(h.shows('Mastered today'), isTrue);
      expect(h.shows(words[30].title), isTrue);
      expect(h.shows(words[31].title), isFalse);
    });

    testWidgets('a stretch already in the stored plan is not offered again',
        (tester) async {
      final base = [for (final w in words.take(3)) entryOf(w, PlanSection.due)];
      final stretch = [
        for (final w in words.skip(3).take(kStretchNew))
          entryOf(w, PlanSection.newItems)
      ];
      // The plan as `4 more new` left it: the four after the base, all answered.
      final h = await pumpSession(
          tester,
          planOf([...base, ...stretch],
              stretchOffer: true, stretchEntries: stretch),
          position: base.length + stretch.length);
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('4 more new'), isFalse);
    });

    testWidgets(
        'a catch-up block in the stored plan keeps its lifted ceiling and is not offered '
        'again', (tester) async {
      final base = [
        for (final w in words.take(13)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(13).take(10)) entryOf(w, PlanSection.due)
      ];
      // The plan as the tap left it: the block where the ceiling fell, three answered.
      final plan = planOf([...base.take(12), ...block, base[12]],
          catchUpOffer: true, catchUpEntries: block);
      final h = await pumpSession(tester, plan, position: 15);
      // 1230 seconds answered: the soft stop shows once on this sitting, then the block runs.
      await h.tap('Keep going');
      final asked = <String>[];
      while (h.onScreen != null) {
        asked.add(h.onScreen!);
        await h.answer(Grade.clear);
      }
      expect(asked, [for (final e in block.skip(3)) e.itemId]);
      expect(h.shows('Catch up: 10 more'), isFalse);
      // The entry past the block stays due: the lifted ceiling covers the block only.
      expect(h.shows('One more (10)'), isFalse);
      expect(await h.store.attempts(itemId: base[12].itemId), isEmpty);
    });

    testWidgets(
        'a resumed catch-up block ends after the block even with room under its ceiling',
        (tester) async {
      final base = [
        for (final w in words.take(5)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(5).take(10)) entryOf(w, PlanSection.due)
      ];
      // The plan finished under the ceiling, then the tap added the block; two answered.
      final h = await pumpSession(
          tester,
          planOf([...base, ...block],
              catchUpOffer: true, catchUpEntries: block),
          position: 7);
      expect(h.onScreen, block[2].itemId);
      // The wrong's re-ask lands after the block, so the block's end stops before it.
      await h.answer(Grade.wrong);
      var more = 0;
      while (h.onScreen != null) {
        await h.answer(Grade.clear);
        more++;
      }
      expect(more, 7);
      expect(h.shows('Done for today'), isTrue);
      expect(await h.store.attempts(itemId: block[2].itemId), hasLength(1));
      expect(h.shows('Catch up: 10 more'), isFalse);
      // One more runs the re-ask under the lifted ceiling and finishes the plan: the
      // catch-up, already in the plan, is still not offered again.
      await h.tap('One more (10)');
      expect(h.onScreen, block[2].itemId);
      await h.answer(Grade.clear);
      expect(h.shows('Done for today'), isTrue);
      expect(h.shows('Catch up: 10 more'), isFalse);
    });

    testWidgets(
        'a re-ask of a catch-up item in the stored plan is not part of the block: the '
        'block still ends after its own ten', (tester) async {
      final base = [
        for (final w in words.take(5)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(5).take(10)) entryOf(w, PlanSection.due)
      ];
      // The plan as a wrong on the third block entry left it: its re-ask after the block.
      final plan = planOf([
        ...base,
        ...block,
        block[2]
            .copyWith(section: PlanSection.repair, wasDue: false, reask: true),
      ], catchUpOffer: true, catchUpEntries: block);
      final h = await pumpSession(tester, plan, position: 8);
      var more = 0;
      while (h.onScreen != null) {
        await h.answer(Grade.clear);
        more++;
      }
      expect(more, 7, reason: 'the seven block entries left, not the re-ask');
      expect(h.shows('Done for today'), isTrue);
      expect(await h.store.attempts(itemId: block[2].itemId), isEmpty);
      expect(h.shows('One more (10)'), isTrue,
          reason: 'the re-ask is still planned and fits');
    });

    testWidgets(
        'a skipped re-ask after the position counts toward the estimate: at 800 answered '
        'and its skip, the soft stop shows first', (tester) async {
      final entries = [
        for (final w in words.take(15)) entryOf(w, PlanSection.due, cost: 100)
      ];
      QueueEntry reaskOf(QueueEntry e, {bool requeued = false}) => e.copyWith(
          section: PlanSection.repair,
          wasDue: false,
          requeued: requeued,
          reask: true);
      // The plan as the live session left it: the first two entries wrong, five more
      // answered, the first re-ask skipped (moved after the second re-ask) and the second
      // re-ask answered: eight answers at the position and one skip past it.
      final plan = planOf([
        ...entries.take(7),
        reaskOf(entries[1]),
        reaskOf(entries[0], requeued: true),
        ...entries.skip(7),
      ]);
      final h = await pumpSession(tester, plan, position: 8);
      expect(h.onScreen, isNull, reason: '800 + the 100 skipped is the target');
      expect(h.shows('About 15 minutes'), isTrue);
      await h.tap('Keep going');
      expect(h.onScreen, entries[0].itemId, reason: 'the skipped re-ask');
      for (var i = 0; i < 3; i++) {
        await h.answer(Grade.clear);
      }
      // 900 before the resume and 300 since: the next entry would pass the ceiling.
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(await h.store.attempts(), hasLength(3));
    });

    testWidgets(
        'a skipped re-ask of a catch-up item is not counted into the spend before the tap: '
        'the lifted ceiling is the block\'s cost over the plan\'s ceiling',
        (tester) async {
      final base = [
        for (final w in words.take(12)) entryOf(w, PlanSection.due, cost: 100)
      ];
      final block = [
        for (final w in words.skip(12).take(10))
          entryOf(w, PlanSection.due, cost: 100)
      ];
      // The plan as the tap left it at the ceiling, then a wrong on the first block entry
      // whose re-ask landed inside the block, skipped once (it stays put as the only
      // re-ask) and then answered: the lift is the block's 1000, so the ceiling is 2200.
      final plan = planOf([
        ...base,
        ...block.take(7),
        block[0].copyWith(
            section: PlanSection.repair,
            wasDue: false,
            requeued: true,
            reask: true),
        ...block.skip(7),
      ], catchUpOffer: true, catchUpEntries: block);
      final h = await pumpSession(tester, plan, position: 20);
      // 1200 + 700 + the skip + the answer = 2100 spent: one block entry fits, not two.
      await h.tap('Keep going');
      expect(h.onScreen, block[7].itemId);
      await h.answer(Grade.clear);
      expect(h.onScreen, isNull);
      expect(h.shows("That is today's 20 minutes"), isTrue);
      expect(await h.store.attempts(itemId: block[8].itemId), isEmpty);
    });
  });

  test('the section line names the section and the place in it', () {
    final plan = planOf([
      entryOf(words[0], PlanSection.repair),
      for (final w in words.skip(1).take(42)) entryOf(w, PlanSection.due),
    ]);
    expect(sectionPosition(plan, 0), 'Repair · 1 of 1');
    expect(sectionPosition(plan, 12), 'Due · 12 of 42');
  });

  group('Review the lesson (plan 2026-11-06, Task 2, PIN-5)', () {
    final grammar = catalog.ofKind(ItemKind.grammar).first;

    /// The session under a router that knows every lesson target's route name. Each target is
    /// a stub page naming its route and query, with a Back that pops it.
    Future<Harness> pumpRouted(WidgetTester tester, DayPlan plan) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final s = JpStoreMemory();
      await s.putDay(DayRecord(day: today, plan: plan.encode(), position: 0));
      // Every item in the catalog, so a taught and an untaught particle both have a route.
      final names = {
        for (final kind in ItemKind.values)
          for (final item in catalog.ofKind(kind))
            lessonTargetOf(item).routeName
      };
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SessionWidget(
              plan: plan,
              store: s,
              clock: FixedClock(at(today)),
              catalog: catalog,
              probeBuilder: fakeProbe,
            ),
          ),
        ),
        for (final name in names)
          GoRoute(
            path: '/stub-$name',
            name: name,
            builder: (context, state) => Scaffold(
              body: Column(children: [
                Text('lesson $name ${state.uri.queryParameters}'),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back')),
              ]),
            ),
          ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final h = Harness(tester, s);
      await h.settle();
      return h;
    }

    testWidgets(
        "the link opens the kind's target, Back returns to the same unanswered card "
        'marked Lesson reviewed, and a clear after it is hinted (End state 1)',
        (tester) async {
      final plan = planOf([
        entryOf(grammar, PlanSection.due),
        entryOf(words[0], PlanSection.due),
      ]);
      final h = await pumpRouted(tester, plan);
      expect(h.onScreen, grammar.id);
      expect(find.text(kReviewTheLesson), findsOneWidget);
      expect(find.text(reviewLessonDetail(grammar)), findsOneWidget);
      expect(find.text(kLessonReviewed), findsNothing);

      await tester.tap(find.text(kReviewTheLesson));
      await tester.pumpAndSettle();
      final target = lessonTargetOf(grammar);
      expect(target.query['point'], grammar.id);
      expect(find.text('lesson ${target.routeName} ${target.query}'),
          findsOneWidget);
      expect(await h.store.attempts(), isEmpty,
          reason: 'opening a lesson writes no attempt');

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(h.onScreen, grammar.id, reason: 'the same card');
      expect(h.shows(sectionPosition(plan, 0)), isTrue);
      expect(find.text(kLessonReviewed), findsOneWidget);
      expect(await h.store.attempts(), isEmpty, reason: 'still unanswered');

      await h.tap('answer clear');
      expect(h.shows('Right with a hint'), isTrue);
      final a = (await h.store.attempts()).single;
      expect(a.itemId, grammar.id);
      expect(a.grade, Grade.hinted);
      expect(a.hintLevel, 1);
      expect(a.rating, fsrsRatingFor(Grade.hinted));
      expect(find.text(kReviewTheLesson), findsNothing,
          reason: 'an answered card has no link');

      await h.tap('Next');
      expect(h.onScreen, words[0].id);
      expect(find.text(kLessonReviewed), findsNothing,
          reason: 'a review covers its own card only');
      await h.tap('answer clear');
      expect(h.shows('Clear'), isTrue);
      expect((await h.store.attempts(itemId: words[0].id)).single.grade,
          Grade.clear);
    });

    testWidgets(
        'the link pushes the lesson target of every item kind through the router, '
        'and Back returns to the same card', (tester) async {
      // The first of each kind, plus a taught particle: the first particle has no
      // lesson, so both particle arms of lessonTargetOf go through the router.
      final items = [
        for (final kind in ItemKind.values) catalog.ofKind(kind).first,
        catalog.ofKind(ItemKind.particle).firstWhere((i) => i.lesson != null),
      ];
      for (final item in items) {
        final kind = item.kind.name;
        final h =
            await pumpRouted(tester, planOf([entryOf(item, PlanSection.due)]));
        expect(h.onScreen, item.id, reason: kind);
        expect(find.text(kLessonReviewed), findsNothing, reason: kind);

        await tester.tap(find.text(kReviewTheLesson));
        await tester.pumpAndSettle();
        final target = lessonTargetOf(item);
        expect(find.text('lesson ${target.routeName} ${target.query}'),
            findsOneWidget,
            reason: '$kind: the route and query of ${item.id}');

        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(h.onScreen, item.id, reason: '$kind: the same card');
        expect(find.text(kLessonReviewed), findsOneWidget, reason: kind);
        expect(await h.store.attempts(), isEmpty,
            reason: '$kind: opening a lesson writes no attempt');
      }
    });

    testWidgets(
        'a failed lesson open leaves the card unreviewed and a clear stays clear',
        (tester) async {
      final h = await pumpSession(
          tester, planOf([entryOf(words[0], PlanSection.due)]),
          openLesson: (context, item) async => throw StateError('no route'));
      expect(h.onScreen, words[0].id);
      await h.tap(kReviewTheLesson);
      expect(tester.takeException(), isA<StateError>(),
          reason: 'the failure is reported, not swallowed');
      expect(find.text(kLessonReviewed), findsNothing,
          reason: 'no lesson opened, so no mark');
      expect(find.text(kReviewTheLesson), findsOneWidget,
          reason: 'the link stays for another try');

      await h.tap('answer clear');
      expect(h.shows('Clear'), isTrue);
      final a = (await h.store.attempts()).single;
      expect(a.grade, Grade.clear);
      expect(a.hintLevel, 0);
    });

    testWidgets(
        'a failed open after an earlier open of the same card keeps the mark',
        (tester) async {
      var opens = 0;
      final h = await pumpSession(
          tester, planOf([entryOf(words[0], PlanSection.due)]),
          openLesson: (context, item) async {
        if (++opens > 1) throw StateError('no route');
      });
      await h.tap(kReviewTheLesson);
      expect(find.text(kLessonReviewed), findsOneWidget);
      await h.tap(kReviewTheLesson);
      expect(tester.takeException(), isA<StateError>());
      expect(find.text(kLessonReviewed), findsOneWidget,
          reason: 'the lesson was seen once, so the mark stays');

      await h.tap('answer clear');
      expect(h.shows('Right with a hint'), isTrue);
      final a = (await h.store.attempts()).single;
      expect(a.grade, Grade.hinted);
      expect(a.hintLevel, 1);
    });

    testWidgets('wrong, hinted and unscored after a review are untouched',
        (tester) async {
      final opened = <String>[];
      final h = await pumpSession(
          tester,
          planOf([
            entryOf(words[0], PlanSection.due),
            entryOf(words[1], PlanSection.due),
            entryOf(words[2], PlanSection.due),
          ]),
          openLesson: (context, item) async => opened.add(item.id));
      Future<void> review() async {
        await h.tap(kReviewTheLesson);
        expect(find.text(kLessonReviewed), findsOneWidget);
      }

      await review();
      await h.tap('answer hinted');
      await h.tap('Next');
      await review();
      await h.tap('answer unscored');
      await h.tap('Next');
      // The skip moved words[1] to the end of the section, so words[2] is next.
      expect(h.onScreen, words[2].id);
      await review();
      await h.tap('answer wrong');
      expect(find.text(kReviewTheLesson), findsNothing,
          reason: 'a held wrong has no link');

      expect(opened, [words[0].id, words[1].id, words[2].id]);
      final byId = {for (final a in await h.store.attempts()) a.itemId: a};
      expect(byId[words[0].id]!.grade, Grade.hinted);
      expect(byId[words[0].id]!.hintLevel, 1,
          reason: 'a hint and a review are not counted twice');
      expect(byId[words[1].id]!.grade, Grade.unscored);
      expect(byId[words[1].id]!.hintLevel, 0);
      expect(byId[words[2].id]!.grade, Grade.wrong);
      expect(byId[words[2].id]!.hintLevel, 0);
    });

    testWidgets('a review after the answer changes nothing', (tester) async {
      final h = await pumpSession(
          tester, planOf([entryOf(words[0], PlanSection.due)]),
          openLesson: (context, item) async {});
      await h.tap('answer clear');
      expect(h.shows('Clear'), isTrue);
      expect(find.text(kReviewTheLesson), findsNothing,
          reason: 'the verdict card offers no review');
      expect((await h.store.attempts()).single.grade, Grade.clear);
    });

    testWidgets('with no router and no opener the card shows no dead link',
        (tester) async {
      final h = await pumpSession(
          tester, planOf([entryOf(words[0], PlanSection.due)]));
      expect(h.onScreen, words[0].id);
      expect(find.text(kReviewTheLesson), findsNothing);
    });
  });
}
