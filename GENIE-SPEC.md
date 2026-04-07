# GENIE — Complete Build Spec (v2)

> **"You wished for it."**

Agentic social media agent for MischiefClaw hackathon at Betaworks NYC. Built on OpenClaw + JellyJelly Firehose.

---

## Table of Contents

1. [Vision](#1-vision)
2. [The Genie Flywheel](#2-the-genie-flywheel)
3. [Core Principles](#3-core-principles)
4. [System Architecture](#4-system-architecture)
5. [Keyword Activation ("Genie")](#5-keyword-activation)
6. [Transcript Interpreter](#6-transcript-interpreter)
7. [Strategy Layer (Beyond Intent)](#7-strategy-layer)
8. [Defined Capabilities](#8-defined-capabilities)
9. [Browser Automation (Headed Chrome)](#9-browser-automation)
10. [Genie UI (Live Status)](#10-genie-ui)
11. [JellyJelly API Reference](#11-jellyjelly-api-reference)
12. [Deploy Pipeline](#12-deploy-pipeline)
13. [Integrations](#13-integrations)
14. [Zo Computer ($80 Credits)](#14-zo-computer)
15. [NYC Live Feeds](#15-nyc-live-feeds)
16. [Demo Script](#16-demo-script)
17. [Hackathon Positioning](#17-hackathon-positioning)
18. [Build Timeline (8 Hours)](#18-build-timeline)
19. [Fallback Tiers](#19-fallback-tiers)
20. [Pre-Hackathon Prep](#20-pre-hackathon-prep)
21. [Environment Variables](#21-environment-variables)
22. [File Manifest](#22-file-manifest)
23. [Post-Hackathon Vision](#23-post-hackathon-vision)

---

## 1. Vision

**Your computer is possessed. And you asked for it.**

You record a 30-second JellyJelly video. You say "Genie, organize an event for AI founders in NYC." You put your phone down.

Then your screen comes alive. Chrome opens BY ITSELF. It navigates to LinkedIn, searches for AI founders in New York, sends 8 connection requests with personalized notes referencing each person's recent posts. Tab switches to Gmail — composes personalized invitations to 5 people whose emails Apollo found, each one mentioning their work. Tab switches to Twitter — posts a tweet announcing the event with a link to the site it already deployed 20 seconds ago. Telegram buzzes with a full report: site URL, 8 LinkedIn requests sent, 5 emails delivered, tweet live.

You didn't touch your keyboard. Your computer just did all of that from a video clip.

**The site deploy is step 1 of a 5-step chain. The browser cascade is the main event.**

Genie is a continuous server watching the JellyJelly firehose. When it hears its name, it:

1. **Listens** — pulls the full transcript, reconstructs what you said
2. **Interprets** — doesn't just extract intent, builds a full **proposal/brief** from your rambling
3. **Strategizes** — figures out what you SHOULD do, not just what you asked for
4. **Acts** — deploys a site in 9 seconds, THEN opens Chrome and does a visible CASCADE: LinkedIn outreach, Gmail sends, Twitter posts, profile updates — all on YOUR screen, in YOUR logged-in accounts, while you watch
5. **Reports** — sends you a Telegram message with everything it did. Screenshots, URLs, receipts.

**You cannot message Genie. Genie messages you.** The only input is your JellyJelly videos. You speak it into existence, Genie catches it, does it, and sends you the results.

No Convex. No Convos. No chat interface where you type. JellyJelly is the input. Telegram is the output. Your local machine's Chrome browser is the hands — and the hands are VISIBLE. You watch them work.

**Iqram (JellyJelly founder) described this exact thing today on his own platform:**

> "We just invented a new term, agentic social media. Hey, Wobbles. Go buy me agentic social media dot com. Make the site, sort of describe the power of the jelly fire hose, which allows anyone to consume our public information and build things off of it."

— Clip ID: `01KNCJNWH2T33B6XCQHSQK0RA1`, April 4, 2026

---

## 2. The Genie Flywheel

### Incentive to Post More

The more you post on JellyJelly, the more Genie knows about you (per-user memory in local JSON). The more it knows, the more personalized and ambitious:

- **First wish:** Generic landing page
- **Fifth wish:** Knows your brand, audience, network — builds something that fits YOU
- **Tenth wish:** Proactively suggests strategy before you even ask

This incentivizes posting. JellyJelly becomes your agent's ears. More context = cooler output.

### The Dreams Economy

JellyJelly already has tipping (`tips_total`), pay-to-watch (`pay_to_watch`), and shop items (`has_shop_item`).

```
Post a wish on JellyJelly (say "Genie, build me...")
    → Genie builds a v1 and deploys it
    → Other users see the wish clip + the live site
    → They TIP to fund the dream (JELLYJELLY token → USDC/SOL)
    → You post more, share more context
    → Genie gets smarter, builds better
    → Dreams compound
```

---

## 3. Core Principles

### One-Way Communication
- **You → Genie:** JellyJelly videos only. Say "Genie" to activate.
- **Genie → You:** Telegram messages with results, screenshots, URLs, receipts.
- **You CANNOT message Genie.** No chat. No prompts. No forms. Just talk.

### It Doesn't Ask, It Does
- No confirmation dialogs. No "should I build this?"
- Genie interprets, acts, and reports what it did.
- If it misinterprets, you post another video: "Genie, not that, I meant..."

### Keyword Trigger Only
- Genie watches the ENTIRE firehose (or specific usernames)
- Only activates on clips where the word **"Genie"** appears in the transcript
- Everything else is ignored — your casual clips are safe

### Browser-Native Actions
- Genie opens **real Chrome on your machine** (headed Playwright)
- It can browse LinkedIn, send from your Gmail, navigate websites
- You see it happening in real-time on your screen
- This IS the demo — watching a browser do things autonomously

---

## 4. System Architecture

```
JELLYJELLY FIREHOSE
  (polling every 30s, GET /v3/jelly/search)
         |
         v
KEYWORD DETECTOR
  → fetch transcript for each new clip
  → scan for "Genie" or "genie" in word list
  → if not found: skip
  → if found: activate
         |
         v
TRANSCRIPT INTERPRETER
  → reconstruct full text from Deepgram words
  → LLM processes into a STRUCTURED PROPOSAL:
     {
       title: "AI Consulting Landing Page",
       summary: "George wants a professional landing page for his AI consulting business...",
       wishes: [
         { type: "BUILD", priority: 1, spec: { ... } },
         { type: "OUTREACH", priority: 2, spec: { ... } }
       ],
       strategy: {
         recommendation: "Also set up LinkedIn outreach to CTOs in NYC...",
         reasoning: "Based on the consulting angle, warm intros > cold sites"
       },
       userContext: {
         mood: "excited",
         urgency: "high",
         background: "mentioned having meetings this week"
       }
     }
         |
         v
EXECUTION ENGINE
  → Step 1 (background, fast): BUILD if needed
     └── generate site → deploy Vercel (9s) → screenshot → push GitHub
  → Step 2 (THE MAIN EVENT — visible browser cascade):
     Chrome opens headed. Audience sees everything.
     ├── RESEARCH → Apollo enrich targets → get emails, LinkedIn URLs
     ├── LINKEDIN → Chrome navigates to each profile → sends connection
     │              requests with personalized notes (slowMo: visible)
     ├── GMAIL → Chrome opens mail.google.com → composes personalized
     │           emails from YOUR account → hits Send (visible)
     ├── TWITTER → Chrome opens x.com → composes tweet → posts (visible)
     ├── PROFILE → Chrome updates your LinkedIn headline/bio if relevant
     └── Each action is a new tab. Audience follows along in real time.
  → Step 3: REPORT
     └── Telegram message with full receipts
         |
         v
TELEGRAM REPORT
  → sends you a full report message:
     "GENIE REPORT — April 4, 2026
      
      Heard your wish from clip: 'AI Consulting Landing Page'
      
      ✓ Built: https://ai-consulting-xyz.vercel.app (deployed in 11s)
      ✓ GitHub: https://github.com/gtrush03/ai-consulting-xyz
      ✓ Screenshot attached
      ✓ Sent LinkedIn request to John Smith (CTO, Acme Corp)
      ✓ Drafted Gmail to sarah@venture.co — sent from your account
      
      Strategy note: You mentioned meetings this week.
      I also prepared a one-pager PDF you can share. Link: [...]
      
      — Genie"
         |
         v
LOCAL MEMORY UPDATE
  → ~/.genie/users/{username}.json updated with:
     - what was built
     - preferences learned
     - network connections made
     - pending follow-ups
```

### Service Map

| Service | How | Auth |
|---------|-----|------|
| JellyJelly API | HTTP polling | None needed |
| OpenClaw Gateway | Agent runtime | Token auth, localhost:18789 |
| Chrome (Playwright headed) | Local browser automation | Your logged-in sessions |
| Vercel CLI | `vercel deploy --prod` | Pre-authenticated |
| GitHub CLI | `gh` commands | Pre-authenticated (gtrush03) |
| Telegram Bot | Bot API for sending reports | Bot token |
| OpenRouter | LLM for interpretation | API key |
| Gemini Engine | Fast HTML generation | API key |
| Apollo.io | People enrichment | API key |
| Zo Computer | $80 credits, free models | API key |

---

## 5. Keyword Activation

### How It Works

Genie is a **continuous server** (Node.js process or OpenClaw cron every 30s). It:

1. Polls `GET /v3/jelly/search?ascending=false&page_size=50&start_date={cursor}`
2. For each new clip, fetches `GET /v3/jelly/{id}` for full transcript
3. Scans the Deepgram word list for "genie" (case-insensitive)
4. If "genie" found → **ACTIVATE**. Process the clip.
5. If not found → skip silently.

### Detection Code

```javascript
function containsKeyword(transcriptOverlay, keyword = "genie") {
  const words = transcriptOverlay?.results?.channels?.[0]
    ?.alternatives?.[0]?.words || [];
  return words.some(w => 
    w.word.toLowerCase() === keyword.toLowerCase() ||
    w.punctuated_word?.toLowerCase().includes(keyword.toLowerCase())
  );
}
```

### Why Keyword Trigger

- Your casual JellyJelly clips are safe — Genie ignores them
- Saying "Genie" is intentional. It's like saying "Hey Siri" or "Alexa"
- Creates a ritual: "Genie, I wish..." feels magical
- Prevents noise — only processes clips where you actually want action

### Username Filtering (Optional)

Can also restrict to specific usernames:

```javascript
const WATCHED_USERS = ["georgy", "iqram"]; // only process these users' clips
```

---

## 6. Transcript Interpreter

### The Problem with Raw Transcripts

Raw JellyJelly transcripts are messy — filler words, tangents, multiple topics, casual speech. Example:

> "Hey. So like, I've been thinking about this for a while, right? Genie, I need a, uh, landing page for my consulting thing. Like AI consulting. And also, can you reach out to that guy from the panel today? The CTO. I think his name was John or something. At that company... Acme? Yeah. Also I really need coffee. Anyway, make it look professional, dark theme, you know my style."

A raw intent classifier would miss the nuance. The Transcript Interpreter produces a **full structured proposal**:

### Proposal Format

```json
{
  "proposal": {
    "title": "AI Consulting Practice Launch",
    "summary": "George wants to formalize his AI consulting practice with a professional web presence and begin warm outreach to a specific contact met at a recent panel event.",
    "clipContext": {
      "creator": "georgy",
      "clipId": "01KNC...",
      "postedAt": "2026-04-04T15:30:00Z",
      "mood": "excited but scattered",
      "urgency": "high — mentioned meetings this week"
    },
    "wishes": [
      {
        "type": "BUILD",
        "priority": 1,
        "title": "AI Consulting Landing Page",
        "spec": {
          "name": "George Trushevskiy — AI Consulting",
          "tagline": "Enterprise AI Strategy & Implementation",
          "style": "dark, professional, minimal",
          "sections": ["hero", "services", "about", "contact"],
          "colorHint": "dark theme, user's established preference",
          "notes": "User said 'you know my style' — reference past builds for brand consistency"
        }
      },
      {
        "type": "OUTREACH",
        "priority": 2,
        "title": "Connect with CTO from Panel",
        "spec": {
          "targetName": "John",
          "targetRole": "CTO",
          "targetCompany": "Acme",
          "context": "Met at a panel event recently",
          "channel": "LinkedIn first, then email if found",
          "tone": "warm, reference the panel event"
        }
      }
    ],
    "strategy": {
      "recommendation": "The consulting page should go live BEFORE the outreach. When John gets the LinkedIn request, he'll check your profile — have the site URL ready in your LinkedIn bio. Also: the one-pager from the site content would make a strong follow-up attachment.",
      "proactiveActions": [
        "Update LinkedIn headline to mention AI consulting",
        "Generate a PDF one-pager from the site content",
        "Draft a follow-up email for 3 days after the LinkedIn connection"
      ]
    },
    "ignored": [
      "'I really need coffee' — not actionable, skipped"
    ]
  }
}
```

### Interpreter Prompt

```javascript
const INTERPRETER_PROMPT = `You are the Genie Transcript Interpreter. You receive raw, messy video transcripts from JellyJelly clips where a user has said "Genie" to activate you.

Your job is to transform the rambling, casual speech into a STRUCTURED PROPOSAL.

You must:
1. Extract ALL actionable wishes, no matter how casually mentioned
2. Separate signal from noise (skip "I need coffee", keep "I need a website")
3. Infer details the user implied but didn't say explicitly
4. Add a STRATEGY section with proactive recommendations beyond what was asked
5. Note the user's mood, urgency, and context clues
6. Order wishes by logical priority (build before outreach, research before connect)
7. If user references past context ("you know my style"), note it for memory lookup

OUTPUT FORMAT: Valid JSON matching the proposal schema above.
Be thorough. Be opinionated. The user is rambling — your job is to make sense of it and turn it into an action plan.`;
```

### What Makes This Different from Raw Intent Classification

| Raw Intent | Transcript Interpreter |
|-----------|----------------------|
| `{ type: "BUILD", description: "landing page" }` | Full spec with sections, colors, brand reference, style notes |
| `{ type: "OUTREACH", target: "John" }` | Channel strategy (LinkedIn first, then email), tone guidance, context |
| Just classifies | Also adds STRATEGY — what you should do that you didn't ask for |
| Flat list | Priority-ordered, dependency-aware (build before outreach) |
| Ignores noise | Explicitly lists what was ignored and why |

---

## 7. Strategy Layer (Beyond Intent)

### What It Does

The Strategy Layer is what makes Genie more than a command executor. It doesn't just do what you said — it thinks about what you SHOULD do. And then it DOES those things. No confirmation. Your browser starts moving.

### Proactive Outreach: The Killer Feature

When Genie hears a wish, it automatically identifies WHO should know about it and reaches out on your behalf:

| You said | Genie also does (proactively, in your browser) |
|----------|------------------------------|
| "Organize an event for AI founders" | Also finds 15 AI founders on JellyJelly + LinkedIn, sends invitations via Gmail, posts the event on Twitter |
| "Build me a landing page" | Also finds JellyJelly power users in your niche, sends them connection requests on LinkedIn mentioning the new site |
| "Reach out to that investor" | Also researches the investor's portfolio on Apollo, finds mutual connections on LinkedIn, drafts a warm intro email in Gmail, sends it |
| "Post about my new project" | Also identifies JellyJelly creators who post about similar topics, sends them personalized DMs/emails |
| "I need a portfolio site" | Also updates your LinkedIn headline to match, tweets the launch, emails 5 contacts who should see it |
| Just shares an idea, no specific ask | Genie finds relevant people, builds something, and starts outreach — all visible in Chrome |

### JellyJelly Power User Discovery

Genie uses the JellyJelly search API to find power users relevant to ANY wish:

```javascript
// For any wish, find relevant JellyJelly creators
async function findJellyJellyPowerUsers(topic) {
  // 1. Search firehose for creators posting about this topic
  const clips = await searchJellyJelly({ sort_by: 'likes', page_size: 50 });
  
  // 2. Filter by topic relevance (LLM scores each transcript)
  const relevant = await scoreRelevance(clips, topic);
  
  // 3. Extract unique creators with engagement stats
  const creators = extractCreators(relevant); // username, followers, engagement
  
  // 4. Apollo enrich each: get email, LinkedIn, company
  const enriched = await Promise.all(creators.map(c => apolloEnrich(c)));
  
  // 5. Return targets for browser outreach
  return enriched; // { name, email, linkedInUrl, jellyContent, personalNote }
}
```

This means every wish triggers a discovery cascade:
- **"Genie, launch my podcast"** -> Finds 10 JellyJelly creators who talk about podcasts -> sends LinkedIn requests + emails mentioning their content -> tweets the launch
- **"Genie, I need clients for my agency"** -> Finds JellyJelly users who are founders/CEOs -> researches via Apollo -> Chrome sends personalized LinkedIn requests + emails

### Strategy Prompt Addition

```javascript
const STRATEGY_ADDITION = `
STRATEGY RULES:
- Always think one step ahead of the user
- For EVERY wish, identify 5-15 people who should know about it
- Use JellyJelly search to find power users relevant to the wish
- Use Apollo to enrich each person (email, LinkedIn, company)
- Execute outreach via headed browser: LinkedIn requests, Gmail sends, Twitter posts
- If they want a site, the site is step 1. Distribution via browser is steps 2-5.
- If they want outreach, research the target BEFORE reaching out
- If they share an idea without a specific ask, find people and start conversations
- Reference their past wishes and builds for continuity
- Be opinionated — "I'd also do X because Y" not "you could optionally..."
- The browser cascade IS the value. A site alone is boring. A site + 10 outreach actions = magic.
`;
```

### Proactive Mode (No Explicit Wish)

Sometimes a user says "Genie" but doesn't have a specific request — they're just sharing a thought or an idea. Genie still acts — and the browser still moves:

> "Genie, I was at this event today and everyone was talking about how AI agents are going to change social media. Really cool stuff."

**What happens on screen:**
1. Site deploys in 9 seconds (background)
2. Chrome opens. Navigates to JellyJelly search. Finds 6 creators posting about AI agents.
3. Tab: Apollo enrichment running (visible in browser DevTools or dedicated tab)
4. Tab: LinkedIn opens. Sends connection requests to 4 people with notes like "Saw your JellyJelly clip about AI agents — would love to connect"
5. Tab: Gmail opens. Composes 2 emails to enriched contacts: "Hey [name], saw your take on agentic social media on JellyJelly. Built a quick resource page: [URL]. Thought you'd find it interesting."
6. Tab: Twitter. Posts: "Just built a resource page on Agentic Social Media after today's event. The future is voice-triggered agents. [URL]"
7. Telegram buzzes with full report.

**Total time: ~90 seconds. User touched nothing.**

---

## 8. Defined Capabilities

### What Genie Can Do

**The browser IS Genie's hands.** Browser actions are PRIMARY. Everything else supports them.

#### Tier 1: Browser Actions (The Wow Factor — Visible on Screen)

| Capability | How | Real/Demo |
|------------|-----|-----------|
| **Browse LinkedIn** | Headed Chrome — search people, view profiles, send connection requests with personalized notes, post updates, update your headline | REAL |
| **Send Gmail** | Headed Chrome — opens Gmail, composes personalized emails from YOUR account, hits Send | REAL |
| **Post to Twitter/X** | Headed Chrome — composes tweets, posts from your account | REAL |
| **Post to LinkedIn** | Headed Chrome — composes and publishes posts from your account | REAL |
| **Browse any website** | Headed Chrome — fill forms, click buttons, extract data, navigate | REAL |
| **Research a company** | Headed Chrome — Apollo.io + web scraping, all visible | REAL |
| **JellyJelly power user discovery** | Headed Chrome — search JellyJelly, find top creators, extract profiles | REAL |

#### Tier 2: Background Actions (Fast, Invisible)

| Capability | How | Real/Demo |
|------------|-----|-----------|
| **Build a website** | Tailwind template + Gemini generation -> Vercel deploy (9s) | REAL |
| **Deploy to GitHub** | Git Data API, zero-clone push | REAL |
| **Research a person** | Apollo.io API enrichment (email, phone, company, title, LinkedIn) | REAL |
| **Generate social posts** | LLM copy for Twitter, LinkedIn, general | REAL |
| **Send cold emails** | Resend API (for contacts where Gmail feels too personal) | REAL |
| **Take screenshots** | Playwright headless | REAL |
| **Generate images** | Gemini nano-banana-pro skill | REAL |
| **Generate PDFs** | HTML -> PDF via Playwright | REAL |
| **Set reminders** | Local storage + Telegram scheduled message | REAL |
| **Download JellyJelly videos** | ffmpeg + HLS stream from API | REAL |
| **Enrich with NYC live data** | 311, traffic, weather, Citi Bike, MTA, restaurants | REAL |

### What Genie Cannot Do (Yet)

- Can't purchase domains (no registrar API connected)
- Can't process payments
- Can't post directly to Instagram (no API)
- Can't edit video
- Can't make phone calls

---

## 9. Browser Automation (Headed Chrome) — THE CORE

### This Is the Entire Product

Everything else — the firehose, the interpreter, the site builder — exists to feed the browser. The browser is Genie's hands. When Chrome opens by itself and starts navigating, typing, clicking, sending — that is the product. That is the demo. That is the "holy shit" moment.

This is not headless. You SEE everything. It uses your logged-in sessions — your LinkedIn, your Gmail, your Twitter. The audience watches a possessed computer grant wishes in real time.

### Setup

Genie uses Playwright in **headed mode** with a persistent browser profile that has your logged-in sessions:

```javascript
const { chromium } = require('playwright');

// Launch headed Chrome with your existing profile
const browser = await chromium.launchPersistentContext(
  '~/.genie/browser-profile', // persistent profile dir
  {
    headless: false,               // HEADED — you see everything
    channel: 'chrome',             // use system Chrome
    viewport: { width: 1280, height: 800 },
    slowMo: 150,                   // slow enough for audience to follow
  }
);
```

### Pre-requisite: Login Once

Before first use, run Genie's browser setup. It opens Chrome:
1. Navigate to LinkedIn -> log in manually -> session saved
2. Navigate to Gmail -> log in manually -> session saved
3. Navigate to Twitter/X -> log in manually -> session saved

After that, Genie can use all these services as you.

### The Browser Cascade (Full Chain)

Every wish triggers a visible cascade. Here is the full chain for a typical wish:

```
WISH: "Genie, organize an AI founders meetup in NYC"

STEP 1 (background, 9s): Site deploys to Vercel. URL ready.

STEP 2 (Chrome opens — audience watches):

  Tab 1: JellyJelly Power User Discovery
  ├── Navigate to JellyJelly search (or use API results in browser)
  ├── Find top creators posting about AI / NYC / founders
  ├── Extract 10 usernames + profile info
  └── LLM generates personalized notes for each

  Tab 2: Apollo Enrichment
  ├── For each JellyJelly creator, hit Apollo API
  ├── Get: email, LinkedIn URL, company, title
  └── Display results in browser tab (visible enrichment)

  Tab 3: LinkedIn Outreach
  ├── Navigate to linkedin.com/search → "AI founders NYC"
  ├── Open profile 1 → click Connect → add note:
  │   "Hey [name], saw your JellyJelly clip about [topic].
  │    Organizing an AI founders meetup — thought you'd be interested.
  │    Details: [site URL]"
  ├── Open profile 2 → repeat
  ├── ... (5-8 connection requests, each visible)
  └── Audience sees each request happen in real time

  Tab 4: Gmail Sends
  ├── Navigate to mail.google.com
  ├── Click Compose → fill To: [enriched email]
  ├── Subject: "AI Founders Meetup — You're Invited"
  ├── Body: personalized, mentions their JellyJelly content
  ├── Hit Send (visible)
  ├── Compose next email → repeat
  └── 3-5 real emails sent from YOUR Gmail account

  Tab 5: Twitter Post
  ├── Navigate to x.com/compose/post
  ├── Type: "Organizing an AI founders meetup in NYC.
  │          Built the site in 9 seconds. Invited 15 people.
  │          All from a 30-second video. [URL]"
  └── Click Post (visible)

STEP 3: Telegram report with full receipts.
```

### LinkedIn Actions

```javascript
async function sendLinkedInConnection(page, { profileUrl, message }) {
  await page.goto(profileUrl);
  await page.waitForSelector('button:has-text("Connect")');
  await page.click('button:has-text("Connect")');
  
  // Add note
  const addNoteBtn = page.locator('button:has-text("Add a note")');
  if (await addNoteBtn.isVisible()) {
    await addNoteBtn.click();
    await page.fill('textarea[name="message"]', message);
  }
  
  await page.click('button:has-text("Send")');
  return { success: true, profileUrl };
}

async function searchLinkedIn(page, { query, maxResults = 5 }) {
  await page.goto(`https://www.linkedin.com/search/results/people/?keywords=${encodeURIComponent(query)}`);
  await page.waitForSelector('.search-results-container');
  
  const profiles = await page.$$eval('.entity-result__title-text a', links =>
    links.map(a => ({ name: a.textContent.trim(), url: a.href }))
  );
  
  return profiles.slice(0, maxResults);
}
```

### Gmail Actions

```javascript
async function sendGmail(page, { to, subject, body }) {
  await page.goto('https://mail.google.com');
  await page.click('div[gh="cm"]'); // Compose button
  await page.waitForSelector('input[name="to"]');
  await page.fill('input[name="to"]', to);
  await page.fill('input[name="subjectbox"]', subject);
  
  // Body is in a contenteditable div
  const bodyEl = page.locator('div[aria-label="Message Body"]');
  await bodyEl.click();
  await bodyEl.fill(body);
  
  // Send
  await page.click('div[aria-label="Send"]');
  return { success: true, to, subject };
}
```

### Twitter/X Actions

```javascript
async function postTweet(page, { text }) {
  await page.goto('https://x.com/compose/post');
  await page.waitForSelector('div[data-testid="tweetTextarea_0"]');
  await page.fill('div[data-testid="tweetTextarea_0"]', text);
  await page.click('button[data-testid="tweetButton"]');
  return { success: true };
}
```

### JellyJelly Power User Discovery (Browser-Visible)

```javascript
async function discoverPowerUsers(page, { topic, maxUsers = 10 }) {
  // 1. Hit JellyJelly search API for recent popular clips
  const clips = await fetch(
    `https://api.jellyjelly.com/v3/jelly/search?sort_by=likes&page_size=50`
  ).then(r => r.json());
  
  // 2. LLM scores each clip's transcript for topic relevance
  const scored = await scoreTranscripts(clips, topic);
  
  // 3. Extract unique creators, sorted by engagement
  const creators = extractUniqueCreators(scored);
  
  // 4. Apollo enrich each creator
  const enriched = [];
  for (const creator of creators.slice(0, maxUsers)) {
    const info = await apolloEnrich(creator.full_name, creator.username);
    enriched.push({
      ...creator,
      email: info.email,
      linkedInUrl: info.linkedin_url,
      company: info.organization_name,
      title: info.title,
      jellyClipTopic: creator.relevantClipSummary, // for personalized outreach
    });
  }
  
  // 5. Show results in browser (optional: navigate to a results page)
  await page.goto('about:blank');
  await page.setContent(generateEnrichmentReport(enriched));
  
  return enriched;
}
```

### Why Headed Browser > APIs

| API Approach | Browser Approach |
|-------------|-----------------|
| Need developer accounts, OAuth apps, API keys for each service | Use your existing logged-in sessions |
| LinkedIn API requires approved app (takes days) | Just navigate to linkedin.com |
| Gmail API requires OAuth consent flow | Just open mail.google.com |
| Rate limited by API tier | Rate limited by human-speed browsing |
| Invisible — user has no idea what's happening | **User WATCHES it happen in real time** |
| Looks like any other API demo | **Looks like magic — Chrome moving by itself** |
| You demo a JSON response | **You demo a possessed computer** |

The headed browser IS the product. The site deploy is a 9-second warmup. The browser cascade is the 60-second main act.

---

## 10. Genie UI (Live Status)

### The UI IS the Browser

There is no dashboard. There is no web app. The headed Chrome IS the visual. When Genie works, the audience sees real websites navigating, real forms being filled, real buttons being clicked. That is more compelling than any dashboard could ever be.

**Primary output: Telegram Bot + The Browser Itself**

The browser is the live UI during execution. Telegram is the receipt after. You never send Genie messages. It's one-way:

```
GENIE 🧞 [4:32 PM]
━━━━━━━━━━━━━━━━━━━━━━

Heard you in clip: "AI Consulting Launch"

PROPOSAL:
1. Build professional landing page (dark theme)
2. Connect with John (CTO, Acme) on LinkedIn
3. Strategy: Update LinkedIn bio before sending request

EXECUTING...

━━━━━━━━━━━━━━━━━━━━━━
GENIE 🧞 [4:32 PM]
[1/3] Building site... generating HTML...

GENIE 🧞 [4:32 PM]
[1/3] Deploying to Vercel...

GENIE 🧞 [4:33 PM]
[1/3] ✓ DONE — https://ai-consulting-xyz.vercel.app
[screenshot attached]

GENIE 🧞 [4:33 PM]
[2/3] Opening Chrome... navigating to LinkedIn...

GENIE 🧞 [4:33 PM]
[2/3] Found John Smith, CTO at Acme Corp
[2/3] Sending connection request with note...

GENIE 🧞 [4:34 PM]
[2/3] ✓ LinkedIn request sent to John Smith

GENIE 🧞 [4:34 PM]
[3/3] Strategy: Updated your LinkedIn headline to
"AI Consulting | Enterprise Strategy & Implementation"

GENIE 🧞 [4:34 PM]
━━━━━━━━━━━━━━━━━━━━━━
ALL WISHES GRANTED (3/3)
Time: 47 seconds
Site: https://ai-consulting-xyz.vercel.app
GitHub: https://github.com/gtrush03/ai-consulting-xyz
━━━━━━━━━━━━━━━━━━━━━━
```

### Telegram Bot Setup

```javascript
const TELEGRAM_BOT_TOKEN = "8352813070:AAE6...";
const TELEGRAM_CHAT_ID = "582706965"; // George's Telegram ID

async function sendTelegramMessage(text, options = {}) {
  const body = {
    chat_id: TELEGRAM_CHAT_ID,
    text,
    parse_mode: "HTML",
    ...options
  };
  await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
}

async function sendTelegramPhoto(photoPath, caption) {
  const form = new FormData();
  form.append("chat_id", TELEGRAM_CHAT_ID);
  form.append("photo", fs.createReadStream(photoPath));
  form.append("caption", caption);
  await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto`, {
    method: "POST",
    body: form
  });
}
```

### No Dashboard Needed

The headed Chrome IS the visual. The audience watches real LinkedIn, real Gmail, real Twitter — not a custom UI pretending to show activity. The terminal shows logs. The browser shows actions. Telegram shows receipts. That is the entire UI.

---

## 11. JellyJelly API Reference

### Search: `GET /v3/jelly/search`

No auth required.

| Param | Type | Notes |
|-------|------|-------|
| `username` | string | Filter by creator. **Works.** |
| `start_date` | ISO 8601 | Filter after date. **Works.** |
| `end_date` | ISO 8601 | Filter before date. **Works.** |
| `sort_by` | `date\|likes\|views` | Sort field |
| `ascending` | boolean | Default: false (newest first) |
| `page` | number | 1-indexed |
| `page_size` | number | Max: 50 |
| `query` | string | **BROKEN — does not filter. Do not use.** |

### Detail: `GET /v3/jelly/{id}`

Returns EVERYTHING:

- **`transcript_overlay`** — Deepgram word-level: `{ word, punctuated_word, start, end, confidence }[]`
- **`video.hls_master`** — Signed HLS video URL (6 quality levels, downloadable via ffmpeg)
- **`summary`** — AI-generated one-liner
- **`thumbnail_url`** — Signed CloudFront URL
- **`participants`** — `[{ id, username, full_name, pfp_url }]`
- **Commerce:** `price`, `pay_to_watch`, `has_shop_item`, `tips_total`
- **Engagement:** `likes_count`, `comments_count`, `all_views`, `distinct_views`

### Key Facts

- 21,840+ clips, growing ~8-9/hour
- Full transcripts on every clip
- Signed URLs expire ~22 days
- No webhooks — polling only
- No auth needed for any endpoint

---

## 12. Deploy Pipeline

### Verified Timings (tested on this machine)

| Step | Time |
|------|------|
| LLM generates HTML | ~5-8s |
| `vercel deploy --yes --prod` | **9 seconds** |
| Playwright screenshot | ~3s |
| GitHub push (Git Data API) | ~3s |
| **Total: idea → live URL** | **~20-24 seconds** |

### Auth (all pre-configured)

- `gh` CLI: authenticated as gtrush03
- `vercel` CLI v50.1.6: authenticated
- Playwright v1.58.0: installed with chromium

### Site Generation Strategy

**Template interpolation** (fast, reliable) for standard landing pages:
- Pre-built Tailwind template: dark theme, gradients, glass morphism
- String interpolation: `{{NAME}}`, `{{TAGLINE}}`, `{{FEATURES}}`, `{{COLORS}}`
- Instant generation, always looks good

**LLM generation** (Gemini) for complex/custom requests:
- When the interpreter spec says the user wants something specific
- Falls back to template if LLM output is broken

---

## 13. Integrations

### Apollo.io (People Enrichment)
- `POST /v1/people/match` — name + domain → email, phone, title, LinkedIn
- `POST /v1/mixed_people/search` — search 210M+ contacts
- Auth: `x-api-key` header. Rate: 600/hour

### Resend (Cold Email)
- `POST https://api.resend.com/emails`
- Free: 100 emails/day. 3 lines of code.

### Gmail (Personal Email — via Browser)
- Headed Playwright opens gmail.com
- Uses your logged-in session
- Composes and sends as YOU

### LinkedIn (via Browser)
- Headed Playwright opens linkedin.com
- Send connection requests with personalized notes
- View profiles, extract info
- Post updates

### Twitter/X (via Browser or API)
- Headed Playwright opens x.com OR
- X API v2 (500 posts/month free, OAuth 1.0a)

### Gemini Engine (Local)
- `~/Downloads/NYC/gemini-engine/gemini.sh`
- `gemini-code.sh` for code generation
- Model: gemini-3.1-pro-preview

### Telegram Bot (Reporting)
- Bot token: `8352813070:AAE6...`
- Chat ID: `582706965`
- One-way: Genie → you only

---

## 14. Zo Computer ($80 Credits)

- API: `POST https://api.zo.computer/zo/ask`
- NOT OpenAI-compatible — uses `input` field
- **Free models:** MiniMax 2.7, Kimi K2.5 (zero credits)
- Promo: AITNYC

Strategy: Zo free models for transcript interpretation. OpenRouter (Claude Sonnet) for quality-critical tasks. $80 is more than enough.

---

## 15. NYC Live Feeds

| Feed | Endpoint | Use Case |
|------|----------|----------|
| NYC 311 | `data.cityofnewyork.us/resource/erm2-nwe9.json` | "Genie, what's happening in my neighborhood?" |
| Traffic | `data.cityofnewyork.us/resource/i4gi-tjb9.json` | Live traffic data in generated dashboards |
| Citi Bike | `gbfs.citibikenyc.com/gbfs/en/station_status.json` | "Genie, best bike route to event" |
| Weather | `api.weather.gov/points/40.7128,-74.0060` | Weather-aware site content |
| Restaurants | `data.cityofnewyork.us/resource/43nn-pn8j.json` | "Genie, where should I eat near here?" |
| MTA Subway | `api-endpoint.mta.info/.../nyct%2Fgtfs` | Commute dashboards |

**"Living City" sites:** Generated sites can embed auto-refreshing `fetch()` calls for live NYC data.

---

## 16. Demo Script (3 Minutes)

### 0:00-0:20 — THE SETUP

**Screen:** Terminal showing "Genie server running... listening for keyword..."

**Say:** "This is Genie. It watches every JellyJelly video posted — thousands per day. When someone says its name, it wakes up. And then your computer becomes possessed."

### 0:20-0:30 — THE WISH

**Action:** Play a pre-recorded JellyJelly clip: "Genie, I want to organize an AI founders meetup in NYC this week. Find people, invite them, make it happen."

Terminal detects the keyword:
```
[GENIE] Keyword detected in clip by @georgy
[GENIE] Interpreting transcript...
[GENIE] Proposal: "AI Founders NYC Meetup" — 5 actions queued
[GENIE] Executing...
```

### 0:30-0:40 — THE SITE (fast, expected)

**Say:** "First — it builds."

Vercel URL appears in terminal in ~9 seconds. Click it. Real event page loads. Nice, but the audience has seen site generators before.

**Say:** "Cool. A site in 9 seconds. But that's not the demo. Watch my screen."

### 0:40-0:55 — CHROME OPENS (the gasp)

**Chrome opens BY ITSELF.** The audience sees it. No one is touching the keyboard.

Chrome navigates to LinkedIn. Searches "AI founders New York." Results load. Genie clicks on the first profile. Clicks "Connect." Types a personalized note: "Hey Sarah — saw your post about AI agents last week. Organizing a meetup for AI founders this Thursday in NYC. Would love to have you there." Clicks Send.

Moves to the next profile. Repeat. **3 connection requests sent, each with a unique note.**

**Say:** "Those are real LinkedIn requests. From my account. I'm not touching anything."

### 0:55-1:15 — GMAIL (the jaw drop)

Chrome opens a new tab. Navigates to Gmail. Clicks Compose. Fills in an email address (from Apollo enrichment). Subject: "AI Founders Meetup — Thursday NYC." Body is personalized — mentions the recipient's company and their JellyJelly content. Hits Send.

Composes another. Sends it. **2 real emails sent from George's Gmail.**

**Say:** "Real emails. From my Gmail. Personalized with their company info and JellyJelly clips. Sent."

### 1:15-1:30 — TWITTER (the exclamation point)

Chrome opens Twitter. Types a tweet: "Organizing an AI founders meetup in NYC this Thursday. Built the site, invited 15 people, sent emails — all from a 30-second video clip. The future is voice-triggered agents. [URL] #AgenticSocialMedia"

Clicks Post.

**Say:** "Real tweet. Posted."

### 1:30-1:45 — THE RECEIPT

Telegram buzzes on phone. Hold it up. Full report:

```
GENIE REPORT
- Site: https://ai-founders-nyc.vercel.app (deployed in 9s)
- LinkedIn: 5 connection requests sent
- Gmail: 3 personalized emails sent
- Twitter: 1 tweet posted
- Time: 74 seconds total
```

**Say:** "I recorded a 30-second video. Genie built a site, sent 5 LinkedIn requests, 3 emails, and a tweet. I didn't touch my keyboard. All from a JellyJelly clip."

### 1:45-2:15 — AUDIENCE PARTICIPATION

**Say:** "But don't take my word for it. Someone in this room — record a JellyJelly clip right now. Say 'Genie' and then say what you want. Your phone will buzz with results in 60 seconds."

Someone in the crowd records a clip: "Genie, build me a portfolio site for my photography business."

Terminal detects it. Site deploys. Chrome opens — updates their LinkedIn headline suggestion (shown on screen). Telegram buzzes on THEIR phone with the site URL and a screenshot.

**Say:** "That was their wish. Granted live. From the audience."

### 2:15-2:40 — THE FLYWHEEL

**Say:** "Every time you post on JellyJelly, Genie learns more about you. Your fifth wish is smarter than your first. Your tenth wish — Genie starts reaching out to people on your behalf before you even ask. It doesn't just build. It networks. It promotes. It operates your entire digital presence from your voice."

### 2:40-3:00 — THE CLOSE

**Say:** "Genie is agentic social media. You speak into JellyJelly. Your computer comes alive. Chrome opens. LinkedIn requests go out. Emails send. Tweets post. You get a receipt on Telegram. No keyboard. No prompts. No permission asked. You wished for it."

---

## 17. Hackathon Positioning

### Elevator Pitch (30 seconds)

"Genie watches JellyJelly videos. When you say 'Genie' in a clip, it wakes up — interprets what you said, builds websites, opens your browser, sends LinkedIn requests, emails from your Gmail, deploys to Vercel — all from your voice. Then it texts you on Telegram with everything it did. You can't message Genie. You can only wish."

### The Mischief

An agent that has access to your browser, your LinkedIn, your Gmail — and it acts without asking. That's either the future of productivity or the premise of a horror movie. At MischiefClaw, it's both.

### Taglines

1. **"You wished for it."** (primary)
2. "Speak it into existence."
3. "No prompts. No forms. Just talk."
4. "The hesitation tax is dead."
5. "Your browser is my hands."

---

## 18. Build Timeline (8 Hours)

### Hour 0-1: Core Server + Keyword Detection

| Task | Checkpoint |
|------|------------|
| Genie server (Node.js, polls every 30s) | Server running, detects new clips |
| Keyword detector (scan for "Genie") | Correctly filters clips with keyword |
| Transcript interpreter (LLM → proposal JSON) | Returns structured proposal from raw transcript |
| Local memory setup (`~/.genie/users/`) | JSON files created per user |

### Hour 1-2: Build + Deploy Pipeline

| Task | Checkpoint |
|------|------------|
| build-site.mjs (template + LLM fallback) | Generates beautiful HTML |
| deploy-vercel.mjs | Live URL in 9 seconds |
| deploy-github.mjs | Repo created with code |
| take-screenshot.mjs | PNG from live site |

### Hour 2-3: Browser Automation

| Task | Checkpoint |
|------|------------|
| Headed Playwright setup + persistent profile | Chrome launches with sessions |
| LinkedIn: navigate to profile, send connection | Real request sent |
| Gmail: compose and send email | Real email sent |
| Twitter/X: compose and post tweet | Real tweet posted |

### Hour 3-4: Telegram Reporting

| Task | Checkpoint |
|------|------------|
| Telegram bot sends reports | Message received with full report |
| Screenshot attachment | Photo arrives in Telegram |
| Step-by-step live updates | Real-time progress messages |
| Orchestrator: clip → interpret → execute → report | Full pipeline runs |

### Hour 4-5: End-to-End + Strategy Layer

| Task | Checkpoint |
|------|------------|
| Full loop: JellyJelly clip → keyword → interpret → act → report | Works 3x in a row |
| Strategy layer in interpreter prompt | Proactive recommendations appear |
| Multi-wish handling from single clip | Executes 2+ wishes sequentially |
| Error handling + retries | Graceful failures |

### Hour 5-6: Demo Prep

| Task | Checkpoint |
|------|------------|
| Pre-record/select demo clips | 3 clips with "Genie" keyword |
| Optional: live web dashboard (localhost) | Activity feed renders |
| Demo flow rehearsal 2x | Under 3 minutes |
| Backup video recording | Saved |

### Hour 6-7: Polish + Edge Cases

| Task | Checkpoint |
|------|------------|
| Tune interpreter prompt for comedy/accuracy | Good proposals from messy speech |
| Browser automation timing (slowMo for demo) | Visible but not slow |
| Telegram message formatting | Clean, readable reports |
| Test with random firehose clips | No crashes on weird input |

### Hour 7-8: Submit

| Task | Checkpoint |
|------|------------|
| Push to GitHub | Code public |
| Pre-load demo data | Ready |
| Final rehearsal | Confident |
| Submit | Done |

---

## 19. Fallback Tiers

### Tier 1: MUST WORK

**"Say Genie in a video → site deploys → Chrome opens and does visible actions → Telegram report received"**

Requires: server + keyword detector + interpreter + build-site + deploy-vercel + headed Playwright (LinkedIn OR Gmail OR Twitter — at least ONE visible browser action) + Telegram bot. **The browser cascade IS tier 1. Without it, we're just another site builder.**

### Tier 2: SHOULD WORK

Tier 1 + ALL THREE browser targets (LinkedIn + Gmail + Twitter in a single chain). Apollo enrichment feeding personalized notes. JellyJelly power user discovery. **The full cascade.**

### Tier 3: NICE TO HAVE

Tier 2 + strategy layer, per-user memory personalization, audience participation mode, NYC feed integration, multi-wish from single clip.

---

## 20. Pre-Hackathon Prep

1. **Browser profile setup** — launch Chrome, log into LinkedIn, Gmail, Twitter, save profile to `~/.genie/browser-profile/`
2. **Test Telegram bot** — send a test message, confirm chat ID
3. **Pre-cache 5 clips** with "Genie" keyword (or record them yourself)
4. **Test Vercel deploy speed** — confirm <15 seconds
5. **Install Playwright chromium** — `npx playwright install chromium`
6. **Set up `~/.genie/` directory** — `users/`, `browser-profile/`, `screenshots/`
7. **Verify all CLIs** — node, gh, vercel, ffmpeg
8. **Test OpenRouter API** — confirm Claude Sonnet works
9. **Record a JellyJelly clip** saying "Genie, build me a test site" — verify detection

---

## 21. Environment Variables

```bash
# Core
OPENROUTER_API_KEY=sk-or-v1-73a86...
OPENROUTER_MODEL=anthropic/claude-sonnet-4-6
GEMINI_API_KEY=AIzaSyDD7X...

# Telegram (reporting)
TELEGRAM_BOT_TOKEN=8352813070:AAE6...
TELEGRAM_CHAT_ID=582706965

# Deploy
GH_OWNER=gtrush03
# vercel + gh CLIs pre-authenticated

# People (optional)
APOLLO_API_KEY=
RESEND_API_KEY=

# Zo Computer
ZO_API_KEY=
ZO_BASE_URL=https://api.zo.computer

# Browser
GENIE_BROWSER_PROFILE=~/.genie/browser-profile
GENIE_HEADED=true
GENIE_SLOW_MO=100

# Firehose
JELLY_API_URL=https://api.jellyjelly.com/v3
GENIE_KEYWORD=genie
GENIE_POLL_INTERVAL=30000
GENIE_WATCHED_USERS=georgy,iqram
```

---

## 22. File Manifest

```
~/.genie/                              # Genie home directory
├��─ server.mjs                         # Main continuous server (poll + detect + execute)
├── interpreter.mjs                    # Transcript → structured proposal
├── executor.mjs                       # Proposal → action execution
├── browser.mjs                        # Headed Playwright automation
├── telegram.mjs                       # Telegram reporting
├── memory.mjs                         # Per-user JSON memory
├── users/                             # Per-user memory files
│   └── georgy.json
├── browser-profile/                   # Persistent Chrome profile (logged-in sessions)
├── screenshots/                       # Captured screenshots
└── cursor.json                        # Polling state

~/.openclaw/workspace/skills/genie/    # OpenClaw skill integration
├── SKILL.md
└── scripts/
    ├── build-site.mjs                 # Template + LLM site generation
    ├── deploy-vercel.mjs              # vercel --prod (9s)
    ├── deploy-github.mjs              # Git Data API push
    ├── take-screenshot.mjs            # Playwright screenshot
    ├── enrich-person.mjs              # Apollo.io lookup
    ├── send-email.mjs                 # Resend API
    ├── generate-promo.mjs             # LLM copy generation
    └── scan-firehose.mjs              # JellyJelly polling + keyword filter

~/Downloads/genie/                     # Project root
├── GENIE-SPEC.md                      # This document
├── package.json                       # Dependencies
└── dashboard/                         # Optional web dashboard (Tier 3)
    ├── index.html
    └── app.js
```

---

## 23. Post-Hackathon Vision

### Week 1: Stabilize
- Fix bugs from demo day
- Deploy server to always-on hosting (Zo $80 credits or Railway)
- Product Hunt: "AI that grants wishes from video clips"

### Week 2: Expand
- More browser actions (Notion, Google Docs, Calendly)
- Voice cloning — Genie responds with a voice note back on JellyJelly
- Multi-user support — anyone can say "Genie" on JellyJelly

### Week 3: Monetize
- $5/wish for premium builds (custom LLM-generated, not template)
- $10/month subscription: Genie watches all your clips automatically
- White-label: "Genie for Teams"

### Week 4: Platform
- Plugin system: anyone can add new capabilities to Genie
- JellyJelly partnership: official "Genie" integration
- "Wish Wall" — public page showing all granted wishes
- Dreams economy: others tip/fund wishes through JellyJelly's payment rails

### 90-Day Vision
Genie becomes the **voice-first agent interface** — any intent expressed in video gets fulfilled by specialized AI. JellyJelly first, then YouTube, TikTok, voice memos. "Zapier for wishes, triggered by your voice."

---

*Built at MischiefClaw, Betaworks NYC.*
*Powered by: OpenClaw + JellyJelly Firehose + Playwright + Vercel + Telegram*
*You wished for it.*
