# Genie × JellyJelly — Product & Integration Brief

**Author:** Research agent for George Trushevskiy
**Date:** April 4, 2026
**Subject:** Can Genie — a voice-triggered autonomous agent prototype — become a native JellyJelly feature?

---

## 1. JellyJelly context

JellyJelly is a NYC-based "human social network" launched in early 2025 by Venmo co-founder Iqram Magdon-Ismail with early-investor-turned-co-founder Sam Lessin. Its pitch is anti-algorithm, anti-AI-slop, raw short video ("jellies") captured with front+back cameras simultaneously, BeReal-style, with automatic Deepgram transcription, AI summaries, and captions layered on top ([Tubefilter](https://www.tubefilter.com/2025/03/20/are-you-ready-for-this-jellyjelly-venmo-co-founders-new-app-is-tiktok-meets-bereal-with-a-memecoin-twist/), [jellyjelly.com/manifesto](https://jellyjelly.com/manifesto)).

The product feel today: an iOS app with a public timeline, event coverage (SXSW, NYCxDESIGN), a "Global Founding Users Community," and a Wobbles plushie as merch. As of January 2, 2026 they removed follower gates and opened UGC to all creators ([App Store listing](https://apps.apple.com/us/app/jellyjelly-post-povs-earn/id6505022038)).

Monetization is unusual and load-bearing: a Solana memecoin, **JELLYJELLY**, launched via Pump.fun in January 2025, hit ~$250M market cap, and acts as the rails for "decentralized" creator payouts — holders get early app access, users earn tokens for posting and engagement ([Decrypt](https://decrypt.co/303551/venmo-founders-jellyjelly-solana-token), [MEXC](https://blog.mexc.com/what-is-jelly-my-jelly/)). Roughly half of reported users hold the coin. Backed by Betaworks (hence the MischiefClaw hackathon series that birthed Genie).

Their public positioning is *explicitly anti-AI-content*: the manifesto trashes "AI slop" and insists "everything you see is real." But they carve out an exception for AI that "uplifts real work" — captions, summaries, transcription. This is the crack Genie slips through: Genie doesn't generate fake content, it executes real actions on behalf of a real human speaking into a real camera. That framing matters enormously for whether the founders would ever greenlight it.

User base is early-adopter crypto-adjacent creators; roadmap signals are creator-payout focused, with no disclosed agent/automation features today. No institutional VC disclosed beyond Betaworks + the token treasury.

## 2. The integration surface

**Trigger placement.** The universal-keyword model George built ("say the word 'genie'") is actually the right default for JellyJelly specifically, because every jelly already ships with a word-level Deepgram transcript server-side — zero new UI required. But universal-by-default is a moderation landmine (see §6). The shippable compromise is a **three-tier trigger**:

1. **Opt-in account toggle**: "Enable Genie" in settings. Off by default. Creator must confirm they understand real-world actions will happen.
2. **Per-clip arm**: a lamp/wand icon on the record screen that lights up only if the toggle is on. Tapping it arms Genie for *that jelly only*. This avoids the "I said 'genie' as a joke" misfire problem.
3. **Keyword in-transcript**: the word "genie" within an armed clip is what actually fires execution. Keeps George's elegant server-side poll pattern intact.

**Results surface.** A dedicated in-app thread per wish, titled with the jelly it came from, showing Genie's text updates + screenshots as a timeline. Push notification on completion. A **"Wishes" tab** in the user's profile — the log becomes content. This is the crucial insight: *the reports themselves are shareable jellies*. Genie completing an Uber Eats order on-camera is content JellyJelly doesn't have today. Don't bury it in DMs.

**Discoverability.** Ship to 100% of users as *visible but gated*. Everyone sees the Genie button. Everyone sees other people's wish-results in the public timeline. Only paid/approved users can actually fire one. Social proof does the growth work; paywall does the unit economics.

**One-way vs two-way.** Keep George's one-way discipline as the **default** but let users send follow-up voice clips into the same wish-thread to clarify ("actually make it Heineken Light, not 0.0"). No text replies — that breaks the magic of "speak into a camera, things happen." Voice-only replies keep the format honest and feed back into the same Deepgram pipeline they already run. This is JellyJelly's wedge over Operator/ChatGPT: *the input modality is a short video, not a chat box.*

**Moderation line.** Hard no on: targeting real non-consenting individuals (the "send flowers to my ex" wish), financial transfers to third parties, anything a human moderator wouldn't approve in <5 seconds. Soft yes with confirmation step on: purchases over $X, public posts on user's connected accounts, any code deploy to a public URL. Genie should pause and DM a "tap to confirm" before any irreversible action above a threshold. George's current yolo-mode is fine for George; at scale it is not.

## 3. Competitive / category landscape

The category Genie occupies is **"voice-in, real-world-action-out autonomous agents."** Adjacent but distinct from everything below.

**Rabbit R1 / Humane AI Pin.** Both shipped voice-triggered agent hardware in 2024; both are effectively dead. Humane was acquired by HP for $116M in Feb 2025 (vs $200M raised), and the AI Pin was **bricked** on Feb 28, 2025 — no user can use it anymore ([Jason Deegan](https://jasondeegan.com/why-humanes-ai-pin-and-rabbit-r1-both-flopped-spectacularly/), [TechRadar](https://www.techradar.com/computing/artificial-intelligence/with-the-humane-ai-pin-now-dead-what-does-the-rabbit-r1-need-to-do-to-survive)). Rabbit R1 sold 100K units but had 5K active users 5 months in — a 95% abandonment rate ([Everyday AI Tech](https://www.everydayaitech.com/en/articles/ai-gadgets-flop-2025)). **Lesson for JellyJelly: don't ship hardware. Don't create a new user base. Attach to something people already use daily.** This is literally the argument for building Genie into JellyJelly rather than as a standalone app.

**ChatGPT Operator / Agent.** $200/mo Pro tier, ~400 agent runs/mo on Plus ([Scalevise](https://scalevise.com/resources/chatgpt-agents-features-pricing-explained/), [TechCrunch](https://techcrunch.com/2025/01/23/openais-agent-tool-will-be-available-to-users-paying-200-per-month-for-pro/)). Fully capable of ordering groceries, reserving restaurants, filling forms. The overlap with Genie is enormous in *capability*. The non-overlap is **input modality and persistence of context**: Operator is a chat-box you go to; Genie is a camera-first trigger attached to a pre-logged-in identity (LinkedIn, Gmail, Stripe, X). You already are who you are on JellyJelly. You don't log into Genie.

**Claude Computer Use / Sonnet 4.6.** The actual brain inside Genie. Claude Sonnet 4.6 (Feb 2026) topped agentic benchmarks with enhanced computer use and a 1M-token context at standard per-token rates ([Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing)). So JellyJelly would be renting the same brain anyone else can rent — the moat is NOT the model.

**Manus, Devin, Lindy, Relay.** Manus: $19–$199/mo credit-based, acquired by Meta for $2B in Dec 2025 ([Lindy blog](https://www.lindy.ai/blog/manus-ai-pricing)). Devin 2.0: dropped from $500/mo to $20/mo entry in April 2025, priced per ACU (~15 min of work). Lindy: visual no-code agent builder for business workflows. None of these are consumer. None are voice-in. None are social. **They're all tools-for-professionals; Genie is an act-of-expression-for-normal-humans.** That's the category break.

**Siri Shortcuts / Alexa Skills.** Alexa has 40K+ skills, Siri Shortcuts leverage iOS's 2M app ecosystem ([GeekWire](https://www.geekwire.com/2018/siri-shortcuts-vs-alexa-skills-apple-tapping-apps-compete-amazons-voice-assistant/)). Both taught users "say a thing, get an action." Adoption has been lukewarm precisely because the action space is narrow and the trust is shallow. Genie's action space is *arbitrary* (Claude Code + browser), which is both the power and the risk.

**Short-form video + agent execution.** I found zero products combining these. JellyJelly + Genie would be genuinely first. The wedge is real: **the camera is a commitment device.** Typing "order me beer" in a chat is cheap; saying it on video with your face attached is a public performance, which makes it shareable content, which makes it a growth loop. No other agent product has this loop.

**Is public-video-as-input a wedge or a gimmick?** Wedge. Three reasons: (a) the clip itself is the demo, the audit log, and the marketing asset in one artifact; (b) video creates accountability and social stakes that reduce frivolous/abusive wishes; (c) JellyJelly already has the Deepgram pipeline — the trigger is free infra.

## 4. The business case

**Value per wish.** The three archetypes George has already executed suggest three pricing floors:

- *Content wish* (tweet, LinkedIn post, meme site deploy): replaces ~$20–200 of freelance/VA time. User would pay $2–10.
- *Commerce wish* (Uber Eats order, flight booking, Stripe link): no labor saved, but time + frictionless "drunk camera → delivery" magic. User would pay $1–3 per wish *plus* JellyJelly takes an affiliate cut on the underlying transaction.
- *Build wish* (landing page for "sell my Wobbles for $67", deployed live with payments): this is the G-Wagon-caliber wish. Replaces $500–5,000 of dev work. Premium tier, $20–50 per wish or gated to paid.

**Unit cost per wish.** Claude Sonnet 4.6 is $3/M input, $15/M output, with 1M context at standard rates ([Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing)). A typical agent run chewing through tool calls, screenshots, and browser DOM is plausibly 200K–800K tokens of mixed I/O. Rough order of magnitude: **$1–5 of Claude cost per wish**, plus ~$0.50 of browser-infra (hosted Chrome session, egress, Deepgram is already sunk cost for JellyJelly). Call it **$2–6 fully loaded**. Commerce wishes net positive even with affiliate alone; content/build wishes need a subscription or per-wish charge.

**Pricing model.** Layered:

- **Free tier**: 1 wish/month, content-only, capped actions, no purchases. Growth funnel.
- **Wisher ($15/mo)**: 20 wishes/mo, unlocks purchases up to $50 each, Stripe/X/LinkedIn connects.
- **Genie Pro ($49/mo)**: 100 wishes/mo, unlimited action types, higher spending caps, priority queue, custom skills.
- **Per-wish add-on**: $2 beyond cap.

This matches Manus/Devin tiering but prices under ChatGPT Pro ($200) by a wide margin, positioned as consumer not professional.

**Affiliate upside is the unsung hero.** Uber's affiliate program pays merchants $10/new Eater signup and negotiable commission on transactions ([Uber affiliate](https://www.uber.com/us/en/affiliate-program/)). At scale, if Genie becomes the voice front-end for Uber Eats orders on JellyJelly, the affiliate economics alone could subsidize Claude inference. Same logic for Stripe (payment link referrals), Vercel (hosting referrals), Booking/Airbnb (travel wishes). **Genie turns every public wish-clip into a commerce funnel.** This is the pitch that should make JellyJelly leadership light up — it's not "an AI feature," it's a new revenue surface layered on top of their existing social product.

**Who pays.** End users for convenience/power; merchants (via affiliate) for intent; JellyJelly captures both sides.

## 5. Go-to-market path

**Phase 1 — Private alpha (weeks 1–4).** 20–50 invited creators from the Founding Users Community, hand-picked for high-trust behavior and existing audiences. George personally on-call for failures. Scope: content wishes + pre-approved commerce partners only (Uber Eats, Stripe links, X posts). Metric: wish success rate, time-to-result, viral coefficient of wish-result clips.

**Phase 2 — Feature-flagged beta (weeks 5–10).** Roll to 5–10% of iOS users behind the opt-in toggle. Free tier only. Measure: DAU lift, retention of activated-Genie cohorts, cost per wish, abuse/moderation rate, support load. This is the gate — if cost per wish > willingness to pay, kill it here.

**Phase 3 — Public launch (weeks 11–13).** Hook: **"The first social network where you can wish things into existence on camera."** Demo clip assembly: George's G-Wagons tweet, the Wobbles Stripe landing page, the $108 Uber Eats order with delivery confirmation screenshots. Press angle: Iqram + a 21-year-old hacker built the first agent you don't type to. Betaworks network amplifies. Ship a landing page at genie.jellyjelly.com with a live feed of public wishes being granted in real time.

**Killer demo clip.** 30 seconds. George opens JellyJelly, holds the camera, says "genie, build me a landing page that sells these Wobbles for $67 and deploy it to Vercel." Cut to a push notification buzzing his phone 90 seconds later. Tap. Live URL. Stripe checkout works. End card: "You just watched a wish come true." Post it *on JellyJelly* as the launch jelly. This is the loop — the product's marketing lives inside the product.

## 6. Risks & open questions

**Legal.** Real purchases on user's payment method → full Terms of Service + per-wish confirmation required for any charge. JellyJelly needs an explicit agent-acting-on-your-behalf EULA. Landing pages deployed under user's identity → DMCA + defamation exposure. Mitigation: a hosted subdomain (wishes.jellyjelly.com/username) where JellyJelly controls takedown.

**Privacy.** Public clips become real-world triggers; bystanders captured in the jelly have no opt-in. Hard rule: Genie can only act *on behalf of* the speaking user, never *against* a third party named in the clip.

**Abuse.** "Hey genie, order 500 pizzas to [rival's address]." "Hey genie, post this slur on my X." Moderation must be model-in-the-loop pre-execution, with a refusal taxonomy. Accept the false-positive rate.

**Platform risk.** LinkedIn explicitly bans automation in ToS §8.2 and permabanned Apollo.io and Seamless.ai in March 2025 ([Growleads](https://growleads.io/blog/linkedin-automation-ban-risk-2026-safe-use/)). X is softer but unpredictable. Uber Eats is fine as long as it's a real human session, not scaled scraping. **Genie cannot scale to millions of users sharing one persistent-login Chrome** — each user needs their own session, which means real account health management. This is the hardest unsolved engineering problem.

## 7. Final recommendation

**Ship it.** JellyJelly should absolutely integrate Genie — but as a **gated, opt-in, tiered feature**, not a universal keyword. The wedge is genuine: no competitor combines short-form video input with real-world agent output, and the camera-as-commitment-device creates a growth loop (wishes become content become demos become signups) that no chat-box agent can replicate. The Humane/Rabbit lesson — don't build new hardware or new user bases — is exactly the argument for doing this *inside* an app with existing distribution instead of as a standalone Genie app.

**90-day plan:** Weeks 1–2, George + 1 JellyJelly engineer harden the prototype into a multi-tenant service (per-user browser sessions, confirmation flow, moderation layer). Weeks 3–6, private alpha with 30 Founding Users. Weeks 7–10, feature-flagged beta at 5% with free tier + $15 Wisher plan live. Weeks 11–13, public launch with the G-Wagons/Wobbles/Uber Eats demo reel as the launch jelly.

**What would change my mind:** if in alpha the per-wish cost exceeds $8 fully loaded, or if >5% of wishes require human moderator intervention, or if LinkedIn/X bans start hitting alpha accounts at >1/week. Any of those means the unit economics or platform risk kills it before scale. Otherwise: this is the most interesting thing JellyJelly could possibly ship in 2026, and the category is wide open for exactly 6–12 months before OpenAI or Meta-via-Manus figures out the video-input angle.

---

**Sources**
- [Tubefilter — JellyJelly launch coverage](https://www.tubefilter.com/2025/03/20/are-you-ready-for-this-jellyjelly-venmo-co-founders-new-app-is-tiktok-meets-bereal-with-a-memecoin-twist/)
- [JellyJelly manifesto](https://jellyjelly.com/manifesto)
- [JellyJelly homepage](https://jellyjelly.com/)
- [Decrypt — JellyJelly Solana token](https://decrypt.co/303551/venmo-founders-jellyjelly-solana-token)
- [MEXC — Jelly-my-jelly guide](https://blog.mexc.com/what-is-jelly-my-jelly/)
- [App Store — JellyJelly iOS](https://apps.apple.com/us/app/jellyjelly-post-povs-earn/id6505022038)
- [Jason Deegan — Why Humane and Rabbit flopped](https://jasondeegan.com/why-humanes-ai-pin-and-rabbit-r1-both-flopped-spectacularly/)
- [TechRadar — Humane AI Pin dead](https://www.techradar.com/computing/artificial-intelligence/with-the-humane-ai-pin-now-dead-what-does-the-rabbit-r1-need-to-do-to-survive)
- [Everyday AI Tech — AI gadget flops 2025](https://www.everydayaitech.com/en/articles/ai-gadgets-flop-2025)
- [Scalevise — ChatGPT Agents pricing](https://scalevise.com/resources/chatgpt-agents-features-pricing-explained/)
- [TechCrunch — OpenAI Operator Pro $200](https://techcrunch.com/2025/01/23/openais-agent-tool-will-be-available-to-users-paying-200-per-month-for-pro/)
- [Anthropic — Claude API pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Lindy — Manus AI pricing 2026](https://www.lindy.ai/blog/manus-ai-pricing)
- [MCPlato — Devin vs Manus vs Claude Code 2026](https://mcplato.com/en/blog/ai-agent-2026-comparison/)
- [GeekWire — Siri Shortcuts vs Alexa Skills](https://www.geekwire.com/2018/siri-shortcuts-vs-alexa-skills-apple-tapping-apps-compete-amazons-voice-assistant/)
- [Growleads — LinkedIn automation ban risk 2026](https://growleads.io/blog/linkedin-automation-ban-risk-2026-safe-use/)
- [Uber affiliate program](https://www.uber.com/us/en/affiliate-program/)
