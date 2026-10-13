// Tests for Today's day arithmetic. These are the first real tests in the repo, so CI's test
// step stops being vacuous.
//
// 🚨 WHAT CI CANNOT CATCH HERE. The bug these cover only misbehaves in a timezone that
// observes DST, and GitHub's runners are UTC. The midnight sweep below therefore guards
// against reintroducing `subtract(Duration(days: 1))` when run on a developer machine in a
// DST zone, and passes vacuously on CI. Said plainly rather than left for someone to discover.

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_today/streak.dart';

void main() {
  group('dayBefore', () {
    test('always lands on midnight, across a 400-day sweep', () {
      // In a DST zone the old duration-based implementation returned 23:00 or 01:00 here.
      var day = DateTime(2026, 1, 1);
      for (var i = 0; i < 400; i++) {
        final previous = dayBefore(day, 1);
        expect(previous.hour, 0,
            reason: 'not midnight stepping back from $day');
        expect(previous.minute, 0);
        day = dayBefore(day, -1);
      }
    });

    test('crosses month, year and leap boundaries', () {
      expect(dayBefore(DateTime(2026, 3, 1), 1), DateTime(2026, 2, 28));
      expect(dayBefore(DateTime(2024, 3, 1), 1), DateTime(2024, 2, 29));
      expect(dayBefore(DateTime(2026, 1, 1), 1), DateTime(2025, 12, 31));
      expect(dayBefore(DateTime(2026, 3, 10), 9), DateTime(2026, 3, 1));
    });
  });

  group('streakFrom', () {
    final today = DateTime(2026, 3, 10, 14, 30);

    test('is zero with no completions', () {
      expect(streakFrom(const [], today: today), 0);
    });

    test('counts consecutive days ending today', () {
      final done = [
        DateTime(2026, 3, 10, 9),
        DateTime(2026, 3, 9, 22),
        DateTime(2026, 3, 8, 7),
      ];
      expect(streakFrom(done, today: today), 3);
    });

    test('counts a streak ending yesterday, so today is not yet a failure', () {
      final done = [DateTime(2026, 3, 9), DateTime(2026, 3, 8)];
      expect(streakFrom(done, today: today), 2);
    });

    test('is zero when the last completion is two days old', () {
      expect(streakFrom([DateTime(2026, 3, 8)], today: today), 0);
    });

    test('ignores gaps before the current run', () {
      final done = [
        DateTime(2026, 3, 10),
        DateTime(2026, 3, 9),
        DateTime(2026, 3, 1),
      ];
      expect(streakFrom(done, today: today), 2);
    });

    test('counts a day once when it holds several completions', () {
      final done = [
        DateTime(2026, 3, 10, 8),
        DateTime(2026, 3, 10, 20),
        DateTime(2026, 3, 9, 12),
      ];
      expect(streakFrom(done, today: today), 2);
    });

    test('counts across a month boundary', () {
      final done = [DateTime(2026, 3, 1), DateTime(2026, 2, 28)];
      expect(streakFrom(done, today: DateTime(2026, 3, 1, 10)), 2);
    });
  });

  group('recentDays', () {
    final today = DateTime(2026, 3, 10, 14, 30);

    test('returns one entry per day, oldest first, ending today', () {
      final days = recentDays([DateTime(2026, 3, 10)], today: today);
      expect(days.length, 14);
      expect(days.last, isTrue, reason: 'today completed');
      expect(days.first, isFalse, reason: '13 days ago not completed');
    });

    test('marks the correct position for an older completion', () {
      // 3 days ago sits at index 10 of 14 (length - 1 - 3).
      final days = recentDays([DateTime(2026, 3, 7)], today: today);
      expect(days[10], isTrue);
      expect(days.where((d) => d).length, 1);
    });

    test('ignores completions outside the window', () {
      final days = recentDays([DateTime(2026, 1, 1)], today: today);
      expect(days.where((d) => d).length, 0);
    });
  });
}
