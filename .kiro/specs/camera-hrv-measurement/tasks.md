# Tasks: Camera-Based HRV Measurement MVP

## Overview

This task breakdown covers the 8-week MVP (Proof of Concept) for validating PPG measurement technology. Tasks are organized by sprint with clear acceptance criteria and dependencies.

**Goal**: Validate BPM and RMSSD measurement accuracy vs Polar H10 reference device.

**Timeline**: 8 weeks (4 sprints × 2 weeks)

**Team Size**: 1-2 developers

---

## Sprint 1: Core Infrastructure (Weeks 1-2)

### Task 1.1: Flutter Project Setup
**Priority**: Critical  
**Estimate**: 4 hours  
**Assignee**: Developer

**Description:**
Initialize Flutter project with required dependencies and folder structure.

**Acceptance Criteria:**
- [ ] Flutter 3.38+ project created
- [ ] Dependencies added to pubspec.yaml:
  - camera: ^0.10.6
  - provider or riverpod for state management
  - sqflite: ^2.3.0 (plain SQLite for MVP)
  - intl for date formatting
- [ ] Folder structure created:
  ```
  lib/
  ├── main.dart
  ├── models/
  ├── services/
  ├── screens/
  ├── widgets/
  └── utils/
  ```
- [ ] App runs on iOS and Android emulators
- [ ] Git repository initialized with .gitignore

**Dependencies**: None

---

### Task 1.2: Data Models
**Priority**: Critical  
**Estimate**: 6 hours  
**Assignee**: Developer

**Description:**
Create simplified data models for MVP.

**Acceptance Criteria:**
- [ ] `MeasurementMode` enum (quick, accurate)
- [ ] `QualityLevel` enum (poor, fair, good) - simplified 3 levels
- [ ] `MeasurementResult` class with fields:
  - id, timestamp, mode
  - bpm (int)
  - rmssd (double?)
  - quality (QualityLevel)
- [ ] JSON serialization methods (toJson/fromJson)
- [ ] Unit tests for data models

**Dependencies**: Task 1.1

---

### Task 1.3: Simple Storage (SharedPreferences)
**Priority**: Low  
**Estimate**: 2 hours  
**Assignee**: Developer

**Description:**
Store last measurement result in SharedPreferences for display on main screen.

**Acceptance Criteria:**
- [ ] Save last measurement as JSON
- [ ] Load last measurement on app start
- [ ] Display on main screen if exists

**Dependencies**: Task 1.2

---

### Task 1.4: Medical Disclaimer Screen
**Priority**: Critical (legal requirement)  
**Estimate**: 4 hours  
**Assignee**: Developer

**Description:**
Implement first-run disclaimer screen with checkbox consent.

**Acceptance Criteria:**
- [ ] Disclaimer screen UI matches design.md layout
- [ ] Checkbox for "I understand and agree"
- [ ] Continue button disabled until checkbox checked
- [ ] Disclaimer acceptance stored in SharedPreferences
- [ ] Screen shown only on first app launch
- [ ] Navigation to Permission Rationale screen on continue

**Dependencies**: Task 1.1

---

### Task 1.5: Permission Rationale Screen
**Priority**: Critical  
**Estimate**: 4 hours  
**Assignee**: Developer

**Description:**
Explain camera permission with clear rationale before requesting.

**Acceptance Criteria:**
- [ ] Permission rationale UI matches design.md
- [ ] "Grant Permission" button triggers system camera permission dialog
- [ ] Handle permission granted → navigate to Tutorial
- [ ] Handle permission denied → show troubleshooting message
- [ ] Permission status persisted

**Dependencies**: Task 1.4

---

### Task 1.6: Tutorial Screens
**Priority**: High  
**Estimate**: 8 hours  
**Assignee**: Developer

**Description:**
Create 3-screen tutorial with swipe navigation.

**Acceptance Criteria:**
- [ ] Screen 1: Finger placement (static images for MVP, no animation)
- [ ] Screen 2: Measurement modes explanation
- [ ] Screen 3: Best practices
- [ ] Swipe or tap Next to advance
- [ ] Dot indicators (● ○ ○)
- [ ] Skip button available
- [ ] Start button on final screen → Main screen
- [ ] Tutorial completion stored in SharedPreferences

**Dependencies**: Task 1.5

---

