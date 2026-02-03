import Cocoa

class Plus4Converter: RetroMachine {
    var name: String = "Plus/4"

    var options: [ConversionOption] = [
        // 1. GRAPHICS MODE
        ConversionOption(
            label: "Graphics Mode",
            key: "mode",
            values: ["HiRes (320×200)", "Multicolor (160×200)"],
            selectedValue: "HiRes (320×200)"
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

        // 6. PIXEL MERGE (for Multicolor)
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

    // Plus/4 palette: 128 colors (16 hues × 8 luminance levels)
    // From Plus4Renderer.java - stored as BGR in original
    static let plus4Palette: [[UInt8]] = [
        // Luminance 0 (darkest)
        [0x00, 0x00, 0x00], [0x17, 0x17, 0x17], [0x0a, 0x07, 0x46], [0x26, 0x2a, 0x00],
        [0x46, 0x02, 0x3e], [0x00, 0x33, 0x00], [0x70, 0x0d, 0x0f], [0x00, 0x21, 0x1f],
        [0x00, 0x0e, 0x3e], [0x00, 0x17, 0x30], [0x00, 0x2b, 0x0f], [0x26, 0x03, 0x46],
        [0x0a, 0x31, 0x00], [0x61, 0x17, 0x03], [0x70, 0x07, 0x1f], [0x00, 0x31, 0x03],
        // Luminance 1
        [0x00, 0x00, 0x00], [0x26, 0x26, 0x26], [0x17, 0x14, 0x59], [0x37, 0x3b, 0x01],
        [0x59, 0x0c, 0x51], [0x01, 0x45, 0x05], [0x85, 0x1c, 0x1e], [0x00, 0x32, 0x30],
        [0x01, 0x1c, 0x51], [0x00, 0x27, 0x42], [0x00, 0x3c, 0x1e], [0x37, 0x0e, 0x59],
        [0x17, 0x42, 0x01], [0x75, 0x26, 0x0f], [0x85, 0x13, 0x30], [0x00, 0x43, 0x0f],
        // Luminance 2
        [0x00, 0x00, 0x00], [0x37, 0x37, 0x37], [0x27, 0x23, 0x6d], [0x49, 0x4e, 0x0c],
        [0x6d, 0x1b, 0x64], [0x0c, 0x58, 0x12], [0x9b, 0x2c, 0x2e], [0x00, 0x44, 0x41],
        [0x0c, 0x2c, 0x64], [0x00, 0x38, 0x55], [0x00, 0x4e, 0x2e], [0x49, 0x1d, 0x6d],
        [0x27, 0x55, 0x0c], [0x8a, 0x37, 0x1d], [0x9b, 0x22, 0x41], [0x00, 0x56, 0x1d],
        // Luminance 3
        [0x00, 0x00, 0x00], [0x4a, 0x4a, 0x4a], [0x38, 0x33, 0x81], [0x5d, 0x61, 0x1a],
        [0x82, 0x2a, 0x79], [0x1a, 0x6c, 0x20], [0xb1, 0x3d, 0x3f], [0x00, 0x57, 0x54],
        [0x1a, 0x3d, 0x79], [0x07, 0x4a, 0x68], [0x00, 0x62, 0x3f], [0x5d, 0x2d, 0x81],
        [0x38, 0x69, 0x1a], [0xa0, 0x49, 0x2d], [0xb1, 0x33, 0x54], [0x07, 0x69, 0x2d],
        // Luminance 4
        [0x00, 0x00, 0x00], [0x7b, 0x7b, 0x7b], [0x67, 0x62, 0xb8], [0x90, 0x96, 0x44],
        [0xb9, 0x58, 0xaf], [0x44, 0xa1, 0x4c], [0xeb, 0x6d, 0x70], [0x1f, 0x8a, 0x87],
        [0x44, 0x6e, 0xaf], [0x2b, 0x7c, 0x9d], [0x1f, 0x96, 0x70], [0x90, 0x5a, 0xb8],
        [0x67, 0x9e, 0x44], [0xd9, 0x7b, 0x5b], [0xeb, 0x62, 0x87], [0x2b, 0x9e, 0x5b],
        // Luminance 5
        [0x00, 0x00, 0x00], [0x9b, 0x9b, 0x9b], [0x86, 0x81, 0xdb], [0xb1, 0xb7, 0x61],
        [0xdc, 0x76, 0xd1], [0x60, 0xc3, 0x69], [0xff, 0x8c, 0x8f], [0x38, 0xab, 0xa8],
        [0x60, 0x8d, 0xd1], [0x45, 0x9c, 0xbf], [0x38, 0xb7, 0x8f], [0xb1, 0x79, 0xdb],
        [0x86, 0xc0, 0x61], [0xfd, 0x9b, 0x79], [0xff, 0x80, 0xa8], [0x45, 0xc0, 0x79],
        // Luminance 6
        [0x00, 0x00, 0x00], [0xe0, 0xe0, 0xe0], [0xc9, 0xc3, 0xff], [0xf8, 0xfe, 0xa0],
        [0xff, 0xb7, 0xff], [0x9f, 0xff, 0xa9], [0xff, 0xd0, 0xd3], [0x71, 0xf1, 0xed],
        [0x9f, 0xd1, 0xff], [0x81, 0xe0, 0xff], [0x71, 0xfe, 0xd3], [0xf8, 0xba, 0xff],
        [0xc9, 0xff, 0xa0], [0xff, 0xe0, 0xbb], [0xff, 0xc3, 0xed], [0x81, 0xff, 0xbb],
        // Luminance 7 (brightest)
        [0x00, 0x00, 0x00], [0xff, 0xff, 0xff], [0xff, 0xff, 0xff], [0xff, 0xff, 0xfd],
        [0xff, 0xff, 0xff], [0xfd, 0xff, 0xff], [0xff, 0xff, 0xff], [0xc9, 0xff, 0xff],
        [0xfd, 0xff, 0xff], [0xdb, 0xff, 0xff], [0xc9, 0xff, 0xff], [0xff, 0xff, 0xff],
        [0xff, 0xff, 0xfd], [0xff, 0xff, 0xff], [0xff, 0xff, 0xff], [0xdb, 0xff, 0xff]
    ]

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        let mode = opts.first(where: { $0.key == "mode" })?.selectedValue ?? "HiRes (320×200)"
        let ditherAlg = opts.first(where: { $0.key == "dither" })?.selectedValue ?? "Bayer 2x2"
        let ditherAmount = Double(opts.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrastMode = opts.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filterMode = opts.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let pixelMerge = opts.first(where: { $0.key == "pixel_merge" })?.selectedValue ?? "Average"
        let colorMatch = opts.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(opts.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(opts.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        let isMulticolor = mode.contains("Multicolor")
        let screenWidth = 320
        let screenHeight = 200

        guard var pixels = getPixelData(from: sourceImage, width: screenWidth, height: screenHeight) else {
            throw NSError(domain: "Plus4Converter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get pixel data"])
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

        // Convert based on mode
        var resultPixels: [UInt8]
        var nativeData: Data
        var fileExtension: String

        if isMulticolor {
            (resultPixels, nativeData) = convertMulticolor(pixels: pixels, width: screenWidth, height: screenHeight,
                                                            ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                            colorMatch: colorMatch, pixelMerge: pixelMerge)
            fileExtension = "prg"
        } else {
            (resultPixels, nativeData) = convertHiRes(pixels: pixels, width: screenWidth, height: screenHeight,
                                                       ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                       colorMatch: colorMatch)
            fileExtension = "prg"
        }

        // Create preview image (doubled for better visibility)
        let previewWidth = screenWidth * 2
        let previewHeight = screenHeight * 2

        var previewBytes = [UInt8](repeating: 255, count: previewWidth * previewHeight * 4)

        for y in 0..<screenHeight {
            for x in 0..<screenWidth {
                let srcOffset = (y * screenWidth + x) * 3
                let r = resultPixels[srcOffset]
                let g = resultPixels[srcOffset + 1]
                let b = resultPixels[srcOffset + 2]

                for dy in 0..<2 {
                    for dx in 0..<2 {
                        let px = x * 2 + dx
                        let py = y * 2 + dy
                        let dstOffset = (py * previewWidth + px) * 4
                        previewBytes[dstOffset] = r
                        previewBytes[dstOffset + 1] = g
                        previewBytes[dstOffset + 2] = b
                        previewBytes[dstOffset + 3] = 255
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &previewBytes,
                                       width: previewWidth,
                                       height: previewHeight,
                                       bitsPerComponent: 8,
                                       bytesPerRow: previewWidth * 4,
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cgImage = context.makeImage() else {
            throw NSError(domain: "Plus4Converter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview"])
        }

        let previewImage = NSImage(cgImage: cgImage, size: NSSize(width: previewWidth, height: previewHeight))

        // Save native file
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("plus4_\(uuid).\(fileExtension)")
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

    // MARK: - HiRes Conversion (320×200, 2 colors per 8×8 cell)

    private func convertHiRes(pixels: [[Float]], width: Int, height: Int,
                              ditherAlg: String, ditherAmount: Double,
                              colorMatch: String) -> ([UInt8], Data) {
        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)
        var bitmap = [UInt8](repeating: 0, count: 8000)
        var screen = [UInt8](repeating: 0, count: 1000)
        var nibble = [UInt8](repeating: 0, count: 1000)

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"

        // Process 8×8 character cells
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                // Analyze cell to find best 2 colors
                var colorCounts = [Int: Int]()

                for y0 in 0..<8 {
                    for x0 in 0..<8 {
                        let x = cellX * 8 + x0
                        let y = cellY * 8 + y0
                        let r = Int(pixels[y * width + x][0])
                        let g = Int(pixels[y * width + x][1])
                        let b = Int(pixels[y * width + x][2])

                        let colorIndex = findClosestPaletteColor(r: r, g: g, b: b, method: colorMatch)
                        colorCounts[colorIndex, default: 0] += 1
                    }
                }

                // Get two most common colors
                let sortedColors = colorCounts.sorted { $0.value > $1.value }
                let fg = sortedColors.count > 0 ? sortedColors[0].key : 0
                let bg = sortedColors.count > 1 ? sortedColors[1].key : 0

                // Encode colors (hue in screen, luminance in nibble)
                let fgLuma = fg / 16
                let fgHue = fg % 16
                let bgLuma = bg / 16
                let bgHue = bg % 16

                let cellIndex = cellY * 40 + cellX
                screen[cellIndex] = UInt8((fgHue << 4) | bgHue)
                nibble[cellIndex] = UInt8((bgLuma << 4) | fgLuma)

                // Create work array for error diffusion
                var work = [[Int]](repeating: [0, 0, 0], count: 64)
                for y0 in 0..<8 {
                    for x0 in 0..<8 {
                        let x = cellX * 8 + x0
                        let y = cellY * 8 + y0
                        work[y0 * 8 + x0] = [Int(pixels[y * width + x][0]),
                                             Int(pixels[y * width + x][1]),
                                             Int(pixels[y * width + x][2])]
                    }
                }

                // Convert each pixel in cell
                for y0 in 0..<8 {
                    var rowByte: UInt8 = 0

                    for x0 in 0..<8 {
                        let x = cellX * 8 + x0
                        let y = cellY * 8 + y0

                        let r = max(0, min(255, work[y0 * 8 + x0][0]))
                        let g = max(0, min(255, work[y0 * 8 + x0][1]))
                        let b = max(0, min(255, work[y0 * 8 + x0][2]))

                        // Choose between fg and bg
                        let fgColor = Self.plus4Palette[fg]
                        let bgColor = Self.plus4Palette[bg]

                        let distFg = colorDistance(r1: r, g1: g, b1: b,
                                                   r2: Int(fgColor[0]), g2: Int(fgColor[1]), b2: Int(fgColor[2]),
                                                   method: colorMatch)
                        let distBg = colorDistance(r1: r, g1: g, b1: b,
                                                   r2: Int(bgColor[0]), g2: Int(bgColor[1]), b2: Int(bgColor[2]),
                                                   method: colorMatch)

                        let chosenColor: [UInt8]
                        if distFg < distBg {
                            chosenColor = fgColor
                            rowByte |= (0x80 >> x0)
                        } else {
                            chosenColor = bgColor
                        }

                        // Store result
                        let pixelOffset = (y * width + x) * 3
                        resultPixels[pixelOffset] = chosenColor[0]
                        resultPixels[pixelOffset + 1] = chosenColor[1]
                        resultPixels[pixelOffset + 2] = chosenColor[2]

                        // Error diffusion within cell
                        if useErrorDiffusion {
                            let rErr = r - Int(chosenColor[0])
                            let gErr = g - Int(chosenColor[1])
                            let bErr = b - Int(chosenColor[2])

                            distributeError(&work, x0: x0, y0: y0, cellWidth: 8, cellHeight: 8,
                                          rErr: rErr, gErr: gErr, bErr: bErr,
                                          algorithm: ditherAlg, amount: ditherAmount)
                        }
                    }

                    // Store bitmap byte
                    let bitmapIndex = cellY * 320 + cellX * 8 + y0
                    bitmap[bitmapIndex] = rowByte
                }
            }
        }

        // Create native file: nibble + screen + bitmap
        var nativeData = Data()
        nativeData.append(contentsOf: nibble)
        nativeData.append(contentsOf: screen)
        nativeData.append(contentsOf: bitmap)

        return (resultPixels, nativeData)
    }

    // MARK: - Multicolor Conversion (160×200, 4 colors per 4×8 cell)

    private func convertMulticolor(pixels: [[Float]], width: Int, height: Int,
                                   ditherAlg: String, ditherAmount: Double,
                                   colorMatch: String, pixelMerge: String) -> ([UInt8], Data) {
        var resultPixels = [UInt8](repeating: 0, count: width * height * 3)
        var bitmap = [UInt8](repeating: 0, count: 8000)
        var screen = [UInt8](repeating: 0, count: 1000)
        var nibble = [UInt8](repeating: 0, count: 1000)

        // First shrink 320 -> 160 and find global background colors
        var shrunkPixels = [[Int]](repeating: [0, 0, 0], count: 160 * height)
        var globalColorCounts = [Int: Int]()

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

                let colorIndex = findClosestPaletteColor(r: r, g: g, b: b, method: colorMatch)
                globalColorCounts[colorIndex, default: 0] += 1
            }
        }

        // Get two most common colors as global background
        let sortedGlobal = globalColorCounts.sorted { $0.value > $1.value }
        let bgColor1 = sortedGlobal.count > 0 ? sortedGlobal[0].key : 0
        let bgColor2 = sortedGlobal.count > 1 ? sortedGlobal[1].key : 0

        // Process 4×8 character cells
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                // Count colors in this cell
                var cellColorCounts = [Int: Int]()

                for y0 in 0..<8 {
                    for x0 in 0..<4 {
                        let x = cellX * 4 + x0
                        let y = cellY * 8 + y0
                        let pixel = shrunkPixels[y * 160 + x]
                        let colorIndex = findClosestPaletteColor(r: pixel[0], g: pixel[1], b: pixel[2], method: colorMatch)
                        cellColorCounts[colorIndex, default: 0] += 1
                    }
                }

                // Get two most common cell colors
                let sortedCell = cellColorCounts.sorted { $0.value > $1.value }
                let cellColor1 = sortedCell.count > 0 ? sortedCell[0].key : 0
                let cellColor2 = sortedCell.count > 1 ? sortedCell[1].key : 0

                // Build 4-color palette for this cell
                let cellPalette = [bgColor1, cellColor1, cellColor2, bgColor2]

                // Encode colors
                let c1Luma = cellColor1 / 16
                let c1Hue = cellColor1 % 16
                let c2Luma = cellColor2 / 16
                let c2Hue = cellColor2 % 16

                let cellIndex = cellY * 40 + cellX
                screen[cellIndex] = UInt8((c1Hue << 4) | c2Hue)
                nibble[cellIndex] = UInt8((c2Luma << 4) | c1Luma)

                // Convert each pixel in cell
                for y0 in 0..<8 {
                    var rowByte: UInt8 = 0

                    for x0 in 0..<4 {
                        let x = cellX * 4 + x0
                        let y = cellY * 8 + y0
                        let pixel = shrunkPixels[y * 160 + x]

                        // Find best color from 4-color palette
                        var bestPaletteIndex = 0
                        var bestDist = Float.greatestFiniteMagnitude

                        for i in 0..<4 {
                            let palColor = Self.plus4Palette[cellPalette[i]]
                            let dist = colorDistance(r1: pixel[0], g1: pixel[1], b1: pixel[2],
                                                    r2: Int(palColor[0]), g2: Int(palColor[1]), b2: Int(palColor[2]),
                                                    method: colorMatch)
                            if dist < bestDist {
                                bestDist = dist
                                bestPaletteIndex = i
                            }
                        }

                        // Pack 2 bits per pixel (4 pixels per byte)
                        rowByte |= UInt8(bestPaletteIndex << (6 - x0 * 2))

                        // Store result (double pixels horizontally)
                        let chosenColor = Self.plus4Palette[cellPalette[bestPaletteIndex]]
                        let px1 = cellX * 8 + x0 * 2
                        let px2 = px1 + 1
                        let py = cellY * 8 + y0

                        resultPixels[(py * width + px1) * 3] = chosenColor[0]
                        resultPixels[(py * width + px1) * 3 + 1] = chosenColor[1]
                        resultPixels[(py * width + px1) * 3 + 2] = chosenColor[2]

                        resultPixels[(py * width + px2) * 3] = chosenColor[0]
                        resultPixels[(py * width + px2) * 3 + 1] = chosenColor[1]
                        resultPixels[(py * width + px2) * 3 + 2] = chosenColor[2]
                    }

                    // Store bitmap byte
                    let bitmapIndex = cellY * 320 + cellX * 8 + y0
                    bitmap[bitmapIndex] = rowByte
                }
            }
        }

        // Create native file with background colors
        var nativeData = Data()
        nativeData.append(UInt8(bgColor1))
        nativeData.append(UInt8(bgColor2))
        nativeData.append(contentsOf: nibble)
        nativeData.append(contentsOf: screen)
        nativeData.append(contentsOf: bitmap)

        return (resultPixels, nativeData)
    }

    // MARK: - Color Matching

    private func findClosestPaletteColor(r: Int, g: Int, b: Int, method: String) -> Int {
        var bestIndex = 0
        var bestDist = Float.greatestFiniteMagnitude

        for i in 0..<Self.plus4Palette.count {
            let dist = colorDistance(r1: r, g1: g, b1: b,
                                    r2: Int(Self.plus4Palette[i][0]),
                                    g2: Int(Self.plus4Palette[i][1]),
                                    b2: Int(Self.plus4Palette[i][2]),
                                    method: method)
            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        return bestIndex
    }

    private func colorDistance(r1: Int, g1: Int, b1: Int, r2: Int, g2: Int, b2: Int, method: String) -> Float {
        let dr = Float(r1 - r2)
        let dg = Float(g1 - g2)
        let db = Float(b1 - b2)

        switch method {
        case "Perceptive":
            let rmean = Float(r1 + r2) / 2.0
            return sqrt((2.0 + rmean / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rmean) / 256.0) * db * db)
        case "Luma":
            let ly1 = Float(r1) * 0.299 + Float(g1) * 0.587 + Float(b1) * 0.114
            let ly2 = Float(r2) * 0.299 + Float(g2) * 0.587 + Float(b2) * 0.114
            return abs(ly1 - ly2)
        case "Chroma":
            let c1 = sqrt(Float(r1 * r1 + g1 * g1 + b1 * b1))
            let c2 = sqrt(Float(r2 * r2 + g2 * g2 + b2 * b2))
            return abs(c1 - c2)
        default: // Euclidean
            return dr * dr + dg * dg + db * db
        }
    }

    private func distributeError(_ work: inout [[Int]], x0: Int, y0: Int, cellWidth: Int, cellHeight: Int,
                                 rErr: Int, gErr: Int, bErr: Int, algorithm: String, amount: Double) {
        let factor = Float(amount)

        if algorithm == "Floyd-Steinberg" {
            if x0 + 1 < cellWidth {
                work[y0 * cellWidth + x0 + 1][0] += Int(Float(rErr) * 7.0 / 16.0 * factor)
                work[y0 * cellWidth + x0 + 1][1] += Int(Float(gErr) * 7.0 / 16.0 * factor)
                work[y0 * cellWidth + x0 + 1][2] += Int(Float(bErr) * 7.0 / 16.0 * factor)
            }
            if y0 + 1 < cellHeight {
                if x0 > 0 {
                    work[(y0 + 1) * cellWidth + x0 - 1][0] += Int(Float(rErr) * 3.0 / 16.0 * factor)
                    work[(y0 + 1) * cellWidth + x0 - 1][1] += Int(Float(gErr) * 3.0 / 16.0 * factor)
                    work[(y0 + 1) * cellWidth + x0 - 1][2] += Int(Float(bErr) * 3.0 / 16.0 * factor)
                }
                work[(y0 + 1) * cellWidth + x0][0] += Int(Float(rErr) * 5.0 / 16.0 * factor)
                work[(y0 + 1) * cellWidth + x0][1] += Int(Float(gErr) * 5.0 / 16.0 * factor)
                work[(y0 + 1) * cellWidth + x0][2] += Int(Float(bErr) * 5.0 / 16.0 * factor)
                if x0 + 1 < cellWidth {
                    work[(y0 + 1) * cellWidth + x0 + 1][0] += Int(Float(rErr) * 1.0 / 16.0 * factor)
                    work[(y0 + 1) * cellWidth + x0 + 1][1] += Int(Float(gErr) * 1.0 / 16.0 * factor)
                    work[(y0 + 1) * cellWidth + x0 + 1][2] += Int(Float(bErr) * 1.0 / 16.0 * factor)
                }
            }
        } else if algorithm == "Atkinson" {
            let f = factor / 8.0
            let offsets = [(1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)]
            for (dx, dy) in offsets {
                let nx = x0 + dx
                let ny = y0 + dy
                if nx >= 0 && nx < cellWidth && ny < cellHeight {
                    work[ny * cellWidth + nx][0] += Int(Float(rErr) * f)
                    work[ny * cellWidth + nx][1] += Int(Float(gErr) * f)
                    work[ny * cellWidth + nx][2] += Int(Float(bErr) * f)
                }
            }
        }
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
            applyCLAHE(&pixels, width: width, height: height)
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
        for i in 1..<256 { cdf[i] = cdf[i - 1] + histogram[i] }

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

    private func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int) {
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
                    let luma = Int(pixels[wy * width + wx][0] * 0.299 + pixels[wy * width + wx][1] * 0.587 + pixels[wy * width + wx][2] * 0.114)
                    histogram[max(0, min(255, luma))] += 1
                    count += 1
                }
            }

