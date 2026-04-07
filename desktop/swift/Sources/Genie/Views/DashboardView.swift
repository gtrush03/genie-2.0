import SwiftUI

struct DashboardView: View {
    @State private var wishText = ""
    @FocusState private var isWishFocused: Bool
    @ObservedObject private var state = GenieState.shared
    @ObservedObject private var config = ConfigManager.shared
    @ObservedObject private var traces = TraceManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 16)

            // Wish input bar
            wishInputBar
                .frame(maxWidth: 560)

            // Upgrade nudge (shows after 3 free wishes)
            if config.shouldShowUpgradeNudge {
                upgradeNudge
                    .frame(maxWidth: 560)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Two-column layout
            HStack(alignment: .top, spacing: 16) {
                // Left: wish history
                wishHistoryPanel
                    .frame(maxWidth: .infinity)

                // Right: status + services
                VStack(spacing: 16) {
                    statusPanel
                    servicesPanel
                }
                .frame(width: 260)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusWishInput)) { _ in
            isWishFocused = true
        }
    }

    // MARK: - Wish Input Bar

    private var wishInputBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 16))
                .foregroundStyle(G.blue)

            TextField("What's your wish?", text: $wishText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(G.textPrimary)
                .focused($isWishFocused)
                .onSubmit { submitWish() }

            Button(action: submitWish) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        wishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? G.textTertiary : G.blue
                    )
            }
            .buttonStyle(.plain)
            .disabled(wishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(G.glassBg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isWishFocused ? G.blue.opacity(0.4) : G.glassBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Upgrade Nudge

    private var upgradeNudge: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(G.amber)

            VStack(alignment: .leading, spacing: 2) {
                Text("Want unlimited wishes with premium models?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(G.textPrimary)
                Text("Get your free OpenRouter API key in 30 seconds")
                    .font(.system(size: 11))
                    .foregroundStyle(G.textSecondary)
            }

            Spacer()

            Link(destination: URL(string: "https://openrouter.ai/keys")!) {
                Text("Get Key")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(G.ctaGradient)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(G.amber.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(G.amber.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Wish History Panel

    private var wishHistoryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("RECENT WISHES")

            if traces.recentWishes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(G.textTertiary)
                    Text("No wishes yet")
                        .font(.system(size: 14))
                        .foregroundStyle(G.textSecondary)
                    Text("Type one above to get started")
                        .font(.system(size: 12))
                        .foregroundStyle(G.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(traces.recentWishes) { wish in
                            WishHistoryRow(wish: wish)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity)
        .glassCard()
        .onAppear {
            TraceManager.shared.startScanning()
        }
    }

    // MARK: - Status Panel

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("STATUS")

            statusRow("Chrome CDP", status: state.chromeStatus)
            statusRow("Server", status: state.serverStatus)

            Divider().background(G.glassBorder)

            HStack {
                Text("Model")
                    .font(.system(size: 12))
                    .foregroundStyle(G.textSecondary)
                Spacer()
                Text(currentModelLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(G.textPrimary)
                    .lineLimit(1)
            }

            HStack {
                Text("Budget")
                    .font(.system(size: 12))
                    .foregroundStyle(G.textSecondary)
                Spacer()
                Text("$\(String(format: "%.2f", state.totalCostUSD)) / $\(String(format: "%.0f", state.maxBudgetUSD))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(G.textPrimary)
            }

            // Budget progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(G.surfaceAlt)
                        .frame(height: 4)
                    Capsule()
                        .fill(G.blue)
                        .frame(
                            width: max(0, geo.size.width * min(1.0, state.totalCostUSD / state.maxBudgetUSD)),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Services Panel

    private var servicesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("CONNECTED SERVICES")

            ForEach(topServices, id: \.self) { service in
                HStack(spacing: 8) {
                    Circle()
                        .fill(G.textTertiary)
                        .frame(width: 6, height: 6)
                    Text(service)
                        .font(.system(size: 12))
                        .foregroundStyle(G.textSecondary)
                    Spacer()
                    Text("Pending")
                        .font(.system(size: 10))
                        .foregroundStyle(G.textTertiary)
                }
            }

            if topServices.count < allServices.count {
                Text("+\(allServices.count - topServices.count) more...")
                    .font(.system(size: 11))
                    .foregroundStyle(G.textTertiary)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Helpers

    private func statusRow(_ label: String, status: GenieState.ProcessStatus) -> some View {
        HStack(spacing: 8) {
            StatusDot(processStatus: status)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(G.textPrimary)
            Spacer()
            Text(status.isRunning ? "Live" : "Down")
                .font(.system(size: 11))
                .foregroundStyle(status.isRunning ? G.teal : G.textTertiary)
        }
    }

    private var currentModelLabel: String {
        let model = config.resolveModel()
        let parts = model.split(separator: "/")
        let name = parts.last.map(String.init) ?? model
        let tier = state.selectedTier == .free ? "Free" : "Pro"
        return "\(name) (\(tier))"
    }

    private var allServices: [String] {
        ["X", "LinkedIn", "Gmail", "Uber Eats", "GitHub", "Vercel", "Stripe", "OpenTable", "Airbnb", "Calendly", "Venmo", "Notion"]
    }

    private var topServices: [String] {
        Array(allServices.prefix(5))
    }

    private func submitWish() {
        let text = wishText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let repoDir = GenieState.shared.repoDir
        let triggerScript = repoDir + "/src/core/trigger.mjs"

        // Find node
        let nodeCandidates = ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"]
        guard let nodePath = nodeCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }),
              FileManager.default.fileExists(atPath: triggerScript) else { return }

        // Build environment with model and key
        var env = ProcessInfo.processInfo.environment
        env["GENIE_MODEL"] = config.resolveModel()
        env["OPENROUTER_API_KEY"] = config.effectiveOpenRouterKey()
        env["GENIE_REPO_DIR"] = repoDir

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [triggerScript, text]
        process.currentDirectoryURL = URL(fileURLWithPath: repoDir)
        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let _ = GenieState.shared.addWish(title: text, creator: "You")
            wishText = ""

            // Track demo wish count
            if GenieState.shared.selectedTier == .free {
                config.demoWishCount += 1
            }
        } catch {
            // Silent fail
        }
    }
}
