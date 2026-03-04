import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum ShieldSensitivityMode {
  minimal,   // Only critical stress alerts (Z-score ≤ -2.5)
  balanced,  // Standard sensitivity (Z-score ≤ -1.8) - default
  intensive, // High sensitivity (Z-score ≤ -1.5)
  custom,    // User-defined thresholds
}

class SettingsService extends ChangeNotifier {
  late Box _settingsBox;
  bool _isInitialized = false;

  // Default settings
  static const bool _defaultShieldEnabled = false;
  static const ShieldSensitivityMode _defaultSensitivityMode = ShieldSensitivityMode.balanced;
  static const double _defaultCustomThreshold = -1.8;
  static const int _defaultCooldownMinutes = 180; // 3 hours
  static const int _defaultActiveHoursStart = 7; // 7 AM
  static const int _defaultActiveHoursEnd = 22; // 10 PM
  static const bool _defaultWeekendMode = false;
  static const bool _defaultStressAlerts = true;
  static const bool _defaultBaselineUpdates = true;
  static const bool _defaultProgressSummaries = true;
  static const bool _defaultCalendarIntegration = false;
  static const int _defaultDataRetentionDays = 90;
  static const ThemeMode _defaultThemeMode = ThemeMode.system;

  bool get isInitialized => _isInitialized;

