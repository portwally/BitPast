import Foundation
import Testing
@testable import BitPast

/// Commodore D64 / D71 / D81 images, checked against the CBM DOS layout.
@Suite("Commodore D64/D71/D81")
struct CommodoreDiskTests {

    /// Sector layout of one CBM disk format.
    nonisolated struct Layout {
        let sectorsPerTrack: (Int) -> Int
        let tracks: Int
        let dirTrack: Int
        let firstDirSector: Int

        func offset(_ track: Int, _ sector: Int) -> Int {
            ((1..<track).reduce(0) { $0 + sectorsPerTrack($1) } + sector) * 256
        }

        static func spt1541(_ t: Int) -> Int { t <= 17 ? 21 : t <= 24 ? 19 : t <= 30 ? 18 : 17 }
        static let d64 = Layout(sectorsPerTrack: spt1541, tracks: 35, dirTrack: 18, firstDirSector: 1)
        static let d71 = Layout(sectorsPerTrack: { spt1541($0 > 35 ? $0 - 35 : $0) }, tracks: 70, dirTrack: 18, firstDirSector: 1)
        static let d81 = Layout(sectorsPerTrack: { _ in 40 }, tracks: 80, dirTrack: 40, firstDirSector: 3)
    }

    /// Reads every file by following the directory and sector chains.
    /// Records an issue on broken links or sectors used twice.
    static func readFiles(_ image: Data, layout: Layout) -> [ReadFile] {
        var files: [ReadFile] = []
        var used = Set<Int>()
        var dir = (layout.dirTrack, layout.firstDirSector)
        var dirSectors = 0
        while dir.0 != 0 && dirSectors < 40 {
            dirSectors += 1
            let ds = image.slice(layout.offset(dir.0, dir.1), 256)
            for e in 0..<8 {
                let entry = ds.slice(e * 32, 32)
                guard entry.u8(2) != 0 else { continue }
                #expect(entry.u8(2) & 0x80 != 0, "file should be closed")
                var data = Data()
                var link = (entry.u8(3), entry.u8(4))
                var blocks = 0
                while link.0 != 0 {
                    guard (1...layout.tracks).contains(link.0), link.1 < layout.sectorsPerTrack(link.0) else {
                        Issue.record("bad link \(link)"); break
                    }
                    let off = layout.offset(link.0, link.1)
                    #expect(used.insert(off).inserted, "sector \(link) used twice")
                    let sector = image.slice(off, 256)
                    blocks += 1
                    if sector.u8(0) == 0 {
                        data.append(sector.slice(2, sector.u8(1) - 1))
                    } else {
                        data.append(sector.slice(2, 254))
                    }
                    link = (sector.u8(0), sector.u8(1))
                    if blocks > 4000 { Issue.record("sector loop"); break }
                }
                #expect(entry.le16(30) == blocks, "directory block count")
                files.append(ReadFile(name: entry.text(5, 16), data: data))
            }
            dir = (ds.u8(0), ds.u8(1))
        }
        return files
    }

    func write(format: DiskFormat, size: DiskSize, files: [SampleFile]) throws -> Data {
        try TestDisk.image(named: "TEST.\(format.fileExtension)", files: files) { url, inputs in
            D64Writer.shared.createDiskImageWithNames(at: url, volumeName: "BITPAST", format: format, size: size, files: inputs)
        }
    }

    @Test("Image has the standard size", arguments: [
        (DiskFormat.d64, DiskSize.kb170, 174_848),
        (DiskFormat.d71, DiskSize.kb340, 349_696),
        (DiskFormat.d81, DiskSize.kb800, 819_200),
    ])
    func imageSize(format: DiskFormat, size: DiskSize, expectedBytes: Int) throws {
        let image = try write(format: format, size: size, files: TestDisk.standardFiles(ext: "prg"))
        #expect(image.count == expectedBytes)
    }

    @Test("Files read back intact", arguments: [
        (DiskFormat.d64, DiskSize.kb170),
        (DiskFormat.d71, DiskSize.kb340),
        (DiskFormat.d81, DiskSize.kb800),
    ])
    func roundTrip(format: DiskFormat, size: DiskSize) throws {
        let samples = TestDisk.standardFiles(ext: "prg")
        let image = try write(format: format, size: size, files: samples)
        let layout: Layout = format == .d64 ? .d64 : format == .d71 ? .d71 : .d81
        let files = Self.readFiles(image, layout: layout)
        #expect(files.map(\.name) == samples.map(\.name))
        #expect(files.map(\.data) == samples.map(\.data))
    }

    @Test("D64 BAM matches the sectors in use")
    func d64BAM() throws {
        let image = try write(format: .d64, size: .kb170, files: TestDisk.standardFiles(ext: "prg"))
        let layout = Layout.d64
        let bam = image.slice(layout.offset(18, 0), 256)
        #expect(bam.u8(0) == 18 && bam.u8(1) == 1, "BAM links to the directory")
        #expect(bam.text(0x90, 16) == "BITPAST")

        // Every sector reachable from the directory, plus the BAM itself.
        var used: Set<[Int]> = [[18, 0]]
        var dir = (18, 1)
        while dir.0 != 0 {
            used.insert([dir.0, dir.1])
            let ds = image.slice(layout.offset(dir.0, dir.1), 256)
            for e in 0..<8 where ds.u8(e * 32 + 2) != 0 {
                var link = (ds.u8(e * 32 + 3), ds.u8(e * 32 + 4))
                while link.0 != 0 {
                    used.insert([link.0, link.1])
                    let s = image.slice(layout.offset(link.0, link.1), 2)
                    link = (s.u8(0), s.u8(1))
                }
            }
            dir = (ds.u8(0), ds.u8(1))
        }

        for track in 1...35 {
            let entry = bam.slice(track * 4, 4)
            let bits = entry.le24(1)
            var free = 0
            for sector in 0..<layout.sectorsPerTrack(track) {
                let isFree = bits >> sector & 1 == 1
                if isFree { free += 1 }
                #expect(isFree != used.contains([track, sector]), "BAM track \(track) sector \(sector)")
            }
            #expect(entry.u8(0) == free, "free count on track \(track)")
        }
    }
}
