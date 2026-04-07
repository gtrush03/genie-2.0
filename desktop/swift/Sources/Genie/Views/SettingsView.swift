import SwiftUI

struct SettingsView: View {
    let state: GenieState
    let config: ConfigManager

    @State private var telegramToken = ""
    @State private var telegramChat = ""
    @State private var openRouterKey = ""
    @State private var anthropicKey = ""
    @State private var stripeKey = ""
    @State private var geminiKey = ""
    @State private var maxBudget = 25.0
    @State private var pollInterval = 3000
    @State private var telegramTestResult: Bool?
    @State private var isTesting = false

    var body: some View {
        TabView {
            apiKeysTab
                .tabItem { Label("API Keys", systemImage: "key") }
            serverTab
                .tabItem { Label("Server", systemImage: "server.rack") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 440)
        .onAppear { loadFromConfig() }
    }

    // ── API Keys Tab ───────────────────────────────────────────────────
    private var apiKeysTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("API Keys")
                    .font(.title2.weight(.semibold))

                Group {
                    secretField("Telegram Bot Token", text: $telegramToken, required: true)
                    HStack {
                        secretField("Telegram Chat ID", text: $telegramChat, required: true)
                        Button(isTesting ? "Testing..." : "Test Telegram") {
                            Task { await testTelegram() }
                        }
                        .disabled(isTesting || telegramToken.isEmpty || telegramChat.isEmpty)
                        if let result = telegramTestResult {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(result ? .green : .red)
                        }
                    }
                }

                Divider()

                Group {
                    secretField("OpenRouter API Key", text: $openRouterKey)
                    secretField("Anthropic API Key", text: $anthropicKey)
                    secretField("Stripe Secret Key", text: $stripeKey)
                    secretField("Gemini API Key", text: $geminiKey)
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Save") { saveToConfig() }
                        .buttonStyle(.borderedProminent)
                        .disabled(telegramToken.isEmpty || telegramChat.isEmpty)
                }
            }
            .padding(20)
        }
    }

    // ── Server Tab ─────────────────────────────────────────────────────
    private var serverTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Server Settings")
                .font(.title2.weight(.semibold))

            LabeledContent("Repo Directory") {
                Text(state.repoDir.isEmpty ? "Not found" : state.repoDir)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            LabeledContent("Max Budget (USD)") {
                Slider(value: $maxBudget, in: 0.5...100, step: 0.5)
                    .frame(width: 200)
                Text("$\(String(format: "%.1f", maxBudget))")
                    .font(.caption)
                    .frame(width: 40)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                statusCard("Chrome CDP", status: state.chromeStatus)
                statusCard("Genie Server", status: state.serverStatus)
            }

            HStack(spacing: 12) {
                if state.serverStatus.isRunning {
                    Button("Stop Server") {
                        ServerManager.shared.stop()
                    }
                } else {
                    Button("Start Server") {
                        Task { await ServerManager.shared.start() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Restart All") {
                    Task {
                        ChromeManager.shared.stop()
                        ServerManager.shared.stop()
                        try? await Task.sleep(for: .seconds(1))
                        await ChromeManager.shared.start()
                        await ServerManager.shared.start()
                    }
                }

                Button("View Logs") {
                    NSWorkspace.shared.selectFile(
                        "/tmp/genie-logs/server.out.log",
                        inFileViewerRootedAtPath: "/tmp/genie-logs")
                }
            }

            Spacer()
        }
        .padding(20)
    }

    // ── About Tab ──────────────────────────────────────────────────────
    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            Text("Genie 2.0")
                .font(.title.weight(.bold))
            Text("Voice-triggered autonomous agent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Say \"Genie\" in a JellyJelly video.\nI hear you. I execute. I report back.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            HStack(spacing: 20) {
                VStack {
                    Text("\(state.totalWishesCompleted)")
                        .font(.title2.weight(.bold))
                    Text("Wishes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("$\(String(format: "%.2f", state.totalCostUSD))")
                        .font(.title2.weight(.bold))
                    Text("Total Cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Link("GitHub Repository", destination: URL(string: "https://github.com/gtrush/genie-2.0")!)
                .font(.caption)

            Text("Repo: \(state.repoDir)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(20)
    }

    // ── Helpers ────────────────────────────────────────────────────────
    private func secretField(_ label: String, text: Binding<String>, required: Bool = false) -> some View {
        LabeledContent {
            SecureField(required ? "Required" : "Optional", text: text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
        } label: {
            HStack(spacing: 4) {
                Text(label)
                if required {
                    Text("*").foregroundStyle(.red)
                }
            }
            .frame(width: 160, alignment: .leading)
        }
    }

    private func statusCard(_ label: String, status: GenieState.ProcessStatus) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.callout)
            Spacer()
            Text(status.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }

    private func statusColor(_ status: GenieState.ProcessStatus) -> Color {
        switch status {
        case .running: .green
        case .starting: .yellow
        case .stopped: .gray
        case .failed: .red
        }
    }

    private func loadFromConfig() {
        telegramToken = config.telegramBotToken
        telegramChat = config.telegramChatID
        openRouterKey = config.openRouterAPIKey
        anthropicKey = config.anthropicAPIKey
        stripeKey = config.stripeSecretKey
        geminiKey = config.geminiAPIKey
        maxBudget = config.maxBudgetUSD
        pollInterval = config.pollInterval
    }

    private func saveToConfig() {
        config.setTelegramBotToken(telegramToken)
        config.setTelegramChatID(telegramChat)
        config.setOpenRouterAPIKey(openRouterKey)
        config.setAnthropicAPIKey(anthropicKey)
        config.setStripeSecretKey(stripeKey)
        config.setGeminiAPIKey(geminiKey)
        config.setMaxBudgetUSD(maxBudget)
        config.setPollInterval(pollInterval)
        config.save()
    }

    private func testTelegram() async {
        isTesting = true
        config.setTelegramBotToken(telegramToken)
        config.setTelegramChatID(telegramChat)
        telegramTestResult = await config.testTelegram()
        isTesting = false
    }
}
