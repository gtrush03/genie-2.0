# Genie CLI + Power-User Interface Spec

## Current State

Genie's engine is a `dispatcher.mjs` that spawns `claude -p` with a system prompt, Playwright MCP (attached to persistent Chrome on CDP :9222), and streams JSON events to Telegram. The server (`server.mjs`) polls JellyJelly for video clips containing the keyword "genie". The dashboard (`dashboard/server.mjs`) is a 4-line placeholder.

Everything below reuses the same dispatcher core. No rewrite needed.

---

## 1. Genie CLI

**Architecture:** A single new file `src/cli/genie.mjs` with a `bin` entry in `package.json`. Thin wrapper around `dispatchToClaude` that bypasses JellyJelly entirely.

### Commands

```bash
# Core
genie wish "Build me a 5-page consulting site"        # inline wish
genie wish --file brief.md                             # wish from file
genie wish --file brief.md --budget 10                 # cap spend at $10
genie wish --model opus "Plan my Q2 strategy"          # override model

# Monitoring
genie status                   # active wishes, queue depth, budget spent today
genie logs <wish-id>           # tail -f the stream-json from a running wish
genie logs <wish-id> --json    # raw stream-json (pipe to jq)

# Control
genie cancel <wish-id>         # SIGTERM → SIGKILL the subprocess
genie resume <session-id>      # claude --resume <id> with same MCP config
genie retry <wish-id>          # re-run the same prompt

# History
genie history                  # table: id, wish, status, cost, duration, date
genie history --json           # machine-readable
genie history --since 7d       # last 7 days

# System
genie health                   # run the CLAUDE.md health check
genie login                    # open Chrome CDP tabs for account setup
genie config                   # show current config (model, budget, poll interval)
genie server start|stop|status # control the JellyJelly poller launchd agent
```

### Implementation Plan

**New files:**
- `src/cli/genie.mjs` -- CLI entry point, argument parser (use `parseArgs` from `node:util`, zero deps)
- `src/core/wish-store.mjs` -- SQLite-backed wish log (use `node:sqlite` or a single JSON file at `~/.genie/wishes.json`)
- `src/core/direct-dispatch.mjs` -- Calls `dispatchToClaude` with a synthetic payload (no JellyJelly metadata)

**Changes to existing files:**
- `dispatcher.mjs`: Refactor `buildUserPrompt` to accept either JellyJelly clip metadata OR a direct text wish. Add a `source` field to the return value (`"jellyjelly"` vs `"cli"` vs `"dashboard"` vs `"schedule"`).
- `package.json`: Add `"bin": { "genie": "./src/cli/genie.mjs" }` so `npm link` makes it global.

**Key decision:** The wish store is a single append-only JSONL file at `~/.genie/wishes.jsonl`. Each line is a wish record:
```json
{"id":"w_abc123","source":"cli","prompt":"Build me a site","model":"sonnet","budget":25,"status":"running","sessionId":"sess_xyz","startedAt":"2026-04-04T10:00:00Z","completedAt":null,"turns":null,"cost":null,"result":null}
```
This avoids adding SQLite as a dependency. `genie history` reads the file, `genie status` filters for `status:"running"`.

### Interactive Mode

```bash
genie
# Drops into a REPL:
# genie> wish "Build a landing page"
# genie> status
# genie> logs w_abc123
# genie> ^C to exit
```

Implemented with `node:readline`. Same commands, no `genie` prefix needed.

---

## 2. Genie Dashboard

**Stack:** Single-file Express server at `dashboard/server.mjs` serving a React SPA (or plain HTML + htmx for zero-build). Connects to the same `~/.genie/wishes.jsonl` and tails running wish logs.

### Layout (ASCII mockup)

