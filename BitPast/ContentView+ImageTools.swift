import SwiftUI

extension ContentView {
    // MARK: - Palette Editor Helpers

    func openPaletteEditor() {
        guard let result = viewModel.currentResult, !result.palettes.isEmpty else { return }

        // Convert PaletteRGB to PaletteColor for the editor
        editablePalettes = result.palettes.map { palette in
            palette.map { PaletteColor(r: $0.r, g: $0.g, b: $0.b) }
        }

        // Open floating window
        PaletteEditorWindowController.shared.openWindow(
            palettes: $editablePalettes
        ) { newPalettes in
            applyEditedPalettes(newPalettes)
        }
    }

    func applyEditedPalettes(_ newPalettes: [[PaletteColor]]) {
        guard var result = viewModel.currentResult else { return }

        // Convert PaletteColor back to PaletteRGB
        result.palettes = newPalettes.map { palette in
            palette.map { PaletteRGB(r: $0.r, g: $0.g, b: $0.b) }
        }

        // Regenerate preview with edited palettes
        let preview = regeneratePreview(
            indices: result.pixelIndices,
            palettes: newPalettes,
            width: result.imageWidth,
            height: result.imageHeight,
            paletteLines: result.paletteLines
        )

        // Write the new palettes into a copy of the converted file, so saving keeps them
        var fileAssets = result.fileAssets
        if let url = fileAssets.first {
            do {
                let data = try Data(contentsOf: url)
                if let edited = AppleIIGSConverter.replacingPalettes(result.palettes, in: data) {
                    let copy = FileManager.default.temporaryDirectory
                        .appendingPathComponent("iigs_\(UUID().uuidString.prefix(8))_edited.\(url.pathExtension)")
                    try edited.write(to: copy)
                    fileAssets[0] = copy
                }
            } catch {
                viewModel.errorMessage = "Couldn't save the edited palettes: \(error.localizedDescription)"
            }
        }

        // Update the result
        viewModel.currentResult = ConversionResult(
            previewImage: preview,
            fileAssets: fileAssets,
            palettes: result.palettes,
            pixelIndices: result.pixelIndices,
            imageWidth: result.imageWidth,
            imageHeight: result.imageHeight,
            paletteLines: result.paletteLines,
            editedPalettes: true
        )
        viewModel.paletteEditsImageId = viewModel.selectedImageId
        viewModel.paletteEditsMachineIndex = viewModel.selectedMachineIndex
    }

    func regeneratePreview(indices: [Int], palettes: [[PaletteColor]], width: Int, height: Int,
                           paletteLines: [Int] = []) -> NSImage {
        guard !indices.isEmpty, !palettes.isEmpty else {
            return NSImage(size: NSSize(width: width, height: height))
        }

        var bytes = [UInt8](repeating: 255, count: width * height * 4)

        for y in 0..<height {
            let paletteIndex: Int
            if y < paletteLines.count {
                // IIgs 256 colours - the palette this line's SCB selects
                paletteIndex = min(paletteLines[y], palettes.count - 1)
            } else if palettes.count == 200 {
                // Brooks 3200 mode - one palette per scanline
                paletteIndex = y
            } else {
                paletteIndex = min(y % palettes.count, palettes.count - 1)
            }

            let palette = palettes[paletteIndex]

            for x in 0..<width {
                let idx = y * width + x
                if idx >= indices.count { continue }

                let colorIdx = indices[idx]
                if colorIdx >= palette.count { continue }

                let color = palette[colorIdx]
                let pixelOffset = idx * 4

                bytes[pixelOffset + 0] = UInt8(max(0, min(255, color.r)))
                bytes[pixelOffset + 1] = UInt8(max(0, min(255, color.g)))
                bytes[pixelOffset + 2] = UInt8(max(0, min(255, color.b)))
                bytes[pixelOffset + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return NSImage(size: NSSize(width: width, height: height))
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // MARK: - Image Flip Functions

    // Flips mirror the picture before converting, so saved files and disks are flipped too
    func flipImageHorizontally() { viewModel.toggleFlip(horizontal: true) }
    func flipImageVertically() { viewModel.toggleFlip(horizontal: false) }
}
