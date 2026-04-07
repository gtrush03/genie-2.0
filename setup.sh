#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# Genie — One-click setup for macOS
# Run once after cloning:  chmod +x setup.sh && ./setup.sh
# Idempotent: safe to run multiple times.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}✓${RESET} $1"; }
fail() { echo -e "${RED}✗${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠${RESET} $1"; }
info() { echo -e "${CYAN}→${RESET} $1"; }

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
SKILLS_SRC="$HOME/.claude/skills"
LOG_DIR="/tmp/genie-logs"

echo ""
echo -e "${BOLD}🧞 Genie Setup${RESET}"
echo "────────────────────────────────────────"
echo ""

# ── Step 1: Prerequisites ────────────────────────────────────────────────────
info "Checking prerequisites..."

if [[ "$(uname)" != "Darwin" ]]; then
  fail "macOS required. Detected: $(uname)"; exit 1
fi
ok "macOS ($(uname -m))"

if ! command -v node &>/dev/null; then
  fail "Node.js not found. Install: https://nodejs.org (v20+)"; exit 1
fi
NODE_VER=$(node --version | sed 's/v//' | cut -d. -f1)
if [[ "$NODE_VER" -lt 20 ]]; then
  fail "Node 20+ required. Found: $(node --version)"; exit 1
fi
ok "Node $(node --version)"

if ! command -v npx &>/dev/null; then
  fail "npx not found (comes with Node). Check your PATH."; exit 1
fi
ok "npx available"

if [[ ! -d "/Applications/Google Chrome.app" ]]; then
  fail "Google Chrome not found at /Applications/Google Chrome.app"; exit 1
fi
ok "Google Chrome installed"

if ! command -v claude &>/dev/null; then
  fail "Claude CLI not found. Install: npm install -g @anthropic-ai/claude-code"
  exit 1
fi
ok "Claude CLI ($(which claude))"

echo ""

# ── Step 2: npm install ──────────────────────────────────────────────────────
info "Installing npm dependencies..."
cd "$REPO_DIR"
npm install --silent 2>&1 | tail -1
ok "npm dependencies installed"

# ── Step 3: Stripe CLI (optional) ────────────────────────────────────────────
if command -v stripe &>/dev/null; then
  ok "Stripe CLI already installed"
else
  if command -v brew &>/dev/null; then
    info "Installing Stripe CLI via Homebrew..."
    brew install stripe/stripe-cli/stripe 2>/dev/null && ok "Stripe CLI installed" || warn "Stripe CLI install failed (non-fatal)"
  else
    warn "Homebrew not found — skipping Stripe CLI install. Install manually if needed."
  fi
fi

echo ""

# ── Step 4: .env ─────────────────────────────────────────────────────────────
if [[ -f "$REPO_DIR/.env" ]]; then
  ok ".env already exists (skipping creation)"
else
  info "Creating .env from .env.example..."
  cp "$REPO_DIR/.env.example" "$REPO_DIR/.env"
  # Auto-fill HOME-based paths
  sed -i '' "s|/Users/you|$HOME|g" "$REPO_DIR/.env"
  echo ""
  echo -e "${BOLD}Required keys:${RESET}"
  echo "  TELEGRAM_BOT_TOKEN   — Create bot via @BotFather on Telegram"
  echo "  TELEGRAM_CHAT_ID     — Your Telegram user ID"
  echo ""
  echo -e "${BOLD}Optional but recommended:${RESET}"
  echo "  OPENROUTER_API_KEY   — For legacy interpreter (not needed if using dispatcher)"
  echo "  STRIPE_SECRET_KEY    — For Stripe-related wishes"
  echo "  GEMINI_API_KEY       — For vision/grounding"
  echo "  GH_OWNER            — Your GitHub username (for Vercel deploys)"
  echo ""
  EDITOR_CMD="${EDITOR:-nano}"
  read -rp "Open .env in $EDITOR_CMD now? [Y/n] " yn
  if [[ "${yn:-Y}" =~ ^[Yy]?$ ]]; then
    "$EDITOR_CMD" "$REPO_DIR/.env"
  fi
fi

echo ""

# ── Step 5: Browser profile directory ────────────────────────────────────────
mkdir -p "$HOME/.genie/browser-profile"
ok "Browser profile dir: ~/.genie/browser-profile"

# ── Step 6: Log directory ────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
ok "Log directory: $LOG_DIR"

echo ""

# ── Step 7: Install LaunchAgents ─────────────────────────────────────────────
info "Installing LaunchAgents..."
mkdir -p "$LAUNCH_AGENTS"

# Detect node path (arm64 vs x86_64)
NODE_PATH="$(which node)"

install_plist() {
  local src="$1" name="$2"
  local dest="$LAUNCH_AGENTS/$name"
  if [[ -f "$dest" ]]; then
    warn "$name already exists at $dest — skipping (delete manually to reinstall)"
    return
  fi
  sed -e "s|/Users/YOURNAME|$HOME|g" \
      -e "s|NODE_BIN|$NODE_PATH|g" \
      -e "s|GENIE_REPO_DIR|$REPO_DIR|g" \
      "$src" > "$dest"
  ok "Installed $dest"
}

mkdir -p "$LAUNCH_AGENTS"
install_plist "$REPO_DIR/examples/com.genie.chrome.plist" "com.genie.chrome.plist"
install_plist "$REPO_DIR/examples/com.genie.server.plist" "com.genie.server.plist"

echo ""

