import Cocoa

/// Image helpers first written for the C64 converter and shared, unchanged, by:
/// C64, VIC20, ZXSpectrum.
/// Other converters keep their own versions where the algorithm differs.
enum CommodoreFamilyImageOps {
    nonisolated static func applyConvolution(_ pixels: inout [[Float]], width: Int, height: Int, kernel: [[Float]]) {
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

    nonisolated static func applyEdgeFilter(_ pixels: inout [[Float]], width: Int, height: Int) {
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

    nonisolated static func applyHistogramEqualization(_ pixels: inout [[Float]], width: Int, height: Int) {
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

    nonisolated static func applyImageFilter(_ pixels: inout [[Float]], width: Int, height: Int, filter: String) {
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
            CommodoreFamilyImageOps.applyConvolution(&pixels, width: width, height: height, kernel: lowpassKernel)
        case "Sharpen":
            CommodoreFamilyImageOps.applyConvolution(&pixels, width: width, height: height, kernel: sharpenKernel)
        case "Emboss":
            CommodoreFamilyImageOps.applyConvolution(&pixels, width: width, height: height, kernel: embossKernel)
        case "Edge":
            CommodoreFamilyImageOps.applyEdgeFilter(&pixels, width: width, height: height)
        default:
            break
        }
    }

    nonisolated static func applyNoiseDither(_ pixels: inout [[Float]], width: Int, height: Int, amount: Double) {
        let strength = Float(amount) * 0.1
        for i in 0..<(width * height) {
            let noise = (Float.random(in: 0...1) - 0.5) * strength
            pixels[i][0] = min(1, max(0, pixels[i][0] + noise))
            pixels[i][1] = min(1, max(0, pixels[i][1] + noise))
            pixels[i][2] = min(1, max(0, pixels[i][2] + noise))
        }
    }

    nonisolated static func applyOrderedDither(_ pixels: inout [[Float]], width: Int, height: Int, ditherType: String, amount: Double) {
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
            matrix = CommodoreFamilyImageOps.generateBayer16x16()
        case "Blue 8x8":
            size = 8
            matrix = CommodoreFamilyImageOps.generateBlueNoise8x8()
        case "Blue 16x16":
            size = 16
            matrix = CommodoreFamilyImageOps.generateBlueNoise16x16()
        case "Noise":
            // Random noise dithering - handled separately
            CommodoreFamilyImageOps.applyNoiseDither(&pixels, width: width, height: height, amount: amount)
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

    nonisolated static func applySWAHE(_ pixels: inout [[Float]], width: Int, height: Int, windowSize: Int) {
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
                let newLuma = windowPixels > 0 ? Float(cumulative) / Float(windowPixels) : Float(bin) / 255.0

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

    nonisolated static func colorDistance(_ r1: Float, _ g1: Float, _ b1: Float,
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

    nonisolated static func diffuseError(_ pixels: inout [[Float]], x: Int, y: Int, width: Int, height: Int,
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

    nonisolated static func generateBayer16x16() -> [[Float]] {
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

    nonisolated static func generateBlueNoise16x16() -> [[Float]] {
        // Extended blue noise pattern
        let blue8 = CommodoreFamilyImageOps.generateBlueNoise8x8()
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

    nonisolated static func generateBlueNoise8x8() -> [[Float]] {
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

    nonisolated static func getCGImage(from image: NSImage) -> CGImage? {
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
