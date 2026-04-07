#!/bin/bash
# Genie dependency checker -- exits 0 if all good, 1 if missing deps
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ERRORS=()

# Node.js
if ! command -v node &>/dev/null; then
    ERRORS+=("Node.js not found. Install: brew install node")
fi

# Google Chrome
if [ ! -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
    ERRORS+=("Google Chrome not found at /Applications/Google Chrome.app")
fi

# Claurst binary
CLAURST_BIN="$REPO_DIR/engines/claurst/src-rust/target/release/claurst"
if [ ! -f "$CLAURST_BIN" ] && ! command -v claurst &>/dev/null; then
    ERRORS+=("claurst binary not found at $CLAURST_BIN and not on PATH")
fi

# npm dependencies
if [ ! -d "$REPO_DIR/node_modules" ]; then
    echo "Installing npm dependencies..."
    cd "$REPO_DIR" && npm install --silent
fi

# .env file
if [ ! -f "$REPO_DIR/.env" ]; then
    ERRORS+=("NEEDS_FIRST_RUN")
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
    for err in "${ERRORS[@]}"; do
        echo "ERROR: $err"
    done
    exit 1
fi

echo "ALL_GOOD"
exit 0
