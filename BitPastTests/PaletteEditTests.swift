import AppKit
import Foundation
import Testing
@testable import BitPast

/// Palette editor changes reach the saved IIgs file and batch exports.
@Suite("Palette edits")
struct PaletteEditTests {

    nonisolated static func convert(mode: String) async throws -> (ConversionResult, Data) {
        var options = AppleIIGSConverter().options
        options[options.firstIndex { $0.key == "mode" }!].selectedValue = mode
        let result = try await AppleIIGSConverter().convert(sourceImage: ConverterGoldenTests.testPicture(), withSettings: options)
        return (result, try Data(contentsOf: try #require(result.fileAssets.first)))
    }

    /// Bytes that differ between two files of equal size.
    nonisolated static func changedOffsets(_ a: Data, _ b: Data) -> [Int] {
        (0..<a.count).filter { a[a.startIndex + $0] != b[b.startIndex + $0] }
    }

    @Test("Unedited palettes give back the same file", arguments: ["256 Colors (16 Palettes)", "3200 Colors (Brooks)", "320x200 (16 Colors)"])
    func roundTrip(mode: String) async throws {
        let (result, file) = try await Self.convert(mode: mode)
        #expect(AppleIIGSConverter.replacingPalettes(result.palettes, in: file) == file)
    }

    @Test("An edited colour lands in its palette slot of a SHR file")
    func shr() async throws {
        let (result, file) = try await Self.convert(mode: "256 Colors (16 Palettes)")
        var palettes = result.palettes
        palettes[3][5] = PaletteRGB(r: 255, g: 0, b: 0)
        let edited = try #require(AppleIIGSConverter.replacingPalettes(palettes, in: file))
        let offset = 32256 + 3 * 32 + 5 * 2
        #expect(edited[offset] == 0x00 && edited[offset + 1] == 0x0F)
        // Only that colour word changes; pixels and SCBs stay
        #expect(Self.changedOffsets(file, edited).allSatisfy { $0 == offset || $0 == offset + 1 })
    }

    @Test("An edited colour lands in its line of a Brooks file, in reverse colour order")
    func brooks() async throws {
        let (result, file) = try await Self.convert(mode: "3200 Colors (Brooks)")
        var palettes = result.palettes
        palettes[7][2] = PaletteRGB(r: 0, g: 0, b: 255)
        let edited = try #require(AppleIIGSConverter.replacingPalettes(palettes, in: file))
        let offset = 32000 + 7 * 32 + (15 - 2) * 2
        #expect(edited[offset] == 0x0F && edited[offset + 1] == 0x00)
        #expect(Self.changedOffsets(file, edited).allSatisfy { $0 == offset || $0 == offset + 1 })
    }

    @Test("Batch export and Create Disk reuse the edited result for its image only")
    @MainActor
    func exportUsesEdits() async throws {
        let vm = ConverterViewModel()
        vm.selectedMachineIndex = 1
        let edited = InputImage(name: "a.png", image: ConverterGoldenTests.testPicture(), details: "")
        let other = InputImage(name: "b.png", image: ConverterGoldenTests.testPicture(), details: "")
        vm.inputImages = [edited, other]
        let marker = URL(fileURLWithPath: "/edited.shr")
        vm.currentResult = ConversionResult(previewImage: NSImage(), fileAssets: [marker], editedPalettes: true)
        vm.paletteEditsImageId = edited.id
        vm.paletteEditsMachineIndex = 1

        #expect(try await vm.exportResult(for: edited, settings: nil).fileAssets == [marker])
        #expect(try await vm.exportResult(for: other, settings: nil).fileAssets != [marker])

        // After switching machine, the edits no longer apply
        vm.selectedMachineIndex = 0
        #expect(try await vm.exportResult(for: edited, settings: nil).fileAssets != [marker])
    }
}
