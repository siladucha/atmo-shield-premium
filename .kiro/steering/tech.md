# Technology Stack

## Primary Technologies
- **Language**: Dart
- **Framework**: Flutter 3.0+
- **Package Manager**: pub (Dart's package manager)
- **Architecture**: Hybrid Native-Flutter for background health data processing

## Platform Requirements
- **iOS**: 16.0+ with HealthKit integration
- **Android**: 10+ (API 29+) with Health Connect support
- **Background Processing**: Native Swift/Kotlin modules (Flutter limitations)

## Health Data Integration
- **iOS**: HealthKit with HKObserverQuery for background delivery
- **Android**: Health Connect (primary), Google Fit (fallback for Android <14)
- **Data Types**: HRV (SDNN), Resting Heart Rate, Step Count, Sleep Analysis
- **Permissions**: Progressive permission requests with clear rationale

## Native Modules Required
Due to Flutter background processing limitations (~30 seconds), critical functionality requires native implementation:

### iOS Native (Swift)
```swift
class ATMOShieldNative {
    func setupHealthKitObserver() // HKObserverQuery setup
    func processHRVInBackground() // Z-score calculation
    func saveAnalysisResults()    // UserDefaults storage
    func scheduleNotification()   // Local notification trigger
}
```

### Android Native (Kotlin)
```kotlin
class ATMOShieldNative {
    fun setupHealthConnectObserver() // Health Connect monitoring
    fun processHRVInBackground()     // Analysis in native
    fun saveAnalysisResults()        // SharedPreferences storage
    fun scheduleNotification()       // Local notification trigger
}
```

## Build System
- Uses Dart's standard build tools
- Pub for dependency management
- Custom Method Channels for native health data processing
- Platform-specific entitlements and permissions

## Common Commands
```bash
# Get dependencies
dart pub get

# Run the application
flutter run

# Build for production
flutter build ios --release
flutter build appbundle --release

# Run tests
flutter test

# Analyze code
dart analyze

# Format code
dart format .

# Generate documentation
dart doc
```

## Build Artifacts
- `.dart_tool/` - Dart tooling cache
- `build/` - Compiled output
- `ios/` - iOS-specific native code and configurations
- `android/` - Android-specific native code and configurations

## Environment & Configuration
- Uses `.env` files for environment variables
- Platform-specific Info.plist (iOS) and AndroidManifest.xml configurations
- HealthKit and Health Connect entitlements
- Background processing capabilities

## Performance Targets
- Z-score calculation: < 100ms
- Background analysis: < 10 seconds total
- UI response time: < 120ms
- Memory usage: < 50MB for full dataset
- Battery impact: < 5% additional drain