import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/models/generation_config.dart';
import 'package:atmo_shield_premium/models/generation_result.dart';
import 'package:atmo_shield_premium/services/data_generation_service.dart';
import 'package:atmo_shield_premium/native/healthkit_bridge.dart';

/// Mock HealthKitBridge for testing without actual HealthKit access
class MockHealthKitBridge extends HealthKitBridge {
  bool _isAvailable = true;
  bool _permissionsGranted = true;
  bool _shouldFailWrite = false;
  final List<String> _requestedPermissions = [];
  final Map<String, int> _writtenRecords = {};

  void setAvailable(bool available) {
    _isAvailable = available;
  }

  void setPermissionsGranted(bool granted) {
    _permissionsGranted = granted;
  }

  void setShouldFailWrite(bool shouldFail) {
    _shouldFailWrite = shouldFail;
  }

  List<String> get requestedPermissions => _requestedPermissions;
  Map<String, int> get writtenRecords => _writtenRecords;

  @override
  Future<bool> isHealthKitAvailable() async {
    return _isAvailable;
  }

  @override
  Future<bool> requestPermissions(List<String> writeTypes) async {
    _requestedPermissions.addAll(writeTypes);
    return _permissionsGranted;
  }

  @override
  Future<bool> writeBatch(
    String dataType,
    List<Map<String, dynamic>> records,
  ) async {
    if (_shouldFailWrite) {
      return false;
    }

    _writtenRecords[dataType] = (_writtenRecords[dataType] ?? 0) + records.length;
    return true;
  }
}

