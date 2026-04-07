# Genie Desktop App -- Build Spec & Execution Prompts

## Overview

**What we are building:** A native macOS menu bar app that wraps the existing Genie 2.0 engine. The user double-clicks Genie.app, it handles all setup (Chrome CDP, Node server, API keys), and sits in the menu bar showing status. The existing `server.mjs` + `dispatcher.mjs` + `claurst` pipeline is untouched -- the desktop app is purely a process orchestrator and settings UI around it.

**Fundamental rule:** Everything goes in `desktop/` subdirectory. ZERO changes to existing code in `src/`, `config/`, `skills/`, `engines/`, or any other current working files.

**Two phases:**
- **Phase A:** Platypus quick `.app` (2 hours) -- shell script wrapper, ships today
- **Phase B:** Native Swift menu bar app (2-3 days) -- the real product
- **Phase C:** Distribution -- DMG, download link, beta testers

**Environment (verified):**
- macOS with Xcode 26.2, Swift 6.2.3 (arm64)
- Homebrew 5.1.3 installed
- Platypus: NOT installed (Phase A will install it via brew)
- Claurst binary exists at: `engines/claurst/src-rust/target/release/claurst`
- Node.js available
- Google Chrome expected at `/Applications/Google Chrome.app`

**Reference patterns:** The OpenClaw macOS app (`engines/openclaw/apps/macos/`) provides excellent patterns for:
- Menu bar app entry point: `Sources/OpenClaw/MenuBar.swift`
- Process management: `Sources/OpenClaw/GatewayProcessManager.swift`
- Settings UI: `Sources/OpenClaw/GeneralSettings.swift` (renamed from Settings/)

---

## Phase A: Quick .app via Platypus (ship today)

### What it does

A shell script wrapped as a macOS `.app` via Platypus:
1. On first run: prompts for Telegram bot token + chat ID, writes `.env`
2. Every run: starts Chrome CDP (if not running), starts Node server, sits in menu bar
3. Menu bar icon shows Genie is running; clicking it shows status + quit option
4. Logs go to `/tmp/genie-logs/`

### Files to create

All files go in `desktop/platypus/`:

```
desktop/platypus/
  launch.sh          -- main launcher (Platypus entry point)
  first-run.sh       -- first-time setup wizard (API key prompts)
  check-deps.sh      -- dependency checker
  build.sh           -- builds the .app using platypus CLI
  icon.png           -- app icon (placeholder; 512x512)
```

### Execution Prompt A1: Install Platypus + Create Launcher Scripts

```
CONTEXT: We are building a macOS .app wrapper for the Genie 2.0 engine using Platypus.
Platypus turns shell scripts into native macOS apps with menu bar support.
The repo lives at /Users/gtrush/Downloads/genie-2.0/
The existing server is at src/core/server.mjs and must NOT be modified.
All new files go in desktop/platypus/ -- create the directory if needed.

DO NOT modify any file outside desktop/platypus/.

STEP 1: Install Platypus CLI via Homebrew (if not already installed):

    brew install --cask platypus
    # Platypus CLI tool is at /usr/local/bin/platypus or installed via the app
    # If the cask doesn't include CLI, install it from Platypus.app preferences

STEP 2: Create desktop/platypus/check-deps.sh with this EXACT content:

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

STEP 3: Create desktop/platypus/first-run.sh with this EXACT content:

#!/bin/bash
# Genie first-run setup -- prompts for API keys via osascript dialogs
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="$REPO_DIR/.env"

# Copy template
cp "$REPO_DIR/.env.example" "$ENV_FILE"

prompt_key() {
    local TITLE="$1"
    local MESSAGE="$2"
    local DEFAULT="$3"
    local RESULT
    RESULT=$(osascript -e "
        set theResponse to display dialog \"$MESSAGE\" default answer \"$DEFAULT\" with title \"$TITLE\" buttons {\"Skip\", \"Save\"} default button \"Save\"
        if button returned of theResponse is \"Save\" then
            return text returned of theResponse
        else
            return \"\"
        end if
    " 2>/dev/null) || true
    echo "$RESULT"
}

# Required: Telegram
TELEGRAM_TOKEN=$(prompt_key "Genie Setup" "Telegram Bot Token (required):\n\nTalk to @BotFather on Telegram -> /newbot -> paste token" "")
if [ -z "$TELEGRAM_TOKEN" ]; then
    osascript -e 'display alert "Genie needs a Telegram bot token to report wish results." as critical'
    exit 1
fi
sed -i '' "s|TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=$TELEGRAM_TOKEN|" "$ENV_FILE"

TELEGRAM_CHAT=$(prompt_key "Genie Setup" "Telegram Chat ID (required):\n\nSend any message to @userinfobot to find yours" "")
if [ -z "$TELEGRAM_CHAT" ]; then
    osascript -e 'display alert "Genie needs your Telegram chat ID." as critical'
    exit 1
fi
sed -i '' "s|TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=$TELEGRAM_CHAT|" "$ENV_FILE"

# Test Telegram
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT" \
    -d text="Genie is alive on a new machine." \
    --max-time 10 2>/dev/null) || HTTP_CODE="000"

if [ "$HTTP_CODE" != "200" ]; then
    osascript -e 'display alert "Telegram test failed (HTTP '$HTTP_CODE'). Check your token and chat ID." as warning'
fi

# Optional: OpenRouter
OPENROUTER_KEY=$(prompt_key "Genie Setup" "OpenRouter API Key (optional):\n\nUsed for AI model routing. Press Skip to use defaults." "")
if [ -n "$OPENROUTER_KEY" ]; then
    sed -i '' "s|OPENROUTER_API_KEY=.*|OPENROUTER_API_KEY=$OPENROUTER_KEY|" "$ENV_FILE"
fi

# Optional: Anthropic
ANTHROPIC_KEY=$(prompt_key "Genie Setup" "Anthropic API Key (optional):\n\nUsed by claurst dispatcher. Skip if using OpenRouter." "")
if [ -n "$ANTHROPIC_KEY" ]; then
    sed -i '' "s|ANTHROPIC_API_KEY=.*|ANTHROPIC_API_KEY=$ANTHROPIC_KEY|" "$ENV_FILE"
fi

# Optional: Stripe
STRIPE_KEY=$(prompt_key "Genie Setup" "Stripe Secret Key (optional):\n\nEnables payment link wishes. Skip if not needed." "")
if [ -n "$STRIPE_KEY" ]; then
    sed -i '' "s|STRIPE_SECRET_KEY=.*|STRIPE_SECRET_KEY=$STRIPE_KEY|" "$ENV_FILE"
    sed -i '' "s|STRIPE_API_KEY=.*|STRIPE_API_KEY=$STRIPE_KEY|" "$ENV_FILE"
fi

osascript -e 'display notification "Setup complete! Genie is starting..." with title "Genie"'
echo "SETUP_COMPLETE"

STEP 4: Create desktop/platypus/launch.sh with this EXACT content:

#!/bin/bash
# Genie Desktop Launcher -- Platypus entry point
# This script is the main executable that Platypus wraps into a .app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# When running inside a .app bundle, the script is in Contents/Resources/
# When running standalone, it is in desktop/platypus/
if [[ "$SCRIPT_DIR" == *"Contents/Resources"* ]]; then
    # Inside .app bundle -- repo is bundled or at a known location
    REPO_DIR="${GENIE_REPO_DIR:-$HOME/Downloads/genie-2.0}"
else
    REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

export REPO_DIR
LOG_DIR="/tmp/genie-logs"
mkdir -p "$LOG_DIR" "$HOME/.genie/browser-profile"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [DESKTOP] $1" >> "$LOG_DIR/desktop.log"
    echo "STATUS: $1"
}

# ── Dependency check ──────────────────────────────────────────────────────
log "Checking dependencies..."
DEP_CHECK=$("$SCRIPT_DIR/check-deps.sh" 2>&1) || true

if echo "$DEP_CHECK" | grep -q "NEEDS_FIRST_RUN"; then
    log "First run detected -- launching setup wizard"
    "$SCRIPT_DIR/first-run.sh"
    if [ $? -ne 0 ]; then
        log "Setup cancelled"
        exit 1
    fi
elif echo "$DEP_CHECK" | grep -q "ERROR:"; then
    # Show errors that aren't NEEDS_FIRST_RUN
    REAL_ERRORS=$(echo "$DEP_CHECK" | grep "ERROR:" | grep -v "NEEDS_FIRST_RUN" || true)
    if [ -n "$REAL_ERRORS" ]; then
        osascript -e "display alert \"Genie dependency check failed\" message \"$REAL_ERRORS\" as critical"
        exit 1
    fi
fi

# ── Start Chrome CDP (if not already running) ────────────────────────────
CDP_UP=false
if curl -s -o /dev/null -w '' --max-time 2 http://127.0.0.1:9222/json/version 2>/dev/null; then
    CDP_UP=true
    log "Chrome CDP already running on :9222"
fi

if [ "$CDP_UP" = false ]; then
    log "Starting Chrome with CDP on :9222..."

    # Check if a LaunchAgent is installed
    if launchctl list 2>/dev/null | grep -q "com.genie.chrome"; then
        launchctl kickstart -k "gui/$(id -u)/com.genie.chrome" 2>/dev/null || true
    else
        # Direct launch
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
            --user-data-dir="$HOME/.genie/browser-profile" \
            --remote-debugging-port=9222 \
            --remote-debugging-address=127.0.0.1 \
            --no-first-run \
            --no-default-browser-check \
            --restore-last-session \
            --disable-features=ChromeWhatsNewUI \
            > "$LOG_DIR/chrome.out.log" 2> "$LOG_DIR/chrome.err.log" &
        CHROME_PID=$!
        log "Chrome started (PID $CHROME_PID)"
    fi

    # Wait for CDP to be ready
    for i in $(seq 1 15); do
        if curl -s -o /dev/null --max-time 2 http://127.0.0.1:9222/json/version 2>/dev/null; then
            CDP_UP=true
            log "Chrome CDP ready after ${i}s"
            break
        fi
        sleep 1
    done

    if [ "$CDP_UP" = false ]; then
        log "WARNING: Chrome CDP did not respond after 15s"
        osascript -e 'display notification "Chrome CDP failed to start. Browser wishes may not work." with title "Genie"'
    fi
fi

# ── Start Node Server ────────────────────────────────────────────────────
NODE_BIN=$(which node)
SERVER_SCRIPT="$REPO_DIR/src/core/server.mjs"

# Check if server is already running via LaunchAgent
if launchctl list 2>/dev/null | grep -q "com.genie.server"; then
    log "Server LaunchAgent already loaded"
    SERVER_RUNNING=true
else
    SERVER_RUNNING=false
fi

# Check if our server process is already running
if pgrep -f "node.*server.mjs" > /dev/null 2>&1; then
    log "Server process already running"
    SERVER_RUNNING=true
fi

if [ "$SERVER_RUNNING" = false ]; then
    log "Starting Genie server..."
    cd "$REPO_DIR"
    "$NODE_BIN" "$SERVER_SCRIPT" >> "$LOG_DIR/server.out.log" 2>> "$LOG_DIR/server.err.log" &
    SERVER_PID=$!
    log "Server started (PID $SERVER_PID)"

    # Verify it started
    sleep 3
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        LAST_ERR=$(tail -5 "$LOG_DIR/server.err.log" 2>/dev/null || echo "unknown error")
        log "Server failed to start: $LAST_ERR"
        osascript -e "display alert \"Genie server failed to start\" message \"$LAST_ERR\" as critical"
        exit 1
    fi
    log "Server verified running"
fi

# ── Running ───────────────────────────────────────────────────────────────
log "Genie is live"
osascript -e 'display notification "Genie is live. Say \"Genie\" in a JellyJelly video." with title "Genie" subtitle "Watching for wishes..."'

# Keep the script alive so Platypus shows it as running
# Platypus "Status Menu" app type will show our STATUSMENU items
# For a simple text-based status, we output PROGRESS lines

echo "QUITACTION"

# Heartbeat loop -- keeps the menu bar app alive and monitors processes
while true; do
    sleep 30

    # Check server health
    if ! pgrep -f "node.*server.mjs" > /dev/null 2>&1; then
        log "Server died -- restarting..."
        cd "$REPO_DIR"
        "$NODE_BIN" "$SERVER_SCRIPT" >> "$LOG_DIR/server.out.log" 2>> "$LOG_DIR/server.err.log" &
        log "Server restarted (PID $!)"
    fi

    # Check Chrome CDP
    if ! curl -s -o /dev/null --max-time 2 http://127.0.0.1:9222/json/version 2>/dev/null; then
        log "Chrome CDP down"
    fi
done

STEP 5: Make all scripts executable:

    chmod +x desktop/platypus/launch.sh
    chmod +x desktop/platypus/first-run.sh
    chmod +x desktop/platypus/check-deps.sh

VERIFICATION:
    # Test the dependency checker
    bash desktop/platypus/check-deps.sh
    # Should output ALL_GOOD or list specific errors
```

