import Cocoa

/// Image helpers first written for the Amiga converters and shared, unchanged, by:
/// Amiga1200, Amiga500, MSX, PC.
/// Other converters keep their own versions where the algorithm differs.
enum AmigaFamilyImageOps {
    nonisolated static func applyConvolution(_ pixels: inout [[Float]], width: Int, height: Int, kernel: [[Float]]) {
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

    nonisolated static func applyEdgeFilter(_ pixels: inout [[Float]], width: Int, height: Int) {
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

    nonisolated static func applyGamma(_ pixels: inout [[Float]], width: Int, height: Int, gamma: Double) {
        let inv = 1.0 / gamma
        for i in 0..<pixels.count {
            pixels[i][0] = Float(pow(Double(pixels[i][0]) / 255.0, inv) * 255.0)
            pixels[i][1] = Float(pow(Double(pixels[i][1]) / 255.0, inv) * 255.0)
            pixels[i][2] = Float(pow(Double(pixels[i][2]) / 255.0, inv) * 255.0)
        }
    }

    nonisolated static func applyImageFilter(_ pixels: inout [[Float]], width: Int, height: Int, filter: String) {
        let lowpassKernel: [[Float]] = [[1.0/9,1.0/9,1.0/9],[1.0/9,1.0/9,1.0/9],[1.0/9,1.0/9,1.0/9]]
        let sharpenKernel: [[Float]] = [[0,-1,0],[-1,5,-1],[0,-1,0]]
        let embossKernel: [[Float]] = [[-2,-1,0],[-1,1,1],[0,1,2]]
        switch filter {
        case "Lowpass": AmigaFamilyImageOps.applyConvolution(&pixels, width: width, height: height, kernel: lowpassKernel)
        case "Sharpen": AmigaFamilyImageOps.applyConvolution(&pixels, width: width, height: height, kernel: sharpenKernel)
        case "Emboss": AmigaFamilyImageOps.applyConvolution(&pixels, width: width, height: height, kernel: embossKernel)
        case "Edge": AmigaFamilyImageOps.applyEdgeFilter(&pixels, width: width, height: height)
        default: break
        }
    }

    nonisolated static func applyOrderedDither(_ pixels: inout [[Float]], width: Int, height: Int, ditherType: String, amount: Double) {
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

    nonisolated static func applySaturation(_ pixels: inout [[Float]], width: Int, height: Int, saturation: Double) {
        let sat = Float(saturation)
        for i in 0..<pixels.count {
            let gray = 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2]
            pixels[i][0] = max(0, min(255, gray + (pixels[i][0] - gray) * sat))
            pixels[i][1] = max(0, min(255, gray + (pixels[i][1] - gray) * sat))
            pixels[i][2] = max(0, min(255, gray + (pixels[i][2] - gray) * sat))
        }
    }

    nonisolated static func colorDistance(_ r1: Float, _ g1: Float, _ b1: Float, _ r2: Float, _ g2: Float, _ b2: Float, _ method: String) -> Float {
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

    nonisolated static func createIFF(width: Int, height: Int, palette: [[UInt8]], bitplanes: [[UInt16]],
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

    nonisolated static func distributeError(_ work: inout [[Float]], width: Int, height: Int, x: Int, y: Int,
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

    nonisolated static func findClosestColor(r: Float, g: Float, b: Float, palette: [[UInt8]], method: String) -> Int {
        var bestIdx = 0
        var bestDist = Float.greatestFiniteMagnitude
        for (i, c) in palette.enumerated() {
            let d = AmigaFamilyImageOps.colorDistance(r, g, b, Float(c[0]), Float(c[1]), Float(c[2]), method)
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        return min(max(bestIdx, 0), palette.count - 1)
    }

    nonisolated static func rgbToHsl(_ r: Float, _ g: Float, _ b: Float) -> (h: Float, s: Float, l: Float) {
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

    nonisolated static func scaleImage(_ cgImage: CGImage, toWidth width: Int, height: Int) -> [[Float]] {
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
}
