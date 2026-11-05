import AppKit
import Foundation
import Testing
@testable import BitPast

/// Fit and Aspect (shared by all converters) and the IIgs Per-Line SCB mode.
@Suite("Fit, Aspect and SCB mode")
struct ImageFramingTests {

    // MARK: - Placement

    @Test("Stretch fills the target whatever the picture's shape")
    func stretch() {
        let rect = ImageFraming().destination(sourceWidth: 800, sourceHeight: 200, width: 320, height: 200)
        #expect(rect == CGRect(x: 0, y: 0, width: 320, height: 200))
    }

    @Test("Contain letterboxes a wide picture on a 4:3 screen")
    func contain() {
        // 2:1 picture on a 4:3 screen: it covers 2/3 of the height
        let rect = ImageFraming(fit: .contain).destination(sourceWidth: 800, sourceHeight: 400, width: 320, height: 200)
        #expect(rect.width == 320)
        #expect(abs(rect.height - 200 * 2 / 3) < 0.001)
        #expect(abs(rect.midY - 100) < 0.001)
    }

    @Test("Contain pillarboxes a tall picture")
    func containTall() {
        // Square picture on a 4:3 screen: 3/4 of the width
        let rect = ImageFraming(fit: .contain).destination(sourceWidth: 500, sourceHeight: 500, width: 256, height: 192)
        #expect(rect.height == 192)
        #expect(abs(rect.width - 192) < 0.001)
        #expect(abs(rect.midX - 128) < 0.001)
    }

    @Test("Cover fills the screen and crops the sides of a wide picture")
    func cover() {
        let rect = ImageFraming(fit: .cover).destination(sourceWidth: 800, sourceHeight: 400, width: 320, height: 200)
        #expect(rect.height == 200)
        #expect(abs(rect.width - 480) < 0.001)
        #expect(abs(rect.minX + 80) < 0.001)
    }

    @Test("Ignore treats the target's pixels as square")
    func ignoreAspect() {
        // 320×200 with square pixels is 16:10; a 16:10 picture fills it exactly
        let rect = ImageFraming(fit: .contain, correctAspect: false)
            .destination(sourceWidth: 1600, sourceHeight: 1000, width: 320, height: 200)
        #expect(rect == CGRect(x: 0, y: 0, width: 320, height: 200))
    }

    @Test("None keeps one source pixel per line, centered")
    func none() {
        let square = ImageFraming(fit: .none, correctAspect: false)
            .destination(sourceWidth: 100, sourceHeight: 50, width: 320, height: 200)
        #expect(square == CGRect(x: 110, y: 75, width: 100, height: 50))
        // 640×200 pixels are 2.4× taller than wide, so the picture gets 2.4× the columns
        let corrected = ImageFraming(fit: .none).destination(sourceWidth: 100, sourceHeight: 50, width: 640, height: 200)
        #expect(abs(corrected.width - 240) < 0.001)
        #expect(corrected.height == 50)
    }

    @Test("Settings without Fit and Aspect stretch, as before")
    func legacySettings() {
        #expect(ImageFraming([]) == .stretch)
        var options = ImageFraming.options
        options[0].selectedValue = "Cover"
        options[1].selectedValue = "Ignore"
        #expect(ImageFraming(options) == ImageFraming(fit: .cover, correctAspect: false))
    }

    // MARK: - Every converter

    @Test("Every converter offers Fit and Aspect, defaulting to Stretch",
          arguments: ConverterGoldenTests.machineNames)
    func everyMachineHasOptions(machine: String) {
        let options = ConverterGoldenTests.makeMachine(machine).options
        #expect(options.first { $0.key == ImageFraming.fitKey }?.selectedValue == "Stretch")
        #expect(options.first { $0.key == ImageFraming.aspectKey }?.selectedValue == "Correct")
    }

