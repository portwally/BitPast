import Cocoa

class AppleIIGSConverter: RetroMachine {
    var name: String = "Apple IIgs (Native)"
    
    var options: [ConversionOption] = [
        // MODUS AUSWAHL
        ConversionOption(
            label: "Display Mode",
            key: "mode",
            values: [
                "3200 Mode (Smart Scanlines)", // NEU: Clustert ähnliche Zeilen
                "3200 Mode (Vertical Strips)", // Klassisch: 16 horizontale Balken
                "320x200 (16 Colors)",         // Standard
                "640x200 (4 Colors)"           // Hi-Res
            ],
            selectedValue: "3200 Mode (Smart Scanlines)"
        ),
        
        ConversionOption(
            label: "Dithering",
            key: "dither",
            values: ["Floyd-Steinberg", "None"],
            selectedValue: "Floyd-Steinberg"
        ),
        
        ConversionOption(
            label: "Gamma / Brightness",
            key: "gamma",
            range: 0.5...2.5,
            defaultValue: 1
        )
    ]
    
    private let defaultPalette: [UInt16] = [
        0x0000, 0x0777, 0x0841, 0x072C, 0x000F, 0x0080, 0x0F70, 0x0D00,
        0x0FA2, 0x0F80, 0x0BBB, 0x0F9B, 0x03D0, 0x0DD0, 0x0CCC, 0x0FFF
    ]
    
    private let palette640: [UInt16] = [
        0x0000, 0x0F00, 0x0FFF, 0x000F, 0,0,0,0,0,0,0,0,0,0,0,0
    ]

