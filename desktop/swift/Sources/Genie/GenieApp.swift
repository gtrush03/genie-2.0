import SwiftUI

@main
struct GenieApp: App {
    @NSApplicationDelegateAdaptor(GenieAppDelegate.self) private var delegate
    @State private var state = GenieState.shared
    @State private var config = ConfigManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(state: state)
        } label: {
            Image(systemName: state.menuBarIconName)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            if state.hasCompletedOnboarding {
                SettingsView(state: state, config: config)
            } else {
                OnboardingView()
            }
        }

        Window("Make a Wish", id: "wish-input") {
            WishInputView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

final class GenieAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only)
        NSApp.setActivationPolicy(.accessory)

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
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "wish-input" }) {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                    if let url = URL(string: "genie://wish-input") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        // Auto-start if onboarding is complete
        if state.hasCompletedOnboarding && ConfigManager.shared.hasRequiredKeys {
            Task {
                await ChromeManager.shared.start()
                await ServerManager.shared.start()
                GenieNotifications.send(
                    title: "Genie",
                    body: "Watching for wishes. Say \"Genie\" in a JellyJelly video."
                )
            }
        } else if !state.hasCompletedOnboarding {
            // Show onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkey.shared.unregister()
        // Don't stop Chrome/Server on quit -- they run as background services
        // User explicitly stops them from the menu if desired
    }
}
