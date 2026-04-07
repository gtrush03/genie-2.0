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
