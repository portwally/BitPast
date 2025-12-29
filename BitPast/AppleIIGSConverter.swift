import Cocoa

class AppleIIGSConverter: RetroMachine {
    var name: String = "Apple IIgs"
    
    var options: [ConversionOption] = [
        // 1. MODE
        ConversionOption(
            label: "Display Mode",
            key: "mode",
            values: [
                "3200 Mode (Smart Scanlines)",
                "320x200 (16 Colors)",
                "640x200 (4 Colors)"
            ],
            selectedValue: "3200 Mode (Smart Scanlines)"
        ),
        
        // 2. DITHERING ALGO
        ConversionOption(
            label: "Dithering Algo",
            key: "dither",
            values: [
                "Floyd-Steinberg",
                "Atkinson",
                "Jarvis-Judice-Ninke",
                "Stucki",
                "Burkes",
                "Ordered (Bayer 4x4)",
                "None"
            ],
            selectedValue: "Floyd-Steinberg"
        ),
        
        // 3. DITHER STRENGTH
        ConversionOption(
            label: "Dither Strength",
            key: "dither_amount",
            range: 0.0...1.0,
            defaultValue: 1.0
        ),
        
        // 4. ERROR THRESHOLD
        ConversionOption(
            label: "Merge Tolerance",
            key: "threshold",
            range: 0.0...50.0,
            defaultValue: 10.0
        ),
        
        // 5. SATURATION
        ConversionOption(
            label: "Saturation Boost",
            key: "saturation",
            range: 0.0...2.0,
            defaultValue: 1.1
        )
    ]
    
    // MARK: - Global Structs (HIER DEFINIERT DAMIT SIE ÜBERALL SICHTBAR SIND)
    
    struct RGB { var r: Double; var g: Double; var b: Double }
    struct PixelFloat { var r: Double; var g: Double; var b: Double }
    struct DitherError { let dx: Int; let dy: Int; let factor: Double }
    struct ColorMatch { let index: Int; let rgb: RGB }
    
    // Struct für Median Cut
    struct ColorBox {
        var pixels: [PixelFloat]
        func getLongestAxis() -> Int {
            var minR=999.0, maxR = -1.0, minG=999.0, maxG = -1.0, minB=999.0, maxB = -1.0
            for p in pixels {
                minR=min(minR, p.r); maxR=max(maxR, p.r)
                minG=min(minG, p.g); maxG=max(maxG, p.g)
                minB=min(minB, p.b); maxB=max(maxB, p.b)
            }
            let dR = maxR-minR, dG = maxG-minG, dB = maxB-minB
            if dR >= dG && dR >= dB { return 0 }
            if dG >= dR && dG >= dB { return 1 }
            return 2
        }
        func getAverageColor() -> RGB {
            var r: Double=0, g: Double=0, b: Double=0
            if pixels.isEmpty { return RGB(r:0,g:0,b:0) }
            for p in pixels { r+=p.r; g+=p.g; b+=p.b }
            let c = Double(pixels.count)
            return RGB(r: r/c, g: g/c, b: b/c)
        }
    }
    
    // Bayer Matrix
    private let bayerMatrix: [Double] = [
         0,  8,  2, 10,
        12,  4, 14,  6,
         3, 11,  1,  9,
        15,  7, 13,  5
    ]
    
    // MARK: - Main Conversion
    
    func convert(sourceImage: NSImage) async throws -> ConversionResult {
        
        // --- CONFIG ---
        let mode = options.first(where: {$0.key == "mode"})?.selectedValue ?? "3200 Mode (Smart Scanlines)"
        let ditherName = options.first(where: {$0.key == "dither"})?.selectedValue ?? "None"
        let ditherAmount = Double(options.first(where: {$0.key == "dither_amount"})?.selectedValue ?? "1.0") ?? 1.0
        let saturation = Double(options.first(where: {$0.key == "saturation"})?.selectedValue ?? "1.0") ?? 1.0
        
        let is640 = mode.contains("640")
        let is3200 = mode.contains("3200")
        
        let targetW = is640 ? 640 : 320
        let targetH = 200
        
        // 1. Resize & Pixel Data
        let resized = sourceImage.fitToStandardSize(targetWidth: targetW, targetHeight: targetH)
        guard let cgImage = resized.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "IIGS", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CGImage"])
        }
        
