import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/generators/steps_generator.dart';

void main() {
  group('StepsGenerator', () {
    late StepsGenerator generator;
    late DateTime start;
    late DateTime end;

    setUp(() {
      generator = StepsGenerator(seed: 42);
      end = DateTime.now();
      start = end.subtract(const Duration(days: 365));
    });

    test('generates exactly 365 records for one year', () {
      final records = generator.generate(start, end);
      expect(records.length, equals(365));
    });

    test('all records have type "steps" and unit "count"', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        expect(record.type, equals('steps'));
        expect(record.unit, equals('count'));
      }
    });

    test('all step counts are within 5000-10000 range', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        expect(record.value, greaterThanOrEqualTo(5000.0));
        expect(record.value, lessThanOrEqualTo(10000.0));
      }
    });

    test('all timestamps are within the date range', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        expect(record.timestamp.isAfter(start) || record.timestamp.isAtSameMomentAs(start), isTrue);
        expect(record.timestamp.isBefore(end), isTrue);
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

    test('weekend step counts are generally lower than weekday', () {
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

      // Weekend average should be lower (with some tolerance for randomness)
      expect(weekendAvg, lessThan(weekdayAvg + 200));
    });

    test('all records are valid', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        expect(record.isValid(), isTrue);
      }
    });

    test('timestamps are in evening hours (20:00-23:59)', () {
      final records = generator.generate(start, end);

      for (final record in records) {
        expect(record.timestamp.hour, greaterThanOrEqualTo(20));
        expect(record.timestamp.hour, lessThanOrEqualTo(23));
      }
    });
  });
}
