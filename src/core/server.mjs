#!/usr/bin/env node
// Genie Server — Continuous JellyJelly firehose watcher
// Polls for new clips, detects "genie" keyword, interprets, executes, reports
// Usage: node src/core/server.mjs

import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

// ─── Load .env manually ───────────────────────────────────────────────────────
const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = resolve(__dirname, '../../.env');

try {
  const envContent = readFileSync(envPath, 'utf-8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    // Skip comments and empty lines
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIndex = trimmed.indexOf('=');
    if (eqIndex === -1) continue;
    const key = trimmed.slice(0, eqIndex).trim();
    const value = trimmed.slice(eqIndex + 1).trim();
    // Don't override existing env vars
    if (!(key in process.env)) {
      process.env[key] = value;
    }
  }
  log('INIT', `Loaded .env from ${envPath}`);
} catch (err) {
  log('INIT', `.env not found at ${envPath} — using existing env vars`);
}

// ─── Imports (after env is loaded) ────────────────────────────────────────────
import {
  pollForNewClips,
  fetchClipDetail,
  containsKeyword,
  reconstructTranscript,
} from './firehose.mjs';
import { sendMessage } from './telegram.mjs';
import { executeProposal } from './executor.mjs'; // kept as fallback reference — no longer called
import { dispatchToClaude } from './dispatcher.mjs';

// ─── Config ───────────────────────────────────────────────────────────────────
const POLL_INTERVAL = parseInt(process.env.GENIE_POLL_INTERVAL || '3000', 10);
const FAST_RETRY_INTERVAL = parseInt(process.env.GENIE_FAST_RETRY_INTERVAL || '1500', 10);
const FAST_RETRY_MAX_MS = parseInt(process.env.GENIE_FAST_RETRY_MAX_MS || '300000', 10); // 5 min — transcripts always arrive
const KEYWORD = (process.env.GENIE_KEYWORD || 'genie').toLowerCase();

// Track seen clip IDs to avoid reprocessing
const seenClipIds = new Set();
// Clips currently being watched for transcript arrival (don't double-process from main loop)
const awaitingTranscript = new Set();

