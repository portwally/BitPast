import Foundation
import AppKit

class Amiga1200Converter: RetroMachine {
    var name: String = "Amiga 1200"

    // Amiga 1200 AGA: 24-bit color (16.7M), 256 colors in STD mode, HAM8 for more
    // Resolutions: 320×256, 320×512, 640×512

    var options: [ConversionOption] = [
        ConversionOption(label: "Mode", key: "mode",
                        values: ["Standard (256 colors)", "HAM8 (262144 colors)"],
                        selectedValue: "Standard (256 colors)"),
        ConversionOption(label: "Resolution", key: "resolution",
                        values: ["320×256", "320×512", "640×512"],
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

    func convert(sourceImage: NSImage) async throws -> ConversionResult {
        let mode = options.first(where: { $0.key == "mode" })?.selectedValue ?? "Standard (256 colors)"
        let resolution = options.first(where: { $0.key == "resolution" })?.selectedValue ?? "320×256"
        let ditherAlg = options.first(where: { $0.key == "dither" })?.selectedValue ?? "Floyd-Steinberg"
        let ditherAmount = Double(options.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrast = options.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filterMode = options.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let colorMatch = options.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(options.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(options.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        let width: Int
        let height: Int
        switch resolution {
        case "320×512": width = 320; height = 512
        case "640×512": width = 640; height = 512
        default: width = 320; height = 256
        }

        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "Amiga1200Converter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }

        var pixels = scaleImage(cgImage, toWidth: width, height: height)

        // Apply preprocessing
        if saturation != 1.0 { applySaturation(&pixels, width: width, height: height, saturation: saturation) }
        if gamma != 1.0 { applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if contrast != "None" { applyContrast(&pixels, width: width, height: height, method: contrast) }
        if filterMode != "None" { applyImageFilter(&pixels, width: width, height: height, filter: filterMode) }

        if ditherAlg.contains("Bayer") {
            applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount)
        }

        let isHAM = mode.contains("HAM8")
        let numColors = isHAM ? 64 : 256
        let numPlanes = 8

        // Select optimal palette (256 colors for STD, 64 for HAM8 base palette)
        let selectedPalette = selectOptimalPalette(pixels: pixels, width: width, height: height, numColors: numColors)

        // Convert
        let (resultPixels, bitplanes) = isHAM ?
            convertHAM8(pixels: pixels, width: width, height: height, palette: selectedPalette,
                       ditherAlg: ditherAlg, ditherAmount: ditherAmount, colorMatch: colorMatch) :
            convertStandard256(pixels: pixels, width: width, height: height, palette: selectedPalette,
                              ditherAlg: ditherAlg, ditherAmount: ditherAmount, colorMatch: colorMatch)

        // Create preview
        let previewImage = createPreviewImage(resultPixels: resultPixels, width: width, height: height)

        // Video mode flags
        let videoMode: UInt32
        switch (mode.contains("HAM8"), resolution) {
        case (true, "320×512"): videoMode = 0x0804
        case (true, "640×512"): videoMode = 0x8804
        case (true, _): videoMode = 0x0800
        case (false, "320×512"): videoMode = 0x0004
        case (false, "640×512"): videoMode = 0x8004
        default: videoMode = 0x0000
        }

        let aspectX: UInt8 = (resolution == "640×512") ? 22 : (resolution == "320×512" ? 22 : 44)
        let aspectY: UInt8 = 44

        let iffData = createIFF(width: width, height: height, palette: selectedPalette, bitplanes: bitplanes,
                                numPlanes: numPlanes, videoMode: videoMode, aspectX: aspectX, aspectY: aspectY)

        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("amiga1200_\(uuid).iff")
        try iffData.write(to: nativeUrl)

        return ConversionResult(previewImage: previewImage, fileAssets: [nativeUrl], palettes: [], pixelIndices: [],
                               imageWidth: width, imageHeight: height)
    }

    private func scaleImage(_ cgImage: CGImage, toWidth width: Int, height: Int) -> [[Float]] {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let data = context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var pixels = [[Float]](repeating: [0, 0, 0], count: width * height)
        for i in 0..<(width * height) {
            pixels[i] = [Float(data[i * 4]), Float(data[i * 4 + 1]), Float(data[i * 4 + 2])]
        }
        return pixels
    }

    private func selectOptimalPalette(pixels: [[Float]], width: Int, height: Int, numColors: Int) -> [[UInt8]] {
        // Simple frequency-based palette selection
        var colorCounts: [[UInt8]: Int] = [:]
        for pixel in pixels {
            let r = UInt8(max(0, min(255, pixel[0])))
            let g = UInt8(max(0, min(255, pixel[1])))
            let b = UInt8(max(0, min(255, pixel[2])))
            // Quantize to reduce unique colors
            let qr = (r / 4) * 4
            let qg = (g / 4) * 4
            let qb = (b / 4) * 4
            colorCounts[[qr, qg, qb], default: 0] += 1
        }

        let sorted = colorCounts.sorted { $0.value > $1.value }
        var palette: [[UInt8]] = []
        for (color, _) in sorted.prefix(numColors) {
            palette.append(color)
        }
        while palette.count < numColors { palette.append([0, 0, 0]) }
        return palette
    }

    private func convertStandard256(pixels: [[Float]], width: Int, height: Int, palette: [[UInt8]],
                                    ditherAlg: String, ditherAmount: Double, colorMatch: String) -> ([UInt8], [[UInt16]]) {
        var work = pixels
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var bitplanes = [[UInt16]](repeating: [UInt16](repeating: 0, count: 8), count: (width / 16) * height)

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"
        var index = 0
        var shift = 15

        for y in 0..<height {
            for x in 0..<width {
                let r = max(0, min(255, work[y * width + x][0]))
                let g = max(0, min(255, work[y * width + x][1]))
                let b = max(0, min(255, work[y * width + x][2]))

                let colorIndex = findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                let color = palette[colorIndex]

                let resultIdx = (y * width + x) * 3
                result[resultIdx] = color[0]
                result[resultIdx + 1] = color[1]
                result[resultIdx + 2] = color[2]

                // Encode to 8 bitplanes
                for plane in 0..<8 {
                    if (colorIndex & (1 << plane)) != 0 {
                        bitplanes[index][plane] |= UInt16(1 << shift)
                    }
                }

                if shift == 0 { shift = 15; index += 1 } else { shift -= 1 }

                if useErrorDiffusion {
                    let rErr = (r - Float(color[0])) * Float(ditherAmount)
                    let gErr = (g - Float(color[1])) * Float(ditherAmount)
                    let bErr = (b - Float(color[2])) * Float(ditherAmount)
                    distributeError(&work, width: width, height: height, x: x, y: y, rErr: rErr, gErr: gErr, bErr: bErr, alg: ditherAlg)
                }
            }
        }
        return (result, bitplanes)
    }

    private func convertHAM8(pixels: [[Float]], width: Int, height: Int, palette: [[UInt8]],
                             ditherAlg: String, ditherAmount: Double, colorMatch: String) -> ([UInt8], [[UInt16]]) {
        var work = pixels
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var bitplanes = [[UInt16]](repeating: [UInt16](repeating: 0, count: 8), count: (width / 16) * height)

        var index = 0
        var shift = 15

        for y in 0..<height {
            var prevR: UInt8 = 0, prevG: UInt8 = 0, prevB: UInt8 = 0

            for x in 0..<width {
                let r0 = max(0, min(255, work[y * width + x][0]))
                let g0 = max(0, min(255, work[y * width + x][1]))
                let b0 = max(0, min(255, work[y * width + x][2]))

                var action: Int
                var finalR: UInt8, finalG: UInt8, finalB: UInt8

                if x == 0 {
                    let colorIdx = findClosestColor(r: r0, g: g0, b: b0, palette: palette, method: colorMatch)
                    let c = palette[colorIdx]
                    finalR = c[0]; finalG = c[1]; finalB = c[2]
                    action = colorIdx
                } else {
                    let colorIdx = findClosestColor(r: r0, g: g0, b: b0, palette: palette, method: colorMatch)
                    let pc = palette[colorIdx]
                    let dPalette = colorDistance(r0, g0, b0, Float(pc[0]), Float(pc[1]), Float(pc[2]), colorMatch)

                    // HAM8: 6 bits per channel modification
                    let newR = UInt8(Int(r0) & 0xFC)
                    let newG = UInt8(Int(g0) & 0xFC)
                    let newB = UInt8(Int(b0) & 0xFC)

                    let dR = colorDistance(r0, g0, b0, Float(newR), Float(prevG), Float(prevB), colorMatch)
                    let dG = colorDistance(r0, g0, b0, Float(prevR), Float(newG), Float(prevB), colorMatch)
                    let dB = colorDistance(r0, g0, b0, Float(prevR), Float(prevG), Float(newB), colorMatch)

                    let minHAM = min(dR, min(dG, dB))

                    if minHAM < dPalette {
                        if minHAM == dR {
                            finalR = newR; finalG = prevG; finalB = prevB
                            action = 0b10_000000 | (Int(newR) >> 2)
                        } else if minHAM == dG {
                            finalR = prevR; finalG = newG; finalB = prevB
                            action = 0b11_000000 | (Int(newG) >> 2)
                        } else {
                            finalR = prevR; finalG = prevG; finalB = newB
                            action = 0b01_000000 | (Int(newB) >> 2)
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

                // Encode to 8 bitplanes
                for plane in 0..<8 {
                    if (action & (1 << plane)) != 0 {
                        bitplanes[index][plane] |= UInt16(1 << shift)
                    }
                }

                if shift == 0 { shift = 15; index += 1 } else { shift -= 1 }
            }
        }
        return (result, bitplanes)
    }

    private func colorDistance(_ r1: Float, _ g1: Float, _ b1: Float, _ r2: Float, _ g2: Float, _ b2: Float, _ method: String) -> Float {
        let dr = r1 - r2, dg = g1 - g2, db = b1 - b2
        switch method {
        case "Perceptive":
            // Weighted for human color perception
            let rmean = (r1 + r2) / 2.0
            return sqrt((2.0 + rmean / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rmean) / 256.0) * db * db)
        case "Luma":
            // Strongly prioritize brightness matching, ignore color differences
            let luma1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
            let luma2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
            let dLuma = luma1 - luma2
            return abs(dLuma) * 3.0 + sqrt(dr * dr + dg * dg + db * db) * 0.1
        case "Chroma":
            // Prioritize hue/saturation matching, tolerate brightness differences
            let luma1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
            let luma2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
            // Normalize to remove brightness, compare chrominance
            let cr1 = luma1 > 1 ? r1 / luma1 : 0, cg1 = luma1 > 1 ? g1 / luma1 : 0, cb1 = luma1 > 1 ? b1 / luma1 : 0
            let cr2 = luma2 > 1 ? r2 / luma2 : 0, cg2 = luma2 > 1 ? g2 / luma2 : 0, cb2 = luma2 > 1 ? b2 / luma2 : 0
            let chromaDist = sqrt((cr1-cr2)*(cr1-cr2) + (cg1-cg2)*(cg1-cg2) + (cb1-cb2)*(cb1-cb2)) * 255.0
            let lumaDist = abs(luma1 - luma2) * 0.2
            return chromaDist + lumaDist
        default: // Euclidean
            return sqrt(dr * dr + dg * dg + db * db)
        }
    }

    private func findClosestColor(r: Float, g: Float, b: Float, palette: [[UInt8]], method: String) -> Int {
        var bestIdx = 0
        var bestDist = Float.greatestFiniteMagnitude
        for (i, c) in palette.enumerated() {
            let d = colorDistance(r, g, b, Float(c[0]), Float(c[1]), Float(c[2]), method)
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        return bestIdx
    }

    private func distributeError(_ work: inout [[Float]], width: Int, height: Int, x: Int, y: Int,
                                  rErr: Float, gErr: Float, bErr: Float, alg: String) {
        if alg == "Floyd-Steinberg" {
            if x < width - 1 {
                work[y * width + x + 1][0] += rErr * 7 / 16
                work[y * width + x + 1][1] += gErr * 7 / 16
                work[y * width + x + 1][2] += bErr * 7 / 16
            }
            if y < height - 1 {
                if x > 0 {
                    work[(y + 1) * width + x - 1][0] += rErr * 3 / 16
                    work[(y + 1) * width + x - 1][1] += gErr * 3 / 16
                    work[(y + 1) * width + x - 1][2] += bErr * 3 / 16
                }
                work[(y + 1) * width + x][0] += rErr * 5 / 16
                work[(y + 1) * width + x][1] += gErr * 5 / 16
                work[(y + 1) * width + x][2] += bErr * 5 / 16
                if x < width - 1 {
                    work[(y + 1) * width + x + 1][0] += rErr / 16
                    work[(y + 1) * width + x + 1][1] += gErr / 16
                    work[(y + 1) * width + x + 1][2] += bErr / 16
                }
            }
        } else if alg == "Atkinson" {
            let d = rErr / 8, dg = gErr / 8, db = bErr / 8
            if x < width - 1 { work[y * width + x + 1][0] += d; work[y * width + x + 1][1] += dg; work[y * width + x + 1][2] += db }
            if x < width - 2 { work[y * width + x + 2][0] += d; work[y * width + x + 2][1] += dg; work[y * width + x + 2][2] += db }
            if y < height - 1 {
                if x > 0 { work[(y+1)*width+x-1][0] += d; work[(y+1)*width+x-1][1] += dg; work[(y+1)*width+x-1][2] += db }
                work[(y+1)*width+x][0] += d; work[(y+1)*width+x][1] += dg; work[(y+1)*width+x][2] += db
                if x < width-1 { work[(y+1)*width+x+1][0] += d; work[(y+1)*width+x+1][1] += dg; work[(y+1)*width+x+1][2] += db }
            }
            if y < height - 2 { work[(y+2)*width+x][0] += d; work[(y+2)*width+x][1] += dg; work[(y+2)*width+x][2] += db }
        }
    }

    private func createPreviewImage(resultPixels: [UInt8], width: Int, height: Int) -> NSImage {
        let scale = (width >= 640 || height >= 512) ? 1 : 2
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

    private func createIFF(width: Int, height: Int, palette: [[UInt8]], bitplanes: [[UInt16]],
                           numPlanes: Int, videoMode: UInt32, aspectX: UInt8, aspectY: UInt8) -> Data {
        var data = Data()

        // BMHD chunk
        var bmhd = Data()
        bmhd.append(contentsOf: withUnsafeBytes(of: UInt16(width).bigEndian) { Array($0) })
        bmhd.append(contentsOf: withUnsafeBytes(of: UInt16(height).bigEndian) { Array($0) })
        bmhd.append(contentsOf: [0, 0, 0, 0])
        bmhd.append(UInt8(numPlanes))
        bmhd.append(0)
        bmhd.append(0)
        bmhd.append(0)
        bmhd.append(contentsOf: [0, 0])
        bmhd.append(aspectX)
        bmhd.append(aspectY)
        bmhd.append(contentsOf: withUnsafeBytes(of: UInt16(width).bigEndian) { Array($0) })
        bmhd.append(contentsOf: withUnsafeBytes(of: UInt16(height).bigEndian) { Array($0) })

        // CMAP chunk
        var cmap = Data()
        for color in palette {
            cmap.append(color[0])
            cmap.append(color[1])
            cmap.append(color[2])
        }

        // CAMG chunk
        var camg = Data()
        camg.append(contentsOf: withUnsafeBytes(of: videoMode.bigEndian) { Array($0) })

        // BODY chunk
        var body = Data()
        let wordsPerRow = width / 16
        for y in 0..<height {
            for plane in 0..<numPlanes {
                for w in 0..<wordsPerRow {
                    let word = bitplanes[y * wordsPerRow + w][plane]
                    body.append(contentsOf: withUnsafeBytes(of: word.bigEndian) { Array($0) })
                }
            }
        }

        func chunk(_ id: String, _ content: Data) -> Data {
            var c = Data(id.utf8)
            c.append(contentsOf: withUnsafeBytes(of: UInt32(content.count).bigEndian) { Array($0) })
            c.append(content)
            if content.count % 2 == 1 { c.append(0) }
            return c
        }

        var form = Data()
        form.append(Data("ILBM".utf8))
        form.append(chunk("BMHD", bmhd))
        form.append(chunk("CMAP", cmap))
        form.append(chunk("CAMG", camg))
        form.append(chunk("BODY", body))

        data.append(Data("FORM".utf8))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(form.count).bigEndian) { Array($0) })
        data.append(form)

        return data
    }

    // MARK: - Preprocessing

    private func applySaturation(_ pixels: inout [[Float]], width: Int, height: Int, saturation: Double) {
        let sat = Float(saturation)
        for i in 0..<pixels.count {
            let gray = 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2]
            pixels[i][0] = max(0, min(255, gray + (pixels[i][0] - gray) * sat))
            pixels[i][1] = max(0, min(255, gray + (pixels[i][1] - gray) * sat))
            pixels[i][2] = max(0, min(255, gray + (pixels[i][2] - gray) * sat))
        }
    }

    private func applyGamma(_ pixels: inout [[Float]], width: Int, height: Int, gamma: Double) {
        let inv = 1.0 / gamma
        for i in 0..<pixels.count {
            pixels[i][0] = Float(pow(Double(pixels[i][0]) / 255.0, inv) * 255.0)
            pixels[i][1] = Float(pow(Double(pixels[i][1]) / 255.0, inv) * 255.0)
            pixels[i][2] = Float(pow(Double(pixels[i][2]) / 255.0, inv) * 255.0)
        }
    }

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
        for i in 0..<total { histogram[Int(max(0, min(255, 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2])))] += 1 }
        var cdf = [Float](repeating: 0, count: 256)
        var cumulative = 0
        for i in 0..<256 { cumulative += histogram[i]; cdf[i] = Float(cumulative) / Float(total) * 255.0 }
        for i in 0..<total {
            let r = pixels[i][0], g = pixels[i][1], b = pixels[i][2]
            let luma = 0.299 * r + 0.587 * g + 0.114 * b
            let newLuma = cdf[Int(max(0, min(255, luma)))]
            if luma > 0.001 { let scale = newLuma / luma; pixels[i][0] = max(0, min(255, r * scale)); pixels[i][1] = max(0, min(255, g * scale)); pixels[i][2] = max(0, min(255, b * scale)) }
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
                for y in startY..<endY { for x in startX..<endX { histogram[Int(max(0, min(255, 0.299 * pixels[y * width + x][0] + 0.587 * pixels[y * width + x][1] + 0.114 * pixels[y * width + x][2])))] += 1 } }
                let clipThreshold = Int(clipLimit * Float(tilePixels) / 256.0)
                var excess = 0
                for i in 0..<256 { if histogram[i] > clipThreshold { excess += histogram[i] - clipThreshold; histogram[i] = clipThreshold } }
                for i in 0..<256 { histogram[i] += excess / 256 }
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
            for wy in startY..<endY { for wx in 0..<min(width, halfWindow + 1) { histogram[lumaBins[wy * width + wx]] += 1; windowPixels += 1 } }
            for x in 0..<width {
                if x > 0 {
                    if x + halfWindow < width { for wy in startY..<endY { histogram[lumaBins[wy * width + x + halfWindow]] += 1; windowPixels += 1 } }
                    if x - halfWindow - 1 >= 0 { for wy in startY..<endY { histogram[lumaBins[wy * width + x - halfWindow - 1]] -= 1; windowPixels -= 1 } }
                }
                let idx = y * width + x
                var cumulative = 0; for i in 0...lumaBins[idx] { cumulative += histogram[i] }
                let newLuma = Float(cumulative) / Float(windowPixels) * 255.0
                let luma = 0.299 * pixels[idx][0] + 0.587 * pixels[idx][1] + 0.114 * pixels[idx][2]
                if luma > 0.001 { let scale = newLuma / luma; result[idx][0] = max(0, min(255, pixels[idx][0] * scale)); result[idx][1] = max(0, min(255, pixels[idx][1] * scale)); result[idx][2] = max(0, min(255, pixels[idx][2] * scale)) }
            }
        }
        pixels = result
    }

    // MARK: - Image Filters

    private func applyImageFilter(_ pixels: inout [[Float]], width: Int, height: Int, filter: String) {
        let lowpassKernel: [[Float]] = [[1.0/9,1.0/9,1.0/9],[1.0/9,1.0/9,1.0/9],[1.0/9,1.0/9,1.0/9]]
        let sharpenKernel: [[Float]] = [[0,-1,0],[-1,5,-1],[0,-1,0]]
        let embossKernel: [[Float]] = [[-2,-1,0],[-1,1,1],[0,1,2]]
        switch filter {
        case "Lowpass": applyConvolution(&pixels, width: width, height: height, kernel: lowpassKernel)
        case "Sharpen": applyConvolution(&pixels, width: width, height: height, kernel: sharpenKernel)
        case "Emboss": applyConvolution(&pixels, width: width, height: height, kernel: embossKernel)
        case "Edge": applyEdgeFilter(&pixels, width: width, height: height)
        default: break
        }
    }

    private func applyConvolution(_ pixels: inout [[Float]], width: Int, height: Int, kernel: [[Float]]) {
        let kSize = kernel.count, kHalf = kSize / 2
        var result = pixels
        for y in kHalf..<(height - kHalf) {
            for x in kHalf..<(width - kHalf) {
                var sumR: Float = 0, sumG: Float = 0, sumB: Float = 0
                for ky in 0..<kSize { for kx in 0..<kSize {
                    let idx = (y + ky - kHalf) * width + (x + kx - kHalf)
                    sumR += pixels[idx][0] * kernel[ky][kx]; sumG += pixels[idx][1] * kernel[ky][kx]; sumB += pixels[idx][2] * kernel[ky][kx]
                }}
                let idx = y * width + x
                result[idx][0] = max(0, min(255, sumR)); result[idx][1] = max(0, min(255, sumG)); result[idx][2] = max(0, min(255, sumB))
            }
        }
        pixels = result
    }

    private func applyEdgeFilter(_ pixels: inout [[Float]], width: Int, height: Int) {
        let sobelX: [[Float]] = [[-1,0,1],[-2,0,2],[-1,0,1]], sobelY: [[Float]] = [[-1,-2,-1],[0,0,0],[1,2,1]]
        var result = pixels
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var gxR: Float = 0, gxG: Float = 0, gxB: Float = 0, gyR: Float = 0, gyG: Float = 0, gyB: Float = 0
                for ky in 0..<3 { for kx in 0..<3 {
                    let idx = (y + ky - 1) * width + (x + kx - 1)
                    gxR += pixels[idx][0] * sobelX[ky][kx]; gxG += pixels[idx][1] * sobelX[ky][kx]; gxB += pixels[idx][2] * sobelX[ky][kx]
                    gyR += pixels[idx][0] * sobelY[ky][kx]; gyG += pixels[idx][1] * sobelY[ky][kx]; gyB += pixels[idx][2] * sobelY[ky][kx]
                }}
                let idx = y * width + x
                result[idx][0] = max(0, min(255, (pixels[idx][0] + sqrt(gxR*gxR + gyR*gyR)) * 0.5))
                result[idx][1] = max(0, min(255, (pixels[idx][1] + sqrt(gxG*gxG + gyG*gyG)) * 0.5))
                result[idx][2] = max(0, min(255, (pixels[idx][2] + sqrt(gxB*gxB + gyB*gyB)) * 0.5))
            }
        }
        pixels = result
    }

    private func applyOrderedDither(_ pixels: inout [[Float]], width: Int, height: Int, ditherType: String, amount: Double) {
        let matrix: [[Float]]
        let size: Int
        switch ditherType {
        case "Bayer 2x2": matrix = [[0,2],[3,1]]; size = 2
        case "Bayer 4x4": matrix = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]; size = 4
        case "Bayer 8x8":
            matrix = [[0,32,8,40,2,34,10,42],[48,16,56,24,50,18,58,26],[12,44,4,36,14,46,6,38],[60,28,52,20,62,30,54,22],
                     [3,35,11,43,1,33,9,41],[51,19,59,27,49,17,57,25],[15,47,7,39,13,45,5,37],[63,31,55,23,61,29,53,21]]
            size = 8
        default: return
        }
        let maxVal = Float(size * size)
        let strength = Float(amount) * 64.0
        for y in 0..<height {
            for x in 0..<width {
                let threshold = (matrix[y % size][x % size] / maxVal - 0.5) * strength
                let idx = y * width + x
                pixels[idx][0] = max(0, min(255, pixels[idx][0] + threshold))
                pixels[idx][1] = max(0, min(255, pixels[idx][1] + threshold))
                pixels[idx][2] = max(0, min(255, pixels[idx][2] + threshold))
            }
        }
    }
}
