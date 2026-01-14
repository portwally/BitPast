
import SwiftUI

@main
struct BitPastApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    openSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