## Sprint 2: Camera & Signal Processing (Weeks 3-4)

### Task 2.1: Camera Integration
**Priority**: Critical  
**Estimate**: 12 hours  
**Assignee**: Developer

**Description:**
Implement camera capture using camera plugin with startImageStream.

**Acceptance Criteria:**
- [ ] CameraController initialized with back camera
- [ ] ResolutionPreset.medium for both modes (simplified for MVP)
- [ ] Flash LED enabled (FlashMode.torch)
- [ ] startImageStream() captures frames
- [ ] Camera preview displayed in UI
- [ ] Camera resources properly disposed
- [ ] Error handling for camera unavailable
- [ ] Works on iOS and Android test devices

**Dependencies**: Task 1.1

---

### Task 2.2: Green Channel Extraction
**Priority**: Critical  
**Estimate**: 16 hours  
**Assignee**: Developer

**Description:**
Extract green channel from camera frames in Dart Isolate.

**Acceptance Criteria:**
- [ ] Long-lived Isolate created for frame processing
- [ ] Handle YUV420 format (Android)
- [ ] Handle BGRA8888 format (iOS)
- [ ] Extract green channel from frame
- [ ] Calculate ROI: 5% of sensor width, clamped 80-150px, centered
- [ ] Calculate mean green intensity in ROI
- [ ] Calculate variance in ROI
- [ ] Return: {meanGreen, timestamp, variance}
- [ ] Processing <50ms per frame on test devices
- [ ] Isolate properly disposed on measurement end

**Dependencies**: Task 2.1

---

### Task 2.3: Basic Signal Filtering
**Priority**: Critical  
**Estimate**: 12 hours  
**Assignee**: Developer

**Description:**
Implement simple moving average filter (simplified for MVP, no Butterworth).

**Acceptance Criteria:**
- [ ] SignalProcessor class created
- [ ] Moving average filter with window size 5
- [ ] Filter applied to intensity time series
- [ ] Filtered signal stored for display
- [ ] Unit tests with synthetic signals
- [ ] Processing <10ms for 60-second signal

**Dependencies**: Task 2.2

---

### Task 2.4: Peak Detection
**Priority**: Critical  
**Estimate**: 12 hours  
**Assignee**: Developer

**Description:**
Detect heartbeat peaks in filtered signal.

**Acceptance Criteria:**
- [ ] Adaptive threshold: mean + 20% of amplitude
- [ ] Minimum peak separation: 250ms (240 BPM max)
- [ ] Simple peak detection (no parabolic interpolation for MVP)
- [ ] Return list of peak indices
- [ ] Handle edge cases (no peaks, too few peaks)
- [ ] Unit tests with synthetic signals
- [ ] Validated with real PPG data if available

**Dependencies**: Task 2.3

---

### Task 2.5: BPM Calculation
**Priority**: Critical  
**Estimate**: 6 hours  
**Assignee**: Developer

**Description:**
Calculate heart rate from detected peaks.

**Acceptance Criteria:**
- [ ] Calculate inter-beat intervals (IBI) from peaks
- [ ] BPM = 60000 / mean(IBI)
- [ ] Round to whole number
- [ ] Validate range: 30-220 BPM
- [ ] Throw exception if out of range
- [ ] Unit tests with known peak sequences

**Dependencies**: Task 2.4

---

### Task 2.6: RMSSD Calculation
**Priority**: Critical  
**Estimate**: 6 hours  
**Assignee**: Developer

**Description:**
Calculate RMSSD for Accurate Mode.

**Acceptance Criteria:**
- [ ] Calculate successive differences of IBIs
- [ ] RMSSD = sqrt(mean(diff^2))
- [ ] Validate range: 10-150ms
- [ ] Throw exception if out of range
- [ ] Return null for Quick Mode
- [ ] Unit tests with known IBI sequences

**Dependencies**: Task 2.5

---

## Sprint 3: UI & Quality Feedback (Weeks 5-6)

### Task 3.1: Main Screen
**Priority**: Critical  
**Estimate**: 8 hours  
**Assignee**: Developer

**Description:**
Implement mode selection and measurement initiation screen.

**Acceptance Criteria:**
- [ ] UI matches design.md layout
- [ ] Two mode cards: Quick (30s) and Accurate (60s)
- [ ] Radio button selection behavior
- [ ] Large "Measure" button with pulse animation
- [ ] Last measurement card (if exists)
- [ ] "View History" button
- [ ] Navigation to Measurement screen on button tap
- [ ] Selected mode passed to Measurement screen

