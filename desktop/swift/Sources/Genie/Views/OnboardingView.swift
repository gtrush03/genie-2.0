import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: Int = 1
    @State private var direction: Int = 1  // 1 = forward, -1 = back

    // Step 2: Plan selection
    @State private var selectedPlan: GenieState.Tier? = nil
    @State private var openRouterKey: String = ""
    @State private var isValidatingKey: Bool = false
    @State private var keyValidationResult: Bool? = nil
    @State private var showKeyInput: Bool = false

    // Step 2: Advanced (Telegram, optional)
    @State private var telegramToken: String = ""
    @State private var telegramChat: String = ""
    @State private var telegramOK: Bool?
    @State private var isTesting: Bool = false
    @State private var showAdvanced: Bool = false

    // Step 3: Browser Login
    @State private var serviceStatuses: [String: ServiceStatus] = {
        var dict: [String: ServiceStatus] = [:]
        for service in OnboardingView.allServices {
            dict[service] = .unchecked
        }
        return dict
    }()
    @State private var isCheckingServices: Bool = false

    // Step 4: Celebration
    @State private var showCelebration: Bool = false

    private let totalSteps = 4

    static let allServices = [
        "X (Twitter)", "LinkedIn", "Gmail", "Uber Eats",
        "Vercel", "GitHub", "Stripe", "OpenTable",
        "Airbnb", "Calendly", "Venmo", "Notion",
    ]

    enum ServiceStatus: Equatable {
        case unchecked
        case loggedIn
        case notLoggedIn
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            G.bg.ignoresSafeArea()

            // Subtle radial glow
            RadialGradient(
                colors: [G.blue.opacity(0.06), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                progressDots
                    .padding(.top, 28)
                    .padding(.bottom, 8)

                // Step content with transition
                ZStack {
                    switch currentStep {
                    case 1: welcomeStep.transition(slideTransition)
                    case 2: planPickerStep.transition(slideTransition)
                    case 3: browserLoginStep.transition(slideTransition)
                    case 4: readyStep.transition(slideTransition)
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .frame(width: 700, height: 560)
        .preferredColorScheme(.dark)
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? G.blue : G.surfaceAlt)
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStep)
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Lamp icon with pulse glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [G.blue.opacity(0.25), Color.clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .modifier(PulseGlow())

                Image(systemName: "lamp.desk.fill")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [G.blue, G.blueLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, 24)

            Text("Genie")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(G.textPrimary)
                .padding(.bottom, 8)

            Text("Your wishes, fulfilled.")
                .font(.system(size: 18))
                .foregroundStyle(G.textSecondary)

            Text("Say it. Genie builds it, orders it, posts it, books it.")
                .font(.system(size: 14))
                .foregroundStyle(G.textTertiary)
                .padding(.top, 4)

            Spacer()

            Button("Get Started") { goToStep(2) }
                .buttonStyle(GlowButtonStyle())
                .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        }
    }

    // MARK: - Step 2: Plan Picker

    private var planPickerStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(G.blue)
                    Text("How do you want to power Genie?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(G.textPrimary)
                }
                Text("Choose your AI engine. You can switch anytime in settings.")
                    .font(.system(size: 14))
                    .foregroundStyle(G.textSecondary)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            // Two plan cards side by side
            HStack(spacing: 16) {
                planCard(
                    tier: .free,
                    icon: "sparkles",
                    title: "Free",
                    models: "Qwen, Llama, Gemma",
                    subtitle: "Good for basic wishes",
                    features: ["Order food", "Post tweets", "Simple research"],
                    price: "$0 forever",
                    buttonTitle: "Start Free",
                    buttonColor: G.teal
                )

                planCard(
                    tier: .byok,
                    icon: "key.fill",
                    title: "Bring Your Own Key",
                    models: "Claude, GPT-4.1, Gemini",
                    subtitle: "Best for complex wishes",
                    features: ["Everything in Free, plus:", "Build websites", "Multi-step workflows"],
                    price: "Pay-as-you-go (~$0.01/wish)",
                    buttonTitle: "Enter API Key",
                    buttonColor: G.blueAccent
                )
            }

            // Expandable API key input (shown when BYOK selected)
            if showKeyInput {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("OpenRouter API Key")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(G.textPrimary)
                        Spacer()
                        Link(destination: URL(string: "https://openrouter.ai/keys")!) {
                            HStack(spacing: 4) {
                                Text("Get your free key")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(G.blue)
                        }
                    }

                    SecureField("sk-or-v1-...", text: $openRouterKey)
                        .glassTextField(isFocused: !openRouterKey.isEmpty)

                    HStack {
                        if let result = keyValidationResult {
                            HStack(spacing: 4) {
                                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result ? G.teal : G.red)
                                Text(result ? "Valid key" : "Invalid key -- check and try again")
                                    .font(.system(size: 12))
                                    .foregroundStyle(result ? G.teal : G.red)
                            }
                        }
                        Spacer()
                        Button(isValidatingKey ? "Validating..." : "Validate & Continue") {
                            Task { await validateAndContinue() }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            openRouterKey.isEmpty
                                ? AnyShapeStyle(G.surfaceAlt)
                                : AnyShapeStyle(G.ctaGradient)
                        )
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                        .disabled(openRouterKey.isEmpty || isValidatingKey)
                    }
                }
                .padding(20)
                .glassCard()
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Advanced section (Telegram -- optional)
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Advanced (Telegram)")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(G.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)

                if showAdvanced {
                    VStack(alignment: .leading, spacing: 12) {
                        advancedField("Telegram Bot Token", text: $telegramToken, placeholder: "Talk to @BotFather")
                        advancedField("Telegram Chat ID", text: $telegramChat, placeholder: "e.g. 123456789")

                        if !telegramToken.isEmpty && !telegramChat.isEmpty {
                            HStack(spacing: 8) {
                                Button(isTesting ? "Testing..." : "Test Connection") {
                                    Task { await testTelegram() }
                                }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(G.blue)
                                .disabled(isTesting)
                                .buttonStyle(.plain)

                                if let ok = telegramOK {
                                    HStack(spacing: 4) {
                                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(ok ? G.teal : G.red)
                                        Text(ok ? "Connected" : "Failed")
                                            .font(.system(size: 11))
                                            .foregroundStyle(ok ? G.teal : G.red)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()

            // Navigation
            HStack {
                backButton { goToStep(1) }
                Spacer()
            }
        }
    }

    // MARK: - Plan Card

    private func planCard(
        tier: GenieState.Tier,
        icon: String,
        title: String,
        models: String,
        subtitle: String,
        features: [String],
        price: String,
        buttonTitle: String,
        buttonColor: Color
    ) -> some View {
        let isSelected = selectedPlan == tier

        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(buttonColor)

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(G.textPrimary)

            Text(models)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(G.textSecondary)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(G.textTertiary)

            Divider().background(G.glassBorder)

            ForEach(features, id: \.self) { feature in
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(buttonColor)
                    Text(feature)
                        .font(.system(size: 12))
                        .foregroundStyle(G.textSecondary)
                }
            }

            Spacer()

            Text(price)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(G.textPrimary)

            Button(buttonTitle) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedPlan = tier
                    if tier == .free {
                        GenieState.shared.savedTier = .free
                        saveConfig()
                        goToStep(3)
                    } else {
                        showKeyInput = true
                    }
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                LinearGradient(
                    colors: [buttonColor, buttonColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(isSelected ? buttonColor.opacity(0.08) : G.glassBg)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? buttonColor.opacity(0.4) : G.glassBorder, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Step 3: Browser Login

    private var browserLoginStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundStyle(G.blue)
                    Text("Connect your world")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(G.textPrimary)
                }
                Text("Log into your accounts so Genie can act on your behalf.")
                    .font(.system(size: 14))
                    .foregroundStyle(G.textSecondary)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ], spacing: 10) {
                    ForEach(Self.allServices, id: \.self) { service in
                        serviceCard(service)
                    }
                }
            }
            .frame(maxHeight: 230)

            HStack(spacing: 10) {
                Button {
                    Task { await ChromeManager.shared.openLoginPages() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                        Text("Open Browser")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(G.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassCard(cornerRadius: 10)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await runHealthChecks() }
                } label: {
                    HStack(spacing: 6) {
                        if isCheckingServices {
                            ProgressView().controlSize(.small).tint(G.blue)
                        } else {
                            Image(systemName: "checkmark.shield").font(.system(size: 12))
                        }
                        Text(isCheckingServices ? "Checking..." : "I'm logged in")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(G.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(G.blue.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(G.blue.opacity(0.3), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isCheckingServices)
            }
            .padding(.top, 14)

            Spacer()

            HStack {
                backButton { goToStep(2) }
                Spacer()
                Button { goToStep(4) } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(G.textTertiary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)

                ctaButton("Continue") { goToStep(4) }
            }
        }
    }

    // MARK: - Step 4: Ready

    private var readyStep: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                if showCelebration {
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(G.blue.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .offset(
                                x: CGFloat.random(in: -50...50),
                                y: CGFloat.random(in: -50...50)
                            )
                            .opacity(showCelebration ? 0 : 1)
                            .animation(.easeOut(duration: 1.5).delay(Double(i) * 0.1), value: showCelebration)
                    }
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [G.teal.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [G.teal, G.green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(showCelebration ? 1.0 : 0.5)
                    .opacity(showCelebration ? 1.0 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCelebration)
            }
            .padding(.bottom, 20)

            Text("You're all set")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(G.textPrimary)
                .padding(.bottom, 12)

            // Summary pills
            let connectedCount = serviceStatuses.values.filter { $0 == .loggedIn }.count
            let budget = GenieState.shared.maxBudgetUSD
            let tierLabel = GenieState.shared.selectedTier == .free ? "Free tier" : "Pro tier"

            HStack(spacing: 16) {
                summaryPill(icon: "cpu", text: tierLabel)
                summaryPill(icon: "link", text: "\(connectedCount) services")
                summaryPill(icon: "dollarsign.circle", text: "$\(String(format: "%.0f", budget)) budget")
            }
            .padding(.bottom, 20)

            // Keyboard shortcut hint
            HStack(spacing: 6) {
                Text("Press")
                    .font(.system(size: 14))
                    .foregroundStyle(G.textSecondary)
                HStack(spacing: 2) {
                    KeyCap(key: "Cmd")
                    KeyCap(key: "Shift")
                    KeyCap(key: "G")
                }
                Text("anywhere to summon Genie")
                    .font(.system(size: 14))
                    .foregroundStyle(G.textSecondary)
            }

            Spacer()

            Button {
                finishOnboarding()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Start Wishing")
                }
            }
            .buttonStyle(GlowButtonStyle())
            .onHover { h in if h { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showCelebration = true
            }
        }
    }

    // MARK: - Reusable Components

    private func serviceCard(_ service: String) -> some View {
        let status = serviceStatuses[service] ?? .unchecked
        let emoji = serviceEmoji(service)

        return VStack(spacing: 6) {
            Text(emoji).font(.system(size: 20))

            Text(service)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(G.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor(for: status))
                    .frame(width: 6, height: 6)
                Text(statusLabel(for: status))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(statusTextColor(for: status))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            Group {
                switch status {
                case .loggedIn: G.teal.opacity(0.08)
                case .notLoggedIn: G.red.opacity(0.06)
                default: G.glassBg
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    status == .loggedIn ? G.teal.opacity(0.3) :
                    status == .notLoggedIn ? G.red.opacity(0.2) :
                    G.glassBorder,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func advancedField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(G.textSecondary)
            SecureField(placeholder, text: text)
                .glassTextField()
        }
    }

    private func ctaButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(G.ctaGradient)
                .clipShape(Capsule())
                .shadow(color: G.blue.opacity(0.2), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text("Back")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(G.textTertiary)
        }
        .buttonStyle(.plain)
    }

    private func summaryPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(G.blue)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(G.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(G.glassBg)
        .overlay(Capsule().stroke(G.glassBorder, lineWidth: 1))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func goToStep(_ step: Int) {
        direction = step > currentStep ? 1 : -1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStep = step
        }
    }

    private func validateAndContinue() async {
        isValidatingKey = true
        keyValidationResult = nil

        guard let url = URL(string: "https://openrouter.ai/api/v1/auth/key") else {
            keyValidationResult = false
            isValidatingKey = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(openRouterKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            let valid = http?.statusCode == 200

            keyValidationResult = valid
            if valid {
                GenieState.shared.savedTier = .byok
                ConfigManager.shared.setOpenRouterAPIKey(openRouterKey)
                saveConfig()
                try? await Task.sleep(for: .milliseconds(500))
                goToStep(3)
            }
        } catch {
            keyValidationResult = false
        }
        isValidatingKey = false
    }

    private func saveConfig() {
        let config = ConfigManager.shared
        if !telegramToken.isEmpty { config.setTelegramBotToken(telegramToken) }
        if !telegramChat.isEmpty { config.setTelegramChatID(telegramChat) }
        if !openRouterKey.isEmpty { config.setOpenRouterAPIKey(openRouterKey) }
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
        for service in Self.allServices {
            let ok = await ChromeManager.shared.checkServiceHealth(service)
            withAnimation(.easeInOut(duration: 0.3)) {
                serviceStatuses[service] = ok ? .loggedIn : .notLoggedIn
            }
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

    // MARK: - Service Helpers

    private func serviceEmoji(_ service: String) -> String {
        switch service {
        case "X (Twitter)": return "\u{1D54F}"
        case "LinkedIn": return "in"
        case "Gmail": return "\u{2709}"
        case "Uber Eats": return "\u{1F354}"
        case "Vercel": return "\u{25B2}"
        case "GitHub": return "\u{25C9}"
        case "Stripe": return "\u{1F4B3}"
        case "OpenTable": return "\u{1F37D}"
        case "Airbnb": return "\u{1F3E0}"
        case "Calendly": return "\u{1F4C5}"
        case "Venmo": return "\u{1F4B8}"
        case "Notion": return "\u{1F4DD}"
        default: return "\u{25CF}"
        }
    }

    private func statusColor(for status: ServiceStatus) -> Color {
        switch status {
        case .unchecked: return G.textTertiary
        case .loggedIn: return G.teal
        case .notLoggedIn: return G.red
        }
    }

    private func statusLabel(for status: ServiceStatus) -> String {
        switch status {
        case .unchecked: return "Pending"
        case .loggedIn: return "Connected"
        case .notLoggedIn: return "Not found"
        }
    }

    private func statusTextColor(for status: ServiceStatus) -> Color {
        switch status {
        case .unchecked: return G.textTertiary
        case .loggedIn: return G.teal
        case .notLoggedIn: return G.red.opacity(0.8)
        }
    }
}