            for x in 0..<width {
                let x1 = x + halfWindow
                if x1 < width {
                    for wy in y0...y1 {
                        let luma = Int(pixels[wy * width + x1][0] * 0.299 + pixels[wy * width + x1][1] * 0.587 + pixels[wy * width + x1][2] * 0.114)
                        histogram[max(0, min(255, luma))] += 1
                        count += 1
                    }
                }
                let x0m = x - halfWindow - 1
                if x0m >= 0 {
                    for wy in y0...y1 {
                        let luma = Int(pixels[wy * width + x0m][0] * 0.299 + pixels[wy * width + x0m][1] * 0.587 + pixels[wy * width + x0m][2] * 0.114)
                        histogram[max(0, min(255, luma))] -= 1
                        count -= 1
                    }
                }

                let currentLuma = Int(pixels[y * width + x][0] * 0.299 + pixels[y * width + x][1] * 0.587 + pixels[y * width + x][2] * 0.114)
                var cdfValue = 0
                for i in 0...max(0, min(255, currentLuma)) { cdfValue += histogram[i] }
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
        let lowpassKernel: [[Float]] = [[1.0/9.0, 1.0/9.0, 1.0/9.0], [1.0/9.0, 1.0/9.0, 1.0/9.0], [1.0/9.0, 1.0/9.0, 1.0/9.0]]
        let sharpenKernel: [[Float]] = [[0.0, -1.0, 0.0], [-1.0, 5.0, -1.0], [0.0, -1.0, 0.0]]
        let embossKernel: [[Float]] = [[-2.0, -1.0, 0.0], [-1.0, 1.0, 1.0], [0.0, 1.0, 2.0]]

        switch filter {
        case "Lowpass": applyConvolution(&pixels, width: width, height: height, kernel: lowpassKernel)
        case "Sharpen": applyConvolution(&pixels, width: width, height: height, kernel: sharpenKernel)
        case "Emboss": applyConvolution(&pixels, width: width, height: height, kernel: embossKernel)
        case "Edge": applyEdgeFilter(&pixels, width: width, height: height)
        default: break
        }
    }

