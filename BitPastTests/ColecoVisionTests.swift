import AppKit
import Foundation
import Testing
@testable import BitPast

/// The ColecoVision cartridge is checked by running its program: a small Z80 that knows
/// only the instructions the cartridge uses, wired to a model of the TMS9928A's ports.
@Suite("ColecoVision cartridge")
struct ColecoVisionTests {

    /// What the VDP ends up with after the program has run.
    nonisolated struct VDP {
        var vram = [UInt8](repeating: 0, count: 0x4000)
        var registers = [UInt8](repeating: 0, count: 8)
        var address = 0
        var latch: UInt8?

        mutating func control(_ value: UInt8) {
            guard let first = latch else { latch = value; return }
            latch = nil
            if value & 0x80 != 0 { registers[Int(value & 0x07)] = first }
            else { address = Int(value & 0x3F) << 8 | Int(first) }
        }
        mutating func data(_ value: UInt8) { vram[address] = value; address = (address + 1) & 0x3FFF }
    }

    /// Runs the cartridge the way the BIOS starts it, until it reaches its endless loop.
    nonisolated static func run(_ rom: Data) throws -> VDP {
        var mem = [UInt8](repeating: 0, count: 0x10000)
        for (i, b) in rom.enumerated() { mem[0x8000 + i] = b }
        #expect(mem[0x8000] == 0x55 && mem[0x8001] == 0xAA, "the signature that skips the title screen")
        var pc = Int(mem[0x800A]) | Int(mem[0x800B]) << 8
        var sp = 0, a: UInt8 = 0, b: UInt8 = 0, c: UInt8 = 0, d: UInt8 = 0, hl = 0, zero = false
        var vdp = VDP()
        func byte() -> UInt8 { defer { pc += 1 }; return mem[pc] }
        func word() -> Int { let lo = Int(byte()); return lo | Int(byte()) << 8 }
        func jump(_ taken: Bool) { let e = Int(Int8(bitPattern: byte())); if taken { pc += e } }
        func out(_ port: UInt8) throws {
            switch port {
            case 0xBF: vdp.control(a)
            case 0xBE: vdp.data(a)
            default: Issue.record("write to port \(port)")
            }
        }
        for _ in 0..<1_000_000 {
            let op = byte()
            switch op {
            case 0xF3: break                                         // di
            case 0x31: sp = word()                                   // ld sp,nn
            case 0xDB: _ = byte(); a = 0; vdp.latch = nil            // in a,(n): reading status resets the latch
            case 0x21: hl = word()                                   // ld hl,nn
            case 0x01: let w = word(); c = UInt8(w & 0xFF); b = UInt8(w >> 8)   // ld bc,nn
            case 0x0E: c = byte()                                    // ld c,n
            case 0x16: d = byte()                                    // ld d,n
            case 0x3E: a = byte()                                    // ld a,n
            case 0x7E: a = mem[hl]                                   // ld a,(hl)
            case 0x79: a = c                                         // ld a,c
            case 0x7A: a = d                                         // ld a,d
            case 0x78: a = b                                         // ld a,b
            case 0x23: hl = (hl + 1) & 0xFFFF                        // inc hl
            case 0x0C: c &+= 1                                       // inc c
            case 0x14: d &+= 1                                       // inc d
            case 0x0B: let bc = (Int(b) << 8 | Int(c)) &- 1 & 0xFFFF; b = UInt8(bc >> 8); c = UInt8(bc & 0xFF)  // dec bc (flags unchanged)
            case 0xB1: a |= c; zero = a == 0                         // or c
            case 0xFE: zero = a == byte()                            // cp n
            case 0xD3: try out(byte())                               // out (n),a
            case 0x20: jump(!zero)                                   // jr nz,e
            case 0x18:                                               // jr e
                if mem[pc] == 0xFE { #expect(sp == 0x7400); return vdp }   // jr $: done
                jump(true)
            case 0xCD: let target = word(); sp -= 2; mem[sp] = UInt8(pc & 0xFF); mem[sp + 1] = UInt8(pc >> 8); pc = target
            case 0xC9: pc = Int(mem[sp]) | Int(mem[sp + 1]) << 8; sp += 2
            default:
                Issue.record("unexpected opcode \(String(op, radix: 16)) at \(String(pc - 1, radix: 16))")
                return vdp
            }
        }
        Issue.record("the program did not reach its loop")
        return vdp
    }

    @Test("The cartridge puts the picture into video memory and turns the display on")
    func cartridgeFillsVRAM() throws {
        let patterns = TestDisk.bytes(6144, seed: 7), colors = TestDisk.bytes(6144, seed: 8)
        let rom = ColecoVisionROM.build(patternTable: patterns, colorTable: colors)
        #expect(rom.count == 16384)

        let vdp = try Self.run(rom)
        #expect(vdp.registers == [0x02, 0xC0, 0x06, 0xFF, 0x03, 0x36, 0x07, 0x01])
        #expect(Array(vdp.vram[0..<0x1800]) == Array(patterns))
        #expect(Array(vdp.vram[0x2000..<0x3800]) == Array(colors))
        #expect((0..<768).allSatisfy { vdp.vram[0x1800 + $0] == UInt8($0 & 0xFF) })
        #expect(vdp.vram[0x1B00] == 0xD0)
    }

    @Test("A converted picture becomes a .col cartridge with the same screen as MSX Screen 2")
    func conversionMatchesMSXScreen2() async throws {
        let size = 64
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3,
                                   hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<size { for x in 0..<size {
            rep.setColor(NSColor(deviceRed: CGFloat(x) / 63, green: CGFloat(y) / 63, blue: 0.5, alpha: 1), atX: x, y: y)
        } }
        let image = NSImage(size: NSSize(width: size, height: size)); image.addRepresentation(rep)

        let result = try await ColecoVisionConverter().convert(sourceImage: image)
        let file = try #require(result.fileAssets.first)
        #expect(file.pathExtension == "col")
        let rom = try Data(contentsOf: file)
        let vdp = try Self.run(rom)

        var msxOptions = MSXConverter().options
        msxOptions[msxOptions.firstIndex { $0.key == "mode" }!].selectedValue = "Screen 2 (MSX1)"
        let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let msx = try await MSXConverter().screen2(cgImage: cg, framing: ImageFraming(msxOptions), ditherAlg: "Floyd-Steinberg", ditherAmount: 0.5,
                                                   contrast: "None", filter: "None", colorMatch: "Perceptive", saturation: 1, gamma: 1)
        #expect(Array(vdp.vram[0..<0x1800]) == Array(msx.patternTable))
        #expect(Array(vdp.vram[0x2000..<0x3800]) == Array(msx.colorTable))
    }
}
