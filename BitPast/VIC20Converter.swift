import Cocoa

class VIC20Converter: RetroMachine {
    var name: String = "VIC-20"

    var options: [ConversionOption] = [
        // 1. GRAPHICS MODE (from Vic20Config.java: HIRES, LOWRES)
        ConversionOption(
            label: "Graphics Mode",
            key: "mode",
            values: ["HiRes (176×184)", "LowRes (88×184)"],
            selectedValue: "HiRes (176×184)"
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
            selectedValue: "None"
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
            selectedValue: "Sharpen"
        ),

        // 6. PIXEL MERGE (for lowres multicolor)
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

    // VIC-20 palette (from Vic20Renderer.java)
    // First 8 colors can be foreground, all 16 can be background
    static let vic20Palette: [[UInt8]] = [
        [0x00, 0x00, 0x00],  // 0: Black
        [0xFF, 0xFF, 0xFF],  // 1: White
        [0xF0, 0x00, 0x00],  // 2: Red
        [0x00, 0xF0, 0xF0],  // 3: Cyan
        [0x60, 0x00, 0x60],  // 4: Purple
        [0x00, 0xA0, 0x00],  // 5: Green
        [0x00, 0x00, 0xF0],  // 6: Blue
        [0xD0, 0xD0, 0x00],  // 7: Yellow
        [0xC0, 0xA0, 0x00],  // 8: Orange
        [0xFF, 0xA0, 0x00],  // 9: Light Orange
        [0xF0, 0x80, 0x80],  // 10: Light Red (Pink)
        [0x00, 0xFF, 0xFF],  // 11: Light Cyan
        [0xFF, 0x00, 0xFF],  // 12: Light Purple (Magenta)
        [0x00, 0xFF, 0x00],  // 13: Light Green
        [0x00, 0xA0, 0xFF],  // 14: Light Blue
        [0xFF, 0xFF, 0x00]   // 15: Light Yellow
    ]

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) throws -> ConversionResult {
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        // Get options
        let mode = opts.first(where: { $0.key == "mode" })?.selectedValue ?? "HiRes"
        let ditherAlg = opts.first(where: { $0.key == "dither" })?.selectedValue ?? "None"
        let ditherAmount = Double(opts.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "1.0") ?? 1.0
        let contrastMode = opts.first(where: { $0.key == "contrast" })?.selectedValue ?? "SWAHE"
        let filterMode = opts.first(where: { $0.key == "filter" })?.selectedValue ?? "Sharpen"
        let pixelMerge = opts.first(where: { $0.key == "pixel_merge" })?.selectedValue ?? "Average"
        let colorMatch = opts.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(opts.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(opts.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        // VIC-20 screen size: 176x184 (22x23 character cells)
        let screenWidth = 176
        let screenHeight = 184

        // Get pixel data
        var pixels = try getPixelData(from: sourceImage, width: screenWidth, height: screenHeight,
                                       saturation: saturation, gamma: gamma)

        // Apply contrast processing
        if contrastMode != "None" {
            applyContrastProcessing(&pixels, width: screenWidth, height: screenHeight, mode: contrastMode)
        }

        // Apply image filter
        if filterMode != "None" {
            applyImageFilter(&pixels, width: screenWidth, height: screenHeight, filter: filterMode)
        }

        // Apply ordered dithering before color reduction
        if ditherAlg.contains("Bayer") || ditherAlg.contains("Blue") || ditherAlg == "Noise" {
            applyOrderedDither(&pixels, width: screenWidth, height: screenHeight, ditherType: ditherAlg, amount: ditherAmount)
        }

        // Convert based on mode
        var resultPixels: [UInt8]
        var nativeData: Data

        if mode.contains("HiRes") {
            (resultPixels, nativeData) = convertHiRes(pixels: pixels, width: screenWidth, height: screenHeight,
                                                       ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                       colorMatch: colorMatch)
        } else { // LowRes
            (resultPixels, nativeData) = convertLowRes(pixels: pixels, width: screenWidth, height: screenHeight,
                                                        ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                        colorMatch: colorMatch, pixelMerge: pixelMerge)
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

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let ctx = CGContext(data: &previewBytes, width: previewWidth, height: previewHeight,
                                   bitsPerComponent: 8, bytesPerRow: previewWidth * 4,
                                   space: colorSpace, bitmapInfo: bitmapInfo),
              let cgImage = ctx.makeImage() else {
            throw NSError(domain: "VIC20Converter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview image"])
        }

        let previewImage = NSImage(cgImage: cgImage, size: NSSize(width: previewWidth, height: previewHeight))

        // Save native file
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("vic20_\(uuid).prg")
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

    // MARK: - HiRes Conversion (176x184, 2 colors per 8x8 cell)

    private func convertHiRes(pixels: [[Float]], width: Int, height: Int,
                              ditherAlg: String, ditherAmount: Double,
                              colorMatch: String) -> ([UInt8], Data) {
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var workPixels = pixels

        // Find background color (most common dark color)
        var colorOccurrence = [Int](repeating: 0, count: 16)
        for pixel in pixels {
            let idx = findNearestColor(r: pixel[0], g: pixel[1], b: pixel[2], colorMatch: colorMatch, foregroundOnly: false)
            let luma = 0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2]
            colorOccurrence[idx] += Int((1.0 - luma) * 255)  // Weight by darkness
        }

        var backgroundColor = 0
        var maxOccurrence = colorOccurrence[0]
        for i in 1..<16 {
            if colorOccurrence[i] > maxOccurrence {
                maxOccurrence = colorOccurrence[i]
                backgroundColor = i
            }
        }

        let bgR = Float(VIC20Converter.vic20Palette[backgroundColor][0]) / 255.0
        let bgG = Float(VIC20Converter.vic20Palette[backgroundColor][1]) / 255.0
        let bgB = Float(VIC20Converter.vic20Palette[backgroundColor][2]) / 255.0
        let bgLuma = 0.299 * bgR + 0.587 * bgG + 0.114 * bgB

        // Screen and color data (22x23 = 506 cells)
        var screenData = [UInt8](repeating: 0, count: 506)
        var colorData = [UInt8](repeating: 0, count: 506)
        var charsetData = [UInt8](repeating: 0, count: 2048)  // 256 chars x 8 bytes

        // Dictionary to track unique character patterns and their assigned charCodes
        var charPatternToCode = [[UInt8]: UInt8]()
        var nextCharCode: Int = 0

        // Process each 8x8 character cell
        for cellY in 0..<23 {
            for cellX in 0..<22 {
                let cellIdx = cellY * 22 + cellX
                let baseX = cellX * 8
                let baseY = cellY * 8

                // Find foreground color (most contrasting to background in this cell)
                // Require minimum contrast to avoid noise affecting the selection
                var fgColor = backgroundColor  // Default to same as background (will be fixed below)
                var maxContrast: Float = 0
                let minContrastThreshold: Float = 0.1  // Minimum 10% contrast to be considered foreground

                for py in 0..<8 {
                    for px in 0..<8 {
                        let y = baseY + py
                        let x = baseX + px
                        if y < height && x < width {
                            let idx = y * width + x
                            let luma = 0.299 * workPixels[idx][0] + 0.587 * workPixels[idx][1] + 0.114 * workPixels[idx][2]
                            let contrast = abs(luma - bgLuma)
                            if contrast > maxContrast && contrast >= minContrastThreshold {
                                maxContrast = contrast
                                // Only first 8 colors can be foreground
                                fgColor = findNearestColor(r: workPixels[idx][0], g: workPixels[idx][1],
                                                           b: workPixels[idx][2], colorMatch: colorMatch, foregroundOnly: true)
                            }
                        }
                    }
                }

                // Ensure foreground is different from background (otherwise cell would be invisible)
                if fgColor == backgroundColor {
                    // Pick a contrasting foreground: white for dark bg, black for light bg
                    fgColor = bgLuma < 0.5 ? 1 : 0
                }

                let fgR = Float(VIC20Converter.vic20Palette[fgColor][0]) / 255.0
                let fgG = Float(VIC20Converter.vic20Palette[fgColor][1]) / 255.0
                let fgB = Float(VIC20Converter.vic20Palette[fgColor][2]) / 255.0

                // Generate character bitmap
                var charBitmap = [UInt8](repeating: 0, count: 8)

                for py in 0..<8 {
                    var rowByte: UInt8 = 0
                    for px in 0..<8 {
                        let y = baseY + py
                        let x = baseX + px
                        if y < height && x < width {
                            let idx = y * width + x
                            let r = workPixels[idx][0]
                            let g = workPixels[idx][1]
                            let b = workPixels[idx][2]

                            // Decide foreground or background
                            // Use strict < so equidistant pixels default to background
                            // This prevents noise/gray pixels from creating dots
                            let distFg = colorDistance(r, g, b, fgR, fgG, fgB, colorMatch)
                            let distBg = colorDistance(r, g, b, bgR, bgG, bgB, colorMatch)

                            var useFg = distFg < distBg

                            // Apply error diffusion dithering
                            if useFg {
                                rowByte |= (1 << (7 - px))
                                result[(y * width + x) * 3] = VIC20Converter.vic20Palette[fgColor][0]
                                result[(y * width + x) * 3 + 1] = VIC20Converter.vic20Palette[fgColor][1]
                                result[(y * width + x) * 3 + 2] = VIC20Converter.vic20Palette[fgColor][2]

                                // Error diffusion
                                if ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson" {
                                    let errR = r - fgR
                                    let errG = g - fgG
                                    let errB = b - fgB
                                    diffuseError(&workPixels, x: x, y: y, width: width, height: height,
                                                 errR: errR * Float(ditherAmount), errG: errG * Float(ditherAmount),
                                                 errB: errB * Float(ditherAmount), algorithm: ditherAlg)
                                }
                            } else {
                                result[(y * width + x) * 3] = VIC20Converter.vic20Palette[backgroundColor][0]
                                result[(y * width + x) * 3 + 1] = VIC20Converter.vic20Palette[backgroundColor][1]
                                result[(y * width + x) * 3 + 2] = VIC20Converter.vic20Palette[backgroundColor][2]

                                if ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson" {
                                    let errR = r - bgR
                                    let errG = g - bgG
                                    let errB = b - bgB
                                    diffuseError(&workPixels, x: x, y: y, width: width, height: height,
                                                 errR: errR * Float(ditherAmount), errG: errG * Float(ditherAmount),
                                                 errB: errB * Float(ditherAmount), algorithm: ditherAlg)
                                }
                            }
                        }
                    }
                    charBitmap[py] = rowByte
                }

                // Check if this pattern already exists in charset
                let charCode: UInt8
                if let existingCode = charPatternToCode[charBitmap] {
                    // Reuse existing character
                    charCode = existingCode
                } else if nextCharCode < 256 {
                    // Create new character
                    charCode = UInt8(nextCharCode)
                    charPatternToCode[charBitmap] = charCode
                    for i in 0..<8 {
                        charsetData[nextCharCode * 8 + i] = charBitmap[i]
                    }
                    nextCharCode += 1
                } else {
                    // Charset full - find most similar existing pattern
                    var bestMatch: UInt8 = 0
                    var bestDiff = Int.max
                    for (pattern, code) in charPatternToCode {
                        var diff = 0
                        for i in 0..<8 {
                            let xor = charBitmap[i] ^ pattern[i]
                            diff += xor.nonzeroBitCount
                        }
                        if diff < bestDiff {
                            bestDiff = diff
                            bestMatch = code
                        }
                    }
                    charCode = bestMatch
                }

                screenData[cellIdx] = charCode
                colorData[cellIdx] = UInt8(fgColor)
            }
        }

        // Build PRG file
        var prgData = Data()

        // Load address: $1201 (unexpanded VIC-20)
        prgData.append(0x01)
        prgData.append(0x12)

        // Simple BASIC stub: 10 SYS 4621
        // This is a minimal stub to run machine code
        let basicStub: [UInt8] = [
            0x0B, 0x12,  // Next line address
            0x0A, 0x00,  // Line number 10
            0x9E,        // SYS token
            0x34, 0x36, 0x32, 0x31,  // "4621"
            0x00,        // End of line
            0x00, 0x00   // End of BASIC
        ]
        prgData.append(contentsOf: basicStub)

        // Machine code to display image (minimal viewer)
        let viewerCode: [UInt8] = [
            // Set screen to $1000, colors to $9400
            0xA9, UInt8((backgroundColor << 4) | 0x08),  // LDA #(bg_color << 4) | 8
            0x8D, 0x0F, 0x90,  // STA $900F (background/border)

            // Copy screen data
            0xA2, 0x00,        // LDX #0
            // loop1:
            0xBD, 0x30, 0x12,  // LDA screen_data,X (offset adjusted)
            0x9D, 0x00, 0x10,  // STA $1000,X
            0xBD, 0x30, 0x14,  // LDA screen_data+512,X
            0x9D, 0x00, 0x12,  // STA $1200,X
            0xE8,              // INX
            0xD0, 0xF1,        // BNE loop1

            // Copy color data
            0xA2, 0x00,        // LDX #0
            // loop2:
            0xBD, 0x36, 0x14,  // LDA color_data,X
            0x9D, 0x00, 0x94,  // STA $9400,X
            0xBD, 0x36, 0x16,  // LDA color_data+512,X
            0x9D, 0x00, 0x96,  // STA $9600,X
            0xE8,              // INX
            0xD0, 0xF1,        // BNE loop2

            // Infinite loop
            0x4C, 0x2D, 0x12   // JMP $122D (self)
        ]
        prgData.append(contentsOf: viewerCode)

        // Padding to align data
        while prgData.count < 0x30 {
            prgData.append(0xEA)  // NOP
        }

        // Screen data (506 bytes)
        prgData.append(contentsOf: screenData)

        // Color data (506 bytes)
        prgData.append(contentsOf: colorData)

        // Charset data (2048 bytes)
        prgData.append(contentsOf: charsetData)

        return (result, prgData)
    }

