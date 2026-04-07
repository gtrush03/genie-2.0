import Foundation
import Combine
import os

@MainActor
final class TraceManager: ObservableObject {
    static let shared = TraceManager()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "traces")
    private let tracesDir: String = NSHomeDirectory() + "/.genie/traces"
    private var scanTimer: Timer?
    private var watchTimer: Timer?
    private var lastKnownFiles: Set<String> = []
    private var activeFilePath: String?
    private var lastReadOffset: UInt64 = 0

    // -- Published state --

    @Published private(set) var recentWishes: [WishTrace] = []
    @Published private(set) var activeEvents: [TraceEvent] = []
    @Published private(set) var activeCost: Double = 0
    @Published private(set) var activeModel: String = ""
    @Published private(set) var isWatchingActive: Bool = false

    // -- Lifecycle --

    func startScanning() {
        try? FileManager.default.createDirectory(atPath: tracesDir, withIntermediateDirectories: true)
        loadExistingTraces()
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scanForNewFiles()
            }
        }
        logger.info("Trace scanning started: \(self.tracesDir)")
    }

    func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        stopWatchingActive()
    }

    func watchActiveWish(path: String) {
        stopWatchingActive()
        activeFilePath = path
        lastReadOffset = 0
        activeEvents = []
        activeCost = 0
        activeModel = ""
        isWatchingActive = true

        readNewLines(from: path)

        watchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let path = self.activeFilePath else { return }
                self.readNewLines(from: path)
            }
        }
        logger.info("Watching active wish: \(path)")
    }

    func stopWatchingActive() {
        watchTimer?.invalidate()
        watchTimer = nil
        activeFilePath = nil
        isWatchingActive = false
    }

    // -- Private: Scan --

    private func loadExistingTraces() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: tracesDir) else { return }
        let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
            .sorted { $0 > $1 }
            .prefix(20)

        var traces: [WishTrace] = []
        for file in jsonlFiles {
            let path = tracesDir + "/" + file
            if let trace = parseTraceFile(path) {
                traces.append(trace)
            }
        }
        recentWishes = traces.sorted { $0.startedAt > $1.startedAt }
        lastKnownFiles = Set(jsonlFiles.map { String($0) })
    }

    private func scanForNewFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: tracesDir) else { return }
        let jsonlFiles = Set(files.filter { $0.hasSuffix(".jsonl") })
        let newFiles = jsonlFiles.subtracting(lastKnownFiles)

        if !newFiles.isEmpty {
            for file in newFiles {
                let path = tracesDir + "/" + file
                if let trace = parseTraceFile(path) {
                    recentWishes.insert(trace, at: 0)
                }
            }
            if recentWishes.count > 20 {
                recentWishes = Array(recentWishes.prefix(20))
            }
            lastKnownFiles = jsonlFiles
        }

        // Refresh the most recent trace if it's still running
        if let first = recentWishes.first, first.status == .running {
            if let updated = parseTraceFile(first.traceFilePath) {
                recentWishes[0] = updated
            }
        }
    }

    // -- Private: Parse --

    private func parseTraceFile(_ path: String) -> WishTrace? {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return nil }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else { return nil }

        var events: [TraceEvent] = []
        var title = "Untitled Wish"
        var cost: Double = 0
        var model = ""
        var status: WishTraceStatus = .running
        var startedAt: Date?
        var completedAt: Date?
        var duration: TimeInterval?

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            let typeStr = json["type"] as? String ?? "unknown"
            let eventType = TraceEventType(rawValue: typeStr) ?? .unknown
            let timestamp = json["timestamp"] as? TimeInterval ?? 0
            let date = Date(timeIntervalSince1970: timestamp)
            if startedAt == nil { startedAt = date }

            let event = TraceEvent(
                id: UUID(),
                type: eventType,
                content: json["content"] as? String ?? json["summary"] as? String ?? "",
                toolName: json["tool"] as? String,
                toolArgs: Self.extractArgs(json["args"]),
                toolResult: json["result"] as? String,
                screenshotPath: json["path"] as? String,
                timestamp: date,
                cost: json["cost"] as? Double
            )
            events.append(event)

            // Extract metadata
            if eventType == .textDelta && title == "Untitled Wish" {
                let text = json["content"] as? String ?? ""
                if text.count > 10 {
                    title = String(text.prefix(60))
                }
            }
            if let eventCost = json["cost"] as? Double { cost = eventCost }
            if let m = json["model"] as? String, !m.isEmpty { model = m }
            if eventType == .result {
                status = .completed
                completedAt = date
                if let d = json["duration"] as? TimeInterval { duration = d }
            }
            if eventType == .error {
                let msg = json["content"] as? String ?? json["message"] as? String ?? "Unknown error"
                status = .failed(msg)
                completedAt = date
            }
        }

        // Try to extract title from file name
        let fileName = (path as NSString).lastPathComponent
        if title == "Untitled Wish" && fileName.contains("-") {
            let parts = fileName.replacingOccurrences(of: ".jsonl", with: "").split(separator: "-")
            if parts.count >= 3 {
                title = parts.dropFirst(2).joined(separator: " ").capitalized
            }
        }

        return WishTrace(
            id: UUID(),
            title: title,
            startedAt: startedAt ?? Date(),
            completedAt: completedAt,
            status: status,
            cost: cost,
            duration: duration,
            events: events,
            traceFilePath: path,
            model: model
        )
    }

    private static func extractArgs(_ args: Any?) -> String? {
        guard let args else { return nil }
        if let argsDict = args as? [String: Any],
           let argsData = try? JSONSerialization.data(withJSONObject: argsDict),
           let argsStr = String(data: argsData, encoding: .utf8) {
            return argsStr
        }
        return String(describing: args)
    }

    // -- Private: Read new lines from active trace --

    private func readNewLines(from path: String) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { try? handle.close() }

        handle.seek(toFileOffset: lastReadOffset)
        let newData = handle.readDataToEndOfFile()
        guard !newData.isEmpty else { return }
        lastReadOffset = handle.offsetInFile

        guard let text = String(data: newData, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }

            let typeStr = json["type"] as? String ?? "unknown"
            let eventType = TraceEventType(rawValue: typeStr) ?? .unknown
            let timestamp = json["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970

            let event = TraceEvent(
                id: UUID(),
                type: eventType,
                content: json["content"] as? String ?? json["summary"] as? String ?? "",
                toolName: json["tool"] as? String,
                toolArgs: Self.extractArgs(json["args"]),
                toolResult: json["result"] as? String,
                screenshotPath: json["path"] as? String,
                timestamp: Date(timeIntervalSince1970: timestamp),
                cost: json["cost"] as? Double
            )
            activeEvents.append(event)

            if let c = json["cost"] as? Double { activeCost = c }
            if let m = json["model"] as? String, !m.isEmpty { activeModel = m }
        }
    }
}
