import Foundation
import HealthKit
import UserNotifications
import UIKit
import Flutter

@objc class ATMOShieldNative: NSObject {
    
    // MARK: - Properties
    private let healthStore = HKHealthStore()
    private let methodChannel: FlutterMethodChannel
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var hrvObserverQuery: HKObserverQuery?
    private var isMonitoring = false
    
    // Background processing
    private let backgroundQueue = DispatchQueue(label: "com.atmo.shield.background", qos: .utility)
    private let userDefaults = UserDefaults.standard
    
    // Health data types
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    private let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    
    // MARK: - Initialization
    init(methodChannel: FlutterMethodChannel) {
        self.methodChannel = methodChannel
        super.init()
        setupBackgroundTaskHandling()
    }
    
    // MARK: - Public Methods
    
    @objc func requestHealthKitPermissions() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [
            hrvType,
            restingHRType,
            stepsType,
            sleepType
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            // We might write wellness analysis results
        ]
        
        var success = false
        let semaphore = DispatchSemaphore(value: 0)
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { (granted, error) in
            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
            }
            success = granted
            semaphore.signal()
        }
        
        semaphore.wait()
        return success
    }
    
    @objc func startHealthKitMonitoring() -> Bool {
        guard !isMonitoring else { return true }
        
        do {
            try setupHRVObserverQuery()
            try enableBackgroundDelivery()
            isMonitoring = true
            print("HealthKit monitoring started successfully")
            return true
        } catch {
            print("Failed to start HealthKit monitoring: \(error)")
            return false
        }
    }
    
    @objc func stopHealthKitMonitoring() -> Bool {
        guard isMonitoring else { return true }
        
        if let query = hrvObserverQuery {
            healthStore.stop(query)
            hrvObserverQuery = nil
        }
        
        disableBackgroundDelivery()
        isMonitoring = false
        print("HealthKit monitoring stopped")
        return true
    }
    
    @objc func getHistoricalHRVData(startDate: Date, endDate: Date) -> [[String: Any]] {
        var results: [[String: Any]] = []
        let semaphore = DispatchSemaphore(value: 0)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            
            if let error = error {
                print("Error fetching HRV data: \(error.localizedDescription)")
                semaphore.signal()
                return
            }
            
            guard let samples = samples as? [HKQuantitySample] else {
                semaphore.signal()
                return
            }
            
            for sample in samples {
                let hrvValue = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                let confidence = self.calculateDataConfidence(for: sample)
                
                let hrvData: [String: Any] = [
                    "timestamp": Int(sample.startDate.timeIntervalSince1970 * 1000),
                    "value": hrvValue,
                    "source": "healthkit",
                    "platform": "ios",
                    "sampleCount": 1,
                    "confidence": confidence,
                    "normalized": false,
                    "metadata": [
                        "source_id": sample.sourceRevision.source.bundleIdentifier,
                        "source_name": sample.sourceRevision.source.name,
                        "unit": "ms"
                    ]
                ]
                results.append(hrvData)
            }
            
            semaphore.signal()
        }
        
        healthStore.execute(query)
        semaphore.wait()
        
        return results
    }
    
    @objc func getRecentStepCount(periodMinutes: Int) -> Int {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-TimeInterval(periodMinutes * 60))
        
        var totalSteps = 0
        let semaphore = DispatchSemaphore(value: 0)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { (query, statistics, error) in
            
            if let sum = statistics?.sumQuantity() {
                totalSteps = Int(sum.doubleValue(for: HKUnit.count()))
            }
            
            semaphore.signal()
        }
        
        healthStore.execute(query)
        semaphore.wait()
        
        return totalSteps
    }
    
    @objc func isUserSleeping() -> Bool {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        
        var isSleeping = false
        let semaphore = DispatchSemaphore(value: 0)
        
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 1, sortDescriptors: nil) { (query, samples, error) in
            
            if let samples = samples as? [HKCategorySample], !samples.isEmpty {
                let sample = samples[0]
                isSleeping = sample.startDate <= now && sample.endDate >= now
            }
            
            semaphore.signal()
        }
        
        healthStore.execute(query)
        semaphore.wait()
        
        return isSleeping
    }
    
    @objc func processHRVInBackground(readings: [[String: Any]], baseline: [String: Any]) -> [String: Any]? {
        return backgroundQueue.sync {
            return performHRVAnalysis(readings: readings, baseline: baseline)
        }
    }
    
    @objc func saveAnalysisResults(_ results: [String: Any]) -> Bool {
        do {
            let data = try JSONSerialization.data(withJSONObject: results, options: [])
            userDefaults.set(data, forKey: "atmo_shield_analysis_results")
            userDefaults.set(Date(), forKey: "atmo_shield_analysis_timestamp")
            return true
        } catch {
            print("Error saving analysis results: \(error)")
            return false
        }
    }
    
    @objc func loadAnalysisResults() -> [String: Any]? {
        guard let data = userDefaults.data(forKey: "atmo_shield_analysis_results") else {
            return nil
        }
        
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            print("Error loading analysis results: \(error)")
            return nil
        }
    }
    
    @objc func scheduleNotification(title: String, body: String, userInfo: [String: Any]) -> Bool {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = userInfo
        content.sound = .default
        
        // Add action buttons for stress alerts
        if userInfo["type"] as? String == "stress_alert" {
            let startAction = UNNotificationAction(identifier: "start_protocol", title: "Start Protocol", options: [])
            let remindAction = UNNotificationAction(identifier: "remind_later", title: "Remind Later", options: [])
            
            let category = UNNotificationCategory(identifier: "stress_alert", actions: [startAction, remindAction], intentIdentifiers: [], options: [])
            UNUserNotificationCenter.current().setNotificationCategories([category])
            content.categoryIdentifier = "stress_alert"
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        var success = false
        let semaphore = DispatchSemaphore(value: 0)
        
        UNUserNotificationCenter.current().add(request) { error in
            success = (error == nil)
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return success
    }
    
    @objc func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    @objc func isLowPowerModeEnabled() -> Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    // MARK: - Private Methods
    
    private func setupHRVObserverQuery() throws {
        hrvObserverQuery = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] (query, completionHandler, error) in
            
            if let error = error {
                print("HRV Observer Query error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            self?.handleNewHRVData()
            completionHandler()
        }
        
        guard let query = hrvObserverQuery else {
            throw NSError(domain: "ATMOShield", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create observer query"])
        }
        
        healthStore.execute(query)
    }
    
    private func enableBackgroundDelivery() throws {
        healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { (success, error) in
            if let error = error {
                print("Background delivery error: \(error.localizedDescription)")
            } else if success {
                print("Background delivery enabled for HRV")
            }
        }
    }
    
    private func disableBackgroundDelivery() {
        healthStore.disableBackgroundDelivery(for: hrvType) { (success, error) in
            if let error = error {
                print("Error disabling background delivery: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleNewHRVData() {
        startBackgroundTask()
        
        backgroundQueue.async { [weak self] in
            self?.fetchAndProcessRecentHRV()
            self?.endBackgroundTask()
        }
    }
    
    private func fetchAndProcessRecentHRV() {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-3600) // Last hour
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            
            guard let self = self, let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                return
            }
            
            // Process the most recent sample
            let latestSample = samples[0]
            let hrvValue = latestSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            let confidence = self.calculateDataConfidence(for: latestSample)
            
            let hrvData: [String: Any] = [
                "timestamp": Int(latestSample.startDate.timeIntervalSince1970 * 1000),
                "value": hrvValue,
                "source": "healthkit",
                "platform": "ios",
                "sampleCount": 1,
                "confidence": confidence,
                "normalized": false,
                "metadata": [
                    "source_id": latestSample.sourceRevision.source.bundleIdentifier,
                    "source_name": latestSample.sourceRevision.source.name,
                    "unit": "ms"
                ]
            ]
            
            // Send to Flutter
            DispatchQueue.main.async {
                self.methodChannel.invokeMethod("onHRVDataReceived", arguments: hrvData)
            }
            
            // Perform background analysis if we have baseline data
            if let baseline = self.loadAnalysisResults()?["baseline"] as? [String: Any] {
                let analysisResult = self.performHRVAnalysis(readings: [hrvData], baseline: baseline)
                
                if let result = analysisResult, let zScore = result["z_score"] as? Double, zScore <= -1.8 {
                    // Stress detected - schedule notification
                    self.handleStressDetection(zScore: zScore, hrvData: hrvData)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func performHRVAnalysis(readings: [[String: Any]], baseline: [String: Any]) -> [String: Any]? {
        guard let baselineMean = baseline["mean"] as? Double,
              let baselineStd = baseline["std"] as? Double,
              baselineStd > 0,
              let latestReading = readings.first,
              let hrvValue = latestReading["value"] as? Double else {
            return nil
        }
        
        // Calculate Z-score
        let zScore = (hrvValue - baselineMean) / baselineStd
        
        // Determine severity
        let severity: String
        if zScore <= -3.0 {
            severity = "critical"
        } else if zScore <= -2.5 {
            severity = "high"
        } else if zScore <= -2.0 {
            severity = "medium"
        } else if zScore <= -1.8 {
            severity = "low"
        } else {
            severity = "normal"
        }
        
        return [
            "z_score": zScore,
            "severity": severity,
            "hrv_value": hrvValue,
            "baseline_mean": baselineMean,
            "baseline_std": baselineStd,
            "timestamp": latestReading["timestamp"] ?? 0,
            "analysis_time": Int(Date().timeIntervalSince1970 * 1000)
        ]
    }
    
    private func handleStressDetection(zScore: Double, hrvData: [String: Any]) {
        let severity = getSeverityFromZScore(zScore)
        let protocol = getRecommendedProtocol(for: zScore)
        
        let notificationTitle = "🛡️ NeuroYoga Stress Alert - \(severity.capitalized)"
        let notificationBody = "Your HRV shows stress patterns (Z-score: \(String(format: "%.1f", zScore))). Recommended: \(protocol)"
        
        let userInfo: [String: Any] = [
            "type": "stress_alert",
            "z_score": zScore,
            "severity": severity,
            "protocol": protocol,
            "hrv_value": hrvData["value"] ?? 0,
            "timestamp": hrvData["timestamp"] ?? 0
        ]
        
        _ = scheduleNotification(title: notificationTitle, body: notificationBody, userInfo: userInfo)
        
        // Notify Flutter
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel.invokeMethod("onStressDetected", arguments: userInfo)
        }
    }
    
    private func getSeverityFromZScore(_ zScore: Double) -> String {
        if zScore <= -3.0 { return "critical" }
        if zScore <= -2.5 { return "high" }
        if zScore <= -2.0 { return "medium" }
        if zScore <= -1.8 { return "low" }
        return "normal"
    }
    
    private func getRecommendedProtocol(for zScore: Double) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if zScore <= -3.0 {
            return hour >= 23 || hour < 5 ? "Before Sleep (4-0-10)" : "Physiological Sigh"
        } else if zScore <= -2.5 {
            return hour >= 17 ? "Huberman Classic (4-7-8)" : "Deep Calming (4-0-8)"
        } else if zScore <= -2.0 {
            return hour >= 17 ? "Deep Calming (4-0-8)" : "Light Calming (4-0-6)"
        } else {
            return hour >= 5 && hour < 11 ? "Energizing (5-0-4)" : "Coherent 5-5"
        }
    }
    
    private func calculateDataConfidence(for sample: HKQuantitySample) -> Double {
        var confidence = 1.0
        
        // Reduce confidence for old data
        let age = Date().timeIntervalSince(sample.startDate)
        if age > 86400 { // > 24 hours
            confidence *= 0.9
        } else if age > 172800 { // > 48 hours
            confidence *= 0.8
        }
        
        // Adjust based on source
        let sourceName = sample.sourceRevision.source.name.lowercased()
        if sourceName.contains("apple watch") {
            confidence *= 1.0 // High quality
        } else if sourceName.contains("iphone") {
            confidence *= 0.8 // Lower quality
        } else if sourceName.contains("manual") {
            confidence *= 0.7 // Manual entry
        }
        
        return max(0.0, min(1.0, confidence))
    }
    
    // MARK: - Background Task Management
    
    private func setupBackgroundTaskHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        startBackgroundTask()
    }
    
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ATMOShieldAnalysis") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }
}