**Dependencies**: Task 1.6

---

### Task 3.2: Measurement Screen - Camera Preview
**Priority**: Critical  
**Estimate**: 8 hours  
**Assignee**: Developer

**Description:**
Display live camera preview during measurement.

**Acceptance Criteria:**
- [ ] Camera preview fills designated area
- [ ] ROI overlay shown (semi-transparent rectangle)
- [ ] Cancel button stops measurement
- [ ] Progress bar shows elapsed time
- [ ] Countdown timer displayed
- [ ] Measurement auto-stops at 30s (Quick) or 60s (Accurate)

**Dependencies**: Task 2.1, Task 3.1

---

### Task 3.3: Quality Validation (Simplified)
**Priority**: High  
**Estimate**: 10 hours  
**Assignee**: Developer

**Description:**
Implement 3-level quality assessment (poor/fair/good).

**Acceptance Criteria:**
- [ ] Quality assessed every 1 second
- [ ] Poor: brightness <20% or >80% baseline (no finger)
- [ ] Poor: variance <2.0 (overpressure)
- [ ] Fair: signal present but suboptimal
- [ ] Good: variance >2.0 and brightness in range
- [ ] Quality level returned as enum
- [ ] Unit tests for quality logic

**Dependencies**: Task 2.2

---

### Task 3.4: Real-Time Quality Indicator
**Priority**: High  
**Estimate**: 6 hours  
**Assignee**: Developer

**Description:**
Display quality feedback during measurement.

**Acceptance Criteria:**
- [ ] Quality bar with color: Red (poor), Yellow (fair), Green (good)
- [ ] Text feedback messages:
  - Poor: "Place finger on camera" or "Adjust pressure"
  - Fair: "Signal detected, keep steady"
  - Good: "Good signal - keep steady"
- [ ] Updates every 1 second
- [ ] Smooth color transitions

**Dependencies**: Task 3.3

---

### Task 3.5: Real-Time Waveform Display
**Priority**: Medium  
**Estimate**: 10 hours  
**Assignee**: Developer

**Description:**
Show live PPG waveform during measurement.

**Acceptance Criteria:**
- [ ] Line chart showing last 10 seconds of signal
- [ ] Updates at 10 FPS minimum
- [ ] Auto-scaling to fit display area
- [ ] Smooth scrolling animation
- [ ] Works for both Quick and Accurate modes

**Dependencies**: Task 2.3

---

### Task 3.6: Breathing Metronome
**Priority**: High (Accurate Mode only)  
**Estimate**: 8 hours  
**Assignee**: Developer

**Description:**
Animated breathing guide for Accurate Mode.

**Acceptance Criteria:**
- [ ] Circular animation: expand (inhale 4s), contract (exhale 6s)
- [ ] Text label: "Breathe In" / "Breathe Out"
- [ ] Smooth animation loop
- [ ] Only shown in Accurate Mode
- [ ] Starts immediately when measurement begins

**Dependencies**: Task 3.2

---

### Task 3.7: Results Screen
**Priority**: Critical  
**Estimate**: 10 hours  
**Assignee**: Developer

**Description:**
Display measurement results with interpretation.

**Acceptance Criteria:**
- [ ] UI matches design.md layout
- [ ] BPM displayed as whole number
- [ ] RMSSD displayed (Accurate Mode only)
- [ ] RMSSD interpretation: Low (<20ms), Normal (20-100ms), High (>100ms)
- [ ] Quality score: Simple calculation (good=80-100, fair=50-79, poor=0-49)
- [ ] Star rating (1-4 stars)
- [ ] Waveform graph (last 10 seconds)
- [ ] Timestamp displayed
- [ ] Three buttons: Save, Retake, Discard
- [ ] Save → stores to database, navigates to Main
- [ ] Retake → starts new measurement
- [ ] Discard → navigates to Main

**Dependencies**: Task 2.6, Task 3.3

---

## Sprint 4: History & Validation (Weeks 7-8)

### Task 4.1: Last Measurement Display
**Priority**: Low  
**Estimate**: 2 hours  
**Assignee**: Developer

**Description:**
Show last measurement on main screen (no full history for MVP).