        var rawPixels = getRGBData(from: cgImage, width: targetW, height: targetH)
        
        // 2. Saturation Boost
        if saturation != 1.0 { applySaturation(&rawPixels, amount: saturation) }
        
        // 3. Setup Dither
        let kernel = getDitherKernel(name: ditherName)
        let isOrdered = ditherName.contains("Ordered")
        let isNone = ditherName == "None"
        
        // 4. Buffers
        var outputIndices = [Int](repeating: 0, count: targetW * targetH)
        var finalPalettes = [[RGB]]()
        
        // --- PALETTE LOGIC ---
        
        if is640 {
            // A. 640 MODE
            var samplePixels: [PixelFloat] = []
            for i in stride(from: 0, to: rawPixels.count, by: 2) {
                let p = rawPixels[i]
                samplePixels.append(PixelFloat(r: max(0, min(255, p.r)), g: max(0, min(255, p.g)), b: max(0, min(255, p.b))))
            }
            
            let best4 = generatePaletteMedianCut(pixels: samplePixels, maxColors: 4)
            var expandedPalette = [RGB]()
            for i in 0..<16 {
                expandedPalette.append(best4.isEmpty ? RGB(r:0,g:0,b:0) : best4[i % best4.count])
            }
            for _ in 0..<200 { finalPalettes.append(expandedPalette) }
            
        } else if !is3200 {
            // B. STANDARD 320 MODE
            var samplePixels: [PixelFloat] = []
            for i in stride(from: 0, to: rawPixels.count, by: 4) {
                let p = rawPixels[i]
                samplePixels.append(PixelFloat(r: max(0, min(255, p.r)), g: max(0, min(255, p.g)), b: max(0, min(255, p.b))))
            }
            
            let best16 = generatePaletteMedianCut(pixels: samplePixels, maxColors: 16)
            for _ in 0..<200 { finalPalettes.append(best16) }
            
        } else {
            // C. 3200 MODE (Palette per Line)
            for y in 0..<targetH {
                let rowStart = y * targetW
                let rowEnd = rowStart + targetW
                
                var cleanRowPixels: [PixelFloat] = []
                cleanRowPixels.reserveCapacity(targetW)
                
                for i in rowStart..<rowEnd {
                    let p = rawPixels[i]
                    let safeP = PixelFloat(
                        r: max(0, min(255, p.r)),
                        g: max(0, min(255, p.g)),
                        b: max(0, min(255, p.b))
                    )
                    cleanRowPixels.append(safeP)
                }
                
                let linePalette = generatePaletteMedianCut(pixels: cleanRowPixels, maxColors: 16)
                finalPalettes.append(linePalette)
                
                // Dither for this line
                let currentPalette = linePalette
                for x in 0..<targetW {
                    let idx = rowStart + x
                    var p = rawPixels[idx]
                    
                    p.r = min(255, max(0, p.r))
                    p.g = min(255, max(0, p.g))
                    p.b = min(255, max(0, p.b))
                    
                    let match = findNearestColor(pixel: p, palette: currentPalette)
                    outputIndices[idx] = match.index
                    
                    if !isNone && !isOrdered {
                        let errR = (p.r - match.rgb.r) * ditherAmount
                        let errG = (p.g - match.rgb.g) * ditherAmount
                        let errB = (p.b - match.rgb.b) * ditherAmount
                        
                        distributeError(source: &rawPixels, x: x, y: y, w: targetW, h: targetH,
                                        errR: errR, errG: errG, errB: errB,
                                        kernel: kernel)
                    }
                }
            }
        }
        
