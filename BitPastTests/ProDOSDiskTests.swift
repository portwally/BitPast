import Foundation
import Testing
@testable import BitPast

/// Apple II ProDOS volumes: volume directory at block 2, 39-byte entries,
/// seedling / sapling / tree files, and a free-block bitmap.
@Suite("Apple II ProDOS")
struct ProDOSDiskTests {

    nonisolated struct Volume {
        let image: Data
        func block(_ n: Int) -> Data { image.slice(n * 512, 512) }

        var header: Data { block(2).slice(4, 39) }
        var totalBlocks: Int { header.le16(0x25) }
        var bitmapBlock: Int { header.le16(0x23) }

        /// Data blocks of a file, following index blocks for saplings and trees.
        /// Index blocks hold low bytes in the first half and high bytes in the second.
        func dataBlocks(storage: Int, key: Int, used: inout Set<Int>) -> [Int] {
            func index(_ b: Int) -> [Int] {
                used.insert(b)
                let ib = block(b)
                return (0..<256).map { ib.u8($0) | ib.u8(256 + $0) << 8 }.filter { $0 != 0 }
            }
            switch storage {
            case 1: return [key]
            case 2: return index(key)
            case 3: return index(key).flatMap { index($0) }
            default: Issue.record("unexpected storage type \(storage)"); return []
            }
        }

        func files() -> (files: [ReadFile], blocks: Set<Int>) {
            var result: [ReadFile] = []
            var used: Set<Int> = [0, 1]
            var dirBlock = 2
            var first = true
            while dirBlock != 0 {
                used.insert(dirBlock)
                let b = block(dirBlock)
                for i in (first ? 1 : 0)..<13 {
                    let e = b.slice(4 + i * 39, 39)
                    let storage = e.u8(0) >> 4
                    guard storage != 0 else { continue }
                    let name = e.text(1, e.u8(0) & 0x0F)
                    let eof = e.le24(0x15)
                    var fileBlocks = Set<Int>()
                    let blocks = dataBlocks(storage: storage, key: e.le16(0x11), used: &fileBlocks)
                    fileBlocks.formUnion(blocks)
                    #expect(e.le16(0x13) == fileBlocks.count, "\(name) blocks used")
                    #expect(used.isDisjoint(with: fileBlocks), "\(name) shares blocks")
                    used.formUnion(fileBlocks)
                    let data = blocks.reduce(into: Data()) { $0.append(block($1)) }
                    result.append(ReadFile(name: name, data: data.prefix(eof)))
                }
                first = false
                dirBlock = b.le16(2)
            }
            return (result, used)
        }
    }

    /// Creates a volume and adds files the same way the app does.
    static func makeVolume(blocks: Int, files: [SampleFile]) async throws -> Volume {
        let dir = try TestDisk.makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("TEST.po")
        let created: Bool = await withCheckedContinuation { c in
            ProDOSWriter.shared.createDiskImage(at: url, volumeName: "BITPAST", totalBlocks: blocks) { ok, _ in c.resume(returning: ok) }
        }
        #expect(created)
        for file in files {
            let added: Bool = await withCheckedContinuation { c in
                ProDOSWriter.shared.addFile(diskImagePath: url, fileName: file.name, fileData: file.data,
                                            fileType: 0x06, auxType: 0x2000) { ok, _ in c.resume(returning: ok) }
            }
            #expect(added, "add \(file.name)")
        }
        return Volume(image: try Data(contentsOf: url))
    }

    @Test("Volume header is valid", arguments: [280, 1600, 65535])
    func header(blocks: Int) async throws {
        let volume = try await Self.makeVolume(blocks: blocks, files: [])
        #expect(volume.image.count == blocks * 512)
        #expect(volume.header.u8(0) >> 4 == 0xF, "volume directory header")
        #expect(volume.header.text(1, volume.header.u8(0) & 0x0F) == "BITPAST")
        #expect(volume.header.u8(0x1F) == 0x27 && volume.header.u8(0x20) == 0x0D, "entry length and entries per block")
        #expect(volume.totalBlocks == blocks)
    }

    /// The 140 000-byte file needs more than 256 blocks, so it is stored as a tree.
    @Test("Seedling, sapling and tree files read back intact")
    func roundTrip() async throws {
        let samples = TestDisk.standardFiles(ext: "bin") + [SampleFile(name: "BIG", ext: "bin", data: TestDisk.bytes(140_000, seed: 5))]
        let volume = try await Self.makeVolume(blocks: 1600, files: samples)
        let files = volume.files().files
        #expect(files.map(\.name) == samples.map(\.name))
        #expect(files.map(\.data) == samples.map(\.data))
        #expect(volume.header.le16(0x21) == samples.count, "file count")
    }

    /// In the bitmap a set bit means free; bit 7 of byte 0 is block 0.
    @Test("Bitmap marks exactly the blocks in use", arguments: [280, 1600])
    func bitmap(blocks: Int) async throws {
        let volume = try await Self.makeVolume(blocks: blocks, files: TestDisk.standardFiles(ext: "bin"))
        var used = volume.files().blocks
        let bitmapBlocks = (blocks + 4095) / 4096
        used.formUnion(volume.bitmapBlock..<(volume.bitmapBlock + bitmapBlocks))
        var bitmap = Data()
        for b in 0..<bitmapBlocks { bitmap.append(volume.block(volume.bitmapBlock + b)) }
        for n in 0..<blocks {
            let isFree = bitmap.u8(n / 8) >> (7 - n % 8) & 1 == 1
            #expect(isFree != used.contains(n), "bitmap block \(n)")
        }
    }
}
