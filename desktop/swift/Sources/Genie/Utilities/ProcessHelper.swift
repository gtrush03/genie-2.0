import Foundation
import os

enum ProcessHelper {
    private static let logger = Logger(subsystem: "com.gtrush.genie", category: "process")

    /// Spawn a long-running process. Returns the Process handle.
    static func spawn(
        executablePath: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        environment: [String: String]? = nil,
        stdoutPath: String? = nil,
        stderrPath: String? = nil
    ) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        if let wd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: wd)
        }

        if let env = environment {
            var merged = ProcessInfo.processInfo.environment
            for (k, v) in env { merged[k] = v }
            process.environment = merged
        }

        // Log files
        let logDir = "/tmp/genie-logs"
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)

        if let outPath = stdoutPath {
            FileManager.default.createFile(atPath: outPath, contents: nil)
            process.standardOutput = FileHandle(forWritingAtPath: outPath)
        }
        if let errPath = stderrPath {
            FileManager.default.createFile(atPath: errPath, contents: nil)
            process.standardError = FileHandle(forWritingAtPath: errPath)
        }

        try process.run()
        logger.info("Spawned \(executablePath) PID=\(process.processIdentifier)")
        return process
    }

    /// Check if a process with given PID is still running
    static func isRunning(pid: Int32) -> Bool {
        kill(pid, 0) == 0
    }

    /// Find PIDs matching a command pattern
    static func findPIDs(matching pattern: String) -> [Int32] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", pattern]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
        } catch {
            return []
        }
    }

    /// Kill process by PID (SIGTERM, then SIGKILL after delay)
    static func terminate(pid: Int32) {
        kill(pid, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if self.isRunning(pid: pid) {
                kill(pid, SIGKILL)
            }
        }
    }
}