### Execution Prompt A2: Build the .app with Platypus

```
CONTEXT: We have launcher scripts in /Users/gtrush/Downloads/genie-2.0/desktop/platypus/.
Now we need to build the actual .app bundle using the Platypus CLI.
DO NOT modify any file outside desktop/.

STEP 1: Create desktop/platypus/build.sh with this EXACT content:

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

STEP 2: Make it executable and run:

    chmod +x desktop/platypus/build.sh
    bash desktop/platypus/build.sh

STEP 3: Verify the .app:

    # Check it exists
    ls -la desktop/platypus/build/Genie.app/
    # Check the bundle structure
    ls desktop/platypus/build/Genie.app/Contents/Resources/
    # Should contain: launch.sh, first-run.sh, check-deps.sh
    # Test launch (will appear in menu bar)
    open desktop/platypus/build/Genie.app
```

### Execution Prompt A3: Test and Fix the Platypus App

```
CONTEXT: The Genie.app was built at /Users/gtrush/Downloads/genie-2.0/desktop/platypus/build/Genie.app
We need to test it end-to-end and fix any issues.
DO NOT modify any file outside desktop/.

STEP 1: Launch the app and check logs:

    open /Users/gtrush/Downloads/genie-2.0/desktop/platypus/build/Genie.app
    sleep 5
    cat /tmp/genie-logs/desktop.log

STEP 2: Check if Chrome CDP started:

    curl -s http://127.0.0.1:9222/json/version | head -c 200

STEP 3: Check if server started:

    pgrep -f "node.*server.mjs"
    tail -20 /tmp/genie-logs/server.out.log

STEP 4: If there are errors, fix the specific script in desktop/platypus/ that
failed. Common issues:
- Script path resolution inside .app bundle (Contents/Resources/ vs standalone)
- Environment variables not inherited
- Chrome not starting because it is already running under a different profile

STEP 5: Kill test processes when done:

    pkill -f "node.*server.mjs" || true
    # Don't kill Chrome if user was already using it

The app should:
- Appear in the menu bar (or as a status item)
- Show "Genie is live" notification
- Have Chrome CDP responding on :9222
- Have the Node server running and polling JellyJelly
```

---

## Phase B: Native Swift Menu Bar App (the real product)

### Architecture

A native SwiftUI app using `MenuBarExtra` that manages the full Genie lifecycle:

**Process management:**
- Chrome CDP process (persistent browser with logged-in sessions)
- Node.js server process (`src/core/server.mjs`)
- Claurst binary location detection (same logic as `dispatcher.mjs` lines 20-26)

**User-facing features:**
- Menu bar icon with status indicator (idle / processing wish / error)
- Settings window: API keys (stored in macOS Keychain), service login status, budget limits
- Global hotkey: Cmd+Shift+G opens a "wish input" text field (manual wish, bypasses JellyJelly)
- Notifications: wish status via macOS notifications + existing Telegram integration
- First-run onboarding wizard: API keys, Chrome login, verification
- Auto-start at login via LaunchAgent

**Reference patterns from OpenClaw macOS app (DO NOT modify these files, only read for patterns):**
- `engines/openclaw/apps/macos/Sources/OpenClaw/MenuBar.swift` -- App entry point with `MenuBarExtra`, status icon, settings window
- `engines/openclaw/apps/macos/Sources/OpenClaw/GatewayProcessManager.swift` -- Process lifecycle management (start/stop/attach/health check), singleton `@Observable` pattern
- `engines/openclaw/apps/macos/Sources/OpenClaw/GeneralSettings.swift` -- Settings UI with toggle rows, status cards, health checks

### Project structure

All files go in `desktop/swift/`:

```
desktop/swift/
  Package.swift                  -- Swift Package Manager (no Xcode project needed)
  Sources/
    Genie/
      GenieApp.swift             -- @main, MenuBarExtra, app lifecycle
      GenieState.swift           -- @Observable singleton, all app state
      Managers/
        ServerManager.swift      -- Node.js server process lifecycle
        ChromeManager.swift      -- Chrome CDP process lifecycle
        ConfigManager.swift      -- .env read/write, Keychain for secrets
      Views/
        MenuContent.swift        -- menu bar dropdown content
        SettingsView.swift       -- settings window (API keys, budget, status)
        OnboardingView.swift     -- first-run wizard
        WishInputView.swift      -- Cmd+Shift+G floating panel
      Utilities/
        GlobalHotkey.swift       -- Carbon hotkey registration
        ProcessHelper.swift      -- spawn/kill/monitor helpers
        Notifications.swift      -- macOS UserNotifications wrapper
  Resources/
    Assets.xcassets/
      AppIcon.appiconset/        -- app icon
      GenieMenuBar.imageset/     -- menu bar icon (template image)
```

### Execution Prompt B1: Create Swift Package Structure

