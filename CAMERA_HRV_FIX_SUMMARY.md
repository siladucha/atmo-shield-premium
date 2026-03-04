# Camera HRV Fix Summary - Signal Quality Improvements

## Problem Identified
From diagnostic logs:
```
Signal stats: min=45.0, max=80.0, mean=69.6, amplitude=35.0, variance=3.95
Detected 1 peaks (threshold: 72.4, prominence: 3.5, amplitude: 35.0, mean: 69.6)
Quality: Good  ← WRONG! This is NOT good!
```

**Issues:**
1. Amplitude = 35 (too low, should be 100-200)
2. Variance = 3.95 (too low, should be 20-50)
3. Quality marked as "Good" when signal is actually poor
4. Only 1 peak detected in 30 seconds

## Root Causes

### 1. Over-Smoothing
- Moving average window = 3 samples
- At 24 FPS, this smooths over 125ms
- Kills the pulse signal (heartbeat is ~800ms cycle)

### 2. ROI Too Large
- Current: 10% of sensor width (100-200px)
- Averaging over large area reduces pulsation visibility
- Blood vessels are small, need focused measurement

### 3. Quality Thresholds Too Low
- "Good" quality at variance >= 3.0
- Should be >= 10.0 for truly good signal
- Misleading user feedback

## Fixes Applied

### Fix 1: Remove Smoothing Filter
```dart
// Before: window size = 3
List<double> applyMovingAverageFilter(List<double> signal, {int windowSize = 3})

// After: window size = 1 (no filtering)
List<double> applyMovingAverageFilter(List<double> signal, {int windowSize = 1}) {
  return signal; // No filtering
}
```

**Rationale:** PPG signal is already averaged over ROI pixels. Additional smoothing kills pulsation.

### Fix 2: Reduce ROI Size
```dart
// Before: 10% of sensor, 100-200px
final int roiSize = (width * 0.1).round().clamp(100, 200);

// After: 5% of sensor, 50-100px
final int roiSize = (width * 0.05).round().clamp(50, 100);
```

**Rationale:** Smaller ROI = more focused on blood vessels = stronger pulsation signal.

### Fix 3: Stricter Quality Thresholds
```dart
// Before:
if (variance >= 3.0) return QualityLevel.good;
if (variance >= 1.0) return QualityLevel.fair;
return QualityLevel.fair; // Always fair minimum

// After:
if (variance >= 10.0) return QualityLevel.good;  // Stricter
if (variance >= 3.0) return QualityLevel.fair;
return QualityLevel.poor; // Can be poor now
```

**Rationale:** Honest feedback helps user adjust finger placement.

### Fix 4: Better User Guidance
```dart
// Before:
if (variance < 2.0) return 'Reduce finger pressure';

// After:
if (variance < 2.0) return 'Reduce finger pressure or adjust position';
```

## Expected Results

### Before Fix
```
Signal: amplitude=35, variance=3.95
Peaks: 1 in 30s
Quality: Good (misleading)
Result: FAILED - not enough peaks
```

### After Fix
```
Signal: amplitude=100-200, variance=20-50
Peaks: 25-35 in 30s
Quality: Good (accurate)
Result: SUCCESS - BPM 60-80, RMSSD 30-60ms
```

## Testing Instructions

1. **Clean finger and camera lens**
2. **Place index finger FIRMLY on camera** - must completely cover lens
3. **Press with medium pressure** - not too light, not too hard
4. **Keep absolutely still** for entire measurement
5. **Watch quality indicator** - should show "Good" with variance >10

### If Still Failing

**Symptoms to check:**
- Variance < 10: Adjust finger pressure/position
- Amplitude < 50: Finger not covering camera completely
- Quality "Poor": Follow on-screen guidance
- Movement detected: Keep hand still

**Try:**
1. Different finger (index usually best)
2. Warm up finger if cold
3. Clean camera lens
4. Ensure flash is on
5. Reduce ambient light

## Files Changed
- `lib/services/signal_processor.dart` - removed smoothing filter
- `lib/services/camera_service.dart` - reduced ROI size from 10% to 5%
- `lib/services/quality_validator.dart` - stricter quality thresholds

## Version
v1.4.6 - Signal quality improvements (no smoothing, smaller ROI, stricter quality)
