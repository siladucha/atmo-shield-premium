# Requirements Document

## Introduction

The HealthKit Data Generator is a standalone iOS application designed to generate synthetic health data for testing the ATMO Shield stress monitoring system. The application simulates one year of realistic Apple Watch health data patterns and writes them directly to HealthKit, enabling comprehensive testing of ATMO Shield's HRV analysis and stress detection capabilities without requiring actual long-term data collection.

## Glossary

- **HealthKit**: Apple's framework for storing and accessing health and fitness data
- **HRV (Heart Rate Variability)**: Variation in time intervals between heartbeats, measured in milliseconds
- **RMSSD**: Root Mean Square of Successive Differences, a time-domain HRV metric
- **SDNN**: Standard Deviation of NN intervals, another time-domain HRV metric
- **HR (Heart Rate)**: Number of heartbeats per minute (bpm)
- **RR (Respiratory Rate)**: Number of breaths per minute (bpm)
- **HKQuantitySample**: HealthKit's data structure for storing quantitative health measurements
- **Generator**: The HealthKit Data Generator application
- **Synthetic Data**: Artificially generated health data that mimics realistic patterns
- **Baseline Period**: The 365-day historical period for which data is generated

## Requirements

### Requirement 1: Data Generation Scope

**User Story:** As a developer testing ATMO Shield, I want to generate one year of synthetic health data, so that I can validate stress detection algorithms without waiting for real data collection.

#### Acceptance Criteria

1. WHEN the user initiates data generation, THE Generator SHALL create synthetic data spanning exactly 365 consecutive days
2. WHEN calculating the baseline period, THE Generator SHALL set the start date to exactly 365 days before the current date
3. WHEN generating data, THE Generator SHALL create records for Heart Rate, HRV (RMSSD and SDNN), and Respiratory Rate
4. THE Generator SHALL complete all data generation and HealthKit writing operations within 10 seconds
5. WHERE the user enables optional features, THE Generator SHALL additionally create synthetic data for Steps and Sleep duration

### Requirement 2: Heart Rate Data Generation

**User Story:** As a developer, I want realistic heart rate patterns, so that ATMO Shield can analyze cardiovascular variations accurately.

#### Acceptance Criteria

1. WHEN generating heart rate data, THE Generator SHALL create between 5000 and 10000 individual HR records across the 365-day period
2. WHEN determining record timestamps, THE Generator SHALL space records at intervals between 5 and 30 minutes using random distribution
3. WHEN generating resting heart rate values, THE Generator SHALL produce values between 60 and 80 bpm
4. WHEN generating active heart rate values, THE Generator SHALL produce values between 90 and 120 bpm
5. WHEN creating daily patterns, THE Generator SHALL alternate between resting and active periods to simulate realistic daily activity cycles
6. WHEN creating long-term trends, THE Generator SHALL implement a gradual decrease in average heart rate to simulate cardiovascular improvement
7. WHEN writing to HealthKit, THE Generator SHALL use HKQuantitySample with HKQuantityTypeIdentifierHeartRate

### Requirement 3: HRV Data Generation

**User Story:** As a developer, I want realistic HRV patterns with stress variations and improvement trends, so that I can test ATMO Shield's stress detection accuracy.

#### Acceptance Criteria

1. WHEN generating HRV data, THE Generator SHALL create 0-5 HRV records per day with realistic probability distribution
2. WHEN determining daily HRV record count, THE Generator SHALL use the following distribution: 35% of days have 0 records, 45% of days have 1-2 records, 20% of days have 3-5 records
3. WHEN generating across 365 days, THE Generator SHALL produce approximately 600-900 total HRV records
4. WHEN generating normal HRV values, THE Generator SHALL produce SDNN values between 40 and 60 milliseconds
5. WHEN simulating stress days, THE Generator SHALL produce HRV values below 30 milliseconds
6. WHEN creating long-term trends, THE Generator SHALL implement a gradual HRV increase of 10-20% over a period of 3-6 months
7. WHEN determining measurement timing, THE Generator SHALL randomly assign records to morning, day, evening, or night periods
8. WHEN writing to HealthKit, THE Generator SHALL use HKQuantitySample with HKQuantityTypeIdentifierHeartRateVariabilitySDNN
9. THE Generator SHALL apply Gaussian distribution to HRV value generation to ensure realistic statistical properties
10. WHEN simulating realistic gaps, THE Generator SHALL ensure 35% of days have zero HRV records to mimic watch removal or measurement failures

### Requirement 4: Respiratory Rate Data Generation

**User Story:** As a developer, I want realistic respiratory rate patterns that correlate with stress levels, so that I can validate multi-metric stress detection.

#### Acceptance Criteria

1. WHEN generating respiratory rate data, THE Generator SHALL create exactly 365 RR records (one per day)
2. WHEN generating normal night respiratory rates, THE Generator SHALL produce values between 12 and 16 breaths per minute
3. WHEN simulating stress periods, THE Generator SHALL produce respiratory rates between 18 and 22 breaths per minute
4. WHEN creating long-term trends, THE Generator SHALL implement a gradual RR decrease to simulate improvement from wellness practices
5. WHEN writing to HealthKit, THE Generator SHALL use HKQuantitySample with HKQuantityTypeIdentifierRespiratoryRate
6. THE Generator SHALL apply Gaussian distribution to RR value generation to ensure realistic statistical properties

### Requirement 5: Optional Data Types

**User Story:** As a developer, I want optional step count and sleep data, so that I can test ATMO Shield with comprehensive health context.

#### Acceptance Criteria