```
CONTEXT: We are building a native macOS menu bar app for Genie 2.0 using Swift
Package Manager (SPM). This avoids the complexity of Xcode project files.
The repo lives at /Users/gtrush/Downloads/genie-2.0/
All new files go in desktop/swift/ -- DO NOT modify any file outside desktop/.

The app wraps the existing Node.js server (src/core/server.mjs) and Chrome CDP
process. It does NOT replace them -- it manages their lifecycle.

Reference: OpenClaw's MenuBar.swift at
engines/openclaw/apps/macos/Sources/OpenClaw/MenuBar.swift
shows the @main App struct with MenuBarExtra pattern.

STEP 1: Create the directory structure:

    mkdir -p /Users/gtrush/Downloads/genie-2.0/desktop/swift/Sources/Genie/Managers
    mkdir -p /Users/gtrush/Downloads/genie-2.0/desktop/swift/Sources/Genie/Views
    mkdir -p /Users/gtrush/Downloads/genie-2.0/desktop/swift/Sources/Genie/Utilities
    mkdir -p /Users/gtrush/Downloads/genie-2.0/desktop/swift/Resources/Assets.xcassets/AppIcon.appiconset
    mkdir -p /Users/gtrush/Downloads/genie-2.0/desktop/swift/Resources/Assets.xcassets/GenieMenuBar.imageset

STEP 2: Create desktop/swift/Package.swift with this EXACT content:

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Genie",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Genie",
            path: "Sources/Genie",
            resources: [
                .process("../../Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)

STEP 3: Create a minimal GenieApp.swift to verify the build works.
Write to desktop/swift/Sources/Genie/GenieApp.swift:

import SwiftUI

@main
struct GenieApp: App {
    var body: some Scene {
        MenuBarExtra("Genie", systemImage: "wand.and.stars") {
            Text("Genie 2.0")
                .font(.headline)
            Divider()
            Text("Status: Starting...")
                .font(.caption)
            Divider()
            Button("Quit Genie") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

STEP 4: Create placeholder asset catalogs.
Write to desktop/swift/Resources/Assets.xcassets/Contents.json:

{
  "info": { "version": 1, "author": "xcode" }
}

Write to desktop/swift/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json:

{
  "images": [
    { "idiom": "mac", "scale": "1x", "size": "128x128" },
    { "idiom": "mac", "scale": "2x", "size": "128x128" },
    { "idiom": "mac", "scale": "1x", "size": "256x256" },
    { "idiom": "mac", "scale": "2x", "size": "256x256" },
    { "idiom": "mac", "scale": "1x", "size": "512x512" },
    { "idiom": "mac", "scale": "2x", "size": "512x512" }
  ],
  "info": { "version": 1, "author": "xcode" }
}

Write to desktop/swift/Resources/Assets.xcassets/GenieMenuBar.imageset/Contents.json:

{
  "images": [
    { "idiom": "universal", "scale": "1x" },
    { "idiom": "universal", "scale": "2x" },
    { "idiom": "universal", "scale": "3x" }
  ],
  "info": { "version": 1, "author": "xcode" },
  "properties": { "template-rendering-intent": "template" }
}

STEP 5: Build and verify:

    cd /Users/gtrush/Downloads/genie-2.0/desktop/swift && swift build 2>&1

Expected: Build succeeds. A menu bar app binary is created at .build/debug/Genie

STEP 6: Test run:

    cd /Users/gtrush/Downloads/genie-2.0/desktop/swift && swift run &
    sleep 3
    # Should see a wand icon in the menu bar
    # Click it to see "Genie 2.0" and "Quit Genie"
    # Kill it when done
    kill %1 2>/dev/null || true
```

### Execution Prompt B2: Build GenieState.swift (Observable State)

```
CONTEXT: Building the Genie macOS menu bar app at /Users/gtrush/Downloads/genie-2.0/desktop/swift/.
Phase B, Step 2: Create the central state object that the entire app observes.
DO NOT modify any file outside desktop/.

Reference pattern: OpenClaw's GatewayProcessManager.swift at
engines/openclaw/apps/macos/Sources/OpenClaw/GatewayProcessManager.swift
uses @Observable + @MainActor singleton with Status enum. We follow the same pattern.

The Genie server has these states we need to track:
- Chrome CDP: stopped / starting / running / failed
- Node server: stopped / starting / running / failed
- Active wishes: count of currently running dispatches
- Last wish: title, status, duration, cost

Create desktop/swift/Sources/Genie/GenieState.swift with this EXACT content:

import Foundation
import Observation
import os

@MainActor
@Observable
final class GenieState {
    static let shared = GenieState()

    // ── Process Status ─────────────────────────────────────────────────
    enum ProcessStatus: Equatable {
        case stopped
        case starting
        case running(pid: Int32?)
        case failed(String)

        var label: String {
            switch self {
            case .stopped: return "Stopped"
            case .starting: return "Starting..."
            case let .running(pid):
                if let pid { return "Running (PID \(pid))" }
                return "Running"
            case let .failed(reason): return "Failed: \(reason)"
            }
        }

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    // ── Wish Tracking ──────────────────────────────────────────────────
    struct WishInfo: Identifiable {
        let id = UUID()
        let title: String
        let creator: String
        let startedAt: Date
        var status: WishStatus = .running
        var duration: TimeInterval?
        var cost: Double?
    }

    enum WishStatus {
        case running
        case completed
        case failed(String)
    }

    // ── State Properties ───────────────────────────────────────────────
    private(set) var chromeStatus: ProcessStatus = .stopped
    private(set) var serverStatus: ProcessStatus = .stopped
    private(set) var activeWishes: [WishInfo] = []
    private(set) var lastWish: WishInfo?
    private(set) var totalWishesCompleted: Int = 0
    private(set) var totalCostUSD: Double = 0

    var isFullyRunning: Bool {
        chromeStatus.isRunning && serverStatus.isRunning
    }

    var overallStatusLabel: String {
        if !chromeStatus.isRunning && !serverStatus.isRunning { return "Offline" }
        if !chromeStatus.isRunning { return "Chrome Down" }
        if !serverStatus.isRunning { return "Server Down" }
        if !activeWishes.isEmpty { return "Granting \(activeWishes.count) wish\(activeWishes.count == 1 ? "" : "es")..." }
        return "Watching"
    }

    var menuBarIconName: String {
        if !isFullyRunning { return "wand.and.stars.inverse" }
        if !activeWishes.isEmpty { return "sparkles" }
        return "wand.and.stars"
    }

    // ── Configuration ──────────────────────────────────────────────────
    var repoDir: String = ""
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "genie.onboardingComplete") }
        set { UserDefaults.standard.set(newValue, forKey: "genie.onboardingComplete") }
    }
    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: "genie.launchAtLogin") }
        set { UserDefaults.standard.set(newValue, forKey: "genie.launchAtLogin") }
    }
    var maxBudgetUSD: Double {
        get { UserDefaults.standard.double(forKey: "genie.maxBudgetUSD").nonZero ?? 25.0 }
        set { UserDefaults.standard.set(newValue, forKey: "genie.maxBudgetUSD") }
    }

    // ── Logging ────────────────────────────────────────────────────────
    private let logger = Logger(subsystem: "com.gtrush.genie", category: "state")

    // ── Mutations ──────────────────────────────────────────────────────
    func setChromeStatus(_ status: ProcessStatus) {
        logger.debug("Chrome: \(status.label)")
        chromeStatus = status
    }

    func setServerStatus(_ status: ProcessStatus) {
        logger.debug("Server: \(status.label)")
        serverStatus = status
    }

    func addWish(title: String, creator: String) -> UUID {
        let wish = WishInfo(title: title, creator: creator, startedAt: Date())
        activeWishes.append(wish)
        logger.info("Wish started: \(title) by \(creator)")
        return wish.id
    }

    func completeWish(id: UUID, cost: Double?) {
        guard let idx = activeWishes.firstIndex(where: { $0.id == id }) else { return }
        var wish = activeWishes.remove(at: idx)
        wish.status = .completed
        wish.duration = Date().timeIntervalSince(wish.startedAt)
        wish.cost = cost
        lastWish = wish
        totalWishesCompleted += 1
        if let cost { totalCostUSD += cost }
        logger.info("Wish completed: \(wish.title) in \(wish.duration ?? 0)s, cost $\(cost ?? 0)")
    }

    func failWish(id: UUID, error: String) {
        guard let idx = activeWishes.firstIndex(where: { $0.id == id }) else { return }
        var wish = activeWishes.remove(at: idx)
        wish.status = .failed(error)
        wish.duration = Date().timeIntervalSince(wish.startedAt)
        lastWish = wish
        logger.error("Wish failed: \(wish.title) -- \(error)")
    }

    // ── Repo Directory Resolution ──────────────────────────────────────
    func resolveRepoDir() {
        // Check environment variable first (set by .app bundle)
        if let envDir = ProcessInfo.processInfo.environment["GENIE_REPO_DIR"],
           FileManager.default.fileExists(atPath: envDir + "/package.json") {
            repoDir = envDir
            return
        }
        // Check common locations
        let candidates = [
            NSHomeDirectory() + "/Downloads/genie-2.0",
            NSHomeDirectory() + "/genie-2.0",
            NSHomeDirectory() + "/Projects/genie-2.0",
            "/opt/genie",
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate + "/package.json") {
                repoDir = candidate
                return
            }
        }
        logger.error("Could not find Genie repo directory")
    }
}

// Helper for non-zero doubles from UserDefaults
private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}

VERIFICATION:
    cd /Users/gtrush/Downloads/genie-2.0/desktop/swift && swift build 2>&1
    # Should compile successfully
```

