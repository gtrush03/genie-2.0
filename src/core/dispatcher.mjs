#!/usr/bin/env node
// Genie Dispatcher — spawns a Claurst subprocess as the execution engine.
//
// Replaces the old interpreter→executor pipeline. When the Genie server detects
// the "genie" keyword in a JellyJelly transcript, it calls dispatchToClaude(),
// which spawns `claurst -p` with our system prompt, the Playwright MCP config
// and full tool access. Stream-json events from the child are parsed live and
// forwarded as Telegram status updates.

import { spawn, execSync } from 'child_process';
import { readFileSync, existsSync, mkdirSync, appendFileSync, readdirSync, unlinkSync, statSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

import { sendMessage } from './telegram.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '../..');
// Claurst binary: env override → repo-local build → PATH lookup
const CLAURST_BIN = process.env.GENIE_CLAURST_BIN
  || (() => {
    const repoBin = resolve(REPO_ROOT, 'engines/claurst/src-rust/target/release/claurst');
    if (existsSync(repoBin)) return repoBin;
    try { return execSync('which claurst', { encoding: 'utf-8' }).trim(); } catch { return null; }
  })()
  || 'claurst';
// Track whether CLAURST_BIN is a bare name (PATH lookup) vs absolute path
const CLAURST_IS_PATH_LOOKUP = !CLAURST_BIN.includes('/');
const SYSTEM_PROMPT_PATH = resolve(REPO_ROOT, 'config/genie-system.md');
// MCP config is now in .claurst/settings.json, not a standalone file.
// Hard timeout is a safety net against a truly stuck process, not a task time budget.
// Default: 60 min. Set GENIE_CLAUDE_TIMEOUT_MS=0 to disable entirely.
const HARD_TIMEOUT_MS = parseInt(process.env.GENIE_CLAUDE_TIMEOUT_MS || String(60 * 60 * 1000), 10);

const TRACE_DIR = resolve(REPO_ROOT, 'traces');
try { mkdirSync(TRACE_DIR, { recursive: true }); } catch {}

// Trace file rotation — keep at most 50 trace files, delete oldest when exceeded.
const MAX_TRACE_FILES = parseInt(process.env.GENIE_MAX_TRACE_FILES || '50', 10);
function rotateTraces() {
  try {
    const files = readdirSync(TRACE_DIR)
      .filter(f => f.startsWith('dispatch-') && f.endsWith('.jsonl'))
      .map(f => ({ name: f, mtime: statSync(resolve(TRACE_DIR, f)).mtimeMs }))
      .sort((a, b) => a.mtime - b.mtime); // oldest first
    const excess = files.length - MAX_TRACE_FILES;
    for (let i = 0; i < excess; i++) {
      try { unlinkSync(resolve(TRACE_DIR, files[i].name)); } catch {}
    }
  } catch {}
}

// Telegram throttle — don't flood the chat with tool-use pings
const TELEGRAM_MIN_INTERVAL_MS = 3000;
// Stall detector — if no stream-json events arrive for this long, the LLM connection
// is probably hung (OpenRouter stall, network issue, rate limit). Kill and fail fast
// instead of waiting for the 60-min hard timeout.
const STALL_TIMEOUT_MS = parseInt(process.env.GENIE_STALL_TIMEOUT_MS || String(120 * 1000), 10);

function log(tag, msg) {
  const ts = new Date().toISOString();
  console.log(`[${ts}] [GENIE] [DISPATCH:${tag}] ${msg}`);
}

// Split a long string into Telegram-safe chunks (4096 char limit, we use 3800).
function chunkText(text, size = 3800) {
  if (!text) return [];
  const out = [];
  let i = 0;
  while (i < text.length) {
    out.push(text.slice(i, i + size));
    i += size;
  }
  return out;
}

async function sendChunked(prefix, text) {
  const chunks = chunkText(text);
  for (let i = 0; i < chunks.length; i++) {
    const p = chunks.length > 1 ? `${prefix} (${i + 1}/${chunks.length})\n` : `${prefix}\n`;
    await sendMessage(p + chunks[i], { plain: true });
  }
}

// ---------------------------------------------------------------------------
// Wish complexity → model routing. Each tier gets a different model + budget.
//   simple  → qwen/qwen3.6-plus:free     (1M ctx, FREE)
//   website → qwen/qwen3-coder-flash     (1M ctx, $0.20/$0.97)
//   browser → anthropic/claude-sonnet-4.6 (1M ctx, $3/$15)
//   premium → anthropic/claude-opus-4.6   (1M ctx, $5/$25)
// ---------------------------------------------------------------------------
const PREMIUM_PATTERNS = [
  /use\s+the\s+best|premium|opus|maximum\s+quality|highest\s+quality/i,
];
const WEBSITE_PATTERNS = [
  /build|create|make|deploy|website|site|landing\s*page|app|html|page/i,
];
const BROWSER_PATTERNS = [
  /order|uber\s?eats|food|delivery|groceries/i,
  /outreach|campaign|dm\s+(everyone|all|multiple)|reach\s+out\s+to\s+\d+/i,
  /research\s+.{10,}|report|analyze|deep\s+dive|investigate/i,
  /stripe|invoice|payment\s+link/i,
  /tweet\s+and|post\s+and|build\s+and|create\s+and/i,
  /browse|login|sign\s+in|click|navigate|scrape/i,
  /linkedin|twitter|x\.com|gmail|uber/i,
];

const TIER_MODELS = {
  simple:  'qwen/qwen3.6-plus:free',
  website: 'qwen/qwen3-coder-flash',
  browser: 'anthropic/claude-sonnet-4.6',
  premium: 'anthropic/claude-opus-4.6',
};

function classifyWishComplexity(transcript) {
  if (PREMIUM_PATTERNS.some(p => p.test(transcript))) return 'premium';
  if (BROWSER_PATTERNS.some(p => p.test(transcript))) return 'browser';
  if (WEBSITE_PATTERNS.some(p => p.test(transcript))) return 'website';
  return 'simple';
}

function getMaxTurns(complexity) {
  if (process.env.GENIE_MAX_TURNS) return process.env.GENIE_MAX_TURNS;
  const map = { simple: '30', website: '200', browser: '999', premium: '999' };
  return map[complexity] || '200';
}

function getMaxBudget(complexity) {
  if (process.env.GENIE_MAX_BUDGET_USD) return process.env.GENIE_MAX_BUDGET_USD;
  const map = { simple: '0.50', website: '5', browser: '25', premium: '50' };
  return map[complexity] || '5';
}

function buildUserPrompt({ transcript, clipTitle, creator, clipId, keyword }) {
  return [
    `## Voice Transcript Interpretation`,
    ``,
    `IMPORTANT: The text below is a raw voice-to-text transcript from a JellyJelly video. It WILL contain:`,
    `- Speech-to-text errors and misheard words — interpret generously`,
    `- Filler words, false starts, and self-corrections`,
    `- The trigger word "${keyword}" which activated you — the actual wish may span the whole clip`,
    ``,
    `## Quality Bar`,
    ``,
    `George is a designer and builder. He expects world-class output:`,
    `- When building websites: beautiful, modern, impressive — multi-section with real content, animations, and polish. NOT a minimal placeholder page. Think award-winning landing page.`,
    `- When writing messages: personalized and compelling, referencing real details about the recipient.`,
    `- When researching: thorough, multi-source, with citations and synthesis.`,
    `- Never deliver mediocre work. If the wish is "build a site", build a GREAT site.`,
    ``,
    `## Clip Metadata`,
    `- Clip ID: ${clipId}`,
    `- Title: ${clipTitle}`,
    `- Creator: @${creator}`,
    ``,
    `## Raw Transcript`,
    ``,
    transcript,
    ``,
    `## Your Job`,
    ``,
    `1. Interpret what George actually wants — read past the speech errors to the real intent.`,
    `2. Execute the wish end-to-end using your tools. Don't stop at 80%. Finish completely.`,
    `3. Report progress and the final receipt to George on Telegram per your system instructions.`,
    ``,
    `Do not reply to me in text. The only way George hears from you is Telegram. Use your tools.`,
  ].join('\n');
}

function summarizeToolInput(toolName, input) {
  if (!input || typeof input !== 'object') return '';
  try {
    if (toolName === 'Bash') return String(input.command || '').slice(0, 140);
    if (toolName === 'Read' || toolName === 'Edit' || toolName === 'Write') {
      return String(input.file_path || input.path || '').slice(0, 140);
    }
    if (toolName === 'WebFetch' || toolName === 'WebSearch') {
      return String(input.url || input.query || '').slice(0, 140);
    }
    if (toolName === 'TodoWrite') {
      const todos = input.todos || [];
      return `${todos.length} todos`;
    }
    if (toolName === 'Task') {
      return String(input.description || input.subagent_type || '').slice(0, 140);
    }
    if (toolName.startsWith('mcp__playwright__') || toolName.includes('browser_')) {
      return String(input.url || input.selector || input.text || JSON.stringify(input)).slice(0, 140);
    }
    const s = JSON.stringify(input);
    return s.length > 140 ? s.slice(0, 140) + '…' : s;
  } catch {
    return '';
  }
}

/**
 * Dispatch a Genie wish to a spawned Claude Code subprocess.
 * Streams events back to Telegram as they arrive.
 *
 * @param {object} args
 * @param {string} args.transcript
 * @param {string} args.clipTitle
 * @param {string} args.creator
 * @param {string} args.clipId
 * @param {string} args.keyword
 * @returns {Promise<{success:boolean, sessionId:?string, result:?string, turns:?number, usdCost:?number, durationMs:number, exitCode:?number, error:?string}>}
 */
export async function dispatchToClaude({ transcript, clipTitle, creator, clipId, keyword }) {
  const startedAt = Date.now();
  const traceFile = resolve(TRACE_DIR, `dispatch-${Date.now()}.jsonl`);
  const trace = (evt) => { try { appendFileSync(traceFile, JSON.stringify({ ts: Date.now(), ...evt }) + '\n'); } catch {} };
  trace({ type: 'dispatch_start', clipId, keyword, transcript: transcript.slice(0, 200) });

  // Validate binary exists — for absolute paths use existsSync, for bare names use `which`
  if (!CLAURST_IS_PATH_LOOKUP && !existsSync(CLAURST_BIN)) {
    const err = `claurst binary not found at ${CLAURST_BIN}`;
    log('ERR', err);
    await sendMessage(`❌ Genie dispatcher error: ${err}`);
    return { success: false, sessionId: null, result: null, turns: null, usdCost: null, durationMs: 0, exitCode: null, error: err };
  }
  if (CLAURST_IS_PATH_LOOKUP) {
    try { execSync(`which ${CLAURST_BIN}`, { encoding: 'utf-8' }); } catch {
      const err = `claurst binary "${CLAURST_BIN}" not found on PATH`;
      log('ERR', err);
      await sendMessage(`❌ Genie dispatcher error: ${err}`);
      return { success: false, sessionId: null, result: null, turns: null, usdCost: null, durationMs: 0, exitCode: null, error: err };
    }
  }
  if (!existsSync(SYSTEM_PROMPT_PATH)) {
    const err = `system prompt missing at ${SYSTEM_PROMPT_PATH}`;
    log('ERR', err);
    await sendMessage(`❌ Genie dispatcher error: ${err}`);
    return { success: false, sessionId: null, result: null, turns: null, usdCost: null, durationMs: 0, exitCode: null, error: err };
  }

  // Validate that the LLM provider has an API key configured
  const provider = process.env.GENIE_PROVIDER || 'openrouter';
  if (provider === 'openrouter' && !process.env.OPENROUTER_API_KEY) {
    const err = 'OPENROUTER_API_KEY not set — cannot dispatch to claurst with openrouter provider';
    log('ERR', err);
    await sendMessage(`❌ Genie dispatcher error: ${err}`);
    return { success: false, sessionId: null, result: null, turns: null, usdCost: null, durationMs: 0, exitCode: null, error: err };
  }
  if (provider === 'anthropic' && !process.env.ANTHROPIC_API_KEY) {
    const err = 'ANTHROPIC_API_KEY not set — cannot dispatch to claurst with anthropic provider';
    log('ERR', err);
    await sendMessage(`❌ Genie dispatcher error: ${err}`);
    return { success: false, sessionId: null, result: null, turns: null, usdCost: null, durationMs: 0, exitCode: null, error: err };
  }

  // Rotate old trace files before creating a new one
  rotateTraces();

  const systemPrompt = readFileSync(SYSTEM_PROMPT_PATH, 'utf-8');
  const userPrompt = buildUserPrompt({ transcript, clipTitle, creator, clipId, keyword });

  // Dynamic max_turns based on wish complexity
  const complexity = classifyWishComplexity(transcript);
  const maxTurns = getMaxTurns(complexity);
  const maxBudget = getMaxBudget(complexity);
  // Model routing: env override wins, otherwise tier-based auto-routing
  const model = process.env.GENIE_CLAUDE_MODEL
    ? (process.env.GENIE_CLAUDE_MODEL.includes('/') ? process.env.GENIE_CLAUDE_MODEL : `anthropic/${process.env.GENIE_CLAUDE_MODEL}`)
    : TIER_MODELS[complexity] || TIER_MODELS.browser;
  log('CLASSIFY', `Wish: ${complexity} → model=${model}, turns=${maxTurns}, budget=$${maxBudget}`);
  const args = [
    '-p',
    '--model', model,
    '--provider', provider,
    '--append-system-prompt', systemPrompt,
    '--permission-mode', 'bypass-permissions',
    '--max-turns', maxTurns,
    '--max-budget-usd', maxBudget,
    '--output-format', 'stream-json',
    '--verbose',
    '--add-dir', REPO_ROOT,
  ];

  log('SPAWN', `Spawning claurst -p (prompt ${userPrompt.length} chars, system ${systemPrompt.length} chars)`);

  const child = spawn(CLAURST_BIN, args, {
    cwd: REPO_ROOT,
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env },
  });

  // Pipe the user prompt to stdin and close it.
  child.stdin.on('error', (err) => log('STDIN-ERR', `stdin pipe error: ${err.message}`));
  child.stdin.write(userPrompt);
  child.stdin.end();

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
    trace(evt);
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

  // Line-buffered stdout parser.
  child.stdout.on('data', (buf) => {
    stdoutBuf += buf.toString('utf-8');
    let nl;
    while ((nl = stdoutBuf.indexOf('\n')) !== -1) {
      const line = stdoutBuf.slice(0, nl).trim();
      stdoutBuf = stdoutBuf.slice(nl + 1);
      if (!line) continue;
      let evt;
      try {
        evt = JSON.parse(line);
      } catch (err) {
        log('PARSE', `non-json line: ${line.slice(0, 200)}`);
        continue;
      }
      // Reset stall detector — we got a valid event, connection is alive.
      armStallTimer();
      // Fire and forget — we don't want to block the stream on Telegram latency
      handleEvent(evt).catch((err) => log('EVT-ERR', err.message));
    }
  });

  child.stderr.on('data', (buf) => {
    const s = buf.toString('utf-8');
    stderrBuf += s;
    // Cap stderr buffer at 100KB to prevent memory bloat on noisy processes
    if (stderrBuf.length > 100_000) {
      stderrBuf = stderrBuf.slice(-50_000);
    }
    for (const line of s.split('\n')) {
      if (line.trim()) log('STDERR', line.trim().slice(0, 300));
    }
  });

  // Hard timeout — only armed if HARD_TIMEOUT_MS > 0. Safety net for a truly stuck process.
  let killed = false;
  let killedReason = null;
  let timeoutHandle = null;
  if (HARD_TIMEOUT_MS > 0) {
    timeoutHandle = setTimeout(() => {
      killed = true;
      killedReason = 'hard_timeout';
      log('TIMEOUT', `Killing child after ${HARD_TIMEOUT_MS}ms (safety net, not a task budget)`);
      sendMessage(`⏰ Genie hit ${Math.round(HARD_TIMEOUT_MS / 60000)}min safety timeout — killing subprocess.`, { plain: true }).catch(() => {});
      try { child.kill('SIGTERM'); } catch {}
      setTimeout(() => { try { child.kill('SIGKILL'); } catch {} }, 5000);
    }, HARD_TIMEOUT_MS);
  }

  // Stall detector — resets on every parsed stream-json event from stdout.
  // If no events arrive for STALL_TIMEOUT_MS, the LLM connection is hung. Kill it.
  let stallHandle = null;
  const armStallTimer = () => {
    if (STALL_TIMEOUT_MS <= 0) return;
    if (stallHandle) clearTimeout(stallHandle);
    stallHandle = setTimeout(() => {
      if (killed) return;
      killed = true;
      killedReason = 'stall';
      log('STALL', `No stream-json events for ${STALL_TIMEOUT_MS / 1000}s — killing hung child`);
      trace({ type: 'stall_kill', stallMs: STALL_TIMEOUT_MS });
      sendMessage(`⏰ Genie stall detected — no LLM response for ${STALL_TIMEOUT_MS / 1000}s. Killing subprocess.`, { plain: true }).catch(() => {});
      try { child.kill('SIGTERM'); } catch {}
      setTimeout(() => { try { child.kill('SIGKILL'); } catch {} }, 5000);
    }, STALL_TIMEOUT_MS);
  };
  // Arm immediately — catches cases where the process never emits any events at all.
  armStallTimer();

  const exitCode = await new Promise((resolvePromise) => {
    let resolved = false;
    const settle = (code) => {
      if (resolved) return;
      resolved = true;
      if (timeoutHandle) clearTimeout(timeoutHandle);
      if (stallHandle) clearTimeout(stallHandle);
      resolvePromise(code);
    };
    child.on('close', (code) => settle(code));
    child.on('error', (err) => {
      log('CHILD-ERR', err.message);
      settle(-1);
    });
  });

  // Drain any pending batched tool messages
  await flushPending().catch(() => {});

  const durationMs = Date.now() - startedAt;
  const success = exitCode === 0 && !killed;

  log('EXIT', `code=${exitCode} killed=${killed} duration=${durationMs}ms turns=${turns} cost=${usdCost}`);

  if (success && finalResult) {
    await sendChunked('🧞 GENIE RECEIPT', finalResult);
    const footer = `✅ Done in ${(durationMs / 1000).toFixed(1)}s · ${turns ?? '?'} turns · $${(usdCost ?? 0).toFixed(3)}`;
    await sendMessage(footer, { plain: true });
  } else if (success) {
    await sendMessage(`✅ Genie finished in ${(durationMs / 1000).toFixed(1)}s but returned no result text. Turns: ${turns ?? '?'}, cost: $${(usdCost ?? 0).toFixed(3)}`, { plain: true });
  } else {
    const tail = stderrBuf.slice(-1500) || '(no stderr)';
    const killLabel = killedReason === 'stall' ? ', killed by stall detector' : killedReason === 'hard_timeout' ? ', killed by timeout' : '';
    await sendMessage(`❌ Genie failed (exit ${exitCode}${killLabel}) after ${(durationMs / 1000).toFixed(1)}s`, { plain: true });
    await sendChunked('stderr tail', tail);
  }

  trace({ type: 'dispatch_end', success, exitCode, durationMs, turns, usdCost, killed, killedReason });

  return {
    success,
    sessionId,
    result: finalResult,
    turns,
    usdCost,
    durationMs,
    exitCode,
    error: success ? null : (killed ? (killedReason || 'timeout') : `exit ${exitCode}`),
  };
}
