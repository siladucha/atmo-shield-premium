import 'measurement_mode.dart';
import 'quality_level.dart';

class MeasurementResult {
  final String id;
  final DateTime timestamp;
  final MeasurementMode mode;
  final int bpm;
  final double? rmssd;
  final QualityLevel quality;

  MeasurementResult({
    required this.id,
    required this.timestamp,
    required this.mode,
    required this.bpm,
    this.rmssd,
    required this.quality,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'mode': mode.name,
      'bpm': bpm,
      'rmssd': rmssd,
      'quality': quality.name,
    };
  }

  factory MeasurementResult.fromJson(Map<String, dynamic> json) {
    return MeasurementResult(
      id: json['id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      mode: MeasurementMode.values.firstWhere((e) => e.name == json['mode']),
      bpm: json['bpm'] as int,
      rmssd: json['rmssd'] as double?,
      quality: QualityLevel.values.firstWhere((e) => e.name == json['quality']),
    );
  }

  String get rmssdInterpretation {
    if (rmssd == null) return 'N/A';
    if (rmssd! < 20) return 'Low';
    if (rmssd! > 100) return 'High';
    return 'Normal';
  }

  int get qualityScore {
    switch (quality) {
      case QualityLevel.good:
        return 85;
      case QualityLevel.fair:
        return 65;
      case QualityLevel.poor:
        return 30;
    }
  }

  int get starRating {
    if (qualityScore >= 80) return 4;
    if (qualityScore >= 60) return 3;
    if (qualityScore >= 40) return 2;
    return 1;
  }
}
