// FSRS-6, vendored from dart-fsrs (D13).
//
// Source: https://github.com/open-spaced-repetition/dart-fsrs, pub.dev `fsrs` 2.0.1,
// commit cd3df9cc5e3021be4940fa2c7b9aa46ce99a565b (2025-06-20), file lib/fsrs.dart.
// dart-fsrs is a port of py-fsrs. test/fixtures/fsrs_golden.json holds py-fsrs 6.3.2 output
// for the same parameters, and test/fsrs_test.dart reproduces it to 1e-6.
//
// Changes from the upstream file:
// - Learning and relearning steps are removed. Every scored answer, the first included,
//   schedules in whole days, and an Again keeps the item in review with an interval from its
//   new stability (py-fsrs with `learning_steps=()` and `relearning_steps=()`).
// - Fuzzing is removed. `Scheduler.nextDue` spreads due days over the load instead (D12).
// - Desired retention and the maximum interval are named constants, 0.90 and 90 days.
// - Days are local day numbers (D15), not UTC timestamps, and the state is `SrsState`.
// - Two details follow py-fsrs 6.3.2 where dart-fsrs 2.0.1 differs: a same-day Hard has its
//   stability increase floored at 1, as Good and Easy do, and the mean-reversion target of
//   the next difficulty is the unclamped initial difficulty of Easy. Intervals round half to
//   even, as Python's round() does.
// - The post-lapse stability is never above the old one: an Again takes the minimum of the
//   computed stability and the stability before the answer.
//
// MIT License
//
// Copyright (c) 2022 Open Spaced Repetition
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'dart:math' as math;

import 'scheduler.dart';

/// The FSRS-6 parameter set dart-fsrs 2.0.1 ships as its default (21 weights).
const List<double> fsrsDefaultParameters = [
  0.2172,
  1.1771,
  3.2602,
  16.1507,
  7.0114,
  0.57,
  2.0966,
  0.0069,
  1.5261,
  0.112,
  1.0178,
  1.849,
  0.1133,
  0.3127,
  2.2934,
  0.2191,
  3.0004,
  0.7536,
  0.3332,
  0.1437,
  0.2,
];

/// The recall chance the intervals aim for (D12).
const double fsrsDesiredRetention = 0.90;

/// The longest interval in days. A Mastered item keeps returning at least this often (PIN-2).
const int fsrsMaximumInterval = 90;

const double _stabilityMin = 0.001;
const double _minDifficulty = 1.0;
const double _maxDifficulty = 10.0;

final double _decay = -fsrsDefaultParameters[20];
final double _factor = math.pow(0.9, 1 / _decay) - 1;

/// FSRS-6 retrievability after `elapsedDays` at `stability`. It is 0.9 when they are equal.
double fsrsRetrievability(
        {required double elapsedDays, required double stability}) =>
    math.pow(1 + _factor * elapsedDays / stability, _decay).toDouble();

/// The FSRS-6 scheduler with the default parameters, no learning steps and no fuzz.
class FsrsScheduler extends Scheduler {
  const FsrsScheduler();

  List<double> get _w => fsrsDefaultParameters;

  @override
  int get maximumInterval => fsrsMaximumInterval;

  @override
  SrsState first(SrsRating rating, int day) {
    final stability = _initialStability(rating);
    final difficulty = _clampDifficulty(_initialDifficulty(rating));
    final interval = _nextInterval(stability);
    return SrsState(
      stability: stability,
      difficulty: difficulty,
      lastReviewDay: day,
      dueDay: day + interval,
      interval: interval,
      reps: 1,
      lapses: rating == SrsRating.again ? 1 : 0,
    );
  }

