import Foundation
import AppKit

class PCConverter: RetroMachine {
    var name: String = "PC"

    // PC Graphics modes:
    // CGA: 320×200, 4 colors (fixed palettes)
    // EGA: 320×200, 16 colors from 64
    // VGA: 320×200, 256 colors (Mode 13h)
    // CGA Text: 80×25 chars (640×200), 16 colors
    // VESA Text: 132×50 chars (1056×400), 16 colors

    var options: [ConversionOption] = [
        ConversionOption(label: "Mode", key: "mode",
                        values: ["CGA (4 colors)", "EGA (16 colors)", "VGA (256 colors)", "CGA 80×25 Text", "VESA 132×50 Text"],
                        selectedValue: "VGA (256 colors)"),
        ConversionOption(label: "CGA Palette", key: "cga_palette",
                        values: ["Cyan/Magenta/White", "Cyan/Magenta/Gray", "Green/Red/Yellow", "Green/Red/Brown"],
                        selectedValue: "Cyan/Magenta/White"),
        ConversionOption(label: "Dither", key: "dither",
                        values: ["None", "Floyd-Steinberg", "Atkinson", "Bayer 2x2", "Bayer 4x4", "Bayer 8x8"],
                        selectedValue: "Floyd-Steinberg"),
        ConversionOption(label: "Dither Amount", key: "dither_amount",
                        range: 0.0...1.0, defaultValue: 0.5),
        ConversionOption(label: "Contrast", key: "contrast",
                        values: ["None", "HE", "CLAHE", "SWAHE"],
                        selectedValue: "None"),
        ConversionOption(label: "Filter", key: "filter",
                        values: ["None", "Lowpass", "Sharpen", "Emboss", "Edge"],
                        selectedValue: "None"),
        ConversionOption(label: "Color Match", key: "color_match",
                        values: ["Euclidean", "Perceptive", "Luma", "Chroma"],
                        selectedValue: "Perceptive"),
        ConversionOption(label: "Saturation", key: "saturation",
                        range: 0.5...2.0, defaultValue: 1.0),
        ConversionOption(label: "Gamma", key: "gamma",
                        range: 0.5...2.0, defaultValue: 1.0)
    ]

    // CGA 16-color palette (used for text modes and EGA)
    static let cgaPalette: [[UInt8]] = [
        [0x00, 0x00, 0x00],  // 0: Black
        [0x00, 0x00, 0xAA],  // 1: Blue
        [0x00, 0xAA, 0x00],  // 2: Green
        [0x00, 0xAA, 0xAA],  // 3: Cyan
        [0xAA, 0x00, 0x00],  // 4: Red
        [0xAA, 0x00, 0xAA],  // 5: Magenta
        [0xAA, 0x55, 0x00],  // 6: Brown
        [0xAA, 0xAA, 0xAA],  // 7: Light Gray
        [0x55, 0x55, 0x55],  // 8: Dark Gray
        [0x55, 0x55, 0xFF],  // 9: Light Blue
        [0x55, 0xFF, 0x55],  // 10: Light Green
        [0x55, 0xFF, 0xFF],  // 11: Light Cyan
        [0xFF, 0x55, 0x55],  // 12: Light Red
        [0xFF, 0x55, 0xFF],  // 13: Light Magenta
        [0xFF, 0xFF, 0x55],  // 14: Yellow
        [0xFF, 0xFF, 0xFF]   // 15: White
    ]

    // CGA 4-color graphics palettes
    static let cgaPalette0High: [[UInt8]] = [[0x00, 0x00, 0x00], [0x55, 0xFF, 0x55], [0xFF, 0x55, 0x55], [0xFF, 0xFF, 0x55]]  // Black, LGreen, LRed, Yellow
    static let cgaPalette0Low: [[UInt8]] = [[0x00, 0x00, 0x00], [0x00, 0xAA, 0x00], [0xAA, 0x00, 0x00], [0xAA, 0x55, 0x00]]   // Black, Green, Red, Brown
    static let cgaPalette1High: [[UInt8]] = [[0x00, 0x00, 0x00], [0x55, 0xFF, 0xFF], [0xFF, 0x55, 0xFF], [0xFF, 0xFF, 0xFF]] // Black, LCyan, LMagenta, White
    static let cgaPalette1Low: [[UInt8]] = [[0x00, 0x00, 0x00], [0x00, 0xAA, 0xAA], [0xAA, 0x00, 0xAA], [0xAA, 0xAA, 0xAA]]  // Black, Cyan, Magenta, LGray

    // EGA 64-color palette (6-bit RGB: 2 bits per channel)
    static let egaPalette: [[UInt8]] = {
        var palette: [[UInt8]] = []
        for i in 0..<64 {
            // EGA uses RGBrgb bit pattern: bit5=r, bit4=g, bit3=b, bit2=R, bit1=G, bit0=B
            let rHigh = (i >> 2) & 0x01
            let rLow = (i >> 5) & 0x01
            let gHigh = (i >> 1) & 0x01
            let gLow = (i >> 4) & 0x01
            let bHigh = i & 0x01
            let bLow = (i >> 3) & 0x01
            let r = UInt8(rHigh * 0xAA + rLow * 0x55)
            let g = UInt8(gHigh * 0xAA + gLow * 0x55)
            let b = UInt8(bHigh * 0xAA + bLow * 0x55)
            palette.append([r, g, b])
        }
        return palette
    }()

    // MARK: - K-D Tree for fast color lookup (VGA optimization)

    private class KDTreeNode {
        let paletteIndex: Int
        let color: (r: Float, g: Float, b: Float)
        var left: KDTreeNode?
        var right: KDTreeNode?
        let splitAxis: Int  // 0=R, 1=G, 2=B

        init(paletteIndex: Int, color: (Float, Float, Float), splitAxis: Int) {
            self.paletteIndex = paletteIndex
            self.color = color
            self.splitAxis = splitAxis
        }
    }

    private func buildKDTree(palette: [[UInt8]], indices: [Int], depth: Int) -> KDTreeNode? {
        guard !indices.isEmpty else { return nil }

        let axis = depth % 3
        let sorted = indices.sorted { i1, i2 in
            let c1 = palette[i1], c2 = palette[i2]
            switch axis {
            case 0: return c1[0] < c2[0]
            case 1: return c1[1] < c2[1]
            default: return c1[2] < c2[2]
            }
        }

        let mid = sorted.count / 2
        let idx = sorted[mid]
        let c = palette[idx]
        let node = KDTreeNode(paletteIndex: idx, color: (Float(c[0]), Float(c[1]), Float(c[2])), splitAxis: axis)

        if mid > 0 {
            node.left = buildKDTree(palette: palette, indices: Array(sorted[0..<mid]), depth: depth + 1)
        }
        if mid + 1 < sorted.count {
            node.right = buildKDTree(palette: palette, indices: Array(sorted[(mid + 1)...]), depth: depth + 1)
        }

        return node
    }

