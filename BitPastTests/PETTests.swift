import AppKit
import Foundation
import Testing
@testable import BitPast

@Suite("Commodore PET")
struct PETTests {

    /// Loads a .prg as the PET does, follows the BASIC line's SYS and runs the 6502 code
    /// with the few instructions it uses. Returns memory when the code reaches its JMP *.
    nonisolated static func run(_ prg: Data) -> [UInt8] {
        var mem = [UInt8](repeating: 0, count: 0x10000)
        let bytes = [UInt8](prg)
        let load = Int(bytes[0]) | Int(bytes[1]) << 8
        #expect(load == 0x0401, "PET BASIC programs load at $0401")
        for (i, b) in bytes.dropFirst(2).enumerated() { mem[load + i] = b }

        // BASIC line: next-line pointer, line number, SYS token, the address in digits
        #expect(mem[0x0405] == 0x9E)
        var digits = "", p = 0x0406
        while mem[p] != 0 { digits.append(Character(UnicodeScalar(mem[p]))); p += 1 }
        let next = Int(mem[0x0401]) | Int(mem[0x0402]) << 8
        #expect(mem[next] == 0 && mem[next + 1] == 0, "the program ends after one line")
        var pc = try! #require(Int(digits))

        var a: UInt8 = 0, x: UInt8 = 0, zero = false
        func byte() -> UInt8 { defer { pc += 1 }; return mem[pc] }
        func word() -> Int { let lo = Int(byte()); return lo | Int(byte()) << 8 }
        for _ in 0..<200_000 {
            let op = byte()
            switch op {
            case 0xA9: a = byte(); zero = a == 0                         // lda #
            case 0xA2: x = byte(); zero = x == 0                         // ldx #
            case 0x8D: mem[word()] = a                                   // sta abs
            case 0xBD: a = mem[word() + Int(x)]; zero = a == 0           // lda abs,x
            case 0x9D: mem[word() + Int(x)] = a                          // sta abs,x
            case 0xE8: x &+= 1; zero = x == 0                            // inx
            case 0xD0: let e = Int(Int8(bitPattern: byte())); if !zero { pc += e }   // bne
            case 0x4C:                                                    // jmp
                let target = word()
                if target == pc - 3 { return mem }
                pc = target
            default:
                Issue.record("unexpected opcode \(String(op, radix: 16))")
                return mem
            }
        }
        Issue.record("the program did not reach its loop")
        return mem
    }

    @Test("The program puts the characters on screen and selects the graphics set", arguments: [40, 80])
    func programFillsScreen(columns: Int) {
        let screen = (0..<columns * 25).map { PETConverter.quarterCodes[$0 % 16] }
        let mem = Self.run(PETProgram.build(screen: screen, columns: columns))
        #expect(mem[0xE84C] == 12)
        #expect(Array(mem[0x8000..<0x8000 + screen.count]) == screen)
    }

    @Test("Each 2×2 group of blocks becomes the matching quarter-block character")
    func blocksBecomeCharacters() async throws {
        // An 80×50 picture where each character cell shows one of the 16 combinations
        let width = 80, height = 50
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 3,
                                   hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        func pattern(_ col: Int, _ row: Int) -> Int { (col + row * 40) % 16 }
        for y in 0..<height { for x in 0..<width {
            let bit = 8 >> ((y % 2) * 2 + x % 2)
            let on = pattern(x / 2, y / 2) & bit != 0
            rep.setColor(NSColor(deviceRed: on ? 1 : 0, green: on ? 1 : 0, blue: on ? 1 : 0, alpha: 1), atX: x, y: y)
        } }
        let image = NSImage(size: NSSize(width: width, height: height)); image.addRepresentation(rep)

        var options = PETConverter().options
        options[options.firstIndex { $0.key == "dither" }!].selectedValue = "None"
        let result = try await PETConverter().convert(sourceImage: image, withSettings: options)
        let mem = Self.run(try Data(contentsOf: try #require(result.fileAssets.first)))
        for row in 0..<25 { for col in 0..<40 {
            #expect(mem[0x8000 + row * 40 + col] == PETConverter.quarterCodes[pattern(col, row)], "cell \(col),\(row)")
        } }
    }

    @Test("All 16 quarter combinations have their own character")
    func quarterCodesAreDistinct() {
        #expect(Set(PETConverter.quarterCodes).count == 16)
        // Reversed characters are the inverse of their plain twin
        for i in 0..<16 {
            let code = PETConverter.quarterCodes[i], inverse = PETConverter.quarterCodes[15 - i]
            #expect(code ^ 0x80 == inverse, "combination \(i)")
        }
    }
}

@Suite("Open Recent")
@MainActor
struct RecentFilesTests {
    func makeStore() -> RecentFiles {
        let defaults = UserDefaults(suiteName: "RecentFilesTests-\(UUID().uuidString)")!
        return RecentFiles(defaults: defaults)
    }

    @Test("Keeps the ten newest files, newest first, without duplicates")
    func keepsTenNewest() throws {
        let dir = try TestDisk.makeDirectory()
        let store = makeStore()
        var urls: [URL] = []
        for i in 0..<12 {
            let url = dir.appendingPathComponent("pic\(i).png")
            try Data([1]).write(to: url)
            urls.append(url)
            store.add(url)
        }
        store.add(urls[5])
        #expect(store.entries.count == 10)
        #expect(store.entries.first?.name == "pic5.png")
        #expect(store.entries.map(\.name).filter { $0 == "pic5.png" }.count == 1)
        #expect(!store.entries.contains { $0.name == "pic0.png" || $0.name == "pic1.png" })
    }

    @Test("Opening goes through the saved bookmark; a missing file leaves the list")
    func opensAndForgetsMissing() throws {
        let dir = try TestDisk.makeDirectory()
        let store = makeStore()
        let url = dir.appendingPathComponent("photo.png")
        try Data([1, 2, 3]).write(to: url)
        store.add(url)
        var opened: URL?
        #expect(store.open(store.entries[0]) { opened = $0 })
        #expect(opened?.standardizedFileURL.path == url.standardizedFileURL.path)

        try FileManager.default.removeItem(at: url)
        #expect(!store.open(store.entries[0]) { _ in })
        #expect(store.entries.isEmpty)
    }

    @Test("The list survives a relaunch")
    func persists() throws {
        let dir = try TestDisk.makeDirectory()
        let defaults = UserDefaults(suiteName: "RecentFilesTests-\(UUID().uuidString)")!
        let url = dir.appendingPathComponent("kept.png")
        try Data([1]).write(to: url)
        RecentFiles(defaults: defaults).add(url)
        #expect(RecentFiles(defaults: defaults).entries.map(\.name) == ["kept.png"])
    }
}
