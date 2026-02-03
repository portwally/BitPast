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
                "3200 Colors (Brooks)",
                "256 Colors (16 Palettes)",
                "320x200 (16 Colors)",
                "640x200 (4 Colors)",
                "640x200 Enhanced (16 Colors)",
                "640x200 Desktop (16 Colors)"
            ],
            selectedValue: "3200 Colors (Brooks)"
        ),
        
        // 2. DITHERING ALGO
        ConversionOption(
            label: "Dithering Algo",
            key: "dither",
            values: [
                "None",
                "Floyd-Steinberg",
                "Atkinson",
                "Jarvis-Judice-Ninke",
                "Stucki",
                "Burkes",
                "Noise",
                "Bayer 2x2",
                "Bayer 4x4",
                "Bayer 8x8",
                "Bayer 16x16",
                "Blue 8x8",
                "Blue 16x16"
            ],
            selectedValue: "Floyd-Steinberg"
        ),
        
        // 2b. QUANTIZATION METHOD (for 3200 mode)
        ConversionOption(
            label: "3200 Quantization",
            key: "quantization_method",
            values: [
                "Per-Scanline",
                "Palette Reuse"
            ],
            selectedValue: "Per-Scanline"
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
        ),

        // 6. PREPROCESSING FILTER
        ConversionOption(
            label: "Preprocessing",
            key: "preprocess",
            values: [
                "None",
                "Lowpass",
                "Median",
                "Sharpen",
                "Sigma",
                "Solarize",
                "Emboss",
                "Find Edges"
            ],
            selectedValue: "None"
        ),

        // 7. FILTER-SPECIFIC PARAMETERS
        // Median: Kernel size (3x3, 5x5, 7x7)
        ConversionOption(
            label: "Kernel Size",
            key: "median_size",
            values: ["3x3", "5x5", "7x7"],
            selectedValue: "3x3"
        ),

        // Sharpen: Strength (0.2 - 2.5)
        ConversionOption(
            label: "Sharpen Amount",
            key: "sharpen_strength",
            range: 0.2...2.5,
            defaultValue: 1.0
        ),

        // Sigma: Range for noise reduction (5 - 50)
        ConversionOption(
            label: "Sigma Range",
            key: "sigma_range",
            range: 5.0...50.0,
            defaultValue: 20.0
        ),

        // Solarize: Brightness threshold (32 - 224)
        ConversionOption(
            label: "Threshold",
            key: "solarize_threshold",
            range: 32.0...224.0,
            defaultValue: 128.0
        ),

        // Emboss: Depth of effect (0.3 - 2.0)
        ConversionOption(
            label: "Emboss Depth",
            key: "emboss_depth",
            range: 0.3...2.0,
            defaultValue: 1.0
        ),

        // Find Edges: Sensitivity threshold (10 - 100)
        ConversionOption(
            label: "Edge Sensitivity",
            key: "edge_threshold",
            range: 10.0...100.0,
            defaultValue: 50.0
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
    
    // Bayer Matrices
    private let bayer2x2: [Double] = [0, 2, 3, 1]

    private let bayer4x4: [Double] = [
         0,  8,  2, 10,
        12,  4, 14,  6,
         3, 11,  1,  9,
        15,  7, 13,  5
    ]

    private let bayer8x8: [Double] = [
         0, 32,  8, 40,  2, 34, 10, 42,
        48, 16, 56, 24, 50, 18, 58, 26,
        12, 44,  4, 36, 14, 46,  6, 38,
        60, 28, 52, 20, 62, 30, 54, 22,
         3, 35, 11, 43,  1, 33,  9, 41,
        51, 19, 59, 27, 49, 17, 57, 25,
        15, 47,  7, 39, 13, 45,  5, 37,
        63, 31, 55, 23, 61, 29, 53, 21
    ]

    private let bayer16x16: [Double] = [
          0, 128,  32, 160,   8, 136,  40, 168,   2, 130,  34, 162,  10, 138,  42, 170,
        192,  64, 224,  96, 200,  72, 232, 104, 194,  66, 226,  98, 202,  74, 234, 106,
         48, 176,  16, 144,  56, 184,  24, 152,  50, 178,  18, 146,  58, 186,  26, 154,
        240, 112, 208,  80, 248, 120, 216,  88, 242, 114, 210,  82, 250, 122, 218,  90,
         12, 140,  44, 172,   4, 132,  36, 164,  14, 142,  46, 174,   6, 134,  38, 166,
        204,  76, 236, 108, 196,  68, 228, 100, 206,  78, 238, 110, 198,  70, 230, 102,
         60, 188,  28, 156,  52, 180,  20, 148,  62, 190,  30, 158,  54, 182,  22, 150,
        252, 124, 220,  92, 244, 116, 212,  84, 254, 126, 222,  94, 246, 118, 214,  86,
          3, 131,  35, 163,  11, 139,  43, 171,   1, 129,  33, 161,   9, 137,  41, 169,
        195,  67, 227,  99, 203,  75, 235, 107, 193,  65, 225,  97, 201,  73, 233, 105,
         51, 179,  19, 147,  59, 187,  27, 155,  49, 177,  17, 145,  57, 185,  25, 153,
        243, 115, 211,  83, 251, 123, 219,  91, 241, 113, 209,  81, 249, 121, 217,  89,
         15, 143,  47, 175,   7, 135,  39, 167,  13, 141,  45, 173,   5, 133,  37, 165,
        207,  79, 239, 111, 199,  71, 231, 103, 205,  77, 237, 109, 197,  69, 229, 101,
         63, 191,  31, 159,  55, 183,  23, 151,  61, 189,  29, 157,  53, 181,  21, 149,
        255, 127, 223,  95, 247, 119, 215,  87, 253, 125, 221,  93, 245, 117, 213,  85
    ]

    // Blue noise 8x8 pattern
    private let blueNoise8x8: [Double] = [
        34,  29,  17,  21,   2,  37,  25,   9,
        10,  48,  40,  58,  14,  55,  44,  31,
        61,   5,  23,  50,  27,  42,   6,  52,
        19,  32,  12,  38,   0,  18,  63,  35,
        54,  45,  56,   8,  46,  59,  22,  11,
        26,   3,  20,  62,  33,  13,  39,  49,
        41,  60,  36,  15,  24,  51,   1,  28,
        16,   7,  47,  43,  57,   4,  53,  30
    ]

    // Blue noise 16x16 pattern (simplified)
    private let blueNoise16x16: [Double] = [
        136,  72, 184, 120,  56, 200,  24, 152,  88, 232,  40, 168, 104,  16, 248,   8,
        216,  32, 160,  96,  48, 144, 112, 240,  64, 176,  80, 224, 128,  48, 192,  64,
         80, 240,  16, 208, 176,  88,  56, 192,  24, 144, 208,  32, 176,  96, 128, 144,
        144, 112, 176,  48, 128,   8, 224, 128,  96, 240,  72, 112,  56, 224,  16, 200,
         24, 192,  64, 224,  80, 160,  40, 168,  48, 184,   8, 160, 136, 168,  72, 112,
        168, 136,  96,  16, 192, 104, 200,  80, 136, 104, 216, 200,  40,  88, 232,  56,
         56,  40, 152, 120, 248,  64, 232,  16, 224,  56, 152,  88, 248, 120, 152,  24,
        208, 232,  80, 200,  40, 144, 112, 176, 168,  24, 128,  16, 184,  48, 176, 136,
         88,   8, 176, 160,  72, 184,  48, 248,  72, 208,  64, 232,  80, 216, 104,  64,
        128, 160, 104,  24, 216,  96,  16, 120, 200,  96, 184, 144, 112,   8, 144, 200,
         48, 216,  56, 240, 136,   0, 240,  64, 152,  40, 168,  24, 192,  56, 240,  32,
        184, 120,  72, 112,  64, 168, 200,  88,  24, 248, 104,  48, 160, 128,  80, 168,
          0, 192, 152, 176,  40, 128,  32, 176, 112, 144,  80, 224, 232,  72, 192,  16,
        144,  32, 248,  16, 200, 232, 152,   8, 232,  56, 200,   8, 176,  40, 112, 208,
         96,  80, 104, 216,  88,  56, 104, 192,  72, 168, 128,  96, 136, 248, 152,  56,
        224, 168,  40, 136, 184, 144,  24, 240, 136,  16, 216,  48, 208,  24,  88, 120
    ]

    // Helper to get dither offset for ordered dithering
    private func getOrderedDitherOffset(x: Int, y: Int, ditherType: String, amount: Double) -> Double {
        let spread = 32.0 * amount
        var val: Double = 0
        var maxVal: Double = 1

        switch ditherType {
        case "Bayer 2x2":
            val = bayer2x2[(y % 2) * 2 + (x % 2)]
            maxVal = 4
        case "Bayer 4x4":
            val = bayer4x4[(y % 4) * 4 + (x % 4)]
            maxVal = 16
        case "Bayer 8x8":
            val = bayer8x8[(y % 8) * 8 + (x % 8)]
            maxVal = 64
        case "Bayer 16x16":
            val = bayer16x16[(y % 16) * 16 + (x % 16)]
            maxVal = 256
        case "Blue 8x8":
            val = blueNoise8x8[(y % 8) * 8 + (x % 8)]
            maxVal = 64
        case "Blue 16x16":
            val = blueNoise16x16[(y % 16) * 16 + (x % 16)]
            maxVal = 256
        case "Noise":
            val = Double.random(in: 0..<1) * maxVal
            maxVal = 1
            return (val - 0.5) * spread
        default:
            return 0
        }

        return (val / maxVal - 0.5) * spread
    }

    // Check if dithering is ordered/noise type
    private func isOrderedDithering(_ name: String) -> Bool {
        return name.contains("Bayer") || name.contains("Blue") || name == "Noise"
    }
    
    // MARK: - Main Conversion
    
    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        // Use provided settings or fall back to instance options
        let opts = settings ?? options

        // --- CONFIG ---
        let mode = opts.first(where: {$0.key == "mode"})?.selectedValue ?? "3200 Mode (Smart Scanlines)"
        let ditherName = opts.first(where: {$0.key == "dither"})?.selectedValue ?? "None"
        let ditherAmount = Double(opts.first(where: {$0.key == "dither_amount"})?.selectedValue ?? "1.0") ?? 1.0
        let saturation = Double(opts.first(where: {$0.key == "saturation"})?.selectedValue ?? "1.0") ?? 1.0
        let quantMethod = opts.first(where: {$0.key == "quantization_method"})?.selectedValue ?? "Per-Scanline (Default)"
        let mergeThreshold = Double(opts.first(where: {$0.key == "threshold"})?.selectedValue ?? "10.0") ?? 10.0
        let preprocessFilter = opts.first(where: {$0.key == "preprocess"})?.selectedValue ?? "None"

        // Get filter-specific parameters
        let medianSize = opts.first(where: {$0.key == "median_size"})?.selectedValue ?? "3x3"
        let sharpenStrength = Double(opts.first(where: {$0.key == "sharpen_strength"})?.selectedValue ?? "1.0") ?? 1.0
        let sigmaRange = Double(opts.first(where: {$0.key == "sigma_range"})?.selectedValue ?? "20.0") ?? 20.0
        let solarizeThreshold = Double(opts.first(where: {$0.key == "solarize_threshold"})?.selectedValue ?? "128.0") ?? 128.0
        let embossDepth = Double(opts.first(where: {$0.key == "emboss_depth"})?.selectedValue ?? "1.0") ?? 1.0
        let edgeThreshold = Double(opts.first(where: {$0.key == "edge_threshold"})?.selectedValue ?? "50.0") ?? 50.0

        let is640 = mode.contains("640")
        let is3200Brooks = mode.contains("3200 Colors")
        let is256Color = mode.contains("256 Colors")
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

        // 2. Preprocessing Filter
        if preprocessFilter != "None" {
            applyPreprocessing(
                &rawPixels, width: targetW, height: targetH,
                filter: preprocessFilter,
                medianSize: medianSize,
                sharpenStrength: sharpenStrength,
                sigmaRange: sigmaRange,
                solarizeThreshold: solarizeThreshold,
                embossDepth: embossDepth,
                edgeThreshold: edgeThreshold
            )
        }

        // 3. Saturation Boost
        if saturation != 1.0 { applySaturation(&rawPixels, amount: saturation) }
        
        // 3. Setup Dither
        let kernel = getDitherKernel(name: ditherName)
        let isOrdered = isOrderedDithering(ditherName)
        let isNone = ditherName == "None"
        
        // 4. Buffers
        var outputIndices = [Int](repeating: 0, count: targetW * targetH)
        var finalPalettes = [[RGB]]()
        
        // --- PALETTE LOGIC ---
        
        // Reset palette mapping
        paletteSlotMapping = []
        
        if isDesktop {
            // DESKTOP MODE - Column-aware dithering (Even/Odd palettes)
            
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
            
            finalPalettes.append(finderPalette)  // Single palette for Desktop mode
            
        } else if isEnhanced {
            // ENHANCED 640 MODE - Custom 8-color palette with column-aware dithering
            
            var samplePixels: [PixelFloat] = []
            for i in stride(from: 0, to: rawPixels.count, by: 4) {
                let p = rawPixels[i]
                samplePixels.append(PixelFloat(r: max(0, min(255, p.r)), g: max(0, min(255, p.g)), b: max(0, min(255, p.b))))
            }
            
            // Generate 8 colors total (4 for even, 4 for odd)
            var best8 = generatePaletteMedianCut(pixels: samplePixels, maxColors: 8)
            best8.sort { ($0.r + $0.g + $0.b) < ($1.r + $1.g + $1.b) }

            // Build palette: 0-3 (Even), 4-7 (Odd), 8-15 (Duplicates)
            var enhancedPalette = [RGB]()
            enhancedPalette.append(contentsOf: Array(best8[0..<4]))  // Even (0-3)
            enhancedPalette.append(contentsOf: Array(best8[4..<8]))  // Odd (4-7)
            enhancedPalette.append(contentsOf: Array(best8[0..<4]))  // Duplicate Even (8-11)
            enhancedPalette.append(contentsOf: Array(best8[4..<8]))  // Duplicate Odd (12-15)
            
            finalPalettes.append(enhancedPalette)  // Single palette for Enhanced mode
            
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
            
            var expandedPalette = [RGB]()
            for i in 0..<16 {
                expandedPalette.append(best4.isEmpty ? RGB(r:0,g:0,b:0) : best4[i % best4.count])
            }
            finalPalettes.append(expandedPalette)  // Single palette for 640 mode
            
        } else if !is3200Brooks && !is256Color {
            // B. STANDARD 320 MODE (single 16-color palette)
            var samplePixels: [PixelFloat] = []
            for i in stride(from: 0, to: rawPixels.count, by: 4) {
                let p = rawPixels[i]
                samplePixels.append(PixelFloat(r: max(0, min(255, p.r)), g: max(0, min(255, p.g)), b: max(0, min(255, p.b))))
            }

            let best16 = generatePaletteMedianCut(pixels: samplePixels, maxColors: 16)
            finalPalettes.append(best16)  // Single palette for 320x200 mode

        } else if is3200Brooks {
            // C. TRUE 3200 COLORS (Brooks format - 200 independent palettes)
            // Each scanline gets its own optimal 16-color palette
            // Uses mergeThreshold to allow palette reuse between similar scanlines
            // This reduces banding at scanline boundaries

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

                if y == 0 || mergeThreshold == 0 {
                    // First scanline or no tolerance: always generate new palette
                    let linePalette = generatePaletteMedianCut(pixels: rowPixels, maxColors: 16)
                    finalPalettes.append(linePalette)
                } else {
                    // Check if previous palette fits this scanline well enough
                    let previousPalette = finalPalettes[y - 1]
                    let error = calculatePaletteFitError(pixels: rowPixels, palette: previousPalette)

                    if error <= mergeThreshold {
                        // Reuse previous palette - reduces banding
                        finalPalettes.append(previousPalette)
                    } else {
                        // Generate new palette for this scanline
                        let linePalette = generatePaletteMedianCut(pixels: rowPixels, maxColors: 16)
                        finalPalettes.append(linePalette)
                    }
                }
            }

            // Quantize and dither for Brooks mode
            for y in 0..<targetH {
                let currentPalette = finalPalettes[y]

                for x in 0..<targetW {
                    let idx = y * targetW + x
                    var p = rawPixels[idx]

                    p.r = min(255, max(0, p.r))
                    p.g = min(255, max(0, p.g))
                    p.b = min(255, max(0, p.b))

                    if isOrdered {
                        let offset = getOrderedDitherOffset(x: x, y: y, ditherType: ditherName, amount: ditherAmount)
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

        } else {
            // D. 256 COLORS MODE (16 palettes - was previously called "3200 Mode")
            let usePaletteReuse = quantMethod.contains("Reuse")
            
            if usePaletteReuse {
                
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
                    // Group consecutive similar palettes into 16 slots
                    var slotPalettes = [[RGB]]()
                    let linesPerSlot = 200 / 16
                    
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
                            let offset = getOrderedDitherOffset(x: x, y: y, ditherType: ditherName, amount: ditherAmount)
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
                let colorPixels = slotColors.map { PixelFloat(r: $0.r, g: $0.g, b: $0.b) }
                
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
                        let offset = getOrderedDitherOffset(x: x, y: y, ditherType: ditherName, amount: ditherAmount)
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
        
        // Loop for non-3200/256 rendering (standard 320 mode, 640 modes)
        if !is3200Brooks && !is256Color {
            let currentPalette = finalPalettes[0]  // Single palette for all scanlines
            for y in 0..<targetH {
                for x in 0..<targetW {
                    let idx = y * targetW + x
                    var p = rawPixels[idx]
                    
                    p.r = min(255, max(0, p.r)); p.g = min(255, max(0, p.g)); p.b = min(255, max(0, p.b))
                    
                    if isOrdered {
                        let offset = getOrderedDitherOffset(x: x, y: y, ditherType: ditherName, amount: ditherAmount)
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

        let fileManager = FileManager.default
        let uuid = UUID().uuidString.prefix(8)

        let outputData: Data
        let outputUrl: URL

        if is3200Brooks {
            // Brooks format (3200 colors) - 38,400 bytes with 200 palettes
            outputData = generateBrooksData(indices: outputIndices, palettes: finalPalettes, width: targetW, height: targetH)
            outputUrl = fileManager.temporaryDirectory.appendingPathComponent("iigs_\(uuid).3200")
        } else {
            // Standard SHR format (32,768 bytes with 16 palettes)
            let shrIs640Mode = is640
            outputData = generateSHRData(indices: outputIndices, palettes: finalPalettes, width: targetW, height: targetH, is640: shrIs640Mode)
            outputUrl = fileManager.temporaryDirectory.appendingPathComponent("iigs_\(uuid).shr")
        }

        try outputData.write(to: outputUrl)

        // Convert palettes to PaletteRGB for editor
        let paletteRGBs: [[PaletteRGB]] = finalPalettes.map { palette in
            palette.map { PaletteRGB(r: $0.r, g: $0.g, b: $0.b) }
        }

        return ConversionResult(
            previewImage: preview,
            fileAssets: [outputUrl],
            palettes: paletteRGBs,
            pixelIndices: outputIndices,
            imageWidth: targetW,
            imageHeight: targetH
        )
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

    // MARK: - Preprocessing Filters

    func applyPreprocessing(_ pixels: inout [PixelFloat], width: Int, height: Int, filter: String,
                             medianSize: String, sharpenStrength: Double, sigmaRange: Double,
                             solarizeThreshold: Double, embossDepth: Double, edgeThreshold: Double) {
        switch filter {
        case "Lowpass":
            applyLowpassFilter(&pixels, width: width, height: height)
        case "Median":
            // Parse kernel size from "3x3", "5x5", "7x7"
            let kernelSize = Int(medianSize.prefix(1)) ?? 3
            applyMedianFilter(&pixels, width: width, height: height, kernelSize: kernelSize)
        case "Sharpen":
            applySharpenFilter(&pixels, width: width, height: height, strength: sharpenStrength)
        case "Sigma":
            applySigmaFilter(&pixels, width: width, height: height, sigma: sigmaRange)
        case "Solarize":
            applySolarizeFilter(&pixels, threshold: solarizeThreshold)
        case "Emboss":
            applyEmbossFilter(&pixels, width: width, height: height, strength: embossDepth)
        case "Find Edges":
            applyFindEdgesFilter(&pixels, width: width, height: height, threshold: edgeThreshold)
        default:
            break
        }
    }

    func applyLowpassFilter(_ pixels: inout [PixelFloat], width: Int, height: Int) {
        var result = pixels
        // 3x3 box blur kernel (all weights = 1/9)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var r: Double = 0, g: Double = 0, b: Double = 0
                for ky in -1...1 {
                    for kx in -1...1 {
                        let idx = (y + ky) * width + (x + kx)
                        r += pixels[idx].r
                        g += pixels[idx].g
                        b += pixels[idx].b
                    }
                }
                let idx = y * width + x
                result[idx].r = r / 9.0
                result[idx].g = g / 9.0
                result[idx].b = b / 9.0
            }
        }
        pixels = result
    }

    func applyMedianFilter(_ pixels: inout [PixelFloat], width: Int, height: Int, kernelSize: Int) {
        let radius = kernelSize / 2
        var result = pixels

        for y in 0..<height {
            for x in 0..<width {
                var reds: [Double] = []
                var greens: [Double] = []
                var blues: [Double] = []

                for ky in -radius...radius {
                    for kx in -radius...radius {
                        let nx = min(max(x + kx, 0), width - 1)
                        let ny = min(max(y + ky, 0), height - 1)
                        let idx = ny * width + nx
                        reds.append(pixels[idx].r)
                        greens.append(pixels[idx].g)
                        blues.append(pixels[idx].b)
                    }
                }

                reds.sort()
                greens.sort()
                blues.sort()

                let mid = reds.count / 2
                let idx = y * width + x
                result[idx].r = reds[mid]
                result[idx].g = greens[mid]
                result[idx].b = blues[mid]
            }
        }
        pixels = result
    }

    func applySharpenFilter(_ pixels: inout [PixelFloat], width: Int, height: Int, strength: Double) {
        var result = pixels
        let kernel: [Double] = [
             0, -1,  0,
            -1,  5, -1,
             0, -1,  0
        ]

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var r = 0.0, g = 0.0, b = 0.0
                var ki = 0

                for ky in -1...1 {
                    for kx in -1...1 {
                        let idx = (y + ky) * width + (x + kx)
                        let weight = kernel[ki]
                        r += pixels[idx].r * weight
                        g += pixels[idx].g * weight
                        b += pixels[idx].b * weight
                        ki += 1
                    }
                }

                let idx = y * width + x
                let orig = pixels[idx]
                result[idx].r = min(255, max(0, orig.r + (r - orig.r) * strength))
                result[idx].g = min(255, max(0, orig.g + (g - orig.g) * strength))
                result[idx].b = min(255, max(0, orig.b + (b - orig.b) * strength))
            }
        }
        pixels = result
    }

    func applySigmaFilter(_ pixels: inout [PixelFloat], width: Int, height: Int, sigma: Double) {
        var result = pixels
        let radius = 1

        for y in 0..<height {
            for x in 0..<width {
                let centerIdx = y * width + x
                let center = pixels[centerIdx]
                var sumR = 0.0, sumG = 0.0, sumB = 0.0
                var count = 0.0

                for ky in -radius...radius {
                    for kx in -radius...radius {
                        let nx = min(max(x + kx, 0), width - 1)
                        let ny = min(max(y + ky, 0), height - 1)
                        let idx = ny * width + nx
                        let p = pixels[idx]

                        let diff = abs(p.r - center.r) + abs(p.g - center.g) + abs(p.b - center.b)
                        if diff < sigma {
                            sumR += p.r
                            sumG += p.g
                            sumB += p.b
                            count += 1
                        }
                    }
                }

                if count > 0 {
                    result[centerIdx].r = sumR / count
                    result[centerIdx].g = sumG / count
                    result[centerIdx].b = sumB / count
                }
            }
        }
        pixels = result
    }

    func applySolarizeFilter(_ pixels: inout [PixelFloat], threshold: Double) {
        for i in 0..<pixels.count {
            if pixels[i].r > threshold { pixels[i].r = 255 - pixels[i].r }
            if pixels[i].g > threshold { pixels[i].g = 255 - pixels[i].g }
            if pixels[i].b > threshold { pixels[i].b = 255 - pixels[i].b }
        }
    }

    func applyEmbossFilter(_ pixels: inout [PixelFloat], width: Int, height: Int, strength: Double) {
        var result = pixels
        let kernel: [Double] = [
            -2, -1,  0,
            -1,  1,  1,
             0,  1,  2
        ]

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var r = 0.0, g = 0.0, b = 0.0
                var ki = 0

                for ky in -1...1 {
                    for kx in -1...1 {
                        let idx = (y + ky) * width + (x + kx)
                        let weight = kernel[ki] * strength
                        r += pixels[idx].r * weight
                        g += pixels[idx].g * weight
                        b += pixels[idx].b * weight
                        ki += 1
                    }
                }

                let idx = y * width + x
                result[idx].r = min(255, max(0, r + 128))
                result[idx].g = min(255, max(0, g + 128))
                result[idx].b = min(255, max(0, b + 128))
            }
        }
        pixels = result
    }

    func applyFindEdgesFilter(_ pixels: inout [PixelFloat], width: Int, height: Int, threshold: Double) {
        var result = pixels
        let sobelX: [Double] = [-1, 0, 1, -2, 0, 2, -1, 0, 1]
        let sobelY: [Double] = [-1, -2, -1, 0, 0, 0, 1, 2, 1]

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var gxR = 0.0, gyR = 0.0
                var gxG = 0.0, gyG = 0.0
                var gxB = 0.0, gyB = 0.0
                var ki = 0

                for ky in -1...1 {
                    for kx in -1...1 {
                        let idx = (y + ky) * width + (x + kx)
                        gxR += pixels[idx].r * sobelX[ki]
                        gyR += pixels[idx].r * sobelY[ki]
                        gxG += pixels[idx].g * sobelX[ki]
                        gyG += pixels[idx].g * sobelY[ki]
                        gxB += pixels[idx].b * sobelX[ki]
                        gyB += pixels[idx].b * sobelY[ki]
                        ki += 1
                    }
                }

                let magR = sqrt(gxR * gxR + gyR * gyR)
                let magG = sqrt(gxG * gxG + gyG * gyG)
                let magB = sqrt(gxB * gxB + gyB * gyB)
                let mag = (magR + magG + magB) / 3.0

                let idx = y * width + x
                let edge = mag > threshold ? 255.0 : 0.0
                result[idx].r = edge
                result[idx].g = edge
                result[idx].b = edge
            }
        }
        pixels = result
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

    func generateBrooksData(indices: [Int], palettes: [[RGB]], width: Int, height: Int) -> Data {
        // Brooks format (3200 colors): 38,400 bytes total
        // - Bytes 0-31,999: Pixel data (200 lines × 160 bytes)
        // - Bytes 32,000-38,399: 200 palettes × 32 bytes each
        // Colors are stored in REVERSE order (15 to 0) per Brooks spec

        var data = Data(count: 38400)

        // Write pixel data (same format as standard SHR 320 mode)
        for y in 0..<height {
            let lineOffset = y * 160

            for x in stride(from: 0, to: width, by: 2) {
                let bytePos = lineOffset + (x / 2)
                if bytePos >= 32000 { continue }

                let p1 = indices[y * width + x] & 0x0F
                let p2 = indices[y * width + x + 1] & 0x0F
                let byte = UInt8(p2 | (p1 << 4))
                data[bytePos] = byte
            }
        }

        // Write 200 palettes (one per scanline) in reverse color order
        let paletteOffset = 32000
        for y in 0..<200 {
            let palette = (y < palettes.count) ? palettes[y] : palettes[0]

            // Brooks format stores colors in reverse order (15 to 0)
            for colorIdx in 0..<16 {
                let reversedIdx = 15 - colorIdx
                let color = (reversedIdx < palette.count) ? palette[reversedIdx] : RGB(r: 0, g: 0, b: 0)
                let iigsVal = rgbToIIGS(color)
                let offset = paletteOffset + (y * 32) + (colorIdx * 2)
                data[offset] = UInt8(iigsVal & 0xFF)
                data[offset + 1] = UInt8((iigsVal >> 8) & 0xFF)
            }
        }

        return data
    }

    func generatePreviewImage(indices: [Int], palettes: [[RGB]], width: Int, height: Int) -> NSImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            // Determine which palette to use for this line
            let paletteIndex: Int
            if palettes.count == 200 {
                // Brooks 3200 mode - one palette per scanline
                paletteIndex = y
            } else if !paletteSlotMapping.isEmpty {
                // 256 color mode with custom mapping
                paletteIndex = paletteSlotMapping[y]
            } else {
                // Standard mode - use available palettes
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
