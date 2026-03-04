# Design Document: Camera-Based HRV Measurement

## Introduction

This design document specifies the technical architecture, UI/UX screens, component specifications, and algorithms for the Camera-Based HRV Measurement application. It translates the 40 requirements from requirements.md into concrete implementation specifications.

The application uses a hybrid native-Flutter architecture where performance-critical camera capture and signal preprocessing occur in native code (Swift/Kotlin), while UI, visualization, and business logic are implemented in Flutter/Dart.

## Technology Stack

- **Framework**: Flutter 3.38+ (Dart) with Impeller renderer (default on Android API 29+)
- **Camera Capture**:
  - Primary path: official `camera` package (^0.10.6+) with `startImageStream`
  - Fallback/high-performance path: custom MethodChannel plugin (Swift AVFoundation + Kotlin Camera2) - auto-activated on FPS instability or thermal issues
- **Signal Processing**: Dart Isolate (primary) + optional native thread via FFI/MethodChannel when processing >16ms/frame
- **Database**: SQLCipher (AES-256 encrypted SQLite)
- **Health Integration**: health / health_kit packages
- **State Management**: Riverpod or Provider
- **Architecture Pattern**: Clean Architecture + plugin-first approach with fallback to custom native

## System Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│          Flutter UI Layer (Dart + Impeller)                  │
│          (stable 60-120 FPS UI/preview)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ UI_Controller│  │ Settings     │  │ History      │      │
│  │              │  │ Manager      │  │ Visualizer   │      │
│  └──────┬───────┘  └──────────────┘  └──────────────┘      │
│         │                                                     │
│  ┌──────▼──────────────────────────────────────────┐        │
│  │         Measurement Orchestrator                 │        │
│  └──────┬──────────────────────────────────────────┘        │
└─────────┼──────────────────────────────────────────────────┘
          │
┌─────────┼──────────────────────────────────────────────────┐
│         │      Camera Capture Strategy                      │
│  ┌──────▼──────────┐         ┌──────────────┐              │
│  │ camera plugin   │         │ Custom Native│              │
│  │ (primary path)  │ fallback│ Plugin       │              │
│  │ 30/60 fps stream│────────>│ Camera2/AVF  │              │
│  └──────┬──────────┘         └──────┬───────┘              │
│         │                           │                       │
│         └───────────┬───────────────┘                       │
│                     │                                       │
│         ┌───────────▼───────────┐                           │
│         │  Green Channel Extract│                           │
│         │  (Dart Isolate/Native)│                           │
│         └───────────┬───────────┘                           │
└─────────────────────┼───────────────────────────────────────┘
                      │ mean green intensity + timestamp
┌─────────────────────▼───────────────────────────────────────┐
│           Signal Processing Layer (Dart Isolate)             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Butterworth  │  │ Peak         │  │ HRV          │      │
│  │ Filter       │  │ Detector     │  │ Calculator   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Data & Storage Layer (Dart)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Storage      │  │ Health Sync  │  │ Quality      │      │
│  │ Manager      │  │ Service      │  │ Validator    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

**Flutter Layer (Dart):**
- UI_Controller: Screen navigation, user interactions, result display (60-120 FPS with Impeller)
- Measurement Orchestrator: Coordinates measurement flow, manages state, FPS monitoring
- Settings Manager: User preferences, app configuration
- History Visualizer: Trend graphs, measurement history display

**Camera Capture Strategy:**
- Primary: `camera` plugin with `startImageStream` (30/60 FPS)
- Fallback: Custom native plugin (auto-activated on performance issues)
- Auto-fallback to 30 FPS if average FPS <55 over 10 seconds
- Thermal monitoring via battery/thermal APIs where available

**Signal Processing Layer (Dart Isolate):**
- Butterworth Filter: 0.8-4.0 Hz bandpass filtering
- Peak Detector: Adaptive threshold peak detection
- HRV Calculator: RMSSD, SDNN calculation
- Fallback to native thread via FFI if processing >16ms/frame

**Data Layer (Dart):**
- Storage Manager: SQLCipher database, encryption, CRUD operations
- Health Sync Service: health/health_kit packages integration
- Quality Validator: 5-level signal quality assessment

**Camera Capture Implementation (v1.0 MVP):**
- Use `camera` plugin + `startImageStream` + Dart Isolate
- Auto-fallback to 30 FPS on thermal issues or FPS instability
- Pass only: mean green intensity, timestamp, optional variance
- Native plugin (v1.1+): opt-in/auto-fallback for Android mid-range devices

## UI/UX Screen Designs

### 1. Onboarding Flow

#### 1.1 Medical Disclaimer Screen
**Purpose**: Legal compliance (Requirement 25)

**Layout:**
```
┌─────────────────────────────────┐
│         [App Logo]              │
│                                 │
│    ATMO Camera HRV Tracker      │
│                                 │
│  ⚠️  Important Notice           │
│                                 │
│  This app is for wellness       │
│  purposes only. It is NOT a     │
│  medical device and should not  │
│  be used to diagnose or treat   │
│  any medical condition.         │
│                                 │
│  Always consult healthcare      │
│  professionals for medical      │
│  concerns.                      │
│                                 │
│  [ ] I understand and agree     │
│                                 │
│      [Continue Button]          │
│                                 │
└─────────────────────────────────┘
```

**Interactions:**
- Checkbox must be checked to enable Continue button
- Continue button navigates to Permission Rationale screen

#### 1.2 Permission Rationale Screen
**Purpose**: Camera permission explanation (Requirement 13)

**Layout:**
```
┌─────────────────────────────────┐
│         Camera Access           │
│                                 │
│     [Camera Icon Animation]     │
│                                 │
│  We need camera access to       │
│  measure your heart rate using  │
│  your fingertip.                │
│                                 │
│  How it works:                  │
│  • Place finger on camera       │
│  • Flash LED illuminates blood  │
│  • Camera detects pulse         │
│  • 100% on-device processing    │
│                                 │
│  Your privacy is protected:     │
│  ✓ No photos/videos saved       │
│  ✓ No data sent to servers      │
│                                 │
│      [Grant Permission]         │
│                                 │
└─────────────────────────────────┘
```

