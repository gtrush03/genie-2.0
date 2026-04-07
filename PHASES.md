# GENIE — Phased Build Plan

Target: **Full pipeline working by 3 PM.** 2-hour build window (1 PM - 3 PM). Each phase has a pre-written prompt, exact files, and a test checkpoint.

The wow factor is NOT a deployed site. It's watching Chrome move by itself — navigating LinkedIn, sending connection requests, opening Gmail, composing emails, posting tweets. All visible on screen. The site deploy is step 1. The browser cascade is the show.

---

## Phase 0: Record Test Video (5 min) — DO THIS FIRST

**Action:** Open JellyJelly app. Record a short video (~15 seconds) saying:

> "Hey Genie, I want you to build me a landing page for an AI meetup event I'm hosting in NYC. Call it 'AI Builders NYC' — make it look clean, dark theme, and include the date April 12th, a location section, and a signup button."

Post it publicly. Note the clip ID from the URL.

**Why first:** The server needs a real clip with the keyword "Genie" in the transcript. No clip = nothing to test against. Do this NOW, it takes 2 minutes, and by the time Phase 1 is done, JellyJelly will have processed the transcript.

---

## Phase 1: Firehose + Keyword Detection (20 min)

**Files to implement:**
- `src/core/firehose.mjs` — poll JellyJelly, track cursor, return new clips
- `src/core/server.mjs` — continuous loop, calls firehose, detects keyword
- `test/test-jelly-api.mjs` — verify API works
- `test/test-keyword.mjs` — verify keyword detection

**What it does:**
1. Polls `GET /v3/jelly/search?ascending=false&page_size=50&start_date={cursor}` every 15s
2. For each new clip, fetches `GET /v3/jelly/{id}` for full transcript
3. Scans `transcript_overlay.results.channels[0].alternatives[0].words` for "genie"
4. If found → logs the clip + reconstructed transcript text
5. If not → skips silently

**Test checkpoint:**
```bash
# Should return a list of recent clips
npm run test:api

# Should detect "genie" in a known transcript
npm run test:keyword

# Should poll and log new clips
npm start
# (let it run for 30 seconds, verify it detects your test video)
```

**Depends on:** Phase 0 (test video recorded)

---

## Phase 2: Interpreter + Site Build + Deploy (25 min)

**Files to implement:**
- `src/core/interpreter.mjs` — transcript → structured proposal JSON
- `config/prompts.mjs` — interpreter system prompt + strategy prompt
- `src/scripts/build-site.mjs` — template interpolation → index.html
- `src/templates/landing.html` — full Tailwind template (dark, glass, responsive)
- `src/scripts/deploy-vercel.mjs` — shell out to vercel CLI
- `src/core/trigger.mjs` — manual trigger for a specific clip ID
- `test/test-interpreter.mjs` — verify proposal JSON from sample transcript
- `test/test-vercel-deploy.mjs` — deploy test HTML, verify URL

**What it does:**
1. Takes reconstructed transcript + creator username
2. Sends to OpenRouter (Claude Sonnet) with interpreter prompt
3. Returns structured proposal: `{ title, summary, wishes[], strategy, ignored[] }`
4. For BUILD wishes: interpolates Tailwind template with proposal data
5. Writes HTML to `/tmp/genie/{slug}/index.html`
6. Runs `vercel deploy --yes --prod` → captures live URL
7. Returns `{ url, dir, deployTime }`

