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
