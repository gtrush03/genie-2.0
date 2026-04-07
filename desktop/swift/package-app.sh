#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Building Genie.app (release)..."
swift build -c release 2>&1

APP_DIR="build/Genie.app/Contents"
rm -rf build/Genie.app
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

# Copy binary
cp .build/release/Genie "$APP_DIR/MacOS/Genie"

# Create Info.plist -- regular app (shows in dock)
cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Genie</string>
  <key>CFBundleIdentifier</key><string>com.gtrush.genie</string>
  <key>CFBundleName</key><string>Genie</string>
  <key>CFBundleDisplayName</key><string>Genie</string>
  <key>CFBundleVersion</key><string>2.0.0</string>
  <key>CFBundleShortVersionString</key><string>2.0.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSEnvironment</key>
  <dict>
    <key>GENIE_REPO_DIR</key><string>/Users/gtrush/Downloads/genie-2.0</string>
  </dict>
</dict>
</plist>
PLIST

# Copy icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "$APP_DIR/Resources/AppIcon.icns"
    echo "Icon: copied"
else
    echo "Icon: not found (will use default)"
fi

echo ""
echo "=== Build Complete ==="
echo "App:  build/Genie.app"
echo "Size: $(du -sh build/Genie.app | cut -f1)"
echo ""
echo "Run:     open build/Genie.app"
echo "Deploy:  cp -r build/Genie.app /Applications/"
