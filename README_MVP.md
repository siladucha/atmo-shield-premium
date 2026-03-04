# HRV Measurement MVP

## Overview

This is the MVP (Proof of Concept) implementation for camera-based HRV measurement. The goal is to validate PPG measurement accuracy before full ATMO Shield integration.

## Current Status

**Sprint 1 (Weeks 1-2): Core Infrastructure** ✅ IN PROGRESS

Completed:
- [x] Project structure created
- [x] Data models (MeasurementMode, QualityLevel, MeasurementResult)
- [x] Disclaimer screen
- [x] Permission screen
- [x] Tutorial screen (3 pages)
- [x] Main screen (mode selection)
- [x] Measurement screen (placeholder)

Next:
- [ ] SQLite database setup
- [ ] Database CRUD operations
- [ ] Unit tests for models

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
│   ├── measurement_mode.dart
│   ├── quality_level.dart
│   └── measurement_result.dart
├── screens/                     # UI screens
│   ├── disclaimer_screen.dart
│   ├── permission_screen.dart
│   ├── tutorial_screen.dart
│   ├── main_screen.dart
│   └── measurement_screen.dart  # TODO: Sprint 2
├── services/                    # Business logic (TODO)
└── utils/                       # Utilities (TODO)
```

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```

## MVP Scope

**Included:**
- Quick Mode (30s, BPM only)
- Accurate Mode (60s, BPM + RMSSD)
- camera plugin (no native fallback)
- Plain SQLite (no encryption)
- 3-level quality validation (poor/fair/good)
- Basic UI screens

**Excluded (post-MVP):**
- Native fallback plugin
- SQLCipher encryption
- Health platform sync
- Trend graphs
- Data export
- Multi-language support
- Settings screen

## Timeline

- **Sprint 1 (Weeks 1-2)**: Core Infrastructure ← WE ARE HERE
- **Sprint 2 (Weeks 3-4)**: Camera & Signal Processing
- **Sprint 3 (Weeks 5-6)**: UI & Quality Feedback
- **Sprint 4 (Weeks 7-8)**: History & Validation

## Success Criteria

- BPM correlation ≥0.85 vs Polar H10
- RMSSD correlation ≥0.75 vs reference
- Success rate ≥60%
- Works on 3+ test devices

## Reference

- Old prototype: `lib/main_old_prototype.dart` (flutter_ppg implementation)
- Requirements: `.kiro/specs/camera-hrv-measurement/requirements.md`
- Design: `.kiro/specs/camera-hrv-measurement/design.md`
- Tasks: `.kiro/specs/camera-hrv-measurement/tasks.md`
