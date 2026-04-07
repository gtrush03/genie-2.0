# GENIE 2.0 ENGINE — Production Runtime Specification

> **Replacing Claude Code with proven open-source alternatives.**
> Zero custom agent loop code. Remix existing projects that already work.
> Model-agnostic. Fully traceable. Desktop + Cloud. Production-grade.

## STATUS: All 4 engine repos forked, cloned, built, and verified running on this machine.

---

## CRITICAL DESIGN PRINCIPLE

**We do NOT write our own agent engine.** We take what already exists, is battle-tested,
and works out of the box. Then we remix it for Genie's purpose with minimal glue code.

- Claurst = compiled and running at `engines/claurst/src-rust/target/release/claurst`
- Pi = built and running at `engines/pi-mono/packages/coding-agent/dist/cli.js`
- Hermes = installed and running via `hermes` (Python venv)
- OpenClaw = built and running at `engines/openclaw/openclaw.mjs`

**The only code we write is the ~50-line adapter in dispatcher.mjs to swap the binary.**

---

## WHY WE'RE REPLACING CLAUDE CODE

Genie v1 spawns `claude -p` (Claude Code CLI) as a subprocess. This works for one user on one Mac. It cannot work for production because:

1. **Vendor lock-in** — Claude Code is Anthropic-proprietary. We can't swap models.
2. **No multi-user** — One process, one user, one machine.
3. **No traceability** — We can't see what the agent is doing or why.
4. **No cost control** — $25 budget cap is the only lever.
5. **Can't host in cloud** — It's a CLI tool, not a library.
6. **Can't package as app** — Users can't download and run it.
7. **Anthropic ToS** — Reselling claude.ai OAuth access is prohibited.

Our engine gives us: **any model, any provider, full audit trail, desktop app, cloud VMs, and total control.**

---

## THE ACTUAL PLAN (AUDIT-VERIFIED)

After building all 4 repos, testing their CLIs, and comparing their event formats
against Genie v1's dispatcher.mjs, here is what actually works:

```
+=============================================================================+
|                                                                              |
|   GENIE V1 (current, working)          GENIE 2.0 (swap)                     |
|                                                                              |
|   server.mjs                           server.mjs (UNCHANGED)               |
|     |                                    |                                   |
|   dispatcher.mjs                       dispatcher.mjs (~50 lines changed)    |
|     |                                    |                                   |
|   spawns: claude -p                    spawns: claurst -p                    |
|     --model sonnet                       --model sonnet                      |
|     --mcp-config mcp.json                --mcp-config mcp.json              |
|     --permission-mode                    --permission-mode                   |
|       bypassPermissions                    bypass-permissions               |
|     --output-format stream-json          --output-format stream-json        |
|     --max-turns 200                      --max-turns 200                    |
|     --max-budget-usd 25                  --max-budget-usd 25               |
|                                          --provider openrouter  <-- NEW    |
|                                                                              |
|   LOCKED TO CLAUDE                     ANY MODEL VIA 35+ PROVIDERS           |
|   NO TRACING                           FULL EVENT STREAM FOR TRACING        |
|   ANTHROPIC ONLY                       OPENROUTER / ANTHROPIC / OPENAI /    |
|                                        GOOGLE / OLLAMA / DEEPSEEK / ...     |
|                                                                              |
+=============================================================================+
```

### PRIMARY ENGINE: CLAURST (Drop-in CLI replacement)

**Binary:** `engines/claurst/src-rust/target/release/claurst` (COMPILED, RUNNING)

Claurst is a clean-room Rust reimplementation of Claude Code. Same CLI flags, same
tools (Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, Agent), same MCP
client, same permission system. BUT with 35+ LLM providers built in.

**What changes in dispatcher.mjs (the ONLY file that changes):**

