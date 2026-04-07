# GENIE 2.0 — NEXT STEPS

> What exactly to build, in what order, with what tools.
> Written April 6, 2026. Engine migration is done. Time to ship product.

---

## SECTION 1: WHAT'S DONE (Engine Migration Recap)

The Genie 2.0 engine migration is complete and running in production.

| What | Status |
|------|--------|
| Claurst replaces Claude Code | DONE — `dispatcher.mjs` spawns `claurst -p` instead of `claude -p` |
| 35+ LLM providers via OpenRouter | DONE — `--provider openrouter` flag, model aliases mapped |
| Full JSONL traceability | DONE — every event appended to `traces/dispatch-*.jsonl`, 50-file rotation |
| Design skills for beautiful websites | DONE — 3 skills (`web-design`, `site-builder`, `design-review`) in `~/.claurst/skills/` |
| JellyJelly branding integrated | DONE — firehose polling, keyword detection, clip commenting |
| Reliability fixes | DONE — stall detector (120s), hard timeout (60min), stderr cap (100KB), graceful shutdown, trace rotation |
| Wish complexity classification | DONE — simple wishes get 15 turns/$2, complex get 200 turns/$25 |
| Concurrent dispatch | DONE — up to 5 parallel wishes with overflow queue |

**Key files:**
- `src/core/dispatcher.mjs` — Claurst subprocess spawning + event stream parsing
- `src/core/server.mjs` — JellyJelly poller + transcript watcher + dispatch trigger
- `config/genie-system.md` — 100-line system prompt (works with any model)
- `.claurst/settings.json` — MCP config (Playwright on CDP :9222), permissions, allowed tools

**What's NOT done:** Desktop packaging, multi-user, voice input, billing, auth.

---

## SECTION 2: DESKTOP APP (Phase 1 — 3-4 weeks)

### Goal

A downloadable `.dmg` for macOS. User installs, enters their API key, Genie runs on their Mac. No terminal, no `git clone`, no `npm install`.

### Architecture

```
+------------------------------------------------------------------+
|  Genie.app (Tauri 2.0, ~90MB .dmg)                              |
|                                                                   |
|  ┌──────────────────────┐  ┌──────────────────────────────────┐  |
|  │  Rust Core (Tauri)   │  │  React Frontend (system webview) │  |
|  │                      │  │                                  │  |
|  │  - IPC bridge        │  │  - Onboarding wizard             │  |
|  │  - Auto-updater      │  │  - Wish history + trace viewer   │  |
|  │  - macOS permissions │  │  - Settings (model, budget, keys)│  |
|  │  - Tray icon + menu  │  │  - Active wish monitor           │  |
|  │  - Global hotkey     │  │  - Account login status          │  |
|  │    (Cmd+Shift+G)     │  │                                  │  |
|  └──────────┬───────────┘  └──────────────────────────────────┘  |
|             │                                                     |
|  ┌──────────▼───────────────────────────────────────────────────┐|
|  │  Node.js Sidecar (the existing engine, bundled)              │|
|  │                                                               │|
|  │  server.mjs → dispatcher.mjs → spawns claurst binary         │|
|  │  firehose.mjs, telegram.mjs, jelly-comment.mjs               │|
|  │  MCP: Playwright → CDP :9222                                  │|
|  │  Traces → ~/.genie/traces/                                    │|
|  └──────────┬───────────────────────────────────────────────────┘|
|             │                                                     |
|  ┌──────────▼───────────────────────────────────────────────────┐|
|  │  Claurst Binary (sidecar, ~15MB, pre-compiled arm64+x86_64) │|
|  │  Spawned per wish by dispatcher.mjs                           │|
|  └──────────────────────────────────────────────────────────────┘|
|             │                                                     |
|  ┌──────────▼───────────────────────────────────────────────────┐|
|  │  Chromium (playwright-core, downloaded on first run ~280MB)  │|
|  │  --remote-debugging-port=9222                                 │|
|  │  --user-data-dir=~/.genie/browser-profile                    │|
|  │  Holds logged-in sessions (Uber Eats, LinkedIn, Gmail, etc.) │|
|  └──────────────────────────────────────────────────────────────┘|
+------------------------------------------------------------------+
```

