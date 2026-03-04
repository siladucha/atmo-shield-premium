import 'dart:math';
import '../models/health_data_point.dart';
import '../utils/gaussian_distribution.dart';
import '../utils/trend_calculator.dart';

/// Generates realistic Heart Rate data across a 365-day period.
///
/// Produces 5000-10000 HR records with:
/// - Timestamp spacing: 5-30 minute intervals with random distribution
/// - Time-of-day variation: resting (60-80 bpm) vs active (90-120 bpm)
/// - Gradual trend decrease for cardiovascular improvement
/// - Realistic daily activity cycles
///
/// **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6**
class HeartRateGenerator {
  final Random _random;
  final GaussianDistribution _gaussian;
  final TrendCalculator _trendCalculator;

  /// Creates a HeartRateGenerator with optional random seed for reproducibility.
  HeartRateGenerator({int? seed})
      : _random = Random(seed),
        _gaussian = GaussianDistribution(seed: seed),
        _trendCalculator = TrendCalculator(seed: seed);

  /// Generates Heart Rate data points across the specified date range.
  ///
  /// Parameters:
  /// - [start]: Start date of the generation period
  /// - [end]: End date of the generation period
  /// - [targetCount]: Target number of HR records (recommended 5000-10000 for 365 days)
  ///
  /// Returns a list of HealthDataPoint objects with type 'heartRate' and unit 'bpm'.
  ///
  /// The method:
  /// 1. Generates timestamps with 5-30 minute spacing
  /// 2. Applies time-of-day variation (resting vs active periods)
  /// 3. Adds gradual downward trend for cardiovascular improvement
  /// 4. Adds Gaussian noise for realistic variation
  ///
  /// Note: For production use with 365 days, targetCount should be 5000-10000.
  /// Smaller values are allowed for testing purposes.
  List<HealthDataPoint> generate(
    DateTime start,
    DateTime end, {
    int targetCount = 7500, // Default to middle of 5000-10000 range
  }) {
    // Validate target count is positive
    if (targetCount <= 0) {
      throw ArgumentError('targetCount must be positive, got $targetCount');
    }

    final records = <HealthDataPoint>[];
    DateTime currentTime = start;

    // Generate records until we reach target count or end date
    while (records.length < targetCount && currentTime.isBefore(end)) {
      // Generate HR value for this timestamp
      final hrValue = _generateHRValue(currentTime, start);

      // Create data point
      records.add(HealthDataPoint(
        type: 'heartRate',
        value: hrValue,
        timestamp: currentTime,
        unit: 'bpm',
      ));

      // Calculate next timestamp with 5-30 minute spacing
      final intervalMinutes = 5 + _random.nextInt(26); // 5-30 minutes
      currentTime = currentTime.add(Duration(minutes: intervalMinutes));
    }

    return records;
  }

  /// Generates a realistic HR value for the given timestamp.
  ///
  /// Combines:
  /// - Baseline HR with downward trend (cardiovascular improvement)
  /// - Time-of-day variation (resting vs active)
  /// - Gaussian noise for natural variation
  double _generateHRValue(DateTime timestamp, DateTime startDate) {
    // Get baseline HR with downward trend
    // Start at 75 bpm average, decrease by ~5% over 365 days
    final baselineHR = _getBaselineHR(timestamp, startDate);

    // Get time-of-day adjustment
    final timeAdjustment = _getTimeOfDayAdjustment(timestamp);

    // Calculate final HR with time-of-day variation
    final targetHR = baselineHR + timeAdjustment;

    // Add Gaussian noise (±5 bpm standard deviation)
    final hrWithNoise = _gaussian.sample(targetHR, 5.0);

    // Clamp to valid HR range (40-200 bpm)
    return _gaussian.clamp(hrWithNoise, 40.0, 200.0);
  }

  /// Calculates baseline HR with gradual downward trend.
  ///
  /// Simulates cardiovascular improvement over time:
  /// - Starts at 75 bpm average
  /// - Decreases by ~5% over 365 days
  /// - Uses TrendCalculator for smooth linear trend
  double _getBaselineHR(DateTime currentDate, DateTime startDate) {
    const baseHR = 75.0; // Average baseline HR
    const trendPercentage = -0.05; // 5% decrease over trend period
    const trendDurationDays = 365; // Full year trend

    return _trendCalculator.getValueWithTrend(
      baseHR,
      currentDate,
      startDate,
      trendDurationDays,
      trendPercentage,
    );
  }

  /// Returns time-of-day adjustment for HR variation.
  ///
  /// Simulates daily activity cycles:
  /// - Resting periods (night/early morning): -10 to -5 bpm
  /// - Active periods (day/afternoon): +15 to +25 bpm
  /// - Transition periods: intermediate values
  ///
  /// Time periods:
  /// - 00:00-06:00: Deep rest (lowest HR)
  /// - 06:00-09:00: Morning transition
  /// - 09:00-18:00: Active day (highest HR)
  /// - 18:00-22:00: Evening transition
  /// - 22:00-24:00: Pre-sleep rest
  double _getTimeOfDayAdjustment(DateTime timestamp) {
    final hour = timestamp.hour;

    if (_isRestingTime(hour)) {
      // Resting period: -10 to -5 bpm adjustment
      // Results in 60-80 bpm range (baseline ~75 - 10 = 65 ± 5)
      return _gaussian.sample(-7.5, 2.5);
    } else if (_isActiveTime(hour)) {
      // Active period: +15 to +25 bpm adjustment
      // Results in 90-120 bpm range (baseline ~75 + 20 = 95 ± 15)
      return _gaussian.sample(20.0, 10.0);
    } else {
      // Transition period: 0 to +10 bpm adjustment
      return _gaussian.sample(5.0, 5.0);
    }
  }

  /// Returns true if the hour is during resting time.
  ///
  /// Resting periods: 00:00-06:00 and 22:00-24:00
  bool _isRestingTime(int hour) {
    return hour < 6 || hour >= 22;
  }

  /// Returns true if the hour is during active time.
  ///
  /// Active periods: 09:00-18:00
  bool _isActiveTime(int hour) {
    return hour >= 9 && hour < 18;
  }
}