**Interactions:**
- Grant Permission triggers system camera permission dialog
- If denied, show troubleshooting steps
- If granted, navigate to Tutorial screen


#### 1.3 Interactive Tutorial Screen
**Purpose**: First-time user guidance (Requirement 13, 34)

**Layout:**
```
┌─────────────────────────────────┐
│    How to Measure (1/3)         │
│                                 │
│   [Animated Diagram:            │
│    Hand placing finger on       │
│    camera with gentle pressure] │
│                                 │
│  ✓ Place finger gently on       │
│    rear camera                  │
│                                 │
│  ✗ Don't press too hard         │
│    (blocks blood flow)          │
│                                 │
│  ✗ Don't press too lightly      │
│    (weak signal)                │
│                                 │
│      ●  ○  ○    [Next]          │
│                                 │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│    Measurement Modes (2/3)      │
│                                 │
│  ⚡ Quick Mode (30 sec)         │
│     • Heart rate only           │
│     • Fast results              │
│     • Good for quick checks     │
│                                 │
│  🎯 Accurate Mode (60 sec)      │
│     • Heart rate + HRV          │
│     • Breathing guidance        │
│     • Stress assessment         │
│                                 │
│      ○  ●  ○    [Next]          │
│                                 │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│    Best Practices (3/3)         │
│                                 │
│  [Icon] Sit comfortably         │
│  [Icon] Stay still              │
│  [Icon] Quiet environment       │
│  [Icon] Morning measurements    │
│         most consistent         │
│                                 │
│  Ready to try your first        │
│  measurement?                   │
│                                 │
│      ○  ○  ●    [Start]         │
│                                 │
└─────────────────────────────────┘
```

**Interactions:**
- Swipe or tap Next to advance
- Animated diagrams show correct/incorrect finger placement
- Start button launches guided first measurement
- Skip button available (navigates to Main screen)

### 2. Main Screen

**Purpose**: Mode selection and measurement initiation (Requirement 1)

**Layout:**
```
┌─────────────────────────────────┐
│  ☰                    ⚙️         │
│                                 │
│    ATMO Camera HRV              │
│                                 │
│  ┌─────────────────────────┐   │
│  │  ⚡ Quick Mode           │   │
│  │  30 seconds • HR only   │ ◉ │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  🎯 Accurate Mode        │   │
│  │  60 seconds • HR + HRV  │ ○ │
│  └─────────────────────────┘   │
│                                 │
│      [Large Measure Button]     │
│           with pulse            │
│           animation             │
│                                 │
│  Last Measurement:              │
│  72 BPM • 45ms RMSSD            │
│  Today at 9:30 AM               │
│  Quality: Good ⭐⭐⭐⭐          │
│                                 │
│  [View History]                 │
│                                 │
└─────────────────────────────────┘
```

**Interactions:**
- Tap mode cards to select (radio button behavior)
- Large Measure button starts measurement
- Last measurement card tappable (opens result details)
- Hamburger menu opens navigation drawer
- Settings icon opens Settings screen


### 3. Measurement Screen

**Purpose**: Real-time measurement with quality feedback (Requirements 2, 3, 7, 26, 27)

#### 3.1 Quick Mode Measurement

**Layout:**
```
┌─────────────────────────────────┐
│  [X Cancel]                     │
│                                 │
│  ┌─────────────────────────┐   │
│  │                         │   │
│  │   [Camera Preview       │   │
│  │    with finger overlay  │   │
│  │    showing ROI]         │   │
│  │                         │   │
│  └─────────────────────────┘   │
│                                 │
│  Signal Quality: ████░░ Good    │
│  (Color: Red/Yellow/Green)      │
│                                 │
│  [Real-time Waveform Graph]     │
│  ╱╲  ╱╲  ╱╲  ╱╲  ╱╲           │
│                                 │
│  Progress: ████████░░░░ 24s     │
│                                 │
│  💡 Keep finger steady          │
│                                 │
└─────────────────────────────────┘
```

#### 3.2 Accurate Mode Measurement

**Layout:**
```
┌─────────────────────────────────┐
│  [X Cancel]                     │
│                                 │
│  ┌─────────────────────────┐   │
│  │   [Camera Preview]      │   │
│  └─────────────────────────┘   │
│                                 │
│  Signal Quality: ████░░ Good    │
│                                 │
│  [Breathing Metronome]          │
│     ┌─────────────┐             │
│     │   Breathe   │             │
│     │      ●      │ (animated)  │
│     │   In: 4s    │             │
│     └─────────────┘             │
│                                 │
│  [Waveform] ╱╲  ╱╲  ╱╲         │
│                                 │
│  Progress: ████░░░░░░░░ 42s     │
│                                 │
└─────────────────────────────────┘
```

**Interactions:**
- Camera preview shows live finger placement
- Quality indicator updates every 1 second (Requirement 3.7)
- Colors: Red (poor), Yellow (fair), Green (good)
- Waveform updates at 10 FPS minimum (Requirement 26.2)
- Breathing metronome animates: expand (inhale 4s), contract (exhale 6s)
- Audio cues if enabled in settings
- Cancel button stops measurement immediately
- Progress bar shows elapsed/remaining time

**Quality Feedback Messages:**
- Level 1: "Place finger on camera"
- Level 2: "Reduce finger pressure"
- Level 3: "Press finger more firmly"
- Level 4: "Keep hand still"
- Level 5: "Good signal - keep steady"

### 4. Results Screen

**Purpose**: Display measurement results with interpretation (Requirements 8, 32)

