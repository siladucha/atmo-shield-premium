# ATMO Shield v1.5.0 - Design Document

## Overview

ATMO Shield transforms ATMO from a reactive wellness app into a predictive nervous system guardian. It analyzes Heart Rate Variability (HRV) data from health platforms to detect stress patterns 15-60 minutes before peak impact, providing timely NeuroYoga interventions through a hybrid native-Flutter architecture.

**Core Innovation**: Proactive stress detection using statistical Z-score analysis of HRV patterns, integrated with ATMO's existing NeuroYoga breathing protocols for scientifically-validated interventions.

**Key Differentiators**:
- Privacy-first: 100% on-device processing, no cloud dependencies
- Cross-platform: iOS HealthKit and Android Health Connect/Google Fit integration
- Scientifically-grounded: Z-score analysis with PubMed-referenced protocol recommendations
- Seamless integration: Leverages existing ATMO NeuroYoga protocol library

## Architecture

### Hybrid Native-Flutter Architecture

The system uses a hybrid architecture to overcome Flutter's background processing limitations while maintaining cross-platform UI consistency:

```
┌─────────────────────────────────────────┐
│           Flutter UI Layer              │
│  • Dashboard integration                │
│  • Settings management                  │
│  • Analytics visualization             │
│  • Notification handling               │
├─────────────────────────────────────────┤
│         Method Channel Bridge           │
│  • Bidirectional communication         │
│  • Event streaming                     │
│  • Error handling                      │
├─────────────────────────────────────────┤
│     Native Background Modules           │
│  iOS: Swift + HealthKit                 │
│  • HKObserverQuery background delivery  │
│  • Z-score calculation                 │
│  • Local notification scheduling       │
│                                         │
│  Android: Kotlin + Health Connect       │
│  • WorkManager periodic sync           │
│  • Foreground service for analysis     │
│  • Platform-specific data handling     │
├─────────────────────────────────────────┤
│        Local Storage Layer              │
│  iOS: UserDefaults + Keychain           │
│  Android: SharedPreferences + Keystore  │
│  • Encrypted HRV data storage          │
│  • Baseline and trend caching          │
│  • Cross-platform data synchronization │
└─────────────────────────────────────────┘
```

### Architecture Rationale

**Why Hybrid Architecture?**
1. **Flutter Limitations**: Dart isolates are killed after ~30 seconds in background
2. **Platform Requirements**: HealthKit observer queries require native Swift implementation
3. **Performance**: Native code provides better performance for statistical calculations
4. **Reliability**: Platform-specific optimizations for background processing

**Communication Flow**:
1. Native modules monitor health data continuously
2. Statistical analysis performed in native code
3. Results cached in platform-specific storage
4. Flutter UI reads cached results on foreground
5. Method channels handle real-time event streaming

## Components and Interfaces

### Core Components

#### 1. ShieldService (Flutter Interface)
```dart
abstract class ShieldService {
  bool get isPremiumAvailable;
  bool get hasPremiumAccess;
  
  Future<bool> initialize();
  Future<void> startMonitoring();
  Future<void> stopMonitoring();
  Future<ShieldStatus> getStatus();
  Future<List<StressEvent>> getRecentEvents({int days = 7});
  Future<BaselineData?> getBaseline();
  Future<StressAnalysis> performManualCheck();
  Future<void> updateSettings(ShieldSettings settings);
}
```

#### 2. Native Health Data Collectors

**iOS HealthKit Module (Swift)**:
```swift
class ATMOShieldHealthKit {
    func setupObserverQueries()
    func processHRVData(_ samples: [HKQuantitySample])
    func calculateZScore(hrv: Double, baseline: BaselineData) -> Double
    func detectStressPatterns() -> StressEvent?
    func scheduleNotification(for event: StressEvent)
}
```

**Android Health Connect Module (Kotlin)**:
```kotlin
class ATMOShieldHealthConnect {
    fun setupDataObserver()
    fun processHRVData(records: List<HeartRateVariabilityRecord>)
    fun calculateZScore(hrv: Double, baseline: BaselineData): Double
    fun detectStressPatterns(): StressEvent?
    fun scheduleNotification(event: StressEvent)
}
```