    // MARK: - LowRes Conversion (88x184, 4 colors per 4x8 cell)

    private func convertLowRes(pixels: [[Float]], width: Int, height: Int,
                               ditherAlg: String, ditherAmount: Double,
                               colorMatch: String, pixelMerge: String) -> ([UInt8], Data) {
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var workPixels = pixels

        // Shrink to 88x184 (double-wide pixels)
        let lowWidth = 88
        var shrunkPixels = [[Float]](repeating: [Float](repeating: 0, count: 3), count: lowWidth * height)

        for y in 0..<height {
            for x in 0..<lowWidth {
                let srcX1 = x * 2
                let srcX2 = min(srcX1 + 1, width - 1)
                let idx1 = y * width + srcX1
                let idx2 = y * width + srcX2

                if pixelMerge == "Brightest" {
                    let luma1 = 0.299 * pixels[idx1][0] + 0.587 * pixels[idx1][1] + 0.114 * pixels[idx1][2]
                    let luma2 = 0.299 * pixels[idx2][0] + 0.587 * pixels[idx2][1] + 0.114 * pixels[idx2][2]
                    let useIdx = luma1 > luma2 ? idx1 : idx2
                    shrunkPixels[y * lowWidth + x] = pixels[useIdx]
                } else {
                    // Average
                    shrunkPixels[y * lowWidth + x] = [
                        (pixels[idx1][0] + pixels[idx2][0]) / 2,
                        (pixels[idx1][1] + pixels[idx2][1]) / 2,
                        (pixels[idx1][2] + pixels[idx2][2]) / 2
                    ]
                }
            }
        }

        // Find 4 most common colors (foreground palette only - first 8 colors)
        var colorOccurrence = [Int](repeating: 0, count: 8)
        for pixel in shrunkPixels {
            let idx = findNearestColor(r: pixel[0], g: pixel[1], b: pixel[2], colorMatch: colorMatch, foregroundOnly: true)
            colorOccurrence[idx] += 1
        }

        // Sort to get top 4 colors
        var colorIndices = Array(0..<8)
        colorIndices.sort { colorOccurrence[$0] > colorOccurrence[$1] }

        let color0 = colorIndices[0]  // Background
        let color1 = colorIndices[1]  // Border
        let color2 = colorIndices[2]  // Auxiliary (foreground from color RAM)
        let color3 = colorIndices[3]  // Auxiliary 2

        let localPalette: [[Float]] = [
            [Float(VIC20Converter.vic20Palette[color0][0]) / 255.0,
             Float(VIC20Converter.vic20Palette[color0][1]) / 255.0,
             Float(VIC20Converter.vic20Palette[color0][2]) / 255.0],
            [Float(VIC20Converter.vic20Palette[color1][0]) / 255.0,
             Float(VIC20Converter.vic20Palette[color1][1]) / 255.0,
             Float(VIC20Converter.vic20Palette[color1][2]) / 255.0],
            [Float(VIC20Converter.vic20Palette[color2][0]) / 255.0,
             Float(VIC20Converter.vic20Palette[color2][1]) / 255.0,
             Float(VIC20Converter.vic20Palette[color2][2]) / 255.0],
            [Float(VIC20Converter.vic20Palette[color3][0]) / 255.0,
             Float(VIC20Converter.vic20Palette[color3][1]) / 255.0,
             Float(VIC20Converter.vic20Palette[color3][2]) / 255.0]
        ]

        // Screen and color data
        var screenData = [UInt8](repeating: 0, count: 506)
        var colorData = [UInt8](repeating: 0, count: 506)
        var charsetData = [UInt8](repeating: 0, count: 2048)

        // Dictionary to track unique character patterns and their assigned charCodes
        var charPatternToCode = [[UInt8]: UInt8]()
        var nextCharCode: Int = 0

        // Process each 4x8 character cell (in lowres coordinates)
        for cellY in 0..<23 {
            for cellX in 0..<22 {
                let cellIdx = cellY * 22 + cellX
                let baseX = cellX * 4
                let baseY = cellY * 8

                // Generate character bitmap (2 bits per pixel)
                var charBitmap = [UInt8](repeating: 0, count: 8)

                for py in 0..<8 {
                    var rowByte: UInt8 = 0
                    for px in 0..<4 {
                        let y = baseY + py
                        let x = baseX + px
                        if y < height && x < lowWidth {
                            let idx = y * lowWidth + x
                            let pixel = shrunkPixels[idx]

                            // Find best of 4 colors
                            var bestColor = 0
                            var bestDist = Float.infinity
                            for c in 0..<4 {
                                let dist = colorDistance(pixel[0], pixel[1], pixel[2],
                                                         localPalette[c][0], localPalette[c][1], localPalette[c][2],
                                                         colorMatch)
                                if dist < bestDist {
                                    bestDist = dist
                                    bestColor = c
                                }
                            }

                            // Pack 2 bits
                            rowByte |= UInt8(bestColor) << (6 - px * 2)

                            // Set result pixels (expand back to 176 width)
                            let resultX1 = (cellX * 4 + px) * 2
                            let resultX2 = resultX1 + 1
                            let resultY = cellY * 8 + py

                            let palColor: Int
                            switch bestColor {
                            case 0: palColor = color0
                            case 1: palColor = color1
                            case 2: palColor = color2
                            default: palColor = color3
                            }

                            if resultY < height && resultX1 < width {
                                result[(resultY * width + resultX1) * 3] = VIC20Converter.vic20Palette[palColor][0]
                                result[(resultY * width + resultX1) * 3 + 1] = VIC20Converter.vic20Palette[palColor][1]
                                result[(resultY * width + resultX1) * 3 + 2] = VIC20Converter.vic20Palette[palColor][2]
                            }
                            if resultY < height && resultX2 < width {
                                result[(resultY * width + resultX2) * 3] = VIC20Converter.vic20Palette[palColor][0]
                                result[(resultY * width + resultX2) * 3 + 1] = VIC20Converter.vic20Palette[palColor][1]
                                result[(resultY * width + resultX2) * 3 + 2] = VIC20Converter.vic20Palette[palColor][2]
                            }
                        }
                    }
                    charBitmap[py] = rowByte
                }

                // Check if this pattern already exists in charset
                let charCode: UInt8
                if let existingCode = charPatternToCode[charBitmap] {
                    // Reuse existing character
                    charCode = existingCode
                } else if nextCharCode < 256 {
                    // Create new character
                    charCode = UInt8(nextCharCode)
                    charPatternToCode[charBitmap] = charCode
                    for i in 0..<8 {
                        charsetData[nextCharCode * 8 + i] = charBitmap[i]
                    }
                    nextCharCode += 1
                } else {
                    // Charset full - find most similar existing pattern
                    var bestMatch: UInt8 = 0
                    var bestDiff = Int.max
                    for (pattern, code) in charPatternToCode {
                        var diff = 0
                        for i in 0..<8 {
                            let xor = charBitmap[i] ^ pattern[i]
                            diff += xor.nonzeroBitCount
                        }
                        if diff < bestDiff {
                            bestDiff = diff
                            bestMatch = code
                        }
                    }
                    charCode = bestMatch
                }

                screenData[cellIdx] = charCode
                colorData[cellIdx] = UInt8(color2 + 8)  // +8 for multicolor mode
            }
        }

        // Build PRG file
        var prgData = Data()

        prgData.append(0x01)
        prgData.append(0x12)

        let basicStub: [UInt8] = [
            0x0B, 0x12,
            0x0A, 0x00,
            0x9E,
            0x34, 0x36, 0x32, 0x31,
            0x00,
            0x00, 0x00
        ]
        prgData.append(contentsOf: basicStub)

        let viewerCode: [UInt8] = [
            0xA9, UInt8((color0 << 4) | color1),  // Background and border
            0x8D, 0x0F, 0x90,
            0xA9, UInt8(color3 << 4),  // Auxiliary color
            0x8D, 0x0E, 0x90,
            0xA2, 0x00,
            0xBD, 0x30, 0x12,
            0x9D, 0x00, 0x10,
            0xBD, 0x30, 0x14,
            0x9D, 0x00, 0x12,
            0xE8,
            0xD0, 0xF1,
            0xA2, 0x00,
            0xBD, 0x36, 0x14,
            0x9D, 0x00, 0x94,
            0xBD, 0x36, 0x16,
            0x9D, 0x00, 0x96,
            0xE8,
            0xD0, 0xF1,
            0x4C, 0x2D, 0x12
        ]
        prgData.append(contentsOf: viewerCode)

        while prgData.count < 0x30 {
            prgData.append(0xEA)
        }

        prgData.append(contentsOf: screenData)
        prgData.append(contentsOf: colorData)
        prgData.append(contentsOf: charsetData)

        return (result, prgData)
    }