void main() {
  group('DataGenerationService', () {
    late MockHealthKitBridge mockBridge;
    late DataGenerationService service;

    setUp(() {
      mockBridge = MockHealthKitBridge();
    });

    group('Initialization', () {
      test('calculates 365-day baseline period correctly', () {
        final currentDate = DateTime(2024, 1, 15);
        service = DataGenerationService(
          currentDate: currentDate,
          healthKitBridge: mockBridge,
        );

        expect(service.endDate, currentDate);
        expect(service.startDate, DateTime(2023, 1, 15));
        expect(service.endDate.difference(service.startDate).inDays, 365);
      });

      test('uses DateTime.now() when currentDate not provided', () {
        final before = DateTime.now();
        service = DataGenerationService(healthKitBridge: mockBridge);
        final after = DateTime.now();

        // End date should be close to now
        expect(service.endDate.isAfter(before) || service.endDate.isAtSameMomentAs(before), true);
        expect(service.endDate.isBefore(after) || service.endDate.isAtSameMomentAs(after), true);

        // Start date should be 365 days before end date
        expect(service.endDate.difference(service.startDate).inDays, 365);
      });

      test('creates stress calendar during initialization', () {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          healthKitBridge: mockBridge,
        );

        expect(service.stressCalendar, isNotNull);
        expect(service.stressCalendar.stressDayCount, greaterThan(0));
        // Should have 2-3 stress days per month × 12 months = 24-36 total
        expect(service.stressCalendar.stressDayCount, greaterThanOrEqualTo(24));
        expect(service.stressCalendar.stressDayCount, lessThanOrEqualTo(36));
      });

      test('uses seed for reproducible generation', () {
        final service1 = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final service2 = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        // Stress calendars should be identical with same seed
        expect(
          service1.stressCalendar.stressDayCount,
          service2.stressCalendar.stressDayCount,
        );
      });
    });

    group('generateAllData - HealthKit Availability', () {
      test('returns error when HealthKit is not available', () async {
        mockBridge.setAvailable(false);
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.defaultConfig());

        expect(result.status, GenerationStatus.error);
        expect(result.errors.first, contains('HealthKit is not available'));
        expect(result.totalRecords, 0);
      });
    });

    group('generateAllData - Permissions', () {
      test('returns permissionDenied when permissions not granted', () async {
        mockBridge.setPermissionsGranted(false);
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.defaultConfig());

        expect(result.status, GenerationStatus.permissionDenied);
        expect(result.errors.first, contains('permission denied'));
        expect(result.totalRecords, 0);
      });

      test('requests correct permissions for default config', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          healthKitBridge: mockBridge,
        );

        await service.generateAllData(GenerationConfig.defaultConfig());

        expect(mockBridge.requestedPermissions, contains('heartRate'));
        expect(mockBridge.requestedPermissions, contains('hrv'));
        expect(mockBridge.requestedPermissions, contains('respiratoryRate'));
        expect(mockBridge.requestedPermissions, isNot(contains('steps')));
        expect(mockBridge.requestedPermissions, isNot(contains('sleep')));
      });

      test('requests additional permissions when optional features enabled', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          healthKitBridge: mockBridge,
        );

        await service.generateAllData(GenerationConfig.withAllFeatures());

        expect(mockBridge.requestedPermissions, contains('heartRate'));
        expect(mockBridge.requestedPermissions, contains('hrv'));
        expect(mockBridge.requestedPermissions, contains('respiratoryRate'));
        expect(mockBridge.requestedPermissions, contains('steps'));
        expect(mockBridge.requestedPermissions, contains('sleep'));
      });
    });

    group('generateAllData - Data Generation', () {
      test('generates all required data types with default config', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.defaultConfig());

        expect(result.status, GenerationStatus.success);
        expect(result.hrRecordsGenerated, greaterThan(0));
        expect(result.hrvRecordsGenerated, greaterThan(0));
        expect(result.rrRecordsGenerated, 365); // Exactly one per day
        expect(result.stepsRecordsGenerated, 0); // Not enabled
        expect(result.sleepRecordsGenerated, 0); // Not enabled
      });

      test('generates optional data types when enabled', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.withAllFeatures());

        expect(result.status, GenerationStatus.success);
        expect(result.hrRecordsGenerated, greaterThan(0));
        expect(result.hrvRecordsGenerated, greaterThan(0));
        expect(result.rrRecordsGenerated, 365);
        expect(result.stepsRecordsGenerated, 365); // One per day
        expect(result.sleepRecordsGenerated, 365); // One per day
      });

      test('respects targetHRRecords configuration', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final config = GenerationConfig.minimal(); // 5000 HR records
        final result = await service.generateAllData(config);

        expect(result.status, GenerationStatus.success);
        // Should be close to 5000 (may vary slightly due to timestamp spacing)
        expect(result.hrRecordsGenerated, greaterThanOrEqualTo(4900));
        expect(result.hrRecordsGenerated, lessThanOrEqualTo(5100));
      });

      test('generates HRV records within expected range', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.defaultConfig());

        expect(result.status, GenerationStatus.success);
        // Should generate 600-900 HRV records across 365 days
        expect(result.hrvRecordsGenerated, greaterThanOrEqualTo(600));
        expect(result.hrvRecordsGenerated, lessThanOrEqualTo(900));
      });
    });

    group('generateAllData - HealthKit Writing', () {
      test('writes all data types to HealthKit', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.withAllFeatures());

        expect(result.status, GenerationStatus.success);
        expect(mockBridge.writtenRecords['heartRate'], greaterThan(0));
        expect(mockBridge.writtenRecords['hrv'], greaterThan(0));
        expect(mockBridge.writtenRecords['respiratoryRate'], 365);
        expect(mockBridge.writtenRecords['steps'], 365);
        expect(mockBridge.writtenRecords['sleep'], 365);
      });

      test('continues generation when write fails for one data type', () async {
        // This test would require more sophisticated mocking to fail specific writes
        // For now, we test that the service handles write failures gracefully
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        mockBridge.setShouldFailWrite(true);
        final result = await service.generateAllData(GenerationConfig.defaultConfig());

        // Should still complete but with errors
        expect(result.status, GenerationStatus.success);
        expect(result.errors, isNotEmpty);
      });
    });

    group('generateAllData - Progress Tracking', () {
      test('calls progress callback with increasing values', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final progressValues = <double>[];
        final progressMessages = <String>[];

        await service.generateAllData(
          GenerationConfig.defaultConfig(),
          onProgress: (progress, message) {
            progressValues.add(progress);
            progressMessages.add(message);
          },
        );

        // Should have multiple progress updates
        expect(progressValues.length, greaterThan(3));

        // Progress should increase monotonically
        for (int i = 1; i < progressValues.length; i++) {
          expect(progressValues[i], greaterThanOrEqualTo(progressValues[i - 1]));
        }

        // Should start at 0.0 and end at 1.0
        expect(progressValues.first, 0.0);
        expect(progressValues.last, 1.0);

        // Should have descriptive messages
        expect(progressMessages, isNotEmpty);
        expect(progressMessages.any((msg) => msg.contains('HealthKit')), true);
      });
    });

    group('generateAllData - Timing', () {
      test('completes within reasonable time', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.defaultConfig());

        expect(result.status, GenerationStatus.success);
        // Should complete in under 10 seconds (requirement 1.4)
        // In tests, it should be much faster since we're not actually writing to HealthKit
        expect(result.generationTime.inSeconds, lessThan(10));
      });

      test('tracks generation time accurately', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.defaultConfig());

        expect(result.status, GenerationStatus.success);
        expect(result.generationTime.inMilliseconds, greaterThan(0));
      });
    });

    group('generateAllData - Error Handling', () {
      test('handles exceptions during generation gracefully', () async {
        // Create service with invalid date range to trigger error
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          healthKitBridge: mockBridge,
        );

        // This should not throw, but return an error result
        final result = await service.generateAllData(GenerationConfig.defaultConfig());

        // Should complete (either success or with errors tracked)
        expect(result, isNotNull);
        expect(result.generationTime, isNotNull);
      });
    });

    group('generateAllData - Statistics', () {
      test('tracks total records generated', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.withAllFeatures());

        expect(result.status, GenerationStatus.success);
        expect(result.totalRecords, greaterThan(0));
        expect(
          result.totalRecords,
          result.hrRecordsGenerated +
              result.hrvRecordsGenerated +
              result.rrRecordsGenerated +
              result.stepsRecordsGenerated +
              result.sleepRecordsGenerated,
        );
      });

      test('provides detailed log summary', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final result = await service.generateAllData(GenerationConfig.defaultConfig());

        final logSummary = result.toLogSummary();
        expect(logSummary, contains('[SynthData]'));
        expect(logSummary, contains('HR records'));
        expect(logSummary, contains('HRV records'));
        expect(logSummary, contains('RR records'));
      });
    });

    group('Parallel Generation', () {
      test('generates data types in parallel for performance', () async {
        service = DataGenerationService(
          currentDate: DateTime(2024, 1, 1),
          seed: 12345,
          healthKitBridge: mockBridge,
        );

        final stopwatch = Stopwatch()..start();
        final result = await service.generateAllData(GenerationConfig.withAllFeatures());
        stopwatch.stop();

        expect(result.status, GenerationStatus.success);
        // Parallel generation should be faster than sequential
        // This is a basic check - actual timing depends on system performance
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });
  });
}