#### 3. Statistical Analysis Engine

**Core Analysis Functions**:
- **Baseline Calculation**: 21-day rolling mean and standard deviation
- **Z-Score Analysis**: Statistical deviation detection
- **Pattern Recognition**: Sympathetic overdrive, neural rigidity, energy depletion
- **Cross-Platform Normalization**: Platform-specific HRV calibration

#### 4. Protocol Recommendation Engine

**Integration with Existing ATMO Protocols**:
- Loads protocols from `Data/specs/breathing_spec.json`
- Maps stress severity to appropriate breathing patterns
- Considers time-of-day context for protocol selection
- Provides scientific rationale for recommendations

#### 5. Notification System

**Smart Notification Features**:
- Contextual timing based on calendar integration
- Actionable notifications with protocol quick-start
- Cooldown management to prevent notification fatigue
- Severity-based notification prioritization

### Interface Definitions

#### Data Models

```dart
class HRVReading {
  final DateTime timestamp;
  final double value; // SDNN in milliseconds
  final String source; // 'healthkit', 'health_connect', 'google_fit'
  final int sampleCount;
  final double confidence; // Data quality score 0-1
}

class BaselineData {
  final DateTime calculatedAt;
  final double mean;
  final double standardDeviation;
  final int dayCount;
  final double confidence;
  final String platform;
}

class StressEvent {
  final DateTime detectedAt;
  final double zScore;
  final StressSeverity severity;
  final String? recommendedProtocol;
  final bool notificationSent;
  final DateTime? interventionStarted;
  final bool interventionCompleted;
  final double? postInterventionHRV;
}

enum StressSeverity { low, medium, high, critical }

class StressAnalysis {
  final DateTime analyzedAt;
  final double currentHRV;
  final double zScore;
  final StressSeverity severity;
  final String recommendation;
  final String scientificContext;
}
```

#### Method Channel Communication

```dart
class ShieldMethodChannel {
  static const MethodChannel _channel = MethodChannel('atmo_shield');
  
  // Flutter → Native
  Future<bool> startHealthMonitoring();
  Future<void> updateAnalysisSettings(Map<String, dynamic> settings);
  
  // Native → Flutter (Event Stream)
  Stream<StressEvent> get stressEventStream;
  Stream<BaselineData> get baselineUpdateStream;
  Stream<Map<String, dynamic>> get healthDataStream;
}
```

## Data Models

### HRV Data Pipeline

**Data Flow Architecture**:
1. **Collection**: Native modules collect HRV data from health platforms
2. **Normalization**: Platform-specific calibration for data consistency
3. **Aggregation**: Daily statistical summaries (mean, median, sample count)
4. **Analysis**: Z-score calculation and pattern detection
5. **Storage**: Encrypted local storage with automatic cleanup
6. **Visualization**: Flutter UI renders trends and analytics

### Cross-Platform Data Normalization

**Challenge**: Different platforms provide HRV data with varying ranges and accuracy:
- HealthKit (Apple Watch): 30-120ms typical range
- Health Connect: 25-100ms typical range
- Google Fit: 20-90ms typical range

**Solution**: Platform-specific normalization and separate baselines:

```dart
class HRVNormalizer {
  static double normalize(double rawHRV, HealthPlatform platform) {
    switch (platform) {
      case HealthPlatform.healthKit:
        return _normalizeRange(rawHRV, 30, 120);
      case HealthPlatform.healthConnect:
        return _normalizeRange(rawHRV, 25, 100);
      case HealthPlatform.googleFit:
        return _normalizeRange(rawHRV, 20, 90);
    }
  }
  
  static double _normalizeRange(double value, double min, double max) {
    return (value - min) / (max - min); // 0-1 normalized
  }
}
```

### Data Storage Strategy

**Local Storage Architecture**:
- **Hive Database**: Extends existing ATMO Hive setup
- **Encryption**: AES-256-GCM for all Shield data
- **Data Retention**: Configurable periods with automatic cleanup
- **Cross-Platform Sync**: Unified data format across platforms

