# Genie 2.0: Claurst Migration

Drop each prompt into a fresh Claude Code session one at a time, in order.

---

## PROMPT 1 — Start Session

```
I'm migrating Genie 2.0 from Claude Code to Claurst (open-source Rust Claude Code reimplementation with 35+ LLM providers).

Working directory: /Users/gtrush/Downloads/genie-2.0/
DO NOT TOUCH: /Users/gtrush/Downloads/genie/  (original v1, must stay working)
Claurst binary: /Users/gtrush/Downloads/genie-2.0/engines/claurst/src-rust/target/release/claurst

What we're doing: Replace `claude -p` with `claurst -p` in dispatcher.mjs. That's the only significant code change.

Key Claurst differences from Claude Code (verified from Rust source):
- Stream-json emits: text_delta, tool_start, error, result (NOT system.init, assistant, user)
- tool_start field is "tool" not "tool_name"
- Result has "cost_usd" not "total_cost_usd", no "result" text, no "num_turns"
- --permission-mode uses kebab-case: "bypass-permissions" not "bypassPermissions"
- --allowed-tools uses kebab-case (not --allowedTools)
- --mcp-config flag is DEAD in headless mode — MCP servers must go in .claurst/settings.json
- --include-partial-messages doesn't exist
- Config dir is ~/.claurst/ not ~/.claude/
- Memory file is AGENTS.md not CLAUDE.md

Launch 3 Opus agents in parallel to read everything:
  Agent 1: Read /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs (every line)
  Agent 2: Read /Users/gtrush/Downloads/genie-2.0/config/genie-system.md + /Users/gtrush/Downloads/genie-2.0/ENGINE-SPEC.md
  Agent 3: Read /Users/gtrush/Downloads/genie-2.0/.claude/settings.json + /Users/gtrush/Downloads/genie-2.0/config/mcp.json + /Users/gtrush/Downloads/genie-2.0/.env.example

Then run pre-flight checks (single parallel Bash call):
  1. ls -la /Users/gtrush/Downloads/genie-2.0/engines/claurst/src-rust/target/release/claurst
  2. /Users/gtrush/Downloads/genie-2.0/engines/claurst/src-rust/target/release/claurst --help 2>&1 | head -5
  3. test -f /Users/gtrush/Downloads/genie-2.0/.env && grep -c "ANTHROPIC_API_KEY" /Users/gtrush/Downloads/genie-2.0/.env || echo "MISSING"
  4. curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:9222/json/version
  5. ls -la ~/.claurst/ 2>/dev/null || echo "DOES NOT EXIST"
  6. ls -la /Users/gtrush/Downloads/genie-2.0/.claurst/ 2>/dev/null || echo "DOES NOT EXIST"
  7. source /Users/gtrush/Downloads/genie-2.0/.env 2>/dev/null && echo "TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:0:10}..." && echo "TELEGRAM_CHAT_ID=$TELEGRAM_CHAT_ID"

Report a status table. If ANTHROPIC_API_KEY is missing, STOP and tell me. Otherwise confirm ready.
```

---

## PROMPT 2 — Create Claurst Config + AGENTS.md + Skills

```
Working directory: /Users/gtrush/Downloads/genie-2.0/
Claurst binary: engines/claurst/src-rust/target/release/claurst

Launch 3 agents in parallel:

AGENT 1: Create ~/.claurst/settings.json
  mkdir -p ~/.claurst
  Write ~/.claurst/settings.json with EXACT content:
  {
    "config": {
      "permission_mode": "bypass-permissions",
      "auto_compact": true,
      "verbose": false
    }
  }

AGENT 2: Create project-level .claurst/settings.json with Playwright MCP
  mkdir -p /Users/gtrush/Downloads/genie-2.0/.claurst
  Write /Users/gtrush/Downloads/genie-2.0/.claurst/settings.json with EXACT content:
  {
    "config": {
      "permission_mode": "bypass-permissions",
      "mcp_servers": [
        {
          "name": "playwright",
          "command": "npx",
          "args": ["-y", "@playwright/mcp@latest", "--cdp-endpoint", "http://127.0.0.1:9222"],
          "env": {},
          "type": "stdio"
        }
      ],
      "allowed_tools": [
        "Bash", "Read", "Write", "Edit", "Glob", "Grep",
        "WebFetch", "WebSearch", "Task", "TodoWrite", "mcp__playwright"
      ]
    }
  }

AGENT 3: Create AGENTS.md and copy skills
  1. Read /Users/gtrush/Downloads/genie-2.0/CLAUDE.md, write its EXACT content to /Users/gtrush/Downloads/genie-2.0/AGENTS.md
  2. mkdir -p ~/.claurst/skills
  3. cp -r /Users/gtrush/Downloads/genie-2.0/skills/ubereats-* ~/.claurst/skills/
  4. cp -r ~/.claude/skills/* ~/.claurst/skills/ 2>/dev/null || true

After all 3 agents finish, verify:
  cat ~/.claurst/settings.json | python3 -m json.tool
  cat /Users/gtrush/Downloads/genie-2.0/.claurst/settings.json | python3 -m json.tool
  test -f /Users/gtrush/Downloads/genie-2.0/AGENTS.md && echo "AGENTS.md OK"
  ls ~/.claurst/skills/
  diff /Users/gtrush/Downloads/genie-2.0/CLAUDE.md /Users/gtrush/Downloads/genie-2.0/AGENTS.md && echo "Match"
```

