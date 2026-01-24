//
//  PaletteEditorView.swift
//  BitPast
//
//  Palette editor for Apple IIgs graphics modes
//

import SwiftUI
import AppKit

struct PaletteColor: Identifiable {
    let id = UUID()
    var r: Double
    var g: Double
    var b: Double

    var nsColor: NSColor {
        NSColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: 1.0)
    }

    var color: Color {
        Color(nsColor)
    }

    // Convert to IIgs 4-bit per channel (0-15)
    var iigsR: Int { Int(r / 255.0 * 15.0 + 0.5) }
    var iigsG: Int { Int(g / 255.0 * 15.0 + 0.5) }
    var iigsB: Int { Int(b / 255.0 * 15.0 + 0.5) }

    var hexString: String {
        String(format: "#%02X%02X%02X", Int(r), Int(g), Int(b))
    }
}

// Helper class to receive color panel changes
class ColorPanelDelegate: NSObject {
    var onColorChange: ((NSColor) -> Void)?

    @objc func colorDidChange(_ sender: NSColorPanel) {
        onColorChange?(sender.color)
    }
}

struct PaletteEditorView: View {
    @Binding var isPresented: Bool
    @Binding var palettes: [[PaletteColor]]
    let onApply: ([[PaletteColor]]) -> Void

    @State private var editedPalettes: [[PaletteColor]] = []
    @State private var selectedPaletteIndex: Int = 0
    @State private var selectedColorIndex: Int? = nil
    @State private var colorPanelDelegate = ColorPanelDelegate()

    private let is3200Mode: Bool

    init(isPresented: Binding<Bool>, palettes: Binding<[[PaletteColor]]>, onApply: @escaping ([[PaletteColor]]) -> Void) {
        self._isPresented = isPresented
        self._palettes = palettes
        self.onApply = onApply
        self.is3200Mode = palettes.wrappedValue.count == 200
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Palette Editor")
                    .font(.headline)
                Spacer()
                Text(is3200Mode ? "3200 Colors (200 Palettes)" : "\(editedPalettes.count) Palette(s)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main content
            HSplitView {
                // Left: Palette list
                VStack(alignment: .leading, spacing: 0) {
                    Text("Palettes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                    List(selection: $selectedPaletteIndex) {
                        ForEach(0..<editedPalettes.count, id: \.self) { index in
                            HStack(spacing: 2) {
                                Text(is3200Mode ? "Line \(index)" : "Palette \(index)")
                                    .font(.caption)
                                    .frame(width: 60, alignment: .leading)

                                // Mini preview of palette colors
                                HStack(spacing: 1) {
                                    ForEach(0..<min(16, editedPalettes[index].count), id: \.self) { colorIdx in
                                        Rectangle()
                                            .fill(editedPalettes[index][colorIdx].color)
                                            .frame(width: 8, height: 12)
                                    }
                                }
                            }
                            .tag(index)
                        }
                    }
                    .listStyle(.sidebar)
                }
                .frame(minWidth: 200, maxWidth: 250)

                // Right: Color grid for selected palette
                VStack(spacing: 12) {
                    if selectedPaletteIndex < editedPalettes.count {
                        Text(is3200Mode ? "Scanline \(selectedPaletteIndex)" : "Palette \(selectedPaletteIndex)")
                            .font(.headline)

                        // Color grid (4x4)
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(60), spacing: 8), count: 4), spacing: 8) {
                            ForEach(0..<editedPalettes[selectedPaletteIndex].count, id: \.self) { colorIdx in
                                ColorCell(
                                    color: editedPalettes[selectedPaletteIndex][colorIdx],
                                    index: colorIdx,
                                    isSelected: selectedColorIndex == colorIdx
                                ) {
                                    selectedColorIndex = colorIdx
                                    openColorPanel(for: colorIdx)
                                }
                            }
                        }
                        .padding()

                        // Selected color info
                        if let colorIdx = selectedColorIndex, colorIdx < editedPalettes[selectedPaletteIndex].count {
                            let color = editedPalettes[selectedPaletteIndex][colorIdx]
                            VStack(spacing: 4) {
                                Text("Color \(colorIdx)")
                                    .font(.caption)
                                Text(color.hexString)
                                    .font(.system(.caption, design: .monospaced))
                                Text("IIgs: $\(String(format: "%X%X%X", color.iigsR, color.iigsG, color.iigsB))")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // Copy/Paste palette buttons
                        HStack {
                            Button("Copy Palette") {
                                copyPalette()
                            }
                            Button("Paste Palette") {
                                pastePalette()
                            }
                            .disabled(!canPaste())
                        }
                        .padding(.bottom)
                    }
                }
                .frame(minWidth: 300)
            }

            Divider()

            // Footer buttons
            HStack {
                Button("Reset") {
                    editedPalettes = palettes.map { $0 }
                }

                Spacer()

                Button("Cancel") {
                    closeColorPanel()
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    closeColorPanel()
                    onApply(editedPalettes)
                    palettes = editedPalettes
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            editedPalettes = palettes.map { $0 }
            setupColorPanelDelegate()
        }
        .onDisappear {
            closeColorPanel()
        }
    }

    @State private var copiedPalette: [PaletteColor]? = nil

    private func copyPalette() {
        if selectedPaletteIndex < editedPalettes.count {
            copiedPalette = editedPalettes[selectedPaletteIndex]
        }
    }

    private func pastePalette() {
        if let copied = copiedPalette, selectedPaletteIndex < editedPalettes.count {
            editedPalettes[selectedPaletteIndex] = copied
        }
    }

    private func canPaste() -> Bool {
        copiedPalette != nil
    }

    private func setupColorPanelDelegate() {
        colorPanelDelegate.onColorChange = { newColor in
            guard let colorIdx = selectedColorIndex,
                  selectedPaletteIndex < editedPalettes.count,
                  colorIdx < editedPalettes[selectedPaletteIndex].count else { return }

            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            newColor.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)

            // Quantize to IIgs 4-bit color (0-15 per channel)
            let r4 = Int(r * 15.0 + 0.5)
            let g4 = Int(g * 15.0 + 0.5)
            let b4 = Int(b * 15.0 + 0.5)

            // Convert back to 8-bit
            editedPalettes[selectedPaletteIndex][colorIdx] = PaletteColor(
                r: Double(r4) * 255.0 / 15.0,
                g: Double(g4) * 255.0 / 15.0,
                b: Double(b4) * 255.0 / 15.0
            )
        }
    }

    private func openColorPanel(for colorIdx: Int) {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(colorPanelDelegate)
        colorPanel.setAction(#selector(ColorPanelDelegate.colorDidChange(_:)))
        colorPanel.color = editedPalettes[selectedPaletteIndex][colorIdx].nsColor
        colorPanel.isContinuous = true
        colorPanel.showsAlpha = false
        colorPanel.orderFront(nil)
    }

    private func closeColorPanel() {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.close()
    }
}

struct ColorCell: View {
    let color: PaletteColor
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(color.color)
                .frame(width: 50, height: 50)
                .border(isSelected ? Color.blue : Color.gray, width: isSelected ? 3 : 1)
                .onTapGesture {
                    onTap()
                }

            Text("\(index)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PaletteEditorView(
        isPresented: .constant(true),
        palettes: .constant([
            (0..<16).map { _ in PaletteColor(r: Double.random(in: 0...255), g: Double.random(in: 0...255), b: Double.random(in: 0...255)) }
        ])
    ) { _ in }
}
