package com.atmo.shield

import android.content.Context
import android.content.SharedPreferences
import android.os.BatteryManager
import android.os.PowerManager
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.work.*
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Field
import com.google.android.gms.fitness.request.DataReadRequest
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.util.concurrent.TimeUnit
import kotlin.math.sqrt

class ATMOShieldNative(
    private val context: Context,
    private val methodChannel: MethodChannel
) {
    companion object {
        private const val TAG = "ATMOShieldNative"
        private const val PREFS_NAME = "atmo_shield_prefs"
        private const val ANALYSIS_RESULTS_KEY = "analysis_results"
        private const val ANALYSIS_TIMESTAMP_KEY = "analysis_timestamp"
        private const val WORK_TAG = "atmo_shield_background"
    }

    private val sharedPrefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // Health Connect client (Android 14+)
    private var healthConnectClient: HealthConnectClient? = null
    
    // Google Fit options (Android <14 fallback)
    private val fitnessOptions = FitnessOptions.builder()
        .addDataType(DataType.TYPE_HEART_RATE_BPM, FitnessOptions.ACCESS_READ)
        .addDataType(DataType.AGGREGATE_HEART_RATE_SUMMARY, FitnessOptions.ACCESS_READ)
        .addDataType(DataType.TYPE_STEP_COUNT_DELTA, FitnessOptions.ACCESS_READ)
        .addDataType(DataType.TYPE_SLEEP_SEGMENT, FitnessOptions.ACCESS_READ)
        .build()

    private var isMonitoring = false

    init {
        initializeHealthPlatforms()
    }

    private fun initializeHealthPlatforms() {
        try {
            // Initialize Health Connect if available (Android 14+)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                if (HealthConnectClient.isProviderAvailable(context)) {
                    healthConnectClient = HealthConnectClient.getOrCreate(context)
                    Log.d(TAG, "Health Connect initialized")
                }
            }
            
            Log.d(TAG, "Health platforms initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing health platforms", e)
        }
    }

    // MARK: - Permission Management

    suspend fun requestHealthConnectPermissions(): Boolean {
        return try {
            healthConnectClient?.let { client ->
                val permissions = setOf(
                    HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
                    HealthPermission.getReadPermission(HeartRateRecord::class),
                    HealthPermission.getReadPermission(RestingHeartRateRecord::class),
                    HealthPermission.getReadPermission(StepsRecord::class),
                    HealthPermission.getReadPermission(SleepSessionRecord::class)
                )
                
                val granted = client.permissionController.getGrantedPermissions()
                permissions.all { it in granted }
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting Health Connect permissions", e)
            false
        }
    }

    fun requestGoogleFitPermissions(): Boolean {
        return try {
            val account = GoogleSignIn.getLastSignedInAccount(context)
            account != null && GoogleSignIn.hasPermissions(account, fitnessOptions)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Google Fit permissions", e)
            false
        }
    }

    // MARK: - Health Monitoring

    suspend fun startHealthMonitoring(): Boolean {
        if (isMonitoring) return true
        
        return try {
            val success = if (healthConnectClient != null) {
                startHealthConnectMonitoring()
            } else {
                startGoogleFitMonitoring()
            }
            
            if (success) {
                setupWorkManager()
                isMonitoring = true
                Log.d(TAG, "Health monitoring started")
            }
            
            success
        } catch (e: Exception) {
            Log.e(TAG, "Error starting health monitoring", e)
            false
        }
    }

    suspend fun stopHealthMonitoring(): Boolean {
        return try {
            WorkManager.getInstance(context).cancelAllWorkByTag(WORK_TAG)
            isMonitoring = false
            Log.d(TAG, "Health monitoring stopped")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping health monitoring", e)
            false
        }
    }

    private suspend fun startHealthConnectMonitoring(): Boolean {
        return try {
            healthConnectClient?.let { client ->
                // Health Connect doesn't have real-time monitoring like HealthKit
                // We'll use WorkManager to periodically check for new data
                true
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Health Connect monitoring", e)
            false
        }
    }

    private fun startGoogleFitMonitoring(): Boolean {
        return try {
            val account = GoogleSignIn.getLastSignedInAccount(context)
            account != null && GoogleSignIn.hasPermissions(account, fitnessOptions)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting Google Fit monitoring", e)
            false
        }
    }

    // MARK: - Data Retrieval

    suspend fun getHistoricalHRVData(startDate: Long, endDate: Long): List<Map<String, Any>> {
        return try {
            if (healthConnectClient != null) {
                getHealthConnectHRVData(startDate, endDate)
            } else {
                getGoogleFitHRVData(startDate, endDate)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting historical HRV data", e)
            emptyList()
        }
    }

    private suspend fun getHealthConnectHRVData(startDate: Long, endDate: Long): List<Map<String, Any>> {
        return try {
            healthConnectClient?.let { client ->
                val request = ReadRecordsRequest(
                    recordType = HeartRateVariabilityRmssdRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startDate),
                        Instant.ofEpochMilli(endDate)
                    )
                )
                
                val response = client.readRecords(request)
                response.records.map { record ->
                    mapOf(
                        "timestamp" to record.time.toEpochMilli(),
                        "value" to record.heartRateVariabilityMillis,
                        "source" to "health_connect",
                        "platform" to "android",
                        "sampleCount" to 1,
                        "confidence" to calculateDataConfidence(record),
                        "normalized" to false,
                        "metadata" to mapOf(
                            "source_id" to (record.metadata.dataOrigin.packageName ?: "unknown"),
                            "unit" to "ms"
                        )
                    )
                }
            } ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting Health Connect HRV data", e)
            emptyList()
        }
    }

    private suspend fun getGoogleFitHRVData(startDate: Long, endDate: Long): List<Map<String, Any>> {
        return try {
            val account = GoogleSignIn.getLastSignedInAccount(context) ?: return emptyList()
            
            // Google Fit doesn't have direct HRV support, we'd need to derive from heart rate
            // This is a simplified implementation - in practice, you'd need more sophisticated processing
            val readRequest = DataReadRequest.Builder()
                .aggregate(DataType.TYPE_HEART_RATE_BPM)
                .setTimeRange(startDate, endDate, TimeUnit.MILLISECONDS)
                .bucketByTime(1, TimeUnit.HOURS)
                .build()
            
            val response = Fitness.getHistoryClient(context, account).readData(readRequest).await()
            
            response.buckets.mapNotNull { bucket ->
                bucket.dataSets.firstOrNull()?.dataPoints?.firstOrNull()?.let { dataPoint ->
                    val heartRate = dataPoint.getValue(Field.FIELD_AVERAGE).asFloat()
                    // Simplified HRV estimation - this would need proper calculation
                    val estimatedHRV = estimateHRVFromHeartRate(heartRate)
                    
                    mapOf(
                        "timestamp" to dataPoint.getTimestamp(TimeUnit.MILLISECONDS),
                        "value" to estimatedHRV,
                        "source" to "google_fit",
                        "platform" to "android",
                        "sampleCount" to 1,
                        "confidence" to 0.7, // Lower confidence for estimated data
                        "normalized" to false,
                        "metadata" to mapOf(
                            "source_id" to "google_fit",
                            "unit" to "ms",
                            "estimated" to true
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting Google Fit HRV data", e)
            emptyList()
        }
    }

    suspend fun getRecentStepCount(periodMinutes: Int): Int {
        return try {
            val endTime = System.currentTimeMillis()
            val startTime = endTime - (periodMinutes * 60 * 1000)
            
            if (healthConnectClient != null) {
                getHealthConnectStepCount(startTime, endTime)
            } else {
                getGoogleFitStepCount(startTime, endTime)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting step count", e)
            0
        }
    }

    private suspend fun getHealthConnectStepCount(startTime: Long, endTime: Long): Int {
        return try {
            healthConnectClient?.let { client ->
                val request = ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startTime),
                        Instant.ofEpochMilli(endTime)
                    )
                )
                
                val response = client.readRecords(request)
                response.records.sumOf { it.count.toInt() }
            } ?: 0
        } catch (e: Exception) {
            Log.e(TAG, "Error getting Health Connect step count", e)
            0
        }
    }

    private suspend fun getGoogleFitStepCount(startTime: Long, endTime: Long): Int {
        return try {
            val account = GoogleSignIn.getLastSignedInAccount(context) ?: return 0
            
            val readRequest = DataReadRequest.Builder()
                .aggregate(DataType.TYPE_STEP_COUNT_DELTA)
                .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
                .build()
            
            val response = Fitness.getHistoryClient(context, account).readData(readRequest).await()
            
            response.buckets.sumOf { bucket ->
                bucket.dataSets.sumOf { dataSet ->
                    dataSet.dataPoints.sumOf { dataPoint ->
                        dataPoint.getValue(Field.FIELD_STEPS).asInt()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting Google Fit step count", e)
            0
        }
    }

    suspend fun isUserSleeping(): Boolean {
        return try {
            val now = System.currentTimeMillis()
            val oneHourAgo = now - (60 * 60 * 1000)
            
            if (healthConnectClient != null) {
                isUserSleepingHealthConnect(oneHourAgo, now)
            } else {
                isUserSleepingGoogleFit(oneHourAgo, now)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking sleep status", e)
            false
        }
    }

    private suspend fun isUserSleepingHealthConnect(startTime: Long, endTime: Long): Boolean {
        return try {
            healthConnectClient?.let { client ->
                val request = ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startTime),
                        Instant.ofEpochMilli(endTime)
                    )
                )
                
                val response = client.readRecords(request)
                response.records.any { session ->
                    val now = Instant.ofEpochMilli(System.currentTimeMillis())
                    session.startTime <= now && session.endTime >= now
                }
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Health Connect sleep status", e)
            false
        }
    }

    private suspend fun isUserSleepingGoogleFit(startTime: Long, endTime: Long): Boolean {
        return try {
            val account = GoogleSignIn.getLastSignedInAccount(context) ?: return false
            
            val readRequest = DataReadRequest.Builder()
                .read(DataType.TYPE_SLEEP_SEGMENT)
                .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
                .build()
            
            val response = Fitness.getHistoryClient(context, account).readData(readRequest).await()
            
            response.dataSets.any { dataSet ->
                dataSet.dataPoints.any { dataPoint ->
                    val now = System.currentTimeMillis()
                    dataPoint.getStartTime(TimeUnit.MILLISECONDS) <= now &&
                    dataPoint.getEndTime(TimeUnit.MILLISECONDS) >= now
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking Google Fit sleep status", e)
            false
        }
    }

    // MARK: - Background Processing

    fun setupWorkManager(): Boolean {
        return try {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .setRequiresBatteryNotLow(false)
                .build()

            val workRequest = PeriodicWorkRequestBuilder<HRVAnalysisWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .addTag(WORK_TAG)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "atmo_shield_analysis",
                ExistingPeriodicWorkPolicy.REPLACE,
                workRequest
            )

            Log.d(TAG, "WorkManager setup completed")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up WorkManager", e)
            false
        }
    }

    suspend fun processHRVInBackground(readings: List<Map<String, Any>>, baseline: Map<String, Any>): Map<String, Any>? {
        return try {
            performHRVAnalysis(readings, baseline)
        } catch (e: Exception) {
            Log.e(TAG, "Error processing HRV in background", e)
            null
        }
    }

    private fun performHRVAnalysis(readings: List<Map<String, Any>>, baseline: Map<String, Any>): Map<String, Any>? {
        try {
            val baselineMean = baseline["mean"] as? Double ?: return null
            val baselineStd = baseline["std"] as? Double ?: return null
            
            if (baselineStd <= 0 || readings.isEmpty()) return null
            
            val latestReading = readings.first()
            val hrvValue = latestReading["value"] as? Double ?: return null
            
            // Calculate Z-score
            val zScore = (hrvValue - baselineMean) / baselineStd
            
            // Determine severity
            val severity = when {
                zScore <= -3.0 -> "critical"
                zScore <= -2.5 -> "high"
                zScore <= -2.0 -> "medium"
                zScore <= -1.8 -> "low"
                else -> "normal"
            }
            
            return mapOf(
                "z_score" to zScore,
                "severity" to severity,
                "hrv_value" to hrvValue,
                "baseline_mean" to baselineMean,
                "baseline_std" to baselineStd,
                "timestamp" to (latestReading["timestamp"] ?: 0),
                "analysis_time" to System.currentTimeMillis()
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error in HRV analysis", e)
            return null
        }
    }

    // MARK: - Notifications

    fun scheduleNotification(title: String, body: String, extras: Map<String, Any>): Boolean {
        return try {
            // This would integrate with Android's notification system
            // Implementation would depend on your notification service
            Log.d(TAG, "Scheduling notification: $title")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling notification", e)
            false
        }
    }

    // MARK: - Data Persistence

    fun saveAnalysisResults(results: Map<String, Any>): Boolean {
        return try {
            val json = JSONObject(results).toString()
            sharedPrefs.edit()
                .putString(ANALYSIS_RESULTS_KEY, json)
                .putLong(ANALYSIS_TIMESTAMP_KEY, System.currentTimeMillis())
                .apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error saving analysis results", e)
            false
        }
    }

    fun loadAnalysisResults(): Map<String, Any>? {
        return try {
            val json = sharedPrefs.getString(ANALYSIS_RESULTS_KEY, null) ?: return null
            val jsonObject = JSONObject(json)
            jsonObject.keys().asSequence().associateWith { key ->
                jsonObject.get(key)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading analysis results", e)
            null
        }
    }

    fun clearAnalysisResults(): Boolean {
        return try {
            sharedPrefs.edit()
                .remove(ANALYSIS_RESULTS_KEY)
                .remove(ANALYSIS_TIMESTAMP_KEY)
                .apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing analysis results", e)
            false
        }
    }

    // MARK: - System Information

    fun getHealthPlatformAvailability(): Map<String, Boolean> {
        return mapOf(
            "health_connect" to (healthConnectClient != null),
            "google_fit" to (GoogleSignIn.getLastSignedInAccount(context) != null)
        )
    }

    fun getPermissionStatus(): Map<String, String> {
        return try {
            val status = mutableMapOf<String, String>()
            
            if (healthConnectClient != null) {
                status["health_connect"] = "available"
            } else {
                status["health_connect"] = "unavailable"
            }
            
            val account = GoogleSignIn.getLastSignedInAccount(context)
            status["google_fit"] = if (account != null && GoogleSignIn.hasPermissions(account, fitnessOptions)) {
                "granted"
            } else {
                "denied"
            }
            
            status
        } catch (e: Exception) {
            Log.e(TAG, "Error getting permission status", e)
            emptyMap()
        }
    }

    fun getBatteryLevel(): Double {
        return try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            level / 100.0
        } catch (e: Exception) {
            Log.e(TAG, "Error getting battery level", e)
            1.0
        }
    }

    fun isPowerSaveModeEnabled(): Boolean {
        return try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isPowerSaveMode
        } catch (e: Exception) {
            Log.e(TAG, "Error checking power save mode", e)
            false
        }
    }

    fun isBatteryOptimizationDisabled(): Boolean {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                powerManager.isIgnoringBatteryOptimizations(context.packageName)
            } else {
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking battery optimization", e)
            false
        }
    }

    fun getAndroidVersionInfo(): Map<String, Any> {
        return mapOf(
            "sdk_int" to android.os.Build.VERSION.SDK_INT,
            "release" to android.os.Build.VERSION.RELEASE,
            "supports_health_connect" to (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
        )
    }

    // MARK: - Helper Methods

    private fun calculateDataConfidence(record: Any): Double {
        var confidence = 1.0
        
        // Reduce confidence for old data
        // This would need to be implemented based on the specific record type
        
        return maxOf(0.0, minOf(1.0, confidence))
    }

    private fun estimateHRVFromHeartRate(heartRate: Float): Double {
        // This is a very simplified estimation
        // In practice, you'd need proper HRV calculation from R-R intervals
        return when {
            heartRate < 60 -> 45.0 + (60 - heartRate) * 0.5
            heartRate > 100 -> maxOf(15.0, 45.0 - (heartRate - 100) * 0.3)
            else -> 45.0 - (heartRate - 60) * 0.2
        }
    }

    fun dispose() {
        coroutineScope.cancel()
    }
}

// WorkManager worker for background HRV analysis
class HRVAnalysisWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            Log.d("HRVAnalysisWorker", "Starting background HRV analysis")
            
            // This would perform the actual background analysis
            // For now, just log that the worker ran
            
            Log.d("HRVAnalysisWorker", "Background HRV analysis completed")
            Result.success()
        } catch (e: Exception) {
            Log.e("HRVAnalysisWorker", "Error in background analysis", e)
            Result.retry()
        }
    }
}