        // Loop for non-3200 rendering
        if !is3200 {
            for y in 0..<targetH {
                let currentPalette = finalPalettes[y]
                for x in 0..<targetW {
                    let idx = y * targetW + x
                    var p = rawPixels[idx]
                    
                    p.r = min(255, max(0, p.r)); p.g = min(255, max(0, p.g)); p.b = min(255, max(0, p.b))
                    
                    if isOrdered {
                        let bayerVal = bayerMatrix[(y % 4) * 4 + (x % 4)] / 16.0
                        let spread = 32.0 * ditherAmount
                        let offset = (bayerVal - 0.5) * spread
                        p.r = min(255, max(0, p.r + offset))
                        p.g = min(255, max(0, p.g + offset))
                        p.b = min(255, max(0, p.b + offset))
                    }
                    
                    let match = findNearestColor(pixel: p, palette: currentPalette)
                    outputIndices[idx] = match.index
                    
                    if !isNone && !isOrdered {
                        let errR = (p.r - match.rgb.r) * ditherAmount
                        let errG = (p.g - match.rgb.g) * ditherAmount
                        let errB = (p.b - match.rgb.b) * ditherAmount
                        
                        distributeError(source: &rawPixels, x: x, y: y, w: targetW, h: targetH,
                                        errR: errR, errG: errG, errB: errB,
                                        kernel: kernel)
                    }
                }
            }
        }
        
        // 5. Generate Results
        let preview = generatePreviewImage(indices: outputIndices, palettes: finalPalettes, width: targetW, height: targetH)
        let shrData = generateSHRData(indices: outputIndices, palettes: finalPalettes, width: targetW, height: targetH, is640: is640)
        
        let fileManager = FileManager.default
        let uuid = UUID().uuidString.prefix(8)
        let outputUrl = fileManager.temporaryDirectory.appendingPathComponent("iigs_\(uuid).shr")
        try shrData.write(to: outputUrl)
        
