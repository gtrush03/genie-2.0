import SwiftUI

// MARK: - Design Tokens

private enum Genie {
    static let black      = Color(red: 0, green: 0, blue: 0)
    static let charcoal   = Color(red: 0.078, green: 0.078, blue: 0.086)   // #141416
    static let grayDark   = Color(red: 0.118, green: 0.118, blue: 0.129)   // #1E1E21
    static let gray       = Color(red: 0.420, green: 0.443, blue: 0.498)   // #6B7280
    static let grayLight  = Color(red: 0.612, green: 0.639, blue: 0.686)   // #9CA3AF
    static let textWarm   = Color(red: 0.949, green: 0.922, blue: 0.969)   // #f2ebf7
    static let blue       = Color(red: 0.545, green: 0.671, blue: 0.953)   // #8babf3
    static let blueAccent = Color(red: 0.310, green: 0.545, blue: 1.0)     // #4f8bff
    static let blueLight  = Color(red: 0.812, green: 0.890, blue: 1.0)     // #cfe3ff
    static let teal       = Color(red: 0, green: 0.831, blue: 0.667)       // #00D4AA
    static let green      = Color(red: 0.133, green: 0.773, blue: 0.369)   // #22c55e

    static let glassBg       = Color(red: 0.545, green: 0.671, blue: 0.953).opacity(0.06)
    static let glassBorder   = Color(red: 0.545, green: 0.671, blue: 0.953).opacity(0.18)
    static let glassBorderHi = Color(red: 0.545, green: 0.671, blue: 0.953).opacity(0.35)
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: Int = 1
    @State private var direction: Int = 1  // 1 = forward, -1 = back

    // Step 2: API Keys
    @State private var openRouterKey: String = ""
    @State private var telegramToken: String = ""
    @State private var telegramChat: String = ""
    @State private var telegramOK: Bool?
    @State private var isTesting: Bool = false
    @State private var showAdvanced: Bool = false

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

    // Step 4: Celebration
    @State private var showCelebration: Bool = false

    private let totalSteps = 4

    enum ServiceStatus {
        case unchecked
        case loggedIn
        case notLoggedIn
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Pure black background
            Genie.black.ignoresSafeArea()

            // Subtle radial glow behind content
            RadialGradient(
                colors: [
                    Genie.blue.opacity(0.06),
                    Color.clear
                ],
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
                    case 1: welcomeStep.transition(.asymmetric(
                        insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
                    case 2: apiKeysStep.transition(.asymmetric(
                        insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
                    case 3: browserLoginStep.transition(.asymmetric(
                        insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
                    case 4: readyStep.transition(.asymmetric(
                        insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .frame(width: 620, height: 520)
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Genie.blue : Genie.grayDark)
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
                // Glow behind icon
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Genie.blue.opacity(0.25), Color.clear],
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
                            colors: [Genie.blue, Genie.blueLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.bottom, 24)

            // Title
            Text("Genie")
                .font(.system(size: 44, weight: .bold, design: .default))
                .foregroundStyle(Genie.textWarm)
                .padding(.bottom, 8)

            // Subtitle
            Text("Your wishes, fulfilled.")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Genie.grayLight)

            Spacer()

            // CTA Button
            Button {
                goToStep(2)
            } label: {
                Text("Get Started")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 280)
                    .frame(height: 48)
                    .background(
                        LinearGradient(
                            colors: [Genie.blueAccent, Genie.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Genie.blue.opacity(0.3), radius: 16, y: 4)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }

    // MARK: - Step 2: API Keys

    private var apiKeysStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Genie.blue)
                    Text("Power your Genie")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Genie.textWarm)
                }

                Text("This is how Genie thinks. One key, 300+ AI models.")
                    .font(.system(size: 14))
                    .foregroundStyle(Genie.grayLight)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)

            // OpenRouter Key Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("OpenRouter API Key")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Genie.textWarm)
                    Spacer()
                    Link(destination: URL(string: "https://openrouter.ai/keys")!) {
                        HStack(spacing: 4) {
                            Text("Get your free key")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Genie.blue)
                    }
                }

                SecureField("sk-or-v1-...", text: $openRouterKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(12)
                    .background(Genie.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                openRouterKey.isEmpty ? Genie.glassBorder : Genie.blue.opacity(0.5),
                                lineWidth: 1
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(20)
            .background(Genie.glassBg)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Genie.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Advanced section
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Advanced")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Genie.gray)
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
                                .foregroundStyle(Genie.blue)
                                .disabled(isTesting)
                                .buttonStyle(.plain)

                                if let ok = telegramOK {
                                    HStack(spacing: 4) {
                                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(ok ? Genie.teal : .red)
                                        Text(ok ? "Connected" : "Failed")
                                            .font(.system(size: 11))
                                            .foregroundStyle(ok ? Genie.teal : .red)
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
                primaryButton("Continue", enabled: !openRouterKey.isEmpty) {
                    saveAPIKeys()
                    goToStep(3)
                }
            }
        }
    }

    // MARK: - Step 3: Browser Login

    private var browserLoginStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundStyle(Genie.blue)
                    Text("Connect your world")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Genie.textWarm)
                }
                Text("Log into your accounts so Genie can act on your behalf.")
                    .font(.system(size: 14))
                    .foregroundStyle(Genie.grayLight)
            }
            .padding(.top, 8)
            .padding(.bottom, 20)

