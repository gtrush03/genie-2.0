import SwiftUI
import Combine

struct WishExecutionView: View {
    let wish: GenieState.WishInfo
    @ObservedObject private var traces = TraceManager.shared
    @State private var elapsed: TimeInterval = 0
    @State private var showStopConfirm = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Button {
                    traces.stopWatchingActive()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Dashboard")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(G.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Stop button
                Button {
                    showStopConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("Stop Wish")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(G.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(G.red.opacity(0.1))
                    .overlay(Capsule().stroke(G.red.opacity(0.3), lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .alert("Stop this wish?", isPresented: $showStopConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Stop", role: .destructive) { stopWish() }
                } message: {
                    Text("The wish will be terminated immediately.")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            // Wish title + live stats
            VStack(alignment: .leading, spacing: 8) {
                Text(wish.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(G.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 20) {
                    Label {
                        Text(formatElapsed(elapsed))
                            .font(.system(size: 12, design: .monospaced))
                    } icon: {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                    }

                    Label {
                        Text("$\(String(format: "%.3f", traces.activeCost))")
                            .font(.system(size: 12, design: .monospaced))
                    } icon: {
                        Image(systemName: "dollarsign.circle")
                            .font(.system(size: 11))
                    }

                    Label {
                        Text("\(toolCount) tools")
                            .font(.system(size: 12, design: .monospaced))
                    } icon: {
                        Image(systemName: "wrench")
                            .font(.system(size: 11))
                    }

                    if !traces.activeModel.isEmpty {
                        Label {
                            Text(traces.activeModel)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "cpu")
                                .font(.system(size: 11))
                        }
                    }
                }
                .foregroundStyle(G.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Live event log
            ScrollViewReader { proxy in
                ScrollView {
                    if traces.activeEvents.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(G.blue)
                            Text("Waiting for events...")
                                .font(.system(size: 13))
                                .foregroundStyle(G.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(traces.activeEvents) { event in
                                TraceEventRow(event: event)
                                    .id(event.id)
                            }
                        }
                        .padding(16)
                    }
                }
                .background(G.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(G.glassBorder, lineWidth: 1)
                )
                .padding(.horizontal, 24)
                .onChange(of: traces.activeEvents.count) { _ in
                    if let last = traces.activeEvents.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Spacer().frame(height: 16)
        }
        .onAppear {
            let tracesDir = NSHomeDirectory() + "/.genie/traces"
            if let files = try? FileManager.default.contentsOfDirectory(atPath: tracesDir) {
                let sorted = files
                    .filter { $0.hasSuffix(".jsonl") }
                    .sorted { f1, f2 in
                        let p1 = tracesDir + "/" + f1
                        let p2 = tracesDir + "/" + f2
                        let d1 = (try? FileManager.default.attributesOfItem(atPath: p1)[.modificationDate] as? Date) ?? Date.distantPast
                        let d2 = (try? FileManager.default.attributesOfItem(atPath: p2)[.modificationDate] as? Date) ?? Date.distantPast
                        return d1 > d2
                    }
                if let latest = sorted.first {
                    traces.watchActiveWish(path: tracesDir + "/" + latest)
                }
            }
        }
        .onDisappear {
            traces.stopWatchingActive()
        }
        .onReceive(timer) { _ in
            elapsed = Date().timeIntervalSince(wish.startedAt)
        }
    }

    // MARK: - Helpers

    private var toolCount: Int {
        traces.activeEvents.filter { $0.type == .toolStart }.count
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }

    private func stopWish() {
        let pids = ProcessHelper.findPIDs(matching: "claurst.*permission-mode")
        for pid in pids {
            ProcessHelper.terminate(pid: pid)
        }
        traces.stopWatchingActive()
    }
}
