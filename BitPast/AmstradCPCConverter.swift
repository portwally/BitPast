import Cocoa

class AmstradCPCConverter: RetroMachine {
    var name: String = "Amstrad CPC"

    var options: [ConversionOption] = [
        // 1. GRAPHICS MODE
        ConversionOption(
            label: "Graphics Mode",
            key: "mode",
            values: ["Mode 1 (320×200, 4 colors)", "Mode 0 (160×200, 16 colors)"],
            selectedValue: "Mode 1 (320×200, 4 colors)"
        ),

        // 2. DITHERING ALGORITHM
        ConversionOption(
            label: "Dithering",
            key: "dither",
            values: [
                "None",
                "Floyd-Steinberg",
                "Atkinson",
                "Noise",
                "Bayer 2x2",
                "Bayer 4x4",
                "Bayer 8x8",
                "Bayer 16x16",
                "Blue 8x8",
                "Blue 16x16"
            ],
            selectedValue: "Bayer 2x2"
        ),

        // 3. DITHER AMOUNT
        ConversionOption(
            label: "Dither Amount",
            key: "dither_amount",
            range: 0.0...1.0,
            defaultValue: 0.5
        ),

        // 4. CONTRAST PROCESSING
        ConversionOption(
            label: "Contrast",
            key: "contrast",
            values: ["None", "HE", "CLAHE", "SWAHE"],
            selectedValue: "None"
        ),

        // 5. IMAGE FILTER
        ConversionOption(
            label: "Filter",
            key: "filter",
            values: ["None", "Lowpass", "Sharpen", "Emboss", "Edge"],
            selectedValue: "None"
        ),

        // 6. PIXEL MERGE (for Mode 0)
        ConversionOption(
            label: "Pixel Merge",
            key: "pixel_merge",
            values: ["Average", "Brightest"],
            selectedValue: "Average"
        ),

        // 7. COLOR MATCHING
        ConversionOption(
            label: "Color Match",
            key: "color_match",
            values: ["Euclidean", "Perceptive", "Luma", "Chroma", "Mahalanobis"],
            selectedValue: "Perceptive"
        ),

        // 8. SATURATION
        ConversionOption(
            label: "Saturation",
            key: "saturation",
            range: 0.0...2.0,
            defaultValue: 1.0
        ),

        // 9. GAMMA
        ConversionOption(
            label: "Gamma",
            key: "gamma",
            range: 0.5...2.0,
            defaultValue: 1.0
        )
    ]

    // Amstrad CPC 27-color hardware palette (from CPCRenderer.java)
    // Format: 0xRRGGBB stored as BGR in Java code
    static let cpcPalette: [[UInt8]] = [
        [0x01, 0x02, 0x00],  // 0: Black
        [0x6B, 0x02, 0x00],  // 1: Blue
        [0xF4, 0x02, 0x0C],  // 2: Bright Blue
        [0x01, 0x02, 0x6C],  // 3: Red
        [0x68, 0x02, 0x69],  // 4: Magenta
        [0xF2, 0x02, 0x6C],  // 5: Mauve
        [0x06, 0x05, 0xF3],  // 6: Bright Red
        [0x68, 0x02, 0xF0],  // 7: Purple
        [0xF4, 0x02, 0xF3],  // 8: Bright Magenta
        [0x01, 0x78, 0x02],  // 9: Green
        [0x68, 0x78, 0x00],  // 10: Cyan
        [0xF4, 0x7B, 0x0C],  // 11: Sky Blue
        [0x01, 0x7B, 0x6E],  // 12: Yellow
        [0x6B, 0x7D, 0x6E],  // 13: White
        [0xF6, 0x7B, 0x6E],  // 14: Pastel Blue
        [0x0D, 0x7D, 0xF3],  // 15: Orange
        [0x6B, 0x7D, 0xF3],  // 16: Pink
        [0xF9, 0x80, 0xFA],  // 17: Pastel Magenta
        [0x01, 0xF0, 0x02],  // 18: Bright Green
        [0x6B, 0xF3, 0x00],  // 19: Sea Green
        [0xF2, 0xF3, 0x0F],  // 20: Bright Cyan
        [0x04, 0xF5, 0x71],  // 21: Lime
        [0x6B, 0xF3, 0x71],  // 22: Pastel Green
        [0xF4, 0xF3, 0x71],  // 23: Pastel Cyan
        [0x0D, 0xF3, 0xF3],  // 24: Bright Yellow
        [0x6D, 0xF3, 0xF3],  // 25: Pastel Yellow
        [0xF9, 0xF3, 0xFF]   // 26: Bright White
    ]

