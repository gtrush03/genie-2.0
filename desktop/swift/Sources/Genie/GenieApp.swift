import SwiftUI

@main
struct GenieApp: App {
    @NSApplicationDelegateAdaptor(GenieAppDelegate.self) private var delegate
    @ObservedObject private var state = GenieState.shared

    var body: some Scene {
        // PRIMARY: Main window (dashboard)
        Window("Genie", id: "main") {
            MainWindowView()
                .sheet(isPresented: $state.isOnboardingPresented) {
                    OnboardingView()
                        .interactiveDismissDisabled()
                }
        }
        .defaultSize(width: 900, height: 640)
        .defaultPosition(.center)

        // SECONDARY: Menu bar status icon
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            Image(systemName: state.menuBarIconName)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class GenieAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Regular app (shows in dock), not accessory
        NSApp.setActivationPolicy(.regular)

        let state = GenieState.shared

        // Resolve repo directory
        state.resolveRepoDir()

        // Load config
        ConfigManager.shared.load()

        // Request notification permission
        GenieNotifications.requestPermission()

        // Register global hotkey (Cmd+Shift+G)
        GlobalHotkey.shared.register {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .focusWishInput, object: nil)
            }
        }

        // Show onboarding if needed
        if !state.hasCompletedOnboarding {
            state.isOnboardingPresented = true
        } else if ConfigManager.shared.hasMinimumConfig {
            // Auto-start services
            Task {
                await ChromeManager.shared.start()
                await ServerManager.shared.start()
                GenieNotifications.send(
                    title: "Genie",
                    body: "Watching for wishes. Say \"Genie\" in a JellyJelly video."
                )
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkey.shared.unregister()
    }

    // Keep app running when window closes (menu bar stays)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let focusWishInput = Notification.Name("genie.focusWishInput")
}
