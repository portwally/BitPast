import Cocoa

class C64Converter: RetroMachine {
    var name: String = "C64"

    var options: [ConversionOption] = [
        // 1. GRAPHICS MODE (from C64Config.java: HIRES, MULTICOLOR)
        ConversionOption(
            label: "Graphics Mode",
            key: "mode",
            values: ["HiRes (320×200)", "Multicolor (160×200)"],
            selectedValue: "Multicolor (160×200)"
        ),

        // 2. DITHERING ALGORITHM (from Config.java: NONE, FLOYDS, ATKINSON, NOISE, BAYER2x2-16x16, BLUE8x8-16x16)
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
            selectedValue: "Atkinson"
        ),

        // 3. DITHER AMOUNT
        ConversionOption(
            label: "Dither Amount",
            key: "dither_amount",
            range: 0.0...1.0,
            defaultValue: 0.5
        ),

        // 4. CONTRAST PROCESSING (from Config.java: NONE, HE, CLAHE, SWAHE)
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

        // 6. PIXEL MERGE (for multicolor)
        ConversionOption(
            label: "Pixel Merge",
            key: "pixel_merge",
            values: ["Average", "Brightest"],
            selectedValue: "Average"
        ),

        // 7. COLOR MATCHING (from Config.java: EUCLIDEAN, PERCEPTED, LUMA_WEIGHTED, CHROMA_WEIGHTED, MAHALANOBIS)
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
            range: 0.5...2.5,
            defaultValue: 1.0
        )
    ]

    // C64 fixed 16-color palette (VICE/Pepto palette - widely accepted as accurate)
    static let c64Palette: [[Int]] = [
        [0x00, 0x00, 0x00],  // 0  Black
        [0xFF, 0xFF, 0xFF],  // 1  White
        [0x68, 0x37, 0x2B],  // 2  Red
        [0x70, 0xA4, 0xB2],  // 3  Cyan
        [0x6F, 0x3D, 0x86],  // 4  Purple
        [0x58, 0x8D, 0x43],  // 5  Green
        [0x35, 0x28, 0x79],  // 6  Blue
        [0xB8, 0xC7, 0x6F],  // 7  Yellow
        [0x6F, 0x4F, 0x25],  // 8  Orange
        [0x43, 0x39, 0x00],  // 9  Brown
        [0x9A, 0x67, 0x59],  // 10 Light Red
        [0x44, 0x44, 0x44],  // 11 Dark Grey
        [0x6C, 0x6C, 0x6C],  // 12 Medium Grey
        [0x9A, 0xD2, 0x84],  // 13 Light Green
        [0x6C, 0x5E, 0xB5],  // 14 Light Blue
        [0x95, 0x95, 0x95]   // 15 Light Grey
    ]

    func convert(sourceImage: NSImage) async throws -> ConversionResult {
        // Get options
        let mode = options.first(where: { $0.key == "mode" })?.selectedValue ?? "Multicolor"
        let ditherAlg = options.first(where: { $0.key == "dither" })?.selectedValue ?? "Atkinson"
        let ditherAmount = Double(options.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "1.0") ?? 1.0
        let contrastMode = options.first(where: { $0.key == "contrast" })?.selectedValue ?? "SWAHE"
        let filterMode = options.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let pixelMerge = options.first(where: { $0.key == "pixel_merge" })?.selectedValue ?? "Average"
        let colorMatch = options.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(options.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(options.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        // C64 screen size
        let screenWidth = 320
        let screenHeight = 200

        let width = screenWidth
        let height = screenHeight

        // Get pixel data using the same approach as AppleIIGSConverter
        var pixels = try getPixelData(from: sourceImage, width: width, height: height,
                                       saturation: saturation, gamma: gamma)

        // Apply contrast processing
        if contrastMode != "None" {
            applyContrastProcessing(&pixels, width: width, height: height, mode: contrastMode)
        }

        // Apply image filter
        if filterMode != "None" {
            applyImageFilter(&pixels, width: width, height: height, filter: filterMode)
        }

        // Apply ordered dithering before color reduction (Bayer, Blue noise, or random noise)
        if ditherAlg.contains("Bayer") || ditherAlg.contains("Blue") || ditherAlg == "Noise" {
            applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount)
        }

        // Convert based on mode
        var resultPixels: [UInt8]
        var nativeData: Data
        var fileExtension: String

        if mode.contains("HiRes") {
            (resultPixels, nativeData) = convertHiRes(pixels: pixels, width: width, height: height,
                                                       ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                       colorMatch: colorMatch)
            fileExtension = "art"
        } else { // Multicolor
            (resultPixels, nativeData) = convertMulticolor(pixels: pixels, width: width, height: height,
                                                            ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                            colorMatch: colorMatch, pixelMerge: pixelMerge)
            fileExtension = "kla"
        }

        // Create preview image using CGContext (doubled for better visibility)
        let previewWidth = screenWidth * 2
        let previewHeight = screenHeight * 2

        // Create preview using CGContext with direct byte access
        var previewBytes = [UInt8](repeating: 255, count: previewWidth * previewHeight * 4)

        // Copy result pixels to preview (doubled)
        for y in 0..<screenHeight {
            for x in 0..<screenWidth {
                let srcOffset = (y * screenWidth + x) * 3
                let r = resultPixels[srcOffset]
                let g = resultPixels[srcOffset + 1]
                let b = resultPixels[srcOffset + 2]

                // Double pixels for preview
                for dy in 0..<2 {
                    for dx in 0..<2 {
                        let px = x * 2 + dx
                        let py = y * 2 + dy
                        let dstOffset = (py * previewWidth + px) * 4
                        previewBytes[dstOffset] = r
                        previewBytes[dstOffset + 1] = g
                        previewBytes[dstOffset + 2] = b
                        previewBytes[dstOffset + 3] = 255  // Alpha
                    }
                }
            }
        }

        // Create CGImage from bytes
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let ctx = CGContext(data: &previewBytes, width: previewWidth, height: previewHeight,
                                   bitsPerComponent: 8, bytesPerRow: previewWidth * 4,
                                   space: colorSpace, bitmapInfo: bitmapInfo),
              let cgImage = ctx.makeImage() else {
            throw NSError(domain: "C64Converter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview image"])
        }

        let previewImage = NSImage(cgImage: cgImage, size: NSSize(width: previewWidth, height: previewHeight))

        // Save native file
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("c64_\(uuid).\(fileExtension)")
        try nativeData.write(to: nativeUrl)

        return ConversionResult(
            previewImage: previewImage,
            fileAssets: [nativeUrl],
            palettes: [],
            pixelIndices: [],
            imageWidth: screenWidth,
            imageHeight: screenHeight
        )
    }

    // MARK: - HiRes Mode (320x200, 2 colors per 8x8 cell)

    private func convertHiRes(pixels: [[Float]], width: Int, height: Int,
                               ditherAlg: String, ditherAmount: Double,
                               colorMatch: String) -> ([UInt8], Data) {
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var bitmap = [UInt8](repeating: 0, count: 8000)  // 320x200 / 8
        var screen = [UInt8](repeating: 0, count: 1000)  // 40x25 character cells

        var workPixels = pixels

        // Process 8x8 character cells
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                // Find two best colors for this cell
                var colorCounts = [Int](repeating: 0, count: 16)

                for py in 0..<8 {
                    for px in 0..<8 {
                        let x = cellX * 8 + px
                        let y = cellY * 8 + py
                        let pixel = workPixels[y * width + x]
                        let colorIdx = findNearestColor(r: pixel[0], g: pixel[1], b: pixel[2], colorMatch: colorMatch)
                        colorCounts[colorIdx] += 1
                    }
                }

                // Find two most common colors
                var color1 = 0, color2 = 0
                var max1 = 0, max2 = 0
                for i in 0..<16 {
                    if colorCounts[i] > max1 {
                        max2 = max1
                        color2 = color1
                        max1 = colorCounts[i]
                        color1 = i
                    } else if colorCounts[i] > max2 {
                        max2 = colorCounts[i]
                        color2 = i
                    }
                }

                // Store screen memory (fg in high nibble, bg in low)
                screen[cellY * 40 + cellX] = UInt8((color1 << 4) | color2)

                // Convert pixels in this cell
                for py in 0..<8 {
                    var byteval: UInt8 = 0
                    for px in 0..<8 {
                        let x = cellX * 8 + px
                        let y = cellY * 8 + py
                        let pixel = workPixels[y * width + x]

                        // Choose between the two cell colors
                        let d1 = colorDistance(pixel: pixel, colorIdx: color1, colorMatch: colorMatch)
                        let d2 = colorDistance(pixel: pixel, colorIdx: color2, colorMatch: colorMatch)

                        let chosenColor = d1 < d2 ? color1 : color2
                        let chosenPalette = C64Converter.c64Palette[chosenColor]

                        // Set bit if foreground color
                        if chosenColor == color1 {
                            byteval |= (1 << (7 - px))
                        }

                        // Store result
                        let offset = (y * width + x) * 3
                        result[offset] = UInt8(chosenPalette[0])
                        result[offset + 1] = UInt8(chosenPalette[1])
                        result[offset + 2] = UInt8(chosenPalette[2])

                        // Error diffusion for non-Bayer dithering
                        if ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson" {
                            let errR = (pixel[0] - Float(chosenPalette[0]) / 255.0) * Float(ditherAmount)
                            let errG = (pixel[1] - Float(chosenPalette[1]) / 255.0) * Float(ditherAmount)
                            let errB = (pixel[2] - Float(chosenPalette[2]) / 255.0) * Float(ditherAmount)

                            diffuseError(&workPixels, x: x, y: y, width: width, height: height,
                                        errR: errR, errG: errG, errB: errB, algorithm: ditherAlg)
                        }
                    }

                    // Store bitmap byte
                    let bitmapIdx = (cellY * 40 + cellX) * 8 + py
                    bitmap[bitmapIdx] = byteval
                }
            }
        }

        // Create Art Studio format file
        var artData = Data()
        artData.append(contentsOf: [0x00, 0x20])  // Load address $2000
        artData.append(contentsOf: bitmap)
        artData.append(contentsOf: screen)

        return (result, artData)
    }

    // MARK: - Multicolor Mode (160x200, 4 colors per 4x8 cell)

    private func convertMulticolor(pixels: [[Float]], width: Int, height: Int,
                                    ditherAlg: String, ditherAmount: Double,
                                    colorMatch: String, pixelMerge: String) -> ([UInt8], Data) {
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var bitmap = [UInt8](repeating: 0, count: 8000)
        var screen = [UInt8](repeating: 0, count: 1000)
        var colorRam = [UInt8](repeating: 0, count: 1000)
        var backgroundColor: UInt8 = 0

        // First, shrink to 160x200 and find global background color
        var shrunkPixels = [[Float]](repeating: [Float](repeating: 0, count: 3), count: 160 * 200)
        var avgR: Float = 0, avgG: Float = 0, avgB: Float = 0

        for y in 0..<200 {
            for x in 0..<160 {
                let x1 = x * 2
                let x2 = x * 2 + 1
                let p1 = pixels[y * width + x1]
                let p2 = pixels[y * width + x2]

                let r, g, b: Float
                if pixelMerge == "Brightest" {
                    let l1 = 0.299 * p1[0] + 0.587 * p1[1] + 0.114 * p1[2]
                    let l2 = 0.299 * p2[0] + 0.587 * p2[1] + 0.114 * p2[2]
                    let sum = l1 + l2
                    if sum > 0 {
                        r = (p1[0] * l1 + p2[0] * l2) / sum
                        g = (p1[1] * l1 + p2[1] * l2) / sum
                        b = (p1[2] * l1 + p2[2] * l2) / sum
                    } else {
                        r = (p1[0] + p2[0]) / 2
                        g = (p1[1] + p2[1]) / 2
                        b = (p1[2] + p2[2]) / 2
                    }
                } else {
                    r = (p1[0] + p2[0]) / 2
                    g = (p1[1] + p2[1]) / 2
                    b = (p1[2] + p2[2]) / 2
                }

                shrunkPixels[y * 160 + x] = [r, g, b]
                avgR += r
                avgG += g
                avgB += b
            }
        }

        // Find background color (average of all pixels)
        avgR /= Float(160 * 200)
        avgG /= Float(160 * 200)
        avgB /= Float(160 * 200)
        backgroundColor = UInt8(findNearestColor(r: avgR, g: avgG, b: avgB, colorMatch: colorMatch))

        var workPixels = shrunkPixels

        // Process 4x8 character cells
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                // Count color occurrences in this cell
                var colorCounts = [Int](repeating: 0, count: 16)

                for py in 0..<8 {
                    for px in 0..<4 {
                        let x = cellX * 4 + px
                        let y = cellY * 8 + py
                        let pixel = workPixels[y * 160 + x]
                        let colorIdx = findNearestColor(r: pixel[0], g: pixel[1], b: pixel[2], colorMatch: colorMatch)
                        colorCounts[colorIdx] += 1
                    }
                }

                // Find three most common colors (plus background = 4 colors)
                var colors = [Int(backgroundColor), 0, 0, 0]
                var maxCounts = [0, 0, 0]

                for i in 0..<16 {
                    if i == Int(backgroundColor) { continue }
                    if colorCounts[i] > maxCounts[0] {
                        maxCounts[2] = maxCounts[1]
                        colors[3] = colors[2]
                        maxCounts[1] = maxCounts[0]
                        colors[2] = colors[1]
                        maxCounts[0] = colorCounts[i]
                        colors[1] = i
                    } else if colorCounts[i] > maxCounts[1] {
                        maxCounts[2] = maxCounts[1]
                        colors[3] = colors[2]
                        maxCounts[1] = colorCounts[i]
                        colors[2] = i
                    } else if colorCounts[i] > maxCounts[2] {
                        maxCounts[2] = colorCounts[i]
                        colors[3] = i
                    }
                }

                // Store screen and color RAM
                screen[cellY * 40 + cellX] = UInt8((colors[1] << 4) | colors[2])
                colorRam[cellY * 40 + cellX] = UInt8(colors[3])

                // Convert pixels in this cell
                for py in 0..<8 {
                    var byteval: UInt8 = 0
                    for px in 0..<4 {
                        let x = cellX * 4 + px
                        let y = cellY * 8 + py
                        let pixel = workPixels[y * 160 + x]

                        // Find best matching color from the 4 available
                        var bestColor = 0
                        var bestDist = Float.infinity
                        for ci in 0..<4 {
                            let dist = colorDistance(pixel: pixel, colorIdx: colors[ci], colorMatch: colorMatch)
                            if dist < bestDist {
                                bestDist = dist
                                bestColor = ci
                            }
                        }

                        let chosenPalette = C64Converter.c64Palette[colors[bestColor]]

                        // Set 2-bit value
                        byteval |= UInt8(bestColor << ((3 - px) * 2))

                        // Store result (double pixels horizontally)
                        let sx = cellX * 8 + px * 2
                        let sy = cellY * 8 + py
                        for dx in 0..<2 {
                            let offset = (sy * width + sx + dx) * 3
                            result[offset] = UInt8(chosenPalette[0])
                            result[offset + 1] = UInt8(chosenPalette[1])
                            result[offset + 2] = UInt8(chosenPalette[2])
                        }

                        // Error diffusion
                        if ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson" {
                            let errR = (pixel[0] - Float(chosenPalette[0]) / 255.0) * Float(ditherAmount)
                            let errG = (pixel[1] - Float(chosenPalette[1]) / 255.0) * Float(ditherAmount)
                            let errB = (pixel[2] - Float(chosenPalette[2]) / 255.0) * Float(ditherAmount)

                            diffuseErrorMC(&workPixels, x: x, y: y, width: 160, height: 200,
                                          errR: errR, errG: errG, errB: errB, algorithm: ditherAlg)
                        }
                    }

                    let bitmapIdx = (cellY * 40 + cellX) * 8 + py
                    bitmap[bitmapIdx] = byteval
                }
            }
        }

        // Create Koala format file
        var koalaData = Data()
        koalaData.append(contentsOf: [0x00, 0x60])  // Load address $6000
        koalaData.append(contentsOf: bitmap)
        koalaData.append(contentsOf: screen)
        koalaData.append(contentsOf: colorRam)
        koalaData.append(backgroundColor)

        return (result, koalaData)
    }

    // MARK: - Color Matching

    private func findNearestColor(r: Float, g: Float, b: Float, colorMatch: String) -> Int {
        var bestIdx = 0
        var bestDist = Float.infinity

        for i in 0..<16 {
            let pr = Float(C64Converter.c64Palette[i][0]) / 255.0
            let pg = Float(C64Converter.c64Palette[i][1]) / 255.0
            let pb = Float(C64Converter.c64Palette[i][2]) / 255.0

            let dist: Float
            switch colorMatch {
            case "Perceptive":
                // Weighted perceptual distance
                let dr = r - pr
                let dg = g - pg
                let db = b - pb
                let rmean = (r + pr) / 2
                dist = sqrt((2 + rmean) * dr * dr + 4 * dg * dg + (3 - rmean) * db * db)
            case "Luma":
                // Luminance-weighted distance (for B&W-ish results)
                let srcLuma = 0.299 * r + 0.587 * g + 0.114 * b
                let palLuma = 0.299 * pr + 0.587 * pg + 0.114 * pb
                dist = abs(srcLuma - palLuma)
            case "Chroma":
                // Chrominance-prioritized distance (preserves color saturation)
                let srcLuma = 0.299 * r + 0.587 * g + 0.114 * b
                let palLuma = 0.299 * pr + 0.587 * pg + 0.114 * pb
                let srcU = 0.492 * (b - srcLuma)
                let srcV = 0.877 * (r - srcLuma)
                let palU = 0.492 * (pb - palLuma)
                let palV = 0.877 * (pr - palLuma)
                let chromaDist = sqrt((srcU - palU) * (srcU - palU) + (srcV - palV) * (srcV - palV))
                let lumaDist = abs(srcLuma - palLuma)
                dist = chromaDist * 2.0 + lumaDist * 0.5  // Prioritize chroma
            case "Mahalanobis":
                // Mahalanobis-like distance using palette-aware weighting
                let dr = r - pr
                let dg = g - pg
                let db = b - pb
                // Weight by inverse variance approximation for C64 palette
                dist = dr * dr * 2.5 + dg * dg * 1.0 + db * db * 3.0
            default:
                // Euclidean distance
                let dr = r - pr
                let dg = g - pg
                let db = b - pb
                dist = dr * dr + dg * dg + db * db
            }

            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }

        return bestIdx
    }

    private func colorDistance(pixel: [Float], colorIdx: Int, colorMatch: String) -> Float {
        let pr = Float(C64Converter.c64Palette[colorIdx][0]) / 255.0
        let pg = Float(C64Converter.c64Palette[colorIdx][1]) / 255.0
        let pb = Float(C64Converter.c64Palette[colorIdx][2]) / 255.0

        switch colorMatch {
        case "Perceptive":
            let dr = pixel[0] - pr
            let dg = pixel[1] - pg
            let db = pixel[2] - pb
            let rmean = (pixel[0] + pr) / 2
            return sqrt((2 + rmean) * dr * dr + 4 * dg * dg + (3 - rmean) * db * db)
        case "Luma":
            let srcLuma = 0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2]
            let palLuma = 0.299 * pr + 0.587 * pg + 0.114 * pb
            return abs(srcLuma - palLuma)
        case "Chroma":
            let srcLuma = 0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2]
            let palLuma = 0.299 * pr + 0.587 * pg + 0.114 * pb
            let srcU = 0.492 * (pixel[2] - srcLuma)
            let srcV = 0.877 * (pixel[0] - srcLuma)
            let palU = 0.492 * (pb - palLuma)
            let palV = 0.877 * (pr - palLuma)
            let chromaDist = sqrt((srcU - palU) * (srcU - palU) + (srcV - palV) * (srcV - palV))
            let lumaDist = abs(srcLuma - palLuma)
            return chromaDist * 2.0 + lumaDist * 0.5
        case "Mahalanobis":
            let dr = pixel[0] - pr
            let dg = pixel[1] - pg
            let db = pixel[2] - pb
            return dr * dr * 2.5 + dg * dg * 1.0 + db * db * 3.0
        default:
            let dr = pixel[0] - pr
            let dg = pixel[1] - pg
            let db = pixel[2] - pb
            return dr * dr + dg * dg + db * db
        }
    }

    // MARK: - Dithering

    private func applyOrderedDither(_ pixels: inout [[Float]], width: Int, height: Int, ditherType: String, amount: Double) {
        let matrix: [[Float]]
        let size: Int

        switch ditherType {
        case "Bayer 2x2":
            size = 2
            matrix = [
                [0.0, 2.0],
                [3.0, 1.0]
            ]
        case "Bayer 4x4":
            size = 4
            matrix = [
                [0.0, 8.0, 2.0, 10.0],
                [12.0, 4.0, 14.0, 6.0],
                [3.0, 11.0, 1.0, 9.0],
                [15.0, 7.0, 13.0, 5.0]
            ]
        case "Bayer 16x16":
            size = 16
            matrix = generateBayer16x16()
        case "Blue 8x8":
            size = 8
            matrix = generateBlueNoise8x8()
        case "Blue 16x16":
            size = 16
            matrix = generateBlueNoise16x16()
        case "Noise":
            // Random noise dithering - handled separately
            applyNoiseDither(&pixels, width: width, height: height, amount: amount)
            return
        default: // Bayer 8x8
            size = 8
            matrix = [
                [0.0, 32.0, 8.0, 40.0, 2.0, 34.0, 10.0, 42.0],
                [48.0, 16.0, 56.0, 24.0, 50.0, 18.0, 58.0, 26.0],
                [12.0, 44.0, 4.0, 36.0, 14.0, 46.0, 6.0, 38.0],
                [60.0, 28.0, 52.0, 20.0, 62.0, 30.0, 54.0, 22.0],
                [3.0, 35.0, 11.0, 43.0, 1.0, 33.0, 9.0, 41.0],
                [51.0, 19.0, 59.0, 27.0, 49.0, 17.0, 57.0, 25.0],
                [15.0, 47.0, 7.0, 39.0, 13.0, 45.0, 5.0, 37.0],
                [63.0, 31.0, 55.0, 23.0, 61.0, 29.0, 53.0, 21.0]
            ]
        }

        let maxVal = Float(size * size)
        let strength = Float(amount) * 0.15

        for y in 0..<height {
            for x in 0..<width {
                let threshold = (matrix[y % size][x % size] / maxVal - 0.5) * strength
                let idx = y * width + x
                pixels[idx][0] = min(1, max(0, pixels[idx][0] + threshold))
                pixels[idx][1] = min(1, max(0, pixels[idx][1] + threshold))
                pixels[idx][2] = min(1, max(0, pixels[idx][2] + threshold))
            }
        }
    }

    private func generateBayer16x16() -> [[Float]] {
        // Generate 16x16 Bayer matrix recursively from 8x8
        let bayer8: [[Float]] = [
            [0, 32, 8, 40, 2, 34, 10, 42],
            [48, 16, 56, 24, 50, 18, 58, 26],
            [12, 44, 4, 36, 14, 46, 6, 38],
            [60, 28, 52, 20, 62, 30, 54, 22],
            [3, 35, 11, 43, 1, 33, 9, 41],
            [51, 19, 59, 27, 49, 17, 57, 25],
            [15, 47, 7, 39, 13, 45, 5, 37],
            [63, 31, 55, 23, 61, 29, 53, 21]
        ]
        var result = [[Float]](repeating: [Float](repeating: 0, count: 16), count: 16)
        for y in 0..<16 {
            for x in 0..<16 {
                let baseVal = bayer8[y % 8][x % 8]
                let quadrant = (y / 8) * 2 + (x / 8)
                let offset: Float = [0, 128, 192, 64][quadrant]
                result[y][x] = baseVal * 4 + offset
            }
        }
        return result
    }

    private func generateBlueNoise8x8() -> [[Float]] {
        // Blue noise pattern - more visually pleasing than Bayer
        return [
            [34, 29, 17, 21, 30, 35, 12, 6],
            [10, 47, 38, 8, 43, 2, 40, 23],
            [44, 3, 24, 52, 15, 56, 19, 51],
            [18, 59, 14, 32, 46, 26, 37, 7],
            [55, 27, 49, 4, 60, 11, 57, 42],
            [1, 36, 20, 41, 22, 50, 28, 16],
            [63, 9, 54, 31, 53, 5, 45, 61],
            [25, 48, 13, 58, 0, 39, 33, 62]
        ]
    }

    private func generateBlueNoise16x16() -> [[Float]] {
        // Extended blue noise pattern
        let blue8 = generateBlueNoise8x8()
        var result = [[Float]](repeating: [Float](repeating: 0, count: 16), count: 16)
        for y in 0..<16 {
            for x in 0..<16 {
                let baseVal = blue8[y % 8][x % 8]
                let quadrant = (y / 8) * 2 + (x / 8)
                let offset: Float = [0, 64, 192, 128][quadrant]
                result[y][x] = baseVal * 4 + offset
            }
        }
        return result
    }

    private func applyNoiseDither(_ pixels: inout [[Float]], width: Int, height: Int, amount: Double) {
        let strength = Float(amount) * 0.1
        for i in 0..<(width * height) {
            let noise = (Float.random(in: 0...1) - 0.5) * strength
            pixels[i][0] = min(1, max(0, pixels[i][0] + noise))
            pixels[i][1] = min(1, max(0, pixels[i][1] + noise))
            pixels[i][2] = min(1, max(0, pixels[i][2] + noise))
        }
    }

    private func diffuseError(_ pixels: inout [[Float]], x: Int, y: Int, width: Int, height: Int,
                              errR: Float, errG: Float, errB: Float, algorithm: String) {
        if algorithm == "Floyd-Steinberg" {
            // Right: 7/16
            if x + 1 < width {
                pixels[y * width + x + 1][0] += errR * 7.0 / 16.0
                pixels[y * width + x + 1][1] += errG * 7.0 / 16.0
                pixels[y * width + x + 1][2] += errB * 7.0 / 16.0
            }
            if y + 1 < height {
                // Bottom-left: 3/16
                if x > 0 {
                    pixels[(y + 1) * width + x - 1][0] += errR * 3.0 / 16.0
                    pixels[(y + 1) * width + x - 1][1] += errG * 3.0 / 16.0
                    pixels[(y + 1) * width + x - 1][2] += errB * 3.0 / 16.0
                }
                // Bottom: 5/16
                pixels[(y + 1) * width + x][0] += errR * 5.0 / 16.0
                pixels[(y + 1) * width + x][1] += errG * 5.0 / 16.0
                pixels[(y + 1) * width + x][2] += errB * 5.0 / 16.0
                // Bottom-right: 1/16
                if x + 1 < width {
                    pixels[(y + 1) * width + x + 1][0] += errR * 1.0 / 16.0
                    pixels[(y + 1) * width + x + 1][1] += errG * 1.0 / 16.0
                    pixels[(y + 1) * width + x + 1][2] += errB * 1.0 / 16.0
                }
            }
        } else if algorithm == "Atkinson" {
            let factor: Float = 1.0 / 8.0
            // Right
            if x + 1 < width {
                pixels[y * width + x + 1][0] += errR * factor
                pixels[y * width + x + 1][1] += errG * factor
                pixels[y * width + x + 1][2] += errB * factor
            }
            if x + 2 < width {
                pixels[y * width + x + 2][0] += errR * factor
                pixels[y * width + x + 2][1] += errG * factor
                pixels[y * width + x + 2][2] += errB * factor
            }
            if y + 1 < height {
                if x > 0 {
                    pixels[(y + 1) * width + x - 1][0] += errR * factor
                    pixels[(y + 1) * width + x - 1][1] += errG * factor
                    pixels[(y + 1) * width + x - 1][2] += errB * factor
                }
                pixels[(y + 1) * width + x][0] += errR * factor
                pixels[(y + 1) * width + x][1] += errG * factor
                pixels[(y + 1) * width + x][2] += errB * factor
                if x + 1 < width {
                    pixels[(y + 1) * width + x + 1][0] += errR * factor
                    pixels[(y + 1) * width + x + 1][1] += errG * factor
                    pixels[(y + 1) * width + x + 1][2] += errB * factor
                }
            }
            if y + 2 < height {
                pixels[(y + 2) * width + x][0] += errR * factor
                pixels[(y + 2) * width + x][1] += errG * factor
                pixels[(y + 2) * width + x][2] += errB * factor
            }
        }
    }

    private func diffuseErrorMC(_ pixels: inout [[Float]], x: Int, y: Int, width: Int, height: Int,
                                errR: Float, errG: Float, errB: Float, algorithm: String) {
        // Same as diffuseError but for multicolor (160 wide)
        diffuseError(&pixels, x: x, y: y, width: width, height: height,
                    errR: errR, errG: errG, errB: errB, algorithm: algorithm)
    }

    // MARK: - Contrast Processing

    private func applyContrastProcessing(_ pixels: inout [[Float]], width: Int, height: Int, mode: String) {
        switch mode {
        case "HE":
            applyHistogramEqualization(&pixels, width: width, height: height)
        case "CLAHE":
            applyCLAHE(&pixels, width: width, height: height, clipLimit: 3.0)
        case "SWAHE":
            applySWAHE(&pixels, width: width, height: height, windowSize: 40)
        default:
            break
        }
    }

    private func applyHistogramEqualization(_ pixels: inout [[Float]], width: Int, height: Int) {
        // Simple histogram equalization on luminance channel
        let total = width * height

        // Build luminance histogram
        var histogram = [Int](repeating: 0, count: 256)
        for i in 0..<total {
            let luma = 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2]
            let bin = min(255, max(0, Int(luma * 255)))
            histogram[bin] += 1
        }

        // Build CDF
        var cdf = [Float](repeating: 0, count: 256)
        var cumulative = 0
        for i in 0..<256 {
            cumulative += histogram[i]
            cdf[i] = Float(cumulative) / Float(total)
        }

        // Apply equalization
        for i in 0..<total {
            let r = pixels[i][0]
            let g = pixels[i][1]
            let b = pixels[i][2]
            let luma = 0.299 * r + 0.587 * g + 0.114 * b
            let bin = min(255, max(0, Int(luma * 255)))
            let newLuma = cdf[bin]

            // Adjust RGB to match new luminance while preserving color ratios
            if luma > 0.001 {
                let scale = newLuma / luma
                pixels[i][0] = min(1, max(0, r * scale))
                pixels[i][1] = min(1, max(0, g * scale))
                pixels[i][2] = min(1, max(0, b * scale))
            } else {
                pixels[i][0] = newLuma
                pixels[i][1] = newLuma
                pixels[i][2] = newLuma
            }
        }
    }

    private func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int, clipLimit: Float) {
        // Contrast Limited Adaptive Histogram Equalization
        let tileWidth = 40
        let tileHeight = 25
        let tilesX = (width + tileWidth - 1) / tileWidth
        let tilesY = (height + tileHeight - 1) / tileHeight

        // Process each tile
        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let startX = tx * tileWidth
                let startY = ty * tileHeight
                let endX = min(startX + tileWidth, width)
                let endY = min(startY + tileHeight, height)
                let tilePixels = (endX - startX) * (endY - startY)

                // Build histogram for this tile
                var histogram = [Int](repeating: 0, count: 256)
                for y in startY..<endY {
                    for x in startX..<endX {
                        let idx = y * width + x
                        let luma = 0.299 * pixels[idx][0] + 0.587 * pixels[idx][1] + 0.114 * pixels[idx][2]
                        let bin = min(255, max(0, Int(luma * 255)))
                        histogram[bin] += 1
                    }
                }

                // Clip histogram
                let clipThreshold = Int(clipLimit * Float(tilePixels) / 256.0)
                var excess = 0
                for i in 0..<256 {
                    if histogram[i] > clipThreshold {
                        excess += histogram[i] - clipThreshold
                        histogram[i] = clipThreshold
                    }
                }

                // Redistribute excess
                let increment = excess / 256
                for i in 0..<256 {
                    histogram[i] += increment
                }

                // Build CDF
                var cdf = [Float](repeating: 0, count: 256)
                var cumulative = 0
                for i in 0..<256 {
                    cumulative += histogram[i]
                    cdf[i] = Float(cumulative) / Float(tilePixels)
                }

                // Apply to tile
                for y in startY..<endY {
                    for x in startX..<endX {
                        let idx = y * width + x
                        let r = pixels[idx][0]
                        let g = pixels[idx][1]
                        let b = pixels[idx][2]
                        let luma = 0.299 * r + 0.587 * g + 0.114 * b
                        let bin = min(255, max(0, Int(luma * 255)))
                        let newLuma = cdf[bin]

                        if luma > 0.001 {
                            let scale = newLuma / luma
                            pixels[idx][0] = min(1, max(0, r * scale))
                            pixels[idx][1] = min(1, max(0, g * scale))
                            pixels[idx][2] = min(1, max(0, b * scale))
                        }
                    }
                }
            }
        }
    }

    private func applySWAHE(_ pixels: inout [[Float]], width: Int, height: Int, windowSize: Int) {
        // Optimized Sliding Window Adaptive Histogram Equalization
        // Uses incremental histogram updates instead of rebuilding from scratch
        let halfWindow = windowSize / 2
        var result = pixels

        // Pre-compute luma values for all pixels (avoids repeated calculation)
        var lumaBins = [Int](repeating: 0, count: width * height)
        for i in 0..<pixels.count {
            let luma = 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2]
            lumaBins[i] = min(255, max(0, Int(luma * 255)))
        }

        // Pre-compute CDF lookup table (cumulative sum up to each bin)
        func computeCDF(_ histogram: [Int]) -> [Int] {
            var cdf = [Int](repeating: 0, count: 256)
            cdf[0] = histogram[0]
            for i in 1..<256 {
                cdf[i] = cdf[i-1] + histogram[i]
            }
            return cdf
        }

        for y in 0..<height {
            let startY = max(0, y - halfWindow)
            let endY = min(height, y + halfWindow + 1)

            // Initialize histogram for first pixel in row
            var histogram = [Int](repeating: 0, count: 256)
            var windowPixels = 0

            let initialEndX = min(width, halfWindow + 1)
            for wy in startY..<endY {
                for wx in 0..<initialEndX {
                    histogram[lumaBins[wy * width + wx]] += 1
                    windowPixels += 1
                }
            }

            for x in 0..<width {
                // Slide window: add new right column, remove old left column
                if x > 0 {
                    let addX = x + halfWindow
                    let removeX = x - halfWindow - 1

                    // Add new right column
                    if addX < width {
                        for wy in startY..<endY {
                            histogram[lumaBins[wy * width + addX]] += 1
                            windowPixels += 1
                        }
                    }

                    // Remove old left column
                    if removeX >= 0 {
                        for wy in startY..<endY {
                            histogram[lumaBins[wy * width + removeX]] -= 1
                            windowPixels -= 1
                        }
                    }
                }

                // Calculate CDF value for current pixel using precomputed CDF
                let idx = y * width + x
                let bin = lumaBins[idx]

                // Compute cumulative up to this bin
                var cumulative = 0
                for i in 0...bin {
                    cumulative += histogram[i]
                }
                let newLuma = Float(cumulative) / Float(windowPixels)

                let r = pixels[idx][0]
                let g = pixels[idx][1]
                let b = pixels[idx][2]
                let luma = 0.299 * r + 0.587 * g + 0.114 * b

                if luma > 0.001 {
                    let scale = newLuma / luma
                    result[idx][0] = min(1, max(0, r * scale))
                    result[idx][1] = min(1, max(0, g * scale))
                    result[idx][2] = min(1, max(0, b * scale))
                }
            }
        }

        pixels = result
    }

    // MARK: - Image Filters

    private func applyImageFilter(_ pixels: inout [[Float]], width: Int, height: Int, filter: String) {
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
                result[idx][0] = min(1, max(0, sumR))
                result[idx][1] = min(1, max(0, sumG))
                result[idx][2] = min(1, max(0, sumB))
            }
        }

        pixels = result
    }

    private func applyEdgeFilter(_ pixels: inout [[Float]], width: Int, height: Int) {
        // Sobel edge detection blended with original
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
                result[idx][0] = min(1, max(0, (pixels[idx][0] + edgeR) * 0.5))
                result[idx][1] = min(1, max(0, (pixels[idx][1] + edgeG) * 0.5))
                result[idx][2] = min(1, max(0, (pixels[idx][2] + edgeB) * 0.5))
            }
        }

        pixels = result
    }

    // MARK: - Pixel Reading (same approach as AppleIIGSConverter)

    private func getPixelData(from sourceImage: NSImage, width: Int, height: Int,
                               saturation: Double, gamma: Double) throws -> [[Float]] {
        // Try to get CGImage from source and draw it directly
        guard let cgImage = getCGImage(from: sourceImage) else {
            throw NSError(domain: "C64Converter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from source"])
        }

        // Create a bitmap context to draw and read pixels
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        guard let ctx = CGContext(data: &bytes, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: width * 4,
                                   space: colorSpace, bitmapInfo: bitmapInfo) else {
            throw NSError(domain: "C64Converter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
        }

        // Draw cgImage scaled to target size
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert bytes to float array (0-1 range)
        var pixels = [[Float]](repeating: [Float](repeating: 0, count: 3), count: width * height)

        for i in 0..<(width * height) {
            let alpha = Float(bytes[i * 4 + 3])
            var r: Float, g: Float, b: Float

            if alpha > 0 {
                // Unpremultiply alpha and convert to 0-1 range
                r = Float(bytes[i * 4]) / alpha
                g = Float(bytes[i * 4 + 1]) / alpha
                b = Float(bytes[i * 4 + 2]) / alpha
            } else {
                r = Float(bytes[i * 4]) / 255.0
                g = Float(bytes[i * 4 + 1]) / 255.0
                b = Float(bytes[i * 4 + 2]) / 255.0
            }

            // Apply gamma correction
            if gamma != 1.0 {
                r = pow(r, Float(gamma))
                g = pow(g, Float(gamma))
                b = pow(b, Float(gamma))
            }

            // Apply saturation
            if saturation != 1.0 {
                let gray = 0.299 * r + 0.587 * g + 0.114 * b
                r = gray + Float(saturation) * (r - gray)
                g = gray + Float(saturation) * (g - gray)
                b = gray + Float(saturation) * (b - gray)
            }

            // Clamp values to 0-1
            r = max(0, min(1, r))
            g = max(0, min(1, g))
            b = max(0, min(1, b))

            pixels[i] = [r, g, b]
        }

        return pixels
    }

    // Helper to get CGImage from NSImage
    private func getCGImage(from image: NSImage) -> CGImage? {
        // Try direct cgImage access first
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }

        // Fallback: draw to bitmap and get cgImage
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return nil }

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: Int(size.width) * 4,
            bitsPerPixel: 32
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.cgImage
    }
}