    // Firmware color mapping for palette file
    static let colorMapping: [UInt8] = [
        0x54, 0x44, 0x55, 0x5C, 0x58, 0x5D, 0x4C, 0x45, 0x4D,
        0x56, 0x46, 0x57, 0x5E, 0x40, 0x5F, 0x4E, 0x47, 0x4F,
        0x52, 0x42, 0x53, 0x5A, 0x59, 0x5B, 0x4A, 0x43, 0x4B
    ]

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        try validateSourceImage(sourceImage)
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        let mode = opts.first(where: { $0.key == "mode" })?.selectedValue ?? "Mode 1 (320×200, 4 colors)"
        let ditherAlg = opts.first(where: { $0.key == "dither" })?.selectedValue ?? "Bayer 2x2"
        let ditherAmount = Double(opts.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrastMode = opts.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filterMode = opts.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let pixelMerge = opts.first(where: { $0.key == "pixel_merge" })?.selectedValue ?? "Average"
        let colorMatch = opts.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(opts.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(opts.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        let isMode0 = mode.contains("Mode 0")
        let screenWidth = 320
        let screenHeight = 200

        // Get pixel data at screen resolution
        guard var pixels = getPixelData(from: sourceImage, width: screenWidth, height: screenHeight) else {
            throw NSError(domain: "AmstradCPCConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get pixel data"])
        }

        // Apply saturation
        if saturation != 1.0 {
            applySaturation(&pixels, width: screenWidth, height: screenHeight, factor: saturation)
        }

        // Apply gamma
        if gamma != 1.0 {
            applyGamma(&pixels, width: screenWidth, height: screenHeight, gamma: gamma)
        }

        // Apply contrast enhancement
        if contrastMode != "None" {
            applyContrast(&pixels, width: screenWidth, height: screenHeight, mode: contrastMode)
        }

        // Apply filter
        if filterMode != "None" {
            applyFilter(&pixels, width: screenWidth, height: screenHeight, filter: filterMode)
        }

        // Apply ordered dithering before color quantization
        if ditherAlg.contains("Bayer") || ditherAlg.contains("Blue") || ditherAlg == "Noise" {
            applyOrderedDither(&pixels, width: screenWidth, height: screenHeight, ditherType: ditherAlg, amount: ditherAmount)
        }

        // Select optimal palette colors from hardware palette
        let numColors = isMode0 ? 16 : 4
        let selectedPalette = selectOptimalPalette(from: pixels, width: screenWidth, height: screenHeight, numColors: numColors)

        // Convert based on mode
        var resultPixels: [UInt8]
        var nativeData: Data

        if isMode0 {
            (resultPixels, nativeData) = convertMode0(pixels: pixels, width: screenWidth, height: screenHeight,
                                                       palette: selectedPalette, pixelMerge: pixelMerge,
                                                       colorMatch: colorMatch, ditherAlg: ditherAlg, ditherAmount: ditherAmount)
        } else {
            (resultPixels, nativeData) = convertMode1(pixels: pixels, width: screenWidth, height: screenHeight,
                                                       palette: selectedPalette, colorMatch: colorMatch,
                                                       ditherAlg: ditherAlg, ditherAmount: ditherAmount)
        }

        // Create preview image
        let previewImage = createPreviewImage(from: resultPixels, width: screenWidth, height: screenHeight)

        guard let preview = previewImage else {
            throw NSError(domain: "AmstradCPCConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview"])
        }

        // Save native file
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("cpc_\(uuid).scr")
        try nativeData.write(to: nativeUrl)

        return ConversionResult(
            previewImage: preview,
            fileAssets: [nativeUrl],
            palettes: [],
            pixelIndices: [],
            imageWidth: screenWidth,
            imageHeight: screenHeight
        )
    }

    // MARK: - Palette Selection

