#!/usr/bin/env node
// Real wish execution: replay a JellyJelly clip through the full Genie pipeline.
// Clip: 01KNJ8EJWJ8CC1YTPA9PMA4HMG — "Suggesting a Personal Website with Pricing Tiers"

import { dispatchToClaude } from '../src/core/dispatcher.mjs';

console.log('🧞 Executing real JellyJelly wish through Claurst engine...\n');

const result = await dispatchToClaude({
  transcript: "Genie, can you make a website about yourself and actually have some sort of a pricing tier thing with, like, live stripling so people can buy something from you? Yeah. Figure it out and, introduce yourself to the world.",
  clipTitle: "Suggesting a Personal Website with Pricing Tiers",
  creator: "georgy",
  clipId: "01KNJ8EJWJ8CC1YTPA9PMA4HMG",
  keyword: "genie",
});

console.log('\n=== DISPATCH RESULT ===');
console.log(`Success: ${result.success}`);
console.log(`Session: ${result.sessionId}`);
console.log(`Turns: ${result.turns}`);
console.log(`Cost: $${(result.usdCost ?? 0).toFixed(4)}`);
console.log(`Duration: ${(result.durationMs / 1000).toFixed(1)}s`);
console.log(`Exit code: ${result.exitCode}`);
if (result.error) console.log(`Error: ${result.error}`);

process.exit(result.success ? 0 : 1);
