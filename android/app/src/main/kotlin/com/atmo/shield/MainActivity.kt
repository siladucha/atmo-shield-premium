package com.atmo.shield

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity: FlutterActivity() {
    private companion object {
        const val HEALTH_CHANNEL = "atmo.shield/android_health"
    }
    
    private lateinit var nativeModule: ATMOShieldNative
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize native module
        nativeModule = ATMOShieldNative(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HEALTH_CHANNEL))
        
        // Setup method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HEALTH_CHANNEL).setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
    }
    
    private fun handleMethodCall(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        coroutineScope.launch {
            try {
                when (call.method) {
                    "requestHealthConnectPermissions" -> {
                        val success = nativeModule.requestHealthConnectPermissions()
                        result.success(success)
                    }
                    "requestGoogleFitPermissions" -> {
                        val success = nativeModule.requestGoogleFitPermissions()
                        result.success(success)
                    }
                    "startHealthMonitoring" -> {
                        val success = nativeModule.startHealthMonitoring()
                        result.success(success)
                    }
                    "stopHealthMonitoring" -> {
                        val success = nativeModule.stopHealthMonitoring()
                        result.success(success)
                    }
                    "getHistoricalHRVData" -> {
                        val args = call.arguments as Map<String, Any>
                        val startDate = args["startDate"] as Long
                        val endDate = args["endDate"] as Long
                        val data = nativeModule.getHistoricalHRVData(startDate, endDate)
                        result.success(data)
                    }
                    "getRecentStepCount" -> {
                        val args = call.arguments as Map<String, Any>
                        val periodMinutes = args["periodMinutes"] as Int
                        val steps = nativeModule.getRecentStepCount(periodMinutes)
                        result.success(steps)
                    }
                    "isUserSleeping" -> {
                        val sleeping = nativeModule.isUserSleeping()
                        result.success(sleeping)
                    }
                    "setupWorkManager" -> {
                        val success = nativeModule.setupWorkManager()
                        result.success(success)
                    }
                    "processHRVInBackground" -> {
                        val args = call.arguments as Map<String, Any>
                        val readings = args["readings"] as List<Map<String, Any>>
                        val baseline = args["baseline"] as Map<String, Any>
                        val analysisResult = nativeModule.processHRVInBackground(readings, baseline)
                        result.success(analysisResult)
                    }
                    "scheduleNotification" -> {
                        val args = call.arguments as Map<String, Any>
                        val title = args["title"] as String
                        val body = args["body"] as String
                        val extras = args["extras"] as Map<String, Any>
                        val success = nativeModule.scheduleNotification(title, body, extras)
                        result.success(success)
                    }
                    "saveAnalysisResults" -> {
                        val args = call.arguments as Map<String, Any>
                        val success = nativeModule.saveAnalysisResults(args)
                        result.success(success)
                    }
                    "loadAnalysisResults" -> {
                        val data = nativeModule.loadAnalysisResults()
                        result.success(data)
                    }
                    "clearAnalysisResults" -> {
                        val success = nativeModule.clearAnalysisResults()
                        result.success(success)
                    }
                    "getHealthPlatformAvailability" -> {
                        val availability = nativeModule.getHealthPlatformAvailability()
                        result.success(availability)
                    }
                    "getPermissionStatus" -> {
                        val status = nativeModule.getPermissionStatus()
                        result.success(status)
                    }
                    "getBatteryLevel" -> {
                        val level = nativeModule.getBatteryLevel()
                        result.success(level)
                    }
                    "isPowerSaveModeEnabled" -> {
                        val enabled = nativeModule.isPowerSaveModeEnabled()
                        result.success(enabled)
                    }
                    "isBatteryOptimizationDisabled" -> {
                        val disabled = nativeModule.isBatteryOptimizationDisabled()
                        result.success(disabled)
                    }
                    "getAndroidVersionInfo" -> {
                        val info = nativeModule.getAndroidVersionInfo()
                        result.success(info)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                result.error("NATIVE_ERROR", e.message, e.stackTraceToString())
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        coroutineScope.cancel()
        if (::nativeModule.isInitialized) {
            nativeModule.dispose()
        }
    }
}