```
+------------------------------------------------------------------+
|  GENIE DASHBOARD                           genie-dashboard.local  |
+------------------------------------------------------------------+
|                                                                    |
|  ACTIVE WISHES (2)                                                |
|  +--------------------------------------------------------------+ |
|  | w_a1b2  "Build consulting site"   sonnet  $1.23  42 turns    | |
|  |         [=====>                    ] 35%   12m elapsed        | |
|  |         Last: pw.navigate → vercel.com/new                   | |
|  |         [View Logs]  [Cancel]                                | |
|  +--------------------------------------------------------------+ |
|  | w_c3d4  "Research competitors"    opus    $3.50  18 turns    | |
|  |         [==>                       ] 15%   4m elapsed        | |
|  |         Last: WebSearch → "saas pricing page examples"       | |
|  |         [View Logs]  [Cancel]                                | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  QUICK WISH                                                       |
|  [____________________________________________] [Send]  [$25 max] |
|                                                                    |
|  TODAY: 5 wishes | $8.42 spent | 3h 12m total runtime             |
|  THIS MONTH: 47 wishes | $62.10 spent                             |
|                                                                    |
|  HISTORY                              [Search: ___________]       |
|  +------+------------------------------+--------+-------+------+ |
|  | ID   | Wish                         | Status | Cost  | Time | |
|  +------+------------------------------+--------+-------+------+ |
|  | w_e5 | Post launch thread on X      | done   | $0.42 | 2m   | |
|  | w_f6 | Order Thai food via UberEats  | done   | $1.10 | 8m   | |
|  | w_g7 | Deploy portfolio site         | failed | $0.80 | 5m   | |
|  +------+------------------------------+--------+-------+------+ |
|                                                                    |
|  ACCOUNTS                                                         |
|  x.com [green] | linkedin [green] | gmail [yellow: 2d to expiry] |
|  ubereats [green] | vercel [green] | stripe [red: not logged in]  |
+------------------------------------------------------------------+
```

### API Endpoints

```
GET  /api/wishes              # all wishes (paginated, filterable)
GET  /api/wishes/:id          # single wish detail
GET  /api/wishes/:id/logs     # SSE stream of live logs for running wish
POST /api/wishes              # create new wish { prompt, model?, budget? }
POST /api/wishes/:id/cancel   # cancel running wish
GET  /api/stats               # cost/time aggregates
GET  /api/health              # same as genie health
```

### Deployment

For local: `genie dashboard` starts on `http://localhost:3939`.
For remote: Deploy to Vercel as a serverless app. The Vercel instance calls back to the Genie server via a tunnel (Cloudflare Tunnel or ngrok). Or simpler: deploy as static dashboard that reads from a Supabase table where the local Genie pushes wish records.

---

## 3. Scheduled / Recurring Wishes

**Architecture:** Use macOS LaunchAgents (same pattern as the existing `com.genie.chrome.plist` and `com.genie.server.plist`). Each schedule gets its own plist.

### How It Works

```bash
genie schedule "Post a thread on X summarizing my LinkedIn activity" --cron "0 9 * * 1"
genie schedule "Check Stripe and send revenue summary" --every day --at 18:00
genie schedule list
genie schedule delete <schedule-id>
```

**Under the hood:**
1. `genie schedule` parses natural language or explicit cron/time args
2. Writes a LaunchAgent plist to `~/Library/LaunchAgents/com.genie.sched.<id>.plist` with the `StartCalendarInterval` key
3. The plist runs `node /path/to/genie/src/cli/genie.mjs wish "<prompt>"` on schedule
4. Results go to Telegram (same as any wish) + wish store

**Natural language parsing:** Use Claude itself. Run `claude -p "Convert this to a cron expression: every Monday at 9am" --max-turns 1` and parse the output. Cost: ~$0.003 per schedule creation.

**Schedule store:** `~/.genie/schedules.json` -- array of `{ id, prompt, cron, plistPath, createdAt, lastRunAt, enabled }`.

**Why LaunchAgents over node-cron:** LaunchAgents survive server crashes, machine restarts, and process kills. They are the macOS-native way to schedule recurring work. No daemon needed.

---

## 4. Wish Chains / Templates

### Format: YAML in `~/.genie/templates/`

```yaml
# ~/.genie/templates/launch-sequence.yaml
name: Launch Sequence
description: Full product launch from build to outreach
steps:
  - wish: "Build the site from the spec in {spec_file}"
    budget: 10
    model: sonnet
  - wish: "Deploy the site to Vercel and give me the production URL"
    budget: 5
    depends_on: [0]  # waits for step 0
  - wish: "Create a Stripe payment link for {product_name} at {price}"
    budget: 3
    depends_on: [0]
  - wish: "Post on X: {launch_tweet} with the URL from step 1"
    budget: 3
    depends_on: [1]
  - wish: "Send LinkedIn DMs to these 5 people about the launch: {targets}"
    budget: 8
    depends_on: [1]
  - wish: "Email the press list at {press_list_file} about the launch"
    budget: 5
    depends_on: [1]
variables:
  spec_file: "./site-spec.md"
  product_name: "Consulting Package"
  price: "$499"
  launch_tweet: "Just launched..."
  targets: "@person1, @person2, @person3, @person4, @person5"
  press_list_file: "./press-emails.txt"
```

