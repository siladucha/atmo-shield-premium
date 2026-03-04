# Implementation Plan: HealthKit Data Generator

## Overview

This plan implements a standalone Flutter iOS app that generates one year of synthetic HealthKit data for testing ATMO Shield. The implementation follows a three-screen UI flow (Generation → Progress → Results) with realistic data patterns including trends, variations, and stress events. All data is written directly to HealthKit using native iOS bridges.

## Tasks

- [x] 1. Set up project structure and dependencies
  - Create new Flutter project with iOS target (minimum iOS 16.0)
  - Add `health` package to pubspec.yaml for HealthKit integration
  - Configure Info.plist with HealthKit permissions (NSHealthShareUsageDescription, NSHealthUpdateUsageDescription)
  - Set up Method Channel for native iOS communication
  - Create directory structure: lib/models/, lib/services/, lib/screens/, lib/utils/, lib/native/
  - _Requirements: 12.1, 12.2, 12.5_

- [ ] 2. Implement statistical utilities and data models
  - [x] 2.1 Create GaussianDistribution utility class
    - Implement Box-Muller transform for normal distribution sampling
    - Add clamp method for value range constraints
    - _Requirements: 3.9, 4.6, 6.5_
  
  - [ ]* 2.2 Write property test for Gaussian distribution
    - **Property 23: Gaussian Distribution Statistical Properties**
    - **Validates: Requirements 3.9, 4.6, 6.5**
  
  - [x] 2.3 Create TrendCalculator utility class
    - Implement linear trend calculation with configurable duration and percentage
    - Add noise injection for realistic variations
    - _Requirements: 2.6, 3.6, 4.4, 6.1_
  
  - [x] 2.4 Create ProbabilityDistribution utility class
    - Implement weighted random selection for discrete distributions
    - Support HRV daily record count distribution (35% zero, 45% 1-2, 20% 3-5)
    - _Requirements: 3.2_
  
  - [x] 2.5 Create HealthDataPoint model
    - Define properties: type, value, timestamp, unit
    - Implement validation for value ranges by type
    - Add toMap() method for Method Channel serialization
    - _Requirements: 7.2_
  
  - [x] 2.6 Create GenerationConfig model
    - Define properties: includeSteps, includeSleep, targetHRRecords, hrvTrendGrowth, trendDurationMonths
    - Add default configuration factory
    - _Requirements: 1.5_
  
  - [x] 2.7 Create GenerationResult model
    - Define properties: record counts by type, generation time, errors list
    - Add status enum (success, permissionDenied, error)
    - _Requirements: 9.4_

- [ ] 3. Implement StressCalendar for correlated stress events
  - [x] 3.1 Create StressCalendar class
    - Generate 2-3 random stress days per month across 365 days
    - Provide isStressDay(DateTime) method for consistent stress day identification
    - _Requirements: 6.4, 6.6_
  
  - [ ]* 3.2 Write property test for stress event frequency
    - **Property 21: Stress Event Frequency**
    - **Validates: Requirements 6.4**

- [ ] 4. Implement Heart Rate data generation
  - [x] 4.1 Create HeartRateGenerator class
    - Implement generate() method producing 5000-10000 records across 365 days
    - Add timestamp spacing logic (5-30 minute intervals with random distribution)
    - Implement time-of-day variation (resting 60-80 bpm, active 90-120 bpm)
    - Add gradual trend decrease for cardiovascular improvement
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  
  - [ ]* 4.2 Write property test for HR record count bounds
    - **Property 4: Heart Rate Record Count Bounds**
    - **Validates: Requirements 2.1**
  
  - [ ]* 4.3 Write property test for HR timestamp spacing
    - **Property 5: Heart Rate Timestamp Spacing**
    - **Validates: Requirements 2.2**
  
  - [ ]* 4.4 Write property test for HR value ranges
    - **Property 6: Heart Rate Value Ranges**
    - **Validates: Requirements 2.3, 2.4**
  
  - [ ]* 4.5 Write property test for HR trend direction
    - **Property 7: Heart Rate Trend Direction**
    - **Validates: Requirements 2.6**

