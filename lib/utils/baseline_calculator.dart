import 'dart:math' as math;
import '../models/hrv_reading.dart';
import '../models/baseline_data.dart';

class BaselineCalculator {
  /// Calculate baseline from HRV readings
  BaselineData? calculate(List<HRVReading> readings) {
    if (readings.isEmpty) return null;
    
    // Filter and validate readings
    final validReadings = _filterValidReadings(readings);
    if (validReadings.length < 20) return null; // Minimum sample size
    
    // Group readings by day to ensure we have sufficient temporal coverage
    final dailyReadings = _groupReadingsByDay(validReadings);
    if (dailyReadings.length < 7) return null; // Minimum 7 days
    
    // Calculate daily averages
    final dailyAverages = _calculateDailyAverages(dailyReadings);
    
    // Calculate baseline statistics
    final statistics = _calculateStatistics(dailyAverages);
    
    // Determine platform (use most common platform)
    final platform = _getMostCommonPlatform(validReadings);
    
    // Calculate confidence score
    final confidence = _calculateConfidence(validReadings, dailyReadings, statistics);
    
    // Get time period
    final sortedReadings = validReadings..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final periodStart = sortedReadings.first.timestamp;
    final periodEnd = sortedReadings.last.timestamp;
    
    return BaselineData(
      calculatedAt: DateTime.now(),
      mean: statistics['mean']!,
      standardDeviation: statistics['std']!,
      dayCount: dailyReadings.length,
      confidence: confidence,
      platform: platform,
      periodStart: periodStart,
      periodEnd: periodEnd,
      sampleCount: validReadings.length,
      median: statistics['median']!,
      min: statistics['min']!,
      max: statistics['max']!,
    );
  }

  /// Filter readings for quality and validity
  List<HRVReading> _filterValidReadings(List<HRVReading> readings) {
    return readings.where((reading) {
      // Basic range validation (10-200ms is physiologically reasonable)
      if (reading.value < 10 || reading.value > 200) return false;
      
      // Confidence threshold
      if (reading.confidence < 0.5) return false;
      
      // Exclude readings during likely exercise periods
      // This would be enhanced with actual activity data
      if (reading.metadata?['during_exercise'] == true) return false;
      
      return true;
    }).toList();
  }

  /// Group readings by calendar day
  Map<String, List<HRVReading>> _groupReadingsByDay(List<HRVReading> readings) {
    final groups = <String, List<HRVReading>>{};
    
    for (final reading in readings) {
      final dayKey = '${reading.timestamp.year}-${reading.timestamp.month}-${reading.timestamp.day}';
      groups.putIfAbsent(dayKey, () => []).add(reading);
    }
    
    return groups;
  }

  /// Calculate daily average HRV values
  List<double> _calculateDailyAverages(Map<String, List<HRVReading>> dailyReadings) {
    final averages = <double>[];
    
    for (final dayReadings in dailyReadings.values) {
      if (dayReadings.isNotEmpty) {
        final dayAverage = dayReadings.map((r) => r.value).reduce((a, b) => a + b) / dayReadings.length;
        averages.add(dayAverage);
      }
    }
    
    return averages;
  }

  /// Calculate statistical measures
  Map<String, double> _calculateStatistics(List<double> values) {
    if (values.isEmpty) {
      return {
        'mean': 0.0,
        'std': 0.0,
        'median': 0.0,
        'min': 0.0,
        'max': 0.0,
      };
    }

    // Sort for median calculation
    final sortedValues = List<double>.from(values)..sort();
    
    // Calculate mean
    final mean = values.reduce((a, b) => a + b) / values.length;
    
    // Calculate standard deviation
    final variance = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    final std = math.sqrt(variance);
    
    // Calculate median
    final median = sortedValues.length % 2 == 0
        ? (sortedValues[sortedValues.length ~/ 2 - 1] + sortedValues[sortedValues.length ~/ 2]) / 2
        : sortedValues[sortedValues.length ~/ 2];
    
    return {
      'mean': mean,
      'std': std,
      'median': median,
      'min': sortedValues.first,
      'max': sortedValues.last,
    };
  }

