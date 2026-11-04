// The 120-day simulator (Task 16, End state 8, PIN-5, PIN-6, PIN-7). A synthetic learner
// (test/support/synthetic_learner.dart: 85% clear while retrievable, otherwise the chance
// tracks retrievability, the rest 45% hinted and 55% wrong) answers the shipped catalog's items
// through their real probes and templates for 120 days, through `buildPlan`, the FSRS scheduler
// and the mastery rule, with a memory store and an injected clock. Four runs: from scratch
// (A), with a 10-day break on days 50 to 59 (B), seeded per `seedFromLessons` (C), and with the
// stretch taken whenever the end card offers it (D). The test prints each run's summary and a
// 10-day table, so the simulator numbers in the plan's Context can be re-measured here.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/attempt.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/item_catalog.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/plan_builder.dart';

import 'support/synthetic_learner.dart';

Map<String, dynamic> _read(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

final catalog = ItemCatalog.fromDocs(_read('assets/lessons/jp_grammar.json'),
    _read('assets/lessons/jp_lessons.json'));

/// The days of run B's break.
final Set<int> breakDays = {for (var d = 50; d < 60; d++) d};

void main() {
  late SimRun scratch, withBreak, seeded, stretch;

  setUpAll(() async {
    scratch =
        await simulate(const SimConfig(label: 'A, from scratch'), catalog);
    withBreak = await simulate(
        SimConfig(label: 'B, a break on days 50 to 59', breakDays: breakDays),
        catalog);
    seeded = await simulate(
        const SimConfig(label: 'C, seeded', seeded: true), catalog);
    stretch = await simulate(
        const SimConfig(label: 'D, the stretch taken', takeStretch: true),
        catalog);
    for (final run in [scratch, withBreak, seeded, stretch]) {
      // The run summaries are the test's output: the plan's Context numbers come from here.
      // ignore: avoid_print
      print('\n${run.table()}${run.summary()}');
    }
  });

  List<SimRun> all() => [scratch, withBreak, seeded, stretch];

  test('every run answers under the 15-minute target on average (PIN-5)', () {
    for (final run in all()) {
      expect(run.meanSeconds, lessThan(kTargetSeconds), reason: run.summary());
    }
  });

  test(
      'no session passes the 20-minute ceiling and no plan fills past the '
      'ceiling less the repair slot (PIN-5)', () {
    for (final run in all()) {
      // Holds by the harness hard stop: `ask` refuses any answer that would pass the ceiling
      // (session behavior, PIN-5). The planner check is `peakPlannedSeconds` below.
      expect(run.peakSeconds, lessThanOrEqualTo(kCeilingSeconds),
          reason: run.summary());
      expect(run.peakPlannedSeconds,
          lessThanOrEqualTo(kCeilingSeconds - kRepairSlotSeconds),
          reason: run.summary());
    }
  });

  test('from scratch, no session leaves a due item behind', () {
    for (final day in scratch.days) {
      expect(day.backlogAfter, 0,
          reason: 'day ${day.day}: ${scratch.summary()}');
    }
  });

  test(
      'from scratch, a first item is Mastered before day 70 and at least 200 '
      'by day 120', () {
    expect(scratch.firstMasteredDay, isNotNull, reason: scratch.summary());
    expect(scratch.firstMasteredDay!, lessThan(70), reason: scratch.summary());
    expect(scratch.masteredEnd, greaterThanOrEqualTo(200),
        reason: scratch.summary());
  });

  test('the seeded run clears its backlog before day 45 (PIN-8)', () {
    expect(seeded.peakBacklog, greaterThan(0),
        reason: 'the seed should start with more due than one session holds');
    expect(seeded.lastBacklogDay, isNotNull);
    expect(seeded.lastBacklogDay!, lessThan(45), reason: seeded.summary());
  });

  test(
      'the seeded run masters nothing before real answers earn it and, by '
      'day 120, at least one item of every kind (PIN-7)', () {
    // Four counting clears with the last 21 or more days after the one before need at least
    // four sessions spread over about a month.
    expect(seeded.firstMasteredDay, isNotNull, reason: seeded.summary());
    expect(seeded.firstMasteredDay!, greaterThanOrEqualTo(21),
        reason: seeded.summary());
    final byKind = seeded.masteredByKind;
    for (final kind in ItemKind.values) {
      expect(byKind[kind], greaterThan(0),
          reason: '${kind.name}: ${seeded.summary()}');
    }
  });

  test(
      'the stretch is never offered with repairs or due items left, and is '
      'taken when offered in run D (PIN-6)', () {
    for (final run in all()) {
      for (final day in run.days) {
        expect(day.stretchWithWorkLeft, isFalse,
            reason: 'run ${run.config.label}, day ${day.day}');
        if (day.stretchOffered) {
          // These two restate how the harness builds `stretchOffered` (the plan offered it,
          // every entry was answered, the ceiling left room). The real check is
          // `stretchWithWorkLeft` above, which reads the store on its own.
          expect(day.planStretchOffer, isTrue);
          expect(day.hitCeiling, isFalse);
        }
      }
    }
    // The checks above are not vacuous: the plan offered the stretch, and run D took it.
    expect(stretch.stretchOfferedDays, greaterThan(0));
    expect(stretch.stretchTaken, greaterThan(0));
    expect(scratch.stretchTaken, 0);
    // The stretch adds items without breaking the budget, and masters more by day 120.
    expect(stretch.masteredEnd, greaterThan(scratch.masteredEnd));
  });

  test(
      'the break pauses New on the return and the backlog clears after it (PIN-9)',
      () {
    final back = withBreak.days[breakDays.reduce((a, b) => a > b ? a : b) + 1];
    expect(back.returnMode, isTrue);
    expect(back.newItems, 0);
    expect(back.newSkip, NewSkip.daysMissed);
    // The break leaves a backlog, gone within two weeks of the return.
    expect(withBreak.peakBacklog, greaterThan(0));
    // `lastBacklogDay` reads active days only, so a null (no backlog left after the return)
    // is the outcome this test wants, not a failure.
    expect((withBreak.lastBacklogDay ?? 0), lessThan(back.day + 14),
        reason: withBreak.summary());
  });
}
