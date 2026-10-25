import Foundation
import AppKit

nonisolated class BBCMicroConverter: RetroMachine {
    var name: String = "BBC Micro"

    // BBC Micro has 8 fixed colors (no flashing support in static images)
    // Mode 0: 640×256, 2 colors
    // Mode 1: 320×256, 4 colors
    // Mode 2: 160×256, 8 colors (logical 16 but 8 solid + 8 flashing)
    // Mode 4: 320×256, 2 colors (20KB)
    // Mode 5: 160×256, 4 colors (20KB)

    var options: [ConversionOption] = [
        ConversionOption(label: "Mode", key: "mode",
                        values: ["Mode 0 (640×256, 2 colors)", "Mode 1 (320×256, 4 colors)", "Mode 2 (160×256, 8 colors)", "Mode 4 (320×256, 2 colors)", "Mode 5 (160×256, 4 colors)"],
                        selectedValue: "Mode 2 (160×256, 8 colors)"),
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

    // BBC Micro 8-color palette (fixed)
    static let bbcPalette: [[UInt8]] = [
        [0, 0, 0],       // 0 - Black
        [255, 0, 0],     // 1 - Red
        [0, 255, 0],     // 2 - Green
        [255, 255, 0],   // 3 - Yellow
        [0, 0, 255],     // 4 - Blue
        [255, 0, 255],   // 5 - Magenta
        [0, 255, 255],   // 6 - Cyan
        [255, 255, 255]  // 7 - White
    ]

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        try validateSourceImage(sourceImage)
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        let mode = opts.first(where: { $0.key == "mode" })?.selectedValue ?? "Mode 2 (160×256, 8 colors)"

        let (width, height, numColors, bytesPerLine): (Int, Int, Int, Int)
        switch mode {
        case "Mode 0 (640×256, 2 colors)":
            width = 640
            height = 256
            numColors = 2
            bytesPerLine = 80
        case "Mode 1 (320×256, 4 colors)":
            width = 320
            height = 256
            numColors = 4
            bytesPerLine = 80
        case "Mode 4 (320×256, 2 colors)":
            width = 320
            height = 256
            numColors = 2
            bytesPerLine = 40
        case "Mode 5 (160×256, 4 colors)":
            width = 160
            height = 256
            numColors = 4
            bytesPerLine = 40
        default: // Mode 2
            width = 160
            height = 256
            numColors = 8
            bytesPerLine = 80
        }

        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "BBCMicroConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
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

        // Select palette based on mode
        let selectedPalette: [[UInt8]]
        try Task.checkCancellation()
        if numColors == 2 {
            selectedPalette = selectOptimalPalette(pixels: pixels, width: width, height: height, numColors: 2)
        } else if numColors == 4 {
            selectedPalette = selectOptimalPalette(pixels: pixels, width: width, height: height, numColors: 4)
        } else {
            selectedPalette = Self.bbcPalette
        }

        // Determine mode number for embedding
        let embeddedMode: UInt8
        switch mode {
        case "Mode 0 (640×256, 2 colors)": embeddedMode = 0
        case "Mode 1 (320×256, 4 colors)": embeddedMode = 1
        case "Mode 4 (320×256, 2 colors)": embeddedMode = 4
        case "Mode 5 (160×256, 4 colors)": embeddedMode = 5
        default: embeddedMode = 2  // Mode 2
        }

        try Task.checkCancellation()
        // Convert with error diffusion if selected
        let (resultPixels, nativeData) = convertToBBCMicro(pixels: pixels, width: width, height: height,
                                                           palette: selectedPalette, mode: mode,
                                                           embeddedMode: embeddedMode,
                                                           bytesPerLine: bytesPerLine,
                                                           ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                           colorMatch: colorMatch)

        // Create preview image (scaled for visibility)
        try Task.checkCancellation()
        let scaleX = mode.contains("640") ? 1 : (mode.contains("160") ? 4 : 2)
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
            throw NSError(domain: "BBCMicroConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview"])
        }

        let previewImage = NSImage(cgImage: previewCGImage, size: NSSize(width: previewWidth, height: previewHeight))

        // Save native file
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let modeNum = mode.prefix(6).filter { $0.isNumber }
        let nativeUrl = tempDir.appendingPathComponent("bbcmicro_mode\(modeNum)_\(uuid).bbc")
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

    private func selectOptimalPalette(pixels: [[Float]], width: Int, height: Int, numColors: Int) -> [[UInt8]] {
        var colorCounts: [Int: Int] = [:]

        for pixel in pixels {
            let r = Int(max(0, min(255, pixel[0])))
            let g = Int(max(0, min(255, pixel[1])))
            let b = Int(max(0, min(255, pixel[2])))

            var bestIdx = 0
            var bestDist = Int.max
            for (i, color) in Self.bbcPalette.enumerated() {
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

        let sorted = colorCounts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }  // ties by key, so output is repeatable
        var palette: [[UInt8]] = []

        for (idx, _) in sorted.prefix(numColors) {
            palette.append(Self.bbcPalette[idx])
        }

        while palette.count < numColors {
            palette.append([0, 0, 0])
        }

        return palette
    }

    private func convertToBBCMicro(pixels: [[Float]], width: Int, height: Int,
                                    palette: [[UInt8]], mode: String, embeddedMode: UInt8,
                                    bytesPerLine: Int,
                                    ditherAlg: String, ditherAmount: Double,
                                    colorMatch: String) -> ([UInt8], Data) {

        var work = pixels
        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)
        var fileData = Data()

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"

        // BBC Micro uses interleaved memory: 8 bytes form one character row
        // Each character is 8 scanlines, with line 0 of all chars, then line 1, etc.
        let screenSize = bytesPerLine * height
        var bitmap = [UInt8](repeating: 0, count: screenSize)

        if mode.contains("Mode 0") || mode.contains("Mode 4") {
            // 1 bit per pixel
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

                    // BBC Micro Mode 0/4: 1bpp, MSB first
                    let charRow = y / 8
                    let charLine = y % 8
                    let charCol = x / 8
                    let pixelInChar = x % 8
                    let byteAddr = charRow * bytesPerLine * 8 + charCol * 8 + charLine
                    let bitPos = 7 - pixelInChar
                    if colorIndex == 1 && byteAddr < screenSize {
                        bitmap[byteAddr] |= UInt8(1 << bitPos)
                    }

                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }

        } else if mode.contains("Mode 1") || mode.contains("Mode 5") {
            // 2 bits per pixel (4 colors)
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

                    // BBC Micro Mode 1/5: 2bpp, packed as bits 7,3 (pixel 0), 6,2 (pixel 1), 5,1 (pixel 2), 4,0 (pixel 3)
                    let charRow = y / 8
                    let charLine = y % 8
                    let charCol = x / 4
                    let pixelInChar = x % 4
                    let byteAddr = charRow * bytesPerLine * 8 + charCol * 8 + charLine

                    if byteAddr < screenSize {
                        let bit0 = (colorIndex & 1) != 0
                        let bit1 = (colorIndex & 2) != 0
                        let shift = 3 - pixelInChar
                        if bit0 {
                            bitmap[byteAddr] |= UInt8(1 << shift)
                        }
                        if bit1 {
                            bitmap[byteAddr] |= UInt8(1 << (shift + 4))
                        }
                    }

                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }

        } else {
            // Mode 2: 4 bits per pixel (8 colors)
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

                    // BBC Micro Mode 2: 4bpp, packed as bits 7,5,3,1 (pixel 0) and 6,4,2,0 (pixel 1)
                    let charRow = y / 8
                    let charLine = y % 8
                    let charCol = x / 2
                    let pixelInChar = x % 2
                    let byteAddr = charRow * bytesPerLine * 8 + charCol * 8 + charLine

                    if byteAddr < screenSize {
                        let bit0 = (colorIndex & 1) != 0
                        let bit1 = (colorIndex & 2) != 0
                        let bit2 = (colorIndex & 4) != 0
                        // BBC uses logical colors 0-7, packed oddly
                        if pixelInChar == 0 {
                            if bit0 { bitmap[byteAddr] |= 0x02 }  // bit 1
                            if bit1 { bitmap[byteAddr] |= 0x08 }  // bit 3
                            if bit2 { bitmap[byteAddr] |= 0x20 }  // bit 5
                            bitmap[byteAddr] |= 0x80  // bit 7 always set for left pixel marker
                        } else {
                            if bit0 { bitmap[byteAddr] |= 0x01 }  // bit 0
                            if bit1 { bitmap[byteAddr] |= 0x04 }  // bit 2
                            if bit2 { bitmap[byteAddr] |= 0x10 }  // bit 4
                            bitmap[byteAddr] |= 0x40  // bit 6 always set for right pixel marker
                        }
                    }

                    if useErrorDiffusion {
                        AtariFamilyImageOps.applyErrorDiffusion(&work, x: x, y: y, width: width, height: height,
                                          r: r, g: g, b: b, finalColor: color,
                                          ditherAlg: ditherAlg, ditherAmount: ditherAmount)
                    }
                }
            }
        }

        fileData.append(contentsOf: bitmap)

        // Embed palette information after screen data
        // Format: mode byte + palette indices (indices into bbcPalette for each logical color)
        fileData.append(embeddedMode)

        // Convert selected palette colors back to their indices in bbcPalette
        for paletteColor in palette {
            var bestIndex: UInt8 = 0
            for (i, bbcColor) in Self.bbcPalette.enumerated() {
                if bbcColor[0] == paletteColor[0] && bbcColor[1] == paletteColor[1] && bbcColor[2] == paletteColor[2] {
                    bestIndex = UInt8(i)
                    break
                }
            }
            fileData.append(bestIndex)
        }

        return (resultPixels, fileData)
    }

    // MARK: - Preprocessing functions

    private func applyContrast(_ pixels: inout [[Float]], width: Int, height: Int, method: String) {
        switch method {
        case "HE":
            applyHistogramEqualization(&pixels, width: width, height: height)
        case "CLAHE":
            applyCLAHE(&pixels, width: width, height: height, clipLimit: 2.0, tileSize: 32)
        case "SWAHE":
            applySWAHE(&pixels, width: width, height: height, windowSize: 64)
        default:
            break
        }
    }

    private func applyHistogramEqualization(_ pixels: inout [[Float]], width: Int, height: Int) {
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in pixels {
            let luma = Int(max(0, min(255, 0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2])))
            histogram[luma] += 1
        }

        var cdf = [Int](repeating: 0, count: 256)
        cdf[0] = histogram[0]
        for i in 1..<256 {
            cdf[i] = cdf[i - 1] + histogram[i]
        }

        let cdfMin = cdf.first(where: { $0 > 0 }) ?? 0
        let totalPixels = width * height
        let denominator = totalPixels - cdfMin
        var lut = [Float](repeating: 0, count: 256)
        for i in 0..<256 {
            if denominator <= 0 {
                // Uniform image: use identity mapping
                lut[i] = Float(i)
            } else {
                lut[i] = Float(max(0, cdf[i] - cdfMin) * 255 / denominator)
            }
        }

        for i in 0..<pixels.count {
            let luma = Int(max(0, min(255, 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2])))
            // Use additive adjustment instead of ratio to avoid black output
            let lumaDiff = lut[luma] - Float(luma)
            pixels[i][0] = max(0, min(255, pixels[i][0] + lumaDiff))
            pixels[i][1] = max(0, min(255, pixels[i][1] + lumaDiff))
            pixels[i][2] = max(0, min(255, pixels[i][2] + lumaDiff))
        }
    }

    private func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int, clipLimit: Float, tileSize: Int) {
        let tilesX = (width + tileSize - 1) / tileSize
        let tilesY = (height + tileSize - 1) / tileSize
        var tileLUTs = [[[Float]]](repeating: [[Float]](repeating: [Float](repeating: 0, count: 256), count: tilesX), count: tilesY)

        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                var histogram = [Int](repeating: 0, count: 256)
                var count = 0

                let startY = ty * tileSize
                let endY = min(startY + tileSize, height)
                let startX = tx * tileSize
                let endX = min(startX + tileSize, width)

                for y in startY..<endY {
                    for x in startX..<endX {
                        let luma = Int(max(0, min(255, 0.299 * pixels[y * width + x][0] + 0.587 * pixels[y * width + x][1] + 0.114 * pixels[y * width + x][2])))
                        histogram[luma] += 1
                        count += 1
                    }
                }

                let clipThreshold = max(1, Int(clipLimit * Float(count) / 256.0))
                var excess = 0
                for i in 0..<256 {
                    if histogram[i] > clipThreshold {
                        excess += histogram[i] - clipThreshold
                        histogram[i] = clipThreshold
                    }
                }

                let increment = excess / 256
                for i in 0..<256 {
                    histogram[i] += increment
                }

                var cdf = [Int](repeating: 0, count: 256)
                cdf[0] = histogram[0]
                for i in 1..<256 {
                    cdf[i] = cdf[i - 1] + histogram[i]
                }

                let cdfMin = cdf.first(where: { $0 > 0 }) ?? 0
                let denominator = count - cdfMin
                for i in 0..<256 {
                    if denominator <= 0 {
                        // Uniform tile: use identity mapping
                        tileLUTs[ty][tx][i] = Float(i)
                    } else {
                        tileLUTs[ty][tx][i] = Float(max(0, cdf[i] - cdfMin) * 255 / denominator)
                    }
                }
            }
        }

        var result = pixels
        for y in 0..<height {
            for x in 0..<width {
                let luma = Int(max(0, min(255, 0.299 * pixels[y * width + x][0] + 0.587 * pixels[y * width + x][1] + 0.114 * pixels[y * width + x][2])))

                let tx = min(x / tileSize, tilesX - 1)
                let ty = min(y / tileSize, tilesY - 1)

                let newLuma = tileLUTs[ty][tx][luma]
                // Use additive adjustment instead of ratio to avoid black output
                let lumaDiff = newLuma - Float(luma)

                result[y * width + x][0] = max(0, min(255, pixels[y * width + x][0] + lumaDiff))
                result[y * width + x][1] = max(0, min(255, pixels[y * width + x][1] + lumaDiff))
                result[y * width + x][2] = max(0, min(255, pixels[y * width + x][2] + lumaDiff))
            }
        }

        pixels = result
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
                // Use additive adjustment instead of ratio to avoid black output
                let lumaDiff = newLuma - Float(luma)

                result[y * width + x][0] = max(0, min(255, pixels[y * width + x][0] + lumaDiff))
                result[y * width + x][1] = max(0, min(255, pixels[y * width + x][1] + lumaDiff))
                result[y * width + x][2] = max(0, min(255, pixels[y * width + x][2] + lumaDiff))

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
