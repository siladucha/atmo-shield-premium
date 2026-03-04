import 'dart:math';
import '../models/health_data_point.dart';
import '../utils/gaussian_distribution.dart';
import '../utils/trend_calculator.dart';
import '../utils/probability_distribution.dart';
import '../utils/stress_calendar.dart';

/// Generates realistic HRV (Heart Rate Variability) data with gaps, trends, and stress patterns.
///
/// Produces 600-900 HRV records across 365 days with:
/// - Realistic gaps (35% of days have zero records)
/// - Daily record count distribution (0-5 records per day)
/// - Time period distribution (morning, day, evening, night)
/// - Stress day detection (values <30ms on stress days)
/// - Gradual improvement trend (10-20% increase over 3-6 months)
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.10**
class HRVGenerator {
  final GaussianDistribution _gaussian;
  final TrendCalculator _trendCalculator;
  final ProbabilityDistribution _probabilityDistribution;
  final Random _random;

  /// Creates a new HRVGenerator with optional random seed for reproducibility.
  HRVGenerator({int? seed})
      : _gaussian = GaussianDistribution(seed: seed),
        _trendCalculator = TrendCalculator(seed: seed),
        _probabilityDistribution = ProbabilityDistribution(seed: seed),
        _random = Random(seed);

  /// Generates HRV data across the specified date range.
  ///
  /// Parameters:
  /// - [start]: Start date of the generation period
  /// - [end]: End date of the generation period
  /// - [stressCalendar]: Calendar identifying stress days for correlated patterns
  /// - [trendGrowth]: Percentage increase over trend period (0.10-0.20)
  /// - [trendDurationMonths]: Duration of improvement trend in months (3-6)
  ///
  /// Returns a list of 600-900 HealthDataPoint objects with HRV measurements.
  ///
  /// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.10**
  List<HealthDataPoint> generate({
    required DateTime start,
    required DateTime end,
    required StressCalendar stressCalendar,
    double trendGrowth = 0.15,
    int trendDurationMonths = 4,
  }) {
    final records = <HealthDataPoint>[];
    final totalDays = end.difference(start).inDays;
    final trendDurationDays = trendDurationMonths * 30;

    // Generate data for each day
    for (int dayOffset = 0; dayOffset < totalDays; dayOffset++) {
      final currentDate = start.add(Duration(days: dayOffset));

      // Determine number of records for this day using probability distribution
      // Requirement 3.2: 35% zero, 45% 1-2, 20% 3-5
      final recordCount = _getRecordsForDay();

      // Skip this day if no records (35% of days)
      if (recordCount == 0) continue;

      // Generate timestamps for this day
      final timestamps = _getTimestampsForDay(currentDate, recordCount);

      // Generate HRV values for each timestamp
      for (final timestamp in timestamps) {
        final hrvValue = _generateHRVValue(
          timestamp: timestamp,
          startDate: start,
          stressCalendar: stressCalendar,
          trendGrowth: trendGrowth,
          trendDurationDays: trendDurationDays,
        );

        records.add(HealthDataPoint(
          type: 'hrv',
          value: hrvValue,
          timestamp: timestamp,
          unit: 'ms',
        ));
      }
    }

    return records;
  }

  /// Determines the number of HRV records for a single day.
  ///
  /// Uses probability distribution matching Requirement 3.2:
  /// - 35% of days: 0 records
  /// - 22.5% of days: 1 record
  /// - 22.5% of days: 2 records (total 45% for 1-2)
  /// - 12% of days: 3 records
  /// - 5% of days: 4 records
  /// - 3% of days: 5 records (total 20% for 3-5)
  int _getRecordsForDay() {
    return _probabilityDistribution.sampleDiscrete(
      ProbabilityDistribution.hrvDailyRecordDistribution(),
    );
  }

  /// Generates timestamps for HRV measurements throughout the day.
  ///
  /// Distributes records across four time periods:
  /// - Morning: 06:00-12:00
  /// - Day: 12:00-18:00
  /// - Evening: 18:00-22:00
  /// - Night: 22:00-06:00
  ///
  /// **Validates: Requirement 3.7**
  List<DateTime> _getTimestampsForDay(DateTime date, int count) {
    final timestamps = <DateTime>[];

    // Define time periods (in hours from midnight)
    final timePeriods = [
      _TimePeriod(6, 12, 'morning'), // 06:00-12:00
      _TimePeriod(12, 18, 'day'), // 12:00-18:00
      _TimePeriod(18, 22, 'evening'), // 18:00-22:00
      _TimePeriod(22, 30, 'night'), // 22:00-06:00 (next day)
    ];

    // Randomly select time periods for each record
    for (int i = 0; i < count; i++) {
      final period = timePeriods[_random.nextInt(timePeriods.length)];
      final timestamp = _generateTimestampInPeriod(date, period);
      timestamps.add(timestamp);
    }

    // Sort timestamps chronologically
    timestamps.sort();

    return timestamps;
  }

  /// Generates a random timestamp within a specific time period.
  DateTime _generateTimestampInPeriod(DateTime date, _TimePeriod period) {
    // Calculate random hour within the period
    final hourRange = period.endHour - period.startHour;
    final randomHours = period.startHour + _random.nextDouble() * hourRange;

    // Handle night period that crosses midnight
    if (randomHours >= 24) {
      final nextDay = date.add(const Duration(days: 1));
      final adjustedHours = randomHours - 24;
      return nextDay.add(Duration(
        hours: adjustedHours.floor(),
        minutes: ((adjustedHours % 1) * 60).floor(),
      ));
    }

    return date.add(Duration(
      hours: randomHours.floor(),
      minutes: ((randomHours % 1) * 60).floor(),
    ));
  }

  /// Generates a single HRV value with trend and stress patterns.
  ///
  /// **Validates: Requirements 3.4, 3.5, 3.6**
  double _generateHRVValue({
    required DateTime timestamp,
    required DateTime startDate,
    required StressCalendar stressCalendar,
    required double trendGrowth,
    required int trendDurationDays,
  }) {
    final isStress = stressCalendar.isStressDay(timestamp);

    if (isStress) {
      // Stress day: HRV < 30ms (Requirement 3.5)
      // Generate values between 15-29ms with Gaussian distribution
      final stressValue = _gaussian.sample(22.0, 5.0);
      return _gaussian.clamp(stressValue, 15.0, 29.0);
    } else {
      // Normal day: HRV 40-60ms with trend (Requirements 3.4, 3.6)
      final baseHRV = 50.0; // Baseline HRV in milliseconds

      // Apply gradual improvement trend (10-20% increase over 3-6 months)
      final trendValue = _trendCalculator.getValueWithTrend(
        baseHRV,
        timestamp,
        startDate,
        trendDurationDays,
        trendGrowth,
      );

      // Clamp to normal range (40-60ms)
      return _gaussian.clamp(trendValue, 40.0, 60.0);
    }
  }
}

/// Helper class to define time periods for HRV measurements.
class _TimePeriod {
  final double startHour;
  final double endHour;
  final String name;

  _TimePeriod(this.startHour, this.endHour, this.name);
}