        return ConversionResult(previewImage: preview, fileAssets: [outputUrl])
    }
    
    // MARK: - Helper Methods
    
    func applySaturation(_ pixels: inout [PixelFloat], amount: Double) {
        for i in 0..<pixels.count {
            let p = pixels[i]
            let gray = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b
            pixels[i].r = gray + (p.r - gray) * amount
            pixels[i].g = gray + (p.g - gray) * amount
            pixels[i].b = gray + (p.b - gray) * amount
        }
    }
    
    func generatePaletteMedianCut(pixels: [PixelFloat], maxColors: Int) -> [RGB] {
        if pixels.isEmpty { return Array(repeating: RGB(r:0,g:0,b:0), count: maxColors) }
        var boxes = [ColorBox(pixels: pixels)]
        while boxes.count < maxColors {
            guard let splitIndex = boxes.firstIndex(where: { $0.pixels.count > 1 }) else { break }
            let boxToSplit = boxes.remove(at: splitIndex)
            
            let axis = boxToSplit.getLongestAxis()
            let sortedPixels: [PixelFloat]
            if axis == 0 { sortedPixels = boxToSplit.pixels.sorted { $0.r < $1.r } }
            else if axis == 1 { sortedPixels = boxToSplit.pixels.sorted { $0.g < $1.g } }
            else { sortedPixels = boxToSplit.pixels.sorted { $0.b < $1.b } }
            
            let mid = sortedPixels.count / 2
            boxes.append(ColorBox(pixels: Array(sortedPixels[0..<mid])))
            boxes.append(ColorBox(pixels: Array(sortedPixels[mid..<sortedPixels.count])))
        }
        var palette = boxes.map { $0.getAverageColor() }
        while palette.count < maxColors { palette.append(RGB(r:0,g:0,b:0)) }
        return palette
    }
    
    func findNearestColor(pixel: PixelFloat, palette: [RGB]) -> ColorMatch {
        var minDiv = Double.greatestFiniteMagnitude
        var bestIdx = 0
        for (i, p) in palette.enumerated() {
            let dr = pixel.r - p.r; let dg = pixel.g - p.g; let db = pixel.b - p.b
            let dist = dr*dr + dg*dg + db*db
            if dist < minDiv { minDiv = dist; bestIdx = i }
        }
        return ColorMatch(index: bestIdx, rgb: palette[bestIdx])
    }
    
    func distributeError(source: inout [PixelFloat], x: Int, y: Int, w: Int, h: Int, errR: Double, errG: Double, errB: Double, kernel: [DitherError]) {
        for k in kernel {
            let nx = x + k.dx, ny = y + k.dy
            if nx >= 0 && nx < w && ny >= 0 && ny < h {
                let idx = (ny * w) + nx
                source[idx].r += errR * k.factor
                source[idx].g += errG * k.factor
                source[idx].b += errB * k.factor
            }
        }
    }
    
    func rgbToIIGS(_ rgb: RGB) -> UInt16 {
        let r4 = UInt16(min(255, max(0, rgb.r)) / 17) & 0x0F
        let g4 = UInt16(min(255, max(0, rgb.g)) / 17) & 0x0F
        let b4 = UInt16(min(255, max(0, rgb.b)) / 17) & 0x0F
        return (0 << 12) | (r4 << 8) | (g4 << 4) | b4
    }
    
    func generateSHRData(indices: [Int], palettes: [[RGB]], width: Int, height: Int, is640: Bool) -> Data {
        var data = Data(count: 32768)
        let scbOffset = 32000
        let palOffset = 32256
        
        for y in 0..<200 {
            let palIdx = y % 16
            var scbByte = UInt8(palIdx & 0x0F)
            if is640 { scbByte |= 0x80 }
            data[scbOffset + y] = scbByte
        }
        
        for pIdx in 0..<16 {
            let sourcePal = (palettes.count > pIdx) ? palettes[pIdx] : palettes[0]
            for cIdx in 0..<16 {
                let color = sourcePal[cIdx]
                let iigsVal = rgbToIIGS(color)
                let offset = palOffset + (pIdx * 32) + (cIdx * 2)
                data[offset] = UInt8(iigsVal & 0xFF)
                data[offset+1] = UInt8((iigsVal >> 8) & 0xFF)
            }
        }
        
        for y in 0..<height {
            for x in stride(from: 0, to: width, by: is640 ? 4 : 2) {
                let bytePos = (y * 160) + (is640 ? x/4 : x/2)
                if bytePos >= 32000 { continue }
                if is640 {
                    let p1 = (indices[y*width + x] & 0x03)
                    let p2 = (indices[y*width + x+1] & 0x03)
                    let p3 = (indices[y*width + x+2] & 0x03)
                    let p4 = (indices[y*width + x+3] & 0x03)
                    let byte = UInt8(p1 | (p2 << 2) | (p3 << 4) | (p4 << 6))
                    data[bytePos] = byte
                } else {
                    let p1 = indices[y*width + x] & 0x0F
                    let p2 = indices[y*width + x+1] & 0x0F
                    let byte = UInt8(p1 | (p2 << 4))
                    data[bytePos] = byte
                }
            }
        }
        return data
    }
    
    func generatePreviewImage(indices: [Int], palettes: [[RGB]], width: Int, height: Int) -> NSImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            let pal = (y < palettes.count) ? palettes[y] : palettes[0]
            for x in 0..<width {
                let idx = y * width + x
                let cIdx = indices[idx]
                let rgb = (cIdx < pal.count) ? pal[cIdx] : RGB(r:0,g:0,b:0)
                let offset = idx * 4
                
                bytes[offset] = UInt8(max(0, min(255, rgb.r)))
                bytes[offset+1] = UInt8(max(0, min(255, rgb.g)))
                bytes[offset+2] = UInt8(max(0, min(255, rgb.b)))
            }
        }
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let bi = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        if let ctx = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width*4, space: cs, bitmapInfo: bi), let img = ctx.makeImage() {
            return NSImage(cgImage: img, size: NSSize(width: width, height: height))
        }
        return NSImage()
    }
    
    func getRGBData(from cgImage: CGImage, width: Int, height: Int) -> [PixelFloat] {
        var pixels = [PixelFloat](repeating: PixelFloat(r:0,g:0,b:0), count: width*height)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let bi = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var bytes = [UInt8](repeating: 0, count: width*height*4)
        guard let ctx = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width*4, space: cs, bitmapInfo: bi) else { return pixels }
        ctx.draw(cgImage, in: CGRect(x:0, y:0, width: width, height: height))
        for i in 0..<(width*height) {
            pixels[i] = PixelFloat(r: Double(bytes[i*4]), g: Double(bytes[i*4+1]), b: Double(bytes[i*4+2]))
        }
        return pixels
    }
    
    func getDitherKernel(name: String) -> [DitherError] {
        switch name {
        case "Floyd-Steinberg":
            return [DitherError(dx: 1, dy: 0, factor: 7/16), DitherError(dx: -1, dy: 1, factor: 3/16), DitherError(dx: 0, dy: 1, factor: 5/16), DitherError(dx: 1, dy: 1, factor: 1/16)]
        case "Atkinson":
            return [DitherError(dx: 1, dy: 0, factor: 1/8), DitherError(dx: 2, dy: 0, factor: 1/8), DitherError(dx: -1, dy: 1, factor: 1/8), DitherError(dx: 0, dy: 1, factor: 1/8), DitherError(dx: 1, dy: 1, factor: 1/8), DitherError(dx: 0, dy: 2, factor: 1/8)]
        case "Jarvis-Judice-Ninke":
            return [DitherError(dx: 1, dy: 0, factor: 7/48), DitherError(dx: 2, dy: 0, factor: 5/48), DitherError(dx: -2, dy: 1, factor: 3/48), DitherError(dx: -1, dy: 1, factor: 5/48), DitherError(dx: 0, dy: 1, factor: 7/48), DitherError(dx: 1, dy: 1, factor: 5/48), DitherError(dx: 2, dy: 1, factor: 3/48), DitherError(dx: -2, dy: 2, factor: 1/48), DitherError(dx: -1, dy: 2, factor: 3/48), DitherError(dx: 0, dy: 2, factor: 5/48), DitherError(dx: 1, dy: 2, factor: 3/48), DitherError(dx: 2, dy: 2, factor: 1/48)]
        case "Stucki":
            return [DitherError(dx: 1, dy: 0, factor: 8/42), DitherError(dx: 2, dy: 0, factor: 4/42), DitherError(dx: -2, dy: 1, factor: 2/42), DitherError(dx: -1, dy: 1, factor: 4/42), DitherError(dx: 0, dy: 1, factor: 8/42), DitherError(dx: 1, dy: 1, factor: 4/42), DitherError(dx: 2, dy: 1, factor: 2/42), DitherError(dx: -2, dy: 2, factor: 1/42), DitherError(dx: -1, dy: 2, factor: 2/42), DitherError(dx: 0, dy: 2, factor: 4/42), DitherError(dx: 1, dy: 2, factor: 2/42), DitherError(dx: 2, dy: 2, factor: 1/42)]
        case "Burkes":
            return [DitherError(dx: 1, dy: 0, factor: 8/32), DitherError(dx: 2, dy: 0, factor: 4/32), DitherError(dx: -2, dy: 1, factor: 2/32), DitherError(dx: -1, dy: 1, factor: 4/32), DitherError(dx: 0, dy: 1, factor: 8/32), DitherError(dx: 1, dy: 1, factor: 4/32), DitherError(dx: 2, dy: 1, factor: 2/32)]
        default:
            return []
        }
    }
}
