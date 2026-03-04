import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/models/generation_result.dart';

void main() {
  group('GenerationResult', () {
    group('constructor', () {
      test('creates result with all required fields', () {
        final result = GenerationResult(
          hrRecordsGenerated: 7500,
          hrvRecordsGenerated: 750,
          rrRecordsGenerated: 365,
          stepsRecordsGenerated: 365,
          sleepRecordsGenerated: 365,
          generationTime: const Duration(seconds: 8),
          errors: const ['Warning: Some records skipped'],
          status: GenerationStatus.success,
        );

        expect(result.hrRecordsGenerated, 7500);
        expect(result.hrvRecordsGenerated, 750);
        expect(result.rrRecordsGenerated, 365);
        expect(result.stepsRecordsGenerated, 365);
        expect(result.sleepRecordsGenerated, 365);
        expect(result.generationTime, const Duration(seconds: 8));
        expect(result.errors, ['Warning: Some records skipped']);
        expect(result.status, GenerationStatus.success);
      });

      test('uses default values for optional fields', () {
        final result = GenerationResult(
          hrRecordsGenerated: 5000,
          hrvRecordsGenerated: 600,
          rrRecordsGenerated: 365,
          generationTime: const Duration(seconds: 5),
          status: GenerationStatus.success,
        );

        expect(result.stepsRecordsGenerated, 0);
        expect(result.sleepRecordsGenerated, 0);
        expect(result.errors, isEmpty);
      });
    });

    group('factory constructors', () {
      test('success factory creates successful result', () {
        final result = GenerationResult.success(
          hrRecords: 7500,
          hrvRecords: 750,
          rrRecords: 365,
          stepsRecords: 365,
          sleepRecords: 365,
          generationTime: const Duration(seconds: 8),
          errors: const ['Minor warning'],
        );

        expect(result.status, GenerationStatus.success);
        expect(result.hrRecordsGenerated, 7500);
        expect(result.hrvRecordsGenerated, 750);
        expect(result.rrRecordsGenerated, 365);
        expect(result.stepsRecordsGenerated, 365);
        expect(result.sleepRecordsGenerated, 365);
        expect(result.errors, ['Minor warning']);
      });

      test('success factory uses default values for optional parameters', () {
        final result = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
        );

        expect(result.stepsRecordsGenerated, 0);
        expect(result.sleepRecordsGenerated, 0);
        expect(result.errors, isEmpty);
      });

      test('permissionDenied factory creates permission denied result', () {
        final result = GenerationResult.permissionDenied();

        expect(result.status, GenerationStatus.permissionDenied);
        expect(result.hrRecordsGenerated, 0);
        expect(result.hrvRecordsGenerated, 0);
        expect(result.rrRecordsGenerated, 0);
        expect(result.stepsRecordsGenerated, 0);
        expect(result.sleepRecordsGenerated, 0);
        expect(result.generationTime, Duration.zero);
        expect(result.errors, ['HealthKit write permission denied']);
      });

      test('error factory creates error result', () {
        final result = GenerationResult.error('HealthKit unavailable');

        expect(result.status, GenerationStatus.error);
        expect(result.hrRecordsGenerated, 0);
        expect(result.hrvRecordsGenerated, 0);
        expect(result.rrRecordsGenerated, 0);
        expect(result.stepsRecordsGenerated, 0);
        expect(result.sleepRecordsGenerated, 0);
        expect(result.generationTime, Duration.zero);
        expect(result.errors, ['HealthKit unavailable']);
      });
    });

    group('computed properties', () {
      test('totalRecords sums all record counts', () {
        final result = GenerationResult(
          hrRecordsGenerated: 7500,
          hrvRecordsGenerated: 750,
          rrRecordsGenerated: 365,
          stepsRecordsGenerated: 365,
          sleepRecordsGenerated: 365,
          generationTime: const Duration(seconds: 8),
          status: GenerationStatus.success,
        );

        expect(result.totalRecords, 9345);
      });

      test('totalRecords excludes optional records when not generated', () {
        final result = GenerationResult(
          hrRecordsGenerated: 5000,
          hrvRecordsGenerated: 600,
          rrRecordsGenerated: 365,
          generationTime: const Duration(seconds: 5),
          status: GenerationStatus.success,
        );

        expect(result.totalRecords, 5965);
      });

      test('isSuccess returns true for success status', () {
        final result = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
        );

        expect(result.isSuccess, isTrue);
      });

      test('isSuccess returns false for non-success status', () {
        final permissionResult = GenerationResult.permissionDenied();
        final errorResult = GenerationResult.error('Test error');

        expect(permissionResult.isSuccess, isFalse);
        expect(errorResult.isSuccess, isFalse);
      });

      test('hasErrors returns true when errors list is not empty', () {
        final result = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
          errors: const ['Warning'],
        );

        expect(result.hasErrors, isTrue);
      });

      test('hasErrors returns false when errors list is empty', () {
        final result = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
        );

        expect(result.hasErrors, isFalse);
      });
    });

    group('toLogSummary', () {
      test('formats basic summary with required data types', () {
        final result = GenerationResult.success(
          hrRecords: 7500,
          hrvRecords: 750,
          rrRecords: 365,
          generationTime: const Duration(seconds: 8),
        );

        expect(
          result.toLogSummary(),
          '[SynthData] Generated 7500 HR records, 750 HRV records, 365 RR records in 8s',
        );
      });

      test('includes optional data types when present', () {
        final result = GenerationResult.success(
          hrRecords: 7500,
          hrvRecords: 750,
          rrRecords: 365,
          stepsRecords: 365,
          sleepRecords: 365,
          generationTime: const Duration(seconds: 10),
        );

        expect(
          result.toLogSummary(),
          '[SynthData] Generated 7500 HR records, 750 HRV records, 365 RR records, 365 Steps records, 365 Sleep records in 10s',
        );
      });

      test('includes error count when errors present', () {
        final result = GenerationResult.success(
          hrRecords: 7500,
          hrvRecords: 750,
          rrRecords: 365,
          generationTime: const Duration(seconds: 8),
          errors: const ['Error 1', 'Error 2'],
        );

        expect(
          result.toLogSummary(),
          '[SynthData] Generated 7500 HR records, 750 HRV records, 365 RR records in 8s (2 errors)',
        );
      });
    });

    group('toDisplaySummary', () {
      test('formats success summary with required data types', () {
        final result = GenerationResult.success(
          hrRecords: 7500,
          hrvRecords: 750,
          rrRecords: 365,
          generationTime: const Duration(seconds: 8),
        );

        final summary = result.toDisplaySummary();
        expect(summary, contains('Generated HR records: 7500'));
        expect(summary, contains('Generated HRV records: 750'));
        expect(summary, contains('Generated RR records: 365'));
        expect(summary, contains('Total: 8615 records'));
        expect(summary, contains('Time: 8s'));
      });

      test('includes optional data types when present', () {
        final result = GenerationResult.success(
          hrRecords: 7500,
          hrvRecords: 750,
          rrRecords: 365,
          stepsRecords: 365,
          sleepRecords: 365,
          generationTime: const Duration(seconds: 10),
        );

        final summary = result.toDisplaySummary();
        expect(summary, contains('Generated Steps records: 365'));
        expect(summary, contains('Generated Sleep records: 365'));
        expect(summary, contains('Total: 9345 records'));
      });

      test('shows permission denied message', () {
        final result = GenerationResult.permissionDenied();

        expect(
          result.toDisplaySummary(),
          'Permission denied. Please enable HealthKit access in Settings.',
        );
      });

      test('shows error message', () {
        final result = GenerationResult.error('HealthKit unavailable');

        expect(
          result.toDisplaySummary(),
          'Generation failed: HealthKit unavailable',
        );
      });

      test('includes warning count when errors present', () {
        final result = GenerationResult.success(
          hrRecords: 7500,
          hrvRecords: 750,
          rrRecords: 365,
          generationTime: const Duration(seconds: 8),
          errors: const ['Warning 1', 'Warning 2', 'Warning 3'],
        );

        final summary = result.toDisplaySummary();
        expect(summary, contains('Warnings: 3 issues encountered'));
      });
    });

    group('copyWith', () {
      test('creates copy with overridden values', () {
        final original = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
        );

        final copy = original.copyWith(
          hrRecordsGenerated: 7500,
          errors: ['New error'],
        );

        expect(copy.hrRecordsGenerated, 7500);
        expect(copy.hrvRecordsGenerated, 600); // unchanged
        expect(copy.rrRecordsGenerated, 365); // unchanged
        expect(copy.errors, ['New error']);
      });

      test('preserves original values when no overrides', () {
        final original = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
        );

        final copy = original.copyWith();

        expect(copy.hrRecordsGenerated, original.hrRecordsGenerated);
        expect(copy.hrvRecordsGenerated, original.hrvRecordsGenerated);
        expect(copy.rrRecordsGenerated, original.rrRecordsGenerated);
        expect(copy.status, original.status);
      });
    });

    group('equality and hashCode', () {
      test('equal results have same hashCode', () {
        final result1 = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
        );

        final result2 = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('different results are not equal', () {
        final result1 = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
        );

        final result2 = GenerationResult.success(
          hrRecords: 7500,
          hrvRecords: 750,
          rrRecords: 365,
          generationTime: const Duration(seconds: 8),
        );

        expect(result1, isNot(equals(result2)));
      });

      test('results with different errors are not equal', () {
        final result1 = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
          errors: const ['Error 1'],
        );

        final result2 = GenerationResult.success(
          hrRecords: 5000,
          hrvRecords: 600,
          rrRecords: 365,
          generationTime: const Duration(seconds: 5),
          errors: const ['Error 2'],
        );

        expect(result1, isNot(equals(result2)));
      });
    });

    group('toString', () {
      test('provides readable string representation', () {
        final result = GenerationResult.success(
          hrRecords: 7500,
          hrvRecords: 750,
          rrRecords: 365,
          stepsRecords: 365,
          sleepRecords: 365,
          generationTime: const Duration(seconds: 8),
          errors: const ['Warning'],
        );

        final str = result.toString();
        expect(str, contains('GenerationResult'));
        expect(str, contains('hrRecords: 7500'));
        expect(str, contains('hrvRecords: 750'));
        expect(str, contains('rrRecords: 365'));
        expect(str, contains('stepsRecords: 365'));
        expect(str, contains('sleepRecords: 365'));
        expect(str, contains('time: 8s'));
        expect(str, contains('status: GenerationStatus.success'));
        expect(str, contains('errors: 1'));
      });
    });
  });

  group('GenerationStatus', () {
    test('has all expected values', () {
      expect(GenerationStatus.values, hasLength(3));
      expect(GenerationStatus.values, contains(GenerationStatus.success));
      expect(
          GenerationStatus.values, contains(GenerationStatus.permissionDenied));
      expect(GenerationStatus.values, contains(GenerationStatus.error));
    });
  });
}