### CLI Usage

```bash
genie chain launch-sequence                          # run with defaults
genie chain launch-sequence --var price='$299'       # override a variable
genie chain launch-sequence --dry-run                # show what would run
genie templates                                      # list available templates
genie templates create                               # interactive template builder
```

### Execution

The chain runner (`src/core/chain.mjs`) reads the YAML, resolves `depends_on`, and dispatches wishes in dependency order. Steps without dependencies run in parallel (respecting `MAX_CONCURRENT`). Each step's output is available to subsequent steps via `{step_N_result}` interpolation.

---

## 5. Long-Running Task Management

### Progress Tracking

Extend `dispatcher.mjs` to emit structured progress events to the wish store:

```json
{"wishId":"w_abc","event":"checkpoint","phase":"research","detail":"Found 8 of 10 competitors","pctEstimate":40,"costSoFar":1.23,"turnsUsed":45,"elapsed":720}
```

Progress is inferred from tool-use patterns:
- `WebSearch`/`WebFetch` = research phase
- `Write`/`Edit` = build phase
- `pw.navigate` to vercel.com = deploy phase
- `sendMessage` to Telegram = reporting phase

### Checkpoint / Resume

Every 50 turns, the dispatcher writes the current `sessionId` + wish metadata to `~/.genie/checkpoints/<wish-id>.json`. If the machine sleeps or the process dies:

```bash
genie resume w_abc123
# Reads checkpoint, calls: claude --resume <sessionId> --mcp-config ...
```

### Budget Alerts

Configurable in `~/.genie/config.json`:
```json
{
  "budgetAlerts": [0.25, 0.50, 0.75, 0.90],
  "defaultBudget": 25,
  "dailyBudgetCap": 100
}
```

When a wish crosses 50% of its budget, Telegram gets: "Budget alert: 'Build consulting site' has spent $12.50 of $25.00 (50%). 62 turns used, estimated 40% complete."

### Partial Delivery

The system prompt already instructs Claude to report to Telegram as it goes. Enhancement: tag partial deliverables in the wish store so the dashboard shows them:

```
w_abc123 - "Build and launch consulting site"
  [done]  Site built at /tmp/genie-sites/consulting/
  [done]  Deployed to https://genie-consulting.vercel.app
  [running] Creating Stripe payment link...
  [pending] Post on X
  [pending] LinkedIn outreach
```

---

## 6. Multi-Model Orchestration

### Model Router in `dispatcher.mjs`

```javascript
const MODEL_ROUTER = {
  plan:     'opus',      // complex planning, strategy
  research: 'opus',      // deep analysis requiring large context
  build:    'sonnet',    // code generation, site building
  execute:  'sonnet',    // browser automation, API calls
  image:    'gemini',    // image generation via Gemini engine
};
```

### Integration Points

**Gemini (image generation):** The wish system prompt already has tool access. Add a skill or bash recipe:
```bash
# Inside a wish, Claude can call:
bash ~/Downloads/NYC/gemini-engine/gemini-design.sh -s "Generate a hero image for a consulting site" -o /tmp/hero.png
```

**Perplexity (deep research):** Add as an MCP server or a simple bash wrapper:
```bash
curl -s https://api.perplexity.ai/chat/completions \
  -H "Authorization: Bearer $PERPLEXITY_API_KEY" \
  -d '{"model":"sonar-pro","messages":[{"role":"user","content":"..."}]}'
```

**Model escalation:** If a Sonnet wish fails after 100 turns or hits repeated errors, the dispatcher auto-escalates to Opus with the conversation context. This is a new `--resume` with `--model opus`.

### Implementation

