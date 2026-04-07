# Genie — Full Context Drop

**Purpose:** Paste this into a fresh Claude Code session on any computer to have the same working knowledge as the session that built Genie. This is everything — architecture, decisions, gotchas, what works, what broke, what's next.

**Last updated:** April 6, 2026
**Repo:** https://github.com/gtrush03/genie (commit `cf01008`)
**Location on George's Mac:** `/Users/gtrush/Downloads/genie/`

---

## What Genie is (30-second version)

A voice-triggered autonomous agent. Say "genie" in a JellyJelly video → a Node server catches the keyword in the Deepgram transcript → spawns a fresh `claude -p` subprocess (Claude Code CLI) with full tool access + a Playwright MCP attached to a persistent, pre-logged-in Chrome → Claude Code executes the wish (builds sites, deploys to Vercel, posts on X, orders Uber Eats, creates Stripe invoices, anything) → reports results to Telegram with screenshots and receipts.

**You can't message Genie. You can only wish.** One-way: camera in, Telegram out.

Built at MischiefClaw hackathon (Betaworks NYC, April 2026). Shipped in 2 days. Has actually posted real tweets, deployed real sites, placed $108 of real Uber Eats orders, and created real Stripe payment links — all from voice on a JellyJelly video.

---

## Architecture (how the pieces connect)

```
JellyJelly Firehose API (api.jellyjelly.com/v3/jelly/search)
  ↓ polled every 3s by...
Node server (src/core/server.mjs) — launchd always-on (com.genie.server)
  ↓ new clip → fast-retry watcher polls /jelly/{id} every 1.5s until transcript has words
  ↓ transcript contains "genie" →
Dispatcher (src/core/dispatcher.mjs)
  ↓ spawns...
claude -p (Claude Code CLI 2.1)
  --append-system-prompt config/genie-system.md (~8KB system prompt)
  --mcp-config config/mcp.json (Playwright MCP → persistent Chrome on CDP :9222)
  --allowedTools Bash,Read,Write,Edit,Glob,Grep,WebFetch,WebSearch,Task,TodoWrite,mcp__playwright
  --permission-mode bypassPermissions
  --max-turns 200, --max-budget-usd 25
  --output-format stream-json --include-partial-messages
  ↓ stream-json events parsed by dispatcher, forwarded to...
Telegram Bot API (one-way: text + photos to George's phone, chat_id 582706965)
```

**Persistent Chrome** (separate launchd agent: `com.genie.chrome`):
- Google Chrome launched with `--user-data-dir=~/.genie/browser-profile --remote-debugging-port=9222`
- George is pre-logged into: X, LinkedIn, Gmail, Uber Eats, Vercel, GitHub, Stripe
- Playwright MCP (`@playwright/mcp`) attaches via `--cdp-endpoint http://127.0.0.1:9222`
- Sessions persist in the user-data-dir forever (cookies on disk). Claude Code drives the SAME browser every wish.

---

## Key files and what they do

### Core pipeline
| File | Lines | What it does |
|---|---|---|
| `src/core/server.mjs` | 230 | Main poll loop + fast-retry transcript watcher. Detects keyword, calls dispatcher. Runs under launchd. |
| `src/core/dispatcher.mjs` | 326 | Spawns `claude -p`, pipes transcript as user prompt, streams stream-json events, throttles Telegram updates (3s debounce), handles timeout/exit. Returns `{success, sessionId, turns, usdCost, durationMs}`. |
| `src/core/firehose.mjs` | 180 | JellyJelly API client. `pollForNewClips()`, `fetchClipDetail()`, `containsKeyword()`, `reconstructTranscript()`. Tracks cursor for pagination. |
| `src/core/telegram.mjs` | 141 | `sendMessage(text, {plain})`, `sendPhoto(path, caption)`, `sendReport(report)`. No hardcoded tokens — requires env vars. |
| `config/genie-system.md` | 169 | The ~8KB system prompt loaded via `--append-system-prompt`. Teaches Claude Code: Telegram reporting patterns, Vercel deploy (public URL rule), Stripe CLI recipes, Uber Eats skill routing, browser MCP patterns, research discipline, final receipt format. |
| `config/mcp.json` | ~10 | `{"mcpServers":{"playwright":{"command":"npx","args":["-y","@playwright/mcp@latest","--cdp-endpoint","http://127.0.0.1:9222"]}}}` |

