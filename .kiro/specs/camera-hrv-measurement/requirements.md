# Requirements Document: Camera-Based HRV Measurement

## Introduction

This document specifies requirements for a standalone mobile application that measures Heart Rate (HR) and Heart Rate Variability (HRV) using smartphone camera photoplethysmography (PPG). The application is positioned as a wellness tracker for users interested in health, fitness, and stress management. It is NOT a medical device and includes appropriate disclaimers.

The application supports two measurement modes: Quick Mode (30 seconds, HR only) and Accurate Mode (60 seconds, HR + RMSSD with breathing guidance). All processing occurs on-device with encrypted local storage for GDPR compliance.

## Glossary

- **Camera_PPG_System**: The complete mobile application for camera-based heart rate and HRV measurement
- **Signal_Processor**: Component responsible for extracting and analyzing PPG signals from camera frames
- **Measurement_Engine**: Component that orchestrates camera capture, signal processing, and metric calculation
- **Quality_Validator**: Component that assesses signal quality using 5-level validation system
- **Health_Sync_Service**: Component that integrates with HealthKit (iOS) or Google Fit (Android)
- **Storage_Manager**: Component that manages encrypted local database and user data
- **UI_Controller**: Component that manages user interface and user interactions
- **PPG_Signal**: Photoplethysmography signal extracted from camera video frames
- **ROI**: Region of Interest (100x100 pixel area) for signal extraction
- **RMSSD**: Root Mean Square of Successive Differences, a time-domain HRV metric
- **SDNN**: Standard Deviation of NN intervals, a time-domain HRV metric
- **BPM**: Beats Per Minute, heart rate measurement
- **Polar_H10**: Reference chest strap heart rate monitor used for validation
- **Quick_Mode**: 30-second measurement mode providing heart rate only
- **Accurate_Mode**: 60-second measurement mode providing heart rate and HRV with breathing guidance
- **Breathing_Metronome**: Visual/audio guide for paced breathing (4s inhale, 6s exhale)
- **Fitzpatrick_Scale**: Skin type classification system (I-VI) for diverse user testing

## Requirements

### Requirement 1: Measurement Mode Selection

**User Story:** As a user, I want to choose between quick and accurate measurement modes, so that I can balance speed with measurement depth based on my needs.

#### Acceptance Criteria

1. THE UI_Controller SHALL provide a Quick_Mode option with 30-second duration
2. THE UI_Controller SHALL provide an Accurate_Mode option with 60-second duration
3. WHEN Quick_Mode is selected, THE Measurement_Engine SHALL capture frames at 30 frames per second
4. WHEN Accurate_Mode is selected, THE Measurement_Engine SHALL capture frames at 60 frames per second
5. WHEN Quick_Mode completes, THE Measurement_Engine SHALL calculate BPM only
6. WHEN Accurate_Mode completes, THE Measurement_Engine SHALL calculate BPM and RMSSD
7. THE UI_Controller SHALL persist the user's last selected mode across app sessions


### Requirement 2: Camera Signal Acquisition

**User Story:** As a user, I want the app to capture my fingertip video through the camera, so that my heart rate can be measured optically.

#### Acceptance Criteria

1. WHEN measurement starts, THE Measurement_Engine SHALL request camera access permission
2. IF camera permission is denied, THEN THE UI_Controller SHALL display a permission rationale screen
3. WHEN camera access is granted, THE Measurement_Engine SHALL activate the rear camera with flash LED
4. THE Measurement_Engine SHALL capture video frames from an ROI sized at 5 percent of camera sensor width, with minimum 80x80 pixels and maximum 150x150 pixels, centered on the camera sensor
5. WHEN Quick_Mode is active, THE Measurement_Engine SHALL maintain 30 frames per second capture rate
6. WHEN Accurate_Mode is active, THE Measurement_Engine SHALL maintain 60 frames per second capture rate
7. THE Measurement_Engine SHALL extract the green color channel from each captured frame
8. THE Measurement_Engine SHALL calculate mean pixel intensity for each frame's green channel
9. THE Measurement_Engine SHALL store raw intensity values in a time-series buffer

### Requirement 3: Signal Quality Validation

**User Story:** As a user, I want real-time feedback on measurement quality, so that I can adjust my finger placement for accurate results.

#### Acceptance Criteria

1. THE Quality_Validator SHALL assess signal quality at 5 distinct levels
2. WHEN mean brightness is below 20 percent of device baseline OR above 80 percent of device baseline, THE Quality_Validator SHALL report Level 1 (no finger detected)
3. WHEN mean brightness exceeds 75 percent of device baseline AND signal variance is below 2.0, THE Quality_Validator SHALL report Level 2 (overpressure)
4. WHEN red-to-green ratio is below 0.6 OR blue-to-green ratio is below 0.5, THE Quality_Validator SHALL report Level 3 (weak blood flow)
5. WHEN signal variance exceeds 15.0 OR accelerometer movement exceeds 0.5 m/s², THE Quality_Validator SHALL report Level 4 (movement detected)
6. WHEN signal autocorrelation at lag corresponding to detected heart rate period exceeds 0.3 AND at least 60 samples are available, THE Quality_Validator SHALL report Level 5 (good signal)
7. THE Quality_Validator SHALL update quality assessment every 1 second during measurement
8. THE UI_Controller SHALL display visual quality indicator corresponding to current validation level
9. IF quality remains below Level 4 for 10 consecutive seconds, THEN THE UI_Controller SHALL display corrective guidance