---

## PROMPT 3 — Modify dispatcher.mjs: Binary Path & Constants

```
Working directory: /Users/gtrush/Downloads/genie-2.0/
Claurst binary: engines/claurst/src-rust/target/release/claurst

Read /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs first. Then make these 3 edits:

EDIT 1: Replace the binary resolution block.
Find EXACT text:
  const REPO_ROOT = resolve(__dirname, '../..');
  // Find claude binary: env override → PATH lookup → common locations
  const CLAUDE_BIN = process.env.GENIE_CLAUDE_BIN
    || (() => { try { return execSync('which claude', { encoding: 'utf-8' }).trim(); } catch { return null; } })()
    || (existsSync('/usr/local/bin/claude') ? '/usr/local/bin/claude' : null)
    || (existsSync(`${process.env.HOME}/.local/bin/claude`) ? `${process.env.HOME}/.local/bin/claude` : null)
    || 'claude';
Replace with:
  const REPO_ROOT = resolve(__dirname, '../..');
  // Claurst binary: env override → repo-local build → PATH lookup
  const CLAURST_BIN = process.env.GENIE_CLAURST_BIN
    || (() => {
      const repoBin = resolve(REPO_ROOT, 'engines/claurst/src-rust/target/release/claurst');
      if (existsSync(repoBin)) return repoBin;
      try { return execSync('which claurst', { encoding: 'utf-8' }).trim(); } catch { return null; }
    })()
    || 'claurst';

EDIT 2: Replace MCP config path constant.
Find EXACT text:
  const MCP_CONFIG_PATH = resolve(REPO_ROOT, 'config/mcp.json');
Replace with:
  // MCP config is now in .claurst/settings.json, not a standalone file.

EDIT 3: Replace the top comment block.
Find EXACT text:
  // Genie Dispatcher — spawns a Claude Code subprocess as the execution engine.
Replace with:
  // Genie Dispatcher — spawns a Claurst subprocess as the execution engine.

Also replace (if it exists):
  // which spawns `claude -p` with our system prompt, the Playwright MCP config,
Replace with:
  // which spawns `claurst -p` with our system prompt, the Playwright MCP config

Verify:
  grep -n "CLAURST_BIN\|CLAUDE_BIN\|MCP_CONFIG_PATH" /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs
Expected: CLAURST_BIN appears. CLAUDE_BIN and MCP_CONFIG_PATH do NOT appear.
```

---

## PROMPT 4 — Modify dispatcher.mjs: Spawn Args

```
Working directory: /Users/gtrush/Downloads/genie-2.0/
Read /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs first.

EDIT 1: Replace the allowedTools + args block.
Find EXACT text:
  const allowedTools = [
    'Bash', 'Read', 'Write', 'Edit', 'Glob', 'Grep',
    'WebFetch', 'WebSearch', 'Task', 'TodoWrite',
    'mcp__playwright',
  ].join(',');

  const model = process.env.GENIE_CLAUDE_MODEL || 'sonnet';
  const args = [
    '-p',
    '--model', model,
    '--append-system-prompt', systemPrompt,
    '--mcp-config', MCP_CONFIG_PATH,
    '--allowedTools', allowedTools,
    '--permission-mode', 'bypassPermissions',
    '--max-turns', process.env.GENIE_MAX_TURNS || '200',
    '--max-budget-usd', process.env.GENIE_MAX_BUDGET_USD || '25',
    '--output-format', 'stream-json',
    '--include-partial-messages',
    '--verbose',
    '--add-dir', REPO_ROOT,
  ];
Replace with:
  const model = process.env.GENIE_CLAUDE_MODEL || 'sonnet';
  const args = [
    '-p',
    '--model', model,
    '--append-system-prompt', systemPrompt,
    '--permission-mode', 'bypass-permissions',
    '--max-turns', process.env.GENIE_MAX_TURNS || '200',
    '--max-budget-usd', process.env.GENIE_MAX_BUDGET_USD || '25',
    '--output-format', 'stream-json',
    '--verbose',
    '--add-dir', REPO_ROOT,
  ];

Changes: removed --mcp-config, --allowedTools, --include-partial-messages. Fixed bypassPermissions→bypass-permissions.

EDIT 2: Replace the spawn log + spawn call.
Find EXACT text that has CLAUDE_BIN in the spawn call and update to CLAURST_BIN. Find all remaining references to CLAUDE_BIN and change to CLAURST_BIN.

EDIT 3: Replace the binary existence check.
Find: if (!existsSync(CLAUDE_BIN))
Replace: if (!existsSync(CLAURST_BIN))
Find: const err = `claude CLI not found at ${CLAUDE_BIN}`;
Replace: const err = `claurst binary not found at ${CLAURST_BIN}`;

Verify:
  grep -n "CLAUDE_BIN\|allowedTools\|bypassPermissions\|mcp-config\|include-partial" /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs
Expected: ZERO matches.
```

