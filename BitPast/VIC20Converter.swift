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
        try validateSourceImage(sourceImage)
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
            CommodoreFamilyImageOps.applyImageFilter(&pixels, width: screenWidth, height: screenHeight, filter: filterMode)
        }

        // Apply ordered dithering before color reduction
        if ditherAlg.contains("Bayer") || ditherAlg.contains("Blue") || ditherAlg == "Noise" {
            CommodoreFamilyImageOps.applyOrderedDither(&pixels, width: screenWidth, height: screenHeight, ditherType: ditherAlg, amount: ditherAmount)
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
                            let distFg = CommodoreFamilyImageOps.colorDistance(r, g, b, fgR, fgG, fgB, colorMatch)
                            let distBg = CommodoreFamilyImageOps.colorDistance(r, g, b, bgR, bgG, bgB, colorMatch)

                            let useFg = distFg < distBg

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
                                    CommodoreFamilyImageOps.diffuseError(&workPixels, x: x, y: y, width: width, height: height,
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
                                    CommodoreFamilyImageOps.diffuseError(&workPixels, x: x, y: y, width: width, height: height,
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
                        // Lowest code wins a tie, so output does not depend on dictionary order
                        if diff < bestDiff || (diff == bestDiff && code < bestMatch) {
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
                                let dist = CommodoreFamilyImageOps.colorDistance(pixel[0], pixel[1], pixel[2],
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
                        // Lowest code wins a tie, so output does not depend on dictionary order
                        if diff < bestDiff || (diff == bestDiff && code < bestMatch) {
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

            let dist = CommodoreFamilyImageOps.colorDistance(r, g, b, pr, pg, pb, colorMatch)
            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }

        return min(max(bestIdx, 0), VIC20Converter.vic20Palette.count - 1)
    }

    // MARK: - Contrast Processing

    private func applyContrastProcessing(_ pixels: inout [[Float]], width: Int, height: Int, mode: String) {
        switch mode {
        case "HE":
            CommodoreFamilyImageOps.applyHistogramEqualization(&pixels, width: width, height: height)
        case "CLAHE":
            applyCLAHE(&pixels, width: width, height: height, clipLimit: 3.0)
        case "SWAHE":
            CommodoreFamilyImageOps.applySWAHE(&pixels, width: width, height: height, windowSize: 40)
        default:
            break
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

    // MARK: - Pixel Reading

    private func getPixelData(from sourceImage: NSImage, width: Int, height: Int,
                               saturation: Double, gamma: Double) throws -> [[Float]] {
        guard let cgImage = CommodoreFamilyImageOps.getCGImage(from: sourceImage) else {
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
}
