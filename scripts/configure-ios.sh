#!/bin/bash
set -e

# This script is run by GitHub Actions to configure the iOS project for MelodiCore

echo "🔧 Configuring iOS project for MelodiCore..."

# Paths - support both repo root = melodi-app and nested melodi-app/melodi-app
if [ -d "melodi-app/ios" ]; then
  IOS_DIR="melodi-app/ios"
  XCFRAMEWORK_SOURCE="melodi-app/go_backend/MelodiCore.xcframework"
else
  IOS_DIR="ios"
  XCFRAMEWORK_SOURCE="go_backend/MelodiCore.xcframework"
fi
CLASSES_DIR="$IOS_DIR/Classes"
PLUGIN_FILE="$CLASSES_DIR/MelodiCorePlugin.m"
PLUGIN_HEADER="$CLASSES_DIR/MelodiCorePlugin.h"
XCFRAMEWORK_DEST="$IOS_DIR/MelodiCore.xcframework"
PROJECT_FILE="$IOS_DIR/Runner.xcodeproj/project.pbxproj"
APPDELEGATE="$IOS_DIR/Runner/AppDelegate.swift"

# 1. Ensure Classes directory exists
mkdir -p "$CLASSES_DIR"

# 2. Copy XCFramework to iOS project
if [ -d "$XCFRAMEWORK_SOURCE" ]; then
  echo "📦 Copying XCFramework to iOS project..."
  rm -rf "$XCFRAMEWORK_DEST"
  cp -R "$XCFRAMEWORK_SOURCE" "$XCFRAMEWORK_DEST"
else
  echo "⚠️  XCFramework not found at $XCFRAMEWORK_SOURCE - skipping (Go backend may be disabled)"
  echo "    Flutter build will continue without Go XCFramework"
  # Don't fail the build - Go XCFramework is optional for CI
fi

# 3. Verify plugin files exist (optional)
if [ ! -f "$PLUGIN_FILE" ] || [ ! -f "$PLUGIN_HEADER" ]; then
  echo "⚠️  MelodiCorePlugin files not found at $PLUGIN_FILE - skipping check"
else
  echo "✅ MelodiCorePlugin files found"
fi

# 4. Add XCFramework to Xcode project (FRAMEWORK_SEARCH_PATHS) - only if project exists
if [ -f "$PROJECT_FILE" ]; then
  if grep -q "MelodiCore.xcframework" "$PROJECT_FILE" 2>/dev/null; then
    echo "✅ MelodiCore.xcframework already in FRAMEWORK_SEARCH_PATHS"
  else
    echo "📝 Adding MelodiCore.xcframework to FRAMEWORK_SEARCH_PATHS..."
    # Use perl (works on both macOS and Linux)
    perl -i -pe 's/(FRAMEWORK_SEARCH_PATHS = \()/$1\n\t\t"$(SRCROOT)\/MelodiCore.xcframework",/' "$PROJECT_FILE" 2>/dev/null || echo "⚠️  Could not patch FRAMEWORK_SEARCH_PATHS"
  fi

  # 5. Add LD_RUNPATH_SEARCH_PATHS for embedded frameworks
  if ! grep -q "LD_RUNPATH_SEARCH_PATHS" "$PROJECT_FILE" 2>/dev/null; then
    echo "📝 Adding LD_RUNPATH_SEARCH_PATHS..."
    perl -i -pe 's/(FRAMEWORK_SEARCH_PATHS = \([^)]*\))/$1\n\t\tLD_RUNPATH_SEARCH_PATHS = (\n\t\t\t"@executable_path\/Frameworks",\n\t\t);/' "$PROJECT_FILE" 2>/dev/null || true
  fi
else
  echo "⚠️  project.pbxproj not found, skipping Xcode patch"
fi

# 6. Create bridging header for Swift-Objective-C interop
BRIDGING_HEADER="$IOS_DIR/Runner/Runner-Bridging-Header.h"
if [ ! -f "$BRIDGING_HEADER" ]; then
  echo "📝 Creating bridging header..."
  cat > "$BRIDGING_HEADER" << 'EOF'
//
//  Runner-Bridging-Header.h
//  Runner
//

#import "MelodiCorePlugin.h"
EOF
  
  # Add bridging header to build settings
  if [ -f "$PROJECT_FILE" ] && ! grep -q "SWIFT_OBJC_BRIDGING_HEADER" "$PROJECT_FILE" 2>/dev/null; then
    perl -i -pe 's/(FRAMEWORK_SEARCH_PATHS = \([^)]*\))/$1\n\t\tSWIFT_OBJC_BRIDGING_HEADER = "Runner\/Runner-Bridging-Header.h";/' "$PROJECT_FILE" 2>/dev/null || true
  fi
else
  # Ensure MelodiCorePlugin.h is imported
  if ! grep -q "MelodiCorePlugin.h" "$BRIDGING_HEADER" 2>/dev/null; then
    echo '#import "MelodiCorePlugin.h"' >> "$BRIDGING_HEADER"
  fi
fi

# 6. Register plugin in AppDelegate (optional)
if [ -f "$APPDELEGATE" ]; then
  if ! grep -q "MelodiCorePlugin" "$APPDELEGATE" 2>/dev/null; then
    echo "📝 Registering MelodiCorePlugin in AppDelegate..."
    
    # macOS BSD sed vs GNU sed
    if sed --version >/dev/null 2>&1; then
      # GNU sed (Linux)
      sed -i '1s/^/import MelodiCore\n/' "$APPDELEGATE" 2>/dev/null || true
      sed -i '/GeneratedPluginRegistrant.register(with: self)/a \    // Register MelodiCore plugin\n    MelodiCorePlugin.register(with: registrar)' "$APPDELEGATE" 2>/dev/null || true
    else
      # BSD sed (macOS)
      sed -i '' '1s/^/import MelodiCore\n/' "$APPDELEGATE" 2>/dev/null || true
      sed -i '' '/GeneratedPluginRegistrant.register(with: self)/a\
\    // Register MelodiCore plugin\
\    MelodiCorePlugin.register(with: registrar)' "$APPDELEGATE" 2>/dev/null || true
    fi
  else
    echo "✅ MelodiCorePlugin already registered in AppDelegate"
  fi
else
  echo "⚠️  AppDelegate.swift not found, skipping plugin registration"
fi

# 7. Add framework to "Frameworks, Libraries, and Embedded Content" in Xcode
# This is done by adding to the target's build phases
# We'll add a linker flag for now
if [ -f "$PROJECT_FILE" ] && ! grep -q "MelodiCore" "$PROJECT_FILE" 2>/dev/null | grep -q "OTHER_LDFLAGS" 2>/dev/null; then
  echo "📝 Adding MelodiCore to OTHER_LDFLAGS..."
  perl -i -pe 's/(OTHER_LDFLAGS = \([^)]*\))/$1\n\t\t"-framework", "MelodiCore",/' "$PROJECT_FILE" 2>/dev/null || true
fi

echo "✅ iOS project configuration complete!"