  /// Determine the most common platform in readings
  String _getMostCommonPlatform(List<HRVReading> readings) {
    final platformCounts = <String, int>{};
    
    for (final reading in readings) {
      platformCounts[reading.platform] = (platformCounts[reading.platform] ?? 0) + 1;
    }
    
    if (platformCounts.isEmpty) return 'unknown';
    
    return platformCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Calculate confidence score for baseline quality
  double _calculateConfidence(
    List<HRVReading> readings,
    Map<String, List<HRVReading>> dailyReadings,
    Map<String, double> statistics,
  ) {
    double confidence = 1.0;
    
    // Reduce confidence based on sample size
    if (readings.length < 50) {
      confidence *= 0.8;
    } else if (readings.length < 100) {
      confidence *= 0.9;
    }
    
    // Reduce confidence based on temporal coverage
    if (dailyReadings.length < 14) {
      confidence *= 0.8;
    } else if (dailyReadings.length < 21) {
      confidence *= 0.9;
    }
    
    // Reduce confidence based on data consistency
    final coefficientOfVariation = statistics['std']! / statistics['mean']!;
    if (coefficientOfVariation > 0.5) {
      confidence *= 0.7; // High variability reduces confidence
    } else if (coefficientOfVariation > 0.3) {
      confidence *= 0.85;
    }
    
    // Reduce confidence based on average reading confidence
    final avgReadingConfidence = readings.map((r) => r.confidence).reduce((a, b) => a + b) / readings.length;
    confidence *= avgReadingConfidence;
    
    // Reduce confidence if too many days have very few readings
    final daysWithFewReadings = dailyReadings.values.where((day) => day.length < 3).length;
    final fewReadingsRatio = daysWithFewReadings / dailyReadings.length;
    if (fewReadingsRatio > 0.5) {
      confidence *= 0.8;
    }
    
    return math.max(0.0, math.min(1.0, confidence));
  }

  /// Calculate rolling baseline for trend analysis
  List<BaselineData> calculateRollingBaseline(
    List<HRVReading> readings,
    {int windowDays = 21, int stepDays = 1}
  ) {
    final baselines = <BaselineData>[];
    
    if (readings.isEmpty) return baselines;
    
    // Sort readings by timestamp
    final sortedReadings = readings..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Find the date range
    final startDate = sortedReadings.first.timestamp;
    final endDate = sortedReadings.last.timestamp;
    
    // Calculate baselines for each window
    DateTime currentStart = startDate;
    while (currentStart.add(Duration(days: windowDays)).isBefore(endDate)) {
      final windowEnd = currentStart.add(Duration(days: windowDays));
      
      final windowReadings = sortedReadings
          .where((r) => r.timestamp.isAfter(currentStart) && r.timestamp.isBefore(windowEnd))
          .toList();
      
      final baseline = calculate(windowReadings);
      if (baseline != null) {
        baselines.add(baseline);
      }
      
      currentStart = currentStart.add(Duration(days: stepDays));
    }
    
    return baselines;
  }

  /// Update existing baseline with new readings
  BaselineData? updateBaseline(BaselineData existingBaseline, List<HRVReading> newReadings) {
    // For now, recalculate from scratch
    // In a production system, you might implement incremental updates
    
    // Get all readings from the baseline period plus new readings
    final allReadings = <HRVReading>[];
    
    // Add new readings
    allReadings.addAll(newReadings);
    
    // Calculate new baseline
    return calculate(allReadings);
  }

  /// Validate baseline quality
  Map<String, dynamic> validateBaseline(BaselineData baseline) {
    final issues = <String>[];
    final warnings = <String>[];
    
    // Check sample size
    if (baseline.sampleCount < 50) {
      issues.add('Insufficient sample size (${baseline.sampleCount} < 50)');
    } else if (baseline.sampleCount < 100) {
      warnings.add('Low sample size (${baseline.sampleCount} < 100)');
    }
    
    // Check temporal coverage
    if (baseline.dayCount < 14) {
      issues.add('Insufficient temporal coverage (${baseline.dayCount} < 14 days)');
    } else if (baseline.dayCount < 21) {
      warnings.add('Limited temporal coverage (${baseline.dayCount} < 21 days)');
    }
    
    // Check confidence
    if (baseline.confidence < 0.7) {
      issues.add('Low confidence score (${(baseline.confidence * 100).toStringAsFixed(0)}% < 70%)');
    } else if (baseline.confidence < 0.8) {
      warnings.add('Moderate confidence score (${(baseline.confidence * 100).toStringAsFixed(0)}% < 80%)');
    }
    
    // Check coefficient of variation
    if (baseline.coefficientOfVariation > 0.5) {
      warnings.add('High variability (CV: ${(baseline.coefficientOfVariation * 100).toStringAsFixed(0)}% > 50%)');
    }
    
    // Check for reasonable HRV range
    if (baseline.mean < 20 || baseline.mean > 150) {
      warnings.add('Unusual mean HRV (${baseline.mean.toStringAsFixed(1)}ms)');
    }
    
    return {
      'is_valid': baseline.isValid,
      'issues': issues,
      'warnings': warnings,
      'quality_score': baseline.confidence,
      'quality_description': baseline.qualityDescription,
    };
  }

  /// Compare two baselines for significant changes
  Map<String, dynamic> compareBaselines(BaselineData baseline1, BaselineData baseline2) {
    final meanChange = baseline2.mean - baseline1.mean;
    final meanChangePercent = (meanChange / baseline1.mean) * 100;
    
    final stdChange = baseline2.standardDeviation - baseline1.standardDeviation;
    final stdChangePercent = (stdChange / baseline1.standardDeviation) * 100;
    
    // Determine significance (>10% change is considered significant)
    final isSignificantChange = meanChangePercent.abs() > 10;
    
    String changeDirection;
    if (meanChange > 0) {
      changeDirection = 'improvement';
    } else if (meanChange < 0) {
      changeDirection = 'decline';
    } else {
      changeDirection = 'stable';
    }
    
    return {
      'mean_change': meanChange,
      'mean_change_percent': meanChangePercent,
      'std_change': stdChange,
      'std_change_percent': stdChangePercent,
      'is_significant': isSignificantChange,
      'direction': changeDirection,
      'confidence_change': baseline2.confidence - baseline1.confidence,
    };
  }
}