    private func applyConvolution(_ pixels: inout [[Float]], width: Int, height: Int, kernel: [[Float]]) {
        var result = pixels
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var sumR: Float = 0, sumG: Float = 0, sumB: Float = 0
                for ky in 0..<3 {
                    for kx in 0..<3 {
                        let idx = (y + ky - 1) * width + (x + kx - 1)
                        sumR += pixels[idx][0] * kernel[ky][kx]
                        sumG += pixels[idx][1] * kernel[ky][kx]
                        sumB += pixels[idx][2] * kernel[ky][kx]
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
        let sobelX: [[Float]] = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]]
        let sobelY: [[Float]] = [[-1, -2, -1], [0, 0, 0], [1, 2, 1]]
        var result = pixels

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var gxR: Float = 0, gxG: Float = 0, gxB: Float = 0
                var gyR: Float = 0, gyG: Float = 0, gyB: Float = 0
                for ky in 0..<3 {
                    for kx in 0..<3 {
                        let idx = (y + ky - 1) * width + (x + kx - 1)
                        gxR += pixels[idx][0] * sobelX[ky][kx]
                        gxG += pixels[idx][1] * sobelX[ky][kx]
                        gxB += pixels[idx][2] * sobelX[ky][kx]
                        gyR += pixels[idx][0] * sobelY[ky][kx]
                        gyG += pixels[idx][1] * sobelY[ky][kx]
                        gyB += pixels[idx][2] * sobelY[ky][kx]
                    }
                }
                let idx = y * width + x
                result[idx][0] = max(0, min(255, (pixels[idx][0] + sqrt(gxR * gxR + gyR * gyR)) * 0.5))
                result[idx][1] = max(0, min(255, (pixels[idx][1] + sqrt(gxG * gxG + gyG * gyG)) * 0.5))
                result[idx][2] = max(0, min(255, (pixels[idx][2] + sqrt(gxB * gxB + gyB * gyB)) * 0.5))
            }
        }
        pixels = result
    }

    private func applyOrderedDither(_ pixels: inout [[Float]], width: Int, height: Int, ditherType: String, amount: Double) {
        let matrix: [[Float]]
        let matrixSize: Int

        switch ditherType {
        case "Bayer 2x2": matrix = [[0, 2], [3, 1]]; matrixSize = 2
        case "Bayer 4x4":
            matrix = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
            matrixSize = 4
        case "Bayer 8x8":
            matrix = [
                [0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
                [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
                [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
                [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]
            ]
            matrixSize = 8
        default: return
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
