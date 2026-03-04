import 'dart:math';
import '../models/health_data_point.dart';
import '../utils/gaussian_distribution.dart';
import '../utils/trend_calculator.dart';
import '../utils/stress_calendar.dart';

/// Generates realistic Respiratory Rate data across a 365-day period.
///
/// Produces exactly 365 RR records (one per day) with:
/// - Night-time timestamp assignment (random hour between 22:00-06:00)
/// - Stress day detection (18-22 bpm on stress days, 12-16 bpm normal)
/// - Gradual trend decrease for respiratory improvement
/// - Correlation with stress events from StressCalendar
///
/// **Validates: Requirements 4.1, 4.2, 4.3, 4.4**
class RespiratoryRateGenerator {
  final Random _random;
  final GaussianDistribution _gaussian;
  final TrendCalculator _trendCalculator;

  /// Creates a RespiratoryRateGenerator with optional random seed for reproducibility.
  RespiratoryRateGenerator({int? seed})
      : _random = Random(seed),
        _gaussian = GaussianDistribution(seed: seed),
        _trendCalculator = TrendCalculator(seed: seed);

  /// Generates Respiratory Rate data points across the specified date range.
  ///
  /// Parameters:
  /// - [start]: Start date of the generation period
  /// - [end]: End date of the generation period
  /// - [stressCalendar]: Calendar identifying stress days for correlated patterns
  ///
  /// Returns a list of exactly 365 HealthDataPoint objects with type 'respiratoryRate'
  /// and unit 'bpm' (breaths per minute).
  ///
  /// The method:
  /// 1. Generates exactly one record per day (365 total)
  /// 2. Assigns night-time timestamps (random hour between 22:00-06:00)
  /// 3. Applies stress day detection (18-22 bpm on stress days, 12-16 bpm normal)
  /// 4. Adds gradual downward trend for respiratory improvement
  /// 5. Adds Gaussian noise for realistic variation
  ///
  /// **Validates: Requirements 4.1, 4.2, 4.3, 4.4**
  List<HealthDataPoint> generate({
    required DateTime start,
    required DateTime end,
    required StressCalendar stressCalendar,
  }) {
    final records = <HealthDataPoint>[];
    final totalDays = end.difference(start).inDays;

    // Generate exactly one record per day (Requirement 4.1)
    for (int dayOffset = 0; dayOffset < totalDays; dayOffset++) {
      final currentDate = start.add(Duration(days: dayOffset));

      // Generate night-time timestamp for this day
      final timestamp = _getNightTimeTimestamp(currentDate);

      // Generate RR value for this timestamp
      final rrValue = _generateRRValue(
        timestamp: timestamp,
        startDate: start,
        stressCalendar: stressCalendar,
      );

      records.add(HealthDataPoint(
        type: 'respiratoryRate',
        value: rrValue,
        timestamp: timestamp,
        unit: 'bpm',
      ));
    }

    return records;
  }

  /// Generates a night-time timestamp for respiratory rate measurement.
  ///
  /// Apple Watch typically measures respiratory rate during sleep.
  /// This method generates a random timestamp between 22:00 (10 PM) and 06:00 (6 AM).
  ///
  /// The time period spans across midnight:
  /// - 22:00-24:00 (same day)
  /// - 00:00-06:00 (next day)
  ///
  /// Returns a DateTime with a random hour and minute within the night period.
  DateTime _getNightTimeTimestamp(DateTime date) {
    // Night period: 22:00 to 06:00 (8 hours total)
    // We'll generate a random hour offset from 22:00
    final nightHours = 8.0; // 22:00 to 06:00 is 8 hours
    final randomHourOffset = _random.nextDouble() * nightHours;

    // Calculate the actual hour (22, 23, 0, 1, 2, 3, 4, 5)
    final hour = (22 + randomHourOffset.floor()) % 24;
    final minute = (_random.nextDouble() * 60).floor();

    // If hour is in the early morning (0-5), it's the next day
    if (hour < 6) {
      final nextDay = date.add(const Duration(days: 1));
      return DateTime(nextDay.year, nextDay.month, nextDay.day, hour, minute);
    } else {
      // Hour is 22 or 23, same day
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
  }

  /// Generates a single RR value with trend and stress patterns.
  ///
  /// **Validates: Requirements 4.2, 4.3, 4.4**
  double _generateRRValue({
    required DateTime timestamp,
    required DateTime startDate,
    required StressCalendar stressCalendar,
  }) {
    final isStress = stressCalendar.isStressDay(timestamp);

    if (isStress) {
      // Stress day: RR 18-22 bpm (Requirement 4.3)
      // Generate values between 18-22 bpm with Gaussian distribution
      final stressValue = _gaussian.sample(20.0, 1.5);
      return _gaussian.clamp(stressValue, 18.0, 22.0);
    } else {
      // Normal day: RR 12-16 bpm with downward trend (Requirements 4.2, 4.4)
      final baseRR = 14.0; // Baseline RR in breaths per minute

      // Apply gradual improvement trend (decrease over time)
      // Respiratory rate decreases as breathing becomes more efficient
      // Use negative trend percentage for decrease
      final trendValue = _trendCalculator.getValueWithTrend(
        baseRR,
        timestamp,
        startDate,
        365, // Full year trend
        -0.05, // 5% decrease over the year
      );

      // Clamp to normal range (12-16 bpm)
      return _gaussian.clamp(trendValue, 12.0, 16.0);
    }
  }
}
