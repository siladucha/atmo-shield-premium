import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/utils/stress_calendar.dart';

void main() {
  group('StressCalendar', () {
    test('generates stress days within date range', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      final calendar = StressCalendar(start, end, seed: 42);

      // All stress days should be within the range
      for (final stressDay in calendar.stressDays) {
        expect(stressDay.isAfter(start.subtract(Duration(days: 1))), isTrue);
        expect(stressDay.isBefore(end.add(Duration(days: 1))), isTrue);
      }
    });

    test('generates approximately 2-3 stress days per month', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      final calendar = StressCalendar(start, end, seed: 42);

      // For 12 months, expect 24-36 stress days (2-3 per month)
      expect(calendar.stressDayCount, greaterThanOrEqualTo(24));
      expect(calendar.stressDayCount, lessThanOrEqualTo(36));
    });

    test('isStressDay returns true for generated stress days', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      final calendar = StressCalendar(start, end, seed: 42);

      // At least one stress day should exist
      expect(calendar.stressDayCount, greaterThan(0));

      // Check that isStressDay returns true for a known stress day
      final firstStressDay = calendar.stressDays.first;
      expect(calendar.isStressDay(firstStressDay), isTrue);
    });

    test('isStressDay returns false for non-stress days', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      final calendar = StressCalendar(start, end, seed: 42);

      // Find a day that's not a stress day
      DateTime? nonStressDay;
      for (int i = 0; i < 365; i++) {
        final testDay = start.add(Duration(days: i));
        if (!calendar.isStressDay(testDay)) {
          nonStressDay = testDay;
          break;
        }
      }

      // Should find at least one non-stress day
      expect(nonStressDay, isNotNull);
      expect(calendar.isStressDay(nonStressDay!), isFalse);
    });

    test('isStressDay normalizes time component', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      final calendar = StressCalendar(start, end, seed: 42);

      final firstStressDay = calendar.stressDays.first;

      // Different times on the same day should all return true
      expect(
          calendar.isStressDay(DateTime(
              firstStressDay.year, firstStressDay.month, firstStressDay.day, 0, 0)),
          isTrue);
      expect(
          calendar.isStressDay(DateTime(firstStressDay.year, firstStressDay.month,
              firstStressDay.day, 12, 30)),
          isTrue);
      expect(
          calendar.isStressDay(DateTime(firstStressDay.year, firstStressDay.month,
              firstStressDay.day, 23, 59)),
          isTrue);
    });

    test('same seed produces same stress days', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);

      final calendar1 = StressCalendar(start, end, seed: 123);
      final calendar2 = StressCalendar(start, end, seed: 123);

      expect(calendar1.stressDays, equals(calendar2.stressDays));
    });

    test('different seeds produce different stress days', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);

      final calendar1 = StressCalendar(start, end, seed: 123);
      final calendar2 = StressCalendar(start, end, seed: 456);

      expect(calendar1.stressDays, isNot(equals(calendar2.stressDays)));
    });

    test('stress days are unique (no duplicates)', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      final calendar = StressCalendar(start, end, seed: 42);

      // Set should have same size as list (no duplicates)
      final stressDaysList = calendar.stressDays.toList();
      expect(stressDaysList.length, equals(calendar.stressDayCount));
    });

    test('handles single month period', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 31);
      final calendar = StressCalendar(start, end, seed: 42);

      // Should have 2-3 stress days for one month
      expect(calendar.stressDayCount, greaterThanOrEqualTo(2));
      expect(calendar.stressDayCount, lessThanOrEqualTo(3));
    });

    test('handles short period (less than 30 days)', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 1, 15);
      final calendar = StressCalendar(start, end, seed: 42);

      // Should still generate 2-3 stress days
      expect(calendar.stressDayCount, greaterThanOrEqualTo(2));
      expect(calendar.stressDayCount, lessThanOrEqualTo(3));

      // All should be within range
      for (final stressDay in calendar.stressDays) {
        expect(stressDay.isAfter(start.subtract(Duration(days: 1))), isTrue);
        expect(stressDay.isBefore(end.add(Duration(days: 1))), isTrue);
      }
    });
  });
}