---

## PROMPT 5 — Modify dispatcher.mjs: Event Parsing (THE BIG ONE)

```
Working directory: /Users/gtrush/Downloads/genie-2.0/
Read /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs first.

This is the critical edit. Claurst stream-json is COMPLETELY DIFFERENT from Claude Code.
Claurst emits: text_delta, tool_start, error, result
Claude Code emits: system.init, assistant (with message.content blocks), user (with tool_result), result

Replace the ENTIRE event handler section. Find the block that starts with:
  let sessionId = null;
  let finalResult = null;
and ends with the closing of handleEvent (the line with just "  };").

Replace that ENTIRE block (sessionId/finalResult vars, maybeSendTool, flushPending, and the full handleEvent function) with:

  let sessionId = null;
  let finalResult = null;
  let turns = null;
  let usdCost = null;
  let stderrBuf = '';
  let stdoutBuf = '';
  let lastTelegramAt = 0;
  let toolCount = 0;
  let assistantText = '';
  const pendingToolMsgs = [];
  let initSent = false;

  const maybeSendTool = async (msg) => {
    const now = Date.now();
    if (now - lastTelegramAt >= TELEGRAM_MIN_INTERVAL_MS) {
      lastTelegramAt = now;
      await sendMessage(msg, { plain: true });
    } else {
      pendingToolMsgs.push(msg);
    }
  };

  const flushPending = async () => {
    if (pendingToolMsgs.length === 0) return;
    const combined = pendingToolMsgs.splice(0).join('\n');
    lastTelegramAt = Date.now();
    const chunks = chunkText('🔧 (batched)\n' + combined);
    for (const c of chunks) await sendMessage(c, { plain: true });
  };

  // Claurst stream-json events (verified from Rust source):
  //   {"type":"text_delta","text":"..."}
  //   {"type":"tool_start","tool":"ToolName"}
  //   {"type":"result","usage":{"input_tokens":N,"output_tokens":N},"cost_usd":F}
  //   {"type":"error","error":"..."}
  const handleEvent = async (evt) => {
    if (!evt || typeof evt !== 'object') return;
    const t = evt.type;

    if (!initSent) {
      initSent = true;
      sessionId = `claurst-${Date.now()}`;
      log('EVT', 'Claurst engine running');
      await sendMessage('🧞 Genie engine spawned. Thinking…', { plain: true });
    }

    if (t === 'text_delta') {
      const text = evt.text || '';
      assistantText += text;
      log('EVT', `text: ${text.slice(0, 120).replace(/\n/g, ' ')}`);
      return;
    }

    if (t === 'tool_start') {
      toolCount++;
      const name = evt.tool || 'tool';
      const short = name.replace(/^mcp__playwright__/, 'pw.');
      log('EVT', `tool_start ${name}`);
      await maybeSendTool(`🔧 ${short}`);
      return;
    }

    if (t === 'error') {
      const errText = evt.error || 'unknown error';
      log('EVT', `error: ${errText.slice(0, 200)}`);
      await sendMessage(`⚠️ Error: ${errText.slice(0, 1000)}`, { plain: true });
      return;
    }

    if (t === 'result') {
      finalResult = assistantText || null;
      usdCost = evt.cost_usd ?? null;
      turns = toolCount;
      if (evt.usage) {
        log('EVT', `result in=${evt.usage.input_tokens} out=${evt.usage.output_tokens} cost=${usdCost}`);
      }
      return;
    }
  };

After editing, verify:
  grep -n "text_delta\|tool_start\|system.*init\|evt\.message\|assistant.*message\|tool_result" /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs
Expected: text_delta and tool_start appear. system.init, evt.message, tool_result do NOT appear.
  node --check /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs && echo "SYNTAX OK"
```

