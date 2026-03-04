# Bug Analysis: Signal Too Stable - No Heartbeat Peaks

## Problem
Measurement detects only 2-3 peaks in 30 seconds, but they are spaced 10+ seconds apart (not heartbeats):

```
flutter: Detected 2 peaks (threshold: 100.7, prominence: 17.6, amplitude: 176.0)
flutter: Retry found 3 peaks with threshold 91.9
flutter: All IBIs: 10000, 15000 ms  ← WAY too long!
flutter: Valid IBIs (250-2000ms): 0 out of 2
flutter: Signal processing error: Exception: No valid inter-beat intervals found
```

Expected: 25-35 peaks in 30s (50-70 BPM) with IBIs of 800-1200ms

## Root Cause Analysis

### Signal Quality Metrics
From logs:
- Brightness: 70 (good ✓)
- Variance: 5-9 (TOO LOW ✗)
- Amplitude: 176 (good ✓)
- FPS: 24 (good ✓)

**The signal is TOO STABLE** - variance 5-9 means almost no pulsation visible.

### Possible Causes

1. **Finger Not Covering Camera Properly**
   - Light leaking around finger edges
   - Not enough pressure on camera
   - Camera lens not fully covered

2. **Over-Smoothing**
   - Moving average window = 5 samples
   - At 24 FPS, this is ~200ms smoothing
   - May be killing the pulse signal

3. **ROI Too Large**
   - Current: 10% of sensor width (100-200px)
   - Averaging over large area reduces pulsation visibility
   - Should use smaller, centered ROI

4. **iOS Camera Auto-Adjustments**
   - iOS may be auto-adjusting exposure/gain
   - This can stabilize the signal artificially
   - Need to lock camera settings

## Attempted Fixes

### v1 - Made Peak Detection More Sensitive
- Reduced threshold: 15% → 8%
- Reduced prominence: 15% → 10%
- Reduced min separation: 400ms → 350ms
- **Result**: Found 3 peaks instead of 2, but still wrong (10s apart)

### v2 - Reduced Smoothing
- Moving average window: 5 → 3 samples
- At 24 FPS, this is ~125ms smoothing
- **Result**: Testing needed

## Next Steps

### Immediate Testing
1. Run measurement with new smoothing (window=3)
2. Check logs for:
   - Signal stats (min, max, mean, amplitude, variance)
   - All detected IBIs
   - Peak count and spacing

### If Still Failing

**Option A: Reduce ROI Size**
```dart
// In camera_service.dart _extractGreenMean()
final int roiSize = (width * 0.05).round().clamp(50, 100); // Smaller ROI
```

**Option B: Lock Camera Settings**
```dart
// In camera_service.dart initialize()
await _controller!.setExposureMode(ExposureMode.locked);
await _controller!.setExposurePoint(Offset(0.5, 0.5));
```

**Option C: Use Raw Y Channel Without RGB Conversion**
Already doing this - using Y channel directly as brightness.

**Option D: Add High-Pass Filter**
Remove DC component to emphasize pulsation:
```dart
List<double> applyHighPassFilter(List<double> signal) {
  double mean = signal.reduce((a, b) => a + b) / signal.length;
  return signal.map((v) => v - mean).toList();
}
```

## User Instructions

**Critical**: Finger placement is EVERYTHING for PPG measurement:

1. **Cover camera lens COMPLETELY** with fingertip
2. **Press firmly** but not too hard (don't cut off blood flow)
3. **Keep finger STILL** - any movement creates artifacts
4. **Use index finger** - best blood flow
5. **Warm up finger** if cold - poor circulation = weak signal

## Files Changed
- `lib/services/signal_processor.dart` - reduced smoothing window, added debug output

## Version
v1.4.4 - Signal quality diagnostics