**Storage Boxes**:
```dart
// Hive box definitions
@HiveType(typeId: 20)
class HRVReadingHive extends HiveObject {
  @HiveField(0) DateTime timestamp;
  @HiveField(1) double value;
  @HiveField(2) String source;
  @HiveField(3) int sampleCount;
  @HiveField(4) double confidence;
}

@HiveType(typeId: 21)
class BaselineDataHive extends HiveObject {
  @HiveField(0) DateTime calculatedAt;
  @HiveField(1) double mean;
  @HiveField(2) double standardDeviation;
  @HiveField(3) int dayCount;
  @HiveField(4) double confidence;
  @HiveField(5) String platform;
}
```

## UI/UX Integration

### Dashboard Integration

**Main Dashboard Enhancement** (`body_zone_screen.dart`):
- **Shield Status Card**: Integrated into existing dashboard layout
- **Real-time Status Indicator**: Color-coded circular gauge
- **Quick Actions**: Manual check and recommended protocol buttons
- **Today's Shield Activity**: Integration with existing statistics

**Status Indicator Design**:
```dart
class ShieldStatusIndicator extends StatelessWidget {
  final double zScore;
  final ShieldStatus status;
  
  Color get statusColor {
    if (zScore > -1.0) return Colors.green;      // Optimal
    if (zScore > -1.8) return Colors.yellow;     // Mild activation
    if (zScore > -2.5) return Colors.orange;     // Stress detected
    return Colors.red;                           // High stress
  }
  
  String get statusText {
    if (zScore > -1.0) return "Optimal State";
    if (zScore > -1.8) return "Mild Activation";
    if (zScore > -2.5) return "Stress Detected";
    return "High Stress";
  }
}
```

### Settings Integration

**Shield Settings Section** (`settings_overlay.dart`):
- **Master Toggle**: Enable/disable Shield monitoring
- **Sensitivity Settings**: Custom Z-score thresholds
- **Notification Preferences**: Timing and frequency controls
- **Data Management**: Export and retention settings

### Analytics Screens

**New Analytics Navigation**:
- **Shield Analytics**: Dedicated section in settings menu
- **Multi-timeframe Views**: 7/30/90/180-day analysis
- **Interactive Charts**: Zoom, pan, and detailed data points
- **Correlation Analysis**: HRV vs sleep, calendar events, weather

### Notification Design

**Actionable Notification Format**:
```
🛡️ NeuroYoga Stress Alert - Medium Level

Your HRV shows sympathetic overdrive (Z-score: -2.1). 
Research shows extended exhale breathing activates 
parasympathetic recovery within 2-3 minutes.

Recommended: Light Calming (4-0-6-0) - 6 cycles
Duration: ~1 minute

[Start Protocol] [Remind Later]
```

## Cross-Platform Considerations

### iOS Implementation

**HealthKit Integration Requirements**:
- **Permissions**: HRV, resting heart rate, steps, sleep analysis
- **Background Delivery**: HKObserverQuery for continuous monitoring
- **Background Processing**: BGAppRefreshTask with 30-second limit
- **Data Quality**: Handle Apple Watch vs iPhone HRV differences

**iOS-Specific Challenges**:
- **Background Limitations**: System kills background processing aggressively
- **Data Delays**: HealthKit observer queries have 15-60 minute delays
- **App Store Review**: Health data usage requires careful justification

**iOS Architecture**:
```swift
class ATMOShieldNative: NSObject {
    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    
    func setupHealthKitObserver() {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, _, error in
            self?.processNewHRVData()
        }
        healthStore.execute(query)
        observerQueries.append(query)
    }
    
    func processNewHRVData() {
        // Native processing to avoid Flutter background limitations
        // Save results to UserDefaults for Flutter to read
    }
}
```

### Android Implementation

**Health Connect Integration** (Android 14+):
- **Permissions**: Heart rate variability, resting heart rate, steps, sleep
- **Background Processing**: WorkManager for periodic sync
- **Foreground Service**: For critical analysis tasks
- **Battery Optimization**: Handle Doze mode and app whitelisting