### Requirement 4: Signal Processing and Filtering

**User Story:** As a user, I want the app to filter out noise from the camera signal, so that my heart rate measurement is accurate.

#### Acceptance Criteria

1. THE Signal_Processor SHALL apply a Butterworth bandpass filter with 0.8 Hz to 4.0 Hz passband for resting measurements
2. THE Signal_Processor SHALL configure the Butterworth filter as 4th order
3. THE Signal_Processor SHALL apply zero-phase filtering to prevent signal delay
4. WHEN Quick_Mode is active, THE Signal_Processor SHALL use basic filtering without artifact removal
5. WHEN Accurate_Mode is active, THE Signal_Processor SHALL apply advanced filtering with artifact removal
6. THE Signal_Processor SHALL detect and remove signal artifacts exceeding 3 standard deviations from mean
7. WHEN artifacts are removed, THE Signal_Processor SHALL interpolate missing values using cubic spline interpolation


### Requirement 5: Peak Detection and Heart Rate Calculation

**User Story:** As a user, I want the app to accurately detect my heartbeats from the camera signal, so that my heart rate is calculated correctly.

#### Acceptance Criteria

1. THE Signal_Processor SHALL detect peaks in the filtered PPG_Signal using adaptive thresholding
2. THE Signal_Processor SHALL set peak detection threshold at 60% of signal amplitude range
3. THE Signal_Processor SHALL enforce minimum peak separation of 250 milliseconds to accommodate heart rates up to 240 BPM
4. THE Signal_Processor SHALL calculate inter-beat intervals (IBI) between consecutive peaks
5. THE Signal_Processor SHALL interpolate peak positions using parabolic interpolation for sub-sample accuracy
6. THE Signal_Processor SHALL calculate BPM as 60000 divided by mean IBI in milliseconds
7. THE Signal_Processor SHALL validate that calculated BPM falls between 30 and 220 BPM to accommodate athletes and high-intensity exercise
8. IF calculated BPM is outside valid range, THEN THE Measurement_Engine SHALL reject the measurement

### Requirement 6: HRV Metric Calculation

**User Story:** As a user, I want the app to calculate my heart rate variability in Accurate Mode, so that I can assess my stress and recovery status.

#### Acceptance Criteria

1. WHEN Accurate_Mode measurement completes, THE Signal_Processor SHALL calculate RMSSD from inter-beat intervals
2. THE Signal_Processor SHALL calculate RMSSD as the square root of mean squared successive differences in milliseconds
3. WHEN Accurate_Mode measurement completes, THE Signal_Processor SHALL calculate SDNN from inter-beat intervals
4. THE Signal_Processor SHALL calculate SDNN as standard deviation of all inter-beat intervals in milliseconds
5. THE Signal_Processor SHALL validate that RMSSD value is between 10 and 150 milliseconds
6. THE Signal_Processor SHALL validate that SDNN value is between 10 and 200 milliseconds
7. IF HRV metrics are outside valid ranges, THEN THE Measurement_Engine SHALL reject the measurement
8. THE Signal_Processor SHALL provide HRV interpretation based on age-adjusted normative ranges

### Requirement 7: Breathing Metronome Guidance

**User Story:** As a user, I want visual breathing guidance during Accurate Mode, so that I can maintain steady breathing for better HRV measurement accuracy.

#### Acceptance Criteria

1. WHEN Accurate_Mode starts, THE UI_Controller SHALL display the Breathing_Metronome
2. THE Breathing_Metronome SHALL animate an inhalation phase with configurable duration
3. THE Breathing_Metronome SHALL animate an exhalation phase with configurable duration
4. THE Breathing_Metronome SHALL repeat the breathing cycle continuously during measurement
5. THE UI_Controller SHALL provide visual cues distinguishing inhalation from exhalation phases
6. WHERE user enables audio guidance, THE Breathing_Metronome SHALL provide audio breathing cues
7. THE Breathing_Metronome SHALL support breathing rates configurable from 4 to 10 breaths per minute
8. THE UI_Controller SHALL provide option to disable Breathing_Metronome in settings
9. THE Breathing_Metronome SHALL default to 6 breaths per minute (4-second inhale, 6-second exhale)


### Requirement 8: Measurement Results Display

**User Story:** As a user, I want to see my measurement results with clear interpretation, so that I can understand my cardiovascular status.

#### Acceptance Criteria