**Layout:**
```
┌─────────────────────────────────┐
│  [< Back]              [Share]  │
│                                 │
│    Measurement Complete ✓       │
│                                 │
│  ┌─────────────────────────┐   │
│  │      Heart Rate         │   │
│  │         72              │   │
│  │        BPM              │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │         HRV             │   │
│  │        45 ms            │   │
│  │       RMSSD             │   │
│  │    Normal Range         │   │
│  └─────────────────────────┘   │
│                                 │
│  Quality Score: 87/100          │
│  ⭐⭐⭐⭐ Excellent              │
│                                 │
│  [Waveform Graph - Last 10s]    │
│  ╱╲  ╱╲  ╱╲  ╱╲  ╱╲           │
│  (peaks marked with dots)       │
│                                 │
│  Mode: Accurate • 60 seconds    │
│  Today at 9:30 AM               │
│                                 │
│  [Save]  [Retake]  [Discard]    │
│                                 │
└─────────────────────────────────┘
```

**Interactions:**
- BPM displayed as whole number (Requirement 8.2)
- RMSSD shown only for Accurate Mode
- Interpretation: Low (<20ms), Normal (20-100ms), High (>100ms)
- Quality score 0-100 with star rating
- Waveform shows last 10 seconds with detected peaks marked
- Save button stores to database and syncs to health platform
- Retake button starts new measurement
- Discard button returns to Main screen
- Share button opens system share sheet (export options)

**Quality Score Ranges:**
- 0-40: Poor (⭐)
- 41-60: Fair (⭐⭐)
- 61-80: Good (⭐⭐⭐)
- 81-100: Excellent (⭐⭐⭐⭐)


### 5. History Screen

**Purpose**: View past measurements and trends (Requirements 10, 37)

**Layout:**
```
┌─────────────────────────────────┐
│  [< Back]              [Export] │
│                                 │
│         Measurement History     │
│                                 │
│  [7 Days] [30 Days] [90 Days]   │
│                                 │
│  Average BPM: 71                │
│  Average RMSSD: 43 ms           │
│  Total Measurements: 24         │
│                                 │
│  [BPM Trend Graph]              │
│   80 ┤     ╱╲                   │
│   75 ┤    ╱  ╲  ╱╲              │
│   70 ┤───╱────╲╱──╲─────        │
│   65 ┤                           │
│      └─────────────────          │
│       Mon  Wed  Fri  Sun        │
│                                 │
│  [RMSSD Trend Graph]            │
│   50 ┤  ╱╲    ╱╲                │
│   40 ┤─╱──╲──╱──╲───            │
│   30 ┤      ╲╱                  │
│      └─────────────────          │
│                                 │
│  Recent Measurements:           │
│  ┌─────────────────────────┐   │
│  │ 72 BPM • 45ms           │   │
│  │ Today 9:30 AM  ⭐⭐⭐⭐   │ > │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ 68 BPM • 38ms           │   │
│  │ Yesterday 9:15 AM ⭐⭐⭐  │ > │
│  └─────────────────────────┘   │
│                                 │
│  [Load More]                    │
│                                 │
└─────────────────────────────────┘
```

**Interactions:**
- Time range tabs filter data (7/30/90 days)
- Trend graphs show BPM and RMSSD over time
- Tap measurement card to view full details
- Export button opens format selection (CSV/PDF)
- Swipe left on measurement to delete
- If <3 Accurate Mode measurements, show "Need more measurements for HRV trends"

### 6. Settings Screen

**Purpose**: App configuration and preferences (Requirements 14, 21)

**Layout:**
```
┌─────────────────────────────────┐
│  [< Back]                       │
│                                 │
│           Settings              │
│                                 │
│  Measurement                    │
│  ┌─────────────────────────┐   │
│  │ Default Mode            │ > │
│  │ Quick Mode              │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ Breathing Metronome     │   │
│  │ 6 breaths/min           │ > │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ Audio Breathing Cues    │ ◉ │
│  └─────────────────────────┘   │
│                                 │
│  Health Integration             │
│  ┌─────────────────────────┐   │
│  │ Sync to Apple Health    │ ◉ │
│  └─────────────────────────┘   │
│                                 │
│  Data Management                │
│  ┌─────────────────────────┐   │
│  │ Data Retention          │ > │
│  │ 90 days                 │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ Storage Used: 2.4 MB    │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ Clear All History       │   │
│  └─────────────────────────┘   │
│                                 │
│  General                        │
│  ┌─────────────────────────┐   │
│  │ Language                │ > │
│  │ English                 │   │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ Replay Tutorial         │   │
│  └─────────────────────────┘   │
│                                 │
│  About                          │
│  ┌─────────────────────────┐   │
│  │ Privacy Policy          │ > │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ Medical Disclaimer      │ > │
│  └─────────────────────────┘   │
│  ┌─────────────────────────┐   │
│  │ Version 1.0.0           │   │
│  └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

**Interactions:**
- Default Mode: Quick/Accurate selection
- Breathing Metronome: 4-10 breaths/min slider + disable option
- Audio Cues: Toggle on/off
- Health Sync: Toggle with permission request
- Data Retention: 30/90/365 days/Forever
- Clear History: Confirmation dialog
- Language: English/Russian selection
- All settings persist across sessions


## Component Architecture

### 1. UI_Controller (Flutter/Dart)

**Responsibilities:**
- Screen navigation and state management
- User input handling
- Result visualization
- Settings persistence

**Key Classes:**

```dart
class MeasurementScreen extends StatefulWidget {
  final MeasurementMode mode;
  // Manages measurement UI, quality feedback, progress
}

class ResultsScreen extends StatelessWidget {
  final MeasurementResult result;
  // Displays BPM, RMSSD, quality score, waveform
}

class HistoryScreen extends StatefulWidget {
  // Trend graphs, measurement list, filtering
}

class SettingsScreen extends StatefulWidget {
  // User preferences, health sync, data management
}
```

**State Management:**
- Provider or Riverpod for reactive state
- Measurement state: idle, capturing, processing, complete, error
- Quality state: level 1-5 with real-time updates

### 2. Measurement_Engine (Flutter + camera plugin)

**Responsibilities:**
- Camera initialization via `camera` plugin
- Frame stream management with `startImageStream`
- LED flash control
- Green channel extraction in Dart Isolate
- FPS and thermal monitoring
- Auto-fallback to native plugin if needed

**Primary Implementation (v1.0 MVP):**

```dart
class MeasurementEngine {
  CameraController? _cameraController;
  StreamSubscription<CameraImage>? _imageStreamSubscription;
  final _intensityController = StreamController<Map<String, dynamic>>();
  