    private func kdTreeFindNearest(node: KDTreeNode?, r: Float, g: Float, b: Float, best: inout (index: Int, dist: Float), palette: [[UInt8]]) {
        guard let node = node else { return }

        // Calculate distance to this node's color
        let c = node.color
        let dr = r - c.r, dg = g - c.g, db = b - c.b
        // Use simple Euclidean for k-d tree traversal (fast)
        let dist = dr * dr + dg * dg + db * db

        if dist < best.dist {
            best = (node.paletteIndex, dist)
        }

        // Determine which subtree to search first
        let query: Float
        let nodeVal: Float
        switch node.splitAxis {
        case 0: query = r; nodeVal = c.r
        case 1: query = g; nodeVal = c.g
        default: query = b; nodeVal = c.b
        }

        let diff = query - nodeVal
        let (first, second) = diff < 0 ? (node.left, node.right) : (node.right, node.left)

        // Search the closer subtree
        kdTreeFindNearest(node: first, r: r, g: g, b: b, best: &best, palette: palette)

        // Check if we need to search the other subtree
        if diff * diff < best.dist {
            kdTreeFindNearest(node: second, r: r, g: g, b: b, best: &best, palette: palette)
        }
    }

    // CP437 charset (8x8 bitmap font) - simplified subset for text rendering
    static let charset: [[UInt8]] = {
        // Generate basic charset patterns for characters 0-255
        // This is a simplified version - real implementation would use actual CP437 bitmaps
        var chars: [[UInt8]] = []
        for _ in 0..<256 {
            chars.append([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        }
        // Space (32)
        chars[32] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        // Full block (219)
        chars[219] = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
        // Upper half block (223)
        chars[223] = [0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00]
        // Lower half block (220)
        chars[220] = [0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF]
        // Light shade (176)
        chars[176] = [0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA]
        // Medium shade (177)
        chars[177] = [0x55, 0xFF, 0xAA, 0xFF, 0x55, 0xFF, 0xAA, 0xFF]
        // Dark shade (178)
        chars[178] = [0xFF, 0xAA, 0xFF, 0x55, 0xFF, 0xAA, 0xFF, 0x55]
        // Left half block (221)
        chars[221] = [0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0]
        // Right half block (222)
        chars[222] = [0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F]
        // Quadrant patterns (often needed for good matching)
        chars[1] = [0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00]   // Upper half
        chars[2] = [0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF]   // Lower half
        chars[3] = [0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0, 0xF0]   // Left half
        chars[4] = [0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F]   // Right half
        chars[5] = [0xF0, 0xF0, 0xF0, 0xF0, 0x00, 0x00, 0x00, 0x00]   // Upper left
        chars[6] = [0x0F, 0x0F, 0x0F, 0x0F, 0x00, 0x00, 0x00, 0x00]   // Upper right
        chars[7] = [0x00, 0x00, 0x00, 0x00, 0xF0, 0xF0, 0xF0, 0xF0]   // Lower left
        chars[8] = [0x00, 0x00, 0x00, 0x00, 0x0F, 0x0F, 0x0F, 0x0F]   // Lower right
        // Gradients
        chars[9] = [0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80]
        chars[10] = [0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0]
        chars[11] = [0xE0, 0xE0, 0xE0, 0xE0, 0xE0, 0xE0, 0xE0, 0xE0]
        chars[12] = [0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01]
        chars[13] = [0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03]
        chars[14] = [0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07]
        // Horizontal lines
        chars[15] = [0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        chars[16] = [0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00]
        chars[17] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF]
        chars[18] = [0xFF, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00]
        chars[19] = [0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00, 0xFF, 0x00]
        // Vertical lines
        chars[20] = [0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80]
        chars[21] = [0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08]
        chars[22] = [0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01]
        chars[23] = [0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88]
        chars[24] = [0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA]
        // Diagonal patterns
        chars[25] = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80]
        chars[26] = [0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01]
        // Dots
        chars[27] = [0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00]
        chars[28] = [0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18]
        // More shade variations
        chars[29] = [0x11, 0x44, 0x11, 0x44, 0x11, 0x44, 0x11, 0x44]
        chars[30] = [0x22, 0x88, 0x22, 0x88, 0x22, 0x88, 0x22, 0x88]
        chars[31] = [0x33, 0xCC, 0x33, 0xCC, 0x33, 0xCC, 0x33, 0xCC]

        return chars
    }()

    func convert(sourceImage: NSImage) async throws -> ConversionResult {
        let mode = options.first(where: { $0.key == "mode" })?.selectedValue ?? "VGA (256 colors)"
        let cgaPaletteChoice = options.first(where: { $0.key == "cga_palette" })?.selectedValue ?? "Cyan/Magenta/White"
        let ditherAlg = options.first(where: { $0.key == "dither" })?.selectedValue ?? "Floyd-Steinberg"
        let ditherAmount = Double(options.first(where: { $0.key == "dither_amount" })?.selectedValue ?? "0.5") ?? 0.5
        let contrast = options.first(where: { $0.key == "contrast" })?.selectedValue ?? "None"
        let filterMode = options.first(where: { $0.key == "filter" })?.selectedValue ?? "None"
        let colorMatch = options.first(where: { $0.key == "color_match" })?.selectedValue ?? "Perceptive"
        let saturation = Double(options.first(where: { $0.key == "saturation" })?.selectedValue ?? "1.0") ?? 1.0
        let gamma = Double(options.first(where: { $0.key == "gamma" })?.selectedValue ?? "1.0") ?? 1.0

        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "PCConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }

        switch mode {
        case "CGA (4 colors)":
            return try await convertCGA(cgImage: cgImage, paletteChoice: cgaPaletteChoice, ditherAlg: ditherAlg, ditherAmount: ditherAmount, contrast: contrast, filter: filterMode, colorMatch: colorMatch, saturation: saturation, gamma: gamma)
        case "EGA (16 colors)":
            return try await convertEGA(cgImage: cgImage, ditherAlg: ditherAlg, ditherAmount: ditherAmount, contrast: contrast, filter: filterMode, colorMatch: colorMatch, saturation: saturation, gamma: gamma)
        case "VGA (256 colors)":
            return try await convertVGA(cgImage: cgImage, ditherAlg: ditherAlg, ditherAmount: ditherAmount, contrast: contrast, filter: filterMode, colorMatch: colorMatch, saturation: saturation, gamma: gamma)
        case "CGA 80×25 Text":
            return try await convertText(cgImage: cgImage, cols: 80, rows: 25, ditherAlg: ditherAlg, ditherAmount: ditherAmount, contrast: contrast, filter: filterMode, colorMatch: colorMatch, saturation: saturation, gamma: gamma)
        case "VESA 132×50 Text":
            return try await convertText(cgImage: cgImage, cols: 132, rows: 50, ditherAlg: ditherAlg, ditherAmount: ditherAmount, contrast: contrast, filter: filterMode, colorMatch: colorMatch, saturation: saturation, gamma: gamma)
        default:
            return try await convertVGA(cgImage: cgImage, ditherAlg: ditherAlg, ditherAmount: ditherAmount, contrast: contrast, filter: filterMode, colorMatch: colorMatch, saturation: saturation, gamma: gamma)
        }
    }

    // MARK: - CGA 320×200 4-color mode

    private func convertCGA(cgImage: CGImage, paletteChoice: String, ditherAlg: String, ditherAmount: Double, contrast: String, filter: String, colorMatch: String, saturation: Double, gamma: Double) async throws -> ConversionResult {
        let width = 320, height = 200
        var pixels = scaleImage(cgImage, toWidth: width, height: height)

        // Preprocessing
        if saturation != 1.0 { applySaturation(&pixels, width: width, height: height, saturation: saturation) }
        if gamma != 1.0 { applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if contrast != "None" { applyContrast(&pixels, width: width, height: height, method: contrast) }
        if filter != "None" { applyImageFilter(&pixels, width: width, height: height, filter: filter) }
        if ditherAlg.contains("Bayer") { applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount) }

        // Select CGA palette
        let palette: [[UInt8]]
        switch paletteChoice {
        case "Cyan/Magenta/White": palette = Self.cgaPalette1High
        case "Cyan/Magenta/Gray": palette = Self.cgaPalette1Low
        case "Green/Red/Yellow": palette = Self.cgaPalette0High
        case "Green/Red/Brown": palette = Self.cgaPalette0Low
        default: palette = Self.cgaPalette1High
        }

        let (resultPixels, _) = convertToFixedPalette(pixels: pixels, width: width, height: height, palette: palette, ditherAlg: ditherAlg, ditherAmount: ditherAmount, colorMatch: colorMatch, bitsPerPixel: 2)

        let previewImage = createPreviewImage(resultPixels: resultPixels, width: width, height: height, scaleY: 2.4)

        // Create PCX file
        let pcxData = createPCXData(resultPixels: resultPixels, width: width, height: height, palette: palette, bitsPerPixel: 2)
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("pc_cga_\(uuid).pcx")
        try pcxData.write(to: nativeUrl)

        return ConversionResult(previewImage: previewImage, fileAssets: [nativeUrl], palettes: [], pixelIndices: [], imageWidth: width, imageHeight: height)
    }

    // MARK: - EGA 320×200 16-color mode

    private func convertEGA(cgImage: CGImage, ditherAlg: String, ditherAmount: Double, contrast: String, filter: String, colorMatch: String, saturation: Double, gamma: Double) async throws -> ConversionResult {
        let width = 320, height = 200
        var pixels = scaleImage(cgImage, toWidth: width, height: height)

        if saturation != 1.0 { applySaturation(&pixels, width: width, height: height, saturation: saturation) }
        if gamma != 1.0 { applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if contrast != "None" { applyContrast(&pixels, width: width, height: height, method: contrast) }
        if filter != "None" { applyImageFilter(&pixels, width: width, height: height, filter: filter) }
        if ditherAlg.contains("Bayer") { applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount) }

        // Use standard fixed 16-color EGA palette (same as CGA 16-color)
        let selectedPalette = Self.cgaPalette

        let (resultPixels, _) = convertToFixedPalette(pixels: pixels, width: width, height: height, palette: selectedPalette, ditherAlg: ditherAlg, ditherAmount: ditherAmount, colorMatch: colorMatch, bitsPerPixel: 4)

        let previewImage = createPreviewImage(resultPixels: resultPixels, width: width, height: height, scaleY: 2.4)

        // Create PCX file
        let pcxData = createPCXData(resultPixels: resultPixels, width: width, height: height, palette: selectedPalette, bitsPerPixel: 4)
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("pc_ega_\(uuid).pcx")
        try pcxData.write(to: nativeUrl)

        return ConversionResult(previewImage: previewImage, fileAssets: [nativeUrl], palettes: [], pixelIndices: [], imageWidth: width, imageHeight: height)
    }

    // MARK: - VGA 320×200 256-color mode (Mode 13h)

    private func convertVGA(cgImage: CGImage, ditherAlg: String, ditherAmount: Double, contrast: String, filter: String, colorMatch: String, saturation: Double, gamma: Double) async throws -> ConversionResult {
        let width = 320, height = 200
        var pixels = scaleImage(cgImage, toWidth: width, height: height)

        if saturation != 1.0 { applySaturation(&pixels, width: width, height: height, saturation: saturation) }
        if gamma != 1.0 { applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if contrast != "None" { applyContrast(&pixels, width: width, height: height, method: contrast) }
        if filter != "None" { applyImageFilter(&pixels, width: width, height: height, filter: filter) }
        if ditherAlg.contains("Bayer") { applyOrderedDither(&pixels, width: width, height: height, ditherType: ditherAlg, amount: ditherAmount) }

        // Generate adaptive 256-color palette using median cut
        let adaptivePalette = generateAdaptivePalette(pixels: pixels, numColors: 256)

        // Build k-d tree for fast color lookup (O(log n) instead of O(n))
        let kdTree = buildKDTree(palette: adaptivePalette, indices: Array(0..<adaptivePalette.count), depth: 0)

        // Use k-d tree accelerated conversion
        let resultPixels = convertWithKDTree(pixels: &pixels, width: width, height: height, palette: adaptivePalette, kdTree: kdTree, ditherAlg: ditherAlg, ditherAmount: ditherAmount)

        let previewImage = createPreviewImage(resultPixels: resultPixels, width: width, height: height, scaleY: 2.4)

        // Create PCX file
        let pcxData = createPCXData(resultPixels: resultPixels, width: width, height: height, palette: adaptivePalette, bitsPerPixel: 8)
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let nativeUrl = tempDir.appendingPathComponent("pc_vga_\(uuid).pcx")
        try pcxData.write(to: nativeUrl)

        return ConversionResult(previewImage: previewImage, fileAssets: [nativeUrl], palettes: [], pixelIndices: [], imageWidth: width, imageHeight: height)
    }

    // Fast VGA conversion using k-d tree for O(log n) color lookup
    private func convertWithKDTree(pixels: inout [[Float]], width: Int, height: Int, palette: [[UInt8]], kdTree: KDTreeNode?, ditherAlg: String, ditherAmount: Double) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: width * height * 3)
        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"

        for y in 0..<height {
            for x in 0..<width {
                let r = max(0, min(255, pixels[y * width + x][0]))
                let g = max(0, min(255, pixels[y * width + x][1]))
                let b = max(0, min(255, pixels[y * width + x][2]))

                // Use k-d tree for fast nearest color lookup
                var best: (index: Int, dist: Float) = (0, Float.greatestFiniteMagnitude)
                kdTreeFindNearest(node: kdTree, r: r, g: g, b: b, best: &best, palette: palette)

                let colorIndex = best.index
                let color = palette[colorIndex]

                let idx = (y * width + x) * 3
                result[idx] = color[0]
                result[idx + 1] = color[1]
                result[idx + 2] = color[2]

                // Error diffusion
                if useErrorDiffusion {
                    let rErr = (r - Float(color[0])) * Float(ditherAmount)
                    let gErr = (g - Float(color[1])) * Float(ditherAmount)
                    let bErr = (b - Float(color[2])) * Float(ditherAmount)
                    distributeError(&pixels, width: width, height: height, x: x, y: y, rErr: rErr, gErr: gErr, bErr: bErr, alg: ditherAlg)
                }
            }
        }

        return result
    }

