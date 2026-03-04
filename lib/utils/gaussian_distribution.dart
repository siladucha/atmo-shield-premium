import 'dart:math';

/// Utility class for generating random values from a Gaussian (normal) distribution.
///
/// Uses the Box-Muller transform to convert uniformly distributed random values
/// into normally distributed values. This is essential for generating realistic
/// health data patterns with proper statistical properties.
class GaussianDistribution {
  final Random _random;
  bool _hasSpare = false;
  double _spare = 0.0;

  /// Creates a new GaussianDistribution with an optional random seed.
  ///
  /// If [seed] is provided, the random number generator will be deterministic,
  /// which is useful for testing and reproducibility.
  GaussianDistribution({int? seed}) : _random = Random(seed);

  /// Generates a random sample from a normal distribution.
  ///
  /// Uses the Box-Muller transform to generate values with the specified
  /// [mean] and [stdDev] (standard deviation).
  ///
  /// The Box-Muller transform generates two independent standard normal
  /// values from two independent uniform random values. This implementation
  /// caches the second value for efficiency.
  ///
  /// Example:
  /// ```dart
  /// final gaussian = GaussianDistribution();
  /// final hrv = gaussian.sample(50.0, 10.0); // mean=50ms, stdDev=10ms
  /// ```
  double sample(double mean, double stdDev) {
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
    // z0 = sqrt(-2 * ln(u1)) * cos(2π * u2)
    // z1 = sqrt(-2 * ln(u1)) * sin(2π * u2)
    final magnitude = sqrt(-2.0 * log(u1));
    final z0 = magnitude * cos(2.0 * pi * u2);
    final z1 = magnitude * sin(2.0 * pi * u2);

    // Cache z1 for next call
    _spare = z1;
    _hasSpare = true;

    // Return z0 scaled to desired mean and standard deviation
    return mean + stdDev * z0;
  }

  /// Clamps a value to be within the specified range [min, max].
  ///
  /// This is useful for ensuring generated health data values stay within
  /// physiologically realistic bounds even when using Gaussian distributions.
  ///
  /// Example:
  /// ```dart
  /// final gaussian = GaussianDistribution();
  /// final rawValue = gaussian.sample(50.0, 20.0);
  /// final clamped = gaussian.clamp(rawValue, 10.0, 200.0); // HRV range
  /// ```
  double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