    // MARK: - Color Matching

    private func findNearestColor(r: Float, g: Float, b: Float, colorMatch: String, foregroundOnly: Bool) -> Int {
        var bestIdx = 0
        var bestDist = Float.infinity
        let maxColors = foregroundOnly ? 8 : 16

        for i in 0..<maxColors {
            let pr = Float(VIC20Converter.vic20Palette[i][0]) / 255.0
            let pg = Float(VIC20Converter.vic20Palette[i][1]) / 255.0
            let pb = Float(VIC20Converter.vic20Palette[i][2]) / 255.0

            let dist = colorDistance(r, g, b, pr, pg, pb, colorMatch)
            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }

        return bestIdx
    }

    private func colorDistance(_ r1: Float, _ g1: Float, _ b1: Float,
                               _ r2: Float, _ g2: Float, _ b2: Float,
                               _ method: String) -> Float {
        switch method {
        case "Perceptive":
            let rmean = (r1 + r2) / 2
            let dr = r1 - r2
            let dg = g1 - g2
            let db = b1 - b2
            return (2 + rmean) * dr * dr + 4 * dg * dg + (3 - rmean) * db * db
        case "Luma":
            let luma1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
            let luma2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
            let dLuma = luma1 - luma2
            let dr = r1 - r2
            let dg = g1 - g2
            let db = b1 - b2
            return dLuma * dLuma * 2 + dr * dr + dg * dg + db * db
        case "Chroma":
            let luma1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
            let luma2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
            let u1 = 0.492 * (b1 - luma1)
            let v1 = 0.877 * (r1 - luma1)
            let u2 = 0.492 * (b2 - luma2)
            let v2 = 0.877 * (r2 - luma2)
            let chromaDist = sqrt((u1 - u2) * (u1 - u2) + (v1 - v2) * (v1 - v2))
            let lumaDist = abs(luma1 - luma2)
            return chromaDist * 2.0 + lumaDist * 0.5
        case "Mahalanobis":
            let dr = r1 - r2
            let dg = g1 - g2
            let db = b1 - b2
            return dr * dr * 2.5 + dg * dg * 1.0 + db * db * 3.0
        default:  // Euclidean
            let dr = r1 - r2
            let dg = g1 - g2
            let db = b1 - b2
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
            applyNoiseDither(&pixels, width: width, height: height, amount: amount)
            return
        default:  // Bayer 8x8
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
            if x + 1 < width {
                pixels[y * width + x + 1][0] += errR * 7.0 / 16.0
                pixels[y * width + x + 1][1] += errG * 7.0 / 16.0
                pixels[y * width + x + 1][2] += errB * 7.0 / 16.0
            }
            if y + 1 < height {
                if x > 0 {
                    pixels[(y + 1) * width + x - 1][0] += errR * 3.0 / 16.0
                    pixels[(y + 1) * width + x - 1][1] += errG * 3.0 / 16.0
                    pixels[(y + 1) * width + x - 1][2] += errB * 3.0 / 16.0
                }
                pixels[(y + 1) * width + x][0] += errR * 5.0 / 16.0
                pixels[(y + 1) * width + x][1] += errG * 5.0 / 16.0
                pixels[(y + 1) * width + x][2] += errB * 5.0 / 16.0
                if x + 1 < width {
                    pixels[(y + 1) * width + x + 1][0] += errR * 1.0 / 16.0
                    pixels[(y + 1) * width + x + 1][1] += errG * 1.0 / 16.0
                    pixels[(y + 1) * width + x + 1][2] += errB * 1.0 / 16.0
                }
            }
        } else if algorithm == "Atkinson" {
            let factor: Float = 1.0 / 8.0
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
        let total = width * height
        var histogram = [Int](repeating: 0, count: 256)

        for i in 0..<total {
            let luma = 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2]
            let bin = min(255, max(0, Int(luma * 255)))
            histogram[bin] += 1
        }

        var cdf = [Float](repeating: 0, count: 256)
        cdf[0] = Float(histogram[0]) / Float(total)
        for i in 1..<256 {
            cdf[i] = cdf[i-1] + Float(histogram[i]) / Float(total)
        }

        for i in 0..<total {
            let r = pixels[i][0]
            let g = pixels[i][1]
            let b = pixels[i][2]
            let luma = 0.299 * r + 0.587 * g + 0.114 * b
            let bin = min(255, max(0, Int(luma * 255)))
            let newLuma = cdf[bin]

            if luma > 0.001 {
                let scale = newLuma / luma
                pixels[i][0] = min(1, max(0, r * scale))
                pixels[i][1] = min(1, max(0, g * scale))
                pixels[i][2] = min(1, max(0, b * scale))
            }
        }
    }

