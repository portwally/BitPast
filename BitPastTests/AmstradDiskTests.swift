import Foundation
import Testing
@testable import BitPast

/// Amstrad CPC Extended DSK images in AMSDOS "Data" format
/// (9 sectors of 512 bytes per track, IDs &C1-&C9, 1 KB blocks, no reserved tracks).
@Suite("Amstrad CPC DSK")
struct AmstradDiskTests {

    nonisolated struct Disk {
        let image: Data
        var tracks: Int { image.u8(0x30) }
        var sides: Int { image.u8(0x31) }

        /// Finds a sector by its ID using the track's sector info table,
        /// so physical sector order in the image does not matter.
        func sector(trackIndex: Int, id: Int) -> Data? {
            var offset = 256
            for t in 0..<trackIndex { offset += image.u8(0x34 + t) * 256 }
            let header = image.slice(offset, 256)
            guard header.slice(0, 10) == Data("Track-Info".utf8) else { return nil }
            var dataOffset = offset + 256
            for s in 0..<header.u8(0x15) {
                let info = header.slice(0x18 + s * 8, 8)
                let length = info.le16(6) != 0 ? info.le16(6) : 128 << info.u8(3)
                if info.u8(2) == id { return image.slice(dataOffset, length) }
                dataOffset += length
            }
            return nil
        }

        /// Logical sector k of the Data format lives on track k / 9, side 0.
        func logicalSector(_ k: Int) -> Data {
            sector(trackIndex: (k / 9) * sides, id: 0xC1 + k % 9) ?? Data(count: 512)
        }

        func block(_ n: Int) -> Data { logicalSector(n * 2) + logicalSector(n * 2 + 1) }

        /// Reads files from the 64-entry directory in blocks 0-1, joining extents.
        func files() -> [ReadFile] {
            let dir = block(0) + block(1)
            var extents: [String: [(ex: Int, rc: Int, blocks: [Int])]] = [:]
            var order: [String] = []
            for i in 0..<64 {
                let e = dir.slice(i * 32, 32)
                guard e.u8(0) != 0xE5 else { continue }
                let name = e.text(1, 8) + "." + e.text(9, 3)
                if extents[name] == nil { order.append(name) }
                let blocks = (16..<32).map { e.u8($0) }.filter { $0 != 0 }
                extents[name, default: []].append((ex: e.u8(12) | e.u8(14) << 5, rc: e.u8(15), blocks: blocks))
            }
            return order.map { name in
                var data = Data()
                let parts = extents[name]!.sorted { $0.ex < $1.ex }
                for part in parts {
                    var extentData = Data()
                    for b in part.blocks { extentData.append(block(b)) }
                    data.append(extentData.prefix(part.rc * 128))
                }
                return ReadFile(name: name, data: data)
            }
        }
    }

    static func write(size: DiskSize, files: [SampleFile]) throws -> Disk {
        Disk(image: try TestDisk.image(named: "TEST.dsk", files: files) { url, inputs in
            CPCDiskWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", size: size, files: inputs)
        })
    }

    @Test("Extended DSK header and size", arguments: [(DiskSize.kb180, 40, 1), (DiskSize.kb360, 40, 2)])
    func header(size: DiskSize, tracks: Int, sides: Int) throws {
        let disk = try Self.write(size: size, files: TestDisk.standardFiles(ext: "scr"))
        #expect(disk.image.slice(0, 34) == Data("EXTENDED CPC DSK File\r\nDisk-Info\r\n".utf8))
        #expect(disk.tracks == tracks && disk.sides == sides)
        let trackBytes = (0..<(tracks * sides)).reduce(0) { $0 + disk.image.u8(0x34 + $1) * 256 }
        #expect(disk.image.count == 256 + trackBytes, "track size table matches the file")
    }

    /// CP/M stores sizes in 128-byte records, so files come back padded
    /// to the next 128 bytes.
    @Test("Files read back intact (180 KB)")
    func roundTrip() throws {
        let samples = TestDisk.standardFiles(ext: "scr") + [SampleFile(name: "BIG", ext: "scr", data: TestDisk.bytes(40_000, seed: 9))]
        let files = try Self.write(size: .kb180, files: samples).files()
        #expect(files.map(\.name) == samples.map { "\($0.name).SCR" })
        for (file, sample) in zip(files, samples) {
            #expect(file.data.prefix(sample.data.count) == sample.data, "\(sample.name) contents")
            #expect(file.data.count == (sample.data.count + 127) / 128 * 128, "\(sample.name) record count")
        }
    }
}
