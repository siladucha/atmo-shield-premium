import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("🍎 iOS AppDelegate запускается...")
        
        // Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)
        
        // Register custom HealthKit writer plugin
        let registrar = self.registrar(forPlugin: "ATMOHealthKitWriter")!
        ATMOHealthKitWriter.register(with: registrar)
        print("✅ ATMOHealthKitWriter plugin registered")
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}


// MARK: - HealthKit Writer Plugin

import Foundation
import HealthKit

/// Native iOS HealthKit writer for synthetic data generation
/// Implements FlutterPlugin protocol for Method Channel communication
class ATMOHealthKitWriter: NSObject, FlutterPlugin {
    
    // MARK: - Properties
    private let healthStore = HKHealthStore()
    private static var methodChannel: FlutterMethodChannel?
    
    // Health data types for writing
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let respiratoryRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
    private let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    
    // MARK: - FlutterPlugin Registration
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "healthkit_generator",
            binaryMessenger: registrar.messenger()
        )
        let instance = ATMOHealthKitWriter()
        registrar.addMethodCallDelegate(instance, channel: channel)
        methodChannel = channel
        
        print("[SynthData] ATMOHealthKitWriter plugin registered")
    }
    
    // MARK: - Method Channel Handler
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestPermissions":
            handleRequestPermissions(call: call, result: result)
            
        case "writeBatch":
            handleWriteBatch(call: call, result: result)
            
        case "isHealthKitAvailable":
            result(HKHealthStore.isHealthDataAvailable())
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Permission Handling
    
    private func handleRequestPermissions(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[SynthData] HealthKit not available on this device")
            result(FlutterError(
                code: "HEALTHKIT_UNAVAILABLE",
                message: "HealthKit is not available on this device",
                details: nil
            ))
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let writeTypes = args["writeTypes"] as? [String] else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing or invalid writeTypes argument",
                details: nil
            ))
            return
        }
        
        requestPermissions(writeTypes: writeTypes) { granted, error in
            if let error = error {
                print("[SynthData] Permission request error: \(error.localizedDescription)")
                result(FlutterError(
                    code: "PERMISSION_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                print("[SynthData] Permissions granted: \(granted)")
                result(granted)
            }
        }
    }
    
    /// Request WRITE permissions for specified HealthKit data types
    private func requestPermissions(
        writeTypes: [String],
        completion: @escaping (Bool, Error?) -> Void
    ) {
        var typesToWrite = Set<HKSampleType>()
        
        for typeString in writeTypes {
            switch typeString {
            case "heartRate":
                typesToWrite.insert(heartRateType)
            case "hrv", "heartRateVariability":
                typesToWrite.insert(hrvType)
            case "respiratoryRate":
                typesToWrite.insert(respiratoryRateType)
            case "steps", "stepCount":
                typesToWrite.insert(stepsType)
            case "sleep", "sleepAnalysis":
                typesToWrite.insert(sleepType)
            default:
                print("[SynthData] Unknown data type: \(typeString)")
            }
        }
        
        guard !typesToWrite.isEmpty else {
            completion(false, NSError(
                domain: "ATMOHealthKitWriter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No valid data types specified"]
            ))
            return
        }
        
        print("[SynthData] Requesting write permissions for: \(writeTypes)")
        
        // Request both READ and WRITE permissions
        // Read permissions are needed if the app wants to read existing health data
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToWrite) { granted, error in
            if let error = error {
                print("[SynthData] Authorization error: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("[SynthData] Authorization granted: \(granted)")
                completion(granted, nil)
            }
        }
    }
    
    // MARK: - Batch Write Handling
    
    private func handleWriteBatch(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let dataType = args["dataType"] as? String,
              let records = args["records"] as? [[String: Any]] else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing or invalid arguments for writeBatch",
                details: nil
            ))
            return
        }
        
        print("[SynthData] Writing batch of \(records.count) \(dataType) records")
        
        writeBatch(dataType: dataType, records: records) { success, error in
            if let error = error {
                print("[SynthData] Batch write error for \(dataType): \(error.localizedDescription)")
                result(FlutterError(
                    code: "WRITE_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                print("[SynthData] Successfully wrote \(records.count) \(dataType) records")
                result(success)
            }
        }
    }
    
    /// Write a batch of health data records to HealthKit
    private func writeBatch(
        dataType: String,
        records: [[String: Any]],
        completion: @escaping (Bool, Error?) -> Void
    ) {
        var samples: [HKSample] = []
        
        for record in records {
            guard let timestamp = record["timestamp"] as? Double,
                  let value = record["value"] as? Double else {
                print("[SynthData] Invalid record format: \(record)")
                continue
            }
            
            let date = Date(timeIntervalSince1970: timestamp / 1000.0)
            
            // Create appropriate sample based on data type
            if let sample = createSample(dataType: dataType, value: value, date: date) {
                samples.append(sample)
            }
        }
        
        guard !samples.isEmpty else {
            completion(false, NSError(
                domain: "ATMOHealthKitWriter",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No valid samples to write"]
            ))
            return
        }
        
        // Batch write to HealthKit
        healthStore.save(samples) { success, error in
            if let error = error {
                print("[SynthData] HealthKit save error: \(error.localizedDescription)")
                completion(false, error)
            } else {
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Sample Creation Helpers
    
    /// Create appropriate HKSample based on data type
    private func createSample(dataType: String, value: Double, date: Date) -> HKSample? {
        switch dataType {
        case "heartRate":
            return createQuantitySample(
                type: heartRateType,
                value: value,
                unit: HKUnit.count().unitDivided(by: .minute()),
                date: date
            )
            
        case "hrv", "heartRateVariability":
            return createQuantitySample(
                type: hrvType,
                value: value,
                unit: HKUnit.secondUnit(with: .milli),
                date: date
            )
            
        case "respiratoryRate":
            return createQuantitySample(
                type: respiratoryRateType,
                value: value,
                unit: HKUnit.count().unitDivided(by: .minute()),
                date: date
            )
            
        case "steps", "stepCount":
            return createQuantitySample(
                type: stepsType,
                value: value,
                unit: HKUnit.count(),
                date: date
            )
            
        case "sleep", "sleepAnalysis":
            // Sleep uses category samples, not quantity samples
            return createCategorySample(value: value, date: date)
            
        default:
            print("[SynthData] Unknown data type for sample creation: \(dataType)")
            return nil
        }
    }
    
    /// Create HKQuantitySample for quantitative health metrics
    private func createQuantitySample(
        type: HKQuantityType,
        value: Double,
        unit: HKUnit,
        date: Date
    ) -> HKQuantitySample? {
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: date,
            end: date,
            metadata: [
                HKMetadataKeyWasUserEntered: false,
                "source": "ATMO HealthKit Generator"
            ]
        )
        
        return sample
    }
    
    /// Create HKCategorySample for sleep analysis
    /// Value represents sleep duration in minutes
    private func createCategorySample(value: Double, date: Date) -> HKCategorySample? {
        // Convert sleep duration (minutes) to start/end dates
        let durationSeconds = value * 60.0
        let endDate = date
        let startDate = endDate.addingTimeInterval(-durationSeconds)
        
        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: startDate,
            end: endDate,
            metadata: [
                HKMetadataKeyWasUserEntered: false,
                "source": "ATMO HealthKit Generator"
            ]
        )
        
        return sample
    }
}
