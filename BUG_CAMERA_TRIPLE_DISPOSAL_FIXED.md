# Bug Fix: Camera Triple Disposal + Peak Detection Improvements

## Problem 1: Camera Triple Disposal
Camera disposal was called 3 times at the end of measurement, causing crashes:
```
flutter: Processing failed: Exception: Not enough peaks
flutter: Camera disposed
flutter: Camera disposed  ← duplicate!
flutter: Camera disposed  ← duplicate!
```

Also saw `CameraException(Disposed CameraController, stopImageStream()...)` because we tried to stop stream on already disposed camera.

### Root Cause
Multiple code paths were calling `_cameraService.dispose()`:
1. `_completeMeasurement()` - when measurement finishes
2. `cancelMeasurement()` - when user cancels
3. `_handleError()` - when processing fails
4. `MeasurementOrchestrator.dispose()` - when screen closes

### Solution
Added guard flag in CameraService:
```dart
bool _isDisposed = false;

Future<void> dispose() async {
  if (_isDisposed) {
    debugPrint('⚠️ Camera already disposed, skipping');
    return;
  }
  
  _isDisposed = true;
  // ... rest of disposal logic
}
```

Now `dispose()` can be called multiple times safely - it will only execute once.

## Problem 2: Too Few Peaks Detected
Only 2 peaks detected in 30 seconds (need minimum 3 for BPM calculation):
```
flutter: Detected 2 peaks (threshold: 102.4, prominence: 30.8, amplitude: 205.3)
flutter: Retry found 2 peaks with threshold 81.9
flutter: Signal processing error: Exception: Not enough peaks detected (need at least 3, got 2)
```

Signal quality was good (variance 5-9, brightness 70), but algorithm was too strict.

### Root Cause
Peak detection parameters were too conservative:
- Threshold: 15% of amplitude (too high)
- Prominence: 15% of amplitude (too strict)
- Min separation: 400ms (correct, but combined with high threshold = too few peaks)
- Window size: ±2 samples (too wide, missed peaks)

### Solution
Made algorithm more sensitive:
1. **Reduced threshold**: 8% of amplitude (from 15%)
2. **Reduced prominence**: 10% of amplitude (from 15%)
3. **Reduced min separation**: 350ms (from 400ms) - allows up to 171 BPM
4. **Simplified window**: Only check immediate neighbors (±1 sample)
5. **Added peak replacement**: If new peak is higher within separation window, replace previous
6. **Lower retry threshold**: 3% of amplitude (from 5%)

Expected results:
- 30s measurement: 25-35 peaks (50-70 BPM)
- 60s measurement: 50-70 peaks (50-70 BPM)

## Testing
Run measurement with finger on camera. Should see:
- Only ONE "Camera disposed" message
- No CameraException errors
- 25+ peaks detected in 30s
- Successful BPM calculation

## Files Changed
- `lib/services/camera_service.dart` - added `_isDisposed` guard flag
- `lib/services/measurement_orchestrator.dart` - cleaned up debug logs
- `lib/services/signal_processor.dart` - improved peak detection sensitivity

## Version
v1.4.3 - Camera disposal fix + peak detection improvements