  // Long-lived Isolate for frame processing
  Isolate? _processingIsolate;
  SendPort? _isolateSendPort;
  ReceivePort? _isolateReceivePort;
  
  // FPS monitoring
  int _frameCount = 0;
  DateTime _lastFpsCheck = DateTime.now();
  double _averageFps = 0.0;
  
  Future<void> start(MeasurementMode mode) async {
    try {
      // Initialize long-lived Isolate for processing
      await _initializeProcessingIsolate();
      
      // Primary: camera plugin
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      
      _cameraController = CameraController(
        backCamera,
        mode == MeasurementMode.accurate 
          ? ResolutionPreset.high 
          : ResolutionPreset.medium,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.torch);
      
      // Start image stream
      await _cameraController!.startImageStream(_processImage);
      
      // Monitor performance
      _monitorPerformance();
      
    } catch (e) {
      _handleCameraError(e);
      // Fallback to native plugin if camera plugin fails
      await _switchToNativeFallback(mode);
    }
  }
  
  Future<void> _initializeProcessingIsolate() async {
    _isolateReceivePort = ReceivePort();
    _processingIsolate = await Isolate.spawn(
      _processingIsolateEntry,
      _isolateReceivePort!.sendPort,
    );
    
    // Get SendPort from Isolate
    _isolateSendPort = await _isolateReceivePort!.first as SendPort;
    
    // Listen for processed results
    _isolateReceivePort!.listen((message) {
      if (message is Map<String, dynamic>) {
        _intensityController.add(message);
      }
    });
  }
  
  static void _processingIsolateEntry(SendPort mainSendPort) {
    final isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);
    
    isolateReceivePort.listen((message) {
      if (message is CameraImage) {
        try {
          final result = _extractGreenMean(message);
          mainSendPort.send(result);
        } catch (e) {
          mainSendPort.send({'error': e.toString()});
        }
      }
    });
  }
  
  void _processImage(CameraImage image) {
    _frameCount++;
    
    // Send to long-lived Isolate for processing
    try {
      _isolateSendPort?.send(image);
    } catch (e) {
      _handleProcessingError(e);
    }
  }
  
  void _handleCameraError(dynamic error) {
    print('Camera error: $error');
    // Log error, notify user, attempt recovery
  }
  
  void _handleProcessingError(dynamic error) {
    print('Processing error: $error');
    // Consider switching to native fallback
  }
  
  void _monitorPerformance() {
    Timer.periodic(Duration(seconds: 10), (timer) {
      final now = DateTime.now();
      final elapsed = now.difference(_lastFpsCheck).inMilliseconds;
      _averageFps = (_frameCount * 1000.0) / elapsed;
      
      // Auto-fallback if FPS drops below 55
      if (_averageFps < 55 && _cameraController != null) {
        _switchToNativeFallback(currentMode);
      }
      
      _frameCount = 0;
      _lastFpsCheck = now;
    });
  }
  
  Future<void> _switchToNativeFallback(MeasurementMode mode) async {
    // Stop camera plugin
    await _cameraController?.dispose();
    _processingIsolate?.kill(priority: Isolate.immediate);
    _isolateReceivePort?.close();
    
    // Call native via MethodChannel
    try {
      await platform.invokeMethod('startNativeCapture', {
        'fps': mode == MeasurementMode.accurate ? 60 : 30,
        'roiSize': 100,
      });
    } catch (e) {
      _handleCameraError(e);
    }
  }
  
  void dispose() {
    _cameraController?.dispose();
    _imageStreamSubscription?.cancel();
    _intensityController.close();
    _processingIsolate?.kill(priority: Isolate.immediate);
    _isolateReceivePort?.close();
  }
}

// Isolate function for green channel extraction
Future<Map<String, dynamic>> _extractGreenMean(CameraImage image) async {
  // Extract green channel from YUV or RGB
  // Calculate ROI (100x100 px centered)
  // Return mean green intensity
  
  final greenChannel = _extractGreenChannel(image);
  final roi = _extractROI(greenChannel, image.width, image.height);
  final meanGreen = _calculateMean(roi);
  final variance = _calculateVariance(roi);
  
  return {
    'meanGreen': meanGreen,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'variance': variance,
  };
}

List<int> _extractGreenChannel(CameraImage image) {
  // Handle YUV420 (Android) or BGRA (iOS)
  if (image.format.group == ImageFormatGroup.yuv420) {
    // YUV to RGB conversion, extract green
    return _yuv420ToGreen(image);
  } else if (image.format.group == ImageFormatGroup.bgra8888) {
    // BGRA, extract green channel (index 1)
    return _bgra8888ToGreen(image);
  }
  throw UnsupportedError('Unsupported image format');
}

List<int> _extractROI(List<int> greenChannel, int width, int height) {
  // Extract ROI: 5% of sensor width, clamped to 80-150px (Requirement 2.4)
  final roiSize = (width * 0.05).round().clamp(80, 150);
  final startX = (width - roiSize) ~/ 2;
  final startY = (height - roiSize) ~/ 2;
  
  List<int> roi = [];
  for (int y = startY; y < startY + roiSize; y++) {
    for (int x = startX; x < startX + roiSize; x++) {
      roi.add(greenChannel[y * width + x]);
    }
  }
  return roi;
}

double _calculateMean(List<int> values) {
  return values.reduce((a, b) => a + b) / values.length;
}

double _calculateVariance(List<int> values) {
  double mean = _calculateMean(values);
  double variance = values.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / values.length;
  return variance;
}
```

**Native Fallback Plugin (v1.1+):**

Only implemented if performance issues detected. Handles:
- Camera2 API (Android) / AVFoundation (iOS)
- Torch control
- ROI crop (100×100 px)
- Mean green calculation
- Passes only: intensity, timestamp, variance to Dart


### 3. Signal_Processor (Dart Isolate)

**Responsibilities:**
- Butterworth bandpass filtering
- Peak detection with adaptive thresholding
- HRV metric calculation (RMSSD, SDNN)
- Artifact removal

**Implementation:**
- Primary: Dart Isolate for cross-platform consistency
- Fallback: Native thread via FFI if processing >16ms/frame
- Isolate minimizes memory copying for small datasets (<2000 samples)

**Key Classes:**

```dart
class SignalProcessor {
  List<double> rawSignal = [];
  List<double> filteredSignal = [];
  List<int> peakIndices = [];
  
