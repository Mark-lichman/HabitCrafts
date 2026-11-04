// Tests for the study record's local day (D15): a day runs 04:00 to 04:00 local time.
//
// 🚨 WHAT CI CANNOT CATCH HERE. The DST cases below only bite in a timezone that observes DST,
// and GitHub's runners are UTC. On a developer machine in a DST zone (Mark's phone and laptop
// are in one) the sweeps exercise the spring-forward and fall-back nights; on CI they pass
// vacuously. The same caveat as streak_test.dart, said plainly.

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_craft/components/pages/quiet_room_mastery/local_day.dart';

void main() {
  group('localDay', () {
    test('day 0 is 2026-01-01 from 04:00', () {
      expect(localDay(DateTime(2026, 1, 1, 4)), 0);
      expect(localDay(DateTime(2026, 1, 1, 12)), 0);
      expect(localDay(DateTime(2026, 1, 2, 3, 59)), 0);
      expect(localDay(DateTime(2026, 1, 2, 4)), 1);
    });

    test('03:59 belongs to the day before, 04:00 to the day itself', () {
      final d = localDay(DateTime(2026, 6, 15, 12));
      expect(localDay(DateTime(2026, 6, 15, 3, 59, 59)), d - 1);
      expect(localDay(DateTime(2026, 6, 15, 4)), d);
      expect(localDay(DateTime(2026, 6, 15, 0, 30)), d - 1);
      expect(localDay(DateTime(2026, 6, 15, 23, 59)), d);
    });

    test('days before the epoch are negative', () {
      expect(localDay(DateTime(2025, 12, 31, 12)), -1);
      expect(localDay(DateTime(2026, 1, 1, 3)), -1);
    });

    test('a UTC instant is read in local time', () {
      final local = DateTime(2026, 5, 20, 3, 30);
      expect(localDay(local.toUtc()), localDay(local));
    });

    test(
        'steps by exactly one at noon, across a 800-day sweep with two DST years',
        () {
      var day = DateTime(2026, 1, 1, 12);
      for (var i = 0; i < 800; i++) {
        expect(localDay(day), i, reason: 'wrong day number at $day');
        day = DateTime(day.year, day.month, day.day + 1, 12);
      }
    });

    test('hour by hour across the spring-forward and fall-back weekends', () {
      // US 2026: clocks go forward 2026-03-08 and back 2026-11-01; EU on 03-29 and 10-25.
      for (final start in [
        DateTime(2026, 3, 6),
        DateTime(2026, 3, 27),
        DateTime(2026, 10, 23),
        DateTime(2026, 10, 30),
      ]) {
        var t = start;
        var last = localDay(t);
        final end = start.add(const Duration(days: 4));
        while (t.isBefore(end)) {
          final next = t.add(const Duration(minutes: 30));
          final d = localDay(next);
          if (d != last) {
            expect(d, last + 1, reason: 'skipped a day at $next');
            expect(next.hour, 4, reason: 'day changed at $next, not at 04:00');
            expect(next.minute, 0);
          }
          last = d;
          t = next;
        }
      }
    });

    test('the boundary on the DST nights themselves', () {
      for (final date in [
        DateTime(2026, 3, 8),
        DateTime(2026, 3, 29),
        DateTime(2026, 10, 25),
        DateTime(2026, 11, 1),
      ]) {
        final d = localDay(DateTime(date.year, date.month, date.day, 12));
        expect(
            localDay(DateTime(date.year, date.month, date.day, 3, 59)), d - 1);
        expect(localDay(DateTime(date.year, date.month, date.day, 4)), d);
        expect(dayStart(d), DateTime(date.year, date.month, date.day, 4));
      }
    });
  });

  group('dayStart and dateOfDay', () {
    test('round-trip with localDay', () {
      for (var d = -10; d < 400; d++) {
        expect(localDay(dayStart(d)), d);
        expect(
            localDay(dayStart(d + 1).subtract(const Duration(minutes: 1))), d);
        final date = dateOfDay(d);
        expect(date.hour, 0);
        expect(localDay(DateTime(date.year, date.month, date.day, 12)), d);
      }
    });

    test('2026-01-05 is a Monday', () {
      expect(dateOfDay(4).weekday, DateTime.monday);
      expect(dateOfDay(0), DateTime(2026, 1, 1));
    });
  });

  group('Clock', () {
    test('a fixed clock gives today from its instant', () {
      final clock = FixedClock(DateTime(2026, 1, 3, 2));
      expect(clock.now(), DateTime(2026, 1, 3, 2));
      expect(clock.today(), 1);
    });

    test('a fixed clock advances by calendar days and keeps its wall time', () {
      final clock = FixedClock(DateTime(2026, 3, 7, 10));
      clock.advanceDays(2);
      expect(clock.now(), DateTime(2026, 3, 9, 10));
      clock.set(DateTime(2026, 3, 9, 3));
      expect(clock.today(), localDay(DateTime(2026, 3, 8, 12)));
    });

    test('the system clock reads now', () {
      const clock = SystemClock();
      final before = localDay(DateTime.now());
      final today = clock.today();
      expect(today == before || today == before + 1, isTrue);
    });
  });
}
