import 'package:hive/hive.dart';

part 'stress_event.g.dart';

@HiveType(typeId: 2)
enum StressSeverity {
  @HiveField(0)
  normal,
  @HiveField(1)
  low,
  @HiveField(2)
  medium,
  @HiveField(3)
  high,
  @HiveField(4)
  critical,
}

@HiveType(typeId: 3)
enum StressPattern {
  @HiveField(0)
  sympatheticOverdrive,
  @HiveField(1)
  neuralRigidity,
  @HiveField(2)
  energyDepletion,
  @HiveField(3)
  acuteStress,
}

@HiveType(typeId: 4)
class StressEvent extends HiveObject {
  @HiveField(0)
  final DateTime detectedAt;
  
  @HiveField(1)
  final double zScore;
  
  @HiveField(2)
  final StressSeverity severity;
  
  @HiveField(3)
  final StressPattern pattern;
  
  @HiveField(4)
  final String? recommendedProtocol;
  
  @HiveField(5)
  final bool notificationSent;
  
  @HiveField(6)
  final DateTime? interventionStarted;
  
  @HiveField(7)
  final bool interventionCompleted;
  
  @HiveField(8)
  final double? postInterventionHRV;
  
  @HiveField(9)
  final String? userFeedback; // 'helpful', 'not_helpful', 'false_positive'
  
  @HiveField(10)
  final Map<String, dynamic>? context; // Calendar events, activity, etc.
  
  @HiveField(11)
  final double confidence; // Detection confidence 0-1

  StressEvent({
    required this.detectedAt,
    required this.zScore,
    required this.severity,
    required this.pattern,
    this.recommendedProtocol,
    this.notificationSent = false,
    this.interventionStarted,
    this.interventionCompleted = false,
    this.postInterventionHRV,
    this.userFeedback,
    this.context,
    this.confidence = 1.0,
  });

  // Factory constructor for creating from detection
  factory StressEvent.fromDetection({
    required DateTime timestamp,
    required double zScore,
    required String? recommendedProtocol,
    Map<String, dynamic>? context,
    double confidence = 1.0,
  }) {
    final severity = _calculateSeverity(zScore);
    final pattern = _determinePattern(zScore, context);
    
    return StressEvent(
      detectedAt: timestamp,
      zScore: zScore,
      severity: severity,
      pattern: pattern,
      recommendedProtocol: recommendedProtocol,
      context: context,
      confidence: confidence,
    );
  }

  // Calculate severity from Z-score
  static StressSeverity _calculateSeverity(double zScore) {
    if (zScore <= -3.0) return StressSeverity.critical;
    if (zScore <= -2.5) return StressSeverity.high;
    if (zScore <= -2.0) return StressSeverity.medium;
    if (zScore <= -1.8) return StressSeverity.low;
    return StressSeverity.normal;
  }

  // Determine stress pattern from context
  static StressPattern _determinePattern(double zScore, Map<String, dynamic>? context) {
    // Default to sympathetic overdrive for acute stress
    if (zScore <= -1.8) {
      // Check for neural rigidity indicators in context
      if (context?['rigidity_detected'] == true) {
        return StressPattern.neuralRigidity;
      }
      
      // Check for energy depletion indicators
      if (context?['consecutive_stress_days'] != null && 
          context!['consecutive_stress_days'] >= 3) {
        return StressPattern.energyDepletion;
      }
      
      return StressPattern.sympatheticOverdrive;
    }
    
    return StressPattern.acuteStress;
  }

  // Get severity color for UI
  String get severityColor {
    switch (severity) {
      case StressSeverity.normal:
        return '#4CAF50'; // Green
      case StressSeverity.low:
        return '#FFC107'; // Amber
      case StressSeverity.medium:
        return '#FF9800'; // Orange
      case StressSeverity.high:
        return '#F44336'; // Red
      case StressSeverity.critical:
        return '#9C27B0'; // Purple
    }
  }

  // Get severity description
  String get severityDescription {
    switch (severity) {
      case StressSeverity.normal:
        return 'Optimal State';
      case StressSeverity.low:
        return 'Mild Activation';
      case StressSeverity.medium:
        return 'Stress Detected';
      case StressSeverity.high:
        return 'High Stress';
      case StressSeverity.critical:
        return 'Critical Stress';
    }
  }

  // Get pattern description
  String get patternDescription {
    switch (pattern) {
      case StressPattern.sympatheticOverdrive:
        return 'Sympathetic Overdrive';
      case StressPattern.neuralRigidity:
        return 'Neural Rigidity';
      case StressPattern.energyDepletion:
        return 'Energy Depletion';
      case StressPattern.acuteStress:
        return 'Acute Stress';
    }
  }

  // Mark intervention as completed
  StressEvent markInterventionCompleted({
    double? postHRV,
    String? feedback,
  }) {
    return StressEvent(
      detectedAt: detectedAt,
      zScore: zScore,
      severity: severity,
      pattern: pattern,
      recommendedProtocol: recommendedProtocol,
      notificationSent: notificationSent,
      interventionStarted: interventionStarted,
      interventionCompleted: true,
      postInterventionHRV: postHRV,
      userFeedback: feedback,
      context: context,
      confidence: confidence,
    );
  }

  // Calculate intervention effectiveness
  double? get interventionEffectiveness {
    if (postInterventionHRV == null || context?['pre_intervention_hrv'] == null) {
      return null;
    }
    
    final preHRV = context!['pre_intervention_hrv'] as double;
    return (postInterventionHRV! - preHRV) / preHRV;
  }

  // JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'detectedAt': detectedAt.millisecondsSinceEpoch,
      'zScore': zScore,
      'severity': severity.index,
      'pattern': pattern.index,
      'recommendedProtocol': recommendedProtocol,
      'notificationSent': notificationSent,
      'interventionStarted': interventionStarted?.millisecondsSinceEpoch,
      'interventionCompleted': interventionCompleted,
      'postInterventionHRV': postInterventionHRV,
      'userFeedback': userFeedback,
      'context': context,
      'confidence': confidence,
    };
  }

  factory StressEvent.fromJson(Map<String, dynamic> json) {
    return StressEvent(
      detectedAt: DateTime.fromMillisecondsSinceEpoch(json['detectedAt']),
      zScore: json['zScore'].toDouble(),
      severity: StressSeverity.values[json['severity']],
      pattern: StressPattern.values[json['pattern']],
      recommendedProtocol: json['recommendedProtocol'],
      notificationSent: json['notificationSent'] ?? false,
      interventionStarted: json['interventionStarted'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['interventionStarted'])
          : null,
      interventionCompleted: json['interventionCompleted'] ?? false,
      postInterventionHRV: json['postInterventionHRV']?.toDouble(),
      userFeedback: json['userFeedback'],
      context: json['context'],
      confidence: json['confidence']?.toDouble() ?? 1.0,
    );
  }

  @override
  String toString() {
    return 'StressEvent(severity: $severityDescription, '
           'zScore: ${zScore.toStringAsFixed(2)}, '
           'pattern: $patternDescription)';
  }
}