  // Butterworth filter implementation
  List<double> applyButterworthFilter(List<double> signal) {
    // 4th order Butterworth bandpass 0.8-4.0 Hz
    // Zero-phase filtering (filtfilt equivalent)
    // Returns filtered signal
  }
  
  // Peak detection
  List<int> detectPeaks(List<double> signal, double threshold) {
    // Adaptive threshold at 60% of amplitude range
    // Minimum separation 250ms (240 BPM max)
    // Parabolic interpolation for sub-sample accuracy
    // Returns peak indices
  }
  
  // Artifact removal
  List<double> removeArtifacts(List<double> signal) {
    // Detect values >3 SD from mean
    // Cubic spline interpolation for missing values
    // Returns cleaned signal
  }
  
  // HRV calculation
  HRVMetrics calculateHRV(List<int> peakIndices, int samplingRate) {
    // Calculate inter-beat intervals (IBI)
    // RMSSD = sqrt(mean(diff(IBI)^2))
    // SDNN = std(IBI)
    // Validate ranges: RMSSD 10-150ms, SDNN 10-200ms
    // Returns HRVMetrics object
  }
}
```

**Butterworth Filter Algorithm:**

```dart
class ButterworthFilter {
  // Design 4th order Butterworth bandpass filter
  // Passband: 0.8-4.0 Hz (48-240 BPM)
  // Sampling rate: 30 or 60 Hz
  
  List<double> _forwardFilter(List<double> signal, List<double> b, List<double> a) {
    // Forward pass using difference equation
  }
  
  List<double> _backwardFilter(List<double> signal, List<double> b, List<double> a) {
    // Backward pass for zero-phase
  }
  
  List<double> filtfilt(List<double> signal) {
    // Zero-phase filtering: forward then backward
    return _backwardFilter(_forwardFilter(signal, b, a), b, a);
  }
}
```

**Peak Detection Algorithm:**

```dart
class PeakDetector {
  List<int> detectPeaks(List<double> signal, int samplingRate) {
    // 1. Calculate adaptive threshold
    double amplitude = signal.reduce(max) - signal.reduce(min);
    double threshold = signal.reduce(min) + (amplitude * 0.6);
    
    // 2. Find peaks above threshold
    int minSeparation = (samplingRate * 0.25).round(); // 250ms
    List<int> peaks = [];
    
    for (int i = 1; i < signal.length - 1; i++) {
      if (signal[i] > threshold &&
          signal[i] > signal[i-1] &&
          signal[i] > signal[i+1]) {
        // Check minimum separation
        if (peaks.isEmpty || (i - peaks.last) >= minSeparation) {
          // Parabolic interpolation for sub-sample accuracy
          double refinedPeak = _parabolicInterpolation(signal, i);
          peaks.add(refinedPeak.round());
        }
      }
    }
    
    return peaks;
  }
  
  double _parabolicInterpolation(List<double> signal, int index) {
    // Fit parabola to 3 points around peak
    double y1 = signal[index - 1];
    double y2 = signal[index];
    double y3 = signal[index + 1];
    
    double offset = 0.5 * (y1 - y3) / (y1 - 2*y2 + y3);
    return index + offset;
  }
}
```

**HRV Calculation:**

```dart
class HRVCalculator {
  HRVMetrics calculate(List<int> peakIndices, int samplingRate) {
    // 1. Calculate inter-beat intervals (IBI) in milliseconds
    List<double> ibis = [];
    for (int i = 1; i < peakIndices.length; i++) {
      double ibi = (peakIndices[i] - peakIndices[i-1]) * 1000.0 / samplingRate;
      ibis.add(ibi);
    }
    
    // 2. Calculate BPM
    double meanIBI = ibis.reduce((a, b) => a + b) / ibis.length;
    int bpm = (60000 / meanIBI).round();
    
    // Validate BPM range: 30-220
    if (bpm < 30 || bpm > 220) {
      throw InvalidMeasurementException('BPM out of valid range');
    }
    
    // 3. Calculate RMSSD
    List<double> successiveDiffs = [];
    for (int i = 1; i < ibis.length; i++) {
      successiveDiffs.add(ibis[i] - ibis[i-1]);
    }
    double sumSquaredDiffs = successiveDiffs.map((d) => d * d).reduce((a, b) => a + b);
    double rmssd = sqrt(sumSquaredDiffs / successiveDiffs.length);
    
    // Validate RMSSD range: 10-150ms
    if (rmssd < 10 || rmssd > 150) {
      throw InvalidMeasurementException('RMSSD out of valid range');
    }
    
    // 4. Calculate SDNN
    double meanIBIForSDNN = ibis.reduce((a, b) => a + b) / ibis.length;
    double variance = ibis.map((ibi) => pow(ibi - meanIBIForSDNN, 2)).reduce((a, b) => a + b) / ibis.length;
    double sdnn = sqrt(variance);
    
    // Validate SDNN range: 10-200ms
    if (sdnn < 10 || sdnn > 200) {
      throw InvalidMeasurementException('SDNN out of valid range');
    }
    
    return HRVMetrics(
      bpm: bpm,
      rmssd: rmssd,
      sdnn: sdnn,
      meanIBI: meanIBI,
    );
  }
}
```


### 4. Quality_Validator (Dart)

**Responsibilities:**
- 5-level signal quality assessment
- Real-time quality feedback
- Adaptive threshold calibration
- Skin tone detection and adjustment

**Implementation:**

```dart
enum QualityLevel {
  noFinger,      // Level 1
  overpressure,  // Level 2
  weakFlow,      // Level 3
  movement,      // Level 4
  goodSignal,    // Level 5
}