```javascript
// CHANGE 1: Binary path (line ~20)
// FROM: const claudeBin = findClaudeBin();
// TO:   const claudeBin = path.resolve('engines/claurst/src-rust/target/release/claurst');

// CHANGE 2: Flag casing (lines ~136-149)
// FROM: '--allowedTools'        TO: '--allowed-tools'
// FROM: 'bypassPermissions'     TO: 'bypass-permissions'

// CHANGE 3: Remove unsupported flag
// REMOVE: '--include-partial-messages'

// CHANGE 4: Add provider flag for model-agnostic mode
// ADD: '--provider', process.env.GENIE_PROVIDER || 'anthropic'

// CHANGE 5: Event parsing (~50 lines in handleEvent)
// Claurst's stream-json emits different event types:
//   text_delta, tool_start, tool_end, error, result
// vs Claude Code's:
//   system.init, assistant, user, result
// Rewrite the switch statement to map Claurst events → Telegram messages
```

**That's it. 5 changes. Everything else stays the same:**
- server.mjs: UNCHANGED (still polls JellyJelly every 3s)
- firehose.mjs: UNCHANGED (still matches keyword "genie")
- telegram.mjs: UNCHANGED (still sends messages/photos)
- jelly-comment.mjs: UNCHANGED (still comments on clips)
- config/genie-system.md: UNCHANGED (system prompt works with any model)
- config/mcp.json: UNCHANGED (Playwright MCP still connects to CDP :9222)
- All 5 Uber Eats skills: UNCHANGED

### WHAT CLAURST GIVES US (out of the box, zero code)

| Capability | How |
|-----------|-----|
| **Any model** | `--provider openrouter` → 300+ models via one API key |
| **Anthropic direct** | `--provider anthropic` (default, same as v1) |
| **OpenAI** | `--provider openai` |
| **Google Gemini** | `--provider google` |
| **Local models** | `--provider ollama` (no API key, free) |
| **DeepSeek, Groq, xAI** | `--provider deepseek/groq/xai` |
| **AWS Bedrock** | `--provider bedrock` |
| **Fallback chain** | `--fallback-model gpt-4o` (auto-switch on failure) |
| **MCP servers** | `--mcp-config` (Playwright, filesystem, any MCP server) |
| **Full tool suite** | Bash, Read, Write, Edit, Glob, Grep, WebFetch, WebSearch, Agent (subagents) |
| **Permission system** | 5-level risk classifier, bash command safety analysis |
| **Auto-compact** | Context window management at 90% fill |
| **Session resume** | `--resume <session-id>` |
| **Budget control** | `--max-budget-usd`, `--max-turns` |
| **Cost tracking** | Per-model token pricing, reported in result event |

### SECONDARY: PI CODING AGENT (SDK for future cloud mode)

**Package:** `@mariozechner/pi-coding-agent` (npm, v0.65.2)

Pi is the TypeScript alternative for when we move to cloud (Phase 2). Instead of
spawning a binary, we import the library directly:

```typescript
import { createAgentSession, SessionManager } from "@mariozechner/pi-coding-agent";

const { session } = await createAgentSession({
  sessionManager: SessionManager.inMemory(),
  model: { provider: "openrouter", model: "anthropic/claude-sonnet-4-20250514" },
});

session.subscribe((event) => {
  // Forward events to Telegram, trace system, WebSocket, etc.
});

await session.prompt(wishTranscript);
```

**Why Pi for cloud but not desktop:**
- Pi has NO MCP support (by design philosophy). Browser automation needs MCP.
- For desktop: Claurst binary has MCP. Use that.
- For cloud: We'd add MCP via `@modelcontextprotocol/sdk` as a Pi extension (~150 lines).
- Pi's SDK mode runs in-process (no subprocess spawning) = better for containers.

### REFERENCE ONLY: HERMES + OPENCLAW

These repos are NOT used as engines. They are **reference implementations** we study for
specific features when needed:

| Repo | What We Study | When |
|------|--------------|------|
| **Hermes Agent** | Plugin hook system (8 lifecycle points), credential pool rotation, context compression algorithm, tool call parsers for raw-text models | Phase 2+ when adding plugin extensibility |
| **OpenClaw** | Channel plugin interface (30+ messaging platforms), BlueBubbles iMessage, browser CDP patterns, macOS native automation | Phase 3+ when adding messaging channels beyond Telegram |

---

## REPO ANALYSIS: WHAT WE TAKE AND WHY

### 1. CLAURST — The Core Reference (github.com/gtrush03/claurst)

