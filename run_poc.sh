#!/bin/bash

# Camera HRV Measurement POC - Quick Start Script

set -e

echo "🚀 Camera HRV Measurement POC - Quick Start"
echo "=========================================="
echo ""

# Check Flutter installation
echo "📋 Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter 3.38+ first."
    echo "   Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

FLUTTER_VERSION=$(flutter --version | head -n 1)
echo "✅ Found: $FLUTTER_VERSION"
echo ""

# Check for connected devices
echo "📱 Checking for connected devices..."
DEVICES=$(flutter devices --machine | grep -c '"id"' || true)

if [ "$DEVICES" -eq 0 ]; then
    echo "❌ No devices found. Please connect a physical device."
    echo "   Note: Camera functionality requires a physical device (not emulator)"
    exit 1
fi

echo "✅ Found $DEVICES device(s)"
flutter devices
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
flutter pub get
echo "✅ Dependencies installed"
echo ""

# Check for iOS/Android specific setup
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "🍎 macOS detected - iOS development available"
    echo "   Make sure Xcode is installed and configured"
fi

echo ""
echo "🎯 Ready to run POC!"
echo ""
echo "Choose your target:"
echo "1. Run on first available device"
echo "2. Select device manually"
echo "3. Exit"
echo ""
read -p "Enter choice (1-3): " choice

case $choice in
    1)
        echo ""
        echo "🏃 Running on first available device..."
        flutter run
        ;;
    2)
        echo ""
        echo "📱 Available devices:"
        flutter devices
        echo ""
        read -p "Enter device ID: " device_id
        echo ""
        echo "🏃 Running on device: $device_id"
        flutter run -d "$device_id"
        ;;
    3)
        echo "👋 Exiting..."
        exit 0
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ POC launched successfully!"
echo ""
echo "📖 Next steps:"
echo "   1. Accept medical disclaimer"
echo "   2. Grant camera permission"
echo "   3. Complete tutorial (or skip)"
echo "   4. Try Quick Mode (30s) or Accurate Mode (60s)"
echo "   5. Place finger gently on rear camera + flash"
echo ""
echo "📚 Documentation:"
echo "   - README_POC.md - Setup and overview"
echo "   - TESTING_GUIDE.md - Testing protocol"
echo "   - POC_STATUS.md - Current status"
echo ""