**Google Fit Fallback** (Android 13 and below):
- **Legacy Support**: Maintain compatibility with older devices
- **Data Migration**: Smooth transition between platforms
- **API Deprecation**: Plan for Google Fit API sunset

**Android Architecture**:
```kotlin
class ATMOShieldNative {
    private val healthConnectClient = HealthConnectClient.getOrCreate(context)
    
    fun setupHealthConnectObserver() {
        val request = ReadRecordsRequest(
            recordType = HeartRateVariabilityRecord::class,
            timeRangeFilter = TimeRangeFilter.after(Instant.now().minus(1, ChronoUnit.DAYS))
        )
        
        // WorkManager for periodic data sync
        val workRequest = PeriodicWorkRequestBuilder<HRVSyncWorker>(15, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder()
                .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
                .build())
            .build()
        
        WorkManager.getInstance(context).enqueue(workRequest)
    }
}
```

### Cross-Platform Data Consistency

**Calibration Strategy**:
1. **Platform Detection**: Identify data source (HealthKit, Health Connect, Google Fit)
2. **Normalization**: Apply platform-specific scaling factors
3. **Baseline Separation**: Maintain separate baselines per platform
4. **Migration Handling**: Smooth transitions when users switch devices

**Data Quality Assurance**:
- **Confidence Scoring**: Rate data quality based on sample count and consistency
- **Outlier Detection**: Filter unrealistic HRV values
- **Gap Handling**: Interpolate missing data points appropriately

## Privacy and Security Design

### Privacy-First Architecture

**Core Privacy Principles**:
1. **Local Processing Only**: All HRV analysis performed on-device
2. **No Cloud Storage**: Zero transmission of biometric data
3. **Encrypted Storage**: AES-256-GCM for all sensitive data
4. **Minimal Data Collection**: Only essential health metrics
5. **User Control**: Complete data ownership and export capabilities

**Data Handling Policies**:
- **HRV Data**: Never leaves device, processed locally only
- **Analysis Results**: Stored locally with user-controlled retention
- **Aggregated Statistics**: Local storage only, no analytics transmission
- **User Preferences**: Local storage with optional cloud backup (non-biometric)

### Security Implementation

**Encryption Strategy**:
```dart
class ShieldSecurityManager {
  static const String _keyAlias = 'atmo_shield_key';
  
  Future<String> encryptData(String data) async {
    final key = await _getOrCreateKey();
    final encrypter = Encrypter(AES(key));
    return encrypter.encrypt(data).base64;
  }
  
  Future<String> decryptData(String encryptedData) async {
    final key = await _getOrCreateKey();
    final encrypter = Encrypter(AES(key));
    return encrypter.decrypt64(encryptedData);
  }
  
  Future<Key> _getOrCreateKey() async {
    // Platform-specific secure key storage
    // iOS: Keychain Services
    // Android: Android Keystore
  }
}
```

**Permission Management**:
- **Progressive Permissions**: Request permissions as features are needed
- **Clear Rationale**: Explain health benefits for each permission
- **Graceful Degradation**: Provide fallback functionality when permissions denied
- **User Education**: Clear explanations of data usage and benefits

### Compliance Considerations

**Medical Device Regulations**:
- **Wellness Positioning**: Clear non-medical disclaimers
- **FDA Guidance**: Compliance with wellness app guidelines
- **Medical Claims**: Avoid diagnostic or treatment claims

**Data Protection Compliance**:
- **GDPR**: Right to data portability and deletion
- **HIPAA**: Business Associate Agreement not required (consumer wellness)
- **Platform Policies**: App Store and Google Play health data policies

## Integration with NeuroYoga Protocols

### Protocol Selection Algorithm

