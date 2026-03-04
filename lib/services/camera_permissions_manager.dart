import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';

/// Manages Camera permissions with local caching
/// 
/// iOS Camera permissions work differently - once granted, they persist.
/// We cache the status locally to avoid repeated checks.
class CameraPermissionsManager {
  // Singleton pattern
  static final CameraPermissionsManager _instance = CameraPermissionsManager._internal();
  factory CameraPermissionsManager() => _instance;
  CameraPermissionsManager._internal();

  static const String _cacheKey = 'camera_permission_granted';
  bool? _cachedPermission;

  /// Request camera permission
  /// This will trigger the system permission dialog
  Future<bool> requestPermission() async {
    try {
      debugPrint('📷 [CameraPermissionsManager] Requesting camera permission...');

      // Try to get available cameras - this triggers permission request
      final cameras = await availableCameras();
      
      if (cameras.isNotEmpty) {
        // Permission granted
        await _savePermissionToCache(true);
        debugPrint('📷 [CameraPermissionsManager] ✅ Camera permission granted');
        return true;
      } else {
        // No cameras available (shouldn't happen on real device)
        debugPrint('📷 [CameraPermissionsManager] ⚠️ No cameras available');
        return false;
      }
    } catch (e) {
      // Permission denied or error
      debugPrint('📷 [CameraPermissionsManager] ❌ Permission denied or error: $e');
      await _savePermissionToCache(false);
      return false;
    }
  }

  /// Check if camera permission is granted (uses cache)
  Future<bool> hasPermission() async {
    try {
      // Load from cache first
      await _loadPermissionFromCache();
      
      if (_cachedPermission == true) {
        debugPrint('📷 [CameraPermissionsManager] ✅ Has cached permission');
        return true;
      }

      // Try to check actual permission by attempting to get cameras
      try {
        final cameras = await availableCameras();
        final hasPermission = cameras.isNotEmpty;
        
        if (hasPermission) {
          await _savePermissionToCache(true);
        }
        
        debugPrint('📷 [CameraPermissionsManager] Permission status: $hasPermission');
        return hasPermission;
      } catch (e) {
        // Permission not granted
        debugPrint('📷 [CameraPermissionsManager] No permission: $e');
        return false;
      }
    } catch (e) {
      debugPrint('📷 [CameraPermissionsManager] ❌ Permission check error: $e');
      return false;
    }
  }

  /// Save permission status to cache
  Future<void> _savePermissionToCache(bool granted) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cacheKey, granted);
      _cachedPermission = granted;
      debugPrint('📷 [CameraPermissionsManager] Permission cached: $granted');
    } catch (e) {
      debugPrint('📷 [CameraPermissionsManager] ❌ Cache save error: $e');
    }
  }

  /// Load permission status from cache
  Future<void> _loadPermissionFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedPermission = prefs.getBool(_cacheKey);
      
      if (_cachedPermission != null) {
        debugPrint('📷 [CameraPermissionsManager] Loaded cached permission: $_cachedPermission');
      }
    } catch (e) {
      debugPrint('📷 [CameraPermissionsManager] ❌ Cache load error: $e');
    }
  }

  /// Clear cached permission (for testing)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      _cachedPermission = null;
      debugPrint('📷 [CameraPermissionsManager] Cache cleared');
    } catch (e) {
      debugPrint('📷 [CameraPermissionsManager] ❌ Cache clear error: $e');
    }
  }

  /// Check if camera is available on device
  Future<bool> isCameraAvailable() async {
    try {
      final cameras = await availableCameras();
      final hasBackCamera = cameras.any(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      
      debugPrint('📷 [CameraPermissionsManager] Back camera available: $hasBackCamera');
      return hasBackCamera;
    } catch (e) {
      debugPrint('📷 [CameraPermissionsManager] ❌ Camera check error: $e');
      return false;
    }
  }
}
