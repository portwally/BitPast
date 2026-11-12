import Foundation
import AppKit

/// ColecoVision (1982). Its TMS9928A video chip is the MSX1's, so the picture is the same
/// Graphics II screen: 256×192 pixels, two of 15 colours for each 8×1 line.
/// The result is a 16 KB cartridge (.col) that shows the picture.
nonisolated class ColecoVisionConverter: RetroMachine {
    var name: String = "ColecoVision"

    var options: [ConversionOption] = MSXConverter().options.filter { $0.key != "mode" }

    func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]? = nil) async throws -> ConversionResult {
        try validateSourceImage(sourceImage)
        let opts = settings ?? options
        guard let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "ColecoVisionConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }
        func value(_ key: String, _ fallback: String) -> String { opts.first { $0.key == key }?.selectedValue ?? fallback }

        try Task.checkCancellation()
        let screen = try await MSXConverter().screen2(
            cgImage: cgImage, framing: ImageFraming(opts),
            ditherAlg: value("dither", "Floyd-Steinberg"),
            ditherAmount: Double(value("dither_amount", "0.5")) ?? 0.5,
            contrast: value("contrast", "None"),
            filter: value("filter", "None"),
            colorMatch: value("color_match", "Perceptive"),
            saturation: Double(value("saturation", "1.0")) ?? 1.0,
            gamma: Double(value("gamma", "1.0")) ?? 1.0)

        let rom = ColecoVisionROM.build(patternTable: screen.patternTable, colorTable: screen.colorTable)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("coleco_\(UUID().uuidString.prefix(8)).col")
        try rom.write(to: url)
        return ConversionResult(previewImage: screen.preview, fileAssets: [url], palettes: [], pixelIndices: [], imageWidth: 256, imageHeight: 192)
    }
}
