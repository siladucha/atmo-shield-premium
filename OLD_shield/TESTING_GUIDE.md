# POC Testing Guide

## Pre-Test Setup

### Equipment Needed
- Physical iOS or Android device with camera and flash
- Polar H10 chest strap (for validation)
- Polar Beat app or equivalent (for reference readings)
- Notebook for recording results

### Test Environment
- Quiet room
- Comfortable seating
- Good lighting
- Stable surface for phone

## Test Protocol

### Test 1: First-Time User Flow

**Objective**: Verify onboarding experience

**Steps**:
1. Install app on fresh device (or clear app data)
2. Launch app
3. Read medical disclaimer
4. Check "I understand and agree"
5. Tap "Continue"
6. Read camera permission rationale
7. Tap "Grant Permission"
8. Grant camera permission in system dialog
9. Complete tutorial (all 3 screens)
10. Arrive at main screen

**Expected Results**:
- [ ] Disclaimer shows on first launch only
- [ ] Cannot proceed without checking agreement
- [ ] Permission rationale explains camera usage clearly
- [ ] System permission dialog appears
- [ ] Tutorial screens are clear and informative
- [ ] Can skip tutorial if desired
- [ ] Main screen shows mode selection

**Pass/Fail**: ___________

**Notes**: ___________________________________________

---

### Test 2: Quick Mode Measurement

**Objective**: Validate 30-second heart rate measurement

**Steps**:
1. Select "Quick Mode" on main screen
2. Tap large heart button
3. Place finger gently on rear camera + flash
4. Observe quality indicator
5. Keep still for 30 seconds
6. View results

**Expected Results**:
- [ ] Camera preview appears
- [ ] Flash LED turns on
- [ ] ROI overlay visible (green rectangle)
- [ ] Quality indicator updates every ~1 second
- [ ] Quality changes based on finger placement
- [ ] Waveform displays live signal
- [ ] Progress bar advances
- [ ] Timer counts 0-30 seconds
- [ ] Measurement auto-completes at 30s
- [ ] Results show BPM only (no RMSSD)
- [ ] Quality score displayed
- [ ] Star rating shown

**Measurements** (repeat 5 times):

| Run | BPM | Polar H10 BPM | Quality | Notes |
|-----|-----|---------------|---------|-------|
| 1   |     |               |         |       |
| 2   |     |               |         |       |
| 3   |     |               |         |       |
| 4   |     |               |         |       |
| 5   |     |               |         |       |

**Pass/Fail**: ___________

**Notes**: ___________________________________________

---

### Test 3: Accurate Mode Measurement

**Objective**: Validate 60-second heart rate + HRV measurement

**Steps**:
1. Select "Accurate Mode" on main screen
2. Tap large heart button
3. Place finger gently on rear camera + flash
4. Follow breathing metronome
5. Keep still for 60 seconds
6. View results

**Expected Results**:
- [ ] Camera preview appears
- [ ] Flash LED turns on
- [ ] Breathing metronome visible
- [ ] Metronome animates: expand (inhale 4s), contract (exhale 6s)
- [ ] "Breathe In" / "Breathe Out" text updates
- [ ] Quality indicator updates
- [ ] Waveform displays
- [ ] Progress bar advances
- [ ] Timer counts 0-60 seconds
- [ ] Measurement auto-completes at 60s
- [ ] Results show BPM AND RMSSD
- [ ] RMSSD interpretation shown (Low/Normal/High)

**Measurements** (repeat 5 times):

| Run | BPM | RMSSD (ms) | Polar H10 BPM | Polar H10 RMSSD | Quality | Notes |
|-----|-----|------------|---------------|-----------------|---------|-------|
| 1   |     |            |               |                 |         |       |
| 2   |     |            |               |                 |         |       |
| 3   |     |            |               |                 |         |       |
| 4   |     |            |               |                 |         |       |
| 5   |     |            |               |                 |         |       |

**Pass/Fail**: ___________

**Notes**: ___________________________________________

---

### Test 4: Quality Feedback

**Objective**: Verify quality indicator responds to finger placement

**Steps**:
1. Start Quick Mode measurement
2. **Test A**: No finger on camera
3. **Test B**: Finger too light (barely touching)
4. **Test C**: Finger too hard (pressing firmly)
5. **Test D**: Finger moving
6. **Test E**: Finger optimal (gentle, steady)

**Expected Results**:

| Test | Expected Quality | Actual Quality | Message Displayed |
|------|------------------|----------------|-------------------|
| A    | Poor             |                |                   |
| B    | Poor/Fair        |                |                   |
| C    | Poor             |                |                   |
| D    | Poor/Fair        |                |                   |
| E    | Good             |                |                   |

**Pass/Fail**: ___________

**Notes**: ___________________________________________

---

### Test 5: Cancel Functionality

