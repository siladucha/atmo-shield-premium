import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/hrv_reading.dart';

class AndroidHealthBridge {
  static const MethodChannel _channel = MethodChannel('atmo.shield/android_health');
  
  // Stream controller for HRV data from native Android
  final StreamController<HRVReading> _hrvStreamController = StreamController<HRVReading>.broadcast();
  Stream<HRVReading> get hrvDataStream => _hrvStreamController.stream;
  
  // Singleton instance
  static final AndroidHealthBridge _instance = AndroidHealthBridge._internal();
  factory AndroidHealthBridge() => _instance;
  AndroidHealthBridge._internal() {
    _setupMethodCallHandler();
  }

  /// Setup method call handler for native -> Flutter communication
  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle method calls from native Android code
  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onHRVDataReceived':
          await _handleHRVDataReceived(call.arguments);
          break;
        case 'onStressDetected':
          await _handleStressDetected(call.arguments);
          break;
        case 'onWorkManagerTaskCompleted':
          await _handleWorkManagerTaskCompleted(call.arguments);
          break;
        case 'onHealthConnectError':
          await _handleHealthConnectError(call.arguments);
          break;
        case 'onGoogleFitError':
          await _handleGoogleFitError(call.arguments);
          break;
        default:
          debugPrint('Unknown method call from Android: ${call.method}');
      }
    } catch (e) {
      debugPrint('Error handling Android method call: $e');
    }
  }

  /// Handle HRV data received from Health Connect or Google Fit
  Future<void> _handleHRVDataReceived(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments);
      final hrvReading = HRVReading.fromJson(data);
      _hrvStreamController.add(hrvReading);
      debugPrint('Received HRV data from Android: ${hrvReading.value}ms (${hrvReading.source})');
    } catch (e) {
      debugPrint('Error processing HRV data from Android: $e');
    }
  }

  /// Handle stress detection from native processing
  Future<void> _handleStressDetected(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments);
      debugPrint('Stress detected by Android native: $data');
      // This would trigger additional Flutter-side processing if needed
    } catch (e) {
      debugPrint('Error handling stress detection from Android: $e');
    }
  }

  /// Handle WorkManager task completion
  Future<void> _handleWorkManagerTaskCompleted(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments);
      debugPrint('Android WorkManager task completed: $data');
    } catch (e) {
      debugPrint('Error handling WorkManager task completion: $e');
    }
  }

  /// Handle Health Connect errors
  Future<void> _handleHealthConnectError(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments);
      final errorMessage = data['error'] as String?;
      debugPrint('Health Connect error: $errorMessage');
    } catch (e) {
      debugPrint('Error handling Health Connect error: $e');
    }
  }

  /// Handle Google Fit errors
  Future<void> _handleGoogleFitError(dynamic arguments) async {
    try {
      final data = Map<String, dynamic>.from(arguments);
      final errorMessage = data['error'] as String?;
      debugPrint('Google Fit error: $errorMessage');
    } catch (e) {
      debugPrint('Error handling Google Fit error: $e');
    }
  }

  /// Request Health Connect permissions (Android 14+)
  Future<bool> requestHealthConnectPermissions() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('requestHealthConnectPermissions');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error requesting Health Connect permissions: $e');
      return false;
    }
  }

  /// Request Google Fit permissions (Android <14 fallback)
  Future<bool> requestGoogleFitPermissions() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('requestGoogleFitPermissions');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error requesting Google Fit permissions: $e');
      return false;
    }
  }

  /// Start health monitoring (Health Connect or Google Fit)
  Future<bool> startHealthMonitoring() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('startHealthMonitoring');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error starting health monitoring: $e');
      return false;
    }
  }

  /// Stop health monitoring
  Future<bool> stopHealthMonitoring() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('stopHealthMonitoring');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error stopping health monitoring: $e');
      return false;
    }
  }

  /// Get historical HRV data
  Future<List<HRVReading>> getHistoricalHRVData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!Platform.isAndroid) return [];
    
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
    if (!Platform.isAndroid) return 0;
    
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
    if (!Platform.isAndroid) return false;
    
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
    if (!Platform.isAndroid) return null;
    
    try {
      final result = await _channel.invokeMethod('getRestingHeartRate');
      return result as double?;
    } catch (e) {
      debugPrint('Error getting resting heart rate: $e');
      return null;
    }
  }

  /// Setup WorkManager for background processing
  Future<bool> setupWorkManager() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('setupWorkManager');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error setting up WorkManager: $e');
      return false;
    }
  }

  /// Process HRV data in background (native)
  Future<Map<String, dynamic>?> processHRVInBackground({
    required List<HRVReading> readings,
    required Map<String, dynamic> baseline,
  }) async {
    if (!Platform.isAndroid) return null;
    
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
    required Map<String, dynamic> extras,
  }) async {
    if (!Platform.isAndroid) return false;
    
    try {
      final arguments = {
        'title': title,
        'body': body,
        'extras': extras,
      };
      
      final result = await _channel.invokeMethod('scheduleNotification', arguments);
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error scheduling native notification: $e');
      return false;
    }
  }

  /// Get health platform availability
  Future<Map<String, bool>> getHealthPlatformAvailability() async {
    if (!Platform.isAndroid) return {};
    
    try {
      final result = await _channel.invokeMethod('getHealthPlatformAvailability');
      return Map<String, bool>.from(result ?? {});
    } catch (e) {
      debugPrint('Error getting health platform availability: $e');
      return {};
    }
  }

  /// Get permission status for health data types
  Future<Map<String, String>> getPermissionStatus() async {
    if (!Platform.isAndroid) return {};
    
    try {
      final result = await _channel.invokeMethod('getPermissionStatus');
      return Map<String, String>.from(result ?? {});
    } catch (e) {
      debugPrint('Error getting permission status: $e');
      return {};
    }
  }

  /// Check if device is in battery optimization whitelist
  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod('isBatteryOptimizationDisabled');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request to disable battery optimization
  Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final result = await _channel.invokeMethod('requestDisableBatteryOptimization');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error requesting battery optimization disable: $e');
      return false;
    }
  }

  /// Get Android version info
  Future<Map<String, dynamic>> getAndroidVersionInfo() async {
    if (!Platform.isAndroid) return {};
    
    try {
      final result = await _channel.invokeMethod('getAndroidVersionInfo');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('Error getting Android version info: $e');
      return {};
    }
  }

  /// Save analysis results to SharedPreferences (for background persistence)
  Future<bool> saveAnalysisResults(Map<String, dynamic> results) async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('saveAnalysisResults', results);
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error saving analysis results: $e');
      return false;
    }
  }

  /// Load analysis results from SharedPreferences
  Future<Map<String, dynamic>?> loadAnalysisResults() async {
    if (!Platform.isAndroid) return null;
    
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
    if (!Platform.isAndroid) return false;
    
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
    if (!Platform.isAndroid) return 1.0;
    
    try {
      final result = await _channel.invokeMethod('getBatteryLevel');
      return result as double? ?? 1.0;
    } catch (e) {
      debugPrint('Error getting battery level: $e');
      return 1.0;
    }
  }

  /// Check if device is in power save mode
  Future<bool> isPowerSaveModeEnabled() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('isPowerSaveModeEnabled');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking power save mode: $e');
      return false;
    }
  }

  /// Start foreground service for critical processing
  Future<bool> startForegroundService() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('startForegroundService');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error starting foreground service: $e');
      return false;
    }
  }

  /// Stop foreground service
  Future<bool> stopForegroundService() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('stopForegroundService');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error stopping foreground service: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _hrvStreamController.close();
  }
}