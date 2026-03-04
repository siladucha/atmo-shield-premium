enum QualityLevel {
  poor,
  fair,
  good;

  String get displayName {
    switch (this) {
      case QualityLevel.poor:
        return 'Poor';
      case QualityLevel.fair:
        return 'Fair';
      case QualityLevel.good:
        return 'Good';
    }
  }

  String get message {
    switch (this) {
      case QualityLevel.poor:
        return 'Place finger on camera';
      case QualityLevel.fair:
        return 'Signal detected, keep steady';
      case QualityLevel.good:
        return 'Good signal - keep steady';
    }
  }
}
