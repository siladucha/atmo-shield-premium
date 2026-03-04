# Camera-Based HRV Measurement - POC

## Overview

This is a Proof of Concept (POC) for camera-based heart rate and HRV measurement using smartphone photoplethysmography (PPG). The app measures heart rate (BPM) and heart rate variability (RMSSD) through the phone's camera and flash LED.

## Features Implemented

### Sprint 1: Core Infrastructure ✅
- ✅ Flutter project setup with dependencies
- ✅ Data models (MeasurementMode, MeasurementResult, QualityLevel)
- ✅ Medical disclaimer screen
- ✅ Permission rationale screen
- ✅ Interactive tutorial (3 screens)
- ✅ Main screen with mode selection
- ✅ Last measurement display

### Sprint 2: Camera & Signal Processing ✅
- ✅ Camera integration with flash LED
- ✅ Green channel extraction from camera frames
- ✅ Moving average filter (simplified for MVP)
- ✅ Peak detection with adaptive threshold
- ✅ BPM calculation
- ✅ RMSSD calculation (HRV)

### Sprint 3: UI & Quality Feedback ✅
- ✅ Real-time camera preview with ROI overlay
- ✅ 3-level quality validation (poor/fair/good)
- ✅ Real-time quality indicator
- ✅ Live waveform visualization
- ✅ Breathing metronome (Accurate Mode)
- ✅ Results screen with interpretation
- ✅ Measurement orchestration

## Quick Start

### Prerequisites

- Flutter 3.38+ installed
- iOS 13+ device or Android 8+ device with camera and flash
- Xcode (for iOS) or Android Studio (for Android)

### Installation

1. **Clone and navigate to project:**
   ```bash
   cd atmo-shield-premium
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on device:**
   ```bash
   # iOS
   flutter run -d <ios-device-id>
   
   # Android
   flutter run -d <android-device-id>
   ```

   **Note:** Camera functionality requires a physical device. Emulators won't work.

### First Run

1. Accept medical disclaimer
2. Grant camera permission
3. Complete tutorial (or skip)
4. Select measurement mode:
   - **Quick Mode**: 30 seconds, heart rate only
   - **Accurate Mode**: 60 seconds, heart rate + HRV
5. Place finger gently on rear camera covering flash
6. Keep still during measurement
7. View results

## Architecture

```
lib/
├── models/                    # Data models
│   ├── measurement_mode.dart
│   ├── measurement_result.dart
│   └── quality_level.dart
├── services/                  # Business logic
│   ├── camera_service.dart           # Camera capture & frame processing
│   ├── signal_processor.dart         # Signal filtering & analysis
│   ├── quality_validator.dart        # Signal quality assessment
│   └── measurement_orchestrator.dart # Coordinates measurement flow
├── screens/                   # UI screens
│   ├── disclaimer_screen.dart
│   ├── permission_screen.dart
│   ├── tutorial_screen.dart
│   ├── main_screen.dart
│   ├── measurement_screen.dart
│   └── results_screen_hrv.dart
└── main.dart                  # App entry point
```

## How It Works

### 1. Camera Capture
- Uses `camera` plugin with `startImageStream`
- Captures frames at ~10 FPS (simplified for MVP)
- Flash LED illuminates fingertip
- Extracts green channel from YUV/BGRA frames

### 2. Signal Processing
- Calculates mean green intensity in ROI (100x100px centered)
- Applies moving average filter (window size 5)
- Detects peaks with adaptive threshold (mean + 20% amplitude)
- Enforces minimum peak separation (250ms = 240 BPM max)

### 3. Metrics Calculation
- **BPM**: 60000 / mean inter-beat interval
- **RMSSD**: sqrt(mean(successive_differences²))
- Validates ranges: BPM 30-220, RMSSD 10-150ms

### 4. Quality Assessment
- **Poor**: No finger detected or overpressure (variance < 2.0)
- **Fair**: Signal present but suboptimal (variance 2.0-5.0)
- **Good**: Strong signal (variance > 5.0)

## Testing

### Manual Testing Checklist

- [ ] Disclaimer acceptance persists across app restarts
- [ ] Camera permission request works on both platforms
- [ ] Tutorial can be skipped or completed
- [ ] Quick Mode (30s) completes successfully
- [ ] Accurate Mode (60s) completes successfully
- [ ] Breathing metronome animates smoothly
- [ ] Quality indicator updates in real-time
- [ ] Waveform displays live signal
- [ ] Results show BPM and RMSSD (Accurate Mode)
- [ ] Last measurement displays on main screen
- [ ] Cancel button stops measurement properly

### Known Limitations (MVP)

1. **Simplified filtering**: Moving average instead of Butterworth
2. **Low frame rate**: ~10 FPS instead of 30/60 FPS
3. **No artifact removal**: Advanced filtering not implemented
4. **No thermal management**: Device temperature not monitored
5. **No skin tone adaptation**: Fixed thresholds for all users
6. **No database**: Only last measurement stored in SharedPreferences
7. **No health sync**: HealthKit/Google Fit integration not implemented
8. **No export**: CSV/PDF export not available

## Validation Plan

### Phase 1: Technical Validation
- [ ] Test on 3+ devices (iOS + Android)
- [ ] Measure 20+ times per device
- [ ] Record simultaneous Polar H10 readings
- [ ] Calculate BPM correlation (target: ≥0.85)
- [ ] Calculate RMSSD correlation (target: ≥0.75)
- [ ] Document success rate (target: ≥60%)

### Phase 2: User Testing
- [ ] 5-10 test participants
- [ ] 3-5 measurements per participant
- [ ] Collect feedback on usability
- [ ] Identify common failure modes
- [ ] Document skin tone performance (Fitzpatrick I-VI)

## Next Steps (Post-POC)

If validation successful (BPM correlation ≥0.85, RMSSD ≥0.75):

1. **Implement Butterworth filter** for better signal quality
2. **Increase frame rate** to 30/60 FPS with native optimization
3. **Add artifact removal** with cubic spline interpolation
4. **Implement thermal management** to prevent overheating
5. **Add skin tone adaptation** for diverse users
6. **Implement SQLCipher database** for encrypted storage
7. **Add health platform sync** (HealthKit/Google Fit)
8. **Implement data export** (CSV/PDF)
9. **Add measurement history** with trend visualization
10. **Integrate into main ATMO Shield** app

## Troubleshooting

### Camera not working
- Ensure running on physical device (not emulator)
- Check camera permission granted
- Verify flash LED available on device
- Try restarting app

### Poor signal quality
- Ensure finger covers both camera and flash
- Adjust finger pressure (not too hard, not too light)
- Warm hands if cold
- Stay completely still
- Use in well-lit environment

### Measurement fails
- Check BPM/RMSSD out of valid range
- Ensure at least 30s (Quick) or 60s (Accurate) duration
- Verify sufficient peaks detected (minimum 2)
- Review quality indicator during measurement

## Technical Specifications

- **Platform**: Flutter 3.38+
- **Min iOS**: 13.0
- **Min Android**: 8.0 (API 26)
- **Camera**: Rear camera with flash LED required
- **Processing**: 100% on-device, no cloud
- **Storage**: SharedPreferences (last measurement only)
- **Dependencies**: camera, provider, permission_handler, shared_preferences

## License

Proprietary - ATMO Shield Premium

## Contact

For questions or issues, contact the development team.

---

**Medical Disclaimer**: This app is for wellness purposes only and is not intended to diagnose, treat, cure, or prevent any medical condition. Always consult healthcare professionals for medical concerns.
