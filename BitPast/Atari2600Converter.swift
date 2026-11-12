import Foundation
import AppKit

/// Atari 2600 (VCS, 1977). The 2600 has no screen memory: a program redraws every line
/// as the beam passes. The playfield is 40 blocks across, so a picture is 40 blocks by
/// 192 lines, each line with two colours (playfield and background) from the 128 NTSC colours.
///
/// The result is a 4 KB cartridge (.bin) whose program writes each line's playfield and colours,
/// rewriting the playfield halfway across the line so the left and right halves differ.
nonisolated class Atari2600Converter: RetroMachine {
    var name: String = "Atari 2600"

    static let columns = 40, rows = 192

    var options: [ConversionOption] = [
        ConversionOption(label: "Dither", key: "dither", values: ["None", "Floyd-Steinberg", "Atkinson"],
                         selectedValue: "Floyd-Steinberg"),
        ConversionOption(label: "Dither Amount", key: "dither_amount", range: 0.0...1.0, defaultValue: 0.5),
        ConversionOption(label: "Color Match", key: "color_match", values: ["Perceptive", "Euclidean", "Luma"],
                         selectedValue: "Perceptive"),
        ConversionOption(label: "Contrast", key: "contrast", values: ["None", "HE"], selectedValue: "None"),
        ConversionOption(label: "Saturation", key: "saturation", range: 0.5...2.0, defaultValue: 1.0),
        ConversionOption(label: "Gamma", key: "gamma", range: 0.5...2.0, defaultValue: 1.0),
    ] + ImageFraming.options

    /// The TIA's NTSC colours as Stella shows them, indexed by the colour register value / 2
    /// (hue × 8 + luminance).
    static let palette: [[UInt8]] = [
        0x000000, 0x4A4A4A, 0x6F6F6F, 0x8E8E8E, 0xAAAAAA, 0xC0C0C0, 0xD6D6D6, 0xECECEC,
        0x484800, 0x69690F, 0x86861D, 0xA2A22A, 0xBBBB35, 0xD2D240, 0xE8E84A, 0xFCFC54,
        0x7C2C00, 0x904811, 0xA26221, 0xB47A30, 0xC3903D, 0xD2A44A, 0xDFB755, 0xECC860,
        0x901C00, 0xA33915, 0xB55328, 0xC66C3A, 0xD5824A, 0xE39759, 0xF0AA67, 0xFCBC74,
        0x940000, 0xA71A1A, 0xB83232, 0xC84848, 0xD65C5C, 0xE46F6F, 0xF08080, 0xFC9090,
        0x840064, 0x97197A, 0xA8308F, 0xB846A2, 0xC659B3, 0xD46CC3, 0xE07CD2, 0xEC8CE0,
        0x500084, 0x68199A, 0x7D30AD, 0x9246C0, 0xA459D0, 0xB56CE0, 0xC57CEE, 0xD48CFC,
        0x140090, 0x331AA3, 0x4E32B5, 0x6848C6, 0x7F5CD5, 0x956FE3, 0xA980F0, 0xBC90FC,
        0x000094, 0x181AA7, 0x2D32B8, 0x4248C8, 0x545CD6, 0x656FE4, 0x7580F0, 0x8490FC,
        0x001C88, 0x183B9D, 0x2D57B0, 0x4272C2, 0x548AD2, 0x65A0E1, 0x75B5EF, 0x84C8FC,
        0x003064, 0x185080, 0x2D6D98, 0x4288B0, 0x54A0C5, 0x65B7D9, 0x75CCEB, 0x84E0FC,
        0x004030, 0x18624E, 0x2D8169, 0x429E82, 0x54B899, 0x65D1AE, 0x75E7C2, 0x84FCD4,
        0x004400, 0x1A661A, 0x328432, 0x48A048, 0x5CBA5C, 0x6FD26F, 0x80E880, 0x90FC90,
        0x143C00, 0x355F18, 0x527E2D, 0x6E9C42, 0x87B754, 0x9ED065, 0xB4E775, 0xC8FC84,
        0x303800, 0x505916, 0x6D7629, 0x88923C, 0xA0AB4F, 0xB7C25F, 0xCCD86E, 0xE0EC7C,
        0x482C00, 0x694D14, 0x866A26, 0xA28638, 0xBB9F47, 0xD2B656, 0xE8CC63, 0xFCE070,
    ].map { [UInt8($0 >> 16), UInt8($0 >> 8 & 0xFF), UInt8($0 & 0xFF)] }

    /// One picture: for every line, which blocks show the playfield colour, and the two colours
    /// as indices into `palette`.
    struct Screen: Equatable {
        var lit: [[Bool]]                   // rows × 40
        var playfield: [Int], background: [Int]
    }

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        try validateSourceImage(sourceImage)
        let opts = settings ?? options
        func value(_ key: String, _ fallback: String) -> String { opts.first { $0.key == key }?.selectedValue ?? fallback }
        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "Atari2600Converter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }
        let width = Self.columns, height = Self.rows

        try Task.checkCancellation()
        var pixels = AmigaFamilyImageOps.scaleImage(cgImage, toWidth: width, height: height, framing: ImageFraming(opts))
        let saturation = Double(value("saturation", "1.0")) ?? 1.0
        if saturation != 1.0 {
            AmigaFamilyImageOps.applySaturation(&pixels, width: width, height: height, saturation: saturation)
        }
        let gamma = Double(value("gamma", "1.0")) ?? 1.0
        if gamma != 1.0 { AmigaFamilyImageOps.applyGamma(&pixels, width: width, height: height, gamma: gamma) }
        if value("contrast", "None") == "HE" {
            var unit = pixels.map { $0.map { $0 / 255 } }
            CommodoreFamilyImageOps.applyHistogramEqualization(&unit, width: width, height: height)
            pixels = unit.map { $0.map { $0 * 255 } }
        }

        try Task.checkCancellation()
        let screen = Self.reduce(pixels, dither: value("dither", "Floyd-Steinberg"),
                                 amount: Float(Double(value("dither_amount", "0.5")) ?? 0.5),
                                 match: value("color_match", "Perceptive"))
        let rom = Atari2600ROM.build(screen)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("atari2600_\(UUID().uuidString.prefix(8)).bin")
        try rom.write(to: url)
        return ConversionResult(previewImage: Self.preview(screen), fileAssets: [url], palettes: [], pixelIndices: [],
                                imageWidth: 160, imageHeight: height)
    }

    static func distance(_ p: [Float], _ c: [UInt8], _ method: String) -> Float {
        let dr = p[0] - Float(c[0]), dg = p[1] - Float(c[1]), db = p[2] - Float(c[2])
        switch method {
        case "Euclidean": return dr * dr + dg * dg + db * db
        case "Luma":
            let dl = 0.299 * dr + 0.587 * dg + 0.114 * db
            return dl * dl * 4 + (dr * dr + dg * dg + db * db) * 0.1
        default:   // "redmean" weighting
            let rmean = (p[0] + Float(c[0])) / 2
            return (2 + rmean / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rmean) / 256) * db * db
        }
    }

    /// Picks two colours for each line and decides each block, line by line from the top,
    /// so error diffusion can carry what one line could not show into the next.
    static func reduce(_ input: [[Float]], dither: String, amount: Float, match: String) -> Screen {
        let width = columns, height = rows
        var work = input
        var screen = Screen(lit: [], playfield: [], background: [])
        for y in 0..<height {
            let line = (0..<width).map { work[y * width + $0].map { min(255, max(0, $0)) } }
            // Candidates: the colours nearest to the line's blocks, then the best pair of them
            var votes = [Int: Int]()
            for p in line {
                let nearest = palette.indices.min { distance(p, palette[$0], match) < distance(p, palette[$1], match) }!
                votes[nearest, default: 0] += 1
            }
            // (ties go to the lower index: a dictionary's own order changes from launch to launch)
            var candidates = votes.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.prefix(10).map(\.key)
            let mean = (0..<3).map { c in line.reduce(0) { $0 + $1[c] } / Float(width) }
            let meanNearest = palette.indices.min { distance(mean, palette[$0], match) < distance(mean, palette[$1], match) }!
            if !candidates.contains(meanNearest) { candidates.append(meanNearest) }
            var best = (candidates[0], candidates[0]), bestError = Float.greatestFiniteMagnitude
            for i in candidates.indices {
                for j in i..<candidates.count {
                    let a = palette[candidates[i]], b = palette[candidates[j]]
                    let error = line.reduce(Float(0)) { $0 + min(distance($1, a, match), distance($1, b, match)) }
                    if error < bestError { bestError = error; best = (candidates[i], candidates[j]) }
                }
            }
            // The more common colour becomes the background
            let a = palette[best.0], b = palette[best.1]
            var lit = [Bool](repeating: false, count: width)
            for x in 0..<width {
                let p = work[y * width + x].map { min(255, max(0, $0)) }
                let useA = distance(p, a, match) <= distance(p, b, match)
                lit[x] = useA
                let chosen = useA ? a : b
                guard dither != "None" else { continue }
                let err = (0..<3).map { (p[$0] - Float(chosen[$0])) * amount }
                func spread(_ dx: Int, _ dy: Int, _ w: Float) {
                    let nx = x + dx, ny = y + dy
                    guard nx >= 0, nx < width, ny < height else { return }
                    for c in 0..<3 { work[ny * width + nx][c] += err[c] * w }
                }
                if dither == "Atkinson" {
                    for (dx, dy) in [(1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)] { spread(dx, dy, 1 / 8) }
                } else {
                    spread(1, 0, 7 / 16); spread(-1, 1, 3 / 16); spread(0, 1, 5 / 16); spread(1, 1, 1 / 16)
                }
            }
            if lit.filter({ $0 }).count > width / 2 {
                screen.lit.append(lit.map { !$0 }); screen.playfield.append(best.1); screen.background.append(best.0)
            } else {
                screen.lit.append(lit); screen.playfield.append(best.0); screen.background.append(best.1)
            }
        }
        return screen
    }

    /// The picture as the TV shows it: blocks 4 colour clocks wide, drawn 16×2 pixels.
    static func preview(_ screen: Screen) -> NSImage {
        let width = columns * 16, height = rows * 2
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            let row = y / 2
            for x in 0..<width {
                let c = palette[screen.lit[row][x / 16] ? screen.playfield[row] : screen.background[row]]
                let o = (y * width + x) * 4
                bytes[o] = c[0]; bytes[o + 1] = c[1]; bytes[o + 2] = c[2]
            }
        }
        let ctx = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: width, height: height))
    }
}

