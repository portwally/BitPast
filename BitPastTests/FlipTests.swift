import AppKit
import Foundation
import Testing
@testable import BitPast

/// H-Flip and V-Flip mirror the picture before converting, so saved files match the preview.
@Suite("Flip")
struct FlipTests {

    /// RGBA bytes of an image, top row first.
    nonisolated static func pixels(_ image: NSImage) throws -> [UInt8] {
        let cg = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        return Array(UnsafeBufferPointer(start: ctx.data!.assumingMemoryBound(to: UInt8.self), count: cg.width * cg.height * 4))
    }

    @Test("Mirroring moves every pixel to the other side")
    func mirror() throws {
        let picture = ConverterGoldenTests.testPicture()   // 400×300, different everywhere
        let original = try Self.pixels(picture)
        let width = 400, height = 300
        func pixel(_ data: [UInt8], _ x: Int, _ y: Int) -> ArraySlice<UInt8> { data[(y * width + x) * 4 ..< (y * width + x) * 4 + 4] }
        let h = try Self.pixels(picture.flipped(horizontal: true, vertical: false))
        let v = try Self.pixels(picture.flipped(horizontal: false, vertical: true))
        let both = try Self.pixels(picture.flipped(horizontal: true, vertical: true))
        #expect(h != original)
        for (x, y) in [(0, 0), (17, 5), (399, 120), (200, 299), (123, 222)] {
            #expect(pixel(h, width - 1 - x, y) == pixel(original, x, y))
            #expect(pixel(v, x, height - 1 - y) == pixel(original, x, y))
            #expect(pixel(both, width - 1 - x, height - 1 - y) == pixel(original, x, y))
        }
        #expect(picture.flipped(horizontal: true, vertical: false).size == picture.size)
    }

    @Test("Flipping is kept per picture and reaches batch export and disks")
    @MainActor
    func exportIsFlipped() async throws {
        let vm = ConverterViewModel()
        vm.selectedMachineIndex = 14   // ZX Spectrum
        let picture = ConverterGoldenTests.testPicture()
        let item = InputImage(name: "a.png", image: picture, details: "")
        let other = InputImage(name: "b.png", image: picture, details: "")
        vm.inputImages = [item, other]
        vm.selectedImageId = item.id
        vm.toggleFlip(horizontal: true)
        #expect(vm.inputImages[0].flipHorizontal)
        #expect(!vm.inputImages[1].flipHorizontal)

        let exported = try await vm.exportResult(for: vm.inputImages[0], settings: nil)
        let expected = try await ZXSpectrumConverter().convert(sourceImage: picture.flipped(horizontal: true, vertical: false))
        let unflipped = try await ZXSpectrumConverter().convert(sourceImage: picture)
        #expect(try ConverterGoldenTests.fingerprint(exported) == ConverterGoldenTests.fingerprint(expected))
        #expect(try ConverterGoldenTests.fingerprint(exported) != ConverterGoldenTests.fingerprint(unflipped))
        // The other picture isn't flipped
        let otherResult = try await vm.exportResult(for: vm.inputImages[1], settings: nil)
        #expect(try ConverterGoldenTests.fingerprint(otherResult) == ConverterGoldenTests.fingerprint(unflipped))
    }
}
