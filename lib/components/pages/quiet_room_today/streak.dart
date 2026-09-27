// Day arithmetic for Today. Extracted from the widget so it can be tested without Firebase.
//
// 🚨 STEP BY CALENDAR, NEVER BY DURATION. `subtract(Duration(days: 1))` removes 24 absolute
// hours, so across a DST change it lands on 23:00 or 01:00 of the previous day instead of
// midnight, and every comparison against a midnight key then misses. That silently truncated
// streaks and drew completed days as missed, twice a year. `DateTime(y, m, d - 1)` normalises
// and stays at midnight. See streak_test.dart.

/// Midnight on the day [t] falls in, local time.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// The day [n] days before [day]. Negative [n] moves forward.
DateTime dayBefore(DateTime day, int n) =>
    DateTime(day.year, day.month, day.day - n);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Consecutive days of completion ending today or yesterday.
///
/// Yesterday counts so a streak is not reported broken before the person has had their day.
int streakFrom(Iterable<DateTime> completions, {required DateTime today}) {
  final days = completions.map(dayOf).toSet();
  if (days.isEmpty) return 0;

  var cursor = dayOf(today);
  if (!days.contains(cursor)) {
    cursor = dayBefore(cursor, 1);
    if (!days.contains(cursor)) return 0;
  }

  var n = 0;
  while (days.contains(cursor)) {
    n++;
    cursor = dayBefore(cursor, 1);
  }
  return n;
}

/// Whether each of the last [length] days, oldest first, had any completion.
List<bool> recentDays(Iterable<DateTime> completions,
    {required DateTime today, int length = 14}) {
  final days = completions.map(dayOf).toSet();
  final start = dayOf(today);
  return List<bool>.generate(
    length,
    (i) => days.contains(dayBefore(start, length - 1 - i)),
  );
}