    func convert(sourceImage: NSImage) async throws -> ConversionResult {
        
        // --- CONFIG ---
        let modeStr = options.first(where: {$0.key == "mode"})?.selectedValue ?? ""
        let useDither = options.first(where: {$0.key == "dither"})?.selectedValue.contains("Floyd") ?? false
        let gamma = Double(options.first(where: {$0.key == "gamma"})?.selectedValue ?? "1") ?? 1.0
        
        let is640 = modeStr.contains("640")
        let isSmart3200 = modeStr.contains("Smart")
        let isStrip3200 = modeStr.contains("Vertical")
        
        let targetW = is640 ? 640 : 320
        let targetH = 200
        
        // --- INPUT ---
        let resized = sourceImage.fitToStandardSize(targetWidth: targetW, targetHeight: targetH)
        guard let cgImage = resized.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "IIGS", code: 1, userInfo: [NSLocalizedDescriptionKey: "No CGImage"])
        }
        var rawInput = getRGBData(from: cgImage, width: targetW, height: targetH)
        
        // --- OUTPUT BUFFERS ---
        var pixelData = [UInt8](repeating: 0, count: 32000)
        var scbData = [UInt8](repeating: 0, count: 256)
        var palettes: [[UInt16]] = Array(repeating: defaultPalette, count: 16)
        var previewRawData = [UInt8](repeating: 255, count: targetW * targetH * 4)
        
        // --- PALETTEN-GENERIERUNG ---
        
        if is640 {
            // --- 640 MODE ---
            palettes[0] = palette640
            for i in 0..<200 { scbData[i] = 0x80 } // Bit 7 gesetzt
            
        } else if isStrip3200 {
            // --- CLASSIC 3200 (Strips) ---
            // Einfach das Bild in 16 Streifen schneiden
            for pIndex in 0..<16 {
                let startY = (pIndex * targetH) / 16
                let endY = ((pIndex + 1) * targetH) / 16
                
                // Wir sammeln Pixel nur aus diesem Bereich
                var stripPixels: [PixelFloat] = []
                for y in startY..<endY {
                    for x in 0..<targetW {
                        stripPixels.append(rawInput[(y * targetW) + x])
                    }
                }
                
                palettes[pIndex] = quantizePixels(pixels: stripPixels, maxColors: 16)
                for y in startY..<endY { if y < 200 { scbData[y] = UInt8(pIndex) } }
            }
            
        } else if isSmart3200 {
            // --- SMART 3200 (Clustered Scanlines) ---
            // 1. Scanlines analysieren (Durchschnittsfarbe berechnen)
            var scanlines: [ScanlineInfo] = []
            for y in 0..<targetH {
                scanlines.append(ScanlineInfo(y: y, avg: calculateAverageColor(rawInput, y: y, w: targetW)))
            }
            
            // 2. Scanlines in 16 Gruppen clustern (Median Cut Prinzip auf Scanline-Level)
            // Das sorgt dafür, dass rote Zeilen in Gruppe A landen, blaue in Gruppe B usw.
            let groups = clusterScanlines(scanlines, depth: 0, maxDepth: 4) // 2^4 = 16 Gruppen
            
            // 3. Für jede Gruppe eine Palette generieren
            for (pIndex, group) in groups.enumerated() {
                if pIndex >= 16 { break }
                
                // Alle Pixel aller Zeilen in dieser Gruppe sammeln
                var groupPixels: [PixelFloat] = []
                for line in group {
                    let y = line.y
                    for x in 0..<targetW {
                        groupPixels.append(rawInput[(y * targetW) + x])
                    }
                }
                
                // Palette generieren
                palettes[pIndex] = quantizePixels(pixels: groupPixels, maxColors: 16)
                
                // SCBs setzen: Jede Zeile in dieser Gruppe zeigt auf diese Palette
                for line in group {
                    scbData[line.y] = UInt8(pIndex)
                }
            }
            
        } else {
            // --- 320 STANDARD ---
            // Eine Palette für das ganze Bild
            palettes[0] = quantizePixels(pixels: rawInput, maxColors: 16)
            // SCB bleibt 0
        }
        
        // --- RENDERING ---
        
        for y in 0..<targetH {
            let paletteIndex = Int(scbData[y] & 0x0F)
            let currentPalette12 = palettes[paletteIndex]
            let currentPaletteRGB = currentPalette12.map { iigsColorToRGB(iigs: $0) }
            
            for x in 0..<targetW {
                let index = (y * targetW) + x
                
                // Gamma
                var r = rawInput[index].r
                var g = rawInput[index].g
                var b = rawInput[index].b
                
                if gamma != 1.0 {
                    r = pow(r / 255.0, 1.0/gamma) * 255.0
                    g = pow(g / 255.0, 1.0/gamma) * 255.0
                    b = pow(b / 255.0, 1.0/gamma) * 255.0
                }
                
                // Matching
                let match = findNearestColor(r: r, g: g, b: b, palette: currentPaletteRGB)
                let colorIdx = match.index
                
                // Dithering
                if useDither {
                    let errR = r - Double(match.rgb.r)
                    let errG = g - Double(match.rgb.g)
                    let errB = b - Double(match.rgb.b)
                    distributeError(source: &rawInput, x: x, y: y, w: targetW, h: targetH, errR: errR, errG: errG, errB: errB)
                }
                
                // Pixel speichern
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
        
        // --- FINISH ---
        
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
    
    // MARK: - SCANLINE CLUSTERING LOGIC
    
    struct ScanlineInfo {
        let y: Int
        let avg: PixelFloat
    }
    
    func calculateAverageColor(_ pixels: [PixelFloat], y: Int, w: Int) -> PixelFloat {
        var r: Double = 0, g: Double = 0, b: Double = 0
        let start = y * w
        for i in 0..<w {
            r += pixels[start+i].r
            g += pixels[start+i].g
            b += pixels[start+i].b
        }
        let count = Double(w)
        return PixelFloat(r: r/count, g: g/count, b: b/count)
    }
    
    // Rekursives Clustern der Zeilen (Median Cut Style)
    func clusterScanlines(_ lines: [ScanlineInfo], depth: Int, maxDepth: Int) -> [[ScanlineInfo]] {
        if depth >= maxDepth || lines.isEmpty {
            return [lines]
        }
        
        // Finde Kanal mit größter Varianz (R, G oder B)
        var minR = Double.greatestFiniteMagnitude, maxR = -1.0
        var minG = Double.greatestFiniteMagnitude, maxG = -1.0
        var minB = Double.greatestFiniteMagnitude, maxB = -1.0
        
        for l in lines {
            minR = min(minR, l.avg.r); maxR = max(maxR, l.avg.r)
            minG = min(minG, l.avg.g); maxG = max(maxG, l.avg.g)
            minB = min(minB, l.avg.b); maxB = max(maxB, l.avg.b)
        }
        
        let diffR = maxR - minR
        let diffG = maxG - minG
        let diffB = maxB - minB
        
        // Sortieren nach stärkstem Kanal
        let sortedLines: [ScanlineInfo]
        if diffR >= diffG && diffR >= diffB {
            sortedLines = lines.sorted { $0.avg.r < $1.avg.r }
        } else if diffG >= diffR && diffG >= diffB {
            sortedLines = lines.sorted { $0.avg.g < $1.avg.g }
        } else {
            sortedLines = lines.sorted { $0.avg.b < $1.avg.b }
        }
        
        // Splitten
        let mid = sortedLines.count / 2
        let left = Array(sortedLines[0..<mid])
        let right = Array(sortedLines[mid..<sortedLines.count])
        
        return clusterScanlines(left, depth: depth + 1, maxDepth: maxDepth) +
               clusterScanlines(right, depth: depth + 1, maxDepth: maxDepth)
    }
    
    // MARK: - QUANTIZER (Freq based)
    
    func quantizePixels(pixels: [PixelFloat], maxColors: Int) -> [UInt16] {
        var counts: [RGB: Int] = [:]
        for p in pixels {
            // 5-Bit Quantisierung für Häufigkeitsanalyse
            let r = UInt8(p.r) & 0xF8
            let g = UInt8(p.g) & 0xF8
            let b = UInt8(p.b) & 0xF8
            counts[RGB(r: r, g: g, b: b), default: 0] += 1
        }
        
        let sorted = counts.sorted { $0.value > $1.value }.prefix(maxColors).map { $0.key }
        var iigsPalette = sorted.map { rgbToIIGS($0) }
        while iigsPalette.count < maxColors { iigsPalette.append(0x0000) }
        return iigsPalette
    }
    
    // MARK: - UTILS
    
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
        for i in 0..<(width*height) {
            pixels[i] = PixelFloat(r: Double(rawBytes[i*4]), g: Double(rawBytes[i*4+1]), b: Double(rawBytes[i*4+2]))
        }
        return pixels
    }
    
    func findNearestColor(r: Double, g: Double, b: Double, palette: [RGB]) -> ColorMatch {
        var minDiv: Double = Double.greatestFiniteMagnitude
        var bestIdx = 0
        for (i, p) in palette.enumerated() {
            let dr = r - Double(p.r); let dg = g - Double(p.g); let db = b - Double(p.b)
            let dist = dr*dr + dg*dg + db*db
            if dist < minDiv { minDiv = dist; bestIdx = i }
        }
        return ColorMatch(index: bestIdx, rgb: palette[bestIdx])
    }
    
    func distributeError(source: inout [PixelFloat], x: Int, y: Int, w: Int, h: Int, errR: Double, errG: Double, errB: Double) {
        func addErr(dx: Int, dy: Int, factor: Double) {
            let nx = x+dx; let ny = y+dy
            if nx>=0 && nx<w && ny>=0 && ny<h {
                let idx = (ny*w)+nx
                source[idx].r += errR * factor
                source[idx].g += errG * factor
                source[idx].b += errB * factor
            }
        }
        addErr(dx: 1, dy: 0, factor: 7.0/16.0)
        addErr(dx: -1, dy: 1, factor: 3.0/16.0)
        addErr(dx: 0, dy: 1, factor: 5.0/16.0)
        addErr(dx: 1, dy: 1, factor: 1.0/16.0)
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
