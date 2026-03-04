import 'dart:math';
import '../models/health_data_point.dart';
import '../utils/gaussian_distribution.dart';

/// Generates realistic daily step count data across a 365-day period.
///
/// Produces 365 records (one per day) with:
/// - Values between 5000-10000 steps with Gaussian distribution
/// - Weekend variation (slightly different patterns)
/// - Realistic daily activity patterns
///
/// **Validates: Requirement 5.1**
class StepsGenerator {
  final Random _random;
  final GaussianDistribution _gaussian;

  /// Creates a StepsGenerator with optional random seed for reproducibility.
  StepsGenerator({int? seed})
      : _random = Random(seed),
        _gaussian = GaussianDistribution(seed: seed);

  /// Generates daily step count data across the specified date range.
  ///
  /// Parameters:
  /// - [start]: Start date of the generation period
  /// - [end]: End date of the generation period
  ///
  /// Returns a list of 365 HealthDataPoint objects with type 'steps' and unit 'count'.
  ///
  /// The method:
  /// 1. Generates one record per day
  /// 2. Applies weekend variation (slightly lower step counts)
  /// 3. Uses Gaussian distribution centered at 7500 steps
  /// 4. Ensures values stay within 5000-10000 range
  ///
  /// **Validates: Requirement 5.1**
  List<HealthDataPoint> generate(DateTime start, DateTime end) {
    final records = <HealthDataPoint>[];
    final totalDays = end.difference(start).inDays;

    for (int dayOffset = 0; dayOffset < totalDays; dayOffset++) {
      final currentDate = start.add(Duration(days: dayOffset));

      // Generate step count for this day
      final stepCount = _generateStepCount(currentDate);

      // Create timestamp at a random time during the day (typically evening when daily total is recorded)
      final timestamp = _generateTimestamp(currentDate);

      records.add(HealthDataPoint(
        type: 'steps',
        value: stepCount,
        timestamp: timestamp,
        unit: 'count',
      ));
    }

    return records;
  }

  /// Generates a realistic step count for the given date.
  ///
  /// Uses Gaussian distribution with:
  /// - Weekday mean: 7500 steps (center of 5000-10000 range)
  /// - Weekend mean: 6500 steps (slightly lower for typical weekend patterns)
  /// - Standard deviation: 1000 steps
  ///
  /// Values are clamped to 5000-10000 range per Requirement 5.1.
  double _generateStepCount(DateTime date) {
    final isWeekend = _isWeekend(date);

    // Weekend: slightly lower average step count
    // Weekday: higher average step count
    final mean = isWeekend ? 6500.0 : 7500.0;
    const stdDev = 1000.0;

    // Generate value with Gaussian distribution
    final stepCount = _gaussian.sample(mean, stdDev);

    // Clamp to required range (5000-10000)
    return _gaussian.clamp(stepCount, 5000.0, 10000.0);
  }

  /// Generates a timestamp for the step count record.
  ///
  /// Step counts are typically recorded in the evening when the daily total is finalized.
  /// Generates a random time between 20:00 and 23:59.
  DateTime _generateTimestamp(DateTime date) {
    // Random hour between 20:00 and 23:59
    final hour = 20 + _random.nextInt(4); // 20, 21, 22, or 23
    final minute = _random.nextInt(60);

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Returns true if the date is a weekend (Saturday or Sunday).
  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }
}
