import Foundation
import AppKit

nonisolated class TRS80CoCoConverter: RetroMachine {
    var name: String = "TRS-80 CoCo"

    // TRS-80 Color Computer graphics modes
    // CoCo 1/2: MC6847 VDG chip (Video Display Generator)
    // CoCo 3: GIME chip (Graphics Interrupt Memory Enhancer)

    var options: [ConversionOption] = [
        ConversionOption(label: "Mode", key: "mode",
                        values: ["PMODE 3 (128×192, 4 colors)", "PMODE 4 (256×192, 2 colors)", "PMODE 1 (128×96, 4 colors)", "PMODE 2 (128×192, 2 colors)", "CoCo 3 (320×200, 16 colors)", "CoCo 3 (640×200, 4 colors)"],
                        selectedValue: "PMODE 3 (128×192, 4 colors)"),
        ConversionOption(label: "Color Set", key: "colorset",
                        values: ["Set 0 (Green/Yellow/Blue/Red)", "Set 1 (Buff/Cyan/Magenta/Orange)", "Artifact (NTSC)"],
                        selectedValue: "Set 0 (Green/Yellow/Blue/Red)"),
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

    // MC6847 Color Set 0: Black, Green, Yellow, Blue, Red, White, Cyan, Magenta
    // PMODE uses 4-color subsets: background (black) + 3 colors from set
    static let colorSet0: [[UInt8]] = [
        [0, 0, 0],       // 0: Black (background)
        [0, 255, 0],     // 1: Green
        [255, 255, 0],   // 2: Yellow
        [0, 0, 255],     // 3: Blue
        [255, 0, 0]      // 4: Red (not used in PMODE but available)
    ]

    // MC6847 Color Set 1: Black, Buff, Cyan, Magenta, Orange
    static let colorSet1: [[UInt8]] = [
        [0, 0, 0],       // 0: Black (background)
        [255, 255, 224], // 1: Buff (light yellow/cream)
        [0, 255, 255],   // 2: Cyan
        [255, 0, 255],   // 3: Magenta
        [255, 128, 0]    // 4: Orange (not used in PMODE but available)
    ]

    // NTSC Artifact colors (for high-res modes)
    static let artifactColors: [[UInt8]] = [
        [0, 0, 0],       // 0: Black
        [255, 255, 255], // 1: White
        [0, 128, 255],   // 2: Blue (artifact)
        [255, 128, 0]    // 3: Orange (artifact)
    ]

    // CoCo 3 GIME palette (64 colors: 2 bits each for R, G, B)
    static let coco3Palette: [[UInt8]] = {
        var palette: [[UInt8]] = []
        for i in 0..<64 {
            // RGB222 format: RRGGBBxx
            let r = ((i >> 4) & 0x03) * 85  // 0, 85, 170, 255
            let g = ((i >> 2) & 0x03) * 85
            let b = (i & 0x03) * 85
            palette.append([UInt8(r), UInt8(g), UInt8(b)])
        }
        return palette
    }()

    // Fixed 16-color CoCo 3 palette for emulator compatibility
    // Uses specific GIME indices to provide a standard palette that works on all emulators
    // GIME RGB222: index = R*16 + G*4 + B where R,G,B are 0-3
    static let coco3Fixed16: [[UInt8]] = [
        coco3Palette[0],   // 0: Black (R0G0B0)
        coco3Palette[63],  // 1: White (R3G3B3)
        coco3Palette[48],  // 2: Red (R3G0B0)
        coco3Palette[12],  // 3: Green (R0G3B0)
        coco3Palette[3],   // 4: Blue (R0G0B3)
        coco3Palette[15],  // 5: Cyan (R0G3B3)
        coco3Palette[51],  // 6: Magenta (R3G0B3)
        coco3Palette[60],  // 7: Yellow (R3G3B0)
        coco3Palette[21],  // 8: Dark Gray (R1G1B1)
        coco3Palette[42],  // 9: Light Gray (R2G2B2)
        coco3Palette[32],  // 10: Dark Red (R2G0B0)
        coco3Palette[8],   // 11: Dark Green (R0G2B0)
        coco3Palette[2],   // 12: Dark Blue (R0G0B2)
        coco3Palette[52],  // 13: Orange (R3G1B0)
        coco3Palette[44],  // 14: Brown (R2G2B0)
        coco3Palette[7]    // 15: Sky Blue (R0G1B3)
    ]

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        try validateSourceImage(sourceImage)
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        let mode = opts.first(where: { $0.key == "mode" })?.selectedValue ?? "PMODE 3 (128×192, 4 colors)"
        let colorSet = opts.first(where: { $0.key == "colorset" })?.selectedValue ?? "Set 0 (Green/Yellow/Blue/Red)"

        let (width, height, numColors, isCoCo3): (Int, Int, Int, Bool)
        switch mode {
        case "PMODE 1 (128×96, 4 colors)":
            width = 128; height = 96; numColors = 4; isCoCo3 = false
        case "PMODE 2 (128×192, 2 colors)":
            width = 128; height = 192; numColors = 2; isCoCo3 = false
        case "PMODE 4 (256×192, 2 colors)":
            width = 256; height = 192; numColors = 2; isCoCo3 = false
        case "CoCo 3 (320×200, 16 colors)":
            width = 320; height = 200; numColors = 16; isCoCo3 = true
        case "CoCo 3 (640×200, 4 colors)":
            width = 640; height = 200; numColors = 4; isCoCo3 = true
        default: // PMODE 3 (128×192, 4 colors)
            width = 128; height = 192; numColors = 4; isCoCo3 = false
        }

        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "TRS80CoCoConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }

        // Get options
        let ditherAlg = opts.first(where: { $0.key == "dither" })?.selectedValue ?? "Bayer 4x4"
        let ditherAmount = Double(opts.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrast = opts.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filter = opts.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let colorMatch = opts.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(opts.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(opts.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        try Task.checkCancellation()
        // Scale image
        var pixels = AtariFamilyImageOps.scaleImage(cgImage, toWidth: width, height: height)

        try Task.checkCancellation()
        // Apply preprocessing
        if saturation != 1.0 {
            AtariFamilyImageOps.applySaturation(&pixels, width: width, height: height, saturation: saturation)
        }
        if gamma != 1.0 {
            AtariFamilyImageOps.applyGamma(&pixels, width: width, height: height, gamma: gamma)
        }
        if contrast != "None" {
            applyContrast(&pixels, width: width, height: height, method: contrast)
        }
        if filter != "None" {
            AtariFamilyImageOps.applyFilter(&pixels, width: width, height: height, filter: filter)
        }

        // Apply ordered dithering if selected
        if ditherAlg.contains("Bayer") || ditherAlg.contains("Blue Noise") || ditherAlg == "Noise" {
            AtariFamilyImageOps.applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount)
        }

        // Select palette
        let selectedPalette: [[UInt8]]
        if isCoCo3 {
            // CoCo 3: Use fixed 16-color palette for emulator compatibility
            // This ensures images display correctly on emulators and in Retro-Graphics-Converter
            if numColors == 16 {
                selectedPalette = Self.coco3Fixed16
            } else {
                // 4-color mode: use first 4 colors (Black, White, Red, Green)
                selectedPalette = Array(Self.coco3Fixed16.prefix(numColors))
            }
        } else {
            // CoCo 1/2: Use MC6847 color sets
            if colorSet.contains("Artifact") && numColors == 2 {
                selectedPalette = Array(Self.artifactColors.prefix(numColors))
            } else if colorSet.contains("Set 1") {
                selectedPalette = Array(Self.colorSet1.prefix(numColors))
            } else {
                selectedPalette = Array(Self.colorSet0.prefix(numColors))
            }
        }

        try Task.checkCancellation()
        // Convert with dithering
        let (resultPixels, nativeData) = convertToCoCo(pixels: pixels, width: width, height: height,
                                                        palette: selectedPalette, mode: mode,
                                                        ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                        colorMatch: colorMatch)

        // Create preview image (scaled for visibility)
        try Task.checkCancellation()
        let scaleX: Int
        let scaleY: Int
        if mode.contains("640×200") {
            scaleX = 1; scaleY = 2
        } else if mode.contains("320×200") {
            scaleX = 2; scaleY = 2
        } else if mode.contains("256×192") {
            scaleX = 2; scaleY = 2
        } else if mode.contains("128×96") {
            scaleX = 4; scaleY = 4
        } else { // 128×192
            scaleX = 4; scaleY = 2
        }

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
            throw NSError(domain: "TRS80CoCoConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview"])
        }

        let previewImage = NSImage(cgImage: previewCGImage, size: NSSize(width: previewWidth, height: previewHeight))

        // Save native file
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let ext: String
        if isCoCo3 {
            ext = "cm3"  // CoCo 3 format
        } else {
            ext = "bin"  // Raw binary
        }
        let nativeUrl = tempDir.appendingPathComponent("coco_\(uuid).\(ext)")
        try nativeData.write(to: nativeUrl)

        return ConversionResult(
            previewImage: previewImage,
            fileAssets: [nativeUrl],
            palettes: [],
            pixelIndices: [],
            imageWidth: width,
            imageHeight: height
        )
    }

    private func convertToCoCo(pixels: [[Float]], width: Int, height: Int,
                               palette: [[UInt8]], mode: String,
                               ditherAlg: String, ditherAmount: Double,
                               colorMatch: String) -> ([UInt8], Data) {

        var work = pixels
        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)
        var fileData = Data()

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"

        if mode.contains("PMODE 4") || mode.contains("PMODE 2") || (mode.contains("640×200") && palette.count == 2) {
            // 1 bit per pixel modes
            let bytesPerRow = (width + 7) / 8
            var bitmap = [UInt8](repeating: 0, count: bytesPerRow * height)

            for y in 0..<height {
                for x in 0..<width {
                    let r = max(0, min(255, work[y * width + x][0]))
                    let g = max(0, min(255, work[y * width + x][1]))
                    let b = max(0, min(255, work[y * width + x][2]))

                    let colorIndex = AtariFamilyImageOps.findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                    let color = palette[colorIndex]

                    let resultIdx = (y * width + x) * 3
                    resultPixels[resultIdx] = color[0]
                    resultPixels[resultIdx + 1] = color[1]
                    resultPixels[resultIdx + 2] = color[2]

                    // Set bit in bitmap
                    if colorIndex == 1 {
                        let byteIdx = y * bytesPerRow + x / 8
                        let bitIdx = 7 - (x % 8)
                        bitmap[byteIdx] |= UInt8(1 << bitIdx)
                    }

                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }

            fileData.append(contentsOf: bitmap)

        } else if mode.contains("PMODE 1") || mode.contains("PMODE 3") || mode.contains("640×200") {
            // 2 bits per pixel (4 colors)
            let bytesPerRow = (width + 3) / 4
            var bitmap = [UInt8](repeating: 0, count: bytesPerRow * height)

            for y in 0..<height {
                for x in 0..<width {
                    let r = max(0, min(255, work[y * width + x][0]))
                    let g = max(0, min(255, work[y * width + x][1]))
                    let b = max(0, min(255, work[y * width + x][2]))

                    let colorIndex = AtariFamilyImageOps.findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                    let color = palette[colorIndex]

                    let resultIdx = (y * width + x) * 3
                    resultPixels[resultIdx] = color[0]
                    resultPixels[resultIdx + 1] = color[1]
                    resultPixels[resultIdx + 2] = color[2]

                    // Pack 4 pixels per byte
                    let byteIdx = y * bytesPerRow + x / 4
                    let shift = (3 - (x % 4)) * 2
                    bitmap[byteIdx] |= UInt8(colorIndex << shift)

                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }

            fileData.append(contentsOf: bitmap)

        } else if mode.contains("320×200") {
            // CoCo 3: 4 bits per pixel (16 colors)
            let bytesPerRow = (width + 1) / 2
            var bitmap = [UInt8](repeating: 0, count: bytesPerRow * height)

            for y in 0..<height {
                for x in 0..<width {
                    let r = max(0, min(255, work[y * width + x][0]))
                    let g = max(0, min(255, work[y * width + x][1]))
                    let b = max(0, min(255, work[y * width + x][2]))

                    let colorIndex = AtariFamilyImageOps.findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                    let color = palette[colorIndex]

                    let resultIdx = (y * width + x) * 3
                    resultPixels[resultIdx] = color[0]
                    resultPixels[resultIdx + 1] = color[1]
                    resultPixels[resultIdx + 2] = color[2]

                    // Pack 2 pixels per byte (high nibble first)
                    let byteIdx = y * bytesPerRow + x / 2
                    if x % 2 == 0 {
                        bitmap[byteIdx] |= UInt8(colorIndex << 4)
                    } else {
                        bitmap[byteIdx] |= UInt8(colorIndex)
                    }

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

    // MARK: - Preprocessing functions

    private func applyContrast(_ pixels: inout [[Float]], width: Int, height: Int, method: String) {
        switch method {
        case "HE":
            AtariFamilyImageOps.applyHistogramEqualization(&pixels, width: width, height: height)
        case "CLAHE":
            AtariFamilyImageOps.applyCLAHE(&pixels, width: width, height: height, clipLimit: 2.0, tileSize: 8)
        case "SWAHE":
            applySWAHE(&pixels, width: width, height: height, windowSize: 64)
        default:
            break
        }
    }

    private func applySWAHE(_ pixels: inout [[Float]], width: Int, height: Int, windowSize: Int) {
        let halfWindow = windowSize / 2
        var result = pixels

        var histogram = [Int](repeating: 0, count: 256)
        var pixelCount = 0

        for y in 0..<min(halfWindow, height) {
            for x in 0..<min(windowSize, width) {
                let luma = Int(max(0, min(255, 0.299 * pixels[y * width + x][0] + 0.587 * pixels[y * width + x][1] + 0.114 * pixels[y * width + x][2])))
                histogram[luma] += 1
                pixelCount += 1
            }
        }

        for y in 0..<height {
            for x in 0..<width {
                let luma = Int(max(0, min(255, 0.299 * pixels[y * width + x][0] + 0.587 * pixels[y * width + x][1] + 0.114 * pixels[y * width + x][2])))

                var cdf = 0
                for i in 0...luma {
                    cdf += histogram[i]
                }

                let newLuma = pixelCount > 0 ? Float(cdf) / Float(pixelCount) * 255.0 : Float(luma) / 255.0
                let ratio = luma > 0 ? newLuma / Float(luma) : 1.0

                result[y * width + x][0] = max(0, min(255, pixels[y * width + x][0] * ratio))
                result[y * width + x][1] = max(0, min(255, pixels[y * width + x][1] * ratio))
                result[y * width + x][2] = max(0, min(255, pixels[y * width + x][2] * ratio))

                if x + halfWindow < width {
                    for dy in max(0, y - halfWindow)..<min(height, y + halfWindow) {
                        let addLuma = Int(max(0, min(255, 0.299 * pixels[dy * width + x + halfWindow][0] + 0.587 * pixels[dy * width + x + halfWindow][1] + 0.114 * pixels[dy * width + x + halfWindow][2])))
                        histogram[addLuma] += 1
                        pixelCount += 1
                    }
                }
                if x - halfWindow >= 0 {
                    for dy in max(0, y - halfWindow)..<min(height, y + halfWindow) {
                        let remLuma = Int(max(0, min(255, 0.299 * pixels[dy * width + x - halfWindow][0] + 0.587 * pixels[dy * width + x - halfWindow][1] + 0.114 * pixels[dy * width + x - halfWindow][2])))
                        histogram[remLuma] -= 1
                        pixelCount -= 1
                    }
                }
            }
        }

        pixels = result
    }

}
