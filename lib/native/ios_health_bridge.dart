import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/hrv_reading.dart';

class IOSHealthBridge {
  static const MethodChannel _channel = MethodChannel('atmo.shield/ios_health');
  
  // Stream controller for HRV data from native iOS
  final StreamController<HRVReading> _hrvStreamController = StreamController<HRVReading>.broadcast();
  Stream<HRVReading> get hrvDataStream => _hrvStreamController.stream;
  
  // Singleton instance
  static final IOSHealthBridge _instance = IOSHealthBridge._internal();
  factory IOSHealthBridge() => _instance;
  IOSHealthBridge._internal() {
    _setupMethodCallHandler();
  }

  /// Setup method call handler for native -> Flutter communication
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle method calls from native iOS code
  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onHRVDataReceived':
          await _handleHRVDataReceived(call.arguments);
          break;
        case 'onStressDetected':
          await _handleStressDetected(call.arguments);
          break;
        case 'onBackgroundTaskCompleted':
          await _handleBackgroundTaskCompleted(call.arguments);
          break;
        case 'onHealthKitError':
          await _handleHealthKitError(call.arguments);
          break;
        default:
          debugPrint('Unknown method call from iOS: ${call.method}');
      }
    } catch (e) {
      debugPrint('Error handling iOS method call: $e');
    }
  }

  /// Handle HRV data received from HealthKit
  Future<void> _handleHRVDataReceived(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments);
      final hrvReading = HRVReading.fromJson(data);
      _hrvStreamController.add(hrvReading);
      debugPrint('Received HRV data from iOS: ${hrvReading.value}ms');
    } catch (e) {
      debugPrint('Error processing HRV data from iOS: $e');
    }
  }

  /// Handle stress detection from native processing
  Future<void> _handleStressDetected(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments);
      debugPrint('Stress detected by iOS native: $data');
      // This would trigger additional Flutter-side processing if needed
    } catch (e) {
      debugPrint('Error handling stress detection from iOS: $e');
    }
  }

  /// Handle background task completion
  Future<void> _handleBackgroundTaskCompleted(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments);
      debugPrint('iOS background task completed: $data');
    } catch (e) {
      debugPrint('Error handling background task completion: $e');
    }
  }

  /// Handle HealthKit errors
  Future<void> _handleHealthKitError(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments);
      final errorMessage = data['error'] as String?;
      debugPrint('HealthKit error: $errorMessage');
    } catch (e) {
      debugPrint('Error handling HealthKit error: $e');
    }
  }

  /// Request HealthKit permissions
  Future<bool> requestHealthKitPermissions() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('requestHealthKitPermissions');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error requesting HealthKit permissions: $e');
      return false;
    }
  }

  /// Start HealthKit monitoring
  Future<bool> startHealthKitMonitoring() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('startHealthKitMonitoring');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error starting HealthKit monitoring: $e');
      return false;
    }
  }

  /// Stop HealthKit monitoring
  Future<bool> stopHealthKitMonitoring() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('stopHealthKitMonitoring');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error stopping HealthKit monitoring: $e');
      return false;
    }
  }

  /// Get historical HRV data
  Future<List<HRVReading>> getHistoricalHRVData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!Platform.isIOS) return [];
    
    try {
      final arguments = {
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
      };
      
      final result = await _channel.invokeMethod('getHistoricalHRVData', arguments);
      final dataList = List<Map<String, dynamic>>.from(result ?? []);
      
      return dataList.map((data) => HRVReading.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Error getting historical HRV data: $e');
      return [];
    }
  }

  /// Get recent step count for activity context
  Future<int> getRecentStepCount({Duration? period}) async {
    if (!Platform.isIOS) return 0;
    
    try {
      final arguments = {
        'periodMinutes': (period ?? const Duration(hours: 1)).inMinutes,
      };
      
      final result = await _channel.invokeMethod('getRecentStepCount', arguments);
      return result as int? ?? 0;
    } catch (e) {
      debugPrint('Error getting step count: $e');
      return 0;
    }
  }

  /// Check if user is currently sleeping
  Future<bool> isUserSleeping() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('isUserSleeping');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking sleep status: $e');
      return false;
    }
  }

  /// Get resting heart rate
  Future<double?> getRestingHeartRate() async {
    if (!Platform.isIOS) return null;
    
    try {
      final result = await _channel.invokeMethod('getRestingHeartRate');
      return result as double?;
    } catch (e) {
      debugPrint('Error getting resting heart rate: $e');
      return null;
    }
  }

  /// Setup background processing
  Future<bool> setupBackgroundProcessing() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('setupBackgroundProcessing');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error setting up background processing: $e');
      return false;
    }
  }

  /// Process HRV data in background (native)
  Future<Map<String, dynamic>?> processHRVInBackground({
    required List<HRVReading> readings,
    required Map<String, dynamic> baseline,
  }) async {
    if (!Platform.isIOS) return null;
    
    try {
      final arguments = {
        'readings': readings.map((r) => r.toJson()).toList(),
        'baseline': baseline,
      };
      
      final result = await _channel.invokeMethod('processHRVInBackground', arguments);
      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      debugPrint('Error processing HRV in background: $e');
      return null;
    }
  }

  /// Schedule local notification from native
  Future<bool> scheduleNativeNotification({
    required String title,
    required String body,
    required Map<String, dynamic> userInfo,
  }) async {
    if (!Platform.isIOS) return false;
    
    try {
      final arguments = {
        'title': title,
        'body': body,
        'userInfo': userInfo,
      };
      
      final result = await _channel.invokeMethod('scheduleNotification', arguments);
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error scheduling native notification: $e');
      return false;
    }
  }

  /// Get HealthKit authorization status
  Future<Map<String, String>> getAuthorizationStatus() async {
    if (!Platform.isIOS) return {};
    
    try {
      final result = await _channel.invokeMethod('getAuthorizationStatus');
      return Map<String, String>.from(result ?? {});
    } catch (e) {
      debugPrint('Error getting authorization status: $e');
      return {};
    }
  }

  /// Check if HealthKit is available
  Future<bool> isHealthKitAvailable() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('isHealthKitAvailable');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking HealthKit availability: $e');
      return false;
    }
  }

  /// Get device capabilities
  Future<Map<String, dynamic>> getDeviceCapabilities() async {
    if (!Platform.isIOS) return {};
    
    try {
      final result = await _channel.invokeMethod('getDeviceCapabilities');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('Error getting device capabilities: $e');
      return {};
    }
  }

  /// Save analysis results to UserDefaults (for background persistence)
  Future<bool> saveAnalysisResults(Map<String, dynamic> results) async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('saveAnalysisResults', results);
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error saving analysis results: $e');
      return false;
    }
  }

  /// Load analysis results from UserDefaults
  Future<Map<String, dynamic>?> loadAnalysisResults() async {
    if (!Platform.isIOS) return null;
    
    try {
      final result = await _channel.invokeMethod('loadAnalysisResults');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      debugPrint('Error loading analysis results: $e');
      return null;
    }
  }

  /// Clear stored analysis results
  Future<bool> clearAnalysisResults() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('clearAnalysisResults');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error clearing analysis results: $e');
      return false;
    }
  }

  /// Get battery level for optimization
  Future<double> getBatteryLevel() async {
    if (!Platform.isIOS) return 1.0;
    
    try {
      final result = await _channel.invokeMethod('getBatteryLevel');
      return result as double? ?? 1.0;
    } catch (e) {
      debugPrint('Error getting battery level: $e');
      return 1.0;
    }
  }

  /// Check if device is in low power mode
  Future<bool> isLowPowerModeEnabled() async {
    if (!Platform.isIOS) return false;
    
    try {
      final result = await _channel.invokeMethod('isLowPowerModeEnabled');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking low power mode: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _hrvStreamController.close();
  }
}