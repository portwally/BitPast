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
            height: result.imageHeight
        )

        // Update the result
        viewModel.currentResult = ConversionResult(
            previewImage: preview,
            fileAssets: result.fileAssets,
            palettes: result.palettes,
            pixelIndices: result.pixelIndices,
            imageWidth: result.imageWidth,
            imageHeight: result.imageHeight
        )
    }

    func regeneratePreview(indices: [Int], palettes: [[PaletteColor]], width: Int, height: Int) -> NSImage {
        guard !indices.isEmpty, !palettes.isEmpty else {
            return NSImage(size: NSSize(width: width, height: height))
        }

        var bytes = [UInt8](repeating: 255, count: width * height * 4)

        for y in 0..<height {
            let paletteIndex: Int
            if palettes.count == 200 {
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

    func flipImageHorizontally() {
        guard let currentImage = viewModel.convertedImage else { return }
        let flipped = flipImage(currentImage, horizontal: true)
        updatePreviewWithFlippedImage(flipped)
    }

    func flipImageVertically() {
        guard let currentImage = viewModel.convertedImage else { return }
        let flipped = flipImage(currentImage, horizontal: false)
        updatePreviewWithFlippedImage(flipped)
    }

    func flipImage(_ image: NSImage, horizontal: Bool) -> NSImage {
        let size = image.size
        let flippedImage = NSImage(size: size)

        flippedImage.lockFocus()

        let transform = NSAffineTransform()
        if horizontal {
            transform.translateX(by: size.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
        } else {
            transform.translateX(by: 0, yBy: size.height)
            transform.scaleX(by: 1, yBy: -1)
        }
        transform.concat()

        image.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1.0)

        flippedImage.unlockFocus()

        return flippedImage
    }

    func updatePreviewWithFlippedImage(_ flipped: NSImage) {
        guard let result = viewModel.currentResult else { return }

        viewModel.currentResult = ConversionResult(
            previewImage: flipped,
            fileAssets: result.fileAssets,
            palettes: result.palettes,
            pixelIndices: result.pixelIndices,
            imageWidth: result.imageWidth,
            imageHeight: result.imageHeight
        )
    }
}
