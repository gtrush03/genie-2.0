# JellyJelly Comment System — Product + Architecture Spec

## Overview

After Genie completes a wish, it posts a public comment on the triggering JellyJelly clip with the results. This closes the loop on the platform where the wish was made, turning each fulfilled wish into visible social proof.

---

## 1. When to Comment

Comment after every dispatched wish, regardless of outcome:

| Outcome | Comment? | Content |
|---------|----------|---------|
| Full success | Yes | Result + live URL(s) |
| Partial success | Yes | What worked, what didn't |
| Failure | Yes | Acknowledgment + redirect to Telegram |
| Keyword detected but no actionable wish | No | Silent — don't spam |

Timing: the comment posts **after** `dispatchToClaude()` resolves, in the same `.then()` block that currently sends the Telegram receipt. The comment is a fire-and-forget side effect — it must never block or delay the Telegram report.

---

## 2. Comment Templates

All comments start with `🧞` for brand recognition. Max 4 lines. No internal metrics (cost, turns, duration). Plain text only — assume JellyJelly comments don't support markdown or images.

**BUILD — site deployed:**
```
🧞 Wish granted! Built and deployed:
https://genie-wobbles.vercel.app
```

If a Stripe checkout was created, add it on line 3:
```
🧞 Wish granted! Built and deployed:
https://genie-wobbles.vercel.app
Checkout: https://buy.stripe.com/test_abc123
```

**X POST — tweet published:**
```
🧞 Posted on X!
https://x.com/GTrushevskiy/status/1964091410115682332
```

**UBER EATS — order placed:**
```
🧞 Order placed on Uber Eats!
ETA: 25-35 min
```
No store name or total (those are in the Telegram receipt).

**RESEARCH — report delivered:**
```
🧞 Research complete — full report sent to Telegram.
```

**GENERIC SUCCESS — no URL produced:**
```
🧞 Done! Check Telegram for the full receipt.
```

**FAILURE:**
```
🧞 Heard your wish but couldn't complete it — check Telegram for details.
```

---

## 3. New Module: `src/core/jelly-comment.mjs`

### Env Vars

```
JELLY_AUTH_TOKEN=eyJhbGciOiJ...    # JWT from a logged-in JellyJelly account
JELLY_API_URL=https://api.jellyjelly.com/v3   # already exists
```

### API-Based Path (Primary)

```js
// src/core/jelly-comment.mjs

const API_BASE = process.env.JELLY_API_URL || 'https://api.jellyjelly.com/v3';
const AUTH_TOKEN = () => process.env.JELLY_AUTH_TOKEN;

// In-memory dedup: clipId -> true
const commented = new Map();
let commentCountThisHour = 0;
let hourWindowStart = Date.now();

const MAX_COMMENTS_PER_HOUR = 10;
const HOUR_MS = 60 * 60 * 1000;

function resetHourlyCounterIfNeeded() {
  if (Date.now() - hourWindowStart > HOUR_MS) {
    commentCountThisHour = 0;
    hourWindowStart = Date.now();
  }
}

/**
 * Post a comment on a JellyJelly clip.
 * Deduplicates by clipId. Rate-limited to 10/hour.
 * Fails silently — commenting is best-effort, never blocks wish execution.
 *
 * @param {string} clipId
 * @param {string} text - Plain text comment (max ~280 chars recommended)
 * @returns {Promise<{ok: boolean, error?: string}>}
 */
export async function commentOnClip(clipId, text) {
  const token = AUTH_TOKEN();
  if (!token) {
    log('No JELLY_AUTH_TOKEN set — skipping comment');
    return { ok: false, error: 'no auth token' };
  }

  // Dedup: one comment per clip
  if (commented.has(clipId)) {
    log(`Already commented on clip ${clipId} — skipping`);
    return { ok: false, error: 'already commented' };
  }

  // Rate limit
  resetHourlyCounterIfNeeded();
  if (commentCountThisHour >= MAX_COMMENTS_PER_HOUR) {
    log(`Rate limit hit (${MAX_COMMENTS_PER_HOUR}/hour) — skipping comment`);
    return { ok: false, error: 'rate limited' };
  }

  // Attempt API comment
  try {
    const result = await postCommentViaAPI(clipId, text);
    if (result.ok) {
      commented.set(clipId, true);
      commentCountThisHour++;
    }
    return result;
  } catch (err) {
    log(`Comment failed: ${err.message}`);
    return { ok: false, error: err.message };
  }
}
```