---

## PROMPT 6 — Update genie-system.md + .env.example

```
Working directory: /Users/gtrush/Downloads/genie-2.0/

Launch 2 agents in parallel:

AGENT 1: Edit /Users/gtrush/Downloads/genie-2.0/config/genie-system.md
  Find: You are running as a spawned `claude -p` subprocess inside the Genie server.
  Replace: You are running as a spawned headless subprocess inside the Genie server.

  Find: Skills available (all at `~/.claude/skills/ubereats-*/SKILL.md`, auto-discovered):
  Replace: Skills available (all at `~/.claurst/skills/ubereats-*/SKILL.md`, auto-discovered):

  Find: Open `~/.claude/skills/ubereats-order/SKILL.md` with the Read tool to get started.
  Replace: Open `~/.claurst/skills/ubereats-order/SKILL.md` with the Read tool to get started.

  Verify: grep -n "claude -p\|~/.claude/skills" /Users/gtrush/Downloads/genie-2.0/config/genie-system.md
  Expected: ZERO matches.

AGENT 2: Edit /Users/gtrush/Downloads/genie-2.0/.env.example
  Find: # === DISPATCHER (Claude Code as the execution engine) ===
  Replace: # === DISPATCHER (Claurst as the execution engine) ===

  Find: # GENIE_CLAUDE_BIN=/Users/you/.local/bin/claude
  Replace: # GENIE_CLAURST_BIN=/path/to/claurst

  Add this line after the dispatcher section if ANTHROPIC_API_KEY is not already there:
  ANTHROPIC_API_KEY=sk-ant-your-key-here

  Verify: grep -n "CLAURST\|Claurst\|ANTHROPIC_API_KEY" /Users/gtrush/Downloads/genie-2.0/.env.example
```

---

## PROMPT 7 — Add Trace Logging

```
Working directory: /Users/gtrush/Downloads/genie-2.0/
Read /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs first.

Make these 4 edits to add JSONL trace logging:

EDIT 1: Add mkdirSync and appendFileSync to the fs import.
Find: import { readFileSync, existsSync } from 'fs';
Replace: import { readFileSync, existsSync, mkdirSync, appendFileSync } from 'fs';

EDIT 2: Add trace directory constant. Find the TELEGRAM_MIN_INTERVAL_MS line, add BEFORE it:
  const TRACE_DIR = resolve(REPO_ROOT, 'traces');
  try { mkdirSync(TRACE_DIR, { recursive: true }); } catch {}

EDIT 3: Add trace function at the start of the dispatch function, right after "const startedAt = Date.now();":
  const traceFile = resolve(TRACE_DIR, `dispatch-${Date.now()}.jsonl`);
  const trace = (evt) => { try { appendFileSync(traceFile, JSON.stringify({ ts: Date.now(), ...evt }) + '\n'); } catch {} };
  trace({ type: 'dispatch_start', clipId, keyword, transcript: transcript.slice(0, 200) });

EDIT 4: In handleEvent, add trace(evt) right after the null check:
  Find: if (!evt || typeof evt !== 'object') return;
  Add on the NEXT line: trace(evt);

EDIT 5: Before the return statement at the end of the function, add:
  trace({ type: 'dispatch_end', success, exitCode, durationMs, turns, usdCost, killed });

Verify:
  node --check /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs && echo "SYNTAX OK"
  grep -c "trace(" /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs
  Expected: SYNTAX OK, trace count > 3
```

---

## PROMPT 8 — Smoke Test: Binary + MCP

