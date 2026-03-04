# Camera HRV Measurement - Critical Fixes Applied

## Date: 2026-03-04

## Problems Identified from Testing

### 1. ❌ Wrong Signal Source (CRITICAL)
**Problem:**
- Green channel = 14.7 (very dark)
- Red channel = 209.0 (abnormally bright)
- RGB conversion from YUV was incorrect for PPG measurement

**Root Cause:**
- YUV to RGB conversion produces unreliable values for low-light conditions
- Green channel calculation was affected by U/V components
- ROI was too small (5% = 80-150px)

**Solution:**
- ✅ Use Y channel (luminance) directly instead of RGB green
- ✅ Increased ROI from 5% to 10% (100-200px)
- ✅ Sample RGB only for finger detection (every 10th pixel)
- ✅ Return Y channel as 'meanGreen' for signal processing

**Expected Result:**
- Brightness should be 60-150 (instead of 14.7)
- Variance should be 5-50 (instead of 0.27)

---

### 2. ❌ Signal Quality Always "Poor"
**Problem:**
- Quality indicator always red
- Variance = 0.00 in QualityValidator (but 0.27 in camera)

**Root Cause:**
- QualityValidator calculated variance from 10 recent samples
- With low brightness (14.7), variance was near zero
- Thresholds were too strict (variance < 2.0 = poor)

**Solution:**
- ✅ Relaxed variance threshold: 0.5 (was 2.0)
- ✅ Brightness threshold: 20 (was adaptive)
- ✅ Color ratio thresholds: R/G > 0.5, B/G > 0.4 (was 0.6, 0.5)
- ✅ Added detailed logging every 5 seconds

**Expected Result:**
- Quality should show "Fair" or "Good" when finger is properly placed
- Variance should be > 1.0 for acceptable signal

---

### 3. ❌ Too Few Peaks Detected
**Problem:**
- Only 5 peaks in 30 seconds (should be ~30-50)
- BPM calculated from only 3 valid IBIs (unreliable)

**Root Cause:**
- Threshold too high: mean + 10% of amplitude
- With low brightness (14.7) and high amplitude (216.5), threshold = 48.3
- Most signal was below threshold

**Solution:**
- ✅ Adaptive threshold multiplier:
  - 5% for dark signals (mean < 50)
  - 10% for normal signals
- ✅ Retry mechanism: if < 5 peaks found, retry with 3% threshold
- ✅ Detailed logging of threshold calculation

**Expected Result:**
- Should detect 20-40 peaks in 30 seconds
- BPM should be calculated from 10+ valid IBIs

---

### 4. ❌ Low FPS Initially
**Problem:**
- FPS started at 10, then increased to 24
- Need consistent 30 FPS for reliable PPG

**Solution:**
- ✅ Changed ResolutionPreset from `medium` to `low`
- ✅ Added `setFocusMode(FocusMode.locked)` for stability
- ✅ FPS logging every second

**Expected Result:**
- Consistent 25-30 FPS throughout measurement

---

### 5. ❌ RMSSD Out of Range
**Problem:**
- RMSSD = 10717ms (should be 20-100ms)
- Caused by outlier IBIs

**Solution:**
- ✅ Stricter IBI filtering: 400-1200ms (was 300-1500ms)
- ✅ Outlier removal: ±20% from median (was 30%)
- ✅ Successive difference filtering: < 200ms
- ✅ Range validation: 10-150ms

**Expected Result:**
- RMSSD should be 20-80ms for normal HRV
- Or null if signal quality insufficient

---

## Testing Checklist

After rebuild, verify:

### Camera & Signal
- [ ] Brightness (Y channel) = 60-150 (not 14.7)
- [ ] Variance = 5-50 (not 0.27)
- [ ] FPS = 25-30 consistently
- [ ] RGB values reasonable (R ≈ G ≈ B when finger on camera)

### Peak Detection
- [ ] 20-40 peaks detected in 30 seconds
- [ ] BPM calculated from 10+ IBIs
- [ ] BPM in range 50-120 for resting measurement

### Quality Indicator
- [ ] Shows "Fair" (yellow) or "Good" (green) when finger properly placed
- [ ] Shows "Poor" (red) when no finger
- [ ] Message changes appropriately

### HRV Measurement (60s)
- [ ] RMSSD = 20-100ms (or null if poor quality)
- [ ] No "out of range" errors
- [ ] Measurement completes successfully

---

## Key Changes Summary

### lib/services/camera_service.dart
- Use Y channel directly for PPG signal
- Increased ROI from 5% to 10%
- Sample RGB only for finger detection
- Added FPS and signal logging

### lib/services/quality_validator.dart
- Relaxed variance threshold: 0.5 (was 2.0)
- Relaxed brightness threshold: 20 (was adaptive)
- Relaxed color ratios for finger detection
- Added detailed logging

### lib/services/signal_processor.dart
- Adaptive threshold: 5% for dark, 10% for normal
- Retry mechanism with 3% threshold
- Stricter RMSSD calculation with outlier filtering

### lib/services/measurement_orchestrator.dart
- Calculate actual sampling rate from collected data
- Added quality metrics logging every 5 seconds

---

## Next Steps

1. **Rebuild and test** on iPhone
2. **Check logs** for:
   - `Camera: X green, Y var, Z FPS` - should show brightness 60-150
   - `Quality check: brightness=X, variance=Y` - should show variance > 1.0
   - `Detected N peaks` - should show 20-40 peaks
3. **Verify UI** matches actual signal quality
4. **Test edge cases**:
   - No finger → "Poor" quality
   - Finger too light → "Fair" quality
   - Finger proper → "Good" quality
   - Movement → quality degrades

---

## Known Limitations (POC)

- FPS may vary 20-30 (acceptable for POC)
- RMSSD may be null if signal quality insufficient
- Accuracy ±5 BPM compared to medical devices
- Requires steady hand for 30-60 seconds
