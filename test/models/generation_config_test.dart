import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/models/generation_config.dart';

void main() {
  group('GenerationConfig', () {
    group('constructor', () {
      test('creates config with default values', () {
        const config = GenerationConfig();

        expect(config.includeSteps, false);
        expect(config.includeSleep, false);
        expect(config.targetHRRecords, 7500);
        expect(config.hrvTrendGrowth, 0.15);
        expect(config.trendDurationMonths, 4);
      });

      test('creates config with custom values', () {
        const config = GenerationConfig(
          includeSteps: true,
          includeSleep: true,
          targetHRRecords: 8000,
          hrvTrendGrowth: 0.18,
          trendDurationMonths: 5,
        );

        expect(config.includeSteps, true);
        expect(config.includeSleep, true);
        expect(config.targetHRRecords, 8000);
        expect(config.hrvTrendGrowth, 0.18);
        expect(config.trendDurationMonths, 5);
      });

      test('validates targetHRRecords minimum bound', () {
        expect(
          () => GenerationConfig(targetHRRecords: 4999),
          throwsA(isA<AssertionError>()),
        );
      });

      test('validates targetHRRecords maximum bound', () {
        expect(
          () => GenerationConfig(targetHRRecords: 10001),
          throwsA(isA<AssertionError>()),
        );
      });

      test('accepts targetHRRecords at minimum bound', () {
        const config = GenerationConfig(targetHRRecords: 5000);
        expect(config.targetHRRecords, 5000);
      });

      test('accepts targetHRRecords at maximum bound', () {
        const config = GenerationConfig(targetHRRecords: 10000);
        expect(config.targetHRRecords, 10000);
      });

      test('validates hrvTrendGrowth minimum bound', () {
        expect(
          () => GenerationConfig(hrvTrendGrowth: 0.09),
          throwsA(isA<AssertionError>()),
        );
      });

      test('validates hrvTrendGrowth maximum bound', () {
        expect(
          () => GenerationConfig(hrvTrendGrowth: 0.21),
          throwsA(isA<AssertionError>()),
        );
      });

      test('accepts hrvTrendGrowth at minimum bound', () {
        const config = GenerationConfig(hrvTrendGrowth: 0.10);
        expect(config.hrvTrendGrowth, 0.10);
      });

      test('accepts hrvTrendGrowth at maximum bound', () {
        const config = GenerationConfig(hrvTrendGrowth: 0.20);
        expect(config.hrvTrendGrowth, 0.20);
      });

      test('validates trendDurationMonths minimum bound', () {
        expect(
          () => GenerationConfig(trendDurationMonths: 2),
          throwsA(isA<AssertionError>()),
        );
      });

      test('validates trendDurationMonths maximum bound', () {
        expect(
          () => GenerationConfig(trendDurationMonths: 7),
          throwsA(isA<AssertionError>()),
        );
      });

      test('accepts trendDurationMonths at minimum bound', () {
        const config = GenerationConfig(trendDurationMonths: 3);
        expect(config.trendDurationMonths, 3);
      });

      test('accepts trendDurationMonths at maximum bound', () {
        const config = GenerationConfig(trendDurationMonths: 6);
        expect(config.trendDurationMonths, 6);
      });
    });

    group('factory constructors', () {
      test('defaultConfig creates config with default values', () {
        final config = GenerationConfig.defaultConfig();

        expect(config.includeSteps, false);
        expect(config.includeSleep, false);
        expect(config.targetHRRecords, 7500);
        expect(config.hrvTrendGrowth, 0.15);
        expect(config.trendDurationMonths, 4);
      });

      test('withAllFeatures enables all optional features', () {
        final config = GenerationConfig.withAllFeatures();

        expect(config.includeSteps, true);
        expect(config.includeSleep, true);
        expect(config.targetHRRecords, 7500);
        expect(config.hrvTrendGrowth, 0.15);
        expect(config.trendDurationMonths, 4);
      });

      test('minimal creates config with minimum values', () {
        final config = GenerationConfig.minimal();

        expect(config.includeSteps, false);
        expect(config.includeSleep, false);
        expect(config.targetHRRecords, 5000);
        expect(config.hrvTrendGrowth, 0.15);
        expect(config.trendDurationMonths, 3);
      });

      test('maximal creates config with maximum values', () {
        final config = GenerationConfig.maximal();

        expect(config.includeSteps, true);
        expect(config.includeSleep, true);
        expect(config.targetHRRecords, 10000);
        expect(config.hrvTrendGrowth, 0.20);
        expect(config.trendDurationMonths, 6);
      });
    });

    group('copyWith', () {
      test('creates copy with no changes when no parameters provided', () {
        const original = GenerationConfig(
          includeSteps: true,
          targetHRRecords: 8000,
        );

        final copy = original.copyWith();

        expect(copy.includeSteps, original.includeSteps);
        expect(copy.includeSleep, original.includeSleep);
        expect(copy.targetHRRecords, original.targetHRRecords);
        expect(copy.hrvTrendGrowth, original.hrvTrendGrowth);
        expect(copy.trendDurationMonths, original.trendDurationMonths);
      });

      test('creates copy with includeSteps changed', () {
        const original = GenerationConfig(includeSteps: false);
        final copy = original.copyWith(includeSteps: true);

        expect(copy.includeSteps, true);
        expect(copy.includeSleep, original.includeSleep);
      });

      test('creates copy with includeSleep changed', () {
        const original = GenerationConfig(includeSleep: false);
        final copy = original.copyWith(includeSleep: true);

        expect(copy.includeSleep, true);
        expect(copy.includeSteps, original.includeSteps);
      });

      test('creates copy with targetHRRecords changed', () {
        const original = GenerationConfig(targetHRRecords: 7500);
        final copy = original.copyWith(targetHRRecords: 9000);

        expect(copy.targetHRRecords, 9000);
        expect(copy.hrvTrendGrowth, original.hrvTrendGrowth);
      });

      test('creates copy with hrvTrendGrowth changed', () {
        const original = GenerationConfig(hrvTrendGrowth: 0.15);
        final copy = original.copyWith(hrvTrendGrowth: 0.18);

        expect(copy.hrvTrendGrowth, 0.18);
        expect(copy.targetHRRecords, original.targetHRRecords);
      });

      test('creates copy with trendDurationMonths changed', () {
        const original = GenerationConfig(trendDurationMonths: 4);
        final copy = original.copyWith(trendDurationMonths: 5);

        expect(copy.trendDurationMonths, 5);
        expect(copy.hrvTrendGrowth, original.hrvTrendGrowth);
      });

      test('creates copy with multiple parameters changed', () {
        const original = GenerationConfig();
        final copy = original.copyWith(
          includeSteps: true,
          includeSleep: true,
          targetHRRecords: 9000,
        );

        expect(copy.includeSteps, true);
        expect(copy.includeSleep, true);
        expect(copy.targetHRRecords, 9000);
        expect(copy.hrvTrendGrowth, original.hrvTrendGrowth);
        expect(copy.trendDurationMonths, original.trendDurationMonths);
      });
    });

    group('toString', () {
      test('returns string representation with all properties', () {
        const config = GenerationConfig(
          includeSteps: true,
          includeSleep: false,
          targetHRRecords: 8000,
          hrvTrendGrowth: 0.18,
          trendDurationMonths: 5,
        );

        final str = config.toString();

        expect(str, contains('GenerationConfig'));
        expect(str, contains('includeSteps: true'));
        expect(str, contains('includeSleep: false'));
        expect(str, contains('targetHRRecords: 8000'));
        expect(str, contains('hrvTrendGrowth: 0.18'));
        expect(str, contains('trendDurationMonths: 5'));
      });
    });

    group('equality', () {
      test('two configs with same values are equal', () {
        const config1 = GenerationConfig(
          includeSteps: true,
          targetHRRecords: 8000,
        );
        const config2 = GenerationConfig(
          includeSteps: true,
          targetHRRecords: 8000,
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('two configs with different includeSteps are not equal', () {
        const config1 = GenerationConfig(includeSteps: true);
        const config2 = GenerationConfig(includeSteps: false);

        expect(config1, isNot(equals(config2)));
      });

      test('two configs with different includeSleep are not equal', () {
        const config1 = GenerationConfig(includeSleep: true);
        const config2 = GenerationConfig(includeSleep: false);

        expect(config1, isNot(equals(config2)));
      });

      test('two configs with different targetHRRecords are not equal', () {
        const config1 = GenerationConfig(targetHRRecords: 7500);
        const config2 = GenerationConfig(targetHRRecords: 8000);

        expect(config1, isNot(equals(config2)));
      });

      test('two configs with different hrvTrendGrowth are not equal', () {
        const config1 = GenerationConfig(hrvTrendGrowth: 0.15);
        const config2 = GenerationConfig(hrvTrendGrowth: 0.18);

        expect(config1, isNot(equals(config2)));
      });

      test('two configs with different trendDurationMonths are not equal', () {
        const config1 = GenerationConfig(trendDurationMonths: 4);
        const config2 = GenerationConfig(trendDurationMonths: 5);

        expect(config1, isNot(equals(config2)));
      });

      test('config is equal to itself', () {
        const config = GenerationConfig();

        expect(config, equals(config));
      });
    });
  });
}
