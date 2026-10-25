import AppKit
import Foundation
import Testing
@testable import BitPast

/// Conversions run off the main thread, and converters can run in parallel.
@Suite("Background conversion")
struct ConverterConcurrencyTests {

    /// Records which thread `convert` runs on.
    nonisolated final class ThreadProbe: RetroMachine, @unchecked Sendable {
        var name = "Probe"
        var options: [ConversionOption] = []
        private(set) var ranOnMainThread: Bool?

        func convert(sourceImage: NSImage, withSettings settings: [ConversionOption]?) async throws -> ConversionResult {
            ranOnMainThread = pthread_main_np() != 0
            return ConversionResult(previewImage: sourceImage, fileAssets: [])
        }
    }

    @Test("Conversions started from the main thread run in the background")
    @MainActor
    func runsOffMainThread() async throws {
        let probe = ThreadProbe()
        _ = try await ConverterViewModel.convertInBackground(probe, image: ConverterGoldenTests.testPicture(), settings: [])
        #expect(probe.ranOnMainThread == false)
    }

    /// Apple II shares C globals (guarded by a lock); the IIgs 3200-color mode
    /// keeps per-scanline palette state. Parallel runs must match serial ones.
    @Test("Parallel conversions give the same result as serial ones", arguments: ["AppleII", "AppleIIGS"])
    func parallelMatchesSerial(machineName: String) async throws {
        let picture = ConverterGoldenTests.testPicture()
        let machine = ConverterGoldenTests.makeMachine(machineName)
        let settings = machine.options
        let expected = try ConverterGoldenTests.fingerprint(
            try await ConverterViewModel.convertInBackground(machine, image: picture, settings: settings))

        let prints = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    try ConverterGoldenTests.fingerprint(
                        try await ConverterViewModel.convertInBackground(machine, image: picture, settings: settings))
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }
        #expect(prints.count == 4)
        #expect(prints.allSatisfy { $0 == expected })
    }

    /// Replaced previews are cancelled; every converter must notice and stop.
    @Test("A cancelled conversion stops with CancellationError", arguments: ConverterGoldenTests.machineNames)
    func cancelledConversionStops(machineName: String) async throws {
        let machine = ConverterGoldenTests.makeMachine(machineName)
        let settings = machine.options
        let picture = ConverterGoldenTests.testPicture()
        let task = Task { try await ConverterViewModel.convertInBackground(machine, image: picture, settings: settings) }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
