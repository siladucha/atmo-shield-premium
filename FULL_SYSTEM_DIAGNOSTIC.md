# Full System Diagnostic - Camera HRV Measurement

## Overview
Complete diagnostic logging system for both Quick Mode (30s) and Accurate Mode (60s) measurements.

## Diagnostic Points

### 1. Measurement Start
```
═══════════════════════════════════════════════════════
🚀 STARTING MEASUREMENT: Quick Mode (30s)
═══════════════════════════════════════════════════════
✅ Camera initialized
📹 Starting capture...
```

### 2. Progress Tracking (Every 5 seconds)
```
⏱️  Progress: 5s / 30s (120 samples collected)
⏱️  Progress: 10s / 30s (240 samples collected)
⏱️  Progress: 15s / 30s (360 samples collected)
...
```

### 3. Quality Checks (Every 10 seconds)
```
📊 Quality @10s: brightness=69.8, variance=5.47, R=198.3, G=69.8, B=17.1
📊 Quality @20s: brightness=69.4, variance=5.12, R=197.4, G=69.4, B=15.7
📊 Quality @30s: brightness=69.0, variance=5.05, R=195.9, G=69.0, B=16.0
```

### 4. Flash Monitoring
```
⚠️  Flash may have turned off (brightness: 43.2), attempting to re-enable...
```

### 5. Processing Start
```
⏱️  Time complete! Starting processing...
═══════════════════════════════════════════════════════
🔄 PROCESSING MEASUREMENT
═══════════════════════════════════════════════════════
📊 Collected 702 samples over 30 seconds
📊 Actual sampling rate: 23 FPS
📊 Final quality: Good
```

### 6. Signal Analysis
```
Signal stats: min=45.2, max=221.2, mean=71.6, amplitude=176.0, variance=6.71
```

### 7. Peak Detection
```
Detected 2 peaks (threshold: 100.7, prominence: 17.6, amplitude: 176.0, mean: 86.6)
Too few peaks, retrying with lower threshold...
Retry found 3 peaks with threshold 91.9
```

### 8. IBI Analysis
```
All IBIs: 10435, 15652 ms
Valid IBIs (250-2000ms): 0 out of 2
```

### 9. Measurement Complete (Success)
```
═══════════════════════════════════════════════════════
✅ MEASUREMENT COMPLETE
   BPM: 72
   RMSSD: 45.3 ms
   Peaks: 28
   Quality: Good
═══════════════════════════════════════════════════════
```

### 10. Measurement Failed
```
═══════════════════════════════════════════════════════
❌ PROCESSING FAILED: Exception: Not enough peaks detected (need at least 3, got 2)
═══════════════════════════════════════════════════════
```

### 11. Save Result
```
═══════════════════════════════════════════════════════
💾 MEASUREMENT SAVED
   ID: 1234567890123
   BPM: 72
   RMSSD: 45.3 ms
   Peaks: 28
   Samples: 702
   FPS: 23.4
   Signal: mean=71.6, var=6.71, amp=176.0
   Quality: Good (85/100)
═══════════════════════════════════════════════════════
```

## Results Screen - Technical Details

Users can expand "Technical Details" section to see:

- **Peaks Detected**: Number of heartbeat peaks found
- **Samples Collected**: Total camera frames processed
- **Sampling Rate**: Actual FPS achieved
- **Signal Mean**: Average brightness value
- **Signal Variance**: Pulsation strength (should be >20)
- **Signal Amplitude**: Peak-to-valley difference

**Expected Values:**
- 30s mode: 25-35 peaks
- 60s mode: 50-70 peaks
- Variance: >20 for good signal
- Sampling rate: 20-30 FPS

## Troubleshooting Guide

### Problem: Only 2-3 peaks detected
**Symptoms:**
```
Detected 2 peaks (threshold: 100.7, prominence: 17.6, amplitude: 176.0)
All IBIs: 10000, 15000 ms  ← Too long!
```

**Diagnosis:**
- Signal variance too low (<10)
- Peaks are not heartbeats (movement artifacts)
- Finger not properly covering camera

**Solution:**
1. Ensure finger completely covers camera lens
2. Press firmly but not too hard
3. Keep finger absolutely still
4. Use index finger (best blood flow)
5. Warm up finger if cold

### Problem: Flash turns off mid-measurement
**Symptoms:**
```
⚠️  Flash may have turned off (brightness: 43.2), attempting to re-enable...
```

**Diagnosis:**
- iOS thermal/battery protection
- Brightness drops from 70 to <60

**Solution:**
- System automatically re-enables flash
- If persists, let phone cool down

### Problem: Low variance signal
**Symptoms:**
```
Signal stats: variance=5.47  ← Too low!
Quality: Poor
```

**Diagnosis:**
- Weak pulsation signal
- Light leaking around finger
- Poor finger placement

**Solution:**
1. Cover camera completely
2. Increase finger pressure slightly
3. Ensure flash is on
4. Check finger is warm

## Files Modified

### Core Services
- `lib/services/measurement_orchestrator.dart` - Progress and quality logging
- `lib/services/signal_processor.dart` - Signal analysis and peak detection logging
- `lib/services/camera_service.dart` - Camera initialization logging

### Models
- `lib/models/measurement_result.dart` - Added diagnostic fields

### UI
- `lib/screens/results_screen_hrv.dart` - Technical details section, save logging

## Version
v1.4.5 - Full diagnostic system