    private func selectOptimalPalette(from pixels: [[Float]], width: Int, height: Int, numColors: Int) -> [(index: Int, color: [UInt8])] {
        // Count color occurrences in the image
        var colorCounts: [Int: Int] = [:]

        for y in 0..<height {
            for x in 0..<width {
                let r = pixels[y * width + x][0]
                let g = pixels[y * width + x][1]
                let b = pixels[y * width + x][2]

                // Find closest palette color
                var bestIndex = 0
                var bestDist = Float.greatestFiniteMagnitude

                for i in 0..<Self.cpcPalette.count {
                    let pr = Float(Self.cpcPalette[i][0])
                    let pg = Float(Self.cpcPalette[i][1])
                    let pb = Float(Self.cpcPalette[i][2])

                    let dist = (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb)
                    if dist < bestDist {
                        bestDist = dist
                        bestIndex = i
                    }
                }

                colorCounts[bestIndex, default: 0] += 1
            }
        }

        // Sort by frequency and take top colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        var selectedColors: [(index: Int, color: [UInt8])] = []

        for (index, _) in sortedColors.prefix(numColors) {
            selectedColors.append((index: index, color: Self.cpcPalette[index]))
        }

        // Pad with remaining colors if needed
        while selectedColors.count < numColors {
            for i in 0..<Self.cpcPalette.count {
                if !selectedColors.contains(where: { $0.index == i }) {
                    selectedColors.append((index: i, color: Self.cpcPalette[i]))
                    break
                }
            }
        }

        return selectedColors
    }

    // MARK: - Mode 1 Conversion (320×200, 4 colors)

    private func convertMode1(pixels: [[Float]], width: Int, height: Int,
                              palette: [(index: Int, color: [UInt8])],
                              colorMatch: String, ditherAlg: String, ditherAmount: Double) -> ([UInt8], Data) {
        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)
        var bitmap = [UInt8](repeating: 0, count: 16384)
        var work = pixels.map { $0.map { Int($0) } }

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"

