// Genie — JellyJelly clip commenting
// Tries API first (multiple payload shapes), falls back to logging on failure.
// Resilient: never throws, never crashes the server.

const JELLY_API_BASE = process.env.JELLY_API_URL || 'https://api.jellyjelly.com/v3';

// ─── Deduplication ───────────────────────────────────────────────────────────
const commentedClipIds = new Set();

// ─── Rate limiting: max 10 comments per rolling hour ─────────────────────────
const commentTimestamps = [];
const MAX_COMMENTS_PER_HOUR = 10;

function isRateLimited() {
  const oneHourAgo = Date.now() - 60 * 60 * 1000;
  // Prune old entries
  while (commentTimestamps.length > 0 && commentTimestamps[0] < oneHourAgo) {
    commentTimestamps.shift();
  }
  return commentTimestamps.length >= MAX_COMMENTS_PER_HOUR;
}

function recordComment() {
  commentTimestamps.push(Date.now());
}

function log(tag, msg) {
  const ts = new Date().toISOString();
  console.log(`[${ts}] [GENIE] [COMMENT:${tag}] ${msg}`);
}

// ─── API path ────────────────────────────────────────────────────────────────
async function tryApiComment(clipId, text) {
  const token = process.env.JELLY_AUTH_TOKEN;
  if (!token) {
    log('API', 'No JELLY_AUTH_TOKEN in env — skipping API path');
    return false;
  }

  // Try multiple endpoint + payload combinations
  const attempts = [
    // Confirmed working: singular "comment" with "content" field
    { url: `${JELLY_API_BASE}/jelly/${clipId}/comment`, body: { content: text } },
    // Fallbacks in case API changes
    { url: `${JELLY_API_BASE}/jelly/${clipId}/comments`, body: { content: text } },
    { url: `${JELLY_API_BASE}/jelly/${clipId}/comment`, body: { text } },
    { url: `${JELLY_API_BASE}/comments`, body: { jelly_id: clipId, content: text } },
  ];

  for (const { url, body } of attempts) {
    try {
      log('API', `POST ${url} — payload keys: [${Object.keys(body).join(',')}]`);
      const resp = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(body),
      });

      if (resp.ok) {
        log('API', `Success! ${resp.status} from ${url}`);
        return true;
      }

      const statusText = await resp.text().catch(() => '');
      log('API', `${resp.status} from ${url}: ${statusText.slice(0, 200)}`);
    } catch (err) {
      log('API', `Network error on ${url}: ${err.message}`);
    }
  }

  return false;
}

// ─── Main export ─────────────────────────────────────────────────────────────
/**
 * Comment on a JellyJelly clip with wish results.
 * Tries API first, falls back to logging if API fails.
 * @param {string} clipId
 * @param {string} text - The comment text
 * @returns {Promise<{success: boolean, method: 'api'|'browser'|'skipped'|'rate_limited'|'failed', error?: string}>}
 */
export async function commentOnClip(clipId, text) {
  try {
    // Dedup check
    if (commentedClipIds.has(clipId)) {
      log('DEDUP', `Already commented on ${clipId} — skipping`);
      return { success: true, method: 'skipped' };
    }

    // Rate limit check
    if (isRateLimited()) {
      log('RATE', `Rate limited (${MAX_COMMENTS_PER_HOUR}/hr) — skipping ${clipId}`);
      return { success: false, method: 'rate_limited', error: 'Hourly comment limit reached' };
    }

    // Try API path
    const apiSuccess = await tryApiComment(clipId, text);
    if (apiSuccess) {
      commentedClipIds.add(clipId);
      recordComment();
      return { success: true, method: 'api' };
    }

    // Browser fallback — not implemented yet, would need Playwright MCP via spawned claude -p
    log('BROWSER', `API failed for ${clipId} — browser fallback not yet implemented`);
    log('BROWSER', `Would navigate to https://jellyjelly.com/jelly/${clipId} and type comment`);

    return { success: false, method: 'failed', error: 'API endpoints returned non-2xx; browser fallback not implemented' };
  } catch (err) {
    log('ERROR', `Unexpected error commenting on ${clipId}: ${err.message}`);
    return { success: false, method: 'failed', error: err.message };
  }
}