**Stress-to-Protocol Mapping**:
```dart
class ProtocolRecommendationEngine {
  String recommendProtocol(double zScore, TimeOfDay timeOfDay) {
    final severity = _calculateSeverity(zScore);
    final timeContext = _getTimeContext(timeOfDay);
    
    switch (severity) {
      case StressSeverity.low:
        return _selectCoherentProtocol(timeContext);
      case StressSeverity.medium:
        return _selectCalmingProtocol(timeContext);
      case StressSeverity.high:
        return _selectIntensiveCalmingProtocol(timeContext);
      case StressSeverity.critical:
        return _selectEmergencyProtocol(timeContext);
    }
  }
  
  String _selectCoherentProtocol(TimeContext context) {
    switch (context) {
      case TimeContext.morning:
        return "5-0-5-0"; // Coherent 5-5
      case TimeContext.afternoon:
        return "6-0-6-0"; // Coherent 6-6
      case TimeContext.evening:
        return "5-0-5-0"; // Coherent 5-5
      case TimeContext.night:
        return "5.5-0-5.5-0"; // Ideal Coherent
    }
  }
}
```

**Scientific Rationale Integration**:
- **PubMed References**: Each protocol includes scientific backing
- **Mechanism Explanation**: Brief explanation of physiological effects
- **Expected Outcomes**: Timeline for stress reduction effects

### Protocol Execution Integration

**Seamless ATMO Integration**:
1. **Notification Tap**: Opens directly to recommended protocol
2. **Pre-configured Settings**: Optimal cycle count and duration
3. **Progress Tracking**: Shield-initiated sessions tracked separately
4. **Effectiveness Measurement**: Post-intervention HRV analysis

**Enhanced Protocol Experience**:
- **Context Awareness**: Protocol selection considers current stress level
- **Adaptive Cycles**: Adjust cycle count based on stress severity
- **Real-time Feedback**: Monitor HRV changes during protocol execution

## Performance and Scalability

### Performance Targets

**Response Time Requirements**:
- **Z-score Calculation**: < 100ms for single analysis
- **Background Analysis**: < 10 seconds total processing time
- **UI Response**: < 120ms for dashboard updates
- **Notification Delivery**: < 5 seconds from detection to notification

**Memory Management**:
- **Data Storage**: < 50MB for 90 days of HRV data
- **Runtime Memory**: < 20MB additional memory usage
- **Background Processing**: < 10MB memory footprint

**Battery Optimization**:
- **Target Impact**: < 5% additional battery drain
- **Background Efficiency**: Minimize CPU usage during analysis
- **Adaptive Frequency**: Reduce analysis frequency when battery low
- **Low Power Mode**: Graceful degradation in power-saving modes

### Scalability Considerations

**Data Volume Management**:
- **Automatic Cleanup**: Remove data older than retention period
- **Compression**: Efficient storage of historical data
- **Indexing**: Fast queries for trend analysis
- **Pagination**: Efficient loading of large datasets

**Cross-Platform Scaling**:
- **Platform Abstraction**: Unified interface for different health platforms
- **Feature Parity**: Consistent functionality across iOS and Android
- **Performance Optimization**: Platform-specific optimizations

## Error Handling

### Robust Error Management

**Health Data Errors**:
```dart
class ShieldErrorHandler {
  Future<void> handleHealthDataError(HealthDataException error) async {
    switch (error.type) {
      case HealthDataErrorType.permissionDenied:
        await _showPermissionRationale();
        break;
      case HealthDataErrorType.noDataAvailable:
        await _enableManualTrackingMode();
        break;
      case HealthDataErrorType.platformUnsupported:
        await _showPlatformLimitations();
        break;
      case HealthDataErrorType.dataQualityPoor:
        await _showDataQualityGuidance();
        break;
    }
  }
}
```

**Background Processing Errors**:
- **System Kills**: Graceful recovery when background processing is terminated
- **Data Gaps**: Handle missing HRV data with interpolation or degraded functionality
- **Platform Changes**: Adapt to iOS/Android policy changes
- **Hardware Limitations**: Fallback modes for devices without HRV capability

**Network and Storage Errors**:
- **Storage Full**: Automatic cleanup of old data
- **Encryption Failures**: Secure fallback and user notification
- **Database Corruption**: Data recovery and rebuilding procedures

