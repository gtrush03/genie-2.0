#!/usr/bin/env node
// JellyJelly Firehose Scanner
// Polls /v3/jelly/search, tracks cursor, detects keyword in transcripts
// Exports: pollForNewClips(), fetchClipDetail(), containsKeyword()

const API_BASE = process.env.JELLY_API_URL || 'https://api.jellyjelly.com/v3';

// In-memory cursor — stores the ISO timestamp of the most recent clip seen
let cursor = null;

/**
 * Poll JellyJelly search API for new clips.
 * @param {object} options
 * @param {string} [options.username] - Filter by username (comma-separated list also accepted)
 * @param {number} [options.pageSize=50]
 * @param {string} [options.startDate] - Override cursor with explicit start date
 * @returns {Promise<{clips: object[], cursor: string|null}>}
 */
export async function pollForNewClips(options = {}) {
  const pageSize = options.pageSize || 50;
  const startDate = options.startDate || cursor || null;

  // Build query params
  const params = new URLSearchParams({
    ascending: 'false',
    page_size: String(pageSize),
  });

  if (startDate) {
    params.set('start_date', startDate);
  }

  // Username filter from options or env
  const usernameFilter = options.username
    || process.env.GENIE_WATCHED_USERS
    || null;

  if (usernameFilter) {
    // The API may accept a single username; if we have multiple, we poll for each
    // For simplicity, use the first one (API likely takes one at a time)
    const usernames = usernameFilter.split(',').map(u => u.trim()).filter(Boolean);
    if (usernames.length > 0) {
      params.set('username', usernames[0]);
    }
  }

  const url = `${API_BASE}/jelly/search?${params.toString()}`;

  const res = await fetch(url);
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`JellyJelly search failed: ${res.status} ${res.statusText} — ${body}`);
  }

  const data = await res.json();

  // API returns { status, jellies: [...], total, page, ... }
  let clips;
  if (Array.isArray(data)) {
    clips = data;
  } else if (data.jellies && Array.isArray(data.jellies)) {
    clips = data.jellies;
  } else if (data.results && Array.isArray(data.results)) {
    clips = data.results;
  } else if (data.items && Array.isArray(data.items)) {
    clips = data.items;
  } else {
    clips = data.id ? [data] : [];
  }

  // Update cursor to the most recent clip's created_at
  if (clips.length > 0) {
    // Clips are descending, so first clip is newest
    const newest = clips[0];
    const ts = newest.posted_at || newest.created_at || newest.createdAt || newest.timestamp;
    if (ts) {
      cursor = ts;
    }
  }

  return { clips, cursor };
}

/**
 * Fetch full detail for a single clip.
 * @param {string} clipId - The clip ULID/ID
 * @returns {Promise<object>} Full clip data with reconstructed transcript
 */
export async function fetchClipDetail(clipId) {
  const url = `${API_BASE}/jelly/${clipId}`;

  const res = await fetch(url);
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`JellyJelly detail failed for ${clipId}: ${res.status} ${res.statusText} — ${body}`);
  }

  const data = await res.json();

  // API returns { status, jelly: {...} } — unwrap it
  const clip = data.jelly || data;

  // Reconstruct transcript from transcript_overlay if present
  clip._transcript = reconstructTranscript(clip.transcript_overlay);

  return clip;
}

/**
 * Reconstruct a plain-text transcript from transcript_overlay data.
 * @param {object} transcriptOverlay
 * @returns {string} Reconstructed transcript text
 */
export function reconstructTranscript(transcriptOverlay) {
  if (!transcriptOverlay) return '';

  try {
    const results = transcriptOverlay.results;
    if (!results || !results.channels || !results.channels[0]) return '';

    const channel = results.channels[0];
    if (!channel.alternatives || !channel.alternatives[0]) return '';

    const words = channel.alternatives[0].words;
    if (!Array.isArray(words) || words.length === 0) return '';

    return words.map(w => w.punctuated_word || w.word || '').join(' ');
  } catch (e) {
    return '';
  }
}

/**
 * Check if a keyword appears in the transcript word-level data.
 * Scans both `word` and `punctuated_word` fields, case-insensitive.
 * @param {object} transcriptOverlay - The transcript_overlay object from clip data
 * @param {string} keyword - Keyword to search for (case-insensitive)
 * @returns {boolean}
 */
// Fuzzy variants Deepgram commonly produces for "genie"
const GENIE_VARIANTS = new Set([
  'genie', 'jeanie', 'jeannie', 'jeany', 'jenie', 'jennie', 'jenny',
  'geeney', 'geenie', 'geany', 'geaney', 'jeaney', 'genee', 'gennie',
  'ginny', 'gini', 'jini', 'djinni', 'djinn', 'jinni', 'jinn',
]);

export function containsKeyword(transcriptOverlay, keyword) {
  if (!transcriptOverlay || !keyword) return false;

  const target = keyword.toLowerCase();
  // Build match set: exact keyword + fuzzy variants if keyword is "genie"
  const matchSet = target === 'genie' ? GENIE_VARIANTS : new Set([target]);

  try {
    const results = transcriptOverlay.results;
    if (!results || !results.channels) return false;

    for (const channel of results.channels) {
      if (!channel.alternatives) continue;
      for (const alt of channel.alternatives) {
        if (!alt.words) continue;
        for (const w of alt.words) {
          // Check the raw word field
          if (w.word && matchSet.has(w.word.toLowerCase())) return true;
          // Check punctuated_word — strip trailing punctuation for comparison
          if (w.punctuated_word) {
            const cleaned = w.punctuated_word.replace(/[.,!?;:'"]+$/g, '').toLowerCase();
            if (matchSet.has(cleaned)) return true;
          }
        }
      }
    }
  } catch (e) {
    return false;
  }

  return false;
}

/**
 * Get/set the current cursor value.
 */
export function getCursor() {
  return cursor;
}

export function setCursor(val) {
  cursor = val;
}