**Objective**: Verify measurement can be cancelled

**Steps**:
1. Start measurement (any mode)
2. Wait 10 seconds
3. Tap "X" cancel button
4. Verify return to main screen

**Expected Results**:
- [ ] Cancel button visible during measurement
- [ ] Tapping cancel stops measurement immediately
- [ ] Camera turns off
- [ ] Flash LED turns off
- [ ] Returns to main screen
- [ ] No results saved

**Pass/Fail**: ___________

**Notes**: ___________________________________________

---

### Test 6: Results Screen

**Objective**: Verify results display and actions

**Steps**:
1. Complete successful measurement
2. Review results screen
3. Test "Save" button
4. Test "Discard" button
5. Verify last measurement on main screen

**Expected Results**:
- [ ] BPM displayed as whole number
- [ ] RMSSD displayed with 1 decimal (Accurate Mode)
- [ ] Quality score 0-100 shown
- [ ] Star rating (1-4 stars) shown
- [ ] Timestamp displayed
- [ ] Mode displayed
- [ ] "Save" button saves and returns to main
- [ ] "Discard" button returns without saving
- [ ] Saved measurement appears on main screen
- [ ] Can tap last measurement to view details

**Pass/Fail**: ___________

**Notes**: ___________________________________________

---

### Test 7: Edge Cases

**Objective**: Test error handling

**Test Cases**:

#### 7A: Insufficient Signal
- Start measurement
- Keep finger off camera entire time
- Expected: Measurement fails or shows poor quality

**Result**: ___________

#### 7B: Movement During Measurement
- Start measurement
- Move hand significantly at 15 seconds
- Expected: Quality drops, possible measurement failure

**Result**: ___________

#### 7C: Cold Hands
- Cool hands with cold water
- Attempt measurement
- Expected: Lower quality, may require multiple attempts

**Result**: ___________

#### 7D: App Backgrounding
- Start measurement
- Press home button (background app)
- Return to app
- Expected: Measurement cancelled or continues

**Result**: ___________

**Pass/Fail**: ___________

**Notes**: ___________________________________________

---

## Validation Metrics

### BPM Accuracy

**Calculation**:
```
Correlation = CORREL(App_BPM, Polar_BPM)
MAE = MEAN(ABS(App_BPM - Polar_BPM))
MAPE = MEAN(ABS((App_BPM - Polar_BPM) / Polar_BPM)) * 100
```

**Target**: Correlation ≥ 0.85, MAPE < 5%

**Results**:
- Correlation: ___________
- MAE: ___________
- MAPE: ___________

### RMSSD Accuracy

**Calculation**:
```
Correlation = CORREL(App_RMSSD, Polar_RMSSD)
MAE = MEAN(ABS(App_RMSSD - Polar_RMSSD))
Relative_Error = MEAN(ABS((App_RMSSD - Polar_RMSSD) / Polar_RMSSD)) * 100
```

**Target**: Correlation ≥ 0.75, Relative Error < 15%

**Results**:
- Correlation: ___________
- MAE: ___________
- Relative Error: ___________

### Success Rate

**Calculation**:
```
Success_Rate = (Successful_Measurements / Total_Attempts) * 100
```

**Target**: ≥ 60%

**Results**:
- Total Attempts: ___________
- Successful: ___________
- Failed: ___________
- Success Rate: ___________%

---

## Device Compatibility

Test on multiple devices:

| Device | OS Version | Camera | Flash | Quick Mode | Accurate Mode | Notes |
|--------|------------|--------|-------|------------|---------------|-------|
|        |            | ✓/✗    | ✓/✗   | ✓/✗        | ✓/✗           |       |
|        |            | ✓/✗    | ✓/✗   | ✓/✗        | ✓/✗           |       |
|        |            | ✓/✗    | ✓/✗   | ✓/✗        | ✓/✗           |       |

---

## Skin Tone Testing

Test with diverse participants (Fitzpatrick Scale I-VI):

| Participant | Skin Type | Success Rate | Avg Quality | Notes |
|-------------|-----------|--------------|-------------|-------|
| 1           |           |              |             |       |
| 2           |           |              |             |       |
| 3           |           |              |             |       |
| 4           |           |              |             |       |
| 5           |           |              |             |       |

---

## Final Assessment

### POC Success Criteria

- [ ] BPM correlation ≥ 0.85 vs Polar H10
- [ ] RMSSD correlation ≥ 0.75 vs Polar H10
- [ ] Success rate ≥ 60%
- [ ] Works on 3+ test devices
- [ ] All critical user flows functional
- [ ] No critical bugs

### Recommendation

**Proceed to Full Development**: YES / NO

**Rationale**: ___________________________________________

**Priority Improvements**: ___________________________________________

---

**Tester Name**: ___________________________________________

**Date**: ___________________________________________

**Signature**: ___________________________________________
