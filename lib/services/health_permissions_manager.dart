import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../native/healthkit_bridge.dart';

/// Manages HealthKit permissions with local caching
/// 
/// iOS HealthKit has privacy protection where hasPermissions() always returns false.
/// Solution: Cache permission status locally after successful grant.
class HealthPermissionsManager {
  // Singleton pattern
  static final HealthPermissionsManager _instance = HealthPermissionsManager._internal();
  factory HealthPermissionsManager() => _instance;
  HealthPermissionsManager._internal();

  final HealthKitBridge _healthKitBridge = HealthKitBridge();
  Map<String, bool> _cachedPermissions = {};

  /// Data types we need to READ
  static const List<String> _readTypes = [
    'heartRate',
    'hrv',
    'respiratoryRate',
    'steps',
    'sleep',
  ];

  /// Data types we need to WRITE (same as read for generator)
  static const List<String> _writeTypes = [
    'heartRate',
    'hrv',
    'respiratoryRate',
    'steps',
    'sleep',
  ];

  /// Request all permissions (read + write)
  Future<bool> requestAllPermissions() async {
    try {
      debugPrint('🏥 [HealthPermissionsManager] Requesting permissions...');

      // Check if HealthKit is available
      final isAvailable = await _healthKitBridge.isHealthKitAvailable();
      if (!isAvailable) {
        debugPrint('🏥 [HealthPermissionsManager] ❌ HealthKit not available');
        return false;
      }

      // Request permissions (iOS will show dialog)
      final granted = await _healthKitBridge.requestPermissions(_writeTypes);

      if (granted) {
        // Save to cache
        await _savePermissionsToCache();
        debugPrint('🏥 [HealthPermissionsManager] ✅ All permissions granted');
        return true;
      }

      debugPrint('🏥 [HealthPermissionsManager] ❌ Permissions denied');
      return false;
    } catch (e) {
      debugPrint('🏥 [HealthPermissionsManager] ❌ Error: $e');
      return false;
    }
  }

  /// Save permissions to local cache
  Future<void> _savePermissionsToCache() async {
    final permissions = <String, bool>{};
    
    for (final type in _writeTypes) {
      permissions[type] = true;
    }

    final prefs = await SharedPreferences.getInstance();
    final encoded = permissions.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');
    
    await prefs.setString('health_permissions_cache', encoded);
    _cachedPermissions = permissions;
    
    debugPrint('🏥 [HealthPermissionsManager] ✅ Permissions cached: ${permissions.keys.join(", ")}');
  }

  /// Load permissions from cache
  Future<void> _loadPermissionsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('health_permissions_cache');
      
      if (encoded != null && encoded.isNotEmpty) {
        _cachedPermissions = {};
        for (final entry in encoded.split(',')) {
          final parts = entry.split(':');
          if (parts.length == 2) {
            _cachedPermissions[parts[0]] = parts[1] == 'true';
          }
        }
        debugPrint('🏥 [HealthPermissionsManager] Loaded ${_cachedPermissions.length} cached permissions');
      }
    } catch (e) {
      debugPrint('🏥 [HealthPermissionsManager] ❌ Cache load error: $e');
    }
  }

  /// Check if has permissions (uses cache)
  Future<bool> hasPermissions() async {
    try {
      await _loadPermissionsFromCache();
      
      // Trust cached permissions (iOS privacy protection)
      final hasMinimum = hasMinimumPermissions;
      debugPrint('🏥 [HealthPermissionsManager] Has minimum permissions: $hasMinimum');
      
      return hasMinimum;
    } catch (e) {
      debugPrint('🏥 [HealthPermissionsManager] ❌ Permission check error: $e');
      return false;
    }
  }

  /// Clear cached permissions
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('health_permissions_cache');
    _cachedPermissions = {};
    debugPrint('🏥 [HealthPermissionsManager] Cache cleared');
  }

  // Individual permission checks
  bool get hasHRVPermission => _cachedPermissions['hrv'] ?? false;
  bool get hasHeartRatePermission => _cachedPermissions['heartRate'] ?? false;
  bool get hasRespiratoryRatePermission => _cachedPermissions['respiratoryRate'] ?? false;
  bool get hasStepsPermission => _cachedPermissions['steps'] ?? false;
  bool get hasSleepPermission => _cachedPermissions['sleep'] ?? false;

  // Grouped permission checks
  bool get hasCorePermissions => hasHRVPermission && hasHeartRatePermission;
  bool get hasMinimumPermissions => hasHRVPermission || hasHeartRatePermission;
  bool get hasAllPermissions => 
      hasHRVPermission && 
      hasHeartRatePermission && 
      hasRespiratoryRatePermission && 
      hasStepsPermission && 
      hasSleepPermission;
}
