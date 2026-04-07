# Genie Desktop App — Packaging Research

## Current Architecture (What Must Be Packaged)

Genie runs as: Node server (polls JellyJelly) + persistent Chrome (CDP port 9222) + Claude Code CLI (spawned per wish via `claude -p`) + Playwright MCP + LaunchAgents. Dependencies: `@playwright/mcp`, `playwright`. The server is ~4 files of ESM JavaScript totaling under 50KB of actual code.

---

## 1. App Shell Options (Ranked)

### Rank 1: Electron — The v1 Winner

- **Bundle size:** ~150MB (ships Chromium + Node.js). Genie already needs a Chromium instance, so this is not waste — it IS the browser.
- **Cold start:** 1-2 seconds on mid-range hardware. ([Tauri vs Electron comparison, tech-insider.org](https://tech-insider.org/tauri-vs-electron-2026/))
- **Child process management:** Native `child_process.spawn()` — no bridging layer. Can spawn Claude Code CLI, manage Chrome CDP, run the Node server all in-process. This is Electron's killer advantage for Genie.
- **IPC:** Built-in `ipcMain`/`ipcRenderer` between main and renderer processes. The Genie server can run directly in the main process — no sidecar needed.
- **Auto-update:** `electron-updater` + GitHub Releases. Battle-tested by VS Code, Slack, Discord. Differential updates via blockmap files (~2-5MB patches). ([electron-builder docs](https://www.electron.build/auto-update))
- **Platform support:** macOS (arm64 + x86_64), Windows, Linux — all from one codebase with electron-builder.
- **Why it wins for Genie:** Electron's bundled Chromium can double as both the app UI AND the CDP-controlled browser. One Chromium instance serves both purposes. No external Chrome dependency. No sidecar complexity.

### Rank 2: Tauri 2.0

- **Bundle size:** ~3-10MB (uses system WebView). ([Tauri docs](https://v2.tauri.app))
- **Cold start:** Under 0.5 seconds. ([Tauri benchmarks](https://www.gethopp.app/blog/tauri-vs-electron))
- **Memory:** 30-50MB idle vs Electron's 200-300MB.
- **Child process management:** Sidecar system requires compiling Node.js server to a standalone binary via `pkg` or `bun build --compile`, then launching via `Command.sidecar()`. IPC is over stdin/stdout or localhost HTTP. ([Tauri sidecar docs](https://v2.tauri.app/learn/sidecar-nodejs/))
- **The Chrome problem:** Tauri uses WebView2 (Windows) / WebKit (macOS) for the app UI — neither supports CDP. You still need a separate Chromium for browser automation. This means shipping Playwright's Chromium (~250MB) alongside a 3MB Tauri shell. The size advantage evaporates.
- **Auto-update:** Built-in updater with mandatory signature verification. Works with GitHub Releases or any static JSON endpoint. ([Tauri updater plugin](https://v2.tauri.app/plugin/updater/))
- **Verdict:** Excellent framework, wrong fit. Genie needs a controllable Chromium instance. Tauri's WebView can't do CDP. You'd end up with Tauri + Chromium sidecar, which is just a worse Electron.

### Rank 3: Wails (Go + WebView)

- **Bundle size:** ~10-15MB. Uses system WebView like Tauri.
- **Child process management:** Go's `exec.Command` is excellent for subprocesses. However, the Go→JS bridge is less mature than Electron's IPC or Tauri's commands.
- **Same Chrome problem as Tauri.** WebView cannot do CDP. Still need external Chromium.
- **Auto-update:** No built-in updater. Must roll your own or use go-update.
- **Verdict:** Interesting for Go-heavy backends. No advantage over Tauri for Genie, and less ecosystem support.

### Rank 4: Neutralinojs

- **Bundle size:** ~2-5MB. Lightest option.
- **Child process management:** Has IPC via extensions and child processes, but documentation and ecosystem are thin.
- **Same Chrome problem.** System WebView only.
- **Auto-update:** Basic built-in updater.
- **Verdict:** Too lightweight for Genie's complexity. Managing Chrome + Claude Code + Node server from Neutralino's thin runtime would be fragile.

### Rank 5: Native Swift (macOS only)

- **Bundle size:** ~5MB for the shell. Smallest native option.
- **Platform lock:** macOS only. Kills 60%+ of potential users.
- **Child process management:** `Process()` API is excellent. But building a full UI in SwiftUI means rewriting the dashboard from scratch — no web tech reuse.
- **Verdict:** Only consider if Genie is permanently Mac-only. Not worth the platform lock for v1.

---

## 2. What Goes Inside the App Bundle

### The Genie Server

**Best path:** Compile `server.mjs` + `dispatcher.mjs` + `firehose.mjs` + `telegram.mjs` with `bun build --compile` into a single ~50MB standalone binary. No Node.js runtime dependency. Cross-compile for mac-arm64, mac-x64, win-x64, linux-x64 from one machine. ([Bun executables docs](https://bun.com/docs/bundler/executables))

**Alternative:** In Electron, the server can run directly in the main process as ESM — Node.js is already bundled. This is simpler and avoids the Bun compilation step entirely. **This is the v1 path.**

### Chrome/Chromium

**In Electron:** The bundled Chromium IS the browser. Launch a BrowserWindow with CDP enabled (`webContents.debugger.attach()`) or launch a second hidden BrowserWindow as the "agent browser." No external Chrome needed.

**Playwright's Chromium:** `npx playwright install chromium` downloads a ~130MB Chromium binary. Can be bundled at build time. Connected via CDP. This is the fallback if Electron's built-in Chromium can't serve both app UI and agent browsing simultaneously.

**Recommendation for v1:** Use Electron's Chromium for everything. The app UI is one BrowserWindow. The agent browser is another BrowserWindow (or BrowserView) with `--remote-debugging-port` equivalent via the `debugger` API. Single Chromium process, two contexts.

### Claude Code

Three paths, in order of shipping speed:

**Path A — Agent SDK as library (v1 winner):** Import `@anthropic-ai/claude-agent-sdk` directly. The `query()` function accepts: `prompt`, `systemPrompt`, `mcpServers`, `permissionMode: 'bypassPermissions'`, `allowDangerouslySkipPermissions: true`, `maxTurns`, `maxBudgetUsd`, `model`, `tools`, custom `agents`, and `hooks`. It returns an async generator streaming `SDKMessage` events. This replaces `dispatcher.mjs`'s `child_process.spawn('claude', ...)` with a direct library call. No CLI binary needed. Supports MCP servers (Playwright MCP still works), custom system prompts, and structured outputs. Package: `@anthropic-ai/claude-agent-sdk`. ([SDK reference](https://platform.claude.com/docs/en/agent-sdk/typescript))

**Path B — Bundle the CLI binary:** Ship the `claude` binary (~50MB) as a sidecar. Spawn it exactly as `dispatcher.mjs` does now. Zero code changes. But 50MB larger bundle and process management overhead.

**Path C — Build own agent loop (like Claurst):** Claurst reimplemented Claude Code's entire agent loop in Rust across 12 crates (core, api, tools, query, tui, commands, mcp, bridge, cli, buddy, plugins, acp). Uses reqwest + tokio for API calls, ratatui for TUI, and direct tool implementations. ([Claurst GitHub](https://github.com/Kuberwastaken/claurst)) This is months of work. Not viable for v1.

**v1 decision: Path A.** Rewrite `dispatcher.mjs` to use `query()` from the Agent SDK. Estimated effort: 1-2 days. The SDK handles the agent loop, tool execution, and MCP integration internally.

### Skills, System Prompt, MCP Config

- `skills/ubereats-*` — bundle in `resources/` directory, copy to `~/.claude/skills/` on first run.
- `config/genie-system.md` — pass directly as `systemPrompt` to `query()`.
- `config/mcp.json` — pass as `mcpServers` option to `query()`.

### Estimated Bundle Size

| Component | Size |
|---|---|
| Electron shell + Chromium | ~150MB |
| Agent SDK + node_modules | ~15MB |
| Playwright MCP | ~5MB |
| Genie source + skills + config | ~1MB |
| **Total .dmg (compressed)** | **~80-90MB** |

This is comparable to VS Code (~100MB download) and smaller than Slack (~170MB).

---

## 3. Chrome Management Inside the App

### Electron's Built-in Chromium as the Agent Browser

Electron's `BrowserWindow` supports the Chrome DevTools Protocol natively via `webContents.debugger`. This means:

1. Create a `BrowserWindow` with `show: false` (or show it as the "agent view")
2. Attach the CDP debugger: `win.webContents.debugger.attach('1.3')`
3. Send CDP commands directly: `win.webContents.debugger.sendCommand('Page.navigate', {url: '...'})`
4. Playwright MCP can connect to it if you expose a debugging port

**Better alternative:** Launch Electron with `--remote-debugging-port=9222` on the main process, then Playwright MCP connects to `http://127.0.0.1:9222` exactly as it does today. Zero changes to the MCP config.

### Profile Management

- **macOS:** `~/Library/Application Support/Genie/browser-profile/`
- **Windows:** `%APPDATA%/Genie/browser-profile/`
- **Linux:** `~/.config/Genie/browser-profile/`

Electron's `app.getPath('userData')` returns the platform-appropriate directory automatically. Set `--user-data-dir` to this path for persistent sessions (cookies, logins survive app restarts).

### Session Persistence Across Updates

The browser profile lives outside the app bundle in user data. App updates don't touch it. Logged-in sessions survive. This is how Chrome itself works.

---

## 4. Claude Code Inside the App — Agent SDK Deep Dive

The Claude Agent SDK (`@anthropic-ai/claude-agent-sdk`) is the correct v1 path. Key mapping from current `dispatcher.mjs`:

| Current (CLI spawn) | Agent SDK equivalent |
|---|---|
| `claude -p "wish text"` | `query({ prompt: wishText, options })` |
| `--append-system-prompt config/genie-system.md` | `systemPrompt: { type: 'preset', preset: 'claude_code', append: genieSystemPrompt }` |
| `--mcp-config config/mcp.json` | `mcpServers: { playwright: { command: 'npx', args: [...] } }` |
| `--permission-mode bypassPermissions` | `permissionMode: 'bypassPermissions', allowDangerouslySkipPermissions: true` |
| `--max-turns 200` | `maxTurns: 200` |
| `--max-budget-usd 25` | `maxBudgetUsd: 25` |
| `--output-format stream-json` | Iterate the async generator — each yield is an `SDKMessage` |
| `--resume <session-id>` | `resume: sessionId` |

The SDK also supports `canUseTool` callback for custom permission logic, `hooks` for lifecycle events, `agents` for subagent definitions, and `outputFormat` for structured JSON responses.

**Authentication:** User provides their Anthropic API key (or Claude Max subscription) on first run. Stored in the system keychain via Electron's `safeStorage` API.

---

## 5. Auto-Update Mechanism

### App Shell Updates (Electron)

Use `electron-updater` with GitHub Releases:
- On launch, check `https://api.github.com/repos/gtrush/genie/releases/latest`
- Download differential update (blockmap-based, typically 2-5MB)
- Apply on next restart
- Code-sign both Mac and Windows builds (required for auto-update trust)

### Hot Updates (Skills + System Prompt Only)

For skill updates without full app release:
- Store skills version in a `skills-manifest.json` on a CDN
- On app launch, compare local vs remote manifest
- Download only changed skill files to `~/.claude/skills/`
- System prompt updates: fetch from CDN, write to app config

This two-tier system means: bug fixes and new skills deploy in minutes (hot update), while Electron/SDK changes go through a full release cycle.

---

## 6. Platform Support and Effort

| Platform | Priority | Effort Delta | Notes |
|---|---|---|---|
| macOS arm64 | P0 | Baseline | Primary dev machine. electron-builder produces universal binaries. |
| macOS x86_64 | P0 | +0 | Universal binary covers both architectures automatically. |
| Windows x64 | P1 | +2 days | Electron handles most differences. Chrome profile path changes. LaunchAgent → Windows Task Scheduler or app startup. Test Playwright MCP on Windows. |
| Linux x64 | P2 | +1 day | AppImage or .deb. Minimal changes — Linux is closest to macOS for process management. |

---

## 7. Distribution

### Direct Download (v1 — do this)

- **macOS:** `.dmg` from GitHub Releases or website. Requires Apple Developer ID ($99/year) for notarization — without it, users get "app is damaged" Gatekeeper errors. ([Apple Developer ID](https://developer.apple.com/developer-id/))
- **Windows:** NSIS installer (`.exe`) via electron-builder. Requires Authenticode OV code signing certificate (~$216/year from SignMyCode). Without it, SmartScreen shows "unknown publisher" warning. ([SignMyCode pricing](https://signmycode.com/))
- Host on a landing page with download buttons. GitHub Releases as the CDN (free, handles bandwidth).

### Mac App Store — Not Viable

The App Store sandbox requires `com.apple.security.app-sandbox` entitlement. Child processes must use `com.apple.security.inherit` and cannot have their own sandbox profile. Spawning arbitrary binaries (Claude CLI, Chromium) is restricted. Running a localhost HTTP server is technically possible but subject to review rejection. **Skip for v1 and probably forever.** ([Apple Developer Forums](https://developer.apple.com/forums/thread/725396))

### Homebrew Cask

```ruby
cask "genie" do
  version "1.0.0"
  url "https://github.com/gtrush/genie/releases/download/v#{version}/Genie-#{version}-arm64.dmg"
  name "Genie"
  homepage "https://genie.app"
  app "Genie.app"
end
```

Easy to add after the direct download works. Free distribution to the Homebrew user base.

### Windows: NSIS vs MSI vs MSIX

- **NSIS** (v1): electron-builder default. Produces `.exe` installer. Well-understood, customizable. Most users expect this.
- **MSI:** Enterprise-friendly, better for IT deployment. electron-builder supports it via electron-winstaller. Add in v2 if enterprise customers ask.
- **MSIX:** Windows Store compatible but adds Store review overhead. Skip unless Store distribution is needed.

### Code Signing Costs Summary

| Item | Cost | Frequency |
|---|---|---|
| Apple Developer Program | $99 | Annual |
| Windows OV Code Signing (Sectigo via SignMyCode) | ~$216 | Annual |
| **Total** | **~$315/year** | |

---

## Recommendation: v1 Architecture

```
Electron app (single process)
├── Main process
│   ├── Genie server (ported from server.mjs, runs in-process)
│   ├── Dispatcher (uses Agent SDK query() instead of spawning CLI)
│   ├── Telegram reporter
│   └── Chrome manager (BrowserWindow with CDP + persistent profile)
├── Renderer process
│   ├── Dashboard UI (port existing dashboard/)
│   ├── Settings (API key, Telegram config, account logins)
│   └── Wish history + live stream viewer
└── Resources
    ├── Skills (ubereats-*, copied to ~/.claude/skills/)
    ├── System prompt (genie-system.md)
    └── MCP config (playwright → CDP on localhost)
```

**Why Electron wins:** Genie needs a controllable Chromium. Electron IS a controllable Chromium. Every other framework requires shipping a separate browser binary, negating their size advantages. The Agent SDK eliminates the Claude CLI dependency. The Node.js server runs natively in Electron's main process — no sidecar compilation needed.

**Estimated v1 timeline:** 1-2 weeks for a working .dmg with core functionality (poll → detect → dispatch → browse → report). Another week for polish (dashboard UI, settings panel, auto-update, installer UX).

**v2 evolution:** If bundle size becomes a concern (Electron's 150MB vs Tauri's 3MB), consider Tauri 2 + Playwright's bundled Chromium as a sidecar. But only after v1 proves product-market fit.

---

## What to Steal from Claurst

Claurst is a clean-room Rust reimplementation of Claude Code's agent loop across 12 crates. Relevant lessons:

1. **They DON'T wrap the CLI** — they reimplemented the agent loop from behavioral specs. This gives them full control but took significant effort. For Genie, the Agent SDK gives us 90% of this control without reimplementation.
2. **TUI via ratatui** — Genie doesn't need a TUI since we have a GUI, but their architecture of separating `core`, `api`, `tools`, `query`, and `mcp` into distinct crates is a clean pattern worth mirroring in our module structure.
3. **They use reqwest + tokio-tungstenite for streaming** — confirms that direct API integration (vs CLI spawning) is the direction serious implementations take.
4. **12 crates for a CLI tool** — validates that the Agent SDK's `query()` function saving us from this complexity is the right v1 call.