**The Tailwind template must be BEAUTIFUL:** dark bg (#0a0a0a), glass panels, gradient accents, responsive, hero section, features grid, CTA button, footer with "Built by Genie" credit.

**Test checkpoint:**
```bash
# Interpret a sample transcript
npm run test:interpret

# Deploy a test site
npm run test:deploy

# Manual trigger: process your recorded clip
node src/core/trigger.mjs <your-clip-id>
# Should: interpret → build → deploy → print live URL
```

**Depends on:** Phase 1 (firehose working)

---

## Phase 3: Browser Automation — THE WOW (30 min)

This is CORE. Not a stretch goal. Not Tier 2. The browser moving by itself IS the demo.

**Files to implement:**
- `src/browser/setup-profile.mjs` — one-time persistent Chrome profile setup + login
- `src/browser/automation.mjs` — LinkedIn, Gmail, Twitter actions (headed Playwright)
- `test/test-browser.mjs` — headed Chrome test

**Pre-flight: `setup:browser` step (DO THIS BEFORE AUTOMATION):**
```bash
npm run setup:browser
```
This launches a persistent Chrome profile and holds it open so you can:
1. Log into LinkedIn (linkedin.com)
2. Log into Gmail (mail.google.com)
3. Log into Twitter/X (x.com)
4. Close the browser — cookies are saved to `~/.genie-chrome-profile/`

All subsequent automation reuses this profile. No login flows in the demo. No 2FA popups.

**What it does:**
1. Launches headed Playwright with persistent Chrome profile (`~/.genie-chrome-profile/`)
2. `slowMo: 150` so the audience can follow every click and keystroke
3. **LinkedIn:** Navigate to a profile URL → click "Connect" → add note → send
4. **Gmail:** Open compose → fill To/Subject/Body → send
5. **Twitter/X:** Navigate to compose → type tweet → post
6. Each action has explicit waits, human-readable logging, and error recovery

**Implementation details:**
- Use `chromium.launchPersistentContext()` with `headless: false`
- `slowMo: 150` for demo visibility
- Each action is an exported async function: `linkedinConnect(page, { profileUrl, note })`, `gmailSend(page, { to, subject, body })`, `tweetPost(page, { text })`
- Log every step: "Opening LinkedIn...", "Clicking Connect...", "Typing note..."
- Screenshots after each major action for Telegram reporting

**Test checkpoint:**
```bash
# First: set up browser profile with saved logins
npm run setup:browser
# → Log into LinkedIn, Gmail, Twitter manually. Close when done.

# Test LinkedIn connection request
npm run test:browser -- --action linkedin
# → Chrome opens, navigates to a test profile, sends connection request

# Test Gmail compose + send
npm run test:browser -- --action gmail
# → Chrome opens Gmail, composes test email, sends it

# Test Twitter post
npm run test:browser -- --action twitter
# → Chrome opens Twitter, types test tweet, posts it
```

**Depends on:** Phase 2 (interpreter working — browser actions need proposal data)

---

## Phase 4: Telegram + Full Orchestration (25 min)

**Files to implement:**
- `src/core/telegram.mjs` — send messages, photos, reports (one-way)
- `src/scripts/take-screenshot.mjs` — Playwright screenshot of deployed URL
- `src/core/executor.mjs` — orchestrator: proposal → site deploy → browser cascade → telegram report
- `src/scripts/enrich-person.mjs` — Apollo.io person enrichment for discovered creators
- Wire `server.mjs` to full loop: detect → interpret → execute → report
- `test/test-telegram.mjs` — send test message

**What it does:**
1. Executor wires the full chain: interpret → build site → deploy → browser cascade → telegram
2. Browser cascade: after site deploys, Chrome opens → LinkedIn connect → Gmail send → Twitter post
3. JellyJelly power user discovery: search API, sort by views, find top creators
4. Apollo enrichment: look up discovered creators for email/company/title
5. After each step, sends progress update to Telegram
6. Final report includes: proposal summary, live URL, screenshots (site + browser actions), timing stats

**Telegram message format:**
```
GENIE REPORT
━━━━━━━━━━━━━━━
Heard you in: "AI Builders NYC Meetup"

✓ Built: https://ai-builders-nyc.vercel.app (12s)
✓ LinkedIn: Connection request sent to @john_doe
✓ Gmail: Email sent to john@example.com
✓ Twitter: Posted tweet with site link
✓ Screenshots attached

Strategy: Share this on LinkedIn tonight.
The event market in NYC is hot right now.

— Genie (92s total)
```

**Test checkpoint:**
```bash
# Send test message to Telegram
npm run test:telegram

# Full loop: start server, it detects your clip, builds, deploys, browser cascade, sends report
npm start
# Telegram notification should arrive within 2 minutes
```

**Depends on:** Phase 3 (browser automation working)

---

## Phase 5: Polish + Demo Prep (20 min)

**Action items:**
1. End-to-end test 3x — full chain from clip detection to Telegram report
2. Tune browser timing — adjust `slowMo`, explicit waits, page load timeouts
3. Audience participation setup — verify someone ELSE can record a clip and trigger Genie
4. Record backup video of the full chain working (screen recording with browser visible)
5. Pre-stage browser tabs: LinkedIn, Gmail, Twitter all logged in before demo starts

**Checklist:**
- [ ] Full chain works end-to-end 3 times in a row
- [ ] Browser actions visible and followable at demo pace
- [ ] Telegram reports arrive with screenshots
- [ ] Second person tested it (not just you)
- [ ] Backup video recorded

---

## Phase 6: Capabilities Expansion (after demo works)

- Per-user memory (preferences, past builds)
- NYC live feeds integration
- Dashboard (live activity feed, browser view, results)
- More browser actions: Notion pages, Google Docs, GitHub repo creation
- Cold email via Resend API
- Promo copy generation
- GitHub push via Git Data API

**Files (when ready):**
- `src/core/memory.mjs` — per-user JSON memory
- `src/scripts/send-email.mjs` — Resend API
- `src/scripts/generate-promo.mjs` — LLM promo copy
- `src/scripts/deploy-github.mjs` — Git Data API push
- `dashboard/server.mjs` — local Express + SSE server
- `dashboard/index.html` — live activity dashboard

---

## Prompt Execution Strategy

Each phase gets a **pre-written prompt** that an Opus agent can execute independently. The prompts include:
- Exact file paths to create/modify
- Full code to write (not pseudocode)
- Test commands to verify
- Clear "DONE when:" criteria

**Execution flow:**
```
Phase 0: YOU record video on JellyJelly (5 min)
Phase 1: Agent 1 builds firehose + keyword detection (20 min)
Phase 2: Agent 2 builds interpreter + site builder + deploy (25 min)
Phase 3: Agent 3 builds browser automation — THE WOW (30 min)
Phase 4: Agent 4 builds Telegram + executor + full orchestration (25 min)
Phase 5: YOU polish, test 3x, record backup video (20 min)
```

Phases 1-4 are sequential (each depends on the previous). Phase 5 is manual verification. Phase 6 is post-demo expansion.

---

## Timeline (2 hours: 1 PM - 3 PM)

```
1:00 PM  — Phase 0: Record JellyJelly test video
1:05 PM  — Phase 1: Firehose + keyword detection
1:25 PM  — Phase 2: Interpreter + build + deploy
1:50 PM  — Phase 3: Browser automation (setup:browser + LinkedIn/Gmail/Twitter)
2:20 PM  — Phase 4: Telegram + full orchestration wiring
2:45 PM  — Phase 5: Polish, end-to-end test 3x, record backup video
3:00 PM  — DEMO READY
```

---

## Fallback Tiers

If time runs short, here's what constitutes a working demo at each tier:

**Tier 1 — Minimum Viable Demo (Phases 0-3):**
- Firehose detects keyword in JellyJelly clips
- Interpreter extracts structured proposal
- Site builds and deploys to Vercel
- At minimum ONE browser action works (LinkedIn connect OR Gmail send)
- This alone is a show-stopper demo

**Tier 2 — Full Pipeline (Phases 0-4):**
- Everything in Tier 1
- Full browser cascade: LinkedIn + Gmail + Twitter
- Telegram reporting with screenshots
- End-to-end orchestration (clip → everything happens automatically)

**Tier 3 — Polished (Phases 0-5):**
- Everything in Tier 2
- Tested 3x end-to-end
- Audience participation verified
- Backup video recorded
- Browser timing tuned for demo pace

---

## Repo Structure

```
genie/
├── README.md                  # Project overview
├── GENIE-SPEC.md              # Complete build specification (v2)
├── PHASES.md                  # This file
├── package.json               # Node.js project config (ESM)
├── .env                       # API keys (gitignored)
├── .env.example               # Template for env vars
├── .gitignore
│
├── src/
│   ├── core/                  # Core pipeline
│   │   ├── server.mjs         # Main continuous server (Phase 1)
│   │   ├── trigger.mjs        # Manual clip trigger (Phase 2)
│   │   ├── firehose.mjs       # JellyJelly polling + keyword detection (Phase 1)
│   │   ├── interpreter.mjs    # Transcript → proposal JSON (Phase 2)
│   │   ├── executor.mjs       # Proposal → execute wishes → browser → report (Phase 4)
│   │   └── telegram.mjs       # One-way Telegram reporting (Phase 4)
│   │
│   ├── scripts/               # Individual action scripts
│   │   ├── build-site.mjs     # Template → HTML generation (Phase 2)
│   │   ├── deploy-vercel.mjs  # Vercel CLI deploy (Phase 2)
│   │   ├── take-screenshot.mjs # Playwright screenshot (Phase 4)
│   │   └── enrich-person.mjs  # Apollo.io lookup (Phase 4)
│   │
│   ├── browser/               # Headed Chrome automation — CORE (Phase 3)
│   │   ├── setup-profile.mjs  # One-time login setup (run setup:browser first!)
│   │   └── automation.mjs     # LinkedIn, Gmail, Twitter actions
│   │
│   └── templates/             # HTML templates
│       └── landing.html       # Tailwind landing page template (Phase 2)
│
├── config/
│   └── prompts.mjs            # Centralized LLM prompts
│
├── test/                      # Test scripts
│   ├── test-jelly-api.mjs     # Phase 1
│   ├── test-keyword.mjs       # Phase 1
│   ├── test-interpreter.mjs   # Phase 2
│   ├── test-vercel-deploy.mjs # Phase 2
│   ├── test-browser.mjs       # Phase 3 (--action linkedin|gmail|twitter)
│   ├── test-telegram.mjs      # Phase 4
│   └── run-all.mjs            # Run all tests
│
└── dashboard/                 # Phase 6 — post-demo expansion
    └── server.mjs
```

---

## Capabilities Demo Plan

For the demo, show variety. The browser moving by itself is the wow factor. Not just "build a site."

**Demo 1 (main — the full chain):** "Genie, build me a landing page for AI Builders NYC"
→ Site deploys to Vercel → Chrome opens LinkedIn, sends connection request → Chrome opens Gmail, sends email → Chrome opens Twitter, posts tweet → Telegram report arrives with screenshots

**Demo 2 (outreach):** "Genie, reach out to that CTO from the panel"
→ Chrome opens, navigates LinkedIn, sends connection request with personalized note

**Demo 3 (social):** "Genie, post about this on Twitter"
→ Chrome opens Twitter, types tweet about the deployed site, posts it

**Demo 4 (proactive):** "Genie, I had this idea about a creator economy platform"
→ Genie interprets the idea, builds a site for it, suggests strategy, fires off outreach

**For other people testing:** They record a JellyJelly clip saying "Genie, [wish]" and watch Chrome move by itself. The variety proves it's not hardcoded — different wishes trigger different browser cascades. Someone asks for a site, they see it deploy AND get tweeted. Someone asks for outreach, they see LinkedIn open and a connection request fly.
