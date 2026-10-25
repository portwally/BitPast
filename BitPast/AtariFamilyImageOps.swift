import Cocoa

/// Image helpers first written for the Atari 800 converter and shared, unchanged, by:
/// AmstradCPC, Atari800, AtariST, BBCMicro, PC, Plus4, TRS80CoCo.
/// Other converters keep their own versions where the algorithm differs.
enum AtariFamilyImageOps {
    nonisolated static func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int, clipLimit: Float, tileSize: Int) {
        let tilesX = (width + tileSize - 1) / tileSize
        let tilesY = (height + tileSize - 1) / tileSize
        var tileLUTs = [[[Float]]](repeating: [[Float]](repeating: [Float](repeating: 0, count: 256), count: tilesX), count: tilesY)

        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                var histogram = [Int](repeating: 0, count: 256)
                var count = 0

                let startY = ty * tileSize
                let endY = min(startY + tileSize, height)
                let startX = tx * tileSize
                let endX = min(startX + tileSize, width)

                for y in startY..<endY {
                    for x in startX..<endX {
                        let luma = Int(max(0, min(255, 0.299 * pixels[y * width + x][0] + 0.587 * pixels[y * width + x][1] + 0.114 * pixels[y * width + x][2])))
                        histogram[luma] += 1
                        count += 1
                    }
                }

                let clipThreshold = Int(clipLimit * Float(count) / 256.0)
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

                var cdf = [Int](repeating: 0, count: 256)
                cdf[0] = histogram[0]
                for i in 1..<256 {
                    cdf[i] = cdf[i - 1] + histogram[i]
                }

                let cdfMin = cdf.first(where: { $0 > 0 }) ?? 0
                for i in 0..<256 {
                    tileLUTs[ty][tx][i] = Float((cdf[i] - cdfMin) * 255 / max(1, count - cdfMin))
                }
            }
        }

        var result = pixels
        for y in 0..<height {
            for x in 0..<width {
                let luma = Int(max(0, min(255, 0.299 * pixels[y * width + x][0] + 0.587 * pixels[y * width + x][1] + 0.114 * pixels[y * width + x][2])))

                let tx = min(x / tileSize, tilesX - 1)
                let ty = min(y / tileSize, tilesY - 1)

                let newLuma = tileLUTs[ty][tx][luma]
                let ratio = luma > 0 ? newLuma / Float(luma) : 1.0

                result[y * width + x][0] = max(0, min(255, pixels[y * width + x][0] * ratio))
                result[y * width + x][1] = max(0, min(255, pixels[y * width + x][1] * ratio))
                result[y * width + x][2] = max(0, min(255, pixels[y * width + x][2] * ratio))
            }
        }

        pixels = result
    }

    nonisolated static func applyContrast(_ pixels: inout [[Float]], width: Int, height: Int, method: String) {
        switch method {
        case "HE":
            AtariFamilyImageOps.applyHistogramEqualization(&pixels, width: width, height: height)
        case "CLAHE":
            AtariFamilyImageOps.applyCLAHE(&pixels, width: width, height: height, clipLimit: 2.0, tileSize: 8)
        case "SWAHE":
            AtariFamilyImageOps.applySWAHE(&pixels, width: width, height: height, windowSize: 64)
        default:
            break
        }
    }

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

    nonisolated static func applyErrorDiffusion(_ work: inout [[Float]], x: Int, y: Int, width: Int, height: Int,
                                      r: Float, g: Float, b: Float, finalColor: [UInt8],
                                      ditherAlg: String, ditherAmount: Double) {
        let rError = (r - Float(finalColor[0])) * Float(ditherAmount)
        let gError = (g - Float(finalColor[1])) * Float(ditherAmount)
        let bError = (b - Float(finalColor[2])) * Float(ditherAmount)

        if ditherAlg == "Floyd-Steinberg" {
            if x < width - 1 {
                work[y * width + x + 1][0] += rError * 7.0 / 16.0
                work[y * width + x + 1][1] += gError * 7.0 / 16.0
                work[y * width + x + 1][2] += bError * 7.0 / 16.0
            }
            if y < height - 1 {
                if x > 0 {
                    work[(y + 1) * width + x - 1][0] += rError * 3.0 / 16.0
                    work[(y + 1) * width + x - 1][1] += gError * 3.0 / 16.0
                    work[(y + 1) * width + x - 1][2] += bError * 3.0 / 16.0
                }
                work[(y + 1) * width + x][0] += rError * 5.0 / 16.0
                work[(y + 1) * width + x][1] += gError * 5.0 / 16.0
                work[(y + 1) * width + x][2] += bError * 5.0 / 16.0
                if x < width - 1 {
                    work[(y + 1) * width + x + 1][0] += rError * 1.0 / 16.0
                    work[(y + 1) * width + x + 1][1] += gError * 1.0 / 16.0
                    work[(y + 1) * width + x + 1][2] += bError * 1.0 / 16.0
                }
            }
        } else if ditherAlg == "Atkinson" {
            let dist = rError / 8.0
            let distG = gError / 8.0
            let distB = bError / 8.0

            if x < width - 1 {
                work[y * width + x + 1][0] += dist
                work[y * width + x + 1][1] += distG
                work[y * width + x + 1][2] += distB
            }
            if x < width - 2 {
                work[y * width + x + 2][0] += dist
                work[y * width + x + 2][1] += distG
                work[y * width + x + 2][2] += distB
            }
            if y < height - 1 {
                if x > 0 {
                    work[(y + 1) * width + x - 1][0] += dist
                    work[(y + 1) * width + x - 1][1] += distG
                    work[(y + 1) * width + x - 1][2] += distB
                }
                work[(y + 1) * width + x][0] += dist
                work[(y + 1) * width + x][1] += distG
                work[(y + 1) * width + x][2] += distB
                if x < width - 1 {
                    work[(y + 1) * width + x + 1][0] += dist
                    work[(y + 1) * width + x + 1][1] += distG
                    work[(y + 1) * width + x + 1][2] += distB
                }
            }
            if y < height - 2 {
                work[(y + 2) * width + x][0] += dist
                work[(y + 2) * width + x][1] += distG
                work[(y + 2) * width + x][2] += distB
            }
        }
    }

    nonisolated static func applyFilter(_ pixels: inout [[Float]], width: Int, height: Int, filter: String) {
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
            AtariFamilyImageOps.applyConvolution(&pixels, width: width, height: height, kernel: lowpassKernel)
        case "Sharpen":
            AtariFamilyImageOps.applyConvolution(&pixels, width: width, height: height, kernel: sharpenKernel)
        case "Emboss":
            AtariFamilyImageOps.applyConvolution(&pixels, width: width, height: height, kernel: embossKernel)
        case "Edge":
            AtariFamilyImageOps.applyEdgeFilter(&pixels, width: width, height: height)
        default:
            break
        }
    }

    nonisolated static func applyGamma(_ pixels: inout [[Float]], width: Int, height: Int, gamma: Double) {
        let invGamma = 1.0 / gamma
        for i in 0..<pixels.count {
            pixels[i][0] = Float(pow(Double(pixels[i][0]) / 255.0, invGamma) * 255.0)
            pixels[i][1] = Float(pow(Double(pixels[i][1]) / 255.0, invGamma) * 255.0)
            pixels[i][2] = Float(pow(Double(pixels[i][2]) / 255.0, invGamma) * 255.0)
        }
    }

    nonisolated static func applyHistogramEqualization(_ pixels: inout [[Float]], width: Int, height: Int) {
        var histogram = [Int](repeating: 0, count: 256)
        for pixel in pixels {
            let luma = Int(max(0, min(255, 0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2])))
            histogram[luma] += 1
        }

        var cdf = [Int](repeating: 0, count: 256)
        cdf[0] = histogram[0]
        for i in 1..<256 {
            cdf[i] = cdf[i - 1] + histogram[i]
        }

        let cdfMin = cdf.first(where: { $0 > 0 }) ?? 0
        let totalPixels = width * height
        var lut = [Float](repeating: 0, count: 256)
        for i in 0..<256 {
            lut[i] = Float((cdf[i] - cdfMin) * 255 / max(1, totalPixels - cdfMin))
        }

        for i in 0..<pixels.count {
            let luma = Int(max(0, min(255, 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2])))
            let ratio = luma > 0 ? lut[luma] / Float(luma) : 1.0
            pixels[i][0] = max(0, min(255, pixels[i][0] * ratio))
            pixels[i][1] = max(0, min(255, pixels[i][1] * ratio))
            pixels[i][2] = max(0, min(255, pixels[i][2] * ratio))
        }
    }

    nonisolated static func applyOrderedDither(_ pixels: inout [[Float]], width: Int, height: Int, ditherType: String, amount: Double) {
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
        case "Bayer 16x16":
            var m = [[Float]](repeating: [Float](repeating: 0, count: 16), count: 16)
            let base: [[Float]] = [
                [0, 8, 2, 10],
                [12, 4, 14, 6],
                [3, 11, 1, 9],
                [15, 7, 13, 5]
            ]
            for y in 0..<16 {
                for x in 0..<16 {
                    m[y][x] = base[y % 4][x % 4] * 16 + base[y / 4][x / 4]
                }
            }
            matrix = m
            matrixSize = 16
        case "Blue Noise 8x8", "Blue Noise 16x16":
            let size = ditherType == "Blue Noise 8x8" ? 8 : 16
            var m = [[Float]](repeating: [Float](repeating: 0, count: size), count: size)
            for y in 0..<size {
                for x in 0..<size {
                    let golden = 0.618033988749895
                    let hash = Double((x * 12345 + y * 67890) & 0xFFFF) / 65536.0
                    m[y][x] = Float((hash + golden).truncatingRemainder(dividingBy: 1.0) * Double(size * size))
                }
            }
            matrix = m
            matrixSize = size
        case "Noise":
            for i in 0..<pixels.count {
                let noise = (Float.random(in: 0...1) - 0.5) * 32.0 * Float(amount)
                pixels[i][0] = max(0, min(255, pixels[i][0] + noise))
                pixels[i][1] = max(0, min(255, pixels[i][1] + noise))
                pixels[i][2] = max(0, min(255, pixels[i][2] + noise))
            }
            return
        default:
            return
        }

        let maxVal = Float(matrixSize * matrixSize)
        let strength = Float(amount) * 64.0

        for y in 0..<height {
            for x in 0..<width {
                let threshold = (matrix[y % matrixSize][x % matrixSize] / maxVal - 0.5) * strength
                let idx = y * width + x
                pixels[idx][0] = max(0, min(255, pixels[idx][0] + threshold))
                pixels[idx][1] = max(0, min(255, pixels[idx][1] + threshold))
                pixels[idx][2] = max(0, min(255, pixels[idx][2] + threshold))
            }
        }
    }

    nonisolated static func applySWAHE(_ pixels: inout [[Float]], width: Int, height: Int, windowSize: Int) {
        let halfWindow = windowSize / 2
        var result = pixels

        var histogram = [Int](repeating: 0, count: 256)
        var pixelCount = 0

        for y in 0..<min(halfWindow, height) {
            for x in 0..<min(windowSize, width) {
                let luma = Int(max(0, min(255, 0.299 * pixels[y * width + x][0] + 0.587 * pixels[y * width + x][1] + 0.114 * pixels[y * width + x][2])))
                histogram[luma] += 1
                pixelCount += 1
            }
        }

        for y in 0..<height {
            for x in 0..<width {
                let luma = Int(max(0, min(255, 0.299 * pixels[y * width + x][0] + 0.587 * pixels[y * width + x][1] + 0.114 * pixels[y * width + x][2])))

                var cdf = 0
                for i in 0...luma {
                    cdf += histogram[i]
                }

                let newLuma = pixelCount > 0 ? Float(cdf * 255) / Float(pixelCount) : Float(luma)
                let ratio = luma > 0 ? newLuma / Float(luma) : 1.0

                result[y * width + x][0] = max(0, min(255, pixels[y * width + x][0] * ratio))
                result[y * width + x][1] = max(0, min(255, pixels[y * width + x][1] * ratio))
                result[y * width + x][2] = max(0, min(255, pixels[y * width + x][2] * ratio))

                if x + halfWindow < width {
                    for dy in max(0, y - halfWindow)..<min(height, y + halfWindow) {
                        let addLuma = Int(max(0, min(255, 0.299 * pixels[dy * width + x + halfWindow][0] + 0.587 * pixels[dy * width + x + halfWindow][1] + 0.114 * pixels[dy * width + x + halfWindow][2])))
                        histogram[addLuma] += 1
                        pixelCount += 1
                    }
                }
                if x - halfWindow >= 0 {
                    for dy in max(0, y - halfWindow)..<min(height, y + halfWindow) {
                        let remLuma = Int(max(0, min(255, 0.299 * pixels[dy * width + x - halfWindow][0] + 0.587 * pixels[dy * width + x - halfWindow][1] + 0.114 * pixels[dy * width + x - halfWindow][2])))
                        histogram[remLuma] -= 1
                        pixelCount -= 1
                    }
                }
            }
        }

        pixels = result
    }

    nonisolated static func applySaturation(_ pixels: inout [[Float]], width: Int, height: Int, saturation: Double) {
        let sat = Float(saturation)
        for i in 0..<pixels.count {
            let r = pixels[i][0]
            let g = pixels[i][1]
            let b = pixels[i][2]
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            pixels[i][0] = max(0, min(255, gray + (r - gray) * sat))
            pixels[i][1] = max(0, min(255, gray + (g - gray) * sat))
            pixels[i][2] = max(0, min(255, gray + (b - gray) * sat))
        }
    }

    nonisolated static func findClosestColor(r: Float, g: Float, b: Float, palette: [[UInt8]], method: String) -> Int {
        var bestIndex = 0
        var bestDist = Float.greatestFiniteMagnitude

        for (i, color) in palette.enumerated() {
            let pr = Float(color[0])
            let pg = Float(color[1])
            let pb = Float(color[2])

            let dist: Float
            switch method {
            case "Perceptive":
                let rmean = (r + pr) / 2.0
                let dr = r - pr
                let dg = g - pg
                let db = b - pb
                dist = sqrt((2.0 + rmean / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rmean) / 256.0) * db * db)
            case "Luma":
                let luma1 = 0.299 * r + 0.587 * g + 0.114 * b
                let luma2 = 0.299 * pr + 0.587 * pg + 0.114 * pb
                dist = abs(luma1 - luma2)
            case "Chroma":
                let dr = r - pr
                let dg = g - pg
                let db = b - pb
                dist = sqrt(dr * dr * 0.5 + dg * dg * 0.5 + db * db * 0.5) + abs((r - g) - (pr - pg)) + abs((g - b) - (pg - pb))
            case "Hue":
                let (h1, s1, l1) = AtariFamilyImageOps.rgbToHsl(r, g, b)
                let (h2, s2, l2) = AtariFamilyImageOps.rgbToHsl(pr, pg, pb)
                var hueDiff = abs(h1 - h2)
                if hueDiff > 180 { hueDiff = 360 - hueDiff }
                let minSat = min(s1, s2)
                let hueWeight: Float = 4.0 * minSat
                dist = (hueDiff / 180.0) * 255.0 * hueWeight + abs(s1 - s2) * 255.0 + abs(l1 - l2) * 255.0 * 0.5
            default: // Euclidean
                let dr = r - pr
                let dg = g - pg
                let db = b - pb
                dist = sqrt(dr * dr + dg * dg + db * db)
            }

            if dist < bestDist {
                bestDist = dist
                bestIndex = i
            }
        }

        return min(max(bestIndex, 0), palette.count - 1)
    }

    nonisolated static func getPixelData(from image: NSImage, width: Int, height: Int) -> [[Float]]? {
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

    nonisolated static func rgbToHsl(_ r: Float, _ g: Float, _ b: Float) -> (Float, Float, Float) {
        let rn = r / 255.0
        let gn = g / 255.0
        let bn = b / 255.0

        let maxC = max(rn, gn, bn)
        let minC = min(rn, gn, bn)
        let delta = maxC - minC

        let l = (maxC + minC) / 2.0

        var h: Float = 0
        var s: Float = 0

        if delta > 0 {
            s = delta / (1.0 - abs(2.0 * l - 1.0))

            if maxC == rn {
                h = 60.0 * (((gn - bn) / delta).truncatingRemainder(dividingBy: 6.0))
            } else if maxC == gn {
                h = 60.0 * ((bn - rn) / delta + 2.0)
            } else {
                h = 60.0 * ((rn - gn) / delta + 4.0)
            }

            if h < 0 { h += 360.0 }
        }

        return (h, s, l)
    }

    nonisolated static func scaleImage(_ cgImage: CGImage, toWidth width: Int, height: Int) -> [[Float]] {
        let context = CGContext(data: nil,
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let data = context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var pixels = [[Float]](repeating: [0, 0, 0], count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4
                pixels[y * width + x] = [Float(data[idx]), Float(data[idx + 1]), Float(data[idx + 2])]
            }
        }

        return pixels
    }
}