class QualityValidator {
  // User-specific adaptive baselines
  double? brightnessBaseline;
  double? varianceBaseline;
  Map<String, double>? colorRatioBaselines;
  
  // Skin tone calibration
  SkinToneProfile? skinToneProfile;
  
  QualityLevel assessQuality(
    List<double> recentSignal,
    double currentBrightness,
    Map<String, double> colorChannels,
    double accelerometerMagnitude,
  ) {
    // Level 1: No finger detected
    if (_isNoFinger(currentBrightness)) {
      return QualityLevel.noFinger;
    }
    
    // Level 2: Overpressure
    if (_isOverpressure(currentBrightness, recentSignal)) {
      return QualityLevel.overpressure;
    }
    
    // Level 3: Weak blood flow
    if (_isWeakFlow(colorChannels)) {
      return QualityLevel.weakFlow;
    }
    
    // Level 4: Movement detected
    if (_isMovement(recentSignal, accelerometerMagnitude)) {
      return QualityLevel.movement;
    }
    
    // Level 5: Good signal
    if (_isGoodSignal(recentSignal)) {
      return QualityLevel.goodSignal;
    }
    
    return QualityLevel.weakFlow; // Default to level 3
  }
  
  bool _isNoFinger(double brightness) {
    double baseline = brightnessBaseline ?? 128.0; // Default mid-range
    return brightness < (baseline * 0.20) || brightness > (baseline * 0.80);
  }
  
  bool _isOverpressure(double brightness, List<double> signal) {
    double baseline = brightnessBaseline ?? 128.0;
    double variance = _calculateVariance(signal);
    return brightness > (baseline * 0.75) && variance < 2.0;
  }
  
  bool _isWeakFlow(Map<String, double> colorChannels) {
    double redGreenRatio = colorChannels['red']! / colorChannels['green']!;
    double blueGreenRatio = colorChannels['blue']! / colorChannels['green']!;
    return redGreenRatio < 0.6 || blueGreenRatio < 0.5;
  }
  
  bool _isMovement(List<double> signal, double accelMagnitude) {
    double variance = _calculateVariance(signal);
    return variance > 15.0 || accelMagnitude > 0.5;
  }
  
  bool _isGoodSignal(List<double> signal) {
    if (signal.length < 60) return false;
    
    // Calculate autocorrelation at detected heart rate period
    double autocorr = _calculateAutocorrelation(signal);
    return autocorr > 0.3;
  }
  
  double _calculateVariance(List<double> signal) {
    double mean = signal.reduce((a, b) => a + b) / signal.length;
    double variance = signal.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / signal.length;
    return variance;
  }
  
  double _calculateAutocorrelation(List<double> signal) {
    // Simplified autocorrelation at adaptive lag
    // Lag corresponds to detected heart rate period
    int estimatedBPM = 70; // Initial estimate
    int lag = (60.0 / estimatedBPM * samplingRate).round();
    
    double sum = 0.0;
    for (int i = 0; i < signal.length - lag; i++) {
      sum += signal[i] * signal[i + lag];
    }
    return sum / (signal.length - lag);
  }
  
  // Adaptive calibration after successful measurements
  void updateBaselines(MeasurementResult result) {
    if (brightnessBaseline == null) {
      brightnessBaseline = result.averageBrightness;
      varianceBaseline = result.signalVariance;
    } else {
      // Exponential moving average
      brightnessBaseline = brightnessBaseline! * 0.8 + result.averageBrightness * 0.2;
      varianceBaseline = varianceBaseline! * 0.8 + result.signalVariance * 0.2;
    }
  }
  
  // Skin tone adaptive calibration (Requirement 16A)
  void detectAndCalibrateSkinTone(
    double signalAmplitude,
    Map<String, double> colorChannels,
  ) {
    // Detect Fitzpatrick category based on signal characteristics
    double redGreenRatio = colorChannels['red']! / colorChannels['green']!;
    
    if (signalAmplitude < 10.0 && redGreenRatio < 0.7) {
      // Likely Fitzpatrick IV-VI (darker skin)
      skinToneProfile = SkinToneProfile(
        category: FitzpatrickCategory.darkSkin,
        ledIntensityMultiplier: 1.3, // +30% LED intensity
        gainCompensation: 1.2,
        snrThresholdAdjustment: 0.8, // Lower SNR threshold
      );
    } else {
      // Fitzpatrick I-III (lighter skin)
      skinToneProfile = SkinToneProfile(
        category: FitzpatrickCategory.lightSkin,
        ledIntensityMultiplier: 1.0,
        gainCompensation: 1.0,
        snrThresholdAdjustment: 1.0,
      );
    }
  }
}

class SkinToneProfile {
  final FitzpatrickCategory category;
  final double ledIntensityMultiplier;
  final double gainCompensation;
  final double snrThresholdAdjustment;
  
  SkinToneProfile({
    required this.category,
    required this.ledIntensityMultiplier,
    required this.gainCompensation,
    required this.snrThresholdAdjustment,
  });
}

enum FitzpatrickCategory {
  lightSkin,  // I-III
  darkSkin,   // IV-VI
}
```

**Quality Score Calculation (Requirement 32):**

```dart
class QualityScoreCalculator {
  int calculateScore(MeasurementResult result) {
    // Formula: (SNR × 0.4) + (confidence × 0.3) + ((100 - artifacts%) × 0.3)
    
    double snrScore = _calculateSNRScore(result.signalToNoiseRatio);
    double confidenceScore = result.peakDetectionConfidence * 100;
    double artifactScore = 100 - result.artifactPercentage;
    
    double totalScore = (snrScore * 0.4) + (confidenceScore * 0.3) + (artifactScore * 0.3);
    
    return totalScore.round().clamp(0, 100);
  }
  
  double _calculateSNRScore(double snr) {
    // Map SNR to 0-100 scale
    // Typical good SNR: >10 dB
    // Excellent SNR: >20 dB
    if (snr >= 20) return 100;
    if (snr <= 5) return 0;
    return ((snr - 5) / 15) * 100;
  }
  
