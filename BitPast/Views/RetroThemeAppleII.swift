import SwiftUI

// MARK: - Apple II Green Phosphor Window Frame

/// Apple II-style window frame with green phosphor look
struct AppleIIWindowFrame<Content: View>: View {
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
            // Title bar - simple green text on black
            HStack {
                Text("*")
                    .font(AppleIITheme.font(size: 16))
                    .foregroundColor(AppleIITheme.textColor)

                Text(title)
                    .font(AppleIITheme.font(size: 16))
                    .foregroundColor(AppleIITheme.textColor)

                Spacer()

                Text(infoText)
                    .font(AppleIITheme.font(size: 14))
                    .foregroundColor(AppleIITheme.dimTextColor)

                Text("*")
                    .font(AppleIITheme.font(size: 16))
                    .foregroundColor(AppleIITheme.textColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppleIITheme.backgroundColor)

            // Green divider line
            Rectangle()
                .fill(AppleIITheme.borderColor)
                .frame(height: AppleIITheme.dividerThickness)

            // Content area
            content
                .background(AppleIITheme.backgroundColor)
        }
        .background(AppleIITheme.backgroundColor)
        .overlay(
            Rectangle()
                .stroke(AppleIITheme.borderColor, lineWidth: 2)
        )
        .padding(.bottom, 12)  // Move border up so macOS window doesn't clip corners
    }
}

// MARK: - Apple II Popup Picker

/// Apple II-style popup picker with green phosphor look
struct AppleIIPopupPicker: View {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void

    // Calculate width based on longest value
    private var calculatedWidth: CGFloat {
        let longestValue = values.max(by: { $0.count < $1.count }) ?? ""
        // Print Char 21 at size 14 - measure actual text width
        let font = AppleIITheme.nsFont(size: 14)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (longestValue as NSString).size(withAttributes: attributes)
        return max(140, textSize.width + 40)  // Add padding for dropdown arrow and borders
    }

    var body: some View {
        AppleIIPopupButtonRepresentable(
            values: values,
            selectedValue: $selectedValue,
            onChange: onChange,
            width: calculatedWidth
        )
        .frame(width: calculatedWidth, height: 22)
        .background(AppleIITheme.backgroundColor)
        .overlay(
            Rectangle()
                .stroke(AppleIITheme.borderColor, lineWidth: 1)
        )
    }
}

/// NSViewRepresentable wrapper for Apple II style popup
struct AppleIIPopupButtonRepresentable: NSViewRepresentable {
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

        // Set Apple II font
        popup.font = AppleIITheme.nsFont(size: 14)

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

        // Add items with Apple II font
        let font = AppleIITheme.nsFont(size: 14)
        for value in values {
            popup.addItem(withTitle: value)
            if let item = popup.lastItem {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(AppleIITheme.textColor)
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
        var parent: AppleIIPopupButtonRepresentable
        var popup: NSPopUpButton?

        init(_ parent: AppleIIPopupButtonRepresentable) {
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