### Execution Prompt B3: Build ServerManager.swift + ChromeManager.swift (Process Management)

```
CONTEXT: Building the Genie macOS menu bar app at /Users/gtrush/Downloads/genie-2.0/desktop/swift/.
Phase B, Step 3: Process managers for the Node.js server and Chrome CDP.
DO NOT modify any file outside desktop/.

Key facts from the existing codebase:
- Server: node src/core/server.mjs (working directory must be the repo root)
- Server loads .env from ../../.env relative to server.mjs (line 12 of server.mjs)
- Chrome CDP: /Applications/Google Chrome.app with --remote-debugging-port=9222
- Chrome profile: ~/.genie/browser-profile
- Claurst binary: engines/claurst/src-rust/target/release/claurst (line 22 of dispatcher.mjs)
- Logs: /tmp/genie-logs/

Reference pattern: OpenClaw's GatewayProcessManager.swift at
engines/openclaw/apps/macos/Sources/OpenClaw/GatewayProcessManager.swift
shows the singleton @Observable pattern, start/stop/attach lifecycle, and
health checking with retry loops.

STEP 1: Create desktop/swift/Sources/Genie/Utilities/ProcessHelper.swift:

import Foundation
import os

enum ProcessHelper {
    private static let logger = Logger(subsystem: "com.gtrush.genie", category: "process")

    /// Spawn a long-running process. Returns the Process handle.
    static func spawn(
        executablePath: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        stdoutPath: String? = nil,
        stderrPath: String? = nil
    ) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        if let env = environment {
            var merged = ProcessInfo.processInfo.environment
            for (k, v) in env { merged[k] = v }
            process.environment = merged
        }

        // Log files
        let logDir = "/tmp/genie-logs"
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)

        if let outPath = stdoutPath {
            FileManager.default.createFile(atPath: outPath, contents: nil)
            process.standardOutput = FileHandle(forWritingAtPath: outPath)
        }
        if let errPath = stderrPath {
            FileManager.default.createFile(atPath: errPath, contents: nil)
            process.standardError = FileHandle(forWritingAtPath: errPath)
        }

        try process.run()
        logger.info("Spawned \(executablePath) PID=\(process.processIdentifier)")
        return process
    }

    /// Check if a process with given PID is still running
    static func isRunning(pid: Int32) -> Bool {
        kill(pid, 0) == 0
    }

    /// Find PIDs matching a command pattern
    static func findPIDs(matching pattern: String) -> [Int32] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", pattern]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
        } catch {
            return []
        }
    }

    /// Kill process by PID (SIGTERM, then SIGKILL after delay)
    static func terminate(pid: Int32) {
        kill(pid, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if self.isRunning(pid: pid) {
                kill(pid, SIGKILL)
            }
        }
    }
}

STEP 2: Create desktop/swift/Sources/Genie/Managers/ChromeManager.swift:

import Foundation
import Observation
import os

@MainActor
@Observable
final class ChromeManager {
    static let shared = ChromeManager()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "chrome")
    private var process: Process?
    private var healthCheckTask: Task<Void, Never>?

    private let chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    private let profileDir = NSHomeDirectory() + "/.genie/browser-profile"
    private let cdpPort = 9222
    private let cdpURL = "http://127.0.0.1:9222/json/version"

    /// Check if Chrome CDP is already responding
    func isAlive() async -> Bool {
        await withCheckedContinuation { continuation in
            var request = URLRequest(url: URL(string: cdpURL)!)
            request.timeoutInterval = 2
            URLSession.shared.dataTask(with: request) { data, response, error in
                let http = response as? HTTPURLResponse
                continuation.resume(returning: http?.statusCode == 200)
            }.resume()
        }
    }

    /// Start Chrome with CDP. Attaches to existing if already running.
    func start() async {
        let state = GenieState.shared

        // Already running?
        if await isAlive() {
            state.setChromeStatus(.running(pid: nil))
            logger.info("Chrome CDP already responding on :\(self.cdpPort)")
            return
        }

        state.setChromeStatus(.starting)

        // Create profile directory
        try? FileManager.default.createDirectory(atPath: profileDir, withIntermediateDirectories: true)

        // Check if Chrome exists
        guard FileManager.default.fileExists(atPath: chromePath) else {
            state.setChromeStatus(.failed("Chrome not found at \(chromePath)"))
            return
        }

        do {
            let proc = try ProcessHelper.spawn(
                executablePath: chromePath,
                arguments: [
                    "--user-data-dir=\(profileDir)",
                    "--remote-debugging-port=\(cdpPort)",
                    "--remote-debugging-address=127.0.0.1",
                    "--no-first-run",
                    "--no-default-browser-check",
                    "--restore-last-session",
                    "--disable-features=ChromeWhatsNewUI",
                ],
                stdoutPath: "/tmp/genie-logs/chrome.out.log",
                stderrPath: "/tmp/genie-logs/chrome.err.log"
            )
            self.process = proc

            // Wait for CDP to become available (up to 15 seconds)
            for attempt in 1...15 {
                try await Task.sleep(for: .seconds(1))
                if await isAlive() {
                    state.setChromeStatus(.running(pid: proc.processIdentifier))
                    logger.info("Chrome CDP ready after \(attempt)s (PID \(proc.processIdentifier))")
                    startHealthChecks()
                    return
                }
            }

            state.setChromeStatus(.failed("CDP did not respond after 15s"))
            logger.error("Chrome started but CDP never responded")
        } catch {
            state.setChromeStatus(.failed(error.localizedDescription))
            logger.error("Failed to start Chrome: \(error.localizedDescription)")
        }
    }

    /// Stop Chrome (only if we started it)
    func stop() {
        healthCheckTask?.cancel()
        healthCheckTask = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
            logger.info("Chrome terminated")
        }
        process = nil
        GenieState.shared.setChromeStatus(.stopped)
    }

    /// Periodic health check every 30s
    private func startHealthChecks() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                let alive = await isAlive()
                if !alive {
                    GenieState.shared.setChromeStatus(.failed("CDP stopped responding"))
                    logger.warning("Chrome CDP health check failed")
                }
            }
        }
    }

    /// Open login pages in Chrome tabs (used during onboarding)
    func openLoginPages() async {
        let urls = [
            "https://x.com/i/flow/login",
            "https://www.linkedin.com/login",
            "https://accounts.google.com",
            "https://www.ubereats.com",
            "https://vercel.com/login",
            "https://github.com/login",
            "https://dashboard.stripe.com/login",
        ]
        for urlString in urls {
            guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { continue }
            let cdpNew = URL(string: "http://127.0.0.1:\(cdpPort)/json/new?\(encoded)")!
            var request = URLRequest(url: cdpNew)
            request.httpMethod = "PUT"
            request.timeoutInterval = 5
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}

STEP 3: Create desktop/swift/Sources/Genie/Managers/ServerManager.swift:

import Foundation
import Observation
import os

@MainActor
@Observable
final class ServerManager {
    static let shared = ServerManager()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "server")
    private var process: Process?
    private var healthCheckTask: Task<Void, Never>?

    /// Start the Node.js Genie server
    func start() async {
        let state = GenieState.shared
        guard !state.repoDir.isEmpty else {
            state.setServerStatus(.failed("Repo directory not set"))
            return
        }

        // Check if already running
        let existingPIDs = ProcessHelper.findPIDs(matching: "node.*server.mjs")
        if !existingPIDs.isEmpty {
            state.setServerStatus(.running(pid: existingPIDs.first))
            logger.info("Server already running (PID \(existingPIDs.first ?? 0))")
            startHealthChecks()
            return
        }

        state.setServerStatus(.starting)

        // Find node
        let nodePath = resolveNodePath()
        guard let nodePath else {
            state.setServerStatus(.failed("node not found on PATH"))
            return
        }

        let serverScript = state.repoDir + "/src/core/server.mjs"
        guard FileManager.default.fileExists(atPath: serverScript) else {
            state.setServerStatus(.failed("server.mjs not found at \(serverScript)"))
            return
        }

        // Ensure .env exists
        let envPath = state.repoDir + "/.env"
        guard FileManager.default.fileExists(atPath: envPath) else {
            state.setServerStatus(.failed(".env file missing -- run onboarding first"))
            return
        }

        // Ensure node_modules
        let nodeModules = state.repoDir + "/node_modules"
        if !FileManager.default.fileExists(atPath: nodeModules) {
            logger.info("Installing npm dependencies...")
            let npm = Process()
            npm.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            npm.arguments = ["npm", "install", "--silent"]
            npm.currentDirectoryURL = URL(fileURLWithPath: state.repoDir)
            npm.standardOutput = FileHandle.nullDevice
            npm.standardError = FileHandle.nullDevice
            try? npm.run()
            npm.waitUntilExit()
        }

        do {
            let proc = try ProcessHelper.spawn(
                executablePath: nodePath,
                arguments: [serverScript],
                workingDirectory: state.repoDir,
                stdoutPath: "/tmp/genie-logs/server.out.log",
                stderrPath: "/tmp/genie-logs/server.err.log"
            )
            self.process = proc

            // Wait for server to stabilize (3 seconds)
            try await Task.sleep(for: .seconds(3))

            if proc.isRunning {
                state.setServerStatus(.running(pid: proc.processIdentifier))
                logger.info("Server started (PID \(proc.processIdentifier))")
                startHealthChecks()
            } else {
                let code = proc.terminationStatus
                state.setServerStatus(.failed("Exited with code \(code)"))
                logger.error("Server exited immediately with code \(code)")
            }
        } catch {
            state.setServerStatus(.failed(error.localizedDescription))
            logger.error("Failed to start server: \(error.localizedDescription)")
        }
    }

    /// Stop the server
    func stop() {
        healthCheckTask?.cancel()
        healthCheckTask = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
            logger.info("Server terminated")
        }
        process = nil

        // Also kill any orphan server processes
        let pids = ProcessHelper.findPIDs(matching: "node.*server.mjs")
        for pid in pids {
            ProcessHelper.terminate(pid: pid)
        }

        GenieState.shared.setServerStatus(.stopped)
    }

    /// Restart the server
    func restart() async {
        stop()
        try? await Task.sleep(for: .seconds(1))
        await start()
    }

    private func startHealthChecks() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled else { return }
                let pids = ProcessHelper.findPIDs(matching: "node.*server.mjs")
                if pids.isEmpty {
                    GenieState.shared.setServerStatus(.failed("Server process died"))
                    logger.warning("Server health check: process not found")
                    // Auto-restart
                    logger.info("Auto-restarting server...")
                    await start()
                }
            }
        }
    }

    private func resolveNodePath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        // Try which
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["node"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }
}

VERIFICATION:
    cd /Users/gtrush/Downloads/genie-2.0/desktop/swift && swift build 2>&1
    # Should compile with no errors
```