/// The 4 KB cartridge. Code at $F000; eight tables of line data, one per page from $F100,
/// indexed by Y = 192 (top line) down to 1; reset vector at $FFFC.
///
/// Each line, after WSYNC (cycle counts from the start of the line):
///   3  COLUBK      background (loaded into X on the line before)
///  10  COLUPF      playfield colour
///  17  PF0, 24 PF1, 31 PF2      left half, before each part is drawn
///  38  PF0, 45 PF1, 52 PF2      right half, after the left part is drawn and before the right one
/// then X = next line's background, DEY, BNE: 61 cycles of the 76.
nonisolated enum Atari2600ROM {
    // TIA registers
    static let VSYNC: UInt8 = 0x00, VBLANK: UInt8 = 0x01, WSYNC: UInt8 = 0x02
    static let COLUPF: UInt8 = 0x08, COLUBK: UInt8 = 0x09, PF0: UInt8 = 0x0D, PF1: UInt8 = 0x0E, PF2: UInt8 = 0x0F

    static let tableBase = 0xF100
    enum Table: Int, CaseIterable { case colupf, pf0Left, pf1Left, pf2Left, pf0Right, pf1Right, pf2Right, nextBackground }
    static func address(_ table: Table) -> Int { tableBase + table.rawValue * 0x100 }

    /// The colour register value for palette index `i` (hue × 8 + luminance).
    static func colour(_ i: Int) -> UInt8 { UInt8(i << 1) }

    /// The six playfield bytes for 40 blocks: PF0 shows bits 4–7, PF1 bits 7–0, PF2 bits 0–7, left to right.
    static func playfieldBytes(_ lit: [Bool]) -> [UInt8] {
        func half(_ b: ArraySlice<Bool>) -> [UInt8] {
            let s = Array(b)
            var pf0: UInt8 = 0, pf1: UInt8 = 0, pf2: UInt8 = 0
            for i in 0..<4 where s[i] { pf0 |= 0x10 << i }
            for i in 0..<8 where s[4 + i] { pf1 |= 0x80 >> i }
            for i in 0..<8 where s[12 + i] { pf2 |= 1 << i }
            return [pf0, pf1, pf2]
        }
        return half(lit[0..<20]) + half(lit[20..<40])
    }

    static func build(_ screen: Atari2600Converter.Screen) -> Data {
        var rom = [UInt8](repeating: 0xFF, count: 0x1000)
        func put(_ address: Int, _ value: UInt8) { rom[address - 0xF000] = value }

        let rows = Atari2600Converter.rows
        for row in 0..<rows {
            let y = rows - row                       // Y for this line
            let pf = playfieldBytes(screen.lit[row])
            put(address(.colupf) + y, colour(screen.playfield[row]))
            for (i, t) in [Table.pf0Left, .pf1Left, .pf2Left, .pf0Right, .pf1Right, .pf2Right].enumerated() {
                put(address(t) + y, pf[i])
            }
            // X is loaded with the background of the line after this one (Y - 1): entry Y holds line Y - 1's
            put(address(.nextBackground) + y + 1, colour(screen.background[row]))
        }
        put(address(.nextBackground) + 1, 0)

        let lo = { (a: Int) in UInt8(a & 0xFF) }, hi = { (a: Int) in UInt8(a >> 8) }
        var code: [UInt8] = []
        let start = 0xF000
        func here() -> Int { start + code.count }
        func zp(_ op: UInt8, _ reg: UInt8) { code += [op, reg] }
        func abs(_ op: UInt8, _ a: Int) { code += [op, lo(a), hi(a)] }
        func branch(_ op: UInt8, to target: Int) { code += [op, UInt8(bitPattern: Int8(target - (here() + 2)))] }

        // Clear the TIA and RAM, set the stack
        code += [0x78, 0xD8, 0xA2, 0x00, 0x8A]                       // sei / cld / ldx #0 / txa
        let clear = here(); code += [0x95, 0x00, 0xE8]; branch(0xD0, to: clear)   // sta 0,x / inx / bne
        code += [0xA2, 0xFF, 0x9A]                                   // ldx #$FF / txs
        let frame = here()
        code += [0xA9, 0x02]; zp(0x85, VBLANK); zp(0x85, VSYNC)      // lda #2 / VBLANK and VSYNC on
        for _ in 0..<3 { zp(0x85, WSYNC) }                           // three lines of sync
        code += [0xA9, 0x00]; zp(0x85, VSYNC)
        code += [0xA2, 37]                                           // 37 lines of vertical blank
        let vblank = here(); zp(0x85, WSYNC); code += [0xCA]; branch(0xD0, to: vblank)
        code += [0xA9, 0x00]; zp(0x85, VBLANK)
        code += [0xA0, UInt8(rows)]                                  // ldy #192
        abs(0xAE, address(.nextBackground) + rows + 1)               // ldx: the top line's background
        let line = here()
        zp(0x85, WSYNC)
        zp(0x86, COLUBK)                                             // stx COLUBK
        abs(0xB9, address(.colupf)); zp(0x85, COLUPF)
        abs(0xB9, address(.pf0Left)); zp(0x85, PF0)
        abs(0xB9, address(.pf1Left)); zp(0x85, PF1)
        abs(0xB9, address(.pf2Left)); zp(0x85, PF2)
        abs(0xB9, address(.pf0Right)); zp(0x85, PF0)
        abs(0xB9, address(.pf1Right)); zp(0x85, PF1)
        abs(0xB9, address(.pf2Right)); zp(0x85, PF2)
        abs(0xBE, address(.nextBackground))                          // ldx next,y
        code += [0x88]; branch(0xD0, to: line)                       // dey / bne
        zp(0x85, WSYNC)
        code += [0xA9, 0x00]; zp(0x85, PF0); zp(0x85, PF1); zp(0x85, PF2); zp(0x85, COLUBK)
        code += [0xA9, 0x02]; zp(0x85, VBLANK)
        code += [0xA2, 29]                                           // 29 lines of overscan: 262 in all
        let overscan = here(); zp(0x85, WSYNC); code += [0xCA]; branch(0xD0, to: overscan)
        abs(0x4C, frame)
        precondition(code.count <= 0x100)
        for (i, b) in code.enumerated() { rom[i] = b }

        put(0xFFFC, lo(start)); put(0xFFFD, hi(start))               // reset
        put(0xFFFE, lo(start)); put(0xFFFF, hi(start))               // IRQ/BRK
        return Data(rom)
    }
}
