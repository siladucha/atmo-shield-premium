import 'dart:math' as math;
import '../models/hrv_reading.dart';
import '../models/baseline_data.dart';

class ZScoreCalculator {
  /// Calculate Z-score for a given HRV value against baseline
  double calculateZScore(double hrvValue, BaselineData baseline) {
    if (baseline.standardDeviation == 0) {
      return 0.0;
    }
    
    return (hrvValue - baseline.mean) / baseline.standardDeviation;
  }

  /// Calculate Z-scores for multiple HRV readings
  List<double> calculateZScores(List<HRVReading> readings, BaselineData baseline) {
    return readings.map((reading) => calculateZScore(reading.value, baseline)).toList();
  }

  /// Determine stress severity from Z-score
  String getStressSeverity(double zScore) {
    if (zScore <= -3.0) return 'critical';
    if (zScore <= -2.5) return 'high';
    if (zScore <= -2.0) return 'medium';
    if (zScore <= -1.8) return 'low';
    return 'normal';
  }

  /// Check if Z-score indicates stress (below threshold)
  bool isStressDetected(double zScore, {double threshold = -1.8}) {
    return zScore <= threshold;
  }

  /// Calculate confidence interval for Z-score
  Map<String, double> calculateConfidenceInterval(
    double zScore, 
    BaselineData baseline, 
    {double confidenceLevel = 0.95}
  ) {
    // Calculate standard error
    final standardError = baseline.standardDeviation / math.sqrt(baseline.sampleCount);
    
    // Calculate critical value for confidence level
    final alpha = 1 - confidenceLevel;
    final criticalValue = _getZCriticalValue(alpha / 2);
    
    // Calculate margin of error
    final marginOfError = criticalValue * standardError;
    
    return {
      'lower_bound': zScore - marginOfError,
      'upper_bound': zScore + marginOfError,
      'margin_of_error': marginOfError,
    };
  }

  /// Get critical Z-value for confidence interval calculation
  double _getZCriticalValue(double alpha) {
    // Approximation for common confidence levels
    if (alpha <= 0.005) return 2.576; // 99%
    if (alpha <= 0.01) return 2.326;  // 98%
    if (alpha <= 0.025) return 1.96;  // 95%
    if (alpha <= 0.05) return 1.645;  // 90%
    return 1.282; // 80%
  }

  /// Calculate rolling Z-scores for trend analysis
  List<Map<String, dynamic>> calculateRollingZScores(
    List<HRVReading> readings,
    BaselineData baseline,
    {int windowSize = 5}
  ) {
    if (readings.length < windowSize) {
      return [];
    }

    final results = <Map<String, dynamic>>[];
    
    for (int i = windowSize - 1; i < readings.length; i++) {
      final window = readings.sublist(i - windowSize + 1, i + 1);
      final avgHRV = window.map((r) => r.value).reduce((a, b) => a + b) / window.length;
      final zScore = calculateZScore(avgHRV, baseline);
      
      results.add({
        'timestamp': readings[i].timestamp,
        'average_hrv': avgHRV,
        'z_score': zScore,
        'severity': getStressSeverity(zScore),
        'window_size': windowSize,
      });
    }
    
    return results;
  }

  /// Detect Z-score anomalies using statistical methods
  List<Map<String, dynamic>> detectAnomalies(
    List<HRVReading> readings,
    BaselineData baseline,
    {double anomalyThreshold = 2.5}
  ) {
    final zScores = calculateZScores(readings, baseline);
    final anomalies = <Map<String, dynamic>>[];
    
    for (int i = 0; i < readings.length; i++) {
      final zScore = zScores[i];
      
      if (zScore.abs() > anomalyThreshold) {
        anomalies.add({
          'timestamp': readings[i].timestamp,
          'hrv_value': readings[i].value,
          'z_score': zScore,
          'anomaly_type': zScore > 0 ? 'high' : 'low',
          'severity': getStressSeverity(zScore),
          'confidence': readings[i].confidence,
        });
      }
    }
    
    return anomalies;
  }

  /// Calculate Z-score statistics for a period
  Map<String, dynamic> calculateZScoreStatistics(
    List<HRVReading> readings,
    BaselineData baseline
  ) {
    if (readings.isEmpty) {
      return {
        'count': 0,
        'mean_z_score': 0.0,
        'std_z_score': 0.0,
        'min_z_score': 0.0,
        'max_z_score': 0.0,
        'stress_events': 0,
        'stress_percentage': 0.0,
      };
    }

    final zScores = calculateZScores(readings, baseline);
    
    // Calculate basic statistics
    final meanZScore = zScores.reduce((a, b) => a + b) / zScores.length;
    final variance = zScores.map((z) => math.pow(z - meanZScore, 2)).reduce((a, b) => a + b) / zScores.length;
    final stdZScore = math.sqrt(variance);
    final minZScore = zScores.reduce(math.min);
    final maxZScore = zScores.reduce(math.max);
    
    // Count stress events
    final stressEvents = zScores.where((z) => isStressDetected(z)).length;
    final stressPercentage = (stressEvents / zScores.length) * 100;
    
    return {
      'count': zScores.length,
      'mean_z_score': meanZScore,
      'std_z_score': stdZScore,
      'min_z_score': minZScore,
      'max_z_score': maxZScore,
      'stress_events': stressEvents,
      'stress_percentage': stressPercentage,
    };
  }

  /// Normalize Z-score for display (0-100 scale)
  double normalizeZScoreForDisplay(double zScore) {
    // Map Z-score range (-4 to +2) to 0-100 scale
    // -4 = 0 (critical stress), 0 = 67 (baseline), +2 = 100 (optimal)
    const minZ = -4.0;
    const maxZ = 2.0;
    
    final clampedZ = math.max(minZ, math.min(maxZ, zScore));
    return ((clampedZ - minZ) / (maxZ - minZ)) * 100;
  }

  /// Get color code for Z-score visualization
  String getZScoreColor(double zScore) {
    if (zScore <= -3.0) return '#9C27B0'; // Purple - Critical
    if (zScore <= -2.5) return '#F44336'; // Red - High stress
    if (zScore <= -2.0) return '#FF9800'; // Orange - Medium stress
    if (zScore <= -1.8) return '#FFC107'; // Amber - Low stress
    if (zScore <= -1.0) return '#FFEB3B'; // Yellow - Mild activation
    return '#4CAF50'; // Green - Optimal
  }

  /// Calculate trend direction from recent Z-scores
  String calculateTrend(List<double> recentZScores) {
    if (recentZScores.length < 2) return 'stable';
    
    final recent = recentZScores.take(3).toList();
    final older = recentZScores.skip(3).take(3).toList();
    
    if (recent.isEmpty || older.isEmpty) return 'stable';
    
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    
    final difference = recentAvg - olderAvg;
    
    if (difference > 0.2) return 'improving';
    if (difference < -0.2) return 'worsening';
    return 'stable';
  }
}