    // MARK: - Text Mode Conversion

    private func convertText(cgImage: CGImage, cols: Int, rows: Int, ditherAlg: String, ditherAmount: Double, contrast: String, filter: String, colorMatch: String, saturation: Double, gamma: Double) async throws -> ConversionResult {
        let charWidth = 8, charHeight = 8
        let width = cols * charWidth
        let height = rows * charHeight

        var pixels = scaleImage(cgImage, toWidth: width, height: height)

        if saturation != 1.0 { applySaturation(&pixels, width: width, height: height, saturation: saturation) }
        if gamma != 1.0 { applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if contrast != "None" { applyContrast(&pixels, width: width, height: height, method: contrast) }
        if filter != "None" { applyImageFilter(&pixels, width: width, height: height, filter: filter) }

        var result = [UInt8](repeating: 0, count: width * height * 3)
        var screenData = Data(count: cols * rows * 2)  // Character + attribute bytes

        // Process each 8×8 cell
        for row in 0..<rows {
            for col in 0..<cols {
                let cellX = col * charWidth
                let cellY = row * charHeight

                // Extract 8×8 tile
                var tile = [[Float]](repeating: [0, 0, 0], count: 64)
                for ty in 0..<charHeight {
                    for tx in 0..<charWidth {
                        tile[ty * charWidth + tx] = pixels[(cellY + ty) * width + (cellX + tx)]
                    }
                }

                // Find brightest and darkest colors in tile
                var maxLuma: Float = 0, minLuma: Float = Float.greatestFiniteMagnitude
                var fgIdx = 15, bgIdx = 0

                for p in tile {
                    let luma = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
                    if luma > maxLuma {
                        maxLuma = luma
                        fgIdx = findClosestColor(r: p[0], g: p[1], b: p[2], palette: Self.cgaPalette, method: colorMatch)
                    }
                    if luma < minLuma {
                        minLuma = luma
                        bgIdx = findClosestColor(r: p[0], g: p[1], b: p[2], palette: Self.cgaPalette.prefix(8).map { $0 }, method: colorMatch)
                    }
                }

                let fgColor = Self.cgaPalette[fgIdx]
                let bgColor = Self.cgaPalette[bgIdx]

                // Create binary pattern based on foreground/background distance
                var pattern = [UInt8](repeating: 0, count: 8)
                for ty in 0..<8 {
                    var byte: UInt8 = 0
                    for tx in 0..<8 {
                        let p = tile[ty * 8 + tx]
                        let dFg = colorDistance(p[0], p[1], p[2], Float(fgColor[0]), Float(fgColor[1]), Float(fgColor[2]), colorMatch)
                        let dBg = colorDistance(p[0], p[1], p[2], Float(bgColor[0]), Float(bgColor[1]), Float(bgColor[2]), colorMatch)
                        if dFg <= dBg {
                            byte |= UInt8(1 << (7 - tx))
                        }
                    }
                    pattern[ty] = byte
                }

                // Find best matching character
                let charCode = findBestCharacter(pattern: pattern)

                // Store screen data (character code + attribute)
                let addr = (row * cols + col) * 2
                screenData[addr] = UInt8(charCode)
                screenData[addr + 1] = UInt8((bgIdx << 4) | fgIdx)

                // Render to preview
                let charBitmap = Self.charset[charCode]
                for ty in 0..<8 {
                    let charByte = charBitmap[ty]
                    for tx in 0..<8 {
                        let bit = (charByte >> (7 - tx)) & 1
                        let color = bit == 1 ? fgColor : bgColor
                        let idx = ((cellY + ty) * width + (cellX + tx)) * 3
                        result[idx] = color[0]
                        result[idx + 1] = color[1]
                        result[idx + 2] = color[2]
                    }
                }
            }
        }

        // Scale for display - correct to 4:3 aspect ratio
        // CGA 80×25: 640×200 → with scaleX=2, width=1280, so height=960 for 4:3 → scaleY=960/200=4.8
        // VESA 132×50: 1056×400 → with scaleX=2, width=2112, so height=1584 for 4:3 → scaleY≈4.0
        let scaleY: Double = cols == 80 ? 4.8 : 4.0
        let previewImage = createPreviewImage(resultPixels: result, width: width, height: height, scaleY: scaleY)

        // Create ANSI file
        let ansiData = createANSIData(screenData: screenData, cols: cols, rows: rows)
        let tempDir = FileManager.default.temporaryDirectory
        let uuid = UUID().uuidString.prefix(8)
        let suffix = cols == 80 ? "cga_text" : "vesa_text"
        let nativeUrl = tempDir.appendingPathComponent("pc_\(suffix)_\(uuid).ans")
        try ansiData.write(to: nativeUrl)

        return ConversionResult(previewImage: previewImage, fileAssets: [nativeUrl], palettes: [], pixelIndices: [], imageWidth: width, imageHeight: height)
    }

    private func findBestCharacter(pattern: [UInt8]) -> Int {
        var bestChar = 32  // Default to space
        var bestScore = Int.max

        for charIdx in 0..<256 {
            let charBitmap = Self.charset[charIdx]
            var score = 0
            for y in 0..<8 {
                let diff = pattern[y] ^ charBitmap[y]
                score += diff.nonzeroBitCount
            }
            if score < bestScore {
                bestScore = score
                bestChar = charIdx
            }
        }

        return bestChar
    }

    // MARK: - Common conversion

    private func convertToFixedPalette(pixels: [[Float]], width: Int, height: Int, palette: [[UInt8]], ditherAlg: String, ditherAmount: Double, colorMatch: String, bitsPerPixel: Int) -> ([UInt8], Data) {
        var work = pixels
        var result = [UInt8](repeating: 0, count: width * height * 3)
        var rawData = Data()

        let useErrorDiffusion = ditherAlg == "Floyd-Steinberg" || ditherAlg == "Atkinson"
        var bitBuffer: UInt8 = 0
        var bitsInBuffer = 0

        for y in 0..<height {
            for x in 0..<width {
                let r = max(0, min(255, work[y * width + x][0]))
                let g = max(0, min(255, work[y * width + x][1]))
                let b = max(0, min(255, work[y * width + x][2]))

                let colorIndex = findClosestColor(r: r, g: g, b: b, palette: palette, method: colorMatch)
                let color = palette[colorIndex]

                let idx = (y * width + x) * 3
                result[idx] = color[0]
                result[idx + 1] = color[1]
                result[idx + 2] = color[2]

                // Pack pixels into bytes
                bitBuffer = (bitBuffer << bitsPerPixel) | UInt8(colorIndex)
                bitsInBuffer += bitsPerPixel
                if bitsInBuffer >= 8 {
                    rawData.append(bitBuffer)
                    bitBuffer = 0
                    bitsInBuffer = 0
                }

                // Error diffusion
                if useErrorDiffusion {
                    let rErr = (r - Float(color[0])) * Float(ditherAmount)
                    let gErr = (g - Float(color[1])) * Float(ditherAmount)
                    let bErr = (b - Float(color[2])) * Float(ditherAmount)
                    distributeError(&work, width: width, height: height, x: x, y: y, rErr: rErr, gErr: gErr, bErr: bErr, alg: ditherAlg)
                }
            }
            // Flush remaining bits at end of row
            if bitsInBuffer > 0 {
                bitBuffer <<= (8 - bitsInBuffer)
                rawData.append(bitBuffer)
                bitBuffer = 0
                bitsInBuffer = 0
            }
        }

        return (result, rawData)
    }

    // MARK: - Palette selection

    private func selectOptimalPalette(pixels: [[Float]], palette: [[UInt8]], numColors: Int) -> [[UInt8]] {
        var colorCounts: [Int: Int] = [:]
        for pixel in pixels {
            let idx = findClosestColor(r: pixel[0], g: pixel[1], b: pixel[2], palette: palette, method: "Euclidean")
            colorCounts[idx, default: 0] += 1
        }
        let sorted = colorCounts.sorted { $0.value > $1.value }
        var result: [[UInt8]] = []
        for (idx, _) in sorted.prefix(numColors) {
            result.append(palette[idx])
        }
        while result.count < numColors { result.append([0, 0, 0]) }
        return result
    }

    private func generateAdaptivePalette(pixels: [[Float]], numColors: Int) -> [[UInt8]] {
        // Simple median-cut algorithm
        var boxes: [[(r: Float, g: Float, b: Float)]] = [pixels.map { (r: $0[0], g: $0[1], b: $0[2]) }]

        while boxes.count < numColors {
            // Find box with largest range
            var maxRangeIdx = 0
            var maxRange: Float = 0

            for (i, box) in boxes.enumerated() {
                guard !box.isEmpty else { continue }
                let rRange = box.map { $0.r }.max()! - box.map { $0.r }.min()!
                let gRange = box.map { $0.g }.max()! - box.map { $0.g }.min()!
                let bRange = box.map { $0.b }.max()! - box.map { $0.b }.min()!
                let range = max(rRange, gRange, bRange)
                if range > maxRange {
                    maxRange = range
                    maxRangeIdx = i
                }
            }

            let box = boxes[maxRangeIdx]
            guard box.count > 1 else { break }

            // Split on axis with largest range
            let rRange = box.map { $0.r }.max()! - box.map { $0.r }.min()!
            let gRange = box.map { $0.g }.max()! - box.map { $0.g }.min()!
            let bRange = box.map { $0.b }.max()! - box.map { $0.b }.min()!

            var sorted: [(r: Float, g: Float, b: Float)]
            if rRange >= gRange && rRange >= bRange {
                sorted = box.sorted { $0.r < $1.r }
            } else if gRange >= bRange {
                sorted = box.sorted { $0.g < $1.g }
            } else {
                sorted = box.sorted { $0.b < $1.b }
            }

            let mid = sorted.count / 2
            boxes[maxRangeIdx] = Array(sorted[0..<mid])
            boxes.append(Array(sorted[mid...]))
        }

        // Extract palette from box averages
        var palette: [[UInt8]] = []
        for box in boxes {
            guard !box.isEmpty else { continue }
            let avgR = box.map { $0.r }.reduce(0, +) / Float(box.count)
            let avgG = box.map { $0.g }.reduce(0, +) / Float(box.count)
            let avgB = box.map { $0.b }.reduce(0, +) / Float(box.count)
            palette.append([UInt8(max(0, min(255, avgR))), UInt8(max(0, min(255, avgG))), UInt8(max(0, min(255, avgB)))])
        }

        while palette.count < numColors { palette.append([0, 0, 0]) }
        return Array(palette.prefix(numColors))
    }

    // MARK: - Helper functions

    private func scaleImage(_ cgImage: CGImage, toWidth width: Int, height: Int) -> [[Float]] {
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

    private func colorDistance(_ r1: Float, _ g1: Float, _ b1: Float, _ r2: Float, _ g2: Float, _ b2: Float, _ method: String) -> Float {
        let dr = r1 - r2, dg = g1 - g2, db = b1 - b2
        switch method {
        case "Perceptive":
            let rmean = (r1 + r2) / 2.0
            return sqrt((2.0 + rmean / 256.0) * dr * dr + 4.0 * dg * dg + (2.0 + (255.0 - rmean) / 256.0) * db * db)
        case "Luma":
            let luma1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
            let luma2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
            let dLuma = luma1 - luma2
            return abs(dLuma) * 3.0 + sqrt(dr * dr + dg * dg + db * db) * 0.1
        case "Chroma":
            let luma1 = 0.299 * r1 + 0.587 * g1 + 0.114 * b1
            let luma2 = 0.299 * r2 + 0.587 * g2 + 0.114 * b2
            let cr1 = luma1 > 1 ? r1 / luma1 : 0, cg1 = luma1 > 1 ? g1 / luma1 : 0, cb1 = luma1 > 1 ? b1 / luma1 : 0
            let cr2 = luma2 > 1 ? r2 / luma2 : 0, cg2 = luma2 > 1 ? g2 / luma2 : 0, cb2 = luma2 > 1 ? b2 / luma2 : 0
            let chromaDist = sqrt((cr1-cr2)*(cr1-cr2) + (cg1-cg2)*(cg1-cg2) + (cb1-cb2)*(cb1-cb2)) * 255.0
            let lumaDist = abs(luma1 - luma2) * 0.2
            return chromaDist + lumaDist
        default:
            return sqrt(dr * dr + dg * dg + db * db)
        }
    }

    private func findClosestColor(r: Float, g: Float, b: Float, palette: [[UInt8]], method: String) -> Int {
        var bestIdx = 0
        var bestDist = Float.greatestFiniteMagnitude
        for (i, c) in palette.enumerated() {
            let d = colorDistance(r, g, b, Float(c[0]), Float(c[1]), Float(c[2]), method)
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        return bestIdx
    }

    private func distributeError(_ work: inout [[Float]], width: Int, height: Int, x: Int, y: Int, rErr: Float, gErr: Float, bErr: Float, alg: String) {
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

    private func createPreviewImage(resultPixels: [UInt8], width: Int, height: Int, scaleY: Double) -> NSImage {
        let scaleX = 2
        let scaleYInt = Int(scaleY)
        let previewW = width * scaleX
        let previewH = height * scaleYInt
        var preview = [UInt8](repeating: 0, count: previewW * previewH * 4)

        for y in 0..<height {
            for x in 0..<width {
                let srcIdx = (y * width + x) * 3
                for dy in 0..<scaleYInt {
                    for dx in 0..<scaleX {
                        let dstIdx = ((y * scaleYInt + dy) * previewW + (x * scaleX + dx)) * 4
                        preview[dstIdx] = resultPixels[srcIdx]
                        preview[dstIdx + 1] = resultPixels[srcIdx + 1]
                        preview[dstIdx + 2] = resultPixels[srcIdx + 2]
                        preview[dstIdx + 3] = 255
                    }
                }
            }
        }

        let ctx = CGContext(data: &preview, width: previewW, height: previewH, bitsPerComponent: 8, bytesPerRow: previewW * 4,
                           space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: previewW, height: previewH))
    }

    // MARK: - Preprocessing

    private func applySaturation(_ pixels: inout [[Float]], width: Int, height: Int, saturation: Double) {
        let sat = Float(saturation)
        for i in 0..<pixels.count {
            let gray = 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2]
            pixels[i][0] = max(0, min(255, gray + (pixels[i][0] - gray) * sat))
            pixels[i][1] = max(0, min(255, gray + (pixels[i][1] - gray) * sat))
            pixels[i][2] = max(0, min(255, gray + (pixels[i][2] - gray) * sat))
        }
    }

    private func applyGamma(_ pixels: inout [[Float]], width: Int, height: Int, gamma: Double) {
        let inv = 1.0 / gamma
        for i in 0..<pixels.count {
            pixels[i][0] = Float(pow(Double(pixels[i][0]) / 255.0, inv) * 255.0)
            pixels[i][1] = Float(pow(Double(pixels[i][1]) / 255.0, inv) * 255.0)
            pixels[i][2] = Float(pow(Double(pixels[i][2]) / 255.0, inv) * 255.0)
        }
    }

    private func applyContrast(_ pixels: inout [[Float]], width: Int, height: Int, method: String) {
        switch method {
        case "HE":
            applyHistogramEqualization(&pixels, width: width, height: height)
        case "CLAHE":
            applyCLAHE(&pixels, width: width, height: height, clipLimit: 3.0)
        case "SWAHE":
            applySWAHE(&pixels, width: width, height: height, windowSize: 40)
        default:
            break
        }
    }

    private func applyHistogramEqualization(_ pixels: inout [[Float]], width: Int, height: Int) {
        let total = width * height
        var histogram = [Int](repeating: 0, count: 256)
        for i in 0..<total {
            let luma = Int(max(0, min(255, 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2])))
            histogram[luma] += 1
        }
        var cdf = [Float](repeating: 0, count: 256)
        var cumulative = 0
        for i in 0..<256 {
            cumulative += histogram[i]
            cdf[i] = Float(cumulative) / Float(total) * 255.0
        }
        for i in 0..<total {
            let r = pixels[i][0], g = pixels[i][1], b = pixels[i][2]
            let luma = 0.299 * r + 0.587 * g + 0.114 * b
            let bin = Int(max(0, min(255, luma)))
            let newLuma = cdf[bin]
            if luma > 0.001 {
                let scale = newLuma / luma
                pixels[i][0] = max(0, min(255, r * scale))
                pixels[i][1] = max(0, min(255, g * scale))
                pixels[i][2] = max(0, min(255, b * scale))
            }
        }
    }

    private func applyCLAHE(_ pixels: inout [[Float]], width: Int, height: Int, clipLimit: Float) {
        let tileWidth = 40, tileHeight = 25
        let tilesX = (width + tileWidth - 1) / tileWidth
        let tilesY = (height + tileHeight - 1) / tileHeight

        for ty in 0..<tilesY {
            for tx in 0..<tilesX {
                let startX = tx * tileWidth, startY = ty * tileHeight
                let endX = min(startX + tileWidth, width), endY = min(startY + tileHeight, height)
                let tilePixels = (endX - startX) * (endY - startY)

                var histogram = [Int](repeating: 0, count: 256)
                for y in startY..<endY {
                    for x in startX..<endX {
                        let idx = y * width + x
                        let luma = Int(max(0, min(255, 0.299 * pixels[idx][0] + 0.587 * pixels[idx][1] + 0.114 * pixels[idx][2])))
                        histogram[luma] += 1
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
                for i in 0..<256 { histogram[i] += increment }

                var cdf = [Float](repeating: 0, count: 256)
                var cumulative = 0
                for i in 0..<256 {
                    cumulative += histogram[i]
                    cdf[i] = Float(cumulative) / Float(tilePixels) * 255.0
                }

                for y in startY..<endY {
                    for x in startX..<endX {
                        let idx = y * width + x
                        let r = pixels[idx][0], g = pixels[idx][1], b = pixels[idx][2]
                        let luma = 0.299 * r + 0.587 * g + 0.114 * b
                        let bin = Int(max(0, min(255, luma)))
                        let newLuma = cdf[bin]
                        if luma > 0.001 {
                            let scale = newLuma / luma
                            pixels[idx][0] = max(0, min(255, r * scale))
                            pixels[idx][1] = max(0, min(255, g * scale))
                            pixels[idx][2] = max(0, min(255, b * scale))
                        }
                    }
                }
            }
        }
    }

    private func applySWAHE(_ pixels: inout [[Float]], width: Int, height: Int, windowSize: Int) {
        let halfWindow = windowSize / 2
        var result = pixels

        var lumaBins = [Int](repeating: 0, count: width * height)
        for i in 0..<pixels.count {
            lumaBins[i] = Int(max(0, min(255, 0.299 * pixels[i][0] + 0.587 * pixels[i][1] + 0.114 * pixels[i][2])))
        }

        for y in 0..<height {
            let startY = max(0, y - halfWindow), endY = min(height, y + halfWindow + 1)
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
                    let addX = x + halfWindow, removeX = x - halfWindow - 1
                    if addX < width {
                        for wy in startY..<endY { histogram[lumaBins[wy * width + addX]] += 1; windowPixels += 1 }
                    }
                    if removeX >= 0 {
                        for wy in startY..<endY { histogram[lumaBins[wy * width + removeX]] -= 1; windowPixels -= 1 }
                    }
                }

                let idx = y * width + x
                let bin = lumaBins[idx]
                var cumulative = 0
                for i in 0...bin { cumulative += histogram[i] }
                let newLuma = Float(cumulative) / Float(windowPixels) * 255.0

                let r = pixels[idx][0], g = pixels[idx][1], b = pixels[idx][2]
                let luma = 0.299 * r + 0.587 * g + 0.114 * b
                if luma > 0.001 {
                    let scale = newLuma / luma
                    result[idx][0] = max(0, min(255, r * scale))
                    result[idx][1] = max(0, min(255, g * scale))
                    result[idx][2] = max(0, min(255, b * scale))
                }
            }
        }
        pixels = result
    }

    private func applyOrderedDither(_ pixels: inout [[Float]], width: Int, height: Int, ditherType: String, amount: Double) {
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

    // MARK: - Image Filters

    private func applyImageFilter(_ pixels: inout [[Float]], width: Int, height: Int, filter: String) {
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
            applyConvolution(&pixels, width: width, height: height, kernel: lowpassKernel)
        case "Sharpen":
            applyConvolution(&pixels, width: width, height: height, kernel: sharpenKernel)
        case "Emboss":
            applyConvolution(&pixels, width: width, height: height, kernel: embossKernel)
        case "Edge":
            applyEdgeFilter(&pixels, width: width, height: height)
        default:
            break
        }
    }

    private func applyConvolution(_ pixels: inout [[Float]], width: Int, height: Int, kernel: [[Float]]) {
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

    private func applyEdgeFilter(_ pixels: inout [[Float]], width: Int, height: Int) {
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
                result[idx][0] = max(0, min(255, (pixels[idx][0] + edgeR) * 0.5))
                result[idx][1] = max(0, min(255, (pixels[idx][1] + edgeG) * 0.5))
                result[idx][2] = max(0, min(255, (pixels[idx][2] + edgeB) * 0.5))
            }
        }

        pixels = result
    }

