import Foundation
import Testing
@testable import BitPast

/// Atari 800 ATR images, checked against the Atari DOS 2.0S layout.
@Suite("Atari 800 ATR")
struct AtariDiskTests {

    nonisolated struct Disk {
        let image: Data
        var sectorSize: Int { image.le16(4) }
        var body: Data { image.dropFirst(16) }
        var sectorCount: Int { body.count / sectorSize }

        /// Sector numbers start at 1. This reader expects every sector,
        /// including boot sectors, to be stored at full size.
        func sector(_ n: Int) -> Data { body.slice((n - 1) * sectorSize, sectorSize) }

        /// Reads the files listed in the directory (sectors 361-368) by
        /// following the 3-byte links at the end of each sector.
        func files() -> (files: [ReadFile], sectors: Set<Int>) {
            var result: [ReadFile] = []
            var used = Set<Int>()
            for index in 0..<64 {
                let e = sector(361 + index / 8).slice((index % 8) * 16, 16)
                let flags = e.u8(0)
                if flags == 0 { break }
                if flags & 0x80 != 0 { continue }  // deleted
                let name = e.text(5, 8) + "." + e.text(13, 3)
                var current = e.le16(3)
                var count = 0
                var data = Data()
                while current != 0 {
                    guard current >= 1 && current <= sectorCount else { Issue.record("bad sector \(current)"); break }
                    #expect(used.insert(current).inserted, "sector \(current) used twice")
                    let s = sector(current)
                    let link = sectorSize - 3
                    #expect(s.u8(link) >> 2 == index, "file number in sector \(current)")
                    data.append(s.slice(0, s.u8(link + 2)))
                    current = (s.u8(link) & 0x03) << 8 | s.u8(link + 1)
                    count += 1
                    if count > 2000 { Issue.record("sector loop"); break }
                }
                #expect(e.le16(1) == count, "\(name) sector count")
                result.append(ReadFile(name: name, data: data))
            }
            return (result, used)
        }
    }

    static func write(size: DiskSize, files: [SampleFile]) throws -> Disk {
        let disk = Disk(image: try TestDisk.image(named: "TEST.atr", files: files) { url, inputs in
            ATRWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", size: size, files: inputs)
        })
        try #require(disk.sectorSize == 128 || disk.sectorSize == 256, "ATR sector size")
        return disk
    }

    @Test("Header and size match the size picked", arguments: [
        (DiskSize.kb90, 720, 128), (DiskSize.kb130, 1040, 128), (DiskSize.kb180, 720, 256), (DiskSize.kb360, 1440, 256),
    ])
    func header(size: DiskSize, sectors: Int, sectorSize: Int) throws {
        let disk = try Self.write(size: size, files: TestDisk.standardFiles(ext: "mic"))
        #expect(disk.image.le16(0) == 0x0296, "ATR signature")
        #expect(disk.sectorSize == sectorSize)
        let paragraphs = disk.image.le16(2) | disk.image.u8(6) << 16
        #expect(paragraphs * 16 == disk.image.count - 16, "header size matches the data")
        #expect(disk.sectorCount == sectors)
    }

    @Test("Files read back intact", arguments: [DiskSize.kb90, .kb130, .kb180, .kb360])
    func roundTrip(size: DiskSize) throws {
        let samples = TestDisk.standardFiles(ext: "mic")
        let disk = try Self.write(size: size, files: samples)
        let files = disk.files().files
        #expect(files.map(\.name) == samples.map { "\($0.name).MIC" })
        #expect(files.map(\.data) == samples.map(\.data))
    }

    /// DOS 2.0S keeps a free-sector bitmap in the VTOC (sector 360), starting at
    /// byte 10. Bit 7 of byte 10 is sector 0, bit 6 is sector 1, and so on;
    /// a set bit means the sector is free.
    @Test("VTOC bitmap marks exactly the sectors in use (90 KB DOS 2.0S)")
    func vtoc() throws {
        let disk = try Self.write(size: .kb90, files: TestDisk.standardFiles(ext: "mic"))
        let vtoc = disk.sector(360)
        var used = disk.files().sectors
        used.formUnion([0, 1, 2, 3])        // sector 0 does not exist; 1-3 are boot sectors
        used.formUnion(360...368)           // VTOC and directory
        var free = 0
        for s in 0..<720 {
            let isFree = vtoc.u8(10 + s / 8) >> (7 - s % 8) & 1 == 1
            if isFree { free += 1 }
            #expect(isFree != used.contains(s), "VTOC sector \(s)")
        }
        #expect(vtoc.le16(3) == free, "free sector count")
    }

    /// DOS 2.5 enhanced density adds VTOC2 at sector 1024: bytes 0-83 mirror
    /// the main bitmap for sectors 48-719, bytes 84-121 cover sectors 720-1023,
    /// and bytes 122-123 count the free sectors above 719.
    @Test("130 KB disks get a DOS 2.5 VTOC2")
    func vtoc2() throws {
        let samples = TestDisk.standardFiles(ext: "mic") + [SampleFile(name: "BIG", ext: "mic", data: TestDisk.bytes(95_000, seed: 8))]
        let disk = try Self.write(size: .kb130, files: samples)
        let (files, used) = disk.files()
        #expect(files.map(\.data) == samples.map(\.data))
        #expect(used.contains { $0 > 720 }, "test file reaches past sector 720")
        #expect(!used.contains(720) && used.allSatisfy { $0 < 1024 }, "sector 720 and 1024+ are not used")

        let vtoc = disk.sector(360), vtoc2 = disk.sector(1024)
        #expect(vtoc.le16(1) == 1010, "total usable sectors")
        #expect(vtoc2.slice(0, 84) == vtoc.slice(16, 84), "VTOC2 mirrors the main bitmap")
        var free = 0
        for s in 720..<1024 {
            let i = s - 720
            let isFree = vtoc2.u8(84 + i / 8) >> (7 - i % 8) & 1 == 1
            if isFree { free += 1 }
            #expect(isFree == (s != 720 && !used.contains(s)), "VTOC2 sector \(s)")
        }
        #expect(vtoc2.le16(122) == free, "VTOC2 free count")
    }
}