**What it is:** Clean-room Rust reimplementation of Claude Code. 109K lines, 12 crates, GPL-3.0.

**Why it matters:** This IS Claude Code in open source. Same CLI flags, same tool system, same agent loop, same MCP integration — but with 35+ LLM providers built in from day one.

**What we take:**

| Component | Why | Complexity |
|-----------|-----|------------|
| `LlmProvider` trait | Clean interface for ANY LLM — Anthropic, OpenAI, Google, Ollama, OpenRouter, 30+ more. Already implemented. | LOW — extract trait + registry |
| `Tool` trait + `ToolContext` | Identical to Claude Code's tool system. JSON Schema inputs, async execute, permission levels. | LOW — extract trait |
| Agent loop (`run_query_loop`) | 600 lines of battle-tested logic: tool dispatch, auto-compact, budget guard, stall detection, fallback models | MEDIUM — port to TS or use directly |
| MCP client | Full JSON-RPC 2.0 MCP implementation: stdio + HTTP transport, tool discovery, resource management | MEDIUM — extract crate |
| Permission system | 5-level risk classification (Safe → Critical), bash command classifier, per-tool allowlists | LOW — extract |
| Session storage | JSONL transcript format (compatible with Claude Code), SQLite alternative | LOW — extract |
| Auto-compact | Context window management: triggers at 90% fill, summarizes old messages, preserves recent 10 | MEDIUM — port logic |

**What we DON'T take:** The 20K-line ratatui TUI (we build our own UI), the bridge to claude.ai, the buddy/tamagotchi.

**Key architectural insight:** Claurst's `ProviderRegistry` already maps 35+ providers. Adding a new OpenAI-compatible endpoint is ~10 lines:
```rust
pub fn my_provider() -> OpenAiCompatProvider {
    OpenAiCompatProvider::new("my-provider", "My Provider", "https://api.example.com/v1")
        .with_api_key(std::env::var("MY_API_KEY").unwrap_or_default())
}
```

---

### 2. HERMES AGENT — The Provider + Plugin Layer (github.com/gtrush03/hermes-agent)

**What it is:** NousResearch's production agent. Python, 9,400-line core, 28K GitHub stars, MIT license.

**Why it matters:** The most battle-tested model-agnostic agent framework. Used by thousands for real work. Has patterns Claurst doesn't: plugin hooks, credential rotation, parallel tool execution, context compression, tool call parsers for raw-text models.

**What we take:**

| Component | Why | Complexity |
|-----------|-----|------------|
| Three-transport abstraction | `openai_chat` + `anthropic_messages` + `codex_responses` covers ALL models through just 3 code paths | LOW — architecture pattern |
| Plugin hook system | 8 lifecycle hooks (pre/post tool call, pre/post LLM call, session start/end). Enables audit logging, safety gates, custom tools without modifying core | MEDIUM — port to TS |
| Self-registering tool registry | Tools register at import time with schema + handler + availability check. Clean, extensible, no central manifest to maintain | LOW — pattern |
| Credential pool rotation | Multiple API keys per provider, auto-rotate on 429. Prevents rate-limit death spirals at scale | LOW — implement |
| Fallback model chain | Primary model fails → auto-switch to configured fallback → restore primary next turn | LOW — implement |
| Context compression | Summarize middle turns when approaching context limit. Structured template (Goal, Progress, Decisions, Files, Next Steps) | MEDIUM — port logic |
| Parallel tool execution | Static analysis determines safety: read-only tools always parallel, file tools only when non-overlapping paths, interactive tools always sequential | MEDIUM — port logic |
| Tool call parsers | Parse tool calls from raw text output for models without native tool calling (Hermes, Llama, DeepSeek, Qwen). 12+ model-specific parsers | LOW — port if needed |

**What we DON'T take:** The 9,400-line monolithic `run_agent.py` (we build clean from patterns), the 381K-line CLI, the Python runtime (we're TypeScript/Rust).

**Key architectural insight:** Hermes proves that **OpenAI message format as the canonical internal representation** works. Everything normalizes to `{role, content, tool_calls}`. Anthropic's `tool_use` blocks get converted. Google's `functionCall` parts get converted. Your agent loop code never sees provider-specific formats.