### Legacy (kept as fallback, no longer in the main pipeline)
| File | What it was |
|---|---|
| `src/core/interpreter.mjs` | Old structured-wish extractor (transcript → JSON wishes via OpenRouter). Replaced by direct Claude Code dispatch. |
| `src/core/executor.mjs` | Old hardcoded handlers (BUILD, BOOK, RESEARCH, OUTREACH, PROMOTE, CONNECT, REMIND). Each was a separate function. Replaced by Claude Code doing everything via tools. |
| `src/scripts/build-site.mjs` | Template-based HTML generator with Unsplash images. Claude Code now writes HTML from scratch with real research. |
| `src/scripts/deploy-vercel.mjs` | Still used but also available to Claude Code via Bash `npx vercel deploy`. Returns public production URL. |
| `src/scripts/research-topic.mjs` | Perplexity Sonar via OpenRouter. Still available as a Node import but Claude Code prefers WebSearch+WebFetch. |

### Skills (at `~/.claude/skills/`)
| Skill | What it teaches Claude Code |
|---|---|
| `ubereats-order` | Master orchestrator for food/drink/grocery wishes. Parses intent → finds store → routes to sub-skills → enforces "Uber Eats only, never stop until ordered." |
| `ubereats-search` | How to use Uber Eats search bar (overlay focus quirk that broke the first attempt), store picking, filtering. |
| `ubereats-add-to-cart` | In-store item search, product modal handling, quantity stepping, out-of-stock substitution. |
| `ubereats-checkout` | Cart → checkout flow, address/payment verification (don't touch defaults), tip handling, age verification modals. |
| `ubereats-pay` | Click "Place Order", handle beforeunload dialogs, wait for confirmation, extract order ID + ETA + total, screenshot proof. |

### Infrastructure
| File | What it does |
|---|---|
| `examples/com.genie.server.plist` | macOS LaunchAgent for the Node server. RunAtLoad, KeepAlive on crash, 10s throttle. Logs to `/tmp/genie-logs/`. |
| `examples/com.genie.chrome.plist` | macOS LaunchAgent for persistent Chrome with CDP. Same pattern. |
| `scripts/start-browser.sh` | `{load|unload|restart|status|logs}` helper for the Chrome LaunchAgent. |
| `docs/BROWSER-SETUP.md` | One-time login flow, CDP verification, troubleshooting. |

---

## Environment variables (.env)

```
OPENROUTER_API_KEY=sk-or-v1-...          # Used by legacy interpreter + research-topic
OPENROUTER_MODEL=anthropic/claude-sonnet-4-6
TELEGRAM_BOT_TOKEN=...                    # Genie reports here
TELEGRAM_CHAT_ID=...                      # George's chat ID
STRIPE_SECRET_KEY=sk_test_...             # Stripe CLI uses this
STRIPE_API_KEY=sk_test_...                # Alias
STRIPE_PUBLISHABLE_KEY=pk_test_...
GEMINI_API_KEY=...                        # Optional
JELLY_API_URL=https://api.jellyjelly.com/v3
GENIE_KEYWORD=genie
GENIE_POLL_INTERVAL=3000                  # Main poll (ms)
GENIE_FAST_RETRY_INTERVAL=1500           # Per-clip transcript watch (ms)
GENIE_FAST_RETRY_MAX_MS=300000           # 5 min max wait for transcript
GH_OWNER=gtrush03
GENIE_BROWSER_PROFILE=~/.genie/browser-profile
```

**Claude Code auth:** authenticates via OAuth in macOS Keychain (not an env var). On headless Linux, set `ANTHROPIC_API_KEY` instead. On a fresh machine, run `claude` once interactively to complete the OAuth flow.

---

## Bugs that were found and fixed (save yourself the pain)

### 1. Empty transcript_overlay treated as "ready"
**Bug:** JellyJelly returns `transcript_overlay` as a stub object BEFORE Deepgram finishes filling in the words. The old code checked `if (!detail.transcript_overlay)` — this passed (object exists), so the clip got marked as "no keyword, seen" and was blacklisted forever.
**Fix:** `transcriptWordCount(overlay)` actually counts words in `overlay.results.channels[0].alternatives[0].words`. If 0 → not ready → hand off to fast-retry watcher.

### 2. Vercel returns SSO-protected preview URL
**Bug:** `npx vercel deploy --prod` prints the preview URL (`*-<hash>-george-the-gs-projects.vercel.app`) which returns 401 to the public. The production alias (`genie-<slug>.vercel.app`) is the public one.
**Fix:** `deploy-vercel.mjs` now constructs the production URL from the sanitized project name and HEAD-checks it returns 200 before returning.

### 3. Playwright search bar focus quirk on Uber Eats
**Bug:** Clicking "Search Uber Eats" opens an overlay with a DIFFERENT input. `browser_type` on the original ref fails because it's no longer the focused element.
**Fix:** Documented in `ubereats-search` skill — click → re-snapshot → find the NEW focused combobox → type on that. Three fallback patterns (fill_form, evaluate JS, press_key character-by-character).

### 4. Telegram Markdown parse failures on tool commands
**Bug:** Tool-use status messages contain backticks and underscores that break Telegram's Markdown parser → 400 error.
**Fix:** Added `{plain: true}` option to `sendMessage()` that skips `parse_mode: 'Markdown'` for tool pings.

### 5. Dispatcher timeout killed running wishes
**Bug:** 15-min hard timeout killed a wish that was mid-checkout on Stripe dashboard (building the Wobbles payment link).
**Fix:** Raised to 60-min safety net. Budget ($25) and turns (200) are the real caps. System prompt says "there is no hard time limit — take what you need."

---

## What has been proven end-to-end (real, not simulated)

| Wish | What happened | Cost | Time |
|---|---|---|---|
| "Post on my X about G wagons" | Navigated x.com/compose, typed tweet in George's voice, clicked Post, grabbed URL | $0.42 | 112s |
| "Sell Wobbles for $67, Stripe checkout, make a website" | Downloaded plushie images from jellyjelly.com, built dark landing page, Stripe CLI: product → price → payment_link, patched buttons, Vercel deploy, screenshot | $0.73 (resume) | 90s (resumed from killed session) |
| "Get me a 6-pack non-alc beer, 2× 12-pack Modelo, 1 tomato" | Two Uber Eats orders: Greenwich Beer ($79.43 for Modelo) + Wegmans ($29.23 for Heineken 0.0 + tomato). Real charges to Visa. | $6.92 | 23 min |
| "Build me a site about the NYC Auto Show at Javits" | Perplexity Sonar research → real 2026 dates/prices/brands → HTML with downloaded imagery → Vercel deploy | $1.15 | 385s |

---

## Resume capability

If a Claude Code run is killed (crash, timeout, manual):
```bash
claude -p "Continue where you left off. [what changed]" \
  --resume <session-id> \
  --mcp-config config/mcp.json \
  --permission-mode bypassPermissions \
  --max-turns 200 --max-budget-usd 25 \
  --output-format stream-json
```
Session ID from logs: `grep "session=" /tmp/genie-logs/launchd.out.log | tail -5`

---

## Scaling considerations (researched, not implemented)

Two Opus research briefs at `/tmp/genie-research/`:
- `product-brief.md` — JellyJelly integration strategy, pricing ($15/mo + 75 wishes), affiliate angle (Uber Eats/Stripe referrals subsidize Claude inference), GTM, risks
- `hosting-brief.md` — Browserbase Contexts ($0.10/hr, per-user isolated Chrome), Claude Agent SDK replacing `claude -p`, Modal for orchestration, E2B for sandboxed Bash, ~$0.19/wish fully loaded

**For 2 concurrent wishes on one machine:** make dispatch fire-and-forget (don't `await`), add "always open a new tab" to system prompt for tab isolation, track `activeDispatches` counter with `GENIE_MAX_CONCURRENT=3`.

**For multi-user:** per-user Chrome on different CDP ports, or swap to Browserbase Contexts. Replace `claude -p` CLI with Claude Agent SDK `query()`.

---

## What to do on a fresh machine

```bash
# Prerequisites: Node 20+, Chrome, claude CLI, stripe CLI, vercel (logged in)

git clone https://github.com/gtrush03/genie.git && cd genie && npm install
cp .env.example .env  # fill in keys
claude  # one-time OAuth login, Ctrl-C after auth

# Persistent Chrome
mkdir -p ~/.genie/browser-profile
# Edit examples/com.genie.chrome.plist → fix paths to your $HOME
cp examples/com.genie.chrome.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.genie.chrome.plist
# Log into X, LinkedIn, Gmail, Uber Eats, Vercel, GitHub, Stripe in that Chrome window
# Check "Keep me signed in" on every login

# Genie server
# Edit examples/com.genie.server.plist → fix paths
cp examples/com.genie.server.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.genie.server.plist

# Verify
curl http://127.0.0.1:9222/json/version  # Chrome CDP alive
tail -f /tmp/genie-logs/launchd.out.log   # Server polling
```

**Uber Eats skills** — copy from this machine or recreate:
```bash
mkdir -p ~/.claude/skills/ubereats-{order,search,add-to-cart,checkout,pay}
# Copy SKILL.md files into each (see repo or ask Claude Code to recreate from this context)
```

---

## Gotchas for a new operator

1. **Claude Code auth on headless Linux:** OAuth doesn't work without a GUI. Set `ANTHROPIC_API_KEY` in `.env` and the plist `EnvironmentVariables` instead.
2. **Chrome SingletonLock:** if Chrome crashes and won't restart, delete `~/.genie/browser-profile/SingletonLock`.
3. **Two Chromes:** the Genie Chrome is a SEPARATE instance from your daily Chrome. Same dock icon, different windows. Use Mission Control or ⌘+` to distinguish.
4. **Telegram bot creation:** talk to @BotFather on Telegram, `/newbot`, get the token, then send any message to the bot first (it needs a chat to exist). Get your chat_id via `https://api.telegram.org/bot<TOKEN>/getUpdates`.
5. **Vercel auth:** `npx vercel login` before first deploy. The CLI stores the token in `~/.local/share/com.vercel.cli/`.
6. **Stripe CLI auth:** either set `STRIPE_API_KEY` env var or run `stripe login` once.
7. **Skills auto-discovery:** Claude Code auto-discovers skills at `~/.claude/skills/<name>/SKILL.md` on every invocation. No registration needed. Just create the files.
8. **Log location:** `/tmp/genie-logs/launchd.out.log` and `.err.log`. On macOS `/tmp` is actually `/private/tmp` — both paths work.
9. **The poll loop doesn't block on wishes anymore** (if you apply the fire-and-forget patch). Without the patch, wish N blocks wish N+1.
10. **Cookie expiry:** X cookies last ~400 days with "Keep me signed in". LinkedIn ~30 days. Gmail indefinitely. Uber Eats ~90 days. When a cookie expires, that wish fails and Telegram reports the error — log in again in the Genie Chrome window.

---

## This session's conversation arc (for continuity)

1. George asked to understand the Genie project, fix the Telegram non-response → found the server was hung, restarted it, caught the Javits Center auto show clip
2. Fixed Vercel URLs (preview was SSO-protected, now returns production alias), added Perplexity Sonar research before builds, installed launchd always-on instance
3. Replaced the entire interpreter→executor pipeline with a Claude Code dispatcher (`claude -p` subprocess). Built config/genie-system.md, config/mcp.json, src/core/dispatcher.mjs. Persistent Chrome via launchd + @playwright/mcp over CDP
4. Fixed the transcript_overlay bug (empty shell treated as ready → clips blacklisted). Added fast-retry watcher (1.5s per-clip polling until words arrive, 5-min max)
5. G Wagons tweet: first end-to-end success via the new dispatcher (X post from a JellyJelly clip, 112s, $0.42)
6. Added Stripe CLI + keys, raised timeout/turns/budget caps, updated system prompt
7. Wobbles wish: built landing page + Stripe payment link. First run killed by 15-min timeout mid-Stripe-dashboard. Resumed via `--resume <session-id>` → finished in 90s ($0.73)
8. Pushed everything to GitHub with a full Mermaid-diagrammed README
9. Built 5 Uber Eats skills. Resumed the Drinks+Tomato wish → two real Uber Eats orders placed ($108.66 total, 152 turns, $6.92, 23 min)
10. Two Opus research agents: product brief (JellyJelly integration strategy) + hosting brief (Browserbase + Agent SDK + Modal + E2B, $0.19/wish at scale)
11. Discussed setting up on another computer + scaling to 2 concurrent wishes

**George's style:** moves fast, speaks into the camera, expects things to work end-to-end, doesn't want to hear about problems — wants them fixed. Dictates messages (expect typos). Prefers concrete execution over discussion. If something breaks, fix it and report what you did. Keep Telegram updates terse (milestones only, not every tool call).
