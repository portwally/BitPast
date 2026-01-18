import SwiftUI

@main
struct BitPastApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Graphics Mode Guide") {
                    openHelpWindow()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }

        // Help Window
        Window("Graphics Mode Guide", id: "help-window") {
            HelpView()
        }
        .defaultSize(width: 750, height: 700)
    }

    private func openHelpWindow() {
        // Check if window already exists
        for window in NSApplication.shared.windows {
            if window.identifier?.rawValue == "help-window" || window.title == "Graphics Mode Guide" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        // Open new window
        if #available(macOS 13.0, *) {
            // Use openWindow environment action via a workaround
            let controller = NSWindowController(window: NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 750, height: 700),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            ))
            controller.window?.title = "Graphics Mode Guide"
            controller.window?.identifier = NSUserInterfaceItemIdentifier("help-window")
            controller.window?.contentView = NSHostingView(rootView: HelpView())
            controller.window?.center()
            controller.showWindow(nil)
        }
    }
}
