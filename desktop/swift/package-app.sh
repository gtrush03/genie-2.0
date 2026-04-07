#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release 2>&1
APP_DIR="build/Genie.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"
cp .build/release/Genie "$APP_DIR/MacOS/Genie"
# Create Info.plist
cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>Genie</string>
  <key>CFBundleIdentifier</key><string>com.gtrush.genie</string>
  <key>CFBundleName</key><string>Genie</string>
  <key>CFBundleVersion</key><string>2.0.0</string>
  <key>CFBundleShortVersionString</key><string>2.0.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSUIElement</key><true/>
  <key>LSEnvironment</key>
  <dict>
    <key>GENIE_REPO_DIR</key><string>/Users/gtrush/Downloads/genie-2.0</string>
  </dict>
</dict>
</plist>
PLIST
echo "Built: build/Genie.app"
echo "Run: open build/Genie.app"
