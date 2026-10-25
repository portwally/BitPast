import Foundation
import AppKit

nonisolated class AtariSTConverter: RetroMachine {
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

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        try validateSourceImage(sourceImage)
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        let mode = opts.first(where: { $0.key == "mode" })?.selectedValue ?? "Low Res (320×200)"

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
        let ditherAlg = opts.first(where: { $0.key == "dither" })?.selectedValue ?? "Bayer 4x4"
        let ditherAmount = Double(opts.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrast = opts.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filter = opts.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let colorMatch = opts.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(opts.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(opts.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        try Task.checkCancellation()
        // Scale image to 320×200
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
            AtariFamilyImageOps.applyContrast(&pixels, width: width, height: height, method: contrast)
        }
        if filter != "None" {
            AtariFamilyImageOps.applyFilter(&pixels, width: width, height: height, filter: filter)
        }

        // Apply ordered dithering if selected
        if ditherAlg.contains("Bayer") || ditherAlg.contains("Blue Noise") || ditherAlg == "Noise" {
            AtariFamilyImageOps.applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount)
        }

        try Task.checkCancellation()
        // Quantize to optimal colors from the 512-color palette
        let selectedPalette = selectOptimalPalette(pixels: pixels, width: width, height: height, numColors: numColors)

        try Task.checkCancellation()
        // Convert with error diffusion if selected
        let (resultPixels, nativeData) = convertToST(pixels: pixels, width: width, height: height,
                                                      palette: selectedPalette,
                                                      ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                      colorMatch: colorMatch,
                                                      numBitplanes: numBitplanes,
                                                      resolutionWord: resolutionWord)

        // Create preview image
        // For low/medium res, double vertically; for high res, use 1:1
        try Task.checkCancellation()
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

    private func selectOptimalPalette(pixels: [[Float]], width: Int, height: Int, numColors: Int = 16) -> [[UInt8]] {
        var palette: [[UInt8]]
        if numColors == 2 {
            // Monochrome (high res): white background, black foreground
            palette = [[255, 255, 255], [0, 0, 0]]
        } else {
            // Colors that cover the picture, from the 512-color palette
            palette = CoveringPalette.pick(numColors, from: Self.stPalette, pixels: pixels).map { Self.stPalette[$0] }
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
            if Task.isCancelled { break }  // stop early if this preview was replaced
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

        return min(max(bestIndex, 0), palette.count - 1)
    }
}
