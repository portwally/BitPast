import Foundation
import Testing
@testable import BitPast

/// FAT12/FAT16 images used by the Atari ST, MSX and PC writers,
/// read back using only the BIOS Parameter Block in the boot sector.
@Suite("FAT disks (Atari ST, MSX, PC)")
struct FATDiskTests {

    nonisolated enum System: String, CaseIterable, CustomStringConvertible {
        case atariST, msx, pc
        var description: String { rawValue }
        var ext: String { self == .atariST ? "st" : self == .msx ? "dsk" : "img" }
        /// The sizes the Create Disk sheet offers for each system.
        var sizes: [DiskSize] {
            switch self {
            case .atariST: [.kb360, .kb720, .mb1_44]
            case .msx: [.kb360, .kb720]
            case .pc: [.kb360, .kb720, .mb1_2, .mb1_44]
            }
        }

        @MainActor func write(at url: URL, size: DiskSize, files: [(url: URL, name: String)]) -> Bool {
            switch self {
            case .atariST: STWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", size: size, files: files)
            case .msx: MSXDiskWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", size: size, files: files)
            case .pc: IMGWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", size: size, files: files)
            }
        }
    }

    /// The parts of a FAT volume a reader needs, taken from the boot sector.
    nonisolated struct Volume {
        let image: Data
        let bytesPerSector, sectorsPerCluster, reserved, fats, rootEntries, totalSectors, fatSectors: Int
        let media: Int

        init(_ image: Data) {
            self.image = image
            bytesPerSector = image.le16(11)
            sectorsPerCluster = image.u8(13)
            reserved = image.le16(14)
            fats = image.u8(16)
            rootEntries = image.le16(17)
            totalSectors = image.le16(19) != 0 ? image.le16(19) : image.le32(32)
            media = image.u8(21)
            fatSectors = image.le16(22)
        }

        var rootOffset: Int { (reserved + fats * fatSectors) * bytesPerSector }
        var dataStart: Int { rootOffset + rootEntries * 32 }
        var clusterBytes: Int { sectorsPerCluster * bytesPerSector }
        var clusterCount: Int { (totalSectors * bytesPerSector - dataStart) / clusterBytes }
        var isFAT16: Bool { clusterCount >= 4085 }

        func fat(_ copy: Int) -> Data {
            image.slice((reserved + copy * fatSectors) * bytesPerSector, fatSectors * bytesPerSector)
        }

        func entry(_ n: Int) -> Int {
            let f = fat(0)
            if isFAT16 { return f.le16(n * 2) }
            let v = f.le16(n * 3 / 2)
            return n % 2 == 1 ? v >> 4 : v & 0xFFF
        }

        var endOfChain: Int { isFAT16 ? 0xFFF8 : 0xFF8 }

        /// Reads the root directory files, following their cluster chains.
        func files() -> (files: [ReadFile], clusters: Set<Int>) {
            var result: [ReadFile] = []
            var used = Set<Int>()
            for i in 0..<rootEntries {
                let e = image.slice(rootOffset + i * 32, 32)
                if e.u8(0) == 0 { break }
                if e.u8(0) == 0xE5 || e.u8(11) & 0x08 != 0 { continue }  // deleted or volume label
                let name = e.text(0, 8)
                let ext = e.text(8, 3)
                let size = e.le32(28)
                var cluster = e.le16(26)
                var data = Data()
                var guardCount = 0
                while cluster >= 2 && cluster < endOfChain {
                    guard cluster < clusterCount + 2 else { Issue.record("cluster \(cluster) out of range"); break }
                    #expect(used.insert(cluster).inserted, "cluster \(cluster) used twice")
                    data.append(image.slice(dataStart + (cluster - 2) * clusterBytes, clusterBytes))
                    cluster = entry(cluster)
                    guardCount += 1
                    if guardCount > 10_000 { Issue.record("FAT loop"); break }
                }
                result.append(ReadFile(name: ext.isEmpty ? name : "\(name).\(ext)", data: data.prefix(size)))
            }
            return (result, used)
        }
    }

    /// Writes an image and checks the boot sector is sane enough to read further.
    static func volume(_ system: System, size: DiskSize, files: [SampleFile]) throws -> Volume {
        let image = try TestDisk.image(named: "TEST.\(system.ext)", files: files) { url, inputs in
            system.write(at: url, size: size, files: inputs)
        }
        let volume = Volume(image)
        try #require(volume.bytesPerSector == 512, "bytes per sector")
        try #require(volume.sectorsPerCluster > 0 && volume.fatSectors > 0, "BPB geometry")
        return volume
    }

    nonisolated static var allCases: [(System, DiskSize)] {
        System.allCases.flatMap { system in system.sizes.map { (system, $0) } }
    }

    @Test("Image size matches the size picked and the boot sector", arguments: allCases)
    func imageSize(system: System, size: DiskSize) throws {
        let volume = try Self.volume(system, size: size, files: TestDisk.standardFiles(ext: "pi1"))
        #expect(volume.image.count == size.bytes)
        #expect(volume.totalSectors * volume.bytesPerSector == volume.image.count, "BPB total sectors")
    }

    @Test("Files read back intact", arguments: allCases)
    func roundTrip(system: System, size: DiskSize) throws {
        let samples = TestDisk.standardFiles(ext: "pi1")
        let files = try Self.volume(system, size: size, files: samples).files().files
        #expect(files.map(\.name) == samples.map { "\($0.name).PI1" })
        #expect(files.map(\.data) == samples.map(\.data))
    }

    @Test("FAT copies agree and start with the media byte", arguments: allCases)
    func fatTables(system: System, size: DiskSize) throws {
        let volume = try Self.volume(system, size: size, files: TestDisk.standardFiles(ext: "pi1"))
        #expect(volume.fats == 2)
        #expect(volume.fat(0) == volume.fat(1), "FAT copies match")
        #expect(volume.fat(0).u8(0) == volume.media, "FAT starts with the media descriptor")
    }

    @Test("Only clusters used by files are allocated", arguments: allCases)
    func noLeakedClusters(system: System, size: DiskSize) throws {
        let volume = try Self.volume(system, size: size, files: TestDisk.standardFiles(ext: "pi1"))
        let used = volume.files().clusters
        for cluster in 2..<(volume.clusterCount + 2) {
            let allocated = volume.entry(cluster) != 0
            #expect(allocated == used.contains(cluster), "cluster \(cluster)")
        }
    }
}
