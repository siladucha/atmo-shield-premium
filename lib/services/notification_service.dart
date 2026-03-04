import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import '../models/stress_event.dart';
import 'settings_service.dart';

class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final SettingsService _settingsService;
  
  bool _isInitialized = false;
  bool _hasPermission = false;

  NotificationService({SettingsService? settingsService}) 
      : _settingsService = settingsService ?? SettingsService();

  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize platform-specific settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions
      await _requestPermissions();

      // Create notification channels (Android)
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }

      _isInitialized = true;
      notifyListeners();

      debugPrint('Notification service initialized');

    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final result = await _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        _hasPermission = result ?? false;
      } else if (Platform.isAndroid) {
        final permission = await Permission.notification.request();
        _hasPermission = permission == PermissionStatus.granted;
      }

      notifyListeners();

    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      _hasPermission = false;
    }
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    const stressAlertChannel = AndroidNotificationChannel(
      'stress_alerts',
      'Stress Alerts',
      description: 'Proactive stress detection notifications',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const progressChannel = AndroidNotificationChannel(
      'progress_updates',
      'Progress Updates',
      description: 'Weekly progress and baseline updates',
      importance: Importance.defaultImportance,
    );

    const systemChannel = AndroidNotificationChannel(
      'system_updates',
      'System Updates',
      description: 'Shield system status and error notifications',
      importance: Importance.low,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(stressAlertChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(progressChannel);

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(systemChannel);
  }

  /// Send stress alert notification
  Future<void> sendStressAlert(StressEvent event) async {
    if (!_hasPermission || !_settingsService.areStressAlertsEnabled) {
      return;
    }

    try {
      final protocol = event.recommendedProtocol ?? 'Coherent Breathing';
      final scientificContext = _getScientificContext(event);
      
      const androidDetails = AndroidNotificationDetails(
        'stress_alerts',
        'Stress Alerts',
        channelDescription: 'Proactive stress detection notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/shield_icon',
        color: Colors.blue,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'start_protocol',
            'Start Protocol',
            icon: DrawableResourceAndroidBitmap('@drawable/play_icon'),
          ),
          AndroidNotificationAction(
            'remind_later',
            'Remind in 15 min',
            icon: DrawableResourceAndroidBitmap('@drawable/clock_icon'),
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        categoryIdentifier: 'stress_alert',
        threadIdentifier: 'shield_alerts',
        interruptionLevel: InterruptionLevel.active,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = '🛡️ NeuroYoga Stress Alert - ${event.severityDescription}';
      final body = _buildNotificationBody(event, protocol, scientificContext);

      await _notifications.show(
        event.hashCode,
        title,
        body,
        details,
        payload: _createNotificationPayload(event),
      );

      debugPrint('Stress alert notification sent: ${event.severity}');

    } catch (e) {
      debugPrint('Error sending stress alert: $e');
    }
  }

  /// Build notification body text
  String _buildNotificationBody(StressEvent event, String protocol, String scientificContext) {
    final zScoreText = event.zScore.toStringAsFixed(1);
    
    return 'Your HRV shows ${event.patternDescription.toLowerCase()} '
           '(Z-score: $zScoreText). $scientificContext\n\n'
           'Recommended: $protocol\n'
           'Duration: ~${_getProtocolDuration(protocol)} minutes';
  }

  /// Get scientific context for notification
  String _getScientificContext(StressEvent event) {
    switch (event.severity) {
      case StressSeverity.critical:
        return 'Research shows physiological sighs rapidly downregulate stress response within 1-2 minutes.';
      case StressSeverity.high:
        return 'Studies indicate 4-7-8 breathing reduces anxiety markers within 2-3 minutes.';
      case StressSeverity.medium:
        return 'Extended exhale breathing activates parasympathetic recovery within 2-4 minutes.';
      case StressSeverity.low:
        return 'Heart rate variability coherence training improves autonomic balance.';
      default:
        return 'Breathing protocols help maintain nervous system balance.';
    }
  }

  /// Get estimated protocol duration
  String _getProtocolDuration(String protocol) {
    final durationMap = {
      'physiological_sigh': '1',
      '4-7-8-0': '2',
      '4-0-8-0': '2',
      '4-0-6-0': '1.5',
      '5-0-5-0': '2',
      '6-0-6-0': '2.5',
      '5-0-4-0': '1.5',
      '4-0-10-0': '3',
    };
    
    return durationMap[protocol] ?? '2';
  }

  /// Create notification payload for handling taps
  String _createNotificationPayload(StressEvent event) {
    return 'stress_alert|${event.detectedAt.millisecondsSinceEpoch}|'
           '${event.severity.index}|${event.recommendedProtocol ?? ""}';
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      final payload = response.payload;
      final actionId = response.actionId;
      
      if (payload == null) return;

      final parts = payload.split('|');
      if (parts.length < 3) return;

      final type = parts[0];
      final timestamp = int.tryParse(parts[1]);
      final severityIndex = int.tryParse(parts[2]);
      final protocol = parts.length > 3 ? parts[3] : null;

      if (type == 'stress_alert' && timestamp != null && severityIndex != null) {
        _handleStressAlertAction(actionId, timestamp, severityIndex, protocol);
      }

    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  /// Handle stress alert notification actions
  void _handleStressAlertAction(String? actionId, int timestamp, int severityIndex, String? protocol) {
    switch (actionId) {
      case 'start_protocol':
        // Navigate to protocol screen
        _navigateToProtocol(protocol);
        break;
      case 'remind_later':
        // Schedule reminder notification
        _scheduleReminder(timestamp, severityIndex, protocol);
        break;
      default:
        // Default tap - open Shield dashboard
        _navigateToShieldDashboard();
        break;
    }
  }

  /// Navigate to protocol screen
  void _navigateToProtocol(String? protocol) {
    // This would integrate with the main app's navigation
    debugPrint('Navigate to protocol: $protocol');
    // TODO: Implement navigation to protocol screen
  }

  /// Navigate to Shield dashboard
  void _navigateToShieldDashboard() {
    debugPrint('Navigate to Shield dashboard');
    // TODO: Implement navigation to Shield dashboard
  }

  /// Schedule reminder notification
  Future<void> _scheduleReminder(int originalTimestamp, int severityIndex, String? protocol) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'stress_alerts',
        'Stress Alerts',
        channelDescription: 'Stress alert reminders',
        importance: Importance.defaultImportance,
        icon: '@drawable/shield_icon',
      );

      const iosDetails = DarwinNotificationDetails(
        categoryIdentifier: 'stress_reminder',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final scheduledTime = tz.TZDateTime.from(
        DateTime.now().add(const Duration(minutes: 15)),
        tz.local,
      );
      
      await _notifications.zonedSchedule(
        originalTimestamp + 1000, // Unique ID
        '🛡️ NeuroYoga Reminder',
        'Your stress alert from 15 minutes ago. Ready for ${protocol ?? "breathing practice"}?',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );

    } catch (e) {
      debugPrint('Error scheduling reminder: $e');
    }
  }

  /// Send daily baseline update
  Future<void> sendBaselineUpdate({
    required double currentHRV,
    required double baselineMean,
    required String trend,
  }) async {
    if (!_hasPermission || !_settingsService.areBaselineUpdatesEnabled) {
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'progress_updates',
        'Progress Updates',
        channelDescription: 'Daily baseline and progress updates',
        importance: Importance.defaultImportance,
        icon: '@drawable/chart_icon',
      );

      const iosDetails = DarwinNotificationDetails(
        categoryIdentifier: 'baseline_update',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final trendEmoji = trend == 'improving' ? '📈' : trend == 'declining' ? '📉' : '➡️';
      final title = '$trendEmoji Daily HRV Update';
      final body = 'Current: ${currentHRV.toStringAsFixed(1)}ms | '
                   'Baseline: ${baselineMean.toStringAsFixed(1)}ms | '
                   'Trend: ${trend.toUpperCase()}';

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );

    } catch (e) {
      debugPrint('Error sending baseline update: $e');
    }
  }

  /// Send weekly progress summary
  Future<void> sendWeeklyProgress({
    required int stressEventsCount,
    required int interventionsCompleted,
    required double averageHRV,
    required double improvementPercent,
  }) async {
    if (!_hasPermission || !_settingsService.areProgressSummariesEnabled) {
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'progress_updates',
        'Progress Updates',
        channelDescription: 'Weekly progress summaries',
        importance: Importance.defaultImportance,
        icon: '@drawable/trophy_icon',
      );

      const iosDetails = DarwinNotificationDetails(
        categoryIdentifier: 'weekly_progress',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = '🏆 Weekly NeuroYoga Progress';
      final body = 'Stress events: $stressEventsCount | '
                   'Interventions: $interventionsCompleted | '
                   'Avg HRV: ${averageHRV.toStringAsFixed(1)}ms | '
                   'Improvement: ${improvementPercent > 0 ? "+" : ""}${improvementPercent.toStringAsFixed(1)}%';

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );

    } catch (e) {
      debugPrint('Error sending weekly progress: $e');
    }
  }

  /// Send system status notification
  Future<void> sendSystemNotification({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!_hasPermission) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        'system_updates',
        'System Updates',
        channelDescription: 'Shield system notifications',
        importance: isError ? Importance.high : Importance.low,
        icon: isError ? '@drawable/error_icon' : '@drawable/info_icon',
      );

      const iosDetails = DarwinNotificationDetails(
        categoryIdentifier: 'system_update',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final emoji = isError ? '⚠️' : 'ℹ️';
      
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '$emoji $title',
        message,
        details,
      );

    } catch (e) {
      debugPrint('Error sending system notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  @override
  void dispose() {
    super.dispose();
  }
}