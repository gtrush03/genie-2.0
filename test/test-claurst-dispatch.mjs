#!/usr/bin/env node
// Integration test: dispatchToClaude() → Claurst → Telegram
// Sends a simple wish through the full pipeline.

import { dispatchToClaude } from '../src/core/dispatcher.mjs';

const result = await dispatchToClaude({
  transcript: 'Hey genie, just say hello on Telegram and tell me the current date and time. That is all.',
  clipTitle: 'Integration Test',
  creator: 'gtrush',
  clipId: `test-${Date.now()}`,
  keyword: 'genie',
});

console.log('\n=== DISPATCH RESULT ===');
console.log(JSON.stringify(result, null, 2));

if (result.success) {
  console.log('\n✅ Integration test PASSED');
  console.log(`   Session: ${result.sessionId}`);
  console.log(`   Turns: ${result.turns}`);
  console.log(`   Cost: $${(result.usdCost ?? 0).toFixed(4)}`);
  console.log(`   Duration: ${(result.durationMs / 1000).toFixed(1)}s`);
} else {
  console.log('\n❌ Integration test FAILED');
  console.log(`   Error: ${result.error}`);
  console.log(`   Exit code: ${result.exitCode}`);
}

process.exit(result.success ? 0 : 1);
