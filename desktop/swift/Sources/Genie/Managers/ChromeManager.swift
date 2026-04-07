import Foundation
import Combine
import os

@MainActor
final class ChromeManager: ObservableObject {
    static let shared = ChromeManager()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "chrome")
    private var process: Process?
    private var healthCheckTask: Task<Void, Never>?

    private let chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    private let profileDir = NSHomeDirectory() + "/.genie/browser-profile"
    private let cdpPort = 9222
    private let cdpURL = "http://127.0.0.1:9222/json/version"

    /// Check if Chrome CDP is already responding
    func isAlive() async -> Bool {
        await withCheckedContinuation { continuation in
            var request = URLRequest(url: URL(string: cdpURL)!)
            request.timeoutInterval = 2
            URLSession.shared.dataTask(with: request) { data, response, error in
                let http = response as? HTTPURLResponse
                continuation.resume(returning: http?.statusCode == 200)
            }.resume()
        }
    }

    /// Start Chrome with CDP. Attaches to existing if already running.
    func start() async {
        let state = GenieState.shared

        // Already running?
        if await isAlive() {
            state.setChromeStatus(.running(pid: nil))
            logger.info("Chrome CDP already responding on :\(self.cdpPort)")
            return
        }

        state.setChromeStatus(.starting)

        // Create profile directory
        try? FileManager.default.createDirectory(atPath: profileDir, withIntermediateDirectories: true)

        // Check if Chrome exists
        guard FileManager.default.fileExists(atPath: chromePath) else {
            state.setChromeStatus(.failed("Chrome not found at \(chromePath)"))
            return
        }

        do {
            let proc = try ProcessHelper.spawn(
                executablePath: chromePath,
                arguments: [
                    "--user-data-dir=\(profileDir)",
                    "--remote-debugging-port=\(cdpPort)",
                    "--remote-debugging-address=127.0.0.1",
                    "--no-first-run",
                    "--no-default-browser-check",
                    "--restore-last-session",
                    "--disable-features=ChromeWhatsNewUI",
                ],
                stdoutPath: "/tmp/genie-logs/chrome.out.log",
                stderrPath: "/tmp/genie-logs/chrome.err.log"
            )
            self.process = proc

            // Wait for CDP to become available (up to 15 seconds)
            for attempt in 1...15 {
                try await Task.sleep(for: .seconds(1))
                if await isAlive() {
                    state.setChromeStatus(.running(pid: proc.processIdentifier))
                    logger.info("Chrome CDP ready after \(attempt)s (PID \(proc.processIdentifier))")
                    startHealthChecks()
                    return
                }
            }

            state.setChromeStatus(.failed("CDP did not respond after 15s"))
            logger.error("Chrome started but CDP never responded")
        } catch {
            state.setChromeStatus(.failed(error.localizedDescription))
            logger.error("Failed to start Chrome: \(error.localizedDescription)")
        }
    }

    /// Stop Chrome (only if we started it)
    func stop() {
        healthCheckTask?.cancel()
        healthCheckTask = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
            logger.info("Chrome terminated")
        }
        process = nil
        GenieState.shared.setChromeStatus(.stopped)
    }

    /// Periodic health check every 30s
    private func startHealthChecks() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                let alive = await isAlive()
                if !alive {
                    GenieState.shared.setChromeStatus(.failed("CDP stopped responding"))
                    logger.warning("Chrome CDP health check failed")
                }
            }
        }
    }

    /// Check if a service appears to be logged in by querying CDP open tabs.
    /// Returns true if Chrome has a tab for that service's domain that is NOT on a login page.
    func checkServiceHealth(_ service: String) async -> Bool {
        let domainMap: [String: (domain: String, loginPattern: String)] = [
            "X (Twitter)":   ("x.com",                  "/login"),
            "LinkedIn":      ("linkedin.com",            "/login"),
            "Gmail":         ("mail.google.com",         "accounts.google.com"),
            "Uber Eats":     ("ubereats.com",            "/login"),
            "Vercel":        ("vercel.com",              "/login"),
            "GitHub":        ("github.com",              "/login"),
            "Stripe":        ("dashboard.stripe.com",    "/login"),
            "OpenTable":     ("opentable.com",           "/sign-in"),
            "Airbnb":        ("airbnb.com",              "/login"),
            "Calendly":      ("calendly.com",            "/login"),
            "Venmo":         ("venmo.com",               "/sign-in"),
            "Notion":        ("notion.so",               "/login"),
        ]

        guard let info = domainMap[service] else { return false }
        guard await isAlive() else { return false }

        // Query CDP for open tabs
        let listURL = URL(string: "http://127.0.0.1:\(cdpPort)/json/list")!
        var request = URLRequest(url: listURL)
        request.timeoutInterval = 3

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let tabs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return false
            }
            // Look for a tab matching the domain that is NOT on a login page
            for tab in tabs {
                guard let url = tab["url"] as? String else { continue }
                if url.contains(info.domain) && !url.contains(info.loginPattern) {
                    return true
                }
            }
        } catch {
            logger.warning("Failed to query CDP tabs: \(error.localizedDescription)")
        }
        return false
    }

    /// Open login pages in Chrome tabs (used during onboarding)
    func openLoginPages() async {
        let urls = [
            "https://x.com/i/flow/login",
            "https://www.linkedin.com/login",
            "https://accounts.google.com",
            "https://www.ubereats.com",
            "https://vercel.com/login",
            "https://github.com/login",
            "https://dashboard.stripe.com/login",
        ]
        for urlString in urls {
            guard let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { continue }
            let cdpNew = URL(string: "http://127.0.0.1:\(cdpPort)/json/new?\(encoded)")!
            var request = URLRequest(url: cdpNew)
            request.httpMethod = "PUT"
            request.timeoutInterval = 5
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
