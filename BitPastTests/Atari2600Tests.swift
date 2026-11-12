import AppKit
import Foundation
import Testing
@testable import BitPast

/// The 2600 program is checked by running it with cycle counting: a TIA write's timing
/// within its line decides which part of the line it changes.
@Suite("Atari 2600 cartridge")
struct Atari2600Tests {

    struct Write { let register: UInt8, value: UInt8, cycle: Int }

    /// Runs two frames; returns the second frame's lines, each with its TIA writes.
    nonisolated static func run(_ rom: Data) -> [[Write]] {
        let bytes = [UInt8](rom)
        #expect(bytes.count == 4096)
        func read(_ a: Int) -> UInt8 { a >= 0xF000 ? bytes[a - 0xF000] : 0 }
        var pc = Int(read(0xFFFC)) | Int(read(0xFFFD)) << 8
        var a: UInt8 = 0, x: UInt8 = 0, y: UInt8 = 0, zero = false
        var lines: [[Write]] = [[]], cycle = 0, frames = 0
        var frameStart = 0

        func byte() -> UInt8 { defer { pc += 1 }; return read(pc) }
        func word() -> Int { let lo = Int(byte()); return lo | Int(byte()) << 8 }
        func tick(_ n: Int) {
            cycle += n
            while cycle >= 76 { cycle -= 76; lines.append([]) }
        }
        func write(_ reg: UInt8, _ value: UInt8) {
            if reg == 0x02 { lines.append([]); cycle = 0; return }       // WSYNC: wait for the next line
            lines[lines.count - 1].append(Write(register: reg, value: value, cycle: cycle))
            if reg == 0x00 && value & 2 != 0 { frames += 1; frameStart = lines.count - 1 }
        }
        func indexed(_ base: Int, _ index: UInt8) -> UInt8 {
            let address = base + Int(index)
            if address >> 8 != base >> 8 { tick(1) }                     // page crossing costs a cycle
            return read(address)
        }

        var firstFrameLines: [[Write]] = []
        for _ in 0..<200_000 {
            let op = byte()
            switch op {
            case 0x78, 0xD8: tick(2)                                      // sei, cld
            case 0xA2: x = byte(); zero = x == 0; tick(2)                 // ldx #
            case 0xA0: y = byte(); zero = y == 0; tick(2)                 // ldy #
            case 0xA9: a = byte(); zero = a == 0; tick(2)                 // lda #
            case 0x8A: a = x; zero = a == 0; tick(2)                      // txa
            case 0x9A: tick(2)                                            // txs
            case 0x95: let z = byte(); tick(4); if z &+ x < 0x80 { write(z &+ x, a) }   // sta zp,x (TIA part only)
            case 0x85: let z = byte(); tick(3); write(z, a)               // sta zp
            case 0x86: let z = byte(); tick(3); write(z, x)               // stx zp
            case 0xE8: x &+= 1; zero = x == 0; tick(2)                    // inx
            case 0xCA: x &-= 1; zero = x == 0; tick(2)                    // dex
            case 0x88: y &-= 1; zero = y == 0; tick(2)                    // dey
            case 0xAE: x = read(word()); zero = x == 0; tick(4)           // ldx abs
            case 0xB9: let base = word(); tick(4); a = indexed(base, y); zero = a == 0   // lda abs,y
            case 0xBE: let base = word(); tick(4); x = indexed(base, y); zero = x == 0   // ldx abs,y
            case 0xD0:                                                    // bne
                let e = Int(Int8(bitPattern: byte())); tick(2)
                if !zero { let target = pc + e; tick(target >> 8 != pc >> 8 ? 2 : 1); pc = target }
            case 0x4C: pc = word(); tick(3)                               // jmp
            default:
                Issue.record("unexpected opcode \(String(op, radix: 16)) at \(String(pc - 1, radix: 16))")
                return []
            }
            if frames == 2 && firstFrameLines.isEmpty { firstFrameLines = Array(lines[..<frameStart]) }
            if frames == 3 { return Array(lines[(firstFrameLines.count)..<frameStart]) }
        }
        Issue.record("the program did not draw three frames")
        return []
    }