        for y in 0..<height {
            // CPC interleaved memory layout
            let i = y >> 3
            let j = y & 7
            let offset = i * 80 + j * 2048

            for x in 0..<width {
                let r = max(0, min(255, work[y * width + x][0]))
                let g = max(0, min(255, work[y * width + x][1]))
                let b = max(0, min(255, work[y * width + x][2]))

                // Find closest color in selected palette
                let colorIndex = findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)

                let pr = Int(palette[colorIndex].color[0])
                let pg = Int(palette[colorIndex].color[1])
                let pb = Int(palette[colorIndex].color[2])

                // Store result
                let pixelOffset = (y * width + x) * 3
                resultPixels[pixelOffset] = UInt8(pr)
                resultPixels[pixelOffset + 1] = UInt8(pg)
                resultPixels[pixelOffset + 2] = UInt8(pb)

                // Pack into bitmap (4 pixels per byte, bits interleaved)
                // Mode 1 bit pattern: pixel 0 uses bits 7,3; pixel 1 uses bits 6,2; etc.
                let byteIndex = offset + (x / 4)
                let pixelInByte = x % 4

                if colorIndex & 1 != 0 {
                    bitmap[byteIndex] |= UInt8(0x80 >> pixelInByte)
                }
                if colorIndex & 2 != 0 {
                    bitmap[byteIndex] |= UInt8(0x08 >> pixelInByte)
                }

                // Error diffusion
                if useErrorDiffusion {
                    let rErr = r - pr
                    let gErr = g - pg
                    let bErr = b - pb

                    if ditherAlg == "Floyd-Steinberg" {
                        distributeErrorFS(&work, x: x, y: y, width: width, height: height,
                                         rErr: rErr, gErr: gErr, bErr: bErr, amount: ditherAmount)
                    } else if ditherAlg == "Atkinson" {
                        distributeErrorAtkinson(&work, x: x, y: y, width: width, height: height,
                                               rErr: rErr, gErr: gErr, bErr: bErr, amount: ditherAmount)
                    }
                }
            }
        }

        // Create native file with AMSDOS header (including palette for decoder compatibility)
        var nativeData = Data()

        // AMSDOS header (128 bytes) with embedded palette in bytes 69-84
        nativeData.append(contentsOf: createAMSDOSHeader(fileName: "PICTURE", ext: "SCR",
                                                          loadAddress: 0xC000, length: 16384,
                                                          palette: palette))

        // Bitmap data
        nativeData.append(contentsOf: bitmap)

        return (resultPixels, nativeData)
    }

    // MARK: - Mode 0 Conversion (160×200, 16 colors)

    private func convertMode0(pixels: [[Float]], width: Int, height: Int,
                              palette: [(index: Int, color: [UInt8])],
                              pixelMerge: String, colorMatch: String,
                              ditherAlg: String, ditherAmount: Double) -> ([UInt8], Data) {
        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)
        var bitmap = [UInt8](repeating: 0, count: 16384)

        // First, shrink 320 -> 160 by merging pixel pairs
        var shrunkPixels = [[Int]](repeating: [0, 0, 0], count: 160 * height)

        for y in 0..<height {
            for x in 0..<160 {
                let x1 = x * 2
                let x2 = x * 2 + 1

                let r1 = Int(pixels[y * width + x1][0])
                let g1 = Int(pixels[y * width + x1][1])
                let b1 = Int(pixels[y * width + x1][2])

                let r2 = Int(pixels[y * width + x2][0])
                let g2 = Int(pixels[y * width + x2][1])
                let b2 = Int(pixels[y * width + x2][2])

                let r, g, b: Int

                if pixelMerge == "Average" {
                    r = (r1 + r2) / 2
                    g = (g1 + g2) / 2
                    b = (b1 + b2) / 2
                } else {
                    // Brightest
                    let luma1 = Float(r1) * 0.299 + Float(g1) * 0.587 + Float(b1) * 0.114
                    let luma2 = Float(r2) * 0.299 + Float(g2) * 0.587 + Float(b2) * 0.114

                    let sum = luma1 + luma2
                    if sum > 0.001 {
                        r = Int((Float(r1) * luma1 + Float(r2) * luma2) / sum)
                        g = Int((Float(g1) * luma1 + Float(g2) * luma2) / sum)
                        b = Int((Float(b1) * luma1 + Float(b2) * luma2) / sum)
                    } else {
                        r = (r1 + r2) / 2
                        g = (g1 + g2) / 2
                        b = (b1 + b2) / 2
                    }
                }

                shrunkPixels[y * 160 + x] = [r, g, b]
            }
        }

        // Convert at 160×200
        for y in 0..<height {
            let i = y >> 3
            let j = y & 7
            let offset = i * 80 + j * 2048

            for x in 0..<160 {
                let r = max(0, min(255, shrunkPixels[y * 160 + x][0]))
                let g = max(0, min(255, shrunkPixels[y * 160 + x][1]))
                let b = max(0, min(255, shrunkPixels[y * 160 + x][2]))

                let colorIndex = findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)

                let pr = palette[colorIndex].color[0]
                let pg = palette[colorIndex].color[1]
                let pb = palette[colorIndex].color[2]

                // Store result (double-wide pixels in preview)
                let x1 = x * 2
                let x2 = x * 2 + 1

                resultPixels[(y * width + x1) * 3] = pr
                resultPixels[(y * width + x1) * 3 + 1] = pg
                resultPixels[(y * width + x1) * 3 + 2] = pb

                resultPixels[(y * width + x2) * 3] = pr
                resultPixels[(y * width + x2) * 3 + 1] = pg
                resultPixels[(y * width + x2) * 3 + 2] = pb

                // Pack into bitmap (2 pixels per byte, bits interleaved)
                // Mode 0 bit pattern: pixel 0 uses bits 7,3,5,1; pixel 1 uses bits 6,2,4,0
                let byteIndex = offset + (x / 2)
                let pixelInByte = x % 2

                if pixelInByte == 0 {
                    // First pixel: bits 7,3,5,1
                    if colorIndex & 1 != 0 { bitmap[byteIndex] |= 0x80 }
                    if colorIndex & 2 != 0 { bitmap[byteIndex] |= 0x08 }
                    if colorIndex & 4 != 0 { bitmap[byteIndex] |= 0x20 }
                    if colorIndex & 8 != 0 { bitmap[byteIndex] |= 0x02 }
                } else {
                    // Second pixel: bits 6,2,4,0
                    if colorIndex & 1 != 0 { bitmap[byteIndex] |= 0x40 }
                    if colorIndex & 2 != 0 { bitmap[byteIndex] |= 0x04 }
                    if colorIndex & 4 != 0 { bitmap[byteIndex] |= 0x10 }
                    if colorIndex & 8 != 0 { bitmap[byteIndex] |= 0x01 }
                }
            }
        }

        // Create native file with AMSDOS header (including palette for decoder compatibility)
        var nativeData = Data()
        nativeData.append(contentsOf: createAMSDOSHeader(fileName: "PICTURE", ext: "SCR",
                                                          loadAddress: 0xC000, length: 16384,
                                                          palette: palette))
        nativeData.append(contentsOf: bitmap)

        return (resultPixels, nativeData)
    }

    // MARK: - AMSDOS Header

    private func createAMSDOSHeader(fileName: String, ext: String, loadAddress: Int, length: Int, palette: [(index: Int, color: [UInt8])]? = nil) -> [UInt8] {
        var header = [UInt8](repeating: 0, count: 128)

        // User number
        header[0] = 0x00

        // File name (8 chars, padded with spaces)
        let nameBytes = Array(fileName.uppercased().utf8)
        for i in 0..<min(8, nameBytes.count) {
            header[1 + i] = nameBytes[i]
        }
        for i in nameBytes.count..<8 {
            header[1 + i] = 0x20  // Space
        }

        // Extension (3 chars)
        let extBytes = Array(ext.uppercased().utf8)
        for i in 0..<min(3, extBytes.count) {
            header[9 + i] = extBytes[i]
        }

        // File type (offset 18): 2 = binary
        header[18] = 0x02

        // Load address (offset 21-22)
        header[21] = UInt8(loadAddress & 0xFF)
        header[22] = UInt8((loadAddress >> 8) & 0xFF)

        // File length (offset 24-25)
        header[24] = UInt8(length & 0xFF)
        header[25] = UInt8((length >> 8) & 0xFF)

        // Entry address (offset 26-27)
        header[26] = UInt8(loadAddress & 0xFF)
        header[27] = UInt8((loadAddress >> 8) & 0xFF)

        // File length again (offset 64-65)
        header[64] = UInt8(length & 0xFF)
        header[65] = UInt8((length >> 8) & 0xFF)

        // Calculate checksum (sum of bytes 0-66)
        var checksum: Int = 0
        for i in 0..<67 {
            checksum += Int(header[i])
        }
        header[67] = UInt8(checksum & 0xFF)
        header[68] = UInt8((checksum >> 8) & 0xFF)

        // Store palette in bytes 69-84 (up to 16 hardware color indices)
        // This allows the decoder to correctly reconstruct the image colors
        if let palette = palette {
            for i in 0..<min(16, palette.count) {
                header[69 + i] = UInt8(palette[i].index)
            }
        }

        return header
    }

    // MARK: - Color Matching

    private func findClosestColor(r: Int, g: Int, b: Int,
                                  palette: [(index: Int, color: [UInt8])],
                                  method: String) -> Int {
        var bestIndex = 0
        var bestDist = Float.greatestFiniteMagnitude

        for i in 0..<palette.count {
            let pr = Float(palette[i].color[0])
            let pg = Float(palette[i].color[1])
            let pb = Float(palette[i].color[2])

            let dist: Float
            switch method {
            case "Perceptive":
                let rmean = (Float(r) + pr) / 2.0
                let dr = Float(r) - pr
                let dg = Float(g) - pg
                let db = Float(b) - pb
                dist = sqrt((2.0 + rmean / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rmean) / 256.0) * db * db)
            case "Luma":
                let ly = Float(r) * 0.299 + Float(g) * 0.587 + Float(b) * 0.114
                let py = pr * 0.299 + pg * 0.587 + pb * 0.114
                dist = abs(ly - py)
            case "Chroma":
                let lc = sqrt(Float(r * r + g * g + b * b))
                let pc = sqrt(pr * pr + pg * pg + pb * pb)
                dist = abs(lc - pc)
            default: // Euclidean
                let dr = Float(r) - pr
                let dg = Float(g) - pg
                let db = Float(b) - pb
                dist = dr * dr + dg * dg + db * db
            }

            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        return min(max(bestIndex, 0), palette.count - 1)
    }

    // MARK: - Error Diffusion

    private func distributeErrorFS(_ work: inout [[Int]], x: Int, y: Int, width: Int, height: Int,
                                   rErr: Int, gErr: Int, bErr: Int, amount: Double) {
        let factor = Float(amount)

        if x + 1 < width {
            work[y * width + x + 1][0] += Int(Float(rErr) * 7.0 / 16.0 * factor)
            work[y * width + x + 1][1] += Int(Float(gErr) * 7.0 / 16.0 * factor)
            work[y * width + x + 1][2] += Int(Float(bErr) * 7.0 / 16.0 * factor)
        }
        if y + 1 < height {
            if x > 0 {
                work[(y + 1) * width + x - 1][0] += Int(Float(rErr) * 3.0 / 16.0 * factor)
                work[(y + 1) * width + x - 1][1] += Int(Float(gErr) * 3.0 / 16.0 * factor)
                work[(y + 1) * width + x - 1][2] += Int(Float(bErr) * 3.0 / 16.0 * factor)
            }
            work[(y + 1) * width + x][0] += Int(Float(rErr) * 5.0 / 16.0 * factor)
            work[(y + 1) * width + x][1] += Int(Float(gErr) * 5.0 / 16.0 * factor)
            work[(y + 1) * width + x][2] += Int(Float(bErr) * 5.0 / 16.0 * factor)
            if x + 1 < width {
                work[(y + 1) * width + x + 1][0] += Int(Float(rErr) * 1.0 / 16.0 * factor)
                work[(y + 1) * width + x + 1][1] += Int(Float(gErr) * 1.0 / 16.0 * factor)
                work[(y + 1) * width + x + 1][2] += Int(Float(bErr) * 1.0 / 16.0 * factor)
            }
        }
    }

    private func distributeErrorAtkinson(_ work: inout [[Int]], x: Int, y: Int, width: Int, height: Int,
                                         rErr: Int, gErr: Int, bErr: Int, amount: Double) {
        let factor = Float(amount) / 8.0

        let offsets = [(1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)]
        for (dx, dy) in offsets {
            let nx = x + dx
            let ny = y + dy
            if nx >= 0 && nx < width && ny < height {
                work[ny * width + nx][0] += Int(Float(rErr) * factor)
                work[ny * width + nx][1] += Int(Float(gErr) * factor)
                work[ny * width + nx][2] += Int(Float(bErr) * factor)
            }
        }
    }

    // MARK: - Preview Image

    private func createPreviewImage(from pixels: [UInt8], width: Int, height: Int) -> NSImage? {
        var pixelData = [UInt8](repeating: 255, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let srcOffset = (y * width + x) * 3
                let dstOffset = (y * width + x) * 4

                pixelData[dstOffset] = pixels[srcOffset]
                pixelData[dstOffset + 1] = pixels[srcOffset + 1]
                pixelData[dstOffset + 2] = pixels[srcOffset + 2]
                pixelData[dstOffset + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &pixelData,
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: width * 4,
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        guard let cgImage = context.makeImage() else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    // MARK: - Image Processing Helpers

    private func getPixelData(from image: NSImage, width: Int, height: Int) -> [[Float]]? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(data: &pixelData,
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: width * 4,
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var result = [[Float]](repeating: [0, 0, 0], count: width * height)
        for i in 0..<(width * height) {
            result[i] = [Float(pixelData[i * 4]), Float(pixelData[i * 4 + 1]), Float(pixelData[i * 4 + 2])]
        }

        return result
    }

    private func applySaturation(_ pixels: inout [[Float]], width: Int, height: Int, factor: Double) {
        for i in 0..<pixels.count {
            let r = pixels[i][0]
            let g = pixels[i][1]
            let b = pixels[i][2]

            let gray = r * 0.299 + g * 0.587 + b * 0.114
            pixels[i][0] = max(0, min(255, gray + Float(factor) * (r - gray)))
            pixels[i][1] = max(0, min(255, gray + Float(factor) * (g - gray)))
            pixels[i][2] = max(0, min(255, gray + Float(factor) * (b - gray)))
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

    private func applyContrast(_ pixels: inout [[Float]], width: Int, height: Int, mode: String) {
        switch mode {
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
        for i in 0..<pixels.count {
            let luma = Int(pixels[i][0] * 0.299 + pixels[i][1] * 0.587 + pixels[i][2] * 0.114)
            histogram[max(0, min(255, luma))] += 1
        }

        var cdf = [Int](repeating: 0, count: 256)
        cdf[0] = histogram[0]
        for i in 1..<256 {
            cdf[i] = cdf[i - 1] + histogram[i]
        }

        let cdfMin = cdf.first(where: { $0 > 0 }) ?? 0
        let scale = Float(255) / Float(max(1, pixels.count - cdfMin))

        for i in 0..<pixels.count {
            let luma = Int(pixels[i][0] * 0.299 + pixels[i][1] * 0.587 + pixels[i][2] * 0.114)
            let newLuma = Float(cdf[max(0, min(255, luma))] - cdfMin) * scale
            let ratio = (luma > 0) ? newLuma / Float(luma) : 1.0

            pixels[i][0] = max(0, min(255, pixels[i][0] * ratio))
            pixels[i][1] = max(0, min(255, pixels[i][1] * ratio))
            pixels[i][2] = max(0, min(255, pixels[i][2] * ratio))
        }
    }

    private func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int, clipLimit: Float, tileSize: Int) {
        applyHistogramEqualization(&pixels, width: width, height: height)
    }

    private func applySWAHE(_ pixels: inout [[Float]], width: Int, height: Int, windowSize: Int) {
        let halfWindow = windowSize / 2
        var result = pixels

        for y in 0..<height {
            var histogram = [Int](repeating: 0, count: 256)
            var count = 0

            let y0 = max(0, y - halfWindow)
            let y1 = min(height - 1, y + halfWindow)

            for wy in y0...y1 {
                for wx in 0..<min(halfWindow, width) {
                    let luma = Int(pixels[wy * width + wx][0] * 0.299 +
                                   pixels[wy * width + wx][1] * 0.587 +
                                   pixels[wy * width + wx][2] * 0.114)
                    histogram[max(0, min(255, luma))] += 1
                    count += 1
                }
            }

            for x in 0..<width {
                let x1 = x + halfWindow
                if x1 < width {
                    for wy in y0...y1 {
                        let luma = Int(pixels[wy * width + x1][0] * 0.299 +
                                       pixels[wy * width + x1][1] * 0.587 +
                                       pixels[wy * width + x1][2] * 0.114)
                        histogram[max(0, min(255, luma))] += 1
                        count += 1
                    }
                }

                let x0 = x - halfWindow - 1
                if x0 >= 0 {
                    for wy in y0...y1 {
                        let luma = Int(pixels[wy * width + x0][0] * 0.299 +
                                       pixels[wy * width + x0][1] * 0.587 +
                                       pixels[wy * width + x0][2] * 0.114)
                        histogram[max(0, min(255, luma))] -= 1
                        count -= 1
                    }
                }

                let currentLuma = Int(pixels[y * width + x][0] * 0.299 +
                                      pixels[y * width + x][1] * 0.587 +
                                      pixels[y * width + x][2] * 0.114)

                var cdfValue = 0
                for i in 0...max(0, min(255, currentLuma)) {
                    cdfValue += histogram[i]
                }

                let newLuma = Float(cdfValue * 255) / Float(max(1, count))
                let ratio = (currentLuma > 0) ? newLuma / Float(currentLuma) : 1.0

                result[y * width + x][0] = max(0, min(255, pixels[y * width + x][0] * ratio))
                result[y * width + x][1] = max(0, min(255, pixels[y * width + x][1] * ratio))
                result[y * width + x][2] = max(0, min(255, pixels[y * width + x][2] * ratio))
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
                // Blend edge with original (50/50)
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
        default:
            return
        }

        let maxVal = Float(matrixSize * matrixSize)
        let strength = Float(amount) * 64.0

        for y in 0..<height {
            for x in 0..<width {
                let threshold = (matrix[y % matrixSize][x % matrixSize] / maxVal - 0.5) * strength
                pixels[y * width + x][0] = max(0, min(255, pixels[y * width + x][0] + threshold))
                pixels[y * width + x][1] = max(0, min(255, pixels[y * width + x][1] + threshold))
                pixels[y * width + x][2] = max(0, min(255, pixels[y * width + x][2] + threshold))
            }
        }
    }
}
