import AppKit
import Foundation
import Testing
@testable import BitPast

/// MSX Screen 2 files are BLOAD images of VRAM $0000–$37FF: every table must sit at its address.
@Suite("MSX Screen 2 file")
struct MSXScreen2Tests {
    @Test("The .sc2 file holds the patterns at $0000, names at $1800 and colours at $2000")
    func tablesAtTheirAddresses() async throws {
        let image = ConverterGoldenTests.testPicture()
        var options = MSXConverter().options
        options[options.firstIndex { $0.key == "mode" }!].selectedValue = "Screen 2 (MSX1)"
        let result = try await MSXConverter().convert(sourceImage: image, withSettings: options)
        let file = try Data(contentsOf: try #require(result.fileAssets.first))

        #expect(file.count == 7 + 0x3800)
        #expect(Array(file.prefix(7)) == [0xFE, 0x00, 0x00, 0xFF, 0x37, 0x00, 0x00])
        let vram = Array(file.dropFirst(7))

        let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let screen = try await MSXConverter().screen2(cgImage: cg, framing: ImageFraming(options), ditherAlg: "Floyd-Steinberg", ditherAmount: 0.5,
                                                      contrast: "None", filter: "None", colorMatch: "Perceptive", saturation: 1, gamma: 1)
        #expect(Array(vram[0..<0x1800]) == Array(screen.patternTable))
        #expect((0..<768).allSatisfy { vram[0x1800 + $0] == UInt8($0 & 0xFF) })
        #expect(vram[0x1B00] == 0xD0)
        #expect(Array(vram[0x2000..<0x3800]) == Array(screen.colorTable))
    }
}
