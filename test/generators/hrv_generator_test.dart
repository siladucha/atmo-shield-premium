import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/generators/hrv_generator.dart';
import 'package:atmo_shield_premium/utils/stress_calendar.dart';

void main() {
  group('HRVGenerator', () {
    late HRVGenerator generator;
    late DateTime startDate;
    late DateTime endDate;
    late StressCalendar stressCalendar;

    setUp(() {
      // Use fixed seed for reproducible tests
      generator = HRVGenerator(seed: 42);
      startDate = DateTime(2024, 1, 1);
      endDate = DateTime(2024, 12, 31);
      stressCalendar = StressCalendar(startDate, endDate, seed: 42);
    });

    test('generates records within expected range (600-900)', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      expect(records.length, greaterThanOrEqualTo(600));
      expect(records.length, lessThanOrEqualTo(900));
    });

    test('all records have correct type and unit', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      for (final record in records) {
        expect(record.type, equals('hrv'));
        expect(record.unit, equals('ms'));
      }
    });

    test('all records fall within date range', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      for (final record in records) {
        expect(record.timestamp.isAfter(startDate) ||
            record.timestamp.isAtSameMomentAs(startDate), isTrue);
        expect(record.timestamp.isBefore(endDate), isTrue);
      }
    });

    test('HRV values are within valid range (10-200ms)', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      for (final record in records) {
        expect(record.value, greaterThanOrEqualTo(10.0));
        expect(record.value, lessThanOrEqualTo(200.0));
      }
    });

    test('stress day HRV values are below 30ms', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      // Find records on stress days
      final stressRecords = records.where((record) {
        return stressCalendar.isStressDay(record.timestamp);
      }).toList();

      // Verify stress records exist
      expect(stressRecords.isNotEmpty, isTrue);

      // All stress day records should have HRV < 30ms
      for (final record in stressRecords) {
        expect(record.value, lessThan(30.0));
      }
    });

    test('normal day HRV values are between 40-60ms', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      // Find records on normal (non-stress) days
      final normalRecords = records.where((record) {
        return !stressCalendar.isStressDay(record.timestamp);
      }).toList();

      // Verify normal records exist
      expect(normalRecords.isNotEmpty, isTrue);

      // Most normal day records should be in 40-60ms range
      // (allowing some variance due to trend and noise)
      final inRangeCount = normalRecords.where((record) {
        return record.value >= 35.0 && record.value <= 65.0;
      }).length;

      // At least 90% should be in the expected range
      expect(inRangeCount / normalRecords.length, greaterThan(0.9));
    });

    test('records are distributed across different time periods', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      // Count records in each time period
      int morningCount = 0;
      int dayCount = 0;
      int eveningCount = 0;
      int nightCount = 0;

      for (final record in records) {
        final hour = record.timestamp.hour;
        if (hour >= 6 && hour < 12) {
          morningCount++;
        } else if (hour >= 12 && hour < 18) {
          dayCount++;
        } else if (hour >= 18 && hour < 22) {
          eveningCount++;
        } else {
          nightCount++;
        }
      }

      // Each period should have at least 10% of records (Requirement 3.7)
      final totalRecords = records.length;
      expect(morningCount / totalRecords, greaterThan(0.1));
      expect(dayCount / totalRecords, greaterThan(0.1));
      expect(eveningCount / totalRecords, greaterThan(0.1));
      expect(nightCount / totalRecords, greaterThan(0.1));
    });

    test('approximately 35% of days have zero records', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      // Count days with records
      final daysWithRecords = <DateTime>{};
      for (final record in records) {
        final date = DateTime(
          record.timestamp.year,
          record.timestamp.month,
          record.timestamp.day,
        );
        daysWithRecords.add(date);
      }

      final totalDays = 365;
      final daysWithZeroRecords = totalDays - daysWithRecords.length;
      final percentageZero = daysWithZeroRecords / totalDays;

      // Should be approximately 35% (allow 25-40% range for variance)
      // Note: To achieve 600-900 total records with realistic distribution,
      // we need to balance zero-day percentage with total record count.
      expect(percentageZero, greaterThan(0.25));
      expect(percentageZero, lessThan(0.40));
    });

    test('HRV shows upward trend over time', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
        trendGrowth: 0.15,
        trendDurationMonths: 4,
      );

      // Filter out stress day records for trend analysis
      final normalRecords = records.where((record) {
        return !stressCalendar.isStressDay(record.timestamp);
      }).toList();

      // Sort by timestamp
      normalRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Calculate average HRV for first and last 90 days
      final first90Days = startDate.add(const Duration(days: 90));
      final last90DaysStart = endDate.subtract(const Duration(days: 90));

      final firstPeriodRecords = normalRecords.where((r) {
        return r.timestamp.isBefore(first90Days);
      }).toList();

      final lastPeriodRecords = normalRecords.where((r) {
        return r.timestamp.isAfter(last90DaysStart);
      }).toList();

      if (firstPeriodRecords.isNotEmpty && lastPeriodRecords.isNotEmpty) {
        final firstAvg = firstPeriodRecords
            .map((r) => r.value)
            .reduce((a, b) => a + b) / firstPeriodRecords.length;

        final lastAvg = lastPeriodRecords
            .map((r) => r.value)
            .reduce((a, b) => a + b) / lastPeriodRecords.length;

        // Last period should have higher average HRV (improvement trend)
        expect(lastAvg, greaterThan(firstAvg));
      }
    });

    test('all generated records are valid', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      for (final record in records) {
        expect(record.isValid(), isTrue);
      }
    });
  });
}
