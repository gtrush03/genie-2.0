# Genie Capability Brainstorm

> 30 new capabilities for the voice-triggered autonomous agent.
> Stars mark the top 10 for demo impact and feasibility.

---

## 5 Services to Log Into Next

1. **OpenTable** -- unlocks restaurant reservations, the most visual "concierge" demo
2. **Airbnb** -- unlocks travel booking, jaw-dropping for "book me a weekend in Hudson Valley"
3. **Calendly** -- unlocks scheduling links, pairs with LinkedIn outreach
4. **Venmo / Cash App (web)** -- unlocks peer-to-peer payments, "split the bill" flows
5. **Notion** -- unlocks note/doc/database creation, pairs with research capabilities

---

## Commerce & Payments

### 1. Amazon One-Click Orders *
**Wish:** "Genie, order a 10-pack of AA batteries on Amazon, cheapest Prime option."
**Execution:** Browser navigates to amazon.com, searches "AA batteries 10 pack", sorts by price, filters Prime, clicks the top result, hits "Buy Now" with saved 1-click settings. Screenshots the order confirmation. Sends confirmation to Telegram.
**Difficulty:** Medium -- Amazon's anti-bot detection is aggressive; needs slow, human-like interaction patterns and possibly cookie warmup.
**Demo impact:** High. Everyone uses Amazon. Buying something with your voice in 15 seconds is visceral.

### 2. Stripe Subscription Setup *
**Wish:** "Genie, create a Stripe product called 'LinkedIn Agent Pro', $49/month recurring, and give me the payment link."
**Execution:** Stripe dashboard browser flow: Products > Add Product > fill name + price + recurring/monthly > Save. Then creates a Payment Link for that product. Copies the URL. Returns it in chat and optionally tweets it.
**Difficulty:** Easy -- Stripe dashboard is clean HTML, predictable selectors. Already has Stripe logged in.
**Demo impact:** Very high. "I just launched a SaaS product with my voice" is a killer clip.

### 3. Venmo Payment
**Wish:** "Genie, Venmo Alex twenty bucks for lunch."
**Execution:** Browser opens venmo.com > Pay/Request > searches "Alex" in contacts > fills $20 > adds note "lunch" > clicks Pay. Screenshots confirmation.
**Difficulty:** Medium -- requires Venmo web login; may hit 2FA on first use.
**Demo impact:** High. Sending real money via voice is dramatic.

