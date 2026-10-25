import Foundation
import AppKit

nonisolated class Atari800Converter: RetroMachine {
    var name: String = "Atari 800"

    // Atari 800 has 128 colors (16 hues × 8 luminances)
    // ANTIC/GTIA graphics system with various modes

    var options: [ConversionOption] = [
        ConversionOption(label: "Mode", key: "mode",
                        values: ["Graphics 8 (320×192, 2 colors)", "Graphics 15 (160×192, 4 colors)", "Graphics 9 (80×192, 16 shades)", "Graphics 10 (80×192, 9 colors)", "Graphics 11 (80×192, 16 hues)"],
                        selectedValue: "Graphics 15 (160×192, 4 colors)"),
        ConversionOption(label: "Dither", key: "dither",
                        values: ["None", "Floyd-Steinberg", "Atkinson", "Noise", "Bayer 2x2", "Bayer 4x4", "Bayer 8x8", "Bayer 16x16", "Blue Noise 8x8", "Blue Noise 16x16"],
                        selectedValue: "Bayer 4x4"),
        ConversionOption(label: "Dither Amount", key: "dither_amount",
                        range: 0.0...1.0, defaultValue: 0.5),
        ConversionOption(label: "Contrast", key: "contrast",
                        values: ["None", "HE", "CLAHE", "SWAHE"],
                        selectedValue: "None"),
        ConversionOption(label: "Filter", key: "filter",
                        values: ["None", "Lowpass", "Sharpen", "Emboss", "Edge"],
                        selectedValue: "None"),
        ConversionOption(label: "Color Match", key: "color_match",
                        values: ["Euclidean", "Perceptive", "Luma", "Chroma", "Hue"],
                        selectedValue: "Perceptive"),
        ConversionOption(label: "Saturation", key: "saturation",
                        range: 0.5...2.0, defaultValue: 1.0),
        ConversionOption(label: "Gamma", key: "gamma",
                        range: 0.5...2.0, defaultValue: 1.0)
    ]

    // Generate full 128-color Atari 800 palette (16 hues × 8 luminances)
    // Based on GTIA color generation
    static let atari800Palette: [[UInt8]] = {
        var palette: [[UInt8]] = []

        // Atari NTSC color palette approximation
        // Hue 0 is grayscale, hues 1-15 are colors
        for hue in 0..<16 {
            for lum in 0..<8 {
                let luminance = Float(lum) / 7.0 * 255.0

                if hue == 0 {
                    // Grayscale
                    let gray = UInt8(luminance)
                    palette.append([gray, gray, gray])
                } else {
                    // Colored - approximate NTSC color generation
                    let angle = Float(hue - 1) * 22.5 * Float.pi / 180.0
                    let saturation: Float = 0.5 + Float(lum) * 0.05

                    // YIQ to RGB approximation
                    let y = luminance / 255.0
                    let i = saturation * cos(angle) * 0.6
                    let q = saturation * sin(angle) * 0.5

                    var r = y + 0.956 * i + 0.621 * q
                    var g = y - 0.272 * i - 0.647 * q
                    var b = y - 1.106 * i + 1.703 * q

                    r = max(0, min(1, r))
                    g = max(0, min(1, g))
                    b = max(0, min(1, b))

                    palette.append([UInt8(r * 255), UInt8(g * 255), UInt8(b * 255)])
                }
            }
        }
        return palette
    }()

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        try validateSourceImage(sourceImage)
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        let mode = opts.first(where: { $0.key == "mode" })?.selectedValue ?? "Graphics 15 (160×192, 4 colors)"

        let (width, height, numColors): (Int, Int, Int)
        switch mode {
        case "Graphics 8 (320×192, 2 colors)":
            width = 320
            height = 192
            numColors = 2
        case "Graphics 9 (80×192, 16 shades)":
            width = 80
            height = 192
            numColors = 16
        case "Graphics 10 (80×192, 9 colors)":
            width = 80
            height = 192
            numColors = 9
        case "Graphics 11 (80×192, 16 hues)":
            width = 80
            height = 192
            numColors = 16
        default: // Graphics 15
            width = 160
            height = 192
            numColors = 4
        }

        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "Atari800Converter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }

        // Get options
        let ditherAlg = opts.first(where: { $0.key == "dither" })?.selectedValue ?? "Bayer 4x4"
        let ditherAmount = Double(opts.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrast = opts.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filter = opts.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let colorMatch = opts.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(opts.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(opts.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        // Scale image
        var pixels = AtariFamilyImageOps.scaleImage(cgImage, toWidth: width, height: height)

        // Apply preprocessing
        if saturation != 1.0 {
            AtariFamilyImageOps.applySaturation(&pixels, width: width, height: height, saturation: saturation)
        }
        if gamma != 1.0 {
            AtariFamilyImageOps.applyGamma(&pixels, width: width, height: height, gamma: gamma)
        }
        if contrast != "None" {
            AtariFamilyImageOps.applyContrast(&pixels, width: width, height: height, method: contrast)
        }
        if filter != "None" {
            AtariFamilyImageOps.applyFilter(&pixels, width: width, height: height, filter: filter)
        }

        // Apply ordered dithering if selected
        if ditherAlg.contains("Bayer") || ditherAlg.contains("Blue Noise") || ditherAlg == "Noise" {
            AtariFamilyImageOps.applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount)
        }

        // Select palette based on mode
        let selectedPalette: [[UInt8]]
        var atariRegisters: [UInt8] = []
        if mode.contains("Graphics 9") {
            // Graphics 9: 16 shades of one hue - find dominant hue
            selectedPalette = selectGrayscalePalette()
            // Generate grayscale register values (hue 0, luminances 0-15)
            for lum in 0..<16 {
                atariRegisters.append(UInt8((lum / 2) << 1))  // Even luminance values
            }
        } else if mode.contains("Graphics 10") {
            // Graphics 10: 9 freely chosen colors
            (selectedPalette, atariRegisters) = selectCoveringPalette(pixels: pixels, numColors: 9)
        } else if mode.contains("Graphics 11") {
            // Graphics 11: 16 different hues at one luminance
            selectedPalette = select16HuePalette()
            // Generate 16 hue register values at fixed luminance (level 4)
            for hue in 0..<16 {
                atariRegisters.append(UInt8((hue << 4) | 8))  // Lum 4 = 8 in register
            }
        } else if mode.contains("Graphics 15") {
            // Graphics 15: 4 freely chosen colors
            (selectedPalette, atariRegisters) = selectCoveringPalette(pixels: pixels, numColors: numColors)
        } else {
            // Graphics 8: most frequent colors from the 128-color palette
            (selectedPalette, atariRegisters) = selectOptimalPalette(pixels: pixels, width: width, height: height, numColors: numColors)
        }

        // Convert with error diffusion if selected
        let (resultPixels, nativeData) = convertToAtari800(pixels: pixels, width: width, height: height,
                                                            palette: selectedPalette, mode: mode,
                                                            ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                            colorMatch: colorMatch)

        // Create preview image (scaled for visibility)
        let scaleX = (mode.contains("Graphics 9") || mode.contains("Graphics 10") || mode.contains("Graphics 11")) ? 4 : (mode.contains("Graphics 8") ? 2 : 2)
        let scaleY = 2
        let previewWidth = width * scaleX
        let previewHeight = height * scaleY
        var previewPixels = [UInt8](repeating: 0, count: previewWidth * previewHeight * 4)

        for y in 0..<height {
            for x in 0..<width {
                let srcIdx = (y * width + x) * 3
                let r = resultPixels[srcIdx]
                let g = resultPixels[srcIdx + 1]
                let b = resultPixels[srcIdx + 2]

                for dy in 0..<scaleY {
                    for dx in 0..<scaleX {
                        let dstIdx = ((y * scaleY + dy) * previewWidth + (x * scaleX + dx)) * 4
                        previewPixels[dstIdx] = r
                        previewPixels[dstIdx + 1] = g
                        previewPixels[dstIdx + 2] = b
                        previewPixels[dstIdx + 3] = 255
                    }
                }
            }
        }

        guard let previewContext = CGContext(data: &previewPixels,
                                             width: previewWidth,
                                             height: previewHeight,
                                             bitsPerComponent: 8,
                                             bytesPerRow: previewWidth * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let previewCGImage = previewContext.makeImage() else {
            throw NSError(domain: "Atari800Converter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview"])
        }

        let previewImage = NSImage(cgImage: previewCGImage, size: NSSize(width: previewWidth, height: previewHeight))

        // Append palette data to native file
        // Format: bitmap data (7680 bytes) + Atari color registers (numColors bytes)
        var fullData = nativeData
        fullData.append(contentsOf: atariRegisters)

        // Save native file
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let ext: String
        if mode.contains("Graphics 8") { ext = "gr8" }
        else if mode.contains("Graphics 9") { ext = "gr9" }
        else if mode.contains("Graphics 10") { ext = "gr10" }
        else if mode.contains("Graphics 11") { ext = "gr11" }
        else { ext = "gr15" }
        let nativeUrl = tempDir.appendingPathComponent("atari800_\(uuid).\(ext)")
        try fullData.write(to: nativeUrl)

        return ConversionResult(
            previewImage: previewImage,
            fileAssets: [nativeUrl],
            palettes: [],
            pixelIndices: [],
            imageWidth: width,
            imageHeight: height
        )
    }

    private func selectGrayscalePalette() -> [[UInt8]] {
        // For Graphics 9: 16 shades of grayscale (hue 0)
        var palette: [[UInt8]] = []
        for lum in 0..<16 {
            let gray = UInt8(Float(lum) / 15.0 * 255.0)
            palette.append([gray, gray, gray])
        }
        return palette
    }

    private func select16HuePalette() -> [[UInt8]] {
        // For Graphics 11: 16 different hues at medium luminance (level 4)
        var palette: [[UInt8]] = []
        let lum = 4 // Medium luminance
        let luminance = Float(lum) / 7.0 * 255.0

        for hue in 0..<16 {
            if hue == 0 {
                // Grayscale
                let gray = UInt8(luminance)
                palette.append([gray, gray, gray])
            } else {
                // Colored - approximate NTSC color generation
                let angle = Float(hue - 1) * 22.5 * Float.pi / 180.0
                let saturation: Float = 0.5 + Float(lum) * 0.05

                // YIQ to RGB approximation
                let y = luminance / 255.0
                let i = saturation * cos(angle) * 0.6
                let q = saturation * sin(angle) * 0.5

                var r = y + 0.956 * i + 0.621 * q
                var g = y - 0.272 * i - 0.647 * q
                var b = y - 1.106 * i + 1.703 * q

                r = max(0, min(1, r))
                g = max(0, min(1, g))
                b = max(0, min(1, b))

                palette.append([UInt8(r * 255), UInt8(g * 255), UInt8(b * 255)])
            }
        }
        return palette
    }

    /// Picks colors that cover the whole picture (see `CoveringPalette`).
    private func selectCoveringPalette(pixels: [[Float]], numColors: Int) -> ([[UInt8]], [UInt8]) {
        let chosen = CoveringPalette.pick(numColors, from: Self.atari800Palette, pixels: pixels)
        var palette = chosen.map { Self.atari800Palette[$0] }
        var registers = chosen.map { atariRegister(forPaletteIndex: $0) }
        while palette.count < numColors {
            palette.append([0, 0, 0])
            registers.append(0)
        }
        return (palette, registers)
    }

    /// Color register value (HHHHLLL0) for an index into the 128-color palette (hue * 8 + luminance).
    private func atariRegister(forPaletteIndex idx: Int) -> UInt8 {
        UInt8(((idx / 8) << 4) | ((idx % 8) << 1))
    }

    private func selectOptimalPalette(pixels: [[Float]], width: Int, height: Int, numColors: Int) -> ([[UInt8]], [UInt8]) {
        // Use median cut to select optimal colors from 128-color palette
        // Returns (RGB palette, Atari color register values)
        var colorCounts: [Int: Int] = [:]

        // Count colors mapped to Atari palette
        for pixel in pixels {
            let r = Int(max(0, min(255, pixel[0])))
            let g = Int(max(0, min(255, pixel[1])))
            let b = Int(max(0, min(255, pixel[2])))

            // Find nearest palette color
            var bestIdx = 0
            var bestDist = Int.max
            for (i, color) in Self.atari800Palette.enumerated() {
                let dr = r - Int(color[0])
                let dg = g - Int(color[1])
                let db = b - Int(color[2])
                let dist = dr * dr + dg * dg + db * db
                if dist < bestDist {
                    bestDist = dist
                    bestIdx = i
                }
            }
            colorCounts[bestIdx, default: 0] += 1
        }

        // Sort by frequency and take top colors
        let sorted = colorCounts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }  // ties by key, so output is repeatable
        var palette: [[UInt8]] = []
        var atariRegisters: [UInt8] = []

        for (idx, _) in sorted.prefix(numColors) {
            palette.append(Self.atari800Palette[idx])
            // Convert palette index to Atari color register value
            // Index format: hue * 8 + luminance (0-127)
            // Register format: HHHHLLLL where H=hue(4 bits), L=luminance*2(4 bits)
            let hue = idx / 8
            let lum = idx % 8
            let register = UInt8((hue << 4) | (lum << 1))
            atariRegisters.append(register)
        }

        // Pad to required colors if needed
        while palette.count < numColors {
            palette.append([0, 0, 0])
            atariRegisters.append(0)
        }

        return (palette, atariRegisters)
    }

    private func convertToAtari800(pixels: [[Float]], width: Int, height: Int,
                                    palette: [[UInt8]], mode: String,
                                    ditherAlg: String, ditherAmount: Double,
                                    colorMatch: String) -> ([UInt8], Data) {

        var work = pixels
        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)
        var fileData = Data()

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"

        if mode.contains("Graphics 8") {
            // Graphics 8: 320×192, 1 bit per pixel = 40 bytes per line
            var bitmap = [UInt8](repeating: 0, count: 40 * 192)

            for y in 0..<height {
                for x in 0..<width {
                    let r = max(0, min(255, work[y * width + x][0]))
                    let g = max(0, min(255, work[y * width + x][1]))
                    let b = max(0, min(255, work[y * width + x][2]))

                    // Find closest color (2 colors)
                    let colorIndex = AtariFamilyImageOps.findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                    let color = palette[colorIndex]

                    let resultIdx = (y * width + x) * 3
                    resultPixels[resultIdx] = color[0]
                    resultPixels[resultIdx + 1] = color[1]
                    resultPixels[resultIdx + 2] = color[2]

                    // Set bit in bitmap
                    if colorIndex == 1 {
                        let byteIdx = y * 40 + x / 8
                        let bitIdx = 7 - (x % 8)
                        bitmap[byteIdx] |= UInt8(1 << bitIdx)
                    }

                    // Error diffusion
                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }

            fileData.append(contentsOf: bitmap)

        } else if mode.contains("Graphics 9") {
            // Graphics 9: 80×192, 4 bits per pixel (16 shades) = 40 bytes per line
            var bitmap = [UInt8](repeating: 0, count: 40 * 192)

            for y in 0..<height {
                for x in 0..<width {
                    let r = max(0, min(255, work[y * width + x][0]))
                    let g = max(0, min(255, work[y * width + x][1]))
                    let b = max(0, min(255, work[y * width + x][2]))

                    // Convert to luminance and find shade
                    let luma = 0.299 * r + 0.587 * g + 0.114 * b
                    let shadeIndex = min(15, Int(luma / 16.0))
                    let color = palette[shadeIndex]

                    let resultIdx = (y * width + x) * 3
                    resultPixels[resultIdx] = color[0]
                    resultPixels[resultIdx + 1] = color[1]
                    resultPixels[resultIdx + 2] = color[2]

                    // Pack 2 pixels per byte (high nibble first)
                    let byteIdx = y * 40 + x / 2
                    if x % 2 == 0 {
                        bitmap[byteIdx] |= UInt8(shadeIndex << 4)
                    } else {
                        bitmap[byteIdx] |= UInt8(shadeIndex)
                    }

                    // Error diffusion
                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }

            fileData.append(contentsOf: bitmap)

        } else if mode.contains("Graphics 10") {
            // Graphics 10: 80×192, 4 bits per pixel (9 colors) = 40 bytes per line
            var bitmap = [UInt8](repeating: 0, count: 40 * 192)

            for y in 0..<height {
                for x in 0..<width {
                    let r = max(0, min(255, work[y * width + x][0]))
                    let g = max(0, min(255, work[y * width + x][1]))
                    let b = max(0, min(255, work[y * width + x][2]))

                    // Find closest color (9 colors)
                    let colorIndex = AtariFamilyImageOps.findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                    let color = palette[colorIndex]

                    let resultIdx = (y * width + x) * 3
                    resultPixels[resultIdx] = color[0]
                    resultPixels[resultIdx + 1] = color[1]
                    resultPixels[resultIdx + 2] = color[2]

                    // Pack 2 pixels per byte (high nibble first)
                    let byteIdx = y * 40 + x / 2
                    if x % 2 == 0 {
                        bitmap[byteIdx] |= UInt8(colorIndex << 4)
                    } else {
                        bitmap[byteIdx] |= UInt8(colorIndex)
                    }

                    // Error diffusion
                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }

            fileData.append(contentsOf: bitmap)

        } else if mode.contains("Graphics 11") {
            // Graphics 11: 80×192, 4 bits per pixel (16 hues at one luminance) = 40 bytes per line
            var bitmap = [UInt8](repeating: 0, count: 40 * 192)

            for y in 0..<height {
                for x in 0..<width {
                    let r = max(0, min(255, work[y * width + x][0]))
                    let g = max(0, min(255, work[y * width + x][1]))
                    let b = max(0, min(255, work[y * width + x][2]))

                    // Find closest hue (16 hues)
                    let colorIndex = AtariFamilyImageOps.findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                    let color = palette[colorIndex]

                    let resultIdx = (y * width + x) * 3
                    resultPixels[resultIdx] = color[0]
                    resultPixels[resultIdx + 1] = color[1]
                    resultPixels[resultIdx + 2] = color[2]

                    // Pack 2 pixels per byte (high nibble first)
                    let byteIdx = y * 40 + x / 2
                    if x % 2 == 0 {
                        bitmap[byteIdx] |= UInt8(colorIndex << 4)
                    } else {
                        bitmap[byteIdx] |= UInt8(colorIndex)
                    }

                    // Error diffusion
                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }

            fileData.append(contentsOf: bitmap)

        } else {
            // Graphics 15: 160×192, 2 bits per pixel (4 colors) = 40 bytes per line
            var bitmap = [UInt8](repeating: 0, count: 40 * 192)

            for y in 0..<height {
                for x in 0..<width {
                    let r = max(0, min(255, work[y * width + x][0]))
                    let g = max(0, min(255, work[y * width + x][1]))
                    let b = max(0, min(255, work[y * width + x][2]))

                    // Find closest color (4 colors)
                    let colorIndex = AtariFamilyImageOps.findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                    let color = palette[colorIndex]

                    let resultIdx = (y * width + x) * 3
                    resultPixels[resultIdx] = color[0]
                    resultPixels[resultIdx + 1] = color[1]
                    resultPixels[resultIdx + 2] = color[2]

                    // Pack 4 pixels per byte
                    let byteIdx = y * 40 + x / 4
                    let shift = (3 - (x % 4)) * 2
                    bitmap[byteIdx] |= UInt8(colorIndex << shift)

                    // Error diffusion
                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }

            fileData.append(contentsOf: bitmap)
        }

        return (resultPixels, fileData)
    }
}
