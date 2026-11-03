// The study record's local day (D15). A day runs from 04:00 to 04:00 local time, so a late
// session at 01:00 still belongs to the evening it started in. The store, the daily plan and the
// 14 dots all use this one function.
//
// 🚨 STEP BY CALENDAR, NEVER BY DURATION. Across a DST change a local day is 23 or 25 hours long,
// so counting 24-hour blocks drifts by an hour twice a year. The day number below is the calendar
// difference of two UTC dates, which has no DST. See local_day_test.dart and streak.dart.

/// The first local day, day 0: 2026-01-01 from 04:00.
final DateTime kLocalDayEpoch = DateTime.utc(2026, 1, 1);

/// The local hour at which a new day starts.
const int kDayStartHour = 4;

/// The local day number of [t]: days since 2026-01-01, the boundary at 04:00 local time.
///
/// A UTC [t] is read in local time first. Days before the epoch are negative.
int localDay(DateTime t) {
  final local = t.isUtc ? t.toLocal() : t;
  // Before 04:00 the instant belongs to the previous calendar date.
  final shift = local.hour < kDayStartHour ? 1 : 0;
  final date = DateTime.utc(local.year, local.month, local.day - shift);
  return date.difference(kLocalDayEpoch).inDays;
}

/// The calendar date (local midnight) that local day [day] is named after.
DateTime dateOfDay(int day) => DateTime(2026, 1, 1 + day);

/// The local instant at which local day [day] starts (04:00 on its date).
DateTime dayStart(int day) => DateTime(2026, 1, 1 + day, kDayStartHour);

/// The seam through which the record reads the time, so nothing calls `DateTime.now()` directly.
abstract class Clock {
  const Clock();

  DateTime now();

  /// Today's local day number.
  int today() => localDay(now());
}

/// The device clock.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock for tests and the simulator: it stays where it is set.
class FixedClock extends Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void set(DateTime t) => _now = t;

  /// Moves by [days] calendar days and keeps the wall-clock time, across DST.
  void advanceDays(int days) => _now = DateTime(_now.year, _now.month,
      _now.day + days, _now.hour, _now.minute, _now.second);
}