// Count words in a transcript_overlay — a non-empty overlay with 0 words means Deepgram
// hasn't finished yet, even though the shell exists. This was the bug: we treated
// "overlay exists" as "transcript ready" and blacklisted clips before words arrived.
function transcriptWordCount(overlay) {
  try {
    const words = overlay?.results?.channels?.[0]?.alternatives?.[0]?.words;
    return Array.isArray(words) ? words.length : 0;
  } catch {
    return 0;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
function log(tag, msg) {
  const ts = new Date().toISOString();
  console.log(`[${ts}] [GENIE] [${tag}] ${msg}`);
}

// ─── Concurrent dispatch ─────────────────────────────────────────────────────
const MAX_CONCURRENT = parseInt(process.env.GENIE_MAX_CONCURRENT || '5', 10);
let activeDispatches = 0;
const wishQueue = []; // overflow queue when at capacity

async function buildCommentText(result, clipTitle = '') {
  if (!result) return '🧞 Heard your wish — couldn\'t complete it. Check Telegram.';
  if (!result.success) return '🧞 Heard your wish — couldn\'t complete it. Check Telegram.';

  const text = result.result || '';

  // Extract ALL unique URLs from the result (deployed sites, tweets, payment links, etc.)
  const urlMatches = text.match(/https?:\/\/[^\s)>"'\]]+/g) || [];
  // Filter to the interesting ones — skip API/internal URLs
  let outputUrls = [...new Set(urlMatches)].filter(u =>
    u.includes('vercel.app') ||
    u.includes('x.com') || u.includes('twitter.com') ||
    u.includes('buy.stripe.com') ||
    u.includes('ubereats.com/orders') ||
    u.includes('genie-') ||
    u.includes('/status/')
  );

  // Fallback: if no URLs in result text, check Vercel for the most recently deployed genie-* project
  if (outputUrls.length === 0) {
    try {
      const { execSync } = await import('child_process');
      const out = execSync('npx vercel project ls 2>/dev/null | head -5', { encoding: 'utf-8', timeout: 15000 });
      const lines = out.split('\n');
      for (const line of lines) {
        const match = line.match(/(https:\/\/genie-[^\s]+\.vercel\.app)/);
        if (match && match[1]) {
          // Check if this project was updated in the last 10 minutes (likely from this wish)
          const updatedMatch = line.match(/(\d+[smhd])\s/);
          if (updatedMatch) {
            const age = updatedMatch[1];
            if (age.endsWith('s') || age.endsWith('m') || (age.endsWith('m') && parseInt(age) <= 10)) {
              outputUrls.push(match[1]);
              break;
            }
          }
        }
      }
    } catch { /* Vercel check is best-effort */ }
  }

  // Still nothing? Try any non-API URL
  if (outputUrls.length === 0) {
    const anyUrl = urlMatches.find(u =>
      !u.includes('api.telegram.org') &&
      !u.includes('api.jellyjelly.com') &&
      !u.includes('openrouter.ai') &&
      !u.includes('127.0.0.1')
    );
    if (anyUrl) return `🧞 Wish granted!\n${anyUrl}`;
    return '🧞 Done! Check Telegram for the full report.';
  }

  // Build a clean comment with all output links
  const lines = ['🧞 Wish granted!'];
  for (const url of outputUrls.slice(0, 4)) {
    if (url.includes('x.com') || url.includes('twitter.com')) lines.push(`🐦 ${url}`);
    else if (url.includes('buy.stripe.com')) lines.push(`💳 ${url}`);
    else if (url.includes('ubereats.com')) lines.push(`🛒 ${url}`);
    else lines.push(`🔗 ${url}`);
  }
  return lines.join('\n');
}

function drainQueue() {
  while (wishQueue.length > 0 && activeDispatches < MAX_CONCURRENT) {
    const next = wishQueue.shift();
    runDispatch(next);
  }
}

function runDispatch(clip) {
  activeDispatches++;
  const clipId = clip.id || clip.ulid || 'unknown';
  const creator = clip.creator?.username || clip.username || 'unknown';
  const transcript = clip._transcript || reconstructTranscript(clip.transcript_overlay) || '';
  const clipTitle = clip.title || clip.description || `Clip ${clipId}`;

  log('EXEC', `Dispatching clip ${clipId} by @${creator} (${activeDispatches}/${MAX_CONCURRENT} active)`);

  dispatchToClaude({ transcript, clipTitle, creator, clipId, keyword: KEYWORD })
    .then(async (result) => {
      log('EXEC', `Clip ${clipId} done: success=${result.success} turns=${result.turns} cost=$${result.usdCost ?? 0} in ${(result.durationMs / 1000).toFixed(1)}s`);

      // Comment on the original clip with results
      try {
        const { commentOnClip } = await import('./jelly-comment.mjs');
        const commentText = await buildCommentText(result, clipTitle);
        const commentResult = await commentOnClip(clipId, commentText);
        log('COMMENT', `Clip ${clipId}: method=${commentResult.method} success=${commentResult.success}`);
      } catch (err) {
        log('COMMENT', `Failed to comment on ${clipId}: ${err.message}`);
      }
    })
    .catch(err => {
      log('EXEC', `Clip ${clipId} threw: ${err.message}`);
      sendMessage(`\u274C Genie error on "${clipTitle}": ${err.message}`).catch(() => {});
    })
    .finally(() => {
      activeDispatches--;
      drainQueue();
    });
}

async function executeGenieAction(clip) {
  const clipId = clip.id || clip.ulid || 'unknown';
  const creator = clip.creator?.username || clip.username || 'unknown';
  const clipTitle = clip.title || clip.description || `Clip ${clipId}`;
  const transcript = clip._transcript || reconstructTranscript(clip.transcript_overlay) || '';

  log('EXEC', `Keyword "${KEYWORD}" detected in clip ${clipId}!`);
  log('EXEC', `  Creator: @${creator}`);
  log('EXEC', `  Transcript: ${transcript.slice(0, 200)}`);

  await sendMessage(`\u{1F9DE} Genie heard "${KEYWORD}" in "${clipTitle}" by @${creator}. Spawning Claude Code…`);

  if (activeDispatches >= MAX_CONCURRENT) {
    log('QUEUE', `${activeDispatches} wishes active, queuing clip ${clipId}`);
    await sendMessage(`\u23F3 Genie is busy (${activeDispatches} active). "${clipTitle}" queued — it'll run next.`);
    wishQueue.push(clip);
  } else {
    runDispatch(clip);
  }
}

// ─── Clip handling ────────────────────────────────────────────────────────────
// Process a clip detail: check if transcript is ready, match keyword, dispatch.
// Returns true if we reached a terminal state (dispatched OR confirmed no keyword).
// Returns false if transcript still isn't ready and we should retry.
async function processClipDetail(detail, clipId) {
  const wordCount = transcriptWordCount(detail.transcript_overlay);

  if (wordCount === 0) {
    return false; // not ready, caller will retry
  }

  // Transcript is ready — terminal state either way
  seenClipIds.add(clipId);

  if (containsKeyword(detail.transcript_overlay, KEYWORD)) {
    log('KEYWORD', `🧞 "${KEYWORD}" DETECTED in clip ${clipId} (${wordCount} words)`);
    await executeGenieAction(detail);
  } else {
    const transcript = detail._transcript || '(empty)';
    const preview = transcript.length > 80 ? transcript.slice(0, 80) + '...' : transcript;
    log('KEYWORD', `No "${KEYWORD}" in clip ${clipId} (${wordCount} words) — "${preview}"`);
  }
  return true;
}

// Fast-retry watcher: polls a single clip's detail endpoint every FAST_RETRY_INTERVAL
// until the transcript is populated, then processes immediately. Fires detached —
// the main poll loop keeps running in parallel and skips clips in awaitingTranscript.
async function watchClipForTranscript(clipId, clipMeta = {}) {
  if (awaitingTranscript.has(clipId) || seenClipIds.has(clipId)) return;
  awaitingTranscript.add(clipId);

  const username = clipMeta.username || 'unknown';
  log('WATCH', `Fast-watching clip ${clipId} by ${username} for transcript...`);

  const started = Date.now();
  try {
    while (Date.now() - started < FAST_RETRY_MAX_MS) {
      await new Promise(r => setTimeout(r, FAST_RETRY_INTERVAL));
      try {
        const detail = await fetchClipDetail(clipId);
        const done = await processClipDetail(detail, clipId);
        if (done) {
          const elapsed = ((Date.now() - started) / 1000).toFixed(1);
          log('WATCH', `Clip ${clipId} transcript ready after ${elapsed}s`);
          return;
        }
      } catch (err) {
        log('WATCH', `Fetch failed for ${clipId}: ${err.message}`);
      }
    }
    // Timeout — give up but mark as seen so main loop doesn't re-spawn a watcher
    seenClipIds.add(clipId);
    log('WATCH', `Clip ${clipId} transcript never arrived after ${FAST_RETRY_MAX_MS / 1000}s — giving up`);
  } finally {
    awaitingTranscript.delete(clipId);
  }
}

// ─── Main Poll Loop ───────────────────────────────────────────────────────────
async function pollOnce() {
  try {
    const { clips, cursor } = await pollForNewClips();

    if (clips.length === 0) return;

    // Filter to only unseen, non-watched clips
    const newClips = clips.filter(c => {
      const id = c.id || c.ulid;
      return id && !seenClipIds.has(id) && !awaitingTranscript.has(id);
    });

    if (newClips.length === 0) return;

    log('POLL', `Got ${clips.length} clips, ${newClips.length} new (cursor: ${cursor || 'none'})`);

    for (const clip of newClips) {
      const clipId = clip.id || clip.ulid;
      const username = clip.participants?.[0]?.username || clip.creator?.username || 'unknown';
      log('CLIP', `New clip ${clipId} by ${username}`);

      try {
        const detail = await fetchClipDetail(clipId);
        const done = await processClipDetail(detail, clipId);
        if (!done) {
          // Transcript not ready — hand off to fast watcher, don't mark seen
          watchClipForTranscript(clipId, { username }).catch(err =>
            log('WATCH', `Watcher for ${clipId} crashed: ${err.message}`)
          );
        }
      } catch (err) {
        log('ERROR', `Failed to process clip ${clipId}: ${err.message}`);
      }
    }
  } catch (err) {
    log('ERROR', `Poll failed: ${err.message}`);
  }
}

// ─── Start ────────────────────────────────────────────────────────────────────
async function main() {
  log('INIT', '=== GENIE SERVER STARTING ===');
  log('INIT', `Keyword: "${KEYWORD}"`);
  log('INIT', `Poll interval: ${POLL_INTERVAL}ms`);
  log('INIT', `Watched users: ${process.env.GENIE_WATCHED_USERS || '(all)'}`);

  await sendMessage(`\u{1F9DE} Genie server started. Watching for "${KEYWORD}" in ALL JellyJelly clips every ${POLL_INTERVAL / 1000}s. Say "Genie" in a video and watch what happens.`);

  // Set initial cursor to 10 minutes ago so we don't process the entire archive
  const { setCursor } = await import('./firehose.mjs');
  const tenMinAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
  setCursor(tenMinAgo);
  log('INIT', `Initial cursor set to ${tenMinAgo} (last 10 min only)`);

  // Initial poll
  await pollOnce();

  // Continuous polling
  setInterval(pollOnce, POLL_INTERVAL);

  log('INIT', `Polling every ${POLL_INTERVAL / 1000}s. Ctrl+C to stop.`);
}

main().catch(err => {
  log('FATAL', err.message);
  console.error(err);
  process.exit(1);
});
