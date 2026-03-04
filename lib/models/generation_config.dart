/// Configuration for synthetic health data generation.
///
/// This model defines the parameters for generating one year of synthetic
/// HealthKit data, including optional data types and trend characteristics.
class GenerationConfig {
  /// Whether to generate step count data (optional feature).
  final bool includeSteps;

  /// Whether to generate sleep duration data (optional feature).
  final bool includeSleep;

  /// Target number of heart rate records to generate (5000-10000).
  final int targetHRRecords;

  /// HRV trend growth percentage over the trend period (0.10-0.20 = 10-20%).
  final double hrvTrendGrowth;

  /// Duration of the improvement trend in months (3-6 months).
  final int trendDurationMonths;

  /// Creates a new generation configuration.
  ///
  /// Parameters:
  /// - [includeSteps]: Enable step count generation (default: false)
  /// - [includeSleep]: Enable sleep duration generation (default: false)
  /// - [targetHRRecords]: Number of HR records to generate (default: 7500)
  /// - [hrvTrendGrowth]: HRV improvement percentage (default: 0.15 = 15%)
  /// - [trendDurationMonths]: Trend duration in months (default: 4)
  const GenerationConfig({
    this.includeSteps = false,
    this.includeSleep = false,
    this.targetHRRecords = 7500,
    this.hrvTrendGrowth = 0.15,
    this.trendDurationMonths = 4,
  }) : assert(targetHRRecords >= 5000 && targetHRRecords <= 10000,
            'targetHRRecords must be between 5000 and 10000'),
       assert(hrvTrendGrowth >= 0.10 && hrvTrendGrowth <= 0.20,
            'hrvTrendGrowth must be between 0.10 and 0.20'),
       assert(trendDurationMonths >= 3 && trendDurationMonths <= 6,
            'trendDurationMonths must be between 3 and 6');

  /// Creates a default configuration with recommended settings.
  ///
  /// Default values:
  /// - No optional features (steps and sleep disabled)
  /// - 7500 heart rate records (mid-range)
  /// - 15% HRV improvement trend
  /// - 4-month trend duration
  factory GenerationConfig.defaultConfig() {
    return const GenerationConfig();
  }

  /// Creates a configuration with all optional features enabled.
  ///
  /// Useful for comprehensive testing scenarios.
  factory GenerationConfig.withAllFeatures() {
    return const GenerationConfig(
      includeSteps: true,
      includeSleep: true,
    );
  }

  /// Creates a configuration with minimal data generation.
  ///
  /// Useful for quick testing with minimum required data.
  factory GenerationConfig.minimal() {
    return const GenerationConfig(
      targetHRRecords: 5000,
      trendDurationMonths: 3,
    );
  }

  /// Creates a configuration with maximum data generation.
  ///
  /// Useful for comprehensive testing with maximum data density.
  factory GenerationConfig.maximal() {
    return const GenerationConfig(
      includeSteps: true,
      includeSleep: true,
      targetHRRecords: 10000,
      hrvTrendGrowth: 0.20,
      trendDurationMonths: 6,
    );
  }

  /// Creates a copy of this configuration with optional parameter overrides.
  GenerationConfig copyWith({
    bool? includeSteps,
    bool? includeSleep,
    int? targetHRRecords,
    double? hrvTrendGrowth,
    int? trendDurationMonths,
  }) {
    return GenerationConfig(
      includeSteps: includeSteps ?? this.includeSteps,
      includeSleep: includeSleep ?? this.includeSleep,
      targetHRRecords: targetHRRecords ?? this.targetHRRecords,
      hrvTrendGrowth: hrvTrendGrowth ?? this.hrvTrendGrowth,
      trendDurationMonths: trendDurationMonths ?? this.trendDurationMonths,
    );
  }

  @override
  String toString() {
    return 'GenerationConfig('
        'includeSteps: $includeSteps, '
        'includeSleep: $includeSleep, '
        'targetHRRecords: $targetHRRecords, '
        'hrvTrendGrowth: $hrvTrendGrowth, '
        'trendDurationMonths: $trendDurationMonths)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is GenerationConfig &&
        other.includeSteps == includeSteps &&
        other.includeSleep == includeSleep &&
        other.targetHRRecords == targetHRRecords &&
        other.hrvTrendGrowth == hrvTrendGrowth &&
        other.trendDurationMonths == trendDurationMonths;
  }

  @override
  int get hashCode {
    return Object.hash(
      includeSteps,
      includeSleep,
      targetHRRecords,
      hrvTrendGrowth,
      trendDurationMonths,
    );
  }
}
