import SwiftUI

// Helper class for managing the floating palette editor window
class PaletteEditorWindowController {
    static let shared = PaletteEditorWindowController()
    private var window: NSWindow?

    func openWindow(palettes: Binding<[[PaletteColor]]>, onApply: @escaping ([[PaletteColor]]) -> Void) {
        // Close existing window if open
        window?.close()

        // Create binding for isPresented that closes the window
        let isPresented = Binding<Bool>(
            get: { self.window != nil },
            set: { if !$0 { self.closeWindow() } }
        )

        let editorView = PaletteEditorView(
            isPresented: isPresented,
            palettes: palettes,
            onApply: onApply
        )

        let hostingView = NSHostingView(rootView: editorView)

        let newWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 550),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "Palette Editor"
        newWindow.contentView = hostingView
        newWindow.isFloatingPanel = true
        newWindow.becomesKeyOnlyIfNeeded = true
        newWindow.level = .floating
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}
