import SwiftUI

// Reuse Genie design tokens
private enum GenieTheme {
    static let black      = Color(red: 0, green: 0, blue: 0)
    static let charcoal   = Color(red: 0.078, green: 0.078, blue: 0.086)
    static let grayDark   = Color(red: 0.118, green: 0.118, blue: 0.129)
    static let gray       = Color(red: 0.420, green: 0.443, blue: 0.498)
    static let grayLight  = Color(red: 0.612, green: 0.639, blue: 0.686)
    static let textWarm   = Color(red: 0.949, green: 0.922, blue: 0.969)
    static let blue       = Color(red: 0.545, green: 0.671, blue: 0.953)
    static let blueAccent = Color(red: 0.310, green: 0.545, blue: 1.0)
    static let teal       = Color(red: 0, green: 0.831, blue: 0.667)
    static let green      = Color(red: 0.133, green: 0.773, blue: 0.369)

    static let glassBg       = Color(red: 0.545, green: 0.671, blue: 0.953).opacity(0.06)
    static let glassBorder   = Color(red: 0.545, green: 0.671, blue: 0.953).opacity(0.18)
}

struct SettingsView: View {
    @ObservedObject var state: GenieState
    @ObservedObject var config: ConfigManager

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
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            GenieTheme.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom tab bar
                HStack(spacing: 0) {
                    tabButton("API Keys", icon: "key.fill", index: 0)
                    tabButton("Server", icon: "server.rack", index: 1)
                    tabButton("About", icon: "info.circle", index: 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, GenieTheme.blue.opacity(0.2), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                // Tab content
                Group {
                    switch selectedTab {
                    case 0: apiKeysTab
                    case 1: serverTab
                    case 2: aboutTab
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 560, height: 480)
        .preferredColorScheme(.dark)
        .onAppear { loadFromConfig() }
    }

    // MARK: - Tab Button

    private func tabButton(_ title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selectedTab == index ? GenieTheme.textWarm : GenieTheme.gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                selectedTab == index ? GenieTheme.glassBg : Color.clear
            )
            .overlay(
                Capsule()
                    .stroke(
                        selectedTab == index ? GenieTheme.glassBorder : Color.clear,
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - API Keys Tab

    private var apiKeysTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Section: Required
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("TELEGRAM")

                    keyField("Bot Token", text: $telegramToken, placeholder: "Required", required: true)

                    HStack(alignment: .top, spacing: 12) {
                        keyField("Chat ID", text: $telegramChat, placeholder: "Required", required: true)
                            .frame(maxWidth: .infinity)

                        VStack {
                            Spacer().frame(height: 20)
                            Button {
                                Task { await testTelegram() }
                            } label: {
                                HStack(spacing: 4) {
                                    if isTesting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else if let result = telegramTestResult {
                                        Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(result ? GenieTheme.teal : .red)
                                    }
                                    Text(isTesting ? "Testing..." : "Test")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(GenieTheme.blue)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(GenieTheme.blue.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(GenieTheme.blue.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(isTesting || telegramToken.isEmpty || telegramChat.isEmpty)
                        }
                    }
                }
                .padding(16)
                .background(GenieTheme.glassBg)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GenieTheme.glassBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Section: AI & Services
                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("AI & SERVICES")

                    keyField("OpenRouter API Key", text: $openRouterKey, placeholder: "sk-or-...")
                    keyField("Anthropic API Key", text: $anthropicKey, placeholder: "sk-ant-...")
                    keyField("Stripe Secret Key", text: $stripeKey, placeholder: "sk_live_...")
                    keyField("Gemini API Key", text: $geminiKey, placeholder: "Optional")
                }
                .padding(16)
                .background(GenieTheme.glassBg)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GenieTheme.glassBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Save button
                HStack {
                    Spacer()
                    Button {
                        saveToConfig()
                    } label: {
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [GenieTheme.blueAccent, GenieTheme.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: GenieTheme.blue.opacity(0.2), radius: 8, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(telegramToken.isEmpty || telegramChat.isEmpty)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Server Tab

    private var serverTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Status cards
            VStack(spacing: 10) {
                processStatusCard("Chrome CDP", status: state.chromeStatus)
                processStatusCard("Genie Server", status: state.serverStatus)
            }

            // Budget slider
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("BUDGET")

                HStack(spacing: 12) {
                    Slider(value: $maxBudget, in: 0.5...100, step: 0.5)
                        .tint(GenieTheme.blue)
                    Text("$\(String(format: "%.1f", maxBudget))")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(GenieTheme.textWarm)
                        .frame(width: 50)
                }
            }
            .padding(16)
            .background(GenieTheme.glassBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GenieTheme.glassBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Repo path
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundStyle(GenieTheme.gray)
                Text(state.repoDir.isEmpty ? "Repo not found" : state.repoDir)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(GenieTheme.grayLight)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 10) {
                if state.serverStatus.isRunning {
                    actionButton("Stop Server", icon: "stop.fill", color: .red.opacity(0.8)) {
                        ServerManager.shared.stop()
                    }
                } else {
                    actionButton("Start Server", icon: "play.fill", color: GenieTheme.teal) {
                        Task { await ServerManager.shared.start() }
                    }
                }

                actionButton("Restart All", icon: "arrow.clockwise", color: GenieTheme.blue) {
                    Task {
                        ChromeManager.shared.stop()
                        ServerManager.shared.stop()
                        try? await Task.sleep(for: .seconds(1))
                        await ChromeManager.shared.start()
                        await ServerManager.shared.start()
                    }
                }

                actionButton("View Logs", icon: "doc.text", color: GenieTheme.gray) {
                    NSWorkspace.shared.selectFile(
                        "/tmp/genie-logs/server.out.log",
                        inFileViewerRootedAtPath: "/tmp/genie-logs")
                }
            }
        }
        .padding(24)
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [GenieTheme.blue.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "lamp.desk.fill")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [GenieTheme.blue, GenieTheme.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, 12)

            Text("Genie 2.0")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(GenieTheme.textWarm)

            Text("Voice-triggered autonomous agent")
                .font(.system(size: 14))
                .foregroundStyle(GenieTheme.grayLight)
                .padding(.bottom, 4)

            Text("Say \"Genie\" in a JellyJelly video.\nI hear you. I execute. I report back.")
                .font(.system(size: 12))
                .foregroundStyle(GenieTheme.gray)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

            // Stats
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(state.totalWishesCompleted)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(GenieTheme.textWarm)
                    Text("Wishes")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(GenieTheme.gray)
                }
                .frame(width: 100)
                .padding(.vertical, 12)
                .background(GenieTheme.glassBg)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(GenieTheme.glassBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 4) {
                    Text("$\(String(format: "%.2f", state.totalCostUSD))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(GenieTheme.textWarm)
                    Text("Total Cost")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(GenieTheme.gray)
                }
                .frame(width: 100)
                .padding(.vertical, 12)
                .background(GenieTheme.glassBg)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(GenieTheme.glassBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            // Footer
            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/gtrush/genie-2.0")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                        Text("GitHub Repository")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(GenieTheme.blue)
                }

                Text(state.repoDir)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(GenieTheme.gray.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.bottom, 8)
        }
        .padding(24)
    }

    // MARK: - Reusable Components

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(GenieTheme.blue)
            .kerning(1.4)
    }

    private func keyField(_ label: String, text: Binding<String>, placeholder: String, required: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GenieTheme.grayLight)
                if required {
                    Text("*")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .padding(10)
                .background(GenieTheme.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(GenieTheme.glassBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func processStatusCard(_ label: String, status: GenieState.ProcessStatus) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(processStatusColor(status))
                .frame(width: 10, height: 10)
                .shadow(color: processStatusColor(status).opacity(0.5), radius: 4)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(GenieTheme.textWarm)

            Spacer()

            Text(status.label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(GenieTheme.grayLight)
        }
        .padding(14)
        .background(GenieTheme.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(GenieTheme.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .overlay(
                Capsule().stroke(color.opacity(0.3), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func processStatusColor(_ status: GenieState.ProcessStatus) -> Color {
        switch status {
        case .running: return GenieTheme.teal
        case .starting: return .yellow
        case .stopped: return GenieTheme.gray
        case .failed: return .red
        }
    }

    // MARK: - Config Helpers

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
