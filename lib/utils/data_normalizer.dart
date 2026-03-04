import 'dart:math' as math;
import '../models/hrv_reading.dart';

enum HealthPlatform {
  healthKit,
  healthConnect,
  googleFit,
  unknown,
}

class DataNormalizer {
  // Platform-specific HRV ranges (in milliseconds)
  static const Map<HealthPlatform, Map<String, double>> _platformRanges = {
    HealthPlatform.healthKit: {
      'min': 30.0,
      'max': 120.0,
      'typical_mean': 45.0,
      'typical_std': 15.0,
    },
    HealthPlatform.healthConnect: {
      'min': 25.0,
      'max': 100.0,
      'typical_mean': 40.0,
      'typical_std': 12.0,
    },
    HealthPlatform.googleFit: {
      'min': 20.0,
      'max': 90.0,
      'typical_mean': 35.0,
      'typical_std': 10.0,
    },
  };

  // Normalization target range (unified scale)
  static const double _targetMin = 0.0;
  static const double _targetMax = 100.0;
  static const double _targetMean = 50.0;

  /// Normalize HRV reading for cross-platform consistency
  HRVReading normalizeHRVReading(HRVReading reading) {
    if (reading.normalized) {
      return reading; // Already normalized
    }

    final platform = _detectPlatform(reading);
    final normalizedValue = normalizeHRVValue(reading.value, platform);
    
    return reading.copyWithNormalized(normalizedValue);
  }

  /// Normalize HRV value based on platform
  double normalizeHRVValue(double rawValue, HealthPlatform platform) {
    final range = _platformRanges[platform];
    if (range == null) {
      return rawValue; // No normalization for unknown platforms
    }

    final platformMin = range['min']!;
    final platformMax = range['max']!;
    
    // Clamp value to platform range
    final clampedValue = math.max(platformMin, math.min(platformMax, rawValue));
    
    // Normalize to 0-100 scale
    final normalizedValue = ((clampedValue - platformMin) / (platformMax - platformMin)) * 100;
    
    return normalizedValue;
  }

  /// Denormalize value back to platform-specific range
  double denormalizeHRVValue(double normalizedValue, HealthPlatform platform) {
    final range = _platformRanges[platform];
    if (range == null) {
      return normalizedValue; // No denormalization for unknown platforms
    }

    final platformMin = range['min']!;
    final platformMax = range['max']!;
    
    // Convert from 0-100 scale back to platform range
    return platformMin + (normalizedValue / 100) * (platformMax - platformMin);
  }

  /// Detect platform from HRV reading
  HealthPlatform _detectPlatform(HRVReading reading) {
    // First check explicit platform info
    if (reading.platform == 'ios') {
      return HealthPlatform.healthKit;
    } else if (reading.platform == 'android') {
      // Determine Android platform based on source
      switch (reading.source) {
        case 'health_connect':
          return HealthPlatform.healthConnect;
        case 'google_fit':
          return HealthPlatform.googleFit;
        default:
          return HealthPlatform.healthConnect; // Default for Android 14+
      }
    }

    // Fallback: detect based on value characteristics
    return _detectPlatformFromValue(reading.value);
  }

  /// Detect platform based on HRV value characteristics
  HealthPlatform _detectPlatformFromValue(double value) {
    // Check which platform range the value fits best
    for (final entry in _platformRanges.entries) {
      final platform = entry.key;
      final range = entry.value;
      
      if (value >= range['min']! && value <= range['max']!) {
        return platform;
      }
    }
    
    return HealthPlatform.unknown;
  }

  /// Calculate platform-specific Z-score
  double calculatePlatformZScore(double value, HealthPlatform platform, {
    double? customMean,
    double? customStd,
  }) {
    final range = _platformRanges[platform];
    if (range == null) return 0.0;

    final mean = customMean ?? range['typical_mean']!;
    final std = customStd ?? range['typical_std']!;
    
    if (std == 0) return 0.0;
    
    return (value - mean) / std;
  }

  /// Normalize baseline data for cross-platform comparison
  Map<String, double> normalizeBaselineData({
    required double mean,
    required double std,
    required HealthPlatform platform,
  }) {
    final normalizedMean = normalizeHRVValue(mean, platform);
    
    // Normalize standard deviation proportionally
    final range = _platformRanges[platform];
    if (range == null) {
      return {'mean': mean, 'std': std};
    }
    
    final platformRange = range['max']! - range['min']!;
    final normalizedStd = (std / platformRange) * 100;
    
    return {
      'mean': normalizedMean,
      'std': normalizedStd,
    };
  }