1. WHEN measurement completes successfully, THE UI_Controller SHALL display the results screen
2. THE UI_Controller SHALL display BPM value as a whole number without decimal places
3. WHEN Accurate_Mode completes, THE UI_Controller SHALL display RMSSD value in milliseconds
4. THE UI_Controller SHALL display a PPG waveform graph showing the last 10 seconds of signal
5. THE UI_Controller SHALL provide textual interpretation of RMSSD value (Low/Normal/High)
6. THE UI_Controller SHALL display measurement timestamp with date and time
7. THE UI_Controller SHALL provide options to save, share, or discard the measurement
8. THE UI_Controller SHALL display measurement mode (Quick or Accurate) on results screen

### Requirement 9: Measurement History Storage

**User Story:** As a user, I want my measurements saved securely on my device, so that I can track my heart rate and HRV trends over time.

#### Acceptance Criteria

1. WHEN user saves a measurement, THE Storage_Manager SHALL encrypt the data using AES-256 encryption
2. THE Storage_Manager SHALL store measurements in SQLCipher encrypted local database
3. THE Storage_Manager SHALL store BPM, RMSSD, SDNN, timestamp, and measurement mode for each record
4. THE Storage_Manager SHALL store the raw PPG waveform data for each measurement
5. THE Storage_Manager SHALL enforce local-only storage with no cloud synchronization
6. THE Storage_Manager SHALL provide retrieval of measurements sorted by timestamp descending
7. THE Storage_Manager SHALL support deletion of individual measurement records
8. THE Storage_Manager SHALL support bulk deletion of all measurement history

### Requirement 10: Measurement History Visualization

**User Story:** As a user, I want to view my measurement history with trends and graphs, so that I can identify patterns in my cardiovascular health.

#### Acceptance Criteria

1. THE UI_Controller SHALL display a history list showing all saved measurements
2. THE UI_Controller SHALL display BPM, RMSSD (if available), and timestamp for each history entry
3. THE UI_Controller SHALL provide filtering by date range (last 7 days, 30 days, 90 days, all time)
4. THE UI_Controller SHALL display a line graph showing BPM trends over selected time period
5. IF at least 3 Accurate_Mode measurements exist, THEN THE UI_Controller SHALL display RMSSD trend graph
6. IF fewer than 3 Accurate_Mode measurements exist, THEN THE UI_Controller SHALL display message "Need more measurements for trend analysis"
6. THE UI_Controller SHALL calculate and display average BPM for selected time period
7. WHEN Accurate_Mode measurements exist, THE UI_Controller SHALL calculate and display average RMSSD
8. WHEN user taps a history entry, THE UI_Controller SHALL display full measurement details


### Requirement 11: Health Platform Integration

**User Story:** As a user, I want my measurements synced to Apple Health or Google Fit, so that I can consolidate my health data in one place.

#### Acceptance Criteria

1. WHERE iOS platform is active, THE Health_Sync_Service SHALL integrate with HealthKit
2. WHERE Android platform is active, THE Health_Sync_Service SHALL integrate with Google Fit
3. WHEN user enables health sync, THE Health_Sync_Service SHALL request health data write permissions
4. IF health permissions are denied, THEN THE UI_Controller SHALL allow app usage without health sync
5. WHEN measurement is saved AND health sync is enabled, THE Health_Sync_Service SHALL write BPM to health platform
6. WHEN Accurate_Mode measurement is saved AND health sync is enabled, THE Health_Sync_Service SHALL write RMSSD to health platform
7. WHERE iOS platform is active, THE Health_Sync_Service SHALL write heart rate samples with HKQuantityTypeIdentifierHeartRate
8. WHERE iOS platform is active, THE Health_Sync_Service SHALL write HRV samples with HKQuantityTypeIdentifierHeartRateVariabilitySDNN annotated as short-term measurement
9. THE Health_Sync_Service SHALL associate each health sample with measurement timestamp

### Requirement 12: Data Export Functionality

**User Story:** As a user, I want to export my measurement data, so that I can share it with healthcare providers or analyze it externally.

#### Acceptance Criteria

1. THE Storage_Manager SHALL support export of measurement history to CSV format
2. THE Storage_Manager SHALL support export of measurement history to PDF format
3. WHEN CSV export is requested, THE Storage_Manager SHALL use UTF-8 encoding with comma delimiter and English column headers
4. WHEN CSV export is requested, THE Storage_Manager SHALL include columns for timestamp, BPM, RMSSD, SDNN, and mode
5. WHEN PDF export is requested, THE Storage_Manager SHALL include summary statistics and trend graphs
6. THE UI_Controller SHALL provide export options in settings or history screen
7. WHEN export completes, THE UI_Controller SHALL provide system share sheet for file distribution
8. THE Storage_Manager SHALL include app version and export date in exported files

### Requirement 13: Onboarding and Tutorial

**User Story:** As a new user, I want clear instructions on how to use the app, so that I can perform measurements correctly on my first attempt.

#### Acceptance Criteria

