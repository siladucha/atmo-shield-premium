import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/hrv_reading.dart';
import '../models/baseline_data.dart';
import '../models/stress_event.dart';
import '../utils/z_score_calculator.dart';
import '../utils/baseline_calculator.dart';
import 'health_data_service.dart';
import 'notification_service_simple.dart';
import 'settings_service.dart';

enum ShieldStatus {
  inactive,
  initializing,
  active,
  error,
  insufficientData,
}

class ShieldService extends ChangeNotifier {
  final HealthDataService _healthService;
  final NotificationService _notificationService;
  final SettingsService _settingsService;
  
  // Hive boxes
  late Box<HRVReading> _hrvBox;
  late Box<BaselineData> _baselineBox;
  late Box<StressEvent> _eventBox;
  
  // Current state
  ShieldStatus _status = ShieldStatus.inactive;
  BaselineData? _currentBaseline;
  List<StressEvent> _recentEvents = [];
  DateTime? _lastAnalysis;
  String? _errorMessage;
  
  // Analysis components
  final ZScoreCalculator _zScoreCalculator = ZScoreCalculator();
  final BaselineCalculator _baselineCalculator = BaselineCalculator();
  
  // Timers and subscriptions
  Timer? _analysisTimer;
  StreamSubscription? _healthDataSubscription;

  ShieldService({
    required HealthDataService healthService,
    required NotificationService notificationService,
    required SettingsService settingsService,
  }) : _healthService = healthService,
       _notificationService = notificationService,
       _settingsService = settingsService {
    _initializeService();
  }

  // Getters
  ShieldStatus get status => _status;
  BaselineData? get currentBaseline => _currentBaseline;
  List<StressEvent> get recentEvents => List.unmodifiable(_recentEvents);
  DateTime? get lastAnalysis => _lastAnalysis;
  String? get errorMessage => _errorMessage;
  
  bool get isActive => _status == ShieldStatus.active;
  bool get hasValidBaseline => _currentBaseline?.isValid ?? false;

  Future<void> _initializeService() async {
    try {
      _status = ShieldStatus.initializing;
      notifyListeners();

      // Initialize Hive boxes
      _hrvBox = Hive.box<HRVReading>('shield_hrv_readings');
      _baselineBox = Hive.box<BaselineData>('shield_baselines');
      _eventBox = Hive.box<StressEvent>('shield_events');

      // Load existing baseline
      await _loadCurrentBaseline();
      
      // Load recent events
      await _loadRecentEvents();

      // Subscribe to health data updates
      _healthDataSubscription = _healthService.hrvDataStream.listen(
        _processNewHRVData,
        onError: _handleHealthDataError,
      );

      // Start periodic analysis if enabled
      if (_settingsService.isShieldEnabled) {
        await startMonitoring();
      } else {
        _status = ShieldStatus.inactive;
        notifyListeners();
      }

    } catch (e) {
      _handleError('Failed to initialize Shield service: $e');
    }
  }

  Future<void> startMonitoring() async {
    try {
      if (!_settingsService.isShieldEnabled) {
        throw Exception('Shield is disabled in settings');
      }

      _status = ShieldStatus.initializing;
      _errorMessage = null;
      notifyListeners();

      // Request health permissions
      final hasPermissions = await _healthService.requestPermissions();
      if (!hasPermissions) {
        throw Exception('Health permissions not granted');
      }

      // Start health data monitoring
      await _healthService.startMonitoring();

      // Calculate or update baseline
      await _updateBaseline();

      // Start periodic analysis
      _startPeriodicAnalysis();

      _status = hasValidBaseline ? ShieldStatus.active : ShieldStatus.insufficientData;
      notifyListeners();

    } catch (e) {
      _handleError('Failed to start monitoring: $e');
    }
  }

  Future<void> stopMonitoring() async {
    try {
      _analysisTimer?.cancel();
      _analysisTimer = null;
      
      await _healthService.stopMonitoring();
      
      _status = ShieldStatus.inactive;
      notifyListeners();

    } catch (e) {
      _handleError('Failed to stop monitoring: $e');
    }
  }

