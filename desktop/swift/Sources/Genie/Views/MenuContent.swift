import SwiftUI
import AppKit

struct MenuContent: View {
    @ObservedObject var state: GenieState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Genie 2.0")
                .font(.headline)

            Text(state.overallStatusLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Genie") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows {
                    if window.title == "Genie" || window.identifier?.rawValue == "main" {
                        window.makeKeyAndOrderFront(nil)
                        break
                    }
                }
            }
            .keyboardShortcut("o")

            if !state.activeWishes.isEmpty {
                Divider()
                ForEach(state.activeWishes) { wish in
                    Label(wish.title, systemImage: "sparkles")
                        .font(.caption)
                        .lineLimit(1)
                }
            }

            if let last = state.lastWish {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last: \(last.title)")
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

            Button("Quit Genie") {
                ServerManager.shared.stop()
                ChromeManager.shared.stop()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }
}
