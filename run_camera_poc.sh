#!/bin/bash

# Camera HRV POC Runner
# Runs only the camera-based HRV measurement POC

echo "🚀 Starting Camera HRV POC..."
echo ""

# Check if device is connected
if ! flutter devices | grep -q "iPhone"; then
    echo "❌ No iPhone detected. Please connect your iPhone."
    exit 1
fi

echo "✅ iPhone detected"
echo ""

# Clean build
echo "🧹 Cleaning build..."
flutter clean > /dev/null 2>&1

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get > /dev/null 2>&1

# Build and run
echo "🔨 Building and running..."
echo ""

flutter run \
    --dart-define=FLUTTER_WEB_USE_SKIA=false \
    --dart-define=FLUTTER_WEB_AUTO_DETECT=false \
    2>&1 | tee test/lastlog.txt

echo ""
echo "✅ POC finished. Log saved to test/lastlog.txt"