### Execution Prompt B4: Build ConfigManager.swift (API Keys, Keychain, .env)

```
CONTEXT: Building the Genie macOS menu bar app at /Users/gtrush/Downloads/genie-2.0/desktop/swift/.
Phase B, Step 4: Configuration management -- reading/writing the .env file and
storing sensitive keys in the macOS Keychain.
DO NOT modify any file outside desktop/.

The .env file format is documented in .env.example at the repo root.
Key variables from .env.example:
  TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID (required)
  OPENROUTER_API_KEY, ANTHROPIC_API_KEY (recommended)
  STRIPE_SECRET_KEY (optional)
  GEMINI_API_KEY (optional)
  GENIE_POLL_INTERVAL, GENIE_MAX_TURNS, GENIE_MAX_BUDGET_USD (tuning)

The server reads .env at startup (server.mjs lines 10-32), so we write the file
and the server picks it up on next restart.

Create desktop/swift/Sources/Genie/Managers/ConfigManager.swift with this EXACT content:

import Foundation
import Security
import os

@MainActor
@Observable
final class ConfigManager {
    static let shared = ConfigManager()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "config")
    private let keychainService = "com.gtrush.genie"

    // ── Loaded Config ──────────────────────────────────────────────────
    private(set) var telegramBotToken: String = ""
    private(set) var telegramChatID: String = ""
    private(set) var openRouterAPIKey: String = ""
    private(set) var anthropicAPIKey: String = ""
    private(set) var stripeSecretKey: String = ""
    private(set) var geminiAPIKey: String = ""
    private(set) var pollInterval: Int = 3000
    private(set) var maxTurns: Int = 50
    private(set) var maxBudgetUSD: Double = 25.0
    private(set) var watchedUsers: String = ""

    var hasRequiredKeys: Bool {
        !telegramBotToken.isEmpty && !telegramChatID.isEmpty
    }

    // ── Load from .env ─────────────────────────────────────────────────
    func load() {
        let repoDir = GenieState.shared.repoDir
        guard !repoDir.isEmpty else { return }
        let envPath = repoDir + "/.env"

        guard let content = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            logger.warning(".env not found at \(envPath)")
            return
        }

        let parsed = parseEnv(content)

        telegramBotToken = parsed["TELEGRAM_BOT_TOKEN"] ?? ""
        telegramChatID = parsed["TELEGRAM_CHAT_ID"] ?? ""
        openRouterAPIKey = parsed["OPENROUTER_API_KEY"] ?? ""
        anthropicAPIKey = parsed["ANTHROPIC_API_KEY"] ?? ""
        stripeSecretKey = parsed["STRIPE_SECRET_KEY"] ?? ""
        geminiAPIKey = parsed["GEMINI_API_KEY"] ?? ""
        pollInterval = Int(parsed["GENIE_POLL_INTERVAL"] ?? "3000") ?? 3000
        maxTurns = Int(parsed["GENIE_MAX_TURNS"] ?? "50") ?? 50
        maxBudgetUSD = Double(parsed["GENIE_MAX_BUDGET_USD"] ?? "25") ?? 25.0
        watchedUsers = parsed["GENIE_WATCHED_USERS"] ?? ""

        logger.info("Config loaded: telegram=\(self.hasRequiredKeys ? "OK" : "MISSING"), openrouter=\(!self.openRouterAPIKey.isEmpty), anthropic=\(!self.anthropicAPIKey.isEmpty)")
    }

    // ── Save to .env ───────────────────────────────────────────────────
    func save() {
        let repoDir = GenieState.shared.repoDir
        guard !repoDir.isEmpty else { return }
        let envPath = repoDir + "/.env"

        // Read existing .env or template
        var content: String
        if let existing = try? String(contentsOfFile: envPath, encoding: .utf8) {
            content = existing
        } else if let template = try? String(contentsOfFile: repoDir + "/.env.example", encoding: .utf8) {
            content = template
        } else {
            logger.error("Neither .env nor .env.example found")
            return
        }

        // Update values
        content = setEnvValue(content, key: "TELEGRAM_BOT_TOKEN", value: telegramBotToken)
        content = setEnvValue(content, key: "TELEGRAM_CHAT_ID", value: telegramChatID)
        content = setEnvValue(content, key: "OPENROUTER_API_KEY", value: openRouterAPIKey)
        content = setEnvValue(content, key: "ANTHROPIC_API_KEY", value: anthropicAPIKey)
        content = setEnvValue(content, key: "STRIPE_SECRET_KEY", value: stripeSecretKey)
        content = setEnvValue(content, key: "STRIPE_API_KEY", value: stripeSecretKey)
        content = setEnvValue(content, key: "GEMINI_API_KEY", value: geminiAPIKey)
        content = setEnvValue(content, key: "GENIE_POLL_INTERVAL", value: String(pollInterval))
        content = setEnvValue(content, key: "GENIE_MAX_TURNS", value: String(maxTurns))
        content = setEnvValue(content, key: "GENIE_MAX_BUDGET_USD", value: String(maxBudgetUSD))
        content = setEnvValue(content, key: "GENIE_WATCHED_USERS", value: watchedUsers)

        do {
            try content.write(toFile: envPath, atomically: true, encoding: .utf8)
            logger.info("Config saved to \(envPath)")
        } catch {
            logger.error("Failed to save .env: \(error.localizedDescription)")
        }
    }

    // ── Setter methods (for UI bindings) ───────────────────────────────
    func setTelegramBotToken(_ value: String) { telegramBotToken = value }
    func setTelegramChatID(_ value: String) { telegramChatID = value }
    func setOpenRouterAPIKey(_ value: String) { openRouterAPIKey = value }
    func setAnthropicAPIKey(_ value: String) { anthropicAPIKey = value }
    func setStripeSecretKey(_ value: String) { stripeSecretKey = value }
    func setGeminiAPIKey(_ value: String) { geminiAPIKey = value }
    func setPollInterval(_ value: Int) { pollInterval = max(1000, value) }
    func setMaxTurns(_ value: Int) { maxTurns = max(1, value) }
    func setMaxBudgetUSD(_ value: Double) { maxBudgetUSD = max(0.1, value) }
    func setWatchedUsers(_ value: String) { watchedUsers = value }

    // ── Test Telegram ──────────────────────────────────────────────────
    func testTelegram() async -> Bool {
        guard !telegramBotToken.isEmpty, !telegramChatID.isEmpty else { return false }
        let urlString = "https://api.telegram.org/bot\(telegramBotToken)/sendMessage"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        let body = "chat_id=\(telegramChatID)&text=Genie desktop app connected."
        request.httpBody = body.data(using: .utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            return http?.statusCode == 200
        } catch {
            logger.error("Telegram test failed: \(error.localizedDescription)")
            return false
        }
    }

    // ── Keychain helpers ───────────────────────────────────────────────
    func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // ── Private helpers ────────────────────────────────────────────────
    private func parseEnv(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard let eqIdx = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
        return result
    }

    private func setEnvValue(_ content: String, key: String, value: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var found = false
        let updated = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(key + "=") || trimmed.hasPrefix("# " + key + "=") {
                found = true
                return "\(key)=\(value)"
            }
            return line
        }
        if found {
            return updated.joined(separator: "\n")
        }
        // Key not found -- append it
        return content + "\n\(key)=\(value)\n"
    }
}

VERIFICATION:
    cd /Users/gtrush/Downloads/genie-2.0/desktop/swift && swift build 2>&1
```

