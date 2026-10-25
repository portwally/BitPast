import AppKit
import CryptoKit
import Foundation
import Testing
@testable import BitPast

/// Golden-output tests for the image converters.
///
/// Each converter runs a fixed test picture through its default settings and
/// then through every value of each option, one option at a time. The preview
/// pixels and native files are fingerprinted (SHA-256) and compared with
/// `converter-fingerprints.json`, so refactors cannot change the output unnoticed.
///
/// The suite takes several minutes in an unoptimised build, so it only runs
/// when asked for. Run it before and after changing converter code:
///
///     TEST_RUNNER_BITPAST_GOLDEN=1 xcodebuild test -scheme BitPast SWIFT_OPTIMIZATION_LEVEL=-O \
///         -only-testing:BitPastTests/ConverterGoldenTests
///
/// When output changes on purpose, run the same command with
/// `TEST_RUNNER_BITPAST_RECORD_GOLDEN=1` instead, then copy the file named in
/// the test log over `BitPastTests/Golden/converter-fingerprints.json`.
/// Settings whose output differs between two identical runs are not recorded.
@Suite("Converter golden output", .enabled(if: GoldenRun.isRequested))
struct ConverterGoldenTests {

    /// Machines in the same order as the app's machine list.
    nonisolated static let machineNames = [
        "AppleII", "AppleIIGS", "Amiga500", "Amiga1200", "AmstradCPC", "Atari800", "AtariST",
        "BBCMicro", "C64", "MSX", "PC", "Plus4", "TRS80CoCo", "VIC20", "ZXSpectrum",
    ]

    static func makeMachine(_ name: String) -> RetroMachine {
        switch name {
        case "AppleII": AppleIIConverter()
        case "AppleIIGS": AppleIIGSConverter()
        case "Amiga500": Amiga500Converter()
        case "Amiga1200": Amiga1200Converter()
        case "AmstradCPC": AmstradCPCConverter()
        case "Atari800": Atari800Converter()
        case "AtariST": AtariSTConverter()
        case "BBCMicro": BBCMicroConverter()
        case "C64": C64Converter()
        case "MSX": MSXConverter()
        case "PC": PCConverter()
        case "Plus4": Plus4Converter()
        case "TRS80CoCo": TRS80CoCoConverter()
        case "VIC20": VIC20Converter()
        default: ZXSpectrumConverter()
        }
    }

    /// Option values that use random numbers, so their output is not repeatable.
    static func isRandom(_ value: String) -> Bool {
        let v = value.lowercased()
        return v.contains("noise") && !v.contains("blue") || v.contains("random")
    }

    /// Default settings, then each picker value and a non-default slider value,
    /// changing one option at a time.
    static func settingCombinations(for machine: RetroMachine) -> [(name: String, options: [ConversionOption])] {
        let defaults = machine.options
        var combos: [(String, [ConversionOption])] = [("default", defaults)]
        for (index, option) in defaults.enumerated() {
            var values: [String]
            switch option.type {
            case .picker:
                values = option.values.filter { $0 != option.selectedValue && !isRandom($0) }
            case .slider:
                let current = Double(option.selectedValue) ?? option.range.lowerBound
                let target = current + (option.range.upperBound - current) / 2
                values = [String(format: "%.2f", target)]
            }
            for value in values {
                var options = defaults
                options[index].selectedValue = value
                combos.append(("\(option.key)=\(value)", options))
            }
        }
        // A random default (e.g. a noise dither) makes every combo unrepeatable
        return defaults.contains { isRandom($0.selectedValue) } ? [] : combos
    }

    /// A 400×300 picture with gradients, hard edges, skin-like tones and fine detail.
    static func testPicture() -> NSImage {
        let width = 400, height = 300
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let pixels = ctx.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                var r = Double(x) / Double(width) * 255
                var g = Double(y) / Double(height) * 255
                var b = 128 + 127 * sin(Double(x + y) / 23)
                if (x / 40 + y / 40) % 2 == 0 && x > 200 { r = 230; g = 180; b = 150 }   // checkerboard of skin tone
                if (x - 100) * (x - 100) + (y - 150) * (y - 150) < 50 * 50 { r = 20; g = 40; b = 200 }  // blue disc
                if x % 7 == 0 && y > 250 { r = 255; g = 255; b = 255 }                   // fine stripes
                pixels[i] = UInt8(r); pixels[i + 1] = UInt8(g); pixels[i + 2] = UInt8(max(0, min(255, b))); pixels[i + 3] = 255
            }
        }
        return NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: width, height: height))
    }

    /// SHA-256 of the preview pixels (as RGBA8) and of each native file.
    static func fingerprint(_ result: ConversionResult) throws -> String {
        var hasher = SHA256()
        var rect = CGRect(origin: .zero, size: result.previewImage.size)
        let cg = try #require(result.previewImage.cgImage(forProposedRect: &rect, context: nil, hints: nil))
        let ctx = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        hasher.update(data: Data(bytes: ctx.data!, count: cg.width * cg.height * 4))
        for url in result.fileAssets {
            hasher.update(data: Data(url.pathExtension.utf8))
            hasher.update(data: try Data(contentsOf: url))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func goldenURL() -> URL? {
        Bundle(for: GoldenBundleToken.self).url(forResource: "converter-fingerprints", withExtension: "json")
    }

    @Test("Output matches the recorded fingerprints", arguments: machineNames)
    func matchesGolden(machineName: String) async throws {
        let record = ProcessInfo.processInfo.environment["BITPAST_RECORD_GOLDEN"] == "1"
        let golden: [String: [String: String]] = try {
            guard let url = Self.goldenURL() else { return [:] }
            return try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
        }()
        if !record { try #require(golden[machineName] != nil, "no recorded fingerprints for \(machineName)") }

        let machine = Self.makeMachine(machineName)
        let picture = Self.testPicture()
        var recorded: [String: String] = [:]
        for combo in Self.settingCombinations(for: machine) {
            let result = try await machine.convert(sourceImage: picture, withSettings: combo.options)
            let print = try Self.fingerprint(result)
            if record {
                // Run twice and keep only repeatable results
                let again = try Self.fingerprint(try await machine.convert(sourceImage: picture, withSettings: combo.options))
                if again == print { recorded[combo.name] = print }
            } else if let expected = golden[machineName]?[combo.name] {
                #expect(print == expected, "\(machineName) \(combo.name)")
            }
        }

        if record {
            try GoldenRecorder.shared.save(machineName, recorded)
        }
    }
}

/// Whether the golden suite was asked for (see `ConverterGoldenTests`).
nonisolated enum GoldenRun {
    static var isRequested: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["BITPAST_GOLDEN"] == "1" || env["BITPAST_RECORD_GOLDEN"] == "1"
    }
}

/// Collects recorded fingerprints from all machines into one JSON file in Caches.
final class GoldenRecorder: @unchecked Sendable {
    static let shared = GoldenRecorder()
    private let lock = NSLock()

    func save(_ machine: String, _ prints: [String: String]) throws {
        lock.lock(); defer { lock.unlock() }
        let caches = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = caches.appendingPathComponent("converter-fingerprints.json")
        var all = (try? JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))) ?? [:]
        all[machine] = prints
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(all).write(to: url)
        Issue.record(Comment(rawValue: "Recorded \(prints.count) fingerprints for \(machine) to \(url.path)"))
    }
}

/// Used to find the test bundle's resources.
final class GoldenBundleToken {}