    // MARK: - PCX Format Export

    private func createPCXData(resultPixels: [UInt8], width: Int, height: Int, palette: [[UInt8]], bitsPerPixel: Int) -> Data {
        var pcx = Data()

        // PCX Header (128 bytes)
        pcx.append(0x0A)  // Manufacturer (ZSoft)
        pcx.append(0x05)  // Version (3.0)
        pcx.append(0x01)  // Encoding (RLE)

        // Bits per pixel per plane
        let bpp: UInt8 = bitsPerPixel == 8 ? 8 : 1
        pcx.append(bpp)

        // Window: Xmin, Ymin, Xmax, Ymax (little-endian words)
        pcx.append(0x00); pcx.append(0x00)  // Xmin = 0
        pcx.append(0x00); pcx.append(0x00)  // Ymin = 0
        pcx.append(UInt8((width - 1) & 0xFF)); pcx.append(UInt8((width - 1) >> 8))   // Xmax
        pcx.append(UInt8((height - 1) & 0xFF)); pcx.append(UInt8((height - 1) >> 8)) // Ymax

        // DPI (72x72)
        pcx.append(72); pcx.append(0)  // HDpi
        pcx.append(72); pcx.append(0)  // VDpi

        // 16-color palette (48 bytes) - for CGA/EGA modes
        for i in 0..<16 {
            if i < palette.count {
                pcx.append(palette[i][0])
                pcx.append(palette[i][1])
                pcx.append(palette[i][2])
            } else {
                pcx.append(0); pcx.append(0); pcx.append(0)
            }
        }

        pcx.append(0x00)  // Reserved

        // Number of planes
        let numPlanes: UInt8
        switch bitsPerPixel {
        case 2: numPlanes = 1   // CGA: 1 plane, 2 bits/pixel (packed)
        case 4: numPlanes = 4   // EGA: 4 planes, 1 bit/pixel each
        case 8: numPlanes = 1   // VGA: 1 plane, 8 bits/pixel
        default: numPlanes = 1
        }
        pcx.append(numPlanes)

        // Bytes per line (must be even)
        let bytesPerLine: Int
        if bitsPerPixel == 8 {
            bytesPerLine = (width + 1) & ~1  // Even width
        } else if bitsPerPixel == 4 {
            bytesPerLine = ((width + 7) / 8 + 1) & ~1  // EGA bitplane
        } else {
            bytesPerLine = ((width * bitsPerPixel + 7) / 8 + 1) & ~1
        }
        pcx.append(UInt8(bytesPerLine & 0xFF))
        pcx.append(UInt8(bytesPerLine >> 8))

        pcx.append(0x01); pcx.append(0x00)  // Palette type (color)
        pcx.append(UInt8(width & 0xFF)); pcx.append(UInt8(width >> 8))   // HScreen size
        pcx.append(UInt8(height & 0xFF)); pcx.append(UInt8(height >> 8)) // VScreen size

        // Filler (54 bytes to reach 128)
        for _ in 0..<54 {
            pcx.append(0x00)
        }

        // RLE encode image data
        if bitsPerPixel == 8 {
            // VGA 256-color mode: simple 8-bit indexed
            for y in 0..<height {
                var x = 0
                while x < width {
                    let idx = (y * width + x) * 3
                    // Find palette index for this pixel
                    let r = resultPixels[idx]
                    let g = resultPixels[idx + 1]
                    let b = resultPixels[idx + 2]
                    var palIdx: UInt8 = 0
                    for (i, c) in palette.enumerated() {
                        if c[0] == r && c[1] == g && c[2] == b {
                            palIdx = UInt8(i)
                            break
                        }
                    }

                    // Count run
                    var runLen = 1
                    while x + runLen < width && runLen < 63 {
                        let nextIdx = (y * width + x + runLen) * 3
                        let nr = resultPixels[nextIdx]
                        let ng = resultPixels[nextIdx + 1]
                        let nb = resultPixels[nextIdx + 2]
                        var nextPalIdx: UInt8 = 0
                        for (i, c) in palette.enumerated() {
                            if c[0] == nr && c[1] == ng && c[2] == nb {
                                nextPalIdx = UInt8(i)
                                break
                            }
                        }
                        if nextPalIdx != palIdx { break }
                        runLen += 1
                    }

                    // Write RLE
                    if runLen > 1 || palIdx >= 0xC0 {
                        pcx.append(UInt8(0xC0 | runLen))
                    }
                    pcx.append(palIdx)
                    x += runLen
                }
                // Pad to even bytes per line
                if width < bytesPerLine {
                    for _ in width..<bytesPerLine {
                        pcx.append(0x00)
                    }
                }
            }

            // VGA palette (768 bytes at end)
            pcx.append(0x0C)  // VGA palette marker
            for color in palette {
                pcx.append(color[0])
                pcx.append(color[1])
                pcx.append(color[2])
            }
            // Pad to 256 colors
            for _ in palette.count..<256 {
                pcx.append(0); pcx.append(0); pcx.append(0)
            }
        } else {
            // CGA/EGA: Write as packed pixels or bitplanes
            for y in 0..<height {
                if bitsPerPixel == 4 {
                    // EGA: 4 bitplanes
                    for plane in 0..<4 {
                        var lineData = [UInt8]()
                        for byteX in 0..<((width + 7) / 8) {
                            var byte: UInt8 = 0
                            for bit in 0..<8 {
                                let x = byteX * 8 + bit
                                if x < width {
                                    let idx = (y * width + x) * 3
                                    let r = resultPixels[idx]
                                    let g = resultPixels[idx + 1]
                                    let b = resultPixels[idx + 2]
                                    var palIdx = 0
                                    for (i, c) in palette.enumerated() {
                                        if c[0] == r && c[1] == g && c[2] == b {
                                            palIdx = i
                                            break
                                        }
                                    }
                                    if (palIdx >> plane) & 1 == 1 {
                                        byte |= UInt8(0x80 >> bit)
                                    }
                                }
                            }
                            lineData.append(byte)
                        }
                        // Pad to bytesPerLine
                        while lineData.count < bytesPerLine {
                            lineData.append(0)
                        }
                        // RLE encode this plane's line
                        var x = 0
                        while x < lineData.count {
                            let val = lineData[x]
                            var runLen = 1
                            while x + runLen < lineData.count && runLen < 63 && lineData[x + runLen] == val {
                                runLen += 1
                            }
                            if runLen > 1 || val >= 0xC0 {
                                pcx.append(UInt8(0xC0 | runLen))
                            }
                            pcx.append(val)
                            x += runLen
                        }
                    }
                } else {
                    // CGA: packed 2-bit pixels
                    var lineData = [UInt8]()
                    for byteX in 0..<((width * 2 + 7) / 8) {
                        var byte: UInt8 = 0
                        for pix in 0..<4 {
                            let x = byteX * 4 + pix
                            if x < width {
                                let idx = (y * width + x) * 3
                                let r = resultPixels[idx]
                                let g = resultPixels[idx + 1]
                                let b = resultPixels[idx + 2]
                                var palIdx: UInt8 = 0
                                for (i, c) in palette.enumerated() {
                                    if c[0] == r && c[1] == g && c[2] == b {
                                        palIdx = UInt8(i)
                                        break
                                    }
                                }
                                byte |= (palIdx & 0x03) << (6 - pix * 2)
                            }
                        }
                        lineData.append(byte)
                    }
                    while lineData.count < bytesPerLine {
                        lineData.append(0)
                    }
                    // RLE encode
                    var x = 0
                    while x < lineData.count {
                        let val = lineData[x]
                        var runLen = 1
                        while x + runLen < lineData.count && runLen < 63 && lineData[x + runLen] == val {
                            runLen += 1
                        }
                        if runLen > 1 || val >= 0xC0 {
                            pcx.append(UInt8(0xC0 | runLen))
                        }
                        pcx.append(val)
                        x += runLen
                    }
                }
            }
        }

        return pcx
    }

