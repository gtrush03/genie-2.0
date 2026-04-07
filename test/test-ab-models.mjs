#!/usr/bin/env node
// A/B test: Sonnet 4.6 vs DeepSeek V3.2 on the same browser+website wish.
// Runs sequentially (not parallel) to avoid Chrome tab conflicts.
// Capped at 40 turns to prevent runaway costs.

import { sendMessage } from '../src/core/telegram.mjs';
import { dispatchToClaude } from '../src/core/dispatcher.mjs';

const WISH = {
  transcript: "Hey Genie, go to the NASA Astronomy Picture of the Day at apod.nasa.gov and grab the image URL and title. Then go to Hacker News and grab the top 3 story titles and links. Then build a beautiful dark-mode dashboard website that shows the NASA image on one side and the HN stories on the other. Use the direct NASA image URL in an img tag, don't download it. Deploy to Vercel and send me the link.",
  clipTitle: "A/B Model Test — Browser + Website",
  creator: "georgy",
  keyword: "genie",
};

// Cap turns to prevent runaway
process.env.GENIE_MAX_TURNS = '40';

const MODELS = [
  { id: 'anthropic/claude-sonnet-4.6', label: 'Sonnet 4.6', suffix: 'sonnet46' },
  { id: 'deepseek/deepseek-v3.2', label: 'DeepSeek V3.2', suffix: 'deepseek' },
];

const results = [];

await sendMessage('🧪 A/B MODEL TEST STARTING\n\nSame wish, two models (40 turn cap):\n• Sonnet 4.6 ($3/$15 per M tokens)\n• DeepSeek V3.2 ($0.26/$0.38 per M tokens)\n\nTask: Browse NASA APOD + HN → build dashboard → deploy\n\nRunning sequentially...', { plain: true });

for (const model of MODELS) {
  const tag = `[${model.label}]`;
  console.log(`\n${'='.repeat(60)}`);
  console.log(`${tag} Starting...`);
  console.log(`${'='.repeat(60)}\n`);

  await sendMessage(`\n🧪 ${tag} Starting now...`, { plain: true });

  // Override the model via env var for this run
  process.env.GENIE_CLAUDE_MODEL = model.id;

  const result = await dispatchToClaude({
    ...WISH,
    clipId: `ab-${model.suffix}-${Date.now()}`,
  });

  results.push({ model: model.label, id: model.id, ...result });

  console.log(`\n${tag} Done: success=${result.success} cost=$${(result.usdCost ?? 0).toFixed(4)} duration=${(result.durationMs / 1000).toFixed(1)}s turns=${result.turns}`);
}

// Send comparison to Telegram
const rows = results.map(r => {
  const status = r.success ? '✅' : '❌';
  const cost = `$${(r.usdCost ?? 0).toFixed(4)}`;
  const time = `${(r.durationMs / 1000).toFixed(0)}s`;
  const turns = r.turns ?? '?';
  return `${status} ${r.model}\n   Cost: ${cost} | Time: ${time} | Tools: ${turns}`;
}).join('\n\n');

const comparison = `🧪 A/B TEST RESULTS

${rows}

${results.length === 2 && results[0].usdCost && results[1].usdCost
  ? `Cost ratio: Sonnet 4.6 is ${(results[0].usdCost / results[1].usdCost).toFixed(1)}x more expensive than DeepSeek`
  : ''}
${results.length === 2
  ? `Speed: ${results[0].durationMs < results[1].durationMs ? 'Sonnet 4.6' : 'DeepSeek V3.2'} was ${Math.abs(results[0].durationMs - results[1].durationMs) / 1000 | 0}s faster`
  : ''}`;

await sendMessage(comparison, { plain: true });
console.log('\n' + comparison);

process.exit(results.every(r => r.success) ? 0 : 1);
