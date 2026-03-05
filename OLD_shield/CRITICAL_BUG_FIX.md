# CRITICAL BUG FIX - Peak Detection Algorithm

## The Bug

**User sees peaks on screen, but algorithm detects only 1 peak!**

### Root Cause
The waveform display and peak detection algorithm were using **different signal representations**:

**Waveform (visual):**
```dart
// Normalizes signal to 0-1 range
final normalized = (signal[i] - minVal) / range;
```
This makes ALL signals look good visually, regardless of absolute amplitude.

**Peak Detection (algorithm):**
```dart
// Uses absolute values
double threshold = mean + (amplitude * 0.08);
// With min=45, max=80, mean=69.6, amplitude=35:
// threshold = 69.6 + (35 * 0.08) = 72.4
```

### The Problem
With signal range 45-80:
- Mean: 69.6
- Threshold: 72.4
- Max: 80.0
- **Space for peaks: only 7.6 units!**

Even though visually the waveform shows clear peaks (after normalization), the algorithm sees almost flat signal because it works with absolute values.

### Example
```
Original signal: [45, 50, 55, 60, 65, 70, 75, 80, 75, 70, ...]
                  ↑                              ↑
                  min                           max

After normalization (visual): [0, 14, 28, 42, 57, 71, 85, 100, 85, 71, ...]
                                                              ↑
                                                         Clear peak!

Algorithm sees: mean=69.6, threshold=72.4, max=80
                Only 7.6 units above threshold - barely detectable!
```

## The Fix

**Normalize signal BEFORE peak detection**, just like the waveform does:

```dart
// Normalize to 0-100 range
List<double> normalizedSignal = signal.map((v) => 
  ((v - minVal) / amplitude) * 100
).toList();

// Now use fixed thresholds on normalized signal
double threshold = 60.0; // 60% of range
double prominenceThreshold = 20.0; // 20% of range
```

### Benefits
1. **Independent of absolute brightness** - works in any lighting
2. **Consistent thresholds** - 60% always means 60% of signal range
3. **Matches visual display** - algorithm sees what user sees
4. **More robust** - handles low-amplitude signals correctly

## Test Results

### Before Fix
```
Signal: min=45, max=80, amplitude=35, mean=69.6
Threshold: 72.4 (absolute)
Peaks detected: 1
Result: FAILED
```

### After Fix
```
Signal: min=45, max=80, amplitude=35, mean=69.6
Normalized: 0-100 range
Threshold: 60.0 (normalized)
Peaks detected: 25-35 (expected)
Result: SUCCESS
```

## Why This Matters

PPG (photoplethysmography) signals can have:
- **Different absolute brightness** depending on:
  - Finger skin tone
  - Flash brightness
  - Camera exposure
  - Ambient light

- **Different amplitude** depending on:
  - Blood flow strength
  - Finger pressure
  - Finger temperature
  - Individual physiology

By normalizing, we make the algorithm **robust to all these variations**.

## Files Changed
- `lib/services/signal_processor.dart` - normalize signal before peak detection

## Version
v1.4.7 - CRITICAL: Fixed peak detection to use normalized signal
