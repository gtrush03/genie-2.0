# GENIE 2.0 — Foundational Principles & Build Spec

> **From hackathon trick to production product.**
> 17 wishes fulfilled. $108 in real Uber Eats orders. Real tweets. Real deploys.
> Now make it work for everyone.

---

## Part 1: Competitive Intelligence Summary

### What We Learned From the Market

**Manus AI (acquired by Meta, $2B, Jan 2026)**
- Architecture: Cloud VM per task (E2B Firecracker microVMs), full Linux sandbox with real Chromium browser (not headless), CodeAct paradigm (executable Python as universal action format)
- Key insight: KV-cache hit rate is their #1 production metric. They treat the file system as extended context. They mask token logits during decoding to constrain tool selection without breaking cache
- Multi-agent: Planner agent breaks tasks into steps, specialized sub-agents execute in parallel, orchestrator merges results
- $100M ARR pre-acquisition. Now integrating into WhatsApp Business and Instagram Direct
- **Lesson for Genie:** Their sandbox-per-task model is the gold standard. One wish = one isolated VM. Their context engineering blog is the best public resource on production agent architecture

**OpenAI Operator / ChatGPT Agent (Jan 2025 launch, Jul 2025 folded into ChatGPT)**
- Architecture: CUA (Computer-Using Agent) — GPT-4o vision + RL-trained GUI interaction. Processes raw screenshots, outputs mouse/keyboard actions
- Browser-first, no desktop apps. Cloud-managed browser sessions on OpenAI infrastructure
- $200/month ChatGPT Pro subscription. No public API yet. US-only geographic restriction
- Folded into ChatGPT as "agent mode" by July 2025 — the standalone product was too successful to keep separate
- **Lesson for Genie:** Browser-only is a deliberate constraint that simplifies everything. But Genie's Mac-native approach (iMessage, Calendar, native apps via OpenClaw) is a differentiator Operator can never match

**Rabbit R1 / Humane AI Pin (both failed, 2024-2025)**
- Humane: $230M raised, sold to HP for $116M, all devices bricked Feb 2025. "Solved a problem nobody has"
- Rabbit: 100K units sold, 95% abandonment rate within 5 months. Admitted it launched too early
- Both tried to replace the phone. Both failed because the phone is the phone
- **Lesson for Genie:** NEVER build dedicated hardware. NEVER try to replace existing devices. Genie works THROUGH the user's existing devices — their Mac, their browser, their logged-in accounts. This is the correct approach. The device is the user's computer. Genie is the ghost inside it.

**Anthropic Computer Use (beta, latest: computer-use-2025-11-24)**
- Desktop-first: screenshot capture + mouse/keyboard control. Works on any OS, any application
- Self-managed sandbox (Docker + virtual display). Developer handles security perimeter
- Pay-per-use API (cached input: $0.30/M tokens vs uncached: $3/M — 10x difference)
- Claude Sonnet 4.5 maintains focus for 30+ hours on complex multi-step tasks
- New Agent SDK (formerly Claude Code SDK) provides full agent loop: gather context -> act -> verify -> iterate
- **Lesson for Genie:** This is the runtime we should build on. Agent SDK replaces `claude -p` subprocess spawning. Computer use for native desktop actions. The cached vs uncached pricing gap means context engineering is a cost problem, not just a performance problem.

**OpenClaw (formerly Clawdbot, MIT-licensed)**
- Mac menu bar agent with voice wake, controls iMessage/Calendar/Browser/Terminal
- TCC prompts for Accessibility, Screen Recording, Automation/AppleScript
- Creator (Peter Steinberger) joined OpenAI Feb 2026, project now under independent foundation
- **Lesson for Genie:** OpenClaw solved the Mac-native control problem. We should integrate it (or fork the relevant parts) rather than rebuilding from scratch. The TCC permission flow is the key UX challenge on macOS.

**SoundHound Amelia 7 (Jan 2026)**
- Voice-triggered agent for vehicles/TVs: orders food, books reservations, pays for parking
- Multi-agent orchestration: multiple agents carry out tasks on behalf of the user
- **Lesson for Genie:** Voice-to-action in constrained domains (food, reservations, parking) works TODAY. Genie's open-ended wish fulfillment is harder but more valuable.

---

## Part 2: First Principles

