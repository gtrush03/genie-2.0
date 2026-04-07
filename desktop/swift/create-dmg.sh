#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Build first
./package-app.sh

DMG_NAME="Genie-2.0"
DMG_PATH="build/${DMG_NAME}.dmg"
STAGING="build/dmg-staging"

echo "Creating DMG..."
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"

# Copy app to staging
cp -r build/Genie.app "$STAGING/"

# Create Applications symlink
ln -s /Applications "$STAGING/Applications"

# Create DMG
hdiutil create -volname "$DMG_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING"

echo ""
echo "=== DMG Created ==="
echo "DMG:  $DMG_PATH"
echo "Size: $(du -sh "$DMG_PATH" | cut -f1)"
