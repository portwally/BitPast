import SwiftUI

// MARK: - GS/OS Popup Picker

/// GS/OS-style popup menu picker with Shaston font
struct GSOSPopupPicker: View {
    let values: [String]
    @Binding var selectedValue: String
    let onChange: () -> Void

    // Calculate width based on longest value
    private var calculatedWidth: CGFloat {
        let longestValue = values.max(by: { $0.count < $1.count }) ?? ""
        // Measure actual text width with Shaston font
        let font = NSFont(name: "Shaston 640", size: 16) ?? NSFont.systemFont(ofSize: 16)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (longestValue as NSString).size(withAttributes: attributes)
        return max(140, textSize.width + 40)  // Add padding for dropdown arrow and borders
    }

    var body: some View {
        GSOSPopupButtonRepresentable(
            values: values,
            selectedValue: $selectedValue,
            onChange: onChange,
            width: calculatedWidth
        )
        .frame(width: calculatedWidth, height: 22)
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(RetroTheme.borderColor, lineWidth: 1)
        )
    }
}

/// NSViewRepresentable wrapper for NSPopUpButton with Shaston font
struct GSOSPopupButtonRepresentable: NSViewRepresentable {
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
        popup.isBordered = false  // Remove default border, we draw our own

        // Set Shaston font for the button title
        if let shastonFont = NSFont(name: "Shaston 640", size: 16) {
            popup.font = shastonFont
        }

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

        // Add items with Shaston font
        for value in values {
            popup.addItem(withTitle: value)
            if let item = popup.lastItem, let shastonFont = NSFont(name: "Shaston 640", size: 16) {
                let attributes: [NSAttributedString.Key: Any] = [.font: shastonFont]
                item.attributedTitle = NSAttributedString(string: value, attributes: attributes)
            }
        }

        // Select current value
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
        var parent: GSOSPopupButtonRepresentable
        var popup: NSPopUpButton?

        init(_ parent: GSOSPopupButtonRepresentable) {
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

// MARK: - GS/OS Window Frame

/// GS/OS-style striped title bar pattern (4 lines, 2px each like real Apple IIgs)
struct GSOSTitleBarPattern: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // 4 horizontal black lines with 2px thickness, evenly spaced
                // Start at y=3 to leave 2px padding at top (avoid connecting with border)
                let lineHeight: CGFloat = 2
                let linePositions: [CGFloat] = [3, 7, 11, 15]

                // Fill background with white first
                context.fill(
                    Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                    with: .color(.white)
                )

                // Draw 4 black lines
                for y in linePositions {
                    context.fill(
                        Path(CGRect(x: 0, y: y, width: size.width, height: lineHeight)),
                        with: .color(.black)
                    )
                }
            }
        }
    }
}

/// GS/OS close box (small square with X pattern)
struct GSOSCloseBox: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: 12, height: 10)
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
                .frame(width: 12, height: 10)
        }
    }
}

/// GS/OS zoom box (small square)
struct GSOSZoomBox: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white)
                .frame(width: 12, height: 10)
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
                .frame(width: 12, height: 10)
            // Inner square for zoom icon
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
                .frame(width: 6, height: 5)
        }
    }
}

/// GS/OS-style window frame that wraps content
struct GSOSWindowFrame<Content: View>: View {
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
            // Title bar with stripes
            ZStack {
                GSOSTitleBarPattern()

                HStack {
                    // Close box
                    GSOSCloseBox()
                        .padding(.leading, 6)

                    Spacer()

                    // Title
                    Text(title)
                        .font(RetroTheme.font(size: 12))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .background(Color.white)

                    Spacer()

                    // Zoom box
                    GSOSZoomBox()
                        .padding(.trailing, 6)
                }
            }
            .frame(height: RetroTheme.titleBarHeight)

            // Black line under title bar
            Rectangle()
                .fill(Color.black)
                .frame(height: 1)

            // Info bar (like "ProDOS  3 items  11.1 MB used  20.8 MB free")
            HStack {
                Text(infoText)
                    .font(RetroTheme.font(size: 12))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: RetroTheme.infoBarHeight)
            .background(Color.white)

            // Black line under info bar
            Rectangle()
                .fill(Color.black)
                .frame(height: 1)

            // Content area with gray background
            content
                .background(RetroTheme.contentGray)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 2)
        )
    }
}