No new architecture needed. The dispatcher already accepts a `model` parameter. Multi-model orchestration is achieved by:
1. Wish chains where different steps specify different models
2. The spawned Claude Code instance calling Gemini/Perplexity via Bash tools
3. Auto-escalation on failure (new feature in dispatcher)

---

## 7. Complex Task Examples

### "Research 10 competitors, analyze pricing, build a better site"

- **Time:** 25-40 minutes
- **Cost:** $8-15 (Opus for research, Sonnet for build)
- **Tools:** WebSearch (find competitors), WebFetch (scrape pricing pages), Write (generate site), Playwright (deploy to Vercel, verify)
- **Phases:** Research (10min) -> Analysis (5min) -> Design (5min) -> Build (10min) -> Deploy (5min)
- **Command:** `genie wish --file competitor-brief.md --budget 15 --model opus`

### "Find 50 prospects on LinkedIn, research, draft personalized DMs, send"

- **Time:** 45-90 minutes
- **Cost:** $12-20
- **Tools:** Playwright (LinkedIn search, profile scraping, DM sending), WebSearch (company research), Write (draft messages)
- **Phases:** Search (15min) -> Research (20min) -> Draft (15min) -> Review/Send (30min)
- **Command:** `genie wish --file linkedin-outreach.md --budget 20`
- **Note:** Rate-limit LinkedIn actions to avoid detection. Max 25 profile views/hour, 10 DMs/hour.

### "Create a pitch deck as a deployed web presentation with real market data"

- **Time:** 30-50 minutes
- **Cost:** $10-18
- **Tools:** WebSearch/Perplexity (market data), Write (HTML/CSS slides), Gemini (generate charts/graphics), Playwright (deploy)
- **Command:** `genie wish "Create a pitch deck for TRU consulting..." --budget 18`

### "Monitor a GitHub repo for new issues and auto-triage every hour"

- **Time:** 2 minutes per run, recurring
- **Cost:** $0.50-1.00 per day
- **Tools:** WebFetch (GitHub API), Write (update triage log), Telegram (notify)
- **Command:** `genie schedule "Check github.com/user/repo for new issues, label and assign them" --every 1h`

---

## Implementation Priority

| Priority | Feature | Effort | Files |
|----------|---------|--------|-------|
| P0 | CLI `genie wish` + `status` + `history` | 1 day | `src/cli/genie.mjs`, `src/core/wish-store.mjs`, `src/core/direct-dispatch.mjs` |
| P0 | Wish store (JSONL) | 0.5 day | `src/core/wish-store.mjs` |
| P1 | `genie resume` + `cancel` + `logs` | 0.5 day | extend `src/cli/genie.mjs` |
| P1 | Dashboard (active wishes + history) | 1 day | `dashboard/server.mjs`, `dashboard/public/index.html` |
| P2 | Schedules via LaunchAgent | 1 day | `src/cli/schedule.mjs` |
| P2 | Budget alerts + progress tracking | 0.5 day | extend `dispatcher.mjs` |
| P3 | Wish chains / templates | 1 day | `src/core/chain.mjs` |
| P3 | Multi-model routing + Gemini integration | 0.5 day | extend `dispatcher.mjs`, add skill |
| P4 | Dashboard deploy to Vercel | 0.5 day | `vercel.json` |
| P4 | Interactive REPL mode | 0.5 day | extend `src/cli/genie.mjs` |

**Total: ~7 days to full feature set. P0 alone (CLI + wish store) is 1.5 days.**

---

## File Tree After Implementation

```
src/
  cli/
    genie.mjs              # CLI entry point (bin)
    schedule.mjs            # Schedule management
  core/
    server.mjs              # (existing) JellyJelly poller
    dispatcher.mjs          # (modified) accepts direct wishes + budget alerts
    direct-dispatch.mjs     # CLI/dashboard dispatch adapter
    wish-store.mjs          # JSONL read/write/query
    chain.mjs               # Template/chain executor
    telegram.mjs            # (existing)
    firehose.mjs            # (existing)
dashboard/
  server.mjs                # Express + SSE for live logs
  public/
    index.html              # Single-page dashboard
~/.genie/
  wishes.jsonl              # Wish history
  schedules.json            # Recurring wishes
  checkpoints/              # Resume data for long-running wishes
  config.json               # Budget caps, model defaults
  browser-profile/          # (existing) Chrome profile
```
