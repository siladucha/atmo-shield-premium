import 'dart:math';

/// Utility class for calculating trend values over time with realistic variations.
///
/// Implements linear trend calculation with configurable duration and percentage,
/// and adds Gaussian noise for realistic variations. This is used to simulate
/// gradual health improvements (e.g., HRV increase, heart rate decrease) over time.
class TrendCalculator {
  final Random _random;
  bool _hasSpare = false;
  double _spare = 0.0;

  /// Creates a new TrendCalculator with an optional random seed.
  ///
  /// If [seed] is provided, the random number generator will be deterministic,
  /// which is useful for testing and reproducibility.
  TrendCalculator({int? seed}) : _random = Random(seed);

  /// Calculates a value with linear trend and Gaussian noise.
  ///
  /// Parameters:
  /// - [baseValue]: The starting baseline value
  /// - [currentDate]: The date for which to calculate the value
  /// - [startDate]: The start date of the trend period
  /// - [trendDurationDays]: Duration of the trend in days
  /// - [trendPercentage]: Percentage change over the trend period (e.g., 0.15 for 15% increase)
  ///
  /// The method calculates:
  /// 1. Progress through the trend period (0.0 to 1.0)
  /// 2. Linear interpolation: baseValue * (1.0 + trendPercentage * progress)
  /// 3. Adds Gaussian noise (±10% variation) for realism
  /// 4. Ensures the result is non-negative
  ///
  /// Example:
  /// ```dart
  /// final calculator = TrendCalculator();
  /// final startDate = DateTime(2024, 1, 1);
  /// final currentDate = DateTime(2024, 3, 1); // 60 days later
  /// final trendDurationDays = 180; // 6 months
  /// final trendPercentage = 0.15; // 15% increase
  ///
  /// // Calculate HRV with upward trend
  /// final hrv = calculator.getValueWithTrend(
  ///   50.0,           // base HRV of 50ms
  ///   currentDate,
  ///   startDate,
  ///   trendDurationDays,
  ///   trendPercentage
  /// );
  /// // Result: ~52.5ms (50 * 1.05) + noise
  /// ```
  double getValueWithTrend(
    double baseValue,
    DateTime currentDate,
    DateTime startDate,
    int trendDurationDays,
    double trendPercentage,
  ) {
    // Calculate days since start
    final daysSinceStart = currentDate.difference(startDate).inDays;

    // Calculate progress through trend period (clamped to 0.0-1.0)
    final trendProgress = min(1.0, max(0.0, daysSinceStart / trendDurationDays));

    // Calculate trend value using linear interpolation
    final trendValue = baseValue * (1.0 + trendPercentage * trendProgress);

    // Add Gaussian noise (±10% variation) for realism
    final noise = _gaussian(0, trendValue * 0.1);

    // Ensure non-negative result
    return max(0, trendValue + noise);
  }

  /// Generates a random sample from a normal distribution using Box-Muller transform.
  ///
  /// This is an internal method used to add realistic noise to trend values.
  /// Uses the same Box-Muller transform as GaussianDistribution for consistency.
  ///
  /// Parameters:
  /// - [mean]: The mean of the distribution
  /// - [stdDev]: The standard deviation of the distribution
  double _gaussian(double mean, double stdDev) {
    // If we have a cached spare value, use it
    if (_hasSpare) {
      _hasSpare = false;
      return mean + stdDev * _spare;
    }

    // Box-Muller transform
    // Generate two uniform random values in (0, 1)
    double u1, u2;
    do {
      u1 = _random.nextDouble();
      u2 = _random.nextDouble();
    } while (u1 <= 0.0); // Ensure u1 > 0 for log

    // Apply Box-Muller transform
    final magnitude = sqrt(-2.0 * log(u1));
    final z0 = magnitude * cos(2.0 * pi * u2);
    final z1 = magnitude * sin(2.0 * pi * u2);

    // Cache z1 for next call
    _spare = z1;
    _hasSpare = true;

    // Return z0 scaled to desired mean and standard deviation
    return mean + stdDev * z0;
  }
}