  void _startPeriodicAnalysis() {
    _analysisTimer?.cancel();
    
    // Analyze every 5 minutes when app is active
    _analysisTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performAnalysis(),
    );
  }

  Future<void> _processNewHRVData(HRVReading reading) async {
    try {
      // Store the reading
      await _hrvBox.add(reading);
      
      // Trigger immediate analysis
      await _performAnalysis();
      
      // Update baseline if needed
      if (_shouldUpdateBaseline()) {
        await _updateBaseline();
      }

    } catch (e) {
      debugPrint('Error processing HRV data: $e');
    }
  }

  Future<void> _performAnalysis() async {
    try {
      if (!hasValidBaseline) {
        return;
      }

      // Get recent HRV readings
      final recentReadings = await _getRecentHRVReadings();
      if (recentReadings.isEmpty) {
        return;
      }

      final latestReading = recentReadings.first;
      
      // Calculate Z-score
      final zScore = _currentBaseline!.calculateZScore(latestReading.value);
      
      // Check if stress detection threshold is met
      final threshold = _settingsService.stressDetectionThreshold;
      if (zScore <= threshold) {
        await _handleStressDetection(latestReading, zScore);
      }

      _lastAnalysis = DateTime.now();
      notifyListeners();

    } catch (e) {
      debugPrint('Error during analysis: $e');
    }
  }

  Future<void> _handleStressDetection(HRVReading reading, double zScore) async {
    try {
      // Check cooldown period
      if (_isInCooldownPeriod()) {
        return;
      }

      // Get context information
      final context = await _gatherContext(reading);
      
      // Determine recommended protocol
      final protocol = _getRecommendedProtocol(zScore, context);
      
      // Create stress event
      final stressEvent = StressEvent.fromDetection(
        timestamp: reading.timestamp,
        zScore: zScore,
        recommendedProtocol: protocol,
        context: context,
      );

      // Store the event
      await _eventBox.add(stressEvent);
      _recentEvents.insert(0, stressEvent);
      
      // Send notification if appropriate
      if (_shouldSendNotification(stressEvent, context)) {
        await _notificationService.sendStressAlert(stressEvent);
        
        // Update event to mark notification sent
        final updatedEvent = StressEvent(
          detectedAt: stressEvent.detectedAt,
          zScore: stressEvent.zScore,
          severity: stressEvent.severity,
          pattern: stressEvent.pattern,
          recommendedProtocol: stressEvent.recommendedProtocol,
          notificationSent: true,
          context: stressEvent.context,
          confidence: stressEvent.confidence,
        );
        
        await stressEvent.save();
      }

      notifyListeners();

    } catch (e) {
      debugPrint('Error handling stress detection: $e');
    }
  }

  Future<Map<String, dynamic>> _gatherContext(HRVReading reading) async {
    final context = <String, dynamic>{
      'pre_intervention_hrv': reading.value,
      'timestamp': reading.timestamp.millisecondsSinceEpoch,
      'platform': reading.platform,
      'source': reading.source,
    };

    // Add activity context
    final stepCount = await _healthService.getRecentStepCount();
    context['recent_steps'] = stepCount;
    context['is_active'] = stepCount > 500; // Active if >500 steps in last hour

    // Add time context
    final hour = reading.timestamp.hour;
    context['time_of_day'] = hour;
    context['is_quiet_hours'] = _settingsService.isQuietHours(reading.timestamp);

    // Check for neural rigidity
    final rigidityDetected = await _checkNeuralRigidity();
    context['rigidity_detected'] = rigidityDetected;

    // Check for consecutive stress days
    final consecutiveDays = await _getConsecutiveStressDays();
    context['consecutive_stress_days'] = consecutiveDays;

    return context;
  }

  String _getRecommendedProtocol(double zScore, Map<String, dynamic> context) {
    final hour = context['time_of_day'] as int;
    
    // Critical stress - emergency protocols
    if (zScore <= -3.0) {
      return hour >= 23 || hour < 5 
          ? '4-0-10-0' // Before Sleep for night
          : 'physiological_sigh'; // Instant Stress Reset for day
    }
    
    // High stress - intensive calming
    if (zScore <= -2.5) {
      return hour >= 17 
          ? '4-7-8-0' // Huberman Classic for evening
          : '4-0-8-0'; // Deep Calming for day
    }
    
    // Medium stress - calming protocols
    if (zScore <= -2.0) {
      return hour >= 17 
          ? '4-0-8-0' // Deep Calming for evening
          : '4-0-6-0'; // Light Calming for day
    }
    
    // Low stress - coherent protocols
    if (zScore <= -1.8) {
      return hour >= 5 && hour < 11 
          ? '5-0-4-0' // Energizing for morning
          : '5-0-5-0'; // Coherent 5-5 for other times
    }
    
    return '5-0-5-0'; // Default coherent breathing
  }

  bool _shouldSendNotification(StressEvent event, Map<String, dynamic> context) {
    // Don't send during quiet hours unless critical
    if (context['is_quiet_hours'] == true && event.severity != StressSeverity.critical) {
      return false;
    }
    
    // Don't send during active periods unless high stress
    if (context['is_active'] == true && event.severity.index < StressSeverity.high.index) {
      return false;
    }
    
    return true;
  }

  bool _isInCooldownPeriod() {
    if (_recentEvents.isEmpty) return false;
    
    final lastEvent = _recentEvents.first;
    final cooldownMinutes = _settingsService.notificationCooldownMinutes;
    final cooldownEnd = lastEvent.detectedAt.add(Duration(minutes: cooldownMinutes));
    
    return DateTime.now().isBefore(cooldownEnd);
  }

  Future<bool> _checkNeuralRigidity() async {
    final readings = await _getRecentHRVReadings(days: 7);
    if (readings.length < 7) return false;
    
    // Calculate coefficient of variation over 7 days
    final values = readings.map((r) => r.value).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    final stdDev = variance > 0 ? variance : 0.0;
    final coefficientOfVariation = mean > 0 ? stdDev / mean : 0.0;
    
    return coefficientOfVariation < 0.1; // Neural rigidity threshold
  }

  Future<int> _getConsecutiveStressDays() async {
    final events = _eventBox.values
        .where((e) => e.severity.index >= StressSeverity.low.index)
        .toList()
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    
    int consecutiveDays = 0;
    DateTime? lastDate;
    
    for (final event in events) {
      final eventDate = DateTime(
        event.detectedAt.year,
        event.detectedAt.month,
        event.detectedAt.day,
      );
      
      if (lastDate == null) {
        consecutiveDays = 1;
        lastDate = eventDate;
      } else if (lastDate.difference(eventDate).inDays == 1) {
        consecutiveDays++;
        lastDate = eventDate;
      } else {
        break;
      }
    }
    
    return consecutiveDays;
  }

  Future<void> _updateBaseline() async {
    try {
      final readings = await _getRecentHRVReadings(days: 21);
      if (readings.length < 20) {
        // Insufficient data for baseline
        return;
      }

      final baseline = _baselineCalculator.calculate(readings);
      if (baseline != null) {
        await _baselineBox.add(baseline);
        _currentBaseline = baseline;
        
        // Update status if we now have valid baseline
        if (_status == ShieldStatus.insufficientData && baseline.isValid) {
          _status = ShieldStatus.active;
        }
        
        notifyListeners();
      }

    } catch (e) {
      debugPrint('Error updating baseline: $e');
    }
  }

  bool _shouldUpdateBaseline() {
    if (_currentBaseline == null) return true;
    
    // Update baseline daily
    final lastUpdate = _currentBaseline!.calculatedAt;
    final daysSinceUpdate = DateTime.now().difference(lastUpdate).inDays;
    
    return daysSinceUpdate >= 1;
  }

  Future<List<HRVReading>> _getRecentHRVReadings({int days = 1}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    
    return _hrvBox.values
        .where((reading) => reading.timestamp.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _loadCurrentBaseline() async {
    final baselines = _baselineBox.values.toList()
      ..sort((a, b) => b.calculatedAt.compareTo(a.calculatedAt));
    
    if (baselines.isNotEmpty) {
      _currentBaseline = baselines.first;
    }
  }

  Future<void> _loadRecentEvents() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    
    _recentEvents = _eventBox.values
        .where((event) => event.detectedAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
  }

  void _handleHealthDataError(dynamic error) {
    _handleError('Health data error: $error');
  }

  void _handleError(String message) {
    _status = ShieldStatus.error;
    _errorMessage = message;
    notifyListeners();
    debugPrint('Shield Service Error: $message');
  }

  // Manual analysis trigger
  Future<void> performManualAnalysis() async {
    await _performAnalysis();
  }

  // Get analytics data
  Future<Map<String, dynamic>> getAnalytics({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    
    final events = _eventBox.values
        .where((e) => e.detectedAt.isAfter(cutoff))
        .toList();
    
    final readings = _hrvBox.values
        .where((r) => r.timestamp.isAfter(cutoff))
        .toList();
    
    return {
      'total_events': events.length,
      'events_by_severity': _groupEventsBySeverity(events),
      'average_hrv': _calculateAverageHRV(readings),
      'baseline_trend': await _getBaselineTrend(days),
      'intervention_effectiveness': _calculateInterventionEffectiveness(events),
    };
  }

  Map<String, int> _groupEventsBySeverity(List<StressEvent> events) {
    final groups = <String, int>{};
    for (final event in events) {
      final key = event.severityDescription;
      groups[key] = (groups[key] ?? 0) + 1;
    }
    return groups;
  }

  double _calculateAverageHRV(List<HRVReading> readings) {
    if (readings.isEmpty) return 0.0;
    return readings.map((r) => r.value).reduce((a, b) => a + b) / readings.length;
  }

  Future<List<BaselineData>> _getBaselineTrend(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    
    return _baselineBox.values
        .where((b) => b.calculatedAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => a.calculatedAt.compareTo(b.calculatedAt));
  }

  double _calculateInterventionEffectiveness(List<StressEvent> events) {
    final completedInterventions = events
        .where((e) => e.interventionCompleted && e.interventionEffectiveness != null)
        .toList();
    
    if (completedInterventions.isEmpty) return 0.0;
    
    final totalEffectiveness = completedInterventions
        .map((e) => e.interventionEffectiveness!)
        .reduce((a, b) => a + b);
    
    return totalEffectiveness / completedInterventions.length;
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _healthDataSubscription?.cancel();
    super.dispose();
  }
}