    /// A white picture three times as wide as high.
    nonisolated static func widePicture() -> NSImage {
        let width = 600, height = 200
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: width, height: height))
    }

    /// Brightness (0...1) of the preview at a fraction of its height, in the middle column.
    nonisolated static func brightness(of result: ConversionResult, atHeight fraction: Double) throws -> Double {
        var rect = CGRect(origin: .zero, size: result.previewImage.size)
        let cg = try #require(result.previewImage.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        let bytes = ctx.data!.bindMemory(to: UInt8.self, capacity: cg.width * cg.height * 4)
        // Average a small block to ride over dithering and artifact colours
        let cy = Int(Double(cg.height) * fraction), cx = cg.width / 2
        var total = 0.0, count = 0.0
        for y in max(0, cy - 2)...min(cg.height - 1, cy + 2) {
            for x in max(0, cx - 8)...min(cg.width - 1, cx + 8) {
                let i = (y * cg.width + x) * 4
                total += (Double(bytes[i]) + Double(bytes[i + 1]) + Double(bytes[i + 2])) / 765
                count += 1
            }
        }
        return total / count
    }

    @Test("Contain puts black bars above and below a wide picture", arguments: ConverterGoldenTests.machineNames)
    func containShowsBars(machine: String) async throws {
        let converter = ConverterGoldenTests.makeMachine(machine)
        var options = converter.options
        let fit = try #require(options.firstIndex { $0.key == ImageFraming.fitKey })
        options[fit].selectedValue = "Contain"
        let result = try await converter.convert(sourceImage: Self.widePicture(), withSettings: options)
        // A 3:1 picture on a 4:3 screen leaves the top and bottom 28% empty
        let bar = try Self.brightness(of: result, atHeight: 0.15)
        let picture = try Self.brightness(of: result, atHeight: 0.5)
        #expect(picture - bar > 0.5, "\(machine): bar \(bar), picture \(picture)")
    }

    @Test("Apple II and IIgs scaling gives exactly the target pixels, whatever screens are attached")
    func standardSizeIsExact() throws {
        let scaled = ConverterGoldenTests.testPicture().fitToStandardSize(targetWidth: 320, targetHeight: 200)
        let cg = try #require(scaled.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(cg.width == 320 && cg.height == 200)
        #expect(scaled.representations.count == 1)
    }

    // MARK: - IIgs Per-Line

    nonisolated static func iigsOptions(scb: String) -> [ConversionOption] {
        var options = AppleIIGSConverter().options
        options[options.firstIndex { $0.key == "mode" }!].selectedValue = "256 Colors (16 Palettes)"
        options[options.firstIndex { $0.key == "scb_mode" }!].selectedValue = scb
        return options
    }

    @Test("Per-Line uses 16 palettes, reports each line's palette and writes a 32 KB SHR file")
    func perLine() async throws {
        let picture = ConverterGoldenTests.testPicture()
        let result = try await AppleIIGSConverter().convert(sourceImage: picture, withSettings: Self.iigsOptions(scb: "Per-Line"))
        #expect(result.palettes.count == 16)
        #expect(result.paletteLines.count == 200)
        #expect(result.paletteLines.allSatisfy { (0..<16).contains($0) })
        // All 16 palettes are in use, and lines don't simply follow fixed bands
        #expect(Set(result.paletteLines).count == 16)
        #expect(result.paletteLines != (0..<200).map { $0 * 16 / 200 })

        let file = try Data(contentsOf: try #require(result.fileAssets.first))
        #expect(file.count == 32768)
        // The SCB of each line (at $7D00) selects the palette the result reports
        for y in 0..<200 { #expect(Int(file[0x7D00 + y] & 0x0F) == result.paletteLines[y]) }

        let again = try await AppleIIGSConverter().convert(sourceImage: picture, withSettings: Self.iigsOptions(scb: "Per-Line"))
        #expect(try ConverterGoldenTests.fingerprint(again) == ConverterGoldenTests.fingerprint(result))
    }

    @Test("Banded keeps 16 even bands of lines")
    func banded() async throws {
        let result = try await AppleIIGSConverter().convert(sourceImage: ConverterGoldenTests.testPicture(),
                                                            withSettings: Self.iigsOptions(scb: "Banded"))
        #expect(result.paletteLines == (0..<200).map { y in (0..<16).last { $0 * 200 / 16 <= y }! })
    }
}