1. WHEN app launches for the first time, THE UI_Controller SHALL display the onboarding flow
2. THE UI_Controller SHALL display a medical disclaimer screen stating the app is not a medical device
3. THE UI_Controller SHALL require user acknowledgment of the disclaimer before proceeding
4. THE UI_Controller SHALL display camera permission rationale explaining why camera access is needed
5. THE UI_Controller SHALL display an interactive tutorial using animated diagrams and illustrations to demonstrate proper finger placement
6. THE UI_Controller SHALL show visual examples of correct and incorrect finger pressure
7. THE UI_Controller SHALL explain the difference between Quick_Mode and Accurate_Mode
8. THE UI_Controller SHALL provide option to replay tutorial from settings screen


### Requirement 14: User Settings and Preferences

**User Story:** As a user, I want to customize app behavior and manage my data, so that the app works according to my preferences.

#### Acceptance Criteria

1. THE UI_Controller SHALL provide a settings screen accessible from main navigation
2. THE UI_Controller SHALL allow user to set default measurement mode (Quick or Accurate)
3. THE UI_Controller SHALL allow user to enable or disable health platform synchronization
4. THE UI_Controller SHALL allow user to enable or disable audio breathing cues
5. THE UI_Controller SHALL allow user to select app language (English or Russian)
6. THE UI_Controller SHALL provide option to clear all measurement history
7. THE UI_Controller SHALL display app version number in settings
8. THE UI_Controller SHALL provide link to privacy policy in settings
9. THE Storage_Manager SHALL persist all user preferences across app sessions

### Requirement 15: Accuracy Validation Requirements

**User Story:** As a developer, I want to validate measurement accuracy against reference devices, so that users can trust the app's measurements.

#### Acceptance Criteria

1. THE Camera_PPG_System SHALL achieve BPM correlation coefficient of 0.90 or higher when compared to Polar_H10 in resting conditions
2. THE Camera_PPG_System SHALL achieve RMSSD correlation coefficient of 0.85 or higher when compared to Polar_H10 in resting conditions
3. THE Camera_PPG_System SHALL achieve mean absolute percentage error (MAPE) for BPM below 5 percent
4. THE Camera_PPG_System SHALL achieve mean absolute error (MAE) for RMSSD below 5 milliseconds OR mean relative error below 15 percent
5. THE Camera_PPG_System SHALL achieve within-session ICC (intraclass correlation coefficient) of 0.80 or higher for repeated RMSSD measurements
6. THE Camera_PPG_System SHALL achieve successful measurement completion rate of 70 percent or higher with good signal quality
7. THE Camera_PPG_System SHALL be validated across all six Fitzpatrick_Scale skin types with separate accuracy reporting for Fitzpatrick IV-VI
8. THE Camera_PPG_System SHALL be validated with 30 to 50 participants in controlled laboratory conditions in seated position, resting state, with 3-5 measurements per participant per session
9. THE Camera_PPG_System SHALL conduct validation over 7-14 consecutive days with morning measurements to establish baseline reliability
10. THE Camera_PPG_System SHALL validate with 100 or more beta users in field conditions
11. THE Camera_PPG_System SHALL document validation methodology and results in accordance with scientific standards

### Requirement 16: Adaptive Threshold Calibration

**User Story:** As a user with unique physiology or skin tone, I want the app to adapt to my characteristics, so that measurements work reliably for me.

#### Acceptance Criteria

1. WHEN user completes first successful measurement, THE Quality_Validator SHALL establish baseline thresholds
2. THE Quality_Validator SHALL store user-specific baseline for brightness range
3. THE Quality_Validator SHALL store user-specific baseline for signal variance
4. THE Quality_Validator SHALL store user-specific baseline for color channel ratios
5. WHEN user completes 5 or more measurements, THE Quality_Validator SHALL update adaptive thresholds
6. THE Quality_Validator SHALL adjust brightness thresholds to remain within 20 percent of user-specific baseline
7. THE Quality_Validator SHALL adjust variance thresholds to remain within 30 percent of user-specific baseline
8. THE Quality_Validator SHALL use adaptive thresholds for all quality validation, not absolute values
9. THE Storage_Manager SHALL persist adaptive thresholds across app sessions


### Requirement 16A: Skin Tone Adaptive Calibration

**User Story:** As a user with dark skin (Fitzpatrick IV-VI), I want the app to automatically adjust camera settings, so that measurements are as accurate as for lighter skin tones.

#### Acceptance Criteria

1. THE Measurement_Engine SHALL detect approximate skin tone category during first measurement based on signal amplitude and color channel ratios
2. WHERE skin tone is detected as Fitzpatrick IV-VI (darker skin), THE Measurement_Engine SHALL increase LED flash intensity by 20-40 percent compared to baseline
3. WHERE skin tone is detected as Fitzpatrick IV-VI, THE Signal_Processor SHALL apply adaptive gain compensation to normalize signal amplitude
4. THE Quality_Validator SHALL adjust signal-to-noise ratio thresholds based on detected skin tone category
5. THE Measurement_Engine SHALL store skin tone calibration profile for subsequent measurements
6. WHERE signal quality remains poor after skin tone adjustment, THE UI_Controller SHALL provide specific guidance: "Try different finger or ensure firm contact with camera"
7. THE Camera_PPG_System SHALL achieve mean relative error of 20 percent or less for Fitzpatrick IV-VI skin types (compared to 15 percent target for Fitzpatrick I-III)
8. THE Measurement_Engine SHALL allow manual skin tone recalibration from settings if automatic detection is inaccurate


