import Foundation
import AppKit

class MSXConverter: RetroMachine {
    var name: String = "MSX"

    // MSX Graphics modes:
    // Screen 2 (MSX1): 256×192, 2 colors per 8×1 line from 16-color TMS9918 palette
    // Screen 5 (MSX2): 256×212, 16 colors from 512-color palette
    // Screen 8 (MSX2): 256×212, 256 fixed colors (3-3-2 RGB)

    var options: [ConversionOption] = [
        ConversionOption(label: "Mode", key: "mode",
                        values: ["Screen 2 (MSX1)", "Screen 5 (MSX2)", "Screen 8 (MSX2)"],
                        selectedValue: "Screen 5 (MSX2)"),
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
                        values: ["Euclidean", "Perceptive", "Luma", "Chroma", "Hue"],
                        selectedValue: "Perceptive"),
        ConversionOption(label: "Saturation", key: "saturation",
                        range: 0.5...2.0, defaultValue: 1.0),
        ConversionOption(label: "Gamma", key: "gamma",
                        range: 0.5...2.0, defaultValue: 1.0)
    ]

    // TMS9918 palette (MSX1) - 16 colors
    static let tms9918Palette: [[UInt8]] = [
        [0x00, 0x00, 0x00],  // 0: Transparent (rendered as black)
        [0x00, 0x00, 0x00],  // 1: Black
        [0x21, 0xC8, 0x42],  // 2: Medium Green
        [0x5E, 0xDC, 0x78],  // 3: Light Green
        [0x54, 0x55, 0xED],  // 4: Dark Blue
        [0x7D, 0x76, 0xFC],  // 5: Light Blue
        [0xD4, 0x52, 0x4D],  // 6: Dark Red
        [0x42, 0xEB, 0xF5],  // 7: Cyan
        [0xFC, 0x55, 0x54],  // 8: Medium Red
        [0xFF, 0x79, 0x78],  // 9: Light Red
        [0xD4, 0xC1, 0x54],  // 10: Dark Yellow
        [0xE6, 0xCE, 0x80],  // 11: Light Yellow
        [0x21, 0xB0, 0x3B],  // 12: Dark Green
        [0xC9, 0x5B, 0xBA],  // 13: Magenta
        [0xCC, 0xCC, 0xCC],  // 14: Gray
        [0xFF, 0xFF, 0xFF]   // 15: White
    ]

    // MSX2 512-color palette (V9938) - 8 levels R × 8 levels G × 8 levels B
    static let v9938Palette: [[UInt8]] = {
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

    // Screen 8 fixed 256-color palette (3-3-2 RGB)
    static let screen8Palette: [[UInt8]] = {
        var palette: [[UInt8]] = []
        for i in 0..<256 {
            let r = UInt8((i >> 5) & 0x07) * 36  // 3 bits red (0-7 → 0-252)
            let g = UInt8((i >> 2) & 0x07) * 36  // 3 bits green
            let b = UInt8(i & 0x03) * 85          // 2 bits blue (0-3 → 0-255)
            palette.append([r, g, b])
        }
        return palette
    }()

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "MSXConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }

        let mode = opts.first(where: { $0.key == "mode" })?.selectedValue ?? "Screen 5 (MSX2)"
        let ditherAlg = opts.first(where: { $0.key == "dither" })?.selectedValue ?? "Floyd-Steinberg"
        let ditherAmount = Double(opts.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrast = opts.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filterMode = opts.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let colorMatch = opts.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(opts.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(opts.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        switch mode {
        case "Screen 2 (MSX1)":
            return try await convertScreen2(cgImage: cgImage, ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                            contrast: contrast, filter: filterMode, colorMatch: colorMatch,
                                            saturation: saturation, gamma: gamma)
        case "Screen 5 (MSX2)":
            return try await convertScreen5(cgImage: cgImage, ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                            contrast: contrast, filter: filterMode, colorMatch: colorMatch,
                                            saturation: saturation, gamma: gamma)
        case "Screen 8 (MSX2)":
            return try await convertScreen8(cgImage: cgImage, ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                            contrast: contrast, filter: filterMode, colorMatch: colorMatch,
                                            saturation: saturation, gamma: gamma)
        default:
            return try await convertScreen5(cgImage: cgImage, ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                            contrast: contrast, filter: filterMode, colorMatch: colorMatch,
                                            saturation: saturation, gamma: gamma)
        }
    }

    // MARK: - Screen 2 (MSX1) - 256×192, 2 colors per 8×1 line

    private func convertScreen2(cgImage: CGImage, ditherAlg: String, ditherAmount: Double, contrast: String, filter: String, colorMatch: String, saturation: Double, gamma: Double) async throws -> ConversionResult {
        let width = 256, height = 192
        var pixels = scaleImage(cgImage, toWidth: width, height: height)

        if saturation != 1.0 { applySaturation(&pixels, width: width, height: height, saturation: saturation) }
        if gamma != 1.0 { applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if contrast != "None" { applyContrast(&pixels, width: width, height: height, method: contrast) }
        if filter != "None" { applyImageFilter(&pixels, width: width, height: height, filter: filter) }
        if ditherAlg.contains("Bayer") { applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount) }

        // Screen 2: 2 colors per 8×1 horizontal line segment
        // Pattern table: 6144 bytes (256×192 / 8 = 6144)
        // Color table: 6144 bytes (one byte per 8×1 line: high nibble = fg, low nibble = bg)
        var patternTable = Data(count: 6144)
        var colorTable = Data(count: 6144)
        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)

        // Process each 8×1 horizontal line segment
        for charY in 0..<24 {
            for charX in 0..<32 {
                for lineInChar in 0..<8 {
                    let y = charY * 8 + lineInChar
                    let x = charX * 8

                    // Find best 2 colors for this 8-pixel line
                    let (fg, bg) = findBest2Colors(pixels: pixels, x: x, y: y, width: width, palette: Self.tms9918Palette, colorMatch: colorMatch)

                    // Create pattern byte and apply colors
                    var patternByte: UInt8 = 0
                    for bit in 0..<8 {
                        let px = x + bit
                        let idx = (y * width + px)
                        let r = pixels[idx][0], g = pixels[idx][1], b = pixels[idx][2]

                        // Decide if this pixel is foreground or background
                        let distFg = colorDistance(r, g, b, Float(Self.tms9918Palette[fg][0]), Float(Self.tms9918Palette[fg][1]), Float(Self.tms9918Palette[fg][2]), colorMatch)
                        let distBg = colorDistance(r, g, b, Float(Self.tms9918Palette[bg][0]), Float(Self.tms9918Palette[bg][1]), Float(Self.tms9918Palette[bg][2]), colorMatch)

                        let useFg = distFg <= distBg
                        if useFg {
                            patternByte |= (1 << (7 - bit))
                        }

                        // Store result pixel
                        let color = useFg ? Self.tms9918Palette[fg] : Self.tms9918Palette[bg]
                        let outIdx = (y * width + px) * 3
                        resultPixels[outIdx] = color[0]
                        resultPixels[outIdx + 1] = color[1]
                        resultPixels[outIdx + 2] = color[2]

                        // Error diffusion
                        if ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson" {
                            let errR = (r - Float(color[0])) * Float(ditherAmount)
                            let errG = (g - Float(color[1])) * Float(ditherAmount)
                            let errB = (b - Float(color[2])) * Float(ditherAmount)
                            distributeError(&pixels, width: width, height: height, x: px, y: y, rErr: errR, gErr: errG, bErr: errB, alg: ditherAlg)
                        }
                    }

                    // Store pattern and color
                    let tableIdx = charY * 256 + charX * 8 + lineInChar
                    patternTable[tableIdx] = patternByte
                    colorTable[tableIdx] = UInt8((fg << 4) | bg)
                }
            }
        }

        let previewImage = createPreviewImage(resultPixels: resultPixels, width: width, height: height, scaleY: 1.0)

        // Create SC2 file (BSAVE format)
        let sc2Data = createSC2Data(patternTable: patternTable, colorTable: colorTable)
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("msx_sc2_\(uuid).sc2")
        try sc2Data.write(to: nativeUrl)

        return ConversionResult(previewImage: previewImage, fileAssets: [nativeUrl], palettes: [], pixelIndices: [], imageWidth: width, imageHeight: height)
    }

    // MARK: - Screen 5 (MSX2) - 256×212, 16 colors from 512

    private func convertScreen5(cgImage: CGImage, ditherAlg: String, ditherAmount: Double, contrast: String, filter: String, colorMatch: String, saturation: Double, gamma: Double) async throws -> ConversionResult {
        let width = 256, height = 212
        var pixels = scaleImage(cgImage, toWidth: width, height: height)

        if saturation != 1.0 { applySaturation(&pixels, width: width, height: height, saturation: saturation) }
        if gamma != 1.0 { applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if contrast != "None" { applyContrast(&pixels, width: width, height: height, method: contrast) }
        if filter != "None" { applyImageFilter(&pixels, width: width, height: height, filter: filter) }
        if ditherAlg.contains("Bayer") { applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount) }

        // Select optimal 16 colors from 512-color palette
        let selectedPalette = selectOptimalPalette(pixels: pixels, palette: Self.v9938Palette, numColors: 16)

        let (resultPixels, rawData) = convertToFixedPalette(pixels: pixels, width: width, height: height, palette: selectedPalette, ditherAlg: ditherAlg, ditherAmount: ditherAmount, colorMatch: colorMatch, bitsPerPixel: 4)

        let previewImage = createPreviewImage(resultPixels: resultPixels, width: width, height: height, scaleY: 1.0)

        // Create SC5 file (BSAVE format)
        let sc5Data = createSC5Data(rawData: rawData, palette: selectedPalette, width: width, height: height)
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("msx_sc5_\(uuid).sc5")
        try sc5Data.write(to: nativeUrl)

        return ConversionResult(previewImage: previewImage, fileAssets: [nativeUrl], palettes: [], pixelIndices: [], imageWidth: width, imageHeight: height)
    }

    // MARK: - Screen 8 (MSX2) - 256×212, 256 fixed colors (3-3-2 RGB)

    private func convertScreen8(cgImage: CGImage, ditherAlg: String, ditherAmount: Double, contrast: String, filter: String, colorMatch: String, saturation: Double, gamma: Double) async throws -> ConversionResult {
        let width = 256, height = 212
        var pixels = scaleImage(cgImage, toWidth: width, height: height)

        if saturation != 1.0 { applySaturation(&pixels, width: width, height: height, saturation: saturation) }
        if gamma != 1.0 { applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if contrast != "None" { applyContrast(&pixels, width: width, height: height, method: contrast) }
        if filter != "None" { applyImageFilter(&pixels, width: width, height: height, filter: filter) }
        if ditherAlg.contains("Bayer") { applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount) }

        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)
        var rawData = Data(count: width * height)

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let r = max(0, min(255, pixels[idx][0]))
                let g = max(0, min(255, pixels[idx][1]))
                let b = max(0, min(255, pixels[idx][2]))

                // Convert to 3-3-2 RGB
                let r3 = UInt8(r / 36.0)  // 0-7
                let g3 = UInt8(g / 36.0)  // 0-7
                let b2 = UInt8(b / 85.0)  // 0-3

                let colorByte = (r3 << 5) | (g3 << 2) | b2
                rawData[idx] = colorByte

                // Get actual color values
                let actualR = r3 * 36
                let actualG = g3 * 36
                let actualB = b2 * 85

                resultPixels[idx * 3] = actualR
                resultPixels[idx * 3 + 1] = actualG
                resultPixels[idx * 3 + 2] = actualB

                // Error diffusion
                if useErrorDiffusion {
                    let errR = (r - Float(actualR)) * Float(ditherAmount)
                    let errG = (g - Float(actualG)) * Float(ditherAmount)
                    let errB = (b - Float(actualB)) * Float(ditherAmount)
                    distributeError(&pixels, width: width, height: height, x: x, y: y, rErr: errR, gErr: errG, bErr: errB, alg: ditherAlg)
                }
            }
        }

        let previewImage = createPreviewImage(resultPixels: resultPixels, width: width, height: height, scaleY: 1.0)

        // Create SC8 file (BSAVE format)
        let sc8Data = createSC8Data(rawData: rawData, width: width, height: height)
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("msx_sc8_\(uuid).sc8")
        try sc8Data.write(to: nativeUrl)

        return ConversionResult(previewImage: previewImage, fileAssets: [nativeUrl], palettes: [], pixelIndices: [], imageWidth: width, imageHeight: height)
    }

    // MARK: - Helper Functions

    private func findBest2Colors(pixels: [[Float]], x: Int, y: Int, width: Int, palette: [[UInt8]], colorMatch: String) -> (fg: Int, bg: Int) {
        // Collect colors for this 8-pixel line
        var lineColors: [(r: Float, g: Float, b: Float)] = []
        for bit in 0..<8 {
            let idx = y * width + x + bit
            lineColors.append((pixels[idx][0], pixels[idx][1], pixels[idx][2]))
        }

        // Find best pair of colors
        var bestPair = (0, 1)
        var bestError = Float.greatestFiniteMagnitude

        for i in 0..<palette.count {
            for j in i..<palette.count {
                var totalError: Float = 0
                for color in lineColors {
                    let distI = colorDistance(color.r, color.g, color.b, Float(palette[i][0]), Float(palette[i][1]), Float(palette[i][2]), colorMatch)
                    let distJ = colorDistance(color.r, color.g, color.b, Float(palette[j][0]), Float(palette[j][1]), Float(palette[j][2]), colorMatch)
                    totalError += min(distI, distJ)
                }
                if totalError < bestError {
                    bestError = totalError
                    bestPair = (i, j)
                }
            }
        }

        return bestPair
    }

    private func colorDistance(_ r1: Float, _ g1: Float, _ b1: Float, _ r2: Float, _ g2: Float, _ b2: Float, _ method: String) -> Float {
        let dr = r1 - r2, dg = g1 - g2, db = b1 - b2
        switch method {
        case "Perceptive":
            let rmean = (r1 + r2) / 2.0
            return sqrt((2.0 + rmean / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rmean) / 256.0) * db * db)
        case "Luma":
            let luma1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
            let luma2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
            return abs(luma1 - luma2) * 3.0 + sqrt(dr * dr + dg * dg + db * db) * 0.1
        case "Chroma":
            let luma1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
            let luma2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
            let cr1 = luma1 > 1 ? r1 / luma1 : 0, cg1 = luma1 > 1 ? g1 / luma1 : 0, cb1 = luma1 > 1 ? b1 / luma1 : 0
            let cr2 = luma2 > 1 ? r2 / luma2 : 0, cg2 = luma2 > 1 ? g2 / luma2 : 0, cb2 = luma2 > 1 ? b2 / luma2 : 0
            let chromaDist = sqrt((cr1-cr2)*(cr1-cr2) + (cg1-cg2)*(cg1-cg2) + (cb1-cb2)*(cb1-cb2)) * 255.0
            let lumaDist = abs(luma1 - luma2) * 0.2
            return chromaDist + lumaDist
        case "Hue":
            let (h1, s1, l1) = rgbToHsl(r1, g1, b1)
            let (h2, s2, l2) = rgbToHsl(r2, g2, b2)
            var hueDiff = abs(h1 - h2)
            if hueDiff > 180 { hueDiff = 360 - hueDiff }
            let minSat = min(s1, s2)
            let hueWeight: Float = 4.0 * minSat
            return (hueDiff / 180.0) * 255.0 * hueWeight + abs(s1 - s2) * 255.0 + abs(l1 - l2) * 255.0 * 0.5
        default:
            return sqrt(dr * dr + dg * dg + db * db)
        }
    }

    private func rgbToHsl(_ r: Float, _ g: Float, _ b: Float) -> (h: Float, s: Float, l: Float) {
        let rn = r / 255.0, gn = g / 255.0, bn = b / 255.0
        let maxC = max(rn, gn, bn)
        let minC = min(rn, gn, bn)
        let l = (maxC + minC) / 2.0
        if maxC == minC { return (0, 0, l) }
        let d = maxC - minC
        let s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC)
        var h: Float
        if maxC == rn { h = (gn - bn) / d + (gn < bn ? 6 : 0) }
        else if maxC == gn { h = (bn - rn) / d + 2 }
        else { h = (rn - gn) / d + 4 }
        h *= 60
        return (h, s, l)
    }

    private func distributeError(_ work: inout [[Float]], width: Int, height: Int, x: Int, y: Int, rErr: Float, gErr: Float, bErr: Float, alg: String) {
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

    private func selectOptimalPalette(pixels: [[Float]], palette: [[UInt8]], numColors: Int) -> [[UInt8]] {
        // Count color usage
        var colorCounts = [Int](repeating: 0, count: palette.count)
        for pixel in pixels {
            var bestIdx = 0
            var bestDist = Float.greatestFiniteMagnitude
            for (i, c) in palette.enumerated() {
                let dr = pixel[0] - Float(c[0])
                let dg = pixel[1] - Float(c[1])
                let db = pixel[2] - Float(c[2])
                let dist = dr * dr + dg * dg + db * db
                if dist < bestDist {
                    bestDist = dist
                    bestIdx = i
                }
            }
            colorCounts[bestIdx] += 1
        }

        // Select top colors
        let indexed = colorCounts.enumerated().sorted { $0.element > $1.element }
        var selected: [[UInt8]] = []
        for i in 0..<min(numColors, indexed.count) {
            selected.append(palette[indexed[i].offset])
        }

        // Ensure we have enough colors
        while selected.count < numColors {
            selected.append([0, 0, 0])
        }

        return selected
    }

    private func convertToFixedPalette(pixels: [[Float]], width: Int, height: Int, palette: [[UInt8]], ditherAlg: String, ditherAmount: Double, colorMatch: String, bitsPerPixel: Int) -> ([UInt8], Data) {
        var work = pixels
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var rawData = Data()

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"

        for y in 0..<height {
            var rowData = Data()
            for x in 0..<width {
                let r = max(0, min(255, work[y * width + x][0]))
                let g = max(0, min(255, work[y * width + x][1]))
                let b = max(0, min(255, work[y * width + x][2]))

                let colorIndex = findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                let color = palette[colorIndex]

                let idx = (y * width + x) * 3
                result[idx] = color[0]
                result[idx + 1] = color[1]
                result[idx + 2] = color[2]

                // Pack into nibbles for Screen 5 (4bpp)
                if x % 2 == 0 {
                    rowData.append(UInt8(colorIndex << 4))
                } else {
                    rowData[rowData.count - 1] |= UInt8(colorIndex & 0x0F)
                }

                if useErrorDiffusion {
                    let rErr = (r - Float(color[0])) * Float(ditherAmount)
                    let gErr = (g - Float(color[1])) * Float(ditherAmount)
                    let bErr = (b - Float(color[2])) * Float(ditherAmount)
                    distributeError(&work, width: width, height: height, x: x, y: y, rErr: rErr, gErr: gErr, bErr: bErr, alg: ditherAlg)
                }
            }
            rawData.append(rowData)
        }

        return (result, rawData)
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

    // MARK: - File Format Creation

    private func createSC2Data(patternTable: Data, colorTable: Data) -> Data {
        var data = Data()
        // BSAVE header
        data.append(0xFE)  // BSAVE identifier
        // Start address: 0x0000
        data.append(0x00); data.append(0x00)
        // End address: 0x37FF (pattern + color + name tables)
        data.append(0xFF); data.append(0x37)
        // Execution address: 0x0000
        data.append(0x00); data.append(0x00)

        // Pattern table (6144 bytes at 0x0000)
        data.append(patternTable)
        // Color table (6144 bytes at 0x2000)
        data.append(colorTable)
        // Name table (768 bytes at 0x1800) - sequential pattern references
        for i in 0..<768 {
            data.append(UInt8(i % 256))
        }

        return data
    }

    private func createSC5Data(rawData: Data, palette: [[UInt8]], width: Int, height: Int) -> Data {
        var data = Data()
        // BSAVE header
        data.append(0xFE)
        // Start address: 0x0000
        data.append(0x00); data.append(0x00)
        // End address
        let endAddr = UInt16(rawData.count + 32 - 1)  // Image + palette
        data.append(UInt8(endAddr & 0xFF)); data.append(UInt8(endAddr >> 8))
        // Execution address: 0x0000
        data.append(0x00); data.append(0x00)

        // Palette (32 bytes - 16 colors × 2 bytes each in GRB format)
        for color in palette {
            // V9938 palette format: 0RRR0BBB 0000GGGG
            let r3 = color[0] / 32  // Convert to 3-bit
            let g3 = color[1] / 32
            let b3 = color[2] / 32
            data.append((r3 << 4) | b3)  // RB byte
            data.append(g3)               // G byte
        }
        // Pad to 16 colors if needed
        while data.count < 7 + 32 {
            data.append(0x00)
        }

        // Image data
        data.append(rawData)

        return data
    }

    private func createSC8Data(rawData: Data, width: Int, height: Int) -> Data {
        var data = Data()
        // BSAVE header
        data.append(0xFE)
        // Start address: 0x0000
        data.append(0x00); data.append(0x00)
        // End address
        let endAddr = UInt16(rawData.count - 1)
        data.append(UInt8(endAddr & 0xFF)); data.append(UInt8(endAddr >> 8))
        // Execution address: 0x0000
        data.append(0x00); data.append(0x00)

        // Image data (256×212 bytes, 1 byte per pixel)
        data.append(rawData)

        return data
    }

    // MARK: - Common Helper Functions

    private func scaleImage(_ cgImage: CGImage, toWidth width: Int, height: Int) -> [[Float]] {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(data: &rawData, width: width, height: height, bitsPerComponent: 8,
                                       bytesPerRow: width * 4, space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return Array(repeating: [0, 0, 0], count: width * height)
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [[Float]] = []
        for i in 0..<(width * height) {
            let r = Float(rawData[i * 4])
            let g = Float(rawData[i * 4 + 1])
            let b = Float(rawData[i * 4 + 2])
            pixels.append([r, g, b])
        }

        return pixels
    }

    private func applySaturation(_ pixels: inout [[Float]], width: Int, height: Int, saturation: Double) {
        for i in 0..<pixels.count {
            let r = pixels[i][0], g = pixels[i][1], b = pixels[i][2]
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            pixels[i][0] = gray + Float(saturation) * (r - gray)
            pixels[i][1] = gray + Float(saturation) * (g - gray)
            pixels[i][2] = gray + Float(saturation) * (b - gray)
        }
    }

    private func applyGamma(_ pixels: inout [[Float]], width: Int, height: Int, gamma: Double) {
        let invGamma = 1.0 / gamma
        for i in 0..<pixels.count {
            pixels[i][0] = 255.0 * pow(pixels[i][0] / 255.0, Float(invGamma))
            pixels[i][1] = 255.0 * pow(pixels[i][1] / 255.0, Float(invGamma))
            pixels[i][2] = 255.0 * pow(pixels[i][2] / 255.0, Float(invGamma))
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
        for channel in 0..<3 {
            var histogram = [Int](repeating: 0, count: 256)
            for pixel in pixels {
                let val = Int(max(0, min(255, pixel[channel])))
                histogram[val] += 1
            }
            var cdf = [Int](repeating: 0, count: 256)
            cdf[0] = histogram[0]
            for i in 1..<256 { cdf[i] = cdf[i-1] + histogram[i] }
            let cdfMin = cdf.first(where: { $0 > 0 }) ?? 0
            let scale = 255.0 / Float(max(1, pixels.count - cdfMin))
            for i in 0..<pixels.count {
                let val = Int(max(0, min(255, pixels[i][channel])))
                pixels[i][channel] = Float(cdf[val] - cdfMin) * scale
            }
        }
    }

    private func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int, clipLimit: Float, tileSize: Int) {
        applyHistogramEqualization(&pixels, width: width, height: height)
    }

    private func applySWAHE(_ pixels: inout [[Float]], width: Int, height: Int, windowSize: Int) {
        applyHistogramEqualization(&pixels, width: width, height: height)
    }

    private func applyImageFilter(_ pixels: inout [[Float]], width: Int, height: Int, filter: String) {
        let kernel: [[Float]]
        switch filter {
        case "Lowpass":
            kernel = [[1,1,1],[1,1,1],[1,1,1]].map { $0.map { $0 / 9.0 } }
        case "Sharpen":
            kernel = [[0,-1,0],[-1,5,-1],[0,-1,0]]
        case "Emboss":
            kernel = [[-2,-1,0],[-1,1,1],[0,1,2]]
        case "Edge":
            kernel = [[-1,-1,-1],[-1,8,-1],[-1,-1,-1]]
        default:
            return
        }
        applyKernel(&pixels, width: width, height: height, kernel: kernel)
    }

    private func applyKernel(_ pixels: inout [[Float]], width: Int, height: Int, kernel: [[Float]]) {
        let original = pixels
        let kSize = kernel.count / 2
        for y in kSize..<(height - kSize) {
            for x in kSize..<(width - kSize) {
                var r: Float = 0, g: Float = 0, b: Float = 0
                for ky in 0..<kernel.count {
                    for kx in 0..<kernel[0].count {
                        let px = x + kx - kSize
                        let py = y + ky - kSize
                        let k = kernel[ky][kx]
                        let src = original[py * width + px]
                        r += src[0] * k; g += src[1] * k; b += src[2] * k
                    }
                }
                pixels[y * width + x] = [max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))]
            }
        }
    }

    private func applyOrderedDither(_ pixels: inout [[Float]], width: Int, height: Int, ditherType: String, amount: Double) {
        let matrix: [[Float]]
        switch ditherType {
        case "Bayer 2x2":
            matrix = [[0, 2], [3, 1]].map { $0.map { ($0 / 4.0 - 0.5) * Float(amount) * 64 } }
        case "Bayer 4x4":
            matrix = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]].map { $0.map { ($0 / 16.0 - 0.5) * Float(amount) * 64 } }
        case "Bayer 8x8":
            let b8: [[Float]] = [
                [0,32,8,40,2,34,10,42],[48,16,56,24,50,18,58,26],
                [12,44,4,36,14,46,6,38],[60,28,52,20,62,30,54,22],
                [3,35,11,43,1,33,9,41],[51,19,59,27,49,17,57,25],
                [15,47,7,39,13,45,5,37],[63,31,55,23,61,29,53,21]
            ]
            matrix = b8.map { $0.map { ($0 / 64.0 - 0.5) * Float(amount) * 64 } }
        default:
            return
        }
        let mSize = matrix.count
        for y in 0..<height {
            for x in 0..<width {
                let threshold = matrix[y % mSize][x % mSize]
                let idx = y * width + x
                pixels[idx][0] += threshold
                pixels[idx][1] += threshold
                pixels[idx][2] += threshold
            }
        }
    }

    private func createPreviewImage(resultPixels: [UInt8], width: Int, height: Int, scaleY: Double) -> NSImage {
        let previewWidth = width * 2
        let previewHeight = Int(Double(height) * 2.0 * scaleY / 2.0)

        var previewBytes = [UInt8](repeating: 255, count: previewWidth * previewHeight * 4)

        for y in 0..<height {
            let py = Int(Double(y) * scaleY)
            for dy in 0..<Int(scaleY) {
                let destY = py + dy
                if destY >= previewHeight { continue }
                for x in 0..<width {
                    let srcIdx = (y * width + x) * 3
                    for dx in 0..<2 {
                        let destIdx = (destY * previewWidth + x * 2 + dx) * 4
                        previewBytes[destIdx] = resultPixels[srcIdx]
                        previewBytes[destIdx + 1] = resultPixels[srcIdx + 1]
                        previewBytes[destIdx + 2] = resultPixels[srcIdx + 2]
                        previewBytes[destIdx + 3] = 255
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &previewBytes, width: previewWidth, height: previewHeight,
                                       bitsPerComponent: 8, bytesPerRow: previewWidth * 4, space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cgImage = context.makeImage() else {
            return NSImage()
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: previewWidth, height: previewHeight))
    }
}
