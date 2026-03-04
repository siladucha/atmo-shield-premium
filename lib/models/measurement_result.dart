import 'measurement_mode.dart';
import 'quality_level.dart';

class MeasurementResult {
  final String id;
  final DateTime timestamp;
  final MeasurementMode mode;
  final int bpm;
  final double? rmssd;
  final QualityLevel quality;
  
  // Diagnostic data
  final int peakCount;
  final int sampleCount;
  final double samplingRate;
  final double signalMean;
  final double signalVariance;
  final double signalAmplitude;

  MeasurementResult({
    required this.id,
    required this.timestamp,
    required this.mode,
    required this.bpm,
    this.rmssd,
    required this.quality,
    this.peakCount = 0,
    this.sampleCount = 0,
    this.samplingRate = 0,
    this.signalMean = 0,
    this.signalVariance = 0,
    this.signalAmplitude = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'mode': mode.name,
      'bpm': bpm,
      'rmssd': rmssd,
      'quality': quality.name,
      'peakCount': peakCount,
      'sampleCount': sampleCount,
      'samplingRate': samplingRate,
      'signalMean': signalMean,
      'signalVariance': signalVariance,
      'signalAmplitude': signalAmplitude,
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
      peakCount: json['peakCount'] as int? ?? 0,
      sampleCount: json['sampleCount'] as int? ?? 0,
      samplingRate: json['samplingRate'] as double? ?? 0,
      signalMean: json['signalMean'] as double? ?? 0,
      signalVariance: json['signalVariance'] as double? ?? 0,
      signalAmplitude: json['signalAmplitude'] as double? ?? 0,
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
