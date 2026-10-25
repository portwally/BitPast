import Foundation
import AppKit

nonisolated class Amiga500Converter: RetroMachine {
    var name: String = "Amiga 500"

    // Amiga 500 OCS/ECS: 4096 colors (12-bit), 32 colors in STD mode, HAM6 for more
    // Resolutions: 320×256, 320×512

    var options: [ConversionOption] = [
        ConversionOption(label: "Mode", key: "mode",
                        values: ["Standard (32 colors)", "HAM6 (4096 colors)"],
                        selectedValue: "Standard (32 colors)"),
        ConversionOption(label: "Resolution", key: "resolution",
                        values: ["320×256", "320×512"],
                        selectedValue: "320×256"),
        ConversionOption(label: "Dither", key: "dither",
                        values: ["None", "Floyd-Steinberg", "Atkinson", "Bayer 2x2", "Bayer 4x4", "Bayer 8x8"],
                        selectedValue: "Floyd-Steinberg"),
        ConversionOption(label: "Dither Amount", key: "dither_amount",
                        range: 0.0...1.0, defaultValue: 0.5),
        ConversionOption(label: "Contrast", key: "contrast",
                        values: ["None", "HE", "CLAHE", "SWAHE"],
                        selectedValue: "None"),
        ConversionOption(label: "Filter", key: "filter",
                        values: ["None", "Lowpass", "Sharpen", "Emboss", "Edge"],
                        selectedValue: "None"),
        ConversionOption(label: "Color Match", key: "color_match",
                        values: ["Euclidean", "Perceptive", "Luma", "Chroma"],
                        selectedValue: "Perceptive"),
        ConversionOption(label: "Saturation", key: "saturation",
                        range: 0.5...2.0, defaultValue: 1.0),
        ConversionOption(label: "Gamma", key: "gamma",
                        range: 0.5...2.0, defaultValue: 1.0)
    ]

    // Generate 4096-color OCS palette (4 bits R × 4 bits G × 4 bits B)
    static let ocsPalette: [[UInt8]] = {
        var palette: [[UInt8]] = []
        for r in 0..<16 {
            let rk = UInt8(r * 17)
            for g in 0..<16 {
                let gk = UInt8(g * 17)
                for b in 0..<16 {
                    let bk = UInt8(b * 17)
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

        let mode = opts.first(where: { $0.key == "mode" })?.selectedValue ?? "Standard (32 colors)"
        let resolution = opts.first(where: { $0.key == "resolution" })?.selectedValue ?? "320×256"
        let ditherAlg = opts.first(where: { $0.key == "dither" })?.selectedValue ?? "Floyd-Steinberg"
        let ditherAmount = Double(opts.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrast = opts.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filterMode = opts.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let colorMatch = opts.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(opts.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(opts.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        let width = 320
        let height = resolution == "320×512" ? 512 : 256

        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "Amiga500Converter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }

        try Task.checkCancellation()
        var pixels = AmigaFamilyImageOps.scaleImage(cgImage, toWidth: width, height: height)

        try Task.checkCancellation()
        // Apply preprocessing
        if saturation != 1.0 { AmigaFamilyImageOps.applySaturation(&pixels, width: width, height: height, saturation: saturation) }
        if gamma != 1.0 { AmigaFamilyImageOps.applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if contrast != "None" { applyContrast(&pixels, width: width, height: height, method: contrast) }
        if filterMode != "None" { AmigaFamilyImageOps.applyImageFilter(&pixels, width: width, height: height, filter: filterMode) }

        // Apply ordered dithering before palette selection
        if ditherAlg.contains("Bayer") {
            AmigaFamilyImageOps.applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount)
        }

        let isHAM = mode.contains("HAM6")
        let numColors = isHAM ? 16 : 32
        let numPlanes = isHAM ? 6 : 5

        try Task.checkCancellation()
        // Select optimal palette
        let selectedPalette = selectOptimalPalette(pixels: pixels, width: width, height: height, numColors: numColors)

        try Task.checkCancellation()
        // Convert
        let (resultPixels, bitplanes) = isHAM ?
            convertHAM6(pixels: pixels, width: width, height: height, palette: selectedPalette,
                       ditherAlg: ditherAlg, ditherAmount: ditherAmount, colorMatch: colorMatch) :
            convertStandard(pixels: pixels, width: width, height: height, palette: selectedPalette,
                           ditherAlg: ditherAlg, ditherAmount: ditherAmount, colorMatch: colorMatch, numPlanes: numPlanes)

        // Create preview image
        try Task.checkCancellation()
        let previewImage = createPreviewImage(resultPixels: resultPixels, width: width, height: height)

        // Create IFF file
        let videoMode: UInt32 = isHAM ? (resolution == "320×512" ? 0x0804 : 0x0800) : (resolution == "320×512" ? 0x0004 : 0x0000)
        let aspectX: UInt8 = resolution == "320×512" ? 22 : 44
        let aspectY: UInt8 = 44

        let iffData = AmigaFamilyImageOps.createIFF(width: width, height: height, palette: selectedPalette, bitplanes: bitplanes,
                                numPlanes: numPlanes, videoMode: videoMode, aspectX: aspectX, aspectY: aspectY)

        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("amiga500_\(uuid).iff")
        try iffData.write(to: nativeUrl)

        return ConversionResult(previewImage: previewImage, fileAssets: [nativeUrl], palettes: [], pixelIndices: [],
                               imageWidth: width, imageHeight: height)
    }

    private func selectOptimalPalette(pixels: [[Float]], width: Int, height: Int, numColors: Int) -> [[UInt8]] {
        // Colors that cover the picture, from the 4096-color OCS palette
        var palette = CoveringPalette.pick(numColors, from: Self.ocsPalette, pixels: pixels).map { Self.ocsPalette[$0] }
        while palette.count < numColors { palette.append([0, 0, 0]) }
        return palette
    }

    private func convertStandard(pixels: [[Float]], width: Int, height: Int, palette: [[UInt8]],
                                 ditherAlg: String, ditherAmount: Double, colorMatch: String, numPlanes: Int) -> ([UInt8], [[UInt16]]) {
        var work = pixels
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var bitplanes = [[UInt16]](repeating: [UInt16](repeating: 0, count: numPlanes), count: (width / 16) * height)

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"
        var index = 0
        var shift = 15

        for y in 0..<height {
            if Task.isCancelled { break }  // stop early if this preview was replaced
            for x in 0..<width {
                let r = max(0, min(255, work[y * width + x][0]))
                let g = max(0, min(255, work[y * width + x][1]))
                let b = max(0, min(255, work[y * width + x][2]))

                let colorIndex = AmigaFamilyImageOps.findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                let color = palette[colorIndex]

                let resultIdx = (y * width + x) * 3
                result[resultIdx] = color[0]
                result[resultIdx + 1] = color[1]
                result[resultIdx + 2] = color[2]

                // Encode to bitplanes
                for plane in 0..<numPlanes {
                    if (colorIndex & (1 << plane)) != 0 {
                        bitplanes[index][plane] |= UInt16(1 << shift)
                    }
                }

                if shift == 0 { shift = 15; index += 1 } else { shift -= 1 }

                // Error diffusion
                if useErrorDiffusion {
                    let rErr = (r - Float(color[0])) * Float(ditherAmount)
                    let gErr = (g - Float(color[1])) * Float(ditherAmount)
                    let bErr = (b - Float(color[2])) * Float(ditherAmount)
                    AmigaFamilyImageOps.distributeError(&work, width: width, height: height, x: x, y: y, rErr: rErr, gErr: gErr, bErr: bErr, alg: ditherAlg)
                }
            }
        }
        return (result, bitplanes)
    }

    private func convertHAM6(pixels: [[Float]], width: Int, height: Int, palette: [[UInt8]],
                             ditherAlg: String, ditherAmount: Double, colorMatch: String) -> ([UInt8], [[UInt16]]) {
        let work = pixels
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var bitplanes = [[UInt16]](repeating: [UInt16](repeating: 0, count: 6), count: (width / 16) * height)

        var index = 0
        var shift = 15

        for y in 0..<height {
            if Task.isCancelled { break }  // stop early if this preview was replaced
            var prevR: UInt8 = 0, prevG: UInt8 = 0, prevB: UInt8 = 0

            for x in 0..<width {
                let r0 = max(0, min(255, work[y * width + x][0]))
                let g0 = max(0, min(255, work[y * width + x][1]))
                let b0 = max(0, min(255, work[y * width + x][2]))

                var action: Int
                var finalR: UInt8, finalG: UInt8, finalB: UInt8

                if x == 0 {
                    // First pixel: use palette
                    let colorIdx = AmigaFamilyImageOps.findClosestColor(r: r0, g: g0, b: b0, palette: palette, method: colorMatch)
                    let c = palette[colorIdx]
                    finalR = c[0]; finalG = c[1]; finalB = c[2]
                    action = colorIdx
                } else {
                    // HAM: choose between palette or modify one channel
                    let colorIdx = AmigaFamilyImageOps.findClosestColor(r: r0, g: g0, b: b0, palette: palette, method: colorMatch)
                    let pc = palette[colorIdx]
                    let dPalette = AmigaFamilyImageOps.colorDistance(r0, g0, b0, Float(pc[0]), Float(pc[1]), Float(pc[2]), colorMatch)

                    // Try modifying each channel (4-bit OCS values, 0-15 mapped to 0-255)
                    let rOCS = min(15, max(0, (Int(r0) + 8) / 17))
                    let gOCS = min(15, max(0, (Int(g0) + 8) / 17))
                    let bOCS = min(15, max(0, (Int(b0) + 8) / 17))
                    let newR = UInt8(rOCS * 17)
                    let newG = UInt8(gOCS * 17)
                    let newB = UInt8(bOCS * 17)

                    let dR = AmigaFamilyImageOps.colorDistance(r0, g0, b0, Float(newR), Float(prevG), Float(prevB), colorMatch)
                    let dG = AmigaFamilyImageOps.colorDistance(r0, g0, b0, Float(prevR), Float(newG), Float(prevB), colorMatch)
                    let dB = AmigaFamilyImageOps.colorDistance(r0, g0, b0, Float(prevR), Float(prevG), Float(newB), colorMatch)

                    let minHAM = min(dR, min(dG, dB))

                    if minHAM < dPalette {
                        if minHAM == dR {
                            finalR = newR; finalG = prevG; finalB = prevB
                            action = 0b100000 | (Int(newR) / 17)
                        } else if minHAM == dG {
                            finalR = prevR; finalG = newG; finalB = prevB
                            action = 0b110000 | (Int(newG) / 17)
                        } else {
                            finalR = prevR; finalG = prevG; finalB = newB
                            action = 0b010000 | (Int(newB) / 17)
                        }
                    } else {
                        finalR = pc[0]; finalG = pc[1]; finalB = pc[2]
                        action = colorIdx
                    }
                }

                prevR = finalR; prevG = finalG; prevB = finalB

                let resultIdx = (y * width + x) * 3
                result[resultIdx] = finalR
                result[resultIdx + 1] = finalG
                result[resultIdx + 2] = finalB

                // Encode to 6 bitplanes
                for plane in 0..<6 {
                    if (action & (1 << plane)) != 0 {
                        bitplanes[index][plane] |= UInt16(1 << shift)
                    }
                }

                if shift == 0 { shift = 15; index += 1 } else { shift -= 1 }
            }
        }
        return (result, bitplanes)
    }

    private func createPreviewImage(resultPixels: [UInt8], width: Int, height: Int) -> NSImage {
        let scale = height > 256 ? 1 : 2
        let previewW = width * scale, previewH = height * scale
        var preview = [UInt8](repeating: 0, count: previewW * previewH * 4)

        for y in 0..<height {
            for x in 0..<width {
                let srcIdx = (y * width + x) * 3
                for dy in 0..<scale {
                    for dx in 0..<scale {
                        let dstIdx = ((y * scale + dy) * previewW + (x * scale + dx)) * 4
                        preview[dstIdx] = resultPixels[srcIdx]
                        preview[dstIdx + 1] = resultPixels[srcIdx + 1]
                        preview[dstIdx + 2] = resultPixels[srcIdx + 2]
                        preview[dstIdx + 3] = 255
                    }
                }
            }
        }

        let ctx = CGContext(data: &preview, width: previewW, height: previewH, bitsPerComponent: 8, bytesPerRow: previewW * 4,
                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: previewW, height: previewH))
    }

    // MARK: - Preprocessing

    private func applyContrast(_ pixels: inout [[Float]], width: Int, height: Int, method: String) {
        switch method {
        case "HE": applyHistogramEqualization(&pixels, width: width, height: height)
        case "CLAHE": applyCLAHE(&pixels, width: width, height: height, clipLimit: 3.0)
        case "SWAHE": applySWAHE(&pixels, width: width, height: height, windowSize: 40)
        default: break
        }
    }

    private func applyHistogramEqualization(_ pixels: inout [[Float]], width: Int, height: Int) {
        let total = width * height
        var histogram = [Int](repeating: 0, count: 256)
        for i in 0..<total {
            let luma = Int(max(0, min(255, 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2])))
            histogram[luma] += 1
        }
        var cdf = [Float](repeating: 0, count: 256)
        var cumulative = 0
        for i in 0..<256 { cumulative += histogram[i]; cdf[i] = Float(cumulative) / Float(total) * 255.0 }
        for i in 0..<total {
            let r = pixels[i][0], g = pixels[i][1], b = pixels[i][2]
            let luma = 0.299 * r + 0.587 * g + 0.114 * b
            let bin = Int(max(0, min(255, luma)))
            let newLuma = cdf[bin]
            if luma > 0.001 {
                let scale = newLuma / luma
                pixels[i][0] = max(0, min(255, r * scale))
                pixels[i][1] = max(0, min(255, g * scale))
                pixels[i][2] = max(0, min(255, b * scale))
            }
        }
    }

    private func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int, clipLimit: Float) {
        let tileWidth = 40, tileHeight = 32
        let tilesX = (width + tileWidth - 1) / tileWidth, tilesY = (height + tileHeight - 1) / tileHeight
        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let startX = tx * tileWidth, startY = ty * tileHeight
                let endX = min(startX + tileWidth, width), endY = min(startY + tileHeight, height)
                let tilePixels = (endX - startX) * (endY - startY)
                var histogram = [Int](repeating: 0, count: 256)
                for y in startY..<endY {
                    for x in startX..<endX {
                        let idx = y * width + x
                        histogram[Int(max(0, min(255, 0.299 * pixels[idx][0] + 0.587 * pixels[idx][1] + 0.114 * pixels[idx][2])))] += 1
                    }
                }
                let clipThreshold = Int(clipLimit * Float(tilePixels) / 256.0)
                var excess = 0
                for i in 0..<256 { if histogram[i] > clipThreshold { excess += histogram[i] - clipThreshold; histogram[i] = clipThreshold } }
                let increment = excess / 256
                for i in 0..<256 { histogram[i] += increment }
                var cdf = [Float](repeating: 0, count: 256)
                var cumulative = 0
                for i in 0..<256 { cumulative += histogram[i]; cdf[i] = Float(cumulative) / Float(tilePixels) * 255.0 }
                for y in startY..<endY {
                    for x in startX..<endX {
                        let idx = y * width + x
                        let r = pixels[idx][0], g = pixels[idx][1], b = pixels[idx][2]
                        let luma = 0.299 * r + 0.587 * g + 0.114 * b
                        let newLuma = cdf[Int(max(0, min(255, luma)))]
                        if luma > 0.001 { let scale = newLuma / luma; pixels[idx][0] = max(0, min(255, r * scale)); pixels[idx][1] = max(0, min(255, g * scale)); pixels[idx][2] = max(0, min(255, b * scale)) }
                    }
                }
            }
        }
    }

    private func applySWAHE(_ pixels: inout [[Float]], width: Int, height: Int, windowSize: Int) {
        let halfWindow = windowSize / 2
        var result = pixels
        var lumaBins = [Int](repeating: 0, count: width * height)
        for i in 0..<pixels.count { lumaBins[i] = Int(max(0, min(255, 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2]))) }
        for y in 0..<height {
            let startY = max(0, y - halfWindow), endY = min(height, y + halfWindow + 1)
            var histogram = [Int](repeating: 0, count: 256)
            var windowPixels = 0
            let initialEndX = min(width, halfWindow + 1)
            for wy in startY..<endY { for wx in 0..<initialEndX { histogram[lumaBins[wy * width + wx]] += 1; windowPixels += 1 } }
            for x in 0..<width {
                if x > 0 {
                    let addX = x + halfWindow, removeX = x - halfWindow - 1
                    if addX < width { for wy in startY..<endY { histogram[lumaBins[wy * width + addX]] += 1; windowPixels += 1 } }
                    if removeX >= 0 { for wy in startY..<endY { histogram[lumaBins[wy * width + removeX]] -= 1; windowPixels -= 1 } }
                }
                let idx = y * width + x
                var cumulative = 0; for i in 0...lumaBins[idx] { cumulative += histogram[i] }
                let newLuma = windowPixels > 0 ? Float(cumulative) / Float(windowPixels) * 255.0 : Float(lumaBins[idx]) / 255.0
                let r = pixels[idx][0], g = pixels[idx][1], b = pixels[idx][2]
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                if luma > 0.001 { let scale = newLuma / luma; result[idx][0] = max(0, min(255, r * scale)); result[idx][1] = max(0, min(255, g * scale)); result[idx][2] = max(0, min(255, b * scale)) }
            }
        }
        pixels = result
    }
}
