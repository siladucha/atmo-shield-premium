import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/utils/gaussian_distribution.dart';
import 'dart:math';

void main() {
  group('GaussianDistribution', () {
    test('sample generates values with approximately correct mean', () {
      final gaussian = GaussianDistribution(seed: 42);
      const mean = 50.0;
      const stdDev = 10.0;
      const sampleSize = 10000;

      // Generate many samples
      final samples = List.generate(sampleSize, (_) => gaussian.sample(mean, stdDev));

      // Calculate sample mean
      final sampleMean = samples.reduce((a, b) => a + b) / sampleSize;

      // Sample mean should be close to target mean (within 1% for large sample)
      expect(sampleMean, closeTo(mean, mean * 0.01));
    });

    test('sample generates values with approximately correct standard deviation', () {
      final gaussian = GaussianDistribution(seed: 123);
      const mean = 50.0;
      const stdDev = 10.0;
      const sampleSize = 10000;

      // Generate many samples
      final samples = List.generate(sampleSize, (_) => gaussian.sample(mean, stdDev));

      // Calculate sample mean and standard deviation
      final sampleMean = samples.reduce((a, b) => a + b) / sampleSize;
      final variance = samples
          .map((x) => pow(x - sampleMean, 2))
          .reduce((a, b) => a + b) / sampleSize;
      final sampleStdDev = sqrt(variance);

      // Sample std dev should be close to target (within 5% for large sample)
      expect(sampleStdDev, closeTo(stdDev, stdDev * 0.05));
    });

    test('sample with seed produces deterministic results', () {
      final gaussian1 = GaussianDistribution(seed: 999);
      final gaussian2 = GaussianDistribution(seed: 999);

      final samples1 = List.generate(100, (_) => gaussian1.sample(50.0, 10.0));
      final samples2 = List.generate(100, (_) => gaussian2.sample(50.0, 10.0));

      // Same seed should produce identical sequences
      for (int i = 0; i < 100; i++) {
        expect(samples1[i], equals(samples2[i]));
      }
    });

    test('sample without seed produces different results', () {
      final gaussian1 = GaussianDistribution();
      final gaussian2 = GaussianDistribution();

      final samples1 = List.generate(100, (_) => gaussian1.sample(50.0, 10.0));
      final samples2 = List.generate(100, (_) => gaussian2.sample(50.0, 10.0));

      // Different instances should produce different sequences
      int differences = 0;
      for (int i = 0; i < 100; i++) {
        if (samples1[i] != samples2[i]) differences++;
      }

      // Expect at least 95% of values to be different
      expect(differences, greaterThan(95));
    });

    test('sample generates values across full distribution range', () {
      final gaussian = GaussianDistribution(seed: 456);
      const mean = 50.0;
      const stdDev = 10.0;
      const sampleSize = 10000;

      final samples = List.generate(sampleSize, (_) => gaussian.sample(mean, stdDev));

      // Check that we get values in different standard deviation ranges
      // ~68% should be within 1 stdDev, ~95% within 2 stdDev, ~99.7% within 3 stdDev
      final within1StdDev = samples.where((x) => (x - mean).abs() <= stdDev).length;
      final within2StdDev = samples.where((x) => (x - mean).abs() <= 2 * stdDev).length;
      final within3StdDev = samples.where((x) => (x - mean).abs() <= 3 * stdDev).length;

      expect(within1StdDev / sampleSize, closeTo(0.68, 0.05));
      expect(within2StdDev / sampleSize, closeTo(0.95, 0.05));
      expect(within3StdDev / sampleSize, closeTo(0.997, 0.01));
    });

    test('clamp returns value when within range', () {
      final gaussian = GaussianDistribution();
      expect(gaussian.clamp(50.0, 10.0, 100.0), equals(50.0));
      expect(gaussian.clamp(10.0, 10.0, 100.0), equals(10.0));
      expect(gaussian.clamp(100.0, 10.0, 100.0), equals(100.0));
    });

    test('clamp returns min when value below range', () {
      final gaussian = GaussianDistribution();
      expect(gaussian.clamp(5.0, 10.0, 100.0), equals(10.0));
      expect(gaussian.clamp(-50.0, 10.0, 100.0), equals(10.0));
      expect(gaussian.clamp(0.0, 10.0, 100.0), equals(10.0));
    });

    test('clamp returns max when value above range', () {
      final gaussian = GaussianDistribution();
      expect(gaussian.clamp(150.0, 10.0, 100.0), equals(100.0));
      expect(gaussian.clamp(200.0, 10.0, 100.0), equals(100.0));
      expect(gaussian.clamp(101.0, 10.0, 100.0), equals(100.0));
    });

    test('clamp handles edge cases', () {
      final gaussian = GaussianDistribution();
      
      // Same min and max
      expect(gaussian.clamp(50.0, 100.0, 100.0), equals(100.0));
      
      // Negative ranges
      expect(gaussian.clamp(-5.0, -10.0, -1.0), equals(-5.0));
      expect(gaussian.clamp(-15.0, -10.0, -1.0), equals(-10.0));
      expect(gaussian.clamp(0.0, -10.0, -1.0), equals(-1.0));
      
      // Zero values
      expect(gaussian.clamp(0.0, 0.0, 100.0), equals(0.0));
      expect(gaussian.clamp(0.0, -100.0, 0.0), equals(0.0));
    });

    test('sample works with different mean and stdDev values', () {
      final gaussian = GaussianDistribution(seed: 789);

      // Test with HRV-like values (mean=50ms, stdDev=10ms)
      final hrvSamples = List.generate(1000, (_) => gaussian.sample(50.0, 10.0));
      final hrvMean = hrvSamples.reduce((a, b) => a + b) / 1000;
      expect(hrvMean, closeTo(50.0, 2.0));

      // Test with HR-like values (mean=70bpm, stdDev=5bpm)
      final hrSamples = List.generate(1000, (_) => gaussian.sample(70.0, 5.0));
      final hrMean = hrSamples.reduce((a, b) => a + b) / 1000;
      expect(hrMean, closeTo(70.0, 1.0));

      // Test with RR-like values (mean=14bpm, stdDev=2bpm)
      final rrSamples = List.generate(1000, (_) => gaussian.sample(14.0, 2.0));
      final rrMean = rrSamples.reduce((a, b) => a + b) / 1000;
      expect(rrMean, closeTo(14.0, 0.5));
    });

    test('sample and clamp work together for realistic health data', () {
      final gaussian = GaussianDistribution(seed: 321);
      const mean = 50.0;
      const stdDev = 20.0;
      const min = 10.0;
      const max = 200.0;

      // Generate samples and clamp them
      final samples = List.generate(
        1000,
        (_) => gaussian.clamp(gaussian.sample(mean, stdDev), min, max),
      );

      // All values should be within range
      expect(samples.every((x) => x >= min && x <= max), isTrue);

      // Most values should not be clamped (since 3*stdDev = 60, range is much larger)
      final unclamped = samples.where((x) => x > min && x < max).length;
      expect(unclamped / samples.length, greaterThan(0.95));
    });
  });
}
