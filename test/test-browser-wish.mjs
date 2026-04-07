#!/usr/bin/env node
// Browser + website wish: browse real sites, scrape data, build a beautiful page.
// Tests: Playwright MCP navigation, snapshots, data extraction → Vercel deploy.

import { dispatchToClaude } from '../src/core/dispatcher.mjs';

console.log('🧞 Executing browser + website wish through Claurst engine...\n');

const result = await dispatchToClaude({
  transcript: "Hey Genie, go to the NASA Astronomy Picture of the Day website, grab today's image and description, then go to Hacker News and grab the top 5 stories with their links and scores. Take screenshots of both sites. Then build me a gorgeous dark-mode dashboard website called Daily Briefing that shows the NASA photo of the day on one side and the top Hacker News stories on the other side, with the actual links. Make it look premium, like an obsidian glass dashboard. Deploy it to Vercel and send me everything.",
  clipTitle: "Browser Research → Beautiful Dashboard Site",
  creator: "georgy",
  clipId: `browser-test-${Date.now()}`,
  keyword: "genie",
});

console.log('\n=== DISPATCH RESULT ===');
console.log(`Success: ${result.success}`);
console.log(`Session: ${result.sessionId}`);
console.log(`Turns: ${result.turns}`);
console.log(`Cost: $${(result.usdCost ?? 0).toFixed(4)}`);
console.log(`Duration: ${(result.durationMs / 1000).toFixed(1)}s`);
if (result.error) console.log(`Error: ${result.error}`);

process.exit(result.success ? 0 : 1);