  @override
  SrsState review(SrsState state, SrsRating rating, int day, {bool? sameDay}) {
    final isSameDay = sameDay ?? day <= state.lastReviewDay;
    var stability = isSameDay
        ? _shortTermStability(state.stability, rating)
        : _nextStability(
            difficulty: state.difficulty,
            stability: state.stability,
            retrievability: retrievability(state, day),
            rating: rating,
          );
    if (rating == SrsRating.again) {
      stability = math.min(stability, state.stability);
    }
    final difficulty = _nextDifficulty(state.difficulty, rating);
    final interval = _nextInterval(stability);
    return state.copyWith(
      stability: stability,
      difficulty: difficulty,
      lastReviewDay: day,
      dueDay: day + interval,
      interval: interval,
      reps: state.reps + 1,
      lapses: state.lapses + (rating == SrsRating.again ? 1 : 0),
    );
  }

  @override
  double retrievability(SrsState state, int day) {
    final elapsed = math.max(0, day - state.lastReviewDay);
    return fsrsRetrievability(
        elapsedDays: elapsed.toDouble(), stability: state.stability);
  }

  double _clampDifficulty(double difficulty) =>
      difficulty.clamp(_minDifficulty, _maxDifficulty).toDouble();

  double _clampStability(double stability) =>
      math.max(stability, _stabilityMin);

  double _initialStability(SrsRating rating) =>
      _clampStability(_w[rating.value - 1]);

  double _initialDifficulty(SrsRating rating) =>
      _w[4] - math.exp(_w[5] * (rating.value - 1)) + 1;

  int _nextInterval(double stability) {
    final raw = (stability / _factor) *
        (math.pow(fsrsDesiredRetention, 1 / _decay) - 1);
    // Intervals are whole days, at least 1, at most the maximum.
    return math.min(math.max(_roundHalfEven(raw), 1), fsrsMaximumInterval);
  }

  double _shortTermStability(double stability, SrsRating rating) {
    var increase = math.exp(_w[17] * (rating.value - 3 + _w[18])) *
        math.pow(stability, -_w[19]);
    if (rating != SrsRating.again) {
      increase = math.max(increase, 1.0);
    }
    return _clampStability(stability * increase);
  }

  double _nextDifficulty(double difficulty, SrsRating rating) {
    final target = _initialDifficulty(SrsRating.easy);
    final delta = -(_w[6] * (rating.value - 3));
    final damped = difficulty + (10.0 - difficulty) * delta / 9.0;
    return _clampDifficulty(_w[7] * target + (1 - _w[7]) * damped);
  }

  double _nextStability({
    required double difficulty,
    required double stability,
    required double retrievability,
    required SrsRating rating,
  }) {
    final next = rating == SrsRating.again
        ? _nextForgetStability(difficulty, stability, retrievability)
        : _nextRecallStability(difficulty, stability, retrievability, rating);
    return _clampStability(next);
  }

  double _nextForgetStability(
      double difficulty, double stability, double retrievability) {
    final longTerm = _w[11] *
        math.pow(difficulty, -_w[12]) *
        (math.pow(stability + 1, _w[13]) - 1) *
        math.exp((1 - retrievability) * _w[14]);
    final shortTerm = stability / math.exp(_w[17] * _w[18]);
    return math.min(longTerm, shortTerm);
  }

  double _nextRecallStability(double difficulty, double stability,
      double retrievability, SrsRating rating) {
    final hardPenalty = rating == SrsRating.hard ? _w[15] : 1.0;
    final easyBonus = rating == SrsRating.easy ? _w[16] : 1.0;
    return stability *
        (1 +
            math.exp(_w[8]) *
                (11 - difficulty) *
                math.pow(stability, -_w[9]) *
                (math.exp((1 - retrievability) * _w[10]) - 1) *
                hardPenalty *
                easyBonus);
  }
}

/// Python's `round()`: halves go to the even neighbour. py-fsrs rounds intervals this way.
int _roundHalfEven(double value) {
  final floor = value.floorToDouble();
  final diff = value - floor;
  if (diff > 0.5) return floor.toInt() + 1;
  if (diff < 0.5) return floor.toInt();
  return floor.toInt().isEven ? floor.toInt() : floor.toInt() + 1;
}
