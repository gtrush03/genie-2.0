import Foundation

// MARK: - Wish Trace (parsed from JSONL trace files)

struct WishTrace: Identifiable {
    let id: UUID
    let title: String
    let startedAt: Date
    var completedAt: Date?
    var status: WishTraceStatus
    var cost: Double
    var duration: TimeInterval?
    var events: [TraceEvent]
    let traceFilePath: String
    var model: String

    var timeAgoLabel: String {
        let interval = Date().timeIntervalSince(startedAt)
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    var costLabel: String {
        "$\(String(format: "%.3f", cost))"
    }

    var statusLabel: String {
        switch status {
        case .running: return "Running"
        case .completed: return "Done"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}

enum WishTraceStatus: Equatable {
    case running
    case completed
    case failed(String)
}

// MARK: - Trace Event (single line from JSONL)

struct TraceEvent: Identifiable {
    let id: UUID
    let type: TraceEventType
    let content: String
    let toolName: String?
    let toolArgs: String?
    let toolResult: String?
    let screenshotPath: String?
    let timestamp: Date
    let cost: Double?

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

enum TraceEventType: String {
    case textDelta = "text_delta"
    case toolStart = "tool_start"
    case toolEnd = "tool_end"
    case screenshot = "screenshot"
    case result = "result"
    case error = "error"
    case unknown = "unknown"
}
