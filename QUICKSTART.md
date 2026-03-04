# Quick Start - Camera HRV POC

## 5-Minute Setup

### 1. Prerequisites
```bash
# Verify Flutter installed
flutter --version  # Should be 3.38+

# Connect physical device (required - emulator won't work)
flutter devices
```

### 2. Install & Run
```bash
# Option A: Use quick start script
./run_poc.sh

# Option B: Manual commands
flutter pub get
flutter run
```

### 3. First Measurement
1. Accept disclaimer ✓
2. Grant camera permission ✓
3. Skip or complete tutorial ✓
4. Select "Quick Mode" (30s)
5. Tap heart button
6. Place finger on rear camera + flash
7. Keep still for 30 seconds
8. View results!

## Measurement Tips

### ✅ DO
- Use rear camera (not front)
- Cover both camera AND flash
- Gentle pressure (like touching screen)
- Stay completely still
- Sit comfortably
- Warm hands if cold

### ❌ DON'T
- Press too hard (blocks blood flow)
- Press too lightly (weak signal)
- Move during measurement
- Use in very dark room
- Use with cold hands

## Modes

### Quick Mode (30s)
- Heart rate only
- Fast results
- Good for quick checks

### Accurate Mode (60s)
- Heart rate + HRV (RMSSD)
- Breathing guidance
- Better for stress assessment

## Troubleshooting

### "No finger detected"
→ Cover both camera and flash completely

### "Reduce finger pressure"
→ Lighten pressure slightly

### "Keep still"
→ Rest phone on stable surface, support arm

### Camera not working
→ Ensure physical device (not emulator)
→ Check camera permission granted
→ Restart app

## Quality Indicators

- 🔴 **Red (Poor)**: Adjust finger placement
- 🟡 **Yellow (Fair)**: Signal detected, keep steady
- 🟢 **Green (Good)**: Perfect - don't move!

## What's Next?

After successful measurement:
- **Save**: Stores result, shows on main screen
- **Discard**: Returns to main without saving
- **Retake**: Start new measurement

## Validation Testing

See `TESTING_GUIDE.md` for full protocol.

Quick validation:
1. Take 5 measurements
2. Compare with Polar H10 or similar
3. Calculate correlation
4. Target: ≥0.85 for BPM, ≥0.75 for RMSSD

## Files

- `README_POC.md` - Full documentation
- `TESTING_GUIDE.md` - Testing protocol
- `POC_STATUS.md` - Current status
- `run_poc.sh` - Quick start script

## Support

Issues? Check:
1. Physical device connected?
2. Camera permission granted?
3. Flash LED available?
4. Flutter 3.38+ installed?

Still stuck? Review `README_POC.md` troubleshooting section.

---

**Ready to measure!** 🫀📱
