import SwiftUI

@main
struct BitPastApp: App {

    init() {
        cleanupTempFolder()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // System menu for switching between target systems (alphabetical, Apple first)
            CommandMenu("System") {
                Button("Apple II") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.selectedMachineIndex != 0 {
                            vm.selectedMachineIndex = 0
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button("Apple IIgs") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.selectedMachineIndex != 1 {
                            vm.selectedMachineIndex = 1
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("2", modifiers: [.command, .shift])

                Button("Amiga 500") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 2 && vm.selectedMachineIndex != 2 {
                            vm.selectedMachineIndex = 2
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("3", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 2)

                Button("Amiga 1200") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 3 && vm.selectedMachineIndex != 3 {
                            vm.selectedMachineIndex = 3
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("4", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 3)

                Button("Amstrad CPC") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 4 && vm.selectedMachineIndex != 4 {
                            vm.selectedMachineIndex = 4
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("5", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 4)

                Button("Atari 800") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 5 && vm.selectedMachineIndex != 5 {
                            vm.selectedMachineIndex = 5
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 5)

                Button("Atari ST") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 6 && vm.selectedMachineIndex != 6 {
                            vm.selectedMachineIndex = 6
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("7", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 6)

                Button("BBC Micro") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 7 && vm.selectedMachineIndex != 7 {
                            vm.selectedMachineIndex = 7
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("8", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 7)

                Button("C64") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 8 && vm.selectedMachineIndex != 8 {
                            vm.selectedMachineIndex = 8
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("9", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 8)

                Button("MSX") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 9 && vm.selectedMachineIndex != 9 {
                            vm.selectedMachineIndex = 9
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("0", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 9)

                Button("PC") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 10 && vm.selectedMachineIndex != 10 {
                            vm.selectedMachineIndex = 10
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("P", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 10)

                Button("Plus/4") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 11 && vm.selectedMachineIndex != 11 {
                            vm.selectedMachineIndex = 11
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("4", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 11)

                Button("TRS-80 CoCo") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 12 && vm.selectedMachineIndex != 12 {
                            vm.selectedMachineIndex = 12
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("T", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 12)

                Button("VIC-20") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 13 && vm.selectedMachineIndex != 13 {
                            vm.selectedMachineIndex = 13
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("V", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 13)

                Button("ZX Spectrum") {
                    Task { @MainActor in
                        let vm = ConverterViewModel.shared
                        if vm.machines.count > 14 && vm.selectedMachineIndex != 14 {
                            vm.selectedMachineIndex = 14
                            vm.triggerLivePreview()
                        }
                    }
                }
                .keyboardShortcut("Z", modifiers: [.command, .shift])
                .disabled(ConverterViewModel.shared.machines.count <= 14)
            }

            CommandGroup(replacing: .help) {
                Button("Graphics Mode Guide") {
                    openHelpWindow()
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button("Visit GitHub Page") {
                    if let url = URL(string: "https://github.com/portwally/BitPast") {
                        NSWorkspace.shared.open(url)
                    }
                }
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

    /// Cleans up the app's temp folder on launch
    private func cleanupTempFolder() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileManager = FileManager.default

        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            var cleanedCount = 0

            for fileURL in tempFiles {
                try? fileManager.removeItem(at: fileURL)
                cleanedCount += 1
            }

            if cleanedCount > 0 {
                print("Cleaned up \(cleanedCount) temporary file(s)")
            }
        } catch {
            // Silently ignore errors - temp cleanup is not critical
        }
    }
}