### 4. eBay Listing Creator
**Wish:** "Genie, list my old MacBook Pro on eBay for $800. Use photos from my Desktop folder."
**Execution:** Browser opens eBay sell flow. Bash reads ~/Desktop/*.jpg for the listing photos. Fills title ("MacBook Pro 14-inch M1 Pro"), price ($800), condition (Used - Like New), uploads photos via file picker. Drafts description using Claude (specs from the photo filenames or user context). Submits as draft for review.
**Difficulty:** Hard -- eBay's sell flow is multi-step with dynamic forms.
**Demo impact:** High. Turning physical stuff into money via voice.

---

## Social & Communication

### 5. Twitter Thread from Voice Ramble *
**Wish:** "Genie, turn what I just said into a Twitter thread and post it."
**Execution:** Takes the transcribed JellyJelly audio, sends it to Claude to restructure into a numbered thread (max 280 chars per tweet). Browser opens X, posts tweet 1, then replies to it with tweets 2-N. Screenshots the thread. Returns the URL.
**Difficulty:** Easy -- already has X posting. Just needs the "thread" pattern (reply-to-self chain).
**Demo impact:** Very high. Voice-to-published-thread in one shot is content creator catnip.

### 6. Instagram Story via Browser
**Wish:** "Genie, post this photo to my Instagram story with the caption 'NYC vibes'."
**Execution:** Browser opens instagram.com (mobile user-agent emulation), clicks the + icon > Story, uploads the specified image file via file picker, adds text overlay "NYC vibes", posts. Screenshots confirmation.
**Difficulty:** Hard -- Instagram web is hostile to automation; mobile UA tricks required. Story creation via web is limited.
**Demo impact:** Very high if it works. Cross-platform social posting from voice.

### 7. LinkedIn Comment Blitz
**Wish:** "Genie, go to my LinkedIn feed and leave thoughtful comments on the first 5 posts."
**Execution:** Browser opens linkedin.com/feed. For each of the first 5 posts: reads the post text, sends to Claude for a relevant 2-3 sentence comment (not generic), types it, clicks "Post". Logs each comment and the original post author.
**Difficulty:** Medium -- LinkedIn feed scraping is straightforward; comment box selectors are stable.
**Demo impact:** Medium-high. Shows autonomous social engagement.

### 8. Telegram Message/Photo Send *
**Wish:** "Genie, send the screenshot of my latest deploy to the 'Builds' Telegram group."
**Execution:** Browser opens web.telegram.org, searches for "Builds" group, clicks the attachment icon, uploads the file from the local path, sends. Alternatively, uses Telegram Bot API via Bash curl if a bot token is configured (much more reliable).
**Difficulty:** Easy with Bot API, Medium with browser.
**Demo impact:** High. Closing the loop -- Genie does work, then reports it on Telegram.

---

## Productivity & Scheduling

### 9. OpenTable Reservation *
**Wish:** "Genie, book me a table at Carbone for Friday at 8pm, party of 2."
**Execution:** Browser opens opentable.com, searches "Carbone New York", selects Friday's date, 8:00 PM, 2 guests. If available, clicks the time slot, fills in name/email/phone from saved profile, confirms booking. Screenshots the confirmation page. If unavailable, reports the nearest available times.
**Difficulty:** Medium -- OpenTable's flow is well-structured; main risk is Carbone being perpetually booked.
**Demo impact:** Extreme. This is the "AI concierge" fantasy in one clip.

### 10. Google Calendar Event via Browser
**Wish:** "Genie, add a meeting called 'Investor Call' on Tuesday at 3pm for 30 minutes."
**Execution:** Browser opens calendar.google.com, clicks the + button or the Tuesday 3pm slot, fills title "Investor Call", sets duration to 30 min, saves. Screenshots the calendar view.
**Difficulty:** Easy -- Google Calendar's web UI is predictable.
**Demo impact:** Medium. Useful but not jaw-dropping alone.

### 11. Calendly Link Generator
**Wish:** "Genie, create a Calendly event type called '15-min Chat' with my availability Mon-Fri 10am-4pm, and give me the link."
**Execution:** Browser opens calendly.com/event_types/new, fills event name, duration (15 min), sets availability schedule, saves. Copies the public link.
**Difficulty:** Medium -- Calendly's event creation wizard has multiple steps.
**Demo impact:** Medium-high. Useful for the outreach pipeline (LinkedIn DM includes the Calendly link).

### 12. Notion Page from Research *
**Wish:** "Genie, research the top 5 AI agent frameworks and put a comparison table in my Notion."
**Execution:** WebSearch + WebFetch to research (LangGraph, CrewAI, AutoGen, Agency Swarm, Claude Agent SDK). Claude synthesizes into a comparison table. Browser opens notion.so, creates a new page in the workspace, pastes the formatted content as a table using Notion's /table command or markdown paste.
**Difficulty:** Medium -- Notion's web editor has quirks with pasting structured content.
**Demo impact:** High. Research-to-documentation in one voice command.

---

## Creative & Content

### 13. Blog Post Draft + Publish *
**Wish:** "Genie, write a blog post about why AI agents need browser access, and publish it on my Substack."
**Execution:** Claude writes a 600-word post with a compelling hook and clear structure. Browser opens substack.com, clicks "New post", pastes the title and body, optionally generates a header image via an image API. Clicks "Publish" (or "Save draft" for review). Returns the URL.
**Difficulty:** Medium -- Substack's editor is a rich text editor; paste-as-markdown may need formatting cleanup.
**Demo impact:** Very high. Voice-to-published-article is a strong creator demo.

### 14. Thumbnail / Social Image Generation
**Wish:** "Genie, make me a YouTube thumbnail that says 'I Built an AI Butler' with a robot emoji and dark background."
**Execution:** Bash calls an image generation API (DALL-E, Flux, or Gemini Imagen) with the prompt. Downloads the result. Optionally overlays text using ImageMagick (`convert -annotate`). Saves to ~/Desktop/thumbnail.png.
**Difficulty:** Medium -- needs an image gen API key configured; text overlay via ImageMagick is reliable.
**Demo impact:** High. Visual output from voice input.

### 15. Video Script + Teleprompter
**Wish:** "Genie, write me a 60-second script for a TikTok about Genie, and put it in a teleprompter."
**Execution:** Claude writes a punchy 150-word script. Genie builds a minimal HTML teleprompter page (black bg, large white text, auto-scroll at reading pace) and deploys it to Vercel. Returns the URL so George can open it on his phone while recording.
**Difficulty:** Easy -- Claude can generate the HTML, Vercel deploy already works.
**Demo impact:** Very high. Meta -- using Genie to make content about Genie.

### 16. Remix a Tweet into Multi-Platform Posts
**Wish:** "Genie, take my last tweet and turn it into a LinkedIn post, an Instagram caption, and a Reddit title."
**Execution:** Browser opens X, goes to George's profile, copies the latest tweet text. Claude reformats it three ways: professional tone for LinkedIn (longer, adds context), casual + hashtags for Instagram, punchy question format for Reddit. Returns all three in chat. Optionally posts them.
**Difficulty:** Easy -- just prompt engineering on existing text + existing posting skills.
**Demo impact:** Medium-high. The "content multiplier" angle resonates with creators.

---

## Developer & Technical

### 17. GitHub Issue Triage *
**Wish:** "Genie, go through my open GitHub issues on the genie repo and label them by priority."
**Execution:** Bash runs `gh issue list --repo gtrush/genie --state open --json title,body,number`. Claude analyzes each issue, assigns priority (P0-P3) based on content. Bash runs `gh issue edit N --add-label priority-P0` for each. Returns a summary table.
**Difficulty:** Easy -- entirely CLI-based with gh, no browser needed.
**Demo impact:** High for dev audiences. Shows AI triage at scale.

### 18. Deploy Preview + Lighthouse Audit
**Wish:** "Genie, deploy the current project to a Vercel preview and run a Lighthouse audit."
**Execution:** Bash runs `vercel --yes` to deploy to a preview URL. Then browser navigates to PageSpeed Insights (web.dev/measure), pastes the preview URL, runs the audit. Screenshots the results. Alternatively, runs `npx lighthouse <url> --output json` via Bash and Claude summarizes the scores.
**Difficulty:** Easy -- both tools are already accessible.
**Demo impact:** Medium-high. Full CI-like flow from voice.

### 19. Spin Up a Throwaway API
**Wish:** "Genie, create a JSON API that returns fake user data and deploy it."
**Execution:** Claude writes a minimal Express server (or Hono on Cloudflare Workers) with a `/users` endpoint that returns faker-generated data. Bash runs `npm init`, writes the files, deploys to Vercel or Cloudflare. Returns the live API URL.
**Difficulty:** Easy -- build + deploy already works.
**Demo impact:** High. "I have a live API in 30 seconds" is a strong dev demo.

### 20. Database Schema from Description
**Wish:** "Genie, create a Supabase database with tables for users, posts, and comments, with proper foreign keys."
**Execution:** Claude generates SQL migration. Bash runs it against Supabase via `supabase db push` or the Supabase Management API. Alternatively, browser opens Supabase dashboard SQL editor, pastes and runs the migration. Returns the schema diagram.
**Difficulty:** Medium -- needs Supabase CLI configured or dashboard login.
**Demo impact:** High for technical demos.

---

## Travel & Lifestyle

### 21. Airbnb Search + Book *
**Wish:** "Genie, find me an Airbnb in Hudson Valley for this weekend under $200/night with a hot tub."
**Execution:** Browser opens airbnb.com, enters "Hudson Valley, NY", sets check-in/check-out to this Fri-Sun, filters price max $200, searches amenities for "hot tub". Scrolls through results, screenshots top 3 options with prices. Asks for confirmation before booking. On confirm, clicks "Reserve", goes through the payment flow with saved payment method.
**Difficulty:** Hard -- Airbnb has aggressive anti-automation, complex dynamic UI, and multi-step booking.
**Demo impact:** Extreme. Booking a weekend getaway by voice is peak concierge.

### 22. Flight Search Summary
**Wish:** "Genie, find me the cheapest round-trip flight NYC to Miami next weekend."
**Execution:** Browser opens Google Flights (google.com/travel/flights), enters JFK > MIA, sets dates, waits for results to load, screenshots the top 5 cheapest options. Claude summarizes: airline, times, price, stops. Returns in chat.
**Difficulty:** Medium -- Google Flights is JavaScript-heavy but scrapeable; booking is a separate harder step.
**Demo impact:** High. Travel search from voice feels futuristic.

### 23. Gym Class Booking
**Wish:** "Genie, book me into the 7am CrossFit class tomorrow at my gym."
**Execution:** Browser opens the gym's booking platform (ClassPass, Mindbody, or gym-specific site), navigates to tomorrow's schedule, finds the 7am CrossFit slot, clicks "Book". Screenshots confirmation.
**Difficulty:** Medium -- varies wildly by gym platform.
**Demo impact:** Medium. Niche but relatable.

---

## Finance & Business

### 24. Invoice from Conversation *
**Wish:** "Genie, invoice John at Acme Corp $2,500 for the website I built. His email is john@acme.com."
**Execution:** Browser opens Stripe dashboard > Invoices > Create Invoice. Fills customer email (john@acme.com), adds line item ("Website Development" - $2,500), sends the invoice. Screenshots the sent invoice. Returns the Stripe invoice URL.
**Difficulty:** Easy -- Stripe dashboard flow is clean; already logged in.
**Demo impact:** Very high. "I just invoiced a client with my voice" is a freelancer's dream clip.

### 25. Expense Tracker Entry
**Wish:** "Genie, log that I spent $47 on dinner at Carbone, categorize it as client entertainment."
**Execution:** Bash appends a row to a local CSV or Google Sheet (via browser: opens sheets.google.com, navigates to the "Expenses" sheet, adds a new row with date, amount, vendor, category). Alternatively, creates a structured JSON log locally.
**Difficulty:** Easy with local CSV, Medium with Google Sheets browser flow.
**Demo impact:** Medium. Practical but not flashy.

### 26. Competitor Price Check
**Wish:** "Genie, check what Jasper, Copy.ai, and Writesonic charge for their pro plans."
**Execution:** WebFetch hits each competitor's pricing page. Claude extracts the plan names and prices. Formats a comparison table. Optionally saves to Notion or a local markdown file.
**Difficulty:** Easy -- pure research, no browser login needed.
**Demo impact:** Medium-high. Business intelligence from voice.

---

## Wild / Moonshot Ideas

### 27. Chain Wishes (Macro Mode) *
**Wish:** "Genie, every Monday morning: check my GitHub notifications, summarize them, post a weekly update tweet, and send the summary to my Telegram."
**Execution:** Genie saves this as a recurring "macro" -- a JSON config with steps and a cron schedule. A background process (launchd on macOS or a simple node cron) triggers the wish chain weekly. Each step is a normal Genie capability executed in sequence.
**Difficulty:** Hard -- needs a scheduler, state persistence, and error handling for multi-step chains.
**Demo impact:** Extreme. Autonomous agent running on a schedule is the AGI fantasy.

### 28. Live Deal Negotiation Bot
**Wish:** "Genie, go to that Facebook Marketplace listing for the couch and offer $300."
**Execution:** Browser opens the Facebook Marketplace listing URL, clicks "Message Seller", types "Hi, would you take $300 for this?", sends. Monitors for replies (polls every few minutes). When seller responds, Claude drafts a counter-response and asks George for approval before sending.
**Difficulty:** Hard -- Facebook Messenger automation is fragile; needs a polling loop.
**Demo impact:** Very high. AI negotiating on your behalf is cinematic.

### 29. Clone and Remix Any Website
**Wish:** "Genie, clone the landing page of linear.app but make it about my product and deploy it."
**Execution:** WebFetch downloads linear.app's HTML/CSS. Claude analyzes the structure and rewrites the copy, colors, and branding to match George's product. Saves the files locally. Deploys to Vercel. Returns the live URL.
**Difficulty:** Medium -- WebFetch + Claude rewrite + deploy are all existing capabilities. Quality of the clone varies.
**Demo impact:** Extreme. "I stole Linear's design with my voice" is a viral clip.

### 30. Multi-Agent Delegation
**Wish:** "Genie, I need a landing page, a Stripe checkout, and a tweet announcing it. Do all three."
**Execution:** Genie decomposes the wish into three parallel sub-tasks. Spawns three Claude Code subprocesses: one builds the site, one creates the Stripe payment link, one drafts the tweet. Waits for all three to complete. The tweet includes the site URL and payment link. Posts the tweet. Returns all three URLs.
**Difficulty:** Hard -- needs subprocess orchestration, dependency resolution (tweet depends on the other two finishing), and result aggregation.
**Demo impact:** Maximum. Three things happening simultaneously from one sentence is the "10x" demo.

---

## Summary: Top 10 (Starred)

| # | Capability | Difficulty | Demo Factor |
|---|-----------|-----------|-------------|
| 2 | Stripe Subscription Setup | Easy | Ship a SaaS by voice |
| 5 | Twitter Thread from Voice | Easy | Voice-to-published-thread |
| 8 | Telegram Send | Easy | Close the automation loop |
| 9 | OpenTable Reservation | Medium | AI concierge fantasy |
| 12 | Notion Research Page | Medium | Research-to-docs pipeline |
| 13 | Blog Post + Publish | Medium | Voice-to-article |
| 17 | GitHub Issue Triage | Easy | Dev audience loves this |
| 24 | Invoice from Conversation | Easy | Freelancer dream |
| 27 | Chain Wishes (Macros) | Hard | Autonomous agent on schedule |
| 29 | Clone + Remix Website | Medium | Viral demo potential |
