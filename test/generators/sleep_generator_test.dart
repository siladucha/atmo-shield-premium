import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/generators/sleep_generator.dart';

void main() {
  group('SleepGenerator', () {
    late SleepGenerator generator;
    late DateTime start;
    late DateTime end;

    setUp(() {
      generator = SleepGenerator(seed: 42);
      end = DateTime.now();
      start = end.subtract(const Duration(days: 365));
    });

    test('generates exactly 365 records for one year', () {
      final records = generator.generate(start, end);
      expect(records.length, equals(365));
    });

    test('all records have type "sleep" and unit "min"', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        expect(record.type, equals('sleep'));
        expect(record.unit, equals('min'));
      }
    });

    test('all sleep durations are within 420-480 minutes (7-8 hours)', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        expect(record.value, greaterThanOrEqualTo(420.0));
        expect(record.value, lessThanOrEqualTo(480.0));
      }
    });

    test('all timestamps are within the date range', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        // Timestamps should be within the date range (allowing for same day)
        expect(record.timestamp.isAfter(start.subtract(const Duration(days: 1))), isTrue);
        expect(record.timestamp.isBefore(end.add(const Duration(days: 1))), isTrue);
      }
    });

    test('generates one record per day', () {
      final records = generator.generate(start, end);

      // Extract unique dates (ignoring time)
      final uniqueDates = records.map((r) {
        final ts = r.timestamp;
        return DateTime(ts.year, ts.month, ts.day);
      }).toSet();

      expect(uniqueDates.length, equals(365));
    });

    test('weekend sleep durations are longer than weekday', () {
      final records = generator.generate(start, end);

      double weekdaySum = 0;
      int weekdayCount = 0;
      double weekendSum = 0;
      int weekendCount = 0;

      for (final record in records) {
        final isWeekend = record.timestamp.weekday == DateTime.saturday ||
            record.timestamp.weekday == DateTime.sunday;

        if (isWeekend) {
          weekendSum += record.value;
          weekendCount++;
        } else {
          weekdaySum += record.value;
          weekdayCount++;
        }
      }

      final weekdayAvg = weekdaySum / weekdayCount;
      final weekendAvg = weekendSum / weekendCount;

      // Weekend average should be higher (Requirement 5.3)
      expect(weekendAvg, greaterThan(weekdayAvg));
    });

    test('all records are valid', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        expect(record.isValid(), isTrue);
      }
    });

    test('timestamps are in morning hours (06:00-09:59)', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        expect(record.timestamp.hour, greaterThanOrEqualTo(6));
        expect(record.timestamp.hour, lessThanOrEqualTo(9));
      }
    });

    test('sleep durations are in hours range (7-8 hours)', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        final hours = record.value / 60;
        expect(hours, greaterThanOrEqualTo(7.0));
        expect(hours, lessThanOrEqualTo(8.0));
      }
    });
  });
}
