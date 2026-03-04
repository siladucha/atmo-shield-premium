import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/generators/heart_rate_generator.dart';
import 'package:atmo_shield_premium/models/health_data_point.dart';

void main() {
  group('HeartRateGenerator', () {
    late HeartRateGenerator generator;
    late DateTime startDate;
    late DateTime endDate;

    setUp(() {
      // Use fixed seed for reproducible tests
      generator = HeartRateGenerator(seed: 42);
      startDate = DateTime(2024, 1, 1);
      endDate = DateTime(2024, 12, 31, 23, 59, 59);
    });

    group('generate()', () {
      test('generates correct number of records within target range', () {
        const targetCount = 7500;
        final records = generator.generate(startDate, endDate,
            targetCount: targetCount);

        expect(records.length, greaterThanOrEqualTo(5000));
        expect(records.length, lessThanOrEqualTo(10000));
        // Should be close to target count (within 10%)
        expect(records.length, greaterThan(targetCount * 0.9));
      });

      test('generates records with correct type and unit', () {
        final records = generator.generate(startDate, endDate, targetCount: 100);

        for (final record in records) {
          expect(record.type, equals('heartRate'));
          expect(record.unit, equals('bpm'));
        }
      });

      test('generates records within valid HR range (40-200 bpm)', () {
        final records =
            generator.generate(startDate, endDate, targetCount: 1000);

        for (final record in records) {
          expect(record.value, greaterThanOrEqualTo(40.0));
          expect(record.value, lessThanOrEqualTo(200.0));
        }
      });

      test('generates records within date range', () {
        final records =
            generator.generate(startDate, endDate, targetCount: 1000);

        for (final record in records) {
          expect(record.timestamp.isAfter(startDate) ||
              record.timestamp.isAtSameMomentAs(startDate), isTrue);
          expect(record.timestamp.isBefore(endDate), isTrue);
        }
      });

      test('generates records with 5-30 minute spacing', () {
        final records = generator.generate(startDate, endDate, targetCount: 500);

        // Check spacing between consecutive records
        for (int i = 1; i < records.length; i++) {
          final interval =
              records[i].timestamp.difference(records[i - 1].timestamp);
          final minutes = interval.inMinutes;

          expect(minutes, greaterThanOrEqualTo(5));
          expect(minutes, lessThanOrEqualTo(30));
        }
      });

      test('throws ArgumentError for invalid target count', () {
        expect(
          () => generator.generate(startDate, endDate, targetCount: 0),
          throwsArgumentError,
        );

        expect(
          () => generator.generate(startDate, endDate, targetCount: -1),
          throwsArgumentError,
        );
      });
    });

    group('time-of-day variation', () {
      test('generates lower HR during resting hours (00:00-06:00)', () {
        // Generate records for early morning hours
        final restingStart = DateTime(2024, 1, 1, 2, 0); // 2 AM
        final restingEnd = DateTime(2024, 1, 1, 5, 0); // 5 AM
        final records =
            generator.generate(restingStart, restingEnd, targetCount: 100);

        // Calculate average HR during resting period
        final avgHR =
            records.map((r) => r.value).reduce((a, b) => a + b) / records.length;

        // Resting HR should be in 60-80 bpm range (allowing some variance)
        expect(avgHR, greaterThanOrEqualTo(55.0));
        expect(avgHR, lessThanOrEqualTo(85.0));
      });

      test('generates higher HR during active hours (09:00-18:00)', () {
        // Generate records for afternoon hours
        final activeStart = DateTime(2024, 1, 1, 12, 0); // 12 PM
        final activeEnd = DateTime(2024, 1, 1, 17, 0); // 5 PM
        final records =
            generator.generate(activeStart, activeEnd, targetCount: 100);

        // Calculate average HR during active period
        final avgHR =
            records.map((r) => r.value).reduce((a, b) => a + b) / records.length;

        // Active HR should be in 90-120 bpm range (allowing some variance)
        expect(avgHR, greaterThanOrEqualTo(85.0));
        expect(avgHR, lessThanOrEqualTo(125.0));
      });

      test('active period HR is higher than resting period HR', () {
        // Generate resting period data
        final restingStart = DateTime(2024, 1, 1, 2, 0);
        final restingEnd = DateTime(2024, 1, 1, 5, 0);
        final restingRecords =
            generator.generate(restingStart, restingEnd, targetCount: 200);
        final avgRestingHR = restingRecords.map((r) => r.value).reduce((a, b) => a + b) /
            restingRecords.length;

        // Generate active period data
        final activeStart = DateTime(2024, 1, 1, 12, 0);
        final activeEnd = DateTime(2024, 1, 1, 17, 0);
        final activeRecords =
            generator.generate(activeStart, activeEnd, targetCount: 200);
        final avgActiveHR = activeRecords.map((r) => r.value).reduce((a, b) => a + b) /
            activeRecords.length;

        // Active HR should be significantly higher than resting HR
        expect(avgActiveHR, greaterThan(avgRestingHR + 10.0));
      });
    });

    group('trend direction', () {
      test('shows downward trend over 365 days', () {
        final records =
            generator.generate(startDate, endDate, targetCount: 7300);

        // Calculate average HR for first 90 days
        final first90Days = startDate.add(Duration(days: 90));
        final firstPeriodRecords = records
            .where((r) => r.timestamp.isBefore(first90Days))
            .toList();
        
        // Skip test if not enough records in first period
        if (firstPeriodRecords.isEmpty) {
          return;
        }
        
        final avgFirstPeriod = firstPeriodRecords.map((r) => r.value).reduce((a, b) => a + b) /
            firstPeriodRecords.length;

        // Calculate average HR for last 90 days
        final last90Days = endDate.subtract(Duration(days: 90));
        final lastPeriodRecords =
            records.where((r) => r.timestamp.isAfter(last90Days)).toList();
        
        // Skip test if not enough records in last period
        if (lastPeriodRecords.isEmpty) {
          return;
        }
        
        final avgLastPeriod = lastPeriodRecords.map((r) => r.value).reduce((a, b) => a + b) /
            lastPeriodRecords.length;

        // Last period should have lower average HR (cardiovascular improvement)
        expect(avgLastPeriod, lessThan(avgFirstPeriod));
      });
    });

    group('data validation', () {
      test('all generated records pass isValid() check', () {
        final records =
            generator.generate(startDate, endDate, targetCount: 1000);

        for (final record in records) {
          expect(record.isValid(), isTrue);
        }
      });

      test('records are in chronological order', () {
        final records = generator.generate(startDate, endDate, targetCount: 500);

        for (int i = 1; i < records.length; i++) {
          expect(
            records[i].timestamp.isAfter(records[i - 1].timestamp),
            isTrue,
            reason: 'Record $i should be after record ${i - 1}',
          );
        }
      });
    });

    group('reproducibility', () {
      test('generates identical data with same seed', () {
        final generator1 = HeartRateGenerator(seed: 123);
        final generator2 = HeartRateGenerator(seed: 123);

        final records1 =
            generator1.generate(startDate, endDate, targetCount: 100);
        final records2 =
            generator2.generate(startDate, endDate, targetCount: 100);

        expect(records1.length, equals(records2.length));

        for (int i = 0; i < records1.length; i++) {
          expect(records1[i].value, equals(records2[i].value));
          expect(records1[i].timestamp, equals(records2[i].timestamp));
        }
      });

      test('generates different data with different seeds', () {
        final generator1 = HeartRateGenerator(seed: 123);
        final generator2 = HeartRateGenerator(seed: 456);

        final records1 =
            generator1.generate(startDate, endDate, targetCount: 100);
        final records2 =
            generator2.generate(startDate, endDate, targetCount: 100);

        // At least some values should be different
        var differentCount = 0;
        for (int i = 0; i < records1.length && i < records2.length; i++) {
          if (records1[i].value != records2[i].value) {
            differentCount++;
          }
        }

        expect(differentCount, greaterThan(0));
      });
    });
  });
}
