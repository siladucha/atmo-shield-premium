# Project Structure

## Current Structure
```
atmo-shield-premium/
├── .git/                 # Git repository
├── .kiro/               # Kiro AI assistant configuration
│   ├── steering/        # AI guidance documents
│   └── specs/           # Project specifications
│       └── camera-hrv-measurement/
├── lib/                 # Main Flutter source code
│   ├── main.dart       # Application entry point
│   ├── models/         # Data models
│   │   ├── measurement_mode.dart
│   │   ├── measurement_result.dart
│   │   └── quality_level.dart
│   ├── services/       # Core PPG processing services
│   │   ├── camera_service.dart          # Camera & YUV processing
│   │   ├── signal_processor.dart        # Peak detection & HRV
│   │   ├── quality_validator.dart       # Signal quality assessment
│   │   └── measurement_orchestrator.dart # Measurement lifecycle
│   ├── screens/        # UI screens
│   │   ├── home_screen.dart
│   │   ├── measurement_screen.dart
│   │   └── results_screen_hrv.dart
│   └── utils/          # Utility functions
├── test/               # Test files
├── ios/                # iOS-specific configurations
├── android/            # Android-specific configurations
├── OLD_shield/         # Archived non-PPG related files
├── pubspec.yaml        # Project dependencies
└── README.md           # Project documentation
```

## Architecture Patterns

### PPG Signal Processing Pipeline
```
Camera → YUV Frame → Green Channel → Band-pass Filter → Peak Detection → BPM/RMSSD
   ↓         ↓            ↓              ↓                  ↓              ↓
Flash    ROI Extract  Intensity    DC Removal        Adaptive        Results
Enabled   (50-100px)   Mean        + Smoothing       Threshold       Display
```

### Data Flow
```
CameraService → SignalProcessor → MeasurementOrchestrator → UI
     ↓              ↓                    ↓                    ↓
  YUV frames    Peak indices        State machine      Real-time
  + metadata    + BPM/RMSSD         + caching          feedback
```

## Conventions

### Dart/Flutter Conventions
- Follow Dart naming conventions (snake_case for files, camelCase for variables)
- Place main application logic in `lib/`
- Mirror `lib/` structure in `test/` for test files
- Use `pubspec.yaml` for dependency management

### PPG Processing Conventions
- All signal processing in Dart (no native modules needed)
- Real-time quality feedback to user
- Adaptive thresholds based on signal characteristics
- Local-only storage with privacy-first approach

### File Naming Patterns
- Models: `*_model.dart` or `*.dart` (e.g., `measurement_result.dart`)
- Services: `*_service.dart` (e.g., `camera_service.dart`)
- Screens: `*_screen.dart` (e.g., `measurement_screen.dart`)
- Utils: `*_utils.dart` for utility functions

### Directory Organization
- Keep PPG-related models together in `models/`
- Separate UI components by feature in `screens/`
- Group related services in `services/`
- Platform-specific configurations in respective `ios/` and `android/` directories