    private func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int, clipLimit: Float) {
        let tileWidth = 40
        let tileHeight = 40
        let tilesX = (width + tileWidth - 1) / tileWidth
        let tilesY = (height + tileHeight - 1) / tileHeight

        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let startX = tx * tileWidth
                let startY = ty * tileHeight
                let endX = min(startX + tileWidth, width)
                let endY = min(startY + tileHeight, height)

                var histogram = [Int](repeating: 0, count: 256)
                var tilePixels = 0

                for y in startY..<endY {
                    for x in startX..<endX {
                        let idx = y * width + x
                        let luma = 0.299 * pixels[idx][0] + 0.587 * pixels[idx][1] + 0.114 * pixels[idx][2]
                        let bin = min(255, max(0, Int(luma * 255)))
                        histogram[bin] += 1
                        tilePixels += 1
                    }
                }

                let clipThreshold = Int(clipLimit * Float(tilePixels) / 256.0)
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

                var cdf = [Float](repeating: 0, count: 256)
                cdf[0] = Float(histogram[0]) / Float(tilePixels)
                for i in 1..<256 {
                    cdf[i] = cdf[i-1] + Float(histogram[i]) / Float(tilePixels)
                }

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
        let halfWindow = windowSize / 2
        var result = pixels

        var lumaBins = [Int](repeating: 0, count: width * height)
        for i in 0..<pixels.count {
            let luma = 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2]
            lumaBins[i] = min(255, max(0, Int(luma * 255)))
        }

        for y in 0..<height {
            let startY = max(0, y - halfWindow)
            let endY = min(height, y + halfWindow + 1)

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
                if x > 0 {
                    let addX = x + halfWindow
                    let removeX = x - halfWindow - 1

                    if addX < width {
                        for wy in startY..<endY {
                            histogram[lumaBins[wy * width + addX]] += 1
                            windowPixels += 1
                        }
                    }

                    if removeX >= 0 {
                        for wy in startY..<endY {
                            histogram[lumaBins[wy * width + removeX]] -= 1
                            windowPixels -= 1
                        }
                    }
                }

                let idx = y * width + x
                let bin = lumaBins[idx]

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
                        sumR += pixels[idx][0] * kernel[ky][kx]
                        sumG += pixels[idx][1] * kernel[ky][kx]
                        sumB += pixels[idx][2] * kernel[ky][kx]
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
                var gxR: Float = 0, gyR: Float = 0
                var gxG: Float = 0, gyG: Float = 0
                var gxB: Float = 0, gyB: Float = 0

                for ky in 0..<3 {
                    for kx in 0..<3 {
                        let px = x + kx - 1
                        let py = y + ky - 1
                        let idx = py * width + px

                        gxR += pixels[idx][0] * sobelX[ky][kx]
                        gyR += pixels[idx][0] * sobelY[ky][kx]
                        gxG += pixels[idx][1] * sobelX[ky][kx]
                        gyG += pixels[idx][1] * sobelY[ky][kx]
                        gxB += pixels[idx][2] * sobelX[ky][kx]
                        gyB += pixels[idx][2] * sobelY[ky][kx]
                    }
                }

                let edgeR = sqrt(gxR * gxR + gyR * gyR)
                let edgeG = sqrt(gxG * gxG + gyG * gyG)
                let edgeB = sqrt(gxB * gxB + gyB * gyB)

                let idx = y * width + x
                result[idx][0] = min(1, max(0, (pixels[idx][0] + edgeR) * 0.5))
                result[idx][1] = min(1, max(0, (pixels[idx][1] + edgeG) * 0.5))
                result[idx][2] = min(1, max(0, (pixels[idx][2] + edgeB) * 0.5))
            }
        }

        pixels = result
    }

    // MARK: - Pixel Reading

    private func getPixelData(from sourceImage: NSImage, width: Int, height: Int,
                               saturation: Double, gamma: Double) throws -> [[Float]] {
        guard let cgImage = getCGImage(from: sourceImage) else {
            throw NSError(domain: "VIC20Converter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from source"])
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        guard let ctx = CGContext(data: &bytes, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: width * 4,
                                   space: colorSpace, bitmapInfo: bitmapInfo) else {
            throw NSError(domain: "VIC20Converter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
        }

        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels = [[Float]](repeating: [Float](repeating: 0, count: 3), count: width * height)

        for i in 0..<(width * height) {
            let alpha = Float(bytes[i * 4 + 3])
            var r: Float, g: Float, b: Float

            if alpha > 0 {
                r = Float(bytes[i * 4]) / alpha
                g = Float(bytes[i * 4 + 1]) / alpha
                b = Float(bytes[i * 4 + 2]) / alpha
            } else {
                r = Float(bytes[i * 4]) / 255.0
                g = Float(bytes[i * 4 + 1]) / 255.0
                b = Float(bytes[i * 4 + 2]) / 255.0
            }

            if gamma != 1.0 {
                r = pow(r, Float(gamma))
                g = pow(g, Float(gamma))
                b = pow(b, Float(gamma))
            }

            if saturation != 1.0 {
                let gray = 0.299 * r + 0.587 * g + 0.114 * b
                r = gray + Float(saturation) * (r - gray)
                g = gray + Float(saturation) * (g - gray)
                b = gray + Float(saturation) * (b - gray)
            }

            r = max(0, min(1, r))
            g = max(0, min(1, g))
            b = max(0, min(1, b))

            pixels[i] = [r, g, b]
        }

        return pixels
    }

    private func getCGImage(from image: NSImage) -> CGImage? {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }

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