# ── Step 8: Install Uber Eats skills ─────────────────────────────────────────
info "Installing Uber Eats skills..."
mkdir -p "$SKILLS_SRC"

for skill_dir in "$REPO_DIR"/skills/ubereats-*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir")"
  dest="$SKILLS_SRC/$skill_name"
  if [[ -d "$dest" ]]; then
    warn "$skill_name already exists at $dest — skipping"
  else
    cp -r "$skill_dir" "$dest"
    ok "Installed skill: $skill_name"
  fi
done

# If no skills/ dir in repo yet, note it
if ! ls "$REPO_DIR"/skills/ubereats-*/ &>/dev/null 2>&1; then
  warn "No skills/ubereats-*/ found in repo. Copy them manually to ~/.claude/skills/"
fi

echo ""

# ── Step 9: Project-level Claude Code settings ───────────────────────────────
info "Setting up Claude Code project settings..."
mkdir -p "$REPO_DIR/.claude"
SETTINGS_FILE="$REPO_DIR/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]]; then
  ok ".claude/settings.json already exists"
else
  cat > "$SETTINGS_FILE" << 'SETTINGS'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read",
      "Write",
      "Edit",
      "MultiEdit",
      "Glob",
      "Grep",
      "Task",
      "TodoWrite",
      "WebSearch",
      "WebFetch(*)",
      "Skill(*)",
      "mcp__playwright__*"
    ],
    "deny": [],
    "defaultMode": "bypassPermissions"
  }
}
SETTINGS
  ok "Created .claude/settings.json"
fi

echo ""

# ── Step 10: Test Claude Code auth ───────────────────────────────────────────
info "Testing Claude Code authentication..."
if claude -p "echo ok" --output-format text &>/dev/null; then
  ok "Claude Code authenticated"
else
  warn "Claude Code auth failed. Fix with one of:"
  echo "    1. Run 'claude' interactively to complete OAuth login"
  echo "    2. Set ANTHROPIC_API_KEY in your shell profile"
  echo "  Setup will continue — fix auth before first run."
fi

echo ""

# ── Step 11: Start Chrome LaunchAgent ─────────────────────────────────────────
info "Starting Chrome with CDP (remote debugging)..."

# Unload first if already loaded (idempotent)
launchctl unload "$LAUNCH_AGENTS/com.genie.chrome.plist" 2>/dev/null || true
launchctl load -w "$LAUNCH_AGENTS/com.genie.chrome.plist" 2>/dev/null

# Give Chrome a moment to start
sleep 3

if curl -s --max-time 5 "http://127.0.0.1:9222/json/version" &>/dev/null; then
  ok "Chrome CDP endpoint live at http://127.0.0.1:9222"
else
  warn "Chrome CDP not responding yet. It may need a few more seconds."
  echo "    Verify manually: curl http://127.0.0.1:9222/json/version"
fi

echo ""
echo -e "${BOLD}🌐 Chrome is open. Log into these sites (check 'Keep me signed in'):${RESET}"
echo ""
echo "    1. Twitter/X        — https://x.com"
echo "    2. LinkedIn          — https://linkedin.com"
echo "    3. Gmail             — https://mail.google.com"
echo "    4. Uber Eats         — https://ubereats.com"
echo "    5. Vercel            — https://vercel.com"
echo "    6. GitHub            — https://github.com"
echo "    7. Stripe Dashboard  — https://dashboard.stripe.com"
echo ""
read -rp "Press Enter once you've logged in to continue..."

echo ""

# ── Step 12: Start Genie server LaunchAgent ──────────────────────────────────
info "Starting Genie server..."
launchctl unload "$LAUNCH_AGENTS/com.genie.server.plist" 2>/dev/null || true
launchctl load -w "$LAUNCH_AGENTS/com.genie.server.plist" 2>/dev/null

sleep 2

if launchctl list | grep -q "com.genie.server"; then
  ok "Genie server LaunchAgent loaded"
else
  warn "Genie server may not have started. Check: launchctl list | grep genie"
fi

echo ""

# ── Step 13: Success banner ──────────────────────────────────────────────────
echo -e "${BOLD}════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  🧞 Genie is running!${RESET}"
echo -e "${BOLD}════════════════════════════════════════════════════════════════${RESET}"
echo ""
echo "  Say 'genie' in a JellyJelly video to trigger a wish."
echo ""
echo -e "  ${CYAN}Logs:${RESET}"
echo "    Server:  tail -f /tmp/genie-logs/launchd.out.log"
echo "    Chrome:  tail -f /tmp/genie-logs/chrome.out.log"
echo "    Errors:  tail -f /tmp/genie-logs/launchd.err.log"
echo ""
echo -e "  ${CYAN}Stop:${RESET}"
echo "    launchctl unload ~/Library/LaunchAgents/com.genie.server.plist"
echo "    launchctl unload ~/Library/LaunchAgents/com.genie.chrome.plist"
echo ""
echo -e "  ${CYAN}Restart:${RESET}"
echo "    launchctl unload ~/Library/LaunchAgents/com.genie.server.plist"
echo "    launchctl load -w ~/Library/LaunchAgents/com.genie.server.plist"
echo ""
echo -e "  ${CYAN}Test wish:${RESET}"
echo "    node src/core/trigger.mjs <clip-id>"
echo "    npm run trigger"
echo ""
echo -e "  ${CYAN}Status:${RESET}"
echo "    launchctl list | grep genie"
echo "    curl http://127.0.0.1:9222/json/version"
echo ""
