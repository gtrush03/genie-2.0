import Foundation
import Observation
import os

@MainActor
@Observable
final class GenieState {
    static let shared = GenieState()

    // ── Process Status ─────────────────────────────────────────────────
    enum ProcessStatus: Equatable {
        case stopped
        case starting
        case running(pid: Int32?)
        case failed(String)

        var label: String {
            switch self {
            case .stopped: return "Stopped"
            case .starting: return "Starting..."
            case let .running(pid):
                if let pid { return "Running (PID \(pid))" }
                return "Running"
            case let .failed(reason): return "Failed: \(reason)"
            }
        }

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    // ── Wish Tracking ──────────────────────────────────────────────────
    struct WishInfo: Identifiable {
        let id = UUID()
        let title: String
        let creator: String
        let startedAt: Date
        var status: WishStatus = .running
        var duration: TimeInterval?
        var cost: Double?
    }

    enum WishStatus {
        case running
        case completed
        case failed(String)
    }

    // ── State Properties ───────────────────────────────────────────────
    private(set) var chromeStatus: ProcessStatus = .stopped
    private(set) var serverStatus: ProcessStatus = .stopped
    private(set) var activeWishes: [WishInfo] = []
    private(set) var lastWish: WishInfo?
    private(set) var totalWishesCompleted: Int = 0
    private(set) var totalCostUSD: Double = 0

    var isFullyRunning: Bool {
        chromeStatus.isRunning && serverStatus.isRunning
    }

    var overallStatusLabel: String {
        if !chromeStatus.isRunning && !serverStatus.isRunning { return "Offline" }
        if !chromeStatus.isRunning { return "Chrome Down" }
        if !serverStatus.isRunning { return "Server Down" }
        if !activeWishes.isEmpty { return "Granting \(activeWishes.count) wish\(activeWishes.count == 1 ? "" : "es")..." }
        return "Watching"
    }

    var menuBarIconName: String {
        if !isFullyRunning { return "wand.and.stars.inverse" }
        if !activeWishes.isEmpty { return "sparkles" }
        return "wand.and.stars"
    }

    // ── Configuration ──────────────────────────────────────────────────
    var repoDir: String = ""
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "genie.onboardingComplete") }
        set { UserDefaults.standard.set(newValue, forKey: "genie.onboardingComplete") }
    }
    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: "genie.launchAtLogin") }
        set { UserDefaults.standard.set(newValue, forKey: "genie.launchAtLogin") }
    }
    var maxBudgetUSD: Double {
        get { UserDefaults.standard.double(forKey: "genie.maxBudgetUSD").nonZero ?? 25.0 }
        set { UserDefaults.standard.set(newValue, forKey: "genie.maxBudgetUSD") }
    }

    // ── Logging ────────────────────────────────────────────────────────
    private let logger = Logger(subsystem: "com.gtrush.genie", category: "state")

    // ── Mutations ──────────────────────────────────────────────────────
    func setChromeStatus(_ status: ProcessStatus) {
        logger.debug("Chrome: \(status.label)")
        chromeStatus = status
    }

    func setServerStatus(_ status: ProcessStatus) {
        logger.debug("Server: \(status.label)")
        serverStatus = status
    }

    func addWish(title: String, creator: String) -> UUID {
        let wish = WishInfo(title: title, creator: creator, startedAt: Date())
        activeWishes.append(wish)
        logger.info("Wish started: \(title) by \(creator)")
        return wish.id
    }

    func completeWish(id: UUID, cost: Double?) {
        guard let idx = activeWishes.firstIndex(where: { $0.id == id }) else { return }
        var wish = activeWishes.remove(at: idx)
        wish.status = .completed
        wish.duration = Date().timeIntervalSince(wish.startedAt)
        wish.cost = cost
        lastWish = wish
        totalWishesCompleted += 1
        if let cost { totalCostUSD += cost }
        logger.info("Wish completed: \(wish.title) in \(wish.duration ?? 0)s, cost $\(cost ?? 0)")
    }

    func failWish(id: UUID, error: String) {
        guard let idx = activeWishes.firstIndex(where: { $0.id == id }) else { return }
        var wish = activeWishes.remove(at: idx)
        wish.status = .failed(error)
        wish.duration = Date().timeIntervalSince(wish.startedAt)
        lastWish = wish
        logger.error("Wish failed: \(wish.title) -- \(error)")
    }

    // ── Repo Directory Resolution ──────────────────────────────────────
    func resolveRepoDir() {
        // Check environment variable first (set by .app bundle)
        if let envDir = ProcessInfo.processInfo.environment["GENIE_REPO_DIR"],
           FileManager.default.fileExists(atPath: envDir + "/package.json") {
            repoDir = envDir
            return
        }
        // Check common locations
        let candidates = [
            NSHomeDirectory() + "/Downloads/genie-2.0",
            NSHomeDirectory() + "/genie-2.0",
            NSHomeDirectory() + "/Projects/genie-2.0",
            "/opt/genie",
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate + "/package.json") {
                repoDir = candidate
                return
            }
        }
        logger.error("Could not find Genie repo directory")
    }
}

// Helper for non-zero doubles from UserDefaults
private extension Double {
    var nonZero: Double? {
        self == 0 ? nil : self
    }
}
