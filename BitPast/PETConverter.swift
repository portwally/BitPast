import Foundation
import AppKit

/// Commodore PET (1977). The PET has no graphics mode: it shows 25 lines of characters,
/// green or white on black. Its character set, though, has every combination of the four
/// quarters of a character cell, so a picture can be drawn in quarter blocks: 80×50 on the
/// 40-column PETs and 160×50 on the 80-column 8032.
///
/// The result is a program (.prg) that loads at $0401 like any PET BASIC program; RUN copies
/// the characters to screen memory at $8000 and keeps the picture on screen.
nonisolated class PETConverter: RetroMachine {
    var name: String = "PET"

    static let mode40 = "40 Columns (80×50 blocks)"
    static let mode80 = "80 Columns (160×50 blocks)"

    var options: [ConversionOption] = [
        ConversionOption(label: "Mode", key: "mode", values: [mode40, mode80], selectedValue: mode40),
        ConversionOption(label: "Monitor", key: "monitor", values: ["Green", "White"], selectedValue: "Green"),
        ConversionOption(label: "Dither", key: "dither",
                         values: ["None", "Floyd-Steinberg", "Atkinson", "Bayer 4x4", "Bayer 8x8"],
                         selectedValue: "None"),       // at 80×50 blocks, plain shapes read best
        ConversionOption(label: "Threshold", key: "threshold", range: 0.2...0.8, defaultValue: 0.5),
        ConversionOption(label: "Contrast", key: "contrast", values: ["None", "HE"], selectedValue: "None"),
        ConversionOption(label: "Filter", key: "filter", values: ["None", "Lowpass", "Sharpen", "Emboss", "Edge"],
                         selectedValue: "None"),
        ConversionOption(label: "Gamma", key: "gamma", range: 0.5...2.0, defaultValue: 1.0),
        ConversionOption(label: "Invert", key: "invert", values: ["Off", "On"], selectedValue: "Off"),
    ] + ImageFraming.options

    /// Screen codes for the 16 ways to fill a character's four quarters, indexed by
    /// top-left 8, top-right 4, bottom-left 2, bottom-right 1. Codes from 128 up are the
    /// reversed (inverse) characters.
    static let quarterCodes: [UInt8] = [
        32,    // 0000  space
        108,   // 0001  ▗ bottom-right
        123,   // 0010  ▖ bottom-left
        98,    // 0011  ▄ lower half
        124,   // 0100  ▝ top-right
        225,   // 0101  ▐ right half (reversed ▌)
        255,   // 0110  ▞ (reversed ▚)
        254,   // 0111  all but top-left (reversed ▘)
        126,   // 1000  ▘ top-left
        127,   // 1001  ▚
        97,    // 1010  ▌ left half
        252,   // 1011  all but top-right (reversed ▝)
        226,   // 1100  ▀ upper half (reversed ▄)
        251,   // 1101  all but bottom-left (reversed ▖)
        236,   // 1110  all but bottom-right (reversed ▗)
        160,   // 1111  full block (reversed space)
    ]

    static let phosphor: [String: [UInt8]] = ["Green": [0x41, 0xFF, 0x50], "White": [0xE6, 0xEA, 0xF0]]

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        try validateSourceImage(sourceImage)
        let opts = settings ?? options
        func value(_ key: String, _ fallback: String) -> String { opts.first { $0.key == key }?.selectedValue ?? fallback }
        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "PETConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }

        let columns = value("mode", Self.mode40) == Self.mode80 ? 80 : 40
        let width = columns * 2, height = 50          // quarter blocks
        let dither = value("dither", "None")
        let threshold = Float(Double(value("threshold", "0.5")) ?? 0.5)
        let gamma = Double(value("gamma", "1.0")) ?? 1.0
        let invert = value("invert", "Off") == "On"

        try Task.checkCancellation()
        // Blocks fill the 4:3 screen, so the framing works on the block grid directly
        var pixels = AmigaFamilyImageOps.scaleImage(cgImage, toWidth: width, height: height, framing: ImageFraming(opts))
            .map { $0.map { $0 / 255 } }
        if value("filter", "None") != "None" {
            CommodoreFamilyImageOps.applyImageFilter(&pixels, width: width, height: height, filter: value("filter", "None"))
        }
        if value("contrast", "None") == "HE" {
            CommodoreFamilyImageOps.applyHistogramEqualization(&pixels, width: width, height: height)
        }
        var luma = pixels.map { p -> Float in
            var l = 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]
            if gamma != 1.0 { l = powf(max(0, l), Float(1 / gamma)) }
            return invert ? 1 - l : l
        }

        try Task.checkCancellation()
        let lit = Self.threshold(&luma, width: width, height: height, threshold: threshold, dither: dither)

        // Four blocks make one character
        var screen = [UInt8](repeating: 32, count: columns * 25)
        for row in 0..<25 {
            for col in 0..<columns {
                func on(_ dx: Int, _ dy: Int) -> Int { lit[(row * 2 + dy) * width + col * 2 + dx] ? 1 : 0 }
                screen[row * columns + col] = Self.quarterCodes[on(0, 0) << 3 | on(1, 0) << 2 | on(0, 1) << 1 | on(1, 1)]
            }
        }

        let colour = Self.phosphor[value("monitor", "Green")] ?? Self.phosphor["Green"]!
        let preview = Self.preview(screen: screen, columns: columns, colour: colour)
        let program = PETProgram.build(screen: screen, columns: columns)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pet_\(UUID().uuidString.prefix(8)).prg")
        try program.write(to: url)
        return ConversionResult(previewImage: preview, fileAssets: [url], palettes: [], pixelIndices: [],
                                imageWidth: columns * 8, imageHeight: 200)
    }

    /// Decides which blocks are lit, with error diffusion or an ordered pattern.
    static func threshold(_ luma: inout [Float], width: Int, height: Int, threshold: Float, dither: String) -> [Bool] {
        var lit = [Bool](repeating: false, count: width * height)
        let bayer4: [[Float]] = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        let bayer8: [[Float]] = [[0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
                                 [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
                                 [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
                                 [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]]
        for y in 0..<height {
            for x in 0..<width {
                let i = y * width + x
                let v = luma[i]
                switch dither {
                case "Bayer 4x4", "Bayer 8x8":
                    let m = dither == "Bayer 4x4" ? bayer4 : bayer8
                    let n = Float(m.count * m.count)
                    lit[i] = v > threshold + (m[y % m.count][x % m.count] + 0.5) / n - 0.5
                default:
                    lit[i] = v > threshold
                    guard dither != "None" else { continue }
                    let err = v - (lit[i] ? 1 : 0)
                    func spread(_ dx: Int, _ dy: Int, _ w: Float) {
                        let nx = x + dx, ny = y + dy
                        if nx >= 0, nx < width, ny < height { luma[ny * width + nx] += err * w }
                    }
                    if dither == "Atkinson" {
                        for (dx, dy) in [(1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)] { spread(dx, dy, 1 / 8) }
                    } else {
                        spread(1, 0, 7 / 16); spread(-1, 1, 3 / 16); spread(0, 1, 5 / 16); spread(1, 1, 1 / 16)
                    }
                }
            }
        }
        return lit
    }

    /// The screen as the PET shows it: each character 8×8 pixels, drawn twice as tall
    /// (40 columns: also twice as wide) so the preview fills a 4:3 shape.
    static func preview(screen: [UInt8], columns: Int, colour: [UInt8]) -> NSImage {
        let sx = columns == 40 ? 2 : 1
        let width = columns * 8 * sx, height = 400
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<25 {
            for col in 0..<columns {
                let index = quarterCodes.firstIndex(of: screen[row * columns + col]) ?? 0
                for py in 0..<16 {
                    for px in 0..<(8 * sx) {
                        let quarter = (py < 8 ? 0 : 2) + (px < 4 * sx ? 0 : 1)        // TL, TR, BL, BR
                        let on = index & (8 >> quarter) != 0
                        let o = ((row * 16 + py) * width + col * 8 * sx + px) * 4
                        if on { bytes[o] = colour[0]; bytes[o + 1] = colour[1]; bytes[o + 2] = colour[2] }
                        bytes[o + 3] = 255
                    }
                }
            }
        }
        let ctx = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: width, height: height))
    }
}

