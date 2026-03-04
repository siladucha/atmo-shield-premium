import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/models/health_data_point.dart';

void main() {
  group('HealthDataPoint', () {
    group('Validation', () {
      test('validates heart rate in valid range (60-120 bpm)', () {
        final point = HealthDataPoint(
          type: 'heartRate',
          value: 75.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isTrue);
      });

      test('validates heart rate at lower boundary (40 bpm)', () {
        final point = HealthDataPoint(
          type: 'heartRate',
          value: 40.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isTrue);
      });

      test('validates heart rate at upper boundary (200 bpm)', () {
        final point = HealthDataPoint(
          type: 'heartRate',
          value: 200.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isTrue);
      });

      test('rejects heart rate below valid range', () {
        final point = HealthDataPoint(
          type: 'heartRate',
          value: 39.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isFalse);
      });

      test('rejects heart rate above valid range', () {
        final point = HealthDataPoint(
          type: 'heartRate',
          value: 201.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isFalse);
      });

      test('validates HRV in normal range (40-60 ms)', () {
        final point = HealthDataPoint(
          type: 'hrv',
          value: 50.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'ms',
        );

        expect(point.isValid(), isTrue);
      });

      test('validates HRV in stress range (<30 ms)', () {
        final point = HealthDataPoint(
          type: 'hrv',
          value: 25.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'ms',
        );

        expect(point.isValid(), isTrue);
      });

      test('validates HRV at lower boundary (10 ms)', () {
        final point = HealthDataPoint(
          type: 'hrv',
          value: 10.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'ms',
        );

        expect(point.isValid(), isTrue);
      });

      test('validates HRV at upper boundary (200 ms)', () {
        final point = HealthDataPoint(
          type: 'hrv',
          value: 200.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'ms',
        );

        expect(point.isValid(), isTrue);
      });

      test('rejects HRV below valid range', () {
        final point = HealthDataPoint(
          type: 'hrv',
          value: 9.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'ms',
        );

        expect(point.isValid(), isFalse);
      });

      test('rejects HRV above valid range', () {
        final point = HealthDataPoint(
          type: 'hrv',
          value: 201.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'ms',
        );

        expect(point.isValid(), isFalse);
      });

      test('validates respiratory rate in normal range (12-16 bpm)', () {
        final point = HealthDataPoint(
          type: 'respiratoryRate',
          value: 14.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isTrue);
      });

      test('validates respiratory rate in stress range (18-22 bpm)', () {
        final point = HealthDataPoint(
          type: 'respiratoryRate',
          value: 20.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isTrue);
      });

      test('validates respiratory rate at lower boundary (8 bpm)', () {
        final point = HealthDataPoint(
          type: 'respiratoryRate',
          value: 8.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isTrue);
      });

      test('validates respiratory rate at upper boundary (30 bpm)', () {
        final point = HealthDataPoint(
          type: 'respiratoryRate',
          value: 30.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isTrue);
      });

      test('rejects respiratory rate below valid range', () {
        final point = HealthDataPoint(
          type: 'respiratoryRate',
          value: 7.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isFalse);
      });

      test('rejects respiratory rate above valid range', () {
        final point = HealthDataPoint(
          type: 'respiratoryRate',
          value: 31.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isFalse);
      });

      test('validates steps in valid range', () {
        final point = HealthDataPoint(
          type: 'steps',
          value: 7500.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'count',
        );

        expect(point.isValid(), isTrue);
      });

      test('validates sleep duration in valid range (7-8 hours)', () {
        final point = HealthDataPoint(
          type: 'sleep',
          value: 450.0, // 7.5 hours in minutes
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'min',
        );

        expect(point.isValid(), isTrue);
      });

      test('rejects negative values', () {
        final point = HealthDataPoint(
          type: 'heartRate',
          value: -10.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isFalse);
      });

      test('rejects zero values', () {
        final point = HealthDataPoint(
          type: 'heartRate',
          value: 0.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isFalse);
      });

      test('rejects future timestamps', () {
        final point = HealthDataPoint(
          type: 'heartRate',
          value: 75.0,
          timestamp: DateTime.now().add(const Duration(hours: 1)),
          unit: 'bpm',
        );

        expect(point.isValid(), isFalse);
      });

      test('accepts unknown data types (extensibility)', () {
        final point = HealthDataPoint(
          type: 'unknownType',
          value: 100.0,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          unit: 'unit',
        );

        expect(point.isValid(), isTrue);
      });
    });

    group('Serialization', () {
      test('toMap converts to correct format', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 0);
        final point = HealthDataPoint(
          type: 'heartRate',
          value: 75.0,
          timestamp: timestamp,
          unit: 'bpm',
        );

        final map = point.toMap();

        expect(map['type'], equals('heartRate'));
        expect(map['value'], equals(75.0));
        expect(map['timestamp'], equals(timestamp.toIso8601String()));
        expect(map['unit'], equals('bpm'));
      });

      test('fromMap creates correct instance', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 0);
        final map = {
          'type': 'hrv',
          'value': 50.0,
          'timestamp': timestamp.toIso8601String(),
          'unit': 'ms',
        };

        final point = HealthDataPoint.fromMap(map);

        expect(point.type, equals('hrv'));
        expect(point.value, equals(50.0));
        expect(point.timestamp, equals(timestamp));
        expect(point.unit, equals('ms'));
      });

      test('fromMap handles integer values', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 0);
        final map = {
          'type': 'steps',
          'value': 7500, // Integer value
          'timestamp': timestamp.toIso8601String(),
          'unit': 'count',
        };

        final point = HealthDataPoint.fromMap(map);

        expect(point.value, equals(7500.0));
      });

      test('round-trip serialization preserves data', () {
        final original = HealthDataPoint(
          type: 'respiratoryRate',
          value: 14.5,
          timestamp: DateTime(2024, 1, 15, 10, 30, 0),
          unit: 'bpm',
        );

        final map = original.toMap();
        final restored = HealthDataPoint.fromMap(map);

        expect(restored, equals(original));
      });
    });

    group('Equality and HashCode', () {
      test('equal instances have same hash code', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 0);
        final point1 = HealthDataPoint(
          type: 'heartRate',
          value: 75.0,
          timestamp: timestamp,
          unit: 'bpm',
        );
        final point2 = HealthDataPoint(
          type: 'heartRate',
          value: 75.0,
          timestamp: timestamp,
          unit: 'bpm',
        );

        expect(point1, equals(point2));
        expect(point1.hashCode, equals(point2.hashCode));
      });

      test('different values produce different instances', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 0);
        final point1 = HealthDataPoint(
          type: 'heartRate',
          value: 75.0,
          timestamp: timestamp,
          unit: 'bpm',
        );
        final point2 = HealthDataPoint(
          type: 'heartRate',
          value: 80.0,
          timestamp: timestamp,
          unit: 'bpm',
        );

        expect(point1, isNot(equals(point2)));
      });

      test('different types produce different instances', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 0);
        final point1 = HealthDataPoint(
          type: 'heartRate',
          value: 75.0,
          timestamp: timestamp,
          unit: 'bpm',
        );
        final point2 = HealthDataPoint(
          type: 'hrv',
          value: 75.0,
          timestamp: timestamp,
          unit: 'ms',
        );

        expect(point1, isNot(equals(point2)));
      });
    });

    group('toString', () {
      test('produces readable string representation', () {
        final timestamp = DateTime(2024, 1, 15, 10, 30, 0);
        final point = HealthDataPoint(
          type: 'heartRate',
          value: 75.0,
          timestamp: timestamp,
          unit: 'bpm',
        );

        final string = point.toString();

        expect(string, contains('heartRate'));
        expect(string, contains('75.0'));
        expect(string, contains('bpm'));
      });
    });
  });
}