  /// Initialize settings service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _settingsBox = Hive.box('shield_settings');
      _isInitialized = true;
      notifyListeners();
      debugPrint('Settings service initialized');
    } catch (e) {
      debugPrint('Error initializing settings: $e');
    }
  }

  // Shield Core Settings
  bool get isShieldEnabled {
    if (!_isInitialized) return _defaultShieldEnabled;
    return _settingsBox.get('shield_enabled', defaultValue: _defaultShieldEnabled);
  }
  
  set isShieldEnabled(bool value) {
    if (!_isInitialized) return;
    _settingsBox.put('shield_enabled', value);
    notifyListeners();
  }

  ShieldSensitivityMode get sensitivityMode {
    final index = _settingsBox.get('sensitivity_mode', defaultValue: _defaultSensitivityMode.index);
    return ShieldSensitivityMode.values[index];
  }
  set sensitivityMode(ShieldSensitivityMode mode) {
    _settingsBox.put('sensitivity_mode', mode.index);
    notifyListeners();
  }

  double get customThreshold => _settingsBox.get('custom_threshold', defaultValue: _defaultCustomThreshold);
  set customThreshold(double value) {
    _settingsBox.put('custom_threshold', value);
    notifyListeners();
  }

  /// Get stress detection threshold based on current sensitivity mode
  double get stressDetectionThreshold {
    switch (sensitivityMode) {
      case ShieldSensitivityMode.minimal:
        return -2.5;
      case ShieldSensitivityMode.balanced:
        return -1.8;
      case ShieldSensitivityMode.intensive:
        return -1.5;
      case ShieldSensitivityMode.custom:
        return customThreshold;
    }
  }

  // Monitoring Schedule Settings
  int get activeHoursStart => _settingsBox.get('active_hours_start', defaultValue: _defaultActiveHoursStart);
  set activeHoursStart(int hour) {
    _settingsBox.put('active_hours_start', hour);
    notifyListeners();
  }

  int get activeHoursEnd => _settingsBox.get('active_hours_end', defaultValue: _defaultActiveHoursEnd);
  set activeHoursEnd(int hour) {
    _settingsBox.put('active_hours_end', hour);
    notifyListeners();
  }

  bool get weekendModeEnabled => _settingsBox.get('weekend_mode', defaultValue: _defaultWeekendMode);
  set weekendModeEnabled(bool value) {
    _settingsBox.put('weekend_mode', value);
    notifyListeners();
  }

  /// Check if current time is within quiet hours
  bool isQuietHours(DateTime time) {
    final hour = time.hour;
    
    // Handle overnight quiet hours (e.g., 22:00 - 07:00)
    if (activeHoursEnd > activeHoursStart) {
      return hour < activeHoursStart || hour >= activeHoursEnd;
    } else {
      return hour >= activeHoursEnd && hour < activeHoursStart;
    }
  }

  /// Check if weekend mode should apply
  bool shouldApplyWeekendMode(DateTime time) {
    if (!weekendModeEnabled) return false;
    return time.weekday == DateTime.saturday || time.weekday == DateTime.sunday;
  }

  // Notification Settings
  int get notificationCooldownMinutes => _settingsBox.get('cooldown_minutes', defaultValue: _defaultCooldownMinutes);
  set notificationCooldownMinutes(int minutes) {
    _settingsBox.put('cooldown_minutes', minutes);
    notifyListeners();
  }

  bool get areStressAlertsEnabled => _settingsBox.get('stress_alerts', defaultValue: _defaultStressAlerts);
  set areStressAlertsEnabled(bool value) {
    _settingsBox.put('stress_alerts', value);
    notifyListeners();
  }

  bool get areBaselineUpdatesEnabled => _settingsBox.get('baseline_updates', defaultValue: _defaultBaselineUpdates);
  set areBaselineUpdatesEnabled(bool value) {
    _settingsBox.put('baseline_updates', value);
    notifyListeners();
  }

  bool get areProgressSummariesEnabled => _settingsBox.get('progress_summaries', defaultValue: _defaultProgressSummaries);
  set areProgressSummariesEnabled(bool value) {
    _settingsBox.put('progress_summaries', value);
    notifyListeners();
  }

  // Integration Settings
  bool get isCalendarIntegrationEnabled => _settingsBox.get('calendar_integration', defaultValue: _defaultCalendarIntegration);
  set isCalendarIntegrationEnabled(bool value) {
    _settingsBox.put('calendar_integration', value);
    notifyListeners();
  }

  // Data Management Settings
  int get dataRetentionDays => _settingsBox.get('data_retention_days', defaultValue: _defaultDataRetentionDays);
  set dataRetentionDays(int days) {
    _settingsBox.put('data_retention_days', days);
    notifyListeners();
  }

  // UI Settings
  ThemeMode get themeMode {
    final index = _settingsBox.get('theme_mode', defaultValue: _defaultThemeMode.index);
    return ThemeMode.values[index];
  }
  set themeMode(ThemeMode mode) {
    _settingsBox.put('theme_mode', mode.index);
    notifyListeners();
  }

  // Advanced Settings
  int get baselineCalculationDays => _settingsBox.get('baseline_days', defaultValue: 21);
  set baselineCalculationDays(int days) {
    _settingsBox.put('baseline_days', days);
    notifyListeners();
  }

  double get minimumDataQuality => _settingsBox.get('min_data_quality', defaultValue: 0.7);
  set minimumDataQuality(double quality) {
    _settingsBox.put('min_data_quality', quality);
    notifyListeners();
  }

  bool get exerciseFilterEnabled => _settingsBox.get('exercise_filter', defaultValue: true);
  set exerciseFilterEnabled(bool value) {
    _settingsBox.put('exercise_filter', value);
    notifyListeners();
  }

  bool get sleepFilterEnabled => _settingsBox.get('sleep_filter', defaultValue: true);
  set sleepFilterEnabled(bool value) {
    _settingsBox.put('sleep_filter', value);
    notifyListeners();
  }

  // Premium Settings
  bool get isPremiumUser => _settingsBox.get('premium_user', defaultValue: false);
  set isPremiumUser(bool value) {
    _settingsBox.put('premium_user', value);
    notifyListeners();
  }

  DateTime? get premiumPurchaseDate {
    final timestamp = _settingsBox.get('premium_purchase_date');
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }
  set premiumPurchaseDate(DateTime? date) {
    _settingsBox.put('premium_purchase_date', date?.millisecondsSinceEpoch);
    notifyListeners();
  }

  String? get premiumSubscriptionType => _settingsBox.get('premium_subscription_type');
  set premiumSubscriptionType(String? type) {
    _settingsBox.put('premium_subscription_type', type);
    notifyListeners();
  }

  // Onboarding and Tutorial
  bool get hasCompletedOnboarding => _settingsBox.get('completed_onboarding', defaultValue: false);
  set hasCompletedOnboarding(bool value) {
    _settingsBox.put('completed_onboarding', value);
    notifyListeners();
  }

  bool get hasSeenShieldTutorial => _settingsBox.get('seen_shield_tutorial', defaultValue: false);
  set hasSeenShieldTutorial(bool value) {
    _settingsBox.put('seen_shield_tutorial', value);
    notifyListeners();
  }

  // Analytics and Feedback
  bool get analyticsEnabled => _settingsBox.get('analytics_enabled', defaultValue: true);
  set analyticsEnabled(bool value) {
    _settingsBox.put('analytics_enabled', value);
    notifyListeners();
  }

  bool get crashReportingEnabled => _settingsBox.get('crash_reporting', defaultValue: true);
  set crashReportingEnabled(bool value) {
    _settingsBox.put('crash_reporting', value);
    notifyListeners();
  }

  // Helper Methods
  
  /// Get sensitivity mode description
  String getSensitivityModeDescription(ShieldSensitivityMode mode) {
    switch (mode) {
      case ShieldSensitivityMode.minimal:
        return 'Only critical stress alerts (Z-score ≤ -2.5)';
      case ShieldSensitivityMode.balanced:
        return 'Standard sensitivity (Z-score ≤ -1.8) - Recommended';
      case ShieldSensitivityMode.intensive:
        return 'High sensitivity (Z-score ≤ -1.5) - More frequent alerts';
      case ShieldSensitivityMode.custom:
        return 'Custom threshold (Z-score ≤ ${customThreshold.toStringAsFixed(1)})';
    }
  }

  /// Get cooldown description
  String getCooldownDescription() {
    final hours = notificationCooldownMinutes ~/ 60;
    final minutes = notificationCooldownMinutes % 60;
    
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m between notifications';
    } else if (hours > 0) {
      return '${hours}h between notifications';
    } else {
      return '${minutes}m between notifications';
    }
  }

  /// Get active hours description
  String getActiveHoursDescription() {
    final startTime = TimeOfDay(hour: activeHoursStart, minute: 0);
    final endTime = TimeOfDay(hour: activeHoursEnd, minute: 0);
    
    return '${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    await _settingsBox.clear();
    notifyListeners();
  }

  /// Export settings
  Map<String, dynamic> exportSettings() {
    return Map<String, dynamic>.from(_settingsBox.toMap());
  }

  /// Import settings
  Future<void> importSettings(Map<String, dynamic> settings) async {
    for (final entry in settings.entries) {
      await _settingsBox.put(entry.key, entry.value);
    }
    notifyListeners();
  }

  /// Get settings summary for debugging
  Map<String, dynamic> getSettingsSummary() {
    return {
      'shield_enabled': isShieldEnabled,
      'sensitivity_mode': sensitivityMode.toString(),
      'stress_threshold': stressDetectionThreshold,
      'active_hours': getActiveHoursDescription(),
      'cooldown': getCooldownDescription(),
      'notifications': {
        'stress_alerts': areStressAlertsEnabled,
        'baseline_updates': areBaselineUpdatesEnabled,
        'progress_summaries': areProgressSummariesEnabled,
      },
      'integrations': {
        'calendar': isCalendarIntegrationEnabled,
      },
      'data_retention_days': dataRetentionDays,
      'premium_user': isPremiumUser,
    };
  }

  /// Validate settings
  List<String> validateSettings() {
    final issues = <String>[];

    if (customThreshold > -1.0) {
      issues.add('Custom threshold too high (${customThreshold.toStringAsFixed(1)})');
    }

    if (customThreshold < -5.0) {
      issues.add('Custom threshold too low (${customThreshold.toStringAsFixed(1)})');
    }

    if (notificationCooldownMinutes < 15) {
      issues.add('Notification cooldown too short (${notificationCooldownMinutes}m)');
    }

    if (dataRetentionDays < 30) {
      issues.add('Data retention period too short (${dataRetentionDays} days)');
    }

    if (baselineCalculationDays < 7) {
      issues.add('Baseline calculation period too short (${baselineCalculationDays} days)');
    }

    return issues;
  }
}