import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: Int = 1

    // Step 2: API Keys
    @State private var openRouterKey: String = ""
    @State private var telegramToken: String = ""
    @State private var telegramChat: String = ""
    @State private var telegramOK: Bool?
    @State private var isTesting: Bool = false

    // Step 3: Browser Login
    @State private var serviceStatuses: [String: ServiceStatus] = [
        "X (Twitter)": .unchecked,
        "LinkedIn": .unchecked,
        "Gmail": .unchecked,
        "Uber Eats": .unchecked,
        "Vercel": .unchecked,
        "GitHub": .unchecked,
        "Stripe": .unchecked,
        "OpenTable": .unchecked,
        "Airbnb": .unchecked,
        "Calendly": .unchecked,
        "Venmo": .unchecked,
        "Notion": .unchecked,
    ]
    @State private var isCheckingServices: Bool = false

    private let totalSteps = 4

    enum ServiceStatus {
        case unchecked
        case loggedIn
        case notLoggedIn
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

            // Step content
            Group {
                switch currentStep {
                case 1: welcomeStep
                case 2: apiKeysStep
                case 3: browserLoginStep
                case 4: readyStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(width: 520, height: 500)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Step \(currentStep) of \(totalSteps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.purple)
                        .frame(
                            width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps),
                            height: 4
                        )
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 64))
                .foregroundStyle(.purple)

            Text("Welcome to Genie")
                .font(.largeTitle.weight(.bold))

            Text("Your wishes are about to come true")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                currentStep = 2
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)
        }
    }

    // MARK: - Step 2: API Keys

    private var apiKeysStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Connect your AI")
                .font(.title2.weight(.semibold))
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // OpenRouter API Key
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("OpenRouter API Key")
                                .font(.callout.weight(.semibold))
                            Spacer()
                            Link("Get a key", destination: URL(string: "https://openrouter.ai/keys")!)
                                .font(.caption)
                        }
                        SecureField("sk-or-...", text: $openRouterKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    // Telegram Bot Token
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Telegram Bot Token")
                                .font(.callout.weight(.semibold))
                            Text("*").foregroundStyle(.red)
                        }
                        SecureField("Talk to @BotFather -> /newbot -> paste token", text: $telegramToken)
                            .textFieldStyle(.roundedBorder)
                        Text("Create a bot via @BotFather on Telegram, then paste the token here.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Telegram Chat ID
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Telegram Chat ID")
                                .font(.callout.weight(.semibold))
                            Text("*").foregroundStyle(.red)
                        }
                        TextField("e.g. 123456789", text: $telegramChat)
                            .textFieldStyle(.roundedBorder)
                        Text("Send any message to @userinfobot on Telegram to find your chat ID.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Test Connection
                    HStack(spacing: 8) {
                        Button(isTesting ? "Testing..." : "Test Connection") {
                            Task { await testTelegram() }
                        }
                        .disabled(isTesting || telegramToken.isEmpty || telegramChat.isEmpty)

                        if let ok = telegramOK {
                            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(ok ? .green : .red)
                            Text(ok ? "Connected!" : "Failed -- check token and chat ID.")
                                .font(.caption)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 12)

            // Navigation
            HStack {
                Button("Back") { currentStep = 1 }
                Spacer()
                Button {
                    saveAPIKeys()
                    currentStep = 3
                } label: {
                    Text("Continue")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(telegramToken.isEmpty || telegramChat.isEmpty)
            }
        }
    }

    // MARK: - Step 3: Browser Login

    private var browserLoginStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Log into your accounts")
                .font(.title2.weight(.semibold))
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sortedServices, id: \.self) { service in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(statusColor(for: serviceStatuses[service] ?? .unchecked))
                                .frame(width: 8, height: 8)
                            Text(service)
                                .font(.callout)
                            Spacer()
                        }
                    }
                }
            }

            Text("Check \"Keep me signed in\" on every site.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer(minLength: 12)

            // Actions
            HStack(spacing: 12) {
                Button("Open Login Pages") {
                    Task {
                        await ChromeManager.shared.openLoginPages()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button(isCheckingServices ? "Checking..." : "I'm Done Logging In") {
                    Task { await runHealthChecks() }
                }
                .disabled(isCheckingServices)
            }

            Spacer(minLength: 12)

            // Navigation
            HStack {
                Button("Back") { currentStep = 2 }
                Spacer()
                Button {
                    currentStep = 4
                } label: {
                    Text("Continue")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
    }

    // MARK: - Step 4: Ready

    private var readyStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Genie is ready")
                .font(.largeTitle.weight(.bold))

            VStack(spacing: 6) {
                let connectedCount = serviceStatuses.values.filter { $0 == .loggedIn }.count
                let budget = GenieState.shared.maxBudgetUSD

                Text("\(connectedCount) accounts connected, budget $\(String(format: "%.0f", budget))/wish")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text("Press Cmd+Shift+G to make a wish")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer()

            Button {
                finishOnboarding()
            } label: {
                Text("Start Wishing")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)
        }
    }

    // MARK: - Helpers

    private var sortedServices: [String] {
        [
            "X (Twitter)", "LinkedIn", "Gmail", "Uber Eats",
            "Vercel", "GitHub", "Stripe", "OpenTable",
            "Airbnb", "Calendly", "Venmo", "Notion",
        ]
    }

    private func statusColor(for status: ServiceStatus) -> Color {
        switch status {
        case .unchecked: return .gray
        case .loggedIn: return .green
        case .notLoggedIn: return .red
        }
    }

    private func saveAPIKeys() {
        let config = ConfigManager.shared
        config.setTelegramBotToken(telegramToken)
        config.setTelegramChatID(telegramChat)
        config.setOpenRouterAPIKey(openRouterKey)
        config.save()
    }

    private func testTelegram() async {
        isTesting = true
        let config = ConfigManager.shared
        config.setTelegramBotToken(telegramToken)
        config.setTelegramChatID(telegramChat)
        telegramOK = await config.testTelegram()
        isTesting = false
    }

    private func runHealthChecks() async {
        isCheckingServices = true
        for service in sortedServices {
            let ok = await ChromeManager.shared.checkServiceHealth(service)
            serviceStatuses[service] = ok ? .loggedIn : .notLoggedIn
        }
        isCheckingServices = false
    }

    private func finishOnboarding() {
        GenieState.shared.hasCompletedOnboarding = true
        dismiss()
        Task {
            await ChromeManager.shared.start()
            await ServerManager.shared.start()
        }
    }
}

// MARK: - Equatable conformance for use in ForEach filtering

extension OnboardingView.ServiceStatus: Equatable {}
