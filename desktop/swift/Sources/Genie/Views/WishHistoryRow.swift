import SwiftUI

struct WishHistoryRow: View {
    let wish: WishTrace

    var body: some View {
        HStack(spacing: 10) {
            statusDot

            VStack(alignment: .leading, spacing: 3) {
                Text(wish.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(G.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 8) {
                    Text(wish.timeAgoLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(G.textTertiary)

                    if wish.cost > 0 {
                        Text(wish.costLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(G.textTertiary)
                    }

                    Text(wish.statusLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(statusTextColor)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(G.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(G.surface.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .shadow(color: statusColor.opacity(0.5), radius: 3)
    }

    private var statusColor: Color {
        switch wish.status {
        case .completed: return G.green
        case .running: return G.amber
        case .failed: return G.red
        }
    }

    private var statusTextColor: Color {
        switch wish.status {
        case .completed: return G.green
        case .running: return G.amber
        case .failed: return G.red
        }
    }
}