---

### 3. OPENCLAW — The Browser + Channels Layer (github.com/gtrush03/openclaw)

**What it is:** Full-featured open-source AI assistant. TypeScript, 108 extensions, 30+ messaging channels, native macOS app, 3,883 tests.

**Why it matters:** OpenClaw has the production-grade browser automation, messaging channel abstraction, and native Mac integration that Genie needs. We're not building these from scratch.

**What we take:**

| Component | Why | Complexity |
|-----------|-----|------------|
| Browser CDP module | Playwright-core + raw CDP. Multi-profile, multi-tab, screenshots, form filling, navigation guards, SSRF protection. Production-tested | HIGH — extract + adapt |
| Channel plugin interface | `ChannelPlugin` type with 25+ adapter slots (messaging, streaming, threading, approval, outbound). THE abstraction for adding any messaging platform | MEDIUM — port types |
| Telegram extension | Self-contained channel plugin. Bot API polling/webhooks. Already what Genie v1 uses (but better) | LOW — extract |
| BlueBubbles iMessage | Connects to BlueBubbles server for iMessage send/receive. Group chats, reactions, attachments. Works remotely | MEDIUM — extract + shim |
| Provider plugin system | Each LLM provider is a self-contained extension with manifest, auth, stream wrappers. Clean hot-swappable architecture | MEDIUM — extract pattern |
| Audit/logging system | tslog-based structured logging with subsystem tagging, redaction, 500MB rotation. Session transcripts in JSONL | LOW — extract pattern |

**What we DON'T take:** The full 108-extension ecosystem (too big), the Swift macOS app (we build our own with Tauri), the voice call telephony system (not needed yet).

**Key architectural insight:** OpenClaw's browser module uses Playwright as the primary automation layer, with raw CDP only for screenshots and viewport manipulation. The `pw-session.ts` (1,133 lines) is the core — it manages Browser/BrowserContext/Page objects, tracks per-page state (console, errors, network), and supports both managed and user-existing Chrome profiles.

---

### 4. PI CODING AGENT — The Architecture Patterns (github.com/gtrush03/pi-mono)

**What it is:** Mario Zechner's coding agent. TypeScript monorepo, 4 clean packages, aggressively extensible.

**Why it matters:** The cleanest architecture of all four repos. Pi has patterns that make the others look messy: EventStream primitive, pluggable operations, steering queues, session tree branching.

**What we take:**

| Component | Why | Complexity |
|-----------|-----|------------|
| `EventStream<T,R>` | Generic async iterable stream with push/end/result. Simpler and cleaner than Node.js streams. THE streaming primitive for our engine | LOW — lift directly |
| Pluggable Operations | Every tool has an `XxxOperations` interface. Swap local filesystem for SSH/Docker/cloud WITHOUT changing tool logic. Critical for desktop→cloud transition | LOW — pattern |
| Steering + Follow-up queues | Dual queue for injecting messages mid-turn (steering) vs after-completion (follow-up). Solves "redirect agent while working" | LOW — pattern |
| Session tree (JSONL + parentId) | Single file, full history, branch/navigate/fork. Better than linear conversation logs | LOW — implement |
| beforeToolCall / afterToolCall hooks | Clean permission + transformation hooks without modifying tool code. The seam for traceability injection | LOW — pattern |
| File mutation queue | Serializes concurrent writes to same file. Prevents race conditions in parallel tool execution | LOW — lift directly |
| Faux stream test harness | Fake LLM with pre-defined responses + realistic streaming. Full integration testing without API calls | LOW — lift directly |
| Lazy provider loading | Dynamic `import()` on first use. Startup doesn't pay for 20+ providers | LOW — pattern |

**What we DON'T take:** The TUI library (we have our own UI), the web-ui components, the Slack bot.

**Key architectural insight:** Pi deliberately avoids sub-agents, MCP, todos, and plan mode — arguing they confuse models and add complexity. For Genie, we DO want MCP (for Playwright) and subagents (for parallel wish execution), but Pi's philosophy of "extension system as the primary customization mechanism" is correct. Skills > MCP for most use cases.

---

