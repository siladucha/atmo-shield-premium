# Technology Stack

## Primary Technologies
- **Language**: Dart
- **Framework**: Flutter 3.0+
- **Package Manager**: pub (Dart's package manager)
- **Architecture**: Camera-based PPG signal processing

## Platform Requirements
- **iOS**: 13.0+ with camera and flash access
- **Android**: 8.0+ (API 26+) with camera and flash access
- **Camera**: Back camera with flash/torch mode support

## PPG Signal Processing
- **Technique**: Photoplethysmography (PPG) via smartphone camera
- **Signal Source**: Green channel from YUV420 camera frames
- **Sampling Rate**: ~24 FPS (adaptive based on device)
- **Metrics**: BPM (heart rate) and RMSSD (HRV measure)
- **Processing**: Real-time peak detection with adaptive thresholds

## Core Components

### Camera Service (`camera_service.dart`)
- YUV420 image stream processing
- ROI (Region of Interest) extraction (5% of sensor, 50-100px)
- Green channel intensity extraction
- Flash/torch management with overheating protection

### Signal Processor (`signal_processor.dart`)
- Band-pass filtering (DC removal + smoothing)
- Amplitude-based peak detection
- BPM calculation from inter-beat intervals
- RMSSD calculation with adaptive thresholds

### Quality Validator (`quality_validator.dart`)
- Real-time signal quality assessment (Poor/Fair/Good)
- Brightness and variance monitoring
- Movement detection via temporal stability
- User guidance messages

### Measurement Orchestrator (`measurement_orchestrator.dart`)
- Measurement lifecycle management
- State machine (idle → initializing → capturing → processing → complete/error)
- Timer coordination and progress tracking
- Result caching and error handling

## Build System
- Uses Dart's standard build tools
- Pub for dependency management
- Platform-specific camera permissions

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
```

## Build Artifacts
- `.dart_tool/` - Dart tooling cache
- `build/` - Compiled output
- `ios/` - iOS-specific configurations
- `android/` - Android-specific configurations

## Environment & Configuration
- Platform-specific Info.plist (iOS) and AndroidManifest.xml configurations
- Camera and flash permissions
- No external API keys or cloud services required

## Performance Targets
- Peak detection: < 50ms per frame
- Signal processing: < 200ms for full measurement
- UI response time: < 120ms
- Memory usage: < 30MB during measurement
- Battery impact: < 3% for 2-minute measurement

## Known Issues & Fixes Applied
- ✅ Standard deviation calculation corrected (was returning variance)
- ✅ Camera disposal race condition fixed with async/await
- ✅ UV plane bounds checking improved for iOS compatibility
- ✅ Peak detection threshold changed to amplitude-based (was percentile-based causing negative thresholds)
- ✅ Prominence threshold lowered to 15% (10% on retry) for better peak detection
- ✅ RMSSD thresholds made adaptive based on measurement duration
- ✅ BPM calculation returns null instead of throwing exceptions
- ✅ UI error state handling added with user-friendly retry dialog