The actual HTTP call is a separate function so we can swap implementations:

```js
async function postCommentViaAPI(clipId, text) {
  // Endpoint TBD — API discovery agent will confirm the exact path.
  // Most likely: POST /v3/jelly/{clipId}/comments
  // Alt candidates: POST /v3/jelly/{clipId}/comment
  //                 POST /v3/comments with { jelly_id: clipId }
  const url = `${API_BASE}/jelly/${clipId}/comments`;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${AUTH_TOKEN()}`,
    },
    body: JSON.stringify({ text }),
  });

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    throw new Error(`JellyJelly comment API ${res.status}: ${body}`);
  }

  log(`Commented on clip ${clipId} (${text.length} chars)`);
  return { ok: true };
}
```

### Browser-Based Path (Fallback)

If JellyJelly has no public comment API (or the endpoint requires a session cookie instead of a JWT), fall back to Playwright via the existing CDP Chrome instance:

```js
async function postCommentViaBrowser(clipId, text) {
  // This runs OUTSIDE the Claude Code subprocess.
  // It uses the same CDP Chrome that the dispatcher's MCP uses,
  // but via direct CDP protocol (not Playwright MCP).
  const clipUrl = `https://jellyjelly.com/jelly/${clipId}`;

  // Steps:
  // 1. Open a new tab to the clip URL
  // 2. Wait for the comment input to appear
  // 3. Type the comment text
  // 4. Click submit
  // 5. Close the tab

  // Implementation uses chrome-connect.mjs (already exists in the repo)
  // to get a CDP session, then executes the browser automation.
  //
  // This is heavier than the API path and should only be used
  // if the API path is confirmed unavailable.
}
```

The browser path is designed but not implemented until we confirm the API path doesn't work. The API discovery agent will determine which path to use.

---

## 4. Integration into Dispatch Flow

The comment happens in `server.mjs`, NOT in `dispatcher.mjs`. The dispatcher returns a result object; the server interprets it and comments.

### Current flow (server.mjs `runDispatch`):

```
dispatchToClaude() → .then(result => log) → .finally(drainQueue)
```

### New flow:

```
dispatchToClaude() → .then(result => { log; commentOnClip(clipId, buildComment(result)) }) → .finally(drainQueue)
```

Specifically, modify `runDispatch()` in `server.mjs`:

```js
import { commentOnClip } from './jelly-comment.mjs';

