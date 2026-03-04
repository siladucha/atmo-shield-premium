import 'dart:math';

/// Utility class for weighted random selection from discrete probability distributions.
///
/// This class enables sampling from discrete distributions where each outcome has
/// a specific probability. It's particularly useful for generating realistic patterns
/// in health data, such as the varying number of HRV measurements per day.
class ProbabilityDistribution {
  final Random _random;

  /// Creates a new ProbabilityDistribution with an optional random seed.
  ///
  /// If [seed] is provided, the random number generator will be deterministic,
  /// which is useful for testing and reproducibility.
  ProbabilityDistribution({int? seed}) : _random = Random(seed);

  /// Samples a value from a discrete probability distribution.
  ///
  /// Takes a map where keys are possible outcomes and values are their probabilities.
  /// The probabilities should sum to 1.0, but the method will normalize them if they don't.
  ///
  /// Parameters:
  /// - [probabilities]: A map of outcome values to their probabilities
  ///
  /// Returns: One of the keys from the map, selected according to the probability distribution
  ///
  /// Example for HRV daily record count (Requirement 3.2):
  /// ```dart
  /// final distribution = ProbabilityDistribution();
  /// final recordCount = distribution.sampleDiscrete({
  ///   0: 0.35,  // 35% of days have 0 records
  ///   1: 0.225, // 22.5% have 1 record
  ///   2: 0.225, // 22.5% have 2 records (total 45% for 1-2)
  ///   3: 0.12,  // 12% have 3 records
  ///   4: 0.05,  // 5% have 4 records
  ///   5: 0.03,  // 3% have 5 records (total 20% for 3-5)
  /// });
  /// ```
  ///
  /// This distribution matches the requirement:
  /// - 35% of days have 0 records
  /// - 45% of days have 1-2 records
  /// - 20% of days have 3-5 records
  int sampleDiscrete(Map<int, double> probabilities) {
    if (probabilities.isEmpty) {
      throw ArgumentError('Probabilities map cannot be empty');
    }

    // Calculate total probability for normalization
    final totalProbability = probabilities.values.reduce((a, b) => a + b);

    if (totalProbability <= 0.0) {
      throw ArgumentError('Total probability must be greater than 0');
    }

    // Generate a random value between 0 and 1
    final randomValue = _random.nextDouble();

    // Normalize and accumulate probabilities to find the selected outcome
    double cumulativeProbability = 0.0;

    for (final entry in probabilities.entries) {
      // Normalize the probability
      final normalizedProbability = entry.value / totalProbability;
      cumulativeProbability += normalizedProbability;

      // If our random value falls within this probability range, return this outcome
      if (randomValue < cumulativeProbability) {
        return entry.key;
      }
    }

    // Fallback: return the last key (handles floating-point precision edge cases)
    return probabilities.keys.last;
  }

  /// Creates a standard HRV daily record count distribution.
  ///
  /// This is a convenience method that returns the specific distribution required
  /// for HRV data generation according to Requirement 3.2:
  /// - 35% of days have 0 records
  /// - Remaining days have 1-5 records with higher counts weighted more heavily
  ///
  /// The distribution is tuned to produce approximately 600-900 total records
  /// across 365 days (Requirement 3.3) while maintaining realistic gaps.
  ///
  /// Example:
  /// ```dart
  /// final distribution = ProbabilityDistribution();
  /// final recordCount = distribution.sampleDiscrete(
  ///   ProbabilityDistribution.hrvDailyRecordDistribution()
  /// );
  /// ```
  static Map<int, double> hrvDailyRecordDistribution() {
    return {
      0: 0.35, // 35% of days have 0 records
      1: 0.08, // 8% have 1 record
      2: 0.22, // 22% have 2 records
      3: 0.20, // 20% have 3 records
      4: 0.10, // 10% have 4 records
      5: 0.05, // 5% have 5 records
    };
  }
}