### Principle 1: One Wish = One Atomic Unit

Every wish is a bounded unit of work with:
- A single trigger (voice clip or text command)
- A plan (generated before execution begins)
- An execution trace (every tool call logged)
- A clear outcome: SUCCESS (with receipts) or FAILURE (with explanation)
- A cost ceiling ($X per wish, user-configurable)
- An isolated sandbox (no wish can corrupt another wish's state)

No wish runs forever. No wish blocks another wish. Every wish is resumable if killed.

### Principle 2: User's Sessions Are Sacred

The user's logged-in browser sessions, cookies, tokens, and accounts are the most valuable thing Genie touches. They are harder to replace than any code we write.

Rules:
- Never store credentials server-side. Sessions live on the user's machine (Phase 1) or in their encrypted VM (Phase 2)
- Never navigate away from a page another wish is using (tab isolation, already proven in v1)
- Never close tabs you didn't open
- Crash recovery must preserve session state
- In cloud mode: sessions are encrypted at rest, destroyed on user request, never accessible to Genie's backend team

### Principle 3: Voice In, Results Out — Never Interrupt

Genie is one-way by design. The user speaks a wish. Genie executes it and reports results. Genie NEVER:
- Asks clarifying questions during execution
- Shows confirmation dialogs ("Are you sure you want to order $50 of food?")
- Pauses for approval mid-task

If ambiguous, Genie picks the more ambitious interpretation. If wrong, the user posts a correction video. This constraint is a feature, not a limitation — it forces Genie to be decisive and it makes the demo spectacular.

**Exception (Phase 2+):** High-risk actions (payments over user's threshold, account deletion, sending messages to >10 people) trigger a ONE-TIME confirmation via Telegram/push notification. The wish pauses, waits up to 5 minutes, auto-cancels if no response. This is the only interruption allowed.

### Principle 4: Show the Work

Genie's magic is VISIBLE. The browser moves. The cursor types. The user watches their screen come alive. This is not a background service — it's a performance.

In desktop mode: headed browser, slowMo enabled, every action visible on screen.
In cloud mode: live screencast of the VM session streamed to the user's dashboard.
In both modes: Telegram/push updates at every milestone (not every tool call — 4-10 messages per wish, not 50).

The "show the work" principle also applies to debugging: every wish produces an execution trace that the user can inspect. No black boxes.

### Principle 5: Memory Makes It Better

Genie gets smarter with every wish. Per-user memory captures:
- Preferences ("George always wants dark theme sites", "George's LinkedIn headline is X")
- Corrections ("When I said 'the usual', I meant pizza from Joe's")
- Context ("George is in NYC", "George works on AI agent products")
- Patterns ("George orders Uber Eats most often on Fridays after 10 PM")

Memory is stored locally in Phase 1 (JSON/SQLite) and in encrypted user-scoped storage in Phase 2. Memory is NEVER shared between users. Memory is exportable and deletable by the user.

### Principle 6: Cost Is a First-Class Constraint

Every wish has a cost. The user must always know:
- How much this wish cost (API tokens + any real-world spend)
- How much they've spent this billing period
- What their limits are

The system must optimize for cost:
- KV-cache hit rate as a primary metric (following Manus's lesson: 10x cost difference)
- Context compaction before hitting token limits
- Model routing: use cheaper models for simple wishes, expensive models for complex ones
- Caching: identical or similar wishes should reuse plans/templates

### Principle 7: Escape Velocity Architecture

Every architectural decision must serve the Phase 1 -> Phase 2 -> Phase 3 transition. No decision that works for single-user desktop but blocks multi-user cloud. Specifically:

- Agent runtime must work locally AND in cloud VMs (Agent SDK, not `claude -p`)
- Browser automation must work via local CDP AND remote Browserbase/Steel sessions
- Memory/state must work with local files AND a remote database
- Auth must work with "it's just George's Mac" AND proper OAuth/JWT

If a shortcut would require a rewrite to go multi-user, don't take the shortcut.

---

## Part 3: Phase Breakdown

### Phase 0: Foundation (2 weeks)

**Goal:** Replace hackathon duct tape with production abstractions. No new features — just make the existing 17-wish capability robust and portable.

**What's Built:**
1. **Agent Runtime Migration** — Replace `claude -p` subprocess with Claude Agent SDK
   - `WishAgent` class: takes a wish, produces a result
   - Tool registry: Playwright MCP, Bash, file ops, web search, Telegram reporting
   - Configurable model (Sonnet for most wishes, Opus for complex ones)
   - Cost tracking per wish (token counts, API spend)
   - Structured output: every wish produces `{ status, result, cost, trace }`

2. **Wish Lifecycle** — Formal state machine
   ```
   RECEIVED -> PLANNING -> EXECUTING -> REPORTING -> COMPLETED
                                     \-> FAILED -> RETRY (optional)
   ```
   - Every state transition persisted (SQLite locally, Postgres in cloud)
   - Resume from any state after crash
   - Timeout handling: soft timeout (warn user) at 80% of budget, hard kill at 100%

3. **Browser Abstraction Layer** — Single interface, multiple backends
   - `BrowserSession` interface: `navigate()`, `click()`, `type()`, `screenshot()`, `waitFor()`
   - `LocalCDPSession` — connects to local Chrome via CDP (current approach)
   - `BrowserbaseSession` — connects to Browserbase cloud session (Phase 2)
   - Tab isolation: each wish gets a tab group, namespaced and tracked

4. **Memory System v1** — Local SQLite
   - Per-user preferences, corrections, context
   - Injected into agent system prompt as structured context
   - Simple API: `memory.remember(key, value)`, `memory.recall(query)`
   - Vector search over past wishes for relevant context

5. **Configuration & Secrets** — Proper management
   - Move from `.env` to structured config (JSON schema-validated)
   - Secrets in macOS Keychain (Phase 1) / cloud secret manager (Phase 2)
   - Separate: agent config, user config, system config

**Exit Criteria:**
- All 17 original hackathon wishes work through new Agent SDK runtime
- Wish state machine handles crash recovery (kill process mid-wish, restart, wish resumes)
- Browser abstraction passes tests against both local CDP and Browserbase
- Cost tracking accurate to within 5% of actual API bills
- Zero hardcoded paths, tokens, or user-specific values

**Estimated Effort:** 2 weeks (1 developer, full-time)

---

### Phase 1: Desktop Beta (4 weeks)

**Goal:** Downloadable Mac app. User installs it, logs into their accounts, Genie controls their Mac. Voice input (local mic) + JellyJelly trigger. Multi-wish concurrency.

**What's Built:**
1. **Tauri Desktop App**
   - Tauri 2.x (Rust backend, web frontend) — 96% smaller than Electron, 30MB RAM vs 250MB
   - Menu bar agent (like OpenClaw) — always running, minimal footprint
   - System tray icon with status indicator (idle / executing wish / error)
   - Settings panel: accounts, preferences, cost limits, voice settings
   - Wish history viewer: timeline of all wishes with status, cost, and execution trace

2. **Voice Input (Local)**
   - macOS Speech Recognition API (on-device, no cloud dependency for wake word)
   - Wake word: "Genie" detected locally, then full utterance sent to Whisper/Deepgram for high-quality transcription
   - Push-to-talk alternative: hold hotkey, speak, release
   - JellyJelly trigger still works in parallel (polling API as in v1)

3. **Native Mac Control via OpenClaw Integration**
   - Fork/integrate OpenClaw's macOS tools: Canvas, Camera, system.run
   - TCC permission flow: guided setup on first launch (Accessibility, Screen Recording, Automation)
   - Native app control: iMessage (send messages), Calendar (create events), Reminders, Notes
   - AppleScript bridge for apps that support it

4. **Wish Queue & Concurrency**
   - Up to 5 concurrent wishes (already proven in v1's MAX_CONCURRENT)
   - Priority queue: voice wishes > JellyJelly wishes > scheduled wishes
   - Resource locking: browser tabs are claimed per-wish, released on completion
   - Visual indicator: which wishes are running, which are queued

5. **Onboarding Flow**
   - First launch: "Genie needs to set up your accounts"
   - Opens Chrome/Safari with login pages for supported services
   - User logs in manually (we NEVER handle credentials)
   - Cookie/session persistence verified per service
   - "Say 'Genie, test' to verify everything works" — deploys a test page and sends Telegram confirmation

6. **Auto-Update**
   - Tauri's built-in updater with Sparkle (macOS)
   - Update channel: stable / beta
   - Delta updates (download only changed files)

**Exit Criteria:**
- App downloads as a single .dmg, installs in <1 minute
- Voice trigger works reliably (>95% wake word detection in quiet environment)
- All v1 capabilities work through the desktop app
- Native Mac actions work: send iMessage, create calendar event, add reminder
- Crash recovery: force-quit app, relaunch, running wishes resume
- 10 beta users have installed and completed at least 3 wishes each

**Estimated Effort:** 4 weeks (2 developers: 1 Rust/Tauri backend, 1 frontend/agent)

---

### Phase 2: Cloud Alpha (6 weeks)

**Goal:** Multi-user. Browser sessions run in cloud VMs. Users authenticate, get their own sandboxed environment. Basic billing.

**What's Built:**
1. **User Auth & Accounts**
   - Auth provider: Clerk (best DX, supports social login, webhook-based)
   - JWT-based session management
   - User profile: name, email, connected accounts, preferences, billing tier
   - OAuth flows for services that support it (Google, GitHub, Twitter)

2. **Cloud Browser Sessions**
   - Browserbase for managed browser instances (50M sessions proven, $40M Series B, reliable)
   - One Browserbase session per wish (isolated, ephemeral)
   - Session recording: full replay available to user
   - Session persistence: user's cookies stored in encrypted per-user vault (not in Browserbase)
   - Cookie injection at session start, extraction at session end

3. **Wish Execution Service**
   - Dockerized Agent SDK runtime
   - One container per active wish
   - Fly.io Machines for fast cold start (<2s) and global distribution
   - Container has: Agent SDK, Playwright (connected to Browserbase session), tools
   - Wish state persisted to Postgres (Supabase) — survives container restarts

4. **Database & Storage**
   - Supabase (Postgres + Auth + Storage + Realtime)
   - Tables: users, wishes, wish_events, memory, billing
   - Row-level security: users can only see their own data
   - Realtime subscriptions: frontend gets live wish status updates
   - File storage: screenshots, generated sites, execution traces

5. **Billing v1**
   - Stripe integration
   - Free tier: 10 wishes/month (capped at $1 API cost each)
   - Pro tier: $29/month — 100 wishes/month, $5 max per wish, priority execution
   - Unlimited tier: $99/month — unlimited wishes, $25 max per wish
   - Real-time cost tracking: user sees running cost during wish execution
   - Overage protection: wish auto-stops if approaching tier limit

6. **Moderation & Safety**
   - Input moderation: wishes screened before execution (reject harmful/illegal requests)
   - Output moderation: generated content screened before posting to social media
   - Action allowlist: configurable per-tier (free tier can't order food or send real emails)
   - Spending caps: per-wish, per-day, per-month
   - Rate limiting: wishes per hour per user
   - Audit log: every action permanently logged, available to user
   - Kill switch: admin can halt any wish in progress

7. **API**
   - REST API for wish submission (not just voice/JellyJelly)
   - WebSocket for real-time wish status
   - Webhook callbacks for wish completion
   - API keys for programmatic access (enables third-party integrations)

**Exit Criteria:**
- 50 users onboarded, each completing at least 5 wishes
- Cloud browser sessions work reliably (>90% wish success rate)
- Billing processes real payments
- No data leakage between users (penetration tested)
- Average wish completion time <3 minutes for simple wishes (site build, tweet, email)
- Cost per wish <$0.50 average for simple wishes

**Estimated Effort:** 6 weeks (3 developers: 1 backend/infra, 1 agent/AI, 1 frontend)

---

### Phase 3: JellyJelly Native Integration (3 weeks)

**Goal:** Genie is a first-class feature inside JellyJelly. Users trigger wishes from the app. Results appear in-app. The "agentic social media" vision becomes real.

**What's Built:**
1. **JellyJelly SDK Integration**
   - Webhook-based trigger (replace polling with push notifications from JellyJelly)
   - In-app results: wish results displayed as a reply/attachment to the original clip
   - Deep linking: "View what Genie built" links back to Genie dashboard
   - Creator attribution: "Built by Genie for @creator" on deployed sites

2. **Social Proof Loop**
   - Other JellyJelly users see wishes being fulfilled in real-time
   - Tipping integration: viewers can tip to fund bigger wishes
   - Wish gallery: public feed of coolest wishes fulfilled

3. **Shared Wishes**
   - Multiple users can wish on the same clip (collaborative)
   - JellyJelly rooms where Genie listens to all participants

**Exit Criteria:**
- JellyJelly users can trigger Genie natively without leaving the app
- Results visible in JellyJelly feed
- 500 wishes fulfilled through JellyJelly integration

**Estimated Effort:** 3 weeks (2 developers + JellyJelly team collaboration)

---

### Phase 4: Scale (Ongoing)

**Goal:** Cost optimization, performance, global reach.

**What's Built:**
1. **Cost Optimization**
   - KV-cache optimization (following Manus playbook): stable prefixes, append-only contexts, session routing
   - Model routing: Haiku for classification/simple tasks, Sonnet for execution, Opus for complex reasoning
   - Template caching: common wish patterns (build site, post tweet, order food) pre-compiled
   - Batch processing: multiple simple wishes batched into single API calls where possible

2. **Performance**
   - Edge deployment: Fly.io regions closest to user
   - Browser session pooling: pre-warmed Browserbase sessions
   - Speculative execution: start common sub-tasks before full plan is generated

3. **Multi-Region**
   - EU data residency option (GDPR compliance)
   - Supabase + Fly.io multi-region setup
   - CDN for generated sites (already using Vercel, extend to Cloudflare)

4. **Platform Features**
   - Wish templates: "Order my usual" → pre-configured wish with saved parameters
   - Scheduled wishes: "Every Friday at 6 PM, order pizza"
   - Conditional wishes: "If Bitcoin drops below $X, buy $100 worth"
   - Wish chains: output of one wish feeds into the next

**Exit Criteria:** (per quarter)
- Average wish cost decreases 30% QoQ
- P95 wish completion time <5 minutes
- 99.9% uptime for wish execution service
- 10,000 monthly active users

**Estimated Effort:** Ongoing (3-5 developers)

---

## Part 4: Architecture Decisions

### Decision 1: Agent Runtime — Claude Agent SDK

**Choice:** Claude Agent SDK (Python or TypeScript)
**Rejected:** `claude -p` subprocess (current), direct Anthropic API, LangChain/LlamaIndex

**Rationale:**
- `claude -p` works but is a hack: no programmatic control over tool execution, no structured output, no cost tracking, no graceful shutdown. It's a CLI tool being used as a library.
- Agent SDK gives us: integrated tool registry, built-in context management (compaction), subagent spawning, MCP integration, structured verification loops, and cost tracking.
- Direct API would require rebuilding the agent loop from scratch. Agent SDK gives us Claude Code's battle-tested loop for free.
- LangChain adds abstraction without value — we're locked into Claude anyway.

**Migration path:** `dispatchToClaude()` in dispatcher.mjs becomes `WishAgent.execute()`. The system prompt (genie-system.md) becomes the Agent SDK system prompt. MCP config stays the same. Tool access stays the same. The difference is programmatic control over the loop.

### Decision 2: Desktop Framework — Tauri 2.x

**Choice:** Tauri 2.x
**Rejected:** Electron, Swift native, Flutter

**Rationale:**
- Tauri: 10MB bundle vs Electron's 100MB+. 30MB RAM vs 250MB. Sub-second startup.
- Rust backend provides: native macOS APIs (Keychain, TCC, AppleScript), memory safety, and performance for local agent orchestration
- Web frontend (React/Svelte) means we share UI code with the cloud dashboard
- Tauri 2.x has matured significantly — JS APIs expanded, Rust tax is minimal for common operations
- Swift native would be faster but locks us out of cross-platform (Windows/Linux in future)
- Electron works but bloated — a menu bar agent should not consume 250MB of RAM

**Risk:** Tauri ecosystem is smaller than Electron. Mitigated by: most of our complexity is in the agent runtime (TypeScript), not the desktop shell (Rust).

### Decision 3: Browser Hosting — Browserbase (Cloud) + Local CDP (Desktop)

**Choice:** Browserbase for cloud, local CDP for desktop
**Rejected:** Steel (open-source but 70% success rate), self-hosted Playwright (operational burden), Playwright cloud (no persistent sessions)

**Rationale:**
- Browserbase: 50M sessions processed, $40M Series B, 1000+ customers. Proven at scale.
- Sub-millisecond session launch. Full Chromium (not headless). Session recording built-in.
- MCP server available (`mcp-server-browserbase` + Stagehand) — direct integration with Agent SDK
- Steel is interesting for self-hosting but 70% success rate is unacceptable for production wishes
- Local CDP (current approach) continues to work for desktop beta — same Playwright commands, different transport

**Cookie/session strategy:** User's authenticated sessions are the hard problem. In desktop mode, sessions live in `~/.genie-chrome-profile/` (current approach). In cloud mode, encrypted cookie vault per user — injected into Browserbase session at start, extracted at end. This is the most sensitive data in the entire system.

### Decision 4: Database — Supabase

**Choice:** Supabase (Postgres + Auth + Realtime + Storage)
**Rejected:** PlanetScale (MySQL, no realtime), raw Postgres (operational burden), Firebase (vendor lock-in, no SQL)

**Rationale:**
- Postgres is the right database for structured wish data, user profiles, billing records
- Supabase Realtime gives us WebSocket-based live wish status without building a pub/sub layer
- Row-level security means multi-tenant data isolation at the database level
- Supabase Storage handles screenshots, execution traces, generated files
- Supabase Auth could replace Clerk (cheaper) but Clerk has better social login DX — evaluate during Phase 2
- George already has Supabase experience from BizSynth

### Decision 5: Auth — Clerk (Phase 2)

**Choice:** Clerk
**Rejected:** Supabase Auth (capable but weaker social login UX), Auth0 (expensive), NextAuth (DIY burden)

**Rationale:**
- Clerk has the best developer experience for social login (Google, GitHub, Twitter/X)
- Pre-built React components for sign-in/sign-up
- Webhook-based: easy to sync user creation to Supabase
- $25/month for 10K MAU — reasonable for beta

**Phase 1 doesn't need auth** — it's a single-user desktop app. Auth becomes necessary at Phase 2.

### Decision 6: Billing — Stripe

**Choice:** Stripe
**Rejected:** LemonSqueezy (simpler but less control), Paddle (tax handling is nice but overkill for beta)

**Rationale:**
- Stripe is the industry standard. Metered billing for per-wish pricing. Subscription management for tiers.
- George already has Stripe experience (Ghost Treasury hackathon had Stripe integration)
- Stripe Checkout for onboarding, Stripe Customer Portal for management
- Usage-based billing (per-wish cost tracking) maps directly to Stripe metered subscriptions

### Decision 7: Hosting — Fly.io (compute) + Vercel (sites) + Supabase (data)

**Choice:** Fly.io for agent runtime, Vercel for deployed wish sites, Supabase for data
**Rejected:** AWS (operational burden), Railway (limited), Render (slow cold starts)

**Rationale:**
- Fly.io Machines: <2s cold start, per-second billing, global regions, Firecracker microVMs (same tech as Manus/E2B)
- One Fly Machine per active wish = perfect isolation (mirrors Manus architecture)
- Vercel continues to host wish-deployed sites (already proven in v1)
- This trio (Fly + Vercel + Supabase) is the modern indie SaaS stack — well-documented, affordable, scales

---

## Part 5: Risk Analysis

### Risk 1: Agent SDK Maturity (HIGH)
**Risk:** Claude Agent SDK is new. May have bugs, missing features, breaking changes.
**Impact:** Blocks Phase 0 entirely. Can't ship anything without a stable runtime.
**Mitigation:** Keep `claude -p` as fallback. Abstract the runtime interface so we can swap implementations. Pin SDK version aggressively. Maintain a direct line to Anthropic developer relations (already have contacts from hackathon).

### Risk 2: Browser Session Persistence in Cloud (HIGH)
**Risk:** Keeping users logged into services across ephemeral cloud browser sessions is technically hard. Cookies expire, sessions get invalidated, 2FA triggers on new environments.
**Impact:** Cloud mode (Phase 2) doesn't work if we can't maintain sessions.
**Mitigation:** Cookie vault with per-service session health checks. Re-auth flow when sessions expire. Start with services that have stable cookie-based sessions (Gmail, Twitter) before tackling flaky ones (LinkedIn with its aggressive bot detection). Consider OAuth where available instead of cookie injection.

### Risk 3: LinkedIn/Twitter Bot Detection (HIGH)
**Risk:** Automated browser interactions on LinkedIn and Twitter/X get accounts flagged or banned.
**Impact:** Core demo use case (LinkedIn outreach, tweet posting) breaks.
**Mitigation:** Human-like interaction patterns: realistic delays, mouse movements, scroll behavior. Rate limiting per service (max 10 LinkedIn actions/day, max 20 tweets/day). Persistent browser profiles that look like real user sessions. In Phase 2, consider using official APIs where available (Twitter API for posting, LinkedIn API for messaging — but these are expensive and limited).

### Risk 4: Cost Runaway (MEDIUM-HIGH)
**Risk:** A complex wish spirals into hundreds of tool calls, consuming $20+ in API costs.
**Impact:** User gets a surprise bill. Company loses money on free/low-tier users.
**Mitigation:** Hard per-wish cost ceiling (kill wish at limit). Per-user daily/monthly caps. Model routing (cheap model for simple tasks). Context compaction to reduce token usage. Alert user at 80% of budget. Budget estimation BEFORE execution: "This wish will cost approximately $X. Proceeding."

### Risk 5: Safety — Agent Does Harmful Things (HIGH)
**Risk:** User wishes for something harmful. Or agent misinterprets a wish and takes destructive action (deletes repo, sends embarrassing email, orders $500 of food).
**Impact:** User trust destroyed. Possible legal liability. PR disaster.
**Mitigation:**
- Input moderation: screen wishes before execution. Block clearly harmful requests.
- Action categories with risk levels: read-only (low), create content (medium), send messages (high), spend money (critical)
- Critical actions require confirmation (the one exception to "never interrupt")
- Undo system: for actions that can be undone (delete tweet, cancel order, unsend email within window)
- Per-service spending caps: max $50/day on Uber Eats, max $0 on financial transactions unless explicitly enabled
- Human review queue for wishes that trigger safety flags

### Risk 6: JellyJelly API Stability (MEDIUM)
**Risk:** JellyJelly is a startup. API could change, rate limits could tighten, company could pivot.
**Impact:** JellyJelly trigger (the signature feature from hackathon) stops working.
**Mitigation:** JellyJelly trigger is ONE input method, not the only one. Phase 1 adds voice input. Phase 2 adds API/text input. Even if JellyJelly disappears, Genie works. Maintain relationship with Iqram (JellyJelly founder) — he was excited about "agentic social media" concept.

### Risk 7: Apple TCC Permissions (MEDIUM)
**Risk:** macOS permission prompts (Accessibility, Screen Recording, Automation) confuse or scare users. Apple could tighten restrictions in future macOS versions.
**Impact:** Desktop app adoption limited. Native Mac control features don't work.
**Mitigation:** Guided onboarding with clear explanations of why each permission is needed. Graceful degradation: if user denies Accessibility, Genie still works via browser-only mode. Follow Apple's guidelines exactly to avoid App Store rejection (if we distribute there).

### Risk 8: Multi-User Data Isolation Breach (HIGH)
**Risk:** One user's data (wishes, browser sessions, memory) leaks to another user.
**Impact:** Catastrophic trust failure. Possible legal liability.
**Mitigation:** Defense in depth: row-level security in Supabase, isolated Fly.io machines per wish, isolated Browserbase sessions per wish, no shared state between users. Penetration testing before Phase 2 launch. Bug bounty program.

### Risk 9: Anthropic API Pricing/Availability Changes (MEDIUM)
**Risk:** Anthropic raises prices, changes rate limits, or deprecates models we depend on.
**Impact:** Unit economics break. Wishes become too expensive for our pricing tiers.
**Mitigation:** Model routing flexibility: support OpenAI, Google, and open-source models as alternatives. Abstract the LLM layer so we can swap providers. Negotiate committed-use pricing with Anthropic as volume grows.

### Risk 10: Regulatory / Platform Risk (LOW-MEDIUM)
**Risk:** EU AI Act or other regulations impose requirements on autonomous agents. LinkedIn/Twitter ban automated access entirely.
**Impact:** Compliance burden. Feature removal.
**Mitigation:** Audit logging from day one (required by EU AI Act for "high-risk" AI systems). Transparent to users about what Genie does and doesn't do. Use official APIs where available. Stay under the radar until we're big enough to negotiate. The agentic AI wave means platforms will eventually embrace it (Meta buying Manus proves this).

---

## Part 6: What to Build This Week

The immediate next step is Phase 0. Here's the exact sequence:

### Day 1-2: Agent SDK Spike
- Install Claude Agent SDK
- Build a minimal `WishAgent` that takes a transcript and produces a result
- Verify it can: use Playwright MCP, execute Bash commands, call web search
- Compare output quality to current `claude -p` approach
- If SDK has blockers: document them, file issues, fall back to `claude -p` with better wrapping

### Day 3-4: Wish State Machine
- Define states: RECEIVED, PLANNING, EXECUTING, REPORTING, COMPLETED, FAILED
- SQLite persistence (local)
- Resume logic: pick up where we left off after crash
- Cost tracking: accumulate token usage per wish

### Day 5-7: Browser Abstraction
- `BrowserSession` interface
- `LocalCDPSession` implementation (port current code)
- Tab isolation: each wish owns its tabs
- Basic Browserbase proof-of-concept (create session, navigate, screenshot)

### Day 8-10: Memory System
- SQLite-backed per-user memory
- Ingest: extract preferences/context from completed wishes
- Recall: inject relevant memory into agent system prompt
- Test: "Genie, order the usual" should work after a few food orders

### Day 11-14: Integration & Testing
- Run all 17 original hackathon wishes through new runtime
- Fix regressions
- Performance benchmarks: time-to-completion, cost-per-wish
- Document gaps for Phase 1

---

## Appendix A: Tech Stack Summary

| Layer | Phase 1 (Desktop) | Phase 2 (Cloud) |
|-------|-------------------|------------------|
| Agent Runtime | Claude Agent SDK (local) | Claude Agent SDK (Fly.io) |
| Browser | Local Chrome CDP | Browserbase |
| Desktop Shell | Tauri 2.x | N/A (web dashboard) |
| Voice Input | macOS Speech Recognition + Deepgram | Browser Web Speech API + Deepgram |
| Database | SQLite (local) | Supabase (Postgres) |
| Auth | None (single user) | Clerk |
| Billing | None | Stripe |
| File Storage | Local filesystem | Supabase Storage |
| Hosting | User's Mac | Fly.io + Vercel + Supabase |
| Monitoring | Local logs | Sentry + Fly.io metrics |
| Native Control | OpenClaw fork | N/A (browser only) |

## Appendix B: Cost Model

**Per-wish cost breakdown (estimate):**
- Agent SDK API calls: $0.10-$2.00 (depends on complexity, with caching)
- Browserbase session: $0.01 per session (their pricing at scale)
- Fly.io compute: $0.005 per wish (seconds of machine time)
- Supabase: negligible per wish
- **Total: $0.12-$2.05 per wish**

**Pricing tiers vs costs:**
- Free (10 wishes/month): costs us ~$5/month per user. Acquisition cost.
- Pro ($29/month, 100 wishes): costs us ~$50/month. Slightly negative at first, optimize to positive.
- Unlimited ($99/month): costs us ~$100-200/month. Need high-cache-hit optimization to make profitable.

**Path to profitability:** KV-cache optimization (10x cost reduction on cached context), model routing (Haiku for simple tasks), template caching (skip planning for common wish types), and volume discounts from Anthropic.

## Appendix C: Competitive Positioning

| Feature | Genie | Manus (Meta) | ChatGPT Agent | Operator |
|---------|-------|-------------|----------------|----------|
| Voice trigger | Yes (primary) | No | No | No |
| Desktop native | Yes (Mac) | No (cloud only) | No | No |
| Browser automation | Yes | Yes | Yes | Yes |
| Multi-user | Phase 2 | Yes | Yes | Limited |
| Billing | Phase 2 | Enterprise | $20-200/mo | $200/mo |
| Open source | Partial | No | No | No |
| JellyJelly integration | Yes (unique) | No | No | No |
| Live stream of execution | Yes | Yes (replay) | No | Yes |
| Native Mac apps | Yes (OpenClaw) | No | No | No |

**Genie's moat:** Voice-first + visible execution + JellyJelly social layer + Mac-native control. Nobody else does all four. Manus is cloud-only. ChatGPT Agent is text-only. Neither does live, visible browser control as a feature (Manus records it, but the user doesn't watch in real-time on their own screen).
