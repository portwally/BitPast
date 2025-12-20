import Cocoa

class AppleIIGSConverter: RetroMachine {
    var name: String = "Apple IIgs"
    
    var options: [ConversionOption] = [
        // 1. MODUS
        ConversionOption(
            label: "Display Mode",
            key: "mode",
            values: [
                "3200 Mode (Smart Scanlines)",
                "3200 Mode (Vertical Strips)",
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
        
        // 3. DITHER STÄRKE
        // FIX: Maximal 1.0, sonst explodiert die Mathematik (Feedback Loop)
        ConversionOption(
            label: "Dither Strength",
            key: "dither_amount",
            range: 0.0...1.0, // <--- HIER von 1.5 auf 1.0 ändern
            defaultValue: 1.0
        ),
        
        // 4. ERROR THRESHOLD
        ConversionOption(
            label: "Merge Tolerance (3200 Mode)",
            key: "threshold",
            range: 0.0...50.0,
            defaultValue: 10.0
        ),
        
        // 5. SATURATION BOOST
        ConversionOption(
            label: "Saturation Boost",
            key: "saturation",
            range: 0.0...2.0,
            defaultValue: 1.1
        ),
        
        // 6. GAMMA (FIX: Jetzt als Double initilisiert)
        ConversionOption(
            label: "Gamma / Brightness",
            key: "gamma",
            range: 0.5...2.5,
            defaultValue: 1.0
        )
    ]
    
    // MARK: - Constants
    private let defaultPalette: [UInt16] = [
        0x0000, 0x0777, 0x0841, 0x072C, 0x000F, 0x0080, 0x0F70, 0x0D00,
        0x0FA2, 0x0F80, 0x0BBB, 0x0F9B, 0x03D0, 0x0DD0, 0x0CCC, 0x0FFF
    ]
    
    private let palette640: [UInt16] = [
        0x0000, 0x0F00, 0x0FFF, 0x000F, 0,0,0,0,0,0,0,0,0,0,0,0
    ]
    
    private let bayerMatrix: [Double] = [
         0,  8,  2, 10,
        12,  4, 14,  6,
         3, 11,  1,  9,
        15,  7, 13,  5
    ]

    // MARK: - Main Conversion
    
    func convert(sourceImage: NSImage) async throws -> ConversionResult {
        
        // --- CONFIG ---
        let modeStr = options.first(where: {$0.key == "mode"})?.selectedValue ?? ""
        let ditherName = options.first(where: {$0.key == "dither"})?.selectedValue ?? "None"
        let ditherAmount = Double(options.first(where: {$0.key == "dither_amount"})?.selectedValue ?? "1") ?? 1.0
        let thresholdVal = Double(options.first(where: {$0.key == "threshold"})?.selectedValue ?? "10") ?? 10.0
        let saturation = Double(options.first(where: {$0.key == "saturation"})?.selectedValue ?? "1") ?? 1.0
        let gamma = Double(options.first(where: {$0.key == "gamma"})?.selectedValue ?? "1") ?? 1.0
        
        let threshold = thresholdVal * 4.0
        
        let is640 = modeStr.contains("640")
        let isSmart3200 = modeStr.contains("Smart")
        let isStrip3200 = modeStr.contains("Vertical")
        
        let targetW = is640 ? 640 : 320
        let targetH = 200
        
        // --- PREPARE IMAGE ---
        let resized = sourceImage.fitToStandardSize(targetWidth: targetW, targetHeight: targetH)
        guard let cgImage = resized.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "IIGS", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CGImage"])
        }
        
        var rawInput = getRGBData(from: cgImage, width: targetW, height: targetH)
        if saturation != 1.0 { applySaturation(&rawInput, amount: saturation) }
        
        let ditherKernel = getDitherKernel(name: ditherName)
        let isOrderedDither = ditherName.contains("Ordered")
        let isNoDither = ditherName == "None"
        
        // --- BUFFERS ---
        var pixelData = [UInt8](repeating: 0, count: 32000)
        var scbData = [UInt8](repeating: 0, count: 256)
        var palettes: [[UInt16]] = Array(repeating: defaultPalette, count: 16)
        var previewRawData = [UInt8](repeating: 255, count: targetW * targetH * 4)
        
        // --- PALETTE GENERATION (MEDIAN CUT) ---
        
        if is640 {
            palettes[0] = palette640
            for i in 0..<200 { scbData[i] = 0x80 }
        } else if isStrip3200 {
            for pIndex in 0..<16 {
                let startY = (pIndex * targetH) / 16
                let endY = ((pIndex + 1) * targetH) / 16
                var sectionPixels: [PixelFloat] = []
                sectionPixels.reserveCapacity(targetW * (endY - startY))
                for y in startY..<endY {
                    let rowStart = y * targetW
                    sectionPixels.append(contentsOf: rawInput[rowStart..<(rowStart + targetW)])
                }
                palettes[pIndex] = generatePaletteMedianCut(pixels: sectionPixels, maxColors: 16)
                for y in startY..<endY { if y < 200 { scbData[y] = UInt8(pIndex) } }
            }
        } else if isSmart3200 {
            var scanlines: [ScanlineInfo] = []
            for y in 0..<targetH {
                scanlines.append(ScanlineInfo(y: y, avg: calculateAverageColor(rawInput, y: y, w: targetW)))
            }
            let groups = clusterScanlines(scanlines, depth: 0, maxDepth: 4, threshold: threshold)
            for (pIndex, group) in groups.enumerated() {
                if pIndex >= 16 { break }
                var groupPixels: [PixelFloat] = []
                for line in group {
                    let rowStart = line.y * targetW
                    for x in stride(from: 0, to: targetW, by: 2) { groupPixels.append(rawInput[rowStart + x]) }
                }
                palettes[pIndex] = generatePaletteMedianCut(pixels: groupPixels, maxColors: 16)
                for line in group { scbData[line.y] = UInt8(pIndex) }
            }
        } else {
            var samplePixels: [PixelFloat] = []
            for i in stride(from: 0, to: rawInput.count, by: 4) { samplePixels.append(rawInput[i]) }
            palettes[0] = generatePaletteMedianCut(pixels: samplePixels, maxColors: 16)
        }
        
        // --- RENDERING LOOP ---
        
        for y in 0..<targetH {
            let paletteIndex = Int(scbData[y] & 0x0F)
            let currentPalette12 = palettes[paletteIndex]
            let currentPaletteRGB = currentPalette12.map { iigsColorToRGB(iigs: $0) }
            
            for x in 0..<targetW {
                let index = (y * targetW) + x
                
                // --- FIX GEGEN VERZERRUNG ---
                // Wir holen den Pixel und CLAMPEN ihn sofort.
                // Das verhindert, dass aufaddierte Fehler (durch Dither) zu Werten wie -500 oder +800 führen.
                var p = rawInput[index]
                p.r = p.r.clamped(to: 0...255)
                p.g = p.g.clamped(to: 0...255)
                p.b = p.b.clamped(to: 0...255)
                
                // GAMMA (optional auch hier clampen)
                if gamma != 1.0 {
                    p.r = (pow(p.r / 255.0, 1.0/gamma) * 255.0).clamped(to: 0...255)
                    p.g = (pow(p.g / 255.0, 1.0/gamma) * 255.0).clamped(to: 0...255)
                    p.b = (pow(p.b / 255.0, 1.0/gamma) * 255.0).clamped(to: 0...255)
                }
                
                if isOrderedDither {
                    let bayerVal = bayerMatrix[(y % 4) * 4 + (x % 4)] / 16.0
                    let spread = 32.0 * ditherAmount
                    let offset = (bayerVal - 0.5) * spread
                    p.r = (p.r + offset).clamped(to: 0...255)
                    p.g = (p.g + offset).clamped(to: 0...255)
                    p.b = (p.b + offset).clamped(to: 0...255)
                }
                
                // Matching
                let match = findNearestColor(pixel: p, palette: currentPaletteRGB)
                let colorIdx = match.index
                
                // Error Diffusion
                if !isNoDither && !isOrderedDither {
                    let errR = (p.r - Double(match.rgb.r)) * ditherAmount
                    let errG = (p.g - Double(match.rgb.g)) * ditherAmount
                    let errB = (p.b - Double(match.rgb.b)) * ditherAmount
                    
                    distributeError(source: &rawInput, x: x, y: y, w: targetW, h: targetH,
                                    errR: errR, errG: errG, errB: errB,
                                    kernel: ditherKernel)
                }
                
                // Store
                if is640 {
                    let bytePos = (y * 160) + (x / 4)
                    let bitShift = (3 - (x % 4)) * 2
                    pixelData[bytePos] |= UInt8((colorIdx & 0x03) << bitShift)
                } else {
                    let bytePos = (y * 160) + (x / 2)
                    if x % 2 == 0 { pixelData[bytePos] |= UInt8(colorIdx & 0x0F) }
                    else          { pixelData[bytePos] |= UInt8((colorIdx & 0x0F) << 4) }
                }
                
                // Preview
                let pIdx = index * 4
                previewRawData[pIdx] = match.rgb.r
                previewRawData[pIdx+1] = match.rgb.g
                previewRawData[pIdx+2] = match.rgb.b
                previewRawData[pIdx+3] = 255
            }
        }
        
        // --- FINALIZE ---
        var finalPreview: NSImage?
        let colorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        if let ctx = CGContext(data: &previewRawData, width: targetW, height: targetH, bitsPerComponent: 8, bytesPerRow: targetW * 4, space: colorSpace, bitmapInfo: bitmapInfo),
           let imgRef = ctx.makeImage() {
            finalPreview = NSImage(cgImage: imgRef, size: NSSize(width: targetW, height: targetH))
        } else {
            finalPreview = NSImage(size: NSSize(width: targetW, height: targetH))
        }
        
        var fileData = Data()
        fileData.append(contentsOf: pixelData)
        fileData.append(contentsOf: scbData)
        var paletteBytes = Data()
        for pal in palettes {
            for color in pal {
                paletteBytes.append(UInt8(color & 0xFF))
                paletteBytes.append(UInt8((color >> 8) & 0xFF))
            }
            if pal.count < 16 { paletteBytes.append(contentsOf: [UInt8](repeating: 0, count: (16 - pal.count) * 2)) }
        }
        fileData.append(paletteBytes)
        
        let fileManager = FileManager.default
        let uuid = UUID().uuidString.prefix(8)
        let outputUrl = fileManager.temporaryDirectory.appendingPathComponent("gs_\(uuid).shr")
        try fileData.write(to: outputUrl)
        
        return ConversionResult(previewImage: finalPreview!, fileAssets: [outputUrl])
    }
    
    // MARK: - MEDIAN CUT QUANTIZER
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
            return RGB(r: UInt8(r/c), g: UInt8(g/c), b: UInt8(b/c))
        }
    }
    
    func generatePaletteMedianCut(pixels: [PixelFloat], maxColors: Int) -> [UInt16] {
        if pixels.isEmpty { return Array(repeating: 0x0000, count: maxColors) }
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
        var iigsPalette = boxes.map { rgbToIIGS($0.getAverageColor()) }
        while iigsPalette.count < maxColors { iigsPalette.append(0x0000) }
        return iigsPalette
    }

    // MARK: - Helper Methods
    func applySaturation(_ pixels: inout [PixelFloat], amount: Double) {
        for i in 0..<pixels.count {
            let p = pixels[i]
            let gray = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b
            pixels[i].r = (gray + (p.r - gray) * amount).clamped(to: 0...255)
            pixels[i].g = (gray + (p.g - gray) * amount).clamped(to: 0...255)
            pixels[i].b = (gray + (p.b - gray) * amount).clamped(to: 0...255)
        }
    }
    
    struct ScanlineInfo { let y: Int; let avg: PixelFloat }
    func calculateAverageColor(_ pixels: [PixelFloat], y: Int, w: Int) -> PixelFloat {
        var r: Double = 0, g: Double = 0, b: Double = 0
        let start = y * w
        for i in 0..<w { r += pixels[start+i].r; g += pixels[start+i].g; b += pixels[start+i].b }
        let count = Double(w)
        return PixelFloat(r: r/count, g: g/count, b: b/count)
    }
    
    func clusterScanlines(_ lines: [ScanlineInfo], depth: Int, maxDepth: Int, threshold: Double) -> [[ScanlineInfo]] {
        if lines.isEmpty { return [] }
        var minR=999.0, maxR = -1.0, minG=999.0, maxG = -1.0, minB=999.0, maxB = -1.0
        for l in lines {
            minR=min(minR, l.avg.r); maxR=max(maxR, l.avg.r)
            minG=min(minG, l.avg.g); maxG=max(maxG, l.avg.g)
            minB=min(minB, l.avg.b); maxB=max(maxB, l.avg.b)
        }
        let dR = maxR-minR, dG = maxG-minG, dB = maxB-minB
        let err = sqrt(dR*dR + dG*dG + dB*dB)
        if depth >= maxDepth || err <= threshold { return [lines] }
        let sorted: [ScanlineInfo]
        if dR >= dG && dR >= dB { sorted = lines.sorted { $0.avg.r < $1.avg.r } }
        else if dG >= dR && dG >= dB { sorted = lines.sorted { $0.avg.g < $1.avg.g } }
        else { sorted = lines.sorted { $0.avg.b < $1.avg.b } }
        let mid = sorted.count / 2
        return clusterScanlines(Array(sorted[0..<mid]), depth: depth+1, maxDepth: maxDepth, threshold: threshold) +
               clusterScanlines(Array(sorted[mid..<sorted.count]), depth: depth+1, maxDepth: maxDepth, threshold: threshold)
    }
    
    struct DitherError { let dx: Int; let dy: Int; let factor: Double }
    func getDitherKernel(name: String) -> [DitherError] {
        switch name {
        case "Atkinson": return [DitherError(dx: 1, dy: 0, factor: 1/8), DitherError(dx: 2, dy: 0, factor: 1/8), DitherError(dx: -1, dy: 1, factor: 1/8), DitherError(dx: 0, dy: 1, factor: 1/8), DitherError(dx: 1, dy: 1, factor: 1/8), DitherError(dx: 0, dy: 2, factor: 1/8)]
        case "Jarvis-Judice-Ninke": return [DitherError(dx: 1, dy: 0, factor: 7/48), DitherError(dx: 2, dy: 0, factor: 5/48), DitherError(dx: -2, dy: 1, factor: 3/48), DitherError(dx: -1, dy: 1, factor: 5/48), DitherError(dx: 0, dy: 1, factor: 7/48), DitherError(dx: 1, dy: 1, factor: 5/48), DitherError(dx: 2, dy: 1, factor: 3/48), DitherError(dx: -2, dy: 2, factor: 1/48), DitherError(dx: -1, dy: 2, factor: 3/48), DitherError(dx: 0, dy: 2, factor: 5/48), DitherError(dx: 1, dy: 2, factor: 3/48), DitherError(dx: 2, dy: 2, factor: 1/48)]
        case "Stucki": return [DitherError(dx: 1, dy: 0, factor: 8/42), DitherError(dx: 2, dy: 0, factor: 4/42), DitherError(dx: -2, dy: 1, factor: 2/42), DitherError(dx: -1, dy: 1, factor: 4/42), DitherError(dx: 0, dy: 1, factor: 8/42), DitherError(dx: 1, dy: 1, factor: 4/42), DitherError(dx: 2, dy: 1, factor: 2/42), DitherError(dx: -2, dy: 2, factor: 1/42), DitherError(dx: -1, dy: 2, factor: 2/42), DitherError(dx: 0, dy: 2, factor: 4/42), DitherError(dx: 1, dy: 2, factor: 2/42), DitherError(dx: 2, dy: 2, factor: 1/42)]
        case "Burkes": return [DitherError(dx: 1, dy: 0, factor: 8/32), DitherError(dx: 2, dy: 0, factor: 4/32), DitherError(dx: -2, dy: 1, factor: 2/32), DitherError(dx: -1, dy: 1, factor: 4/32), DitherError(dx: 0, dy: 1, factor: 8/32), DitherError(dx: 1, dy: 1, factor: 4/32), DitherError(dx: 2, dy: 1, factor: 2/32)]
        default: return [DitherError(dx: 1, dy: 0, factor: 7/16), DitherError(dx: -1, dy: 1, factor: 3/16), DitherError(dx: 0, dy: 1, factor: 5/16), DitherError(dx: 1, dy: 1, factor: 1/16)]
        }
    }
    
    struct RGB: Hashable { var r: UInt8; var g: UInt8; var b: UInt8 }
    struct PixelFloat { var r: Double; var g: Double; var b: Double }
    struct ColorMatch { var index: Int; var rgb: RGB }
    
    func getRGBData(from cgImage: CGImage, width: Int, height: Int) -> [PixelFloat] {
        var pixels = [PixelFloat](repeating: PixelFloat(r: 0, g: 0, b: 0), count: width * height)
        let colorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var rawBytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(data: &rawBytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else { return pixels }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        for i in 0..<(width*height) { pixels[i] = PixelFloat(r: Double(rawBytes[i*4]), g: Double(rawBytes[i*4+1]), b: Double(rawBytes[i*4+2])) }
        return pixels
    }
    
    func findNearestColor(pixel: PixelFloat, palette: [RGB]) -> ColorMatch {
        var minDiv = Double.greatestFiniteMagnitude
        var bestIdx = 0
        for (i, p) in palette.enumerated() {
            let dr = pixel.r - Double(p.r); let dg = pixel.g - Double(p.g); let db = pixel.b - Double(p.b)
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
        let r4 = UInt16(rgb.r / 17) & 0x0F
        let g4 = UInt16(rgb.g / 17) & 0x0F
        let b4 = UInt16(rgb.b / 17) & 0x0F
        return (r4 << 8) | (g4 << 4) | b4
    }
    
    func iigsColorToRGB(iigs: UInt16) -> RGB {
        let r4 = (iigs >> 8) & 0x0F
        let g4 = (iigs >> 4) & 0x0F
        let b4 = iigs & 0x0F
        return RGB(r: UInt8(r4*17), g: UInt8(g4*17), b: UInt8(b4*17))
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self { return min(max(self, limits.lowerBound), limits.upperBound) }
}
