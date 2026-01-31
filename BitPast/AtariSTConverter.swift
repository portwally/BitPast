import Foundation
import AppKit

class AtariSTConverter: RetroMachine {
    var name: String = "Atari ST"

    // Atari ST has 512 colors (8 levels each for R, G, B)
    // Low Res: 320×200, 16 colors
    // Medium Res: 640×200, 4 colors
    // High Res: 640×400, 2 colors (monochrome)

    var options: [ConversionOption] = [
        ConversionOption(label: "Mode", key: "mode",
                        values: ["Low Res (320×200)", "Medium Res (640×200)", "High Res (640×400)"],
                        selectedValue: "Low Res (320×200)"),
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
                        values: ["Euclidean", "Perceptive", "Luma", "Chroma", "Mahalanobis"],
                        selectedValue: "Perceptive"),
        ConversionOption(label: "Saturation", key: "saturation",
                        range: 0.5...2.0, defaultValue: 1.0),
        ConversionOption(label: "Gamma", key: "gamma",
                        range: 0.5...2.0, defaultValue: 1.0)
    ]

    // Generate full 512-color Atari ST palette (8 levels R × 8 levels G × 8 levels B)
    static let stPalette: [[UInt8]] = {
        var palette: [[UInt8]] = []
        let k: Float = 255.0 / 7.0
        for r in 0..<8 {
            let rk = UInt8(round(Float(r) * k))
            for g in 0..<8 {
                let gk = UInt8(round(Float(g) * k))
                for b in 0..<8 {
                    let bk = UInt8(round(Float(b) * k))
                    palette.append([rk, gk, bk])
                }
            }
        }
        return palette
    }()

    func convert(sourceImage: NSImage) async throws -> ConversionResult {
        let mode = options.first(where: { $0.key == "mode" })?.selectedValue ?? "Low Res (320×200)"

        // Determine resolution and colors based on mode
        let width: Int
        let height: Int
        let numColors: Int
        let numBitplanes: Int
        let fileExtension: String
        let resolutionWord: UInt16

        switch mode {
        case "Medium Res (640×200)":
            width = 640
            height = 200
            numColors = 4
            numBitplanes = 2
            fileExtension = "pi2"
            resolutionWord = 0x0001
        case "High Res (640×400)":
            width = 640
            height = 400
            numColors = 2
            numBitplanes = 1
            fileExtension = "pi3"
            resolutionWord = 0x0002
        default: // Low Res
            width = 320
            height = 200
            numColors = 16
            numBitplanes = 4
            fileExtension = "pi1"
            resolutionWord = 0x0000
        }

        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "AtariSTConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }

        // Get options
        let ditherAlg = options.first(where: { $0.key == "dither" })?.selectedValue ?? "Bayer 4x4"
        let ditherAmount = Double(options.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrast = options.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filter = options.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let colorMatch = options.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(options.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(options.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        // Scale image to 320×200
        var pixels = scaleImage(cgImage, toWidth: width, height: height)

        // Apply preprocessing
        if saturation != 1.0 {
            applySaturation(&pixels, width: width, height: height, saturation: saturation)
        }
        if gamma != 1.0 {
            applyGamma(&pixels, width: width, height: height, gamma: gamma)
        }
        if contrast != "None" {
            applyContrast(&pixels, width: width, height: height, method: contrast)
        }
        if filter != "None" {
            applyFilter(&pixels, width: width, height: height, filter: filter)
        }

        // Apply ordered dithering if selected
        if ditherAlg.contains("Bayer") || ditherAlg.contains("Blue Noise") || ditherAlg == "Noise" {
            applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount)
        }

        // Quantize to optimal colors from the 512-color palette
        let selectedPalette = selectOptimalPalette(pixels: pixels, width: width, height: height, numColors: numColors)

        // Convert with error diffusion if selected
        let (resultPixels, nativeData) = convertToST(pixels: pixels, width: width, height: height,
                                                      palette: selectedPalette,
                                                      ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                      colorMatch: colorMatch,
                                                      numBitplanes: numBitplanes,
                                                      resolutionWord: resolutionWord)

        // Create preview image
        // For low/medium res, double vertically; for high res, use 1:1
        let scaleX = width == 320 ? 2 : 1
        let scaleY = height == 200 ? 2 : 1
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
            throw NSError(domain: "AtariSTConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview"])
        }

        let previewImage = NSImage(cgImage: previewCGImage, size: NSSize(width: previewWidth, height: previewHeight))

        // Save native file (DEGAS format: PI1/PI2/PI3)
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("atari_\(uuid).\(fileExtension)")
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

    private func scaleImage(_ cgImage: CGImage, toWidth width: Int, height: Int) -> [[Float]] {
        let context = CGContext(data: nil,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let data = context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var pixels = [[Float]](repeating: [0, 0, 0], count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                pixels[y * width + x] = [Float(data[idx]), Float(data[idx + 1]), Float(data[idx + 2])]
            }
        }

        return pixels
    }

    private func selectOptimalPalette(pixels: [[Float]], width: Int, height: Int, numColors: Int = 16) -> [[UInt8]] {
        // For monochrome (high res), just use black and white
        if numColors == 2 {
            // Pad to 16 entries (DEGAS format requirement)
            var palette: [[UInt8]] = [[255, 255, 255], [0, 0, 0]]  // White background, black foreground
            while palette.count < 16 {
                palette.append([0, 0, 0])
            }
            return palette
        }

        // Use median cut to select optimal colors from 512-color palette
        var colorCounts: [Int: Int] = [:]

        // Count colors mapped to ST palette
        for pixel in pixels {
            let r = Int(max(0, min(255, pixel[0])))
            let g = Int(max(0, min(255, pixel[1])))
            let b = Int(max(0, min(255, pixel[2])))

            // Map to nearest ST palette color
            let rIdx = (r * 7 + 127) / 255
            let gIdx = (g * 7 + 127) / 255
            let bIdx = (b * 7 + 127) / 255
            let colorIdx = rIdx * 64 + gIdx * 8 + bIdx

            colorCounts[colorIdx, default: 0] += 1
        }

        // Sort by frequency and take top N colors
        let sorted = colorCounts.sorted { $0.value > $1.value }
        var palette: [[UInt8]] = []

        for (idx, _) in sorted.prefix(numColors) {
            palette.append(Self.stPalette[idx])
        }

        // Pad to 16 (DEGAS format always stores 16 palette entries)
        while palette.count < 16 {
            palette.append([0, 0, 0])
        }

        return palette
    }

    private func convertToST(pixels: [[Float]], width: Int, height: Int,
                             palette: [[UInt8]],
                             ditherAlg: String, ditherAmount: Double,
                             colorMatch: String,
                             numBitplanes: Int = 4,
                             resolutionWord: UInt16 = 0x0000) -> ([UInt8], Data) {

        var work = pixels
        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)

        // Calculate bitplane array size
        // Words per line: width / 16
        // Total: numBitplanes × (width / 16) × height
        let wordsPerLine = width / 16
        var bitplanes = [UInt16](repeating: 0, count: numBitplanes * wordsPerLine * height)

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"

        var index = 0
        var shift = 15

        for y in 0..<height {
            for x in 0..<width {
                let r = max(0, min(255, work[y * width + x][0]))
                let g = max(0, min(255, work[y * width + x][1]))
                let b = max(0, min(255, work[y * width + x][2]))

                // Find closest color in selected palette
                let colorIndex = findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                let color = palette[colorIndex]

                let finalR = color[0]
                let finalG = color[1]
                let finalB = color[2]

                // Store result
                let resultIdx = (y * width + x) * 3
                resultPixels[resultIdx] = finalR
                resultPixels[resultIdx + 1] = finalG
                resultPixels[resultIdx + 2] = finalB

                // Encode to bitplanes (interleaved format)
                let maxColors = 1 << numBitplanes
                let value = colorIndex & (maxColors - 1)

                // Write bits to each bitplane
                for bp in 0..<numBitplanes {
                    let bit = (value >> bp) & 1
                    bitplanes[index + bp] |= UInt16(bit) << shift
                }

                if shift == 0 {
                    shift = 15
                    index += numBitplanes
                } else {
                    shift -= 1
                }

                // Error diffusion
                if useErrorDiffusion {
                    let rError = (r - Float(finalR)) * Float(ditherAmount)
                    let gError = (g - Float(finalG)) * Float(ditherAmount)
                    let bError = (b - Float(finalB)) * Float(ditherAmount)

                    if ditherAlg == "Floyd-Steinberg" {
                        if x < width - 1 {
                            work[y * width + x + 1][0] += rError * 7.0 / 16.0
                            work[y * width + x + 1][1] += gError * 7.0 / 16.0
                            work[y * width + x + 1][2] += bError * 7.0 / 16.0
                        }
                        if y < height - 1 {
                            if x > 0 {
                                work[(y + 1) * width + x - 1][0] += rError * 3.0 / 16.0
                                work[(y + 1) * width + x - 1][1] += gError * 3.0 / 16.0
                                work[(y + 1) * width + x - 1][2] += bError * 3.0 / 16.0
                            }
                            work[(y + 1) * width + x][0] += rError * 5.0 / 16.0
                            work[(y + 1) * width + x][1] += gError * 5.0 / 16.0
                            work[(y + 1) * width + x][2] += bError * 5.0 / 16.0
                            if x < width - 1 {
                                work[(y + 1) * width + x + 1][0] += rError * 1.0 / 16.0
                                work[(y + 1) * width + x + 1][1] += gError * 1.0 / 16.0
                                work[(y + 1) * width + x + 1][2] += bError * 1.0 / 16.0
                            }
                        }
                    } else if ditherAlg == "Atkinson" {
                        let dist = rError / 8.0
                        let distG = gError / 8.0
                        let distB = bError / 8.0

                        if x < width - 1 {
                            work[y * width + x + 1][0] += dist
                            work[y * width + x + 1][1] += distG
                            work[y * width + x + 1][2] += distB
                        }
                        if x < width - 2 {
                            work[y * width + x + 2][0] += dist
                            work[y * width + x + 2][1] += distG
                            work[y * width + x + 2][2] += distB
                        }
                        if y < height - 1 {
                            if x > 0 {
                                work[(y + 1) * width + x - 1][0] += dist
                                work[(y + 1) * width + x - 1][1] += distG
                                work[(y + 1) * width + x - 1][2] += distB
                            }
                            work[(y + 1) * width + x][0] += dist
                            work[(y + 1) * width + x][1] += distG
                            work[(y + 1) * width + x][2] += distB
                            if x < width - 1 {
                                work[(y + 1) * width + x + 1][0] += dist
                                work[(y + 1) * width + x + 1][1] += distG
                                work[(y + 1) * width + x + 1][2] += distB
                            }
                        }
                        if y < height - 2 {
                            work[(y + 2) * width + x][0] += dist
                            work[(y + 2) * width + x][1] += distG
                            work[(y + 2) * width + x][2] += distB
                        }
                    }
                }
            }
        }

        // Create DEGAS file (PI1/PI2/PI3)
        var fileData = Data()

        // Resolution word (0x0000 = low-res, 0x0001 = med-res, 0x0002 = high-res)
        fileData.append(UInt8((resolutionWord >> 8) & 0xFF))
        fileData.append(UInt8(resolutionWord & 0xFF))

        // Palette (16 colors × 2 bytes, big-endian)
        // Atari ST palette format: 0x0RGB (3 bits each)
        for i in 0..<16 {
            let color = palette[i]
            let r3 = Int(color[0]) / 32  // 8-bit to 3-bit
            let g3 = Int(color[1]) / 32
            let b3 = Int(color[2]) / 32

            // Note: Atari ST stores as 0x0RGB but the reference shows BGR order
            // Looking at reference: b = color[0], g = color[1], r = color[2]
            // So the value is (r << 8) | (g << 4) | b
            let value = (r3 << 8) | (g3 << 4) | b3
            fileData.append(UInt8((value >> 8) & 0xFF))
            fileData.append(UInt8(value & 0xFF))
        }

        // Bitplane data (big-endian words)
        for word in bitplanes {
            fileData.append(UInt8((word >> 8) & 0xFF))
            fileData.append(UInt8(word & 0xFF))
        }

        return (resultPixels, fileData)
    }

    private func findClosestColor(r: Float, g: Float, b: Float, palette: [[UInt8]], method: String) -> Int {
        var bestIndex = 0
        var bestDist = Float.greatestFiniteMagnitude

        for (i, color) in palette.enumerated() {
            let pr = Float(color[0])
            let pg = Float(color[1])
            let pb = Float(color[2])

            let dist: Float
            switch method {
            case "Perceptive":
                let rmean = (r + pr) / 2.0
                let dr = r - pr
                let dg = g - pg
                let db = b - pb
                dist = sqrt((2.0 + rmean / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rmean) / 256.0) * db * db)
            case "Luma":
                let luma1 = 0.299 * r + 0.587 * g + 0.114 * b
                let luma2 = 0.299 * pr + 0.587 * pg + 0.114 * pb
                dist = abs(luma1 - luma2)
            case "Chroma":
                let dr = r - pr
                let dg = g - pg
                let db = b - pb
                dist = sqrt(dr * dr * 0.5 + dg * dg * 0.5 + db * db * 0.5) + abs((r - g) - (pr - pg)) + abs((g - b) - (pg - pb))
            case "Mahalanobis":
                let dr = (r - pr) / 64.0
                let dg = (g - pg) / 64.0
                let db = (b - pb) / 64.0
                dist = sqrt(dr * dr + dg * dg + db * db + dr * dg * 0.5 + dg * db * 0.5)
            default: // Euclidean
                let dr = r - pr
                let dg = g - pg
                let db = b - pb
                dist = sqrt(dr * dr + dg * dg + db * db)
            }

            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        return bestIndex
    }

    // MARK: - Preprocessing functions

    private func applySaturation(_ pixels: inout [[Float]], width: Int, height: Int, saturation: Double) {
        let sat = Float(saturation)
        for i in 0..<pixels.count {
            let r = pixels[i][0]
            let g = pixels[i][1]
            let b = pixels[i][2]
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            pixels[i][0] = max(0, min(255, gray + (r - gray) * sat))
            pixels[i][1] = max(0, min(255, gray + (g - gray) * sat))
            pixels[i][2] = max(0, min(255, gray + (b - gray) * sat))
        }
    }

    private func applyGamma(_ pixels: inout [[Float]], width: Int, height: Int, gamma: Double) {
        let invGamma = 1.0 / gamma
        for i in 0..<pixels.count {
            pixels[i][0] = Float(pow(Double(pixels[i][0]) / 255.0, invGamma) * 255.0)
            pixels[i][1] = Float(pow(Double(pixels[i][1]) / 255.0, invGamma) * 255.0)
            pixels[i][2] = Float(pow(Double(pixels[i][2]) / 255.0, invGamma) * 255.0)
        }
    }

    private func applyContrast(_ pixels: inout [[Float]], width: Int, height: Int, method: String) {
        switch method {
        case "HE":
            applyHistogramEqualization(&pixels, width: width, height: height)
        case "CLAHE":
            applyCLAHE(&pixels, width: width, height: height, clipLimit: 2.0, tileSize: 8)
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
        var lut = [Float](repeating: 0, count: 256)
        for i in 0..<256 {
            lut[i] = Float((cdf[i] - cdfMin) * 255 / max(1, totalPixels - cdfMin))
        }

        for i in 0..<pixels.count {
            let luma = Int(max(0, min(255, 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2])))
            let ratio = luma > 0 ? lut[luma] / Float(luma) : 1.0
            pixels[i][0] = max(0, min(255, pixels[i][0] * ratio))
            pixels[i][1] = max(0, min(255, pixels[i][1] * ratio))
            pixels[i][2] = max(0, min(255, pixels[i][2] * ratio))
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

                let clipThreshold = Int(clipLimit * Float(count) / 256.0)
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
                for i in 0..<256 {
                    tileLUTs[ty][tx][i] = Float((cdf[i] - cdfMin) * 255 / max(1, count - cdfMin))
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
                let ratio = luma > 0 ? newLuma / Float(luma) : 1.0

                result[y * width + x][0] = max(0, min(255, pixels[y * width + x][0] * ratio))
                result[y * width + x][1] = max(0, min(255, pixels[y * width + x][1] * ratio))
                result[y * width + x][2] = max(0, min(255, pixels[y * width + x][2] * ratio))
            }
        }

        pixels = result
    }

    private func applySWAHE(_ pixels: inout [[Float]], width: Int, height: Int, windowSize: Int) {
        let halfWindow = windowSize / 2
        var result = pixels

        var histogram = [Int](repeating: 0, count: 256)
        var pixelCount = 0

        // Initialize histogram for first window
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

                let newLuma = Float(cdf * 255 / max(1, pixelCount))
                let ratio = luma > 0 ? newLuma / Float(luma) : 1.0

                result[y * width + x][0] = max(0, min(255, pixels[y * width + x][0] * ratio))
                result[y * width + x][1] = max(0, min(255, pixels[y * width + x][1] * ratio))
                result[y * width + x][2] = max(0, min(255, pixels[y * width + x][2] * ratio))

                // Update histogram for sliding window
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

    private func applyFilter(_ pixels: inout [[Float]], width: Int, height: Int, filter: String) {
        let lowpassKernel: [[Float]] = [
            [1.0/9.0, 1.0/9.0, 1.0/9.0],
            [1.0/9.0, 1.0/9.0, 1.0/9.0],
            [1.0/9.0, 1.0/9.0, 1.0/9.0]
        ]
        let sharpenKernel: [[Float]] = [
            [0.0, -1.0, 0.0],
            [-1.0, 5.0, -1.0],
            [0.0, -1.0, 0.0]
        ]
        let embossKernel: [[Float]] = [
            [-2.0, -1.0, 0.0],
            [-1.0, 1.0, 1.0],
            [0.0, 1.0, 2.0]
        ]

        switch filter {
        case "Lowpass":
            applyConvolution(&pixels, width: width, height: height, kernel: lowpassKernel)
        case "Sharpen":
            applyConvolution(&pixels, width: width, height: height, kernel: sharpenKernel)
        case "Emboss":
            applyConvolution(&pixels, width: width, height: height, kernel: embossKernel)
        case "Edge":
            applyEdgeFilter(&pixels, width: width, height: height)
        default:
            break
        }
    }

    private func applyConvolution(_ pixels: inout [[Float]], width: Int, height: Int, kernel: [[Float]]) {
        let kSize = kernel.count
        let kHalf = kSize / 2
        var result = pixels

        for y in kHalf..<(height - kHalf) {
            for x in kHalf..<(width - kHalf) {
                var sumR: Float = 0
                var sumG: Float = 0
                var sumB: Float = 0

                for ky in 0..<kSize {
                    for kx in 0..<kSize {
                        let px = x + kx - kHalf
                        let py = y + ky - kHalf
                        let idx = py * width + px
                        let weight = kernel[ky][kx]

                        sumR += pixels[idx][0] * weight
                        sumG += pixels[idx][1] * weight
                        sumB += pixels[idx][2] * weight
                    }
                }

                let idx = y * width + x
                result[idx][0] = max(0, min(255, sumR))
                result[idx][1] = max(0, min(255, sumG))
                result[idx][2] = max(0, min(255, sumB))
            }
        }

        pixels = result
    }

    private func applyEdgeFilter(_ pixels: inout [[Float]], width: Int, height: Int) {
        let sobelX: [[Float]] = [
            [-1, 0, 1],
            [-2, 0, 2],
            [-1, 0, 1]
        ]
        let sobelY: [[Float]] = [
            [-1, -2, -1],
            [0, 0, 0],
            [1, 2, 1]
        ]

        var result = pixels

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var gxR: Float = 0, gxG: Float = 0, gxB: Float = 0
                var gyR: Float = 0, gyG: Float = 0, gyB: Float = 0

                for ky in 0..<3 {
                    for kx in 0..<3 {
                        let px = x + kx - 1
                        let py = y + ky - 1
                        let idx = py * width + px

                        gxR += pixels[idx][0] * sobelX[ky][kx]
                        gxG += pixels[idx][1] * sobelX[ky][kx]
                        gxB += pixels[idx][2] * sobelX[ky][kx]

                        gyR += pixels[idx][0] * sobelY[ky][kx]
                        gyG += pixels[idx][1] * sobelY[ky][kx]
                        gyB += pixels[idx][2] * sobelY[ky][kx]
                    }
                }

                let edgeR = sqrt(gxR * gxR + gyR * gyR)
                let edgeG = sqrt(gxG * gxG + gyG * gyG)
                let edgeB = sqrt(gxB * gxB + gyB * gyB)

                let idx = y * width + x
                result[idx][0] = max(0, min(255, (pixels[idx][0] + edgeR) * 0.5))
                result[idx][1] = max(0, min(255, (pixels[idx][1] + edgeG) * 0.5))
                result[idx][2] = max(0, min(255, (pixels[idx][2] + edgeB) * 0.5))
            }
        }

        pixels = result
    }

    private func applyOrderedDither(_ pixels: inout [[Float]], width: Int, height: Int, ditherType: String, amount: Double) {
        let matrix: [[Float]]
        let matrixSize: Int

        switch ditherType {
        case "Bayer 2x2":
            matrix = [[0, 2], [3, 1]]
            matrixSize = 2
        case "Bayer 4x4":
            matrix = [
                [0, 8, 2, 10],
                [12, 4, 14, 6],
                [3, 11, 1, 9],
                [15, 7, 13, 5]
            ]
            matrixSize = 4
        case "Bayer 8x8":
            matrix = [
                [0, 32, 8, 40, 2, 34, 10, 42],
                [48, 16, 56, 24, 50, 18, 58, 26],
                [12, 44, 4, 36, 14, 46, 6, 38],
                [60, 28, 52, 20, 62, 30, 54, 22],
                [3, 35, 11, 43, 1, 33, 9, 41],
                [51, 19, 59, 27, 49, 17, 57, 25],
                [15, 47, 7, 39, 13, 45, 5, 37],
                [63, 31, 55, 23, 61, 29, 53, 21]
            ]
            matrixSize = 8
        case "Bayer 16x16":
            var m = [[Float]](repeating: [Float](repeating: 0, count: 16), count: 16)
            let base: [[Float]] = [
                [0, 8, 2, 10],
                [12, 4, 14, 6],
                [3, 11, 1, 9],
                [15, 7, 13, 5]
            ]
            for y in 0..<16 {
                for x in 0..<16 {
                    m[y][x] = base[y % 4][x % 4] * 16 + base[y / 4][x / 4]
                }
            }
            matrix = m
            matrixSize = 16
        case "Blue Noise 8x8", "Blue Noise 16x16":
            let size = ditherType == "Blue Noise 8x8" ? 8 : 16
            var m = [[Float]](repeating: [Float](repeating: 0, count: size), count: size)
            for y in 0..<size {
                for x in 0..<size {
                    let golden = 0.618033988749895
                    let hash = Double((x * 12345 + y * 67890) & 0xFFFF) / 65536.0
                    m[y][x] = Float((hash + golden).truncatingRemainder(dividingBy: 1.0) * Double(size * size))
                }
            }
            matrix = m
            matrixSize = size
        case "Noise":
            for i in 0..<pixels.count {
                let noise = (Float.random(in: 0...1) - 0.5) * 32.0 * Float(amount)
                pixels[i][0] = max(0, min(255, pixels[i][0] + noise))
                pixels[i][1] = max(0, min(255, pixels[i][1] + noise))
                pixels[i][2] = max(0, min(255, pixels[i][2] + noise))
            }
            return
        default:
            return
        }

        let maxVal = Float(matrixSize * matrixSize)
        let strength = Float(amount) * 64.0

        for y in 0..<height {
            for x in 0..<width {
                let threshold = (matrix[y % matrixSize][x % matrixSize] / maxVal - 0.5) * strength
                let idx = y * width + x
                pixels[idx][0] = max(0, min(255, pixels[idx][0] + threshold))
                pixels[idx][1] = max(0, min(255, pixels[idx][1] + threshold))
                pixels[idx][2] = max(0, min(255, pixels[idx][2] + threshold))
            }
        }
    }
}