## THE GENIE 2.0 ENGINE ARCHITECTURE

```
                           GENIE 2.0 ENGINE
+========================================================================+
|                                                                         |
|  +-----------------------+         +-----------------------------+      |
|  |   WISH INTAKE         |         |   TRACE SYSTEM              |      |
|  |                       |         |                             |      |
|  |  JellyJelly webhook   |         |  OTEL spans + Langfuse      |      |
|  |  Voice (Porcupine     |         |  JSONL local fallback       |      |
|  |    + Deepgram)         |         |  rrweb browser recording    |      |
|  |  Desktop CLI           |         |  Deterministic replay       |      |
|  |  API endpoint          |         |                             |      |
|  +-----------+-----------+         +-----------------------------+      |
|              |                                                          |
|              v                                                          |
|  +-----------------------+                                              |
|  |   WISH INTERPRETER    |    Haiku pre-screen (safety)                 |
|  |   + SAFETY GATE       |    Content classification                    |
|  +-----------+-----------+    Budget validation                         |
|              |                                                          |
|              v                                                          |
|  +-------------------------------------------------------------------+ |
|  |                    AGENT LOOP (from Claurst + Pi)                   | |
|  |                                                                     | |
|  |  while (hasToolCalls || steeringQueue.length > 0) {                | |
|  |    1. Drain steering messages (mid-run user input)                  | |
|  |    2. Build context (system prompt + user memory + tools)           | |
|  |    3. Stream LLM response via Provider Registry                     | |
|  |    4. Extract tool calls                                            | |
|  |    5. Execute tools (parallel if safe, sequential if destructive)   | |
|  |    6. Log everything to Trace System                                | |
|  |    7. Check budget / turn limits / abort signal                     | |
|  |    8. Auto-compact if context > 90% full                           | |
|  |    9. Continue loop                                                 | |
|  |  }                                                                  | |
|  |  Check follow-up queue → continue or finish                        | |
|  +-------------------------------------------------------------------+ |
|              |                                                          |
|              v                                                          |
|  +-------------------------------------------------------------------+ |
|  |                    PROVIDER REGISTRY                                | |
|  |                                                                     | |
|  |  LiteLLM Proxy (sidecar)  ──or──  Direct Provider Adapters         | |
|  |                                                                     | |
|  |  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐              | |
|  |  │OpenRouter│ │Anthropic │ │ OpenAI   │ │  Ollama  │  ... 35+     | |
|  |  │ (300+    │ │ (direct) │ │ (direct) │ │ (local)  │              | |
|  |  │ models)  │ │          │ │          │ │          │              | |
|  |  └──────────┘ └──────────┘ └──────────┘ └──────────┘              | |
|  +-------------------------------------------------------------------+ |
|              |                                                          |
|              v                                                          |
|  +-------------------------------------------------------------------+ |
|  |                    TOOL REGISTRY                                    | |
|  |                                                                     | |
|  |  Built-in Tools          MCP Tools           Extension Tools        | |
|  |  ┌─────┐ ┌─────┐       ┌──────────┐        ┌──────────────┐       | |
|  |  │Bash │ │Read │       │Playwright│        │Custom tools  │       | |
|  |  │Write│ │Edit │       │ (browser)│        │via extension │       | |
|  |  │Glob │ │Grep │       │GitHub MCP│        │API           │       | |
|  |  │Web* │ │Agent│       │Slack MCP │        │              │       | |
|  |  └─────┘ └─────┘       └──────────┘        └──────────────┘       | |
|  |                                                                     | |
|  |  Each tool has:                                                     | |
|  |    - TypeBox JSON Schema (validated before execution)               | |
|  |    - Operations interface (swappable: local / SSH / Docker / cloud) | |
|  |    - beforeToolCall hook (permission, logging)                      | |
|  |    - afterToolCall hook (transformation, audit)                     | |
|  |    - Permission level (None / ReadOnly / Write / Execute / Critical)| |
|  +-------------------------------------------------------------------+ |
|              |                                                          |
|              v                                                          |
|  +-------------------------------------------------------------------+ |
|  |                    DELIVERY                                         | |
|  |                                                                     | |
|  |  Channel Abstraction (from OpenClaw)                                | |
|  |  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐ ┌───────────┐  | |
|  |  │Telegram │ │JellyJelly│ │iMessage │ │ Discord  │ │ Web/Push  │  | |
|  |  │ (v1)    │ │ comment  │ │BlueBubb.│ │          │ │           │  | |
|  |  └─────────┘ └─────────┘ └─────────┘ └──────────┘ └───────────┘  | |
|  +-------------------------------------------------------------------+ |
|                                                                         |
+=========================================================================+
```