1. WHERE optional features are enabled, THE Generator SHALL create daily step count records between 5000 and 10000 steps
2. WHERE optional features are enabled, THE Generator SHALL create daily sleep duration records between 7 and 8 hours
3. WHEN generating weekend data, THE Generator SHALL increase sleep duration to simulate realistic weekend patterns
4. WHEN writing step data to HealthKit, THE Generator SHALL use HKQuantitySample with HKQuantityTypeIdentifierStepCount
5. WHEN writing sleep data to HealthKit, THE Generator SHALL use HKCategorySample with HKCategoryTypeIdentifierSleepAnalysis

### Requirement 6: Realistic Pattern Simulation

**User Story:** As a developer, I want data that mimics real-world health patterns, so that testing reflects actual user scenarios.

#### Acceptance Criteria

1. WHEN generating data across the year, THE Generator SHALL implement gradual improvement trends (HRV increase, RR decrease, HR decrease)
2. WHEN creating daily patterns, THE Generator SHALL differentiate between morning, day, evening, and night measurements
3. WHEN generating weekend data, THE Generator SHALL modify patterns to reflect typical weekend behavior (more sleep, less stress, different activity)
4. WHEN simulating stress events, THE Generator SHALL create 2-3 random stress days per month with correlated HRV drops and RR increases
5. THE Generator SHALL use Gaussian distribution for all metric variations to ensure statistical realism
6. WHEN correlating metrics, THE Generator SHALL ensure stress days show consistent patterns across HRV, RR, and HR
7. WHEN simulating realistic gaps, THE Generator SHALL ensure 35% of days have zero HRV records to mimic watch removal or measurement failures

### Requirement 7: HealthKit Integration

**User Story:** As a developer, I want seamless HealthKit integration, so that generated data appears in Apple Health and is accessible to ATMO Shield.

#### Acceptance Criteria

1. WHEN the application launches, THE Generator SHALL request WRITE permissions for Heart Rate, HRV, Respiratory Rate, Step Count, and Sleep Analysis
2. WHEN writing data to HealthKit, THE Generator SHALL use HKQuantitySample format for all quantitative metrics
3. WHEN writing sleep data to HealthKit, THE Generator SHALL use HKCategorySample format
4. WHEN HealthKit permissions are denied, THE Generator SHALL handle the error gracefully without crashing
5. WHEN data generation completes, THE Generator SHALL verify that all records are accessible through the Apple Health app
6. THE Generator SHALL write all data with timestamps within the 365-day baseline period

### Requirement 8: User Interface

**User Story:** As a user, I want a simple interface to generate data and monitor progress, so that I can quickly create test datasets.

#### Acceptance Criteria

1. WHEN the application launches, THE Generator SHALL display a screen with a "Generate 1 Year Data" button
2. WHEN the main screen is displayed, THE Generator SHALL show toggle switches for optional features (Steps and Sleep)
3. WHEN the user taps the generation button, THE Generator SHALL navigate to a progress screen
4. WHILE data generation is in progress, THE Generator SHALL display an animated progress bar with percentage completion
5. WHEN data generation completes, THE Generator SHALL navigate to a results screen
6. WHEN displaying results, THE Generator SHALL show the count of records generated for each data type in the format: "Generated HR records: X, Generated HRV records: Y, Generated RR records: Z"
7. WHEN displaying the results screen, THE Generator SHALL provide a button to open Apple Health app using the URL scheme "x-apple-health://"
8. THE Generator SHALL implement exactly three screens: Generation, Progress, and Results

### Requirement 9: Performance and Reliability

**User Story:** As a developer, I want fast and reliable data generation, so that I can quickly iterate on testing scenarios.

#### Acceptance Criteria

1. WHEN generating all data types, THE Generator SHALL complete the entire process within 10 seconds
2. WHEN writing to HealthKit, THE Generator SHALL batch operations to optimize performance
3. IF HealthKit write operations fail, THEN THE Generator SHALL log the error and continue with remaining operations
4. WHEN generation completes, THE Generator SHALL report the total number of successfully written records
5. THE Generator SHALL not block the UI thread during data generation operations

### Requirement 10: Logging and Debugging

**User Story:** As a developer, I want detailed logging, so that I can troubleshoot issues and verify data generation accuracy.

#### Acceptance Criteria

1. WHEN data generation starts, THE Generator SHALL log the start date and end date of the baseline period with prefix "[SynthData]"
2. WHEN each data type is generated, THE Generator SHALL log the count of records created with prefix "[SynthData]"
3. IF HealthKit write operations fail, THEN THE Generator SHALL log detailed error messages with prefix "[SynthData]"
4. WHEN generation completes, THE Generator SHALL log a summary in the format: "[SynthData] Generated X HR records, Y HRV records, Z RR records"
5. THE Generator SHALL output all logs using debugPrint to the Xcode debug console

### Requirement 11: Privacy and Data Handling

**User Story:** As a user, I want my data to remain private and local, so that I can trust the application with health data generation.

#### Acceptance Criteria

1. THE Generator SHALL process all data locally on the device
2. THE Generator SHALL NOT transmit any data to external servers
3. THE Generator SHALL NOT store any data outside of HealthKit
4. WHEN requesting permissions, THE Generator SHALL provide clear explanations for why WRITE access is needed
5. THE Generator SHALL comply with Apple's HealthKit privacy requirements

### Requirement 12: Platform Requirements

**User Story:** As a developer, I want the application to work on modern iOS devices, so that I can test on current hardware.

#### Acceptance Criteria

1. THE Generator SHALL support iOS 16.0 and later versions
2. THE Generator SHALL be built using Flutter 3.0+
3. THE Generator SHALL run on physical iPhone devices (not simulator, due to HealthKit limitations)
4. WHEN running on iOS 18+, THE Generator SHALL utilize all available HealthKit features
5. THE Generator SHALL request appropriate HealthKit entitlements in Info.plist
