import SwiftUI

struct MainWindowView: View {
    @ObservedObject private var state = GenieState.shared
    @State private var showSettings = false

    var body: some View {
        ZStack {
            G.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .frame(height: 48)

                // Main content
                if let activeWish = state.activeWishes.first {
                    WishExecutionView(wish: activeWish)
                } else {
                    DashboardView()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 560)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView(state: state, config: ConfigManager.shared)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // App icon + title
            Image(systemName: "lamp.desk.fill")
                .font(.system(size: 18))
                .foregroundStyle(
                    LinearGradient(
                        colors: [G.blue, G.blueLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Genie")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(G.textPrimary)

            Spacer()

            // Tier badge
            PillBadge(
                text: state.selectedTier == .free ? "Free" : "Pro",
                color: state.selectedTier == .free ? G.teal : G.blue
            )

            // Settings gear
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .foregroundStyle(G.textSecondary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 20)
        .background(G.glassBg)
        .overlay(
            Rectangle()
                .fill(G.glassBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