```
Working directory: /Users/gtrush/Downloads/genie-2.0/

Run these tests in sequence. Report each as PASS/FAIL.

TEST 1 — Claurst binary runs:
  /Users/gtrush/Downloads/genie-2.0/engines/claurst/src-rust/target/release/claurst --help 2>&1 | head -5
  PASS if output contains usage info. FAIL if command not found.

TEST 2 — Stream-json output:
  source /Users/gtrush/Downloads/genie-2.0/.env
  echo "Say exactly: hello world" | /Users/gtrush/Downloads/genie-2.0/engines/claurst/src-rust/target/release/claurst -p --output-format stream-json --max-turns 1 --permission-mode bypass-permissions 2>/dev/null
  PASS if output contains {"type":"text_delta" AND {"type":"result"
  FAIL if no output or auth error

TEST 3 — MCP/Playwright (requires Chrome CDP on :9222):
  curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9222/json/version
  If not 200, tell me to start Chrome first. Otherwise:
  source /Users/gtrush/Downloads/genie-2.0/.env
  cd /Users/gtrush/Downloads/genie-2.0 && echo 'Navigate to https://example.com using mcp__playwright__browser_navigate then take a snapshot with mcp__playwright__browser_snapshot. Print the page title.' | ./engines/claurst/src-rust/target/release/claurst -p --output-format stream-json --max-turns 5 --permission-mode bypass-permissions --verbose 2>/tmp/claurst-mcp-stderr.log | tee /tmp/claurst-mcp.log
  Then: grep "tool_start" /tmp/claurst-mcp.log
  PASS if tool_start events for playwright tools appear. FAIL if "No MCP servers" in stderr.

TEST 4 — Dispatcher syntax:
  node --check /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs && echo "SYNTAX OK"
  PASS if SYNTAX OK.

Report table:
| Test | Result |
|------|--------|
| Binary runs | |
| Stream-json | |
| MCP/Playwright | |
| Dispatcher syntax | |
```

---

## PROMPT 9 — Full End-to-End Test

```
Working directory: /Users/gtrush/Downloads/genie-2.0/

This tests the complete wish flow: Claurst + system prompt + MCP + Telegram reporting.

Pre-check (all must be SET):
  source /Users/gtrush/Downloads/genie-2.0/.env
  echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:+SET}"
  echo "TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:+SET}"
  echo "TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID:+SET}"
  curl -s -o /dev/null -w "CDP:%{http_code}" --max-time 2 http://127.0.0.1:9222/json/version
If anything is missing, tell me exactly what and stop.

Run the test:
  source /Users/gtrush/Downloads/genie-2.0/.env
  SYSTEM_PROMPT=$(cat /Users/gtrush/Downloads/genie-2.0/config/genie-system.md)
  cd /Users/gtrush/Downloads/genie-2.0 && echo "A human named George triggered you by saying genie on JellyJelly. He said: genie, send a test message on Telegram saying Claurst engine migration successful. Do this now using curl and the TELEGRAM env vars." | ./engines/claurst/src-rust/target/release/claurst -p \
    --model sonnet \
    --append-system-prompt "$SYSTEM_PROMPT" \
    --permission-mode bypass-permissions \
    --max-turns 20 \
    --max-budget-usd 5 \
    --output-format stream-json \
    --verbose \
    --add-dir /Users/gtrush/Downloads/genie-2.0 \
    2>/tmp/claurst-e2e-stderr.log | tee /tmp/claurst-e2e.log

Check results:
  echo "=== Tools used ==="
  grep "tool_start" /tmp/claurst-e2e.log
  echo "=== Result ==="
  grep '"type":"result"' /tmp/claurst-e2e.log
  echo "=== Errors ==="
  grep -i "error" /tmp/claurst-e2e.log /tmp/claurst-e2e-stderr.log 2>/dev/null | head -5

Also check: ls -la /Users/gtrush/Downloads/genie-2.0/traces/
There should be a new trace file if trace logging is working.

Report:
| Check | Status |
|-------|--------|
| Stream started | |
| Tool events | N tool_start events |
| Result event | cost: $X.XX |
| Trace file | exists / missing |
| Telegram received | ASK ME |
| Errors | none / list |
```

---

## PROMPT 10 — Final Verification + Commit

```
Working directory: /Users/gtrush/Downloads/genie-2.0/

Run final checks:

CHECK 1 — All files parse:
  node --check /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs && echo "dispatcher: OK"
  python3 -m json.tool < /Users/gtrush/Downloads/genie-2.0/.claurst/settings.json > /dev/null && echo "settings: OK"
  python3 -m json.tool < ~/.claurst/settings.json > /dev/null && echo "global settings: OK"

CHECK 2 — No stale Claude Code references:
  grep -rn "CLAUDE_BIN\|claude -p\|~/.claude/skills\|--allowedTools\|bypassPermissions\|--include-partial-messages\|MCP_CONFIG_PATH" \
    /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs \
    /Users/gtrush/Downloads/genie-2.0/config/genie-system.md
  Expected: ZERO matches.

CHECK 3 — New references exist:
  grep -c "CLAURST_BIN" /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs
  grep -c "text_delta\|tool_start" /Users/gtrush/Downloads/genie-2.0/src/core/dispatcher.mjs
  Expected: all > 0.

CHECK 4 — Git diff:
  cd /Users/gtrush/Downloads/genie-2.0 && git diff --stat

If all checks pass, ask me if I want to commit. If yes, commit with message:
"Replace Claude Code with Claurst engine — model-agnostic, 35+ providers, full traceability"
```