  String getQualityLabel(int score) {
    if (score >= 81) return 'Excellent';
    if (score >= 61) return 'Good';
    if (score >= 41) return 'Fair';
    return 'Poor';
  }
  
  int getStarRating(int score) {
    if (score >= 81) return 4;
    if (score >= 61) return 3;
    if (score >= 41) return 2;
    return 1;
  }
}
```



## Performance Targets

### Frame Rate and UI Performance
- **Target**: 55-60 FPS preview + waveform on 90%+ devices in release mode
- **Android mid-range**: Fallback to 30 FPS acceptable with torch + extended sessions
- **UI rendering**: 60-120 FPS with Impeller renderer (Flutter 3.38+)

### Battery and Thermal
- **Battery drain**: ≤1.5-2% per 60-second Accurate Mode measurement
- **Temperature increase**: ≤8-10°C per measurement session
- **Cooldown**: Only when thermal threshold exceeded (not every measurement)

### Processing Performance
- **Signal processing**: <16ms per frame (Dart Isolate target)
- **Result calculation**: <2 seconds after measurement completion
- **Database operations**: <100ms for queries

### Memory Usage
- **Active measurement**: <100 MB RAM
- **Background**: <50 MB RAM
- **Storage**: ~2-5 MB per 100 measurements

### Test Devices (Release Mode)
- Pixel 9 (Android 15)
- iPhone 16 (iOS 18)
- Samsung Galaxy A55 (mid-range Android)
- Redmi Note 14 Pro (mid-range Android)
- Poco X7 (budget Android)

## Development Roadmap

### v1.0 (MVP) - Camera PPG Foundation
**Focus**: Stable camera capture with Flutter plugin

**Features:**
- `camera` plugin + `startImageStream` implementation
- Dart Isolate for signal processing
- Auto-fallback to 30 FPS on performance issues
- Quick Mode (30s, BPM only)
- Accurate Mode (60s, BPM + RMSSD)
- Basic quality validation (5 levels)
- SQLCipher encrypted storage
- Health platform sync (HealthKit/Google Fit)

**Performance:**
- Target 55+ FPS on 80% devices
- Graceful degradation to 30 FPS

**Timeline**: 8-10 weeks

### v1.1 - Native Fallback Plugin
**Focus**: Performance optimization for Android mid-range

**Features:**
- Custom native plugin (Camera2/AVFoundation)
- Auto-activation on FPS instability or thermal issues
- Optimized green channel extraction in native code
- Minimal data transfer (intensity + timestamp only)

**Performance:**
- Target 55+ FPS on 90% devices
- Improved battery efficiency

**Timeline**: +3-4 weeks

### v1.2 - Adaptive Calibration
**Focus**: Accuracy improvements for diverse users

**Features:**
- Dynamic torch strength adjustment
- Skin tone detection and LED compensation (Fitzpatrick IV-VI)
- Adaptive ROI sizing based on signal quality
- User-specific baseline calibration

**Performance:**
- ≤20% error for dark skin tones
- ≤15% error for light skin tones

**Timeline**: +2-3 weeks

### v1.3 - Advanced Features
**Focus**: Enhanced user experience

**Features:**
- Trend analysis and predictions
- Export to PDF with graphs
- Comparative analysis (side-by-side measurements)
- Weekly/monthly summary reports

**Timeline**: +3-4 weeks

## Data Models

### MeasurementResult

```dart
class MeasurementResult {
  final String id;
  final DateTime timestamp;
  final MeasurementMode mode;
  
  // Metrics
  final int bpm;
  final double? rmssd;  // null for Quick Mode
  final double? sdnn;   // null for Quick Mode
  
  // Quality
  final int qualityScore;  // 0-100
  final QualityLevel qualityLevel;
  final double signalToNoiseRatio;
  final double peakDetectionConfidence;
  final double artifactPercentage;
  
  // Signal data
  final List<double> rawSignal;
  final List<double> filteredSignal;
  final List<int> peakIndices;
  
  // Metadata
  final double averageBrightness;
  final double signalVariance;
  final Map<String, double> colorChannels;
  final int duration;  // seconds
  
  MeasurementResult({
    required this.id,
    required this.timestamp,
    required this.mode,
    required this.bpm,
    this.rmssd,
    this.sdnn,
    required this.qualityScore,
    required this.qualityLevel,
    required this.signalToNoiseRatio,
    required this.peakDetectionConfidence,
    required this.artifactPercentage,
    required this.rawSignal,
    required this.filteredSignal,
    required this.peakIndices,
    required this.averageBrightness,
    required this.signalVariance,
    required this.colorChannels,
    required this.duration,
  });
  
  // Interpretation helpers
  String get rmssdInterpretation {
    if (rmssd == null) return 'N/A';
    if (rmssd! < 20) return 'Low';
    if (rmssd! > 100) return 'High';
    return 'Normal';
  }
  
  String get qualityLabel {
    if (qualityScore >= 81) return 'Excellent';
    if (qualityScore >= 61) return 'Good';
    if (qualityScore >= 41) return 'Fair';
    return 'Poor';
  }
  
  int get starRating {
    if (qualityScore >= 81) return 4;
    if (qualityScore >= 61) return 3;
    if (qualityScore >= 41) return 2;
    return 1;
  }
}
```

### UserPreferences

```dart
class UserPreferences {
  final MeasurementMode defaultMode;
  final bool healthSyncEnabled;
  final bool audioBreathingCues;
  final int breathingRate;  // 4-10 breaths/min
  final String language;  // 'en' or 'ru'
  final int dataRetentionDays;  // 30, 90, 365, or -1 (forever)
  
  UserPreferences({
    this.defaultMode = MeasurementMode.quick,
    this.healthSyncEnabled = false,
    this.audioBreathingCues = true,
    this.breathingRate = 6,
    this.language = 'en',
    this.dataRetentionDays = 90,
  });
}
```

### AdaptiveBaseline

```dart
class AdaptiveBaseline {
  final double brightnessBaseline;
  final double varianceBaseline;
  final Map<String, double> colorRatioBaselines;
  final SkinToneProfile? skinToneProfile;
  final int measurementCount;
  final DateTime lastUpdated;
  
