import 'package:flutter_test/flutter_test.dart';
import 'package:atmo_shield_premium/utils/trend_calculator.dart';

void main() {
  group('TrendCalculator', () {
    test('returns base value at start of trend period', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 1, 1); // Same as start
      
      final value = calculator.getValueWithTrend(
        50.0,           // base value
        currentDate,
        startDate,
        180,            // 6 months
        0.15,           // 15% increase
      );
      
      // At start, progress = 0, so value should be close to base (50.0) with noise
      // Allow ±20% variance for noise (10% stdDev means ~95% within ±20%)
      expect(value, greaterThan(40.0));
      expect(value, lessThan(60.0));
    });

    test('returns increased value at end of trend period', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 6, 30); // 180 days later
      
      final value = calculator.getValueWithTrend(
        50.0,           // base value
        currentDate,
        startDate,
        180,            // 6 months
        0.15,           // 15% increase
      );
      
      // At end, progress = 1.0, so value should be 50 * 1.15 = 57.5 with noise
      // Allow ±20% variance: 57.5 * 0.8 = 46, 57.5 * 1.2 = 69
      expect(value, greaterThan(46.0));
      expect(value, lessThan(69.0));
    });

    test('returns mid-trend value at halfway point', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 3, 31); // 90 days later (halfway)
      
      final value = calculator.getValueWithTrend(
        50.0,           // base value
        currentDate,
        startDate,
        180,            // 6 months
        0.15,           // 15% increase
      );
      
      // At halfway, progress = 0.5, so value should be 50 * 1.075 = 53.75 with noise
      // Allow ±20% variance: 53.75 * 0.8 = 43, 53.75 * 1.2 = 64.5
      expect(value, greaterThan(43.0));
      expect(value, lessThan(64.5));
    });

    test('handles negative trend (decrease)', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 6, 30); // 180 days later
      
      final value = calculator.getValueWithTrend(
        80.0,           // base value (e.g., heart rate)
        currentDate,
        startDate,
        180,            // 6 months
        -0.10,          // 10% decrease
      );
      
      // At end, progress = 1.0, so value should be 80 * 0.90 = 72.0 with noise
      // Allow ±20% variance: 72 * 0.8 = 57.6, 72 * 1.2 = 86.4
      expect(value, greaterThan(57.6));
      expect(value, lessThan(86.4));
    });

    test('clamps progress to 1.0 after trend period ends', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 12, 31); // 365 days later (beyond 180)
      
      final value = calculator.getValueWithTrend(
        50.0,           // base value
        currentDate,
        startDate,
        180,            // 6 months
        0.15,           // 15% increase
      );
      
      // Progress clamped to 1.0, so value should be 50 * 1.15 = 57.5 with noise
      // Allow ±20% variance: 57.5 * 0.8 = 46, 57.5 * 1.2 = 69
      expect(value, greaterThan(46.0));
      expect(value, lessThan(69.0));
    });

    test('handles date before start (negative progress)', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2023, 12, 1); // Before start
      
      final value = calculator.getValueWithTrend(
        50.0,           // base value
        currentDate,
        startDate,
        180,            // 6 months
        0.15,           // 15% increase
      );
      
      // Progress clamped to 0.0, so value should be close to base (50.0) with noise
      expect(value, greaterThan(40.0));
      expect(value, lessThan(60.0));
    });

    test('returns non-negative values even with large negative noise', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      
      // Test multiple times to catch potential negative values
      for (int i = 0; i < 100; i++) {
        final currentDate = startDate.add(Duration(days: i));
        final value = calculator.getValueWithTrend(
          10.0,           // small base value
          currentDate,
          startDate,
          180,
          0.15,
        );
        
        expect(value, greaterThanOrEqualTo(0.0), 
          reason: 'Value should never be negative (iteration $i)');
      }
    });

    test('produces different values with different seeds', () {
      final calculator1 = TrendCalculator(seed: 42);
      final calculator2 = TrendCalculator(seed: 123);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 3, 1);
      
      final value1 = calculator1.getValueWithTrend(
        50.0, currentDate, startDate, 180, 0.15,
      );
      final value2 = calculator2.getValueWithTrend(
        50.0, currentDate, startDate, 180, 0.15,
      );
      
      // Different seeds should produce different noise, thus different values
      expect(value1, isNot(equals(value2)));
    });

    test('produces same values with same seed (reproducibility)', () {
      final calculator1 = TrendCalculator(seed: 42);
      final calculator2 = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 3, 1);
      
      final value1 = calculator1.getValueWithTrend(
        50.0, currentDate, startDate, 180, 0.15,
      );
      final value2 = calculator2.getValueWithTrend(
        50.0, currentDate, startDate, 180, 0.15,
      );
      
      // Same seed should produce identical values
      expect(value1, equals(value2));
    });

    test('handles zero trend percentage', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 6, 30);
      
      final value = calculator.getValueWithTrend(
        50.0,           // base value
        currentDate,
        startDate,
        180,
        0.0,            // No trend
      );
      
      // With 0% trend, value should be close to base (50.0) with noise
      expect(value, greaterThan(40.0));
      expect(value, lessThan(60.0));
    });

    test('handles very short trend duration', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 1, 8); // 7 days later
      
      final value = calculator.getValueWithTrend(
        50.0,           // base value
        currentDate,
        startDate,
        7,              // 1 week trend
        0.15,           // 15% increase
      );
      
      // At end of 1-week trend, value should be 50 * 1.15 = 57.5 with noise
      expect(value, greaterThan(46.0));
      expect(value, lessThan(69.0));
    });

    test('handles very long trend duration', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      final currentDate = DateTime(2024, 6, 30); // 180 days later
      
      final value = calculator.getValueWithTrend(
        50.0,           // base value
        currentDate,
        startDate,
        730,            // 2 years trend
        0.20,           // 20% increase
      );
      
      // At 180/730 progress (~0.247), value should be 50 * 1.0494 = 52.47 with noise
      expect(value, greaterThan(42.0));
      expect(value, lessThan(63.0));
    });

    test('trend increases over time with positive percentage', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      
      // Generate many values to average out noise
      final firstPeriodValues = <double>[];
      final lastPeriodValues = <double>[];
      
      // Sample first 30 days (multiple samples per day)
      for (int days = 0; days < 30; days++) {
        for (int sample = 0; sample < 3; sample++) {
          final currentDate = startDate.add(Duration(days: days, hours: sample * 8));
          final value = calculator.getValueWithTrend(
            50.0, currentDate, startDate, 180, 0.15,
          );
          firstPeriodValues.add(value);
        }
      }
      
      // Sample last 30 days (multiple samples per day)
      for (int days = 150; days < 180; days++) {
        for (int sample = 0; sample < 3; sample++) {
          final currentDate = startDate.add(Duration(days: days, hours: sample * 8));
          final value = calculator.getValueWithTrend(
            50.0, currentDate, startDate, 180, 0.15,
          );
          lastPeriodValues.add(value);
        }
      }
      
      // Calculate averages
      final avgFirst = firstPeriodValues.reduce((a, b) => a + b) / firstPeriodValues.length;
      final avgLast = lastPeriodValues.reduce((a, b) => a + b) / lastPeriodValues.length;
      
      // Last period should have higher average than first period
      // With +15% trend over 180 days, we expect ~13.75% increase (50 * 1.1375 = 56.875)
      expect(avgLast, greaterThan(avgFirst),
        reason: 'Trend should show increase over time');
    });

    test('trend decreases over time with negative percentage', () {
      final calculator = TrendCalculator(seed: 42);
      final startDate = DateTime(2024, 1, 1);
      
      // Generate many values to average out noise
      final firstPeriodValues = <double>[];
      final lastPeriodValues = <double>[];
      
      // Sample first 30 days (multiple samples per day)
      for (int days = 0; days < 30; days++) {
        for (int sample = 0; sample < 3; sample++) {
          final currentDate = startDate.add(Duration(days: days, hours: sample * 8));
          final value = calculator.getValueWithTrend(
            80.0, currentDate, startDate, 180, -0.10,
          );
          firstPeriodValues.add(value);
        }
      }
      
      // Sample last 30 days (multiple samples per day)
      for (int days = 150; days < 180; days++) {
        for (int sample = 0; sample < 3; sample++) {
          final currentDate = startDate.add(Duration(days: days, hours: sample * 8));
          final value = calculator.getValueWithTrend(
            80.0, currentDate, startDate, 180, -0.10,
          );
          lastPeriodValues.add(value);
        }
      }
      
      // Calculate averages
      final avgFirst = firstPeriodValues.reduce((a, b) => a + b) / firstPeriodValues.length;
      final avgLast = lastPeriodValues.reduce((a, b) => a + b) / lastPeriodValues.length;
      
      // Last period should have lower average than first period
      // With -10% trend over 180 days, we expect ~8% decrease (80 * 0.92 = 73.6)
      expect(avgLast, lessThan(avgFirst),
        reason: 'Trend should show decrease over time');
    });
  });
}