- [ ] 5. Implement HRV data generation
  - [x] 5.1 Create HRVGenerator class
    - Implement generate() method producing 600-900 records across 365 days
    - Add daily record count logic using probability distribution (0-5 records per day)
    - Ensure 35% of days have zero records (realistic gaps)
    - Implement time period distribution (morning, day, evening, night)
    - Add stress day detection (values <30ms on stress days, 40-60ms normal)
    - Add gradual trend increase (10-20% over 3-6 months)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.10_
  
  - [ ]* 5.2 Write property test for HRV daily record count bounds
    - **Property 8: HRV Daily Record Count Bounds**
    - **Validates: Requirements 3.1**
  
  - [ ]* 5.3 Write property test for HRV total record count bounds
    - **Property 9: HRV Total Record Count Bounds**
    - **Validates: Requirements 3.3**
  
  - [ ]* 5.4 Write property test for HRV value ranges
    - **Property 10: HRV Value Ranges**
    - **Validates: Requirements 3.4, 3.5**
  
  - [ ]* 5.5 Write property test for HRV trend direction
    - **Property 11: HRV Trend Direction**
    - **Validates: Requirements 3.6**
  
  - [ ]* 5.6 Write property test for HRV gap distribution
    - **Property 12: HRV Gap Distribution**
    - **Validates: Requirements 3.10, 6.7**
  
  - [ ]* 5.7 Write property test for HRV time period distribution
    - **Property 13: HRV Time Period Distribution**
    - **Validates: Requirements 3.7**

- [ ] 6. Implement Respiratory Rate data generation
  - [x] 6.1 Create RespiratoryRateGenerator class
    - Implement generate() method producing exactly 365 records (one per day)
    - Add night-time timestamp assignment (random hour between 22:00-06:00)
    - Implement stress day detection (18-22 bpm on stress days, 12-16 bpm normal)
    - Add gradual trend decrease for respiratory improvement
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [ ]* 6.2 Write property test for RR exact daily count
    - **Property 14: Respiratory Rate Exact Daily Count**
    - **Validates: Requirements 4.1**
  
  - [ ]* 6.3 Write property test for RR value ranges
    - **Property 15: Respiratory Rate Value Ranges**
    - **Validates: Requirements 4.2, 4.3**
  
  - [ ]* 6.4 Write property test for RR trend direction
    - **Property 16: Respiratory Rate Trend Direction**
    - **Validates: Requirements 4.4**

- [x] 7. Checkpoint - Ensure core generation logic tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement optional data generators (Steps and Sleep)
  - [x] 8.1 Create StepsGenerator class
    - Implement generate() method producing 365 records (one per day)
    - Generate values between 5000-10000 steps with Gaussian distribution
    - Add weekend variation (slightly different patterns)
    - _Requirements: 5.1_
  
  - [x] 8.2 Create SleepGenerator class
    - Implement generate() method producing 365 records (one per day)
    - Generate durations between 7-8 hours (420-480 minutes)
    - Increase sleep duration on weekends
    - _Requirements: 5.2, 5.3_
  
  - [ ]* 8.3 Write property test for optional steps value ranges
    - **Property 17: Optional Steps Value Ranges**
    - **Validates: Requirements 5.1**
  
  - [ ]* 8.4 Write property test for optional sleep value ranges
    - **Property 18: Optional Sleep Value Ranges**
    - **Validates: Requirements 5.2**
  
  - [ ]* 8.5 Write property test for weekend sleep increase
    - **Property 19: Weekend Sleep Increase**
    - **Validates: Requirements 5.3**

- [ ] 9. Implement cross-metric property tests
  - [ ]* 9.1 Write property test for multi-metric trend consistency
    - **Property 20: Multi-Metric Trend Consistency**
    - **Validates: Requirements 6.1**
  
  - [ ]* 9.2 Write property test for stress event metric correlation
    - **Property 22: Stress Event Metric Correlation**
    - **Validates: Requirements 6.6**

