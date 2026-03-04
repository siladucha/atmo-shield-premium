import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/hrv_reading.dart';
import '../utils/data_normalizer.dart';

class HealthDataService extends ChangeNotifier {
  final Health _health = Health();
  final DataNormalizer _normalizer = DataNormalizer();
  
  // Stream controller for HRV data
  final StreamController<HRVReading> _hrvStreamController = StreamController<HRVReading>.broadcast();
  Stream<HRVReading> get hrvDataStream => _hrvStreamController.stream;
  
  // Monitoring state
  bool _isMonitoring = false;
  Timer? _monitoringTimer;
  DateTime? _lastDataFetch;
  
  // Platform detection
  String get currentPlatform => Platform.isIOS ? 'ios' : 'android';
  
  // Health data types we need
  static const List<HealthDataType> _requiredTypes = [
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
  ];

  bool get isMonitoring => _isMonitoring;
  DateTime? get lastDataFetch => _lastDataFetch;

  /// Request health permissions
  Future<bool> requestPermissions() async {
    try {
      // Request health data permissions
      final healthPermissions = await _health.requestAuthorization(_requiredTypes);
      
      if (!healthPermissions) {
        debugPrint('Health permissions denied');
        return false;
      }

      // Request additional platform-specific permissions
      if (Platform.isAndroid) {
        final activityPermission = await Permission.activityRecognition.request();
        final sensorsPermission = await Permission.sensors.request();
        
        if (activityPermission != PermissionStatus.granted || 
            sensorsPermission != PermissionStatus.granted) {
          debugPrint('Android activity/sensor permissions denied');
          // Continue anyway as health data might still work
        }
      }

      debugPrint('Health permissions granted');
      return true;

    } catch (e) {
      debugPrint('Error requesting health permissions: $e');
      return false;
    }
  }