### Execution Prompt B5: Build SettingsView.swift + MenuContent.swift (UI)

```
CONTEXT: Building the Genie macOS menu bar app at /Users/gtrush/Downloads/genie-2.0/desktop/swift/.
Phase B, Step 5: The settings window and menu bar dropdown UI.
DO NOT modify any file outside desktop/.

Reference: OpenClaw's GeneralSettings.swift at
engines/openclaw/apps/macos/Sources/OpenClaw/GeneralSettings.swift
shows the pattern for settings UI: SettingsToggleRow, status cards with colored
dots, health check cards, labeled content fields.

STEP 1: Create desktop/swift/Sources/Genie/Views/MenuContent.swift:

import SwiftUI

struct MenuContent: View {
    let state: GenieState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Genie 2.0")
                .font(.headline)

            Divider()

            // Status indicators
            statusRow("Chrome CDP", status: state.chromeStatus)
            statusRow("Server", status: state.serverStatus)

            if !state.activeWishes.isEmpty {
                Divider()
                ForEach(state.activeWishes) { wish in
                    Label {
                        Text(wish.title)
                            .lineLimit(1)
                    } icon: {
                        ProgressView()
                            .controlSize(.small)
                    }
                    .font(.caption)
                }
            }

            if let last = state.lastWish {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last wish: \(last.title)")
                        .font(.caption)
                        .lineLimit(1)
                    if let duration = last.duration, let cost = last.cost {
                        Text("\(String(format: "%.1f", duration))s / $\(String(format: "%.3f", cost))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            Text("Total: \(state.totalWishesCompleted) wishes / $\(String(format: "%.2f", state.totalCostUSD))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Actions
            if state.serverStatus.isRunning {
                Button("Restart Server") {
                    Task { await ServerManager.shared.restart() }
                }
            } else {
                Button("Start Server") {
                    Task { await ServerManager.shared.start() }
                }
            }

            Button("Open Logs") {
                NSWorkspace.shared.selectFile(
                    "/tmp/genie-logs/server.out.log",
                    inFileViewerRootedAtPath: "/tmp/genie-logs")
            }

            Divider()

            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",")

            Button("Quit Genie") {
                ServerManager.shared.stop()
                ChromeManager.shared.stop()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }

    private func statusRow(_ label: String, status: GenieState.ProcessStatus) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Spacer()
            Text(status.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statusColor(_ status: GenieState.ProcessStatus) -> Color {
        switch status {
        case .running: .green
        case .starting: .yellow
        case .stopped: .gray
        case .failed: .red
        }
    }
}

STEP 2: Create desktop/swift/Sources/Genie/Views/SettingsView.swift:

import SwiftUI

struct SettingsView: View {
    let state: GenieState
    let config: ConfigManager

    @State private var telegramToken = ""
    @State private var telegramChat = ""
    @State private var openRouterKey = ""
    @State private var anthropicKey = ""
    @State private var stripeKey = ""
    @State private var geminiKey = ""
    @State private var maxBudget = 25.0
    @State private var pollInterval = 3000
    @State private var telegramTestResult: Bool?
    @State private var isTesting = false

    var body: some View {
        TabView {
            apiKeysTab
                .tabItem { Label("API Keys", systemImage: "key") }
            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 440)
        .onAppear { loadFromConfig() }
    }

    // ── API Keys Tab ───────────────────────────────────────────────────
    private var apiKeysTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("API Keys")
                    .font(.title2.weight(.semibold))

                Group {
                    secretField("Telegram Bot Token", text: $telegramToken, required: true)
                    HStack {
                        secretField("Telegram Chat ID", text: $telegramChat, required: true)
                        Button(isTesting ? "Testing..." : "Test") {
                            Task { await testTelegram() }
                        }
                        .disabled(isTesting || telegramToken.isEmpty || telegramChat.isEmpty)
                        if let result = telegramTestResult {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result ? .green : .red)
                        }
                    }
                }

                Divider()

                Group {
                    secretField("OpenRouter API Key", text: $openRouterKey)
                    secretField("Anthropic API Key", text: $anthropicKey)
                    secretField("Stripe Secret Key", text: $stripeKey)
                    secretField("Gemini API Key", text: $geminiKey)
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Save") { saveToConfig() }
                        .buttonStyle(.borderedProminent)
                        .disabled(telegramToken.isEmpty || telegramChat.isEmpty)
                }
            }
            .padding(20)
        }
    }

    // ── Server Tab ─────────────────────────────────────────────────────
    private var serverTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Server Settings")
                .font(.title2.weight(.semibold))

            LabeledContent("Poll Interval (ms)") {
                TextField("3000", value: $pollInterval, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }

            LabeledContent("Max Budget (USD)") {
                TextField("25", value: $maxBudget, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                statusCard("Chrome CDP", status: state.chromeStatus)
                statusCard("Genie Server", status: state.serverStatus)
            }

            HStack(spacing: 12) {
                Button("Restart All") {
                    Task {
                        ChromeManager.shared.stop()
                        ServerManager.shared.stop()
                        try? await Task.sleep(for: .seconds(1))
                        await ChromeManager.shared.start()
                        await ServerManager.shared.start()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Stop All") {
                    ChromeManager.shared.stop()
                    ServerManager.shared.stop()
                }

                Button("Open Logs") {
                    NSWorkspace.shared.selectFile(
                        "/tmp/genie-logs/server.out.log",
                        inFileViewerRootedAtPath: "/tmp/genie-logs")
                }
            }

            Spacer()
        }
        .padding(20)
    }

    // ── About Tab ──────────────────────────────────────────────────────
    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("Genie 2.0")
                .font(.title.weight(.bold))
            Text("Voice-triggered autonomous agent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Say \"Genie\" in a JellyJelly video.\nI hear you. I execute. I report back.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 20) {
                VStack {
                    Text("\(state.totalWishesCompleted)")
                        .font(.title2.weight(.bold))
                    Text("Wishes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("$\(String(format: "%.2f", state.totalCostUSD))")
                        .font(.title2.weight(.bold))
                    Text("Total Cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("Repo: \(state.repoDir)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(20)
    }

    // ── Helpers ────────────────────────────────────────────────────────
    private func secretField(_ label: String, text: Binding<String>, required: Bool = false) -> some View {
        LabeledContent {
            SecureField(required ? "Required" : "Optional", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
        } label: {
            HStack(spacing: 4) {
                Text(label)
                if required {
                    Text("*").foregroundStyle(.red)
                }
            }
            .frame(width: 160, alignment: .leading)
        }
    }

    private func statusCard(_ label: String, status: GenieState.ProcessStatus) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.callout)
            Spacer()
            Text(status.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }

    private func statusColor(_ status: GenieState.ProcessStatus) -> Color {
        switch status {
        case .running: .green
        case .starting: .yellow
        case .stopped: .gray
        case .failed: .red
        }
    }

    private func loadFromConfig() {
        telegramToken = config.telegramBotToken
        telegramChat = config.telegramChatID
        openRouterKey = config.openRouterAPIKey
        anthropicKey = config.anthropicAPIKey
        stripeKey = config.stripeSecretKey
        geminiKey = config.geminiAPIKey
        maxBudget = config.maxBudgetUSD
        pollInterval = config.pollInterval
    }

    private func saveToConfig() {
        config.setTelegramBotToken(telegramToken)
        config.setTelegramChatID(telegramChat)
        config.setOpenRouterAPIKey(openRouterKey)
        config.setAnthropicAPIKey(anthropicKey)
        config.setStripeSecretKey(stripeKey)
        config.setGeminiAPIKey(geminiKey)
        config.setMaxBudgetUSD(maxBudget)
        config.setPollInterval(pollInterval)
        config.save()
    }

    private func testTelegram() async {
        isTesting = true
        config.setTelegramBotToken(telegramToken)
        config.setTelegramChatID(telegramChat)
        telegramTestResult = await config.testTelegram()
        isTesting = false
    }
}

VERIFICATION:
    cd /Users/gtrush/Downloads/genie-2.0/desktop/swift && swift build 2>&1
```

### Execution Prompt B6: Build OnboardingView.swift (First-Run Wizard)

