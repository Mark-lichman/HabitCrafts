// The scheduling interface shared by FSRS-6 (fsrs.dart) and the time-aware Leitner fallback
// (leitner.dart), so the store, the plan builder and the session never name an algorithm
// (D12, D13).
//
// Days are local day numbers: whole integers, one per 04:00-to-04:00 local day (D15). The
// scheduler never reads a clock. Callers turn a moment into a day with `localDay()` and pass
// the number in, which keeps every function here pure and replayable from the attempt log.

/// The four answer ratings FSRS knows. The grade mapping (D12, D17) uses Good for clear, Hard
/// for hinted and for a self override, and Again for wrong and for a revealed machine-checked
/// probe. Easy exists for fidelity with FSRS and is never produced by a grade.
enum SrsRating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const SrsRating(this.value);

  /// The FSRS numeric rating, 1 to 4.
  final int value;

  static SrsRating fromValue(int value) => switch (value) {
        1 => SrsRating.again,
        2 => SrsRating.hard,
        3 => SrsRating.good,
        4 => SrsRating.easy,
        _ => throw ArgumentError('Invalid rating value: $value'),
      };
}

/// An item's scheduling state after at least one scored answer. A New or seeded item has no
/// `SrsState` (D26).
class SrsState {
  /// FSRS memory stability in days. For Leitner, the current box's interval in days.
  final double stability;

  /// FSRS difficulty, 1 to 10. Leitner does not use it and stores 0.
  final double difficulty;

  /// The local day of the last scored review.
  final int lastReviewDay;

  /// The local day the item is next due. `review` sets the nominal day
  /// (`lastReviewDay + interval`); `Scheduler.nextDue` spreads it over the load.
  final int dueDay;

  /// The scheduled interval in whole days, 1 to 90.
  final int interval;

  /// Scored reviews so far.
  final int reps;

  /// Again ratings so far.
  final int lapses;

  /// The Leitner box index into `leitnerBoxDays`. FSRS leaves it at 0.
  final int box;

  const SrsState({
    required this.stability,
    required this.difficulty,
    required this.lastReviewDay,
    required this.dueDay,
    required this.interval,
    this.reps = 0,
    this.lapses = 0,
    this.box = 0,
  });

  SrsState copyWith({
    double? stability,
    double? difficulty,
    int? lastReviewDay,
    int? dueDay,
    int? interval,
    int? reps,
    int? lapses,
    int? box,
  }) =>
      SrsState(
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        lastReviewDay: lastReviewDay ?? this.lastReviewDay,
        dueDay: dueDay ?? this.dueDay,
        interval: interval ?? this.interval,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        box: box ?? this.box,
      );

  Map<String, dynamic> toJson() => {
        'stability': stability,
        'difficulty': difficulty,
        'lastReviewDay': lastReviewDay,
        'dueDay': dueDay,
        'interval': interval,
        'reps': reps,
        'lapses': lapses,
        'box': box,
      };

  static SrsState fromJson(Map<String, dynamic> json) => SrsState(
        stability: (json['stability'] as num).toDouble(),
        difficulty: (json['difficulty'] as num).toDouble(),
        lastReviewDay: json['lastReviewDay'] as int,
        dueDay: json['dueDay'] as int,
        interval: json['interval'] as int,
        reps: (json['reps'] as int?) ?? 0,
        lapses: (json['lapses'] as int?) ?? 0,
        box: (json['box'] as int?) ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is SrsState &&
      other.stability == stability &&
      other.difficulty == difficulty &&
      other.lastReviewDay == lastReviewDay &&
      other.dueDay == dueDay &&
      other.interval == interval &&
      other.reps == reps &&
      other.lapses == lapses &&
      other.box == box;

  @override
  int get hashCode => Object.hash(stability, difficulty, lastReviewDay, dueDay,
      interval, reps, lapses, box);

  @override
  String toString() =>
      'SrsState(S: $stability, D: $difficulty, last: $lastReviewDay, '
      'due: $dueDay, interval: $interval, reps: $reps, lapses: $lapses, box: $box)';
}

/// The share of an interval the due day may move to a less-loaded day (D12).
const double loadSpreadFraction = 0.05;

/// One scheduling algorithm. Every method is pure.
abstract class Scheduler {
  const Scheduler();

  /// The longest interval this scheduler ever gives, in days (90, D12, PIN-2).
  int get maximumInterval;

  /// The state after an item's first scored answer, given on `day`.
  SrsState first(SrsRating rating, int day);

  /// The state after a scored answer on `day`. `sameDay` marks a second scored answer on the
  /// day of the last one; when omitted it is `day <= state.lastReviewDay`.
  SrsState review(SrsState state, SrsRating rating, int day, {bool? sameDay});

  /// The predicted chance of recall on `day`, 0 to 1. It equals 0.9 when the days since the
  /// last review equal the stability.
  double retrievability(SrsState state, int day);

  /// The due day after load spreading: the least-loaded day within 5% of the interval of the
  /// nominal due day, never past `maximumInterval` and never before one day after the last
  /// review. Ties go to the day closest to the nominal one, then the earlier. `loadByDay`
  /// maps a local day to the items already due on it; a missing day has no load.
  int nextDue(SrsState state, Map<int, int> loadByDay) =>
      spreadDueDay(state, loadByDay, maximumInterval: maximumInterval);
}

/// The load spreading behind `Scheduler.nextDue`, shared by every scheduler.
int spreadDueDay(SrsState state, Map<int, int> loadByDay,
    {required int maximumInterval}) {
  final interval = state.interval;
  final delta = (interval * loadSpreadFraction).round();
  final low = (interval - delta).clamp(1, maximumInterval);
  final high = (interval + delta).clamp(1, maximumInterval);
  var best = state.lastReviewDay + interval.clamp(1, maximumInterval);
  var bestLoad = loadByDay[best] ?? 0;
  var bestDistance = 0;
  for (var days = low; days <= high; days++) {
    final day = state.lastReviewDay + days;
    final load = loadByDay[day] ?? 0;
    final distance = (days - interval).abs();
    final better = load < bestLoad ||
        (load == bestLoad &&
            (distance < bestDistance ||
                (distance == bestDistance && day < best)));
    if (better) {
      best = day;
      bestLoad = load;
      bestDistance = distance;
    }
  }
  return best;
}
