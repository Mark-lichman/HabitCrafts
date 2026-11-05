// Widget tests for the Review session (plan 2026-11-02, Task 18, End state 10).
//
// The session walks a hand-built `DayPlan` over the shipped catalog on a memory store with an
// injected clock. A fake probe builder stands in for the probe widgets (tested on their own in
// probe_widgets_test.dart): it shows four buttons that hand on a clear, a hinted, a wrong or an
// unscored draft. The cases: the section order and the "Due · 1 of 2" line, the attempt written
// at answer time with the entry's `wasDue` and source (ASK-6), the no-credit card (PIN-3), the
// Clear and Mastered cards, the repair re-ask about 10 minutes later and not due (PIN-11), the
// soft stop at the target with Stop and Keep going, the end at the ceiling with the rest left
// due (PIN-5), One more (10) inside the ceiling, the catch-up only when the plan offers it and
// only on a tap (PIN-12), the stretch only under its conditions (PIN-6), and the 14 dots over
// the days whose session completed.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/drill_recorder.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/jp_store_memory.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/mastery_rule.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/plan_builder.dart';
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

Future<Harness> pumpSession(WidgetTester tester, DayPlan plan,
    {JpStoreMemory? store}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final s = store ?? JpStoreMemory();
  await s.putDay(DayRecord(day: today, plan: plan.encode()));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SessionWidget(
        plan: plan,
        store: s,
        clock: FixedClock(at(today)),
        catalog: catalog,
        probeBuilder: fakeProbe,
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
    expect((await store.mastery(particle.id))!.status, MasteryStatus.mastered);
    await h.tap('Next');
    expect(h.shows('Mastered today'), isTrue);
    expect(h.shows(particle.title), isTrue);
  });

  testWidgets(
      'a wrong shows Not this time and is re-asked about 10 minutes later in the same '
      'session, as a not-due Repair (PIN-11)', (tester) async {
    final rest = [
      for (final w in words.skip(1).take(8))
        entryOf(w, PlanSection.due, cost: 100)
    ];
    final plan = planOf(
        [entryOf(words[0], PlanSection.due, cost: 100), ...rest],
        target: 10000, ceiling: 20000);
    final h = await pumpSession(tester, plan);
    await h.tap('answer wrong');
    expect(h.shows('Not this time'), isTrue);
    expect(h.shows('It comes back in about 10 minutes, and again tomorrow.'),
        isTrue);
    await h.tap('Next');
    // Six entries of 100 seconds come first: about 10 minutes of answers.
    for (var i = 0; i < 6; i++) {
      expect(h.onScreen, rest[i].itemId);
      await h.answer(Grade.clear);
    }
    expect(h.onScreen, words[0].id);
    expect(h.shows('Repair · 1 of 1'), isTrue);
    await h.answer(Grade.clear);
    final onItem = await h.store.attempts(itemId: words[0].id);
    expect([for (final a in onItem) a.grade], [Grade.wrong, Grade.clear]);
    expect([for (final a in onItem) a.wasDue], [true, false]);
    // A not-due clear starts no run of counting clears.
    expect((await h.store.mastery(words[0].id))!.clearCount, 0);
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
    expect(h.shows('15 answered · 15 clear · 0 with help · 0 not this time'),
        isTrue);
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

  test('the section line names the section and the place in it', () {
    final plan = planOf([
      entryOf(words[0], PlanSection.repair),
      for (final w in words.skip(1).take(42)) entryOf(w, PlanSection.due),
    ]);
    expect(sectionPosition(plan, 0), 'Repair · 1 of 1');
    expect(sectionPosition(plan, 12), 'Due · 12 of 42');
  });
}
