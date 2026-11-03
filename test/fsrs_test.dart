// Tests for the vendored FSRS-6 scheduler and the Leitner fallback (D12, D13).
//
// The golden sequence in test/fixtures/fsrs_golden.json was produced once by py-fsrs, the
// reference implementation dart-fsrs ports. If the vendored code drifts from it, the golden
// test goes red and the Leitner fallback is the documented switch (A3).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/fsrs.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/leitner.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/scheduler.dart';

SrsRating _rating(int value) => SrsRating.fromValue(value);

void main() {
  group('FSRS golden sequence from py-fsrs', () {
    final golden =
        jsonDecode(File('test/fixtures/fsrs_golden.json').readAsStringSync())
            as Map<String, dynamic>;
    final reviews = (golden['reviews'] as List).cast<Map<String, dynamic>>();

    test('the fixture is dated and holds 40 reviews', () {
      expect(golden['recorded'], isA<String>());
      expect(reviews, hasLength(40));
    });

    test('the fixture was recorded with the vendored parameters and limits',
        () {
      final config = golden['scheduler'] as Map<String, dynamic>;
      final params = (config['parameters'] as List).cast<num>();
      expect(params, hasLength(fsrsDefaultParameters.length));
      for (var i = 0; i < params.length; i++) {
        expect(params[i].toDouble(), fsrsDefaultParameters[i], reason: 'w$i');
      }
      expect(config['desiredRetention'], fsrsDesiredRetention);
      expect(config['maximumInterval'], fsrsMaximumInterval);
      expect(config['learningSteps'], isEmpty);
      expect(config['relearningSteps'], isEmpty);
      expect(config['enableFuzzing'], isFalse);
    });

    test('stability, difficulty and interval match to 1e-6', () {
      const scheduler = FsrsScheduler();
      SrsState? state;
      var day = 1000;
      for (var i = 0; i < reviews.length; i++) {
        final row = reviews[i];
        final rating = _rating(row['rating'] as int);
        if (state == null) {
          state = scheduler.first(rating, day);
        } else {
          final gap = row['gapDays'] as int;
          day += gap;
          final rBefore = scheduler.retrievability(state, day);
          expect(rBefore,
              closeTo((row['retrievabilityBefore'] as num).toDouble(), 1e-6),
              reason: 'R before review $i');
          state = scheduler.review(state, rating, day, sameDay: gap == 0);
        }
        expect(state.stability,
            closeTo((row['stability'] as num).toDouble(), 1e-6),
            reason: 'stability after review $i');
        expect(state.difficulty,
            closeTo((row['difficulty'] as num).toDouble(), 1e-6),
            reason: 'difficulty after review $i');
        expect(state.interval, row['interval'],
            reason: 'interval after review $i');
        expect(state.dueDay, day + state.interval);
        expect(state.lastReviewDay, day);
      }
    });

    test('the same-day flag defaults to comparing the days', () {
      const scheduler = FsrsScheduler();
      final first = scheduler.first(SrsRating.good, 10);
      expect(scheduler.review(first, SrsRating.good, 10).stability,
          scheduler.review(first, SrsRating.good, 10, sameDay: true).stability);
      expect(
          scheduler.review(first, SrsRating.good, 13).stability,
          scheduler
              .review(first, SrsRating.good, 13, sameDay: false)
              .stability);
    });
  });

  group('FSRS properties', () {
    const scheduler = FsrsScheduler();

    // A seeded random walk over ratings and gaps, the gaps including same-day reviews and
    // returns long after the due date.
    List<(SrsState, SrsRating, SrsState)> walk(int seed, int length) {
      final random = math.Random(seed);
      final steps = <(SrsState, SrsRating, SrsState)>[];
      var day = 0;
      var state = scheduler.first(SrsRating.values[random.nextInt(4)], day);
      for (var i = 0; i < length; i++) {
        final gaps = [
          0,
          1,
          state.interval,
          state.interval * 2,
          random.nextInt(200)
        ];
        day += gaps[random.nextInt(gaps.length)];
        final rating = SrsRating.values[random.nextInt(4)];
        final next = scheduler.review(state, rating, day);
        steps.add((state, rating, next));
        state = next;
      }
      return steps;
    }

    final steps = [for (var seed = 0; seed < 40; seed++) ...walk(seed, 60)];

    test('Good never lowers stability', () {
      for (final (before, rating, after) in steps) {
        if (rating != SrsRating.good) continue;
        expect(after.stability, greaterThanOrEqualTo(before.stability));
      }
    });

    test('Again never raises stability', () {
      for (final (before, rating, after) in steps) {
        if (rating != SrsRating.again) continue;
        expect(after.stability, lessThanOrEqualTo(before.stability));
      }
    });

    test('a lapse after a long gap keeps stability at or below the old one',
        () {
      // The long-term forget formula grows with S; the min() clauses keep it under S.
      for (final s in [0.5, 3.0, 30.0, 90.0, 400.0]) {
        final state = SrsState(
            stability: s,
            difficulty: 1.0,
            lastReviewDay: 0,
            dueDay: 1,
            interval: 1);
        expect(scheduler.review(state, SrsRating.again, 1000).stability,
            lessThanOrEqualTo(s));
        expect(scheduler.review(state, SrsRating.again, 0).stability,
            lessThanOrEqualTo(s));
      }
    });

    test('intervals stay in 1 to 90 days', () {
      for (final (_, _, after) in steps) {
        expect(after.interval, inInclusiveRange(1, fsrsMaximumInterval));
      }
      for (final rating in SrsRating.values) {
        expect(scheduler.first(rating, 0).interval, inInclusiveRange(1, 90));
      }
    });

    test('retrievability at the stability equals 0.9', () {
      for (final s in [0.4, 1.0, 2.5, 7.0, 33.3, 90.0, 365.0]) {
        expect(fsrsRetrievability(elapsedDays: s, stability: s),
            closeTo(0.9, 1e-12));
      }
      const state = SrsState(
          stability: 12.0,
          difficulty: 5.0,
          lastReviewDay: 100,
          dueDay: 111,
          interval: 11);
      expect(scheduler.retrievability(state, 112), closeTo(0.9, 1e-12));
      expect(scheduler.retrievability(state, 100), 1.0);
    });

    test('desired retention and maximum interval are 0.90 and 90', () {
      expect(fsrsDesiredRetention, 0.90);
      expect(fsrsMaximumInterval, 90);
    });
  });

  group('nextDue load spreading', () {
    const scheduler = FsrsScheduler();
    SrsState stateWith(int interval) => SrsState(
        stability: interval.toDouble(),
        difficulty: 5.0,
        lastReviewDay: 100,
        dueDay: 100 + interval,
        interval: interval);

    test('an empty load keeps the nominal due day', () {
      expect(scheduler.nextDue(stateWith(40), const {}), 140);
      expect(scheduler.nextDue(stateWith(1), const {}), 101);
    });

    test('picks the least-loaded day within 5% of the interval', () {
      // 5% of 40 is 2, so days 138 to 142 are candidates.
      final load = {138: 9, 139: 4, 140: 7, 141: 2, 142: 2, 143: 0, 137: 0};
      expect(scheduler.nextDue(stateWith(40), load), 141);
    });

    test('ties go to the day closest to the nominal one, then the earlier', () {
      expect(
          scheduler
              .nextDue(stateWith(40), {138: 3, 139: 1, 140: 5, 141: 1, 142: 3}),
          139);
    });

    test('short intervals are not moved', () {
      expect(scheduler.nextDue(stateWith(5), {105: 50, 104: 0, 106: 0}), 105);
      expect(scheduler.nextDue(stateWith(1), {101: 50, 102: 0}), 101);
    });

    test('never moves past the 90-day cap', () {
      final load = {for (var d = 186; d <= 190; d++) d: 10, 194: 0, 195: 0};
      // 5% of 90 rounds to 5: the window is 85 to 95 days, cut at 90.
      final due = scheduler.nextDue(stateWith(90), load);
      expect(due, 185);
      expect(
          scheduler
              .nextDue(stateWith(90), {for (var d = 185; d <= 190; d++) d: 10}),
          inInclusiveRange(185, 190));
    });
  });

  group('SrsState', () {
    test('round-trips through JSON', () {
      const state = SrsState(
          stability: 3.25,
          difficulty: 6.5,
          lastReviewDay: 20,
          dueDay: 23,
          interval: 3,
          reps: 4,
          lapses: 1,
          box: 2);
      expect(SrsState.fromJson(state.toJson()), state);
    });
  });

  group('Leitner fallback', () {
    const leitner = LeitnerScheduler();

    test('the boxes are 1, 3, 7, 14, 30, 60 and 90 days', () {
      expect(leitnerBoxDays, [1, 3, 7, 14, 30, 60, 90]);
    });

    test('a first clear lands in the first box, any first answer does', () {
      for (final rating in SrsRating.values) {
        final s = leitner.first(rating, 5);
        expect(s.box, 0);
        expect(s.interval, 1);
        expect(s.dueDay, 6);
      }
    });

    SrsState inBox(int box, int day) => SrsState(
        stability: leitnerBoxDays[box].toDouble(),
        difficulty: 0,
        lastReviewDay: day,
        dueDay: day + leitnerBoxDays[box],
        interval: leitnerBoxDays[box],
        box: box);

    test('a clear on time moves up one box', () {
      final s = leitner.review(inBox(2, 0), SrsRating.good, 7);
      expect(s.box, 3);
      expect(s.interval, 14);
      expect(s.dueDay, 21);
    });

    test('a clear more than 50% late moves up two boxes', () {
      // Box 2 is 7 days; 50% late is 10.5 days, so day 11 is more than 50% late.
      expect(leitner.review(inBox(2, 0), SrsRating.good, 10).box, 3);
      expect(leitner.review(inBox(2, 0), SrsRating.good, 11).box, 4);
    });

    test('a hinted answer stays in its box', () {
      final s = leitner.review(inBox(3, 0), SrsRating.hard, 14);
      expect(s.box, 3);
      expect(s.interval, 14);
      expect(s.dueDay, 28);
    });

    test('a wrong answer moves down two boxes, never below the first', () {
      expect(leitner.review(inBox(4, 0), SrsRating.again, 30).box, 2);
      expect(leitner.review(inBox(1, 0), SrsRating.again, 3).box, 0);
      expect(leitner.review(inBox(1, 0), SrsRating.again, 3).lapses, 1);
    });

    test('the top box holds and never exceeds 90 days', () {
      final s = leitner.review(inBox(6, 0), SrsRating.good, 200);
      expect(s.box, 6);
      expect(s.interval, 90);
    });

    test('a same-day clear changes nothing, a same-day wrong counts', () {
      final start = inBox(3, 0);
      final clear = leitner.review(start, SrsRating.good, 0);
      expect(clear.box, 3);
      expect(clear.dueDay, start.dueDay);
      expect(leitner.review(start, SrsRating.again, 0).box, 1);
    });

    test('retrievability at the box interval is 0.9', () {
      final s = inBox(4, 0);
      expect(leitner.retrievability(s, 30), closeTo(0.9, 1e-12));
      expect(leitner.retrievability(s, 0), 1.0);
      expect(leitner.retrievability(s, 60), lessThan(0.9));
    });

    test('shares the load spreading of the interface', () {
      final s = inBox(5, 100);
      // Box 5 is 60 days; 5% is 3, so days 157 to 163 are candidates.
      final load = {157: 1, 158: 4, 159: 3, 160: 9, 161: 5, 162: 6, 163: 2};
      expect(leitner.nextDue(s, load), 157);
    });
  });
}
