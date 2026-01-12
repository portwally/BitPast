import Cocoa

class AppleIIGSConverter: RetroMachine {
    var name: String = "Apple IIgs"
    
    // Store palette mapping for 3200 mode
    private var paletteSlotMapping: [Int] = []
    
    var options: [ConversionOption] = [
        // 1. MODE
        ConversionOption(
            label: "Display Mode",
            key: "mode",
            values: [
                "3200 Mode (Smart Scanlines)",
                "320x200 (16 Colors)",
                "640x200 (4 Colors)",
                "640x200 Enhanced (16 Colors)",
                "640x200 Desktop (16 Colors)"
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
        
        // 2b. QUANTIZATION METHOD (for 3200 mode)
        ConversionOption(
            label: "3200 Quantization",
            key: "quantization_method",
            values: [
                "Per-Scanline (Default)",
                "Palette Reuse (Optimized)"
            ],
            selectedValue: "Per-Scanline (Default)"
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
            label: "Palette Merge Tolerance",
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
    
    // Apple IIgs Standard System Palette (16 colors)
    static let iigsSystemPalette: [RGB] = [
        RGB(r: 0, g: 0, b: 0),         // 0: Black
        RGB(r: 221, g: 0, b: 51),      // 1: Deep Red
        RGB(r: 0, g: 0, b: 153),       // 2: Dark Blue
        RGB(r: 221, g: 0, b: 221),     // 3: Purple
        RGB(r: 0, g: 119, b: 0),       // 4: Dark Green
        RGB(r: 85, g: 85, b: 85),      // 5: Dark Gray
        RGB(r: 34, g: 34, b: 255),     // 6: Medium Blue
        RGB(r: 102, g: 170, b: 255),   // 7: Light Blue
        RGB(r: 136, g: 85, b: 0),      // 8: Brown
        RGB(r: 255, g: 102, b: 0),     // 9: Orange
        RGB(r: 170, g: 170, b: 170),   // A: Light Gray
        RGB(r: 255, g: 153, b: 136),   // B: Pink
        RGB(r: 17, g: 221, b: 0),      // C: Light Green
        RGB(r: 255, g: 255, b: 0),     // D: Yellow
        RGB(r: 68, g: 255, b: 153),    // E: Aqua
        RGB(r: 255, g: 255, b: 255)    // F: White
    ]
    
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
        let quantMethod = options.first(where: {$0.key == "quantization_method"})?.selectedValue ?? "Per-Scanline (Default)"
        let mergeThreshold = Double(options.first(where: {$0.key == "threshold"})?.selectedValue ?? "10.0") ?? 10.0
        
        let is640 = mode.contains("640")
        let is3200 = mode.contains("3200")
        let isDesktop = mode.contains("Desktop")
        let isEnhanced = mode.contains("Enhanced")
        
        // All 640 modes (including Desktop/Enhanced) use 640 width
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
        
        // Reset palette mapping
        paletteSlotMapping = []
        
        if isDesktop {
            // DESKTOP MODE - Column-aware dithering (Even/Odd palettes)
            print("=== DESKTOP MODE (640x200, 16 dithered colors) ===")
            print("Using GS/OS Finder palette with column-aware dithering")
            
            // Standard GS/OS Finder palette
            // Even columns (indices 0-3): Black, Deep Blue, Yellow, White
            // Odd columns (indices 4-7): Black, Red, Green, White
            // Indices 8-15 are duplicates for hardware compatibility
            let finderPalette = [
                // Indices 0-3 (Even columns)
                RGB(r: 0, g: 0, b: 0),         // 0: Black
                RGB(r: 0, g: 0, b: 255),       // 1: Deep Blue ($00F)
                RGB(r: 255, g: 255, b: 0),     // 2: Yellow ($FF0)
                RGB(r: 255, g: 255, b: 255),   // 3: White
                // Indices 4-7 (Odd columns)
                RGB(r: 0, g: 0, b: 0),         // 4: Black
                RGB(r: 255, g: 0, b: 0),       // 5: Red ($F00)
                RGB(r: 0, g: 224, b: 0),       // 6: Green ($0E0)
                RGB(r: 255, g: 255, b: 255),   // 7: White
                // Indices 8-15 (Duplicates for hardware)
                RGB(r: 0, g: 0, b: 0),         // 8: Black (copy of 0)
                RGB(r: 0, g: 0, b: 255),       // 9: Deep Blue (copy of 1)
                RGB(r: 255, g: 255, b: 0),     // 10: Yellow (copy of 2)
                RGB(r: 255, g: 255, b: 255),   // 11: White (copy of 3)
                RGB(r: 0, g: 0, b: 0),         // 12: Black (copy of 4)
                RGB(r: 255, g: 0, b: 0),       // 13: Red (copy of 5)
                RGB(r: 0, g: 224, b: 0),       // 14: Green (copy of 6)
                RGB(r: 255, g: 255, b: 255)    // 15: White (copy of 7)
            ]
            
            for _ in 0..<200 { finalPalettes.append(finderPalette) }
            
        } else if isEnhanced {
            // ENHANCED 640 MODE - Custom 8-color palette with column-aware dithering
            print("=== ENHANCED 640 MODE (640x200, 16 dithered colors) ===")
            print("Generating 8 optimal colors for column-aware dithering")
            
            var samplePixels: [PixelFloat] = []
            for i in stride(from: 0, to: rawPixels.count, by: 4) {
                let p = rawPixels[i]
                samplePixels.append(PixelFloat(r: max(0, min(255, p.r)), g: max(0, min(255, p.g)), b: max(0, min(255, p.b))))
            }
            
            // Generate 8 colors total (4 for even, 4 for odd)
            var best8 = generatePaletteMedianCut(pixels: samplePixels, maxColors: 8)
            best8.sort { ($0.r + $0.g + $0.b) < ($1.r + $1.g + $1.b) }
            
            print("Generated 8-color palette:")
            for (idx, color) in best8.enumerated() {
                let col = idx < 4 ? "Even" : "Odd"
                print("  \(idx) (\(col)): R=\(Int(color.r)) G=\(Int(color.g)) B=\(Int(color.b))")
            }
            
            // Build palette: 0-3 (Even), 4-7 (Odd), 8-15 (Duplicates)
            var enhancedPalette = [RGB]()
            enhancedPalette.append(contentsOf: Array(best8[0..<4]))  // Even (0-3)
            enhancedPalette.append(contentsOf: Array(best8[4..<8]))  // Odd (4-7)
            enhancedPalette.append(contentsOf: Array(best8[0..<4]))  // Duplicate Even (8-11)
            enhancedPalette.append(contentsOf: Array(best8[4..<8]))  // Duplicate Odd (12-15)
            
            for _ in 0..<200 { finalPalettes.append(enhancedPalette) }
            
        } else if is640 {
            // A. 640 MODE - 4 colors with guaranteed brightness range
            var samplePixels: [PixelFloat] = []
            for i in stride(from: 0, to: rawPixels.count, by: 2) {
                let p = rawPixels[i]
                samplePixels.append(PixelFloat(r: max(0, min(255, p.r)), g: max(0, min(255, p.g)), b: max(0, min(255, p.b))))
            }
            
            // Find min and max brightness in image
            var minBrightness = 999.0
            var maxBrightness = 0.0
            var darkestPixel = PixelFloat(r: 0, g: 0, b: 0)
            var brightestPixel = PixelFloat(r: 255, g: 255, b: 255)
            
            for p in samplePixels {
                let brightness = (p.r + p.g + p.b) / 3.0
                if brightness < minBrightness {
                    minBrightness = brightness
                    darkestPixel = p
                }
                if brightness > maxBrightness {
                    maxBrightness = brightness
                    brightestPixel = p
                }
            }
            
            // Use median cut to get 4 colors, then force in brightest
            var best4 = generatePaletteMedianCut(pixels: samplePixels, maxColors: 4)
            
            // Replace darkest palette color with image's darkest
            // Replace brightest palette color with image's brightest
            best4.sort { ($0.r + $0.g + $0.b) < ($1.r + $1.g + $1.b) }
            best4[0] = RGB(r: darkestPixel.r, g: darkestPixel.g, b: darkestPixel.b)
            best4[3] = RGB(r: brightestPixel.r, g: brightestPixel.g, b: brightestPixel.b)
            
            // DEBUG: Print palette colors
            print("=== 640 MODE PALETTE ===")
            print("Image brightness range: \(Int(minBrightness)) to \(Int(maxBrightness))")
            for (idx, color) in best4.enumerated() {
                let brightness = (color.r + color.g + color.b) / 3.0
                print("Color \(idx): R=\(Int(color.r)) G=\(Int(color.g)) B=\(Int(color.b)) Brightness=\(Int(brightness))")
            }
            print("========================")
            
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
            // C. TRUE 3200 MODE
            let usePaletteReuse = quantMethod.contains("Reuse")
            
            if usePaletteReuse {
                print("=== 3200 MODE: PALETTE REUSE ===")
                print("Merge Threshold: \(mergeThreshold)")
                
                // Sequential palette reuse: try to reuse previous scanline's palette
                var linePalettes = [[RGB]]()
                var uniquePaletteCount = 0
                
                for y in 0..<targetH {
                    let rowStart = y * targetW
                    let rowEnd = rowStart + targetW
                    
                    var rowPixels: [PixelFloat] = []
                    for i in rowStart..<rowEnd {
                        let p = rawPixels[i]
                        rowPixels.append(PixelFloat(
                            r: max(0, min(255, p.r)),
                            g: max(0, min(255, p.g)),
                            b: max(0, min(255, p.b))
                        ))
                    }
                    
                    if y == 0 {
                        // First scanline: always generate new palette
                        let newPalette = generatePaletteMedianCut(pixels: rowPixels, maxColors: 16)
                        linePalettes.append(newPalette)
                        uniquePaletteCount = 1
                    } else {
                        // Try to reuse previous scanline's palette
                        let previousPalette = linePalettes[y - 1]
                        
                        // Calculate how well previous palette fits this scanline
                        let error = calculatePaletteFitError(pixels: rowPixels, palette: previousPalette)
                        
                        if error <= mergeThreshold {
                            // Error is acceptable - REUSE previous palette
                            linePalettes.append(previousPalette)
                        } else {
                            // Error too high - GENERATE new palette
                            let newPalette = generatePaletteMedianCut(pixels: rowPixels, maxColors: 16)
                            linePalettes.append(newPalette)
                            uniquePaletteCount += 1
                        }
                    }
                }
                
                print("Generated \(uniquePaletteCount) unique palettes for 200 scanlines")
                
                // Now map these palettes to 16 slots
                paletteSlotMapping = [Int](repeating: 0, count: 200)
                
                if uniquePaletteCount <= 16 {
                    // Find unique palettes and assign slots
                    var uniquePalettes = [[RGB]]()
                    var paletteToSlot = [String: Int]()
                    
                    for (lineIdx, palette) in linePalettes.enumerated() {
                        let paletteKey = paletteToKey(palette)
                        
                        if let existingSlot = paletteToSlot[paletteKey] {
                            paletteSlotMapping[lineIdx] = existingSlot
                        } else {
                            let newSlot = uniquePalettes.count
                            uniquePalettes.append(palette)
                            paletteToSlot[paletteKey] = newSlot
                            paletteSlotMapping[lineIdx] = newSlot
                        }
                    }
                    
                    finalPalettes = uniquePalettes
                    while finalPalettes.count < 16 {
                        finalPalettes.append(uniquePalettes[0])
                    }
                    
                } else {
                    print("Warning: \(uniquePaletteCount) unique palettes > 16, need to merge further")
                    
                    // Group consecutive similar palettes into 16 slots
                    var slotPalettes = [[RGB]]()
                    var currentSlot = 0
                    var linesPerSlot = 200 / 16
                    
                    for slot in 0..<16 {
                        let startLine = slot * linesPerSlot
                        let endLine = (slot == 15) ? 200 : (slot + 1) * linesPerSlot
                        
                        // Use the palette from the middle line of this group
                        let midLine = (startLine + endLine) / 2
                        slotPalettes.append(linePalettes[midLine])
                        
                        for lineIdx in startLine..<endLine {
                            paletteSlotMapping[lineIdx] = slot
                        }
                    }
                    
                    finalPalettes = slotPalettes
                }
                
                // CRITICAL: Quantize pixels using the actual palettes from palette reuse
                // Use linePalettes directly, not the mapped slots
                for y in 0..<targetH {
                    let currentPalette = linePalettes[y]  // Use the ACTUAL palette for this line
                    
                    for x in 0..<targetW {
                        let idx = y * targetW + x
                        var p = rawPixels[idx]
                        
                        p.r = min(255, max(0, p.r))
                        p.g = min(255, max(0, p.g))
                        p.b = min(255, max(0, p.b))
                        
                        if isOrdered {
                            let bayerVal = bayerMatrix[(y % 4) * 4 + (x % 4)] / 16.0
                            let spread = 32.0 * ditherAmount
                            let offset = (bayerVal - 0.5) * spread
                            p.r = min(255, max(0, p.r + offset))
                            p.g = min(255, max(0, p.g + offset))
                            p.b = min(255, max(0, p.b + offset))
                        }
                        
                        let match = findNearestColor(pixel: p, palette: currentPalette)
                        
                        // Map to the slot index for this line
                        let paletteSlot = paletteSlotMapping[y]
                        let slotPalette = finalPalettes[paletteSlot]
                        
                        // Find this color in the slot palette
                        let slotMatch = findNearestColor(pixel: PixelFloat(r: match.rgb.r, g: match.rgb.g, b: match.rgb.b), palette: slotPalette)
                        outputIndices[idx] = slotMatch.index
                        
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
                
            } else {
                // PER-SCANLINE METHOD (Original/Default)
                print("=== 3200 MODE: PER-SCANLINE ===")
                
                // Step 1: Generate optimal palette for each scanline
                var linePalettes = [[RGB]]()
                for y in 0..<targetH {
                let rowStart = y * targetW
                let rowEnd = rowStart + targetW
                
                var rowPixels: [PixelFloat] = []
                for i in rowStart..<rowEnd {
                    let p = rawPixels[i]
                    rowPixels.append(PixelFloat(
                        r: max(0, min(255, p.r)),
                        g: max(0, min(255, p.g)),
                        b: max(0, min(255, p.b))
                    ))
                }
                
                let linePalette = generatePaletteMedianCut(pixels: rowPixels, maxColors: 16)
                linePalettes.append(linePalette)
            }
            
            // Step 2: Map 200 line palettes to 16 slots
            // Simple approach: Group consecutive lines
            paletteSlotMapping = [Int](repeating: 0, count: 200)
            var slotPalettes = [[RGB]]()
            
            for slot in 0..<16 {
                let startLine = (slot * 200) / 16
                let endLine = ((slot + 1) * 200) / 16
                
                // Collect all unique colors from these lines
                var slotColors: [RGB] = []
                for lineIdx in startLine..<endLine {
                    slotColors.append(contentsOf: linePalettes[lineIdx])
                }
                
                // Convert to PixelFloat for median cut
                var colorPixels = slotColors.map { PixelFloat(r: $0.r, g: $0.g, b: $0.b) }
                
                // Generate merged palette
                let mergedPalette = generatePaletteMedianCut(pixels: colorPixels, maxColors: 16)
                slotPalettes.append(mergedPalette)
                
                // Map these lines to this slot
                for lineIdx in startLine..<endLine {
                    paletteSlotMapping[lineIdx] = slot
                }
            }
            
            finalPalettes = slotPalettes
            
            // Step 3: Quantize pixels using assigned palette slots
            for y in 0..<targetH {
                let paletteSlot = paletteSlotMapping[y]
                let currentPalette = finalPalettes[paletteSlot]
                
                for x in 0..<targetW {
                    let idx = y * targetW + x
                    var p = rawPixels[idx]
                    
                    p.r = min(255, max(0, p.r))
                    p.g = min(255, max(0, p.g))
                    p.b = min(255, max(0, p.b))
                    
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
                        
                        // Only distribute within same palette slot group
                        let nextY = y + 1
                        if nextY < targetH && paletteSlotMapping[nextY] == paletteSlot {
                            distributeError(source: &rawPixels, x: x, y: y, w: targetW, h: targetH,
                                            errR: errR, errG: errG, errB: errB,
                                            kernel: kernel)
                        } else {
                            // Within same line only
                            let filteredKernel = kernel.filter { $0.dy == 0 }
                            if !filteredKernel.isEmpty {
                                distributeError(source: &rawPixels, x: x, y: y, w: targetW, h: targetH,
                                                errR: errR, errG: errG, errB: errB,
                                                kernel: filteredKernel)
                            }
                        }
                    }
                }
            }
            } // End of per-scanline else block
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
                    
                    // Column-aware quantization for Desktop/Enhanced 640 modes
                    if is640 && (isDesktop || isEnhanced) {
                        // Even columns use indices 0-3, Odd columns use indices 4-7
                        let isEvenColumn = (x % 2 == 0)
                        let paletteStart = isEvenColumn ? 0 : 4
                        let paletteEnd = paletteStart + 4
                        
                        // Extract the 4-color sub-palette for this column
                        let subPalette = Array(currentPalette[paletteStart..<paletteEnd])
                        
                        // Find nearest color in the constrained palette
                        let match = findNearestColor(pixel: p, palette: subPalette)
                        
                        // Store index offset by palette start
                        outputIndices[idx] = match.index + paletteStart
                        
                        // Error diffusion with the actual matched color
                        if !isNone && !isOrdered {
                            let actualColor = currentPalette[match.index + paletteStart]
                            let errR = (p.r - actualColor.r) * ditherAmount
                            let errG = (p.g - actualColor.g) * ditherAmount
                            let errB = (p.b - actualColor.b) * ditherAmount
                            
                            distributeError(source: &rawPixels, x: x, y: y, w: targetW, h: targetH,
                                            errR: errR, errG: errG, errB: errB,
                                            kernel: kernel)
                        }
                    } else {
                        // Standard quantization for other modes
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
        }
        
        // 5. Generate Results
        let preview = generatePreviewImage(indices: outputIndices, palettes: finalPalettes, width: targetW, height: targetH)
        
        // All 640 modes (regular, Desktop, Enhanced) are stored in 640 mode with 4 colors
        let shrIs640Mode = is640
        
        let shrData = generateSHRData(indices: outputIndices, palettes: finalPalettes, width: targetW, height: targetH, is640: shrIs640Mode)
        
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
    
    func calculatePaletteFitError(pixels: [PixelFloat], palette: [RGB]) -> Double {
        // Calculate average quantization error when using this palette
        var totalError = 0.0
        
        for pixel in pixels {
            let match = findNearestColor(pixel: pixel, palette: palette)
            let dr = pixel.r - match.rgb.r
            let dg = pixel.g - match.rgb.g
            let db = pixel.b - match.rgb.b
            totalError += sqrt(dr*dr + dg*dg + db*db)
        }
        
        return totalError / Double(pixels.count)
    }
    
    func paletteToKey(_ palette: [RGB]) -> String {
        // Create a unique string key for this palette
        return palette.map { "\(Int($0.r)),\(Int($0.g)),\(Int($0.b))" }.joined(separator: "|")
    }
    
    func palettesDistance(_ pal1: [RGB], _ pal2: [RGB]) -> Double {
        // Calculate average color distance between two palettes
        var totalDistance = 0.0
        let count = min(pal1.count, pal2.count)
        
        for i in 0..<count {
            let dr = pal1[i].r - pal2[i].r
            let dg = pal1[i].g - pal2[i].g
            let db = pal1[i].b - pal2[i].b
            totalDistance += sqrt(dr*dr + dg*dg + db*db)
        }
        
        return totalDistance / Double(count)
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
        
        // DON'T quantize palette - keep full 8-bit precision for preview
        // Only quantize when writing to SHR file
        
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
        // Proper 8-bit to 4-bit conversion with rounding to preserve brightness
        let r4 = UInt16((min(255, max(0, rgb.r)) * 15.0 + 127.5) / 255.0) & 0x0F
        let g4 = UInt16((min(255, max(0, rgb.g)) * 15.0 + 127.5) / 255.0) & 0x0F
        let b4 = UInt16((min(255, max(0, rgb.b)) * 15.0 + 127.5) / 255.0) & 0x0F
        return (0 << 12) | (r4 << 8) | (g4 << 4) | b4
    }
    
    func generateSHRData(indices: [Int], palettes: [[RGB]], width: Int, height: Int, is640: Bool) -> Data {
        var data = Data(count: 32768)
        let scbOffset = 32000
        let palOffset = 32256
        
        // SCB (Scan Control Bytes) - assign palette slot to each scanline
        for y in 0..<200 {
            let palIdx: Int
            if !paletteSlotMapping.isEmpty {
                // 3200 mode with custom mapping
                palIdx = paletteSlotMapping[y]
            } else if palettes.count == 16 {
                // Standard: cycle through available palettes
                palIdx = y % 16
            } else if palettes.count == 1 {
                // Single palette mode
                palIdx = 0
            } else {
                // Fallback
                palIdx = y % palettes.count
            }
            
            var scbByte = UInt8(palIdx & 0x0F)
            if is640 { scbByte |= 0x80 }
            data[scbOffset + y] = scbByte
        }
        
        // Write palette data (always 16 slots)
        let numPalettes = min(palettes.count, 16)
        for pIdx in 0..<16 {
            let sourcePal = (pIdx < numPalettes) ? palettes[pIdx] : palettes[0]
            
            for cIdx in 0..<16 {
                let color = sourcePal[cIdx]
                let iigsVal = rgbToIIGS(color)
                let offset = palOffset + (pIdx * 32) + (cIdx * 2)
                data[offset] = UInt8(iigsVal & 0xFF)
                data[offset+1] = UInt8((iigsVal >> 8) & 0xFF)
            }
        }
        
        for y in 0..<height {
            let lineOffset = y * 160
            
            for x in stride(from: 0, to: width, by: is640 ? 4 : 2) {
                let bytePos = lineOffset + (is640 ? x/4 : x/2)
                if bytePos >= 32000 { continue }
                if is640 {
                    let p1 = (indices[y*width + x] & 0x03)
                    let p2 = (indices[y*width + x+1] & 0x03)
                    let p3 = (indices[y*width + x+2] & 0x03)
                    let p4 = (indices[y*width + x+3] & 0x03)
                    // REVERSED: p4 goes to bits 0-1, p1 goes to bits 6-7
                    let byte = UInt8(p4 | (p3 << 2) | (p2 << 4) | (p1 << 6))
                    data[bytePos] = byte
                } else {
                    let p1 = indices[y*width + x] & 0x0F
                    let p2 = indices[y*width + x+1] & 0x0F
                    // SWAPPED: Try reversed nibble order
                    let byte = UInt8(p2 | (p1 << 4))
                    data[bytePos] = byte
                }
            }
        }
        return data
    }
    
    func generatePreviewImage(indices: [Int], palettes: [[RGB]], width: Int, height: Int) -> NSImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            // Determine which palette to use for this line
            let paletteIndex: Int
            if !paletteSlotMapping.isEmpty {
                // 3200 mode with custom mapping
                paletteIndex = paletteSlotMapping[y]
            } else if palettes.count > 16 {
                // Shouldn't happen, but fallback
                paletteIndex = y % 16
            } else {
                // Standard mode
                paletteIndex = min(y, palettes.count - 1)
            }
            
            let pal = palettes[paletteIndex]
            
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
            let alpha = Double(bytes[i*4+3])
            if alpha > 0 {
                // Unpremultiply to get correct RGB values
                let r = Double(bytes[i*4]) * 255.0 / alpha
                let g = Double(bytes[i*4+1]) * 255.0 / alpha
                let b = Double(bytes[i*4+2]) * 255.0 / alpha
                pixels[i] = PixelFloat(r: min(255, r), g: min(255, g), b: min(255, b))
            } else {
                pixels[i] = PixelFloat(r: Double(bytes[i*4]), g: Double(bytes[i*4+1]), b: Double(bytes[i*4+2]))
            }
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