### Requirement 17: Device Thermal Management

**User Story:** As a user, I want the app to prevent my phone from overheating during measurement, so that my device remains safe and comfortable to use.

#### Acceptance Criteria

1. WHEN Accurate_Mode runs at 60 frames per second, THE Measurement_Engine SHALL monitor device temperature
2. IF device temperature exceeds safe operating threshold, THEN THE Measurement_Engine SHALL reduce frame rate to 30 frames per second
3. IF device temperature remains elevated, THEN THE Measurement_Engine SHALL terminate measurement and display warning
4. THE Measurement_Engine SHALL limit continuous measurement sessions to 60 seconds maximum
5. THE Measurement_Engine SHALL enforce cooldown period only when device temperature exceeds safe threshold
6. THE UI_Controller SHALL display thermal warning when cooldown period is active
7. WHERE Android platform is active, THE Measurement_Engine SHALL query device-specific thermal APIs

### Requirement 18: Platform-Specific Camera Handling

**User Story:** As a developer, I want the app to handle diverse Android device cameras, so that measurements work reliably across different hardware.

#### Acceptance Criteria

1. WHERE Android platform is active, THE Measurement_Engine SHALL detect device camera capabilities
2. WHERE Android platform is active, THE Measurement_Engine SHALL create device-specific camera profiles
3. IF device cannot maintain 60 frames per second, THEN THE Measurement_Engine SHALL disable Accurate_Mode
4. IF device cannot maintain 30 frames per second, THEN THE UI_Controller SHALL display incompatibility message
5. WHERE iOS platform is active, THE Measurement_Engine SHALL use AVFoundation framework for camera access
6. WHERE Android platform is active, THE Measurement_Engine SHALL use Camera2 API for camera access
7. THE Measurement_Engine SHALL verify flash LED availability before starting measurement
8. IF flash LED is unavailable, THEN THE UI_Controller SHALL display hardware incompatibility message

### Requirement 19: Privacy and Data Protection

**User Story:** As a privacy-conscious user, I want my health data protected and never transmitted externally, so that my personal information remains secure.

#### Acceptance Criteria

1. THE Camera_PPG_System SHALL process all data locally on the device
2. THE Camera_PPG_System SHALL transmit zero measurement data to external servers
3. THE Storage_Manager SHALL encrypt all stored measurements using AES-256 encryption
4. THE Storage_Manager SHALL encrypt the database file using SQLCipher
5. THE Camera_PPG_System SHALL comply with GDPR data protection requirements
6. THE UI_Controller SHALL provide clear privacy policy accessible from settings
7. THE Camera_PPG_System SHALL request only essential permissions (camera, health data write)
8. WHEN app is uninstalled, THE Storage_Manager SHALL ensure all local data is deleted


### Requirement 20: Error Handling and User Feedback

**User Story:** As a user, I want clear feedback when measurements fail, so that I understand what went wrong and how to fix it.

#### Acceptance Criteria

1. IF measurement fails due to poor signal quality, THEN THE UI_Controller SHALL display specific guidance for improvement
2. IF measurement fails due to insufficient duration, THEN THE UI_Controller SHALL display minimum duration requirement
3. IF measurement fails due to excessive movement, THEN THE UI_Controller SHALL advise user to remain still
4. IF measurement fails due to camera access issues, THEN THE UI_Controller SHALL provide troubleshooting steps
5. WHEN measurement is interrupted, THE UI_Controller SHALL offer option to restart measurement
6. THE UI_Controller SHALL log error events for debugging purposes without storing personal data
7. THE UI_Controller SHALL provide option to report technical issues from settings screen

### Requirement 21: Localization Support

**User Story:** As a non-English speaking user, I want the app in my language, so that I can understand all instructions and results.

#### Acceptance Criteria

1. THE UI_Controller SHALL support English language interface
2. THE UI_Controller SHALL support Russian language interface
3. THE UI_Controller SHALL detect device language and set app language accordingly
4. THE UI_Controller SHALL allow manual language selection in settings
5. THE UI_Controller SHALL localize all user-facing text including error messages
6. THE UI_Controller SHALL localize measurement result interpretations
7. THE UI_Controller SHALL use locale-appropriate date and time formatting
8. THE Storage_Manager SHALL persist language preference across app sessions

### Requirement 22: Performance Requirements

**User Story:** As a user, I want the app to respond quickly and not drain my battery, so that it's practical for daily use.

#### Acceptance Criteria

1. WHEN user taps measurement button, THE UI_Controller SHALL start camera preview within 500 milliseconds
2. WHEN measurement completes, THE Signal_Processor SHALL calculate results within 2 seconds
3. THE Measurement_Engine SHALL process signal analysis in a background thread to maintain UI responsiveness
4. THE Camera_PPG_System SHALL consume less than 15 percent additional battery during 60-second measurement
5. THE UI_Controller SHALL render at 60 frames per second during non-measurement screens
6. THE Storage_Manager SHALL complete database queries within 100 milliseconds
7. THE Camera_PPG_System SHALL use less than 100 megabytes of RAM during active measurement