            // Service grid
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ], spacing: 10) {
                    ForEach(sortedServices, id: \.self) { service in
                        serviceCard(service)
                    }
                }
            }
            .frame(maxHeight: 230)

            // Action buttons
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
                    .foregroundStyle(Genie.textWarm)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Genie.glassBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Genie.glassBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await runHealthChecks() }
                } label: {
                    HStack(spacing: 6) {
                        if isCheckingServices {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Genie.blue)
                        } else {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 12))
                        }
                        Text(isCheckingServices ? "Checking..." : "I'm logged in")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Genie.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Genie.blue.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Genie.blue.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isCheckingServices)
            }
            .padding(.top, 14)

            Spacer()

            // Navigation
            HStack {
                backButton { goToStep(2) }
                Spacer()
                Button {
                    goToStep(4)
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Genie.gray)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)

                primaryButton("Continue", enabled: true) {
                    goToStep(4)
                }
            }
        }
    }

    // MARK: - Step 4: Ready

    private var readyStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Celebration icon
            ZStack {
                // Sparkle particles
                if showCelebration {
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(Genie.blue.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .offset(
                                x: CGFloat.random(in: -50...50),
                                y: CGFloat.random(in: -50...50)
                            )
                            .opacity(showCelebration ? 0 : 1)
                            .animation(
                                .easeOut(duration: 1.5)
                                    .delay(Double(i) * 0.1),
                                value: showCelebration
                            )
                    }
                }

                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Genie.teal.opacity(0.3), Color.clear],
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
                            colors: [Genie.teal, Genie.green],
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
                .foregroundStyle(Genie.textWarm)
                .padding(.bottom, 12)

            // Summary card
            let connectedCount = serviceStatuses.values.filter { $0 == .loggedIn }.count
            let budget = GenieState.shared.maxBudgetUSD

            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    summaryPill(
                        icon: "link",
                        text: "\(connectedCount) services"
                    )
                    summaryPill(
                        icon: "cpu",
                        text: "300+ models"
                    )
                    summaryPill(
                        icon: "dollarsign.circle",
                        text: "$\(String(format: "%.0f", budget)) budget"
                    )
                }
            }
            .padding(.bottom, 20)

            // Keyboard shortcut hint
            HStack(spacing: 6) {
                Text("Press")
                    .font(.system(size: 14))
                    .foregroundStyle(Genie.grayLight)
                HStack(spacing: 2) {
                    keyCapView("Cmd")
                    keyCapView("Shift")
                    keyCapView("G")
                }
                Text("anywhere to summon Genie")
                    .font(.system(size: 14))
                    .foregroundStyle(Genie.grayLight)
            }

            Spacer()

            // CTA
            Button {
                finishOnboarding()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Start Wishing")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 280)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [Genie.blueAccent, Genie.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Genie.blue.opacity(0.3), radius: 16, y: 4)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
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
            Text(emoji)
                .font(.system(size: 20))

            Text(service)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Genie.textWarm)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Status badge
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
                case .loggedIn:
                    Genie.teal.opacity(0.08)
                case .notLoggedIn:
                    Color.red.opacity(0.06)
                default:
                    Genie.glassBg
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    status == .loggedIn ? Genie.teal.opacity(0.3) :
                    status == .notLoggedIn ? Color.red.opacity(0.2) :
                    Genie.glassBorder,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.3), value: serviceStatuses[service] == .loggedIn)
    }

    private func advancedField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Genie.grayLight)
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(10)
                .background(Genie.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Genie.glassBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(
                    enabled ?
                    AnyShapeStyle(LinearGradient(
                        colors: [Genie.blueAccent, Genie.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )) :
                    AnyShapeStyle(Genie.grayDark)
                )
                .clipShape(Capsule())
                .shadow(color: enabled ? Genie.blue.opacity(0.2) : Color.clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text("Back")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Genie.gray)
        }
        .buttonStyle(.plain)
    }

    private func summaryPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Genie.blue)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Genie.textWarm)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Genie.glassBg)
        .overlay(
            Capsule()
                .stroke(Genie.glassBorder, lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private func keyCapView(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Genie.textWarm)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Genie.grayDark)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Genie.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Helpers

    private func goToStep(_ step: Int) {
        direction = step > currentStep ? 1 : -1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            currentStep = step
        }
    }

    private var sortedServices: [String] {
        [
            "X (Twitter)", "LinkedIn", "Gmail", "Uber Eats",
            "Vercel", "GitHub", "Stripe", "OpenTable",
            "Airbnb", "Calendly", "Venmo", "Notion",
        ]
    }

    private func serviceEmoji(_ service: String) -> String {
        switch service {
        case "X (Twitter)": return "𝕏"
        case "LinkedIn": return "in"
        case "Gmail": return "✉"
        case "Uber Eats": return "🍔"
        case "Vercel": return "▲"
        case "GitHub": return "◉"
        case "Stripe": return "💳"
        case "OpenTable": return "🍽"
        case "Airbnb": return "🏠"
        case "Calendly": return "📅"
        case "Venmo": return "💸"
        case "Notion": return "📝"
        default: return "●"
        }
    }

    private func statusColor(for status: ServiceStatus) -> Color {
        switch status {
        case .unchecked: return Genie.gray
        case .loggedIn: return Genie.teal
        case .notLoggedIn: return .red
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
        case .unchecked: return Genie.gray
        case .loggedIn: return Genie.teal
        case .notLoggedIn: return .red.opacity(0.8)
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
}

// MARK: - Pulse Glow Animation Modifier

private struct PulseGlow: ViewModifier {
    @State private var isGlowing = false

    func body(content: Content) -> some View {
        content
            .opacity(isGlowing ? 1.0 : 0.5)
            .scaleEffect(isGlowing ? 1.1 : 0.9)
            .animation(
                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                value: isGlowing
            )
            .onAppear { isGlowing = true }
    }
}

// MARK: - Equatable conformance for use in ForEach filtering

extension OnboardingView.ServiceStatus: Equatable {}
