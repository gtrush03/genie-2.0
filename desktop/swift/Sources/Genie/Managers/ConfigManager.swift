import Foundation
import Security
import os

@MainActor
@Observable
final class ConfigManager {
    static let shared = ConfigManager()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "config")
    private let keychainService = "com.gtrush.genie"

    // ── Loaded Config ──────────────────────────────────────────────────
    private(set) var telegramBotToken: String = ""
    private(set) var telegramChatID: String = ""
    private(set) var openRouterAPIKey: String = ""
    private(set) var anthropicAPIKey: String = ""
    private(set) var stripeSecretKey: String = ""
    private(set) var geminiAPIKey: String = ""
    private(set) var pollInterval: Int = 3000
    private(set) var maxTurns: Int = 50
    private(set) var maxBudgetUSD: Double = 25.0
    private(set) var watchedUsers: String = ""

    var hasRequiredKeys: Bool {
        !telegramBotToken.isEmpty && !telegramChatID.isEmpty
    }

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