### Requirement 23: Accessibility Requirements

**User Story:** As a user with visual or motor impairments, I want the app to be accessible, so that I can use it independently.

#### Acceptance Criteria

1. THE UI_Controller SHALL support screen reader accessibility labels for all interactive elements
2. THE UI_Controller SHALL provide minimum touch target size of 44x44 points for all buttons
3. THE UI_Controller SHALL support dynamic text sizing according to system preferences
4. THE UI_Controller SHALL provide sufficient color contrast ratios meeting WCAG AA standards
5. THE UI_Controller SHALL provide haptic feedback for measurement start and completion
6. THE UI_Controller SHALL support VoiceOver (iOS) and TalkBack (Android) navigation
7. THE Breathing_Metronome SHALL provide audio cues as alternative to visual guidance


### Requirement 24: Native Module Architecture

**User Story:** As a developer, I want camera capture and preprocessing in native code, so that performance is optimized for real-time signal processing.

#### Acceptance Criteria

1. WHERE iOS platform is active, THE Measurement_Engine SHALL implement camera capture in Swift using AVFoundation
2. WHERE Android platform is active, THE Measurement_Engine SHALL implement camera capture in Kotlin using Camera2 API
3. THE Measurement_Engine SHALL perform green channel extraction in native code
4. THE Measurement_Engine SHALL transfer extracted intensity values to Dart layer via Method Channel
5. THE Signal_Processor SHALL execute filtering and peak detection in Dart Isolate for parallel processing, or consider native thread implementation to avoid isolate memory copying overhead for large datasets
6. THE Measurement_Engine SHALL minimize data transfer between native and Dart layers
7. THE Measurement_Engine SHALL release camera resources immediately when measurement completes

### Requirement 25: Medical Disclaimer and Legal Compliance

**User Story:** As a user, I want clear information about the app's limitations, so that I understand it's not a medical device.

#### Acceptance Criteria

1. THE UI_Controller SHALL display medical disclaimer on first app launch
2. THE UI_Controller SHALL state that Camera_PPG_System is for wellness purposes only
3. THE UI_Controller SHALL state that Camera_PPG_System is not intended to diagnose or treat medical conditions
4. THE UI_Controller SHALL advise users to consult healthcare professionals for medical concerns
5. THE UI_Controller SHALL require user acknowledgment before allowing app usage
6. THE UI_Controller SHALL provide access to full disclaimer text in settings
7. THE Camera_PPG_System SHALL comply with app store age rating requirements (4+ / All ages)
8. THE Camera_PPG_System SHALL not make medical claims in user interface or marketing materials

### Requirement 26: Waveform Visualization

**User Story:** As a user, I want to see my heart rate waveform, so that I can visually verify the measurement quality.

#### Acceptance Criteria

1. WHEN measurement is in progress, THE UI_Controller SHALL display real-time PPG waveform
2. THE UI_Controller SHALL update waveform display at 10 frames per second minimum
3. THE UI_Controller SHALL display the most recent 10 seconds of PPG_Signal
4. THE UI_Controller SHALL auto-scale waveform amplitude to fit display area
5. WHEN measurement completes, THE UI_Controller SHALL display final waveform on results screen
6. THE UI_Controller SHALL mark detected peaks on the waveform visualization
7. THE Storage_Manager SHALL store waveform data for display in measurement history

### Requirement 27: Measurement Session Management

**User Story:** As a user, I want to cancel or pause measurements if needed, so that I have control over the measurement process.

#### Acceptance Criteria

1. WHILE measurement is in progress, THE UI_Controller SHALL display a cancel button
2. WHEN user taps cancel, THE Measurement_Engine SHALL stop camera capture immediately
3. WHEN user taps cancel, THE UI_Controller SHALL return to main screen without saving results
4. THE Measurement_Engine SHALL release all camera and processing resources when cancelled
5. THE UI_Controller SHALL display measurement progress as percentage completed
6. THE UI_Controller SHALL display elapsed time during measurement
7. THE UI_Controller SHALL display estimated time remaining during measurement

### Requirement 29: Multi-Device Consistency

**User Story:** As a user with multiple devices, I want consistent measurement methodology, so that results are comparable across devices.

#### Acceptance Criteria

1. THE Signal_Processor SHALL use identical filtering algorithms across iOS and Android platforms
2. THE Signal_Processor SHALL use identical peak detection algorithms across iOS and Android platforms
3. THE Signal_Processor SHALL use identical HRV calculation formulas across iOS and Android platforms
4. THE Quality_Validator SHALL use identical validation thresholds across iOS and Android platforms
5. THE Measurement_Engine SHALL normalize for device-specific camera characteristics
6. THE Signal_Processor SHALL apply platform-specific calibration factors when necessary
7. THE Camera_PPG_System SHALL document any platform-specific algorithmic differences

