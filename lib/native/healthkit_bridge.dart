import 'package:flutter/services.dart';

/// Bridge to native iOS HealthKit functionality for data generation
/// 
/// This class provides a Dart interface to the native Swift ATMOHealthKitWriter
/// plugin, enabling the app to write synthetic health data to HealthKit.
/// 
/// Supported data types:
/// - 'heartRate': Heart rate in beats per minute (bpm)
/// - 'hrv' or 'heartRateVariability': HRV SDNN in milliseconds (ms)
/// - 'respiratoryRate': Respiratory rate in breaths per minute (bpm)
/// - 'steps' or 'stepCount': Step count
/// - 'sleep' or 'sleepAnalysis': Sleep duration in minutes
/// 
/// Requirements: 7.1, 7.2
class HealthKitBridge {
  static const MethodChannel _channel = MethodChannel('healthkit_generator');

  /// Request write permissions for HealthKit data types
  /// 
  /// [writeTypes] should contain strings like 'heartRate', 'hrv', 'respiratoryRate', etc.
  /// Returns true if permissions granted, false otherwise
  /// 
  /// Example:
  /// ```dart
  /// final granted = await bridge.requestPermissions([
  ///   'heartRate',
  ///   'hrv',
  ///   'respiratoryRate',
  ///   'steps',
  ///   'sleep',
  /// ]);
  /// ```
  Future<bool> requestPermissions(List<String> writeTypes) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestPermissions',
        {'writeTypes': writeTypes},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[SynthData] Permission request error: ${e.message}');
      return false;
    }
  }

  /// Write a batch of health data points to HealthKit
  /// 
  /// [dataType] specifies the type of data (e.g., 'heartRate', 'hrv')
  /// [records] is a list of maps containing 'timestamp' (milliseconds) and 'value' (double)
  /// Returns true if successful, false otherwise
  /// 
  /// Example:
  /// ```dart
  /// final success = await bridge.writeBatch('heartRate', [
  ///   {'timestamp': 1234567890000.0, 'value': 72.0},
  ///   {'timestamp': 1234567900000.0, 'value': 75.0},
  /// ]);
  /// ```
  Future<bool> writeBatch(
    String dataType,
    List<Map<String, dynamic>> records,
  ) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'writeBatch',
        {
          'dataType': dataType,
          'records': records,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[SynthData] Write batch error for $dataType: ${e.message}');
      return false;
    }
  }

  /// Check if HealthKit is available on this device
  /// 
  /// Returns false on simulator or devices without HealthKit support
  /// Always check this before requesting permissions or writing data
  Future<bool> isHealthKitAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isHealthKitAvailable');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[SynthData] HealthKit availability check error: ${e.message}');
      return false;
    }
  }
}