---

## MODEL-AGNOSTIC: HOW IT WORKS

The engine speaks **one internal format** (OpenAI-compatible). All providers normalize to this:

```
User Input
    |
    v
+-------------------+
| Internal Message   |
| Format (OpenAI)    |
|                   |
| role: "assistant" |
| content: "..."    |
| tool_calls: [{    |
|   id, name, args  |
| }]                |
+-------------------+
    |
    |-- OpenRouter (300+ models, one API key)
    |-- Anthropic direct (tool_use blocks → normalized)
    |-- OpenAI direct (native format)
    |-- Google Gemini (functionCall → normalized)
    |-- Ollama local (OpenAI-compat endpoint)
    |-- LM Studio local (OpenAI-compat endpoint)
    |-- Any OpenAI-compatible API
    |
    v
LiteLLM Proxy (optional sidecar)
    - Auto-translates formats bidirectionally
    - Failover: Claude → GPT-4o → Gemini
    - Cost tracking per request
    - Rate limit management
    - Prompt caching
```

**Switching models is one config change:**
```yaml
# ~/.genie/config.yaml
model:
  primary: anthropic/claude-sonnet-4-20250514
  fallback: openai/gpt-4o
  local: ollama/llama3.2
provider: openrouter  # or: anthropic, openai, ollama, litellm
```

---

## TRACEABILITY: EVERY ACTION LOGGED

This is the most important differentiator from Claude Code.

```
WISH: "Order me Thai food"
  |
  [trace_id: wish-a1b2c3]
  |
  +-- [span] LLM Call: Plan actions
  |     model: claude-sonnet-4
  |     tokens: 1,200 in / 340 out
  |     cost: $0.005
  |     latency: 1,847ms
  |
  +-- [span] Tool: browser_navigate
  |     url: https://www.ubereats.com
  |     screenshot_before: s3://traces/shot-001.png
  |     screenshot_after: s3://traces/shot-002.png
  |     duration: 2,100ms
  |
  +-- [span] LLM Call: Find restaurant
  |     tokens: 2,400 in / 180 out
  |     cost: $0.008
  |
  +-- [span] Tool: browser_click
  |     selector: [data-testid="store-card-waewaa"]
  |     screenshot_after: s3://traces/shot-003.png
  |
  +-- [span] Decision: Choose menu items
  |     options: ["pad thai", "green curry", "som tum"]
  |     chosen: "pad thai" (matches user preference from memory)
  |     reasoning: "User ordered pad thai 3 of last 4 times"
  |
  +-- ... (10 more spans)
  |
  +-- [span] Tool: browser_click "Place Order"
  |     screenshot_after: s3://traces/shot-final.png
  |
  RESULT: Order #UE-39281, $22.45, ETA 35min
  TOTAL: 14 spans, $0.043 AI cost, 47 seconds
```

**Stack:**
- **OTEL SDK** instruments all spans (vendor-neutral)
- **Langfuse** (self-hosted) stores and visualizes traces
- **JSONL fallback** for desktop/offline mode
- **rrweb** records browser DOM mutations for replay
- **Deterministic replay** re-runs wishes from recorded trace data

---

## DEPLOYMENT MODES

### Mode 1: Desktop App (Beta — Phase 1)