### Requirement 30: Beta Testing and Validation Tracking

**User Story:** As a developer, I want to track validation metrics during beta testing, so that I can verify accuracy targets are met.

#### Acceptance Criteria

1. WHERE beta testing mode is enabled, THE Camera_PPG_System SHALL log measurement quality metrics
2. WHERE beta testing mode is enabled AND user has provided explicit consent, THE Camera_PPG_System SHALL log device model and OS version
3. WHEN beta testing mode is first enabled, THE UI_Controller SHALL request explicit user consent for telemetry data collection
4. WHERE beta testing mode is enabled, THE Camera_PPG_System SHALL log measurement success and failure rates
5. WHERE beta testing mode is enabled, THE Camera_PPG_System SHALL support optional reference device comparison
6. THE Camera_PPG_System SHALL provide aggregated validation statistics for beta testing cohort
7. THE Camera_PPG_System SHALL calculate correlation coefficients against reference measurements
8. THE Camera_PPG_System SHALL disable beta testing mode in production releases

### Requirement 31: App Store Compliance

**User Story:** As a developer, I want the app to meet app store requirements, so that it can be published successfully.

#### Acceptance Criteria

1. THE Camera_PPG_System SHALL target iOS 13.0 or higher
2. THE Camera_PPG_System SHALL target Android 8.0 (API level 26) or higher
3. THE Camera_PPG_System SHALL include required privacy policy URL in app store metadata
4. THE Camera_PPG_System SHALL declare camera usage description in Info.plist (iOS)
5. THE Camera_PPG_System SHALL declare camera permission in AndroidManifest.xml (Android)
6. THE Camera_PPG_System SHALL declare health data permissions with usage descriptions
7. THE UI_Controller SHALL provide app store screenshots demonstrating key features
8. THE Camera_PPG_System SHALL comply with health app review guidelines for both platforms


### Requirement 32: Measurement Quality Metrics

**User Story:** As a user, I want to know the quality of each measurement, so that I can trust the results or retake if needed.

#### Acceptance Criteria

1. WHEN measurement completes, THE Quality_Validator SHALL calculate an overall quality score from 0 to 100
2. THE Quality_Validator SHALL calculate quality score as: (signal_to_noise_ratio_score × 0.4) + (peak_detection_confidence × 0.3) + ((100 - artifact_percentage) × 0.3)
3. THE UI_Controller SHALL display quality score on results screen
4. THE UI_Controller SHALL display quality indicator (Poor/Fair/Good/Excellent) based on score ranges
5. IF quality score is below 60, THEN THE UI_Controller SHALL suggest retaking the measurement
6. THE Storage_Manager SHALL store quality score with each measurement record
7. THE UI_Controller SHALL allow filtering history by minimum quality threshold

### Requirement 33: Background App Behavior

**User Story:** As a user, I want the app to handle interruptions gracefully, so that measurements aren't lost due to phone calls or notifications.

#### Acceptance Criteria

1. WHEN app moves to background during measurement, THE Measurement_Engine SHALL pause camera capture
2. WHEN app returns to foreground within 5 seconds, THE Measurement_Engine SHALL resume measurement
3. IF app remains in background for more than 5 seconds, THEN THE Measurement_Engine SHALL cancel measurement
4. WHEN phone call is received during measurement, THE Measurement_Engine SHALL cancel measurement immediately
5. WHEN measurement is cancelled due to interruption, THE UI_Controller SHALL display interruption reason
6. THE Measurement_Engine SHALL release camera resources when app moves to background
7. THE UI_Controller SHALL restore app state when returning from background

### Requirement 34: First-Time User Experience

**User Story:** As a first-time user, I want a smooth onboarding experience, so that I can successfully complete my first measurement.

#### Acceptance Criteria

1. WHEN user completes onboarding, THE UI_Controller SHALL offer to start a guided first measurement
2. WHEN guided measurement starts, THE UI_Controller SHALL provide step-by-step instructions
3. THE UI_Controller SHALL highlight the measurement button with animation
4. THE UI_Controller SHALL show finger placement overlay on camera preview
5. THE UI_Controller SHALL provide real-time coaching during first measurement
6. WHEN first measurement completes successfully, THE UI_Controller SHALL display congratulations message
7. THE UI_Controller SHALL explain results screen elements after first measurement
8. THE Storage_Manager SHALL track whether user has completed first measurement

### Requirement 35: Data Retention and Cleanup

**User Story:** As a user, I want control over how long my data is stored, so that I can manage device storage.

#### Acceptance Criteria

1. THE Storage_Manager SHALL provide automatic data retention policy options (30 days, 90 days, 1 year, forever)
2. WHEN retention period expires, THE Storage_Manager SHALL automatically delete old measurements
3. THE Storage_Manager SHALL preserve at least the 10 most recent measurements regardless of retention policy
4. THE UI_Controller SHALL display current storage usage in settings
5. THE UI_Controller SHALL provide manual option to delete measurements older than specified date
6. WHEN user deletes app data, THE Storage_Manager SHALL remove all measurements and configurations
7. THE Storage_Manager SHALL compact database after bulk deletions to reclaim storage space