- [ ] 10. Implement native iOS HealthKit bridge
  - [x] 10.1 Create Swift ATMOHealthKitWriter class
    - Implement FlutterPlugin protocol and Method Channel registration
    - Add requestPermissions method for WRITE permissions (HR, HRV, RR, Steps, Sleep)
    - Implement writeBatch method for batch HealthKit writes
    - Add createQuantitySample helper for HKQuantitySample creation
    - Add createCategorySample helper for HKCategorySample (sleep) creation
    - Implement error handling with detailed logging
    - _Requirements: 7.1, 7.2, 7.3, 2.7, 3.8, 4.5, 5.4, 5.5_
  
  - [x] 10.2 Create Dart HealthKitBridge class
    - Define Method Channel with name 'healthkit_generator'
    - Implement requestPermissions method calling native code
    - Implement writeBatch method for batch data writes
    - Add error handling and type conversion
    - _Requirements: 7.1, 7.2_
  
  - [ ]* 10.3 Write unit tests for HealthKit bridge error handling
    - Test permission denial handling
    - Test write failure handling
    - Test HealthKit unavailable scenario
    - _Requirements: 7.4, 9.3_

- [ ] 11. Implement DataGenerationService orchestration
  - [x] 11.1 Create DataGenerationService class
    - Initialize with current date and calculate 365-day baseline period
    - Create StressCalendar for correlated stress events
    - Implement generateAllData method orchestrating all generators
    - Add progress callback support for UI updates
    - Implement parallel generation using Future.wait for performance
    - Add comprehensive error handling with logging
    - Track generation statistics (counts, time, errors)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.4_
  
  - [ ]* 11.2 Write property test for date range consistency
    - **Property 1: Date Range Consistency**
    - **Validates: Requirements 1.1, 1.2, 7.6**
  
  - [ ]* 11.3 Write property test for required data types presence
    - **Property 2: Required Data Types Presence**
    - **Validates: Requirements 1.3**
  
  - [ ]* 11.4 Write property test for optional data types conditional generation
    - **Property 3: Optional Data Types Conditional Generation**
    - **Validates: Requirements 1.5**
  
  - [ ]* 11.5 Write property test for generation result completeness
    - **Property 25: Generation Result Completeness**
    - **Validates: Requirements 9.4**

- [ ] 12. Implement UI screens
  - [x] 12.1 Create GenerationScreen
    - Add "Generate 1 Year Data" button with heart icon
    - Add toggle switches for optional features (Steps, Sleep)
    - Implement button tap handler navigating to ProgressScreen
    - Add minimalist styling consistent with health app aesthetic
    - _Requirements: 8.1, 8.2, 8.3_
  
  - [x] 12.2 Create ProgressScreen
    - Add animated circular progress indicator
    - Display percentage completion (0-100%)
    - Show current task description (e.g., "Generating Heart Rate data...")
    - Listen to DataGenerationService progress updates
    - Navigate to ResultsScreen on completion
    - _Requirements: 8.3, 8.4, 8.5_
  
  - [x] 12.3 Create ResultsScreen
    - Display record counts for each data type in format: "Generated HR records: X"
    - Show generation time and success/failure status
    - Add "Open Apple Health" button with URL scheme "x-apple-health://"
    - Add "Generate Again" button returning to GenerationScreen
    - Display errors if any occurred during generation
    - _Requirements: 8.5, 8.6, 8.7_
  
  - [ ]* 12.4 Write widget tests for UI navigation
    - Test GenerationScreen button tap navigates to ProgressScreen
    - Test ProgressScreen navigates to ResultsScreen on completion
    - Test ResultsScreen displays correct record counts
    - _Requirements: 8.3, 8.5, 8.6_