    // MARK: - ANSI Format Export

    private func createANSIData(screenData: Data, cols: Int, rows: Int) -> Data {
        var ansi = Data()

        // ANSI color codes mapping from CGA attribute to ANSI
        // CGA colors: 0=black, 1=blue, 2=green, 3=cyan, 4=red, 5=magenta, 6=brown, 7=white
        //             8=gray, 9=lt blue, 10=lt green, 11=lt cyan, 12=lt red, 13=lt magenta, 14=yellow, 15=white
        // ANSI foreground: 30-37 (dark), 90-97 (bright)
        // ANSI background: 40-47

        let ansiFg: [Int] = [30, 34, 32, 36, 31, 35, 33, 37, 90, 94, 92, 96, 91, 95, 93, 97]
        let ansiBg: [Int] = [40, 44, 42, 46, 41, 45, 43, 47]

        // CP437 to Unicode mapping for common block characters
        func cp437ToUtf8(_ char: UInt8) -> [UInt8] {
            switch char {
            case 176: return [0xE2, 0x96, 0x91]  // ░ Light shade
            case 177: return [0xE2, 0x96, 0x92]  // ▒ Medium shade
            case 178: return [0xE2, 0x96, 0x93]  // ▓ Dark shade
            case 219: return [0xE2, 0x96, 0x88]  // █ Full block
            case 220: return [0xE2, 0x96, 0x84]  // ▄ Lower half
            case 221: return [0xE2, 0x96, 0x8C]  // ▌ Left half
            case 222: return [0xE2, 0x96, 0x90]  // ▐ Right half
            case 223: return [0xE2, 0x96, 0x80]  // ▀ Upper half
            case 32: return [0x20]               // Space
            default:
                if char >= 32 && char < 127 {
                    return [char]  // ASCII printable
                } else {
                    return [0x20]  // Replace unprintable with space
                }
            }
        }

        var lastFg = -1
        var lastBg = -1

        for row in 0..<rows {
            for col in 0..<cols {
                let addr = (row * cols + col) * 2
                let char = screenData[addr]
                let attr = screenData[addr + 1]

                let fg = Int(attr & 0x0F)
                let bg = Int((attr >> 4) & 0x07)

                // Output ANSI escape sequence if colors changed
                if fg != lastFg || bg != lastBg {
                    let esc = "\u{1B}[\(ansiFg[fg]);\(ansiBg[bg])m"
                    ansi.append(contentsOf: esc.utf8)
                    lastFg = fg
                    lastBg = bg
                }

                // Output character
                let utf8Bytes = cp437ToUtf8(char)
                ansi.append(contentsOf: utf8Bytes)
            }
            // Newline
            ansi.append(contentsOf: "\u{1B}[0m\r\n".utf8)
            lastFg = -1
            lastBg = -1
        }

        // Reset at end
        ansi.append(contentsOf: "\u{1B}[0m".utf8)

        return ansi
    }
}