/// The PET program: a BASIC line "10 SYS1037" and a short 6502 routine after it.
/// The routine switches to the graphics character set (POKE 59468,12), copies the
/// characters to screen memory at $8000 and then loops, so the picture stays until reset.
nonisolated enum PETProgram {
    static let loadAddress = 0x0401

    static func build(screen: [UInt8], columns: Int) -> Data {
        let pages = columns == 80 ? 8 : 4                  // 2,000 or 1,000 characters
        let start = loadAddress + 12                        // after the 12-byte BASIC line
        var out: [UInt8] = [UInt8(loadAddress & 0xFF), UInt8(loadAddress >> 8)]
        let nextLine = loadAddress + 10
        out += [UInt8(nextLine & 0xFF), UInt8(nextLine >> 8), 10, 0, 0x9E] + Array(String(start).utf8) + [0, 0, 0]

        var code: [UInt8] = [0xA9, 0x0C, 0x8D, 0x4C, 0xE8,   // lda #12 / sta $E84C   graphics characters
                             0xA2, 0x00]                     // ldx #0
        let dataAddress = start + code.count + pages * 6 + 3 + 3
        let loop = start + code.count
        for page in 0..<pages {
            let src = dataAddress + page * 256, dst = 0x8000 + page * 256
            code += [0xBD, UInt8(src & 0xFF), UInt8(src >> 8)]     // lda data+page,x
            code += [0x9D, UInt8(dst & 0xFF), UInt8(dst >> 8)]     // sta $8000+page,x
        }
        code += [0xE8, 0xD0, UInt8(bitPattern: Int8(loop - (start + code.count + 3)))]   // inx / bne loop (from after the bne)
        let forever = start + code.count
        code += [0x4C, UInt8(forever & 0xFF), UInt8(forever >> 8)]                        // jmp *
        precondition(start + code.count == dataAddress)

        var data = screen
        data += [UInt8](repeating: 32, count: pages * 256 - screen.count)
        return Data(out + code + data)
    }
}