```
+------------------------------------------+
|  Genie Desktop (Tauri 2.0, ~80MB .dmg)    |
|                                           |
|  +----------------+  +-----------------+  |
|  | React Frontend |  | Rust Core       |  |
|  | (system webview)|  | (IPC, perms,   |  |
|  | - Dashboard     |  |  auto-update)  |  |
|  | - Trace viewer  |  |                |  |
|  | - Settings      |  |                |  |
|  +----------------+  +-----------------+  |
|           |                               |
|  +--------------------------------------+ |
|  | Node.js Sidecar (agent engine)        | |
|  | - Agent loop + tool registry          | |
|  | - MCP client (Playwright, macOS-auto) | |
|  | - Traces → ~/.genie/traces/           | |
|  +--------------------------------------+ |
|           |                               |
|  +--------------------------------------+ |
|  | Chromium (downloaded on first run)    | |
|  | - CDP on localhost:9222               | |
|  | - User's logged-in sessions          | |
|  +--------------------------------------+ |
+------------------------------------------+
```

- User downloads .dmg, drags to Applications
- First run: downloads Chromium (~280MB), requests permissions
- User logs into accounts in the Genie browser
- Voice: Porcupine wake word ("genie") → Deepgram transcription
- Everything runs locally. No cloud dependency except LLM API.

### Mode 2: Cloud (Production — Phase 2)

```
+------------------------------------------+
|  Genie Cloud                              |
|                                           |
|  API Gateway (Fly.io)                     |
|    |                                      |
|    +-- Auth (Clerk)                       |
|    +-- Wish Queue (Redis/BullMQ)          |
|    +-- Billing (Stripe)                   |
|    |                                      |
|    v                                      |
|  E2B Sandbox (per wish, Firecracker VM)   |
|    +-- Agent engine (Node.js)             |
|    +-- Playwright + Chromium              |
|    +-- User's browser session (injected)  |
|    +-- Traces → Langfuse                  |
|    +-- Events → WebSocket to client       |
|    |                                      |
|    +-- Steel.dev / Browserbase            |
|         (persistent browser sessions)     |
|                                           |
|  User's browser sessions stored:          |
|    Steel Profiles (encrypted cookies)     |
|    Per-user, per-service isolation         |
+------------------------------------------+
```

- Users authenticate via Clerk (Apple/Google/email)
- Log into accounts via Steel.dev live browser view
- Sessions persist as encrypted Steel Profiles
- Each wish: E2B sandbox spins up (80ms), loads user session, executes, tears down
- Full trace sent to Langfuse for audit

---

## PHASE PLAN (REALISTIC, AUDIT-VERIFIED)

### Phase 0: Claurst Swap (2-3 days)

**Swap `claude` binary for `claurst` binary. Verify everything works.**

- [ ] Verify Claurst binary runs with Anthropic API key
- [ ] Test: `claurst -p "echo hello" --provider anthropic --permission-mode bypass-permissions`
- [ ] Test: `claurst -p "navigate to google.com" --mcp-config config/mcp.json --provider anthropic`
- [ ] Update dispatcher.mjs: binary path, flag casing, event parsing (~50 lines)
- [ ] Test full wish flow: JellyJelly clip → Claurst dispatch → Telegram report
- [ ] Test with OpenRouter: `--provider openrouter` + OPENROUTER_API_KEY
- [ ] Test with Ollama local: `--provider ollama --model llama3.2`
- [ ] Add JSONL trace logging (append each Claurst event to ~/.genie/traces/)
- [ ] **EXIT CRITERIA:** Same 17 wish types from hackathon work with Claurst, any provider

### Phase 1: Desktop App (3-4 weeks)

**Package Claurst + Genie as a downloadable Mac app.**

- [ ] Tauri 2.0 shell with React frontend
- [ ] Bundle Claurst binary as sidecar (pre-compiled, ~15MB)
- [ ] Chrome management (launch with CDP, session health checks)
- [ ] Voice input: Porcupine wake word + Deepgram streaming
- [ ] macOS permissions flow (Accessibility, Microphone)
- [ ] Settings UI (model/provider selection, budget, connected accounts)
- [ ] Trace viewer (read from ~/.genie/traces/ JSONL files)
- [ ] Auto-update via GitHub Releases (electron-updater pattern)
- [ ] Confirmation flow for purchases > $20
- [ ] Kill switch (Cmd+Shift+K → SIGTERM to Claurst process)
- [ ] **EXIT CRITERIA:** >60% wish success, <$2/wish, <10min time-to-first-wish

