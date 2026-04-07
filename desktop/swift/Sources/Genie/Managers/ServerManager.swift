import Foundation
import Combine
import os

@MainActor
final class ServerManager: ObservableObject {
    static let shared = ServerManager()

    private let logger = Logger(subsystem: "com.gtrush.genie", category: "server")
    private var process: Process?
    private var healthCheckTask: Task<Void, Never>?

    /// Start the Node.js Genie server
    func start() async {
        let state = GenieState.shared
        guard !state.repoDir.isEmpty else {
            state.setServerStatus(.failed("Repo directory not set"))
            return
        }

        // Check if already running
        let existingPIDs = ProcessHelper.findPIDs(matching: "node.*server.mjs")
        if !existingPIDs.isEmpty {
            state.setServerStatus(.running(pid: existingPIDs.first))
            logger.info("Server already running (PID \(existingPIDs.first ?? 0))")
            startHealthChecks()
            return
        }

        state.setServerStatus(.starting)

        // Find node
        let nodePath = resolveNodePath()
        guard let nodePath else {
            state.setServerStatus(.failed("node not found on PATH"))
            return
        }

        let serverScript = state.repoDir + "/src/core/server.mjs"
        guard FileManager.default.fileExists(atPath: serverScript) else {
            state.setServerStatus(.failed("server.mjs not found at \(serverScript)"))
            return
        }

        // Ensure .env exists
        let envPath = state.repoDir + "/.env"
        guard FileManager.default.fileExists(atPath: envPath) else {
            state.setServerStatus(.failed(".env file missing -- run onboarding first"))
            return
        }

        // Ensure node_modules
        let nodeModules = state.repoDir + "/node_modules"
        if !FileManager.default.fileExists(atPath: nodeModules) {
            logger.info("Installing npm dependencies...")
            let npm = Process()
            npm.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            npm.arguments = ["npm", "install", "--silent"]
            npm.currentDirectoryURL = URL(fileURLWithPath: state.repoDir)
            npm.standardOutput = FileHandle.nullDevice
            npm.standardError = FileHandle.nullDevice
            try? npm.run()
            npm.waitUntilExit()
        }

        do {
            let proc = try ProcessHelper.spawn(
                executablePath: nodePath,
                arguments: [serverScript],
                workingDirectory: state.repoDir,
                stdoutPath: "/tmp/genie-logs/server.out.log",
                stderrPath: "/tmp/genie-logs/server.err.log"
            )
            self.process = proc

            // Wait for server to stabilize (3 seconds)
            try await Task.sleep(for: .seconds(3))

            if proc.isRunning {
                state.setServerStatus(.running(pid: proc.processIdentifier))
                logger.info("Server started (PID \(proc.processIdentifier))")
                startHealthChecks()
            } else {
                let code = proc.terminationStatus
                state.setServerStatus(.failed("Exited with code \(code)"))
                logger.error("Server exited immediately with code \(code)")
            }
        } catch {
            state.setServerStatus(.failed(error.localizedDescription))
            logger.error("Failed to start server: \(error.localizedDescription)")
        }
    }

    /// Stop the server
    func stop() {
        healthCheckTask?.cancel()
        healthCheckTask = nil

        if let proc = process, proc.isRunning {
            proc.terminate()
            logger.info("Server terminated")
        }
        process = nil

        // Also kill any orphan server processes
        let pids = ProcessHelper.findPIDs(matching: "node.*server.mjs")
        for pid in pids {
            ProcessHelper.terminate(pid: pid)
        }

        GenieState.shared.setServerStatus(.stopped)
    }

    /// Restart the server
    func restart() async {
        stop()
        try? await Task.sleep(for: .seconds(1))
        await start()
    }

    private func startHealthChecks() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled else { return }
                let pids = ProcessHelper.findPIDs(matching: "node.*server.mjs")
                if pids.isEmpty {
                    GenieState.shared.setServerStatus(.failed("Server process died"))
                    logger.warning("Server health check: process not found")
                    // Auto-restart
                    logger.info("Auto-restarting server...")
                    await start()
                }
            }
        }
    }

    private func resolveNodePath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        // Try which
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["node"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }
}
