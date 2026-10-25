import Cocoa

nonisolated class ZXSpectrumConverter: RetroMachine {
    var name: String = "ZX Spectrum"

    var options: [ConversionOption] = [
        // 1. DITHERING ALGORITHM
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

        // 2. DITHER AMOUNT
        ConversionOption(
            label: "Dither Amount",
            key: "dither_amount",
            range: 0.0...1.0,
            defaultValue: 0.5
        ),

        // 3. CONTRAST PROCESSING
        ConversionOption(
            label: "Contrast",
            key: "contrast",
            values: ["None", "HE", "CLAHE", "SWAHE"],
            selectedValue: "None"
        ),

        // 4. IMAGE FILTER
        ConversionOption(
            label: "Filter",
            key: "filter",
            values: ["None", "Lowpass", "Sharpen", "Emboss", "Edge"],
            selectedValue: "None"
        ),

        // 5. COLOR MATCHING
        ConversionOption(
            label: "Color Match",
            key: "color_match",
            values: ["Euclidean", "Perceptive", "Luma", "Chroma", "Mahalanobis"],
            selectedValue: "Perceptive"
        ),

        // 6. SATURATION
        ConversionOption(
            label: "Saturation",
            key: "saturation",
            range: 0.0...2.0,
            defaultValue: 1.0
        ),

        // 7. GAMMA
        ConversionOption(
            label: "Gamma",
            key: "gamma",
            range: 0.5...2.0,
            defaultValue: 1.0
        )
    ]

    // ZX Spectrum palette (from ZXRenderer.java)
    // 8 colors × 2 brightness levels = 16 colors
    // Colors 0-7: Normal brightness (0xD7), Colors 8-15: Bright (0xFF)
    // But color 0 and 1 are both black
    static let zxPalette: [[UInt8]] = [
        [0x00, 0x00, 0x00],  // 0: Black (normal)
        [0x00, 0x00, 0x00],  // 1: Black (bright) - same as normal
        [0x00, 0x00, 0xD7],  // 2: Blue (normal)
        [0x00, 0x00, 0xFF],  // 3: Blue (bright)
        [0xD7, 0x00, 0x00],  // 4: Red (normal)
        [0xFF, 0x00, 0x00],  // 5: Red (bright)
        [0xD7, 0x00, 0xD7],  // 6: Magenta (normal)
        [0xFF, 0x00, 0xFF],  // 7: Magenta (bright)
        [0x00, 0xD7, 0x00],  // 8: Green (normal)
        [0x00, 0xFF, 0x00],  // 9: Green (bright)
        [0x00, 0xD7, 0xD7],  // 10: Cyan (normal)
        [0x00, 0xFF, 0xFF],  // 11: Cyan (bright)
        [0xD7, 0xD7, 0x00],  // 12: Yellow (normal)
        [0xFF, 0xFF, 0x00],  // 13: Yellow (bright)
        [0xD7, 0xD7, 0xD7],  // 14: White (normal)
        [0xFF, 0xFF, 0xFF]   // 15: White (bright)
    ]

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) throws -> ConversionResult {
        try validateSourceImage(sourceImage)
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        let ditherAlg = opts.first(where: { $0.key == "dither" })?.selectedValue ?? "Bayer 2x2"
        let ditherAmount = Double(opts.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "1.0") ?? 1.0
        let contrastMode = opts.first(where: { $0.key == "contrast" })?.selectedValue ?? "SWAHE"
        let filterMode = opts.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let colorMatch = opts.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(opts.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(opts.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        // ZX Spectrum screen: 256×192 (32×24 attribute cells of 8×8)
        let screenWidth = 256
        let screenHeight = 192

        try Task.checkCancellation()
        var pixels = try getPixelData(from: sourceImage, width: screenWidth, height: screenHeight,
                                       saturation: saturation, gamma: gamma)

        try Task.checkCancellation()
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

        try Task.checkCancellation()
        // Convert to ZX Spectrum format
        let (resultPixels, nativeData) = convertHiRes(pixels: pixels, width: screenWidth, height: screenHeight,
                                                       ditherAlg: ditherAlg, ditherAmount: ditherAmount,
                                                       colorMatch: colorMatch)

        // Create preview image (doubled for better visibility)
        try Task.checkCancellation()
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
            throw NSError(domain: "ZXSpectrumConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create preview image"])
        }

        let previewImage = NSImage(cgImage: cgImage, size: NSSize(width: previewWidth, height: previewHeight))

        // Save native .scr file
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("zx_\(uuid).scr")
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

    // MARK: - HiRes Conversion (256×192, 2 colors per 8×8 attribute cell)

    private func convertHiRes(pixels: [[Float]], width: Int, height: Int,
                              ditherAlg: String, ditherAmount: Double,
                              colorMatch: String) -> ([UInt8], Data) {
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var workPixels = pixels

        // ZX Spectrum screen memory
        var bitmap = [UInt8](repeating: 0, count: 6144)   // 32 × 192 bytes
        var attribs = [UInt8](repeating: 0, count: 768)   // 32 × 24 bytes

        // Process each 8×8 attribute cell
        for cellY in 0..<24 {
            for cellX in 0..<32 {
                let baseX = cellX * 8
                let baseY = cellY * 8

                // Count color occurrences in this cell
                var colorOccurrence = [Int](repeating: 0, count: 16)

                for py in 0..<8 {
                    for px in 0..<8 {
                        let y = baseY + py
                        let x = baseX + px
                        let idx = y * width + x
                        let colorIdx = findNearestColor(r: workPixels[idx][0], g: workPixels[idx][1],
                                                        b: workPixels[idx][2], colorMatch: colorMatch)
                        colorOccurrence[colorIdx] += 1
                    }
                }

                // Find two most common colors (ink and paper)
                var inkColor = 0
                var paperColor = 0
                var max1 = 0
                var max2 = 0

                for i in 0..<16 {
                    if colorOccurrence[i] > max1 {
                        max2 = max1
                        paperColor = inkColor
                        max1 = colorOccurrence[i]
                        inkColor = i
                    } else if colorOccurrence[i] > max2 {
                        max2 = colorOccurrence[i]
                        paperColor = i
                    }
                }

                // Build local 2-color palette
                let inkR = Float(ZXSpectrumConverter.zxPalette[inkColor][0]) / 255.0
                let inkG = Float(ZXSpectrumConverter.zxPalette[inkColor][1]) / 255.0
                let inkB = Float(ZXSpectrumConverter.zxPalette[inkColor][2]) / 255.0

                let paperR = Float(ZXSpectrumConverter.zxPalette[paperColor][0]) / 255.0
                let paperG = Float(ZXSpectrumConverter.zxPalette[paperColor][1]) / 255.0
                let paperB = Float(ZXSpectrumConverter.zxPalette[paperColor][2]) / 255.0

                // Calculate attribute byte
                // Ink = bits 0-2, Paper = bits 3-5, Bright = bit 6
                let ink3bit = inkColor >> 1      // Remove brightness bit to get 0-7
                let paper3bit = paperColor >> 1
                let bright = ((inkColor & 1) | (paperColor & 1)) << 6

                let attrAddress = cellY * 32 + cellX
                attribs[attrAddress] = UInt8(((paper3bit & 0x7) << 3) | (ink3bit & 0x7) | bright)

                // Process each pixel in the cell
                for py in 0..<8 {
                    var rowByte: UInt8 = 0

                    for px in 0..<8 {
                        let y = baseY + py
                        let x = baseX + px
                        let idx = y * width + x

                        let r = workPixels[idx][0]
                        let g = workPixels[idx][1]
                        let b = workPixels[idx][2]

                        // Choose ink (1) or paper (0)
                        let distInk = CommodoreFamilyImageOps.colorDistance(r, g, b, inkR, inkG, inkB, colorMatch)
                        let distPaper = CommodoreFamilyImageOps.colorDistance(r, g, b, paperR, paperG, paperB, colorMatch)

                        let useInk = distInk <= distPaper

                        if useInk {
                            rowByte = (rowByte << 1) | 1
                            result[(y * width + x) * 3] = ZXSpectrumConverter.zxPalette[inkColor][0]
                            result[(y * width + x) * 3 + 1] = ZXSpectrumConverter.zxPalette[inkColor][1]
                            result[(y * width + x) * 3 + 2] = ZXSpectrumConverter.zxPalette[inkColor][2]

                            // Error diffusion
                            if ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson" {
                                let errR = r - inkR
                                let errG = g - inkG
                                let errB = b - inkB
                                CommodoreFamilyImageOps.diffuseError(&workPixels, x: x, y: y, width: width, height: height,
                                             errR: errR * Float(ditherAmount), errG: errG * Float(ditherAmount),
                                             errB: errB * Float(ditherAmount), algorithm: ditherAlg)
                            }
                        } else {
                            rowByte = rowByte << 1
                            result[(y * width + x) * 3] = ZXSpectrumConverter.zxPalette[paperColor][0]
                            result[(y * width + x) * 3 + 1] = ZXSpectrumConverter.zxPalette[paperColor][1]
                            result[(y * width + x) * 3 + 2] = ZXSpectrumConverter.zxPalette[paperColor][2]

                            if ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson" {
                                let errR = r - paperR
                                let errG = g - paperG
                                let errB = b - paperB
                                CommodoreFamilyImageOps.diffuseError(&workPixels, x: x, y: y, width: width, height: height,
                                             errR: errR * Float(ditherAmount), errG: errG * Float(ditherAmount),
                                             errB: errB * Float(ditherAmount), algorithm: ditherAlg)
                            }
                        }
                    }

                    // Store in ZX Spectrum's interleaved screen memory format
                    let screenY = baseY + py
                    let zxOffset = ((screenY & 0x07) << 8) | ((screenY & 0x38) << 2) | ((screenY & 0xC0) << 5) | cellX
                    bitmap[zxOffset] = rowByte
                }
            }
        }

        // Build .scr file (6144 bitmap + 768 attributes = 6912 bytes)
        var scrData = Data()
        scrData.append(contentsOf: bitmap)
        scrData.append(contentsOf: attribs)

        return (result, scrData)
    }

    // MARK: - Color Matching

    private func findNearestColor(r: Float, g: Float, b: Float, colorMatch: String) -> Int {
        var bestIdx = 0
        var bestDist = Float.infinity

        for i in 0..<16 {
            let pr = Float(ZXSpectrumConverter.zxPalette[i][0]) / 255.0
            let pg = Float(ZXSpectrumConverter.zxPalette[i][1]) / 255.0
            let pb = Float(ZXSpectrumConverter.zxPalette[i][2]) / 255.0

            let dist = CommodoreFamilyImageOps.colorDistance(r, g, b, pr, pg, pb, colorMatch)
            if dist < bestDist {
                bestDist = dist
                bestIdx = i
            }
        }

        return min(max(bestIdx, 0), ZXSpectrumConverter.zxPalette.count - 1)
    }

    // MARK: - Contrast Processing

    private func applyContrastProcessing(_ pixels: inout [[Float]], width: Int, height: Int, mode: String) {
        switch mode {
        case "HE":
            CommodoreFamilyImageOps.applyHistogramEqualization(&pixels, width: width, height: height)
        case "CLAHE":
            applyCLAHE(&pixels, width: width, height: height, clipLimit: 3.0)
        case "SWAHE":
            CommodoreFamilyImageOps.applySWAHE(&pixels, width: width, height: height, windowSize: 30)
        default:
            break
        }
    }

    private func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int, clipLimit: Float) {
        let tileWidth = 32
        let tileHeight = 32
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
            throw NSError(domain: "ZXSpectrumConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage from source"])
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        guard let ctx = CGContext(data: &bytes, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: width * 4,
                                   space: colorSpace, bitmapInfo: bitmapInfo) else {
            throw NSError(domain: "ZXSpectrumConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext"])
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
