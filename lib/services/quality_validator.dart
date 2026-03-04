import '../models/quality_level.dart';

class QualityValidator {
  // Device baseline values (calibrated during first measurement)
  double _baselineBrightness = 128.0;
  bool _isCalibrated = false;
  
  // History for temporal analysis
  final List<double> _brightnessHistory = [];
  final List<double> _varianceHistory = [];
  static const int _historyLength = 10; // Last 10 samples (~10 seconds)

  QualityLevel assessQuality(
    double meanBrightness,
    double variance, {
    double? redMean,
    double? blueMean,
  }) {
    // Store history
    _brightnessHistory.add(meanBrightness);
    _varianceHistory.add(variance);
    if (_brightnessHistory.length > _historyLength) {
      _brightnessHistory.removeAt(0);
      _varianceHistory.removeAt(0);
    }

    // Auto-calibrate on first signal
    if (!_isCalibrated && meanBrightness > 20) {
      _baselineBrightness = meanBrightness;
      _isCalibrated = true;
    }

    // 1. Check brightness range (finger presence)
    // Too dark: no finger or no flash
    if (meanBrightness < 20) {
      return QualityLevel.poor; // No finger or flash off
    }
    
    // Too bright: oversaturation (rare with finger)
    if (meanBrightness > 240) {
      return QualityLevel.poor; // Oversaturation
    }

    // 2. Check variance (blood flow pulsation)
    // Even weak pulsation is acceptable (0.5+)
    if (variance < 0.5) {
      return QualityLevel.poor; // No pulsation - overpressure or no finger
    }

    // 3. Check color ratios if available (finger detection)
    if (redMean != null && blueMean != null && meanBrightness > 0) {
      final double redToGreen = redMean / meanBrightness;
      final double blueToGreen = blueMean / meanBrightness;
      
      // Relaxed thresholds: red/green > 0.5, blue/green > 0.4
      if (redToGreen < 0.5 || blueToGreen < 0.4) {
        return QualityLevel.fair; // Weak signal but acceptable
      }
    }

    // 4. Check temporal stability (movement detection)
    if (_brightnessHistory.length >= 5) {
      final recentBrightness = _brightnessHistory.sublist(
        _brightnessHistory.length - 5,
      );
      final brightnessStd = _calculateStdDev(recentBrightness);
      
      // High brightness variation = movement
      if (brightnessStd > 20.0) {
        return QualityLevel.fair; // Movement detected
      }
    }

    // 5. Check signal strength
    // Strong variance indicates good pulsatile signal
    if (variance >= 10.0) {
      return QualityLevel.good; // Strong signal
    }

    // Moderate variance = fair signal (still usable)
    if (variance >= 3.0) {
      return QualityLevel.fair;
    }

    // Weak but detectable signal
    return QualityLevel.poor; // Too weak
  }

  String getQualityMessage(QualityLevel level, double variance, double brightness) {
    switch (level) {
      case QualityLevel.poor:
        // Provide specific guidance based on metrics
        if (brightness < _baselineBrightness * 0.2) {
          return 'Place finger on camera';
        }
        if (brightness > _baselineBrightness * 0.8) {
          return 'Adjust finger position';
        }
        if (variance < 2.0) {
          return 'Reduce finger pressure or adjust position';
        }
        return 'Place finger firmly on camera';
        
      case QualityLevel.fair:
        if (_brightnessHistory.length >= 5) {
          final recentBrightness = _brightnessHistory.sublist(
            _brightnessHistory.length - 5,
          );
          final brightnessStd = _calculateStdDev(recentBrightness);
          if (brightnessStd > 15.0) {
            return 'Keep hand still';
          }
        }
        return 'Signal detected, keep steady';
        
      case QualityLevel.good:
        return 'Good signal - keep steady';
    }
  }

  double _calculateStdDev(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values
        .map((x) => (x - mean) * (x - mean))
        .reduce((a, b) => a + b) / values.length;
    
    return variance > 0 ? variance : 0.0; // Return variance, not sqrt
  }

  void reset() {
    _isCalibrated = false;
    _baselineBrightness = 128.0;
    _brightnessHistory.clear();
    _varianceHistory.clear();
  }
}