```
CONTEXT: Building the Genie macOS menu bar app at /Users/gtrush/Downloads/genie-2.0/desktop/swift/.
Phase B, Step 6: First-run onboarding wizard.
DO NOT modify any file outside desktop/.

The onboarding flow mirrors CLAUDE.md (the bootstrap flow we are automating):
1. Welcome screen
2. API key entry (Telegram required, others optional)
3. Telegram verification
4. Chrome login (open login pages, user logs in manually)
5. Verification + done

Create desktop/swift/Sources/Genie/Views/OnboardingView.swift with this EXACT content:

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var telegramToken = ""
    @State private var telegramChat = ""
    @State private var openRouterKey = ""
    @State private var anthropicKey = ""
    @State private var telegramOK: Bool?
    @State private var isTesting = false
    @State private var chromeReady = false
    @State private var loginDone = false

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Step \(step + 1) of \(totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 24)
            .padding(.top, 8)

            // Content
            Group {
                switch step {
                case 0: welcomeStep
                case 1: apiKeysStep
                case 2: chromeLoginStep
                case 3: verificationStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Spacer()
                if step < totalSteps - 1 {
                    Button("Next") { advanceStep() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAdvance)
                } else {
                    Button("Finish") { finishOnboarding() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 520, height: 460)
    }

    // ── Step 0: Welcome ────────────────────────────────────────────────
    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 56))
                .foregroundStyle(.purple)
            Text("Welcome to Genie")
                .font(.title.weight(.bold))
            Text("You wished for it. I make it real.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Genie watches JellyJelly for the trigger word, then executes your wish autonomously -- building sites, ordering food, posting tweets, sending outreach, creating invoices -- and reports back on Telegram.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
    }

    // ── Step 1: API Keys ───────────────────────────────────────────────
    private var apiKeysStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Connect Your Services")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Telegram Bot Token")
                            .font(.callout.weight(.semibold))
                        Text("*").foregroundStyle(.red)
                    }
                    SecureField("Talk to @BotFather -> /newbot -> paste token", text: $telegramToken)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Telegram Chat ID")
                            .font(.callout.weight(.semibold))
                        Text("*").foregroundStyle(.red)
                    }
                    TextField("Send any message to @userinfobot", text: $telegramChat)
                        .textFieldStyle(.roundedBorder)
                }

                // Test button
                HStack {
                    Button(isTesting ? "Testing..." : "Test Telegram") {
                        Task { await testTelegram() }
                    }
                    .disabled(isTesting || telegramToken.isEmpty || telegramChat.isEmpty)

                    if let ok = telegramOK {
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(ok ? .green : .red)
                        Text(ok ? "Connected -- check your phone!" : "Failed. Check token and chat ID.")
                            .font(.caption)
                    }
                }

                Divider()

                Text("Optional (skip any you don't have)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenRouter API Key")
                        .font(.callout)
                    SecureField("For AI model routing (recommended)", text: $openRouterKey)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Anthropic API Key")
                        .font(.callout)
                    SecureField("For Claude direct access", text: $anthropicKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // ── Step 2: Chrome Login ───────────────────────────────────────────
    private var chromeLoginStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Log Into Your Accounts")
                .font(.title2.weight(.semibold))

            Text("A Chrome window will open. Log into each service so Genie can act on your behalf. Check \"Keep me signed in\" on every site.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(["X (Twitter)", "LinkedIn", "Gmail", "Uber Eats", "Vercel", "GitHub", "Stripe"], id: \.self) { service in
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(service)
                            .font(.callout)
                    }
                }
            }
            .padding(.leading, 8)

            Text("Skip any you don't use -- Genie works with whatever's logged in.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if !chromeReady {
                    Button("Start Chrome & Open Login Pages") {
                        Task {
                            await ChromeManager.shared.start()
                            chromeReady = GenieState.shared.chromeStatus.isRunning
                            if chromeReady {
                                await ChromeManager.shared.openLoginPages()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Label("Chrome running -- log into each tab", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Toggle("I'm done logging in", isOn: $loginDone)
                    .toggleStyle(.checkbox)
            }
        }
    }

    // ── Step 3: Verification ───────────────────────────────────────────
    private var verificationStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("All Set!")
                .font(.title.weight(.bold))
            Text("Genie is ready to grant wishes.")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                verifyRow("Telegram", ok: telegramOK == true)
                verifyRow("Chrome CDP", ok: chromeReady)
                verifyRow("API Keys", ok: !telegramToken.isEmpty)
            }
            .padding()
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)

            Text("Record a JellyJelly video and say \"Genie, ...\" -- I'll handle the rest.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────
    private func verifyRow(_ label: String, ok: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? .green : .orange)
            Text(label)
                .font(.callout)
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return true
        case 1: return !telegramToken.isEmpty && !telegramChat.isEmpty
        case 2: return true // Chrome login is best-effort
        default: return true
        }
    }

    private func advanceStep() {
        if step == 1 {
            // Save API keys when leaving step 1
            let config = ConfigManager.shared
            config.setTelegramBotToken(telegramToken)
            config.setTelegramChatID(telegramChat)
            config.setOpenRouterAPIKey(openRouterKey)
            config.setAnthropicAPIKey(anthropicKey)
            config.save()
        }
        step += 1
    }

    private func testTelegram() async {
        isTesting = true
        let config = ConfigManager.shared
        config.setTelegramBotToken(telegramToken)
        config.setTelegramChatID(telegramChat)
        telegramOK = await config.testTelegram()
        isTesting = false
    }

    private func finishOnboarding() {
        GenieState.shared.hasCompletedOnboarding = true
        dismiss()
        // Start services
        Task {
            await ChromeManager.shared.start()
            await ServerManager.shared.start()
        }
    }
}

VERIFICATION:
    cd /Users/gtrush/Downloads/genie-2.0/desktop/swift && swift build 2>&1
```

### Execution Prompt B7: Build WishInputView.swift + GlobalHotkey.swift (Cmd+Shift+G)

```
CONTEXT: Building the Genie macOS menu bar app at /Users/gtrush/Downloads/genie-2.0/desktop/swift/.
Phase B, Step 7: Global hotkey (Cmd+Shift+G) and floating wish input panel.
DO NOT modify any file outside desktop/.

This lets the user type a wish manually without needing a JellyJelly video.
The wish gets dispatched through the same pipeline as voice wishes.

STEP 1: Create desktop/swift/Sources/Genie/Utilities/GlobalHotkey.swift:

import AppKit
import Carbon
import os

final class GlobalHotkey {
    static let shared = GlobalHotkey()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "hotkey")
    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private var callback: (() -> Void)?

    /// Register Cmd+Shift+G as a global hotkey
    func register(action: @escaping () -> Void) {
        callback = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerRef = UnsafeMutablePointer<GlobalHotkey>.allocate(capacity: 1)
        handlerRef.initialize(to: self)

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotkey = userData.assumingMemoryBound(to: GlobalHotkey.self).pointee
                DispatchQueue.main.async {
                    hotkey.callback?()
                }
                return noErr
            },
            1,
            &eventType,
            handlerRef,
            &eventHandler
        )

        // Cmd+Shift+G: modifier = cmdKey | shiftKey, keyCode = 5 (G key)
        let hotkeyID = EventHotKeyID(signature: OSType(0x474E4945), id: 1) // "GNIE"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_G),
            UInt32(cmdKey | shiftKey),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        logger.info("Global hotkey registered: Cmd+Shift+G")
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        logger.info("Global hotkey unregistered")
    }

    deinit {
        unregister()
    }
}

STEP 2: Create desktop/swift/Sources/Genie/Views/WishInputView.swift:

import SwiftUI

struct WishInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var wishText = ""
    @State private var isDispatching = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.purple)
                Text("Make a Wish")
                    .font(.headline)
                Spacer()
                Text("Cmd+Shift+G")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
            }

            TextEditor(text: $wishText)
                .font(.body)
                .frame(minHeight: 60, maxHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .focused($isFocused)

            HStack {
                Text("Type what you want. Genie will execute it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button(isDispatching ? "Dispatching..." : "Grant Wish") {
                    Task { await dispatchWish() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(wishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDispatching)
                .keyboardShortcut(.return)
            }
        }
        .padding(16)
        .frame(width: 440)
        .onAppear { isFocused = true }
    }

    private func dispatchWish() async {
        isDispatching = true
        let text = wishText.trimmingCharacters(in: .whitespacesAndNewlines)
        let repoDir = GenieState.shared.repoDir

        // Use the trigger script if available, otherwise spawn claurst directly
        let triggerScript = repoDir + "/src/core/trigger.mjs"
        let nodePath = "/opt/homebrew/bin/node"

        guard FileManager.default.fileExists(atPath: nodePath) else {
            isDispatching = false
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [triggerScript, text]
        process.currentDirectoryURL = URL(fileURLWithPath: repoDir)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Don't wait -- the wish runs asynchronously
            dismiss()
        } catch {
            isDispatching = false
        }
    }
}

STEP 3: Create desktop/swift/Sources/Genie/Utilities/Notifications.swift:

import UserNotifications
import os

enum GenieNotifications {
    private static let logger = Logger(subsystem: "com.gtrush.genie", category: "notifications")

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                logger.info("Notification permission granted")
            } else if let error {
                logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    static func send(title: String, body: String, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}

VERIFICATION:
    cd /Users/gtrush/Downloads/genie-2.0/desktop/swift && swift build 2>&1
```

