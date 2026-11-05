import AppKit
import Foundation
import Testing
@testable import BitPast

/// Choosing which part of the picture shows by dragging the preview.
@Suite("Picture position")
struct FramingPositionTests {

    @Test("The position moves the picture within its overflow; 0 is centered")
    func placement() {
        // 2:1 picture with Cover on a 4:3 screen: 480 wide on a 320-wide screen
        func rect(_ x: CGFloat, _ y: CGFloat, _ sw: Int, _ sh: Int) -> CGRect {
            ImageFraming(fit: .cover, offset: CGPoint(x: x, y: y)).destination(sourceWidth: sw, sourceHeight: sh, width: 320, height: 200)
        }
        #expect(abs(rect(0, 0, 800, 400).minX + 80) < 0.001)
        #expect(abs(rect(-1, 0, 800, 400).minX) < 0.001)          // left edge shows
        #expect(abs(rect(1, 0, 800, 400).maxX - 320) < 0.001)     // right edge shows
        // Tall picture: y -1 puts its top at the top of the screen (origin is bottom-left)
        #expect(abs(rect(0, -1, 400, 800).maxY - 200) < 0.001)
        #expect(abs(rect(0, 1, 400, 800).minY) < 0.001)
    }

    @Test("Dragging follows the mouse and stays in range")
    func drag() {
        // Picture 1.5× the screen: dragging right by 1/4 of the screen moves it 1/4 right,
        // which uses half of its 1/2 overflow - from centered to showing more of the left
        let cover = ImageFraming.offset(.zero, afterDrag: CGSize(width: 0.125, height: 0), scale: CGSize(width: 1.5, height: 1))
        #expect(abs(cover.x + 0.5) < 0.001)
        #expect(cover.y == 0)   // fits exactly vertically, can't move
        // Picture half the screen (Contain): it moves the same way as the mouse
        let contain = ImageFraming.offset(.zero, afterDrag: CGSize(width: 0.1, height: -0.1), scale: CGSize(width: 0.5, height: 0.5))
        #expect(abs(contain.x - 0.4) < 0.001 && abs(contain.y + 0.4) < 0.001)
        // Clamped
        #expect(ImageFraming.offset(.zero, afterDrag: CGSize(width: 5, height: 0), scale: CGSize(width: 1.5, height: 1)).x == -1)
    }

    @Test("The position travels in the settings, and centered adds nothing")
    func settings() {
        let base = ImageFraming.options
        let moved = ImageFraming.settings(base, offset: CGPoint(x: -0.25, y: 0.5))
        #expect(ImageFraming(moved).offset == CGPoint(x: -0.25, y: 0.5))
        #expect(ImageFraming.settings(moved, offset: .zero).count == base.count)
    }

    /// Red on one side, blue on the other.
    nonisolated static func split(width: Int, height: Int, vertical: Bool) -> NSImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        // Red on the left, or on top (CG's origin is bottom-left)
        ctx.fill(vertical ? CGRect(x: 0, y: height / 2, width: width, height: height / 2)
                          : CGRect(x: 0, y: 0, width: width / 2, height: height))
        return NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: width, height: height))
    }

    /// Average red minus average blue of a preview (positive: mostly red).
    nonisolated static func redness(_ result: ConversionResult) throws -> Double {
        let pixels = try FlipTests.pixels(result.previewImage)
        var red = 0.0, blue = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) { red += Double(pixels[i]); blue += Double(pixels[i + 2]) }
        return (red - blue) / Double(pixels.count / 4) / 255
    }

    nonisolated static func convert(_ machine: RetroMachine, _ image: NSImage, offset: CGPoint) async throws -> ConversionResult {
        var options = machine.options
        options[options.firstIndex { $0.key == ImageFraming.fitKey }!].selectedValue = "Cover"
        return try await ConverterViewModel.convertInBackground(machine, image: image,
                                                                settings: ImageFraming.settings(options, offset: offset))
    }

    @Test("Left, right, top and bottom show the matching side of the picture", arguments: ["ZXSpectrum", "AppleIIGS"])
    func sides(machine: String) async throws {
        let m = ConverterGoldenTests.makeMachine(machine)
        let wide = Self.split(width: 900, height: 300, vertical: false)
        let tall = Self.split(width: 300, height: 900, vertical: true)
        #expect(try Self.redness(await Self.convert(m, wide, offset: CGPoint(x: -1, y: 0))) > 0.5, "left")
        #expect(try Self.redness(await Self.convert(m, wide, offset: CGPoint(x: 1, y: 0))) < -0.5, "right")
        #expect(try Self.redness(await Self.convert(m, tall, offset: CGPoint(x: 0, y: -1))) > 0.5, "top")
        #expect(try Self.redness(await Self.convert(m, tall, offset: CGPoint(x: 0, y: 1))) < -0.5, "bottom")
    }

    @Test("Every converter reports how large it drew the picture", arguments: ConverterGoldenTests.machineNames)
    func report(machine: String) async throws {
        // 3:1 picture with Cover on a 4:3 screen: 2.25× the screen's width
        let result = try await Self.convert(ConverterGoldenTests.makeMachine(machine),
                                            Self.split(width: 900, height: 300, vertical: false), offset: .zero)
        let scale = try #require(result.framedScale, "\(machine) didn't report")
        #expect(abs(scale.width - 2.25) < 0.001 && abs(scale.height - 1) < 0.001, "\(machine): \(scale)")
    }

    @Test("Dragging moves only the selected picture, and exports use its position")
    @MainActor
    func viewModel() async throws {
        let vm = ConverterViewModel()
        vm.selectedMachineIndex = 14   // ZX Spectrum
        let fit = vm.currentMachine.options.firstIndex { $0.key == ImageFraming.fitKey }!
        vm.currentMachine.options[fit].selectedValue = "Cover"
        let wide = Self.split(width: 900, height: 300, vertical: false)
        let item = InputImage(name: "a.png", image: wide, details: "")
        let other = InputImage(name: "b.png", image: wide, details: "")
        vm.inputImages = [item, other]
        vm.selectedImageId = item.id
        vm.currentResult = ConversionResult(previewImage: NSImage(), fileAssets: [])
        vm.currentResult?.framedScale = CGSize(width: 2.25, height: 1)
        #expect(vm.canMovePicture)

        // Drag right by half the screen: shows the left edge
        #expect(vm.movePicture(byDrag: CGSize(width: 0.625, height: 0.3)))
        #expect(vm.inputImages[0].fitOffset == CGPoint(x: -1, y: 0))
        #expect(vm.inputImages[1].fitOffset == .zero)

        let exported = try await vm.exportResult(for: vm.inputImages[0], settings: nil)
        #expect(try Self.redness(exported) > 0.5)
        let centered = try await vm.exportResult(for: vm.inputImages[1], settings: nil)
        #expect(try Self.redness(centered) < 0.5)

        vm.centerPicture()
        #expect(vm.inputImages[0].fitOffset == .zero)
    }
}
