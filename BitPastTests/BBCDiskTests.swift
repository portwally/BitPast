import Foundation
import Testing
@testable import BitPast

/// BBC Micro Acorn DFS images. SSD is one side; DSD interleaves the two sides
/// track by track (side 0 track 0, side 1 track 0, side 0 track 1, ...).
@Suite("BBC Micro SSD/DSD")
struct BBCDiskTests {

    nonisolated struct Disk {
        let image: Data
        let doubleSided: Bool

        /// Logical sector on side 0.
        func sector(_ s: Int) -> Data {
            let track = s / 10, inTrack = s % 10
            let index = doubleSided ? track * 20 + inTrack : s
            return image.slice(index * 256, 256)
        }

        /// Catalogue sectors for side 1 sit on track 0 of side 1.
        func side1Catalogue() -> (Data, Data) {
            (image.slice(10 * 256, 256), image.slice(11 * 256, 256))
        }

        func files() -> [(file: ReadFile, start: Int)] {
            let s0 = sector(0), s1 = sector(1)
            let count = s1.u8(5) / 8
            return (0..<count).map { i in
                let n = s0.slice(8 + i * 8, 8), a = s1.slice(8 + i * 8, 8)
                let mixed = a.u8(6)
                let length = a.le16(4) | (mixed >> 4 & 3) << 16
                let start = a.u8(7) | (mixed & 3) << 8
                var data = Data()
                for s in 0..<((length + 255) / 256) { data.append(sector(start + s)) }
                let dir = String(UnicodeScalar(UInt8(n.u8(7) & 0x7F)))
                return (ReadFile(name: "\(dir).\(n.text(0, 7))", data: data.prefix(length)), start)
            }
        }
    }

    static func write(format: DiskFormat, size: DiskSize, files: [SampleFile]) throws -> Disk {
        let image = try TestDisk.image(named: "TEST.\(format.fileExtension)", files: files) { url, inputs in
            BBCDiskWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", format: format, size: size, files: inputs)
        }
        return Disk(image: image, doubleSided: format == .dsd)
    }

    nonisolated static let layouts: [(DiskFormat, DiskSize, Int)] = [
        (.ssd, .kb100, 40), (.ssd, .kb200, 80), (.dsd, .kb200, 40), (.dsd, .kb400, 80),
    ]

    @Test("Image size and catalogue sector count", arguments: layouts)
    func imageSize(format: DiskFormat, size: DiskSize, tracks: Int) throws {
        let disk = try Self.write(format: format, size: size, files: TestDisk.standardFiles(ext: "scr"))
        #expect(disk.image.count == tracks * 10 * 256 * (format == .dsd ? 2 : 1))
        let s1 = disk.sector(1)
        #expect(s1.u8(7) | (s1.u8(6) & 3) << 8 == tracks * 10, "sectors per side in catalogue")
        #expect(disk.sector(0).text(0, 8) == "BITPAST")
    }

    @Test("Files read back intact", arguments: layouts)
    func roundTrip(format: DiskFormat, size: DiskSize, tracks: Int) throws {
        let samples = TestDisk.standardFiles(ext: "scr")
        let files = try Self.write(format: format, size: size, files: samples).files().map(\.file)
        #expect(Set(files.map(\.name)) == Set(samples.map { "$.\($0.name)" }))
        for sample in samples {
            #expect(files.first { $0.name == "$.\(sample.name)" }?.data == sample.data, "\(sample.name)")
        }
    }

    /// DFS expects catalogue entries ordered by start sector, highest first.
    /// *SAVE relies on this to find free space.
    @Test("Catalogue is sorted by start sector, highest first")
    func catalogueOrder() throws {
        let starts = try Self.write(format: .ssd, size: .kb100, files: TestDisk.standardFiles(ext: "scr")).files().map(\.start)
        #expect(starts == starts.sorted(by: >))
    }

    @Test("DSD has an empty catalogue for side 1 on track 0", arguments: [(DiskSize.kb200, 40), (DiskSize.kb400, 80)])
    func side1Catalogue(size: DiskSize, tracks: Int) throws {
        let disk = try Self.write(format: .dsd, size: size, files: TestDisk.standardFiles(ext: "scr"))
        let (s0, s1) = disk.side1Catalogue()
        #expect(s1.u8(5) == 0, "no files on side 1")
        #expect(s1.u8(7) | (s1.u8(6) & 3) << 8 == tracks * 10, "side 1 sector count")
        #expect(s0.text(0, 8) == "BITPAST", "side 1 title")
    }
}
