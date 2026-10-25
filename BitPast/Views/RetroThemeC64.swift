import SwiftUI

// MARK: - Commodore 64 Window Frame

struct C64WindowFrame<Content: View>: View {
    let title: String
    let infoText: String
    let content: Content

    init(title: String, infoText: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.infoText = infoText
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar - C64 style with PETSCII border
            HStack {
                Text("*")
                    .font(C64Theme.font(size: 16))
                    .foregroundColor(C64Theme.textColor)

                Text(title)
                    .font(C64Theme.font(size: 16))
                    .foregroundColor(C64Theme.textColor)
                    .textCase(.uppercase)

                Spacer()

                Text(infoText)
                    .font(C64Theme.font(size: 14))
                    .foregroundColor(C64Theme.textColor)

                Text("*")
                    .font(C64Theme.font(size: 16))
                    .foregroundColor(C64Theme.textColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(C64Theme.backgroundColor)

            // C64 blue divider line
            Rectangle()
                .fill(C64Theme.borderColor)
                .frame(height: C64Theme.dividerThickness)

            // Content area
            content
                .background(C64Theme.backgroundColor)
        }
        .background(C64Theme.backgroundColor)
        .overlay(
            Rectangle()
                .stroke(C64Theme.borderColor, lineWidth: 2)
        )
        .padding(.bottom, 12)  // Move border up so macOS window doesn't clip corners
    }
}

// MARK: - C64 Popup Picker

struct C64PopupPicker: View {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void

    // Calculate width based on longest value
    private var calculatedWidth: CGFloat {
        let longestValue = values.max(by: { $0.count < $1.count }) ?? ""
        // PetMe64 at size 14 - measure actual text width
        let font = C64Theme.nsFont(size: 14)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (longestValue as NSString).size(withAttributes: attributes)
        return max(140, textSize.width + 40)  // Add padding for dropdown arrow and borders
    }

    var body: some View {
        C64PopupButtonRepresentable(
            values: values,
            selectedValue: $selectedValue,
            onChange: onChange,
            width: calculatedWidth
        )
        .frame(width: calculatedWidth, height: 22)
        .background(C64Theme.backgroundColor)
        .overlay(
            Rectangle()
                .stroke(C64Theme.borderColor, lineWidth: 1)
        )
    }
}

/// NSViewRepresentable wrapper for C64 style popup
struct C64PopupButtonRepresentable: NSViewRepresentable {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void
    let width: CGFloat

    func makeNSView(context: Context) -> NSView {
        // Create clipping container view to enforce width
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        container.wantsLayer = true
        container.layer?.masksToBounds = true

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: width, height: 22), pullsDown: false)
        popup.bezelStyle = .smallSquare
        popup.isBordered = false

        // Set C64 font
        popup.font = C64Theme.nsFont(size: 14)

        // Configure cell for text truncation
        if let cell = popup.cell as? NSPopUpButtonCell {
            cell.lineBreakMode = .byTruncatingTail
            cell.truncatesLastVisibleLine = true
        }

        popup.target = context.coordinator
        popup.action = #selector(Coordinator.selectionChanged(_:))

        container.addSubview(popup)
        context.coordinator.popup = popup

        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let popup = context.coordinator.popup else { return }

        popup.removeAllItems()

        // Add items with C64 font
        let font = C64Theme.nsFont(size: 14)
        for value in values {
            popup.addItem(withTitle: value)
            if let item = popup.lastItem {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(C64Theme.textColor)
                ]
                item.attributedTitle = NSAttributedString(string: value, attributes: attributes)
            }
        }

        if let index = values.firstIndex(of: selectedValue) {
            popup.selectItem(at: index)
        }

        // Update frames
        container.frame = NSRect(x: 0, y: 0, width: width, height: 22)
        popup.frame = NSRect(x: 0, y: 0, width: width, height: 22)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: C64PopupButtonRepresentable
        var popup: NSPopUpButton?

        init(_ parent: C64PopupButtonRepresentable) {
            self.parent = parent
        }

        @objc func selectionChanged(_ sender: NSPopUpButton) {
            if let title = sender.selectedItem?.title {
                parent.selectedValue = title
                parent.onChange()
            }
        }
    }
}
