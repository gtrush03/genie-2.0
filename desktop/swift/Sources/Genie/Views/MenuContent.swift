import SwiftUI
import AppKit

struct MenuContent: View {
    @ObservedObject var state: GenieState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Genie 2.0")
                .font(.headline)

            Divider()

            // Status indicators
            statusRow("Chrome CDP", status: state.chromeStatus)
            statusRow("Server", status: state.serverStatus)

            if !state.activeWishes.isEmpty {
                Divider()
                ForEach(state.activeWishes) { wish in
                    Label {
                        Text(wish.title)
                            .lineLimit(1)
                    } icon: {
                        ProgressView()
                            .controlSize(.small)
                    }
                    .font(.caption)
                }
            }

            if let last = state.lastWish {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last wish: \(last.title)")
                        .font(.caption)
                        .lineLimit(1)
                    if let duration = last.duration, let cost = last.cost {
                        Text("\(String(format: "%.1f", duration))s / $\(String(format: "%.3f", cost))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            Text("Total: \(state.totalWishesCompleted) wishes / $\(String(format: "%.2f", state.totalCostUSD))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Actions
            if state.serverStatus.isRunning {
                Button("Restart Server") {
                    Task { await ServerManager.shared.restart() }
                }
            } else {
                Button("Start Server") {
                    Task { await ServerManager.shared.start() }
                }
            }

            Button("Open Login Pages") {
                Task { await ChromeManager.shared.openLoginPages() }
            }

            Button("View Logs") {
                NSWorkspace.shared.selectFile(
                    "/tmp/genie-logs/server.out.log",
                    inFileViewerRootedAtPath: "/tmp/genie-logs")
            }

            Divider()

            Button("Open Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")

            Button("Quit Genie") {
                ServerManager.shared.stop()
                ChromeManager.shared.stop()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }

    private func statusRow(_ label: String, status: GenieState.ProcessStatus) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(status))
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Spacer()
            Text(status.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statusColor(_ status: GenieState.ProcessStatus) -> Color {
        switch status {
        case .running: .green
        case .starting: .yellow
        case .stopped: .gray
        case .failed: .red
        }
    }
}
