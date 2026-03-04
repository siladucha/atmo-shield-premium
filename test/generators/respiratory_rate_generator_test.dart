import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/generators/respiratory_rate_generator.dart';
import 'package:atmo_shield_premium/utils/stress_calendar.dart';

void main() {
  group('RespiratoryRateGenerator', () {
    late RespiratoryRateGenerator generator;
    late DateTime startDate;
    late DateTime endDate;
    late StressCalendar stressCalendar;

    setUp(() {
      // Use fixed seed for reproducible tests
      generator = RespiratoryRateGenerator(seed: 42);
      startDate = DateTime(2024, 1, 1);
      endDate = DateTime(2024, 12, 31);
      stressCalendar = StressCalendar(startDate, endDate, seed: 42);
    });

    test('generates exactly 365 records for one year', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      expect(records.length, equals(365));
    });

    test('all records have correct type and unit', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      for (final record in records) {
        expect(record.type, equals('respiratoryRate'));
        expect(record.unit, equals('bpm'));
      }
    });

    test('all records have night-time timestamps', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      for (final record in records) {
        final hour = record.timestamp.hour;
        // Night time: 22:00-06:00 (hour >= 22 OR hour < 6)
        expect(hour >= 22 || hour < 6, isTrue,
            reason: 'Hour $hour is not in night period (22:00-06:00)');
      }
    });

    test('all RR values are within valid range (12-22 bpm)', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      for (final record in records) {
        expect(record.value, greaterThanOrEqualTo(12.0));
        expect(record.value, lessThanOrEqualTo(22.0));
      }
    });

    test('stress days have higher RR values (18-22 bpm)', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      // Find records on stress days
      final stressRecords = records.where((record) {
        return stressCalendar.isStressDay(record.timestamp);
      }).toList();

      // Verify we have some stress days
      expect(stressRecords.isNotEmpty, isTrue);

      // All stress day RR values should be in stress range (18-22 bpm)
      for (final record in stressRecords) {
        expect(record.value, greaterThanOrEqualTo(18.0),
            reason: 'Stress day RR should be >= 18 bpm');
        expect(record.value, lessThanOrEqualTo(22.0),
            reason: 'Stress day RR should be <= 22 bpm');
      }
    });

    test('normal days have lower RR values (12-16 bpm)', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      // Find records on normal (non-stress) days
      final normalRecords = records.where((record) {
        return !stressCalendar.isStressDay(record.timestamp);
      }).toList();

      // Verify we have normal days
      expect(normalRecords.isNotEmpty, isTrue);

      // Most normal day RR values should be in normal range (12-16 bpm)
      // Allow some flexibility due to trend and noise
      final normalRangeCount = normalRecords.where((record) {
        return record.value >= 12.0 && record.value <= 16.0;
      }).length;

      // At least 90% should be in normal range
      final normalPercentage = normalRangeCount / normalRecords.length;
      expect(normalPercentage, greaterThan(0.9),
          reason: 'At least 90% of normal days should have RR in 12-16 bpm range');
    });

    test('shows downward trend over time', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      // Filter out stress days to see trend clearly
      final normalRecords = records.where((record) {
        return !stressCalendar.isStressDay(record.timestamp);
      }).toList();

      // Calculate average RR for first 90 days
      final firstQuarter = normalRecords
          .where((r) => r.timestamp.difference(startDate).inDays < 90)
          .toList();
      final firstAvg = firstQuarter.isEmpty
          ? 0.0
          : firstQuarter.map((r) => r.value).reduce((a, b) => a + b) /
              firstQuarter.length;

      // Calculate average RR for last 90 days
      final lastQuarter = normalRecords
          .where((r) => endDate.difference(r.timestamp).inDays < 90)
          .toList();
      final lastAvg = lastQuarter.isEmpty
          ? 0.0
          : lastQuarter.map((r) => r.value).reduce((a, b) => a + b) /
              lastQuarter.length;

      // Last quarter should have lower average RR (improvement)
      expect(lastAvg, lessThan(firstAvg),
          reason: 'RR should decrease over time (respiratory improvement)');
    });

    test('all records have valid timestamps within date range', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      for (final record in records) {
        // Allow timestamps to extend slightly beyond end date due to night-time
        // measurements that may fall on the next day
        final allowedEnd = endDate.add(const Duration(days: 1));
        expect(record.timestamp.isAfter(startDate.subtract(const Duration(days: 1))), isTrue);
        expect(record.timestamp.isBefore(allowedEnd), isTrue);
      }
    });

    test('generates one record per day', () {
      final records = generator.generate(
        start: startDate,
        end: endDate,
        stressCalendar: stressCalendar,
      );

      // Group records by date (ignoring time)
      final recordsByDate = <DateTime, int>{};
      for (final record in records) {
        // Normalize timestamp to date only
        // Account for night measurements that may be on the next day
        var recordDate = DateTime(
          record.timestamp.year,
          record.timestamp.month,
          record.timestamp.day,
        );
        
        // If it's an early morning measurement (before 6 AM), attribute it to previous day
        if (record.timestamp.hour < 6) {
          recordDate = recordDate.subtract(const Duration(days: 1));
        }
        
        recordsByDate[recordDate] = (recordsByDate[recordDate] ?? 0) + 1;
      }

      // Each day should have exactly one record
      for (final count in recordsByDate.values) {
        expect(count, equals(1),
            reason: 'Each day should have exactly one RR record');
      }
    });
  });
}
