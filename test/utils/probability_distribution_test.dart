import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/utils/probability_distribution.dart';

void main() {
  group('ProbabilityDistribution', () {
    test('sampleDiscrete returns values from the distribution', () {
      final distribution = ProbabilityDistribution(seed: 42);
      final probabilities = {0: 0.5, 1: 0.3, 2: 0.2};

      // Generate samples
      final samples =
          List.generate(100, (_) => distribution.sampleDiscrete(probabilities));

      // All samples should be valid keys
      expect(samples.every((s) => probabilities.containsKey(s)), isTrue);
    });

    test('sampleDiscrete respects probability distribution over many samples',
        () {
      final distribution = ProbabilityDistribution(seed: 123);
      final probabilities = {0: 0.5, 1: 0.3, 2: 0.2};
      const sampleSize = 10000;

      // Generate many samples
      final samples = List.generate(
          sampleSize, (_) => distribution.sampleDiscrete(probabilities));

      // Count occurrences
      final counts = <int, int>{};
      for (final sample in samples) {
        counts[sample] = (counts[sample] ?? 0) + 1;
      }

      // Check that frequencies match probabilities (within 5% tolerance)
      for (final entry in probabilities.entries) {
        final expectedCount = sampleSize * entry.value;
        final actualCount = counts[entry.key] ?? 0;
        expect(actualCount, closeTo(expectedCount, expectedCount * 0.05));
      }
    });

    test('sampleDiscrete with seed produces deterministic results', () {
      final distribution1 = ProbabilityDistribution(seed: 999);
      final distribution2 = ProbabilityDistribution(seed: 999);
      final probabilities = {0: 0.35, 1: 0.45, 2: 0.20};

      final samples1 = List.generate(
          100, (_) => distribution1.sampleDiscrete(probabilities));
      final samples2 = List.generate(
          100, (_) => distribution2.sampleDiscrete(probabilities));

      // Same seed should produce identical sequences
      for (int i = 0; i < 100; i++) {
        expect(samples1[i], equals(samples2[i]));
      }
    });

    test('sampleDiscrete without seed produces different results', () {
      final distribution1 = ProbabilityDistribution();
      final distribution2 = ProbabilityDistribution();
      final probabilities = {0: 0.35, 1: 0.45, 2: 0.20};

      final samples1 = List.generate(
          100, (_) => distribution1.sampleDiscrete(probabilities));
      final samples2 = List.generate(
          100, (_) => distribution2.sampleDiscrete(probabilities));

      // Different instances should produce different sequences
      int differences = 0;
      for (int i = 0; i < 100; i++) {
        if (samples1[i] != samples2[i]) differences++;
      }

      // Expect at least 50% of values to be different
      expect(differences, greaterThan(50));
    });

    test('sampleDiscrete normalizes probabilities that do not sum to 1.0', () {
      final distribution = ProbabilityDistribution(seed: 456);
      // Probabilities sum to 2.0 instead of 1.0
      final probabilities = {0: 1.0, 1: 0.6, 2: 0.4};
      const sampleSize = 10000;

      final samples = List.generate(
          sampleSize, (_) => distribution.sampleDiscrete(probabilities));

      // Count occurrences
      final counts = <int, int>{};
      for (final sample in samples) {
        counts[sample] = (counts[sample] ?? 0) + 1;
      }

      // After normalization: 0: 0.5, 1: 0.3, 2: 0.2
      expect(counts[0]! / sampleSize, closeTo(0.5, 0.05));
      expect(counts[1]! / sampleSize, closeTo(0.3, 0.05));
      expect(counts[2]! / sampleSize, closeTo(0.2, 0.05));
    });

    test('sampleDiscrete throws on empty probabilities map', () {
      final distribution = ProbabilityDistribution();
      expect(
        () => distribution.sampleDiscrete({}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sampleDiscrete throws on zero total probability', () {
      final distribution = ProbabilityDistribution();
      final probabilities = {0: 0.0, 1: 0.0, 2: 0.0};
      expect(
        () => distribution.sampleDiscrete(probabilities),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sampleDiscrete throws on negative total probability', () {
      final distribution = ProbabilityDistribution();
      final probabilities = {0: -0.5, 1: -0.3, 2: -0.2};
      expect(
        () => distribution.sampleDiscrete(probabilities),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sampleDiscrete handles single outcome', () {
      final distribution = ProbabilityDistribution(seed: 789);
      final probabilities = {42: 1.0};

      final samples =
          List.generate(100, (_) => distribution.sampleDiscrete(probabilities));

      // All samples should be the single outcome
      expect(samples.every((s) => s == 42), isTrue);
    });

    test('sampleDiscrete handles very small probabilities', () {
      final distribution = ProbabilityDistribution(seed: 321);
      final probabilities = {
        0: 0.001,
        1: 0.001,
        2: 0.998,
      };
      const sampleSize = 10000;

      final samples = List.generate(
          sampleSize, (_) => distribution.sampleDiscrete(probabilities));

      // Count occurrences
      final counts = <int, int>{};
      for (final sample in samples) {
        counts[sample] = (counts[sample] ?? 0) + 1;
      }

      // Most samples should be 2
      expect(counts[2]! / sampleSize, closeTo(0.998, 0.01));

      // 0 and 1 should appear rarely but might appear
      expect(counts[0] ?? 0, lessThan(50));
      expect(counts[1] ?? 0, lessThan(50));
    });

    test('hrvDailyRecordDistribution returns correct distribution', () {
      final distribution = ProbabilityDistribution.hrvDailyRecordDistribution();

      // Check all required keys are present
      expect(distribution.keys, containsAll([0, 1, 2, 3, 4, 5]));

      // Check probabilities match requirements
      expect(distribution[0], equals(0.35)); // 35% have 0 records
      expect(distribution[1], equals(0.225)); // 22.5% have 1 record
      expect(distribution[2], equals(0.225)); // 22.5% have 2 records
      expect(distribution[3], equals(0.12)); // 12% have 3 records
      expect(distribution[4], equals(0.05)); // 5% have 4 records
      expect(distribution[5], equals(0.03)); // 3% have 5 records

      // Check that probabilities sum to 1.0
      final total = distribution.values.reduce((a, b) => a + b);
      expect(total, closeTo(1.0, 0.0001));
    });

    test('hrvDailyRecordDistribution matches requirement 3.2 distribution', () {
      final probDist = ProbabilityDistribution(seed: 654);
      final distribution = ProbabilityDistribution.hrvDailyRecordDistribution();
      const sampleSize = 10000;

      // Generate samples
      final samples = List.generate(
          sampleSize, (_) => probDist.sampleDiscrete(distribution));

      // Count occurrences
      final counts = <int, int>{};
      for (final sample in samples) {
        counts[sample] = (counts[sample] ?? 0) + 1;
      }

      // Check requirement 3.2: 35% have 0 records
      final zeroRecords = counts[0] ?? 0;
      expect(zeroRecords / sampleSize, closeTo(0.35, 0.02));

      // Check requirement 3.2: 45% have 1-2 records
      final oneToTwoRecords = (counts[1] ?? 0) + (counts[2] ?? 0);
      expect(oneToTwoRecords / sampleSize, closeTo(0.45, 0.02));

      // Check requirement 3.2: 20% have 3-5 records
      final threeToFiveRecords =
          (counts[3] ?? 0) + (counts[4] ?? 0) + (counts[5] ?? 0);
      expect(threeToFiveRecords / sampleSize, closeTo(0.20, 0.02));
    });

    test('sampleDiscrete works with negative outcome values', () {
      final distribution = ProbabilityDistribution(seed: 111);
      final probabilities = {-2: 0.3, -1: 0.3, 0: 0.4};

      final samples = List.generate(
          1000, (_) => distribution.sampleDiscrete(probabilities));

      // All samples should be valid keys
      expect(samples.every((s) => probabilities.containsKey(s)), isTrue);

      // Count occurrences
      final counts = <int, int>{};
      for (final sample in samples) {
        counts[sample] = (counts[sample] ?? 0) + 1;
      }

      // Check approximate distribution
      expect(counts[-2]! / 1000, closeTo(0.3, 0.05));
      expect(counts[-1]! / 1000, closeTo(0.3, 0.05));
      expect(counts[0]! / 1000, closeTo(0.4, 0.05));
    });

    test('sampleDiscrete works with large outcome values', () {
      final distribution = ProbabilityDistribution(seed: 222);
      final probabilities = {1000: 0.5, 2000: 0.3, 3000: 0.2};

      final samples = List.generate(
          1000, (_) => distribution.sampleDiscrete(probabilities));

      // All samples should be valid keys
      expect(samples.every((s) => probabilities.containsKey(s)), isTrue);

      // Count occurrences
      final counts = <int, int>{};
      for (final sample in samples) {
        counts[sample] = (counts[sample] ?? 0) + 1;
      }

      // Check approximate distribution
      expect(counts[1000]! / 1000, closeTo(0.5, 0.05));
      expect(counts[2000]! / 1000, closeTo(0.3, 0.05));
      expect(counts[3000]! / 1000, closeTo(0.2, 0.05));
    });

    test('sampleDiscrete handles unordered keys', () {
      final distribution = ProbabilityDistribution(seed: 333);
      // Keys are not in ascending order
      final probabilities = {5: 0.2, 1: 0.3, 3: 0.5};

      final samples = List.generate(
          1000, (_) => distribution.sampleDiscrete(probabilities));

      // All samples should be valid keys
      expect(samples.every((s) => probabilities.containsKey(s)), isTrue);

      // Count occurrences
      final counts = <int, int>{};
      for (final sample in samples) {
        counts[sample] = (counts[sample] ?? 0) + 1;
      }

      // Check approximate distribution
      expect(counts[5]! / 1000, closeTo(0.2, 0.05));
      expect(counts[1]! / 1000, closeTo(0.3, 0.05));
      expect(counts[3]! / 1000, closeTo(0.5, 0.05));
    });
  });
}
