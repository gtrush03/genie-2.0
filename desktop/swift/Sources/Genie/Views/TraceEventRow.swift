import SwiftUI
import AppKit

struct TraceEventRow: View {
    let event: TraceEvent
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Timestamp
            Text(event.timeLabel)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(G.textTertiary)
                .frame(width: 60, alignment: .leading)

            // Event content
            eventContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var eventContent: some View {
        switch event.type {
        case .textDelta:
            Text(event.content)
                .font(.system(size: 12))
                .foregroundStyle(G.textTertiary)
                .italic()
                .lineLimit(isExpanded ? nil : 2)
                .onTapGesture { isExpanded.toggle() }

        case .toolStart:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("tool")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(G.blue)
                        .clipShape(Capsule())

                    Text(event.toolName ?? "unknown")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(G.textPrimary)
                }

                if let args = event.toolArgs, !args.isEmpty {
                    Text(args)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(G.textSecondary)
                        .lineLimit(isExpanded ? nil : 3)
                        .padding(8)
                        .background(G.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onTapGesture { isExpanded.toggle() }
                }
            }

        case .toolEnd:
            if let result = event.toolResult, !result.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(G.teal)
                        Text("Result")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(G.teal)
                    }
                    Text(result)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(G.textSecondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .onTapGesture { isExpanded.toggle() }
                }
            }

        case .screenshot:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(G.amber)
                    Text("Screenshot")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(G.amber)
                }
                if let path = event.screenshotPath,
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: isExpanded ? 400 : 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(G.glassBorder, lineWidth: 1)
                        )
                        .onTapGesture { isExpanded.toggle() }
                } else {
                    Text(event.screenshotPath ?? "No path")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(G.textTertiary)
                }
            }

        case .result:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("completed")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(G.green)
                        .clipShape(Capsule())

                    if let cost = event.cost {
                        Text("$\(String(format: "%.3f", cost))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(G.textSecondary)
                    }
                }
                if !event.content.isEmpty {
                    Text(event.content)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(G.textPrimary)
                }
            }

        case .error:
            VStack(alignment: .leading, spacing: 4) {
                Text("error")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(G.red)
                    .clipShape(Capsule())

                Text(event.content)
                    .font(.system(size: 12))
                    .foregroundStyle(G.red.opacity(0.9))
            }

        case .unknown:
            Text(event.content)
                .font(.system(size: 11))
                .foregroundStyle(G.textTertiary)
        }
    }
}