  /// Convert between platforms (for device migration)
  HRVReading convertBetweenPlatforms(
    HRVReading reading,
    HealthPlatform targetPlatform,
  ) {
    final sourcePlatform = _detectPlatform(reading);
    
    if (sourcePlatform == targetPlatform) {
      return reading; // No conversion needed
    }

    // Normalize to unified scale first
    final normalizedReading = normalizeHRVReading(reading);
    
    // Denormalize to target platform
    final targetValue = denormalizeHRVValue(
      normalizedReading.value,
      targetPlatform,
    );
    
    return HRVReading(
      timestamp: reading.timestamp,
      value: targetValue,
      source: _getSourceForPlatform(targetPlatform),
      platform: _getPlatformString(targetPlatform),
      sampleCount: reading.sampleCount,
      confidence: reading.confidence * 0.9, // Reduce confidence for converted data
      normalized: false, // Reset normalization flag
      metadata: {
        ...?reading.metadata,
        'converted_from': reading.source,
        'original_value': reading.value,
      },
    );
  }

  /// Get source string for platform
  String _getSourceForPlatform(HealthPlatform platform) {
    switch (platform) {
      case HealthPlatform.healthKit:
        return 'healthkit';
      case HealthPlatform.healthConnect:
        return 'health_connect';
      case HealthPlatform.googleFit:
        return 'google_fit';
      case HealthPlatform.unknown:
        return 'unknown';
    }
  }

  /// Get platform string for platform enum
  String _getPlatformString(HealthPlatform platform) {
    switch (platform) {
      case HealthPlatform.healthKit:
        return 'ios';
      case HealthPlatform.healthConnect:
      case HealthPlatform.googleFit:
        return 'android';
      case HealthPlatform.unknown:
        return 'unknown';
    }
  }

  /// Validate HRV value for platform
  bool isValidHRVValue(double value, HealthPlatform platform) {
    final range = _platformRanges[platform];
    if (range == null) {
      // Generic validation for unknown platforms
      return value >= 10 && value <= 200;
    }

    return value >= range['min']! && value <= range['max']!;
  }

  /// Get quality score based on platform characteristics
  double getPlatformQualityScore(HRVReading reading) {
    final platform = _detectPlatform(reading);
    double score = reading.confidence;

    // Adjust score based on platform reliability
    switch (platform) {
      case HealthPlatform.healthKit:
        score *= 1.0; // HealthKit is generally reliable
        break;
      case HealthPlatform.healthConnect:
        score *= 0.95; // Health Connect is newer but good
        break;
      case HealthPlatform.googleFit:
        score *= 0.9; // Google Fit varies by source
        break;
      case HealthPlatform.unknown:
        score *= 0.8; // Unknown platforms get lower score
        break;
    }

    // Adjust based on value reasonableness
    if (!isValidHRVValue(reading.value, platform)) {
      score *= 0.5; // Significantly reduce score for invalid values
    }

    return math.max(0.0, math.min(1.0, score));
  }

  /// Get platform statistics
  Map<String, dynamic> getPlatformStatistics(HealthPlatform platform) {
    final range = _platformRanges[platform];
    if (range == null) {
      return {
        'platform': platform.toString(),
        'supported': false,
      };
    }

    return {
      'platform': platform.toString(),
      'supported': true,
      'min_value': range['min'],
      'max_value': range['max'],
      'typical_mean': range['typical_mean'],
      'typical_std': range['typical_std'],
      'range_size': range['max']! - range['min']!,
    };
  }

  /// Batch normalize multiple readings
  List<HRVReading> normalizeReadings(List<HRVReading> readings) {
    return readings.map(normalizeHRVReading).toList();
  }

  /// Calculate cross-platform compatibility score
  double calculateCompatibilityScore(List<HRVReading> readings) {
    if (readings.isEmpty) return 0.0;

    final platforms = readings.map(_detectPlatform).toSet();
    
    // Single platform is most compatible
    if (platforms.length == 1) return 1.0;
    
    // Multiple platforms reduce compatibility
    double score = 1.0 - (platforms.length - 1) * 0.1;
    
    // Check for unknown platforms
    if (platforms.contains(HealthPlatform.unknown)) {
      score *= 0.8;
    }
    
    return math.max(0.0, score);
  }
}