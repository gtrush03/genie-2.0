# 06 — User Onboarding & Account Management

**Status:** Design spec
**Audience:** Engineering, product, design
**Constraint:** Every screen must feel like a consumer app. No terminal output. No config files. No jargon.

---

## 1. First Launch Experience

The user has downloaded Genie.dmg (or .exe), installed it, and double-clicks the icon for the first time.

### Screen 1: Splash (2 seconds, no interaction)

Full-screen dark background (#0A0A0A). A single gold lamp icon fades in at center, emits a soft particle shimmer, then dissolves into the wordmark "Genie" in a clean serif. No loading bar. The shimmer IS the loading indicator.

### Screen 2: Onboarding Carousel (3 cards, swipeable or auto-advance)

Each card is full-bleed with a looping 4-second video clip and a single line of copy below it.

**Card A — "Say it. It happens."**
Video: someone holding a phone, speaking into a JellyJelly clip. A tweet appears on screen behind them. A delivery notification buzzes. A landing page deploys.
Copy: "Genie watches your JellyJelly clips and turns your words into real actions."

**Card B — "Your accounts. Your control."**
Video: a grid of service tiles (X, Uber Eats, LinkedIn, Gmail) lighting up green one by one.
Copy: "Connect the services you use. Genie acts on your behalf, only when you ask."

**Card C — "One wish at a time."**
Video: a wish timeline — the spoken words transcribed, then steps appearing (Ordered, Deployed, Posted), ending with a Telegram notification on a phone.
Copy: "You get a full report with screenshots and receipts. Every time."

CTA button at bottom of Card C: **"Get Started"** (gold, full-width).

### Screen 3: Account Creation

Centered card on dark background. Three sign-in options stacked vertically:

1. **Continue with Apple** (native Apple Sign-In, one tap on macOS)
2. **Continue with Google** (Google OAuth popup)
3. **Sign up with email** (expands to email + password fields inline)

No JellyJelly OAuth at launch — their API does not expose an auth flow for third parties. We connect JellyJelly accounts in the next step via username lookup, not login.

Below the options: "Already have an account? **Sign in**" link.

**Why Apple + Google first:** Desktop app users on macOS overwhelmingly have an Apple ID. Google covers the rest. Email/password is the fallback, not the default. Reduce friction on the first gate.

### Screen 4: Free Tier Auto-Assignment

After account creation, no billing screen. The user lands directly on:

> "You're on the **Starter** plan — 3 free wishes per month."
> "Upgrade anytime for more wishes and premium services."

A small "View plans" link (not a button — do not pressure). The user should feel welcomed, not upsold. Billing lives in Settings for when they are ready.

---

## 2. JellyJelly Connection

Immediately after account creation, the app transitions to a single-purpose screen.

### Screen 5: Connect JellyJelly

Header: "Which JellyJelly account should Genie listen to?"

**Input field:** "@" prefix, placeholder text "your JellyJelly username". The user types their username. Below the field, a helper line: "This is the name that appears on your JellyJelly profile."

When the user types and hits Enter:
- Genie calls the JellyJelly search API to verify the username exists.
- If found: shows the user's JellyJelly avatar and display name. "Is this you?" with **Confirm** / **Try another** buttons.
- If not found: "We couldn't find that username on JellyJelly. Double-check the spelling."

**After confirmation:**
Genie displays a verification step. The user records a short JellyJelly clip saying "Genie, connect my account" (or any clip containing the keyword "genie"). Genie polls for it, detects it via the firehose, and matches it to the claimed username. This proves ownership — only the real account holder can post clips from that account.

Success state: green checkmark, "Connected! Genie is now listening to your clips." Auto-advances after 2 seconds.

**Skip option:** "I don't have JellyJelly yet" link at bottom. Takes the user to the dashboard where they can type wishes directly (see Section 5, Option B). The JellyJelly connection prompt reappears gently in Settings.

---

## 3. Service Connection Flow

### Screen 6: Service Grid

Header: "Connect your accounts"
Subheader: "Genie uses these to act on your behalf. Connect as many or as few as you want."

A 3-column grid of service tiles, each showing:
- Service icon (full color)
- Service name
- One-line capability description
- Status indicator (gray = not connected, green = connected)

**Tile layout:**

| Tile | Description |
|------|-------------|
| X (Twitter) | "Post and reply on your behalf" |
| LinkedIn | "Send connection requests, post updates" |
| Gmail | "Compose and send emails" |
| Uber Eats | "Order food and groceries" |
| GitHub | "Create repos, push code" |
| Vercel | "Deploy websites and apps" |
| Stripe | "Create payment links" |
| OpenTable | "Make restaurant reservations" |
| Airbnb | "Search and book stays" |
| Notion | "Create and edit documents" |
| Calendly | "Schedule meetings" |
| Venmo | "Send and request payments" |

**Connection behavior per service type:**

**OAuth services (X, LinkedIn, Gmail, GitHub, Stripe):**
User clicks tile. A native OS browser window (not a webview — for security trust) opens the OAuth consent screen. "Allow Genie to [specific permission] on your behalf?" User clicks Allow. Browser redirects to `genie://callback?code=...`. The app catches the deep link, exchanges the code for tokens, stores them encrypted. Tile turns green. The browser window closes automatically.

**Browser-session services (Uber Eats, OpenTable, Airbnb, Venmo, Notion, Calendly):**
User clicks tile. The app opens a managed webview (Tauri webview or Electron BrowserWindow) showing the service's login page. A banner at top of the webview reads: "Log in normally. Genie saves your session so it can act for you later." User logs in with their real credentials. Genie detects successful login by checking for authenticated cookies/redirects. Webview closes. Tile turns green.

**Each connected tile shows:**
- Green dot + "Connected"
- Small "Disconnect" link (click to revoke)
- Last used timestamp after first wish

**Bottom of grid:** "Skip for now — you can connect services anytime from Settings." Full-width CTA: **"Continue"** (enabled whether or not any services are connected).

---

## 4. Notification Setup

### Screen 7: How should Genie reach you?

Three options presented as large selectable cards (radio-style, pick one as primary):

**Option A: In-App Notifications (recommended, pre-selected)**
Icon: bell. "Get notified right here in the Genie app. Includes screenshots and full reports."
Requires: macOS notification permission (system prompt fires on selection).
This is the default. Zero setup. Works immediately.

**Option B: Telegram**
Icon: paper plane. "Get reports in Telegram with rich previews."
On selection, expands to show:
1. A QR code that deep-links to `t.me/GenieWishBot?start=<user-token>`
2. Text alternative: "Or search for @GenieWishBot on Telegram and send /start"
3. Once the user messages the bot, Genie captures the chat_id via webhook and confirms: "Telegram connected" with a green check.

**Option C: Email**
Icon: envelope. "Get a summary email after each wish."
On selection: "We'll send reports to [their signup email]. Change in Settings."
No additional setup.

**Launch priority:** Ship all three. In-app is trivial (local notification API). Telegram is already built. Email is a Resend/Postmark API call with a template. None are hard. Let the user pick what feels natural.

**SMS:** Not at launch. Cost is $0.01-0.05 per message via Twilio, adds phone number collection to onboarding (friction), and the message format is too constrained for wish reports with screenshots. Add in v2 only if user research shows demand.

CTA: **"Continue"**

---

## 5. First Wish Guided Experience

### Screen 8: Make Your First Wish

This is the main dashboard, but on first visit it has a guided overlay.

Center of screen: a large text input with a microphone button, styled like a search bar but warmer — rounded, glowing border, placeholder text cycling through examples:
- "Order me a coffee from the nearest cafe..."
- "Post about what I'm working on today..."
- "Build a landing page for my new project..."
- "Make a dinner reservation for two tonight..."

**Three input modes, toggled by subtle icons on the input bar:**

1. **Type** (keyboard icon, default): User types a wish in plain language. Lowest friction for first-timers.
2. **Speak** (microphone icon): Tap to record. Waveform animation while recording. Tap again to stop. Transcription appears in the text field. User can edit before submitting.
3. **JellyJelly** (lamp icon): "Record a JellyJelly clip and say 'Genie, ...'" — this is the "real" way but requires the JellyJelly app. A reminder card, not an input mode.

**Below the input bar:** "Suggested first wishes" — a horizontal carousel of 4 clickable cards:

| Card | Wish text | Why it's good for first-timers |
|------|-----------|-------------------------------|
| "Order a coffee" | "Order me a drip coffee from the closest cafe on Uber Eats" | Tangible, fast, small dollar amount |
| "Post something" | "Post a tweet saying I'm trying out Genie and it's wild" | Visible result, shareable |
| "Build a page" | "Build me a simple landing page for my side project" | Impressive, demonstrates power |
| "Send an email" | "Draft and send an email to [contact] about catching up" | Practical, immediately useful |

Clicking a suggestion card fills the input bar with that text (editable).

### First Wish Execution View

User submits their wish. The screen transitions to a **wish timeline** — a vertical feed showing Genie's progress in real-time:

```
[timestamp] Understanding your wish...
[timestamp] Planning: Order drip coffee from nearest cafe
[timestamp] Opening Uber Eats...
[timestamp] Searching for "drip coffee"...
            [live screenshot of Uber Eats in the managed browser]
[timestamp] Found: Blue Bottle Coffee - Drip Coffee $4.50
[timestamp] Adding to cart...
[timestamp] Checking out...
[timestamp] Order placed! Estimated delivery: 25 min
            [screenshot of order confirmation]
```

Each step appears with a gentle slide-in animation. Screenshots are inline, not attachments. The user watches their wish come true in real time — this is the magic moment.

At completion, a summary card:

> **Wish granted**
> Ordered: Drip Coffee from Blue Bottle Coffee
> Total: $4.50 + $2.00 tip
> Delivery: ~25 minutes
> [View full report]

---

## 6. Account Settings / Dashboard

After onboarding, the app has three main views accessible from a left sidebar:

### Wish Bar (Home)
The input bar from Screen 8, plus a feed of recent wishes below it. Each wish card shows: the original text, status (in progress / completed / failed), timestamp, cost, and a thumbnail of the result. Click to expand into the full timeline view.

### Connected Services (Settings > Services)
The same grid from Screen 6, but now showing live status. Each tile displays:
- **Green** = healthy, last verified < 6 hours ago
- **Yellow** = token expiring soon or last health check ambiguous
- **Red** = disconnected, needs re-auth
- Last used date
- [Reconnect] button for yellow/red, [Disconnect] for green

### Billing (Settings > Plan)
Current plan card showing:
- Plan name and price
- Wishes used this month: "7 of 20"
- Progress bar
- Per-wish cost beyond cap: $2
- Total spend this month: $14.00
- [Upgrade] / [Manage payment method] buttons

Payment method: Stripe-powered. User adds a card once. Charges happen at end of billing cycle (wishes used x rate), not per-wish in real time. The free tier never charges — it simply blocks wishes beyond 3/month with a gentle "Upgrade to keep wishing" prompt.

### Preferences (Settings > Preferences)
- **Default tip %**: slider, 15-25%, default 20%
- **Posting style**: dropdown — "Casual", "Professional", "Match my voice" (Genie analyzes past clips for tone)
- **Design aesthetic**: for build wishes — "Dark & minimal", "Clean & bright", "Bold & colorful"
- **Spending cap per wish**: $0 (confirm every purchase), $25, $50, $100, custom
- **Confirmation behavior**: "Always confirm before purchasing" / "Auto-approve under $[amount]" / "Ask me only for new services"

### Notification Settings (Settings > Notifications)
Toggle per channel (in-app, Telegram, email). Choose which events trigger notifications: wish started, wish completed, wish failed, service disconnected, billing alert.

### Privacy & Data (Settings > Privacy)
- **Export my data**: generates a ZIP of all wish history, connected services (no tokens), and preferences. Download link emailed.
- **Delete my account**: red button, confirmation modal: "This will disconnect all services, delete your wish history, and revoke all tokens. This cannot be undone." 7-day grace period before actual deletion.
- **Wish visibility**: "Allow Genie to use anonymized wish patterns to improve the service" toggle (opt-out, default on).

### Teach Genie (Settings > Teach Genie)
A freeform text area: "Tell Genie things it should always remember about you."
Examples shown as placeholder text:
- "I'm vegetarian"
- "My girlfriend's name is Sarah"
- "I prefer window seats on flights"
- "Never post anything political"

Saved as a persistent context block that gets injected into every wish execution. Editable anytime.

---

## 7. Service Health Monitoring

### Background Health Checks

Every 6 hours, the app runs a silent health sweep:

**OAuth services:** Attempt a lightweight authenticated API call (e.g., `GET /2/users/me` for X). If 401, mark as red. If token refresh succeeds silently, stay green. If refresh fails, mark as yellow and schedule a retry in 1 hour before going red.

**Browser-session services:** Load an authenticated page in a headless context and check for login redirects. If redirected to login, mark as red.

### Notification on Failure

When a service goes red:
- In-app: a badge appears on the Services section of the sidebar. The tile pulses gently.
- Push notification (if enabled): "Your X connection expired. Tap to reconnect."
- Telegram (if enabled): "Your X session needs a refresh. Open Genie to reconnect."

### During Wish Execution

If Genie hits a login wall mid-wish:
1. The wish timeline shows: "Could not access X — your session has expired."
2. The wish continues with remaining services (does not abort entirely).
3. The completion report notes: "Skipped: Post to X (session expired). Reconnect in Settings."
4. The X tile goes red in the dashboard.

No silent failures. No ambiguity about what happened.

---

## 8. Multi-Device Story

### What Syncs (via Genie cloud account)

- Account identity and billing
- Wish history and reports
- Preferences and "Teach Genie" context
- Notification channel configuration
- JellyJelly username link

### What Does NOT Sync

- Connected service sessions (browser cookies are per-machine)
- OAuth tokens (generated per-device for security — revoking on one machine should not break another)

### Behavior

User has Genie on a MacBook and an iMac:
- Both machines show the same wish history and billing.
- The MacBook might have X and Uber Eats connected. The iMac might have LinkedIn and Gmail.
- A JellyJelly-triggered wish routes to whichever machine is online and has the required services connected. If both are online, the app that most recently passed a health check wins.
- If no machine is online with the required service, the wish queues and the user gets a notification: "Genie needs your [MacBook] online to complete this wish (X is connected there)."

### First Launch on Second Device

User installs Genie on a new machine, signs in with their existing account. They see:
- Their wish history (synced)
- Their preferences (synced)
- An empty service grid: "Connect your accounts on this device"
- A note: "Services you connected on other devices stay active there. Connect the ones you want to use from this machine."

No confusion. No expectation that logging into X on one machine means it works everywhere.

---

## Summary: Onboarding Flow Duration

| Step | Screen | Time |
|------|--------|------|
| Splash + carousel | Screens 1-2 | 15 seconds |
| Account creation | Screen 3-4 | 30 seconds (Apple Sign-In) to 90 seconds (email) |
| JellyJelly connection | Screen 5 | 60 seconds (including verification clip) |
| Service connections | Screen 6 | 2-5 minutes (depends on how many) |
| Notification setup | Screen 7 | 15 seconds |
| First wish | Screen 8 | 30 seconds to type, 1-5 minutes to execute |

**Total: Under 10 minutes from download to first wish granted.** The critical path (account + first typed wish) is under 2 minutes if the user skips JellyJelly connection and service setup.
