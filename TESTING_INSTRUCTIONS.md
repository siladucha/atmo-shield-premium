# Testing Instructions - Camera HRV POC

## Quick Test (5 minutes)

### 1. Rebuild App
```bash
flutter clean
flutter pub get
flutter run
```

### 2. Start Quick Mode (30s)
- Tap "Quick Mode"
- Place finger FIRMLY on camera (cover completely)
- Keep hand VERY still

### 3. Watch Logs in Xcode Console

**Every 1 second - Camera metrics:**
```
Camera: 85.3 green, 12.45 var, 24 FPS
```
✅ Good: green = 60-150, var = 5-50, FPS = 20-30
❌ Bad: green < 30, var < 1.0, FPS < 15

**Every 5 seconds - Quality metrics:**
```
Quality check: brightness=85.3, variance=12.45, R=90.1, G=85.3, B=82.7
```
✅ Good: brightness > 60, variance > 5, R ≈ G ≈ B
❌ Bad: brightness < 30, variance < 1, R >> G

**At end - Peak detection:**
```
Detected 28 peaks (threshold: 92.1, amplitude: 45.3, mean: 85.7, multiplier: 0.1)
Calculated BPM: 72 from 28 peaks (22 valid IBIs)
```
✅ Good: 20-40 peaks, 10+ IBIs, BPM 50-120
❌ Bad: < 10 peaks, < 5 IBIs

### 4. Check UI

**Signal Quality Indicator:**
- ❌ Red "Poor" → No finger or too light pressure
- ⚠️ Yellow "Fair" → Finger detected, some movement
- ✅ Green "Good" → Strong stable signal

**Waveform:**
- Should show clear pulsation (peaks and valleys)
- Not flat line
- Not random noise

**Result Screen:**
- BPM: 50-120 (resting)
- Quality: Fair or Good
- HRV: 20-100ms (or "Not available" if poor quality)

---

## Detailed Test (15 minutes)

### Test 1: No Finger
**Expected:**
- Quality: Red "Poor"
- Message: "Place finger on camera"
- Brightness < 30
- Variance < 1.0

### Test 2: Finger Too Light
**Expected:**
- Quality: Red "Poor"
- Message: "Reduce finger pressure" or "Adjust position"
- Brightness 30-60
- Variance < 2.0

### Test 3: Finger Proper
**Expected:**
- Quality: Yellow "Fair" → Green "Good" (after 5-10s)
- Message: "Good signal - keep steady"
- Brightness 60-150
- Variance 5-50
- Clear waveform with peaks

### Test 4: Movement During Measurement
**Expected:**
- Quality degrades: Green → Yellow → Red
- Message: "Keep hand still"
- Waveform shows spikes

### Test 5: Complete 60s Accurate Mode
**Expected:**
- 40-80 peaks detected
- BPM: 50-120
- RMSSD: 20-100ms (or null if quality insufficient)
- No errors in log

---

## Common Issues & Solutions

### Issue: Brightness always < 30
**Cause:** Flash not working or finger not covering camera
**Solution:** 
- Check flash is ON (should see light)
- Cover camera COMPLETELY with finger
- Try different finger (index works best)

### Issue: Variance always < 1.0
**Cause:** Too much pressure (blocking blood flow)
**Solution:**
- Reduce finger pressure
- Just rest finger gently on camera

### Issue: Quality jumps Poor → Good → Poor
**Cause:** Hand movement
**Solution:**
- Rest phone on table
- Rest hand on table
- Don't hold phone in air

### Issue: Only 3-5 peaks detected
**Cause:** Signal too weak or threshold too high
**Solution:**
- Check brightness > 60
- Check variance > 5
- If still failing, algorithm needs tuning

### Issue: BPM unrealistic (< 40 or > 150)
**Cause:** False peak detection
**Solution:**
- Improve signal quality (brightness, variance)
- Check waveform for clear peaks

---

## Success Criteria (POC)

### Minimum Viable:
- ✅ Detects finger presence (quality changes Poor → Fair/Good)
- ✅ Measures BPM within ±10 of actual (compare with Apple Watch)
- ✅ Completes 30s measurement without crashes
- ✅ Shows reasonable waveform

### Ideal:
- ✅ BPM within ±5 of actual
- ✅ RMSSD calculated (even if not perfectly accurate)
- ✅ Quality indicator responsive (< 3s to detect finger)
- ✅ Works in different lighting conditions

### Out of Scope (for POC):
- ❌ Medical-grade accuracy
- ❌ Works with any finger position
- ❌ Works while moving
- ❌ Automatic finger detection

---

## Log Analysis

### Good Measurement Example:
```
Camera: 85.3 green, 12.45 var, 24 FPS
Quality check: brightness=85.3, variance=12.45, R=90.1, G=85.3, B=82.7
Detected 28 peaks (threshold: 92.1, amplitude: 45.3, mean: 85.7, multiplier: 0.1)
Calculated BPM: 72 from 28 peaks (22 valid IBIs)
Calculated RMSSD: 45.3 ms (from 18 diffs, 21 filtered IBIs)
```

### Bad Measurement Example:
```
Camera: 14.7 green, 0.27 var, 24 FPS
Quality check: brightness=14.7, variance=0.00, R=209.0, G=14.7, B=13.9
Detected 3 peaks (threshold: 48.3, amplitude: 216.5, mean: 23.9, multiplier: 0.05)
Too few peaks, retrying with lower threshold...
Retry found 5 peaks with threshold 30.1
Signal processing error: Exception: Not enough peaks detected (need at least 3, got 5)
```

**Problem:** Brightness too low (14.7), variance near zero
**Solution:** Finger not covering camera properly

---

## Report Format

After testing, report:

1. **Camera Metrics:**
   - Brightness range: X-Y
   - Variance range: X-Y
   - FPS: X

2. **Peak Detection:**
   - Peaks in 30s: X
   - BPM: X
   - Compared to Apple Watch: ±X BPM

3. **Quality Indicator:**
   - Responds to finger: Yes/No
   - Shows correct state: Yes/No
   - Response time: X seconds

4. **Issues Found:**
   - List any problems
   - Include relevant log snippets

5. **Overall Assessment:**
   - Works: Yes/No/Partially
   - Ready for next phase: Yes/No
   - Blockers: List