### Phase 2: Cloud Alpha (4 weeks)

**Multi-user with cloud browser sessions. Switch from Claurst CLI to Pi SDK.**

- [ ] Swap dispatcher from Claurst subprocess → Pi SDK library call (in-process)
- [ ] Add MCP support to Pi via @modelcontextprotocol/sdk extension (~150 lines)
- [ ] API gateway on Fly.io
- [ ] Clerk auth (Apple/Google/email)
- [ ] Steel.dev browser sessions (persistent profiles per user)
- [ ] E2B sandboxes for per-wish execution (Firecracker microVM, 80ms cold start)
- [ ] Stripe billing (Free 10/mo, Pro $29/100)
- [ ] Langfuse self-hosted for trace visualization
- [ ] User memory (Supabase Postgres + pgvector)
- [ ] Per-user system prompt injection (preferences, budget, connected services)
- [ ] **EXIT CRITERIA:** Multi-user isolation verified, billing works, <5% wish leakage

### Phase 3: JellyJelly Native (3 weeks)

**Partner integration. Webhook replaces polling.**

- [ ] JellyJelly partner API key + webhook (`send_transcriptions`)
- [ ] User opt-in flow (JellyJelly username → Genie account)
- [ ] In-app results (comments on clips)
- [ ] Content moderation (Haiku classifier pre-screen)
- [ ] **EXIT CRITERIA:** Polling eliminated, wishes triggered via webhook, <1s trigger latency

### Phase 4: Scale + Polish (ongoing)

- [ ] Prompt caching optimization (KV-cache hit rate tracking)
- [ ] Self-hosted Steel Browser on k8s (cost optimization)
- [ ] Multi-region deployment (US-East, EU-West)
- [ ] OpenClaw channel integration (Discord, Slack, WhatsApp)
- [ ] iMessage integration via BlueBubbles
- [ ] Smart model routing (cheap model for simple wishes, strong for complex)

---

## FORKED REPOS

All four repos are forked to gtrush03 and cloned locally:

| Repo | Fork | Local Path |
|------|------|------------|
| Claurst | github.com/gtrush03/claurst | `/Users/gtrush/Downloads/genie-2.0/engines/claurst` |
| OpenClaw | github.com/gtrush03/openclaw | `/Users/gtrush/Downloads/genie-2.0/engines/openclaw` |
| Hermes Agent | github.com/gtrush03/hermes-agent | `/Users/gtrush/Downloads/genie-2.0/engines/hermes-agent` |
| Pi Mono | github.com/gtrush03/pi-mono | `/Users/gtrush/Downloads/genie-2.0/engines/pi-mono` |

---

## WHAT CHANGES vs WHAT STAYS THE SAME

| Component | v1 | v2 | Changed? |
|-----------|----|----|----------|
| server.mjs | Polls JellyJelly | Polls JellyJelly | NO |
| firehose.mjs | Keyword "genie" | Keyword "genie" | NO |
| telegram.mjs | Send messages/photos | Send messages/photos | NO |
| jelly-comment.mjs | Comment on clips | Comment on clips | NO |
| config/genie-system.md | System prompt | System prompt | NO |
| config/mcp.json | Playwright MCP | Playwright MCP | NO |
| Uber Eats skills | 5 skills | 5 skills | NO |
| **dispatcher.mjs** | **Spawns `claude -p`** | **Spawns `claurst -p`** | **YES (~50 lines)** |
| Model support | Claude only | 35+ providers, 300+ models | NEW |
| Traceability | None | JSONL trace per wish | NEW |
| Provider | Anthropic locked | `--provider X` flag | NEW |
| Fallback | None | `--fallback-model` | NEW |

**Lines of code we write: ~50 (event parsing adapter in dispatcher.mjs)**
**Lines of code we DON'T write: 109,645 (Claurst), 9,371 (Hermes), ~200K (OpenClaw), ~50K (Pi)**

---

*This document is the foundation for Genie 2.0's custom engine. All work happens in `/Users/gtrush/Downloads/genie-2.0/`. The original Genie v1 at `/Users/gtrush/Downloads/genie/` remains untouched and ready to run.*

*Built by George Trushevskiy. April 2026.*
