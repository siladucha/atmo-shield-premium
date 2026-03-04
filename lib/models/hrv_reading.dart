import 'package:hive/hive.dart';

part 'hrv_reading.g.dart';

@HiveType(typeId: 0)
class HRVReading extends HiveObject {
  @HiveField(0)
  final DateTime timestamp;
  
  @HiveField(1)
  final double value; // SDNN in milliseconds
  
  @HiveField(2)
  final String source; // 'healthkit', 'health_connect', 'google_fit'
  
  @HiveField(3)
  final int sampleCount; // Number of readings in aggregate
  
  @HiveField(4)
  final double confidence; // Data quality score 0-1
  
  @HiveField(5)
  final String platform; // 'ios', 'android'
  
  @HiveField(6)
  final bool normalized; // Whether data has been normalized
  
  @HiveField(7)
  final Map<String, dynamic>? metadata; // Additional context data

  HRVReading({
    required this.timestamp,
    required this.value,
    required this.source,
    this.sampleCount = 1,
    this.confidence = 1.0,
    required this.platform,
    this.normalized = false,
    this.metadata,
  });

  // Factory constructor for creating from health platform data
  factory HRVReading.fromHealthData({
    required DateTime timestamp,
    required double value,
    required String source,
    required String platform,
    int sampleCount = 1,
    double confidence = 1.0,
    Map<String, dynamic>? metadata,
  }) {
    return HRVReading(
      timestamp: timestamp,
      value: value,
      source: source,
      platform: platform,
      sampleCount: sampleCount,
      confidence: confidence,
      normalized: false,
      metadata: metadata,
    );
  }

  // Create normalized copy
  HRVReading copyWithNormalized(double normalizedValue) {
    return HRVReading(
      timestamp: timestamp,
      value: normalizedValue,
      source: source,
      platform: platform,
      sampleCount: sampleCount,
      confidence: confidence,
      normalized: true,
      metadata: metadata,
    );
  }

  // JSON serialization for Method Channel communication
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'value': value,
      'source': source,
      'sampleCount': sampleCount,
      'confidence': confidence,
      'platform': platform,
      'normalized': normalized,
      'metadata': metadata,
    };
  }

  factory HRVReading.fromJson(Map<String, dynamic> json) {
    return HRVReading(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      value: json['value'].toDouble(),
      source: json['source'],
      sampleCount: json['sampleCount'] ?? 1,
      confidence: json['confidence']?.toDouble() ?? 1.0,
      platform: json['platform'],
      normalized: json['normalized'] ?? false,
      metadata: json['metadata'],
    );
  }

  @override
  String toString() {
    return 'HRVReading(timestamp: $timestamp, value: ${value.toStringAsFixed(1)}ms, '
           'source: $source, confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HRVReading &&
        other.timestamp == timestamp &&
        other.value == value &&
        other.source == source;
  }

  @override
  int get hashCode {
    return timestamp.hashCode ^ value.hashCode ^ source.hashCode;
  }
}