# Project Structure

## Current Structure
```
atmo-shield-premium/
├── .git/                 # Git repository
├── .kiro/               # Kiro AI assistant configuration
│   ├── steering/        # AI guidance documents
│   └── atmo-shield/     # Project specifications
│       └── requirements.md # Detailed requirements (v1.5.0)
├── .gitignore           # Git ignore patterns (Dart/Flutter)
└── README.md            # Project documentation
```

## Expected Flutter Health App Structure
Based on ATMO Shield requirements, the project will evolve to include:

```
atmo-shield-premium/
├── lib/                 # Main Flutter source code
│   ├── main.dart       # Application entry point
│   ├── models/         # Data models for HRV, stress events, baselines
│   │   ├── hrv_reading.dart
│   │   ├── baseline_data.dart
│   │   ├── stress_event.dart
│   │   └── trend_analysis.dart
│   ├── services/       # Business logic and health data integration
│   │   ├── hrv_service.dart
│   │   ├── stress_detection_service.dart
│   │   ├── notification_service.dart
│   │   └── health_data_service.dart
│   ├── widgets/        # UI components
│   │   ├── shield_dashboard.dart
│   │   ├── stress_indicator.dart
│   │   ├── trend_charts.dart
│   │   └── settings_panel.dart
│   ├── utils/          # Utility functions
│   │   ├── z_score_calculator.dart
│   │   ├── baseline_calculator.dart
│   │   └── data_normalizer.dart
│   └── native/         # Method channel interfaces
│       ├── ios_health_bridge.dart
│       └── android_health_bridge.dart
├── ios/                # iOS-specific native code
│   ├── Runner/
│   │   ├── Info.plist  # HealthKit permissions and background modes
│   │   └── ATMOShieldNative.swift # Native HealthKit processing
│   └── Runner.xcodeproj/
├── android/            # Android-specific native code
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml # Health Connect permissions
│   │   │   └── kotlin/.../ATMOShieldNative.kt # Native Health Connect processing
│   │   └── build.gradle
│   └── build.gradle
├── test/               # Test files mirroring lib/ structure
├── assets/             # Static assets (icons, images)
├── pubspec.yaml        # Project configuration and health-related dependencies
└── analysis_options.yaml # Dart analyzer configuration
```

## Architecture Patterns

### Hybrid Native-Flutter Architecture
Due to background processing limitations, ATMO Shield uses a hybrid approach:

- **Flutter Layer**: UI, settings, data visualization, user interactions
- **Native Layer**: Background health monitoring, HRV analysis, notifications
- **Method Channels**: Communication bridge between Flutter and native code

### Data Flow
```
Health Platform → Native Module → Local Storage → Flutter UI
     ↓                ↓              ↓             ↓
  HealthKit/      Background      Encrypted     Dashboard/
Health Connect    Processing      Hive DB       Analytics
```

## Conventions

### Dart/Flutter Conventions
- Follow Dart naming conventions (snake_case for files, camelCase for variables)
- Place main application logic in `lib/`
- Mirror `lib/` structure in `test/` for test files
- Use `pubspec.yaml` for dependency management

### Health Data Conventions
- All HRV data processing in native modules for performance
- Cross-platform data normalization for consistency
- Platform-specific baselines (HealthKit vs Health Connect)
- Local-only storage with encryption (privacy-first)

### File Naming Patterns
- Models: `*_model.dart` or `*.dart` (e.g., `hrv_reading.dart`)
- Services: `*_service.dart` (e.g., `stress_detection_service.dart`)
- Widgets: `*_widget.dart` or descriptive names (e.g., `shield_dashboard.dart`)
- Utils: `*_utils.dart` or `*_calculator.dart` for specific functions
- Native bridges: `*_bridge.dart` for Method Channel interfaces

### Directory Organization
- Keep health-related models together in `models/`
- Separate UI components by feature in `widgets/`
- Group related services in `services/`
- Platform-specific native code in respective `ios/` and `android/` directories