    nonisolated static func sampleScreen() -> Atari2600Converter.Screen {
        let rows = Atari2600Converter.rows
        var screen = Atari2600Converter.Screen(lit: [], playfield: [], background: [])
        for row in 0..<rows {
            screen.lit.append((0..<40).map { ($0 * 7 + row * 3) % 5 < 2 })
            screen.playfield.append((row * 5) % 128)
            screen.background.append((row * 11 + 3) % 128)
        }
        return screen
    }

    @Test("A frame has 262 lines and every visible line's writes land in time")
    func kernelTiming() {
        let screen = Self.sampleScreen()
        let frame = Self.run(Atari2600ROM.build(screen))
        #expect(frame.count == 262)

        let picture = frame.filter { line in line.filter { $0.register == Atari2600ROM.PF0 }.count == 2 }
        #expect(picture.count == 192)
        for (row, line) in picture.enumerated() {
            func writes(_ reg: UInt8) -> [Write] { line.filter { $0.register == reg } }
            let pf = Atari2600ROM.playfieldBytes(screen.lit[row])
            let bk = writes(Atari2600ROM.COLUBK), pfc = writes(Atari2600ROM.COLUPF)
            let p0 = writes(Atari2600ROM.PF0), p1 = writes(Atari2600ROM.PF1), p2 = writes(Atari2600ROM.PF2)
            #expect(bk.count == 1 && bk[0].cycle <= 22 && bk[0].value == Atari2600ROM.colour(screen.background[row]), "row \(row) background")
            #expect(pfc.count == 1 && pfc[0].cycle <= 22 && pfc[0].value == Atari2600ROM.colour(screen.playfield[row]), "row \(row) playfield colour")
            #expect(p0[0].cycle <= 22 && (28...49).contains(p0[1].cycle), "row \(row) PF0 at \(p0.map(\.cycle))")
            #expect(p1[0].cycle <= 28 && (39...54).contains(p1[1].cycle), "row \(row) PF1 at \(p1.map(\.cycle))")
            #expect(p2[0].cycle <= 38 && (50...65).contains(p2[1].cycle), "row \(row) PF2 at \(p2.map(\.cycle))")
            #expect([p0[0].value, p1[0].value, p2[0].value, p0[1].value, p1[1].value, p2[1].value] == pf, "row \(row) playfield")
        }
    }

    @Test("Playfield bytes follow the TIA's drawing order")
    func playfieldBitOrder() {
        // Decode the bytes the way the TIA draws them and get the blocks back
        func decode(_ b: [UInt8]) -> [Bool] {
            func half(_ pf0: UInt8, _ pf1: UInt8, _ pf2: UInt8) -> [Bool] {
                (4..<8).map { pf0 & (1 << $0) != 0 } + (0..<8).map { pf1 & (0x80 >> $0) != 0 } + (0..<8).map { pf2 & (1 << $0) != 0 }
            }
            return half(b[0], b[1], b[2]) + half(b[3], b[4], b[5])
        }
        for seed in 0..<20 {
            let lit = (0..<40).map { ($0 * 13 + seed * 7) % 3 == 0 }
            #expect(decode(Atari2600ROM.playfieldBytes(lit)) == lit)
        }
        var single = [Bool](repeating: false, count: 40); single[0] = true
        #expect(Atari2600ROM.playfieldBytes(single) == [0x10, 0, 0, 0, 0, 0])
        single = [Bool](repeating: false, count: 40); single[39] = true
        #expect(Atari2600ROM.playfieldBytes(single) == [0, 0, 0, 0, 0, 0x80])
    }

    @Test("A converted picture becomes a 4 KB cartridge")
    func conversion() async throws {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 80, pixelsHigh: 60, bitsPerSample: 8, samplesPerPixel: 3,
                                   hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<60 { for x in 0..<80 {
            rep.setColor(NSColor(deviceRed: CGFloat(x) / 79, green: CGFloat(y) / 59, blue: 0.3, alpha: 1), atX: x, y: y)
        } }
        let image = NSImage(size: NSSize(width: 80, height: 60)); image.addRepresentation(rep)
        let result = try await Atari2600Converter().convert(sourceImage: image)
        let file = try #require(result.fileAssets.first)
        #expect(file.pathExtension == "bin")
        #expect(Self.run(try Data(contentsOf: file)).count == 262)
    }
}
