import Foundation
import Testing
@testable import BitPast

/// TRS-80 Color Computer RS-DOS (Disk BASIC) images:
/// 35 tracks of 18 sectors (256 bytes), directory on track 17.
@Suite("TRS-80 CoCo DSK")
struct CoCoDiskTests {

    nonisolated struct Disk {
        let image: Data

        /// Sectors are numbered from 1 on each track.
        func sector(track: Int, sector: Int) -> Data { image.slice((track * 18 + sector - 1) * 256, 256) }

        /// Granules 0-33 are tracks 0-16, granules 34-67 are tracks 18-34
        /// (track 17 holds the directory). Each track has two 9-sector granules.
        func granule(_ g: Int) -> Data {
            let track = g / 2 + (g >= 34 ? 1 : 0)
            let first = (g % 2) * 9 + 1
            return (0..<9).reduce(into: Data()) { $0.append(sector(track: track, sector: first + $1)) }
        }

        var gat: Data { sector(track: 17, sector: 2) }

        /// Directory entry: name (8), extension (3), type, ASCII flag,
        /// first granule, bytes used in last sector (big-endian).
        func files() -> (files: [ReadFile], granules: Set<Int>) {
            var result: [ReadFile] = []
            var used = Set<Int>()
            for i in 0..<72 {
                let e = sector(track: 17, sector: 3 + i / 8).slice((i % 8) * 32, 32)
                if e.u8(0) == 0xFF { break }   // end of directory
                if e.u8(0) == 0 { continue }   // killed entry
                let name = e.text(0, 8) + "." + e.text(8, 3)
                var g = e.u8(13)
                var data = Data()
                var steps = 0
                while true {
                    guard g < 68 else { Issue.record("\(name): granule \(g) out of range"); break }
                    #expect(used.insert(g).inserted, "granule \(g) used twice")
                    let next = gat.u8(g)
                    if next >= 0xC0 {
                        let sectors = next & 0x0F
                        let lastBytes = e.be16(14)
                        data.append(granule(g).prefix(max(0, sectors - 1) * 256 + lastBytes))
                        break
                    }
                    data.append(granule(g))
                    g = next
                    steps += 1
                    if steps > 68 { Issue.record("granule loop"); break }
                }
                result.append(ReadFile(name: name, data: data))
            }
            return (result, used)
        }
    }

    static func write(size: DiskSize, files: [SampleFile]) throws -> Disk {
        Disk(image: try TestDisk.image(named: "TEST.dsk", files: files) { url, inputs in
            CoCoDiskWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", size: size, files: inputs) > 0
        })
    }

    @Test("Image size", arguments: [(DiskSize.kb180, 161_280), (DiskSize.kb360, 322_560)])
    func imageSize(size: DiskSize, expectedBytes: Int) throws {
        #expect(try Self.write(size: size, files: TestDisk.standardFiles(ext: "bin")).image.count == expectedBytes)
    }

    /// Includes a file large enough to pass the directory track,
    /// which checks the granule numbering beyond track 17.
    @Test("Files read back intact")
    func roundTrip() throws {
        let samples = TestDisk.standardFiles(ext: "bin") + [SampleFile(name: "BIG", ext: "bin", data: TestDisk.bytes(90_000, seed: 7))]
        let files = try Self.write(size: .kb180, files: samples).files().files
        #expect(files.map(\.name) == samples.map { "\($0.name).BIN" })
        for (file, sample) in zip(files, samples) {
            #expect(file.data == sample.data, "\(sample.name): \(file.data.count) of \(sample.data.count) bytes")
        }
    }

    @Test("GAT marks exactly the granules in use")
    func gat() throws {
        let disk = try Self.write(size: .kb180, files: TestDisk.standardFiles(ext: "bin"))
        let used = disk.files().granules
        for g in 0..<68 {
            #expect((disk.gat.u8(g) != 0xFF) == used.contains(g), "GAT granule \(g)")
        }
    }
}
