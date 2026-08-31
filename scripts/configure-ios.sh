#!/bin/bash
set -e

# This script is run by GitHub Actions to configure the iOS project for MelodiCore

echo "🔧 Configuring iOS project for MelodiCore..."

# Paths
IOS_DIR="melodi-app/ios"
CLASSES_DIR="$IOS_DIR/Classes"
PLUGIN_FILE="$CLASSES_DIR/MelodiCorePlugin.m"
PLUGIN_HEADER="$CLASSES_DIR/MelodiCorePlugin.h"
XCFRAMEWORK_SOURCE="go_backend/MelodiCore.xcframework"
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
  echo "⚠️  XCFramework not found at $XCFRAMEWORK_SOURCE"
  exit 1
fi

# 3. Verify plugin files exist
if [ ! -f "$PLUGIN_FILE" ] || [ ! -f "$PLUGIN_HEADER" ]; then
  echo "❌ MelodiCorePlugin files not found"
  exit 1
fi

# 4. Add XCFramework to Xcode project (FRAMEWORK_SEARCH_PATHS)
if grep -q "MelodiCore.xcframework" "$PROJECT_FILE"; then
  echo "✅ MelodiCore.xcframework already in FRAMEWORK_SEARCH_PATHS"
else
  echo "📝 Adding MelodiCore.xcframework to FRAMEWORK_SEARCH_PATHS..."
  # Use a more robust approach with perl
  perl -i -pe 's/(FRAMEWORK_SEARCH_PATHS = \()/$1\n\t\t"$(SRCROOT)\/MelodiCore.xcframework",/' "$PROJECT_FILE"
fi

# 5. Add LD_RUNPATH_SEARCH_PATHS for embedded frameworks
if ! grep -q "LD_RUNPATH_SEARCH_PATHS" "$PROJECT_FILE"; then
  echo "📝 Adding LD_RUNPATH_SEARCH_PATHS..."
  perl -i -pe 's/(FRAMEWORK_SEARCH_PATHS = \([^)]*\))/$1\n\t\tLD_RUNPATH_SEARCH_PATHS = (\n\t\t\t"@executable_path\/Frameworks",\n\t\t);/' "$PROJECT_FILE"
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
  if ! grep -q "SWIFT_OBJC_BRIDGING_HEADER" "$PROJECT_FILE"; then
    perl -i -pe 's/(FRAMEWORK_SEARCH_PATHS = \([^)]*\))/$1\n\t\tSWIFT_OBJC_BRIDGING_HEADER = "Runner\/Runner-Bridging-Header.h";/' "$PROJECT_FILE"
  fi
else
  # Ensure MelodiCorePlugin.h is imported
  if ! grep -q "MelodiCorePlugin.h" "$BRIDGING_HEADER"; then
    echo '#import "MelodiCorePlugin.h"' >> "$BRIDGING_HEADER"
  fi
fi

# 6. Register plugin in AppDelegate
if ! grep -q "MelodiCorePlugin" "$APPDELEGATE"; then
  echo "📝 Registering MelodiCorePlugin in AppDelegate..."
  
  # Add import MelodiCore at the top (after existing imports)
  sed -i '' '1s/^/import MelodiCore\n/' "$APPDELEGATE"
  
  # Add plugin registration after GeneratedPluginRegistrant
  sed -i '' '/GeneratedPluginRegistrant.register(with: self)/a\
\    // Register MelodiCore plugin\
\    MelodiCorePlugin.register(with: registrar)' "$APPDELEGATE"
else
  echo "✅ MelodiCorePlugin already registered in AppDelegate"
fi

# 7. Add framework to "Frameworks, Libraries, and Embedded Content" in Xcode
# This is done by adding to the target's build phases
# We'll add a linker flag for now
if ! grep -q "MelodiCore" "$PROJECT_FILE" | grep -q "OTHER_LDFLAGS"; then
  echo "📝 Adding MelodiCore to OTHER_LDFLAGS..."
  perl -i -pe 's/(OTHER_LDFLAGS = \([^)]*\))/$1\n\t\t"-framework", "MelodiCore",/' "$PROJECT_FILE"
fi

echo "✅ iOS project configuration complete!"