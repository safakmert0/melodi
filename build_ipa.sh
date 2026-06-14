#!/bin/bash
#=============================================================================
# Melodi - iOS .ipa Build Script
# Requires: macOS with Xcode 15+, Flutter 3.16+, CocoaPods
#=============================================================================

set -e

echo "=========================================="
echo "  Melodi - iOS Build Script"
echo "=========================================="

# Check prerequisites
if ! command -v flutter &> /dev/null; then
    echo "ERROR: Flutter is not installed!"
    echo "Install it from: https://flutter.dev/docs/get-started/install/macos"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo "ERROR: Xcode is not installed!"
    echo "Install it from the Mac App Store."
    exit 1
fi

echo ""
echo "[1/7] Cleaning previous builds..."
flutter clean

echo ""
echo "[2/7] Installing dependencies..."
flutter pub get

echo ""
echo "[3/7] Installing CocoaPods..."
cd ios
pod install --repo-update
cd ..

echo ""
echo "[4/7] Building iOS (unsigned .app)..."
flutter build ios --debug --no-codesign

echo ""
echo "[5/7] Creating unsigned .ipa..."
mkdir -p build/unsigned_ipa/Payload
cp -r build/ios/debug/iphoneos/Runner.app build/unsigned_ipa/Payload/
cd build/unsigned_ipa
zip -r ../Melodi-unsigned.ipa Payload/
cd ../..

echo ""
echo "[6/7] Cleaning up..."
rm -rf build/unsigned_ipa

echo ""
echo "=========================================="
echo "  BUILD COMPLETE!"
echo "=========================================="
echo ""
echo "Unsigned IPA: build/Melodi-unsigned.ipa"
echo ""
echo "To sign and install on a device, you need:"
echo "  1. An Apple Developer account"
echo "  2. A signing certificate and provisioning profile"
echo ""
echo "Then run:"
echo "  flutter build ios --release"
echo "  or open ios/Runner.xcworkspace in Xcode"
echo "  Product > Archive > Distribute App"
echo ""
echo "=========================================="
