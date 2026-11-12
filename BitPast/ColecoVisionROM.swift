import Foundation

/// Builds a ColecoVision cartridge that shows one Graphics II picture.
///
/// The cartridge starts at $8000 with the "55 AA" signature, which makes the BIOS skip
/// its title screen and jump straight to the program. The program sets up the
/// TMS9928A for Graphics II with the display off, copies the pattern table to
/// VRAM $0000, writes the name table (0–255 three times) at $1800, ends the sprite
/// list at $1B00, copies the colour table to $2000, turns the display on and waits.
/// Interrupts stay off; the NMI vector only returns.
nonisolated enum ColecoVisionROM {

    static let origin = 0x8000
    static let size = 0x4000            // 16 KB: the program and 12 KB of tables fit

    /// VDP registers 0–7: Graphics II, 16 KB VRAM, display off; name table $1800,
    /// colour table $2000, pattern table $0000, sprite attributes $1B00,
    /// sprite patterns $3800, black backdrop.
    static let registers: [UInt8] = [0x02, 0x80, 0x06, 0xFF, 0x03, 0x36, 0x07, 0x01]

    static func build(patternTable: Data, colorTable: Data) -> Data {
        precondition(patternTable.count == 6144 && colorTable.count == 6144)
        var a = Z80Assembler(origin: origin)

        // Cartridge header
        a.bytes(0x55, 0xAA)                 // skip the BIOS title screen
        a.word(0); a.word(0); a.word(0); a.word(0)   // sprite, sprite order, work buffer, controller pointers (unused)
        a.wordLabel("start")                // $800A: start address
        for _ in 0..<7 { a.bytes(0xC9, 0x00, 0x00) }  // RST 08h–38h: RET
        a.bytes(0xED, 0x45, 0x00)           // $8021 NMI: RETN

        a.label("start")
        a.bytes(0xF3)                       // di
        a.bytes(0x31); a.word(0x7400)       // ld sp,$7400 (top of the 1 KB of RAM)
        a.bytes(0xDB, 0xBF)                 // in a,($BF)    clear the VDP status

        a.bytes(0x21); a.wordLabel("regs")  // ld hl,regs
        a.bytes(0x0E, 0x80)                 // ld c,$80
        a.label("regloop")
        a.bytes(0x7E, 0xD3, 0xBF)           // ld a,(hl) / out ($BF),a
        a.bytes(0x79, 0xD3, 0xBF)           // ld a,c    / out ($BF),a
        a.bytes(0x23, 0x0C)                 // inc hl / inc c
        a.bytes(0x79, 0xFE, 0x88)           // ld a,c / cp $88
        a.jrNZ("regloop")

        a.setWriteAddress(0x0000)
        a.bytes(0x21); a.wordLabel("patterns")
        a.bytes(0x01); a.word(0x1800)       // ld bc,6144
        a.bytes(0xCD); a.wordLabel("copy")  // call copy

        a.setWriteAddress(0x1800)
        a.bytes(0x01); a.word(0x0300)       // ld bc,768
        a.bytes(0x16, 0x00)                 // ld d,0
        a.label("names")
        a.bytes(0x7A, 0xD3, 0xBE, 0x14)     // ld a,d / out ($BE),a / inc d
        a.bytes(0x0B, 0x78, 0xB1)           // dec bc / ld a,b / or c
        a.jrNZ("names")

        a.setWriteAddress(0x1B00)
        a.bytes(0x3E, 0xD0, 0xD3, 0xBE)     // ld a,$D0 / out ($BE),a   no sprites

        a.setWriteAddress(0x2000)
        a.bytes(0x21); a.wordLabel("colors")
        a.bytes(0x01); a.word(0x1800)
        a.bytes(0xCD); a.wordLabel("copy")

        a.bytes(0x3E, 0xC0, 0xD3, 0xBF)     // ld a,$C0 / out ($BF),a
        a.bytes(0x3E, 0x81, 0xD3, 0xBF)     // ld a,$81 / out ($BF),a   R1: display on
        a.label("forever")
        a.jr("forever")

        a.label("copy")
        a.bytes(0x7E, 0xD3, 0xBE, 0x23)     // ld a,(hl) / out ($BE),a / inc hl
        a.bytes(0x0B, 0x78, 0xB1)           // dec bc / ld a,b / or c
        a.jrNZ("copy")
        a.bytes(0xC9)                       // ret

        a.label("regs")
        a.data(Data(registers))
        a.label("patterns")
        a.data(patternTable)
        a.label("colors")
        a.data(colorTable)

        var rom = a.assemble()
        precondition(rom.count <= size)
        rom.append(Data(repeating: 0xFF, count: size - rom.count))
        return rom
    }
}

/// Just enough of a Z80 assembler for the cartridge above: raw bytes, labels and relative jumps.
nonisolated struct Z80Assembler {
    private let origin: Int
    private var code: [UInt8] = []
    private var labels: [String: Int] = [:]
    private var absolute: [(at: Int, label: String)] = []
    private var relative: [(at: Int, label: String)] = []

    init(origin: Int) { self.origin = origin }

    mutating func bytes(_ b: UInt8...) { code += b }
    mutating func data(_ d: Data) { code += d }
    mutating func word(_ w: Int) { code += [UInt8(w & 0xFF), UInt8(w >> 8 & 0xFF)] }
    mutating func label(_ name: String) { labels[name] = origin + code.count }
    mutating func wordLabel(_ name: String) { absolute.append((code.count, name)); code += [0, 0] }
    mutating func jr(_ name: String) { code.append(0x18); relative.append((code.count, name)); code.append(0) }
    mutating func jrNZ(_ name: String) { code.append(0x20); relative.append((code.count, name)); code.append(0) }

    /// Sets the VDP's VRAM write address: low byte, then high byte with bit 6 set.
    mutating func setWriteAddress(_ address: Int) {
        bytes(0x3E, UInt8(address & 0xFF), 0xD3, 0xBF)            // ld a,lo / out ($BF),a
        bytes(0x3E, UInt8(address >> 8 | 0x40), 0xD3, 0xBF)       // ld a,hi|$40 / out ($BF),a
    }

    func assemble() -> Data {
        var out = code
        for (at, name) in absolute {
            let target = labels[name]!
            out[at] = UInt8(target & 0xFF); out[at + 1] = UInt8(target >> 8)
        }
        for (at, name) in relative {
            let offset = labels[name]! - (origin + at + 1)
            precondition((-128...127).contains(offset), "jr to \(name) out of range")
            out[at] = UInt8(bitPattern: Int8(offset))
        }
        return Data(out)
    }
}