- [ ] 13. Implement logging and debugging
  - [x] 13.1 Add comprehensive logging throughout DataGenerationService
    - Log baseline period start/end dates with "[SynthData]" prefix
    - Log record counts for each data type as generated
    - Log detailed error messages for HealthKit write failures
    - Log final summary with all record counts and generation time
    - Use debugPrint for all log output
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_
  
  - [ ]* 13.2 Write unit tests for logging format
    - Verify log messages contain "[SynthData]" prefix
    - Verify summary format matches specification
    - _Requirements: 10.1, 10.2, 10.4_

- [ ] 14. Implement error handling and edge cases
  - [x] 14.1 Add permission denial handling
    - Display user-friendly error message on permission denial
    - Provide button to open iOS Settings (App-Prefs:root=Privacy&path=HEALTH)
    - Return to GenerationScreen gracefully without crashing
    - _Requirements: 7.4, 9.3_
  
  - [x] 14.2 Add HealthKit write failure handling
    - Log individual write failures with record details
    - Continue with remaining records on failure
    - Track failed writes in GenerationResult
    - Display failure summary on ResultsScreen
    - _Requirements: 9.3_
  
  - [x] 14.3 Add HealthKit availability check
    - Check HKHealthStore.isHealthDataAvailable() before operations
    - Display clear error if HealthKit unavailable (simulator, unsupported iOS)
    - Disable generation button if HealthKit unavailable
    - _Requirements: 7.4_
  
  - [ ]* 14.4 Write unit tests for error scenarios
    - Test permission denial handling
    - Test write failure continuation
    - Test HealthKit unavailable handling
    - _Requirements: 7.4, 9.3_

- [x] 15. Checkpoint - Ensure all tests pass and UI works
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 16. Wire everything together and finalize
  - [x] 16.1 Create main.dart entry point
    - Initialize Flutter app with MaterialApp
    - Set GenerationScreen as home screen
    - Configure app theme (minimalist, health-focused)
    - _Requirements: 8.1, 8.8_
  
  - [x] 16.2 Integrate DataGenerationService with UI
    - Connect GenerationScreen button to DataGenerationService.generateAllData()
    - Wire progress callbacks to ProgressScreen updates
    - Pass GenerationResult to ResultsScreen
    - Handle errors and display to user
    - _Requirements: 8.3, 8.4, 8.5, 8.6_
  
  - [x] 16.3 Add privacy and data handling compliance
    - Verify no network calls are made (local-only processing)
    - Verify no local storage outside HealthKit
    - Add clear permission explanations in Info.plist
    - _Requirements: 11.1, 11.2, 11.3, 11.4_
  
  - [ ]* 16.4 Write integration tests for end-to-end flow
    - Test complete generation flow from button tap to results
    - Verify data written to HealthKit (requires physical device)
    - Test with different configurations (with/without optional features)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 7.5_

- [ ] 17. Final testing and validation
  - [x] 17.1 Test on physical iPhone with iOS 16+
    - Verify app requests correct HealthKit permissions
    - Generate data and verify completion within 10 seconds
    - Open Apple Health app and verify data appears correctly
    - Test ATMO Shield can read the generated data
    - _Requirements: 1.4, 7.5, 12.3, 12.4_
  
  - [x] 17.2 Test on iOS 18+ device
    - Verify all HealthKit features work correctly
    - Test with latest iOS APIs
    - _Requirements: 12.4_
  
  - [x] 17.3 Validate data realism
    - Verify trends are visible (HRV increase, RR/HR decrease)
    - Verify stress days show correlated metric changes
    - Verify gaps in HRV data (~35% of days)
    - Verify weekend patterns differ from weekdays
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.6, 6.7_

- [x] 18. Final checkpoint - Complete testing and documentation
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional property-based tests and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Native iOS code (Swift) is required due to HealthKit limitations
- Testing on physical device is mandatory (HealthKit unavailable in simulator)
- Property tests use `dart_check` package with minimum 100 iterations
- All logs use "[SynthData]" prefix for easy filtering
- Generation target: <10 seconds for all data types
- Data realism is critical for ATMO Shield testing accuracy
