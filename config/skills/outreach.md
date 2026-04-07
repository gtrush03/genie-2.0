# LinkedIn / Twitter / Gmail Outreach

All outreach goes via Playwright MCP against the pre-logged-in Chrome.

## Flow

1. `mcp__playwright__browser_navigate` to e.g. `https://www.linkedin.com/search/results/people/?keywords=<name>`
2. `mcp__playwright__browser_snapshot` to see the page
3. Click the right profile, send a connection request with a personalized note, OR compose a message
4. Screenshot the result with `mcp__playwright__browser_take_screenshot`. **IMPORTANT:** the Playwright MCP only allows writing under the repo's `.playwright-mcp/` directory or the repo root. Save screenshots to `.playwright-mcp/<name>.png` (relative to repo root). Do NOT try to write to `/tmp/` — it will fail with "File access denied".
5. Send the screenshot to George via Telegram `sendPhoto`

## Quality bar

Personalize every outreach message. No generic "Hi, I'd love to connect". Reference something specific from their profile or George's transcript. George's outreach should feel like it came from a thoughtful human, not a bot.

## Platform-specific notes

- **LinkedIn:** Search → Profile → "Connect" or "Message". For connection requests, always add a note.
- **Twitter/X:** Navigate to `https://x.com/compose/tweet` or DM via `https://x.com/messages/compose`
- **Gmail:** Navigate to `https://mail.google.com/mail/u/0/#inbox?compose=new`