function runDispatch(clip) {
  activeDispatches++;
  const clipId = clip.id || clip.ulid || 'unknown';
  // ... existing code ...

  dispatchToClaude({ transcript, clipTitle, creator, clipId, keyword: KEYWORD })
    .then(async (result) => {
      log('EXEC', `Clip ${clipId} done: success=${result.success} ...`);

      // Post comment on the original clip
      const commentText = buildCommentText(result);
      await commentOnClip(clipId, commentText).catch(err =>
        log('COMMENT', `Failed to comment on ${clipId}: ${err.message}`)
      );
    })
    // ... rest unchanged
}
```

### `buildCommentText(result)` — comment construction

This function lives in `jelly-comment.mjs` and parses the dispatcher result to pick the right template:

```js
export function buildCommentText(result) {
  if (!result.success) {
    return `🧞 Heard your wish but couldn't complete it — check Telegram for details.`;
  }

  const text = result.result || '';

  // Extract URLs from the result text
  const urls = text.match(/https?:\/\/[^\s)]+/g) || [];
  const vercelUrl = urls.find(u => u.includes('vercel.app'));
  const stripeUrl = urls.find(u => u.includes('stripe.com') || u.includes('buy.stripe'));
  const twitterUrl = urls.find(u => u.includes('x.com/') || u.includes('twitter.com/'));

  if (twitterUrl) {
    return `🧞 Posted on X!\n${twitterUrl}`;
  }

  if (vercelUrl) {
    let comment = `🧞 Wish granted! Built and deployed:\n${vercelUrl}`;
    if (stripeUrl) comment += `\nCheckout: ${stripeUrl}`;
    return comment;
  }

  // Check for Uber Eats patterns
  if (/uber\s*eats|order\s*placed|delivery/i.test(text)) {
    const etaMatch = text.match(/(\d+[-–]\d+\s*min)/);
    let comment = `🧞 Order placed on Uber Eats!`;
    if (etaMatch) comment += `\nETA: ${etaMatch[1]}`;
    return comment;
  }

  // Check for research patterns
  if (/research|report|analysis|findings/i.test(text)) {
    return `🧞 Research complete — full report sent to Telegram.`;
  }

  // Generic success with URL
  if (urls.length > 0) {
    return `🧞 Done!\n${urls[0]}`;
  }

  // Generic success, no URL
  return `🧞 Done! Check Telegram for the full receipt.`;
}
```

---

## 5. Rate Limiting and Dedup

| Guard | Mechanism | Location |
|-------|-----------|----------|
| 1 comment per clip | `commented` Map keyed by clipId | jelly-comment.mjs |
| 10 comments per hour | Rolling counter with hourly reset | jelly-comment.mjs |
| Only keyword-triggered clips | Already enforced — `commentOnClip` is only called from the dispatch `.then()` which only fires for keyword-matched clips | server.mjs |

The `commented` Map is in-memory. On server restart it resets, but since `seenClipIds` also resets and the cursor is set to 10 minutes ago, the overlap window is small and acceptable.

---

## 6. Opt-Out: Silent Wishes

If the transcript contains "don't comment", "no comment", or "quietly", Genie skips the comment but still executes the wish and reports via Telegram.

Implementation: add a check in `buildCommentText()` or in the caller, passing the transcript through:

```js
const SILENT_PATTERNS = /\b(don'?t comment|no comment|quietly|private|silent)\b/i;

// In runDispatch, before calling commentOnClip:
if (!SILENT_PATTERNS.test(transcript)) {
  await commentOnClip(clipId, commentText);
}
```

---

## 7. Genie Account Identity

The `JELLY_AUTH_TOKEN` JWT corresponds to a JellyJelly account. Set up this account manually:

| Field | Value |
|-------|-------|
| Username | `genie` (or `genie-bot` if taken) |
| Display name | `Genie` |
| Profile picture | Genie lamp icon (gold on dark background, matching the 🧞 brand) |
| Bio | `You wished for it. I make it real.` |

The token is obtained by logging into this account in the CDP Chrome instance and extracting the JWT from localStorage or a network request. Store it in `.env` as `JELLY_AUTH_TOKEN`.

---

## 8. Privacy Considerations

**What becomes public:**
- That Genie was invoked on this clip
- URLs to things Genie built (Vercel deploys, tweets, etc.)
- The fact that a wish succeeded or failed

**What stays private (Telegram only):**
- Cost, duration, turn count
- Full error details on failure
- Research report contents
- Order totals and store details

**Opt-out:** The "silent wish" pattern (Section 6) lets users say "genie, do X quietly" to suppress the public comment while still getting the Telegram receipt.

---

## 9. File Changes Summary

| File | Change |
|------|--------|
| `src/core/jelly-comment.mjs` | **New.** `commentOnClip()`, `buildCommentText()`, rate limiting, dedup |
| `src/core/server.mjs` | Import `jelly-comment.mjs`. Add `commentOnClip()` call in `runDispatch()` `.then()` block |
| `.env.example` | Add `JELLY_AUTH_TOKEN=` |
| `dispatcher.mjs` | **No changes.** The dispatcher stays focused on Claude Code orchestration |

---

## 10. Open Questions for API Discovery Agent

1. What is the exact comment endpoint? (`POST /v3/jelly/{id}/comments`? Something else?)
2. What auth header does it expect? (`Authorization: Bearer <jwt>`? Cookie-based?)
3. What is the request body schema? (`{ text: "..." }`? `{ content: "..." }`? `{ body: "..." }`)
4. Can comments include images/attachments, or text only?
5. Is there a character limit on comments?
6. Does the API return the created comment object (with a comment ID we could store)?

Once the API agent confirms these, update `postCommentViaAPI()` with the real endpoint and payload shape. If no API exists, implement the browser fallback.
