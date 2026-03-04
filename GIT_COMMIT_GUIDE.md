# Git Commit Guide - Camera HRV POC

## Current Branch Status

You are working on the main development branch. The POC implementation is complete and ready for testing.

## Commit Strategy

### Option 1: Single Atomic Commit (Recommended for POC)

```bash
# Stage all POC files
git add lib/services/camera_service.dart
git add lib/services/signal_processor.dart
git add lib/services/quality_validator.dart
git add lib/services/measurement_orchestrator.dart
git add lib/screens/measurement_screen.dart
git add lib/screens/results_screen_hrv.dart
git add lib/screens/main_screen.dart
git add pubspec.yaml
git add android/app/src/main/AndroidManifest.xml
git add README_POC.md
git add TESTING_GUIDE.md
git add POC_STATUS.md
git add QUICKSTART.md
git add run_poc.sh
git add GIT_COMMIT_GUIDE.md

# Commit with descriptive message
git commit -m "feat: implement camera-based HRV measurement POC

- Add CameraService for camera capture and green channel extraction
- Add SignalProcessor for filtering, peak detection, BPM/RMSSD calculation
- Add QualityValidator for 3-level signal quality assessment
- Add MeasurementOrchestrator to coordinate measurement flow
- Update MeasurementScreen with live camera preview, quality indicator, waveform
- Add ResultsScreenHRV for displaying measurement results
- Update MainScreen to show last measurement
- Add camera permissions for iOS and Android
- Add POC documentation (README, testing guide, status report)
- Add quick start script for easy setup

Implements Sprint 1-3 tasks from camera-hrv-measurement spec.
Ready for validation testing with Polar H10 reference device.

Ref: .kiro/specs/camera-hrv-measurement/tasks.md"
```

### Option 2: Multiple Logical Commits

```bash
# Commit 1: Core services
git add lib/services/camera_service.dart
git add lib/services/signal_processor.dart
git add lib/services/quality_validator.dart
git commit -m "feat(services): add camera capture and signal processing

- CameraService: camera integration with green channel extraction
- SignalProcessor: filtering, peak detection, BPM/RMSSD calculation
- QualityValidator: 3-level signal quality assessment"

# Commit 2: Measurement orchestration
git add lib/services/measurement_orchestrator.dart
git commit -m "feat(services): add measurement orchestrator

Coordinates camera, signal processing, and quality validation
for complete measurement flow"

# Commit 3: UI updates
git add lib/screens/measurement_screen.dart
git add lib/screens/results_screen_hrv.dart
git add lib/screens/main_screen.dart
git commit -m "feat(ui): update measurement and results screens

- MeasurementScreen: live camera preview, quality indicator, waveform
- ResultsScreenHRV: display BPM, RMSSD, quality score
- MainScreen: show last measurement"

# Commit 4: Configuration
git add pubspec.yaml
git add android/app/src/main/AndroidManifest.xml
git commit -m "chore: add camera permissions and dependencies

- Add camera permissions for iOS and Android
- Add url_launcher dependency"

# Commit 5: Documentation
git add README_POC.md
git add TESTING_GUIDE.md
git add POC_STATUS.md
git add QUICKSTART.md
git add run_poc.sh
git add GIT_COMMIT_GUIDE.md
git commit -m "docs: add POC documentation and testing guide

- README_POC.md: setup and overview
- TESTING_GUIDE.md: validation protocol
- POC_STATUS.md: implementation status
- QUICKSTART.md: 5-minute setup guide
- run_poc.sh: quick start script"
```

## Commit Message Format

Following conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `chore`: Maintenance tasks
- `refactor`: Code restructuring
- `test`: Adding tests
- `perf`: Performance improvements

### Scopes
- `services`: Business logic services
- `ui`: User interface screens
- `models`: Data models
- `config`: Configuration files

## Before Committing

### 1. Check Status
```bash
git status
```

### 2. Review Changes
```bash
git diff
```

### 3. Verify No Sensitive Data
```bash
# Check for API keys, tokens, passwords
grep -r "API_KEY\|SECRET\|PASSWORD" lib/ android/ ios/
```

### 4. Ensure Code Compiles
```bash
flutter analyze
```

## After Committing

### 1. Verify Commit
```bash
git log -1 --stat
```

### 2. Push to Remote (if applicable)
```bash
# Push to feature branch
git push origin feature/camera-hrv-poc

# Or push to develop
git push origin develop
```

### 3. Create Tag (Optional)
```bash
# Tag POC version
git tag -a v1.0.0-poc -m "Camera HRV Measurement POC - Ready for validation"
git push origin v1.0.0-poc
```

## Branch Strategy

### Current Workflow
```
main (production)
  └── develop (current development)
       └── feature/camera-hrv-poc (POC work)
```

### After Validation

If POC successful:
```bash
# Merge to develop (using rebase, not merge)
git checkout develop
git rebase feature/camera-hrv-poc
git push origin develop
```

If POC needs iteration:
```bash
# Continue work on feature branch
git checkout feature/camera-hrv-poc
# Make improvements
git add .
git commit -m "fix: improve signal processing accuracy"
```

## Important Notes

⚠️ **NO MERGE COMMITS**: Always use rebase, never merge
⚠️ **NO SENSITIVE DATA**: Never commit API keys, tokens, passwords
⚠️ **ATOMIC COMMITS**: Each commit should be a logical unit
⚠️ **DESCRIPTIVE MESSAGES**: Explain what and why, not how

## Validation Checklist

Before committing, ensure:
- [ ] Code compiles without errors
- [ ] No Flutter analyzer warnings
- [ ] No sensitive data in code
- [ ] Documentation updated
- [ ] Commit message follows format
- [ ] Changes are atomic and logical

## Next Steps After Commit

1. Run validation testing (TESTING_GUIDE.md)
2. Document results in POC_STATUS.md
3. Make GO/NO-GO decision
4. If GO: Plan v1.1 development
5. If NO-GO: Iterate on POC

---

**Ready to commit!** 🚀