**Acceptance Criteria:**
- [ ] Last measurement card on main screen
- [ ] Shows: BPM, RMSSD (if available), timestamp, quality
- [ ] Tap to view full details (reuse Results screen)
- [ ] "No measurements yet" message when empty

**Dependencies**: Task 1.3, Task 3.7

---

### Task 4.2: Measurement Orchestration
**Priority**: Critical  
**Estimate**: 12 hours  
**Assignee**: Developer

**Description:**
Coordinate camera, signal processing, and quality validation.

**Acceptance Criteria:**
- [ ] MeasurementOrchestrator class created
- [ ] Start measurement flow:
  1. Initialize camera
  2. Start Isolate
  3. Begin frame capture
  4. Collect intensity values
  5. Update quality indicator
  6. Update waveform
  7. Stop at duration limit
- [ ] Process collected signal:
  1. Apply filter
  2. Detect peaks
  3. Calculate BPM
  4. Calculate RMSSD (Accurate Mode)
  5. Calculate quality score
- [ ] Handle errors gracefully
- [ ] Proper resource cleanup
- [ ] State management (idle, capturing, processing, complete, error)

**Dependencies**: All Sprint 2 and Sprint 3 tasks

---

### Task 4.3: End-to-End Testing
**Priority**: Critical  
**Estimate**: 16 hours  
**Assignee**: Developer + Tester

**Description:**
Manual testing on real devices with Polar H10 reference.

**Acceptance Criteria:**
- [ ] Test on 3+ devices (iOS + Android)
- [ ] Complete 20+ measurements per device
- [ ] Record Polar H10 BPM simultaneously
- [ ] Calculate correlation: BPM vs Polar H10
- [ ] Target: correlation ≥0.85
- [ ] Document success rate (% of valid measurements)
- [ ] Target: ≥60% success rate
- [ ] Identify and fix critical bugs
- [ ] Performance profiling (FPS, battery, memory)

**Dependencies**: Task 4.2

---

### Task 4.4: RMSSD Validation
**Priority**: Critical  
**Estimate**: 12 hours  
**Assignee**: Developer + Tester

**Description:**
Validate RMSSD accuracy with Polar H10 or HRV reference app.

**Acceptance Criteria:**
- [ ] 5-10 test participants
- [ ] 3-5 Accurate Mode measurements per participant
- [ ] Compare RMSSD with reference device/app
- [ ] Calculate correlation: RMSSD vs reference
- [ ] Target: correlation ≥0.75
- [ ] Document measurement conditions (seated, resting, morning)
- [ ] Analyze failure cases

**Dependencies**: Task 4.3

---

### Task 4.5: Bug Fixes & Polish
**Priority**: High  
**Estimate**: 16 hours  
**Assignee**: Developer

**Description:**
Address issues found during validation testing.

**Acceptance Criteria:**
- [ ] All critical bugs fixed
- [ ] UI polish (loading states, error messages)
- [ ] Performance optimizations if needed
- [ ] Code cleanup and documentation
- [ ] README.md with setup instructions
- [ ] Known limitations documented

**Dependencies**: Task 4.3, Task 4.4

---

### Task 4.6: Validation Report
**Priority**: Critical  
**Estimate**: 8 hours  
**Assignee**: Developer + Tester

**Description:**
Document validation results and decision for next phase.

**Acceptance Criteria:**
- [ ] Validation report created with:
  - BPM correlation vs Polar H10
  - RMSSD correlation vs reference
  - Success rate statistics
  - Device compatibility matrix
  - Performance metrics (FPS, battery, memory)
  - Known issues and limitations
- [ ] Decision: Proceed to full ATMO Shield integration OR iterate on algorithms
- [ ] Recommendations for v1.1 improvements

**Dependencies**: Task 4.4, Task 4.5

---

## Summary

**Total Estimated Hours**: 232 hours (~6 weeks for 1 developer, 3 weeks for 2 developers)

**Critical Path**:
1. Project setup → Camera integration → Signal processing → Measurement orchestration → Validation

**Success Criteria**:
- BPM correlation ≥0.85 vs Polar H10
- RMSSD correlation ≥0.75 vs reference
- Success rate ≥60%
- Works on 3+ test devices

**Post-MVP**: If validation successful, proceed with full ATMO Shield integration including native optimizations, encryption, health sync, and premium features.
