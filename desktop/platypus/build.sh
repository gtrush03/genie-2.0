#!/bin/bash
# Build Genie.app using Platypus CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/build"
APP_NAME="Genie"

mkdir -p "$OUTPUT_DIR"

# Check for platypus CLI
PLATYPUS_CLI=""
if command -v platypus &>/dev/null; then
    PLATYPUS_CLI="platypus"
elif [ -f "/usr/local/bin/platypus" ]; then
    PLATYPUS_CLI="/usr/local/bin/platypus"
elif [ -f "/opt/homebrew/bin/platypus" ]; then
    PLATYPUS_CLI="/opt/homebrew/bin/platypus"
elif [ -f "/Applications/Platypus.app/Contents/Resources/platypus_clt" ]; then
    PLATYPUS_CLI="/Applications/Platypus.app/Contents/Resources/platypus_clt"
else
    echo "ERROR: Platypus CLI not found."
    echo "Install with: brew install --cask platypus"
    echo "Then install CLI from Platypus.app > Preferences > Install Command Line Tool"
    exit 1
fi

echo "Using Platypus CLI: $PLATYPUS_CLI"
echo "Building $APP_NAME.app..."

# Generate a placeholder icon if none exists
ICON_PATH="$SCRIPT_DIR/icon.png"
if [ ! -f "$ICON_PATH" ]; then
    echo "Generating placeholder icon..."
    # Use sips to create a basic icon from a system icon
    cp /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarCustomizeIcon.icns \
       "$SCRIPT_DIR/icon.icns" 2>/dev/null || true
    ICON_PATH="$SCRIPT_DIR/icon.icns"
fi

# Build with Platypus
# -a = app name
# -o = output type (Text Window, Progress Bar, Status Menu, etc.)
# -p = interpreter
# -V = version
# -I = bundle identifier
# -y = overwrite
# -B = run in background (LSUIElement)
# -R = bundled files (additional scripts)
"$PLATYPUS_CLI" \
    -a "$APP_NAME" \
    -o 'Status Menu' \
    -p /bin/bash \
    -V "2.0.0" \
    -I "com.gtrush.genie" \
    -u "George Trushevskiy" \
    -y \
    -B \
    -c "$SCRIPT_DIR/launch.sh" \
    -f "$SCRIPT_DIR/first-run.sh" \
    -f "$SCRIPT_DIR/check-deps.sh" \
    "$OUTPUT_DIR/$APP_NAME.app"

if [ -d "$OUTPUT_DIR/$APP_NAME.app" ]; then
    echo ""
    echo "SUCCESS: $OUTPUT_DIR/$APP_NAME.app"
    echo ""
    echo "To run:  open '$OUTPUT_DIR/$APP_NAME.app'"
    echo "To install: cp -r '$OUTPUT_DIR/$APP_NAME.app' /Applications/"
    echo ""
    # Set the repo dir as an environment variable in the app's Info.plist
    defaults write "$OUTPUT_DIR/$APP_NAME.app/Contents/Info" LSEnvironment \
        -dict GENIE_REPO_DIR "$REPO_DIR"
    echo "Set GENIE_REPO_DIR=$REPO_DIR in app bundle"
else
    echo "ERROR: Build failed"
    exit 1
fi
