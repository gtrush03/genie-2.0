#!/usr/bin/env node
// Genie Dispatcher — spawns a Claude Code subprocess as the execution engine.
//
// Replaces the old interpreter→executor pipeline. When the Genie server detects
// the "genie" keyword in a JellyJelly transcript, it calls dispatchToClaude(),
// which spawns `claude -p` with our system prompt, the Playwright MCP config,
// and full tool access. Stream-json events from the child are parsed live and
// forwarded as Telegram status updates.

import { spawn, execSync } from 'child_process';
import { readFileSync, existsSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

import { sendMessage } from './telegram.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '../..');
// Find claude binary: env override → PATH lookup → common locations
const CLAUDE_BIN = process.env.GENIE_CLAUDE_BIN
  || (() => { try { return execSync('which claude', { encoding: 'utf-8' }).trim(); } catch { return null; } })()
  || (existsSync('/usr/local/bin/claude') ? '/usr/local/bin/claude' : null)
  || (existsSync(`${process.env.HOME}/.local/bin/claude`) ? `${process.env.HOME}/.local/bin/claude` : null)
  || 'claude';
const SYSTEM_PROMPT_PATH = resolve(REPO_ROOT, 'config/genie-system.md');
const MCP_CONFIG_PATH = resolve(REPO_ROOT, 'config/mcp.json');
// Hard timeout is a safety net against a truly stuck process, not a task time budget.
// Default: 60 min. Set GENIE_CLAUDE_TIMEOUT_MS=0 to disable entirely.
const HARD_TIMEOUT_MS = parseInt(process.env.GENIE_CLAUDE_TIMEOUT_MS || String(60 * 60 * 1000), 10);

// Telegram throttle — don't flood the chat with tool-use pings
const TELEGRAM_MIN_INTERVAL_MS = 3000;

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

function buildUserPrompt({ transcript, clipTitle, creator, clipId, keyword }) {
  return [
    `A human named George just triggered you by saying the word "${keyword}" on a JellyJelly video.`,
    ``,
    `--- CLIP METADATA ---`,
    `Clip ID: ${clipId}`,
    `Title: ${clipTitle}`,
    `Creator: @${creator}`,
    ``,
    `--- RAW TRANSCRIPT ---`,
    transcript,
    `--- END TRANSCRIPT ---`,
    ``,
    `Interpret the transcript. George's wish begins near the word "${keyword}" but may span the whole clip. Extract what he actually wants you to do — concretely, in plain English — and then DO it end-to-end using your tools. Report progress and the final receipt to George on Telegram per your system instructions.`,
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

  if (!existsSync(CLAUDE_BIN)) {
    const err = `claude CLI not found at ${CLAUDE_BIN}`;
    log('ERR', err);
    await sendMessage(`❌ Genie dispatcher error: ${err}`);
    return { success: false, sessionId: null, result: null, turns: null, usdCost: null, durationMs: 0, exitCode: null, error: err };
  }
  if (!existsSync(SYSTEM_PROMPT_PATH)) {
    const err = `system prompt missing at ${SYSTEM_PROMPT_PATH}`;
    log('ERR', err);
    await sendMessage(`❌ Genie dispatcher error: ${err}`);
    return { success: false, sessionId: null, result: null, turns: null, usdCost: null, durationMs: 0, exitCode: null, error: err };
  }

  const systemPrompt = readFileSync(SYSTEM_PROMPT_PATH, 'utf-8');
  const userPrompt = buildUserPrompt({ transcript, clipTitle, creator, clipId, keyword });

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

  log('SPAWN', `Spawning claude -p (prompt ${userPrompt.length} chars, system ${systemPrompt.length} chars)`);

  const child = spawn(CLAUDE_BIN, args, {
    cwd: REPO_ROOT,
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env },
  });

  // Pipe the user prompt to stdin and close it.
  child.stdin.write(userPrompt);
  child.stdin.end();

  let sessionId = null;
  let finalResult = null;
  let turns = null;
  let usdCost = null;
  let numTurnsFromResult = null;
  let stderrBuf = '';
  let stdoutBuf = '';
  let lastTelegramAt = 0;
  const pendingToolMsgs = [];

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

  const handleEvent = async (evt) => {
    if (!evt || typeof evt !== 'object') return;
    const t = evt.type;

    if (t === 'system' && evt.subtype === 'init') {
      sessionId = evt.session_id || null;
      log('EVT', `system.init session=${sessionId} model=${evt.model || '?'}`);
      await sendMessage(`🧞 Claude Code spawned. Session ${(sessionId || 'n/a').slice(0, 8)} thinking…`, { plain: true });
      return;
    }

    if (t === 'assistant' && evt.message && Array.isArray(evt.message.content)) {
      for (const block of evt.message.content) {
        if (block.type === 'tool_use') {
          const name = block.name || 'tool';
          const brief = summarizeToolInput(name, block.input);
          const short = name.replace(/^mcp__playwright__/, 'pw.');
          log('EVT', `tool_use ${name} ${brief}`);
          await maybeSendTool(`🔧 ${short} — ${brief || '(no args)'}`);
        } else if (block.type === 'text' && block.text && block.text.trim()) {
          // Assistant thinking text — log but don't spam Telegram
          log('EVT', `text: ${block.text.slice(0, 120).replace(/\n/g, ' ')}`);
        }
      }
      return;
    }

    if (t === 'user' && evt.message && Array.isArray(evt.message.content)) {
      for (const block of evt.message.content) {
        if (block.type === 'tool_result' && block.is_error) {
          const errText = typeof block.content === 'string'
            ? block.content
            : JSON.stringify(block.content).slice(0, 500);
          log('EVT', `tool_result ERROR: ${errText.slice(0, 200)}`);
          await sendMessage(`⚠️ Tool error:\n${errText.slice(0, 1000)}`, { plain: true });
        }
      }
      return;
    }

    if (t === 'result') {
      finalResult = evt.result || evt.message || null;
      numTurnsFromResult = evt.num_turns ?? null;
      usdCost = evt.total_cost_usd ?? evt.cost_usd ?? null;
      turns = numTurnsFromResult;
      log('EVT', `result turns=${turns} cost=${usdCost} len=${(finalResult || '').length}`);
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
      // Fire and forget — we don't want to block the stream on Telegram latency
      handleEvent(evt).catch((err) => log('EVT-ERR', err.message));
    }
  });

  child.stderr.on('data', (buf) => {
    const s = buf.toString('utf-8');
    stderrBuf += s;
    for (const line of s.split('\n')) {
      if (line.trim()) log('STDERR', line.trim().slice(0, 300));
    }
  });

  // Hard timeout — only armed if HARD_TIMEOUT_MS > 0. Safety net for a truly stuck process.
  let killed = false;
  let timeoutHandle = null;
  if (HARD_TIMEOUT_MS > 0) {
    timeoutHandle = setTimeout(() => {
      killed = true;
      log('TIMEOUT', `Killing child after ${HARD_TIMEOUT_MS}ms (safety net, not a task budget)`);
      sendMessage(`⏰ Genie hit ${Math.round(HARD_TIMEOUT_MS / 60000)}min safety timeout — killing subprocess.`, { plain: true }).catch(() => {});
      try { child.kill('SIGTERM'); } catch {}
      setTimeout(() => { try { child.kill('SIGKILL'); } catch {} }, 5000);
    }, HARD_TIMEOUT_MS);
  }

  const exitCode = await new Promise((resolvePromise) => {
    child.on('close', (code) => {
      if (timeoutHandle) clearTimeout(timeoutHandle);
      resolvePromise(code);
    });
    child.on('error', (err) => {
      if (timeoutHandle) clearTimeout(timeoutHandle);
      log('CHILD-ERR', err.message);
      resolvePromise(-1);
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
    await sendMessage(`❌ Genie failed (exit ${exitCode}${killed ? ', killed by timeout' : ''}) after ${(durationMs / 1000).toFixed(1)}s`, { plain: true });
    await sendChunked('stderr tail', tail);
  }

  return {
    success,
    sessionId,
    result: finalResult,
    turns,
    usdCost,
    durationMs,
    exitCode,
    error: success ? null : (killed ? 'timeout' : `exit ${exitCode}`),
  };
}