  AdaptiveBaseline({
    required this.brightnessBaseline,
    required this.varianceBaseline,
    required this.colorRatioBaselines,
    this.skinToneProfile,
    required this.measurementCount,
    required this.lastUpdated,
  });
  
  // Update baselines with exponential moving average
  AdaptiveBaseline update(MeasurementResult result) {
    return AdaptiveBaseline(
      brightnessBaseline: brightnessBaseline * 0.8 + result.averageBrightness * 0.2,
      varianceBaseline: varianceBaseline * 0.8 + result.signalVariance * 0.2,
      colorRatioBaselines: _updateColorRatios(result.colorChannels),
      skinToneProfile: skinToneProfile,
      measurementCount: measurementCount + 1,
      lastUpdated: DateTime.now(),
    );
  }
}
```



## MVP Scope (Proof of Concept)

### Goal
Validate core PPG measurement technology and HRV calculation accuracy. This is a standalone proof-of-concept app, NOT the final ATMO Shield integration.

### MVP Features (Must Have)

**Core Measurement:**
- ✅ Quick Mode only (30s, BPM measurement)
- ✅ Accurate Mode (60s, BPM + RMSSD)
- ✅ camera plugin with startImageStream (no native fallback)
- ✅ Dart Isolate signal processing
- ✅ Real-time quality feedback (5 levels)
- ✅ Breathing metronome for Accurate Mode

**UI Screens:**
- ✅ Medical disclaimer (one-time)
- ✅ Simple tutorial (3 screens)
- ✅ Main screen (mode selection + measure button)
- ✅ Measurement screen (camera preview, quality indicator, waveform)
- ✅ Results screen (BPM, RMSSD, quality score, save/discard)

**Data Storage:**
- ✅ Local SQLite (no encryption for MVP)
- ✅ Basic measurement history (list view only)
- ✅ No trend graphs, no export

**Validation:**
- ✅ Manual testing with Polar H10 reference device
- ✅ 5-10 test participants
- ✅ Correlation analysis (BPM and RMSSD vs reference)

### MVP Exclusions (Out of Scope)

**NOT in MVP:**
- ❌ Native fallback plugin (v1.1 feature)
- ❌ SQLCipher encryption (use plain SQLite)
- ❌ Health platform sync (HealthKit/Google Fit)
- ❌ Trend graphs and analytics
- ❌ Data export (CSV/PDF)
- ❌ Skin tone adaptive calibration
- ❌ Adaptive baseline calibration
- ❌ Multi-language support (English only)
- ❌ Settings screen (hardcoded defaults)
- ❌ Thermal management (basic only)
- ❌ Beta telemetry
- ❌ Comparison features

### MVP Technical Simplifications

**Camera Capture:**
```dart
// Simplified - no FPS monitoring, no fallback
Future<void> start(MeasurementMode mode) async {
  final cameras = await availableCameras();
  final backCamera = cameras.firstWhere(
    (c) => c.lensDirection == CameraLensDirection.back,
  );
  
  _cameraController = CameraController(
    backCamera,
    ResolutionPreset.medium, // Always medium for MVP
    enableAudio: false,
  );
  
  await _cameraController!.initialize();
  await _cameraController!.setFlashMode(FlashMode.torch);
  await _cameraController!.startImageStream(_processImage);
}
```

**Signal Processing:**
```dart
// Simplified - basic filtering only
class SignalProcessor {
  List<double> applyBasicFilter(List<double> signal) {
    // Simple moving average instead of Butterworth for MVP
    return _movingAverage(signal, windowSize: 5);
  }
  
  List<int> detectPeaks(List<double> signal) {
    // Simple threshold without parabolic interpolation
    double threshold = _calculateMean(signal) * 1.2;
    return _findPeaksAboveThreshold(signal, threshold);
  }
}
```

**Quality Validation:**
```dart
// Simplified - 3 levels instead of 5
enum QualityLevel {
  poor,    // Red - no finger or bad signal
  fair,    // Yellow - acceptable but not ideal
  good,    // Green - good signal quality
}
```

**Data Model:**
```dart
// Minimal for MVP
class MeasurementResult {
  final String id;
  final DateTime timestamp;
  final MeasurementMode mode;
  final int bpm;
  final double? rmssd;
  final QualityLevel quality;
  
  // No waveform storage, no detailed metrics
}
```

### MVP Success Criteria

**Technical Validation:**
- BPM correlation ≥0.85 vs Polar H10 (relaxed from 0.90)
- RMSSD correlation ≥0.75 vs Polar H10 (relaxed from 0.85)
- Successful measurement rate ≥60% (relaxed from 70%)
- Works on 3+ test devices (iOS + Android)

**User Experience:**
- First measurement completed within 2 minutes of app launch
- Clear quality feedback during measurement
- Results displayed within 3 seconds

**Decision Point:**
- If validation successful → proceed with full ATMO Shield integration
- If validation fails → iterate on signal processing algorithms

### MVP Timeline

**Week 1-2: Core Infrastructure**
- Flutter project setup
- Camera integration with camera plugin
- Basic UI screens (disclaimer, main, measurement)

**Week 3-4: Signal Processing**
- Green channel extraction
- Basic filtering (moving average)
- Peak detection
- BPM calculation
- RMSSD calculation

**Week 5-6: Quality & UX**
- Quality validation (3 levels)
- Real-time feedback
- Breathing metronome
- Results screen
- Basic history

**Week 7-8: Validation**
- Polar H10 comparison testing
- 5-10 participants
- Data analysis
- Bug fixes

**Total: 8 weeks for MVP**

### Post-MVP: Full Integration Path

After MVP validation, full ATMO Shield integration will include:
1. Native performance optimizations
2. SQLCipher encryption
3. Health platform sync
4. Advanced analytics and trends
5. Skin tone calibration
6. Multi-language support
7. Premium features (stress detection, NeuroYoga integration)

This MVP is purely for technical validation of PPG measurement accuracy.

