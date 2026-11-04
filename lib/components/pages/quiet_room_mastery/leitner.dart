// The time-aware Leitner fallback behind the same `Scheduler` interface as FSRS-6 (D13).
//
// It is the switch if the vendored FSRS ever drifts from py-fsrs (A3). The rules are simple
// enough to explain on an item page:
// - the boxes are 1, 3, 7, 14, 30, 60 and 90 days, and every first answer lands in the first;
// - a clear (Good or Easy) moves up one box, or two when the answer came more than 50% late;
// - a hinted answer (Hard) stays in its box and restarts its interval;
// - a wrong answer (Again) moves down two boxes, never below the first;
// - a second answer on the same day changes nothing unless it is wrong.

import 'dart:math' as math;

import 'scheduler.dart';

/// The box intervals in days. The last one is the 90-day cap (PIN-2).
const List<int> leitnerBoxDays = [1, 3, 7, 14, 30, 60, 90];

/// The lateness beyond which a clear skips a box: more than half the interval late.
const double leitnerLateFraction = 0.5;

class LeitnerScheduler extends Scheduler {
  const LeitnerScheduler();

  @override
  int get maximumInterval => leitnerBoxDays.last;

  SrsState _inBox(int box, int day, {required int reps, required int lapses}) {
    final interval = leitnerBoxDays[box];
    return SrsState(
      stability: interval.toDouble(),
      difficulty: 0,
      lastReviewDay: day,
      dueDay: day + interval,
      interval: interval,
      reps: reps,
      lapses: lapses,
      box: box,
    );
  }

  @override
  SrsState first(SrsRating rating, int day) =>
      _inBox(0, day, reps: 1, lapses: rating == SrsRating.again ? 1 : 0);

  @override
  SrsState review(SrsState state, SrsRating rating, int day, {bool? sameDay}) {
    final isSameDay = sameDay ?? day <= state.lastReviewDay;
    final reps = state.reps + 1;
    if (rating == SrsRating.again) {
      return _inBox(math.max(state.box - 2, 0), day,
          reps: reps, lapses: state.lapses + 1);
    }
    if (isSameDay) {
      return state.copyWith(reps: reps);
    }
    if (rating == SrsRating.hard) {
      return _inBox(state.box, day, reps: reps, lapses: state.lapses);
    }
    final elapsed = day - state.lastReviewDay;
    final late = elapsed > state.interval * (1 + leitnerLateFraction);
    final box = math.min(state.box + (late ? 2 : 1), leitnerBoxDays.length - 1);
    return _inBox(box, day, reps: reps, lapses: state.lapses);
  }

  /// 0.9 raised to the days since the last review over the box interval: 0.9 at the interval,
  /// the same anchor FSRS uses, so the plan builder can sort either scheduler's items.
  @override
  double retrievability(SrsState state, int day) {
    final elapsed = math.max(0, day - state.lastReviewDay);
    return math.pow(0.9, elapsed / state.interval).toDouble();
  }
}