### Requirement 36: Measurement Reliability Indicators

**User Story:** As a user, I want to understand factors affecting measurement reliability, so that I can optimize conditions for accurate results.

#### Acceptance Criteria

1. THE Quality_Validator SHALL detect ambient light interference during measurement
2. THE Quality_Validator SHALL detect hand tremor using accelerometer data
3. THE Quality_Validator SHALL detect irregular heart rhythms based on IBI variability
4. IF ambient light interference is detected, THEN THE UI_Controller SHALL suggest moving to darker environment
5. IF hand tremor is detected, THEN THE UI_Controller SHALL suggest stabilizing hand position
6. IF irregular rhythm is detected, THEN THE UI_Controller SHALL display advisory to consult healthcare provider
7. THE UI_Controller SHALL display reliability factors on results screen
8. THE Storage_Manager SHALL store reliability indicators with each measurement

### Requirement 37: Comparative Analysis Features

**User Story:** As a user, I want to compare measurements over time, so that I can track improvements or changes in my cardiovascular health.

#### Acceptance Criteria

1. THE UI_Controller SHALL allow selection of two measurements for side-by-side comparison
2. THE UI_Controller SHALL display percentage change between compared measurements
3. THE UI_Controller SHALL highlight significant changes (greater than 10 percent) in comparison view
4. THE UI_Controller SHALL display waveforms for both measurements in comparison view
5. THE UI_Controller SHALL calculate and display average values for selected time periods
6. THE UI_Controller SHALL show trend direction (improving/stable/declining) for BPM and RMSSD
7. THE UI_Controller SHALL provide weekly and monthly summary statistics

### Requirement 38: Offline Functionality

**User Story:** As a user, I want full app functionality without internet connection, so that I can measure my heart rate anywhere.

#### Acceptance Criteria

1. THE Camera_PPG_System SHALL function completely without internet connectivity
2. THE Camera_PPG_System SHALL not require network access for any core functionality
3. THE Storage_Manager SHALL store all data locally without cloud dependencies
4. THE UI_Controller SHALL not display network error messages during normal operation
5. THE Camera_PPG_System SHALL not include analytics or telemetry requiring network access
6. WHERE health sync is enabled, THE Health_Sync_Service SHALL queue data for sync when network is unavailable
7. THE Camera_PPG_System SHALL declare offline capability in app store metadata

### Requirement 39: Version Migration and Updates

**User Story:** As a user, I want my data preserved when updating the app, so that I don't lose my measurement history.

#### Acceptance Criteria

1. WHEN app is updated, THE Storage_Manager SHALL migrate database schema to new version
2. THE Storage_Manager SHALL preserve all measurement data during migration
3. THE Storage_Manager SHALL preserve all user preferences during migration
4. IF migration fails, THEN THE Storage_Manager SHALL restore previous database version
5. THE Storage_Manager SHALL create backup before attempting migration
6. THE UI_Controller SHALL display migration progress for updates requiring database changes
7. THE Storage_Manager SHALL validate data integrity after migration completes


### Requirement 40: Debug and Development Tools

**User Story:** As a developer, I want debugging tools to troubleshoot issues, so that I can diagnose and fix problems efficiently.

#### Acceptance Criteria

1. WHERE debug mode is enabled, THE UI_Controller SHALL display raw signal values in real-time
2. WHERE debug mode is enabled, THE Signal_Processor SHALL log filter coefficients and processing parameters
3. WHERE debug mode is enabled, THE Quality_Validator SHALL display all validation threshold values
4. WHERE debug mode is enabled, THE UI_Controller SHALL provide option to export raw signal data
5. WHERE debug mode is enabled, THE Measurement_Engine SHALL log frame capture timing statistics
6. THE Camera_PPG_System SHALL disable debug mode in production builds
7. WHERE debug mode is enabled, THE UI_Controller SHALL display performance metrics (CPU, memory, FPS)

## Summary

This requirements document specifies 39 functional requirements for a camera-based HRV measurement mobile application. The requirements cover:

- Core measurement functionality (Quick and Accurate modes)
- Signal acquisition and processing
- Quality validation and user feedback
- Data storage and privacy
- Health platform integration
- User interface and experience
- Accuracy validation and testing
- Platform-specific implementations
- Accessibility and localization
- Performance and reliability

All requirements follow EARS patterns and comply with INCOSE quality rules for clarity, testability, and completeness. The application is designed as a wellness tool with appropriate medical disclaimers and privacy protections.

## Next Steps

Upon approval of these requirements, the next phase will involve:
1. Creating a detailed design document
2. Defining system architecture and component interactions
3. Specifying algorithms and data structures
4. Creating implementation tasks and timeline

## Notes on Requirements Changes

**Requirement 28 (Signal Processing Parser and Printer)** has been removed from this requirements document as it represents an internal technical implementation detail rather than a user-facing requirement. This functionality will be addressed in the design phase where serialization and configuration management patterns will be specified.

