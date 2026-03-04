import 'dart:math';
import '../models/health_data_point.dart';
import '../utils/gaussian_distribution.dart';

/// Generates realistic daily sleep duration data across a 365-day period.
///
/// Produces 365 records (one per day) with:
/// - Durations between 7-8 hours (420-480 minutes)
/// - Increased sleep duration on weekends
/// - Realistic sleep patterns
///
/// **Validates: Requirements 5.2, 5.3**
class SleepGenerator {
  final Random _random;
  final GaussianDistribution _gaussian;

  /// Creates a SleepGenerator with optional random seed for reproducibility.
  SleepGenerator({int? seed})
      : _random = Random(seed),
        _gaussian = GaussianDistribution(seed: seed);

  /// Generates daily sleep duration data across the specified date range.
  ///
  /// Parameters:
  /// - [start]: Start date of the generation period
  /// - [end]: End date of the generation period
  ///
  /// Returns a list of 365 HealthDataPoint objects with type 'sleep' and unit 'min'.
  ///
  /// The method:
  /// 1. Generates one record per day
  /// 2. Applies weekend variation (longer sleep duration)
  /// 3. Uses Gaussian distribution centered at 7.5 hours (450 minutes)
  /// 4. Ensures values stay within 7-8 hours (420-480 minutes) range
  ///
  /// **Validates: Requirements 5.2, 5.3**
  List<HealthDataPoint> generate(DateTime start, DateTime end) {
    final records = <HealthDataPoint>[];
    final totalDays = end.difference(start).inDays;

    for (int dayOffset = 0; dayOffset < totalDays; dayOffset++) {
      final currentDate = start.add(Duration(days: dayOffset));

      // Generate sleep duration for this day
      final sleepDuration = _generateSleepDuration(currentDate);

      // Create timestamp for when sleep ended (morning wake-up time)
      final timestamp = _generateWakeUpTimestamp(currentDate);

      records.add(HealthDataPoint(
        type: 'sleep',
        value: sleepDuration,
        timestamp: timestamp,
        unit: 'min',
      ));
    }

    return records;
  }

  /// Generates a realistic sleep duration for the given date.
  ///
  /// Uses Gaussian distribution with:
  /// - Weekday mean: 440 minutes (7.33 hours)
  /// - Weekend mean: 470 minutes (7.83 hours) - increased per Requirement 5.3
  /// - Standard deviation: 15 minutes
  ///
  /// Values are clamped to 420-480 minutes (7-8 hours) per Requirement 5.2.
  ///
  /// **Validates: Requirements 5.2, 5.3**
  double _generateSleepDuration(DateTime date) {
    final isWeekend = _isWeekend(date);

    // Weekend: longer sleep duration (Requirement 5.3)
    // Weekday: slightly shorter sleep duration
    final mean = isWeekend ? 470.0 : 440.0;
    const stdDev = 15.0;

    // Generate value with Gaussian distribution
    final sleepDuration = _gaussian.sample(mean, stdDev);

    // Clamp to required range (420-480 minutes = 7-8 hours)
    return _gaussian.clamp(sleepDuration, 420.0, 480.0);
  }

  /// Generates a timestamp for when sleep ended (wake-up time).
  ///
  /// Sleep records are typically timestamped at the end of the sleep period.
  /// Generates a random wake-up time between 06:00 and 09:00.
  DateTime _generateWakeUpTimestamp(DateTime date) {
    // Random hour between 06:00 and 09:00
    final hour = 6 + _random.nextInt(4); // 6, 7, 8, or 9
    final minute = _random.nextInt(60);

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Returns true if the date is a weekend (Saturday or Sunday).
  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }
}
