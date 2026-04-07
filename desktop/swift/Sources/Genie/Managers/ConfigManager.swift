import Foundation
import Combine
import Security
import os

@MainActor
final class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "config")
    private let keychainService = "com.gtrush.genie"

    // ── Loaded Config ──────────────────────────────────────────────────
    @Published private(set) var telegramBotToken: String = ""
    @Published private(set) var telegramChatID: String = ""
    @Published private(set) var openRouterAPIKey: String = ""
    @Published private(set) var anthropicAPIKey: String = ""
    @Published private(set) var stripeSecretKey: String = ""
    @Published private(set) var geminiAPIKey: String = ""
    @Published private(set) var pollInterval: Int = 3000
    @Published private(set) var maxTurns: Int = 50
    @Published private(set) var maxBudgetUSD: Double = 25.0
    @Published private(set) var watchedUsers: String = ""

    var hasRequiredKeys: Bool {
        !telegramBotToken.isEmpty && !telegramChatID.isEmpty
    }

    /// Minimum config: free tier needs nothing, BYOK needs an OpenRouter key
    var hasMinimumConfig: Bool {
        let tier = GenieState.shared.selectedTier
        if tier == .free { return true }
        return !openRouterAPIKey.isEmpty
    }

    // ── Demo Key ──────────────────────────────────────────────────────
    static let demoOpenRouterKey = "sk-or-v1-demo-genie-free-tier"

    var demoWishCount: Int {
        get { UserDefaults.standard.integer(forKey: "genie.demoWishCount") }
        set { UserDefaults.standard.set(newValue, forKey: "genie.demoWishCount") }
    }

    var shouldShowUpgradeNudge: Bool {
        let tier = GenieState.shared.selectedTier
        return tier == .free && demoWishCount >= 3
    }

    // ── Model Selection ───────────────────────────────────────────────
    @Published private(set) var selectedModel: String = ""

    func setSelectedModel(_ value: String) {
        selectedModel = value
        objectWillChange.send()
    }

    func effectiveOpenRouterKey() -> String {
        let tier = GenieState.shared.selectedTier
        if tier == .free && openRouterAPIKey.isEmpty {
            return Self.demoOpenRouterKey
        }
        return openRouterAPIKey
    }

    func resolveModel() -> String {
        if !selectedModel.isEmpty { return selectedModel }
        switch GenieState.shared.selectedTier {
        case .free:
            return "qwen/qwen3-235b-a22b:free"
        case .byok:
            return "anthropic/claude-sonnet-4-20250514"
        }
    }

    static let freeModels: [(id: String, label: String)] = [
        ("qwen/qwen3-235b-a22b:free", "Qwen 3 235B (Free)"),
        ("meta-llama/llama-4-maverick:free", "Llama 4 Maverick (Free)"),
        ("google/gemma-3-27b-it:free", "Gemma 3 27B (Free)"),
        ("mistralai/mistral-small-3.1-24b-instruct:free", "Mistral Small 3.1 (Free)"),
    ]

    static let proModels: [(id: String, label: String)] = [
        ("anthropic/claude-sonnet-4-20250514", "Claude Sonnet 4"),
        ("openai/gpt-4.1", "GPT-4.1"),
        ("google/gemini-2.5-pro-preview", "Gemini 2.5 Pro"),
        ("anthropic/claude-opus-4-20250514", "Claude Opus 4"),
    ]

    // ── Load from .env ─────────────────────────────────────────────────
    func load() {
        let repoDir = GenieState.shared.repoDir
        guard !repoDir.isEmpty else { return }
        let envPath = repoDir + "/.env"

        guard let content = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            logger.warning(".env not found at \(envPath)")
            return
        }

        let parsed = parseEnv(content)

        telegramBotToken = parsed["TELEGRAM_BOT_TOKEN"] ?? ""
        telegramChatID = parsed["TELEGRAM_CHAT_ID"] ?? ""
        openRouterAPIKey = parsed["OPENROUTER_API_KEY"] ?? ""
        anthropicAPIKey = parsed["ANTHROPIC_API_KEY"] ?? ""
        stripeSecretKey = parsed["STRIPE_SECRET_KEY"] ?? ""
        geminiAPIKey = parsed["GEMINI_API_KEY"] ?? ""
        pollInterval = Int(parsed["GENIE_POLL_INTERVAL"] ?? "3000") ?? 3000
        maxTurns = Int(parsed["GENIE_MAX_TURNS"] ?? "50") ?? 50
        maxBudgetUSD = Double(parsed["GENIE_MAX_BUDGET_USD"] ?? "25") ?? 25.0
        watchedUsers = parsed["GENIE_WATCHED_USERS"] ?? ""

        logger.info("Config loaded: telegram=\(self.hasRequiredKeys ? "OK" : "MISSING"), openrouter=\(!self.openRouterAPIKey.isEmpty), anthropic=\(!self.anthropicAPIKey.isEmpty)")
    }

    // ── Save to .env ───────────────────────────────────────────────────
    func save() {
        let repoDir = GenieState.shared.repoDir
        guard !repoDir.isEmpty else { return }
        let envPath = repoDir + "/.env"

        // Read existing .env or template
        var content: String
        if let existing = try? String(contentsOfFile: envPath, encoding: .utf8) {
            content = existing
        } else if let template = try? String(contentsOfFile: repoDir + "/.env.example", encoding: .utf8) {
            content = template
        } else {
            logger.error("Neither .env nor .env.example found")
            return
        }

        // Update values
        content = setEnvValue(content, key: "TELEGRAM_BOT_TOKEN", value: telegramBotToken)
        content = setEnvValue(content, key: "TELEGRAM_CHAT_ID", value: telegramChatID)
        content = setEnvValue(content, key: "OPENROUTER_API_KEY", value: openRouterAPIKey)
        content = setEnvValue(content, key: "ANTHROPIC_API_KEY", value: anthropicAPIKey)
        content = setEnvValue(content, key: "STRIPE_SECRET_KEY", value: stripeSecretKey)
        content = setEnvValue(content, key: "STRIPE_API_KEY", value: stripeSecretKey)
        content = setEnvValue(content, key: "GEMINI_API_KEY", value: geminiAPIKey)
        content = setEnvValue(content, key: "GENIE_POLL_INTERVAL", value: String(pollInterval))
        content = setEnvValue(content, key: "GENIE_MAX_TURNS", value: String(maxTurns))
        content = setEnvValue(content, key: "GENIE_MAX_BUDGET_USD", value: String(maxBudgetUSD))
        content = setEnvValue(content, key: "GENIE_WATCHED_USERS", value: watchedUsers)

        do {
            try content.write(toFile: envPath, atomically: true, encoding: .utf8)
            logger.info("Config saved to \(envPath)")
        } catch {
            logger.error("Failed to save .env: \(error.localizedDescription)")
        }
    }

    // ── Setter methods (for UI bindings) ───────────────────────────────
    func setTelegramBotToken(_ value: String) { telegramBotToken = value }
    func setTelegramChatID(_ value: String) { telegramChatID = value }
    func setOpenRouterAPIKey(_ value: String) { openRouterAPIKey = value }
    func setAnthropicAPIKey(_ value: String) { anthropicAPIKey = value }
    func setStripeSecretKey(_ value: String) { stripeSecretKey = value }
    func setGeminiAPIKey(_ value: String) { geminiAPIKey = value }
    func setPollInterval(_ value: Int) { pollInterval = max(1000, value) }
    func setMaxTurns(_ value: Int) { maxTurns = max(1, value) }
    func setMaxBudgetUSD(_ value: Double) { maxBudgetUSD = max(0.1, value) }
    func setWatchedUsers(_ value: String) { watchedUsers = value }

    // ── Test Telegram ──────────────────────────────────────────────────
    func testTelegram() async -> Bool {
        guard !telegramBotToken.isEmpty, !telegramChatID.isEmpty else { return false }
        let urlString = "https://api.telegram.org/bot\(telegramBotToken)/sendMessage"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        let body = "chat_id=\(telegramChatID)&text=Genie desktop app connected."
        request.httpBody = body.data(using: .utf8)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            return http?.statusCode == 200
        } catch {
            logger.error("Telegram test failed: \(error.localizedDescription)")
            return false
        }
    }

    // ── Keychain helpers ───────────────────────────────────────────────
    func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // ── Private helpers ────────────────────────────────────────────────
    private func parseEnv(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard let eqIdx = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: eqIdx)...]).trimmingCharacters(in: .whitespaces)
            result[key] = value
        }
        return result
    }

    private func setEnvValue(_ content: String, key: String, value: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var found = false
        let updated = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(key + "=") || trimmed.hasPrefix("# " + key + "=") {
                found = true
                return "\(key)=\(value)"
            }
            return line
        }
        if found {
            return updated.joined(separator: "\n")
        }
        // Key not found -- append it
        return content + "\n\(key)=\(value)\n"
    }
}
