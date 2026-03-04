/// Represents a single health data point for HealthKit generation.
///
/// This model encapsulates health metrics (HR, HRV, RR, Steps, Sleep) with
/// validation and serialization for Method Channel communication with native iOS.
class HealthDataPoint {
  /// Type of health data (e.g., 'heartRate', 'hrv', 'respiratoryRate', 'steps', 'sleep')
  final String type;

  /// Numeric value of the measurement
  final double value;

  /// Timestamp when the measurement was taken
  final DateTime timestamp;

  /// Unit of measurement (e.g., 'bpm', 'ms', 'count', 'min')
  final String unit;

  const HealthDataPoint({
    required this.type,
    required this.value,
    required this.timestamp,
    required this.unit,
  });

  /// Validates that the data point has valid values.
  ///
  /// Checks:
  /// - Value is positive
  /// - Timestamp is not in the future
  /// - Value is within valid range for the data type
  bool isValid() {
    return value > 0 &&
        timestamp.isBefore(DateTime.now()) &&
        _isValidRange();
  }

  /// Checks if the value is within the valid range for this data type.
  bool _isValidRange() {
    switch (type) {
      case 'heartRate':
        // Valid HR range: 40-200 bpm (covers resting to maximum)
        return value >= 40 && value <= 200;
      case 'hrv':
        // Valid HRV range: 10-200 ms (covers stress to excellent)
        return value >= 10 && value <= 200;
      case 'respiratoryRate':
        // Valid RR range: 8-30 breaths per minute
        return value >= 8 && value <= 30;
      case 'steps':
        // Valid steps range: 0-100000 steps per day
        return value >= 0 && value <= 100000;
      case 'sleep':
        // Valid sleep range: 0-960 minutes (0-16 hours)
        return value >= 0 && value <= 960;
      default:
        // Unknown types are considered valid (extensibility)
        return true;
    }
  }

  /// Converts the data point to a Map for Method Channel serialization.
  ///
  /// Returns a map with keys: type, value, timestamp (ISO 8601), unit
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'unit': unit,
    };
  }

  /// Creates a HealthDataPoint from a Map (for deserialization).
  factory HealthDataPoint.fromMap(Map<String, dynamic> map) {
    return HealthDataPoint(
      type: map['type'] as String,
      value: (map['value'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      unit: map['unit'] as String,
    );
  }

  @override
  String toString() {
    return 'HealthDataPoint(type: $type, value: $value, timestamp: $timestamp, unit: $unit)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is HealthDataPoint &&
        other.type == type &&
        other.value == value &&
        other.timestamp == timestamp &&
        other.unit == unit;
  }

  @override
  int get hashCode {
    return type.hashCode ^
        value.hashCode ^
        timestamp.hashCode ^
        unit.hashCode;
  }
}