### Execution Prompt B8: Wire Up GenieApp.swift + Build Script + DMG

```
CONTEXT: Building the Genie macOS menu bar app at /Users/gtrush/Downloads/genie-2.0/desktop/swift/.
Phase B, Step 8: Wire everything together in GenieApp.swift and create a build/package script.
DO NOT modify any file outside desktop/.

STEP 1: Replace desktop/swift/Sources/Genie/GenieApp.swift with this EXACT content:

import SwiftUI

@main
struct GenieApp: App {
    @NSApplicationDelegateAdaptor(GenieAppDelegate.self) private var delegate
    @State private var state = GenieState.shared
    @State private var config = ConfigManager.shared
    @State private var showWishInput = false

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            Image(systemName: state.menuBarIconName)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            if state.hasCompletedOnboarding {
                SettingsView(state: state, config: config)
            } else {
                OnboardingView()
            }
        }

        Window("Make a Wish", id: "wish-input") {
            WishInputView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

final class GenieAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        let state = GenieState.shared

        // Resolve repo directory
        state.resolveRepoDir()

        // Load config
        ConfigManager.shared.load()

        // Request notification permission
        GenieNotifications.requestPermission()

        // Register global hotkey (Cmd+Shift+G)
        GlobalHotkey.shared.register {
            DispatchQueue.main.async {
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "wish-input" }) {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    // Open the wish input window via SwiftUI
                    NSApp.activate(ignoringOtherApps: true)
                    if let url = URL(string: "genie://wish-input") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        // Auto-start if onboarding is complete
        if state.hasCompletedOnboarding && ConfigManager.shared.hasRequiredKeys {
            Task {
                await ChromeManager.shared.start()
                await ServerManager.shared.start()
                GenieNotifications.send(
                    title: "Genie",
                    body: "Watching for wishes. Say \"Genie\" in a JellyJelly video."
                )
            }
        } else if !state.hasCompletedOnboarding {
            // Show onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkey.shared.unregister()
        // Don't stop Chrome/Server on quit -- they run as background services
        // User explicitly stops them from the menu if desired
    }
}

STEP 2: Create the build script at desktop/swift/build.sh:

#!/bin/bash
# Build Genie.app from Swift Package Manager project
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building Genie..."
swift build -c release 2>&1

# Get the built binary
BINARY=".build/release/Genie"
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

echo "Creating app bundle..."
APP_DIR="build/Genie.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_DIR/Contents/MacOS/Genie"

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Genie</string>
    <key>CFBundleIdentifier</key>
    <string>com.gtrush.genie</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Genie</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSEnvironment</key>
    <dict>
        <key>GENIE_REPO_DIR</key>
        <string>REPLACE_WITH_REPO_DIR</string>
    </dict>
</dict>
</plist>
PLIST

# Patch repo dir into Info.plist
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
sed -i '' "s|REPLACE_WITH_REPO_DIR|$REPO_DIR|g" "$APP_DIR/Contents/Info.plist"

echo ""
echo "SUCCESS: $SCRIPT_DIR/$APP_DIR"
echo ""
echo "  Run:     open $APP_DIR"
echo "  Install: cp -r $APP_DIR /Applications/"
echo "  Repo:    $REPO_DIR"
echo ""

STEP 3: Create the DMG packaging script at desktop/swift/package-dmg.sh:

#!/bin/bash
# Package Genie.app into a DMG for distribution
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/build/Genie.app"
DMG_NAME="Genie-2.0"
DMG_DIR="$SCRIPT_DIR/build/dmg"
DMG_PATH="$SCRIPT_DIR/build/$DMG_NAME.dmg"

if [ ! -d "$APP_DIR" ]; then
    echo "ERROR: Genie.app not found. Run build.sh first."
    exit 1
fi

rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$DMG_DIR"

# Copy app to staging
cp -r "$APP_DIR" "$DMG_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG
hdiutil create \
    -volname "$DMG_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_DIR"

echo ""
echo "SUCCESS: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "Users drag Genie.app to Applications, then double-click."

STEP 4: Make scripts executable:

    chmod +x desktop/swift/build.sh
    chmod +x desktop/swift/package-dmg.sh

STEP 5: Build everything:

    cd /Users/gtrush/Downloads/genie-2.0/desktop/swift
    swift build 2>&1
    # Fix any compilation errors
    # Then:
    bash build.sh
    # Then:
    bash package-dmg.sh

STEP 6: Verify the app:

    open /Users/gtrush/Downloads/genie-2.0/desktop/swift/build/Genie.app
    sleep 3
    # Should see a wand icon in the menu bar
    # Click it -- should show Genie 2.0 menu with status
    # Cmd+, should open Settings/Onboarding

STEP 7: Verify the DMG:

    ls -la /Users/gtrush/Downloads/genie-2.0/desktop/swift/build/Genie-2.0.dmg
    # Mount and check
    hdiutil attach /Users/gtrush/Downloads/genie-2.0/desktop/swift/build/Genie-2.0.dmg
    ls /Volumes/Genie-2.0/
    # Should show: Genie.app and Applications alias
    hdiutil detach /Volumes/Genie-2.0/
```

---

## Phase C: Distribution

### Creating the DMG

After Phase B is complete:

```bash
cd /Users/gtrush/Downloads/genie-2.0/desktop/swift
bash build.sh       # Builds release binary + .app bundle
bash package-dmg.sh # Creates Genie-2.0.dmg
```

The DMG is at `desktop/swift/build/Genie-2.0.dmg`.

### Sending to Beta Testers

1. Upload DMG to a file host (Google Drive, Dropbox, S3, or a Vercel static deploy)
2. Share the download link
3. Note: The app is NOT code-signed or notarized. Users will need to:
   - Right-click > Open (first time only, bypasses Gatekeeper)
   - Or: `xattr -cr /Applications/Genie.app` in Terminal

### Beta Tester Instructions

Send this to testers:

```
GENIE 2.0 DESKTOP -- BETA

1. Download Genie-2.0.dmg from [link]
2. Open the DMG and drag Genie.app to Applications
3. First launch: Right-click Genie.app > Open (macOS will warn about unsigned app)
4. The onboarding wizard will guide you through:
   - Telegram bot setup (required -- this is how Genie reports results)
   - API keys (OpenRouter and/or Anthropic)
   - Chrome login (log into services you want Genie to use)
5. Once set up, Genie runs in your menu bar (wand icon)
6. Say "Genie" in a JellyJelly video to trigger a wish
7. Or press Cmd+Shift+G to type a wish directly

REQUIREMENTS:
- macOS 14+ (Sonoma or later)
- Google Chrome installed
- Node.js 18+ (brew install node)
- The Genie repo at ~/Downloads/genie-2.0/ (cloned separately)
- Telegram account (for receiving wish reports)

KNOWN LIMITATIONS:
- Not code-signed (need Apple Developer account for notarization)
- Repo must be cloned separately (not bundled in the app yet)
- Chrome sessions need manual login on first run
```

### Future: Code Signing + Notarization

When ready for public distribution:

```bash
# 1. Sign the app (requires Apple Developer account, $99/year)
codesign --force --deep --sign "Developer ID Application: Your Name (TEAM_ID)" \
    desktop/swift/build/Genie.app

# 2. Notarize (so users don't get Gatekeeper warnings)
xcrun notarytool submit desktop/swift/build/Genie-2.0.dmg \
    --apple-id "your@email.com" \
    --team-id "TEAM_ID" \
    --password "app-specific-password" \
    --wait

# 3. Staple the notarization ticket
xcrun stapler staple desktop/swift/build/Genie-2.0.dmg
```

### File Summary

```
desktop/
  platypus/                          -- Phase A (quick ship)
    launch.sh                        -- Platypus entry point
    first-run.sh                     -- API key setup wizard
    check-deps.sh                    -- Dependency checker
    build.sh                         -- Builds .app via Platypus CLI
    build/Genie.app                  -- Output .app

  swift/                             -- Phase B (real product)
    Package.swift                    -- SPM package definition
    Sources/Genie/
      GenieApp.swift                 -- @main, MenuBarExtra, delegate
      GenieState.swift               -- @Observable singleton state
      Managers/
        ServerManager.swift          -- Node.js server lifecycle
        ChromeManager.swift          -- Chrome CDP lifecycle
        ConfigManager.swift          -- .env read/write + Keychain
      Views/
        MenuContent.swift            -- Menu bar dropdown
        SettingsView.swift           -- Settings window (tabs)
        OnboardingView.swift         -- First-run wizard
        WishInputView.swift          -- Cmd+Shift+G wish panel
      Utilities/
        GlobalHotkey.swift           -- Carbon hotkey registration
        ProcessHelper.swift          -- Process spawn/kill helpers
        Notifications.swift          -- macOS notification wrapper
    Resources/Assets.xcassets/       -- App icon + menu bar icon
    build.sh                         -- Build release + create .app
    package-dmg.sh                   -- Create distributable DMG
    build/
      Genie.app                      -- Output .app bundle
      Genie-2.0.dmg                  -- Output DMG
```