  /// Start health data monitoring
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    try {
      _isMonitoring = true;
      notifyListeners();

      // Fetch initial historical data
      await _fetchHistoricalData();

      // Start periodic monitoring
      _startPeriodicFetch();

      debugPrint('Health monitoring started');

    } catch (e) {
      _isMonitoring = false;
      notifyListeners();
      debugPrint('Error starting health monitoring: $e');
      rethrow;
    }
  }

  /// Stop health data monitoring
  Future<void> stopMonitoring() async {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    notifyListeners();
    
    debugPrint('Health monitoring stopped');
  }

  /// Start periodic data fetching
  void _startPeriodicFetch() {
    _monitoringTimer?.cancel();
    
    // Fetch new data every 15 minutes
    _monitoringTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _fetchRecentData(),
    );
  }

  /// Fetch historical HRV data (last 30 days)
  Future<void> _fetchHistoricalData() async {
    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        startTime: thirtyDaysAgo,
        endTime: now,
      );

      await _processHealthData(healthData);
      _lastDataFetch = now;
      notifyListeners();

    } catch (e) {
      debugPrint('Error fetching historical health data: $e');
    }
  }

  /// Fetch recent HRV data (last 2 hours)
  Future<void> _fetchRecentData() async {
    try {
      final now = DateTime.now();
      final twoHoursAgo = _lastDataFetch ?? now.subtract(const Duration(hours: 2));

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        startTime: twoHoursAgo,
        endTime: now,
      );

      await _processHealthData(healthData);
      _lastDataFetch = now;
      notifyListeners();

    } catch (e) {
      debugPrint('Error fetching recent health data: $e');
    }
  }

  /// Process health data and emit HRV readings
  Future<void> _processHealthData(List<HealthDataPoint> healthData) async {
    for (final dataPoint in healthData) {
      if (dataPoint.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) {
        try {
          final hrvReading = await _createHRVReading(dataPoint);
          if (hrvReading != null) {
            _hrvStreamController.add(hrvReading);
          }
        } catch (e) {
          debugPrint('Error processing HRV data point: $e');
        }
      }
    }
  }

  /// Create HRV reading from health data point
  Future<HRVReading?> _createHRVReading(HealthDataPoint dataPoint) async {
    try {
      final rawValue = (dataPoint.value as NumericHealthValue).numericValue.toDouble();
      
      // Validate HRV value range
      if (rawValue < 1 || rawValue > 300) {
        debugPrint('Invalid HRV value: $rawValue');
        return null;
      }

      // Determine data source
      final source = _getDataSource(dataPoint);
      
      // Calculate confidence based on data quality
      final confidence = _calculateDataConfidence(dataPoint);
      
      // Create raw reading
      final rawReading = HRVReading.fromHealthData(
        timestamp: dataPoint.dateFrom,
        value: rawValue,
        source: source,
        platform: currentPlatform,
        confidence: confidence,
        metadata: {
          'source_id': dataPoint.sourceId,
          'source_name': dataPoint.sourceName,
          'unit': dataPoint.unit.name,
        },
      );

      // Normalize the reading for cross-platform consistency
      final normalizedReading = _normalizer.normalizeHRVReading(rawReading);
      
      return normalizedReading;

    } catch (e) {
      debugPrint('Error creating HRV reading: $e');
      return null;
    }
  }

  /// Determine data source from health data point
  String _getDataSource(HealthDataPoint dataPoint) {
    if (Platform.isIOS) {
      return 'healthkit';
    } else {
      // Android - could be Health Connect or Google Fit
      final sourceName = dataPoint.sourceName?.toLowerCase() ?? '';
      if (sourceName.contains('health connect')) {
        return 'health_connect';
      } else if (sourceName.contains('google fit') || sourceName.contains('fit')) {
        return 'google_fit';
      } else {
        return 'health_connect'; // Default for Android 14+
      }
    }
  }

  /// Calculate data confidence based on various factors
  double _calculateDataConfidence(HealthDataPoint dataPoint) {
    double confidence = 1.0;
    
    // Reduce confidence for very old data
    final age = DateTime.now().difference(dataPoint.dateFrom);
    if (age.inHours > 24) {
      confidence *= 0.9;
    } else if (age.inHours > 48) {
      confidence *= 0.8;
    }
    
    // Reduce confidence based on source reliability
    final sourceName = dataPoint.sourceName?.toLowerCase() ?? '';
    if (sourceName.contains('manual') || sourceName.contains('user')) {
      confidence *= 0.7; // Manual entries are less reliable
    } else if (sourceName.contains('apple watch') || sourceName.contains('samsung')) {
      confidence *= 1.0; // High-quality wearables
    } else if (sourceName.contains('phone') || sourceName.contains('smartphone')) {
      confidence *= 0.8; // Phone sensors are less accurate
    }
    
    return confidence;
  }

  /// Get recent step count for activity context
  Future<int> getRecentStepCount({Duration? period}) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(period ?? const Duration(hours: 1));

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: start,
        endTime: now,
      );

      if (healthData.isEmpty) return 0;

      // Sum all step counts in the period
      return healthData
          .map((point) => (point.value as NumericHealthValue).numericValue.toInt())
          .reduce((a, b) => a + b);

    } catch (e) {
      debugPrint('Error getting step count: $e');
      return 0;
    }
  }

  /// Get sleep data for context
  Future<bool> isUserSleeping({DateTime? at}) async {
    try {
      final checkTime = at ?? DateTime.now();
      final start = checkTime.subtract(const Duration(hours: 1));
      final end = checkTime.add(const Duration(hours: 1));

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: start,
        endTime: end,
      );

      // Check if any sleep data overlaps with the check time
      return healthData.any((point) =>
          point.dateFrom.isBefore(checkTime) && point.dateTo.isAfter(checkTime));

    } catch (e) {
      debugPrint('Error checking sleep status: $e');
      return false;
    }
  }

  /// Get resting heart rate for additional context
  Future<double?> getRecentRestingHeartRate() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.RESTING_HEART_RATE],
        startTime: yesterday,
        endTime: now,
      );

      if (healthData.isEmpty) return null;

      // Get the most recent resting heart rate
      healthData.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      return healthData.first.value != null ? (healthData.first.value as NumericHealthValue).numericValue.toDouble() : null;

    } catch (e) {
      debugPrint('Error getting resting heart rate: $e');
      return null;
    }
  }

  /// Check if health data is available
  Future<bool> isHealthDataAvailable() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        startTime: yesterday,
        endTime: now,
      );

      return healthData.isNotEmpty;

    } catch (e) {
      debugPrint('Error checking health data availability: $e');
      return false;
    }
  }

  /// Get health data statistics
  Future<Map<String, dynamic>> getHealthDataStatistics() async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final healthData = await _health.getHealthDataFromTypes(
        types: _requiredTypes,
        startTime: sevenDaysAgo,
        endTime: now,
      );

      final stats = <String, dynamic>{};
      
      // Group by data type
      for (final type in _requiredTypes) {
        final typeData = healthData.where((point) => point.type == type).toList();
        stats[type.name] = {
          'count': typeData.length,
          'latest': typeData.isNotEmpty ? typeData.last.dateFrom : null,
          'sources': typeData.map((p) => p.sourceName).toSet().toList(),
        };
      }

      return stats;

    } catch (e) {
      debugPrint('Error getting health data statistics: $e');
      return {};
    }
  }

  /// Manual data refresh
  Future<void> refreshData() async {
    if (!_isMonitoring) return;
    
    await _fetchRecentData();
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    _hrvStreamController.close();
    super.dispose();
  }
}