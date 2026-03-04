import 'package:hive/hive.dart';

part 'baseline_data.g.dart';

@HiveType(typeId: 1)
class BaselineData extends HiveObject {
  @HiveField(0)
  final DateTime calculatedAt;
  
  @HiveField(1)
  final double mean; // Average HRV over baseline period
  
  @HiveField(2)
  final double standardDeviation; // Standard deviation for Z-score calculation
  
  @HiveField(3)
  final int dayCount; // Number of days used in calculation
  
  @HiveField(4)
  final double confidence; // Baseline quality score 0-1
  
  @HiveField(5)
  final String platform; // Platform-specific baseline
  
  @HiveField(6)
  final DateTime periodStart; // Start of baseline calculation period
  
  @HiveField(7)
  final DateTime periodEnd; // End of baseline calculation period
  
  @HiveField(8)
  final int sampleCount; // Total number of HRV readings used
  
  @HiveField(9)
  final double median; // Median HRV value
  
  @HiveField(10)
  final double min; // Minimum HRV value in period
  
  @HiveField(11)
  final double max; // Maximum HRV value in period

  BaselineData({
    required this.calculatedAt,
    required this.mean,
    required this.standardDeviation,
    required this.dayCount,
    required this.confidence,
    required this.platform,
    required this.periodStart,
    required this.periodEnd,
    required this.sampleCount,
    required this.median,
    required this.min,
    required this.max,
  });

  // Calculate Z-score for a given HRV value
  double calculateZScore(double hrvValue) {
    if (standardDeviation == 0) return 0.0;
    return (hrvValue - mean) / standardDeviation;
  }

  // Check if baseline is valid (sufficient data and confidence)
  bool get isValid {
    return dayCount >= 7 && 
           confidence >= 0.7 && 
           sampleCount >= 20 &&
           standardDeviation > 0;
  }

  // Get baseline quality description
  String get qualityDescription {
    if (confidence >= 0.9) return 'Excellent';
    if (confidence >= 0.8) return 'Good';
    if (confidence >= 0.7) return 'Fair';
    return 'Poor';
  }

  // Calculate coefficient of variation (for neural rigidity detection)
  double get coefficientOfVariation {
    if (mean == 0) return 0.0;
    return standardDeviation / mean;
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'calculatedAt': calculatedAt.millisecondsSinceEpoch,
      'mean': mean,
      'standardDeviation': standardDeviation,
      'dayCount': dayCount,
      'confidence': confidence,
      'platform': platform,
      'periodStart': periodStart.millisecondsSinceEpoch,
      'periodEnd': periodEnd.millisecondsSinceEpoch,
      'sampleCount': sampleCount,
      'median': median,
      'min': min,
      'max': max,
    };
  }

  factory BaselineData.fromJson(Map<String, dynamic> json) {
    return BaselineData(
      calculatedAt: DateTime.fromMillisecondsSinceEpoch(json['calculatedAt']),
      mean: json['mean'].toDouble(),
      standardDeviation: json['standardDeviation'].toDouble(),
      dayCount: json['dayCount'],
      confidence: json['confidence'].toDouble(),
      platform: json['platform'],
      periodStart: DateTime.fromMillisecondsSinceEpoch(json['periodStart']),
      periodEnd: DateTime.fromMillisecondsSinceEpoch(json['periodEnd']),
      sampleCount: json['sampleCount'],
      median: json['median'].toDouble(),
      min: json['min'].toDouble(),
      max: json['max'].toDouble(),
    );
  }

  @override
  String toString() {
    return 'BaselineData(mean: ${mean.toStringAsFixed(1)}ms, '
           'std: ${standardDeviation.toStringAsFixed(1)}ms, '
           'days: $dayCount, confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BaselineData &&
        other.calculatedAt == calculatedAt &&
        other.platform == platform;
  }

  @override
  int get hashCode {
    return calculatedAt.hashCode ^ platform.hashCode;
  }
}