### Fallback Strategies

**Graceful Degradation Modes**:

1. **No Background Processing**: Manual check mode only
2. **Limited Permissions**: Reduced functionality with clear explanations
3. **Poor Data Quality**: Lower confidence analysis with user warnings
4. **Platform Limitations**: Alternative data sources or manual input

**User Communication**:
- **Clear Error Messages**: Non-technical explanations of issues
- **Actionable Solutions**: Specific steps users can take to resolve problems
- **Progress Indicators**: Show system status and recovery progress

## Testing Strategy

### Dual Testing Approach

**Unit Tests**: Verify specific examples, edge cases, and error conditions
- Focus on mathematical calculations (Z-score, baseline)
- Test data model serialization/deserialization
- Verify error handling scenarios
- Test platform-specific data normalization

**Property-Based Tests**: Verify universal properties across all inputs
- Test statistical calculations with random data
- Verify protocol recommendation consistency
- Test data storage and retrieval integrity
- Validate cross-platform data consistency

### Property-Based Testing Configuration

**Testing Framework**: Use `test` package with custom property generators
- **Minimum Iterations**: 100 per property test
- **Test Tagging**: Reference design document properties
- **Tag Format**: `Feature: atmo-shield, Property {number}: {property_text}`

**Example Property Test**:
```dart
@Property('Feature: atmo-shield, Property 1: Z-score calculation accuracy')
void testZScoreCalculation() {
  forAll(
    tuple3(
      doubles(min: 10.0, max: 150.0), // HRV values
      doubles(min: 30.0, max: 80.0),  // Baseline mean
      doubles(min: 5.0, max: 20.0),   // Baseline std
    ),
    (tuple) {
      final hrv = tuple.item1;
      final mean = tuple.item2;
      final std = tuple.item3;
      
      final zScore = ShieldAnalytics.calculateZScore(hrv, mean, std);
      final expectedZScore = (hrv - mean) / std;
      
      expect(zScore, closeTo(expectedZScore, 0.001));
    },
  );
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria from the requirements document, I identified several areas where properties could be consolidated to eliminate redundancy:

**Redundancy Analysis**:
- **Notification Properties**: Properties about notification content, timing, and cooldown can be combined into comprehensive notification behavior properties
- **Data Processing Properties**: HRV data collection, aggregation, and baseline calculation can be unified into data pipeline properties  
- **Detection Properties**: Different stress detection algorithms (sympathetic overdrive, neural rigidity, energy depletion) can be consolidated into pattern detection properties
- **Protocol Properties**: Protocol loading, selection, and recommendation can be combined into protocol management properties

The following properties represent the unique validation requirements after eliminating redundancy:

### Core Statistical Properties

**Property 1: Z-Score Calculation Accuracy**
*For any* valid HRV value, baseline mean, and baseline standard deviation, the Z-score calculation should equal (HRV - baseline_mean) / baseline_std with mathematical precision
**Validates: Requirements 1.4**

**Property 2: Baseline Calculation Consistency**  
*For any* sequence of daily HRV readings spanning 21+ days, the rolling baseline calculation should produce mathematically correct mean and standard deviation values
**Validates: Requirements 1.3**

**Property 3: HRV Data Aggregation Accuracy**
*For any* collection of HRV readings within a day, the daily aggregation should correctly calculate mean, median, and sample count statistics
**Validates: Requirements 1.2**

### Detection Algorithm Properties

**Property 4: Stress Detection Threshold Consistency**
*For any* Z-score and activity level combination, stress detection should trigger if and only if Z-score ≤ -1.8 and recent activity < 500 steps/hour
**Validates: Requirements 2.1**

**Property 5: Pattern Recognition Accuracy**
*For any* sequence of 7 daily HRV aggregates, neural rigidity detection should trigger when coefficient of variation < 0.1 or range analysis indicates low variability
**Validates: Requirements 2.2**

**Property 6: Energy Depletion Detection**
*For any* sequence of daily Z-scores, energy depletion should be detected when 3+ consecutive days have Z-score ≤ -1.5
**Validates: Requirements 2.3**

### Protocol Integration Properties

**Property 7: Protocol Recommendation Mapping**
*For any* Z-score value, the recommended breathing protocol should match the severity-based mapping (coherent for ≤-1.8, calming for ≤-2.0, intensive for ≤-2.5, emergency for ≤-3.0)
**Validates: Requirements 4.1**

**Property 8: Protocol Data Loading Integrity**
*For any* protocol key from the breathing specification, the system should successfully load protocol definitions with all required fields (name, instruction, phase_captions, emphasis)
**Validates: Requirements 4.2**

### Notification System Properties

**Property 9: Notification Content Formatting**
*For any* stress event with severity level, the notification should follow the format "NeuroYoga Stress Alert - [Severity Level]" and include protocol recommendation and scientific context
**Validates: Requirements 3.2, 4.3**

**Property 10: Notification Cooldown Management**
*For any* sequence of stress events, notifications should respect the configured cooldown period (default 3 hours) unless critical severity overrides the restriction
**Validates: Requirements 3.3, 6.2**

### Data Management Properties

**Property 11: Cross-Platform Data Normalization**
*For any* HRV reading from any supported platform (HealthKit, Health Connect, Google Fit), the normalized value should fall within the 0-1 range and maintain relative ordering
**Validates: Requirements 8.1**

**Property 12: Data Storage Encryption Integrity**
*For any* Shield data stored locally, the encryption and decryption process should preserve data integrity and maintain confidentiality using AES-256-GCM
**Validates: Requirements 8.3, 10.1**

### UI Integration Properties

**Property 13: Status Indicator Color Mapping**
*For any* Z-score value, the status indicator should display the correct color (green > -1.0, yellow -1.0 to -1.8, orange -1.8 to -2.5, red < -2.5) and corresponding status text
**Validates: Requirements 5.1**

**Property 14: Trend Analysis Data Accuracy**
*For any* collection of HRV readings over a week, the trend analysis should correctly calculate averages, event counts, and protocol usage statistics
**Validates: Requirements 5.2, 8.2**

### Configuration and Settings Properties

**Property 15: Feature Flag Functionality**
*For any* feature flag state (enabled/disabled), the system should correctly show or hide Shield functionality and provide appropriate fallback behavior
**Validates: Requirements 6.1, 9.1**

**Property 16: Settings Persistence and Validation**
*For any* valid Shield settings configuration, the system should persist the settings correctly and validate custom thresholds within acceptable ranges
**Validates: Requirements 6.3**

### Performance and Privacy Properties

**Property 17: On-Device Processing Guarantee**
*For any* HRV analysis operation, no biometric data should be transmitted over the network, ensuring 100% local processing
**Validates: Requirements 10.1**

**Property 18: Performance Constraint Compliance**
*For any* background analysis operation, the processing time should remain under 30 seconds on iOS and memory usage should stay below 50MB for 90 days of data
**Validates: Requirements 10.2, 10.3**

### Calendar Integration Properties

**Property 19: Calendar Event Context Integration**
*For any* calendar event marked as important, the system should correctly identify the event and adjust notification timing and priority accordingly
**Validates: Requirements 3.1**

### License and Premium Feature Properties

**Property 20: License Validation Accuracy**
*For any* license validation attempt, the system should correctly determine license validity, handle device binding, and provide appropriate access to premium features
**Validates: Requirements 9.2**

## Error Handling

### Comprehensive Error Management Strategy

**Health Data Access Errors**:
- **Permission Denied**: Graceful fallback to manual stress tracking mode
- **No Data Available**: Clear user guidance on enabling HRV data collection
- **Platform Unsupported**: Informative messaging about device limitations
- **Data Quality Issues**: Confidence scoring and user education

**Background Processing Errors**:
- **System Termination**: Automatic recovery and state restoration
- **Data Gaps**: Intelligent interpolation or degraded analysis mode
- **Platform Policy Changes**: Adaptive behavior and user notification
- **Hardware Limitations**: Alternative data sources and manual input options

**Storage and Encryption Errors**:
- **Storage Full**: Automatic cleanup with user notification
- **Encryption Failures**: Secure fallback and data recovery procedures
- **Database Corruption**: Rebuild capabilities with data integrity checks
- **Migration Errors**: Safe data migration with rollback capabilities

**Network and Connectivity Errors**:
- **Calendar Access Failures**: Graceful degradation without calendar context
- **Time Synchronization Issues**: Local time fallback for analysis
- **Platform API Changes**: Version compatibility and adaptation strategies

### Error Recovery Mechanisms

**Automatic Recovery**:
- **Background Task Recovery**: Restart monitoring after system kills
- **Data Consistency Checks**: Automatic validation and repair
- **Baseline Recalculation**: Rebuild baselines when data corruption detected
- **Settings Restoration**: Restore default settings if corruption detected

**User-Initiated Recovery**:
- **Manual Data Refresh**: Force reload of health data
- **Baseline Reset**: Recalculate baseline from scratch
- **Settings Reset**: Restore factory defaults
- **Data Export/Import**: User-controlled data portability

## Testing Strategy

### Comprehensive Testing Approach

**Unit Testing Focus**:
- **Mathematical Functions**: Z-score calculation, baseline computation, statistical analysis
- **Data Models**: Serialization, deserialization, validation
- **Error Handling**: Exception scenarios and recovery mechanisms
- **Platform Integration**: Mock health platform responses
- **UI Components**: Widget behavior and state management

**Property-Based Testing Focus**:
- **Statistical Accuracy**: Random data validation for all mathematical operations
- **Data Integrity**: Storage and retrieval consistency across all data types
- **Cross-Platform Consistency**: Behavior uniformity across iOS and Android
- **Performance Constraints**: Resource usage validation under various loads
- **Security Properties**: Encryption and privacy guarantee validation

**Integration Testing**:
- **End-to-End Workflows**: Complete stress detection and intervention cycles
- **Cross-Platform Data Migration**: Device switching scenarios
- **Background Processing**: Real-world background execution testing
- **Notification Delivery**: Complete notification pipeline testing
- **Health Platform Integration**: Real device testing with actual health data

**Performance Testing**:
- **Load Testing**: 90 days of HRV data processing
- **Memory Profiling**: Long-running analysis memory usage
- **Battery Impact**: Real-world battery drain measurement
- **Background Efficiency**: System resource usage monitoring

### Testing Configuration

**Property-Based Test Setup**:
```dart
// Example test configuration
@Property('Feature: atmo-shield, Property 1: Z-score calculation accuracy')
void testZScoreCalculationProperty() {
  forAll(
    tuple3(
      doubles(min: 10.0, max: 150.0), // HRV values
      doubles(min: 30.0, max: 80.0),  // Baseline mean  
      doubles(min: 5.0, max: 20.0),   // Baseline std
    ),
    (tuple) {
      final hrv = tuple.item1;
      final mean = tuple.item2;
      final std = tuple.item3;
      
      final zScore = ShieldAnalytics.calculateZScore(hrv, mean, std);
      final expectedZScore = (hrv - mean) / std;
      
      expect(zScore, closeTo(expectedZScore, 0.001));
    },
    iterations: 100,
  );
}
```

**Test Coverage Requirements**:
- **Unit Tests**: > 90% code coverage for core algorithms
- **Property Tests**: 100 iterations minimum per property
- **Integration Tests**: All major user workflows covered
- **Performance Tests**: All performance targets validated
- **Error Handling**: All error scenarios tested

**Continuous Testing Strategy**:
- **Automated Test Execution**: All tests run on every commit
- **Cross-Platform Testing**: Automated testing on iOS and Android
- **Performance Regression**: Automated performance benchmarking
- **Real Device Testing**: Regular testing on actual devices with health data
- **User Acceptance Testing**: Beta testing with real users and health scenarios

---

**Document Version**: 1.0  
**Last Updated**: January 27, 2025  
**Status**: Ready for Implementation  
**Next Phase**: Begin Proof of Concept (PoC) development focusing on background HRV data delivery validation