### What the user sees vs what runs under the hood

| User sees | Under the hood |
|-----------|---------------|
| "Genie.app" in Applications | Tauri shell wrapping React UI + Node sidecar + Claurst binary |
| First-run wizard asking for API key | Key written to `~/.genie/config.json`, env injected into sidecar |
| "Downloading browser..." progress bar | `playwright-core` downloading Chromium to `~/.genie/chromium/` |
| Chrome window with login tabs | Chromium launched with `--remote-debugging-port=9222` |
| Wish history list with expand/collapse | Reads `~/.genie/traces/*.jsonl`, renders timeline |
| "Genie is listening" in menu bar | Porcupine wake word detection on microphone stream |
| Kill switch (Cmd+Shift+K) | `SIGTERM` to active Claurst child process |

### First-run flow (step by step)

1. User opens Genie.app for the first time
2. **Welcome screen** — "Enter your OpenRouter API key" (link to openrouter.ai/keys)
   - Optional: Anthropic key, Telegram bot token + chat ID
   - Keys saved to `~/.genie/config.json` (encrypted at rest via Tauri's secure store)
3. **Downloading Chromium** — progress bar, ~280MB, one-time
   - Uses `playwright-core`'s `chromium.download()` API
   - Stored at `~/.genie/chromium/`
4. **macOS permissions** — prompt for:
   - Accessibility (for global hotkey Cmd+Shift+G)
   - Microphone (for voice wake word — optional, can skip)
5. **Browser login** — Chrome opens with tabs for each service
   - Same flow as current `CLAUDE.md` setup, but GUI-driven
   - User logs in, checks "Keep me signed in", clicks "Done" in Genie UI
6. **Ready** — Genie tray icon turns green, "Say 'Genie' in a JellyJelly video or press Cmd+Shift+G"

### Tech stack (exact packages)

```
Desktop shell:
  @tauri-apps/cli@2          # Build tooling
  @tauri-apps/api@2          # Frontend ↔ Rust IPC
  tauri-plugin-store          # Encrypted key storage
  tauri-plugin-autostart      # Launch at login
  tauri-plugin-updater        # Auto-update from GitHub Releases
  tauri-plugin-global-shortcut # Cmd+Shift+G hotkey
  tauri-plugin-notification    # macOS notifications for wish completion
  tauri-plugin-shell          # Spawn Node sidecar + Claurst binary

Frontend (inside Tauri webview):
  react@19                    # UI framework
  react-router@7              # Onboarding wizard → main app navigation
  tailwindcss@4               # Styling
  @tanstack/react-query       # Trace file polling + wish status
  lucide-react                # Icons

Node.js sidecar (the existing engine, bundled):
  playwright-core             # Chromium download + CDP management
  # Everything else is already in package.json

Voice (optional, Phase 1.5):
  @porcupine/web              # Wake word "Genie" detection (Picovoice, free tier)
  @deepgram/sdk               # Streaming STT after wake word triggers

Claurst binary:
  Pre-compiled for arm64 (Apple Silicon) and x86_64 (Intel)
  Bundled as Tauri sidecar (~15MB per architecture)
```

### Distribution

| Step | How |
|------|-----|
| Code signing | Apple Developer account ($99/yr), sign with `codesign` via Tauri build |
| Notarization | `xcrun notarytool submit` — required for Gatekeeper on macOS |
| .dmg creation | Tauri's built-in `dmg` bundle target (`tauri build --target dmg`) |
| Auto-update | `tauri-plugin-updater` checks GitHub Releases on startup, downloads + installs silently |
| CI/CD | GitHub Actions: `tauri-action` builds arm64 + x86_64 on macOS runner, uploads to Release |

### Build order (sub-phases)

**Week 1: Tauri shell + sidecar plumbing**
- Initialize Tauri 2.0 project in `desktop/` subdirectory
- Configure Node.js sidecar (bundle `src/core/*.mjs` + `node_modules`)
- Configure Claurst binary as sidecar resource
- IPC bridge: frontend can call `start_engine()`, `stop_engine()`, `get_status()`
- Tray icon with start/stop/quit

**Week 2: Onboarding wizard + settings**
- React frontend: 4-step wizard (API key → Chromium download → permissions → browser login)
- Settings page: model selector, budget cap, connected accounts, API keys
- Encrypted key storage via `tauri-plugin-store`
- Chromium lifecycle management (download, launch, health check, restart)

**Week 3: Trace viewer + wish monitor**
- Read `~/.genie/traces/*.jsonl` files, render as expandable wish timeline
- Live wish monitor: WebSocket from sidecar → frontend showing current tool calls
- Kill switch: Cmd+Shift+K sends SIGTERM
- Global hotkey: Cmd+Shift+G opens wish input (text, not voice yet)

**Week 4: Polish + distribution**
- Auto-update from GitHub Releases
- Code signing + notarization
- First .dmg build
- Voice input (Porcupine + Deepgram) — stretch goal, can ship without

---

## SECTION 3: MULTI-USER / CLOUD (Phase 2 — 4 weeks)

### Goal

Multiple users connect through JellyJelly. Each has their own browser sessions, memory, and billing. Genie runs in the cloud — no local install needed.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│  JellyJelly App                                          │
│  User says "Genie, order me pad thai"                    │
│  webhook_targets fires with clip + transcript            │
└──────────────────────┬──────────────────────────────────┘
                       │ POST /webhook/jellyjelly
                       ▼
┌─────────────────────────────────────────────────────────┐
│  API Gateway (Fly.io, Node.js)                           │
│                                                          │
│  1. Verify webhook signature                             │
│  2. Look up JellyJelly username → Genie user             │
│  3. Check auth + billing (Clerk + Stripe)                │
│  4. Queue wish (BullMQ on Redis)                         │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Wish Worker (pulls from BullMQ queue)                   │
│                                                          │
│  1. Spin up E2B sandbox (Firecracker microVM, ~80ms)     │
│  2. Inject user's browser session from Steel.dev         │
│  3. Load user's system prompt (preferences, memory)      │
│  4. Run agent loop (Pi SDK, in-process, not subprocess)  │
│  5. Stream events → WebSocket → user's Telegram/app      │
│  6. Tear down sandbox                                    │
│  7. Log trace to Langfuse                                │
│  8. Debit user's wish count                              │
└─────────────────────────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
┌──────────────┐ ┌──────────┐ ┌──────────────┐
│ Steel.dev    │ │ E2B      │ │ Langfuse     │
│              │ │          │ │              │
│ Per-user     │ │ Sandbox  │ │ Trace store  │
│ browser      │ │ per wish │ │ + analytics  │
│ profiles     │ │ (80ms    │ │              │
│ (encrypted   │ │  cold    │ │              │
│  cookies)    │ │  start)  │ │              │
└──────────────┘ └──────────┘ └──────────────┘
```

### Auth: Clerk

- Sign up with Apple / Google / email
- Clerk webhook on user creation → create Genie user record in Supabase
- JWT on every API call, verified at gateway
- **JellyJelly username linking:** User enters their JellyJelly username in Genie settings → stored in `users.jellyjelly_username` column → gateway maps webhook clip creator to Genie user

### Billing: Stripe

| Tier | Price | Wishes/month | Overage |
|------|-------|-------------|---------|
| Free | $0 | 10 | Hard cap, no overage |
| Pro | $29/mo | 100 | $0.50/wish after 100 |
| Team | $99/mo | 500 | $0.35/wish after 500 |

- Stripe Checkout for subscription creation
- Stripe webhook on `invoice.paid` → reset monthly wish count
- Per-wish cost tracking: LLM tokens + Steel session time + E2B compute
- Budget cap per wish: $5 default, configurable up to $25

### How JellyJelly users connect

1. User signs up on genie.app (Clerk auth)
2. Settings page: "Connect JellyJelly" → enters JellyJelly username
3. We verify the username exists via JellyJelly API
4. On next "genie" keyword in their clip, webhook fires → gateway maps username → dispatches to their account
5. Results delivered via Telegram (initial) → in-app notification (later) → JellyJelly clip comment (always)

### How to pitch this to Iqram

The `webhook_targets` table with `send_transcriptions` flag already exists in JellyJelly's database. This is what we need:

**The ask:**
1. Partner API key for Genie (one webhook target row)
2. `send_transcriptions: true` — fire POST to `https://api.genie.app/webhook/jellyjelly` whenever any clip contains the word "genie"
3. Payload: `{ clip_id, creator_username, transcript_text, clip_url }`

**The pitch:**
- "Genie makes JellyJelly clips actionable. Users say 'Genie, build me a website' into a clip and it actually happens. It's the first platform where voice → action is real."
- "We already have it working with polling. Webhook replaces polling, cuts latency from 3s to <500ms, and removes our API load on your servers."
- "Users opt in by connecting their JellyJelly username in Genie settings. We never access clips from non-opted-in users."
- "Revenue share possible: every Genie user is a JellyJelly power user who records more clips."

### Per-user isolation

| Resource | How it's isolated |
|----------|------------------|
| Browser sessions | Steel.dev profiles — each user gets their own encrypted cookie jar, never shared |
| Execution sandbox | E2B Firecracker microVM — spun up per wish, torn down after. No cross-user state |
| Memory | Supabase row-level security — `user_id` on every row, RLS policies enforce isolation |
| Preferences | Per-user config JSON in Supabase: default model, budget cap, connected services, dietary prefs |
| Traces | Langfuse project per user (or user_id tag on traces with filtered views) |
| Budget | Stripe subscription + wish counter — each user has their own billing state |

### Per-user memory and preferences

```sql
-- Supabase schema
create table users (
  id uuid primary key default gen_random_uuid(),
  clerk_id text unique not null,
  jellyjelly_username text unique,
  telegram_chat_id text,
  stripe_customer_id text,
  tier text default 'free',
  wishes_this_month int default 0,
  created_at timestamptz default now()
);

create table user_preferences (
  user_id uuid references users(id),
  key text not null,
  value jsonb not null,
  primary key (user_id, key)
);
-- Examples: ("default_model", "sonnet"), ("budget_cap", 5), ("dietary", ["no peanuts"])

create table user_memory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  content text not null,
  embedding vector(1536),
  created_at timestamptz default now()
);
-- RAG: on each wish, query top-5 relevant memories and inject into system prompt
```

### Cloud tech stack

| Component | Service | Cost estimate |
|-----------|---------|--------------|
| API Gateway | Fly.io (Node.js) | ~$5/mo base |
| Auth | Clerk | Free tier (10K MAU) |
| Queue | Upstash Redis (BullMQ) | ~$10/mo |
| Sandboxes | E2B | $0.10/sandbox-minute |
| Browser sessions | Steel.dev | $0.05/session-minute |
| Database | Supabase (Postgres + pgvector) | Free tier |
| Traces | Langfuse self-hosted on Fly.io | ~$10/mo |
| Billing | Stripe | 2.9% + $0.30 per transaction |
| DNS + CDN | Cloudflare | Free tier |

### Build order (sub-phases)

**Week 1: API gateway + auth**
- Fly.io Node.js app with Express
- Clerk integration (JWT verification middleware)
- Supabase schema (users, preferences, memory)
- Health check + deploy pipeline

**Week 2: Wish execution in E2B**
- E2B sandbox template with Node.js + Playwright + Chromium
- Pi SDK integration (replace Claurst subprocess with in-process library call)
- Add MCP support to Pi via `@modelcontextprotocol/sdk` (~150 lines)
- Steel.dev browser session injection into sandbox

**Week 3: Billing + JellyJelly webhook**
- Stripe subscription checkout flow
- Wish counter + overage billing
- JellyJelly webhook endpoint (POST `/webhook/jellyjelly`)
- Username verification + mapping

**Week 4: Memory + polish**
- Per-user memory (Supabase pgvector)
- Preference injection into system prompt
- Langfuse trace pipeline
- Load testing (10 concurrent wishes)

---

## SECTION 4: IMMEDIATE ACTIONS (This Week)

### 1. Initialize Tauri 2.0 project

```bash
cd /Users/gtrush/Downloads/genie-2.0
mkdir desktop && cd desktop
npm create tauri-app@latest -- --template react-ts --manager npm
```

Then wire up the sidecar config in `desktop/src-tauri/tauri.conf.json`:
- Add `claurst` as an external binary sidecar
- Add Node.js sidecar for `src/core/server.mjs`
- Configure `tauri-plugin-shell` for process spawning

**Decision needed:** App name. Suggestion: "Genie" with the lamp icon. Bundle ID: `app.genie.desktop`.

### 2. Cross-compile Claurst for distribution

The current binary at `engines/claurst/src-rust/target/release/claurst` is compiled for this machine only. For distribution we need both architectures:

```bash
cd /Users/gtrush/Downloads/genie-2.0/engines/claurst/src-rust
# Apple Silicon (most users)
cargo build --release --target aarch64-apple-darwin
# Intel Mac
cargo build --release --target x86_64-apple-darwin
```

Copy both binaries to `desktop/src-tauri/binaries/`:
- `claurst-aarch64-apple-darwin`
- `claurst-x86_64-apple-darwin`

Tauri auto-selects the right one at runtime.

### 3. Build the onboarding wizard UI

Create `desktop/src/pages/Onboarding.tsx` with 4 steps:
1. **API Key** — text input for OpenRouter key, "Test" button that hits OpenRouter `/auth/key`
2. **Download Browser** — progress bar, calls Tauri command that runs `playwright-core install chromium`
3. **Permissions** — instructions for Accessibility + Microphone, "Check" button
4. **Browser Login** — opens Chrome tabs, shows checklist of services, "Done" button

This is the highest-value UI work because it determines first impression.

### 4. Get Apple Developer account

- Go to https://developer.apple.com/account
- Enroll in Apple Developer Program ($99/year)
- This unlocks: code signing certificate, notarization, .dmg distribution outside App Store
- **Do this NOW** — approval takes 24-48 hours and blocks the entire distribution pipeline

### 5. Message Iqram about webhook partnership

Draft message (send on Telegram or JellyJelly DM):

> "Hey Iqram — Genie is working in production now. Users say 'Genie' in a clip and it builds websites, orders food, sends outreach. Right now I'm polling your API every 3s which is wasteful. I see you already have webhook_targets in your DB with send_transcriptions. Can we set up a partner webhook? I'd send you a URL, you fire a POST when any clip contains 'genie' with the transcript. Cuts my latency to <500ms and removes polling load from your API. Happy to demo anytime — takes 60 seconds to see the magic."

This unblocks Phase 3 but plant the seed now so it's not on the critical path later.

---

## Timeline Summary

```
Week 1-2 (Apr 7-18):  Tauri shell + sidecar plumbing + onboarding wizard
Week 3 (Apr 21-25):   Trace viewer + wish monitor + settings UI
Week 4 (Apr 28-May 2): Code signing + notarization + first .dmg build
                        Voice input if time allows
--- DESKTOP APP SHIPS ---
Week 5-6 (May 5-16):  API gateway + Clerk auth + E2B sandbox
Week 7 (May 19-23):   Steel.dev integration + Stripe billing
Week 8 (May 26-30):   JellyJelly webhook + per-user memory + polish
--- MULTI-USER CLOUD SHIPS ---
```

**The constraint is shipping, not designing.** Everything above is buildable with what exists today. No research needed, no exploratory spikes. Just execute.
